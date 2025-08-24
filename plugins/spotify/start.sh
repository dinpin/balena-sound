#!/usr/bin/env bash
set -e

if [[ -n "$SOUND_DISABLE_SPOTIFY" ]]; then
  echo "Spotify is disabled, exiting..."
  exit 0
fi

SOUND_DEVICE_NAME="${SOUND_DEVICE_NAME:-balenaSound Spotify ${BALENA_DEVICE_UUID:0:4}}"
# Maximum quality: 320 kbps (Spotify Premium quality)
SOUND_SPOTIFY_BITRATE="${SOUND_SPOTIFY_BITRATE:-320}"

ARGS=(
  --name "$SOUND_DEVICE_NAME"
  --backend pulseaudio
  --bitrate "$SOUND_SPOTIFY_BITRATE"
  --cache /var/cache/raspotify
  --volume-ctrl linear
  --initial-volume 100
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

# Configure PulseAudio connection
# Since Spotify uses network_mode: host, connect to localhost
export PULSE_SERVER="tcp:localhost:4317"

echo "Starting Spotify plugin..."
echo "Device name: $SOUND_DEVICE_NAME"

exec /usr/bin/librespot "${ARGS[@]}"
