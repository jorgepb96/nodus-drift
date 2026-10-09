# App Store preparation

## Product

- Name: Nodus Drift
- Bundle ID: `com.drakonis96.nodusdrift`
- Language: English
- Devices: iPhone and iPad; iOS 17+
- Price: Free; all features included
- In-app purchases/subscriptions/advertising: None
- Login: None; no demo account needed
- Category suggestion: Lifestyle
- Privacy: No data collected; tracking disabled
- Privacy policy source: `ios/NodusDrift/Resources/Legal/PRIVACY.md`
- Background mode: Audio, for user-initiated ambient playback
- Required-reason API: app-only UserDefaults, CA92.1, declared in PrivacyInfo.xcprivacy

## Saved draft description and media

On October 9, 2026, the English (US) description and promotional text were saved
to the App Store draft, initially version 1.0 and corrected to 0.1.0. Exact text is in
[APP_STORE_DESCRIPTION.txt](APP_STORE_DESCRIPTION.txt) and
[APP_STORE_PROMOTIONAL_TEXT.txt](APP_STORE_PROMOTIONAL_TEXT.txt).

Six actual screenshots were uploaded for each of the medium Dynamic Island
iPhone, large Dynamic Island iPhone and 13-inch iPad. The draft remains Prepare
for Submission, with no build attached or App Store review submitted. See
[TESTFLIGHT_METADATA.md](TESTFLIGHT_METADATA.md) for the upload record.

## Proposed review notes

This is a standalone native SwiftUI ambient sound mixer. It needs no account, network
connection, companion desktop app or purchase. Select any sound in Sounds to start
playback, or load a starter mix and press Play in My mix. Up to six voices may play
at once. One binaural preset may be selected at a time; use stereo headphones to
hear separated tones. All 81 newly produced loops are included in the app bundle; the eight native generators work on device.

My mix provides volume controls, saved mixes and a sleep timer. The expand icon
opens meditation mode. Controls hide after five seconds; tap anywhere to reveal
controls and open Nodi's eyes. The X leaves meditation mode. VoiceOver keeps the
controls visible and supplies an escape action. Reduce Motion stops the breathing
animation. Audio background mode is used only for deliberate playback. Unplugging
headphones or an audio interruption pauses playback. No medical effects are claimed.

## Before public App Store distribution

1. Complete the release rights review in LICENSING.md. Attach any rights documentation
   Apple needs; do not equate free pricing with cleared distribution.
   The original recording-provenance gap was resolved by the replacement bank;
   AUDIO_REPLACEMENT_2026-10-09.md records its individual CC0 sources and notices.
   The owner selected MIT for the iOS implementation from build 7; public source publication is not required by MIT. Third-party notices remain bundled.
2. Select the developer's team, verify the bundle ID, and configure distribution signing.
3. Run the app on a physical iPhone: headphones/Bluetooth routes, phone interruptions,
   locked-screen playback, timer completion, VoiceOver, energy usage and sleep/wake.
4. Confirm iPad multitasking, landscape and accessibility sizes on intended devices.
5. The Drift-specific policy is hosted at https://nodusresearch.com/drift/privacy/
   and saved in App Store Connect, with the main Nodus issue tracker as support URL.
   Complete the current age-rating questionnaire accurately.
6. Archive the Release scheme, validate the signed archive and upload using Xcode.
7. Set the price to Free, attach the real screenshots, and submit for Apple's review.

The previous internal-only build 1.0.0 (1) was signed, uploaded and assigned to the
account holder in TestFlight. The current source version is 0.1.0, build 7. See
TESTFLIGHT.md for the actual distribution evidence.
Public rights clearance, device validation and App Store approval remain separate.
No public App Store review submission was performed. The separate external TestFlight beta is tracked in TESTFLIGHT.md.
