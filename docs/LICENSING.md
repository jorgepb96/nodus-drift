# Distribution rights: current status

Fresh audit: October 9, 2026. **The release is not yet cleared for public App Store
distribution.** See the [full audit](RIGHTS_AUDIT_2026-10-09.md) for evidence,
limits and decisions needed to close it.

| Material / obligation | Verified evidence | Closure status |
| --- | --- | --- |
| Original Nodi geometry/animation and connected N | Three source files byte-identical to published Nodus v3.2.7 MIT; notice added to app resources and Settings | Historical MIT route documented and notice prepared for next build |
| September DRIFT material and native adaptation | 14 scoped upstream commits attributed to Drakonis96 / Jorge; matching GitHub identity; verified CLA acceptance | First-party Apple license route available; explicit release license decision not yet recorded |
| Moodist catalogue data | Pinned MIT license and bundled notice | Notice retained; no audio rights inferred from MIT |
| 81 original recordings | All bytes, SHA-256 digests and upstream Git blobs match; metadata/history recorded | **0/81 individual original sources or licenses verified**; obtain evidence/permission or replace unresolved recordings |
| Native noise/binaural generators | Local synthesis; no upstream recordings used | No third-party recording clearance needed; project code license applies |
| Corresponding Source | In-app URL points to a private, empty repository | Provide exact release source and build instructions to recipients under the chosen license |
| Apple terms | Current public texts checked; account free-app agreement Active through Aug 31, 2027 | Signed account agreement text / EULA must be reconciled with the release license before external distribution |

AGPL is not treated here as a blanket App Store prohibition. The fresh audit replaces
the earlier broad compatibility warning with a scoped ownership and licensing analysis.
Historical MIT permissions do not cover later DRIFT additions; the CLA does not
retrospectively cover earlier merged contributions or third-party audio.

Evidence and reviewable next steps:

- [First-party material and hashes](rights/first-party-material.json)
- [Verified CLA record and identity](rights/cla-evidence.json)
- [Historical Nodus MIT notice](rights/NODUS-HISTORICAL-MIT.txt)
- [81-recording table](rights/audio-recordings.csv) and [detailed evidence](rights/audio-recordings.json)
- [Unsigned first-party Apple permission draft](rights/APPLE_PERMISSION_DRAFT.md)
- [Unsent requests for original sources and use-specific permission](rights/PERMISSION_REQUESTS_DRAFT.md)

The historical desktop Legal/REVIEW.md and PROVENANCE.md remain unchanged. Their
September 29 decision concerns desktop Nodus, not a new iOS grant. Record a new
release decision against exact files and evidence.

No third-party permission was obtained by this audit. No grant, public release,
source publication or new external beta distribution was made. The existing internal
TestFlight build is separate from public clearance; Apple's processing is not a
copyright authorization.
