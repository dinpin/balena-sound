/** Current local playback state, populated by PulseAudio events. */
export const activeAudioSinks = new Set<string>()
export let playbackStateKnown = false

export function onSinkPlaybackStarted(name: string): void {
  activeAudioSinks.add(name)
  playbackStateKnown = true
}

export function onSinkPlaybackStopped(name: string): void {
  activeAudioSinks.delete(name)
  playbackStateKnown = true
}
