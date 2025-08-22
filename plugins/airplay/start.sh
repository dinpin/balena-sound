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

# Start avahi-daemon without D-Bus to avoid the looping issue
echo "Starting avahi daemon"
avahi-daemon --daemonize --no-drop-root --no-chroot 2>/dev/null || {
    echo "Avahi daemon failed to start, continuing without mDNS discovery"
}

# Wait a moment for avahi to initialize
sleep 3

# Wait for PulseAudio to be available
echo "Waiting for PulseAudio server..."
timeout=30
while [ $timeout -gt 0 ]; do
    if nc -z localhost 4317 2>/dev/null; then
        echo "PulseAudio server is available"
        break
    fi
    echo "Waiting for PulseAudio... ($timeout seconds remaining)"
    sleep 1
    timeout=$((timeout - 1))
done

if [ $timeout -eq 0 ]; then
    echo "Warning: PulseAudio server not detected, continuing anyway"
fi

# Create shairport-sync configuration file with simplified settings
cat > /tmp/shairport-sync.conf << EOF
general = {
    name = "$SOUND_DEVICE_NAME";
    output_backend = "pa";
    mdns_backend = "avahi";
    port = 5000;
    udp_port_base = 6001;
    udp_port_range = 10;
    statistics = "yes";
    log_verbosity = 2;
    ignore_volume_control = "no";
    volume_range_db = 60;
    regtype = "_raop._tcp";
    playbook_mode = "stereo";
};

pa = {
    application_name = "Shairport Sync";
    server = "tcp:localhost:4317";
};

sessioncontrol = {
    allow_session_interruption = "yes";
    session_timeout = 120;
};

metadata = {
    enabled = "no";
};
EOF

echo "Starting Shairport Sync with custom configuration"
echo "Configuration written to /tmp/shairport-sync.conf"

# Start shairport-sync with the config file and more verbose logging
exec shairport-sync -c /tmp/shairport-sync.conf --use-stderr --statistics --verbose
