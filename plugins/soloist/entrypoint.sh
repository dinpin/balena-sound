#!/bin/sh
set -u

MACHINE=$(uname -m)
if command -v dpkg >/dev/null 2>&1; then
  DEBIAN_ARCH=$(dpkg --print-architecture 2>/dev/null || true)
else
  DEBIAN_ARCH=
fi

case "${DEBIAN_ARCH:-$MACHINE}" in
  amd64|x86_64) ARCH=x86_64 ;;
  arm64|aarch64) ARCH=arm64 ;;
  armhf|armel|armv7l|armv6l|armv8l) ARCH=arm32 ;;
  i386|i686) ARCH=x86_64 ;;
  *)
    echo "Unsupported architecture: native=$DEBIAN_ARCH kernel=$MACHINE" >&2
    exit 1
    ;;
esac

echo "Running native $DEBIAN_ARCH on kernel $MACHINE; using Soloist $ARCH build"

URL="https://soloist-builds.spotifycdn.com/soloist_release_${ARCH}.tar.gz"
BIN=/data/bin/soloist
export STATE_DIRECTORY=/data/state CACHE_DIRECTORY=/data/cache

if [ -z "${SOLOIST_API_KEY:-}" ]; then
  echo "SOLOIST_API_KEY must be configured." >&2
  exit 1
fi

mkdir -p /data/bin "$STATE_DIRECTORY" "$CACHE_DIRECTORY"

fetch() {
  tmp=$(mktemp -d /data/.soloist-download.XXXXXX) || return 1
  if curl -fsSL -o "$tmp/soloist.tar.gz" "$URL" \
     && tar -xzf "$tmp/soloist.tar.gz" -C "$tmp"; then
    candidate=$(find "$tmp" -type f -name soloist -perm -111 | head -n 1)
    if [ -z "$candidate" ]; then
      echo "Soloist archive did not contain an executable named soloist" >&2
      rc=1
    else
      echo "Downloaded binary: $(file "$candidate" 2>/dev/null || true)"
      if "$candidate" --version >/dev/null 2>&1; then
        if mv "$candidate" "$BIN.new" && mv "$BIN.new" "$BIN"; then
          rc=0
        else
          echo "Failed to install downloaded Soloist binary" >&2
          rc=1
        fi
      else
        echo "Downloaded Soloist binary cannot start; missing native libraries or wrong architecture" >&2
        if command -v ldd >/dev/null 2>&1; then
          ldd "$candidate" >&2 || true
        fi
        rc=1
      fi
    fi
  else
    echo "Failed to download or extract $URL" >&2
    rc=1
  fi
  rm -rf "$tmp"
  return "$rc"
}

if [ ! -x "$BIN" ]; then
  fetch || { echo "Unable to download Soloist." >&2; exit 1; }
fi

case "${SOLOIST_VERBOSE:-false}" in
  1|[Tt][Rr][Uu][Ee]|[Yy][Ee][Ss]|[Oo][Nn]) set -- --verbose ;;
  *) set -- ;;
esac

while true; do
  code=0
  timeout 3888000 "$BIN" \
         --device-name "${SOUND_DEVICE_NAME:-balenaSound}" \
         --api-key "$SOLOIST_API_KEY" \
         --initial-volume "${SOUND_VOLUME:-100}" \
         "$@" || code=$?

  if ! fetch; then
    echo "Soloist update failed; keeping the existing binary." >&2
  fi
  echo "Soloist exited with code $code; restarting in 5 seconds."
  sleep 5
done
