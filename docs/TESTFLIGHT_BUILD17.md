# TestFlight private preview · 0.2.0 (17)

**Build 17 is available for private internal testing**, verified at
2026-11-24T16:17:00.715575+01:00 (Europe/Madrid). Apple reports `VALID`, `INTERNAL_ONLY` and
`IN_BETA_TESTING`. Open TestFlight with the existing internal invitation and
update to **0.2.0 (17)**.

- App: Nodus Drift (`com.drakonis96.nodusdrift`, App Store ID `6820753637`).
- Upload/build ID: `90886da7-e07b-4283-aebe-6b287b45513f`.
- CLI upload completed: 2026-11-24T16:11:39+01:00 (Europe/Madrid).
- Assigned group: **Jorge — beta interna**, the only group with access.
- Audience: `INTERNAL_ONLY`; external state: `NOT_APPLICABLE`.
- English **What to Test** notes were saved as `en-US` and read back with an exact match.
- [Open build in App Store Connect](https://appstoreconnect.apple.com/teams/36804ede-f0b5-4cd2-a273-c619feb6168f/apps/6820753637/testflight/ios/90886da7-e07b-4283-aebe-6b287b45513f).

## Included correction

The landscape Sounds catalogue no longer reserves a portrait-sized pinned header.
Search, sorting and horizontal categories share one compact row and can scroll
away, leaving room for complete cards. Cards and the mini player use less padding
while keeping names readable and favorite, volume, playback and landscape actions
usable. Rotation preserves the mix, query and filters and brings a scrolled
library back to its results. Portrait proportions are retained.

Only DriftViews.swift and version/build settings differ from the build-16
application/runtime snapshot. All 22 dedicated horizontal landscape photographs,
main-photograph-plus-atmosphere presentation and existing sound features remain
included. Decorative cutout assets are retained but disabled.

## Verification

Two focused UI tests passed in a completed iOS 26.5 simulator result bundle:
a six-sound mix in landscape, filtering, full-card bounds and control hit targets,
opening the landscape from the mini player, and deep Favorites filtering in
portrait. Final native screenshots were visually inspected. No physical iPhone
tests were repeated, per user instruction.

The signed archive was verified against 200 source/runtime files. It contains
89 catalogue entries, all 81 recordings verified by size/SHA-256, 44 photographic
JPEG plates and two dormant PNG atlases, totaling 31,046,523 artwork bytes.
Both Metal libraries, notices and the privacy manifest are present; no model
weights are bundled. The source fingerprint includes uncommitted working-tree
changes and does not imply they are in Git HEAD.

- [Delivery receipt](rights/release17.json).
- [Archive verification](rights/release17-archive-verification.json).
- [Exact source fingerprint](rights/release17-source.json).
- [English What to Test notes](TESTFLIGHT_NOTES_BUILD17.txt).
- [Layout implementation and validation](soundscape-studio/BUILD17_LANDSCAPE_LIBRARY.md).
- [Completed UI test summary](soundscape-studio/Build17Layout-summary.json).
- [Horizontal library screenshot](../screenshots/studio/build17/landscape-library.png).
- [Landscape opened from the mini player](../screenshots/studio/build17/landscape-player.png).
- [Portrait Favorites screenshot](../screenshots/studio/build17/portrait-favorites.png).

Previous delivery and broader landscape-rendering evidence are preserved in
[TESTFLIGHT_BUILD16.md](TESTFLIGHT_BUILD16.md). Existing inference limitations
remain documented in [FEASIBILITY.md](soundscape-studio/FEASIBILITY.md).

## Version and distribution

Marketing version is 0.2.0 and build number is 17. The existing internal-only
export options explicitly disable automatic build renumbering. No App Store
submission or external beta review was made; public beta access is unchanged.
A future upload requires a new build number. Archives, logs and credentials are
not stored in Git.
