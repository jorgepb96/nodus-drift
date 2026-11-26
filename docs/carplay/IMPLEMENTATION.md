# CarPlay Audio · static artwork browser

The vehicle experience is a native audio browser with static photographic covers.
It offers Home (Continue and recent selections), My mixes (saved simple mixes and
Studio scenes) and Explore (three starter mixes and three evolving Studio scenes).
Selecting an available cover starts playback and opens the system Now Playing
screen after an audio voice is ready. Connecting never starts playback.

On iOS 26+, `CPListImageRowItemImageGridElement` provides rounded rectangular
artwork and titles in multi-line system grids. Rows are chunked using the system's
image limit so the full 48-mix/96-scene library remains addressable. iOS 17.4–25
uses the titled image-row API; iOS 17.0–17.3 uses labelled thumbnail list items.
CarPlay decides the final column count, cropping and placement. These are content
grids, not a custom SwiftUI/Metal interface or a fullscreen photograph.

## Architecture

- `DriftSession` owns one DriftStore, one StudioStore and their shared audio engine.
  Either the phone or the CarPlay scene can initialize it first. The SwiftUI root
  receives the shared StudioStore instead of constructing a second one.
- `DriftCarPlayLibrary` resolves stable item identifiers against the current
  library. Deleted items cannot replay stale captured objects. Persistent recent
  history holds at most 12 identifiers; drafts are accessible through Continue.
- `DriftArtwork` downsamples bundled wide photographs on a utility task and
  creates square static covers. An in-flight map coalesces duplicate requests;
  the cache is capped at 12 MiB/48 entries, and individual covers at 768 pixels.
  No Metal view, effect, animal/object atlas or generated image is used.
- `DriftPlaybackMetadata` publishes the actual mix/scene title and artwork through
  MediaPlayer. Finite Studio scenes publish their duration and elapsed position;
  repeating scenes and open-ended mixes omit a fixed duration. Canceled
  cover loads cannot replace the current scene's cover.
- `DriftCarPlayBrowser` retains native tab/list templates, refreshes their sections
  as the shared library changes, and completes every selection handler. Failed
  or missing recordings are handled on CarPlay without asking for iPhone input.
  A selection spinner completes when a voice is ready, with a bounded timeout.
- Playback uses the existing pause/resume commands, including the steering-wheel
  remote interface. Unsupported seek/track controls are disabled. No queue or
  automatic next-track behavior is advertised. Temporary interruptions resume
  only when playback was active and the system supplies `shouldResume`.

Studio editing, prompts, generation, model downloads, account setup and immersive
visuals are outside the CarPlay interface. The existing phone editor remains.
CarPlay supports a separate scene in the manifest; the phone and vehicle share
state through the MainActor and never create independent audio transports.

## Signing and activation

CarPlay Audio was enabled for Drift in the Apple Developer portal on 2026-11-26.
The existing team already held the managed capability (Reader has signed CarPlay
profiles); no new entitlement request or agreement was needed. After saving the
App ID change and reopening its configuration, **CarPlay Audio App (CarPlay
framework)** was checked and Save was disabled, confirming the persisted setting.
The App Store Connect capabilities endpoint did not list this managed capability,
so its earlier response was not treated as proof that account approval was absent.

The app's default signing configuration now uses
`ios/NodusDrift/CarPlay.entitlements`; `ios/Config/CarPlay.xcconfig` also records
this setting explicitly. The entitlement is
`com.apple.developer.carplay-audio`. No navigation, video, Dashboard navigation
or instrument-cluster capability is requested. Provisioning profiles must carry
the same entitlement. Adding the key to a file alone would not establish signing
or runtime eligibility. The signed-build result is recorded in `VALIDATION.md`.

Enabling a capability invalidates existing profiles for future signing; profiles
must be regenerated. This change was confirmed in the portal. No other app's
identifier or capability was modified. TestFlight availability, if delivered,
is recorded separately in `../TESTFLIGHT.md`.

## Validation scope

Focused tests cover full-library grid labels and limits, stable recent IDs,
deleted/edited items, missing generated recordings, all 22 bounded static covers,
the shared transport, real simulator playback and Now Playing metadata. Final
results and remaining validation are recorded in `VALIDATION.md`.

No physical iPhone or vehicle tests are performed, per the user's instruction.
Actual template rendering on vehicle screens, light/dark appearances, rotary
input, locked-phone playback and vehicle/navigation interruptions still require
CarPlay validation. Constructing templates in an app unit test is not proof of
approved entitlement, vehicle integration or App Review acceptance.

## Apple references

- [CarPlay design](https://developer.apple.com/design/human-interface-guidelines/carplay)
- [Image row grids](https://developer.apple.com/documentation/carplay/cplistimagerowitem)
- [Grid elements](https://developer.apple.com/documentation/carplay/cplistimagerowitemimagegridelement)
- [Scene configuration](https://developer.apple.com/documentation/carplay/building-your-apps-initial-carplay-interface)
- [Entitlements and signing](https://developer.apple.com/documentation/carplay/preparing-your-ios-app-for-carplay-development)
- [Now Playing](https://developer.apple.com/documentation/carplay/cpnowplayingtemplate)
