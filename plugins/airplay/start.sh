#!/bin/bash

set -e

if [ -n "$SOUND_DISABLE_AIRPLAY" ]; then
  echo "Airplay is disabled, exiting..."
  exit 0
fi

# --- ENV VARS ---
# SOUND_DEVICE_NAME: Set the device broadcast name for AirPlay
SOUND_DEVICE_NAME=${SOUND_DEVICE_NAME:-"balenaSound AirPlay $(echo "$BALENA_DEVICE_UUID" | cut -c -4)"}

echo "Starting AirPlay plugin..."
echo "Device name: ${SOUND_DEVICE_NAME:-${DEVICE_NAME:-$BALENA_DEVICE_NAME_AT_INIT}}"

# Skip avahi daemon startup completely - mDNS discovery works via system services
echo "Skipping avahi daemon startup - using system mDNS services"

# Wait for PulseAudio to be available
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

# Create shairport-sync configuration with ALSA backend and high-quality audio settings
echo "Starting Shairport Sync with custom configuration"
echo "Configuration written to /etc/shairport-sync.conf"

# Use SOUND_DEVICE_NAME if available, otherwise fall back to DEVICE_NAME or BALENA_DEVICE_NAME_AT_INIT
AIRPLAY_NAME="${SOUND_DEVICE_NAME:-${DEVICE_NAME:-$BALENA_DEVICE_NAME_AT_INIT}}"

cat > /etc/shairport-sync.conf << EOF
general = {
    name = "$AIRPLAY_NAME";
    interpolation = "soxr";
    output_backend = "alsa";
    mdns_backend = "avahi";
    port = 5000;
    udp_port_base = 6001;
    udp_port_range = 10;
    drift_tolerance_in_seconds = 0.002;
    resync_threshold_in_seconds = 0.050;
    default_airplay_volume = 0.0;
    ignore_volume_control = "yes";
};

metadata = {
    enabled = "yes";
    include_cover_art = "yes";
    pipe_name = "/tmp/shairport-sync-metadata";
    pipe_timeout = 5000;
};

sessioncontrol = {
    allow_session_interruption = "yes";
    session_timeout = 120;
};

alsa = {
    output_device = "default";
    mixer_control_name = "PCM";
    mixer_device = "default";
    output_rate = 48000;
    output_format = "S24_3LE";
    disable_synchronization = "no";
    period_size = 1024;
    buffer_size = 8192;
    use_mmap_if_available = "yes";
};

airplay_2 = {
    enabled = "yes";
    nqptp_shared_memory_interface_name = "nqptp";
};

diagnostics = {
    disable_resend_requests = "no";
    log_verbosity = 1;
    log_show_time_since_startup = "yes";
    log_show_time_since_last_message = "yes";
};
EOF

# Start shairport-sync with the correct configuration file and remove deprecated options
exec /usr/local/bin/shairport-sync -c /etc/shairport-sync.conf
