// Engine_Micelio.sc
// MICELIO - generated sonic worlds for monome norns
// by un luogo moderatamente sicuro
//
// 32 engines: ROOT, BRONZE, FOLD, DUST, BREATH, RUST, CRYSTAL, SWARM,
//             CHOIR, VEIL, ABYSS, FOG, BELL, STRING, TAPE, GLASS,
//             WOOD, ORGAN, FLUTE, ACID, DROP, REEDS, STATIC, GONG,
//             HARP, KALIMBA, BRASS, THEREMIN, CHIP, SPECTRE, THUNDER, SITAR
// 4 voices (with a polyphony limit per voice), a shared reverb and a final limiter.
//
// Commands:
//   note(voice, type, freq, amp, dur, cutoff, res, p1, p2, p3, pan, send, atk, sus)
//   reverb(level, room, damp)
//   silence()   fades out and frees the notes that are still sounding
//
// Envelope: attack atk, then a plateau (dur * sus), then a release (dur * (1 - sus)).
// With sus = 0 the note is percussive; with a high sus and a long atk it is a drone.
//
// p1, p2, p3 are normalised timbre parameters, 0..1:
//    0 ROOT       pulse width     | sub level          | detune
//    1 BRONZE     strike hardness | ring time          | beating
//    2 FOLD       fold amount     | saw mix            | detune
//    3 DUST       grain density   | grain length       | scatter
//    4 BREATH     overblow        | breath/tone        | vibrato
//    5 RUST       ring ratio      | sample rate        | bit depth
//    6 CRYSTAL    PD resonance    | detune             | sub
//    7 SWARM      glide amount    | tremolo            | warble
//    8 CHOIR      vowel           | vowel motion       | vibrato
//    9 VEIL       detune          | filter motion      | pulse modulation
//   10 ABYSS      beating         | slow FM            | rumble
//   11 FOG        decay           | motion             | second resonance
//   12 BELL       inharmonicity   | brightness         | fifth partial
//   13 STRING     damping         | string length      | body
//   14 TAPE       wow             | flutter            | hiss
//   15 GLASS      detuning        | tremolo            | air
//   16 WOOD       strike hardness | ring time          | detune
//   17 ORGAN      registration    | tremolo            | key click
//   18 FLUTE      breath          | tone colour        | vibrato
//   19 ACID       sweep amount    | decay              | saturation
//   20 DROP       pitch jump      | length             | echo
//   21 REEDS      detuning        | brightness         | bellows
//   22 STATIC     density         | ring time          | crackle
//   23 GONG       brightness      | length             | beating
//   24 HARP       pluck softness  | string length      | octave string
//   25 KALIMBA    tine overtone   | ring time          | buzz
//   26 BRASS      detune          | swell time         | vibrato
//   27 THEREMIN   glide offset    | glide time         | vibrato
//   28 CHIP       duty modulation | duty speed         | pitch drop
//   29 SPECTRE    spectral tilt   | partial drift      | stretch
//   30 THUNDER    sub drop        | rumble colour      | crack
//   31 SITAR      pluck softness  | string length      | bridge buzz

Engine_Micelio : CroneEngine {

	var synthGroup, fxGroup, revBus, revSynth, masterSynth, voiceList, defNames;

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc {
		var mk;

		defNames = [
			\micRoot, \micBronze, \micFold, \micDust,
			\micBreath, \micRust, \micCrystal, \micSwarm,
			\micChoir, \micVeil, \micAbyss, \micFog,
			\micBell, \micString, \micTape, \micGlass,
			\micWood, \micOrgan, \micFlute, \micAcid,
			\micDrop, \micReeds, \micStatic, \micGong,
			\micHarp, \micKalimba, \micBrass, \micTheremin,
			\micChip, \micSpectre, \micThunder, \micSitar
		];
		voiceList = Array.fill(4, { List.new });

		synthGroup = Group.head(context.xg);
		fxGroup = Group.tail(context.xg);
		revBus = Bus.audio(context.server, 2);

		// common builder: atk / sustain / release envelope, soft saturation, pan, send
		mk = { arg name, crv, body;
			SynthDef(name, {
				arg out = 0, rbus = 0, freq = 220, amp = 0.3, dur = 0.5, cutoff = 3000, res = 0.3,
				p1 = 0.5, p2 = 0.5, p3 = 0.5, pan = 0, send = 0.2, atk = 0.01, sus = 0, kill = 0;
				var env, kenv, sig;
				env = EnvGen.ar(
					Env.new(
						[0, 1, 1, 0],
						[atk.max(0.001), (dur * sus).max(0.001), (dur * (1 - sus)).max(0.01)],
						[-2, 0, crv]
					),
					doneAction: 2
				);
				kenv = EnvGen.kr(Env.asr(0.005, 1, 0.12), 1 - kill, doneAction: 2);
				sig = body.value(freq, dur, cutoff, res, p1, p2, p3, env) * kenv;
				sig = LeakDC.ar(sig);
				sig = (sig * amp).tanh;
				sig = Pan2.ar(sig, pan);
				Out.ar(out, sig);
				Out.ar(rbus, sig * send);
			}).add;
		};

		// 0 - ROOT: saw + pulse + sub, Moog filter with envelope
		mk.value(\micRoot, -4, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var det, saws, pul, sub, mix, fenv, sig;
			det = 1 + (p3 * 0.015);
			saws = Saw.ar([freq, freq * det]);
			pul = Pulse.ar(freq, 0.1 + (p1 * 0.8));
			sub = SinOsc.ar(freq * 0.5) * (p2 * 1.2);
			mix = (Mix.new(saws) * 0.35) + (pul * 0.4) + sub;
			fenv = EnvGen.ar(Env.perc(0.001, dur * 0.7, 1, -4));
			sig = MoogFF.ar(mix, (cutoff * (0.4 + (fenv * 1.6))).clip(40, 16000), res * 3.2);
			sig * env;
		});

		// 1 - BRONZE: metal bar, six modes with inharmonic ratios
		mk.value(\micBronze, -1, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var ratios, click, modes, sig;
			ratios = [1, 2.756, 5.404, 8.933, 13.344, 18.64];
			click = Decay2.ar(Impulse.ar(0), 0.0005, 0.012) * PinkNoise.ar * (0.3 + (p1 * 1.2));
			modes = Mix.fill(6, { arg i;
				var f, a, de, beat;
				f = freq * ratios[i];
				a = (1 + (i * (1.8 - (p1 * 1.5)))).reciprocal;
				de = EnvGen.ar(Env.perc(0.001, dur * (0.3 + (p2 * 1.3)) / (1 + (i * 0.6)), 1, -4));
				beat = 1 + (p3 * 0.004 * (i + 1));
				(SinOsc.ar(f.min(15000)) + SinOsc.ar((f * beat).min(15000))) * 0.5 * a * de * (f < 15000);
			});
			sig = (modes * 1.4) + click;
			sig = LPF.ar(sig, cutoff.clip(400, 16000));
			sig * env;
		});

		// 2 - FOLD: wavefolder on sine/saw
		mk.value(\micFold, -3, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var o1, o2, mix, fenv, folded, sig;
			o1 = SinOsc.ar(freq);
			o2 = Saw.ar(freq * (1 + (p3 * 0.01)));
			mix = (o1 * (1 - p2)) + (o2 * p2 * 0.6);
			fenv = EnvGen.ar(Env.perc(0.002, dur * 0.7, 1, -3));
			folded = (mix * (1 + (p1 * 9 * (0.3 + fenv)))).fold2(1.0);
			sig = RLPF.ar(folded, cutoff.clip(100, 16000), (1 - (res * 0.7)).max(0.2));
			sig * 0.8 * env;
		});

		// 3 - DUST: cloud of sine grains
		mk.value(\micDust, -2, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var trig, f, grains, base, sig;
			trig = Dust.ar(15 + (p1 * 110));
			f = freq * (1 + TRand.ar(p3.neg * 0.08, p3 * 0.08, trig));
			grains = GrainSin.ar(1, trig, 0.015 + (p2 * 0.12), f.clip(30, 15000), TRand.ar(-0.8, 0.8, trig).clip(-1, 1));
			base = SinOsc.ar(freq) * 0.15 * (1 - p1);
			sig = (grains * 1.8) + base;
			sig = LPF.ar(sig, cutoff.clip(500, 16000));
			sig * env;
		});

		// 4 - BREATH: noise filtered on harmonic partials, with tone and vibrato
		mk.value(\micBreath, -2, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var nz, vib, f, bands, tone, sig, rq;
			vib = 1 + (SinOsc.kr(4.5 + (p3 * 2), 0, p3 * 0.012));
			f = freq * vib;
			nz = PinkNoise.ar;
			rq = 0.012 + ((1 - res) * 0.02);
			bands = (BPF.ar(nz, f.clip(40, 12000), rq) * 1.0)
				+ (BPF.ar(nz, (f * 2).clip(40, 14000), rq * 1.2) * (0.3 + (p1 * 0.9)))
				+ (BPF.ar(nz, (f * 3).clip(40, 15000), rq * 1.5) * (p1 * 0.6));
			tone = SinOsc.ar(f) * (1 - p2) * 0.5;
			sig = (bands * 14 * (0.4 + (p2 * 0.8))) + tone;
			sig = LPF.ar(sig, cutoff.clip(500, 14000));
			sig * env;
		});

		// 5 - RUST: ring modulation, sample-and-hold and bit reduction
		mk.value(\micRust, -4, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var osc, ring, mix, rate, held, step, sig;
			osc = Saw.ar(freq);
			ring = SinOsc.ar(freq * (0.5 + (p1 * 5.5)));
			mix = (osc * ring * 0.9) + (osc * 0.25);
			rate = 1500 + (p2 * p2 * 22000);
			held = Latch.ar(mix, Impulse.ar(rate));
			step = ((((1 - p3) * 9) + 2).neg * 2.log).exp;
			sig = held.round(step);
			sig = RLPF.ar(sig, cutoff.clip(200, 16000), (1 - (res * 0.6)).max(0.25));
			sig * 0.8 * env;
		});

		// 6 - CRYSTAL: phase distortion (CZ style), resonant saw
		mk.value(\micCrystal, -3, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var fenv, rz, ph1, ph2, s1, s2, sub, sig;
			fenv = EnvGen.ar(Env.perc(0.001, dur * 0.8, 1, -3));
			rz = 1 + (p1 * 14 * (0.2 + fenv));
			ph1 = Phasor.ar(0, freq * SampleDur.ir, 0, 1);
			ph2 = Phasor.ar(0, freq * (1 + (p2 * 0.012)) * SampleDur.ir, 0, 1);
			s1 = sin(ph1 * rz * 2pi) * (1 - ph1);
			s2 = sin(ph2 * rz * 2pi) * (1 - ph2);
			sub = SinOsc.ar(freq * 0.5) * p3 * 0.5;
			sig = ((s1 + s2) * 0.9) + sub;
			sig = LPF.ar(sig, cutoff.clip(300, 16000));
			sig * env;
		});

		// 7 - SWARM: six sines with random glides and tremolo
		mk.value(\micSwarm, -2, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var sig;
			sig = Mix.fill(6, { arg i;
				var st, en, fr, trem, w;
				st = (freq * Rand(0.97, 1.03) * [1, 1, 1.5, 2, 2, 3][i]).clip(40, 9000);
				en = (st * ((Rand(-1, 1) * p1 * 0.7 * 2.log).exp)).clip(40, 9000);
				fr = XLine.kr(st, en, (dur + 0.05));
				w = SinOsc.kr(Rand(3, 7), 0, p3 * 0.02, 1);
				trem = LFNoise1.kr(4 + (p2 * 22)).range(1 - (p2 * 0.9), 1);
				SinOsc.ar(fr * w) * trem * [1, 0.7, 0.5, 0.4, 0.3, 0.25][i];
			});
			sig = LPF.ar(sig * 0.5, cutoff.clip(500, 14000));
			sig * env;
		});

		// 8 - CHOIR: three detuned saws through moving vowel formants
		mk.value(\micChoir, -2, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var vib, f, src, pos, f1, f2, f3, q, sig;
			vib = 1 + SinOsc.kr(0.15 + (p3 * 4.5), 0, 0.003 + (p3 * 0.01));
			f = freq * vib;
			src = Mix.new([Saw.ar(f), Saw.ar(f * 1.005), Saw.ar(f * 0.995)]) * 0.28;
			src = src + (PinkNoise.ar * 0.05);
			pos = ((p1 * 4) + SinOsc.kr(0.05 + (p2 * 0.25), 0, p2 * 1.6)).clip(0, 4);
			f1 = SelectX.kr(pos, [800, 400, 350, 450, 325]);
			f2 = SelectX.kr(pos, [1150, 1600, 1700, 800, 700]);
			f3 = SelectX.kr(pos, [2900, 2700, 2700, 2830, 2530]);
			q = 1.2 - (res * 0.6);
			sig = (BPF.ar(src, f1, 0.1 * q) * 3) + (BPF.ar(src, f2, 0.08 * q) * 2.2) + (BPF.ar(src, f3, 0.05 * q) * 1.6);
			sig = LPF.ar(sig * 3, cutoff.clip(600, 12000));
			sig * env;
		});

		// 9 - VEIL: pad of detuned saws and pulses, a breathing filter
		mk.value(\micVeil, -2, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var det, saws, pw, pul, lfo, sig;
			det = 0.002 + (p1 * 0.012);
			saws = Mix.fill(3, { arg i; Saw.ar(freq * (1 + ((i - 1) * det))) });
			pw = 0.5 + SinOsc.kr(0.1 + (p3 * 1.2), 0, 0.35);
			pul = Mix.new([Pulse.ar(freq * (1 - det), pw), Pulse.ar(freq * (1 + det), 1 - pw)]);
			lfo = LFNoise2.kr(0.15 + (p2 * 1.5)).range(0.35, 1.2);
			sig = (saws * 0.22) + (pul * 0.2);
			sig = RLPF.ar(sig, (cutoff * lfo).clip(120, 14000), (1 - (res * 0.65)).max(0.2));
			sig * env;
		});

		// 10 - ABYSS: deep sub with beating, slow FM and rumble
		mk.value(\micAbyss, -2, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var sub, beat, fmv, rumble, sig;
			sub = SinOsc.ar(freq * 0.5) * 0.9;
			beat = SinOsc.ar(freq * 0.5 * (1 + (p1 * 0.008))) * 0.7;
			fmv = SinOsc.ar(freq, SinOsc.ar(freq * 0.25, 0, p2 * 2.2)) * 0.3;
			rumble = LPF.ar(BrownNoise.ar, 220) * p3 * 1.2;
			sig = sub + beat + fmv + rumble;
			sig = LPF.ar(sig, cutoff.clip(120, 8000));
			sig * env;
		});

		// 11 - FOG: noise made to resonate by tuned combs
		mk.value(\micFog, -2, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var nz, mod, d1, d2, sig;
			nz = PinkNoise.ar * 0.25;
			mod = LFNoise1.kr(0.1 + (p2 * 2.5)).range(0.9, 1.12);
			d1 = ((freq * mod).reciprocal).clip(0.0005, 0.2);
			d2 = ((freq * 1.5 * mod).reciprocal).clip(0.0005, 0.2);
			sig = CombC.ar(nz, 0.25, d1, 1.5 + (p1 * 7)) + (CombC.ar(nz, 0.25, d2, 1.5 + (p1 * 7)) * p3);
			sig = LPF.ar(sig * 0.7, cutoff.clip(300, 12000));
			sig * env;
		});

		// 12 - BELL: FM bell with inharmonic partials
		mk.value(\micBell, -4, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var ienv, c1, c2, c3, sig;
			ienv = EnvGen.ar(Env.perc(0.001, dur * 0.35, 1, -4));
			c1 = SinOsc.ar(freq, SinOsc.ar(freq * (1.4 + (p1 * 1.6)), 0, ienv * (1.5 + (p2 * 5))));
			c2 = SinOsc.ar(freq * 2.76, SinOsc.ar(freq * 1.41, 0, ienv * 2)) * 0.4 * EnvGen.ar(Env.perc(0.001, dur * 0.5, 1, -4));
			c3 = SinOsc.ar(freq * 5.4 * (1 + (p3 * 0.02))) * 0.2 * EnvGen.ar(Env.perc(0.001, dur * 0.2, 1, -4));
			sig = c1 + c2 + c3;
			sig = LPF.ar(sig, cutoff.clip(500, 16000));
			sig * env;
		});

		// 13 - STRING: Karplus-Strong
		mk.value(\micString, -1, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var exc, trig, sig, body, benv;
			trig = Impulse.ar(0);
			exc = (WhiteNoise.ar * (1 - (p3 * 0.6))) + (PinkNoise.ar * (p3 * 0.6));
			sig = Pluck.ar(exc * 0.6, trig, 0.2, freq.reciprocal.clip(0.0005, 0.2), dur * (0.6 + (p2 * 1.6)), p1 * 0.85);
			benv = EnvGen.ar(Env.perc(0.001, 0.09, 1, -4));
			body = SinOsc.ar(freq) * benv * p3 * 0.5;
			sig = sig + body;
			sig = LPF.ar(sig, cutoff.clip(300, 16000));
			sig * env;
		});

		// 14 - TAPE: oscillator on unstable tape, with wow, flutter and hiss
		mk.value(\micTape, -2, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var wow, flut, f, osc, hiss, sig;
			wow = SinOsc.kr(0.4 + (p1 * 0.6), 0, p1 * 0.012);
			flut = SinOsc.kr(6 + (p2 * 4), 0, p2 * 0.004) + LFNoise2.kr(3, p2 * 0.003);
			f = freq * (1 + wow + flut);
			osc = (Saw.ar(f) * 0.35) + (Pulse.ar(f * 0.5, 0.4) * 0.3);
			hiss = PinkNoise.ar * p3 * 0.06;
			sig = ((osc + hiss) * 1.4).tanh;
			sig = LPF.ar(sig, cutoff.clip(300, 10000));
			sig * env;
		});

		// 15 - GLASS: glass harmonica, pure partials with tremolo and a veil of air
		mk.value(\micGlass, -2, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var ks, as, sig, air;
			ks = [1, 2, 3, 5, 8];
			as = [1, 0.6, 0.4, 0.25, 0.15];
			sig = Mix.fill(5, { arg i;
				var f, tr;
				f = freq * ks[i] * (1 + (p1 * 0.003 * i * Rand(-1, 1)));
				tr = SinOsc.kr(0.2 + (i * 0.17) + (p2 * 2), Rand(0, 6.28), 0.4, 0.6);
				SinOsc.ar(f.min(15000)) * as[i] * tr * (f < 15000);
			});
			air = BPF.ar(PinkNoise.ar, (freq * 4).clip(200, 12000), 0.05) * p3 * 3;
			sig = LPF.ar((sig * 0.5) + air, cutoff.clip(400, 15000));
			sig * env;
		});

		// 16 - WOOD: wooden bar (marimba), few modes and a dry strike
		mk.value(\micWood, -3, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var ratios, amps, click, modes, sig;
			ratios = [1, 3.99, 9.38, 16.3];
			amps = [1, 0.35, 0.12, 0.05];
			click = Decay2.ar(Impulse.ar(0), 0.0003, 0.01) * BPF.ar(WhiteNoise.ar, (freq * 6).clip(300, 9000), 0.5) * (0.4 + (p1 * 1.5));
			modes = Mix.fill(4, { arg i;
				var f, de;
				f = freq * ratios[i] * (1 + (p3 * 0.003 * i));
				de = EnvGen.ar(Env.perc(0.001, dur * (0.25 + (p2 * 0.9)) / (1 + (i * 1.2)), 1, -4));
				SinOsc.ar(f.min(15000)) * amps[i] * de * (f < 15000);
			});
			sig = (modes * 1.5) + click;
			sig = LPF.ar(sig, cutoff.clip(400, 14000));
			sig * env;
		});

		// 17 - ORGAN: additive registers with a rotating tremolo and a key click
		mk.value(\micOrgan, -2, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var ks, as, sig, key, trem;
			ks = [0.5, 1, 1.5, 2, 3, 4, 6, 8];
			as = [0.9, 1, 0.5, 0.8, 0.4, 0.5, 0.25, 0.2];
			sig = Mix.fill(8, { arg i;
				var f, w;
				f = freq * ks[i];
				w = (1 - (((i / 7) - p1).abs * 1.4)).max(0.15);
				SinOsc.ar(f.min(15000)) * as[i] * w * (f < 15000);
			});
			key = SinOsc.ar((freq * 3).min(15000)) * EnvGen.ar(Env.perc(0.001, 0.15, 1, -4)) * p3 * 0.8;
			trem = SinOsc.kr(0.8 + (p2 * 6)).range(1 - (p2 * 0.5), 1);
			sig = ((sig * 0.14) + key) * trem;
			sig = LPF.ar(sig, cutoff.clip(500, 12000));
			sig * env;
		});

		// 18 - FLUTE: flute with breath, vibrato that arrives after the attack
		mk.value(\micFlute, -2, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var vib, f, breath, tone, sig;
			vib = 1 + (SinOsc.kr(4.8 + (p3 * 2)) * (0.002 + (p3 * 0.008)) * EnvGen.kr(Env([0, 0, 1], [0.25, 0.6])));
			f = freq * vib;
			breath = BPF.ar(PinkNoise.ar, f.clip(100, 12000), 0.3) * (0.3 + (p1 * 1.2)) * 2;
			tone = SinOsc.ar(f) + (SinOsc.ar(f * 2) * 0.25 * (1 - p2)) + (SinOsc.ar(f * 3) * 0.1 * p2);
			sig = (tone * 0.5) + (breath * (0.2 + (p2 * 0.5)));
			sig = LPF.ar(sig, cutoff.clip(500, 14000));
			sig * env;
		});

		// 19 - ACID: resonant saw with filter envelope and saturation
		mk.value(\micAcid, -3, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var fenv, src, sig;
			fenv = EnvGen.ar(Env.perc(0.003, dur * (0.2 + (p2 * 0.8)), 1, -3));
			src = (Saw.ar(freq) * (1 - (p3 * 0.4))) + (Pulse.ar(freq, 0.5) * p3 * 0.5);
			sig = RLPF.ar(src, (cutoff * (0.15 + (fenv * (0.5 + (p1 * 3))))).clip(60, 14000), (1 - (res * 0.88)).max(0.08));
			sig = (sig * (1 + (p3 * 3))).tanh * 0.7;
			sig * env;
		});

		// 20 - DROP: water drop, a sine rising in pitch plus a short echo
		mk.value(\micDrop, -4, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var sweep, f, s1, s2, sig;
			sweep = EnvGen.ar(Env.perc(0.001, 0.02 + (p1 * 0.08), 1, -3));
			f = freq * (0.75 + (sweep * (0.3 + (p1 * 1.2))));
			s1 = SinOsc.ar(f.clip(30, 15000)) * EnvGen.ar(Env.perc(0.001, dur * (0.2 + (p2 * 0.6)), 1, -4));
			s2 = SinOsc.ar((f * 2.01).clip(30, 15000)) * 0.3 * EnvGen.ar(Env.perc(0.001, dur * 0.15, 1, -5));
			sig = s1 + s2;
			sig = sig + (DelayN.ar(sig, 0.5, 0.07 + (p3 * 0.2)) * 0.35 * p3);
			sig = LPF.ar(sig, cutoff.clip(500, 16000));
			sig * env;
		});

		// 21 - REEDS: paired reeds (accordion), detuned pulses and bellows
		mk.value(\micReeds, -2, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var det, reeds, bell, sig;
			det = 0.002 + (p1 * 0.01);
			reeds = Mix.new([
				Pulse.ar(freq * (1 - det), 0.3), Pulse.ar(freq, 0.3), Pulse.ar(freq * (1 + det), 0.3),
				Pulse.ar(freq * 2 * (1 + det), 0.2) * 0.4
			]);
			bell = LFNoise2.kr(0.3 + (p3 * 1.5)).range(1 - (p3 * 0.4), 1);
			sig = RLPF.ar(reeds * 0.18, (cutoff * (0.5 + p2)).clip(300, 9000), 0.5);
			sig = (BPF.ar(sig, 1200, 0.8) * 0.6) + (sig * 0.6);
			sig * bell * env;
		});

		// 22 - STATIC: random discharges that ring three frequencies
		mk.value(\micStatic, -3, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var ratios, rings, crackle, sig;
			ratios = [1, 1.5, 2.01];
			rings = Mix.fill(3, { arg i;
				Ringz.ar(Dust.ar(40 + (p1 * 300)), (freq * ratios[i]).min(15000), 0.02 + (p2 * 0.15)) * 0.15;
			});
			crackle = BPF.ar(Dust.ar(100 + (p3 * 900)), (freq * 4).clip(300, 12000), 0.4) * 0.5;
			sig = rings + crackle;
			sig = LPF.ar(sig, cutoff.clip(500, 15000));
			sig * env;
		});

		// 23 - GONG: inharmonic modes that bloom slowly and die away slowly
		mk.value(\micGong, -2, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var ratios, sig;
			ratios = [1, 1.47, 2.09, 2.56, 3.37, 4.12, 5.7];
			sig = Mix.fill(7, { arg i;
				var f, a, de;
				f = freq * ratios[i];
				a = (1 + (i * (1.4 - p1))).reciprocal;
				de = EnvGen.ar(Env.perc(0.01 + (i * 0.03), dur * (0.4 + (p2 * 0.8)) / (1 + (i * 0.25)), 1, -2));
				(SinOsc.ar(f.min(14000)) + SinOsc.ar((f * (1 + (p3 * 0.006 * (i + 1)))).min(14000))) * 0.5 * a * de * (f < 14000);
			});
			sig = (sig * 1.3) + (Decay2.ar(Impulse.ar(0), 0.001, 0.05) * PinkNoise.ar * 0.3);
			sig = LPF.ar(sig, cutoff.clip(400, 15000));
			sig * env;
		});


		// 24 - HARP: plucked string with a ringing octave and a soft body resonance
		mk.value(\micHarp, -1, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var exc, s1, s2, body, sig;
			exc = PinkNoise.ar * Decay.ar(Impulse.ar(0), 0.004) * 1.2;
			s1 = Pluck.ar(exc, Impulse.ar(0), 0.2, freq.reciprocal.clip(0.0005, 0.2), dur * (0.8 + (p2 * 1.8)), 0.15 + (p1 * 0.6));
			s2 = Pluck.ar(exc, Impulse.ar(0), 0.2, (freq * 2).reciprocal.clip(0.0005, 0.2), dur * 0.7, 0.3 + (p1 * 0.5)) * p3 * 0.6;
			body = BPF.ar(s1, 220 + (p3 * 180), 0.6) * 0.5;
			sig = s1 + s2 + body;
			sig = LPF.ar(sig, cutoff.clip(400, 15000));
			sig * env;
		});

		// 25 - KALIMBA: thumb piano, a stiff tine with a short metallic buzz
		mk.value(\micKalimba, -3, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var ratios, amps, tines, tick, buzz, sig;
			ratios = [1, 5.4, 11.3];
			amps = [1, 0.3 + (p1 * 0.4), 0.1];
			tines = Mix.fill(3, { arg i;
				var f;
				f = (freq * ratios[i]).min(15000);
				SinOsc.ar(f) * amps[i] * EnvGen.ar(Env.perc(0.001, dur * (0.3 + (p2 * 0.8)) / (1 + (i * 1.5)), 1, -5));
			});
			tick = Decay2.ar(Impulse.ar(0), 0.0005, 0.008) * BPF.ar(WhiteNoise.ar, 3000, 0.4) * 1.5;
			buzz = (tines * 8 * p3).tanh * 0.2 * EnvGen.ar(Env.perc(0.001, 0.12, 1, -4));
			sig = (tines * 0.9) + tick + buzz;
			sig = LPF.ar(sig, cutoff.clip(500, 15000));
			sig * env;
		});

		// 26 - BRASS: saw stack, the filter swells open after the attack
		mk.value(\micBrass, -2, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var det, saws, swell, vib, sig;
			det = 0.002 + (p1 * 0.006);
			vib = 1 + (SinOsc.kr(5 + (p3 * 1.5)) * 0.003 * EnvGen.kr(Env([0, 0, 1], [0.3, 0.7])));
			saws = Mix.fill(4, { arg i; Saw.ar(freq * vib * (1 + ((i - 1.5) * det))) });
			swell = EnvGen.kr(Env([0.2, 1, 0.7], [0.08 + (p2 * 0.4), dur.max(0.2)], [2, -2]));
			sig = RLPF.ar(saws * 0.2, (cutoff * (0.3 + (swell * 1.2))).clip(150, 12000), (1 - (res * 0.5)).max(0.25));
			sig * env;
		});

		// 27 - THEREMIN: pure tone with a slow glide into each note, wide vibrato
		mk.value(\micTheremin, -2, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var f, vib, sig;
			f = XLine.kr(freq * (1 + ((p1 - 0.5) * 0.12)), freq, 0.05 + (p2 * 0.5));
			vib = SinOsc.kr(5.5 + (p3 * 2), 0, 0.004 + (p3 * 0.012));
			sig = SinOsc.ar(f * (1 + vib)) + (SinOsc.ar(f * 2 * (1 + vib)) * 0.12) + (SinOsc.ar(f * 3 * (1 + vib)) * 0.04);
			sig = LPF.ar(sig * 0.6, cutoff.clip(600, 12000));
			sig * env;
		});

		// 28 - CHIP: square with a moving duty cycle and a tiny pitch drop
		mk.value(\micChip, -3, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var f, duty, sig;
			f = freq * (1 + (EnvGen.ar(Env.perc(0.001, 0.04, 1, -4)) * p3 * 0.2));
			duty = (0.5 + (SinOsc.kr(0.5 + (p2 * 6), 0, 0.4 * p1))).clip(0.08, 0.92);
			sig = Pulse.ar(f, duty) * 0.5;
			sig = (sig * 4).round(0.25) * 0.4 + (sig * 0.3);
			sig = LPF.ar(sig, cutoff.clip(500, 14000));
			sig * env;
		});

		// 29 - SPECTRE: additive partials whose levels drift independently
		mk.value(\micSpectre, -2, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var sig;
			sig = Mix.fill(10, { arg i;
				var n, a, f;
				n = i + 1;
				f = freq * n * (1 + (p3 * 0.002 * n * n));
				a = LFNoise1.kr(0.1 + (p2 * 1.2)).range(0, 1) * (n ** (p1 * 1.6 - 1.2));
				SinOsc.ar(f.min(15000)) * a * (f < 15000);
			});
			sig = LPF.ar(sig * 0.35, cutoff.clip(500, 14000));
			sig * env;
		});

		// 30 - THUNDER: low rumble, a filtered noise burst on top of a falling sub
		mk.value(\micThunder, -3, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var sub, rumble, crack, sig;
			sub = SinOsc.ar(freq * 0.5 * XLine.kr(1.3, 1, 0.3 + (p1 * 0.6))) * 0.8;
			rumble = LPF.ar(BrownNoise.ar, 80 + (p2 * 300)) * 2.2 * EnvGen.ar(Env.perc(0.02, dur * 0.8, 1, -2));
			crack = HPF.ar(WhiteNoise.ar, 1500) * EnvGen.ar(Env.perc(0.001, 0.05, 1, -6)) * p3 * 0.6;
			sig = sub + rumble + crack;
			sig = LPF.ar(sig, cutoff.clip(120, 8000));
			sig * env;
		});

		// 31 - SITAR: plucked string through a bridge buzz
		mk.value(\micSitar, -1, { arg freq, dur, cutoff, res, p1, p2, p3, env;
			var exc, str, buzz, sig;
			exc = WhiteNoise.ar * Decay.ar(Impulse.ar(0), 0.003);
			str = Pluck.ar(exc, Impulse.ar(0), 0.2, freq.reciprocal.clip(0.0005, 0.2), dur * (0.7 + (p2 * 1.4)), 0.1 + (p1 * 0.4));
			buzz = (str * (3 + (p3 * 14))).tanh * 0.5;
			sig = (str * 0.4) + buzz + (BPF.ar(str, freq * 4, 0.2) * 0.5);
			sig = LPF.ar(sig, cutoff.clip(400, 14000));
			sig * env;
		});

		// shared reverb
		SynthDef(\micRev, {
			arg out = 0, rbus = 0, level = 0.4, room = 0.8, damp = 0.5;
			var in, wet;
			in = In.ar(rbus, 2);
			in = HPF.ar(in, 120);
			wet = FreeVerb2.ar(in[0], in[1], 1.0, room, damp);
			Out.ar(out, wet * level);
		}).add;

		// final limiter: protects the outputs when many layers add up
		SynthDef(\micMaster, {
			arg bus = 0;
			var in;
			in = In.ar(bus, 2);
			in = LeakDC.ar(in);
			// soft saturation before the limiter: peaks do not turn into crackle
			in = (in * 0.85).softclip;
			in = Limiter.ar(in, 0.9, 0.01);
			ReplaceOut.ar(bus, in);
		}).add;

		context.server.sync;

		revSynth = Synth.new(\micRev, [\out, context.out_b, \rbus, revBus], fxGroup);
		masterSynth = Synth.tail(fxGroup, \micMaster, [\bus, context.out_b]);

		this.addCommand("note", "iiffffffffffff", { arg msg;
			var v, t, now, s;
			v = (msg[1].asInteger - 1).clip(0, 3);
			t = msg[2].asInteger.clip(0, 31);
			now = SystemClock.seconds;
			// drop notes that already ended, then limit the polyphony of the voice
			voiceList[v] = voiceList[v].select({ arg e; e[1] > now });
			while({ voiceList[v].size >= 5 }, {
				// the oldest voice leaves with a short fade (no clicks)
				voiceList[v][0][0].set(\kill, 1);
				voiceList[v].removeAt(0);
			});
			s = Synth.new(defNames[t], [
				\out, context.out_b, \rbus, revBus,
				\freq, msg[3], \amp, msg[4], \dur, msg[5], \cutoff, msg[6], \res, msg[7],
				\p1, msg[8], \p2, msg[9], \p3, msg[10], \pan, msg[11], \send, msg[12],
				\atk, msg[13], \sus, msg[14]
			], synthGroup);
			voiceList[v].add([s, now + msg[13] + msg[5] + 0.2]);
		});

		// silence: fades out and frees all sounding notes (new ones are untouched)
		this.addCommand("silence", "", { arg msg;
			voiceList.do({ arg l;
				l.do({ arg e; e[0].set(\kill, 1); });
				l.clear;
			});
		});

		this.addCommand("reverb", "fff", { arg msg;
			revSynth.set(\level, msg[1], \room, msg[2], \damp, msg[3]);
		});
	}

	free {
		masterSynth.free;
		revSynth.free;
		synthGroup.free;
		fxGroup.free;
		revBus.free;
	}
}
