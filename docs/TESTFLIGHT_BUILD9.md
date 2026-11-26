# TestFlight private preview · 0.1.0 (9)

**Build 9 is available for internal testing**, verified on 2026-11-07T00:26:13.890879+01:00 (Europe/Madrid).
Apple reports `VALID`, `INTERNAL_ONLY`, and `IN_BETA_TESTING`.

- App: Nodus Drift (`com.drakonis96.nodusdrift`, App Store ID `6820753637`).
- Version/build: **0.1.0 (9)**.
- Internal group: **Jorge — beta interna** (`40f2ec9c-cccb-4c2d-b3ce-ce073515bc77`).
- Build ID: `f8c28659-c4c0-454e-ad94-1322d699c67e`.
- [Open the build in App Store Connect](https://appstoreconnect.apple.com/teams/36804ede-f0b5-4cd2-a273-c619feb6168f/apps/6820753637/testflight/ios/f8c28659-c4c0-454e-ad94-1322d699c67e).
- English **What to Test** notes were saved as `en-US` and read back from Apple to verify the exact text: [build 9 notes](TESTFLIGHT_NOTES_BUILD9.txt).

Open TestFlight using the existing internal invitation and update to **0.1.0 (9)**.
The build belongs only to the internal group. Apple marks its external state
`NOT_APPLICABLE`; no external review or production submission was created.
Existing public-beta builds and their tester access were left unchanged.

## Contents

Soundscape Studio adds up to 12 layers, timeline keyframes, spatial positioning,
natural random events, scene documents, procedural landscapes, optional Stable
Audio generation, and on-device Apple scene direction. The existing catalogue,
simple mixer, saved mixes, favorites, timer and Nodi remain.

The signed archive contains all 89 catalogue entries and all 81 recordings,
verified by size and SHA-256, plus the required legal notices and MLX Metal
library. Optional model weights are not bundled. The 146-file source fingerprint
includes the current Studio working-tree changes; it does not claim they are
represented by the previous Git HEAD commit.

## Evidence

- [Delivery receipt](rights/release9.json).
- [Signed archive verification](rights/release9-archive-verification.json).
- [Exact source fingerprint](rights/release9-source.json).
- [Studio validation and limits](soundscape-studio/VALIDATION.md).
- [Reader-based feasibility](soundscape-studio/FEASIBILITY.md).

The user explicitly deferred further physical-device tests. No device installation
or new physical audio test was performed for this upload. Model downloads and
new audio generation can now be evaluated through this private build.

## Reproduce

The project uses `CURRENT_PROJECT_VERSION: '9'`. Regenerate with XcodeGen, archive
Release for generic iOS with the existing team, verify the signed package, and
export with **ios/ExportOptions-TestFlight.plist**, which sets
`testFlightInternalTestingOnly` to `true` and disables automatic build renumbering.
Use a new build number for another upload. Archives, upload logs and credentials
are not stored in Git. Distribution metadata and receipts contain no credentials.

## Earlier public beta

The previous record is preserved in [TESTFLIGHT_BUILD8.md](TESTFLIGHT_BUILD8.md).
Build 8 was observed as `IN_BETA_TESTING` externally before this private upload;
its original October review record remains historical.
