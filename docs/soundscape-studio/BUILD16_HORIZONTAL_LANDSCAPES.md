# Dedicated horizontal environments · 0.2.0 (16)

All 22 environments now have independently generated horizontal artwork in
addition to their original portrait plate. The built-in image generation tool
created one new 16:9 composition per scenario; these are not resized or cropped
copies of the portrait files. The selected PNGs were encoded as bundled JPEGs
without changing their framing. New plates are 1672 × 941 pixels and total
13,484,135 bytes. The originals and the dormant sprite atlases remain bundled.
Prompts, sizes, source hashes and final hashes are recorded in
[LANDSCAPE_WIDE_ASSETS.json](LANDSCAPE_WIDE_ASSETS.json).

`StudioLandscapePlate` selects artwork from the actual view bounds, so an iPhone,
a tablet, an expanded Duo window and a split window follow their available space.
Portrait and square views use the portrait plate; wider views use the new image.
Aspect-fill cropping preserves proportions. The native fallback and GPU use the
same choice. Interior glass bounds and the cabin hearth have separate horizontal
calibration; portrait effect masks retain their existing coordinates.

The native host keeps a still photograph over the Metal view until a replacement
frame completes. Texture revision checks reject asynchronous loads or completion
callbacks from a previous orientation. A paused scene redraws after a resize.
Texture caches remain limited to two photographs and rendering stays capped at
2048 pixels on its longest edge. Decorative cutouts remain disabled, including
legacy/imported scenes; unused atlases are not loaded into GPU memory.

This build also includes the previous source-only simplification and the Nodi /
landscape selection changes. A single landscape surface survives mode switches
and pauses while hidden. The full-screen wake gesture is inactive while controls
are showing; their central empty area handles wake taps without competing with
the selection buttons.

Validation and private delivery are recorded in `docs/TESTFLIGHT.md` after
verification. The initial interrupted run finished with 17 passing tests and two
failures: a cold-start fixed-delay assertion and a selector tap made after the controls had already auto-hidden. Captured before/after
images confirmed that the tap was revealing controls rather than choosing Nodi.
The startup test now waits for rendered frames with a bounded timeout; the UI
flow refreshes controls before a selection. The wake hit area is also separate
from visible controls.
No new physical iPhone tests or battery measurements are requested or performed.

## Final evidence

The resumed iOS 26.5 simulator run passed all 17 rendering test bodies, including
both artwork orientations, all 22 wide textures, real GPU motion, resize while
paused, preserved scene data and the retained surface behind Nodi. Its console
summary is [Build16Rendering-console-summary.json](Build16Rendering-console-summary.json).
The final two UI tests passed in a complete result bundle: three landscape/Nodi
round trips with real audio, and clean horizontal cabin/car fixtures. See
[Build16FinalUI-summary.json](Build16FinalUI-summary.json). The earlier personalized
snow/car portrait-to-horizontal flow also passed in `Build16WideValidation.xcresult`.

The native [cabin](../../screenshots/studio/build16/cabin-wide.png) and
[car](../../screenshots/studio/build16/car-wide.png) horizontal captures were
visually inspected. The fire stays inside the newly composed hearth, rain is in
the window/windshield and no decorative cutouts or control panels obscure the
scene. The Duo fixture launched in a portrait window, so its screenshot is
retained as portrait evidence; expanded Duo editing-flow certification is not
claimed. Wide and 4:3/Duo-style viewport selection is covered by rendering tests.

Private delivery completed: 0.2.0 (16), VALID / INTERNAL_ONLY / IN_BETA_TESTING,
English notes verified and only the existing internal group assigned. See
[delivery receipt](../rights/release16.json).
