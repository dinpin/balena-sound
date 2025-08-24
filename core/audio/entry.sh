#!/bin/bash
set -e

echo "--- Audio Container Starting ---"

# Start UDEV daemon for hardware detection
if [ "$UDEV" = "on" ]; then
    echo "Starting UDEV daemon..."
    /lib/systemd/systemd-udevd --daemon
    udevadm trigger --action=add --subsystem-match=sound
    udevadm settle
    echo "UDEV initialized"
fi

# Wait for hardware to be ready
echo "Waiting for audio hardware..."
sleep 10

# List detected audio devices
echo "Detected audio cards:"
cat /proc/asound/cards

# Set audio quality parameters
export PULSE_SAMPLE_RATE=${AUDIO_SAMPLE_RATE:-48000}
export PULSE_SAMPLE_FORMAT=${AUDIO_BIT_DEPTH:-s24le}

# Start PulseAudio in system mode
echo "Starting PulseAudio..."
exec pulseaudio \
    --system \
    --disallow-exit \
    --disallow-module-loading=false \
    --log-target=stderr \
    --log-level=${AUDIO_LOG_LEVEL:-info} \
    -v
