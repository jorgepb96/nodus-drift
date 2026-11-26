# Meditation, animation and consistency · build 12

The tester reported a crash opening the first cabin starter in build 10, static
fire/rain, missing mix visuals in meditation, an absent N logo on a tab and a
larger Nodi on the second tab. Physical iPhone tests remain deferred at the user's
request. App Store Connect initially returned no crash feedback. A later read-only
copy of the existing system crash log identified the abort in AVAudioPlayerNode
startup on iOS 27.2; its app UUID matches build 10's archived dSYM. No app was
launched or tested on the iPhone. See BUILD10_CRASH_ANALYSIS.json; the raw report
remains only in the ignored local build directory.

## Changes

- Selected sounds are interpreted as a local composition across 22 environments,
  with 16 animal sprites, supported object sprites and 14 procedural effects.
  Snow footsteps plus wolf has both tracks and wolf; car rain plus wipers has the
  car interior and moving windshield effects. Your landscape / Nodi stays editable
  in My mix and meditation. No second audio engine or runtime image service is used.
- Immersive screens default to just the small N / Nodus Drift brand at top left,
  without gray header, legend or persistent pause pill. Tap reveals controls and
  Hide controls restores the clean landscape. Gesture handling stays behind buttons.
- Studio previews and immersive modes no longer require audio playback to animate.
  Users can pause visuals independently. Low Power Mode lowers frame rate instead
  of freezing; Reduce Motion still stops motion. A paused draft previews beyond
  the silent fade-in at t=0. Rain contrast and subpixel coverage are increased.
- Metal drawing mode changes are applied only when needed. The drawable size cap
  is explicit, and GPU command-buffer errors suspend the renderer and reveal the
  native still instead of continuing failed work.
- Audio sources connect through explicit unused input buses. Spatial source
  mixers convert to the environment's output sample rate, rather than assuming
  each recording matches it. On iOS 27, the throwing connection API allows graph
  errors to reach the existing error UI; partial attachments are cleaned up.
  These remain defensive improvements; the report does not include the exact
  invalid graph condition.
- Player startup now checks attachment and output connections, restarts an engine
  that stopped during asynchronous preparation, and uses throwing `playAudio()` on
  iOS 27+. Failed sources are detached and reported through the existing UI. This
  replaces the legacy startup path that the symbolicated crash identifies.
- A shared brand header restores the N mark in Studio and all other tabs retain
  the same header. A shared 185-point Nodi canvas makes the first and second tab
  use the same drawing scale; it also keeps other empty states consistent.

## Regression evidence

`StarterCrashReproduction.xcresult` ran all three real starter scenes before the
defensive audio changes: one test passed on iOS 26.5, with no crash. This does not
reproduce the user's physical iPhone environment.

`MeditationMotionValidation.xcresult` ran 37 tests: 34 passed, two were skipped for
the already documented simulator AI limitations, and one UI test failed because
two appearance pickers shared an accessibility identifier. Separate identifiers
were added. `MeditationChoiceFinal.xcresult` then passed that complete UI test,
including real rain/campfire playback, Cabin meditation, independent visual pause,
switching to Nodi and restoring the chosen appearance after relaunch.

The native-window test counts completed GPU frames during repeated host updates,
then verifies the clock freezes on pause and resumes after reattachment. Separate
offscreen tests isolate fire in the photographed hearth and falling rain with no
water, foliage, stars or fog to mask static effects.

`IOS27CabinAndBrandValidation.xcresult` passed all nine targeted unit tests,
including real starter playback through the iOS 27 connection API and completed
onscreen GPU frames. Its two UI tests failed at the tab-bar locator: the supplied
Duo runtime exposes different control types and no matching TabBar. These are
not counted as passing UI validation. The tab-brand test is rerun on the normal
iPhone 17 Pro / iOS 26.5 profile in `BrandFinalValidation.xcresult`.

The delivery receipt is recorded in `docs/TESTFLIGHT.md`. A separate simulator
is used because the installed iOS 27.1
runtime supports only its supplied iPhone Duo profile; this is runtime coverage,
not a physical iPhone 16 Pro Max measurement.

Reference contracts: [MetalKit drawing modes](https://developer.apple.com/documentation/metalkit/mtkview),
plus the installed Apple SDK's AVAudioEngine.h connection API and
AVAudioEnvironmentNode.h nextAvailableInputBus contracts.

## Final crash-path follow-up

Build 11 had finished uploading when the existing device crash report was located.
It was not assigned to any testing group. Build 12 supersedes it with the player
startup correction. English notes are in `docs/TESTFLIGHT_NOTES_BUILD12.txt`.

`CabinCrashFixValidation.xcresult` specifically exercises iOS 27's new startup API,
an unattached player that must return an error without aborting, an engine stopped
between source preparation and playback, and all three real starter scenes.
Final regression and delivery results are recorded in `docs/TESTFLIGHT.md`.

## Orientation investigation

The app declares both landscape orientations on iPhone and all four on iPad. The
native window geometry probe confirms the application mask is 26, root mask 30,
and a supported landscape request resizes the real window successfully on iOS
26.5. Device Hub/XCTest sensor rotation left the window portrait in three attempts
(and on Duo), despite rotation lock being off; those attempts are retained as
failures rather than passing orientation coverage. Immersive controls now also
provide a native Rotate immersive view action, available only when controls are
shown. It requests geometry on the foreground scene and preserves the clean
surface when hidden. iOS 17–25 uses the compatible coordinate-space API.

Reference: [Apple's supported orientation contract](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/application(_:supportedinterfaceorientationsfor:)).
Duo layout uses the available window size, following [Apple's adaptation guidance](https://developer-mdn.apple.com/videos/play/tech-talks/111461/).

## Signed archive

The final build 12 archive was regenerated after adaptive artwork and clean UI
changes. Verification checks 89 catalogue records, 81 recording hashes, all 24
artwork hashes/dimensions and atlas alpha, sprite-region metadata, privacy and
legal texts, both Metal libraries, no bundled model weights, supported landscape
orientations, signing validity, internal-only export policy and the exact 178-file
application/runtime snapshot. The earlier pre-adaptive build 12 archive was
renamed and was never uploaded.

The last isolated appearance-control run, `MeditationControlsVerified.xcresult`,
passed after the harness refreshed the controls timer following its screenshot.
There were no additional release-app changes after the 178-file fingerprint.
The build 12 export completed successfully at 2026-11-07 13:04:17 Europe/Madrid;
final Apple processing and group/English-note verification are recorded separately
in `docs/TESTFLIGHT.md` and `docs/rights/release12.json`.
