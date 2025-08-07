#!/usr/bin/env bash
set -e

if [[ -n "$SOUND_DISABLE_SPOTIFY" ]]; then
  echo "Spotify is disabled, exiting..."
  exit 0
fi

SOUND_DEVICE_NAME="${SOUND_DEVICE_NAME:-balenaSound Spotify ${BALENA_DEVICE_UUID:0:4}}"
SOUND_SPOTIFY_BITRATE="${SOUND_SPOTIFY_BITRATE:-160}"

ARGS=(
  --name "$SOUND_DEVICE_NAME"
  --backend pulseaudio
  --bitrate "$SOUND_SPOTIFY_BITRATE"
  --cache /var/cache/raspotify
  --volume-ctrl linear
)

if [[ -z "$SOUND_SPOTIFY_DISABLE_NORMALISATION" ]]; then
  ARGS+=(--enable-volume-normalisation)
else
  echo "Volume normalization disabled."
fi

if [[ -z "$SOUND_SPOTIFY_ENABLE_CACHE" ]]; then
  ARGS+=(--disable-audio-cache)
else
  echo "Spotify audio cache enabled."
fi

echo "Starting Spotify plugin..."
echo "Device name: $SOUND_DEVICE_NAME"

exec /usr/bin/librespot "${ARGS[@]}"
