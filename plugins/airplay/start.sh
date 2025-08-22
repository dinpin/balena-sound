#!/usr/bin/env sh

if [[ -n "$SOUND_DISABLE_AIRPLAY" ]]; then
  echo "Airplay is disabled, exiting..."
  exit 0
fi

# --- ENV VARS ---
# SOUND_DEVICE_NAME: Set the device broadcast name for AirPlay
SOUND_DEVICE_NAME=${SOUND_DEVICE_NAME:-"balenaSound AirPlay $(echo "$BALENA_DEVICE_UUID" | cut -c -4)"}

echo "Starting AirPlay plugin..."
echo "Device name: $SOUND_DEVICE_NAME"

# Start AirPlay with high quality settings and low latency for video sync
echo "Starting Shairport Sync"
exec shairport-sync \
  --name "$SOUND_DEVICE_NAME" \
  --output alsa \
  --use-stderr \
  --statistics \
  --tolerance 88 \
  --audio-backend-latency-offset -1000 \
  --audio-backend-buffer-desired-length 0.15 \
  -c /dev/null \
  -- -d pulse -r 48000 -f S24_LE \
  | echo "Shairport-sync started. Device is discoverable as $SOUND_DEVICE_NAME"
