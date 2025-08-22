#!/usr/bin/env sh

if [[ -n "$SOUND_DISABLE_AIRPLAY" ]]; then
  echo "Airplay is disabled, exiting..."
  exit 0
fi

# --- ENV VARS ---
# SOUND_DEVICE_NAME: Set the device broadcast name for AirPlay
SOUND_DEVICE_NAME=${SOUND_DEVICE_NAME:-"balenaSound AirPlay $(echo "$BALENA_DEVICE_UUID" | cut -c -4)"}

echo "Starting AirPlay plugin..."
echo "Device name: $SOUND_DEVICE_NAME"

# Check if avahi-daemon is running, if not start it (needed for ARM32)
if ! pgrep -x "avahi-daemon" > /dev/null; then
    echo "Starting avahi-daemon for mDNS (no D-Bus mode)..."
    
    # Create avahi config that disables D-Bus
    mkdir -p /etc/avahi
    cat > /etc/avahi/avahi-daemon.conf <<EOF
[server]
use-ipv4=yes
use-ipv6=no
enable-dbus=no
allow-interfaces=eth0,wlan0
ratelimit-interval-usec=1000000
ratelimit-burst=1000

[wide-area]
enable-wide-area=yes

[publish]
publish-addresses=yes
publish-hinfo=yes
publish-workstation=no
publish-domain=yes

[reflector]

[rlimits]
EOF
    
    # Start avahi-daemon with our config (no D-Bus required)
    avahi-daemon --no-drop-root --no-chroot -D &
    sleep 2
fi

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
