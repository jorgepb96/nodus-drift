# Real simulator captures

These are unretouched captures of the native application. The main gallery is from
an iPhone 17 Pro on iOS 26.3.1. The device variants include an iPhone SE (3rd generation)
on iOS 18.2 and an iPad mini (A17 Pro) on iOS 26.3.1. Landscape images retain Apple's
native screenshot orientation metadata.

| Home | Playing mix |
| --- | --- |
| ![Home](01-home.png) | ![Mix](02-mix.png) |

| Nodi resting, controls hidden | Nodi awake after a tap |
| --- | --- |
| ![Resting](05-meditation-resting.png) | ![Awake](06-meditation-awake.png) |

- [Saved mixes](03-saved.png)
- [Meditation controls](04-meditation-controls.png)
- [Settings](07-settings.png)
- [Rain library and volume controls](08-sound-library.png)
- [Favorites](09-favorites.png)
- [Small iPhone](10-device-portrait-se.png)
- [Small iPhone, landscape meditation](13-device-meditation-landscape-se.png)
- [iPad](10-device-portrait-ipad.png)
- [iPad, landscape meditation](13-device-meditation-landscape-ipad.png)
- [Internal TestFlight build 1 is Testing](14-testflight-build1.jpg)

## Store media uploaded October 9, 2026

The [store media record](app-store/README.md) lists the six selected images in each
device gallery. Additional iPhone 17 Pro Max and iPad Pro 13-inch M5 images are
native XCTest screen captures at their original dimensions, with no visual edits.

- [Saved TestFlight beta description](15-testflight-description.jpg)
- [Saved What to Test instructions](16-testflight-testing-notes.jpg)
- [Medium iPhone upload](17-app-store-iphone-screenshots.jpg)
- [13-inch iPad upload](18-app-store-ipad-screenshots.jpg)
- [Large iPhone upload](19-app-store-iphone-large-screenshots.jpg)
- [Description and medium iPhone gallery, with page context](20-app-store-metadata-proof.jpg)

## Current version 0.1.0

- [Corrected App Store draft version](21-app-store-version-0.1.0.jpg)
- [Only active internal group build, 0.1.0 (2)](22-testflight-0.1.0-active.jpg)
- [Saved instructions for 0.1.0 (2)](23-testflight-0.1.0-notes.jpg)

Earlier browser proofs retain their actual historical version labels.


The October 9 build 4 interaction fixes have fresh silent native UI captures:
24-card-activation.png, 25-stable-filters.png, 26-settings-aligned.png and
27-moodist-license.png and 32-deep-filter-results.png. The equivalent iPad captures are in silent-ipad/.
No audio was played to produce these captures. The centered icon is the actual
1024px AppIcon asset in ios/NodusDrift/Assets.xcassets/AppIcon.appiconset/.


## Saved layout parity — build 5

Fresh silent iPhone 17 Pro Max captures from the focused Saved regression test:

| My mix | Saved |
| --- | --- |
| ![Empty mixer](36-empty-my-mix.png) | ![Empty Saved](37-empty-saved.png) |
| ![Paused mixer](38-saved-parity-my-mix.png) | ![Saved soundscape](39-saved-parity-saved.png) |

The test compares heading scale, Nodi size, action-button dimensions and card
width/height across both tabs, then saves and loads a mix without pressing Play.
The corresponding iPad captures are under silent-ipad/. Historical App Store
captures above retain their actual uploaded image contents.

- [Saved build 5 instructions](40-testflight-0.1.0-5-notes.png)
- [Current internal TestFlight beta, 0.1.0 (5)](41-testflight-0.1.0-5-active.png)

## Replacement audio bank — build 6

These captures come from the successful silent iPhone and iPad tests:

- [Sound activations, iPhone](43-build6-iphone-sounds.png)
- [Settings, iPhone](44-build6-iphone-settings.png)
- [Settings, iPad](45-build6-ipad-settings.png)
- [Audio permissions and source credits, iPhone](46-build6-iphone-audio-credits.png)
- [Audio permissions and source credits, iPad](47-build6-ipad-audio-credits.png)

The new bank keeps all 89 options. No audio was played for these captures.

- [Saved build 6 notes](48-testflight-0.1.0-6-notes.jpg)
- [Private TestFlight beta 0.1.0 (6), Testing](49-testflight-0.1.0-6-active.jpg)


## Deep Favorites filtering — build 8

Fresh, unretouched silent simulator captures show the first result or empty-state
explanation immediately after scrolling to the end of Sounds and choosing Favorites.
The populated card retains its catalogue dimensions. The mix stays paused.

- 66-build8-iphone-deep-library.png: catalogue before changing the filter.
- 67-build8-iphone-favorites.png: first favorite with a paused active mix.
- 68-build8-iphone-empty-favorites.png: empty Favorites with the mini-player.
- 69-build8-iphone-empty-favorites-no-mix.png: alphabetical catalogue to empty Favorites, no active mix.
- 70-build8-iphone-category.png: deep catalogue to the first Rain results.
- [iPad first favorite](71-build8-ipad-favorites.png)
- [iPad empty Favorites](72-build8-ipad-empty-favorites.png)

- [Private beta, build 8 Testing](73-testflight-build8-private.jpg)
- [Public beta, build 8 Waiting for Review](74-testflight-build8-public-review.jpg)
- [All 89 favorites and retained search after tab navigation](76-build8-all-favorites-search.png)

## App Store final draft — 0.1.0 (8)

Fresh browser proofs show the saved title and existing accepted media. Contact
details and the physical recording are excluded from these screenshots.

- [Six medium iPhone screenshots](77-app-store-final-iphone.jpg)
- [Six 13-inch iPad screenshots](78-app-store-final-ipad.jpg)
- [Named video attachment and automatic release](79-app-store-video-auto-release.jpg)

The large iPhone gallery also contains six accepted screenshots. The draft has
not been submitted: Apple requires the final App Privacy declaration publication.
See [current preparation](../docs/APP_STORE.md).
