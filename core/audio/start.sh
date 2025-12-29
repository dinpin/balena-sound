#!/bin/bash
set -e

# PulseAudio configuration files for balena-sound
CONFIG_TEMPLATE=/usr/src/balena-sound.pa
CONFIG_FILE=/etc/pulse/default.pa.d/01-balenasound.pa
DAEMON_CONFIG_TEMPLATE=/usr/src/daemon.conf
DAEMON_CONFIG_FILE=/etc/pulse/daemon.conf

# Set loopback module latency
function set_loopback_latency() {
  local LOOPBACK="$1"
  local LATENCY="$2"
  
  sed -i "s/%$LOOPBACK%/$LATENCY/" "$CONFIG_FILE"
}

# Route "balena-sound.input" to the appropriate sink depending on selected mode
# Either "snapcast" fifo sink or "balena-sound.output"
function route_input_sink() {
  local MODE="$1"

  declare -A options=(
      ["MULTI_ROOM"]=0
      ["MULTI_ROOM_CLIENT"]=1
      ["STANDALONE"]=2
    )

  case "${options[$MODE]}" in
    ${options["STANDALONE"]} | ${options["MULTI_ROOM_CLIENT"]})
      sed -i "s/%INPUT_SINK%/sink=balena-sound.output/" "$CONFIG_FILE"
      echo "Routing 'balena-sound.input' to 'balena-sound.output'."
      ;;

    ${options["MULTI_ROOM"]} | *)
      sed -i "s/%INPUT_SINK%/sink=snapcast/" "$CONFIG_FILE"
      echo "Routing 'balena-sound.input' to 'snapcast'."
      ;;
  esac
}

# Route any existing source to the input router ("balena-sound.input")
function route_input_source() {
  local INPUT_DEVICE=$(arecord -l | awk '/card [0-9]:/ { print $3 }')

  if [[ -n "$INPUT_DEVICE" ]]; then
    local INPUT_DEVICE_FULLNAME="alsa_input.$INPUT_DEVICE.analog-stereo"
    echo "Routing audio from '$INPUT_DEVICE_FULLNAME' into 'balena-sound.input sink'"
    echo -e "\nload-module module-loopback source=$INPUT_DEVICE_FULLNAME sink=balena-sound.input" >> "$CONFIG_FILE"
  fi

}

# Route "balena-sound.output" to the appropriate audio hardware
function route_output_sink() {
  local OUTPUT=""

  # Audio block outputs the default sink name to this file
  # If file doesn't exist, default to sink #0. This shouldn't happen though
  local SINK_FILE=/run/pulse/pulseaudio.sink
  if [[ -f "$SINK_FILE" ]]; then
    OUTPUT=$(cat "$SINK_FILE")
  fi
  OUTPUT="${OUTPUT:-0}"
  sed -i "s/%OUTPUT_SINK%/sink=$OUTPUT/" "$CONFIG_FILE"
  echo "Routing 'balena-sound.output' to '$OUTPUT'."
}

function reset_sound_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    rm "$CONFIG_FILE"
  fi 
  cp "$CONFIG_TEMPLATE" "$CONFIG_FILE"
  
  # Copy daemon configuration for high-quality audio
  if [[ -f "$DAEMON_CONFIG_TEMPLATE" ]]; then
    cp "$DAEMON_CONFIG_TEMPLATE" "$DAEMON_CONFIG_FILE"
    local SAMPLE_RATE=$(grep "^default-sample-rate" "$DAEMON_CONFIG_TEMPLATE" | awk '{print $3}')
    local SAMPLE_FORMAT=$(grep "^default-sample-format" "$DAEMON_CONFIG_TEMPLATE" | awk '{print $3}')
    echo "Applied high-quality audio configuration (${SAMPLE_RATE:-44100}Hz/${SAMPLE_FORMAT:-s24le})"
  fi
}

SOUND_SUPERVISOR_PORT=${SOUND_SUPERVISOR_PORT:-80}
SOUND_SUPERVISOR="$(ip route | awk '/default / { print $3 }'):$SOUND_SUPERVISOR_PORT"
# Wait for sound supervisor to start
while ! curl --silent --output /dev/null "$SOUND_SUPERVISOR/ping"; do sleep 5; echo "Waiting for sound supervisor to start at $SOUND_SUPERVISOR"; done

# Get mode from sound supervisor. 
# mode: default to MULTI_ROOM
MODE=$(curl --silent "$SOUND_SUPERVISOR/mode" || true)

# Get latency values
SOUND_INPUT_LATENCY=${SOUND_INPUT_LATENCY:-200}
SOUND_OUPUT_LATENCY=${SOUND_OUTPUT_LATENCY:-200}

# Audio routing: route intermediate balena-sound input/output sinks
echo "Setting audio routing rules..."
reset_sound_config
route_input_sink "$MODE"
route_output_sink
set_loopback_latency "INPUT_LATENCY" "$SOUND_INPUT_LATENCY"
set_loopback_latency "OUTPUT_LATENCY" "$SOUND_OUPUT_LATENCY"
if [[ -n "$SOUND_ENABLE_SOUNDCARD_INPUT" ]]; then
  route_input_source
fi

# Clean up stale PulseAudio runtime files to prevent "Daemon already running" error on restart
echo "Cleaning up stale PulseAudio runtime files..."
rm -rf /var/run/pulse/* /root/.pulse /root/.config/pulse/*-runtime 2>/dev/null || true
pkill -9 pulseaudio 2>/dev/null || true
# Ensure runtime directory exists
mkdir -p /var/run/pulse
sleep 0.5

echo "Starting PulseAudio..."
exec pulseaudio
