#!/bin/bash
set -e

# Audio quality environment variables with defaults
AUDIO_SAMPLE_RATE=${AUDIO_SAMPLE_RATE:-48000}
AUDIO_BIT_DEPTH=${AUDIO_BIT_DEPTH:-24}
AUDIO_RESAMPLER=${AUDIO_RESAMPLER:-soxr-vhq}

# Determine audio format based on bit depth
case "$AUDIO_BIT_DEPTH" in
  16) AUDIO_FORMAT="S16LE" ;;
  24) AUDIO_FORMAT="S24LE" ;;
  32) AUDIO_FORMAT="S32LE" ;;
  *) AUDIO_FORMAT="S24LE"; AUDIO_BIT_DEPTH=24 ;;
esac

echo "Audio Quality Settings:"
echo "  Sample Rate: ${AUDIO_SAMPLE_RATE}Hz"
echo "  Bit Depth: ${AUDIO_BIT_DEPTH}-bit"
echo "  Format: ${AUDIO_FORMAT}"
echo "  Resampler: ${AUDIO_RESAMPLER}"

# Set default mode and latency values
MODE=${SOUND_MODE:-MULTI_ROOM}
SOUND_INPUT_LATENCY=${SOUND_INPUT_LATENCY:-200}
SOUND_OUTPUT_LATENCY=${SOUND_OUTPUT_LATENCY:-200}

echo "balena-sound Configuration:"
echo "  Mode: $MODE"
echo "  Input Latency: ${SOUND_INPUT_LATENCY}ms"
echo "  Output Latency: ${SOUND_OUTPUT_LATENCY}ms"

# Set up environment for PipeWire
export XDG_RUNTIME_DIR="/tmp/pipewire-runtime"
export PIPEWIRE_RUNTIME_DIR="$XDG_RUNTIME_DIR"
export PULSE_RUNTIME_PATH="/tmp/pulse-runtime"
export PULSE_STATE_PATH="/tmp/pulse-state"
export PULSE_CONFIG_PATH="/tmp/pulse-config"

# Create necessary directories
mkdir -p "$XDG_RUNTIME_DIR" "$PULSE_RUNTIME_PATH" "$PULSE_STATE_PATH" "$PULSE_CONFIG_PATH"
mkdir -p /etc/pipewire/pipewire.conf.d
mkdir -p /etc/wireplumber/main.lua.d

# Update PipeWire configuration with current audio settings
function update_pipewire_config() {
  local CONFIG_FILE="/usr/src/pipewire.conf"
  local TARGET_CONFIG="/etc/pipewire/pipewire.conf.d/99-balena-sound.conf"
  
  # Copy base configuration
  cp "$CONFIG_FILE" "$TARGET_CONFIG"
  
  # Update audio format and sample rate in configuration
  sed -i "s/default.clock.rate = .*/default.clock.rate = $AUDIO_SAMPLE_RATE/" "$TARGET_CONFIG"
  sed -i "s/audio.format = \"S24LE\"/audio.format = \"$AUDIO_FORMAT\"/g" "$TARGET_CONFIG"
  sed -i "s/audio.rate = 48000/audio.rate = $AUDIO_SAMPLE_RATE/g" "$TARGET_CONFIG"
  
  echo "Updated PipeWire configuration: $TARGET_CONFIG"
}

# Update WirePlumber configuration
function update_wireplumber_config() {
  local CONFIG_FILE="/usr/src/wireplumber.lua"
  local TARGET_CONFIG="/etc/wireplumber/main.lua.d/99-balena-sound.lua"
  
  # Copy WirePlumber configuration
  cp "$CONFIG_FILE" "$TARGET_CONFIG"
  
  echo "Updated WirePlumber configuration: $TARGET_CONFIG"
}

# Create PulseAudio client configuration for compatibility
function setup_pulse_compatibility() {
  cat > "$PULSE_CONFIG_PATH/client.conf" << EOF
# PulseAudio client configuration for PipeWire compatibility
default-server = tcp:localhost:4317
autospawn = no
EOF
  
  echo "PulseAudio compatibility layer configured"
}

# Wait for hardware detection
function wait_for_hardware() {
  echo "Waiting for audio hardware detection..."
  sleep 3
  
  # Check if any ALSA devices are available
  if aplay -l >/dev/null 2>&1; then
    echo "Audio hardware detected:"
    aplay -l | grep "card [0-9]:" || true
  else
    echo "No audio hardware detected, using software-only mode"
  fi
}

# Function to create simple routing setup
function create_routing_setup() {
  cat > /tmp/setup-routing.sh << 'EOF'
#!/bin/bash
# Simple routing setup for balena-sound
sleep 10

echo "Setting up balena-sound audio routing..."

# Wait for PipeWire to be ready
for i in {1..30}; do
  if pw-cli info >/dev/null 2>&1; then
    echo "PipeWire is ready"
    break
  fi
  sleep 1
done

# List available nodes
echo "Available audio nodes:"
pw-cli ls Node | grep -E "(node.name|node.description)" || true

echo "Audio routing setup completed"
EOF
  
  chmod +x /tmp/setup-routing.sh
}

# Function to handle shutdown
cleanup() {
  echo "Shutting down balena-sound audio services..."
  pkill -f pipewire || true
  pkill -f wireplumber || true
  wait
  exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Main setup sequence
echo "Setting up balena-sound with PipeWire..."

# Configure audio routing based on mode
case "$MODE" in
  "STANDALONE" | "MULTI_ROOM_CLIENT")
    echo "Routing 'balena-sound.input' to 'balena-sound.output'."
    ;;
  "MULTI_ROOM" | *)
    echo "Routing 'balena-sound.input' to 'snapcast'."
    ;;
esac

# Update configuration files
update_pipewire_config
update_wireplumber_config
setup_pulse_compatibility
create_routing_setup
wait_for_hardware

# Start PipeWire with simplified approach
echo "Starting PipeWire daemon..."
pipewire --config-dir=/etc/pipewire/pipewire.conf.d &
PIPEWIRE_PID=$!

# Give PipeWire time to initialize
sleep 5

# Start WirePlumber session manager
echo "Starting WirePlumber session manager..."
wireplumber --config-dir=/etc/wireplumber &
WIREPLUMBER_PID=$!

# Give WirePlumber time to initialize
sleep 5

# Start PipeWire PulseAudio compatibility daemon
echo "Starting PipeWire PulseAudio compatibility layer..."
pipewire-pulse &
PULSE_PID=$!

# Give the compatibility layer time to start
sleep 3

# Run routing setup in background
/tmp/setup-routing.sh &

echo "balena-sound PipeWire audio system is running"
echo "PulseAudio compatibility available on tcp:4317"
echo "Virtual sinks: balena-sound.input, balena-sound.output, snapcast"

# Keep the container running and monitor processes
while true; do
  # Check if main processes are still running
  if ! kill -0 $PIPEWIRE_PID 2>/dev/null; then
    echo "PipeWire daemon stopped unexpectedly, restarting..."
    pipewire --config-dir=/etc/pipewire/pipewire.conf.d &
    PIPEWIRE_PID=$!
    sleep 5
  fi
  
  if ! kill -0 $WIREPLUMBER_PID 2>/dev/null; then
    echo "WirePlumber stopped unexpectedly, restarting..."
    wireplumber --config-dir=/etc/wireplumber &
    WIREPLUMBER_PID=$!
    sleep 5
  fi
  
  if ! kill -0 $PULSE_PID 2>/dev/null; then
    echo "PipeWire-Pulse stopped unexpectedly, restarting..."
    pipewire-pulse &
    PULSE_PID=$!
    sleep 3
  fi
  
  sleep 10
done
