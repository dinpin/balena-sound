#!/bin/sh
set -u

case "$(uname -m)" in
  x86_64) ARCH=x86_64 ;;
  aarch64) ARCH=arm64 ;;
  armv7l) ARCH=arm32 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

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
     && tar -xzf "$tmp/soloist.tar.gz" -C "$tmp" \
     && [ -x "$tmp/soloist" ] \
     && "$tmp/soloist" --version >/dev/null; then
    if mv "$tmp/soloist" "$BIN.new" && mv "$BIN.new" "$BIN"; then
      rc=0
    else
      rc=1
    fi
  else
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
