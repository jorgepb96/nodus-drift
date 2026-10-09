# Replacement audio bank — October 9, 2026

This release replaces **all 81 original Moodist MP3 recordings** with newly
produced loops. The **89 options stay identical**: 81 file options, three noise
colors and five binaural presets. IDs, names, descriptions, categories, icons,
asset paths and native generator frequencies are retained. Existing mixes and
favorites continue to refer to the same IDs.

## Permissions and evidence

**80 options use 77 individually CC0-licensed originals; one radio-tuning option
is original Nodus synthesis.** No original Moodist audio bytes remain in this
bank. No Pixabay material is used. The historical investigation is retained,
but its 76 unidentified original sources no longer describe bundled audio.

Source providers: 59 options from [BigSoundBank](https://bigsoundbank.com/licenses.html),
17 from the individually CC0 subset of [FSD50K](https://zenodo.org/records/4060432),
and four individually CC0 recordings from [Clotho v2.1](https://zenodo.org/records/4783391).
The radio loop contains seeded noise and original tone sweeps, without recordings
of third-party voices, stations, music or broadcasts.

BigSoundBank source pages explicitly state CC0. The selected WAV's SHA-256,
author, individual page, CC0 notice, download URL and dated rating are retained.
FSD50K and Clotho licenses are checked **per recording**, not inferred from a
blanket dataset license. FSD50K's compilation is CC BY 4.0; the curators, paper,
license and transformations are acknowledged in the app. Clotho captions and
Clotho code are not used. The four selected WAVs are extracted from an archive
whose MD5 matches primary Zenodo evidence, and individually SHA-256 checked.

The underlying CC0 permissions remain in effect. Nodus owns the new editing and
original sound-design contributions; the source manifest distinguishes those
contributions from the original public-domain files. No unsolicited CC0
dedication of the owner's new work is asserted. Owner-directed inclusion in
this free app is recorded by the production request. The catalogue therefore
uses `LicenseRef-Nodus-loop-CC0-sources` and `LicenseRef-Nodus-original-audio`,
with `licenseStatus: verified` for every file option.

Records: [sources](rights/replacement-audio/sources.json),
[recipes](rights/replacement-audio/recipes.json),
[81-option source register](rights/replacement-audio/source-register.csv),
[final per-loop size/hash register](rights/replacement-audio/loop-register.csv),
[source-page evidence](rights/replacement-audio/evidence),
[technical build report](rights/replacement-audio/build-report.json), and
[current audit](rights/replacement-audio/audit-summary.json).
Each original and final file has a separate hash. Old hashes are retained only
as the [comparison baseline](rights/replacement-audio/baseline-catalog.json).

## Ratings and fit

Searches of BigSoundBank used its highest-to-least-rated ordering (`tri=n`).
The highest-rated **semantically fitting** eligible candidates were prioritized;
ties consider duration and the ability to produce an ambience loop. A higher
rating does not make an unrelated sound appropriate. Recordings containing
background music were rejected. Reviewed alternatives included: fireworks with
music, hotplate sizzling labelled as boiling water, a train interior for station
ambience, and a church service for church bells. Different street options use
different excerpts of the top-rated relevant source. Ratings and counts are
snapshots as of October 9, 2026, not a claim of worldwide optimality.

FSD50K and Clotho primary metadata do not supply community quality averages;
no scores were invented. FSD50K event-label validation ratings (PP/PNP) do not
measure the quality of a recording and were not used as a ranking.

The Whale source is the author's whale-song vocal imitation; Wolf and Beehive
are their authors' documented sound designs. Carousel is an amusement-park
ambience. These identities are explicit in the source register and in-app
credits. Authentic field recording is not claimed where not supported.

## Loop construction and weights

The pipeline decodes silently to 44.1 kHz float PCM, retains mono or stereo,
filters low-frequency/DC content, selects documented excerpts, and creates
circular source joins. Discrete events get deliberate pauses. The actual
excerpt is level-balanced with soft compression. Post-MP3 checks detect codec
overshoot and apply additional attenuation where needed. Files use real CBR MP3
encoding, without arbitrary byte padding. The sample duration is calibrated to
the previous byte budget; durations can change when a better bitrate is used.
The app makes a 200 ms circular boundary join at runtime.

Every output must be within **1% of its previous byte size**, decode correctly,
have finite samples, no clipping, low DC and a continuous runtime seam. The
report records actual changes for every option. All 81 final hashes must differ
from the historical hashes. The eight native generators must remain unchanged.

**No audio was played and no output device was activated.** Signal checks,
FFmpeg decoding and AVFoundation decode/streaming-loop tests are silent.
Perceived realism, repetition and comfort require the owner's private iPhone
listening test; technical analysis is not represented as an auditory review.

## Reproduction

Use Python 3.13, the packages in `scripts/requirements-audio.txt`, and FFmpeg
8.0.1 with libmp3lame as recorded in the build report. Run:

```sh
python3 scripts/prepare_audio.py
python3 scripts/audit_audio_bank.py
```

When current assets already match their hashes, preparation performs no download.
Otherwise it downloads only the recorded CC0 inputs and reconstructs the loops.
The Clotho archive is approximately 4.54 GB; no captions or code are extracted.
Reconstruction validates **all final release hashes before installing any file**.
An encoder mismatch fails instead of silently changing the catalogue. Maintainers
can explicitly generate a new reviewed bank with `create_audio_loops.py --install`.

The MP3s, source WAVs and archives remain excluded from Git. The recipes, evidence,
checks and legal notices are versioned. No upstream permission request was sent.
This step is a **private/internal TestFlight release**, not a public beta or
App Store submission. Public first-party license/source-access obligations remain
separate from the now-documented audio permissions.
