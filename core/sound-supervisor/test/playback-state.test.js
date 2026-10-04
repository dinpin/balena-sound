const assert = require('assert')
const {
  activeAudioSinks,
  getPlaybackState,
  onSinkPlaybackStarted,
  onSinkPlaybackStopped,
  subscribePlaybackState
} = require('../build/PlaybackState')

assert.strictEqual(getPlaybackState(), null)
const updates = []
const unsubscribe = subscribePlaybackState((playing) => updates.push(playing))

onSinkPlaybackStarted('spotify-output')
onSinkPlaybackStarted('spotify-output')
assert.strictEqual(getPlaybackState(), true)
onSinkPlaybackStarted('airplay-output')
onSinkPlaybackStopped('spotify-output')
assert.strictEqual(getPlaybackState(), true)
onSinkPlaybackStopped('airplay-output')
assert.strictEqual(getPlaybackState(), false)
assert.deepStrictEqual(updates, [true, false])

unsubscribe()
assert.strictEqual(activeAudioSinks.size, 0)
console.log('Playback state tests passed')
