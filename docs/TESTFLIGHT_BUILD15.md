# TestFlight private preview · 0.2.0 (15)

**Build 15 is available for private internal testing**, verified at
2026-11-13T22:17:58.868177+01:00 (Europe/Madrid). Apple reports `VALID`, `INTERNAL_ONLY` and
`IN_BETA_TESTING`. Open TestFlight with the existing internal invitation and
update to **0.2.0 (15)**.

- App: Nodus Drift (`com.drakonis96.nodusdrift`, App Store ID `6820753637`).
- Version/build: **0.2.0 (15)**.
- Upload/build ID: `ba8e3361-ca54-4f93-88bc-15edccd4db30`.
- CLI upload completed: 2026-11-13T22:14:19+01:00 (Europe/Madrid).
- Export uses `testFlightInternalTestingOnly: true`; no external distribution requested.
- Assigned group: **Jorge — beta interna** (the only group with access).
- External build state: `NOT_APPLICABLE`; no external review or production submission.
- [Open build in App Store Connect](https://appstoreconnect.apple.com/teams/36804ede-f0b5-4cd2-a273-c619feb6168f/apps/6820753637/testflight/ios/ba8e3361-ca54-4f93-88bc-15edccd4db30).
- English **What to Test** notes: [build 15 notes](TESTFLIGHT_NOTES_BUILD15.txt), saved as `en-US` and read back from Apple with an exact match.

## Included changes

Visual composition now checks the setting, animal habitat and calibrated surfaces.
Car rain plus umbrella rain plus campfire keeps the audio but shows a coherent car
view with exterior weather and windshield effects. Fire is restricted to the cabin
hearth. Unsupported props remain off-screen; expanded controls explain the audible
sources without adding panels to the clean immersive view. The same policy protects
older drafts, imported scenes, manually edited scenes and director output.

A new picture-frame button beside play/pause opens the active landscape directly.
The mini player follows the actual audio owner and remains accessible for a paused
Studio scene even when the simple mix is empty. A stopped audio graph is rebuilt
at playback boundaries, fixing the reproduced -10867 when switching from a playing
six-sound mix to each Studio starter and back.

The existing 22 photographic settings, native animated weather, Your landscape /
Nodi choice, top-left immersive branding and matched Nodi sizes remain included.

## Verified package and evidence

The signed 0.2.0 (15) archive contains all 89 catalogue entries and 81 recordings
verified by size/SHA-256, 22 JPEG backgrounds, two transparent PNG atlases and
sprite metadata (17,562,388 artwork bytes), native landscape and MLX Metal
libraries, legal notices and no model weights. Its source fingerprint covers 178
application/runtime files, including working-tree changes; it does not imply that
those changes are in Git HEAD.

- [Delivery receipt](rights/release15.json).
- [Signed archive verification](rights/release15-archive-verification.json).
- [Exact source fingerprint](rights/release15-source.json).
- [English What to Test notes](TESTFLIGHT_NOTES_BUILD15.txt).
- [Composition and audio integration](soundscape-studio/BUILD15_INTEGRATION.md).
- [Corrected car composition](../screenshots/studio/build13/car-conflicting-mix.png).
- [Mini-player landscape shortcut](../screenshots/studio/build13/mini-player-landscape.png).
- [Artwork provenance](soundscape-studio/LANDSCAPE_ASSETS.json).

The final iPhone/iOS 26.5 simulator regression ran 47 tests: 45 passed, two AI
simulator probes were skipped, and none failed. This includes all 45 unit tests
and both new mini-player UI flows. A separate final UI test passed the paused
Studio scene → landscape → resume flow with no simple mix selected.

The composition audit covers all 3,916 catalogue pairs, the 22 background policies,
legacy documents, shader fire isolation and portrait/wide/Duo crop invariants. It
is not a claim that every possible six-sound combination was individually viewed.
The exact six-source car recipe and mini-player screenshots were visually inspected.

On iOS 27.1 Duo, 17 test bodies passed, including the audio handoff and composition
checks. Xcode stalled during runner finalization, so this is console evidence,
not a completed result bundle. An earlier isolated run completed all three audio
tests successfully. See the retained summaries in `docs/soundscape-studio/`.
No new physical iPhone tests or battery measurements were performed, per user
instruction. Existing generation/platform limits remain in
[FEASIBILITY.md](soundscape-studio/FEASIBILITY.md).

Only version/build settings differ from the tested build 14 application source;
the signed archive is verified again for 0.2.0 (15).

## Version and distribution history

App Store Connect confirmed that 0.1.0 is already READY_FOR_SALE /
READY_FOR_DISTRIBUTION. This beta therefore increments the marketing version to
0.2.0, as requested. The provisional 0.1.0 (13) upload was stopped during
preparation and was never assigned to testers; its record is retained in
[release13.json](rights/release13.json). The preliminary 0.1.1 (14) upload was not assigned to testers after the user
clarified the requested marketing version during Apple processing. Its record is
retained in [release14.json](rights/release14.json). The previous private build 12 delivery
is preserved in [TESTFLIGHT_BUILD12.md](TESTFLIGHT_BUILD12.md).

## Reproduce

The project uses `MARKETING_VERSION: 0.2.0` and `CURRENT_PROJECT_VERSION: '15'`.
Regenerate with XcodeGen, archive Release for generic iOS with the existing signing
team, verify the signed package, and export with
`ios/ExportOptions-TestFlight.plist`. Internal-only export is enabled and automatic
build renumbering is disabled. A subsequent upload needs a new build number.
Archives, upload logs and credentials are not stored in Git.
