#!/bin/bash
set -e

# Audio quality environment variables with defaults
AUDIO_SAMPLE_RATE=${AUDIO_SAMPLE_RATE:-48000}
AUDIO_BIT_DEPTH=${AUDIO_BIT_DEPTH:-24}
AUDIO_RESAMPLER=${AUDIO_RESAMPLER:-soxr-vhq}

# Determine audio format based on bit depth
case "$AUDIO_BIT_DEPTH" in
  16) AUDIO_FORMAT="s16le" ;;
  24) AUDIO_FORMAT="s24le" ;;
  32) AUDIO_FORMAT="s32le" ;;
  *) AUDIO_FORMAT="s24le"; AUDIO_BIT_DEPTH=24 ;;
esac

echo "Audio Quality Settings:"
echo "  Sample Rate: ${AUDIO_SAMPLE_RATE}Hz"
echo "  Bit Depth: ${AUDIO_BIT_DEPTH}-bit"
echo "  Format: ${AUDIO_FORMAT}"
echo "  Resampler: ${AUDIO_RESAMPLER}"

# Update PulseAudio daemon configuration
sed -i "s/default-sample-rate = .*/default-sample-rate = $AUDIO_SAMPLE_RATE/" /etc/pulse/daemon.conf
sed -i "s/default-sample-format = .*/default-sample-format = $AUDIO_FORMAT/" /etc/pulse/daemon.conf
sed -i "s/resample-method = .*/resample-method = $AUDIO_RESAMPLER/" /etc/pulse/daemon.conf

# PulseAudio configuration files for balena-sound
CONFIG_TEMPLATE=/usr/src/balena-sound.pa
CONFIG_FILE=/etc/pulse/default.pa.d/01-balenasound.pa

# Set loopback module latency
function set_loopback_latency() {
  local LOOPBACK="$1"
  local LATENCY="$2"
  
  sed -i "s/%$LOOPBACK%/$LATENCY/" "$CONFIG_FILE"
}

# Route "balena-sound.input" to the appropriate sink depending on selected mode
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

# Route "balena-sound.output" to the appropriate audio hardware
function route_output_sink() {
  local OUTPUT=""

  # Wait for PulseAudio to start and detect hardware
  sleep 2
  
  # Find the first hardware audio sink (not null-sink)
  OUTPUT=$(pactl list sinks short | grep -v "module-null-sink" | head -n1 | awk '{print $2}')
  
  # If no hardware sink found, try to find ALSA sink
  if [[ -z "$OUTPUT" ]]; then
    OUTPUT=$(pactl list sinks short | grep -E "(alsa|hw)" | head -n1 | awk '{print $2}')
  fi
  
  # Fallback to sink index if name not found
  if [[ -z "$OUTPUT" ]]; then
    OUTPUT=$(pactl list sinks short | grep -v "module-null-sink" | head -n1 | awk '{print $1}')
  fi
  
  # Final fallback
  OUTPUT="${OUTPUT:-0}"
  
  sed -i "s/%OUTPUT_SINK%/sink=$OUTPUT/" "$CONFIG_FILE"
  echo "Routing 'balena-sound.output' to '$OUTPUT'."
}

function reset_sound_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    rm "$CONFIG_FILE"
  fi 
  cp "$CONFIG_TEMPLATE" "$CONFIG_FILE"
  
  # Update sink formats to match current audio settings
  sed -i "s/format=s24le/format=$AUDIO_FORMAT/g" "$CONFIG_FILE"
  sed -i "s/rate=48000/rate=$AUDIO_SAMPLE_RATE/g" "$CONFIG_FILE"
}

# Set default mode and latency values
MODE=${SOUND_MODE:-MULTI_ROOM}
SOUND_INPUT_LATENCY=${SOUND_INPUT_LATENCY:-200}
SOUND_OUPUT_LATENCY=${SOUND_OUTPUT_LATENCY:-200}

# Audio routing: route intermediate balena-sound input/output sinks
echo "Setting audio routing rules..."
reset_sound_config
route_input_sink "$MODE"
set_loopback_latency "INPUT_LATENCY" "$SOUND_INPUT_LATENCY"
set_loopback_latency "OUTPUT_LATENCY" "$SOUND_OUPUT_LATENCY"

# Start PulseAudio with our custom configuration
echo "Starting PulseAudio with config file: $CONFIG_FILE"
echo "PulseAudio command: pulseaudio --disallow-exit --disallow-module-loading=false --daemonize=false --log-target=stderr -v --file=\"$CONFIG_FILE\""
exec pulseaudio --disallow-exit --disallow-module-loading=false --daemonize=false --log-target=stderr -v --file="$CONFIG_FILE"
