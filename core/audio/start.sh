#!/bin/bash
set -e

echo "Starting PipeWire audio server with PulseAudio compatibility..."

# Wait for sound supervisor
SOUND_SUPERVISOR_PORT=${SOUND_SUPERVISOR_PORT:-80}
SOUND_SUPERVISOR="$(ip route | awk '/default / { print $3 }'):$SOUND_SUPERVISOR_PORT"

echo "Waiting for sound supervisor at $SOUND_SUPERVISOR..."
while ! curl --silent --output /dev/null "$SOUND_SUPERVISOR/ping"; do 
  sleep 5
  echo "Waiting for sound supervisor to start at $SOUND_SUPERVISOR"
done

# Get mode from sound supervisor
MODE=$(curl --silent "$SOUND_SUPERVISOR/mode" || echo "STANDALONE")
echo "Audio mode: $MODE"

# Get latency values
SOUND_INPUT_LATENCY=${SOUND_INPUT_LATENCY:-200}
SOUND_OUTPUT_LATENCY=${SOUND_OUTPUT_LATENCY:-200}

echo "Audio routing configuration:"
echo "  Mode: $MODE"
echo "  Input latency: ${SOUND_INPUT_LATENCY}ms"
echo "  Output latency: ${SOUND_OUTPUT_LATENCY}ms"

# Create FIFO for snapcast if in multiroom mode
if [[ "$MODE" == "MULTI_ROOM" ]]; then
  echo "Creating FIFO for snapcast..."
  if [[ ! -p /tmp/snapfifo ]]; then
    mkfifo /tmp/snapfifo
  fi
fi

# Set environment to suppress D-Bus session errors
export DBUS_SESSION_BUS_ADDRESS=unix:path=/dev/null

# Clean up any stale D-Bus PID files
rm -f /run/dbus/dbus.pid /var/run/dbus/dbus.pid 2>/dev/null || true

# Start system D-Bus if not running
if ! pgrep -x "dbus-daemon" > /dev/null; then
  echo "Starting system D-Bus..."
  mkdir -p /var/run/dbus
  dbus-daemon --system --fork 2>/dev/null || echo "D-Bus already running or not needed"
fi

# Clean up any existing PipeWire/PulseAudio instances
killall pipewire wireplumber pipewire-pulse 2>/dev/null || true
sleep 1

# Start PipeWire
echo "Starting PipeWire..."
pipewire 2>&1 | grep -v "Failed to connect to session bus" &
PIPEWIRE_PID=$!

# Wait for PipeWire to initialize
sleep 2

# Start WirePlumber (session manager)
echo "Starting WirePlumber..."
wireplumber 2>&1 | grep -v "Failed to connect to session bus" &
WIREPLUMBER_PID=$!

# Wait for WirePlumber to initialize
sleep 3

# Start PipeWire-Pulse (PulseAudio compatibility)
echo "Starting PipeWire-Pulse (PulseAudio compatibility layer)..."
pipewire-pulse 2>&1 | grep -v "Failed to connect to session bus" &
PIPEWIRE_PULSE_PID=$!

# Wait for services to stabilize
sleep 2

# Create audio links using pw-link after services are running
if [[ "$MODE" == "MULTI_ROOM" ]]; then
  echo "Setting up multiroom audio routing..."
  # Link balena-sound.input to snapcast
  pw-link balena-sound.input:monitor_FL snapcast:playback_FL 2>/dev/null || true
  pw-link balena-sound.input:monitor_FR snapcast:playback_FR 2>/dev/null || true
else
  echo "Setting up standalone audio routing..."
  # Link balena-sound.input to balena-sound.output
  pw-link balena-sound.input:monitor_FL balena-sound.output:playback_FL 2>/dev/null || true
  pw-link balena-sound.input:monitor_FR balena-sound.output:playback_FR 2>/dev/null || true
fi

# Link balena-sound.output to hardware if available
echo "Linking output to hardware..."
pw-link balena-sound.output:monitor_FL alsa_output.*:playback_FL 2>/dev/null || true
pw-link balena-sound.output:monitor_FR alsa_output.*:playback_FR 2>/dev/null || true

# Function to handle shutdown
cleanup() {
  echo "Shutting down PipeWire audio server..."
  kill $PIPEWIRE_PULSE_PID 2>/dev/null || true
  kill $WIREPLUMBER_PID 2>/dev/null || true
  kill $PIPEWIRE_PID 2>/dev/null || true
  exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Monitor the processes
echo "PipeWire audio server is running with PulseAudio compatibility on port 4317"
echo "Monitoring processes..."

while true; do
  # Check if processes are still running
  if ! kill -0 $PIPEWIRE_PID 2>/dev/null; then
    echo "PipeWire died, restarting..."
    cleanup
    exec "$0" "$@"
  fi
  
  if ! kill -0 $WIREPLUMBER_PID 2>/dev/null; then
    echo "WirePlumber died, restarting..."
    cleanup
    exec "$0" "$@"
  fi
  
  if ! kill -0 $PIPEWIRE_PULSE_PID 2>/dev/null; then
    echo "PipeWire-Pulse died, restarting..."
    cleanup
    exec "$0" "$@"
  fi
  
  sleep 5
done
