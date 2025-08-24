#!/usr/bin/env sh

if [ -n "$SOUND_DISABLE_AIRPLAY" ]; then
  echo "Airplay is disabled, exiting..."
  exit 0
fi

# --- ENV VARS ---
# SOUND_DEVICE_NAME: Set the device broadcast name for AirPlay
SOUND_DEVICE_NAME=${SOUND_DEVICE_NAME:-"balenaSound AirPlay $(echo "$BALENA_DEVICE_UUID" | cut -c -4)"}

echo "Starting AirPlay plugin..."
echo "Device name: $SOUND_DEVICE_NAME"

# Skip avahi daemon startup - device discovery is working without it
echo "Skipping avahi daemon startup - mDNS discovery working via system"

# ALSA bridge will connect to PulseAudio automatically when audio plays
echo "Using ALSA bridge for PulseAudio connectivity"

# Create shairport-sync configuration file with high-quality 48kHz/24-bit audio (matching snapcast)
cat > /tmp/shairport-sync.conf << EOF
general = {
    name = "$SOUND_DEVICE_NAME";
    output_backend = "alsa";
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
    interpolation = "soxr";
    output_format = "S24_3LE";
    output_rate = 48000;
    audio_backend_latency_offset_in_seconds = 0.0;
    audio_backend_buffer_desired_length_in_seconds = 0.15;
    drift_tolerance_in_seconds = 0.002;
    resync_threshold_in_seconds = 0.05;
};

alsa = {
    output_device = "default";
    mixer_control_name = "PCM";
    output_rate = 48000;
    output_format = "S24_3LE";
    disable_synchronization = "no";
    period_size = 1024;
    buffer_size = 4096;
    use_mmap_if_available = "yes";
};

soxr = {
    quality = "very high";
    precision = 28;
    phase_response = 50;
    passband_end = 0.95;
    stopband_begin = 1.05;
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
