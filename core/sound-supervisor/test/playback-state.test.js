const assert = require('assert')
const {
  activePlaybackStreams,
  getPlaybackState,
  onPlaybackStreamChanged,
  onPlaybackStreamRemoved,
  onPlaybackStreamsChanged,
  subscribePlaybackState
} = require('../build/PlaybackState')

assert.strictEqual(getPlaybackState(), null)
const updates = []
const unsubscribe = subscribePlaybackState((playing) => updates.push(playing))

// Snapshot includes persistent loopbacks and a paused (corked) Spotify stream.
onPlaybackStreamsChanged([
  { index: 0, driverName: 'module-loopback.c', unknown4: false },
  { index: 3, driverName: 'protocol-native.c', unknown4: true }
])
assert.strictEqual(getPlaybackState(), false)
assert.strictEqual(activePlaybackStreams.size, 0)

// An un-corked app stream counts; a loopback never counts as playback.
onPlaybackStreamChanged({ index: 4, driverName: 'protocol-native.c', unknown4: false })
onPlaybackStreamChanged({ index: 5, driverName: 'module-loopback.c', unknown4: false })
assert.strictEqual(getPlaybackState(), true)
assert.deepStrictEqual(Array.from(activePlaybackStreams), [4])

// Corking or removing the final app stream returns to not playing.
onPlaybackStreamChanged({ index: 4, driverName: 'protocol-native.c', unknown4: true })
assert.strictEqual(getPlaybackState(), false)
onPlaybackStreamChanged({ index: 6, driverName: 'protocol-native.c', unknown4: false })
onPlaybackStreamRemoved(6)
assert.strictEqual(getPlaybackState(), false)
assert.deepStrictEqual(updates, [false, true, false, true, false])

unsubscribe()
assert.strictEqual(activePlaybackStreams.size, 0)
onPlaybackStreamsChanged([])
assert.strictEqual(getPlaybackState(), false)
console.log('Playback state tests passed')
