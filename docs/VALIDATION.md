# Validation record

## Build 7 · Tab navigation, immediate Clear and MIT notices (October 9, 2026)

All nine intended silent UI checks passed: four on iPhone 17 Pro Max and five on iPad Pro 13-inch (M5). Both devices verify deep scrolling and return-to-top behavior for all four tabs, retained search/category state, immediate Clear, preserved favorites/saved mixes, cancelled sleep timer and paused saved-mix loading. Card activation regions and stable filters remain correct. Settings widths and the loaded Nodus Drift MIT notice pass on both devices; Saved parity also passes on iPad.

The initial iPad Clear test stopped at a timer button whose reported hitability included an off-screen frame. The test now reveals the complete control before tapping; its focused repeat passed. A separate iPhone Settings run failed during simulator startup before the tab was present; repeating that focused check after the other simulator test ended passed. No production change was needed for those harness failures. All initial failure logs and result bundles remain in ignored .build; they are not omitted from this record.

No Play control was pressed. Debug UI launches use -ui-testing-silent, which blocks audio engine/session activation. No auditory or physical-device audio-route test was performed. The audio bank and catalogue were not regenerated: the signed Release archive contains the exact same 89 entries and 81 audio hashes as build 6. All 11 current legal files match the source, the bundled Nodus Drift notice is MIT, and the old AGPL app notice is absent. Archive version 0.1.0 (7), bundle ID and strict code signature verification pass. The archive receipt is rights/release7-archive-verification.json.

Captures 50–60 show the returned tab headings, cleared mix, iPad layout and MIT notices; capture 62 verifies the iPhone MIT disclosure. They were visually reviewed for alignment, card dimensions, usable controls and native paragraph wrapping. Captures using the scroll fixture include six paused voices and twelve dummy saved mixes only in Debug; fixture data is excluded from Release.

Result bundles: Silent7Phone (three passing checks), Silent7IPad (four passing checks and the initial Clear failure), Silent7IPadClear (passing focused repeat), Silent7PhoneMIT (startup failure) and Silent7PhoneMITRetry (passing Settings/MIT check). The public export uses ExportOptions-PublicBeta.plist with internal-only false; upload success is recorded separately in TESTFLIGHT.md.

## Build 6 · Replacement audio bank (October 9, 2026)

All 81 original Moodist MP3s were replaced; the 89 catalogue options and the
eight native generators are unchanged. The silent Python audit checks each
current asset hash, original source evidence, per-file weight, mono/stereo PCM,
44.1 kHz rate, finite samples, level headroom, DC and circular joins. Actual
byte changes range from −0.1377% to +0.4299%; total bytes change from
103,863,687 to 103,894,123. Post-codec maximum peak is −3.078 dBFS and lowest
loop RMS is −26.898 dBFS. See rights/replacement-audio/audit-summary.json.

Five focused iPhone unit tests passed, including decoding **every one of the 81**
files and comparing streaming seams with the whole-buffer algorithm. The four
silent UI tests passed on both iPhone 17 Pro Max and iPad Pro 13-inch (M5): card
hit areas/stable filters, Saved parity, Settings widths/Moodist license, and the
new Audio sources & permissions disclosure. **13/13 tests passed**, with no
failures. UI launches use `-ui-testing-silent`; no test presses Play, and no
audio engine/session is started. No other XCTest methods were run.

New legal credits were verified to load, including the 80/77 CC0 count, FSD50K
and Clotho notices, the Whale vocal-imitation disclosure and original radio
source. Actual captures were visually reviewed for page widths, controls and
justified legal text:

- screenshots/43-build6-iphone-sounds.png
- screenshots/44-build6-iphone-settings.png
- screenshots/45-build6-ipad-settings.png
- screenshots/46-build6-iphone-audio-credits.png
- screenshots/47-build6-ipad-audio-credits.png

The signed Release archive was checked to contain 0.1.0 (6), the exact current
catalogue, all 81 new audio hashes and eight current legal documents. Code
signing verification passed. The export configuration is internal testing only.
Results and complete logs are retained in ignored .build: AudioAudit6-iphone,
AudioAudit6-ipad, AudioCredits6-iphone and AudioCredits6-ipad xcresult bundles.

**No auditory quality test or physical-device audio-route test was performed.**
The owner will listen on the private iPhone beta. Technical silence is not a
claim that perceptual quality or every background/route scenario was checked.


Validated October 9, 2026 with Xcode 26.2 (17C52), SwiftUI and Apple SDKs.
Deployment target: iOS 17.0. No third-party runtime dependencies.

## Historical baseline automated evidence

The initial suite had twelve unit/integration tests and three UI tests. Final adaptive
checks wait for the actual landscape frame, rather than merely setting the simulated
device orientation. Screen captures use the physical screen to avoid app-region
cropping problems after iPad rotation.

Recorded local result bundles (excluded from Git):

| Result | Device / build | Outcome |
| --- | --- | --- |
| `FinalVerification.xcresult`, DriftTests | iPhone 17 Pro, iOS 26.3.1 | All 12 audio/state tests passed |
| `BrandedScreens.xcresult`, DriftUITests | iPhone 17 Pro, iOS 26.3.1 | All 3 interface tests passed with the original N mark |
| `SmallPhoneValidation.xcresult` | iPhone SE (3rd generation), iOS 18.2 | All 10 original audio/state tests and 3 interface tests passed |
| `BrandedSmallScreens.xcresult` | iPhone SE (3rd generation), iOS 18.2 | Final branded portrait, landscape and meditation layout passed |
| `BrandedTabletScreens.xcresult` | iPad mini (A17 Pro), iOS 26.3.1 | Final branded portrait, landscape and meditation layout passed |
| Release build | Generic arm64 iOS, Xcode 26.2 | Build succeeded with signing disabled |

The final 15 distinct tests passed in their latest runs. The screenshot flow was
re-run after correcting a test fixture that gave a saved mix the same accessibility
label as its starter card; the final branded interface run passes all three flows.
The small-phone full run predates the streaming optimization; final streaming,
seam fidelity and six-long-recording checks are covered by the 12-test iPhone 17 run.

| Check | Coverage |
| --- | --- |
| Catalogue and assets | All 89 entries, valid system symbols, SHA-256, byte count, decode and duration of all 81 recordings |
| Playback processing | Circular loop seams, bounded stereo noise with distinct spectral characteristics, all five measured binaural frequencies |
| Playback safety | Memory budget, missing assets, asynchronous cancellation and rapid clear/play changes |
| Mobile audio memory | The six longest original files play together with under 6 MiB of resident app-owned PCM buffers; file queues replenish across actual loop boundaries |
| State | Six-voice limit, one binaural, invalid persisted data, local restore paused |
| Saved mixes | Save/load/edit/delete; editing keeps original sound and volume settings; load paused |
| Timer | Deadline completion stops playback and clears its deadline |
| Native UI | Starter mix, playback, saving/loading, search, favorites, category selection, timer and native tabs |
| Meditation | Enter/exit, controls auto-hide, tap wakes eyes, accessibility value, rotation and horizontal centering |

## Screenshots

The PNG files in `screenshots/` are actual simulator captures, not design mockups.
No compositing or visual retouching was applied. The main flow shows the home library,
playing mix, saved mix, immersive controls, Nodi resting alone, Nodi awake after a tap,
settings, selected rain sounds and favorites. Device variants document smaller-phone
and iPad layouts. See `screenshots/README.md` for the gallery.

## Practical limits

The initial Release check compiled for arm64 iOS without signing. It proved compilation,
not installation on hardware or an App Store upload. Simulators do not prove real
headphone/Bluetooth routes, phone-call interruptions, lock-screen behavior, battery
usage, loudness on hardware or App Store acceptance. Those device checks are listed
in APP_STORE.md. VoiceOver labels and Reduce Motion are implemented; a human hardware
accessibility pass remains before release. iOS 17 is the deployment target, not a
runtime included in these local simulator checks.

Rights clearance remains a separate release requirement; see LICENSING.md. Subsequent
signing and the internal beta upload are recorded below.

## Subsequent signed internal beta

On October 9, 2026 the Release archive 1.0.0 (1) was built with automatic signing
for team 6RPLS9EA4X. codesign verification passed and all 81 bundled recordings were
checked against the catalogue's byte counts and SHA-256 hashes. Xcode's App Store
Connect export/upload succeeded, Apple finished processing, and the build is Testing
in the account holder's single-tester internal group. This does not constitute the
pending hardware validation. See TESTFLIGHT.md and screenshots/14-testflight-build1.jpg.

## Fresh distribution-rights audit

The October 9 audit rechecked all 81 local recording byte counts, SHA-256 hashes
and upstream Git blob identities, including per-file Git history and container/stream
metadata. Three original Nodi/connected-N source files match the published Nodus
v3.2.7 MIT versions byte for byte. CLA text digest and public account identity were
verified. This is provenance evidence, not a third-party rights grant.

The historical MIT notice was added to Legal resources, credits and Settings. A
new local Release simulator build succeeded; its packaged notice and active legal
documents match the source files exactly. The binary already uploaded as 1.0.0 (1)
was not replaced. No audio/engine behavior changed in this audit, so the previous
audio/UI suite was not repeated. See RIGHTS_AUDIT_2026-10-09.md for unresolved rights.

## Store screenshot captures

On October 9, 2026, the existing testCompleteSoundscapeAndScreenshots UI flow
passed on an iPhone 17 Pro Max (1320 × 2868 pixels) and an iPad Pro 13-inch M5
(2064 × 2752 pixels). Each run produced nine native, unretouched screenshots;
six from each run were selected for the uploaded store galleries. The previously
captured iPhone 17 Pro screenshots supply the 1206 × 2622 medium iPhone gallery.

The first 13-inch iPad capture run stopped when the test helper searched only
inside a bottom tab bar. The native regular-width iPad layout places its tabs at
the top. The helper now finds those observed buttons when no compact tab exists;
the rerun completed with one test and zero failures. Production behavior was not
changed. Result bundles are .build/StoreMediaPhone.xcresult and
.build/StoreMediaTabletFinal.xcresult. These were focused capture flows, not a
repeat of the entire audio/unit/UI suite or hardware validation.

App Store Connect accepted all 18 uploaded PNGs and displayed six of ten slots
for each of the three device galleries. English descriptions and TestFlight
instructions were saved through the integrated browser. Screenshot visibility
in TestFlight still depends on an approved App Store version, as documented in
TESTFLIGHT_METADATA.md. The local rights manifests were refreshed after the test
helper change; that refresh grants no additional distribution rights.

## Version correction to 0.1.0

The October 9 version correction sets MARKETING_VERSION to 0.1.0 and the build
number to 2 in project.yml and the regenerated Xcode project. Settings now reads
its version from CFBundleShortVersionString instead of a hardcoded 1.0 label.
The signed Release archive succeeded, codesign verification passed, and its
packaged Info.plist was verified as 0.1.0 (2) with the existing bundle ID.
All 81 recordings still match catalogue byte counts and SHA-256 hashes, and
all packaged legal documents match source. App Store Connect export/upload
succeeded at 01:56:10 Europe/Madrid. No audio behavior changed, so the focused
archive/package checks did not repeat the full test suite. See TESTFLIGHT.md
for Apple's processing and internal distribution result.


## October 9 interaction fixes — 0.1.0 (4)

Two focused silent UI tests pass on iPhone 17 Pro Max and iPad Pro 13-inch (M5),
both on iOS 26.2. Taps in the card's upper blank area and right side add/remove
the sound. Independent favorites and volume controls keep selection. Successive
Rain, Nature, Favorites and All filters retain the search/filter controls'
position. After scrolling far down, switching to the one-item Favorites list
keeps the controls fixed and shows the card below them. Settings cards have equal
widths, the requested Nodus/Moodist destinations are present, and the Moodist MIT
text and copyright render correctly with native paragraph justification.

The Debug-only `-ui-testing-silent` launch argument returns before audio-session
activation or engine startup. Neither test taps Play. No playback or audio-output
test was run for this update. Release excludes the silent testing branch.
Results: `.build/SilentUIPhoneBuild4Final.xcresult` (2/2) and
`.build/SilentUITabletBuild4Final.xcresult` (2/2). Real captures are
`screenshots/24-card-activation.png` through `27-moodist-license.png`, plus
`32-deep-filter-results.png`, with iPad equivalents under
`screenshots/silent-ipad/`. Earlier build 3 captures remain in its xcresult bundles.

The Nodi icon renderer centers the complete painted character and ripples on the
1024-square canvas. The original geometry is retained. The signed Release archive
succeeds; its packaged version is 0.1.0 (4), bundle ID and signing team are
unchanged, all 81 recording hashes match the catalogue, and every bundled legal
document matches the source. Code-signature verification passes.

Presenter's privacy policy describes camera use, local network pairing and PDFs.
A separate Drift policy covers local preferences, offline playback, optional
external links and Apple diagnostics. Its source was published through Nodus
PR #1079 and Website workflow 37903966692 at
`https://nodusresearch.com/drift/privacy/`; the live page and saved App Store
Connect policy URL were verified through the integrated browser.


## October 9 Saved parity — 0.1.0 (5)

The focused silent regression first reproduced the empty-state mismatch:
Saved's Nodi was 210 points high, while My mix used 230 points. The two screens
now share their header, full-width content layout and empty-state component,
including the 230-point Nodi and the primary action's dimensions. Saved cards
retain the mixer's width and have a 128-point minimum height, 26-point icons,
Dynamic Type titles and native subheadline metadata instead of 11-point details.

`DriftSilentUITests/testSilentSavedLayoutParity` passes on iPhone 17 Pro Max
and iPad Pro 13-inch (M5), both on iOS 26.2: one test, zero failures per device.
It compares heading origin/height, Nodi width/height, action-button dimensions
and populated card width/height, then saves and reloads two sounds and checks
that playback remains paused. Neither run presses Play; the Debug silent guard
prevents audio-session activation and engine startup. No sound was played.

Results: `.build/SavedParityPhoneBuild5.xcresult` and
`.build/SavedParityTabletBuild5.xcresult`. Actual, unretouched screenshots are
36-empty-my-mix.png, 37-empty-saved.png, 38-saved-parity-my-mix.png and
39-saved-parity-saved.png, with iPad equivalents under screenshots/silent-ipad/.
The earlier build 4 interaction and license checks are retained as historical
validation; this run does not repeat the audio test suite.

The signed Release archive contains 0.1.0 (5), all 89 catalogue entries, all 81
recordings with their expected SHA-256 hashes and all seven current legal files.
`codesign --verify --deep --strict` succeeds. The Release executable excludes the
silent Debug testing argument. The refreshed rights manifest records this exact
Swift source; the Apple permission remains an unsigned draft.
