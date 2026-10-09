# Distribution rights — version 0.1.0 (7)

**The owner chose MIT for Nodus Drift for iOS and requested a public TestFlight beta.** The native implementation and the owner's incorporated DRIFT contributions are MIT licensed from build 7. The development repository remains private; MIT does not require public corresponding source. This decision does not change the main Nodus repository's license, revoke earlier AGPL grants, or relicense third-party material.

## First-party license decision

The owner previously stated “Yo soy el propietario de Nodus” and, when offered a public source route for AGPL, chose “y si hacemos nodus drift MIT y ya? y asi no subimos el codigo”. The decision is applied to this iOS app, including the owner's incorporated DRIFT contributions, under the full [MIT notice](../LICENSE). The [build 7 record](rights/MIT_DECISION_BUILD7.json) identifies the scope, hashes, evidence and retained notices.

The 14 upstream commits affecting the incorporated Nodi, N mark, DRIFT components and shared catalogue/state are attributed to Drakonis96 or Jorge Pérez Burgueño. The inspected commit bodies declare an AI coauthor, with no other human coauthor. The eight runtime Swift files are native adaptations produced in the owner's workspace. They import Apple platform frameworks and have no bundled third-party code package dependencies. The original Nodi geometry/animation and connected N are additionally byte-identical to the historical Nodus v3.2.7 MIT material; that notice remains bundled. Moodist's catalogue data retains its separate MIT notice.

The [MIT text](https://opensource.org/license/mit) requires retaining copyright and permission notices and does not require publishing source. The [GNU licensing FAQ](https://www.gnu.org/licenses/gpl-faq.en.html#ReleaseUnderGPLAndNF) explains that a copyright holder can grant different non-exclusive licenses to their own code. This review relies on the owner's ownership statement and scoped authorship evidence; it does not infer that owning a repository alone grants rights in unrelated third-party code. No third-party AGPL-only portion was identified in this app's incorporated scope.

The earlier [Apple additional-permission draft](rights/APPLE_PERMISSION_DRAFT.md) remains **unsigned and unadopted**. It is not used as a grant. The prior native AGPL text is preserved in [the historical record](rights/NODUS_DRIFT_PREBUILD7_AGPL.txt) and Git history. Existing recipients retain previously granted rights.

## Audio and catalogue

All **81 original Moodist MP3s were replaced** in build 6. Eighty current file options derive from **77 individually documented CC0 originals**, and the radio-tuning option is original Nodus synthesis. The catalogue remains exactly **89 options**, including eight unchanged native generators. No Pixabay or unidentified Moodist recording remains bundled. Source permissions and processing records are documented in the [replacement report](AUDIO_REPLACEMENT_2026-10-09.md), [source register](rights/replacement-audio/source-register.csv) and bundled Settings notices.

| Material | Basis retained in the app |
| --- | --- |
| Native iOS code and owner's incorporated DRIFT contributions | Nodus Drift MIT notice |
| Original Nodi and N | Historical Nodus MIT notice |
| Moodist catalogue data | MIT, © 2023 MAZE; does not license Moodist recordings |
| 80 current CC0-based audio options | Individual CC0 source IDs, authors, source URLs and license record; original permissions unaffected by edits |
| Original radio loop and eight native generators | First-party sound design/code; no third-party broadcasts or binaural recordings |
| FSD50K compilation | CC BY 4.0 notice, curator/paper attribution and processing changes |
| Four Clotho source clips | Individual CC0 basis; captions and Clotho code not incorporated |

CC0 records the applicable copyright permissions rather than giving an absolute warranty of title. The historical [original-bank audit](RIGHTS_AUDIT_2026-10-09.md) and [source investigation](AUDIO_SOURCE_INVESTIGATION_2026-10-09.md) remain unchanged records of the removed material in builds 1–5. No Moodist author query was sent.

## Public beta

The owner expressly requested the new external TestFlight beta and join link. Build 7 is exported without the internal-only restriction. Apple must review the first external build before external installation; this is distinct from publishing the app on the App Store. Current submission and link evidence belongs in [TESTFLIGHT.md](TESTFLIGHT.md).
