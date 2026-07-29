#!/usr/bin/env bash
set -e

if [[ -n "$SOUND_DISABLE_PLEX" ]]; then
  echo "Plex is disabled, exiting..."
  exit 0
fi

# --- ENV VARS ---
# SOUND_DEVICE_NAME : Name shown as the player in the Plex cast menu (default: hostname)
#
# NOTE: plex-mpv-shim requires NO login/token. It discovers and registers with
# a Plex Media Server on the local network via the GDM multicast protocol
# (239.0.0.250:32413). The Plex Media Server must have "Enable local network
# discovery (GDM)" turned on under Settings -> Network for this to work.

SOUND_DEVICE_NAME="${SOUND_DEVICE_NAME:-balenaSound Plex ${BALENA_DEVICE_UUID:0:4}}"

CONFIG_DIR="/root/.config/plex-mpv-shim"
CONFIG_FILE="$CONFIG_DIR/config.json"

mkdir -p "$CONFIG_DIR" /var/cache/plex-mpv-shim

# mpv audio/video options go in mpv.conf, not config.json
# ao=pulse: route audio through PulseAudio (via PULSE_SERVER env var)
# vo=null:  no video output - music only
cat > "$CONFIG_DIR/mpv.conf" << 'MPVEOF'
ao=pulse
vo=null
MPVEOF

# Only the keys actually recognised by plex-mpv-shim's config schema are used here.
# See: https://github.com/iwalton3/plex-mpv-shim/blob/master/plex_mpv_shim/conf.py
cat > "$CONFIG_FILE" << EOF
{
    "player_name": "$SOUND_DEVICE_NAME",
    "http_port": "32433",
    "enable_gui": false,
    "fullscreen": false
}
EOF

echo "Starting Plex plugin (plex-mpv-shim)..."
echo "Player name : $SOUND_DEVICE_NAME"

# Wait for PulseAudio to be available (provided by the core audio service)
echo "Waiting for PulseAudio server..."
timeout=30
while ! curl -s http://localhost:4317 > /dev/null 2>&1; do
  sleep 1
  timeout=$((timeout - 1))
  if [ $timeout -eq 0 ]; then
    echo "Warning: PulseAudio server not responding, continuing anyway..."
    break
  fi
done
echo "PulseAudio server is available"

exec /opt/plex-venv/bin/plex-mpv-shim
