# TestFlight private preview · 0.1.0 (12)

**Build 12 is available for private internal testing**, verified at
2026-11-07T13:08:36.434682+01:00 (Europe/Madrid). Apple reports `VALID`, `INTERNAL_ONLY` and
`IN_BETA_TESTING`. Open TestFlight with the existing internal invitation and
update to **0.1.0 (12)**.

- App: Nodus Drift (`com.drakonis96.nodusdrift`, App Store ID `6820753637`).
- Version/build: **0.1.0 (12)**.
- Upload/build ID: `f44f8e65-c56c-4a42-81b7-173ffd0f5687`.
- CLI upload completed: 2026-11-07T13:04:17+01:00 (Europe/Madrid).
- Export uses `testFlightInternalTestingOnly: true`; no external distribution requested.
- Assigned group: **Jorge — beta interna** (the only group with access).
- External build state: `NOT_APPLICABLE`; no external review or production submission.
- [Open build in App Store Connect](https://appstoreconnect.apple.com/teams/36804ede-f0b5-4cd2-a273-c619feb6168f/apps/6820753637/testflight/ios/f44f8e65-c56c-4a42-81b7-173ffd0f5687).
- English **What to Test** notes: [build 12 notes](TESTFLIGHT_NOTES_BUILD12.txt), saved as `en-US` and read back from Apple with an exact match.

## Included changes

Personalized meditation combines selected sounds with 22 bundled photographic
settings, animal/object atlases and native weather/effects. Snow footsteps plus
wolf includes tracks and a wolf; car rain plus wipers uses a car interior with
animated windshield effects. Your landscape / Nodi remains selectable and its
preference persists. The default immersive view keeps only the small N / Nodus
Drift brand at top left; tap reveals controls and Hide controls clears them.
Rain and flames animate independently of audio. Branding appears on all five tabs
and the first two tabs share the same 185-point Nodi drawing scale.

The audio startup path symbolicated from the existing build 10 cabin report now
validates connections, recovers an engine stopped during asynchronous preparation
and uses iOS 27's throwing player API. No physical iPhone retest was performed.
See [crash analysis](soundscape-studio/BUILD10_CRASH_ANALYSIS.json).

## Verified package and evidence

The signed archive contains all 89 catalogue entries and all 81 recordings verified
by size/SHA-256, 22 JPEG backgrounds, two transparent PNG atlases and sprite metadata
(17,562,388 artwork bytes), native landscape and MLX Metal libraries, legal notices
and no model weights. Its exact source fingerprint covers 178 application/runtime
files including working-tree changes; this does not imply those changes are in Git HEAD.

- [Delivery receipt](rights/release12.json).
- [Signed archive verification](rights/release12-archive-verification.json).
- [Exact source fingerprint](rights/release12-source.json).
- [Artwork prompts and provenance](soundscape-studio/LANDSCAPE_ASSETS.json).
- [Expanded Duo snow composition](../screenshots/studio/adaptive/duo-open-snow.png).
- [Expanded Duo car/rain/wipers](../screenshots/studio/adaptive/duo-open-car.png).
- [Validation and limits](soundscape-studio/VALIDATION.md).

All 41 unit tests ran on the iPhone simulator: 39 passed and two AI probes were
skipped for documented simulator limitations. The same regression passed tab
branding, personalized portrait/horizontal mixes and all three real Studio starter
playback/immersion flows. Its appearance UI test timed out after controls auto-hid;
[the isolated final run](soundscape-studio/MeditationControlsVerified-summary.json)
then passed real audio with independent visual pause, switching to Nodi and choice
persistence after relaunch. App-region screenshot cropping and UI keyboard events
were unreliable on the supplied runtimes; failed harness attempts are documented.

Ten rendering/composition tests also passed on iOS 27.1 Duo. Its programmatic
orientation probe was skipped because UIKit rejects it in the expanded resizable
windowing mode. The snow and car fixtures were inspected on the actual expanded
simulator display at 2853 × 2007. Catalogue UI automation on Duo did not pass, so
this is not full Duo editing-flow certification. The iPhone window accepts native
landscape requests; immersive controls include an explicit rotation action for
fixed phone windows. These are simulator checks; no new physical iPhone tests or
battery measurements were performed, per user instruction. Existing inference
limits remain in [FEASIBILITY.md](soundscape-studio/FEASIBILITY.md).

Build 11 was superseded before distribution when the existing crash report was
located; its record remains in [release11.json](rights/release11.json). The earlier
pre-adaptive build 12 archive was never uploaded. Completed build 10 delivery is
preserved in [TESTFLIGHT_BUILD10.md](TESTFLIGHT_BUILD10.md); earlier records remain
in [TESTFLIGHT_BUILD9.md](TESTFLIGHT_BUILD9.md) and [TESTFLIGHT_BUILD8.md](TESTFLIGHT_BUILD8.md).

## Reproduce

The project uses `CURRENT_PROJECT_VERSION: '12'`. Regenerate with XcodeGen, archive
Release for generic iOS with the existing signing team, verify the signed package,
and export with `ios/ExportOptions-TestFlight.plist`. Internal-only export is
explicitly enabled and automatic build renumbering is disabled. A subsequent
upload needs a new build number. Archives, upload logs and credentials are not
stored in Git. Existing public-beta access was not changed.
