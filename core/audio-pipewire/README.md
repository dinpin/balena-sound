# PipeWire Audio Container for balena-sound

This container provides a PipeWire-based audio server with full PulseAudio compatibility for balena-sound.

## Features

- **PipeWire Core**: Modern audio server with low latency and efficient resource usage
- **PulseAudio Compatibility**: Full compatibility layer allowing existing plugins to work without modification
- **WirePlumber**: Session and policy manager for automatic audio routing
- **Virtual Sinks**: Maintains the same audio routing architecture as the original PulseAudio implementation
  - `balena-sound.input`: Default sink for all audio plugins
  - `balena-sound.output`: Routes to hardware audio output
  - `snapcast`: For multiroom audio support

## Architecture

The PipeWire implementation maintains full compatibility with the existing balena-sound architecture:

1. **Audio Plugins** (Spotify, AirPlay, Bluetooth, etc.) connect via PulseAudio protocol on port 4317
2. **Virtual Sinks** handle audio routing based on the configured mode
3. **WirePlumber** manages the audio graph and routing policies
4. **PipeWire-Pulse** provides the PulseAudio compatibility layer

## Configuration

### Environment Variables

- `SOUND_MODE`: Audio mode (STANDALONE, MULTI_ROOM, MULTI_ROOM_CLIENT)
- `SOUND_INPUT_LATENCY`: Input routing latency in milliseconds (default: 200)
- `SOUND_OUTPUT_LATENCY`: Output routing latency in milliseconds (default: 200)
- `SOUND_ENABLE_SOUNDCARD_INPUT`: Enable hardware audio input routing

### Audio Routing

The routing logic follows the same pattern as the original PulseAudio implementation:

- **STANDALONE/MULTI_ROOM_CLIENT**: Routes `balena-sound.input` → `balena-sound.output` → hardware
- **MULTI_ROOM**: Routes `balena-sound.input` → `snapcast` → multiroom server

## Files

- `Dockerfile.template`: Container image definition
- `pipewire.conf`: Main PipeWire configuration
- `pipewire-pulse.conf`: PulseAudio compatibility layer configuration
- `balena-sound.conf`: Virtual sinks and balena-sound specific configuration
- `wireplumber.conf`: WirePlumber session manager configuration
- `start.sh`: Startup script with routing logic

## Benefits over PulseAudio

1. **Lower Latency**: PipeWire provides better latency handling
2. **Better Resource Usage**: More efficient CPU and memory usage
3. **Modern Architecture**: Graph-based audio routing
4. **Future-Proof**: Active development and better hardware support
5. **Compatibility**: Maintains full backward compatibility with PulseAudio clients

## Testing

To test the PipeWire implementation:

1. Build the container: `docker-compose build audio`
2. Start the services: `docker-compose up`
3. Verify PulseAudio compatibility: The plugins should connect normally on port 4317
4. Test audio playback through various plugins (Spotify, AirPlay, etc.)

## Troubleshooting

### Check PipeWire Status
```bash
docker exec -it balena-sound_audio_1 pw-cli info all
```

### Check PulseAudio Compatibility
```bash
docker exec -it balena-sound_audio_1 pactl info
```

### View Audio Graph
```bash
docker exec -it balena-sound_audio_1 pw-dot
```

### Monitor Audio Streams
```bash
docker exec -it balena-sound_audio_1 pw-top
```

## Migration from PulseAudio

The PipeWire container is a drop-in replacement for the PulseAudio container. Simply update the `docker-compose.yml` to use `./core/audio-pipewire` instead of `./core/audio`.
