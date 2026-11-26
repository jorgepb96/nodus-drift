# CarPlay validation · 2026-11-26

The first focused run passed five CarPlay tests. A second complete run passed
six CarPlay tests and two existing phone UI regressions, with no failures:
`ios/CarPlayFinalValidation.xcresult`.
See [the completed summary](CarPlayFinalValidation-summary.json).

Coverage:

- All 48 saved mixes plus 96 saved Studio scenes remain represented in native
  image grids with ordered titles, enabled states, per-row limits and multi-line
  layout. No library entries are silently truncated to an eight-button menu.
- Recent history uses stable starter IDs, resolves edited entries from the current
  library and ignores removed items. Connecting does not play audio.
- A missing generated attachment is unavailable and cannot replace the current
  mix. Playback does not initiate downloads, sign-in or generation.
- All 22 photographs produce static square thumbnails with bounded dimensions;
  two distinct environments produce distinct cover data.
- Mix and Studio playback use the same engine, change ownership, start real
  simulator audio and publish the scene title, cover and finite duration. The
  Studio clock freezes on pause. Recent selections preserve playback order.
- An interrupted session resumes only with `shouldResume`; an explicit user pause
  cancels resumption, and a nonresumable interruption stays paused.
- The existing horizontal-library UI flow passed in 61.591 seconds; manual scene
  creation, timeline, space, visuals, save and reopen passed in 67.793 seconds.

The native app was tested on the dedicated iPhone 17 Pro / iOS 26.5 simulator.
No physical iPhone or vehicle was used, per the user's instruction.

The desktop CarPlay Simulator did not return a usable native UI snapshot. Reader's
local CarPlay documentation also records that this version's CarPlay Simulator
requires an iPhone for a vehicle-display session. Therefore these results do not
claim to verify the vehicle screen's actual rendering, rotary input, light/dark
appearance, locked-phone playback or real navigation/call routing. These remain
CarPlay integration checks rather than assertions inferred from a unit test.

Apple's CarPlay Audio managed capability was enabled and read back on Drift's
App ID in the developer portal. See [the capability record](CAPABILITY.json).
The distribution/build signing result is recorded below when completed.

The final six CarPlay tests passed again after enabling the default entitlement
and checking distinct saved mixes with identical sounds publish the selected
name. See [signed-configuration summary](CarPlaySignedConfiguration-summary.json)
and `ios/CarPlaySignedConfiguration.xcresult`. The earlier two phone UI regressions
remain recorded in the eight-test summary above.

The generic-iOS Debug build succeeded without deployment to an iPhone. Both its
signed app and embedded provisioning profile contain CarPlay Audio. A fresh
App Store distribution profile was also created and independently decoded to
verify the same entitlement for Drift. See [signed Debug build](SIGNED_BUILD.json)
and [distribution profile](DISTRIBUTION_PROFILE.json).

The Release archive for 0.2.0 (18) completed and its strict signature check passed.
Both the app and embedded profile carry CarPlay Audio, and the compiled manifest
registers the CarPlay scene delegate with multiple-scene support. All 89 catalogue
entries, 81 recording checksums, 44 photographic plates, dormant atlas metadata,
legal notices, privacy manifest and both Metal libraries were reverified. The
archive matches 208 application/runtime source files. See
[archive verification](../rights/release18-archive-verification.json).

Private TestFlight delivery completed. Apple reported `VALID`, `INTERNAL_ONLY`,
`IN_BETA_TESTING` and only Jorge's internal group at 2026-11-26T10:29:47.697242+01:00.
The English `en-US` test notes were read back with an exact match. See
[delivery receipt](../rights/release18.json) and [TestFlight](../TESTFLIGHT.md).
