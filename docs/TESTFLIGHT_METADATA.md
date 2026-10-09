# TestFlight and store metadata update

Saved through the integrated browser on October 9, 2026, in English (US), for
Nodus Drift, App Store ID 6820753637.

## Saved text

- [Beta description](TESTFLIGHT_DESCRIPTION.txt), saved under Test Information.
- [What to Test](TESTFLIGHT_NOTES.txt), saved for the current build 0.1.0 (5).
- [Product description](APP_STORE_DESCRIPTION.txt), saved in App Store draft 0.1.0.
- [Promotional text](APP_STORE_PROMOTIONAL_TEXT.txt), saved in the same draft.

The text covers the offline sound library, six-layer mixing, saved mixes, sleep
timer, background playback, Nodi's dark meditation scene and tap interaction,
native iPhone/iPad layouts, accessibility, free pricing and English availability.
Test instructions ask testers to check these features on their own devices.

## Uploaded screenshots

| Gallery | Native dimensions | Accepted screenshots |
| --- | --- | --- |
| iPhone with Dynamic Island, medium | 1206 × 2622 | 6 of 10 |
| iPhone with Dynamic Island, large | 1320 × 2868 | 6 of 10 |
| iPad, 13-inch | 2064 × 2752 | 6 of 10 |

All galleries use this order: home, mixer, saved mixes, Nodi resting with hidden
controls, Nodi awake after a tap, rain library with selected sound layers. See
[original media](../screenshots/app-store/README.md). Each PNG is an actual native
simulator screenshot with no visual edits. The large iPhone and 13-inch iPad
capture flow each passed; the earlier medium iPhone capture set was reused.
Exact file dimensions and SHA-256 hashes are recorded in
[TESTFLIGHT_METADATA.json](TESTFLIGHT_METADATA.json).

## Visible state and limits

App Store Connect displays six accepted screenshot slots in each gallery. The
store draft remains Prepare for Submission; no build was attached and no App Store review
submission was performed. The subsequent version correction uploaded internal
beta 0.1.0 (2), followed by interaction builds 0.1.0 (3) and 0.1.0 (4); see TESTFLIGHT.md.

The existing Show approved screenshots and category TestFlight setting is enabled.
[Apple documents that TestFlight takes its screenshots from the latest approved
Ready for Distribution App Store version](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/).
Nodus Drift does not yet have an approved version, so these draft screenshots
cannot appear in the current TestFlight listing. The saved beta description and
What to Test instructions are independent of that screenshot requirement.

## Browser evidence

- [Beta description](../screenshots/15-testflight-description.jpg)
- [What to Test](../screenshots/16-testflight-testing-notes.jpg)
- [Medium iPhone](../screenshots/17-app-store-iphone-screenshots.jpg)
- [13-inch iPad](../screenshots/18-app-store-ipad-screenshots.jpg)
- [Large iPhone](../screenshots/19-app-store-iphone-large-screenshots.jpg)
- [Product text and gallery with page context](../screenshots/20-app-store-metadata-proof.jpg)

The browser captures document the saved web forms; they were not uploaded as app
screenshots. Rights clearance remains as recorded in LICENSING.md; saving this
metadata does not provide any additional copyright permissions.

## Subsequent version correction

The user set the current version to 0.1.0. The App Store draft was saved with
that exact value and kept its descriptions and all uploaded media. Build 0.1.0
(2) was archived, uploaded, processed and assigned to the existing internal
beta group. Its updated instructions were saved in English. The original 1.0.0
(1) instructions are preserved in TESTFLIGHT_NOTES_BUILD1.txt; the earlier browser
captures document the initial state rather than the current version.

- [Draft version 0.1.0](../screenshots/21-app-store-version-0.1.0.jpg)
- [Current internal build](../screenshots/22-testflight-0.1.0-active.jpg)
- [Current build instructions](../screenshots/23-testflight-0.1.0-notes.jpg)


## Interaction update — build 4

0.1.0 (4) keeps the app version and adds full-card touch targets, stable library
filters, equal-width Settings cards, the requested Nodus/Moodist destinations,
justified native license paragraphs and a centered Nodi icon. The English notes
are in TESTFLIGHT_NOTES.txt; earlier notes remain in TESTFLIGHT_NOTES_BUILD2.txt
and TESTFLIGHT_NOTES_BUILD3.txt.
Build 4 also keeps short filtered results visible below the fixed controls
after scrolling deeply. The App Store policy URL is https://nodusresearch.com/drift/privacy/, with
https://github.com/jorgepb96/nodus/issues for support and
https://nodusresearch.com/ for marketing. The policy page is live after Nodus
PR #1079 and successful Website workflow 37903966692.


## Saved layout parity — build 5

0.1.0 (5) gives Saved the mixer's page margins, heading scale, empty-state Nodi
and full-width action. Saved cards now have the mixer's width and at least its
standard card height, with larger metadata and icons and Dynamic Type titles.
The focused silent test passed on iPhone 17 Pro Max and iPad Pro 13-inch (M5).
Saving and loading restores the selected sounds while remaining paused.
New captures 36–39 and their silent-ipad equivalents are saved in the repository;
the earlier App Store draft galleries retain their original uploaded contents.
The current build's English notes are in TESTFLIGHT_NOTES.txt; build 4's notes
remain in TESTFLIGHT_NOTES_BUILD4.txt. No playback test was performed.
