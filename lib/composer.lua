-- composer.lua
-- MICELIO: the engine that composes the sequences of every world.
-- un luogo moderatamente sicuro
--
-- A sequence is made of bars of 16 steps (16th notes). Each bar is built from
-- rhythmic cells (from 1 step = a 16th up to 16 steps = a whole note); bars follow
-- a form (AABA, ABAB...) and a chord progression. Strong beats land on chord tones,
-- the others are passing notes. Note lengths (gates) change from note to note.
-- Everything is decided by the world's random generator.

local C = {}

local floor, ceil, max, min, abs, sin, pi = math.floor, math.ceil, math.max, math.min, math.abs, math.sin, math.pi

local MAXSTEP = 64
C.MAXSTEP = MAXSTEP

local function round(x) return floor(x + 0.5) end
local function clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

-- progressions: degrees in sevenths (0 = root). They are rescaled to the number of
-- notes of the scale in use, so they also work with pentatonic and microtonal scales.
local PROGS = {
  {0, 3, 4, 0}, {0, 5, 3, 4}, {0, 4, 5, 3}, {0, 2, 3, 4}, {0, -2, 3, 0},
  {0, 3, 0, 4}, {0, 5, 2, 6}, {0, 0, 3, 4}, {0, 6, 5, 4}, {0, 2, 5, 4},
  {0, 4, 0, 3}, {0, 1, 5, 4},
}

local FORMS = {"AABA", "ABAB", "AAAB", "ABAC", "AABB", "ABCB", "AAAA", "ABBA", "AABC", "ABAA"}

-- rhythmic cells. Positive = a note of that length in steps, negative = a rest.
local BAR_PAD = {{16}, {8, 8}, {12, 4}, {10, 6}, {8, 4, 4}, {6, 6, 4}, {-4, 12}, {4, 12}}
local BASS8 = {{8}, {6, 2}, {4, 4}, {4, 2, 2}, {3, 5}, {2, 6}, {4, -4}, {-2, 6}, {2, 2, 4},
               {6, -2}, {3, 3, 2}, {2, 2, 2, 2}, {2, 1, 1, 4}}
local LEAD4_BUSY = {{1, 1, 1, 1}, {1, 1, 2}, {2, 1, 1}, {1, 2, 1}, {2, 2}, {1, 1, 1, -1},
                    {-1, 1, 1, 1}, {3, 1}}
local LEAD4_MID = {{2, 2}, {3, 1}, {1, 3}, {2, 1, 1}, {4}, {2, -2}, {1, 1, 2}, {-1, 3},
                   {1, -1, 2}, {3, -1}}
local LEAD8_LONG = {{8}, {6, 2}, {4, 4}, {5, 3}, {4, 2, 2}, {2, 6}, {3, 3, 2}}

local STYLES = {
  bass = {"cells", "cells", "cells", "pulse"},
  lead = {"cells", "cells", "cells", "arp", "synco"},
  pad  = {"pad"},
  perc = {"euclid", "euclid", "synco"},
}

function C.euclid(k, n)
  local pat = {}
  if k <= 0 then
    for i = 1, n do pat[i] = false end
    return pat
  end
  if k >= n then
    for i = 1, n do pat[i] = true end
    return pat
  end
  local bucket = 0
  for i = 1, n do
    bucket = bucket + k
    if bucket >= n then
      bucket = bucket - n
      pat[i] = true
    else
      pat[i] = false
    end
  end
  return pat
end

-- chord: third and fifth in degrees, proportional to the scale
function C.chord(N)
  return round(N * 2 / 7), round(N * 4 / 7)
end

function C.make_prog(rg, N)
  local p = rg.pick(PROGS)
  local out = {}
  for i = 1, #p do out[i] = round(p[i] * N / 7) end
  return out
end

function C.pick_form(rg, nb)
  if nb <= 1 then return "A" end
  return rg.pick(FORMS)
end

function C.pick_style(rg, role)
  return rg.pick(STYLES[role] or STYLES.lead)
end

local function beat_strength(p)
  if p == 0 then return 1.0 end
  if p == 8 then return 0.85 end
  if p % 4 == 0 then return 0.7 end
  if p % 2 == 0 then return 0.45 end
  return 0.25
end

local function cells_to_events(cells)
  local evs, pos = {}, 0
  for _, v in ipairs(cells) do
    if v > 0 then
      evs[#evs + 1] = {pos = pos, dur = v}
      pos = pos + v
    else
      pos = pos - v
    end
  end
  return evs
end

local function concat_cells(list)
  local out = {}
  for _, cell in ipairs(list) do
    for _, v in ipairs(cell) do out[#out + 1] = v end
  end
  return out
end

-- rhythm of one bar, according to the style
local function gen_rhythm(rg, style, role, busy)
  if style == "pad" then
    return cells_to_events(rg.pick(BAR_PAD))
  elseif style == "cells" then
    if role == "bass" then
      return cells_to_events(concat_cells({rg.pick(BASS8), rg.pick(BASS8)}))
    end
    local list = {}
    for half = 1, 2 do
      if rg.f() < 0.22 then
        list[#list + 1] = rg.pick(LEAD8_LONG)
      else
        for q = 1, 2 do
          list[#list + 1] = (rg.f() < busy) and rg.pick(LEAD4_BUSY) or rg.pick(LEAD4_MID)
        end
      end
    end
    return cells_to_events(concat_cells(list))
  elseif style == "pulse" then
    local evs = {}
    for pos = 0, 14, 2 do
      if pos == 0 or rg.f() > 0.2 then
        evs[#evs + 1] = {pos = pos, dur = (rg.f() < 0.15) and 3 or 2}
      end
    end
    return evs
  elseif style == "arp" then
    local unit = rg.pick({1, 2, 2})
    local evs, pos = {}, 0
    while pos < 16 do
      local d = unit
      if rg.f() < 0.1 then d = unit * 2 end
      d = min(d, 16 - pos)
      if pos == 0 or rg.f() > 0.15 then
        evs[#evs + 1] = {pos = pos, dur = d}
      end
      pos = pos + d
    end
    return evs
  elseif style == "synco" then
    local pool = {2, 3, 5, 6, 7, 10, 11, 13, 14, 15}
    local n = rg.i(3, 7)
    local used = {}
    local evs = {}
    if rg.f() < 0.5 then evs[1] = {pos = 0, dur = rg.pick({1, 2, 3})}; used[0] = true end
    for _ = 1, n do
      local p = rg.pick(pool)
      if not used[p] then
        used[p] = true
        evs[#evs + 1] = {pos = p, dur = rg.pick({1, 1, 2, 2, 3})}
      end
    end
    table.sort(evs, function(a, b) return a.pos < b.pos end)
    return evs
  else -- euclid
    local k = rg.i(3, 8)
    local e = C.euclid(k, 16)
    local rot = rg.i(0, 15)
    local evs = {}
    for s = 0, 15 do
      if e[((s - rot) % 16) + 1] then
        evs[#evs + 1] = {pos = s, dur = rg.pick({1, 1, 2})}
      end
    end
    return evs
  end
end

local function nearest_octave(deg, ref, N)
  while deg - ref > N / 2 do deg = deg - N end
  while ref - deg > N / 2 do deg = deg + N end
  return deg
end

-- melody of one bar: returns degrees relative to the chord root
local function gen_melody(rg, evs, root, c, b, style, prev)
  local rel = {}
  local cur = prev or root
  local tones = {0, 0, c.t3, c.t3, c.f5, c.f5, c.N}
  local arp = {0, c.t3, c.f5, c.N}
  local ap = rg.pick({"up", "down", "updown", "rand"})
  for k, e in ipairs(evs) do
    local d
    if style == "arp" then
      local n = #arp
      local idx
      if ap == "up" then idx = ((k - 1) % n) + 1
      elseif ap == "down" then idx = n - ((k - 1) % n)
      elseif ap == "updown" then
        local m = ((k - 1) % (2 * n - 2))
        idx = (m < n) and (m + 1) or (2 * n - 1 - m)
      else idx = rg.i(1, n) end
      d = root + arp[idx]
    elseif c.role == "bass" then
      d = root + rg.pick({0, 0, 0, c.f5, 0, c.f5, c.t3})
      d = nearest_octave(d, c.lo + (c.hi - c.lo) * 0.3, c.N)
    elseif c.role == "pad" then
      d = root + rg.pick({0, c.t3, c.f5, c.f5, c.N})
    elseif c.role == "perc" then
      d = root + rg.pick({0, 0, 0, c.f5})
    else
      local want = c.lo + (c.hi - c.lo) * (0.30 + 0.5 * sin(pi * ((b - 1) + e.pos / 16) / c.nb))
      local strong = (e.pos % 4 == 0) or e.dur >= 3
      if strong or k == 1 then
        d = nearest_octave(root + rg.pick(tones), cur, c.N)
      else
        d = cur + rg.pick({-1, -1, 1, 1, 1, -2, 2, 0})
      end
      if rg.f() < 0.35 then
        if d < want - 1 then d = d + 1 elseif d > want + 1 then d = d - 1 end
      end
    end
    while d > c.hi do d = d - c.N end
    while d < c.lo do d = d + c.N end
    cur = d
    rel[k] = d - root
  end
  return rel, cur
end

local function gate_factor(rg, art)
  if art == "stacc" then return 0.3 + rg.f() * 0.3 end
  if art == "legato" then return 0.95 + rg.f() * 0.1 end
  return rg.pick({0.4, 0.55, 0.8, 0.95, 1.0, 1.0})
end

-- sorts the steps by importance (most important first)
function C.reorder(tr)
  local order = {}
  for s = 1, tr.len do order[s] = s end
  table.sort(order, function(a, b)
    if tr.imp[a] ~= tr.imp[b] then return tr.imp[a] > tr.imp[b] end
    return a < b
  end)
  tr.order = order
end

-- switches on the first n steps by importance: changes density while keeping the musical sense
function C.set_nact(tr, n)
  n = clamp(floor(n), 0, tr.len)
  tr.nact = n
  for rank, s in ipairs(tr.order) do
    tr.pat[s] = (rank <= n)
  end
end

function C.count_active(tr)
  local n = 0
  for s = 1, tr.len do
    if tr.pat[s] then n = n + 1 end
  end
  return n
end

-- repeats the material beyond len up to MAXSTEP, so changing the length breaks nothing
local function fill_cyclic(tr)
  local len = tr.len
  for s = len + 1, MAXSTEP do
    local src = ((s - 1) % len) + 1
    tr.pat[s] = tr.pat[src]
    tr.deg[s] = tr.deg[src]
    tr.vel[s] = tr.vel[src]
    tr.gate[s] = tr.gate[src]
    tr.imp[s] = tr.imp[src]
  end
end

-- changes the loop length (1..64) keeping the active notes
function C.fit_len(tr, newlen)
  newlen = clamp(floor(newlen), 1, MAXSTEP)
  tr.len = newlen
  local n = C.count_active(tr)
  if n == 0 then n = 1 end
  C.reorder(tr)
  C.set_nact(tr, min(n, newlen))
  if tr.pos > newlen then tr.pos = 0 end
end

-- rotates the loop by n steps (pattern, notes, velocity, gate and importance together)
function C.rotate(tr, n)
  local len = tr.len
  n = n % len
  if n == 0 then return end
  local np, nd, nv, ng, ni = {}, {}, {}, {}, {}
  for s = 1, len do
    local src = ((s - 1 - n) % len) + 1
    np[s], nd[s], nv[s], ng[s], ni[s] = tr.pat[src], tr.deg[src], tr.vel[src], tr.gate[src], tr.imp[src]
  end
  for s = 1, len do
    tr.pat[s], tr.deg[s], tr.vel[s], tr.gate[s], tr.imp[s] = np[s], nd[s], nv[s], ng[s], ni[s]
  end
  tr.rot = (tr.rot + n) % len
  C.reorder(tr)
  fill_cyclic(tr)
end

-- distance in steps from note s to the next active note (wrapping around)
function C.next_gap(tr, s)
  local len = tr.len
  for k = 1, len do
    local idx = ((s - 1 + k) % len) + 1
    if tr.pat[idx] then return k end
  end
  return len
end

-- small mutation, used by drift
function C.mutate(tr)
  local len = tr.len
  local act = {}
  for s = 1, len do
    if tr.pat[s] then act[#act + 1] = s end
  end
  if #act == 0 then return end
  local r = math.random()
  local s = act[math.random(#act)]
  if r < 0.40 then
    tr.deg[s] = clamp(tr.deg[s] + ({-2, -1, 1, 2})[math.random(4)], tr.lo, tr.hi)
  elseif r < 0.60 then
    local t = ((s - 1 + ({-2, -1, 1, 2})[math.random(4)]) % len) + 1
    if not tr.pat[t] then
      tr.pat[t], tr.deg[t], tr.vel[t], tr.gate[t] = true, tr.deg[s], tr.vel[s], tr.gate[s]
      tr.pat[s] = false
      tr.imp[s], tr.imp[t] = tr.imp[t], tr.imp[s]
      C.reorder(tr)
    end
  elseif r < 0.85 then
    tr.gate[s] = clamp(tr.gate[s] * ({0.5, 0.75, 1.5, 2})[math.random(4)], 0.25, 16)
  else
    tr.vel[s] = clamp(0.4 + 0.6 * math.random(), 0.3, 1)
  end
  fill_cyclic(tr)
end

-- composes the sequence of a track.
-- o: role, N (notes of the scale), len, art, busy, prog, form, style
function C.generate(tr, rg, o)
  local N, len, role = o.N, o.len, o.role
  local nb = ceil(len / 16)
  local t3, f5 = C.chord(N)
  local lo, hi
  if role == "bass" then lo, hi = -N, f5
  elseif role == "pad" then lo, hi = 0, N + t3
  elseif role == "perc" then lo, hi = 0, f5
  else lo, hi = -t3, N + f5 end
  local c = {N = N, t3 = t3, f5 = f5, lo = lo, hi = hi, role = role, nb = nb}
  tr.lo, tr.hi, tr.len = lo, hi, len

  local form = o.form or C.pick_form(rg, nb)
  local style = o.style
  local tmpl = {}
  local prev = nil

  for s = 1, MAXSTEP do
    tr.pat[s], tr.deg[s], tr.vel[s], tr.gate[s], tr.imp[s] = false, 0, 0.7, 0.5, 0
  end

  local lastev
  for b = 1, nb do
    local root = o.prog[((b - 1) % #o.prog) + 1]
    local letter = form:sub(((b - 1) % #form) + 1, ((b - 1) % #form) + 1)
    local t = tmpl[letter]
    local evs, rel
    if not t then
      evs = gen_rhythm(rg, style, role, o.busy)
      rel, prev = gen_melody(rg, evs, root, c, b, style, prev)
      tmpl[letter] = {evs = evs, rel = rel}
    else
      -- repetition with small variations
      evs, rel = {}, {}
      for k, e in ipairs(t.evs) do
        local keep = not (rg.f() < 0.06 and #t.evs > 2)
        if keep then
          local d = e.dur
          if rg.f() < 0.08 then d = clamp(d + rg.pick({-1, 1, 2}), 1, 16 - e.pos) end
          local r = t.rel[k]
          if rg.f() < 0.15 then r = r + rg.pick({-1, 1, -2, 2}) end
          evs[#evs + 1] = {pos = e.pos, dur = d}
          rel[#rel + 1] = r
        end
      end
    end
    for k, e in ipairs(evs) do
      local s = (b - 1) * 16 + e.pos + 1
      if s <= len then
        local d = root + rel[k]
        while d > hi do d = d - N end
        while d < lo do d = d + N end
        local acc = beat_strength(e.pos)
        local dur = min(e.dur, len - s + 1)
        tr.pat[s] = true
        tr.deg[s] = d
        tr.vel[s] = clamp(0.45 + 0.5 * acc + (rg.f() - 0.5) * 0.15, 0.3, 1.0)
        tr.gate[s] = max(0.25, dur * gate_factor(rg, o.art))
        lastev = s
      end
    end
  end

  -- closure: the last note often lands on the root or fifth of the last chord
  if lastev and rg.f() < 0.65 then
    local root = o.prog[((nb - 1) % #o.prog) + 1]
    local d = root + rg.pick({0, 0, f5})
    while d > hi do d = d - N end
    while d < lo do d = d + N end
    tr.deg[lastev] = d
  end

  -- for steps without a note: spare values (used when density grows)
  local last = tr.deg[lastev or 1]
  for s = 1, len do
    if tr.pat[s] then
      last = tr.deg[s]
    else
      tr.deg[s] = clamp(last + rg.pick({-1, 0, 0, 1}), lo, hi)
      tr.vel[s] = 0.4 + 0.3 * rg.f()
      tr.gate[s] = max(0.25, (0.6 + 0.8 * rg.f()) * gate_factor(rg, o.art))
    end
  end

  -- step importance: strong beats count more, existing notes count even more
  for s = 1, len do
    tr.imp[s] = beat_strength((s - 1) % 16) + 0.15 * rg.f() + (tr.pat[s] and 10 or 0)
  end
  tr.nact = C.count_active(tr)
  if tr.nact == 0 then
    tr.pat[1] = true
    tr.imp[1] = tr.imp[1] + 10
    tr.nact = 1
  end
  C.reorder(tr)
  fill_cyclic(tr)
  tr.rot = 0
  tr.pos = 0
  tr.prog, tr.N = o.prog, N
  tr.gen = {role = role, art = o.art, busy = o.busy, form = o.form, style = o.style}
end

-- changes the chord progression: each bar is transposed by the difference between
-- the old and the new chord, so the melody stays recognisable
function C.reharm(tr, newprog)
  local old = tr.prog
  if not old or not tr.N then return false end
  local N = tr.N
  local nb = ceil(tr.len / 16)
  for b = 1, nb do
    local delta = newprog[((b - 1) % #newprog) + 1] - old[((b - 1) % #old) + 1]
    if delta ~= 0 then
      for s = (b - 1) * 16 + 1, min(b * 16, tr.len) do
        local d = tr.deg[s] + delta
        while d > tr.hi do d = d - N end
        while d < tr.lo do d = d + N end
        tr.deg[s] = d
      end
    end
  end
  tr.prog = newprog
  fill_cyclic(tr)
  return true
end

-- limits (first and last step) of bar b
local function bar_range(tr, b)
  local a = (b - 1) * 16 + 1
  return a, min(b * 16, tr.len)
end

-- retrograde: the bar is played backwards
function C.retro(tr, b)
  local a, z = bar_range(tr, b)
  if z - a < 3 then return false end
  local n = z - a + 1
  for k = 0, floor(n / 2) - 1 do
    local i, j = a + k, z - k
    tr.pat[i], tr.pat[j] = tr.pat[j], tr.pat[i]
    tr.deg[i], tr.deg[j] = tr.deg[j], tr.deg[i]
    tr.vel[i], tr.vel[j] = tr.vel[j], tr.vel[i]
    tr.gate[i], tr.gate[j] = tr.gate[j], tr.gate[i]
    tr.imp[i], tr.imp[j] = tr.imp[j], tr.imp[i]
  end
  C.reorder(tr)
  fill_cyclic(tr)
  return true
end

-- inversion: the melodic leaps of the bar are mirrored
function C.invert(tr, b)
  local a, z = bar_range(tr, b)
  local sum, cnt = 0, 0
  for s = a, z do
    if tr.pat[s] then sum, cnt = sum + tr.deg[s], cnt + 1 end
  end
  if cnt < 2 then return false end
  local mean = sum / cnt
  for s = a, z do
    local d = floor(2 * mean - tr.deg[s] + 0.5)
    tr.deg[s] = clamp(d, tr.lo, tr.hi)
  end
  fill_cyclic(tr)
  return true
end

-- stretches or shortens the lengths of a bar (longer or drier gates)
function C.regate(tr, b, f)
  local a, z = bar_range(tr, b)
  for s = a, z do
    tr.gate[s] = clamp(tr.gate[s] * f, 0.25, 16)
  end
  fill_cyclic(tr)
  return true
end

-- moves the pitches of a bar by n degrees (register variation)
function C.lift(tr, b, n)
  local a, z = bar_range(tr, b)
  for s = a, z do
    tr.deg[s] = clamp(tr.deg[s] + n, tr.lo, tr.hi)
  end
  fill_cyclic(tr)
  return true
end

return C
