# Native media uploaded to App Store Connect

On October 9, 2026, six unretouched PNGs were accepted for each of the English (US)
App Store draft galleries below. No screenshot was resized or composited.

| Gallery | Source | Dimensions |
| --- | --- | --- |
| Medium Dynamic Island iPhone | iPhone 17 Pro; original screenshots in the parent directory | 1206 × 2622 |
| Large Dynamic Island iPhone | iPhone 17 Pro Max; iphone-large directory | 1320 × 2868 |
| 13-inch iPad | iPad Pro 13-inch M5; ipad-13 directory | 2064 × 2752 |

The two new device sets were exported from passing XCTest capture runs in
.build/StoreMediaPhone.xcresult and .build/StoreMediaTabletFinal.xcresult. Exported
attachments were copied byte for byte into these directories. Extra captures
04-meditation-controls, 07-settings and 09-favorites are preserved but were not
selected for the store gallery.

## Uploaded order

| Screen | Medium iPhone | Large iPhone | iPad 13-inch |
| --- | --- | --- | --- |
| Home | [01](../01-home.png) | [01](iphone-large/01-home.png) | [01](ipad-13/01-home.png) |
| Mixer | [02](../02-mix.png) | [02](iphone-large/02-mix.png) | [02](ipad-13/02-mix.png) |
| Saved mixes | [03](../03-saved.png) | [03](iphone-large/03-saved.png) | [03](ipad-13/03-saved.png) |
| Nodi resting | [05](../05-meditation-resting.png) | [05](iphone-large/05-meditation-resting.png) | [05](ipad-13/05-meditation-resting.png) |
| Nodi awake | [06](../06-meditation-awake.png) | [06](iphone-large/06-meditation-awake.png) | [06](ipad-13/06-meditation-awake.png) |
| Sound library | [08](../08-sound-library.png) | [08](iphone-large/08-sound-library.png) | [08](ipad-13/08-sound-library.png) |

[Upload record and TestFlight visibility](../../docs/TESTFLIGHT_METADATA.md).
