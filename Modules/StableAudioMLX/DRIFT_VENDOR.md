# Drift integration

Vendored from the separately MIT-licensed StableAudioMLX package in Nodus Reader's
soundscape worktree, commit `ab01cb3`, on 6 November 2026. The package's LICENSE and
NODUS_VENDOR.md are retained. Reader's AGPL-only application services are not part
of this copy. No weights or generated recordings are checked in.

Drift lowers the package deployment target from iOS 18 to iOS 17, matching MLX
0.33.0's own minimum. Network mathematics, tokenizer, manifest, converter and
sampling remain unchanged. Simulator inference is still blocked before MLX
initialization. Application-level generation uses staged residency, serial
requests, admission checks and cancellation.
