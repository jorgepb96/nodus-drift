# Soundscape Studio

Studio is an additional creation workflow. The existing catalogue, six-sound mixes,
favorites, presets, sleep timer, lock-screen controls and Nodi meditation remain.
The minimum deployment target remains iOS 17; Apple Foundation Models is optional
and availability-gated on iOS 26 or newer. No cloud language model is used.

## Boundaries

- **Scene document:** versioned Codable scene, layers, automation keyframes,
  spatial coordinates, randomized event schedules and visual composition.
- **Studio library:** atomic local persistence and a portable scene archive containing
  its generated recordings. Import is bounded, validates all documents and does
  not accept arbitrary paths. Scene copies have independent identities.
- **Playback:** the existing DriftAudioEngine retains its streaming seams, gain ramps,
  output limiter and media controls. Studio adds an AVAudioEnvironmentNode with mono
  spatial inputs; binaural/music layers keep their stereo image. A monotonic transport
  evaluates volume and position automation; random events have stable schedules within
  a session so seeking is reproducible. One playback owner at a time.
- **Generation:** the MIT-licensed StableAudioMLX package from Reader's soundscape
  branch, pinned MLX 0.33.0 and pinned SHA-256 model manifest. T5Gemma → DiT → SAME-S
  run serially with staged residency. Models and archives are excluded from backup.
  Generated audio is checked and levelled before being added as an editable layer.
- **Scene director:** Apple's on-device SystemLanguageModel returns constrained Swift
  structures. The app validates sound IDs, numeric bounds and layer counts. It
  cannot access the network or execute arbitrary tools. Existing sounds are usable
  without downloading Stable Audio. Missing sounds become explicit generation requests.
- **Visuals:** 22 bundled photographic-style plates and two transparent 4 × 4 atlases rendered by native Metal
  through a SwiftUI/MTKView bridge. Material masks animate foliage and water without
  moving the entire photograph; layered precipitation, mist, flames and lighting
  follow the same evaluated scene as audio. The renderer caps resolution and frame
  rate, bounds its texture cache, and suspends animation offscreen, in background,
  with Reduce Motion or critical thermal pressure. Low Power Mode uses 15 fps;
  serious thermal pressure uses 10 fps. A native still
  image is the fallback. Visuals can be disabled entirely. See LANDSCAPES.md.
- **Meditation:** a pure interpretation of the selected catalogue mix chooses a
  photographic environment, weather, animal/object actors and procedural effects without taking audio ownership. The
  original Nodi and landscape share meditation controls; the optional appearance
  preference decodes safely from older configuration files. Visual motion can
  be paused independently from audio and remains available in a paused preview.

## Reader reuse and licensing

Inspected local Reader main `224d56a` and its separate soundscape worktree on
`feature/nodus-soundscapes-poc-7ae487` (`ab01cb3`). Main does not contain Stable Audio.
Reader's app-level services are AGPL-3.0-only: they are architectural references and
are not copied into this MIT app. Only `Modules/StableAudioMLX`, which includes its
own MIT LICENSE, is vendored. See that package's NODUS_VENDOR.md for upstream origins.
The module's minimum iOS version is lowered from 18 to 17 to match MLX's supported
deployment target and retain Drift compatibility; hardware validation remains separate.

Model weights are not MIT: the pinned Stability AI Community License and Gemma
Terms are included in the app's Legal directory. Model downloads require the user
to read/accept those terms. See FEASIBILITY.md for measurements and distribution gates.

Visual uniforms use five SIMD4 groups (80 bytes); each actor uses 48 bytes. The
renderer shares a single encoder path between tests and production, with separate
photo/animal/prop textures and a maximum of 12 actors. Crops follow a context-aware
focal point; actors remain within the visible crop with their aspect ratio intact.
Immersive views default to the plain top-left brand. Tapping reveals controls;
Hide controls restores the clean scene without a gray header, legend or pause pill.
