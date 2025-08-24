#!/bin/bash
set -e

SOUND_SUPERVISOR_PORT=${SOUND_SUPERVISOR_PORT:-80}
SOUND_SUPERVISOR="$(ip route | awk '/default / { print $3 }'):$SOUND_SUPERVISOR_PORT"
# Wait for sound supervisor to start
while ! curl --silent --output /dev/null "$SOUND_SUPERVISOR/ping"; do sleep 5; echo "Waiting for sound supervisor to start at $SOUND_SUPERVISOR"; done

# Get mode from sound supervisor. 
# mode: default to MULTI_ROOM
MODE=$(curl --silent "$SOUND_SUPERVISOR/mode" || true)

# Multi-room server can't run properly in some platforms because of resource constraints, so we disable them
declare -A blacklisted=(
  ["raspberry-pi"]=0
  ["raspberry-pi2"]=1
)

if [[ -n "${blacklisted[$BALENA_DEVICE_TYPE]}" ]]; then
  echo "Multi-room server blacklisted for $BALENA_DEVICE_TYPE. Exiting..."

  if [[ "$MODE" == "MULTI_ROOM" ]]; then
    echo "Multi-room has been disabled on this device type due to performance constraints."
    echo "You should use this device in 'MULTI_ROOM_CLIENT' mode if you have other devices running balenaSound, or 'STANDALONE' mode if this is your only device."
  fi
  exit 0
fi

# Start snapserver
if [[ "$MODE" == "MULTI_ROOM" ]]; then
  echo "Starting multi-room server..."
  
  # Configure audio quality settings with defaults
  AUDIO_SAMPLE_RATE=${AUDIO_SAMPLE_RATE:-48000}
  AUDIO_BIT_DEPTH=${AUDIO_BIT_DEPTH:-24}
  
  echo "Multi-room Audio Quality Settings:"
  echo "  Sample Rate: ${AUDIO_SAMPLE_RATE}Hz"
  echo "  Bit Depth: ${AUDIO_BIT_DEPTH}-bit"
  
  # Update snapserver configuration with current audio settings
  sed -i "s/%AUDIO_SAMPLE_RATE%/$AUDIO_SAMPLE_RATE/g" /etc/snapserver.conf
  sed -i "s/%AUDIO_BIT_DEPTH%/$AUDIO_BIT_DEPTH/g" /etc/snapserver.conf
  
  # Wait for PulseAudio to be ready (critical for snapserver to work)
  echo "Waiting for PulseAudio at tcp://audio:4317..."
  retries=0
  while [ $retries -lt 60 ]; do
    # Try to connect to PulseAudio port
    if timeout 1 bash -c "echo > /dev/tcp/audio/4317" 2>/dev/null; then
      echo "PulseAudio is ready!"
      break
    fi
    retries=$((retries + 1))
    echo "Waiting for PulseAudio... ($retries/60)"
    sleep 2
  done
  
  if [ $retries -eq 60 ]; then
    echo "WARNING: PulseAudio may not be ready, but continuing anyway..."
  fi
  
  # Give PulseAudio a moment to fully stabilize
  sleep 3
  
  # Main restart loop
  while true; do 
    /usr/bin/snapserver &
    sleep 21600 
    echo "Stopping multi-room server to eliminate lag..."
    pkill -f "snapserver"
    echo "Starting multi-room server..."
  done
else
  echo "Multi-room server disabled. Exiting..."
  exit 0
fi


# while true; do 
#   sleep 21600 
#   echo "Stopping multi-room server to eliminate lag..."
#   pkill -f "snapserver"
#   echo "Starting multi-room server..."
#   /usr/bin/snapserver  &
# done
