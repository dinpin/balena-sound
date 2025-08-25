#!/bin/bash
set -e

echo "Starting PipeWire audio server with PulseAudio compatibility..."

# Function to create audio routing links
function create_audio_link() {
  local SOURCE="$1"
  local SINK="$2"
  local LATENCY="${3:-200}"
  
  echo "Creating link: $SOURCE -> $SINK (latency: ${LATENCY}ms)"
  
  # Create a link configuration file for WirePlumber
  cat > "/etc/wireplumber/main.lua.d/99-link-${SOURCE//[.]/-}-to-${SINK//[.]/-}.lua" << EOF
rule = {
  matches = {
    {
      { "node.name", "equals", "$SOURCE" },
    },
  },
  apply_properties = {
    ["node.latency"] = "${LATENCY}/48000",
  },
}
table.insert(alsa_monitor.rules, rule)

link_rule = {
  matches = {
    {
      { "node.name", "equals", "$SOURCE" },
    },
  },
  apply_properties = {
    ["link.output.node"] = "$SINK",
    ["link.input.port"] = 0,
    ["link.output.port"] = 0,
    ["object.linger"] = true,
  },
}
table.insert(default_links.rules, link_rule)
EOF
}

# Function to route input sink based on mode
function route_input_sink() {
  local MODE="$1"
  
  case "$MODE" in
    "STANDALONE" | "MULTI_ROOM_CLIENT")
      create_audio_link "balena-sound.input" "balena-sound.output" "$SOUND_INPUT_LATENCY"
      echo "Routing 'balena-sound.input' to 'balena-sound.output'."
      ;;
    
    "MULTI_ROOM" | *)
      create_audio_link "balena-sound.input" "snapcast" "$SOUND_INPUT_LATENCY"
      echo "Routing 'balena-sound.input' to 'snapcast'."
      ;;
  esac
}

# Function to route output to hardware
function route_output_sink() {
  local OUTPUT_LATENCY="${SOUND_OUTPUT_LATENCY:-200}"
  
  # Wait for hardware sink to be available
  echo "Will route 'balena-sound.output' to hardware sink when available."
  
  # Create a script to link output to hardware dynamically
  cat > "/etc/wireplumber/main.lua.d/98-output-to-hardware.lua" << EOF
-- Route balena-sound.output to the first available hardware sink
rule = {
  matches = {
    {
      { "media.class", "equals", "Audio/Sink" },
      { "node.name", "matches", "alsa_output.*" },
    },
  },
  apply_properties = {
    ["priority.session"] = 1000,
  },
}
table.insert(alsa_monitor.rules, rule)

-- Create link from balena-sound.output monitor to hardware
link_rule = {
  matches = {
    {
      { "node.name", "equals", "balena-sound.output" },
    },
  },
  apply_properties = {
    ["link.output.node"] = "~alsa_output.*",
    ["link.passive"] = false,
    ["node.latency"] = "${OUTPUT_LATENCY}/48000",
  },
}
table.insert(default_links.rules, link_rule)
EOF
}

# Function to route hardware input if enabled
function route_input_source() {
  if [[ -n "$SOUND_ENABLE_SOUNDCARD_INPUT" ]]; then
    echo "Enabling hardware input routing..."
    
    cat > "/etc/wireplumber/main.lua.d/97-hardware-input.lua" << EOF
-- Route hardware input to balena-sound.input
link_rule = {
  matches = {
    {
      { "media.class", "equals", "Audio/Source" },
      { "node.name", "matches", "alsa_input.*" },
    },
  },
  apply_properties = {
    ["link.output.node"] = "balena-sound.input",
    ["link.passive"] = false,
  },
}
table.insert(default_links.rules, link_rule)
EOF
  fi
}

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

# Configure audio routing
echo "Setting audio routing rules..."
route_input_sink "$MODE"
route_output_sink
route_input_source

# Create FIFO for snapcast if in multiroom mode
if [[ "$MODE" == "MULTI_ROOM" ]]; then
  echo "Creating FIFO for snapcast..."
  if [[ ! -p /tmp/snapfifo ]]; then
    mkfifo /tmp/snapfifo
  fi
fi

# Start D-Bus if not running (required for some PipeWire features)
if ! pgrep -x "dbus-daemon" > /dev/null; then
  echo "Starting D-Bus..."
  dbus-daemon --system --fork
fi

# Clean up any existing PipeWire/PulseAudio instances
killall pipewire wireplumber pipewire-pulse 2>/dev/null || true
sleep 1

# Start PipeWire
echo "Starting PipeWire..."
pipewire &
PIPEWIRE_PID=$!

# Wait for PipeWire to initialize
sleep 2

# Start WirePlumber (session manager)
echo "Starting WirePlumber..."
wireplumber &
WIREPLUMBER_PID=$!

# Wait for WirePlumber to initialize
sleep 2

# Start PipeWire-Pulse (PulseAudio compatibility)
echo "Starting PipeWire-Pulse (PulseAudio compatibility layer)..."
pipewire-pulse &
PIPEWIRE_PULSE_PID=$!

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
