# TestFlight private preview · 0.1.0 (10)

**Build 10 is available for private internal testing**, verified at
2026-11-07T07:36:48.818234+01:00 (Europe/Madrid). Apple reports `VALID`, `INTERNAL_ONLY` and
`IN_BETA_TESTING`. Open TestFlight with the existing internal invitation and
update to **0.1.0 (10)**.

- App: Nodus Drift (`com.drakonis96.nodusdrift`, App Store ID `6820753637`).
- Version/build: **0.1.0 (10)**.
- Upload ID: `8749105a-8883-41ba-b1c1-d0509f288c55`.
- Upload completed: 2026-11-07T07:33:08+01:00 (Europe/Madrid).
- Export uses `testFlightInternalTestingOnly: true`; no external distribution requested.
- Assigned group: **Jorge — beta interna** (the only group with access).
- External build state: `NOT_APPLICABLE`; no external review or production submission.
- [Open build in App Store Connect](https://appstoreconnect.apple.com/teams/36804ede-f0b5-4cd2-a273-c619feb6168f/apps/6820753637/testflight/ios/8749105a-8883-41ba-b1c1-d0509f288c55).
- English **What to Test** notes: [build 10 notes](TESTFLIGHT_NOTES_BUILD10.txt), saved as `en-US` and read back from Apple with an exact match.

The signed archive contains all 89 catalogue entries, all 81 recordings verified
by size/SHA-256, seven 1024 × 1536 photographic-style landscape JPEGs (5,194,496
bytes), native landscape and MLX Metal libraries, legal notices and no model
weights. The source fingerprint covers 158 current application/runtime files,
including working-tree changes; it does not imply those changes are in Git HEAD.

## Evidence

- [Delivery receipt](rights/release10.json).
- [Signed archive verification](rights/release10-archive-verification.json).
- [Exact source fingerprint](rights/release10-source.json).
- [Landscape rendering and screenshots](soundscape-studio/LANDSCAPES.md).
- [Validation](soundscape-studio/VALIDATION.md).

Seven final simulator tests passed. The cabin was additionally inspected in an
isolated iPad Air simulator. No new physical iPhone tests were performed, per the
user's instruction. Earlier inference and hardware-validation limits remain in
[FEASIBILITY.md](soundscape-studio/FEASIBILITY.md).

Build 9's completed private-delivery record is preserved in
[TESTFLIGHT_BUILD9.md](TESTFLIGHT_BUILD9.md); build 8's earlier public-beta record
remains in [TESTFLIGHT_BUILD8.md](TESTFLIGHT_BUILD8.md).

## Reproduce

The project uses `CURRENT_PROJECT_VERSION: '10'`. Regenerate with XcodeGen,
archive Release for generic iOS with the existing signing team, verify the signed
package, and export with `ios/ExportOptions-TestFlight.plist`. It explicitly sets
`testFlightInternalTestingOnly` to `true` and disables automatic build renumbering.
A subsequent upload needs a new build number. Archives, upload logs and credentials
are not stored in Git; the linked receipts contain no credentials. Existing
public-beta access was not changed.
