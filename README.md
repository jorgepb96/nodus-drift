# Nodus Drift for iOS

The quiet corner of [Nodus](https://github.com/jorgepb96/nodus), rebuilt with
SwiftUI, AVAudioEngine and native iOS controls. English only. iPhone and iPad,
iOS 17 and later. Free, with no accounts, advertisements, subscriptions or purchases.

## Run

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
python3 scripts/prepare_audio.py
xcodegen generate --spec ios/project.yml
open ios/NodusDrift.xcodeproj
```

Select the NodusDrift scheme and an iPhone or iPad simulator. For a physical device,
select your own development team in Signing & Capabilities. No API keys or server
are needed. Recordings are downloaded only during preparation; the app works offline.

## Experience

| Desktop Drift capability | Native iOS implementation |
| --- | --- |
| Full catalogue | Same 89 options, names, categories and frequencies; newly produced licensed loops |
| Six simultaneous sounds | Shared selection rule; one binaural preset at a time |
| Individual and master volume | Native sliders, 150 ms gain ramps and output peak limiter |
| Seamless loops | New licensed loops stream from disk with 200 ms circular PCM seams |
| Noise | Independent stereo white, Voss–McCartney pink and leaky-integrator brown noise |
| Binaural | 100 Hz carrier; Delta 2, Theta 5, Alpha 10, Beta 20, Gamma 40 Hz |
| Favorites and search | Local favorites, accent-insensitive search, nine category filters |
| Sort | Recommended, alphabetical, by type, most used; also for saved mixes |
| Presets | Up to 48 saved mixes; names, icons, sounds and all volumes; edit/delete |
| Restore | Local settings persist; restored and loaded mixes always start paused |
| Meditating Nodi | Native vector lotus pose, pearl limbs, internal mesh and six-second breath |
| Full screen | Black meditation scene, tap to wake, gaze toward touch, rest after 2.5 s |
| Mobile additions | Starter mixes, sleep timer, haptics, background playback, lock-screen controls |
| Accessibility | VoiceOver labels and actions, Reduce Motion, adaptive grids, native controls |

There is no React, Electron, web view, audio service or third-party runtime dependency.
Nodi is drawn with SwiftUI Canvas from the original vector geometry.
The original connected N identifies the in-app headers; Nodi remains the app icon.

## Tests

```sh
xcodebuild -project ios/NodusDrift.xcodeproj -scheme NodusDrift \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

The tests check the entire audio catalogue, file hashes and decoding, circular seams,
noise characteristics, binaural frequencies, memory limits, state recovery, saved mixes,
selection policy, playback cancellation and the main UI flows. UI tests attach real
simulator screenshots. See [docs/VALIDATION.md](docs/VALIDATION.md) for recorded results.

For silent interaction checks, run only `NodusDriftUITests/DriftSilentUITests`
with `-only-testing:NodusDriftUITests/DriftSilentUITests`. These tests launch
the Debug app with an audio guard and never press Play. The build 4 iPhone and
iPad runs each passed both interaction tests. The build 5 Saved parity regression
also passes on both devices, including saving and loading while paused.

## Source and rights

The current app version is **0.1.0**, with build number **6**.
It is Testing in the account holder's existing private internal TestFlight group.
All 81 old audio files have been replaced; no public beta was created.
The previous upload, 1.0.0 (1), remains in the release history.
See [docs/TESTFLIGHT.md](docs/TESTFLIGHT.md) for installation and release evidence.

Reference: `jorgepb96/nodus` at `68fa0210dc8407938d644978291840d85aeb49b1`.
Catalogue reference: `remvze/moodist` at `11c0be2200116a3635880d600fd6953899cc51a3`.
Audio: 80 new CC0-based loops and one original Nodus radio loop; see
[the replacement report](docs/AUDIO_REPLACEMENT_2026-10-09.md).

Adapted native code retains AGPL-3.0-only. The historical MIT notice for the original
Nodi geometry/animation and connected N is also included. Moodist catalogue data
retains its MIT notice. The original Moodist audio bank has been completely replaced.
CC0 source permissions, FSD50K attribution and new Nodus sound design are
recorded in the [81-option source register](docs/rights/replacement-audio/source-register.csv).
Audio assets remain excluded from Git and are reproducible with the checked-in
recipes. Preparation never fetches the removed Moodist recordings.

Install Python dependencies with `python3 -m pip install -r scripts/requirements-audio.txt`
and use FFmpeg 8.0.1 with libmp3lame. `prepare_audio.py` validates complete release
hashes before installing reconstructed assets. `audit_audio_bank.py` checks all
81 replacements, per-file weights and the unchanged 89-option catalogue.

This is an owner-only internal beta. Public distribution and recipient source access
remain a separate release step; see [docs/LICENSING.md](docs/LICENSING.md).
