# TestFlight private preview · 0.2.0 (18)

**Build 18 is available for private internal testing**, verified at
2026-11-26T10:29:47.697242+01:00 (Europe/Madrid). Apple reports `VALID`, `INTERNAL_ONLY` and
`IN_BETA_TESTING`. Update Nodus Drift to **0.2.0 (18)** using the existing internal
TestFlight invitation.

- App: Nodus Drift (`com.drakonis96.nodusdrift`, App Store ID `6820753637`).
- Upload/build ID: `a40f7359-90f7-4144-9e70-ef84f72904e6`.
- CLI upload completed: 2026-11-26T10:26:02+01:00 (Europe/Madrid).
- Group: **Jorge — beta interna**, the only group with access.
- External state: `NOT_APPLICABLE`; no external beta review or App Store submission.
- English What to Test notes saved as `en-US`, read back with an exact match.
- [Open build in App Store Connect](https://appstoreconnect.apple.com/teams/36804ede-f0b5-4cd2-a273-c619feb6168f/apps/6820753637/testflight/ios/a40f7359-90f7-4144-9e70-ef84f72904e6).

## CarPlay Audio

Home offers Continue Listening and recent selections. My Mixes displays saved
simple mixes and Studio scenes; Explore offers three starter mixes and three
Studio soundscapes. Static photographic covers and titles use native multi-line
image grids on iOS 26+, titled image rows on iOS 17.4–25, and labelled thumbnail
lists on iOS 17.0–17.3. CarPlay controls the final screen layout and column count.
Selecting an available cover starts playback and opens the system Now Playing
screen after a voice is ready. Connecting alone never starts playback.

The phone and CarPlay share one engine, library and Studio clock. Editing,
generation, downloads and immersive visuals remain on the phone. Now Playing
publishes the selected title and static artwork, plus elapsed time and duration
for finite Studio scenes. Play, pause and stop use system remote commands;
unsupported seeking and queue controls are disabled. Interruption resumption
requires the system's permission and is canceled by a user pause.

The existing account capability was enabled for Drift in the Apple Developer
portal and read back. The signed Release archive and embedded profile both
contain CarPlay Audio and the compiled manifest declares its scene. A matching
App Store distribution profile was created and used for manual internal-only
export. No new entitlement request or agreement was required.

## Verification and limits

Six CarPlay tests passed with the final entitlement configuration, including the
selected name for otherwise identical saved mixes. An earlier completed run also
passed those six tests plus the two phone regressions for horizontal catalogue
browsing and manual Studio creation/edit/save/reopen.

Coverage includes all 144 saved library entries, names, native grid element
limits, recent identifiers, updated/deleted entries, missing recordings, all 22
static covers, real simulator playback, shared ownership/clock, metadata and
interruption behavior. Tests ran on the dedicated iPhone 17 Pro / iOS 26.5
simulator. No physical iPhone tests were performed, per user instruction.

Actual CarPlay-display rendering, rotary input, light/dark appearance,
locked-phone playback and real vehicle/navigation/call routing remain unverified
on hardware. The desktop CarPlay Simulator did not provide a usable native UI
snapshot; no vehicle-screen screenshot or physical compatibility claim is made.

The strict archive verification covers 208 source/runtime files, 89 catalogue
entries, all 81 recording checksums, 44 photographic plates, two dormant atlases,
legal/privacy files and both Metal libraries. Artwork remains 31,046,523 bytes;
no model weights are bundled. The source fingerprint includes uncommitted
working-tree changes and does not imply those changes are in Git HEAD.

- [Delivery receipt](rights/release18.json).
- [Archive verification](rights/release18-archive-verification.json).
- [Exact source fingerprint](rights/release18-source.json).
- [English What to Test notes](TESTFLIGHT_NOTES_BUILD18.txt).
- [CarPlay implementation](carplay/IMPLEMENTATION.md).
- [Validation evidence and remaining checks](carplay/VALIDATION.md).
- [Final six-test summary](carplay/CarPlaySignedConfiguration-summary.json).
- [Eight-test summary with phone UI regressions](carplay/CarPlayFinalValidation-summary.json).
- [Capability activation](carplay/CAPABILITY.json).
- [Signed generic-iOS Debug build](carplay/SIGNED_BUILD.json).
- [Distribution profile verification](carplay/DISTRIBUTION_PROFILE.json).

## Reproduce

Marketing version is 0.2.0 and build number is 18. Archive the Release scheme for
generic iOS, verify it, then use `ios/ExportOptions-TestFlight-CarPlay.plist` with
the installed **Nodus Drift App Store CarPlay** profile and existing Apple
Distribution identity. Internal-only export is enabled and automatic build
renumbering is disabled. Future uploads need a new build number. Credentials,
profiles, archives and upload logs are not stored in Git.

Previous private delivery is preserved in [TESTFLIGHT_BUILD17.md](TESTFLIGHT_BUILD17.md).
