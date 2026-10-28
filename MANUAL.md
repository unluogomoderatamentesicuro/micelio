# MICELIO manual

*a new world grows from the mycelium*

By **un luogo moderatamente sicuro**. For monome norns. MIT license.

---

## Contents

1. [What it is](#1-what-it-is)
2. [Install](#2-install)
3. [First minutes](#3-first-minutes)
4. [Controls](#4-controls)
5. [World types](#5-world-types)
6. [How sequences are composed](#6-how-sequences-are-composed)
7. [A world that keeps growing](#7-a-world-that-keeps-growing)
8. [Morph](#8-morph)
9. [The 32 engines](#9-the-32-engines)
10. [The 32 scales](#10-the-32-scales)
11. [The visual worlds](#11-the-visual-worlds)
12. [Favorites, seeds and history](#12-favorites-seeds-and-history)
13. [Parameters](#13-parameters)
14. [MIDI and clock](#14-midi-and-clock)
15. [Troubleshooting](#15-troubleshooting)
16. [Credits and license](#16-credits-and-license)

---

## 1. What it is

MICELIO is a one-key idea machine. Tap **K2** and a whole world appears, built from a single random seed:

- a **tempo** (a continuous value, never rounded: no two worlds share one);
- a **scale** and a **root note**;
- **four instruments**, each one a different engine out of 32;
- **music**: composed sequences, long drones, scattered events, or a mix;
- a **visual world** that moves on the screen and reacts to every note.

After that the world is alive. It rotates, mutates, modulates, rearranges itself and slowly drifts for as long as you leave it playing. You can steer it with your hands (rotate, thin out, change the timbre, change the engine), or let it surprise you.

It needs nothing but norns. There is no grid support, on purpose: the whole experience is three keys, three encoders and the screen.

## 2. Install

### From maiden (recommended)

1. Connect norns to your network and open **maiden** in a browser: `http://norns.local/maiden`.
2. In the REPL at the bottom of the page, type the following line and press enter:

   ```
   ;install https://github.com/unluogomoderatamentesicuro/micelio
   ```

3. Wait for the message that the download is finished.
4. On norns choose **SYSTEM > RESTART**. The restart is needed once, so that norns compiles the SuperCollider engine (`Engine_Micelio.sc`).
5. Choose **SELECT**, find **micelio** and open it.

To update: use the project manager in maiden (the *update* button next to micelio), or run the `;install` line again, then restart norns.

### By hand

Copy the whole `micelio` folder into `dust/code/` on norns (SFTP, SMB or a USB drive). The folder must be named exactly `micelio` and contain `micelio.lua` and the `lib` folder. Restart norns and open the script from **SELECT**.

## 3. First minutes

1. Open the script. A world starts playing at once.
2. **Tap K2.** A new world. Do it a few times; each one is different. The bottom of the screen shows its name, type, tempo and scale for a moment.
3. Turn **E2** to change the tempo. Turn **E3** and listen to the timbre and the notes move (this is *morph*). Turn **E1** to rotate the sequences.
4. **Hold K1** and turn E1: you select a track. Turn E3 to add or remove notes on it.
5. **Hold K3** and turn E3: you change the engine of the selected track. Turn E1: you change the scale.
6. When a world moves you, **hold K2 and tap K3**: it is saved as a favorite.
7. Leave it alone. Sooner or later it will do something you did not expect.

## 4. Controls

The screen shows a small help panel at the bottom while you hold K1, K2 or K3.

**Tap and hold.** K2 and K3 do their action when you *tap* them (press and release within about a third of a second). If you hold them longer, or use an encoder or another key while they are down, nothing happens when you let go. This lets K2 and K3 also be modifiers.

### Without modifiers

| Control | Action |
|---|---|
| **K2** (tap) | new world |
| **K3** (tap) | play / stop. Stopping fades out every note that is still ringing, drones included |
| **E1** | rotate every track by one step, whatever it plays: a sequence shifts its steps, a drone turns the voicing of its chord (inversion), a scape slides its register window up or down. The change is heard on the next notes; nothing is retriggered, so the sound stays clean. The screen shows ROTATE and a counter |
| **E2** | tempo, in steps of 0.5 BPM (1.5 BPM when you turn fast) |
| **E3** | morph, in steps of 0.25 |

### Hold K1: the track

| Control | Action |
|---|---|
| **E1** | select track 1 to 4 |
| **E2** | rotate the selected track only (same meaning as E1: steps, chord voicing or register window). The number of events of a scape is on E3 |
| **E3** | sequence: add or remove one note at a time, starting from the strongest beats. Drone: level. Scape: how many events |
| **K2** | go back to the previous world (up to 64) |
| **K3** | mute / unmute the track |

### Hold K2: the world

| Control | Action |
|---|---|
| **E1** | type of the *next* world: AUTO, SEQ, DRONE, SCAPE, MIXED |
| **E2** | reverb |
| **E3** | volume |
| **K3** | save this world as a favorite |

### Hold K3: the sound

| Control | Action |
|---|---|
| **E1** | scale (32) |
| **E2** | root note |
| **E3** | engine of the selected track (32) |
| **K2** | drift and evolution on / off |

## 5. World types

| Type | What you hear |
|---|---|
| **SEQ** | four composed sequences, up to 64 steps long |
| **DRONE** | notes tens of seconds long that fade in and out, with chords that slowly move |
| **SCAPE** | scattered events with changing pitches, lengths and stereo positions |
| **MIXED** | a drone underneath, the other tracks are sequences or scape events |

With the type set to **AUTO**, chance decides: about 36% SEQ, 22% DRONE, 22% SCAPE, 20% MIXED. Hold K2 and turn E1 to force a type for the next worlds.

Tempo ranges depend on the type: SEQ 52 to 162 BPM, DRONE 34 to 90, SCAPE 34 to 104, MIXED 44 to 144. Every value is continuous.

## 6. How sequences are composed

Sequences are not loops of identical notes. Every track has a **role** (bass, lead, pad or percussion) that depends on its engine, and the composer works bar by bar:

- **Length.** From 16 to 64 steps. Every track has its own length, so the loops drift against each other.
- **Step value.** Mostly 16th notes, but also 8th notes, 16th and 8th triplets, 32nd notes, dotted 8ths and quarters.
- **Note lengths.** Each note has its own length, from a 16th to a whole note, with rests. The gate changes from note to note: staccato, mixed or legato depending on the character of the track. A note never runs over the next one, except in pads, which overlap.
- **Form.** Bars follow patterns such as AABA, ABAB, ABAC: phrases come back, transposed onto the next chord and slightly varied.
- **Harmony.** A chord progression, rescaled to the number of notes in the scale. Chord tones fall on the strong beats and passing notes in between, along an arching line. The last note often closes on the root or the fifth.
- **Styles.** Rhythmic-cell melodies, arpeggios, bass pulses, syncopation, long pads, Euclidean rhythms.

**Density** (hold K1, E3) switches notes on and off by metric importance: strong beats are the last to disappear and the first to come back.

**Echo.** Some short notes repeat once, softer, half a step later.

## 7. A world that keeps growing

Once a world is born, it does not stand still. From time to time something happens, always inside the scale, engines and character chosen by the seed. A small message at the bottom of the screen tells you what it was.

How often depends on the **evolution** parameter (off, slow, medium, lively; default medium). At medium, an event happens roughly every 10 to 90 seconds, depending on the tempo.

What can happen:

- **Rotate**: one sequence is rotated by some steps.
- **New progression**: all sequences move onto a new chord progression; the melody stays recognisable.
- **One bar changes**: played backwards, mirrored, with different note lengths, or in another register.
- **New phrase**: a track gets a brand new composition, sometimes with a different length.
- **Density, step value, echo**: a track gets busier or sparser, doubles or halves its pace, adds echoes.
- **Arrangement**: a track drops out and later comes back.
- **Engine swap**: an instrument is replaced by another one.
- **Timbre**: filter, parameters and pan of a track shift.
- **Modulation**: the root note moves (a fifth up, a fourth up...).
- **Tempo drift**: the tempo glides slowly toward a new value, within about 20% of the world's own tempo.
- **Drone and scape changes**: a drone gets a new chord, a scape a new range and rate.
- **Reverb**: the space opens or closes.
- **Metamorphosis**: a sequence melts into a drone or a scape, or goes back to being a sequence.
- **New scene**: the visual world changes.

The locks (tempo, scale, engines in the parameters) are respected. If you want a world to stay exactly as it is, hold K3 and tap K2 to switch **drift** off, or set **evolution** to off.

## 8. Morph

Morph is a continuous control (E3). It moves, together:

- the **timbre** of every track: filter cutoff, resonance, the three engine parameters, pan;
- the **length** of the notes;
- the **dynamics**;
- the **notes themselves**: at some morph positions a few notes are skipped and a few are moved one scale degree up or down.

The effect is deterministic: the same morph value always gives the same variation, so turning E3 back restores the original music. The **morph depth** parameter sets how far it goes. While a world is playing, morph also drifts slowly by itself (more in drones and scapes).

## 9. The 32 engines

Each world uses four different engines. Struck engines (marked *struck*) ring for as long as their nature allows; the others follow the length of each note.

| # | Name | Character |
|---|---|---|
| 1 | ROOT | saw, pulse and sub through a Moog filter: the bass |
| 2 | BRONZE | metal bar, six inharmonic modes with beating *(struck)* |
| 3 | FOLD | wavefolder on sine and saw |
| 4 | DUST | a cloud of scattered sine grains |
| 5 | BREATH | noise on harmonic partials, with tone and vibrato |
| 6 | RUST | ring modulation, sample-and-hold and bit reduction *(struck)* |
| 7 | CRYSTAL | phase distortion, a resonant saw |
| 8 | SWARM | six sines with random glides and tremolo |
| 9 | CHOIR | vowel formants that move |
| 10 | VEIL | a pad of detuned saws and pulses, the filter breathes |
| 11 | ABYSS | deep sub with beating, slow FM and rumble |
| 12 | FOG | noise made to resonate by tuned combs |
| 13 | BELL | FM bell with inharmonic partials *(struck)* |
| 14 | STRING | plucked string, Karplus-Strong *(struck)* |
| 15 | TAPE | an oscillator on unstable tape: wow, flutter and hiss |
| 16 | GLASS | glass harmonica, pure partials, tremolo and a veil of air |
| 17 | WOOD | wooden bar, marimba-like *(struck)* |
| 18 | ORGAN | additive registers with a rotating tremolo |
| 19 | FLUTE | flute with breath; vibrato arrives after the attack |
| 20 | ACID | resonant saw with filter sweep and saturation |
| 21 | DROP | a water drop: a sine rising in pitch, with a short echo *(struck)* |
| 22 | REEDS | paired reeds, accordion-like, with bellows |
| 23 | STATIC | random discharges that make three frequencies ring *(struck)* |
| 24 | GONG | inharmonic modes that bloom and fade slowly *(struck)* |
| 25 | HARP | plucked strings with an octave and a soft body *(struck)* |
| 26 | KALIMBA | thumb piano: a stiff tine with a short buzz *(struck)* |
| 27 | BRASS | saw stack; the filter swells open after the attack |
| 28 | THEREMIN | pure tone with a glide into every note and a wide vibrato |
| 29 | CHIP | square wave with a moving duty cycle |
| 30 | SPECTRE | ten partials whose levels drift independently |
| 31 | THUNDER | rumble, a noise burst over a falling sub *(struck)* |
| 32 | SITAR | plucked string through a buzzing bridge *(struck)* |

A shared reverb and a final limiter close the chain.

## 10. The 32 scales

MAJOR, MINOR, DORIAN, PHRYGIAN, LYDIAN, MIXOLYDIAN, LOCRIAN, HARM MINOR, MEL MINOR, MAJ PENTA, MIN PENTA, BLUES, WHOLE TONE, DIMINISHED, HIRAJOSHI, INSEN, SPANISH, BYZANTINE, HUNGARIAN, NEAPOLITAN, ENIGMATIC, BEBOP, TRITONE, CHROMATIC, and eight **microtonal** scales: SLENDRO, PELOG, 19-EDO, QUARTER TONE, ARAB RAST, ARAB BAYATI, 7-EDO, HARMONICS.

Chord progressions adapt to the number of notes in the scale, so they work with pentatonic and microtonal scales as well. The internal sound plays microtonal pitches exactly; MIDI output rounds them to the nearest semitone.

## 11. The visual worlds

The screen has no fixed pages. Each world builds its own scene by combining **one to three layers** out of 80 generators, each with continuous random parameters. The scene also gets its own radial and mirror symmetry, rotation, zoom, camera drift, brightness, line width, antialiasing, background, and sometimes a light overlay (scan lines, a frame, a dot lattice or corner marks). Notes light up the layers, and tempo and morph modulate them. The combinations are practically endless.

When the sound is stopped the scene keeps moving and a pause mark appears in the top right corner.

The layers: rings, lissajous, warp, polygons, bars, waves, rain, automaton, spirograph, flow, moire, orbits, tunnel, tree, superformula, attractor, lattice, rays, fireflies, solid, horizon, threads, comets, web, network, ribbon, rose, harmonograph, spiral, chladni, constellations, bubbles, fractal, dna, snow, radar, asemic, lightning, mushrooms, sporeprint, mycelium, fairy ring, gills, hyphae, pulsar, hexagons, knot, snowflake, supernova, dot matrix, checkerboard, inkblot, urchin, lichen, amanita, leaves, equalizer, pinwheel, dunes, globe, torus, squares, starwheel, pulse trace, blocks, snake, pendulums, moon, phyllotaxis, forest, aurora, galaxy, kelp, mandala, scales, vines, eclipse, stalactites, atoms, ripples.

A draw budget keeps the frame rate smooth: if a scene would be too heavy, the extra layers or symmetries are dropped.

## 12. Favorites, seeds and history

- **Favorites.** Hold K2 and tap K3 to save the current world. Up to 64 favorites are kept in the script's data file, `dust/data/micelio/favs.data`, and survive restarts. In the parameters, *favorite slot* plus *load favorite* brings one back, *delete favorite* removes it.
- **Seeds.** Every world comes from a seed number. In the parameters, *seed* plus *generate from seed* regenerates a world exactly: the same seed and the same world type always give the same tempo, scale, engines, sequences and visuals (the world then evolves differently each time).
- **History.** Hold K1 and tap K2 to return to the previous world, up to 64 steps back.

## 13. Parameters

Open **PARAMS** from the norns menu.

| Parameter | Meaning |
|---|---|
| seed, generate from seed | regenerate a world from a number |
| favorite slot, load / delete favorite | manage favorites |
| tails | *cut*: a new world silences the previous one; *ring out*: old notes finish by themselves |
| world type | AUTO, SEQ, DRONE, SCAPE, MIXED, for the next world |
| drift | on / off. Switches off mutation and evolution |
| evolution | off, slow, medium, lively |
| drift amount | how strongly sequences mutate at each loop |
| scale, root | the current scale and root note |
| volume | master volume |
| morph depth | how far morph reaches |
| **REVERB** | level, room, damping |
| **LOCKS** | lock tempo, lock scale, lock engines: new worlds keep your choice |
| **TRACK 1 to 4** | engine, length (1 to 64), notes, step value, level, mute, octave, MIDI channel |
| **MIDI / AUDIO** | internal sound on / off, MIDI out on / off, MIDI device |

## 14. MIDI and clock

- **MIDI out.** Switch it on in the parameters, pick the device, and give each track its own channel. Notes carry velocity and length; microtonal notes are rounded to the nearest semitone. Turn the internal sound off if you only want to play external gear.
- **Clock.** MICELIO uses the norns clock. With the default internal source the script sets the tempo itself. If the clock source is MIDI, Link or crow, the tempo comes from that source: the script follows it, E2 shows a message instead of changing the tempo, and tempo drift is disabled. Set the tempo on the source.

## 15. Troubleshooting

**No sound after install.** Restart norns once (SYSTEM > RESTART) so that the engine is compiled. If maiden's REPL shows an error mentioning `Engine_Micelio`, open an issue on the repository and paste the message.

**The tempo jumps or does not obey E2.** Check **PARAMS > CLOCK > source**. It should be *internal*. With link, MIDI or crow the tempo belongs to the source.

**Crackle or dropouts.** Many layers and voices can load the CPU. Try the world types with fewer simultaneous voices, lower the reverb level, or reduce overlapping long notes (drones) by switching `tails` to *cut*. If the audio crackles only in a particular world, note its seed (PARAMS > seed) and report it.

**E1 seems to do nothing.** In worlds with sequences it rotates them; if a track is muted or very sparse the change may be hard to hear. In drones it changes the voicing of the chord and in scapes it moves the register window; both are heard on the following notes, which in a slow drone can take a few seconds. The screen always shows ROTATE and the counter. To change the sound more drastically use E3 (morph) or let the world evolve on its own.

**A world is gone.** Hold K1 and tap K2 to go back, or look into your favorites.

## 16. Credits and license

- **monome** and **norns**: Brian Crabtree, Ezra Buchla and contributors.
- **SuperCollider**: James McCartney and its community.
- The **lines** community (llllllll.co).
- The one-button "new idea" concept was inspired by Cyma Forma's RND synth. MICELIO shares no code, sounds or design with it.
- Techniques from the common heritage of music and mathematics: Euclidean rhythms (Godfried Toussaint), Karplus-Strong synthesis, phase distortion, vowel formant tables, gamelan scales, equal temperaments, Arabic maqam intervals, Wolfram's elementary cellular automata, Lissajous figures, harmonographs, Chladni figures, phyllotaxis, strange attractors of the Clifford / de Jong family, the Sierpinski triangle.
- Developed with the assistance of Claude, an AI model by Anthropic.

MICELIO is released under the **MIT license** (see `LICENSE`): copyright (c) 2026 un luogo moderatamente sicuro.
