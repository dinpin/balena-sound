/** PulseAudio corked sink inputs are paused; loopback streams are audio routing. */
export interface PlaybackStream {
  index: number
  driverName?: string
  unknown4?: boolean
}

export const activePlaybackStreams = new Set<number>()
let playbackStateKnown = false

const playbackStateListeners = new Set<(playing: boolean | null) => void>()

export function getPlaybackState(): boolean | null {
  return playbackStateKnown ? activePlaybackStreams.size > 0 : null
}

export function subscribePlaybackState(
  listener: (playing: boolean | null) => void
): () => void {
  playbackStateListeners.add(listener)
  return () => playbackStateListeners.delete(listener)
}

function notifyPlaybackState(previousState: boolean | null): void {
  const currentState = getPlaybackState()
  if (currentState !== previousState) {
    playbackStateListeners.forEach((listener) => listener(currentState))
  }
}

function isPlaybackActive(stream: PlaybackStream): boolean {
  return stream.driverName !== 'module-loopback.c' && stream.unknown4 !== true
}

export function onPlaybackStreamsChanged(streams: PlaybackStream[]): void {
  const previousState = getPlaybackState()
  activePlaybackStreams.clear()
  streams.forEach((stream) => {
    if (isPlaybackActive(stream)) {
      activePlaybackStreams.add(stream.index)
    }
  })
  playbackStateKnown = true
  notifyPlaybackState(previousState)
}

export function onPlaybackStreamChanged(stream: PlaybackStream): void {
  const previousState = getPlaybackState()
  if (isPlaybackActive(stream)) {
    activePlaybackStreams.add(stream.index)
  } else {
    activePlaybackStreams.delete(stream.index)
  }
  playbackStateKnown = true
  notifyPlaybackState(previousState)
}

export function onPlaybackStreamRemoved(index: number): void {
  const previousState = getPlaybackState()
  activePlaybackStreams.delete(index)
  playbackStateKnown = true
  notifyPlaybackState(previousState)
}
