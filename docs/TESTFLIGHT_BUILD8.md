# TestFlight beta · 0.1.0 (8)

**0.1.0 (8) is Testing in the existing internal group and Waiting for Review for the public beta.** The signed archive was uploaded successfully on October 9, 2026 at **16:05:51 Europe/Madrid**, processed by Apple and assigned to both groups. The replacement external TestFlight review has been submitted with automatic tester notification enabled. **Public joining and installation are not yet available**: App Store Connect explicitly says the group needs an approved build before testers can join the public link.

The beta will become available after Apple's approval; this record does not claim it has been approved.

- Public group: **Nodus Drift — Public Beta**
- Public link: https://testflight.apple.com/join/kAXnsjJS
- External group ID: `4dcab8a9-bef4-4ff4-bb70-7118cb375068`
- Existing internal group: **Jorge — beta interna**
- Version and build: **0.1.0 (8)**
- Internal-only export: **false**, using ios/ExportOptions-PublicBeta.plist
- [Build 8](https://appstoreconnect.apple.com/teams/36804ede-f0b5-4cd2-a273-c619feb6168f/apps/6820753637/testflight/ios/7905ec5e-d60e-4912-a79d-57371cc4cdca)
- [Public group](https://appstoreconnect.apple.com/teams/36804ede-f0b5-4cd2-a273-c619feb6168f/apps/6820753637/testflight/groups/4dcab8a9-bef4-4ff4-bb70-7118cb375068/builds)
- [Internal Testing proof](../screenshots/73-testflight-build8-private.jpg)
- [External Waiting for Review proof](../screenshots/74-testflight-build8-public-review.jpg)
- [Enabled link and approval requirement](../screenshots/65-testflight-public-link-awaiting-approval.jpg)

## Install and share

The owner can update now through the existing internal TestFlight invitation and select **0.1.0 (8)**. Physical iPhone installation of build 8 has not been verified. Builds 5, 6 and 7 remain available for comparison.

Share https://testflight.apple.com/join/kAXnsjJS once the first external build has been approved. The link is enabled and open to everyone under Apple's standard tester maximum; no device-specific criteria or custom lower tester cap were set. No recipient email addresses were uploaded, and there are currently no external testers.

## Changes and validation

After deeply scrolling through Sounds, choosing Favorites shows the first favorite or the empty-state explanation below the persistent search and filters. Categories, search and sorting also return to their first results, including when a new filter matches the same IDs. Card dimensions and search focus are preserved. Sounds, My mix, Saved and Settings still return to the top when selected, retaining search/filter state. Clear remains immediate and preserves favorites and saved mixes.

The owner selected MIT from build 7 for the iOS implementation and incorporated first-party DRIFT material. The repository stays private; MIT requires retained notices rather than publishing source. Third-party Moodist MIT, CC0 source and FSD50K compilation notices remain bundled. See [LICENSING.md](LICENSING.md).

The same 89 options and build 6 replacement audio bank remain unchanged. Eight focused silent UI checks passed across iPhone and iPad; simulator captures 66–72 and 76 record the fixed behavior. Physical-device verification remains for the owner. The signed archive receipt is [release8-archive-verification.json](rights/release8-archive-verification.json), and the distribution receipt is [release8.json](rights/release8.json). English testing notes are in [TESTFLIGHT_NOTES.txt](TESTFLIGHT_NOTES.txt), review notes in [TESTFLIGHT_REVIEW_NOTES_BUILD8.txt](TESTFLIGHT_REVIEW_NOTES_BUILD8.txt), and silent checks in [VALIDATION.md](VALIDATION.md). No audio output or auditory test is performed.

## Reproduce the upload

Increase CURRENT_PROJECT_VERSION for each new upload, regenerate with XcodeGen, archive the Release scheme, verify the packaged version, catalogue, audio hashes, legal notices and signature, then export with **ExportOptions-PublicBeta.plist**. The previous ExportOptions-TestFlight.plist restricts uploads to internal testing and cannot enable an external beta.

Signed archives, source WAVs, MP3s, upload logs and signing credentials stay excluded from Git. English-only remains the shipped interface; the translation JSON is a draft.

## Privacy and App Store scope

The app-specific policy is https://nodusresearch.com/drift/privacy/ and is saved in the App Store draft. TestFlight’s own privacy URL was saved as https://nodusresearch.com/drift/privacy/ and its public Feedback Email was saved as **contact@nodusresearch.com**, per the owner’s instruction. The owner entered the private review-contact fields directly; those details are not saved in source or captures. [Public metadata proof](../screenshots/61-testflight-public-contact-privacy.jpg). The saved No Data Collected answer's final Apple accuracy/update declaration remains separate; this beta does not publish an App Store listing or accept that declaration. The existing App Store description and screenshots remain in the draft.

## Previous builds

[The build 7 record](TESTFLIGHT_BUILD7.md) preserves the earlier release and review submission; [build 6](TESTFLIGHT_BUILD6.md) preserves the replacement-audio release. The pending public review for build 7 was withdrawn before submitting build 8, so Apple reviews the corrected build. Build 7 remains in the public group as Ready to Submit and in the private group as Testing; it was not expired or deleted. Builds 5 and 6 also remain in the internal group.
