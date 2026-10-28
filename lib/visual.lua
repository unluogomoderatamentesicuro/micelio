-- visual.lua
-- MICELIO: procedural generator of visual worlds.
-- un luogo moderatamente sicuro
--
-- Every world builds a scene from 1 to 3 "layers" chosen among 80 generators
-- (rings, spirographs, flow fields, cellular automata, attractors, rotating solids,
-- mushrooms...). Each layer has continuous random parameters, and the scene has
-- random radial and mirror symmetry, rotation, zoom, camera drift, brightness,
-- line width, background and overlay. The combinations are practically endless:
-- two worlds are never alike.

local V = {}

local floor, sin, cos, pi, abs, max, min, sqrt = math.floor, math.sin, math.cos, math.pi, math.abs, math.max, math.min, math.sqrt
local TAU = 2 * pi
local BUDGET = 800   -- maximum estimated draw calls per frame
-- factor that turns a layer's nominal cost into real (measured) draw calls
local FACT = {
  rings = 3, lissajous = 1.1, warp = 4.3, polygons = 2.4, bars = 4.5, waves = 1.2, rain = 5.3,
  automaton = 0.9, spirograph = 1.1, flow = 4.5, moire = 3.4, orbits = 1.0, tunnel = 1.3,
  tree = 4.3, superformula = 1.3, attractor = 1.1, lattice = 1.1, rays = 4.6, fireflies = 1.5,
  solid = 3.6, horizon = 4.4, threads = 4.5,
  comets = 1.5, web = 1.6, network = 1.15, ribbon = 1.3, rose = 1.25, harmonograph = 1.2, spiral = 1.4,
  chladni = 1.25, constellations = 1.25, bubbles = 1.2, fractal = 1.5, dna = 1.2, snow = 1.5, radar = 1.2,
  asemic = 1.25, lightning = 1,
  mushrooms = 2.1, sporeprint = 3.1, mycelium = 1.2, fairy_ring = 3.3, gills = 2.2, hyphae = 2.3, pulsar = 1.65,
  hexagons = 1.25, knot = 1.15, snowflake = 3.8, supernova = 1.4, dotmatrix = 1.9, checkerboard = 2.25, inkblot = 1.9,
  urchin = 3.2, lichen = 1.75,
  amanita = 2.0, leaves = 2.2, equalizer = 2.2, pinwheel = 3.0, dunes = 2.2, globe = 2.2, torus = 1.4, squares = 2.4,
  starwheel = 3.0, pulse_trace = 1.6, blocks = 1.3, snake = 2.6, pendulums = 2.4, moon = 2.6, phyllotaxis = 1.4, forest = 1.7,
  aurora = 1.1, galaxy = 1.7, kelp = 1.9, mandala = 2.3, scales = 1.4, vines = 1.1, eclipse = 3.7,
  stalactites = 1.8, atoms = 4.8, ripples = 1.1,
}

local TEST = rawget(_G, "MICELIO_TEST")

local ctx            -- { S = state, tracks = tracks, pulse = pulses per track }
local SCN            -- current scene
local vt, energy = 0, 0
local TX = {c = 1, s = 0, fx = 1, sc = 1, ox = 64, oy = 32}
local LO = {x = 0, y = 0}

local LAYER, ORDER = {}, {}
local function add(name, def)
  LAYER[name] = def
  ORDER[#ORDER + 1] = name
end

local function clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

local function gcd(a, b)
  while b ~= 0 do a, b = b, a % b end
  return a
end

local function lvl(x)
  local g, o = 1, 0
  if SCN then g, o = SCN.gain, SCN.off end
  screen.level(clamp(floor(x * g + o + 0.5), 0, 15))
end

local function P(k) return ctx.pulse[(k - 1) % 4 + 1] end

-- layer coordinates -> screen (layer offset, mirror, rotation, zoom)
local function pt(x, y)
  x = (x + LO.x) * TX.fx
  y = y + LO.y
  return TX.ox + (x * TX.c - y * TX.s) * TX.sc, TX.oy + (x * TX.s + y * TX.c) * TX.sc
end
local function mv(x, y) local a, b = pt(x, y); screen.move(a, b) end
local function ln(x, y) local a, b = pt(x, y); screen.line(a, b) end
local function circ(x, y, r)
  local a, b = pt(x, y)
  screen.circle(a, b, max(0.4, r * TX.sc))
end

-- ------------------------------------------------------------------ layers

add("rings", {
  new = function(rg)
    return {rings = {}, nb = rg.i(2, 5), sp = 0.5 + rg.f() * 1.3, rad = 6 + rg.f() * 18,
            ph = rg.f() * TAU, flat = 0.5 + rg.f() * 0.5, cost = 36}
  end,
  hit = function(s, i, vel, pn)
    s.rings[#s.rings + 1] = {x = (pn - 0.5) * 70, y = (i - 2.5) * 11, r = 1, sp = 0.6 + vel * 1.6, l = 15}
    if #s.rings > 24 then table.remove(s.rings, 1) end
  end,
  upd = function(s)
    for k = #s.rings, 1, -1 do
      local o = s.rings[k]
      o.r = o.r + o.sp
      o.l = o.l - 0.45
      if o.l <= 0.6 then table.remove(s.rings, k) end
    end
  end,
  draw = function(s)
    for k = 1, s.nb do
      local a = vt * (0.3 + k * 0.17 * s.sp) + s.ph * k
      lvl(3 + P(k) * 12)
      circ(cos(a) * s.rad * k * 0.5, sin(a) * s.rad * k * 0.5 * s.flat, 1 + P(k) * 2)
      screen.fill()
    end
    for _, o in ipairs(s.rings) do
      lvl(o.l)
      circ(o.x, o.y, o.r)
      screen.stroke()
    end
  end,
})

add("lissajous", {
  new = function(rg)
    local a, b = rg.i(1, 7), rg.i(1, 7)
    if a == b then b = b % 7 + 1 end
    local pts, cp = rg.pick({60, 80, 100, 120}), rg.i(1, 3)
    return {a = a, b = b, ph = rg.f() * TAU, pts = pts, cp = cp, ax = 18 + rg.f() * 44,
            ay = 9 + rg.f() * 22, sp = 0.15 + rg.f() * 0.7, cost = pts * cp}
  end,
  draw = function(s)
    for c = 0, s.cp - 1 do
      lvl(15 - c * 5)
      for k = 0, s.pts do
        local th = k / s.pts * TAU
        local x = s.ax * (1 + 0.15 * energy) * sin(s.a * th + vt * s.sp + c * 0.12)
        local y = s.ay * (1 + 0.15 * energy) * sin(s.b * th + s.ph + vt * s.sp * 0.47 + ctx.S.morph * 0.3 + c * 0.06)
        if k == 0 then mv(x, y) else ln(x, y) end
      end
      screen.stroke()
    end
  end,
})

add("warp", {
  new = function(rg)
    local n = rg.i(30, 70)
    local st = {}
    for k = 1, n do st[k] = {a = rg.f() * TAU, r = rg.f() * 50, s = 0.4 + rg.f() * 1.2, b = 0} end
    return {stars = st, ey = 0.5 + rg.f() * 0.5, cost = n}
  end,
  hit = function(s)
    for _ = 1, 6 do
      local st = s.stars[math.random(#s.stars)]
      st.r = 2 + math.random() * 6
      st.b = 12
    end
  end,
  upd = function(s)
    local sp = 0.03 + ctx.S.bpm / 120 * 0.04
    for _, st in ipairs(s.stars) do
      st.r = st.r * (1 + sp * st.s) + 0.15
      st.a = st.a + 0.003
      st.b = max(0, st.b - 0.5)
      if st.r > 95 then
        st.r = 1 + math.random() * 4
        st.a = math.random() * TAU
        st.b = 0
      end
    end
  end,
  draw = function(s)
    for _, st in ipairs(s.stars) do
      local r0 = st.r * 0.86
      lvl(2 + st.r / 9 + st.b)
      mv(cos(st.a) * r0, sin(st.a) * r0 * s.ey)
      ln(cos(st.a) * st.r, sin(st.a) * st.r * s.ey)
      screen.stroke()
    end
  end,
})

add("polygons", {
  new = function(rg)
    return {size = 0.7 + rg.f() * 0.5, spin = 0.03 + rg.f() * 0.1, cost = 150}
  end,
  draw = function(s)
    for i = 1, 4 do
      local tr = ctx.tracks[i]
      local len = max(1, tr.len)
      local n = min(len, 16)
      local dim = tr.mute and 0.35 or 1
      local R = (6 + i * 6) * s.size * (1 + 0.1 * P(i))
      local rot = vt * s.spin * ((i % 2 == 0) and 1 or -1) + i + ctx.S.morph * 0.03
      local px, py, on = {}, {}, {}
      for k = 1, n do
        local a = -pi / 2 + TAU * (k - 1) / n + rot
        px[k], py[k] = cos(a) * R * 1.6, sin(a) * R
        local s0, s1 = floor((k - 1) * len / n) + 1, floor(k * len / n)
        on[k] = false
        for q = s0, max(s0, s1) do
          if tr.pat[q] then on[k] = true end
        end
      end
      lvl((1 + P(i) * 3) * dim)
      for k = 1, n do
        local k2 = k % n + 1
        mv(px[k], py[k]); ln(px[k2], py[k2]); screen.stroke()
      end
      local act = {}
      for k = 1, n do if on[k] then act[#act + 1] = k end end
      if #act > 1 then
        lvl((6 + P(i) * 5) * dim)
        mv(px[act[1]], py[act[1]])
        for q = 2, #act do ln(px[act[q]], py[act[q]]) end
        ln(px[act[1]], py[act[1]])
        screen.stroke()
      end
      lvl(3 * dim)
      for k = 1, n do
        if not on[k] then
          local a, b = pt(px[k], py[k])
          screen.rect(a, b, 1, 1)
        end
      end
      screen.fill()
      lvl(12 * dim)
      for k = 1, n do
        if on[k] then
          local a, b = pt(px[k], py[k])
          screen.rect(a - 1, b - 1, 2, 2)
        end
      end
      screen.fill()
    end
  end,
})

add("bars", {
  new = function(rg)
    local n = rg.i(12, 40)
    return {n = n, radial = rg.f() < 0.5, r0 = 8 + rg.f() * 14, cost = n}
  end,
  draw = function(s)
    local n = s.n
    for k = 1, n do
      local band = floor((k - 1) * 4 / n) + 1
      local h = 2 + abs(sin(vt * 1.3 + k * 0.7)) * 7 + abs(sin(vt * 0.5 - k * 0.31)) * 6 + P(band) * 18
      lvl(2 + h * 0.45)
      if s.radial then
        local a = k / n * TAU
        mv(cos(a) * s.r0, sin(a) * s.r0)
        ln(cos(a) * (s.r0 + h), sin(a) * (s.r0 + h))
      else
        local x = (k - (n + 1) / 2) * (120 / n)
        mv(x, -h); ln(x, h)
      end
      screen.stroke()
    end
  end,
})

add("waves", {
  new = function(rg)
    local n, step = rg.i(4, 9), rg.pick({4, 6, 8})
    return {n = n, step = step, cost = n * floor(128 / step)}
  end,
  draw = function(s)
    for l = 1, s.n do
      local y0 = (l - (s.n + 1) / 2) * (54 / s.n)
      local p = P(l)
      local amp = 1.8 + p * 8
      local f = 0.05 + l * 0.012
      local sp = ((l % 2 == 0) and 1 or -1) * (0.9 + l * 0.13)
      lvl(3 + (l % 3) * 2 + p * 9)
      for x = -64, 64, s.step do
        local y = y0 + amp * sin(x * f + vt * sp * 1.8 + ctx.S.morph * 0.4) * (0.55 + 0.45 * sin(x * 0.045 + vt * 0.7 + l))
        if x == -64 then mv(x, y) else ln(x, y) end
      end
      screen.stroke()
    end
  end,
})

add("rain", {
  new = function(rg)
    local sp = {}
    for k = 1, 16 do sp[k] = {x = (rg.f() - 0.5) * 128, y = (rg.f() - 0.5) * 60, v = 0.1 + rg.f() * 0.3} end
    return {drops = {}, splash = {}, specks = sp, fl = 20 + rg.f() * 8, cost = 50}
  end,
  hit = function(s, i, vel, pn)
    s.drops[#s.drops + 1] = {x = (pn - 0.5) * 110 + math.random(-3, 3), y = -34, v = 1.2 + vel * 2.2,
                             len = 5 + i * 3, l = 7 + vel * 8}
    if #s.drops > 40 then table.remove(s.drops, 1) end
  end,
  upd = function(s)
    local k = 0.6 + ctx.S.bpm / 110
    for _, p in ipairs(s.specks) do
      p.y = p.y + p.v
      if p.y > 30 then p.y = -32; p.x = (math.random() - 0.5) * 128 end
    end
    for q = #s.drops, 1, -1 do
      local d = s.drops[q]
      d.y = d.y + d.v * k
      if d.y >= s.fl then
        s.splash[#s.splash + 1] = {x = d.x, r = 1, l = d.l}
        table.remove(s.drops, q)
      end
    end
    for q = #s.splash, 1, -1 do
      local p = s.splash[q]
      p.r = p.r + 0.8
      p.l = p.l - 0.7
      if p.l <= 0.6 then table.remove(s.splash, q) end
    end
  end,
  draw = function(s)
    lvl(2)
    mv(-64, s.fl); ln(64, s.fl); screen.stroke()
    for _, p in ipairs(s.specks) do
      local a, b = pt(p.x, p.y)
      lvl(2)
      screen.rect(a, b, 1, 1)
      screen.fill()
    end
    for _, d in ipairs(s.drops) do
      lvl(d.l)
      mv(d.x, d.y - d.len * 0.5); ln(d.x, d.y); screen.stroke()
      lvl(d.l * 0.4)
      mv(d.x, d.y - d.len); ln(d.x, d.y - d.len * 0.5); screen.stroke()
    end
    for _, p in ipairs(s.splash) do
      lvl(p.l)
      circ(p.x, s.fl, p.r)
      screen.stroke()
    end
  end,
})

add("automaton", {
  new = function(rg)
    local cols, rows = rg.i(20, 40), rg.i(8, 14)
    local rr = {}
    for r = 1, rows do
      local row = {}
      for c = 1, cols do row[c] = 0 end
      rr[r] = row
    end
    for _ = 1, rg.i(1, 4) do rr[1][rg.i(1, cols)] = 1 end
    return {cols = cols, rows = rows, cell = rg.pick({3, 4}), rule = rg.i(0, 255),
            rate = rg.pick({1, 2, 3}), rr = rr, acc = 0, cost = floor(cols * rows * 0.45)}
  end,
  hit = function(s, i, vel, pn)
    s.rr[1][clamp(floor(pn * (s.cols - 1)) + 1, 1, s.cols)] = 1
  end,
  upd = function(s)
    s.acc = s.acc + (ctx.S.bpm / 60) * s.rate / 30
    while s.acc >= 1 do
      s.acc = s.acc - 1
      local top, nr, alive = s.rr[1], {}, 0
      local cols = s.cols
      for c = 1, cols do
        local l, m, r = top[(c - 2) % cols + 1], top[c], top[c % cols + 1]
        nr[c] = (s.rule >> (l * 4 + m * 2 + r)) & 1
        alive = alive + nr[c]
      end
      if alive == 0 then nr[math.random(1, cols)] = 1 end
      table.remove(s.rr)
      table.insert(s.rr, 1, nr)
    end
  end,
  draw = function(s)
    for r = 1, s.rows do
      lvl(max(1, 14 - (r - 1) * (14 / s.rows)))
      local row = s.rr[r]
      for c = 1, s.cols do
        if row[c] == 1 then
          local a, b = pt((c - s.cols / 2) * s.cell, (r - s.rows / 2) * s.cell)
          screen.rect(a - 1, b - 1, s.cell - 1, s.cell - 1)
        end
      end
      screen.fill()
    end
  end,
})

add("spirograph", {
  new = function(rg)
    local R = rg.i(5, 11)
    local rr = rg.i(2, R - 1)
    local d = rr * (0.4 + rg.f() * 1.1)
    local turns = rr / gcd(R, rr)
    local pts = clamp(floor(turns * 48), 60, 200)
    return {R = R, r = rr, d = d, turns = turns, pts = pts, sc = 34 / (R - rr + d),
            sp = 0.1 + rg.f() * 0.4, cost = pts}
  end,
  draw = function(s)
    local d = s.d * (1 + 0.25 * sin(vt * 0.21))
    local k1 = (s.R - s.r) / s.r
    local a = vt * s.sp
    local ca, sa = cos(a), sin(a)
    local scl = s.sc * (1 + 0.15 * energy)
    lvl(9 + energy * 3)
    for k = 0, s.pts do
      local t = k / s.pts * TAU * s.turns
      local x = ((s.R - s.r) * cos(t) + d * cos(k1 * t)) * scl
      local y = ((s.R - s.r) * sin(t) - d * sin(k1 * t)) * scl
      local xr, yr = x * ca - y * sa, x * sa + y * ca
      if k == 0 then mv(xr, yr) else ln(xr, yr) end
    end
    screen.stroke()
  end,
})

add("flow", {
  new = function(rg)
    local n = rg.i(14, 36)
    local ps = {}
    for k = 1, n do ps[k] = {x = (rg.f() - 0.5) * 128, y = (rg.f() - 0.5) * 64, a = 0} end
    return {n = n, ps = ps, kx = 0.03 + rg.f() * 0.08, ky = 0.03 + rg.f() * 0.08,
            w1 = 0.2 + rg.f() * 0.6, w2 = 0.2 + rg.f() * 0.6, sp = 0.6 + rg.f() * 1.2,
            len = 3 + rg.f() * 5, cost = n}
  end,
  upd = function(s)
    for _, p in ipairs(s.ps) do
      p.a = sin(p.x * s.kx + vt * s.w1) * 2.2 + cos(p.y * s.ky - vt * s.w2) * 2.2
      p.x = p.x + cos(p.a) * s.sp * (1 + energy * 0.4)
      p.y = p.y + sin(p.a) * s.sp
      if p.x > 66 then p.x = -66 elseif p.x < -66 then p.x = 66 end
      if p.y > 34 then p.y = -34 elseif p.y < -34 then p.y = 34 end
    end
  end,
  draw = function(s)
    for k, p in ipairs(s.ps) do
      lvl(5 + (k % 4) * 2 + P(k) * 5)
      mv(p.x - cos(p.a) * s.len, p.y - sin(p.a) * s.len)
      ln(p.x, p.y)
      screen.stroke()
    end
  end,
})

add("moire", {
  new = function(rg)
    local n = rg.i(8, 14)
    return {kind = rg.pick({1, 2}), n = n, gap = 2.5 + rg.f() * 3, w = 0.1 + rg.f() * 0.4,
            a0 = rg.f() * TAU, da = 0.05 + rg.f() * 0.18, cost = 2 * (2 * n + 1)}
  end,
  draw = function(s)
    for set = 0, 1 do
      lvl(set == 0 and 9 or 5)
      if s.kind == 1 then
        local dx = set * (6 + 5 * sin(vt * s.w))
        for k = 1, s.n do
          circ(dx, 0, k * s.gap)
          screen.stroke()
        end
      else
        local a = s.a0 + set * s.da * sin(vt * s.w * 2) + vt * 0.02
        local dx, dy = cos(a), sin(a)
        for k = -s.n, s.n do
          local o = k * s.gap
          local px, py = -dy * o, dx * o
          mv(px - dx * 70, py - dy * 70)
          ln(px + dx * 70, py + dy * 70)
          screen.stroke()
        end
      end
    end
  end,
})

add("orbits", {
  new = function(rg)
    local k = rg.i(3, 7)
    local os = {}
    for i = 1, k do
      local a = 8 + rg.f() * 30
      os[i] = {a = a, b = a * (0.4 + 0.6 * rg.f()), sp = ((rg.f() < 0.5) and -1 or 1) * (0.2 + rg.f() * 0.8) / (1 + i * 0.3),
               ph = rg.f() * TAU, tl = rg.f() * TAU}
    end
    return {os = os, k = k, cost = min(k, 4) * 24 + k * 3}
  end,
  draw = function(s)
    for i, o in ipairs(s.os) do
      local ct, st = cos(o.tl), sin(o.tl)
      if i <= 4 then
        lvl(2)
        for q = 0, 20 do
          local th = q / 20 * TAU
          local x, y = o.a * cos(th), o.b * sin(th)
          local xr, yr = x * ct - y * st, x * st + y * ct
          if q == 0 then mv(xr, yr) else ln(xr, yr) end
        end
        screen.stroke()
      end
      local th = vt * o.sp + o.ph
      local x, y = o.a * cos(th), o.b * sin(th)
      lvl(10 + P(i) * 5)
      circ(x * ct - y * st, x * st + y * ct, 1.2 + P(i) * 2)
      screen.fill()
    end
  end,
})

add("tunnel", {
  new = function(rg)
    local n, d = rg.i(3, 8), rg.i(6, 12)
    return {n = n, d = d, sp = 0.15 + rg.f() * 0.5, tw = (rg.f() - 0.5) * 0.5, rs = (rg.f() - 0.5) * 0.4, cost = d * (n + 4)}
  end,
  draw = function(s)
    for j = 1, s.d do
      local z = ((j / s.d) + vt * s.sp * 0.2) % 1
      local rad = 3 + z ^ 1.7 * 60
      local rot = j * s.tw + vt * s.rs
      lvl(2 + z * 12 + energy * 2)
      for q = 0, s.n do
        local a = rot + q / s.n * TAU
        local x, y = cos(a) * rad, sin(a) * rad * 0.6
        if q == 0 then mv(x, y) else ln(x, y) end
      end
      screen.stroke()
    end
  end,
})

local function branch(s, x, y, ang, len, d)
  local x2, y2 = x + cos(ang) * len, y + sin(ang) * len
  lvl(3 + d * 2.2)
  mv(x, y); ln(x2, y2); screen.stroke()
  if d > 1 then
    local sw = sin(vt * s.sw + d) * 0.12
    branch(s, x2, y2, ang - s.spread + sw, len * s.ratio, d - 1)
    branch(s, x2, y2, ang + s.spread + sw, len * s.ratio, d - 1)
  end
end

add("tree", {
  new = function(rg)
    local depth = rg.i(4, 6)
    return {depth = depth, spread = 0.3 + rg.f() * 0.6, ratio = 0.64 + rg.f() * 0.14,
            len = 11 + rg.f() * 8, sw = 0.3 + rg.f() * 1.2, cost = 2 ^ depth}
  end,
  draw = function(s)
    branch(s, 0, 28, -pi / 2, s.len * (1 + 0.1 * energy), s.depth)
  end,
})

add("superformula", {
  new = function(rg)
    return {m = rg.i(2, 12), n1 = 0.25 + rg.f() * 1.8, n2 = 0.3 + rg.f() * 2.5, n3 = 0.3 + rg.f() * 2.5,
            size = 16 + rg.f() * 16, pts = 80, rr = {}, cost = 80}
  end,
  draw = function(s)
    local n1 = s.n1 * (1 + 0.25 * sin(vt * 0.4))
    local n2 = max(0.2, s.n2 + 0.5 * sin(vt * 0.27 + 1))
    local n3 = max(0.2, s.n3 + 0.5 * sin(vt * 0.31))
    local mx = 0.0001
    for k = 0, s.pts do
      local th = k / s.pts * TAU
      local c, sn = abs(cos(s.m * th / 4)) ^ n2, abs(sin(s.m * th / 4)) ^ n3
      local r = (c + sn) ^ (-1 / n1)
      s.rr[k] = r
      if r > mx then mx = r end
    end
    local sc = s.size * (1 + 0.3 * energy) / mx
    local a0 = vt * 0.1
    lvl(10)
    for k = 0, s.pts do
      local th = k / s.pts * TAU + a0
      local x, y = cos(th) * s.rr[k] * sc, sin(th) * s.rr[k] * sc
      if k == 0 then mv(x, y) else ln(x, y) end
    end
    screen.stroke()
  end,
})

add("attractor", {
  new = function(rg)
    local function par()
      local v = rg.f() * 4.4 - 2.2
      if abs(v) < 0.5 then v = (v < 0) and -0.5 or 0.5 end
      return v
    end
    return {a = par(), b = par(), c = rg.f() * 2 - 1, d = rg.f() * 2 - 1, x = 0.1, y = 0.1,
            sc = 11 + rg.f() * 8, n = 180, px = {}, py = {}, cost = 180}
  end,
  upd = function(s)
    local aa = s.a + 0.15 * sin(vt * 0.07)
    local bb = s.b + 0.15 * sin(vt * 0.05 + 1)
    local x, y = s.x, s.y
    for k = 1, s.n do
      x, y = sin(aa * y) + s.c * cos(aa * x), sin(bb * x) + s.d * cos(bb * y)
      s.px[k], s.py[k] = x, y
    end
    s.x, s.y = x, y
  end,
  draw = function(s)
    lvl(9 + energy * 3)
    for k = 1, s.n do
      local a, b = pt(s.px[k] * s.sc, s.py[k] * s.sc)
      screen.rect(a, b, 1, 1)
    end
    screen.fill()
  end,
})

add("lattice", {
  new = function(rg)
    local cols, rows = rg.i(8, 16), rg.i(4, 8)
    return {cols = cols, rows = rows, sp = rg.pick({5, 6, 7}), amp = 2 + rg.f() * 6,
            w = 0.4 + rg.f() * 1.2, cost = cols * rows}
  end,
  draw = function(s)
    lvl(8)
    for cx = 1, s.cols do
      for ry = 1, s.rows do
        local x, y = (cx - (s.cols + 1) / 2) * s.sp, (ry - (s.rows + 1) / 2) * s.sp
        local dx = s.amp * sin(vt * s.w + ry * 0.8 + cx * 0.3) * (1 + energy * 0.5)
        local dy = s.amp * cos(vt * s.w * 0.8 + cx * 0.6)
        local a, b = pt(x + dx, y + dy)
        screen.rect(a, b, 1, 1)
      end
    end
    screen.fill()
  end,
})

add("rays", {
  new = function(rg)
    local n = rg.i(12, 36)
    return {n = n, r0 = rg.f() * 8, dir = (rg.f() < 0.5) and -1 or 1, f1 = 0.4 + rg.f() * 1.2,
            f2 = 0.3 + rg.f() * 0.9, cost = n}
  end,
  draw = function(s)
    for k = 1, s.n do
      local a = k / s.n * TAU + vt * 0.1 * s.dir
      local len = 6 + 14 * abs(sin(vt * s.f1 + k * 0.9)) + 8 * abs(sin(vt * s.f2 - k * 0.37)) + P(k) * 14
      lvl(3 + len * 0.4)
      mv(cos(a) * s.r0, sin(a) * s.r0)
      ln(cos(a) * (s.r0 + len), sin(a) * (s.r0 + len))
      screen.stroke()
    end
  end,
})

add("fireflies", {
  new = function(rg)
    local n = rg.i(20, 60)
    local ps = {}
    for k = 1, n do
      ps[k] = {x = (rg.f() - 0.5) * 120, y = (rg.f() - 0.5) * 60, vx = 0, vy = 0, ph = rg.f() * TAU}
    end
    return {n = n, ps = ps, cost = n}
  end,
  upd = function(s)
    for _, p in ipairs(s.ps) do
      p.vx = clamp(p.vx + (math.random() - 0.5) * 0.2, -0.8, 0.8)
      p.vy = clamp(p.vy + (math.random() - 0.5) * 0.2, -0.8, 0.8)
      p.x, p.y = p.x + p.vx, p.y + p.vy
      if abs(p.x) > 64 then p.vx = -p.vx; p.x = clamp(p.x, -64, 64) end
      if abs(p.y) > 32 then p.vy = -p.vy; p.y = clamp(p.y, -32, 32) end
    end
  end,
  draw = function(s)
    for pass = 1, 3 do
      lvl(2 + pass * 4)
      for _, p in ipairs(s.ps) do
        local tw = 0.5 + 0.5 * sin(vt * 3 + p.ph)
        if floor(tw * 2.99) + 1 == pass then
          local a, b = pt(p.x, p.y)
          screen.rect(a, b, 1, 1)
        end
      end
      screen.fill()
    end
  end,
})

-- rotating solids: cube, octahedron, prism, pyramid
local function make_solid(kind, n)
  local v, e = {}, {}
  if kind == 1 then
    for i = 0, 7 do
      v[#v + 1] = {(i & 1) * 2 - 1, ((i >> 1) & 1) * 2 - 1, ((i >> 2) & 1) * 2 - 1}
    end
    for i = 0, 7 do
      for b = 0, 2 do
        local j = i ~ (1 << b)
        if j > i then e[#e + 1] = {i + 1, j + 1} end
      end
    end
    for _, p in ipairs(v) do p[1], p[2], p[3] = p[1] / 1.732, p[2] / 1.732, p[3] / 1.732 end
  elseif kind == 2 then
    v = {{1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0}, {0, 0, 1}, {0, 0, -1}}
    for i = 1, 6 do
      for j = i + 1, 6 do
        if not ((i == 1 and j == 2) or (i == 3 and j == 4) or (i == 5 and j == 6)) then e[#e + 1] = {i, j} end
      end
    end
  elseif kind == 3 then
    for k = 0, n - 1 do v[#v + 1] = {cos(k / n * TAU) * 0.8, sin(k / n * TAU) * 0.8, 0.8} end
    for k = 0, n - 1 do v[#v + 1] = {cos(k / n * TAU) * 0.8, sin(k / n * TAU) * 0.8, -0.8} end
    for k = 1, n do
      e[#e + 1] = {k, k % n + 1}
      e[#e + 1] = {n + k, n + k % n + 1}
      e[#e + 1] = {k, n + k}
    end
  else
    for k = 0, n - 1 do v[#v + 1] = {cos(k / n * TAU) * 0.9, sin(k / n * TAU) * 0.9, -0.7} end
    v[#v + 1] = {0, 0, 0.9}
    for k = 1, n do
      e[#e + 1] = {k, k % n + 1}
      e[#e + 1] = {k, n + 1}
    end
  end
  return v, e
end

add("solid", {
  new = function(rg)
    local kind, n = rg.i(1, 4), rg.i(3, 7)
    local v, e = make_solid(kind, n)
    return {v = v, e = e, size = 14 + rg.f() * 14, wx = (rg.f() - 0.5) * 1.2, wy = (rg.f() - 0.5) * 1.2,
            wz = (rg.f() - 0.5) * 0.8, px = {}, py = {}, cost = #e}
  end,
  upd = function(s)
    local ax, ay, az = vt * s.wx, vt * s.wy, vt * s.wz
    local cx, sx, cy, sy, cz, sz = cos(ax), sin(ax), cos(ay), sin(ay), cos(az), sin(az)
    local sc = s.size * (1 + 0.2 * energy)
    for i, p in ipairs(s.v) do
      local x, y, z = p[1], p[2], p[3]
      y, z = y * cx - z * sx, y * sx + z * cx
      x, z = x * cy + z * sy, -x * sy + z * cy
      x, y = x * cz - y * sz, x * sz + y * cz
      local f = 3.2 / (3.2 - z)
      s.px[i], s.py[i] = x * f * sc, y * f * sc
    end
  end,
  draw = function(s)
    lvl(11)
    for _, ed in ipairs(s.e) do
      mv(s.px[ed[1]], s.py[ed[1]])
      ln(s.px[ed[2]], s.py[ed[2]])
      screen.stroke()
    end
  end,
})

add("horizon", {
  new = function(rg)
    return {nh = rg.i(6, 10), nv = rg.i(4, 8), sp = 0.1 + rg.f() * 0.3, yh = -10 + rg.f() * 14, cost = 8 + 18}
  end,
  draw = function(s)
    local yb = 34
    for j = 1, s.nh do
      local z = ((j / s.nh) + vt * s.sp * 0.3) % 1
      local y = s.yh + (yb - s.yh) * z * z
      lvl(2 + z * 10)
      mv(-70, y); ln(70, y); screen.stroke()
    end
    local vx = 10 * sin(vt * 0.2)
    lvl(5)
    for k = -s.nv, s.nv do
      mv(vx, s.yh); ln(k * 16, yb); screen.stroke()
    end
  end,
})

add("threads", {
  new = function(rg)
    local n = rg.i(20, 40)
    return {n = n, R = 22 + rg.f() * 12, w = 0.05 + rg.f() * 0.12, k0 = 2 + rg.f() * 3, kd = 0.5 + rg.f() * 2, cost = n}
  end,
  draw = function(s)
    local k = s.k0 + s.kd * sin(vt * s.w)
    for i = 0, s.n - 1 do
      local a1 = i / s.n * TAU
      local a2 = ((i * k) % s.n) / s.n * TAU
      lvl(3 + (i % 4) * 2 + P(i + 1) * 5)
      mv(cos(a1) * s.R, sin(a1) * s.R)
      ln(cos(a2) * s.R, sin(a2) * s.R)
      screen.stroke()
    end
  end,
})

-- ------------------------------------------------------- layers, second series

add("comets", {
  new = function(rg)
    local n = rg.i(3, 8)
    local c = {}
    for k = 1, n do
      c[k] = {a = rg.f() * TAU, w = (0.25 + rg.f() * 1.1) * (rg.f() < 0.5 and -1 or 1),
              rx = 8 + rg.f() * 50, ry = 4 + rg.f() * 26, tilt = rg.f() * pi, tl = rg.i(6, 12)}
    end
    return {c = c, cost = n * 9 * 4}
  end,
  draw = function(s)
    for k, o in ipairs(s.c) do
      local ct, st = cos(o.tilt), sin(o.tilt)
      local px, py
      for j = 0, o.tl do
        local a = o.a + vt * o.w - j * 0.09 * (o.w > 0 and 1 or -1)
        local ex, ey = cos(a) * o.rx, sin(a) * o.ry
        local x, y = ex * ct - ey * st, ex * st + ey * ct
        if px then
          lvl(15 - j * 1.3 + P(k) * 3)
          mv(px, py); ln(x, y); screen.stroke()
        end
        px, py = x, y
      end
    end
  end,
})

add("web", {
  new = function(rg)
    local rings, spokes = rg.i(3, 7), rg.i(5, 13)
    return {rings = rings, spokes = spokes, R = 18 + rg.f() * 22, sw = 0.3 + rg.f() * 1.2,
            amp = 0.04 + rg.f() * 0.1, cost = rings * (spokes + 3) + spokes + 4}
  end,
  draw = function(s)
    for j = 1, s.rings do
      local r = s.R * j / s.rings
      lvl(3 + j * 1.5 + energy * 3)
      for k = 0, s.spokes do
        local a = k / s.spokes * TAU
        local rr = r * (1 + s.amp * sin(vt * s.sw + k * 1.7 + j))
        local x, y = cos(a) * rr, sin(a) * rr * 0.75
        if k == 0 then mv(x, y) else ln(x, y) end
      end
      screen.stroke()
    end
    lvl(4)
    for k = 0, s.spokes - 1 do
      local a = k / s.spokes * TAU
      mv(0, 0); ln(cos(a) * s.R, sin(a) * s.R * 0.75)
    end
    screen.stroke()
  end,
})

add("network", {
  new = function(rg)
    local n = rg.i(8, 15)
    local p = {}
    for k = 1, n do
      p[k] = {x = (rg.f() - 0.5) * 110, y = (rg.f() - 0.5) * 54,
              vx = (rg.f() - 0.5) * 0.7, vy = (rg.f() - 0.5) * 0.4}
    end
    return {p = p, n = n, thr = 22 + rg.f() * 18, maxl = n * 3, cost = n * 3 * 4 + n * 2 + 2}
  end,
  hit = function(s, i, vel, pn)
    local o = s.p[math.random(s.n)]
    o.vx, o.vy = o.vx + (math.random() - 0.5) * vel * 2, o.vy + (math.random() - 0.5) * vel
  end,
  upd = function(s)
    for _, o in ipairs(s.p) do
      o.x, o.y = o.x + o.vx, o.y + o.vy
      if o.x > 58 or o.x < -58 then o.vx = -o.vx end
      if o.y > 29 or o.y < -29 then o.vy = -o.vy end
      o.vx, o.vy = clamp(o.vx * 0.998, -1.4, 1.4), clamp(o.vy * 0.998, -0.8, 0.8)
    end
  end,
  draw = function(s)
    local lines = 0
    for i = 1, s.n - 1 do
      local a = s.p[i]
      for j = i + 1, s.n do
        local b = s.p[j]
        local d = sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
        if d < s.thr and lines < s.maxl then
          lines = lines + 1
          lvl(2 + (1 - d / s.thr) * 11)
          mv(a.x, a.y); ln(b.x, b.y); screen.stroke()
        end
      end
    end
    lvl(14)
    for _, o in ipairs(s.p) do circ(o.x, o.y, 1) screen.fill() end
  end,
})

add("ribbon", {
  new = function(rg)
    local len = rg.i(18, 34)
    return {len = len, A = 7 + rg.f() * 14, k = 0.04 + rg.f() * 0.07, sp = 0.3 + rg.f() * 1.2,
            tw = 0.5 + rg.f() * 1.5, cost = len * 4 + 2 * (len + 2)}
  end,
  draw = function(s)
    local function y1(x) return s.A * sin(x * s.k + vt * s.sp) end
    local function y2(x) return s.A * sin(x * s.k * 1.3 + vt * s.sp + 1.2 + s.tw * sin(vt * 0.3)) end
    for i = 0, s.len do
      local x = -60 + i / s.len * 120
      lvl(2 + abs(y1(x) - y2(x)) * 0.4 + energy * 2)
      mv(x, y1(x)); ln(x, y2(x)); screen.stroke()
    end
    lvl(13)
    for i = 0, s.len do
      local x = -60 + i / s.len * 120
      if i == 0 then mv(x, y1(x)) else ln(x, y1(x)) end
    end
    screen.stroke()
    lvl(9)
    for i = 0, s.len do
      local x = -60 + i / s.len * 120
      if i == 0 then mv(x, y2(x)) else ln(x, y2(x)) end
    end
    screen.stroke()
  end,
})

add("rose", {
  new = function(rg)
    local pts, cp = rg.pick({90, 120, 160}), rg.i(1, 3)
    local ks = {}
    for c = 1, cp do ks[c] = rg.i(2, 9) / rg.pick({1, 2, 3}) end
    return {ks = ks, cp = cp, pts = pts, R = 16 + rg.f() * 16, sp = 0.08 + rg.f() * 0.3, cost = pts * cp + cp * 3}
  end,
  draw = function(s)
    for c = 1, s.cp do
      local k = s.ks[c] + 0.35 * sin(vt * 0.17 + c)
      lvl(15 - (c - 1) * 4)
      for j = 0, s.pts do
        local th = j / s.pts * TAU * 3
        local r = s.R * (1 + 0.12 * energy) * cos(k * th + vt * s.sp * c)
        local x, y = cos(th) * r, sin(th) * r * 0.8
        if j == 0 then mv(x, y) else ln(x, y) end
      end
      screen.stroke()
    end
  end,
})

add("harmonograph", {
  new = function(rg)
    return {f1 = 1 + rg.f() * 2.5, f2 = 1 + rg.f() * 3.5, f3 = 1 + rg.f() * 2.5, f4 = 1 + rg.f() * 3.5,
            d = 0.01 + rg.f() * 0.03, ax = 20 + rg.f() * 24, ay = 10 + rg.f() * 14, pts = 150,
            cost = 150 + 4}
  end,
  draw = function(s)
    local w = vt * 0.15
    lvl(12)
    for j = 0, s.pts do
      local t = j * 0.5
      local e = math.exp(-s.d * t)
      local x = e * s.ax * (sin(t * s.f1 + w) + 0.5 * sin(t * s.f2 * 1.01))
      local y = e * s.ay * (sin(t * s.f3 + w * 1.3) + 0.5 * sin(t * s.f4 * 0.99 + 1))
      if j == 0 then mv(x, y) else ln(x, y) end
    end
    screen.stroke()
  end,
})

add("spiral", {
  new = function(rg)
    local arms = rg.i(1, 5)
    return {arms = arms, turns = 1.5 + rg.f() * 3, pts = 56, R = 26 + rg.f() * 12,
            sp = 0.1 + rg.f() * 0.5, cost = arms * 56 + arms * 3}
  end,
  draw = function(s)
    for a = 0, s.arms - 1 do
      lvl(5 + (a % 3) * 4 + energy * 3)
      for j = 0, s.pts do
        local f = j / s.pts
        local th = f * s.turns * TAU + a * TAU / s.arms + vt * s.sp
        local r = s.R * f * (1 + 0.1 * sin(f * 9 - vt))
        local x, y = cos(th) * r, sin(th) * r * 0.78
        if j == 0 then mv(x, y) else ln(x, y) end
      end
      screen.stroke()
    end
  end,
})

add("chladni", {
  new = function(rg)
    local gx, gy = rg.i(10, 18), rg.i(5, 9)
    return {gx = gx, gy = gy, m = rg.i(2, 6), n = rg.i(3, 8), sp = 0.1 + rg.f() * 0.25, cost = gx * gy * 2 + 2}
  end,
  draw = function(s)
    local m = s.m + 1.4 * sin(vt * s.sp)
    local n = s.n + 1.4 * sin(vt * s.sp * 0.73 + 1)
    for i = 0, s.gx - 1 do
      local u = i / (s.gx - 1)
      for j = 0, s.gy - 1 do
        local w = j / (s.gy - 1)
        local v = sin(m * pi * u) * sin(n * pi * w) - sin(n * pi * u) * sin(m * pi * w)
        local av = abs(v)
        if av > 0.22 then
          lvl(3 + av * 10 + energy * 2)
          circ((u - 0.5) * 110, (w - 0.5) * 56, 0.6 + av * 1.7)
          screen.fill()
        end
      end
    end
  end,
})

add("constellations", {
  new = function(rg)
    local n = rg.i(9, 18)
    local p, e = {}, {}
    for k = 1, n do p[k] = {x = (rg.f() - 0.5) * 112, y = (rg.f() - 0.5) * 56, ph = rg.f() * TAU} end
    for k = 1, n do
      local best, bd = nil, 1e9
      for j = 1, n do
        if j ~= k then
          local d = (p[k].x - p[j].x) ^ 2 + (p[k].y - p[j].y) ^ 2
          if d < bd then best, bd = j, d end
        end
      end
      if best and bd < 1500 then e[#e + 1] = {k, best} end
    end
    return {p = p, e = e, n = n, cost = n * 3 + #e * 4 + 2}
  end,
  draw = function(s)
    lvl(3)
    for _, ed in ipairs(s.e) do
      mv(s.p[ed[1]].x, s.p[ed[1]].y); ln(s.p[ed[2]].x, s.p[ed[2]].y); screen.stroke()
    end
    for k, o in ipairs(s.p) do
      lvl(6 + 9 * (0.5 + 0.5 * sin(vt * 1.3 + o.ph)) + P(k) * 3)
      circ(o.x, o.y, 0.8 + 0.8 * P(k))
      screen.fill()
    end
  end,
})

add("bubbles", {
  new = function(rg)
    return {b = {}, rate = 0.04 + rg.f() * 0.12, cost = 16 * 4}
  end,
  hit = function(s, i, vel, pn)
    if #s.b < 16 then
      s.b[#s.b + 1] = {x = (pn - 0.5) * 100, y = 34, r = 1.5 + vel * 5, v = 0.3 + math.random() * 0.6,
                       ph = math.random() * TAU}
    end
  end,
  upd = function(s)
    if math.random() < s.rate and #s.b < 16 then
      s.b[#s.b + 1] = {x = (math.random() - 0.5) * 110, y = 34, r = 1 + math.random() * 5,
                       v = 0.25 + math.random() * 0.6, ph = math.random() * TAU}
    end
    for k = #s.b, 1, -1 do
      local o = s.b[k]
      o.y = o.y - o.v
      if o.y < -36 then table.remove(s.b, k) end
    end
  end,
  draw = function(s)
    for _, o in ipairs(s.b) do
      lvl(4 + (34 - o.y) * 0.1 + o.r)
      circ(o.x + 3 * sin(o.ph + vt * 1.5 + o.y * 0.1), o.y, o.r)
      screen.stroke()
    end
  end,
})

local function tri(s, x, y, r, d, rot)
  if d == 0 then
    for k = 0, 3 do
      local a = rot + k * TAU / 3
      local px, py = x + cos(a) * r, y + sin(a) * r
      if k == 0 then mv(px, py) else ln(px, py) end
    end
    screen.stroke()
    return
  end
  for k = 0, 2 do
    local a = rot + k * TAU / 3
    tri(s, x + cos(a) * r * 0.5, y + sin(a) * r * 0.5, r * 0.5, d - 1, rot)
  end
end

add("fractal", {
  new = function(rg)
    local d = rg.i(2, 4)
    return {d = d, R = 22 + rg.f() * 14, sp = (rg.f() - 0.5) * 0.4, cost = 3 ^ d * 5 + 2}
  end,
  draw = function(s)
    lvl(8 + energy * 4)
    tri(s, 0, 0, s.R * (1 + 0.06 * sin(vt * 0.5)), s.d, vt * s.sp - pi / 2)
  end,
})

add("dna", {
  new = function(rg)
    local n = rg.i(14, 26)
    return {n = n, A = 8 + rg.f() * 12, k = 0.06 + rg.f() * 0.06, sp = 0.5 + rg.f() * 1.5, cost = n * 5 + 2 * (n + 2)}
  end,
  draw = function(s)
    for i = 0, s.n do
      local x = -60 + i / s.n * 120
      local a = x * s.k + vt * s.sp
      lvl(3 + 5 * (0.5 + 0.5 * cos(a)))
      mv(x, sin(a) * s.A); ln(x, -sin(a) * s.A); screen.stroke()
    end
    for sgn = -1, 1, 2 do
      lvl(sgn > 0 and 14 or 10)
      for i = 0, s.n do
        local x = -60 + i / s.n * 120
        local y = sgn * sin(x * s.k + vt * s.sp) * s.A
        if i == 0 then mv(x, y) else ln(x, y) end
      end
      screen.stroke()
    end
  end,
})

add("snow", {
  new = function(rg)
    local n = rg.i(40, 110)
    local p = {}
    for k = 1, n do p[k] = {x = (rg.f() - 0.5) * 140, y = (rg.f() - 0.5) * 80, v = 0.15 + rg.f() * 0.7} end
    return {p = p, n = n, wind = (rg.f() - 0.5) * 0.6, up = rg.f() < 0.25, cost = n + 4}
  end,
  upd = function(s)
    local dir = s.up and -1 or 1
    for _, o in ipairs(s.p) do
      o.y = o.y + o.v * dir * (1 + energy * 0.5)
      o.x = o.x + s.wind * o.v
      if o.y > 40 then o.y = -40 elseif o.y < -40 then o.y = 40 end
      if o.x > 70 then o.x = -70 elseif o.x < -70 then o.x = 70 end
    end
  end,
  draw = function(s)
    lvl(11)
    for _, o in ipairs(s.p) do
      local a, b = pt(o.x, o.y)
      screen.rect(a, b, 1, 1)
    end
    screen.fill()
  end,
})

add("radar", {
  new = function(rg)
    return {sp = 0.4 + rg.f() * 1.2, R = 24 + rg.f() * 10, blips = {}, rings = rg.i(2, 4), cost = 10 * 4 + 4 * 3 + 12 * 3 + 4}
  end,
  hit = function(s, i, vel, pn)
    s.blips[#s.blips + 1] = {a = math.random() * TAU, r = 0.2 + pn * 0.8, l = 15}
    if #s.blips > 12 then table.remove(s.blips, 1) end
  end,
  upd = function(s)
    for k = #s.blips, 1, -1 do
      s.blips[k].l = s.blips[k].l - 0.22
      if s.blips[k].l < 1 then table.remove(s.blips, k) end
    end
  end,
  draw = function(s)
    lvl(3)
    for j = 1, s.rings do circ(0, 0, s.R * j / s.rings); screen.stroke() end
    local a0 = vt * s.sp
    for j = 0, 9 do
      lvl(13 - j * 1.3)
      local a = a0 - j * 0.09
      mv(0, 0); ln(cos(a) * s.R, sin(a) * s.R * 0.8); screen.stroke()
    end
    for _, b in ipairs(s.blips) do
      lvl(b.l)
      circ(cos(b.a) * s.R * b.r, sin(b.a) * s.R * b.r * 0.8, 1.2)
      screen.fill()
    end
  end,
})

add("asemic", {
  new = function(rg)
    local gl = {}
    for g = 1, 24 do
      local np = rg.i(3, 6)
      local pts = {}
      for k = 1, np do pts[k] = {rg.f() * 6, rg.f() * 7} end
      gl[g] = pts
    end
    local rows = rg.i(2, 4)
    local seq = {}
    for r = 1, rows do
      seq[r] = {}
      for c = 1, 40 do seq[r][c] = rg.i(1, 24) end
    end
    return {gl = gl, rows = rows, seq = seq, sp = 1.5 + rg.f() * 5, dir = (rg.f() < 0.5) and 1 or -1,
            cost = rows * 15 * 7 + 4}
  end,
  draw = function(s)
    local cw = 8
    local off = (vt * s.sp * s.dir) % 40
    for r = 1, s.rows do
      local y0 = (r - (s.rows + 1) / 2) * 12
      local shift = off * cw + r * 3
      local c0 = floor(shift / cw)
      for k = -8, 7 do
        local idx = ((c0 + k) % 40) + 1
        local gx = k * cw - (shift % cw)
        local g = s.gl[s.seq[r][idx]]
        lvl(6 + (r % 2) * 4 + energy * 2)
        for p = 1, #g do
          if p == 1 then mv(gx + g[p][1], y0 + g[p][2] - 3) else ln(gx + g[p][1], y0 + g[p][2] - 3) end
        end
        screen.stroke()
      end
    end
  end,
})

add("lightning", {
  new = function(rg)
    return {seg = {}, rate = 0.006 + rg.f() * 0.02, cost = 44 * 4}
  end,
  hit = function(s, i, vel, pn)
    if vel > 0.55 and math.random() < 0.5 then s.zap = true end
  end,
  upd = function(s)
    for k = #s.seg, 1, -1 do
      s.seg[k].l = s.seg[k].l - 0.9
      if s.seg[k].l <= 0.5 then table.remove(s.seg, k) end
    end
    if (s.zap or math.random() < s.rate) and #s.seg == 0 then
      s.zap = false
      local x, y = (math.random() - 0.5) * 80, -34
      local function bolt(x0, y0, n, dir, l)
        for _ = 1, n do
          local x1, y1 = x0 + (math.random() - 0.5) * 14 + dir * 3, y0 + 4 + math.random() * 4
          s.seg[#s.seg + 1] = {x0, y0, x1, y1, l = l}
          x0, y0 = x1, y1
        end
        return x0, y0
      end
      local bx, by = x, y
      for part = 1, 3 do
        bx, by = bolt(bx, by, 4, 0, 15)
        if math.random() < 0.7 then bolt(bx, by, 3, math.random() < 0.5 and -1 or 1, 9) end
      end
    end
  end,
  draw = function(s)
    for _, g in ipairs(s.seg) do
      lvl(g.l)
      mv(g[1], g[2]); ln(g[3], g[4]); screen.stroke()
    end
  end,
})

-- ------------------------------------------------------- layers, third series (mushrooms and more)

add("mushrooms", {
  new = function(rg)
    local n = rg.i(3, 7)
    local m = {}
    for k = 1, n do
      m[k] = {x = (k - (n + 1) / 2) * (96 / n) + (rg.f() - 0.5) * 6, w = 5 + rg.f() * 9, h = 4 + rg.f() * 8,
              st = 6 + rg.f() * 14, ph = rg.f() * TAU, spots = rg.i(0, 3)}
    end
    return {m = m, base = 22 + rg.f() * 6, cost = n * 26 + 4}
  end,
  draw = function(s)
    for k, o in ipairs(s.m) do
      local g = 0.85 + 0.15 * sin(vt * 0.6 + o.ph) + P(k) * 0.25
      local top = s.base - o.st * g
      lvl(5 + P(k) * 6)
      mv(o.x - 1.5, s.base); ln(o.x - 1.2, top)
      mv(o.x + 1.5, s.base); ln(o.x + 1.2, top)
      screen.stroke()
      lvl(11 + P(k) * 4)
      for j = 0, 10 do
        local a = pi + j / 10 * pi
        local x, y = o.x + cos(a) * o.w * g, top + sin(a) * o.h * g
        if j == 0 then mv(x, y) else ln(x, y) end
      end
      ln(o.x - o.w * g, top)
      screen.stroke()
      for q = 1, o.spots do
        circ(o.x + (q - 2) * o.w * 0.4 * g, top - o.h * 0.5 * g, 0.8)
        screen.fill()
      end
    end
    lvl(4); mv(-60, s.base); ln(60, s.base); screen.stroke()
  end,
})

add("sporeprint", {
  new = function(rg)
    local n, dd = rg.i(10, 24), rg.i(5, 9)
    return {n = n, dd = dd, R = 20 + rg.f() * 12, sp = 0.4 + rg.f() * 1.4, cost = n * dd + 4}
  end,
  draw = function(s)
    lvl(8 + energy * 4)
    for k = 0, s.n - 1 do
      local a = k / s.n * TAU + vt * 0.05
      local ca, sa = cos(a), sin(a)
      for d = 1, s.dd do
        local r = s.R * (d / s.dd) * (1 + 0.08 * sin(vt * s.sp + k))
        local x, y = pt(ca * r, sa * r * 0.8)
        screen.rect(x, y, 1, 1)
      end
    end
    screen.fill()
  end,
})

add("mycelium", {
  new = function(rg)
    local segs, tips = {}, {{0, 0, rg.f() * TAU, 0}}
    local guard = 0
    while #segs < 56 and #tips > 0 and guard < 400 do
      guard = guard + 1
      local i = rg.i(1, #tips)
      local t = tips[i]
      local ang = t[3] + (rg.f() - 0.5) * 0.9
      local len = 3 + rg.f() * 5
      local x1, y1 = t[1] + cos(ang) * len, t[2] + sin(ang) * len * 0.8
      segs[#segs + 1] = {t[1], t[2], x1, y1, t[4]}
      t[1], t[2], t[3], t[4] = x1, y1, ang, t[4] + 1
      if rg.f() < 0.18 and #tips < 8 then tips[#tips + 1] = {x1, y1, ang + (rg.f() - 0.5) * 1.6, t[4]} end
      if abs(x1) > 62 or abs(y1) > 32 then table.remove(tips, i) end
    end
    return {segs = segs, sp = 0.05 + rg.f() * 0.12, cost = 56 * 4 + 4}
  end,
  draw = function(s)
    local n = #s.segs
    local g = (vt * s.sp) % 1.5
    local count = floor(min(1, g) * n)
    local fade = (g > 1) and (1 - (g - 1) * 2) or 1
    for i = 1, count do
      local sg = s.segs[i]
      lvl((3 + (i / n) * 9 + ((i > count - 4) and 3 or 0)) * max(0.2, fade))
      mv(sg[1], sg[2]); ln(sg[3], sg[4]); screen.stroke()
    end
  end,
})

add("fairy_ring", {
  new = function(rg)
    local n = rg.i(8, 18)
    local rx = 22 + rg.f() * 22
    return {n = n, rx = rx, ry = rx * (0.35 + rg.f() * 0.25), sp = (rg.f() < 0.5 and -1 or 1) * (0.05 + rg.f() * 0.2),
            cost = n * 7 + 4}
  end,
  draw = function(s)
    for k = 0, s.n - 1 do
      local a = k / s.n * TAU + vt * s.sp
      local depth = 0.5 + 0.5 * sin(a)
      local x, y = cos(a) * s.rx, sin(a) * s.ry
      local size = 1.5 + 1.8 * depth
      lvl(4 + 7 * depth + P(k + 1) * 4)
      circ(x, y - size * 0.4, size)
      screen.fill()
      mv(x, y + size); ln(x, y - size * 0.4); screen.stroke()
    end
  end,
})

add("gills", {
  new = function(rg)
    return {n = rg.i(20, 44), R = 14 + rg.f() * 20, r0 = 2 + rg.f() * 4, sp = 0.05 + rg.f() * 0.3,
            cost = 44 * 2 + 36}
  end,
  draw = function(s)
    lvl(11)
    for j = 0, 28 do
      local a = j / 28 * TAU
      local x, y = cos(a) * s.R, sin(a) * s.R * 0.7
      if j == 0 then mv(x, y) else ln(x, y) end
    end
    screen.stroke()
    lvl(4 + energy * 3)
    for k = 0, s.n - 1 do
      local a = k / s.n * TAU + vt * s.sp
      local r1 = s.R * (0.82 + 0.18 * sin(k * 2.3 + vt * 0.5))
      mv(cos(a) * s.r0, sin(a) * s.r0 * 0.7)
      ln(cos(a) * r1, sin(a) * r1 * 0.7)
    end
    screen.stroke()
  end,
})

add("hyphae", {
  new = function(rg)
    local k = rg.i(4, 9)
    local th = {}
    for i = 1, k do
      th[i] = {x = (rg.f() - 0.5) * 70, y = (rg.f() - 0.5) * 36, a0 = rg.f() * TAU, ph = rg.f() * TAU,
               w = 0.25 + rg.f() * 0.5}
    end
    return {th = th, pts = 26, cost = k * 29}
  end,
  draw = function(s)
    for i, t in ipairs(s.th) do
      local x, y, ang = t.x, t.y, t.a0 + sin(vt * 0.1 + t.ph)
      lvl(4 + (i % 4) * 3 + P(i) * 4)
      mv(x, y)
      for j = 1, s.pts do
        ang = ang + 0.35 * sin(vt * t.w + t.ph + j * 0.5)
        x, y = x + cos(ang) * 2.6, y + sin(ang) * 2.6
        ln(x, y)
      end
      screen.stroke()
    end
  end,
})

add("pulsar", {
  new = function(rg)
    local rows = rg.i(7, 11)
    return {rows = rows, pts = 32, k = rg.i(2, 5), sp = 0.4 + rg.f() * 1.2, cost = rows * 35}
  end,
  draw = function(s)
    for r = 0, s.rows - 1 do
      local y = -24 + r / (s.rows - 1) * 48
      lvl(3 + r * 1.1 + energy * 2)
      for j = 0, s.pts do
        local u = (j / s.pts - 0.5) * 2
        local h = math.exp(-u * u * 4) * (0.5 + 0.5 * sin(u * s.k * 3 + vt * s.sp - r * 0.4)) * 9 * (1 + energy)
        if j == 0 then mv(-50, y - h) else ln(u * 50, y - h) end
      end
      screen.stroke()
    end
  end,
})

add("hexagons", {
  new = function(rg)
    local cols, rows = rg.i(6, 9), rg.i(3, 5)
    return {cols = cols, rows = rows, r = 6 + rg.f() * 4, sp = 0.5 + rg.f() * 1.5, k = 0.1 + rg.f() * 0.15,
            cost = cols * rows * 9 + 4}
  end,
  draw = function(s)
    local dx, dy = s.r * 1.73, s.r * 1.5
    for rr = 0, s.rows - 1 do
      for c = 0, s.cols - 1 do
        local x = (c - (s.cols - 1) / 2) * dx + (rr % 2) * dx / 2
        local y = (rr - (s.rows - 1) / 2) * dy
        local v = sin(sqrt(x * x + y * y) * s.k * 2 - vt * s.sp)
        if v > -0.15 then
          lvl(3 + (v + 1) * 6 + energy * 2)
          for q = 0, 6 do
            local a = q / 6 * TAU + pi / 6
            local px, py = x + cos(a) * s.r * 0.95, y + sin(a) * s.r * 0.95
            if q == 0 then mv(px, py) else ln(px, py) end
          end
          screen.stroke()
        end
      end
    end
  end,
})

add("knot", {
  new = function(rg)
    local p = rg.i(2, 5)
    local q = p + rg.pick({1, 2, 3})
    if gcd(p, q) ~= 1 then q = q + 1 end
    return {p = p, q = q, pts = 120, R = 7 + rg.f() * 5, sp = 0.2 + rg.f() * 0.5, X = {}, Y = {}, Z = {},
            cost = 2 * 120 + 6}
  end,
  draw = function(s)
    local ay, ax = vt * s.sp, vt * s.sp * 0.6
    local cy, sy, cx, sx = cos(ay), sin(ay), cos(ax), sin(ax)
    for j = 0, s.pts do
      local t = j / s.pts * TAU
      local r = 2 + cos(s.q * t)
      local x, y, z = r * cos(s.p * t), r * sin(s.p * t), sin(s.q * t)
      local x1, z1 = x * cy + z * sy, -x * sy + z * cy
      local y1, z2 = y * cx - z1 * sx, y * sx + z1 * cx
      local k = s.R / (1 + 0.12 * (3 - z2))
      s.X[j], s.Y[j], s.Z[j] = x1 * k, y1 * k, z2
    end
    for pass = 0, 1 do
      lvl(pass == 0 and 4 or 13)
      local on = false
      for j = 0, s.pts do
        if (s.Z[j] >= 0) == (pass == 1) then
          if on then ln(s.X[j], s.Y[j]) else mv(s.X[j], s.Y[j]); on = true end
        else
          on = false
        end
      end
      screen.stroke()
    end
  end,
})

add("snowflake", {
  new = function(rg)
    local arms = rg.pick({5, 6, 6, 8, 12})
    local br = rg.i(2, 3)
    return {arms = arms, br = br, L = 18 + rg.f() * 12, ang = 0.6 + rg.f() * 0.7, cost = arms * (2 + br * 4) + 4}
  end,
  draw = function(s)
    lvl(11 + energy * 3)
    for a = 0, s.arms - 1 do
      local th = a / s.arms * TAU + vt * 0.1
      local c, sn = cos(th), sin(th)
      mv(0, 0); ln(c * s.L, sn * s.L)
      for b = 1, s.br do
        local f = b / (s.br + 1) + 0.1
        local px, py = c * s.L * f, sn * s.L * f
        local bl = s.L * 0.35 * (1 - f) * (1 + 0.2 * sin(vt + b))
        for sgn = -1, 1, 2 do
          local t2 = th + sgn * s.ang
          mv(px, py); ln(px + cos(t2) * bl, py + sin(t2) * bl)
        end
      end
    end
    screen.stroke()
  end,
})

add("supernova", {
  new = function(rg)
    return {b = {}, cost = 3 * 14 * 4 + 4}
  end,
  hit = function(s, i, vel, pn)
    if #s.b < 3 then
      s.b[#s.b + 1] = {x = (pn - 0.5) * 80, y = (i - 2.5) * 9, n = math.random(8, 14),
                       rot = math.random() * TAU, R = 14 + vel * 26, l = 0}
    end
  end,
  upd = function(s)
    if #s.b == 0 and math.random() < 0.004 then
      s.b[1] = {x = (math.random() - 0.5) * 80, y = (math.random() - 0.5) * 30, n = math.random(8, 14),
                rot = math.random() * TAU, R = 18 + math.random() * 20, l = 0}
    end
    for k = #s.b, 1, -1 do
      s.b[k].l = s.b[k].l + 0.035
      if s.b[k].l >= 1 then table.remove(s.b, k) end
    end
  end,
  draw = function(s)
    for _, o in ipairs(s.b) do
      lvl(15 * (1 - o.l))
      for k = 0, o.n - 1 do
        local a = o.rot + k / o.n * TAU
        local r1, r2 = o.l * o.R * 0.3, o.l * o.R
        mv(o.x + cos(a) * r1, o.y + sin(a) * r1)
        ln(o.x + cos(a) * r2, o.y + sin(a) * r2)
        screen.stroke()
      end
    end
  end,
})

add("dotmatrix", {
  new = function(rg)
    local gx, gy = rg.i(18, 26), rg.i(7, 10)
    return {gx = gx, gy = gy, k1 = 0.3 + rg.f() * 0.6, k2 = 0.3 + rg.f() * 0.6, sp = 0.6 + rg.f() * 1.8,
            cost = gx * gy + 10}
  end,
  draw = function(s)
    for pass = 1, 3 do
      lvl(3 + pass * 4 + energy * 2)
      local lo, hi = (pass - 1) / 3, pass / 3
      for i = 0, s.gx - 1 do
        for j = 0, s.gy - 1 do
          local v = 0.5 + 0.5 * sin(i * s.k1 + j * s.k2 + vt * s.sp)
          if v >= lo and (v < hi or (pass == 3 and v <= 1)) then
            local a, b = pt((i / (s.gx - 1) - 0.5) * 112, (j / (s.gy - 1) - 0.5) * 54)
            screen.rect(a - pass / 2, b - pass / 2, pass, pass)
          end
        end
      end
      screen.fill()
    end
  end,
})

add("checkerboard", {
  new = function(rg)
    local rows, cols = rg.i(5, 8), rg.i(6, 10)
    return {rows = rows, cols = cols, sp = 0.2 + rg.f() * 0.8, hy = -8 + rg.f() * 6, cost = rows * cols * 3 + rows + 6}
  end,
  draw = function(s)
    local adv = vt * s.sp
    local off, base = adv % 1, floor(adv)
    local function yz(z) return s.hy + (30 - s.hy) * z ^ 1.6 end
    local function wz(z) return 14 + 90 * z end
    lvl(5 + energy * 3)
    for r = 0, s.rows - 1 do
      local z1, z2 = (r + off) / s.rows, (r + 1 + off) / s.rows
      if z2 > 1 then z2 = 1 end
      local y1, y2, w1, w2 = yz(z1), yz(z2), wz(z1), wz(z2)
      for c = 0, s.cols - 1 do
        if (c + r + base) % 2 == 0 then
          local a, b = (c / s.cols - 0.5), ((c + 1) / s.cols - 0.5)
          mv(a * w1, y1); ln(b * w1, y1); ln(b * w2, y2); ln(a * w2, y2); ln(a * w1, y1)
          screen.fill()
        end
      end
    end
  end,
})

add("inkblot", {
  new = function(rg)
    return {R = 14 + rg.f() * 10, p1 = rg.f() * TAU, p2 = rg.f() * TAU, p3 = rg.f() * TAU, pts = 40,
            cost = 4 * 43}
  end,
  draw = function(s)
    local function rad(th, sc)
      return s.R * sc * (0.6 + 0.2 * sin(3 * th + vt * 0.4 + s.p1) + 0.12 * sin(5 * th - vt * 0.3 + s.p2)
             + 0.1 * sin(8 * th + vt * 0.2 + s.p3)) * (1 + 0.1 * energy)
    end
    for pass = 0, 1 do
      local sc = (pass == 0) and 1 or 0.55
      lvl(pass == 0 and 13 or 7)
      for sgn = -1, 1, 2 do
        for j = 0, s.pts do
          local th = -pi / 2 + j / s.pts * pi
          local r = rad(th, sc)
          local x, y = sgn * cos(th) * r * 1.2, sin(th) * r
          if j == 0 then mv(x, y) else ln(x, y) end
        end
        screen.stroke()
      end
    end
  end,
})

add("urchin", {
  new = function(rg)
    local n = rg.i(16, 36)
    local d = {}
    for k = 1, n do
      local z, ph = rg.f() * 2 - 1, rg.f() * TAU
      local r = sqrt(1 - z * z)
      d[k] = {cos(ph) * r, sin(ph) * r, z}
    end
    return {d = d, n = n, R0 = 6 + rg.f() * 6, L = 8 + rg.f() * 10, sp = 0.15 + rg.f() * 0.4, cost = n * 4 + 4}
  end,
  draw = function(s)
    local ay, ax = vt * s.sp, vt * s.sp * 0.55
    local cy, sy, cx, sx = cos(ay), sin(ay), cos(ax), sin(ax)
    for k, v in ipairs(s.d) do
      local x1, z1 = v[1] * cy + v[3] * sy, -v[1] * sy + v[3] * cy
      local y1, z2 = v[2] * cx - z1 * sx, v[2] * sx + z1 * cx
      local len = s.R0 + s.L * (1 + 0.3 * sin(vt * 1.2 + k)) * (1 + 0.2 * energy)
      lvl(3 + (z2 + 1) * 5)
      mv(x1 * s.R0, y1 * s.R0); ln(x1 * len, y1 * len); screen.stroke()
    end
  end,
})

add("lichen", {
  new = function(rg)
    local n = rg.i(60, 110)
    local p = {{0, 0, 0}}
    for k = 2, n do
      local o = p[rg.i(1, #p)]
      local a = rg.f() * TAU
      local x, y = o[1] + cos(a) * 2.6, o[2] + sin(a) * 2.2
      if abs(x) < 60 and abs(y) < 30 then p[#p + 1] = {x, y, sqrt(x * x + y * y)} end
    end
    return {p = p, sp = 4 + rg.f() * 8, cost = 2 * #p + 6}
  end,
  draw = function(s)
    lvl(5)
    for _, o in ipairs(s.p) do
      local a, b = pt(o[1], o[2])
      screen.rect(a, b, 1.5, 1.5)
    end
    screen.fill()
    lvl(14)
    for _, o in ipairs(s.p) do
      if (o[3] - vt * s.sp) % 40 < 6 then
        local a, b = pt(o[1], o[2])
        screen.rect(a - 0.5, b - 0.5, 2.5, 2.5)
      end
    end
    screen.fill()
  end,
})

-- ------------------------------------------------------- layers, fourth series

add("amanita", {
  new = function(rg)
    local sp = {}
    for k = 1, rg.i(4, 8) do sp[k] = {rg.f() * 2 - 1, rg.f() * 0.8, 0.8 + rg.f() * 1.4} end
    return {R = 14 + rg.f() * 9, H = 12 + rg.f() * 9, sp = sp, gills = rg.i(9, 15), sw = 0.2 + rg.f() * 0.5,
            cost = 22 + 4 + 8 + 15 * 2 + #sp * 3}
  end,
  draw = function(s)
    local sway = sin(vt * s.sw) * 0.06
    local R = s.R * (1 + 0.05 * energy)
    local top = -s.H
    local function X(x, y) return x + sway * (y + 20) * 6 end
    lvl(5)
    for j = 0, 20 do
      local a = pi + j / 20 * pi
      local x, y = cos(a) * R, top + sin(a) * R * 0.72
      if j == 0 then mv(X(x, y), y) else ln(X(x, y), y) end
    end
    screen.fill()
    lvl(14)
    for j = 0, 20 do
      local a = pi + j / 20 * pi
      local x, y = cos(a) * R, top + sin(a) * R * 0.72
      if j == 0 then mv(X(x, y), y) else ln(X(x, y), y) end
    end
    ln(X(-R, top), top)
    screen.stroke()
    lvl(8)
    mv(X(-3, top), top); ln(X(-3.5, 24), 24); mv(X(3, top), top); ln(X(3.5, 24), 24)
    mv(X(-6, 24), 24); ln(X(6, 24), 24)
    screen.stroke()
    lvl(5)
    for g = 0, s.gills - 1 do
      local u = (g / (s.gills - 1)) * 2 - 1
      mv(X(u * R, top), top); ln(X(u * 2.5, top + 5), top + 5)
    end
    screen.stroke()
    lvl(15)
    for _, d in ipairs(s.sp) do
      circ(X(d[1] * R * 0.75, top - d[2] * R * 0.5), top - d[2] * R * 0.5, d[3])
      screen.fill()
    end
  end,
})

add("leaves", {
  new = function(rg)
    local n = rg.i(9, 18)
    local l = {}
    for k = 1, n do
      l[k] = {x = (rg.f() - 0.5) * 120, y = (rg.f() - 0.5) * 80, v = 0.15 + rg.f() * 0.5, r = 2 + rg.f() * 3,
              rot = rg.f() * TAU, w = (rg.f() - 0.5) * 0.12, ph = rg.f() * TAU}
    end
    return {l = l, cost = n * 6}
  end,
  upd = function(s)
    for _, o in ipairs(s.l) do
      o.y = o.y + o.v
      o.x = o.x + sin(o.ph + o.y * 0.08) * 0.4
      o.rot = o.rot + o.w
      if o.y > 40 then o.y = -40 end
    end
  end,
  draw = function(s)
    for k, o in ipairs(s.l) do
      lvl(4 + (k % 5) * 2 + P(k) * 4)
      local c, sn = cos(o.rot), sin(o.rot)
      mv(o.x + c * o.r * 1.6, o.y + sn * o.r * 1.6)
      ln(o.x - sn * o.r, o.y + c * o.r)
      ln(o.x - c * o.r * 1.6, o.y - sn * o.r * 1.6)
      ln(o.x + sn * o.r, o.y - c * o.r)
      screen.fill()
    end
  end,
})

add("equalizer", {
  new = function(rg)
    local n = rg.i(14, 28)
    local b = {}
    for k = 1, n do b[k] = {f = 0.4 + rg.f() * 1.6, ph = rg.f() * TAU, a = 0.3 + rg.f() * 0.7} end
    return {n = n, b = b, mirror = rg.f() < 0.5, cost = n * 2 + 6}
  end,
  draw = function(s)
    local w = 112 / s.n
    local H = {}
    for k, o in ipairs(s.b) do
      H[k] = (0.5 + 0.5 * sin(vt * o.f + o.ph)) * 18 * o.a + P(k) * 14
    end
    lvl(8)
    for k = 1, s.n do
      local x = -56 + (k - 1) * w
      local a, b = pt(x, s.mirror and -H[k] / 2 or 28 - H[k])
      screen.rect(a, b, math.max(1, w - 1), s.mirror and H[k] or H[k])
    end
    screen.fill()
    lvl(15)
    for k = 1, s.n do
      local x = -56 + (k - 1) * w
      local a, b = pt(x, s.mirror and -H[k] / 2 - 1 or 27 - H[k])
      screen.rect(a, b, math.max(1, w - 1), 1)
    end
    screen.fill()
  end,
})

add("pinwheel", {
  new = function(rg)
    local n = rg.i(3, 9)
    return {n = n, R = 22 + rg.f() * 14, sp = (rg.f() < 0.5 and -1 or 1) * (0.2 + rg.f() * 0.8), twist = rg.f() * 0.7,
            cost = n * 6 + 2}
  end,
  draw = function(s)
    for k = 0, s.n - 1 do
      local a = k / s.n * TAU + vt * s.sp
      local a2 = a + TAU / s.n * 0.9
      lvl((k % 2 == 0) and 12 or 5)
      mv(0, 0)
      ln(cos(a) * s.R, sin(a) * s.R)
      ln(cos(a2 - s.twist) * s.R * 0.7, sin(a2 - s.twist) * s.R * 0.7)
      screen.fill()
    end
  end,
})

add("dunes", {
  new = function(rg)
    local n = rg.i(3, 5)
    local d = {}
    for k = 1, n do
      d[k] = {base = -8 + k * 8 + rg.f() * 4, amp = 3 + rg.f() * 6, f = 0.03 + rg.f() * 0.06, sp = 0.1 + rg.f() * 0.4,
              ph = rg.f() * TAU}
    end
    return {d = d, cost = n * 32}
  end,
  draw = function(s)
    for k, o in ipairs(s.d) do
      lvl(2 + k * 2)
      for i = 0, 20 do
        local x = -62 + i * 6.2
        local y = o.base + o.amp * sin(x * o.f + vt * o.sp + o.ph) + o.amp * 0.4 * sin(x * o.f * 2.7 - vt * o.sp)
        if i == 0 then mv(x, y) else ln(x, y) end
      end
      ln(62, 40); ln(-62, 40)
      screen.fill()
      lvl(7 + k * 1.5 + energy * 2)
      for i = 0, 20 do
        local x = -62 + i * 6.2
        local y = o.base + o.amp * sin(x * o.f + vt * o.sp + o.ph) + o.amp * 0.4 * sin(x * o.f * 2.7 - vt * o.sp)
        if i == 0 then mv(x, y) else ln(x, y) end
      end
      screen.stroke()
    end
  end,
})

add("globe", {
  new = function(rg)
    local nlat, nlon = rg.i(3, 6), rg.i(4, 8)
    return {nlat = nlat, nlon = nlon, R = 16 + rg.f() * 10, sp = 0.2 + rg.f() * 0.5, tilt = 0.2 + rg.f() * 0.7,
            cost = (nlat + nlon) * 17 + 4}
  end,
  draw = function(s)
    local ay = vt * s.sp
    local cy, sy, ct, st = cos(ay), sin(ay), cos(s.tilt), sin(s.tilt)
    local function proj(lat, lon)
      local x, y, z = cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon)
      local x1, z1 = x * cy + z * sy, -x * sy + z * cy
      local y1, z2 = y * ct - z1 * st, y * st + z1 * ct
      return x1 * s.R, y1 * s.R, z2
    end
    lvl(9 + energy * 3)
    for i = 1, s.nlat do
      local lat = -pi / 2 + i / (s.nlat + 1) * pi
      for j = 0, 15 do
        local x, y = proj(lat, j / 15 * TAU)
        if j == 0 then mv(x, y) else ln(x, y) end
      end
      screen.stroke()
    end
    lvl(6)
    for i = 0, s.nlon - 1 do
      local lon = i / s.nlon * pi
      for j = 0, 15 do
        local x, y = proj(-pi / 2 + j / 15 * pi, lon)
        if j == 0 then mv(x, y) else ln(x, y) end
      end
      for j = 15, 0, -1 do
        local x, y = proj(-pi / 2 + j / 15 * pi, lon + pi)
        ln(x, y)
      end
      screen.stroke()
    end
  end,
})

add("torus", {
  new = function(rg)
    local nm, nn = rg.i(7, 11), rg.i(4, 7)
    return {R = 11 + rg.f() * 5, r = 4 + rg.f() * 4, nm = nm, nn = nn, sp = 0.15 + rg.f() * 0.4,
            cost = nm * 15 + nn * 17}
  end,
  draw = function(s)
    local ay, ax = vt * s.sp, vt * s.sp * 0.7 + 0.8
    local cy, sy, cx, sx = cos(ay), sin(ay), cos(ax), sin(ax)
    local function proj(u, v)
      local x = (s.R + s.r * cos(v)) * cos(u)
      local y = (s.R + s.r * cos(v)) * sin(u)
      local z = s.r * sin(v)
      local x1, z1 = x * cy + z * sy, -x * sy + z * cy
      local y1 = y * cx - z1 * sx
      return x1, y1
    end
    lvl(10 + energy * 3)
    for i = 0, s.nm - 1 do
      local u = i / s.nm * TAU
      for j = 0, 12 do
        local x, y = proj(u, j / 12 * TAU)
        if j == 0 then mv(x, y) else ln(x, y) end
      end
      screen.stroke()
    end
    lvl(5)
    for i = 0, s.nn - 1 do
      local v = i / s.nn * TAU
      for j = 0, 14 do
        local x, y = proj(j / 14 * TAU, v)
        if j == 0 then mv(x, y) else ln(x, y) end
      end
      screen.stroke()
    end
  end,
})

add("squares", {
  new = function(rg)
    local n = rg.i(7, 14)
    return {n = n, tw = (rg.f() - 0.5) * 0.35, sp = 0.15 + rg.f() * 0.5, spin = (rg.f() - 0.5) * 0.4, cost = n * 6}
  end,
  draw = function(s)
    for j = 0, s.n - 1 do
      local z = ((j / s.n) + vt * s.sp * 0.1) % 1
      local half = 2 + z ^ 1.8 * 56
      local rot = j * s.tw + vt * s.spin
      local c, sn = cos(rot), sin(rot)
      lvl(2 + z * 12 + energy * 2)
      for q = 0, 4 do
        local qx = ((q == 1 or q == 2) and 1 or -1) * half
        local qy = ((q == 2 or q == 3) and 1 or -1) * half
        local x, y = qx * c - qy * sn, (qx * sn + qy * c) * 0.7
        if q == 0 then mv(x, y) else ln(x, y) end
      end
      screen.stroke()
    end
  end,
})

add("starwheel", {
  new = function(rg)
    local n = rg.i(5, 12)
    local k = rg.i(2, math.max(2, floor(n / 2) - (n % 2 == 0 and 1 or 0) + 0))
    if gcd(n, k) ~= 1 then k = 2 end
    local cp = rg.i(1, 3)
    return {n = n, k = k, cp = cp, R = 14 + rg.f() * 14, sp = (rg.f() - 0.5) * 0.5, cost = cp * (n + 3)}
  end,
  draw = function(s)
    for c = 1, s.cp do
      local rad = s.R * (1 - (c - 1) * 0.28) * (1 + 0.08 * sin(vt * 0.7 + c))
      lvl(14 - (c - 1) * 4 + energy * 2)
      for j = 0, s.n do
        local a = (j * s.k % s.n) / s.n * TAU + vt * s.sp * c - pi / 2
        local x, y = cos(a) * rad, sin(a) * rad * 0.9
        if j == 0 then mv(x, y) else ln(x, y) end
      end
      screen.stroke()
    end
  end,
})

add("pulse_trace", {
  new = function(rg)
    local ch = rg.i(1, 3)
    local buf = {}
    for c = 1, ch do
      buf[c] = {}
      for k = 1, 60 do buf[c][k] = 0 end
    end
    return {ch = ch, buf = buf, queue = {}, cost = ch * 62 + 4}
  end,
  hit = function(s, i, vel, pn)
    local c = ((i - 1) % s.ch) + 1
    s.queue[c] = vel
  end,
  upd = function(s)
    for c = 1, s.ch do
      local v = (math.random() - 0.5) * 0.8
      if s.queue[c] then
        v = v + s.queue[c] * 14
        s.queue[c] = nil
      elseif s.buf[c][60] > 6 then
        v = -s.buf[c][60] * 0.9
      end
      table.remove(s.buf[c], 1)
      s.buf[c][60] = v
    end
  end,
  draw = function(s)
    for c = 1, s.ch do
      local y0 = (c - (s.ch + 1) / 2) * 18
      lvl(15 - (c - 1) * 3)
      for k = 1, 60 do
        local x, y = -60 + (k - 1) * 2, y0 - s.buf[c][k]
        if k == 1 then mv(x, y) else ln(x, y) end
      end
      screen.stroke()
    end
  end,
})

add("blocks", {
  new = function(rg)
    return {sp = 0.8 + rg.f() * 3, th = 0.45 + rg.f() * 0.25, bs = rg.pick({6, 8, 8, 10}), seed = rg.f() * 100,
            cost = 150}
  end,
  draw = function(s)
    local cols, rows = floor(112 / s.bs), floor(56 / s.bs)
    local t = floor(vt * s.sp)
    local groups = {{}, {}, {}}
    for i = 0, cols - 1 do
      for j = 0, rows - 1 do
        local h = sin(i * 12.9898 + j * 78.233 + t * 37.719 + s.seed) * 43758.5453
        h = h - floor(h)
        if h > s.th then
          local b = clamp(math.ceil((h - s.th) / (1 - s.th) * 3), 1, 3)
          groups[b][#groups[b] + 1] = {i, j}
        end
      end
    end
    for pass = 1, 3 do
      lvl(2 + pass * 4 + energy * 2)
      for _, c in ipairs(groups[pass]) do
        local a, b = pt(-56 + c[1] * s.bs, -28 + c[2] * s.bs)
        screen.rect(a, b, s.bs - 1, s.bs - 1)
      end
      screen.fill()
    end
  end,
})

add("snake", {
  new = function(rg)
    local n = rg.i(14, 26)
    return {n = n, a = rg.i(1, 4), b = rg.i(2, 5), ax = 30 + rg.f() * 22, ay = 12 + rg.f() * 14,
            sp = 0.3 + rg.f() * 0.7, cost = n * 3}
  end,
  draw = function(s)
    for k = s.n, 1, -1 do
      local t = vt * s.sp - k * 0.09
      local x, y = s.ax * sin(s.a * t), s.ay * sin(s.b * t + 1)
      local f = 1 - k / (s.n + 1)
      lvl(2 + f * 13)
      circ(x, y, 0.8 + f * 2.8 * (1 + 0.2 * energy))
      screen.fill()
    end
  end,
})

add("pendulums", {
  new = function(rg)
    local n = rg.i(10, 18)
    return {n = n, A = 36 + rg.f() * 20, f0 = 0.5 + rg.f() * 0.6, df = 0.03 + rg.f() * 0.05, cost = n * 3 + n + 4}
  end,
  draw = function(s)
    lvl(5)
    for k = 1, s.n do
      local x = s.A * sin(vt * (s.f0 + k * s.df))
      local y = (k - (s.n + 1) / 2) * (54 / s.n)
      if k == 1 then mv(x, y) else ln(x, y) end
    end
    screen.stroke()
    for k = 1, s.n do
      local x = s.A * sin(vt * (s.f0 + k * s.df))
      local y = (k - (s.n + 1) / 2) * (54 / s.n)
      lvl(8 + (k % 3) * 3 + P(k) * 4)
      circ(x, y, 1.6)
      screen.fill()
    end
  end,
})

add("moon", {
  new = function(rg)
    local st = {}
    for k = 1, rg.i(10, 24) do st[k] = {(rg.f() - 0.5) * 120, (rg.f() - 0.5) * 60, rg.f() * TAU} end
    return {R = 14 + rg.f() * 10, sp = 0.01 + rg.f() * 0.04, ph0 = rg.f(), st = st, cost = 40 + #st}
  end,
  draw = function(s)
    local ph = (s.ph0 + vt * s.sp) % 1
    local k = cos(ph * TAU)
    lvl(4)
    circ(0, 0, s.R); screen.stroke()
    lvl(13)
    local mirror = (ph > 0.5) and -1 or 1
    for j = 0, 16 do
      local t = -pi / 2 + j / 16 * pi
      local x, y = mirror * cos(t) * s.R, sin(t) * s.R
      if j == 0 then mv(x, y) else ln(x, y) end
    end
    for j = 16, 0, -1 do
      local t = -pi / 2 + j / 16 * pi
      ln(mirror * k * cos(t) * s.R, sin(t) * s.R)
    end
    screen.fill()
    for i, o in ipairs(s.st) do
      lvl(3 + 6 * (0.5 + 0.5 * sin(vt * 1.2 + o[3])))
      local a, b = pt(o[1], o[2])
      screen.rect(a, b, 1, 1)
    end
    screen.fill()
  end,
})

add("phyllotaxis", {
  new = function(rg)
    local n = rg.i(100, 220)
    return {n = n, c = 2.2 + rg.f() * 1.4, ang = 2.39996 + (rg.f() - 0.5) * 0.02, sp = 0.05 + rg.f() * 0.2,
            cost = n + 8}
  end,
  draw = function(s)
    local ang = s.ang + 0.0005 * sin(vt * 0.1)
    local grow = clamp(0.5 + 0.5 * sin(vt * s.sp), 0.2, 1)
    local n = floor(s.n * grow)
    for pass = 1, 2 do
      lvl(pass == 1 and 7 or 14)
      for k = 1, n do
        if (k % 2 == 0) == (pass == 2) then
          local a, r = k * ang + vt * 0.1, s.c * sqrt(k) * (1 + 0.04 * energy)
          local x, y = pt(cos(a) * r, sin(a) * r * 0.75)
          screen.rect(x, y, 1, 1)
        end
      end
      screen.fill()
    end
  end,
})

add("forest", {
  new = function(rg)
    local n = rg.i(6, 12)
    local t = {}
    for k = 1, n do
      t[k] = {x = -58 + (k - 1) * (116 / (n - 1)) + (rg.f() - 0.5) * 6, h = 14 + rg.f() * 18, w = 5 + rg.f() * 5,
              ph = rg.f() * TAU, tiers = rg.i(2, 3)}
    end
    return {t = t, moon = rg.f() < 0.7, mx = (rg.f() - 0.5) * 70, cost = n * 14 + 8}
  end,
  draw = function(s)
    if s.moon then
      lvl(13); circ(s.mx, -20, 4); screen.fill()
    end
    for k, o in ipairs(s.t) do
      local sway = sin(vt * 0.5 + o.ph) * 1.2
      lvl(3 + (k % 3) * 2 + P(k) * 3)
      local base = 30
      for q = 1, o.tiers do
        local f = q / o.tiers
        local top = base - o.h * f
        local w = o.w * (1.1 - f * 0.4)
        mv(o.x + sway * (1 - f), top - o.h / o.tiers * 0.7)
        ln(o.x + w, base - o.h * (q - 1) / o.tiers)
        ln(o.x - w, base - o.h * (q - 1) / o.tiers)
        screen.fill()
      end
      mv(o.x, base); ln(o.x, 34); screen.stroke()
    end
    lvl(6); mv(-62, 34); ln(62, 34); screen.stroke()
  end,
})

-- ------------------------------------------------------------ added in 1.1

add("aurora", {
  new = function(rg)
    local n = rg.i(3, 5)
    local t = {}
    for k = 1, n do
      t[k] = {y = -14 + k * 6 + (rg.f() - 0.5) * 4, a = 3 + rg.f() * 5, f = 0.04 + rg.f() * 0.08,
              sp = 0.3 + rg.f() * 0.8, h = 8 + rg.f() * 10}
    end
    return {t = t, cost = n * 34 * 2}
  end,
  draw = function(s)
    for k, o in ipairs(s.t) do
      lvl(3 + k * 1.3 + P(k) * 4)
      for x = -60, 60, 4 do
        local y = o.y + o.a * sin(x * o.f + vt * o.sp + k) + o.a * 0.5 * sin(x * o.f * 2.3 - vt * o.sp)
        local h = o.h * (0.6 + 0.4 * sin(x * 0.07 + vt * 0.6 + k))
        mv(x, y); ln(x, y - h)
      end
      screen.stroke()
    end
  end,
})

add("galaxy", {
  new = function(rg)
    local arms = rg.i(2, 5)
    return {arms = arms, n = rg.i(14, 24), tw = 0.25 + rg.f() * 0.5, sp = 0.05 + rg.f() * 0.12,
            cost = arms * 24 + 10}
  end,
  draw = function(s)
    for a = 0, s.arms - 1 do
      lvl(5 + P(a + 1) * 5)
      for k = 1, s.n do
        local r = k * 2.6
        local ang = a * TAU / s.arms + r * s.tw * 0.2 + vt * s.sp * (1 / (1 + r * 0.03))
        local x, y = cos(ang) * r, sin(ang) * r * 0.55
        circ(x, y, 0.6 + (k % 3) * 0.3)
      end
      screen.fill()
    end
    lvl(14); circ(0, 0, 2 + P(1) * 2); screen.fill()
  end,
})

add("kelp", {
  new = function(rg)
    local n = rg.i(5, 10)
    local t = {}
    for k = 1, n do
      t[k] = {x = -56 + (k - 1) * (112 / (n - 1)), h = 22 + rg.f() * 22, ph = rg.f() * TAU, sw = 3 + rg.f() * 4}
    end
    return {t = t, cost = n * 10}
  end,
  draw = function(s)
    for k, o in ipairs(s.t) do
      lvl(3 + (k % 3) * 2 + P(k) * 4)
      mv(o.x, 34)
      for q = 1, 8 do
        local f = q / 8
        ln(o.x + sin(vt * 0.9 + o.ph + f * 3.2) * o.sw * f, 34 - o.h * f)
      end
      screen.stroke()
    end
  end,
})

add("mandala", {
  new = function(rg)
    local n, rings = rg.i(6, 16), rg.i(2, 4)
    return {n = n, r = 10 + rg.f() * 8, rot = (rg.f() - 0.5) * 0.4, rings = rings, cost = n * rings * 2}
  end,
  draw = function(s)
    for q = 1, s.rings do
      local R = s.r * q * 0.9
      lvl(3 + q * 2 + P(q) * 4)
      for k = 0, s.n - 1 do
        local a = k * TAU / s.n + vt * s.rot * (q % 2 == 0 and 1 or -1)
        local x, y = cos(a) * R, sin(a) * R
        circ(x, y, R * 0.28 + P(k + 1) * 1.5)
        screen.stroke()
      end
    end
  end,
})

add("scales", {
  new = function(rg)
    local r = 6 + rg.f() * 3
    return {r = r, sp = 0.2 + rg.f() * 0.5, cost = (74 / (r * 0.8)) * (2 * (132 / (r * 2)) + 2)}
  end,
  draw = function(s)
    local r = s.r
    local row = 0
    for y = -36, 38, r * 0.8 do
      row = row + 1
      local off = (row % 2) * r
      lvl(2 + (sin(vt * s.sp + y * 0.12) + 1) * 3 + P(row) * 5)
      mv(-70 + off, y)
      local up = false
      for x = -70 + off, 70, r do
        up = not up
        ln(x + r, y + (up and r * 0.8 or 0))
      end
      screen.stroke()
    end
  end,
})

add("vines", {
  new = function(rg)
    local n = rg.i(3, 6)
    local t = {}
    for k = 1, n do
      t[k] = {x = -50 + (k - 1) * (100 / (n - 1)), len = 0, max = 30 + rg.f() * 30, ph = rg.f() * TAU, dir = rg.f() < 0.5 and 1 or -1}
    end
    return {t = t, cost = n * 24}
  end,
  hit = function(s, i, vel)
    local o = s.t[(i - 1) % #s.t + 1]
    o.len = o.len + 4 + vel * 8
  end,
  upd = function(s)
    for _, o in ipairs(s.t) do
      o.len = o.len + 0.35
      if o.len > o.max then o.len = 2 end
    end
  end,
  draw = function(s)
    for k, o in ipairs(s.t) do
      lvl(4 + (k % 3) * 2 + P(k) * 5)
      mv(o.x, 34)
      local steps = floor(o.len / 2.5)
      for q = 1, steps do
        local y = 34 - q * 2.5
        ln(o.x + sin(q * 0.5 + o.ph + vt * 0.4) * 5 * o.dir, y)
      end
      screen.stroke()
      if steps > 2 then
        local y = 34 - steps * 2.5
        circ(o.x + sin(steps * 0.5 + o.ph + vt * 0.4) * 5 * o.dir, y, 1.5)
        screen.fill()
      end
    end
  end,
})

add("eclipse", {
  new = function(rg)
    return {r = 12 + rg.f() * 10, sp = 0.08 + rg.f() * 0.15, rays = rg.i(16, 28), cost = 30}
  end,
  draw = function(s)
    local ph = vt * s.sp
    local mx = sin(ph) * s.r * 1.6
    lvl(9 + P(1) * 5)
    for k = 0, s.rays - 1 do
      local a = k * TAU / s.rays + vt * 0.05
      local r1 = s.r + 2
      local r2 = s.r + 4 + ((k * 7) % 5) * 2 + P(k + 1) * 4
      mv(cos(a) * r1, sin(a) * r1); ln(cos(a) * r2, sin(a) * r2)
    end
    screen.stroke()
    lvl(6); circ(0, 0, s.r); screen.stroke()
    lvl(0); circ(mx, 0, s.r * 0.97); screen.fill()
    lvl(3); circ(mx, 0, s.r * 0.97); screen.stroke()
  end,
})

add("stalactites", {
  new = function(rg)
    local n = rg.i(8, 14)
    local t = {}
    for k = 1, n do
      t[k] = {x = -60 + (k - 1) * (120 / (n - 1)) + (rg.f() - 0.5) * 5, h = 5 + rg.f() * 16, w = 2 + rg.f() * 3,
              dr = rg.f() * 10, sp = 3 + rg.f() * 5}
    end
    return {t = t, cost = n * 8}
  end,
  draw = function(s)
    for k, o in ipairs(s.t) do
      lvl(3 + (k % 3) * 2 + P(k) * 3)
      mv(o.x - o.w, -34); ln(o.x, -34 + o.h); ln(o.x + o.w, -34)
      screen.fill()
      local y = -34 + o.h + ((vt * o.sp + o.dr) % 22)
      if y < 32 then
        lvl(8 + P(k) * 5); circ(o.x, y, 0.9); screen.fill()
      end
    end
  end,
})

add("atoms", {
  new = function(rg)
    local n = rg.i(2, 4)
    local t = {}
    for k = 1, n do
      t[k] = {x = (rg.f() - 0.5) * 80, y = (rg.f() - 0.5) * 36, r = 7 + rg.f() * 9, tilt = rg.f() * pi,
              sp = (0.6 + rg.f() * 1.5) * (rg.f() < 0.5 and 1 or -1), e = rg.i(1, 3)}
    end
    return {t = t, cost = n * 14}
  end,
  draw = function(s)
    for k, o in ipairs(s.t) do
      lvl(14); circ(o.x, o.y, 1.5 + P(k) * 1.5); screen.fill()
      for e = 1, o.e do
        local tl = o.tilt + (e - 1) * pi / o.e
        lvl(2 + e)
        for q = 0, 10 do
          local a = q * TAU / 10
          local ex, ey = cos(a) * o.r, sin(a) * o.r * 0.38
          local x, y = o.x + ex * cos(tl) - ey * sin(tl), o.y + ex * sin(tl) + ey * cos(tl)
          if q == 0 then mv(x, y) else ln(x, y) end
        end
        screen.stroke()
        local a = vt * o.sp + e * 2
        local ex, ey = cos(a) * o.r, sin(a) * o.r * 0.38
        lvl(12)
        circ(o.x + ex * cos(tl) - ey * sin(tl), o.y + ex * sin(tl) + ey * cos(tl), 1)
        screen.fill()
      end
    end
  end,
})

add("ripples", {
  new = function(rg)
    local n = rg.i(2, 4)
    local t = {}
    for k = 1, n do t[k] = {x = (rg.f() - 0.5) * 90, y = (rg.f() - 0.5) * 44, ph = rg.f() * 6, sp = 0.6 + rg.f() * 1.2} end
    return {t = t, cost = n * 6 * 6}
  end,
  draw = function(s)
    for k, o in ipairs(s.t) do
      for q = 0, 5 do
        local r = ((vt * o.sp * 6 + o.ph * 4 + q * 7) % 42)
        lvl((15 - r * 0.33) * (0.6 + P(k) * 0.6))
        circ(o.x, o.y, r)
        screen.stroke()
      end
    end
  end,
})

-- ------------------------------------------------------------------- scene

V.layer_names = ORDER

function V.init(c)
  ctx = c
  vt, energy = 0, 0
end

-- builds a new scene from the world's random generator
function V.build(rg)
  local names
  if TEST and TEST.layers then
    names = TEST.layers
  else
    local nl = rg.pick({1, 1, 2, 2, 2, 3, 3})
    local pool = {}
    for k, v in ipairs(ORDER) do pool[k] = v end
    names = {}
    for k = 1, nl do names[k] = table.remove(pool, rg.i(1, #pool)) end
  end

  local sc = {layers = {}, sig = ""}
  local total = 0
  -- light overlay on top of the scene (lines, frame, dot lattice, corners)
  sc.ov = rg.pick({0, 0, 0, 0, 1, 2, 3, 4})
  local budget = BUDGET - ({0, 20, 6, 135, 10})[sc.ov + 1]
  for k, nm in ipairs(names) do
    local def = LAYER[nm]
    local s = def.new(rg)
    s.def = def
    if rg.f() < 0.55 then
      s.ox, s.oy = (rg.f() * 2 - 1) * 36, (rg.f() * 2 - 1) * 18
    else
      s.ox, s.oy = 0, 0
    end
    s.cost = s.cost * (FACT[nm] or 3)
    total = total + s.cost
    sc.layers[k] = s
    sc.sig = sc.sig .. nm .. floor(s.cost) .. floor(s.ox) .. ";"
  end
  -- if the scene exceeds the budget the last layers are dropped (already generated: chance is unchanged)
  while total > budget and #sc.layers > 1 do
    total = total - sc.layers[#sc.layers].cost
    table.remove(sc.layers)
  end

  local nsym = rg.pick({1, 1, 1, 2, 3, 3, 4, 5, 6, 7, 8})
  local mirror = rg.f() < 0.3
  if TEST and TEST.nsym then nsym = TEST.nsym end
  if TEST and TEST.mirror ~= nil then mirror = TEST.mirror end
  while nsym * (mirror and 2 or 1) * total > budget and (nsym > 1 or mirror) do
    if nsym > 1 then nsym = nsym - 1 else mirror = false end
  end
  sc.nsym, sc.mirror, sc.total = nsym, mirror, total
  if TEST then TEST.last = {nsym = nsym, mirror = mirror, total = total, n = #sc.layers} end

  sc.rot = (rg.f() < 0.35) and 0 or (rg.f() * 2 - 1) * 0.5
  sc.rot0 = rg.f() * TAU
  sc.zamp = (rg.f() < 0.5) and rg.f() * 0.12 or 0
  sc.zspd = 0.2 + rg.f() * 0.9
  sc.zoom = 0.7 + rg.f() * 0.55
  sc.panx = (rg.f() < 0.5) and rg.f() * 14 or 0
  sc.pany = (rg.f() < 0.5) and rg.f() * 7 or 0
  sc.pfx, sc.pfy = 0.05 + rg.f() * 0.2, 0.05 + rg.f() * 0.2
  sc.gain = 0.6 + rg.f() * 0.4
  sc.off = rg.pick({0, 0, 0, 1, 2})
  sc.lw = rg.pick({1, 1, 1, 1.5, 2})
  sc.aa = rg.pick({0, 1})
  sc.bg = rg.pick({0, 0, 0, 0, 1, 2, 3})
  sc.sig = sc.sig .. nsym .. (mirror and "m" or "-") .. floor(sc.rot * 1000) .. floor(sc.rot0 * 100)
           .. floor(sc.gain * 100) .. floor(sc.zoom * 100) .. sc.lw .. sc.aa .. sc.bg .. "o" .. sc.ov

  SCN = sc
  vt = 0
  energy = 0
  return sc.sig
end

function V.hit(i, vel, pn)
  if not SCN then return end
  for _, s in ipairs(SCN.layers) do
    if s.def.hit then s.def.hit(s, i, vel, pn) end
  end
end

function V.update()
  if not SCN then return end
  vt = vt + (1 / 30) * (0.5 + ctx.S.bpm / 240)
  local e = 0
  for i = 1, 4 do e = e + ctx.pulse[i] end
  energy = energy * 0.85 + e * 0.15
  for _, s in ipairs(SCN.layers) do
    if s.def.upd then s.def.upd(s) end
  end
end

function V.draw()
  if not SCN then return end
  if SCN.bg > 0 then
    screen.level(SCN.bg)
    screen.rect(0, 0, 128, 64)
    screen.fill()
  end
  screen.aa(SCN.aa)
  screen.line_width(SCN.lw)
  local zoom = SCN.zoom * (1 + SCN.zamp * sin(vt * SCN.zspd) + 0.04 * energy)
  local ang0 = SCN.rot0 + vt * SCN.rot
  TX.sc = zoom
  TX.ox = 64 + SCN.panx * sin(vt * SCN.pfx)
  TX.oy = 32 + SCN.pany * sin(vt * SCN.pfy + 1)
  for k = 0, SCN.nsym - 1 do
    for m = 0, (SCN.mirror and 1 or 0) do
      local a = ang0 + k * TAU / SCN.nsym
      TX.c, TX.s = cos(a), sin(a)
      TX.fx = (m == 0) and 1 or -1
      for _, s in ipairs(SCN.layers) do
        LO.x, LO.y = s.ox, s.oy
        s.def.draw(s)
      end
    end
  end
  local ov = SCN.ov
  if ov and ov > 0 then
    screen.aa(0)
    screen.line_width(1)
    local l = clamp(floor(2 + energy * 3 + 0.5), 1, 6)
    screen.level(l)
    if ov == 1 then
      local o = floor(vt * 3) % 4
      for y = o, 63, 4 do screen.rect(0, y, 128, 1) end
      screen.fill()
    elseif ov == 2 then
      screen.rect(0.5, 0.5, 127, 63)
      screen.stroke()
    elseif ov == 3 then
      for y = 4, 60, 8 do
        for x = 4, 124, 8 do screen.rect(x, y, 1, 1) end
      end
      screen.fill()
    else
      screen.level(l + 3)
      for _, c in ipairs({{0, 0, 1, 1}, {128, 0, -1, 1}, {0, 64, 1, -1}, {128, 64, -1, -1}}) do
        screen.move(c[1] + c[3] * 8, c[2]); screen.line(c[1], c[2]); screen.line(c[1], c[2] + c[4] * 8)
      end
      screen.stroke()
    end
  end
end

function V.signature() return SCN and SCN.sig or "" end
function V.layers() return SCN and SCN.layers or {} end

return V
