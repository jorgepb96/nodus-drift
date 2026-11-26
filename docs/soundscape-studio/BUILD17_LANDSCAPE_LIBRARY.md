# Readable landscape library · 0.2.0 (17)

The tester's landscape screenshot showed only the top edge of catalogue cards.
Portrait-sized pinned library controls, a tall mini player and the native bars
left too little vertical room for the results in a compact-height phone window.

In compact-height layouts, the library uses intrinsic document flow instead of
a portrait-sized placeholder and pinned overlay. Search, sorting and horizontally
scrollable categories share one row. They can scroll away to make room for whole
cards. Card spacing and icon size are tighter while names retain their existing
font size and favorites keep their independent 44-point targets. Volume controls
and selection reserves remain present. The mini player uses less padding while
retaining its 48-point playback and landscape actions. Portrait pinning, card
proportions and the shared 185-point Nodi drawing size are preserved.

A scrolled library is re-anchored when the vertical size class changes, preserving
selected sounds, filters and query. Compact control height does not overwrite the
portrait header's placeholder height. The actual landscape artwork and immersive
rendering pipeline are unchanged from build 16.

The focused UI flow uses a six-sound mix, rotates the native app window, filters
the library, positions a complete selected card above the player, checks its
favorite and volume targets, then opens the landscape directly from the horizontal
mini player. Drags are confined to the observed catalogue viewport: app-wide
swipeUp begins in bottom chrome on a landscape phone. Slow bounded drags avoid
fling/overshoot and begin in the visible portion of a card when needed.

Final test results, screenshots and private delivery are recorded below.
No physical iPhone tests are performed, per the user's instruction.

The final two UI tests passed in `Build17LandscapeFinal.xcresult`: the complete
horizontal catalogue/landscape flow and deep Favorites filtering in portrait.
See [Build17Layout-summary.json](Build17Layout-summary.json). Native screenshots
were visually inspected: [horizontal library](../../screenshots/studio/build17/landscape-library.png),
[opened landscape](../../screenshots/studio/build17/landscape-player.png) and
[portrait Favorites](../../screenshots/studio/build17/portrait-favorites.png).
Only DriftViews.swift and version/build settings differ from the build-16
application/runtime snapshot. No image or audio asset was changed.

Apple accepted build `90886da7-e07b-4283-aebe-6b287b45513f` and the final API read at
2026-11-24T16:17:00.715575+01:00 confirmed `VALID`, `INTERNAL_ONLY`, `IN_BETA_TESTING`,
only Jorge's internal group and an exact `en-US` What to Test match.
See [delivery receipt](../rights/release17.json) and [TestFlight](../TESTFLIGHT.md).
