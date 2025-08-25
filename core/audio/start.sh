#!/bin/bash
set -e

echo "Starting PipeWire audio server with PulseAudio compatibility..."

# Simple environment setup
export XDG_RUNTIME_DIR=/run/pipewire
export PIPEWIRE_RUNTIME_DIR=/run/pipewire
export PULSE_RUNTIME_PATH=/run/pulse

# Clean up any existing instances
killall pipewire wireplumber pipewire-pulse 2>/dev/null || true
sleep 1

# Start PipeWire (includes PulseAudio compatibility)
echo "Starting PipeWire..."
pipewire &
PIPEWIRE_PID=$!

sleep 2

# Start WirePlumber (manages audio devices)
echo "Starting WirePlumber..."
wireplumber &
WIREPLUMBER_PID=$!

sleep 2

# Start PipeWire-Pulse (PulseAudio server on port 4317)
echo "Starting PulseAudio compatibility layer..."
pipewire-pulse &
PIPEWIRE_PULSE_PID=$!

echo "PipeWire audio server is running with PulseAudio compatibility on port 4317"

# Keep running and monitor
while true; do
  if ! kill -0 $PIPEWIRE_PID 2>/dev/null || \
     ! kill -0 $WIREPLUMBER_PID 2>/dev/null || \
     ! kill -0 $PIPEWIRE_PULSE_PID 2>/dev/null; then
    echo "Service died, restarting..."
    exec "$0" "$@"
  fi
  sleep 5
done
