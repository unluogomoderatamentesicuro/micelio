# MICELIO

*a new world grows from the mycelium*

A generative instrument for [monome norns](https://monome.org/docs/norns/), by **un luogo moderatamente sicuro**.

Tap one key and a complete world is born: a tempo, a scale, four instruments picked from 32 synthesis engines, music that can be a composed **sequence**, a long **drone** or a **scape** of scattered events, and a moving visual world drawn from 80 procedural layers. No two worlds are alike. Then the world keeps growing on its own, for hours, if you let it: sequences rotate, progressions change, bars are mirrored, instruments come and go, the tempo breathes.

norns only. No grid, no keyboard, no other hardware: three keys, three encoders and the screen.

## Install

From **maiden** (open `http://norns.local/maiden` in your browser), type this in the REPL at the bottom and press enter:

```
;install https://github.com/unluogomoderatamentesicuro/micelio
```

Wait for the download to finish, then restart norns once (**SYSTEM > RESTART**) so that the SuperCollider engine gets compiled. Open **micelio** from **SELECT**.

You can also copy the `micelio` folder to `dust/code/` by SFTP/SMB. The folder must be called `micelio`.

To update later, use the maiden project manager (or run the `;install` line again) and restart.

## Quick start

| | |
|---|---|
| **K2** (tap) | a new world |
| **K3** (tap) | play / stop |
| **E1** | rotate everything: sequences shift, drone chords change voicing, scapes slide their register |
| **E2** | tempo |
| **E3** | morph: timbres and notes move together, and come back if you turn back |

Hold **K1**, **K2** or **K3** to reach more: track selection, world type, reverb, volume, favorites, scale, root, engine. The screen tells you what each encoder does while you hold a key. The full list is in the manual.

## Manual

Everything is explained in **[MANUAL.md](MANUAL.md)**: controls, world types, how sequences are composed, how a world evolves, the 32 engines, 32 scales, the visual layers, parameters, favorites and seeds, MIDI, troubleshooting.

## Credits

MICELIO stands on the shoulders of the norns community.

- **monome** and **norns**, by Brian Crabtree, Ezra Buchla and the many contributors: a free, open, hackable instrument, and the philosophy this script tries to honour.
- **SuperCollider**, by James McCartney and its community: every sound here is built from SuperCollider's core UGens.
- The **lines** community (llllllll.co), for the scripts, the habits and the generosity that make writing for norns a pleasure.
- The one-button "new idea" concept was inspired by Cyma Forma's RND synth. MICELIO shares no code, sounds or design with it.
- Ideas from the public domain of music and mathematics: Euclidean rhythms (Godfried Toussaint), Karplus-Strong plucked strings, phase distortion (as on Casio CZ synthesizers), vowel formant tables, gamelan slendro and pelog scales, equal divisions of the octave, Arabic maqam intervals, Wolfram's elementary cellular automata, Lissajous figures, harmonographs, Chladni figures, phyllotaxis, strange attractors of the Clifford / de Jong family, the Sierpinski triangle.
- Developed with the assistance of Claude, an AI model by Anthropic.

## License

MIT, see [LICENSE](LICENSE). Use it, change it, share it. If you make something with it, I would love to hear it.
