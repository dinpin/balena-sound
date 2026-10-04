/** Current local playback state, populated by PulseAudio events. */
export const activeAudioSinks = new Set<string>()
export let playbackStateKnown = false

const playbackStateListeners = new Set<(playing: boolean | null) => void>()

export function getPlaybackState(): boolean | null {
  return playbackStateKnown ? activeAudioSinks.size > 0 : null
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

export function onSinkPlaybackStarted(name: string): void {
  const previousState = getPlaybackState()
  activeAudioSinks.add(name)
  playbackStateKnown = true
  notifyPlaybackState(previousState)
}

export function onSinkPlaybackStopped(name: string): void {
  const previousState = getPlaybackState()
  activeAudioSinks.delete(name)
  playbackStateKnown = true
  notifyPlaybackState(previousState)
}
