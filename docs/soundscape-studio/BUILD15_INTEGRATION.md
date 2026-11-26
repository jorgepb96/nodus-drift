# Coherent compositions and playback handoff · 0.2.0 (15)

The build 12 screenshots showed an umbrella and flames over a car dashboard.
Audio sources had been translated into sprites/effects without checking the host
scene. The tester also reported AVFAudio -10867 when opening a Studio starter
while a simple mix was already playing, and requested a landscape shortcut beside
the mini player's play/pause button.

## Composition contract

`StudioVisualPolicy` gates visual elements for the selected environment. It runs
when interpreting a mix, when the director builds a scene, and when any scene is
rendered, including saved/imported build 12 documents. It changes visual
representation, preserving audio layers, IDs, volumes and manual audio editing.

- Cars have exterior weather and windshield effects; no foreground object sprites.
- Only the calibrated cabin hearth receives flames, heat, firelight and embers.
  The shader independently enforces this invariant for malformed snapshots.
- Underwater scenes have compatible aquatic subjects/bubbles, without rain,
  airborne wind, fire, livestock or household appliances.
- Perched wildlife without a calibrated photographic perch stays off-screen.
  Terrestrial and aquatic subjects require the corresponding habitat.
- Tabletop items use two non-overlapping surface slots in a study/cafe. Laundry
  appliances use the utility-room floor. Unsupported wall/ceiling mounts,
  free-floating umbrellas and inappropriate props stay off-screen.
- Actors keep their physical source-image anchors and scale. A viewport crop may
  leave an actor outside the shot; it never relocates it onto another surface.
  The GPU actor count is the post-crop count, including the zero-actor case.
- Silent sources do not decide the automatically chosen mix setting. Active sounds
  without a supported literal depiction remain audible; controls explain them as
  off-screen ambience. The clean immersive view remains free of panels and labels.

This is a bounded composition system. An arbitrary six-sound request can be
acoustically creative without requiring every sound to become a visible object.
The pair audit checks all 3,916 catalogue pairs against the shared invariants; it
is not a claim that every possible six-sound mix was individually viewed.

## Playback and mini player

The six-sound mix → Studio starter → mix sequence reproduced the reported -10867
on the iOS 27.1 simulator. Apple's SDK identifies it as
`kAudioUnitErr_Uninitialized`. A stopped stereo graph could retain converter/bus
state across ownership changes. The shared service now rebuilds its core graph at
transport boundaries after detaching old voices, invalidates old preparation
revisions, edits graph inputs while paused, and initializes new inputs before
starting their players. Runtime layer automation keeps the existing graph and
streams; a graph rebuild is not performed on every timeline tick.

The mini player now observes which source owns audio. Its text, transport and
picture-frame action refer to that mix or Studio scene. Studio immersion is
presented by the root container so the shortcut also works from Sounds and Saved.
The simple mix's picture button explicitly chooses Your landscape; Nodi remains
available from the meditation appearance control.

Reference contracts: [AVAudioEngine graph editing](https://developer.apple.com/documentation/avfaudio/avaudioengine),
[uninitialized audio unit](https://developer.apple.com/documentation/audiotoolbox/kaudiouniterr_uninitialized),
and [configuration changes](https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/avaudioengineconfigurationchange).

## Validation

`Build13AudioGraphReset.xcresult` passed all three iOS 27.1 targeted audio tests:
all starters, six-sound mix handoff to each starter and back, and six concurrent
spatial sources with rerouting. A retained summary is stored beside this document.
Final regression, visual evidence and private delivery are recorded in
`docs/TESTFLIGHT.md`. No new physical iPhone tests were requested or performed.

The final iPhone/iOS 26.5 regression ran 47 tests: 45 passed, two AI simulator
probes were skipped, and none failed. It includes all 45 unit tests and both new
mini-player UI flows. The current iOS 27.1 validation executed 17 test bodies
without failure, including the same 3,916-pair audit and all three audio handoff
checks. Its runner finalization is recorded separately if the supplied runtime
fails to produce a complete result bundle.

Native screenshots were inspected for the exact six-source car conflict recipe
(rain on car, rain on umbrella, campfire, wipers, wind in trees, gravel footsteps)
and the new mini-player button. They are stored in `screenshots/studio/build13/`.

## Next marketing version

App Store Connect confirms 0.1.0 is READY_FOR_SALE / READY_FOR_DISTRIBUTION. At the
user's request the delivery is 0.2.0 (15). The preliminary 0.1.1 (14) was
uploaded but never assigned to testers; the user clarified the marketing version
while Apple was processing it. Only version/build settings differ from the tested
build 14 application source. The
provisional 0.1.0 (13) upload was stopped during preparation and was never assigned
to testers. The final mini-player condition also keeps a paused Studio scene
available when the simple mix is empty. `Build14PausedMiniPlayer.xcresult` passed
that complete pause → landscape → resume UI flow without a failure.
