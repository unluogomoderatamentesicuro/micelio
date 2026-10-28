# Changelog

## 1.1.0

- E1 and K1+E2 now rotate every kind of track: sequences shift, drone chords change voicing, scapes slide their register. Always visible, never retriggers notes.
- 10 new visual layers (80 in total): aurora, galaxy, kelp, mandala, scales, vines, eclipse, stalactites, atoms, ripples.
- Sound and existing visuals unchanged.

## 1.0.0

First public release.

- 32 synthesis engines, 32 scales (8 microtonal), 70 visual layers.
- Four world types: SEQ, DRONE, SCAPE, MIXED.
- A composer that writes sequences up to 64 steps, with forms, chord progressions, rhythmic cells from 1/32 to whole notes and per-note gates.
- Evolution: a world keeps changing on its own (rotation, new progressions, mirrored bars, new phrases, arrangement, engine swaps, modulation, tempo drift, scene changes).
- Morph acts on timbre and on the notes, deterministically and reversibly.
- Favorites, seeds and a history of the last 64 worlds.
- Tempo is always written from the script and never read back, which makes it stable with any clock source.
- No pitch control: the key lives in the scale/root section.
