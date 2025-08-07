#!/usr/bin/env bash

if [[ -n "$SOUND_DISABLE_SPOTIFY" ]]; then
  echo "Spotify is disabled, exiting..."
  exit 0
fi

# --- ENV VARS ---
# SOUND_DEVICE_NAME: Set the device broadcast name for Spotify
# SOUND_SPOTIFY_BITRATE: Set the playback bitrate
SOUND_DEVICE_NAME=${SOUND_DEVICE_NAME:-"balenaSound Spotify $(echo "$BALENA_DEVICE_UUID" | cut -c -4)"}
SOUND_SPOTIFY_BITRATE=${SOUND_SPOTIFY_BITRATE:-160}

# SOUND_SPOTIFY_DISABLE_NORMALISATION: Disable volume normalization
if [[ -z ${SOUND_SPOTIFY_DISABLE_NORMALISATION+x} ]]; then
  set -- "$@" --enable-volume-normalisation
fi

# SOUND_SPOTIFY_ENABLE_CACHE: Enable Spotify audio cache
if [[ -z ${SOUND_SPOTIFY_ENABLE_CACHE+x} ]]; then
  set -- "$@" --disable-audio-cache
fi

# Explicitly enable discovery mode (required for librespot >= 0.6)
set -- "$@" --enable-discovery

echo "Starting Spotify plugin..."
echo "Device name: $SOUND_DEVICE_NAME"
[[ -n ${SOUND_SPOTIFY_DISABLE_NORMALISATION+x} ]] && echo "Volume normalization disabled."
[[ -n ${SOUND_SPOTIFY_ENABLE_CACHE+x} ]] && echo "Spotify audio cache enabled."

# Run librespot with pulseaudio backend and passed arguments
exec /usr/bin/librespot \
  --backend pulseaudio \
  --name "$SOUND_DEVICE_NAME" \
  --bitrate "$SOUND_SPOTIFY_BITRATE" \
  --cache /var/cache/raspotify \
  --volume-ctrl linear \
  "$@"
