-- MICELIO
-- a new world grows from
-- the mycelium
--
-- by un luogo
-- moderatamente
-- sicuro
--
-- tempo, scale, sounds,
-- rhythm and visuals,
-- never the same twice.
-- the world keeps
-- evolving on its own.
--
-- K2   new world (tap)
-- K3   play / stop (tap)
-- E1   rotate / pitch
-- E2   tempo
-- E3   morph
--
-- hold K1: track select
--   E2 rotate E3 notes
--   K2 back  K3 mute
-- hold K2: world type
--   E2 reverb E3 volume
--   K3 save favorite
-- hold K3: scale, root
--   E3 engine of track
--   K2 drift on/off

engine.name = "Micelio"

local ControlSpec = require "controlspec"
local Composer = include("lib/composer")
local Visual = include("lib/visual")

local TEST = rawget(_G, "MICELIO_TEST")

local floor, sin, cos, pi = math.floor, math.sin, math.cos, math.pi
local max, min, abs = math.max, math.min, math.abs

local function clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

-- ---------------------------------------------------------------- constants

local NUM_TR = 4
local HOLD_FRAMES = 10             -- 1/3 s: longer than this, K2 and K3 count as "held", not "tapped"
local TPB = 24                      -- ticks per beat: 16th = 6, 8th = 12, quarter = 24
local DIVLIST = {3, 4, 6, 8, 12, 18, 24}
local DIV_NAMES = {"1/32", "1/16T", "1/16", "1/8T", "1/8", "1/8.", "1/4"}
local DIV_POOL = {
  bass = {6, 6, 6, 12, 12, 8, 24},
  lead = {6, 6, 6, 6, 12, 4, 8, 3, 18},
  pad  = {6, 12, 12, 24},
  perc = {6, 6, 6, 4, 8, 3, 12},
}

local ENG = {"ROOT", "BRONZE", "FOLD", "DUST", "BREATH", "RUST", "CRYSTAL", "SWARM",
             "CHOIR", "VEIL", "ABYSS", "FOG", "BELL", "STRING", "TAPE", "GLASS",
             "WOOD", "ORGAN", "FLUTE", "ACID", "DROP", "REEDS", "STATIC", "GONG",
             "HARP", "KALIMBA", "BRASS", "THEREMIN", "CHIP", "SPECTRE", "THUNDER", "SITAR"}
-- base note, lowest octave, highest octave (relative)
local ENG_BASE = {{36, 0, 1}, {60, -1, 1}, {36, 0, 1}, {60, -1, 1}, {60, -1, 0}, {48, -1, 1},
                  {48, -1, 1}, {60, -1, 0}, {48, -1, 0}, {48, -1, 0}, {24, 0, 1}, {48, -1, 1},
                  {60, -1, 1}, {48, -1, 1}, {48, -1, 1}, {60, -1, 1},
                  {60, -1, 1}, {48, -1, 1}, {60, -1, 1}, {36, 0, 1}, {72, -1, 0}, {48, -1, 1}, {60, -1, 1}, {36, 0, 1},
                  {48, -1, 1}, {60, -1, 1}, {36, 0, 1}, {60, -1, 0}, {48, -1, 1}, {48, -1, 0}, {24, 0, 1}, {48, -1, 1}}
local ENG_LEVEL = {1.0, 0.7, 0.6, 0.7, 0.8, 0.5, 0.7, 0.6, 0.8, 0.45, 0.9, 0.8, 0.6, 1.0, 0.7, 0.7,
                   0.8, 0.5, 0.7, 0.55, 0.7, 0.5, 0.55, 0.6,
                   0.9, 0.8, 0.5, 0.55, 0.5, 0.55, 0.8, 0.8}
local ENG_ATK = {0.002, 0.001, 0.002, 0.01, 0.04, 0.001, 0.003, 0.02, 0.06, 0.08, 0.1, 0.05, 0.001, 0.001, 0.01, 0.05,
                  0.001, 0.01, 0.06, 0.003, 0.001, 0.03, 0.001, 0.01,
                  0.001, 0.001, 0.05, 0.2, 0.003, 0.3, 0.004, 0.001}
local ENG_ROLE = {"bass", "lead", "bass", "pad", "pad", "perc", "lead", "pad",
                  "pad", "pad", "bass", "pad", "lead", "lead", "lead", "pad",
                  "lead", "pad", "lead", "bass", "lead", "pad", "perc", "perc",
                  "lead", "lead", "pad", "lead", "lead", "pad", "perc", "lead"}
-- struck engines: the duration is the ring time, not a gate
local PERC = {[2] = true, [6] = true, [13] = true, [14] = true, [17] = true, [21] = true, [23] = true, [24] = true,
              [25] = true, [26] = true, [31] = true, [32] = true}
local ENG_RING = {[2] = 3.0, [6] = 0.8, [13] = 3.0, [14] = 2.0, [17] = 1.6, [21] = 1.5, [23] = 0.8, [24] = 4.0, [25] = 3.0, [26] = 1.6, [31] = 3.0, [32] = 2.5}
-- engines that suit drones and scapes
local SUSTAIN = {[1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [7] = true, [8] = true,
                 [9] = true, [10] = true, [11] = true, [12] = true, [13] = true, [15] = true, [16] = true,
                 [17] = true, [18] = true, [19] = true, [20] = true, [21] = true, [22] = true, [23] = true, [24] = true,
                 [25] = true, [26] = true, [27] = true, [28] = true, [29] = true, [30] = true, [31] = true, [32] = true}

local TYPES = {"SEQ", "DRONE", "SCAPE", "MIXED"}
local TYPE_OPT = {"AUTO", "SEQ", "DRONE", "SCAPE", "MIXED"}

local SCALES = {
  {name = "MAJOR",    n = {0, 2, 4, 5, 7, 9, 11}},
  {name = "MINOR",      n = {0, 2, 3, 5, 7, 8, 10}},
  {name = "DORIAN",      n = {0, 2, 3, 5, 7, 9, 10}},
  {name = "PHRYGIAN",      n = {0, 1, 3, 5, 7, 8, 10}},
  {name = "LYDIAN",       n = {0, 2, 4, 6, 7, 9, 11}},
  {name = "MIXOLYDIAN",   n = {0, 2, 4, 5, 7, 9, 10}},
  {name = "LOCRIAN",      n = {0, 1, 3, 5, 6, 8, 10}},
  {name = "HARM MINOR",   n = {0, 2, 3, 5, 7, 8, 11}},
  {name = "MEL MINOR",   n = {0, 2, 3, 5, 7, 9, 11}},
  {name = "MAJ PENTA",   n = {0, 2, 4, 7, 9}},
  {name = "MIN PENTA",    n = {0, 3, 5, 7, 10}},
  {name = "BLUES",       n = {0, 3, 5, 6, 7, 10}},
  {name = "WHOLE TONE", n = {0, 2, 4, 6, 8, 10}},
  {name = "DIMINISHED",   n = {0, 2, 3, 5, 6, 8, 9, 11}},
  {name = "HIRAJOSHI",   n = {0, 2, 3, 7, 8}},
  {name = "INSEN",       n = {0, 1, 5, 7, 10}},
  {name = "SPANISH",    n = {0, 1, 4, 5, 7, 8, 10}},
  {name = "BYZANTINE",   n = {0, 1, 4, 5, 7, 8, 11}},
  {name = "HUNGARIAN",   n = {0, 2, 3, 6, 7, 8, 11}},
  {name = "NEAPOLITAN",  n = {0, 1, 3, 5, 7, 8, 11}},
  {name = "ENIGMATIC",  n = {0, 1, 4, 6, 8, 10, 11}},
  {name = "BEBOP",       n = {0, 2, 4, 5, 7, 9, 10, 11}},
  {name = "TRITONE",     n = {0, 1, 4, 6, 7, 10}},
  {name = "CHROMATIC",   n = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11}},
  {name = "SLENDRO",     n = {0, 2.4, 4.8, 7.1, 9.6}},
  {name = "PELOG",       n = {0, 1.2, 3.2, 7.0, 8.0}},
  {name = "19-EDO",      n = {0, 0.63, 1.26, 1.89, 2.53, 3.16, 3.79, 4.42, 5.05, 5.68, 6.32, 6.95, 7.58, 8.21, 8.84, 9.47, 10.11, 10.74, 11.37}},
  {name = "QUARTER TONE", n = {0, 1.5, 3, 4.5, 6, 7.5, 9, 10.5}},
  {name = "ARAB RAST",  n = {0, 2, 3.5, 5, 7, 9, 10.5}},
  {name = "ARAB BAYATI", n = {0, 1.5, 3, 5, 7, 8, 10}},
  {name = "7-EDO",       n = {0, 1.71, 3.43, 5.14, 6.86, 8.57, 10.29}},
  {name = "HARMONICS",   n = {0, 2.04, 3.86, 5.51, 7.02, 8.41, 9.69, 10.88}},
}
local NOTE_NAMES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

-- ------------------------------------------------------------------- state

local S = {
  seed = 1, tidx = 1, wtype = "SEQ", name = "", root = 0, scale = 1,
  playing = true, sel = 1, shift = false,
  k2 = false, k3 = false, k2used = false, k3used = false, k2f = 0, k3f = 0,
  morph = 0, mdrift = 0, rotall = 0, history = {}, cur = nil,
  lock = {tempo = false, scale = false, engine = false},
  bpm = 120, tempo = 120, tempo_touch = 0, drift = true, driftamt = 0.3, typesel = 1, favs = {}, ready = false, evo = 3,
}
local tracks = {}
local pulse = {0, 0, 0, 0}
local pdecay = {0.86, 0.86, 0.86, 0.86}
local pitchn = {0.5, 0.5, 0.5, 0.5}
local tick_count = 0
local trans = 0
local info = {lines = {}, frames = 0}
local master = 0.8
local morph_depth = 0.6
local audio_on = true
local midi_out = nil
local frame_metro, tick_clock
local FAV_PATH

-- ---------------------------------------------------------------- utilities

local function say(...)
  info.lines = {...}
  info.frames = 50
end

local function f1(x) return string.format("%.1f", x) end
local function pct(x) return floor(x * 100 + 0.5) end

-- deterministic generator: the same seed always gives the same world
local function make_rng(seed)
  local s = (floor(seed) * 2654435761 + 40503) % 4294967296
  if s == 0 then s = 2463534242 end
  local function nxt()
    s = s ~ ((s << 13) & 0xFFFFFFFF)
    s = s ~ (s >> 17)
    s = s ~ ((s << 5) & 0xFFFFFFFF)
    return s
  end
  for _ = 1, 8 do nxt() end
  local R = {}
  function R.f() return nxt() / 4294967296 end
  function R.i(a, b) return a + floor(R.f() * (b - a + 1)) end
  function R.pick(t) return t[R.i(1, #t)] end
  return R
end

local SYL = {"va", "lo", "ri", "ne", "mi", "sa", "tu", "ke", "zo", "an", "el", "or", "ul", "ix",
             "ma", "po", "de", "fi", "gra", "bru", "sol", "nu", "ta", "qui", "vel", "om", "ar", "is", "ca", "lu"}

local function make_name(r)
  local s = ""
  for _ = 1, r.i(2, 4) do s = s .. r.pick(SYL) end
  return string.upper(s)
end

local function pset(id, v) params:set(id, v, true) end

local function div_index(ticks)
  for i, d in ipairs(DIVLIST) do
    if d == ticks then return i end
  end
  return 3
end

local function degree_to_semis(d)
  local sc = SCALES[S.scale].n
  local n = #sc
  return sc[(d % n) + 1] + 12 * (d // n)
end

local function base_midi(tr, deg)
  return tr.base + 12 * tr.octave + S.root + degree_to_semis(deg)
end

-- ------------------------------------------------------------------- sound

local function morph_off(tr, j)
  local m = tr.mph[j]
  local x = S.morph
  return (0.65 * sin(x * m.f1 + m.p1) + 0.35 * sin(x * m.f2 + m.p2)) * m.dep * morph_depth
end

local function play_note(i, midi, vel, dur, atk, sus, pan_override)
  local tr = tracks[i]
  local hz = clamp(440 * 2 ^ ((midi - 69) / 12), 20, 9000)
  local cutoff = clamp(tr.cut * 2 ^ (morph_off(tr, 2) * 3.6), 80, 16000)
  local res = clamp(tr.res + morph_off(tr, 3) * 0.7, 0, 0.95)
  local p1 = clamp(tr.p1 + morph_off(tr, 4) * 1.3, 0, 1)
  local p2 = clamp(tr.p2 + morph_off(tr, 5) * 1.3, 0, 1)
  local p3 = clamp(tr.p3 + morph_off(tr, 6) * 1.3, 0, 1)
  local pan = clamp((pan_override or tr.pan) + morph_off(tr, 7) * 1.0, -1, 1)
  local gain = (tr.mode == "drone") and 0.85 or ((tr.mode == "scape") and 0.8 or 1)
  local amp = tr.level * ENG_LEVEL[tr.engine] * (vel ^ 1.2) * master * 0.6 * gain
  dur = clamp(dur, 0.05, 70)
  atk = clamp(atk, 0.001, 30)

  if audio_on then
    engine.note(i, tr.engine - 1, hz, amp, dur, cutoff, res, p1, p2, p3, pan, tr.send, atk, sus)
  end

  if midi_out and params:get("midi_on") == 2 then
    local n = clamp(floor(midi + 0.5), 0, 127)
    local ch = tr.midi_ch
    midi_out:note_on(n, clamp(floor(vel * 127), 1, 127), ch)
    clock.run(function()
      clock.sleep(atk + dur * (sus > 0 and 1 or 0.6))
      midi_out:note_off(n, 0, ch)
    end)
  end

  pulse[i] = 0.4 + 0.6 * vel
  pitchn[i] = clamp((midi - 24) / 72, 0, 1)
  Visual.hit(i, vel, pitchn[i])
end

-- a sequence note: the gate sets the length, limited by the next note
local function hash2(a, b)
  local x = sin(a * 12.9898 + b * 78.233) * 43758.5453
  return x - floor(x)
end

local function trigger(i, s, vmul)
  local tr = tracks[i]
  -- morph also acts on the sequence, deterministically and reversibly:
  -- a given morph position always gives the same variation
  local mo = abs(morph_off(tr, 8))
  local qm = floor(S.morph * 2)
  local deg = tr.deg[s]
  local p = clamp(mo * 1.8, 0, 0.7)
  if p > 0.02 then
    local h = hash2(s + i * 131, qm)
    if h < p * 0.18 and not vmul then return tr.gate[s] end     -- the note is skipped
    if h > 1 - p * 0.55 then
      deg = deg + ((hash2(s * 7 + i, qm + 5) < 0.5) and -1 or 1)
    end
  end
  local vel = clamp(tr.vel[s] * (vmul or 1) * (1 + 0.5 * morph_off(tr, 9)), 0.05, 1)
  local midi = base_midi(tr, deg)
  local steps = tr.gate[s]
  local gap = Composer.next_gap(tr, s)
  if gap < tr.len then steps = min(steps, gap * tr.ovl) end
  local gt = steps * (tr.div / TPB) * clock.get_beat_sec() * 2 ^ (morph_off(tr, 1) * 0.3)
  gt = clamp(gt, 0.04, 30)
  local e = tr.engine
  local atk, sus, dur
  if PERC[e] then
    atk, sus, dur = ENG_ATK[e], 0, clamp(gt * ENG_RING[e], 0.15, 12)
  else
    atk, sus, dur = min(ENG_ATK[e], gt * 0.5), 0.6, gt
  end
  play_note(i, midi, vel, dur, atk, sus)
  return steps
end

-- drone: very long notes that overlap and cross-fade
local function drone_note(i)
  local tr = tracks[i]
  if S.drift and math.random() < S.driftamt then
    local k = math.random(#tr.chord)
    tr.chord[k] = clamp(tr.chord[k] + ({-2, -1, 1, 2})[math.random(4)], -7, 10)
  end
  local deg = tr.chord[math.random(#tr.chord)]
  local dur = clamp(tr.dr_len * clock.get_beat_sec() * 1.35, 3, 70)
  local e = tr.engine
  local atk, sus
  if PERC[e] then
    atk, sus = ENG_ATK[e], 0
  else
    atk, sus = clamp(dur * 0.32, 1, 20), 0.5
  end
  play_note(i, base_midi(tr, deg), 0.7 + 0.3 * math.random(), dur, atk, sus)
end

-- scape: events scattered in time, with varying pitch and length
local function scape_note(i)
  local tr = tracks[i]
  tr.sc_deg = clamp(tr.sc_deg + ({-4, -3, -2, -1, 1, 2, 3, 4, 5, -5})[math.random(10)], tr.sc_lo, tr.sc_hi)
  local dur = tr.sc_dmin + math.random() * (tr.sc_dmax - tr.sc_dmin)
  local e = tr.engine
  local atk, sus
  if PERC[e] then
    atk, sus = ENG_ATK[e], 0
  else
    atk, sus = clamp(dur * (0.2 + 0.4 * math.random()), 0.3, 12), 0.2 + 0.3 * math.random()
  end
  local pan = clamp(tr.pan + (math.random() - 0.5) * 1.4, -1, 1)
  play_note(i, base_midi(tr, tr.sc_deg), 0.35 + 0.65 * math.random(), dur, atk, sus, pan)
end

local function next_scape(tr)
  local gap = 16 / tr.sc_rate
  return max(1, floor(gap * TPB * (0.35 + 1.3 * math.random())))
end

-- ------------------------------------------------------------- evolution
-- The world does not stand still: every now and then something happens, always inside
-- the scale, engines and character chosen by the seed. Each event is a musical change
-- (phrase, progression, rotation, mirroring...), never a jump to a foreign world.

local EVO_SCALE = {0, 2.2, 1, 0.45}     -- off, slow, medium, lively
local evo_cd = 40
local bpm_target, bpm_home = nil, nil

-- The only place where the script writes norns' tempo. The commanded value is kept in
-- S.tempo and never read back from clock.get_tempo(): this avoids any feedback between
-- the script's writes and the clock (which, with an external source, may answer with
-- a different value).
local function ext_clock()
  local ok, v = pcall(function() return params:get("clock_source") end)
  return ok and type(v) == "number" and v ~= 1
end

local function set_tempo(v)
  v = clamp(v, 20, 300)
  S.tempo, S.bpm = v, v
  if not ext_clock() then params:set("clock_tempo", v) end
end

local function evo_schedule()
  local k = EVO_SCALE[S.evo] or 1
  evo_cd = floor((26 + math.random() * 60) * (k > 0 and k or 1))
end

local function seq_list()
  local t = {}
  for i = 1, NUM_TR do
    if tracks[i].mode == "seq" then t[#t + 1] = i end
  end
  return t
end

local function rpick(t) return t[math.random(#t)] end

local function tname(i) return "T" .. i .. " " .. ENG[tracks[i].engine] end

local EVO = {}

function EVO.rotate()
  local sq = seq_list()
  if #sq == 0 then return nil end
  local i = rpick(sq)
  local n = rpick({1, 2, 3, 4, 6, 8, -1, -2, -3, -4})
  Composer.rotate(tracks[i], n)
  return tname(i), "ROTATE " .. n
end

function EVO.reharm()
  local sq = seq_list()
  if #sq == 0 then return nil end
  local N = tracks[sq[1]].N
  if not N then return nil end
  local newprog = Composer.make_prog(make_rng(math.random(1, 1073741823)), N)
  local done = 0
  for _, i in ipairs(sq) do
    if tracks[i].N == N and Composer.reharm(tracks[i], newprog) then done = done + 1 end
  end
  if done == 0 then return nil end
  return "NEW PROGRESSION"
end

function EVO.bar()
  local sq = seq_list()
  if #sq == 0 then return nil end
  local i = rpick(sq)
  local tr = tracks[i]
  local b = math.random(1, math.ceil(tr.len / 16))
  local r = math.random(4)
  local ok, what
  if r == 1 then ok, what = Composer.retro(tr, b), "REVERSED"
  elseif r == 2 then ok, what = Composer.invert(tr, b), "MIRRORED"
  elseif r == 3 then ok, what = Composer.regate(tr, b, rpick({0.5, 0.7, 1.4, 2})), "LENGTHS"
  else ok, what = Composer.lift(tr, b, rpick({-2, -1, 1, 2, 3})), "REGISTER" end
  if not ok then return nil end
  return tname(i), "BAR " .. b .. " " .. what
end

function EVO.phrase()
  local sq = seq_list()
  if #sq == 0 then return nil end
  local i = rpick(sq)
  local tr = tracks[i]
  if not tr.gen then return nil end
  local rg = make_rng(math.random(1, 1073741823))
  local N = #SCALES[S.scale].n
  local len = tr.len
  if math.random() < 0.4 then
    local pool = (tr.role == "pad") and {32, 48, 64} or {16, 24, 28, 32, 40, 48, 64}
    len = rpick(pool)
  end
  local prog = (tr.prog and tr.N == N) and tr.prog or Composer.make_prog(rg, N)
  local keep = tr.pos
  Composer.generate(tr, rg, {role = tr.gen.role, N = N, len = len, art = tr.gen.art,
    busy = clamp((tr.gen.busy or 0.5) + (math.random() - 0.5) * 0.5, 0.1, 1),
    prog = prog, form = nil, style = Composer.pick_style(rg, tr.gen.role)})
  tr.pos = keep % tr.len
  pset("t" .. i .. "_steps", tr.len)
  pset("t" .. i .. "_notes", tr.nact)
  return tname(i), "NEW PHRASE " .. tr.len
end

function EVO.density()
  local sq = seq_list()
  if #sq == 0 then return nil end
  local i = rpick(sq)
  local tr = tracks[i]
  local n = clamp(tr.nact + rpick({-4, -3, -2, -1, 1, 2, 3, 4}), 1, tr.len)
  if n == tr.nact then return nil end
  Composer.set_nact(tr, n)
  pset("t" .. i .. "_notes", tr.nact)
  return tname(i), "NOTES " .. tr.nact .. "/" .. tr.len
end

function EVO.stepvalue()
  local sq = seq_list()
  if #sq == 0 then return nil end
  local i = rpick(sq)
  local tr = tracks[i]
  local d = rpick(DIV_POOL[tr.role] or DIV_POOL.lead)
  if d == tr.div then return nil end
  tr.div = d
  pset("t" .. i .. "_div", div_index(d))
  return tname(i), "STEP " .. DIV_NAMES[div_index(d)]
end

function EVO.echo()
  local sq = seq_list()
  if #sq == 0 then return nil end
  local i = rpick(sq)
  tracks[i].ratch = rpick({0, 0, 0.2, 0.35, 0.5})
  return tname(i), "ECO " .. pct(tracks[i].ratch)
end

-- arrangement: a track drops out, then comes back
function EVO.arrange()
  for i = 1, NUM_TR do
    local tr = tracks[i]
    if tr.evo_mute and math.random() < 0.7 then
      tr.evo_mute, tr.mute = nil, false
      pset("t" .. i .. "_mute", 1)
      return tname(i), "COMES BACK"
    end
  end
  local live = {}
  for i = 1, NUM_TR do
    if not tracks[i].mute then live[#live + 1] = i end
  end
  if #live < 3 then return nil end
  local i = rpick(live)
  tracks[i].mute, tracks[i].evo_mute = true, true
  pset("t" .. i .. "_mute", 2)
  return tname(i), "DROPS OUT"
end

function EVO.engine()
  if S.lock.engine then return nil end
  local i = math.random(NUM_TR)
  local tr = tracks[i]
  local used = {}
  for k = 1, NUM_TR do used[tracks[k].engine] = true end
  local cand = {}
  for e = 1, #ENG do
    if not used[e] and (tr.mode == "seq" or SUSTAIN[e]) then cand[#cand + 1] = e end
  end
  if #cand == 0 then return nil end
  local e = rpick(cand)
  local b = ENG_BASE[e]
  tr.engine = e
  tr.base = b[1] + 12 * clamp(rpick({-1, 0, 0, 1}), b[2], b[3])
  pset("t" .. i .. "_engine", e)
  return "T" .. i .. " BECOMES", ENG[e]
end

function EVO.timbre()
  local i = math.random(NUM_TR)
  local tr = tracks[i]
  tr.cut = clamp(tr.cut * 2 ^ ((math.random() - 0.5) * 1.6), 100, 12000)
  tr.res = clamp(tr.res + (math.random() - 0.5) * 0.4, 0, 0.9)
  tr.p1 = clamp(tr.p1 + (math.random() - 0.5) * 0.6, 0, 1)
  tr.p2 = clamp(tr.p2 + (math.random() - 0.5) * 0.6, 0, 1)
  tr.p3 = clamp(tr.p3 + (math.random() - 0.5) * 0.6, 0, 1)
  tr.pan = clamp(tr.pan + (math.random() - 0.5) * 0.8, -0.9, 0.9)
  return tname(i), "TIMBRE"
end

function EVO.modulate()
  if S.lock.scale then return nil end
  S.root = (S.root + rpick({7, 5, 2, 10, 3, 9})) % 12
  pset("root", S.root + 1)
  return "MODULATES", "ROOT " .. NOTE_NAMES[S.root + 1]
end

function EVO.tempo()
  if S.lock.tempo or ext_clock() then return nil end
  bpm_home = bpm_home or S.bpm
  bpm_target = clamp(bpm_home * (0.8 + 0.4 * math.random()), 20, 300)
  return "TEMPO DRIFTS TO " .. f1(bpm_target)
end

function EVO.drone(only)
  local list = {}
  for i = 1, NUM_TR do
    if tracks[i].mode == "drone" and (not only or only == i) then list[#list + 1] = i end
  end
  if #list == 0 then return nil end
  local i = rpick(list)
  local tr = tracks[i]
  local N = #SCALES[S.scale].n
  local t3, f5 = Composer.chord(N)
  local ch = {rpick({0, t3, f5, -t3})}
  for _ = 2, math.random(1, 3) do ch[#ch + 1] = rpick({0, t3, f5, N, N + t3}) end
  tr.chord = ch
  tr.dr_len = clamp(floor(tr.dr_len * rpick({0.7, 0.85, 1.2, 1.5})), 8, 70)
  return tname(i), "NEW CHORD"
end

function EVO.scape(only)
  local list = {}
  for i = 1, NUM_TR do
    if tracks[i].mode == "scape" and (not only or only == i) then list[#list + 1] = i end
  end
  if #list == 0 then return nil end
  local i = rpick(list)
  local tr = tracks[i]
  tr.sc_rate = clamp(tr.sc_rate + rpick({-3, -2, -1, 1, 2, 3}), 1, 14)
  local sh = rpick({-3, -2, 0, 2, 3})
  tr.sc_lo, tr.sc_hi = tr.sc_lo + sh, tr.sc_hi + sh
  tr.sc_dmin = clamp(tr.sc_dmin * rpick({0.7, 1, 1.4}), 1, 14)
  tr.sc_dmax = max(tr.sc_dmin + 2, clamp(tr.sc_dmax * rpick({0.7, 1, 1.4}), 3, 30))
  return tname(i), "SCAPE CHANGES"
end

function EVO.reverb()
  local v = clamp(params:get("reverb") + (math.random() - 0.5) * 0.4, 0.05, 0.9)
  params:set("reverb", v)
  return "REVERB " .. pct(v)
end

function EVO.scene()
  S.sig = Visual.build(make_rng(math.random(1, 1073741823)))
  trans = 0.45
  return nil
end

-- surprise: a sequence melts into a drone or scape, or goes back to a sequence
function EVO.metamorph()
  local i = math.random(NUM_TR)
  local tr = tracks[i]
  if tr.mode == "seq" then
    if #seq_list() < 2 then return nil end
    tr.mode = rpick({"drone", "scape"})
    tr.dr_cnt, tr.sc_next = 1, 1
    pdecay[i] = (tr.mode == "drone") and 0.985 or 0.96
    return tname(i), "BECOMES " .. (tr.mode == "drone" and "DRONE" or "PAESAGGIO")
  end
  tr.mode = "seq"
  tr.pos = 0
  pdecay[i] = 0.86
  return tname(i), "BACK TO SEQUENCE"
end

local EVO_TABLE = {
  {2.0, EVO.rotate}, {2.0, EVO.reharm}, {3.0, EVO.bar}, {1.6, EVO.phrase}, {2.0, EVO.density},
  {1.0, EVO.stepvalue}, {1.0, EVO.echo}, {1.6, EVO.arrange}, {1.4, EVO.engine}, {2.0, EVO.timbre},
  {1.4, EVO.modulate}, {2.0, EVO.tempo}, {2.0, EVO.drone}, {2.0, EVO.scape}, {1.4, EVO.reverb},
  {2.5, EVO.scene}, {0.9, EVO.metamorph},
}

local function evo_event()
  local total = 0
  for _, e in ipairs(EVO_TABLE) do total = total + e[1] end
  for _ = 1, 10 do
    local r = math.random() * total
    for _, e in ipairs(EVO_TABLE) do
      r = r - e[1]
      if r <= 0 then
        local a, b = e[2]()
        if a or e[2] == EVO.scene then
          if a then say(a, b) end
          S.evocount = (S.evocount or 0) + 1
          return true
        end
        break
      end
    end
  end
  return false
end

local function evo_beat()
  -- tempo glides slowly toward its target; it pauses while the user turns E2
  if ext_clock() then
    bpm_target = nil
    local seen = clock.get_tempo()
    if type(seen) == "number" then S.tempo, S.bpm = seen, seen end
  elseif bpm_target and not S.lock.tempo and S.tempo_touch <= 0 then
    local d = bpm_target - S.tempo
    if abs(d) < 0.06 then
      bpm_target = nil
    else
      set_tempo(S.tempo + clamp(d, -0.08, 0.08))
    end
  end
  if S.drift and S.evo > 1 then
    evo_cd = evo_cd - 1
    if evo_cd <= 0 then
      evo_event()
      evo_schedule()
    end
  end
end

local function tick()
  if tick_count % TPB == 0 then evo_beat() end
  for i = 1, NUM_TR do
    local tr = tracks[i]
    if tr.mode == "seq" then
      if tick_count % tr.div == 0 then
        tr.pos = tr.pos % tr.len + 1
        if tr.pos == 1 and S.drift and math.random() < S.driftamt then Composer.mutate(tr) end
        if tr.pat[tr.pos] and not tr.mute then
          local steps = trigger(i, tr.pos)
          -- echo: one softer repeat at half a step, short notes only
          if tr.ratch > 0 and steps <= 1.2 and math.random() < tr.ratch then
            local pos = tr.pos
            clock.run(function()
              clock.sleep(tr.div / TPB * clock.get_beat_sec() * 0.5)
              if S.playing and not tr.mute then trigger(i, pos, 0.5) end
            end)
          end
        end
      end
    elseif tr.mode == "drone" then
      tr.dr_cnt = tr.dr_cnt - 1
      if tr.dr_cnt <= 0 then
        if not tr.mute then drone_note(i) end
        tr.dr_cnt = floor(tr.dr_len * TPB * (0.9 + 0.2 * math.random()))
      end
    else
      tr.sc_next = tr.sc_next - 1
      if tr.sc_next <= 0 then
        if not tr.mute then scape_note(i) end
        tr.sc_next = next_scape(tr)
      end
    end
  end
  tick_count = tick_count + 1
end

local function tick_loop()
  while true do
    clock.sync(1 / TPB)
    if S.playing then tick() end
  end
end

local function restart_positions()
  tick_count = 0
  for i = 1, NUM_TR do
    local tr = tracks[i]
    tr.pos = 0
    tr.dr_cnt = 1 + (i - 1) * 6
    tr.sc_next = 1 + (i - 1) * 12
  end
end

-- ------------------------------------------------------ parameter sync

local function sync_params()
  pset("scale", S.scale)
  pset("root", S.root + 1)
  pset("seed", S.seed)
  pset("worldtype", S.typesel)
  pset("drift", S.drift and 2 or 1)
  for i = 1, NUM_TR do
    local tr = tracks[i]
    pset("t" .. i .. "_engine", tr.engine)
    pset("t" .. i .. "_steps", tr.len)
    pset("t" .. i .. "_notes", tr.nact)
    pset("t" .. i .. "_div", div_index(tr.div))
    pset("t" .. i .. "_level", tr.level)
    pset("t" .. i .. "_mute", tr.mute and 2 or 1)
    pset("t" .. i .. "_octave", tr.octave)
  end
end

local function set_scale(v)
  S.scale = clamp(v, 1, #SCALES)
  pset("scale", S.scale)
  say(SCALES[S.scale].name, "ROOT " .. NOTE_NAMES[S.root + 1])
end

local function set_root(v)
  S.root = v % 12
  pset("root", S.root + 1)
  say(SCALES[S.scale].name, "ROOT " .. NOTE_NAMES[S.root + 1])
end

local function set_mute(i, m)
  tracks[i].mute = m
  pset("t" .. i .. "_mute", m and 2 or 1)
  say("TRACK " .. i .. " " .. ENG[tracks[i].engine], m and "MUTE" or "ON")
end

local function set_engine(i, e)
  tracks[i].engine = clamp(e, 1, #ENG)
  pset("t" .. i .. "_engine", tracks[i].engine)
  say("TRACK " .. i, ENG[tracks[i].engine])
end

-- ---------------------------------------------------- world generation

local function load_seed(seed, force_t)
  seed = clamp(floor(seed), 1, 4294967295)
  local r = make_rng(seed)
  local wname = make_name(r)
  local roll = r.f()
  local scale_r = r.i(1, #SCALES)
  local root_r = r.i(0, 11)
  local vseed = r.i(1, 1073741823)

  local tidx
  if force_t then
    tidx = force_t
  elseif S.typesel > 1 then
    tidx = S.typesel - 1
  else
    tidx = roll < 0.36 and 1 or (roll < 0.58 and 2 or (roll < 0.80 and 3 or 4))
  end
  S.seed, S.tidx, S.wtype, S.name = seed, tidx, TYPES[tidx], wname
  S.cur = {s = seed, t = tidx}
  local rt = make_rng(seed + 977 * tidx)

  if not S.lock.scale then
    S.scale, S.root = scale_r, root_r
  end
  local N = #SCALES[S.scale].n

  -- continuous tempo: every world has its own, never two alike
  local bpm
  if tidx == 1 then bpm = 52 + rt.f() * 110
  elseif tidx == 2 then bpm = 34 + rt.f() * 56
  elseif tidx == 3 then bpm = 34 + rt.f() * 70
  else bpm = 44 + rt.f() * 100 end
  if not S.lock.tempo then
    set_tempo(bpm)
  end

  local ambient = (tidx == 2 or tidx == 3)
  local rev = ambient and (0.35 + rt.f() * 0.45) or (0.15 + rt.f() * 0.5)
  local room = ambient and (0.8 + rt.f() * 0.19) or (0.55 + rt.f() * 0.4)
  local damp = rt.f()
  S.mdrift = (tidx == 1) and ((rt.f() < 0.5) and 0 or rt.f() * 0.04) or (0.02 + rt.f() * 0.12)
  S.morph = 0

  -- mode of each track
  local modes
  if tidx == 1 then modes = {"seq", "seq", "seq", "seq"}
  elseif tidx == 2 then modes = {"drone", "drone", "drone", "drone"}
  elseif tidx == 3 then modes = {"scape", "scape", "scape", "scape"}
  else modes = {"drone", rt.pick({"scape", "seq"}), "seq", rt.pick({"seq", "scape"})} end

  -- random order of the engines
  local shuf = {}
  for k = 1, #ENG do shuf[k] = k end
  for k = #ENG, 2, -1 do
    local j = rt.i(1, k)
    shuf[k], shuf[j] = shuf[j], shuf[k]
  end
  local used = {}
  local function take(sustain)
    for _, e in ipairs(shuf) do
      if not used[e] and (not sustain or SUSTAIN[e]) then
        used[e] = true
        return e
      end
    end
    return 1
  end

  local prog = Composer.make_prog(rt, N)
  local wform = (rt.f() < 0.6) and Composer.pick_form(rt, 4) or nil
  local t3, f5 = Composer.chord(N)

  for i = 1, NUM_TR do
    local tr = tracks[i]
    local mode = modes[i]
    local e
    if S.lock.engine then e = tr.engine else e = take(mode ~= "seq") end
    tr.engine, tr.mode = e, mode

    local role = ENG_ROLE[e]
    if rt.f() < 0.2 then role = rt.pick({"lead", "bass", "pad"}) end
    local b = ENG_BASE[e]
    tr.base = b[1] + 12 * clamp(rt.pick({-1, 0, 0, 1}), b[2], b[3])
    tr.octave = 0; tr.rot = 0
    tr.level, tr.mute = 0.8, false
    tr.cut, tr.res = 300 * 30 ^ rt.f(), rt.f() * 0.8
    tr.p1, tr.p2, tr.p3 = rt.f(), rt.f(), rt.f()
    tr.pan = rt.f() * 1.4 - 0.7
    tr.send = ambient and (0.3 + rt.f() * 0.5) or (rt.f() * 0.5)
    tr.ratch = (rt.f() < 0.45) and (rt.f() * 0.35) or 0
    for j = 1, 9 do
      tr.mph[j] = {
        f1 = 0.6 + rt.f() * 2.2, p1 = rt.f() * 2 * pi,
        f2 = 1.7 + rt.f() * 3.0, p2 = rt.f() * 2 * pi,
        dep = 0.5 + 0.5 * rt.f(),
      }
    end

    -- sequence
    local len
    if role == "pad" then len = rt.pick({32, 32, 48, 64})
    elseif role == "bass" then len = rt.pick({16, 16, 24, 32, 32, 48, 64})
    elseif role == "perc" then len = rt.pick({16, 16, 24, 32})
    else len = rt.pick({16, 24, 28, 32, 32, 40, 48, 64}) end
    local art
    if role == "pad" then art = "legato"
    elseif role == "perc" then art = "stacc"
    elseif role == "bass" then art = rt.pick({"mixed", "stacc", "legato"})
    else art = rt.pick({"mixed", "mixed", "stacc", "legato"}) end
    tr.div = rt.pick(DIV_POOL[role])
    tr.ovl = (role == "pad") and 1.6 or ((role == "bass") and 1.05 or 1.0)
    tr.role = role
    Composer.generate(tr, rt, {role = role, N = N, len = len, art = art, busy = rt.f() * 0.9,
                               prog = prog, form = wform, style = Composer.pick_style(rt, role)})

    -- drone
    tr.dr_len = rt.i(10, 56)
    tr.dr_cnt = rt.i(1, 36)
    tr.chord = {rt.pick({0, 0, t3, f5})}
    for _ = 2, rt.i(1, 3) do tr.chord[#tr.chord + 1] = rt.pick({0, t3, f5, N}) end

    -- scape
    tr.sc_rate = rt.i(2, 10)
    tr.sc_next = rt.i(1, 48)
    tr.sc_deg = rt.pick({0, t3, f5})
    tr.sc_lo, tr.sc_hi = -t3, N + f5 + t3
    tr.sc_dmin = 2 + rt.f() * 4
    tr.sc_dmax = tr.sc_dmin + 3 + rt.f() * 10

    pdecay[i] = (mode == "drone") and 0.985 or ((mode == "scape") and 0.96 or 0.86)
  end

  params:set("reverb", rev, true)
  params:set("room", room, true)
  params:set("damp", damp, true)
  engine.reverb(rev, room, damp)

  if params:get("fade_mode") == 1 then engine.silence() end
  S.rotall = 0
  tick_count = 0
  bpm_target, bpm_home = nil, S.bpm
  evo_schedule()
  for i = 1, NUM_TR do pulse[i] = 0; tracks[i].evo_mute = nil end
  S.sig = Visual.build(make_rng(vseed))
  trans = 1
  sync_params()

  say(wname, S.wtype .. " " .. f1(S.bpm) .. "BPM", SCALES[S.scale].name .. " " .. NOTE_NAMES[S.root + 1])
  info.frames = 75

  if TEST then
    local w = {seed = seed, bpm = S.bpm, wtype = S.wtype, sig = S.sig, name = wname, engines = {}, lens = {}, divs = {}}
    for i = 1, NUM_TR do
      w.engines[i], w.lens[i], w.divs[i] = tracks[i].engine, tracks[i].len, tracks[i].div
    end
    TEST.worlds[#TEST.worlds + 1] = w
  end
end

local function new_random()
  if S.cur then
    S.history[#S.history + 1] = S.cur
    if #S.history > 64 then table.remove(S.history, 1) end
  end
  load_seed(math.random(1, 4294967295))
end

local function go_back()
  local h = table.remove(S.history)
  if h then
    load_seed(h.s, h.t)
  else
    say("NO PREVIOUS", "WORLD")
  end
end

-- ---------------------------------------------------------------- favorites

local function favs_load()
  S.favs = {}
  local ok, t = pcall(function() return tab.load(FAV_PATH) end)
  if ok and type(t) == "table" then S.favs = t end
end

local function favs_save()
  pcall(function()
    util.make_dir(_path.data .. "micelio")
    tab.save(S.favs, FAV_PATH)
  end)
end

local function save_fav()
  if not S.cur then return end
  for n, f in ipairs(S.favs) do
    if f.s == S.cur.s and f.t == S.cur.t then
      say("ALREADY SAVED", "FAVORITE " .. n)
      return
    end
  end
  if #S.favs >= 64 then table.remove(S.favs, 1) end
  S.favs[#S.favs + 1] = {s = S.cur.s, t = S.cur.t}
  favs_save()
  say(S.name .. " SAVED", "FAVORITE " .. #S.favs)
end

-- ---------------------------------------------------------------- actions

local function set_play(p)
  S.playing = p
  if p then restart_positions() else engine.silence() end
  say(p and "PLAY" or "STOP")
end

local function change_tempo(d)
  local step = (abs(d) >= 3) and d * 1.5 or d * 0.5
  if ext_clock() then
    say("EXTERNAL CLOCK", "SET TEMPO ON SOURCE")
    return
  end
  set_tempo(S.tempo + step)
  S.tempo_touch = 90
  bpm_target, bpm_home = nil, S.tempo
  say("TEMPO " .. f1(S.tempo))
end

local function change_morph(d)
  S.morph = S.morph + d
  say("MORPH " .. f1(S.morph))
end

-- rotation of any track kind. Sequences rotate their steps; drones rotate the voicing of
-- their chord (inversion); scapes slide their register window. Only future notes are
-- affected (nothing is retriggered), so it can never cause crackle.
local function rotate_track(tr, n)
  local N = #SCALES[S.scale].n
  if tr.mode == "seq" then
    Composer.rotate(tr, n)
  elseif tr.mode == "drone" then
    table.sort(tr.chord)
    if n > 0 then
      local v = table.remove(tr.chord, 1)
      tr.chord[#tr.chord + 1] = clamp(v + N, -7, 14)
    else
      local v = table.remove(tr.chord)
      table.insert(tr.chord, 1, clamp(v - N, -14, 10))
    end
    tr.rot = (tr.rot or 0) + n
  else
    local sh = clamp(tr.sc_lo + n, -7, 12) - tr.sc_lo
    tr.sc_lo, tr.sc_hi = tr.sc_lo + sh, tr.sc_hi + sh
    tr.sc_deg = clamp(tr.sc_deg + sh, tr.sc_lo, tr.sc_hi)
    tr.rot = (tr.rot or 0) + n
  end
end

local function rotate_all(n)
  for i = 1, NUM_TR do rotate_track(tracks[i], n) end
  S.rotall = S.rotall + n
  say("ROTATE " .. S.rotall)
end

local function rotate_sel(n)
  local tr = tracks[S.sel]
  rotate_track(tr, n)
  say("TRACK " .. S.sel .. " " .. ENG[tr.engine], "ROTATE " .. (tr.rot or 0))
end

local function change_density(d)
  local tr = tracks[S.sel]
  if tr.mode == "seq" then
    Composer.set_nact(tr, tr.nact + d)
    pset("t" .. S.sel .. "_notes", tr.nact)
    say("TRACK " .. S.sel .. " " .. ENG[tr.engine], "NOTES " .. tr.nact .. "/" .. tr.len)
  elseif tr.mode == "drone" then
    tr.level = clamp(tr.level + d * 0.04, 0, 1)
    pset("t" .. S.sel .. "_level", tr.level)
    say("TRACK " .. S.sel .. " " .. ENG[tr.engine], "LEVEL " .. pct(tr.level))
  else
    tr.sc_rate = clamp(tr.sc_rate + d, 1, 16)
    say("TRACK " .. S.sel .. " " .. ENG[tr.engine], "EVENTS " .. tr.sc_rate)
  end
end

local function set_typesel(v)
  S.typesel = clamp(v, 1, #TYPE_OPT)
  pset("worldtype", S.typesel)
  say("NEXT WORLD", TYPE_OPT[S.typesel])
end

local function toggle_drift()
  S.drift = not S.drift
  pset("drift", S.drift and 2 or 1)
  say("DRIFT", S.drift and "ON" or "OFF")
end

-- ------------------------------------------------------------ keys and encoders

function key(n, z)
  if n == 1 then
    S.shift = (z == 1)
  elseif n == 2 then
    if z == 1 then
      S.k2, S.k2used, S.k2f = true, false, 0
      if S.shift then
        go_back()
        S.k2used = true
      elseif S.k3 then
        toggle_drift()
        S.k2used, S.k3used = true, true
      end
    else
      S.k2 = false
      -- short tap = new world; long hold without using anything = nothing
      if not S.k2used and S.k2f < HOLD_FRAMES then new_random() end
    end
  elseif n == 3 then
    if z == 1 then
      S.k3, S.k3used, S.k3f = true, false, 0
      if S.shift then
        set_mute(S.sel, not tracks[S.sel].mute)
        S.k3used = true
      elseif S.k2 then
        save_fav()
        S.k2used, S.k3used = true, true
      end
    else
      S.k3 = false
      if not S.k3used and S.k3f < HOLD_FRAMES then set_play(not S.playing) end
    end
  end
end

function enc(n, d)
  local sgn = d > 0 and 1 or -1
  if S.shift then
    if n == 1 then
      S.sel = clamp(S.sel + sgn, 1, NUM_TR)
      local tr = tracks[S.sel]
      say("TRACK " .. S.sel, ENG[tr.engine] .. " " .. tr.mode:upper())
    elseif n == 2 then
      rotate_sel(sgn)
    else
      change_density(sgn)
    end
  elseif S.k2 then
    S.k2used = true
    if n == 1 then
      set_typesel(S.typesel + sgn)
    elseif n == 2 then
      local v = clamp(params:get("reverb") + d * 0.02, 0, 1)
      params:set("reverb", v)
      say("REVERB " .. pct(v))
    else
      local v = clamp(params:get("level") + d * 0.02, 0, 1)
      params:set("level", v)
      say("VOLUME " .. pct(v))
    end
  elseif S.k3 then
    S.k3used = true
    if n == 1 then
      set_scale(clamp(S.scale + sgn, 1, #SCALES))
    elseif n == 2 then
      set_root(S.root + sgn)
    else
      set_engine(S.sel, clamp(tracks[S.sel].engine + sgn, 1, #ENG))
    end
  else
    if n == 1 then
      rotate_all(sgn)
    elseif n == 2 then
      change_tempo(d)
    else
      change_morph(d * 0.25)
    end
  end
end

-- ------------------------------------------------------------------- screen

local function fit(s)
  s = tostring(s)
  while #s > 1 and screen.text_extents(s) > 124 do s = s:sub(1, #s - 1) end
  return s
end

local function info_lines()
  if S.shift then
    local tr = tracks[S.sel]
    local l2, l3
    if tr.mode == "seq" then
      l2, l3 = "E2 ROTATE " .. tr.rot, "E3 NOTES " .. tr.nact .. "/" .. tr.len
    elseif tr.mode == "drone" then
      l2 = "E2 ROTATE " .. (tr.rot or 0)
      l3 = "E3 LEVEL " .. pct(tr.level)
    else
      l2 = "E2 ROTATE " .. (tr.rot or 0)
      l3 = "E3 EVENTS " .. tr.sc_rate
    end
    return {"E1 TR" .. S.sel .. " " .. ENG[tr.engine], l2, l3,
            "K2 BACK  K3 " .. (tr.mute and "ON" or "MUTE")}
  elseif S.k2 and S.k2f >= HOLD_FRAMES then
    return {"E1 TYPE " .. TYPE_OPT[S.typesel], "E2 REVERB " .. pct(params:get("reverb")),
            "E3 VOLUME " .. pct(params:get("level")), "K3 SAVE WORLD"}
  elseif S.k3 and S.k3f >= HOLD_FRAMES then
    return {"E1 " .. SCALES[S.scale].name, "E2 ROOT " .. NOTE_NAMES[S.root + 1],
            "E3 TR" .. S.sel .. " " .. ENG[tracks[S.sel].engine], "K2 DRIFT " .. (S.drift and "ON" or "OFF")}
  elseif info.frames > 0 then
    return info.lines
  end
  return nil
end

local function draw_info()
  local lines = info_lines()
  if not lines or #lines == 0 then return end
  local n = #lines
  local top = 63 - n * 9
  screen.level(0)
  screen.rect(0, top, 128, 64 - top)
  screen.fill()
  screen.level(15)
  screen.font_size(8)
  for k, line in ipairs(lines) do
    screen.move(2, top + 7 + (k - 1) * 9)
    screen.text(fit(line))
  end
end

function redraw()
  screen.clear()
  screen.aa(0)
  screen.line_width(1)
  Visual.draw()
  screen.aa(0)
  screen.line_width(1)
  if trans > 0 then
    screen.level(clamp(floor(trans * trans * 14 + 0.5), 0, 15))
    screen.rect(0, 0, 128, 64)
    screen.fill()
  end
  if not S.playing then
    screen.level(15)
    screen.rect(120, 2, 2, 7)
    screen.rect(124, 2, 2, 7)
    screen.fill()
  end
  draw_info()
  screen.update()
end

local function frame()
  if S.tempo_touch > 0 then S.tempo_touch = S.tempo_touch - 1 end
  if S.k2 then S.k2f = S.k2f + 1 end
  if S.k3 then S.k3f = S.k3f + 1 end
  for i = 1, NUM_TR do
    pulse[i] = pulse[i] * pdecay[i]
    if pulse[i] < 0.02 then pulse[i] = 0 end
  end
  if S.playing then S.morph = S.morph + S.mdrift / 30 end
  Visual.update()
  if trans > 0 then trans = max(0, trans - 0.08) end
  if info.frames > 0 then info.frames = info.frames - 1 end
  redraw()
end

-- ------------------------------------------------------------------ parameters

local function build_params()
  params:add_separator("MICELIO")

  params:add_number("seed", "seed", 1, 4294967295, 1)
  params:add_trigger("seed_go", "generate from seed")
  params:set_action("seed_go", function()
    if not S.ready then return end
    if S.cur then S.history[#S.history + 1] = S.cur end
    load_seed(params:get("seed"))
  end)

  params:add_number("fav_slot", "favorite slot", 1, 64, 1)
  params:add_trigger("fav_load", "load favorite")
  params:set_action("fav_load", function()
    if not S.ready then return end
    local f = S.favs[params:get("fav_slot")]
    if f then
      if S.cur then S.history[#S.history + 1] = S.cur end
      load_seed(f.s, f.t)
    else
      say("EMPTY SLOT")
    end
  end)
  params:add_trigger("fav_clear", "delete favorite")
  params:set_action("fav_clear", function()
    if not S.ready then return end
    local n = params:get("fav_slot")
    if S.favs[n] then
      table.remove(S.favs, n)
      favs_save()
      say("FAVORITE " .. n, "DELETED")
    end
  end)

  params:add_option("fade_mode", "tails", {"cut", "ring out"}, 1)
  params:add_option("worldtype", "world type", TYPE_OPT, 1)
  params:set_action("worldtype", function(v) S.typesel = v end)

  params:add_option("drift", "drift", {"off", "on"}, 2)
  params:set_action("drift", function(v) S.drift = (v == 2) end)
  params:add_option("evo", "evolution", {"off", "slow", "medium", "lively"}, 3)
  params:set_action("evo", function(v) S.evo = v; evo_schedule() end)
  params:add_control("driftamt", "drift amount", ControlSpec.new(0, 1, "lin", 0.01, 0.3))
  params:set_action("driftamt", function(v) S.driftamt = v end)

  local sc_names = {}
  for i, sc in ipairs(SCALES) do sc_names[i] = sc.name end
  params:add_option("scale", "scale", sc_names, 1)
  params:set_action("scale", function(v) S.scale = v end)
  params:add_option("root", "root", NOTE_NAMES, 1)
  params:set_action("root", function(v) S.root = v - 1 end)

  params:add_control("level", "volume", ControlSpec.new(0, 1, "lin", 0.01, 0.8))
  params:set_action("level", function(v) master = v end)
  params:add_control("morph_depth", "morph depth", ControlSpec.new(0, 1, "lin", 0.01, 0.6))
  params:set_action("morph_depth", function(v) morph_depth = v end)

  params:add_group("REVERB", 3)
  local function rev_update()
    engine.reverb(params:get("reverb"), params:get("room"), params:get("damp"))
  end
  params:add_control("reverb", "level", ControlSpec.new(0, 1, "lin", 0.01, 0.35))
  params:set_action("reverb", rev_update)
  params:add_control("room", "room", ControlSpec.new(0, 1, "lin", 0.01, 0.8))
  params:set_action("room", rev_update)
  params:add_control("damp", "damping", ControlSpec.new(0, 1, "lin", 0.01, 0.5))
  params:set_action("damp", rev_update)

  params:add_group("LOCKS", 3)
  params:add_option("lock_tempo", "lock tempo", {"no", "yes"}, 1)
  params:set_action("lock_tempo", function(v) S.lock.tempo = (v == 2) end)
  params:add_option("lock_scale", "lock scale", {"no", "yes"}, 1)
  params:set_action("lock_scale", function(v) S.lock.scale = (v == 2) end)
  params:add_option("lock_engine", "lock engines", {"no", "yes"}, 1)
  params:set_action("lock_engine", function(v) S.lock.engine = (v == 2) end)

  for i = 1, NUM_TR do
    params:add_group("TRACK " .. i, 8)
    params:add_option("t" .. i .. "_engine", "engine", ENG, i)
    params:set_action("t" .. i .. "_engine", function(v) tracks[i].engine = v end)
    params:add_number("t" .. i .. "_steps", "length", 1, 64, 16)
    params:set_action("t" .. i .. "_steps", function(v)
      if tracks[i].len ~= v then
        Composer.fit_len(tracks[i], v)
        pset("t" .. i .. "_notes", tracks[i].nact)
      end
    end)
    params:add_number("t" .. i .. "_notes", "notes", 0, 64, 8)
    params:set_action("t" .. i .. "_notes", function(v)
      if tracks[i].nact ~= v then Composer.set_nact(tracks[i], v) end
    end)
    params:add_option("t" .. i .. "_div", "step value", DIV_NAMES, 3)
    params:set_action("t" .. i .. "_div", function(v) tracks[i].div = DIVLIST[v] end)
    params:add_control("t" .. i .. "_level", "level", ControlSpec.new(0, 1, "lin", 0.01, 0.8))
    params:set_action("t" .. i .. "_level", function(v) tracks[i].level = v end)
    params:add_option("t" .. i .. "_mute", "mute", {"no", "yes"}, 1)
    params:set_action("t" .. i .. "_mute", function(v) tracks[i].mute = (v == 2) end)
    params:add_number("t" .. i .. "_octave", "octave", -2, 2, 0)
    params:set_action("t" .. i .. "_octave", function(v) tracks[i].octave = v end)
    params:add_number("t" .. i .. "_midi", "midi channel", 1, 16, i)
    params:set_action("t" .. i .. "_midi", function(v) tracks[i].midi_ch = v end)
  end

  params:add_group("MIDI / AUDIO", 3)
  params:add_option("audio", "internal sound", {"off", "on"}, 2)
  params:set_action("audio", function(v) audio_on = (v == 2) end)
  params:add_option("midi_on", "midi out", {"off", "on"}, 1)
  params:add_number("midi_dev", "midi device", 1, 4, 1)
  params:set_action("midi_dev", function(v) midi_out = midi.connect(v) end)
end

-- ------------------------------------------------------------------------ init

function init()
  math.randomseed(os.time() + floor(os.clock() * 1000))
  FAV_PATH = _path.data .. "micelio/favs.data"

  for i = 1, NUM_TR do
    local tr = {
      engine = i, mode = "seq", role = "lead", len = 16, nact = 0, rot = 0, div = 6, pos = 0, ovl = 1,
      pat = {}, deg = {}, vel = {}, gate = {}, imp = {}, mph = {}, order = {}, lo = -2, hi = 9,
      level = 0.8, mute = false, octave = 0, base = 48,
      cut = 2000, res = 0.3, p1 = 0.5, p2 = 0.5, p3 = 0.5,
      pan = 0, send = 0.2, midi_ch = i, ratch = 0,
      dr_len = 24, dr_cnt = 1, chord = {0},
      sc_rate = 4, sc_next = 1, sc_deg = 0, sc_lo = -2, sc_hi = 12, sc_dmin = 3, sc_dmax = 8,
    }
    for s = 1, Composer.MAXSTEP do
      tr.pat[s], tr.deg[s], tr.vel[s], tr.gate[s], tr.imp[s] = false, 0, 0.8, 1, 0
    end
    for j = 1, 9 do
      tr.mph[j] = {f1 = 1, p1 = 0, f2 = 2, p2 = 0, dep = 0.5}
    end
    tracks[i] = tr
  end

  Visual.init({S = S, tracks = tracks, pulse = pulse})
  if TEST then
    TEST.S = S; TEST.tracks = tracks
    TEST.evo_event = evo_event
    TEST.evo_beat = evo_beat
    TEST.evo_table = EVO
  end
  build_params()
  midi_out = midi.connect(1)
  favs_load()

  load_seed(math.random(1, 4294967295))
  S.ready = true

  tick_clock = clock.run(tick_loop)
  frame_metro = metro.init(frame, 1 / 30, -1)
  frame_metro:start()
end

function cleanup()
  if frame_metro then frame_metro:stop() end
  if tick_clock then clock.cancel(tick_clock) end
end
