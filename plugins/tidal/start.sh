#!/usr/bin/env bash
set -e

if [[ -n "$SOUND_DISABLE_TIDAL" ]]; then
  echo "Tidal Connect is disabled, exiting..."
  exit 0
fi

# Default values
SOUND_DEVICE_NAME="${SOUND_DEVICE_NAME:-balenaSound Tidal ${BALENA_DEVICE_UUID:0:4}}"
SOUND_TIDAL_FRIENDLY_NAME="${SOUND_TIDAL_FRIENDLY_NAME:-$SOUND_DEVICE_NAME}"
SOUND_TIDAL_MODEL_NAME="${SOUND_TIDAL_MODEL_NAME:-balenaSound Tidal Connect}"
SOUND_TIDAL_MQA_CODEC="${SOUND_TIDAL_MQA_CODEC:-true}"
SOUND_TIDAL_MQA_PASSTHROUGH="${SOUND_TIDAL_MQA_PASSTHROUGH:-false}"
SOUND_TIDAL_LOG_LEVEL="${SOUND_TIDAL_LOG_LEVEL:-3}"

# Certificate path
CERT_PATH="/usr/ifi/ifi-tidal-release/id_certificate/IfiAudio_ZenStream.dat"

# Build arguments for tidal_connect_application
ARGS=(
  --tc-certificate-path "$CERT_PATH"
  --friendly-name "$SOUND_TIDAL_FRIENDLY_NAME"
  --model-name "$SOUND_TIDAL_MODEL_NAME"
  --codec-mqa "$SOUND_TIDAL_MQA_CODEC"
  --enable-mqa-passthrough "$SOUND_TIDAL_MQA_PASSTHROUGH"
  --log-level "$SOUND_TIDAL_LOG_LEVEL"
  --disable-app-security false
  --disable-web-security false
)

# Add network interface if available
if [[ -n "$SOUND_TIDAL_NETIF" ]]; then
  ARGS+=(--netif-for-deviceid "$SOUND_TIDAL_NETIF")
fi

echo "Starting Tidal Connect plugin..."
echo "Device name: $SOUND_TIDAL_FRIENDLY_NAME"
echo "Model name: $SOUND_TIDAL_MODEL_NAME"
echo "MQA codec: $SOUND_TIDAL_MQA_CODEC"
echo "MQA passthrough: $SOUND_TIDAL_MQA_PASSTHROUGH"

exec /usr/ifi/ifi-tidal-release/bin/tidal_connect_application "${ARGS[@]}"
