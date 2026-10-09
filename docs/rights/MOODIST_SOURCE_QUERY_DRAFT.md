# Proposed public comment on Moodist issue #113 — NOT SENT

Destination: https://github.com/remvze/moodist/issues/113

Decision, October 9, 2026: the user declined publication and requested retaining
the report only. This comment was not sent; no contact is authorized.

This is the exact proposed comment. It contains no bundled audio or private account
details. It must not be posted without the user's explicit authorization.

---

I'm also tracing the original sources for a free native iOS ambient-sound app,
Nodus Drift, with no purchases, subscriptions or advertising. Our app uses 81
ambient MP3s from Moodist commit `11c0be2200116a3635880d600fd6953899cc51a3`;
our binaural and noise options are synthesized locally.

I have matched five Moodist files to Freesound originals currently published
under CC0, by comparing three separate signal windows without playing audio:

- `transport/submarine.mp3`: [Squeeb, 185589](https://freesound.org/people/Squeeb/sounds/185589/).
- `places/laundry-room.mp3`: [moviebuffgavin, 411914](https://freesound.org/people/moviebuffgavin/sounds/411914/).
- `places/restaurant.mp3`: [mshahen, 507218](https://freesound.org/people/mshahen/sounds/507218/), consistent with the Michael Shahen metadata.
- `things/morse-code.mp3`: [NebulousRoyale, 343740](https://freesound.org/people/NebulousRoyale/sounds/343740/).
- `things/slide-projector.mp3`: [guyburns, 551486](https://freesound.org/people/guyburns/sounds/551486/), Slideprojector #2.

The three windows for each have correlations above 0.95 and consistent time offsets.
Some loop tails differ, so this supports derivation from the source rather than
full-file byte identity. I have not established which download platform was used.

Could you share the original Freesound/Pixabay URLs or sound IDs for the remaining
recordings, their applicable licenses, and any trimming or loop edits? Any retained
download/source records would help verify the mapping. I have read your statement
in [issue #33](https://github.com/remvze/moodist/issues/33#issuecomment-2082429291)
and the README license section; I am looking for the individual source list, not
assuming that 81 new permissions are needed or that MIT applies to the audio.

The intended app bundles the recordings for offline looping, allows one recording
or up to six mixed with independent volumes, saved mixes, a timer and background
playback, and includes an animated meditation view. It has no audio-file export.
Distribution would be free through TestFlight and the App Store.

Thanks! I hope the five identified sources also help anyone else tracing this list.
