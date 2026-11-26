# TestFlight private preview · 0.2.0 (16)

**Build 16 is available for private internal testing**, verified at
2026-11-24T15:36:46.894915+01:00 (Europe/Madrid). Apple reports `VALID`, `INTERNAL_ONLY` and
`IN_BETA_TESTING`. Open TestFlight with the existing internal invitation and
update to **0.2.0 (16)**.

- App: Nodus Drift (`com.drakonis96.nodusdrift`, App Store ID `6820753637`).
- Version/build: **0.2.0 (16)**.
- Upload/build ID: `7d0ce55e-a8bf-4152-9126-bcc1f71b427a`.
- CLI upload completed: 2026-11-24T15:30:01+01:00 (Europe/Madrid).
- Assigned group: **Jorge — beta interna**, the only group with access.
- Audience: `INTERNAL_ONLY`; external state: `NOT_APPLICABLE`.
- English **What to Test** notes were saved as `en-US` and read back with an exact match.
- [Open build in App Store Connect](https://appstoreconnect.apple.com/teams/36804ede-f0b5-4cd2-a273-c619feb6168f/apps/6820753637/testflight/ios/7d0ce55e-a8bf-4152-9126-bcc1f71b427a).

## Included changes

Every environment has a new dedicated horizontal photographic composition.
The 22 original portrait plates and 22 new wide plates are bundled offline.
Artwork follows actual viewport bounds, including landscape phone windows,
4:3 tablets and resizable windows, with proportional cropping. New horizontal
interior glass bounds and the cabin hearth are calibrated separately. A still
photograph stays visible until a replacement Metal frame completes, and texture
revision checks discard stale orientation loads. Paused scenes also redraw after
resizing. Caches and GPU resolution remain bounded.

The main setting and animated atmosphere are visible without decorative animal
or object cutouts. Existing sounds continue to play; dormant artwork, placement
recipes and saved actor data are preserved. Unused atlases are not loaded into GPU
memory. Nodi and Your landscape remain selectable using explicit buttons. One
landscape surface survives mode changes and pauses behind Nodi. Controls remain
stable after selection and the wake gesture is separate from visible buttons.

## Verification

The signed archive contains 89 catalogue entries, all 81 recordings verified by
size/SHA-256, 44 photographic JPEG plates, two retained transparent PNG atlases and
sprite metadata. Artwork totals 31,046,523 bytes. Landscape and MLX Metal libraries,
legal notices and the privacy manifest are present; no model weights are bundled.
The exact source fingerprint covers 200 application/runtime files including
uncommitted working-tree changes, and does not imply the changes are in Git HEAD.

- [Delivery receipt](rights/release16.json).
- [Archive verification](rights/release16-archive-verification.json).
- [Exact source fingerprint](rights/release16-source.json).
- [English What to Test notes](TESTFLIGHT_NOTES_BUILD16.txt).
- [Integration and validation](soundscape-studio/BUILD16_HORIZONTAL_LANDSCAPES.md).
- [New horizontal images and complete prompt set](soundscape-studio/LANDSCAPE_WIDE_ASSETS.json).
- [Original artwork provenance](soundscape-studio/LANDSCAPE_ASSETS.json).
- [Native horizontal cabin screenshot](../screenshots/studio/build16/cabin-wide.png).
- [Native horizontal car screenshot](../screenshots/studio/build16/car-wide.png).

All 17 rendering test bodies passed on the iOS 26.5 simulator: all 22 wide textures,
real GPU animation, old scene protection, portrait/wide selection, resizing while
paused and surface retention behind Nodi. Two final UI tests passed in a completed
result bundle: repeated appearance switches with real audio, and the dedicated
horizontal cabin/car fixtures. The earlier personalized snow/car portrait-to-wide
flow also passed. Final screenshots were visually inspected.

Initial attempts included a cold-start timing assertion and a selection tap made
after the five-second controls timer had hidden the UI. Before/after screenshots
confirmed that the tap was revealing controls rather than changing appearance.
The final tests wait for the first frames and reveal controls before selecting.
The resumed rendering run stalled at Xcode finalization after the unit suites
passed, so that part is retained as console evidence; the final two UI tests have
a complete result bundle. See the linked integration document and summaries.

The Duo fixture launched in a portrait window, which was inspected; expanded Duo
editing-flow certification is not claimed. Wide, tablet and Duo-style viewport
selection is covered by rendering tests. No physical iPhone tests or battery
measurements were repeated, per user instruction. Existing inference limits remain
in [FEASIBILITY.md](soundscape-studio/FEASIBILITY.md).

## Version and distribution

The marketing version remains 0.2.0 and the new build number is 16. Previous private
build 15 is preserved in [TESTFLIGHT_BUILD15.md](TESTFLIGHT_BUILD15.md). No public
App Store submission or external beta review is part of this delivery. The public
beta group's access is unchanged.

## Reproduce

The project uses `MARKETING_VERSION: 0.2.0` and `CURRENT_PROJECT_VERSION: '16'`.
Archive Release for generic iOS with the existing signing team, verify the package
and export using `ios/ExportOptions-TestFlight.plist`. Internal-only export is
explicitly enabled; automatic build renumbering is disabled. A future upload needs
a new build number. Archives, upload logs and credentials are not stored in Git.
