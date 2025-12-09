# Text Effects Lua Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Port 18 C++ text effects to Lua with improved API, add 20 new juicy/magical effects with color integration.

**Architecture:** Modular effect registry with smart defaults. Effects modify character properties (ox, oy, rotation, scale, color, alpha). Rendering uses `queueTextPro` for rotation + matrix transforms for scale.

**Tech Stack:** Lua, existing `util/easing.lua`, layer command buffer system.

---

## Task 1: Create Effect Registry Module

**Files:**
- Create: `assets/scripts/ui/text_effects/init.lua`

**Step 1: Write the effect registry**

```lua
-- assets/scripts/ui/text_effects/init.lua
-- Text effect registry with color utilities and smart defaults

local Easing = require("util.easing")

local effects = {}
local registered = {}

-- ============================================================================
-- Color Utilities
-- ============================================================================

effects.colors = {
  white = Col(255, 255, 255, 255),
  black = Col(0, 0, 0, 255),
  red = Col(255, 80, 80, 255),
  orange = Col(255, 160, 60, 255),
  yellow = Col(255, 230, 80, 255),
  gold = Col(255, 200, 80, 255),
  green = Col(80, 220, 100, 255),
  cyan = Col(80, 220, 255, 255),
  blue = Col(80, 120, 255, 255),
  purple = Col(180, 80, 255, 255),
  pink = Col(255, 130, 180, 255),
  silver = Col(200, 210, 220, 255),
  lightblue = Col(180, 220, 255, 255),
  -- Element colors
  fire = Col(255, 120, 40, 255),
  ice = Col(150, 220, 255, 255),
  poison = Col(120, 200, 80, 255),
  holy = Col(255, 240, 180, 255),
  void = Col(80, 40, 120, 255),
  electric = Col(180, 240, 255, 255),
}

function effects.hsv_to_rgb(h, s, v)
  h = h % 360
  local c = v * s
  local x = c * (1 - math.abs((h / 60) % 2 - 1))
  local m = v - c
  local r, g, b
  if h < 60 then r, g, b = c, x, 0
  elseif h < 120 then r, g, b = x, c, 0
  elseif h < 180 then r, g, b = 0, c, x
  elseif h < 240 then r, g, b = 0, x, c
  elseif h < 300 then r, g, b = x, 0, c
  else r, g, b = c, 0, x end
  return math.floor((r + m) * 255), math.floor((g + m) * 255), math.floor((b + m) * 255)
end

function effects.rgb_to_hsv(r, g, b)
  r, g, b = r / 255, g / 255, b / 255
  local max, min = math.max(r, g, b), math.min(r, g, b)
  local h, s, v = 0, 0, max
  local d = max - min
  s = max == 0 and 0 or d / max
  if max ~= min then
    if max == r then h = (g - b) / d + (g < b and 6 or 0)
    elseif max == g then h = (b - r) / d + 2
    else h = (r - g) / d + 4 end
    h = h * 60
  end
  return h, s, v
end

function effects.shift_hue(color, degrees)
  local h, s, v = effects.rgb_to_hsv(color.r, color.g, color.b)
  local r, g, b = effects.hsv_to_rgb(h + degrees, s, v)
  return Col(r, g, b, color.a)
end

function effects.lerp_color(c1, c2, t)
  t = math.max(0, math.min(1, t))
  return Col(
    math.floor(c1.r + (c2.r - c1.r) * t),
    math.floor(c1.g + (c2.g - c1.g) * t),
    math.floor(c1.b + (c2.b - c1.b) * t),
    math.floor(c1.a + (c2.a - c1.a) * t)
  )
end

function effects.get_color(name_or_color)
  if type(name_or_color) == "string" then
    return effects.colors[name_or_color] or effects.colors.white
  end
  return name_or_color or effects.colors.white
end

function effects.with_alpha(color, alpha)
  return Col(color.r, color.g, color.b, math.floor(alpha))
end

-- ============================================================================
-- Registry Functions
-- ============================================================================

function effects.register(name, fn, defaults)
  registered[name] = {
    fn = fn,
    defaults = defaults or {},
  }
end

function effects.get(name)
  return registered[name]
end

function effects.apply(name, ctx, dt, char, args)
  local eff = registered[name]
  if not eff then return end

  -- Merge defaults with provided args
  local merged = {}
  for i, default in ipairs(eff.defaults) do
    merged[i] = (args and args[i]) or default
  end

  eff.fn(ctx, dt, char, unpack(merged))
end

function effects.list()
  local names = {}
  for name in pairs(registered) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

-- Expose easing for effects to use
effects.easing = Easing

return effects
```

**Step 2: Verify file created**

Run: `ls -la assets/scripts/ui/text_effects/`
Expected: `init.lua` exists

**Step 3: Commit**

```bash
git add assets/scripts/ui/text_effects/init.lua
git commit -m "feat(text): add effect registry with color utilities"
```

---

## Task 2: Create Static Effects Module

**Files:**
- Create: `assets/scripts/ui/text_effects/static.lua`

**Step 1: Write static effects (color, fan)**

```lua
-- assets/scripts/ui/text_effects/static.lua
-- Non-animated text effects

local effects = require("ui.text_effects")

-- color: Set character color
-- Params: color (name or Col)
effects.register("color", function(ctx, dt, char, color)
  char.color = effects.get_color(color)
end, { "white" })

-- fan: Spread rotation from center
-- Params: max_angle (degrees)
effects.register("fan", function(ctx, dt, char, max_angle)
  if ctx.char_count <= 1 then
    char.rotation = 0
    return
  end

  local mid = (ctx.char_count - 1) * 0.5
  local offset_index = char.i - 1 - mid  -- 0-indexed
  local normalized = offset_index / mid  -- -1 to +1

  char.rotation = normalized * max_angle
end, { 10 })

return effects
```

**Step 2: Commit**

```bash
git add assets/scripts/ui/text_effects/static.lua
git commit -m "feat(text): add static effects (color, fan)"
```

---

## Task 3: Create Continuous Effects Module (Part 1)

**Files:**
- Create: `assets/scripts/ui/text_effects/continuous.lua`

**Step 1: Write continuous effects (shake, float, pulse, bump, wiggle)**

```lua
-- assets/scripts/ui/text_effects/continuous.lua
-- Looping text effects that run continuously

local effects = require("ui.text_effects")

-- shake: Random jitter
-- Params: intensity, speed
effects.register("shake", function(ctx, dt, char, intensity, speed)
  local t = ctx.time * speed + char.i * 5
  char.ox = (char.ox or 0) + math.sin(t) * intensity * (math.random() * 0.5 + 0.5)
  char.oy = (char.oy or 0) + math.cos(t * 1.3) * intensity * (math.random() * 0.5 + 0.5)
end, { 2, 10 })

-- float: Vertical sine bob
-- Params: amplitude, speed, stagger
effects.register("float", function(ctx, dt, char, amplitude, speed, stagger)
  local t = ctx.time * speed + char.i * stagger
  char.oy = (char.oy or 0) + math.sin(t) * amplitude
end, { 5, 2.5, 0.4 })

-- pulse: Scale oscillation
-- Params: min_scale, max_scale, speed, stagger
effects.register("pulse", function(ctx, dt, char, min_scale, max_scale, speed, stagger)
  local t = ctx.time * speed + char.i * stagger
  local wave = (math.sin(t) + 1) * 0.5  -- 0 to 1
  char.scale = min_scale + (max_scale - min_scale) * wave
end, { 0.8, 1.2, 2, 0 })

-- bump: Snap-jump vertical displacement
-- Params: amplitude, speed, threshold, stagger
effects.register("bump", function(ctx, dt, char, amplitude, speed, threshold, stagger)
  local t = -ctx.time * speed + char.i * stagger
  local wave = (math.sin(t) + 1) * 0.5  -- 0 to 1
  local bump = wave > threshold and amplitude or 0
  char.oy = (char.oy or 0) - bump
end, { 3, 6, 0.8, 1.2 })

-- wiggle: Fast rotation oscillation
-- Params: angle, speed, stagger
effects.register("wiggle", function(ctx, dt, char, angle, speed, stagger)
  local t = ctx.time * speed + char.i * stagger
  char.rotation = math.sin(t) * angle
end, { 10, 10, 1 })

-- rotate: Gentle rotation wave
-- Params: speed, angle
effects.register("rotate", function(ctx, dt, char, speed, angle)
  local t = ctx.time * speed + char.i * 10
  char.rotation = math.sin(t) * angle
end, { 2, 25 })

-- spin: Continuous 360 rotation
-- Params: speed (rotations per second), stagger
effects.register("spin", function(ctx, dt, char, speed, stagger)
  char.effect_data.spin = char.effect_data.spin or {}
  local data = char.effect_data.spin

  if not data.start_time then
    data.start_time = ctx.time
  end

  local start_time = data.start_time + char.i * stagger
  if ctx.time >= start_time then
    local elapsed = ctx.time - start_time
    char.rotation = (elapsed * speed * 360) % 360
  end
end, { 1, 0.5 })

-- fade: Alpha oscillation
-- Params: min_alpha (0-1), max_alpha (0-1), speed, stagger
effects.register("fade", function(ctx, dt, char, min_alpha, max_alpha, speed, stagger)
  local t = ctx.time * speed - char.i * stagger
  local wave = (math.sin(t) + 1) * 0.5
  char.alpha = math.floor((min_alpha + (max_alpha - min_alpha) * wave) * 255)
end, { 0.4, 1, 3, 0.5 })

-- rainbow: HSV color cycling
-- Params: speed (degrees/sec), stagger, step (0 = smooth)
effects.register("rainbow", function(ctx, dt, char, speed, stagger, step)
  local hue = (ctx.time * speed - char.i * stagger) % 360
  if step > 0 then
    hue = math.floor(hue / step) * step
  end
  local r, g, b = effects.hsv_to_rgb(hue, 1, 1)
  char.color = Col(r, g, b, char.alpha or 255)
end, { 60, 10, 0 })

-- highlight: Color sweep wave
-- Params: speed, color, stagger
effects.register("highlight", function(ctx, dt, char, speed, color, stagger)
  local t = ctx.time * speed - char.i * stagger
  local wave = (math.sin(t) + 1) * 0.5
  local threshold = 0.7
  local factor = wave > (1 - threshold) and 1 or 0

  local base = char.color or effects.colors.white
  local target = effects.get_color(color)
  char.color = effects.lerp_color(base, target, factor * 0.7)
end, { 4, "white", 0.5 })

-- expand: Axis-specific scale pulse
-- Params: min_scale, max_scale, speed, axis ("x", "y", "both")
effects.register("expand", function(ctx, dt, char, min_scale, max_scale, speed, axis)
  local t = ctx.time * speed + char.i * 0.3
  local wave = (math.sin(t) + 1) * 0.5
  local scale_val = min_scale + (max_scale - min_scale) * wave

  if axis == "x" then
    char.scaleX = scale_val
  elseif axis == "y" then
    char.scaleY = scale_val
  else
    char.scaleX = scale_val
    char.scaleY = scale_val
  end
end, { 0.8, 1.2, 2, "y" })

return effects
```

**Step 2: Commit**

```bash
git add assets/scripts/ui/text_effects/continuous.lua
git commit -m "feat(text): add continuous effects (shake, float, pulse, bump, wiggle, rotate, spin, fade, rainbow, highlight, expand)"
```

---

## Task 4: Create One-Shot Effects Module

**Files:**
- Create: `assets/scripts/ui/text_effects/oneshot.lua`

**Step 1: Write one-shot effects (pop, slide, bounce, scramble)**

```lua
-- assets/scripts/ui/text_effects/oneshot.lua
-- Effects that play once and finish

local effects = require("ui.text_effects")
local Easing = effects.easing

-- pop: Scale in/out animation
-- Params: duration, stagger, mode ("in" or "out")
effects.register("pop", function(ctx, dt, char, duration, stagger, mode)
  -- Initialize created_at on first frame
  if not char.created_at then
    char.created_at = ctx.time
  end

  local time_alive = ctx.time - char.created_at
  local time_offset = char.i * stagger
  local local_time = math.max(0, time_alive - time_offset)
  local t = math.min(1, local_time / duration)

  local scale
  if mode == "out" then
    scale = 1 - Easing.outExpo.f(t)
  else
    scale = Easing.outExpo.f(t)
  end

  char.scale = math.max(0, math.min(1, scale))

  if t >= 1 then
    char.effect_finished = char.effect_finished or {}
    char.effect_finished.pop = true
  end
end, { 0.3, 0.1, "in" })

-- slide: Slide from direction with fade
-- Params: duration, stagger, direction ("l", "r", "t", "b"), fade_mode ("in", "out", "")
effects.register("slide", function(ctx, dt, char, duration, stagger, direction, fade_mode)
  if not char.created_at then
    char.created_at = ctx.time
  end

  char.effect_data.slide = char.effect_data.slide or {}
  local data = char.effect_data.slide

  -- Set initial offset once
  if not data.initial_offset then
    local magnitude = 50
    if direction == "l" then
      data.initial_offset = { x = -magnitude, y = 0 }
    elseif direction == "r" then
      data.initial_offset = { x = magnitude, y = 0 }
    elseif direction == "t" then
      data.initial_offset = { x = 0, y = -magnitude }
    else  -- "b"
      data.initial_offset = { x = 0, y = magnitude }
    end
  end

  local time_alive = ctx.time - char.created_at
  local time_offset = char.i * stagger
  local local_time = math.max(0, time_alive - time_offset)
  local t = math.min(1, local_time / duration)

  local eased = Easing.outExpo.f(t)
  local remaining = 1 - eased

  char.ox = (char.ox or 0) + data.initial_offset.x * remaining
  char.oy = (char.oy or 0) + data.initial_offset.y * remaining

  -- Alpha
  if fade_mode == "in" then
    char.alpha = math.floor(255 * eased)
  elseif fade_mode == "out" then
    char.alpha = math.floor(255 * remaining)
  end

  if t >= 1 then
    char.effect_finished = char.effect_finished or {}
    char.effect_finished.slide = true
  end
end, { 0.3, 0.1, "l", "in" })

-- bounce: Drop with physics damping
-- Params: height, gravity, stagger
effects.register("bounce", function(ctx, dt, char, height, gravity, stagger)
  if not char.created_at then
    char.created_at = ctx.time
  end

  char.effect_data.bounce = char.effect_data.bounce or {}
  local data = char.effect_data.bounce

  if not data.initialized then
    data.y = -height
    data.vel = 0
    data.initialized = true
  end

  local start_time = char.created_at + stagger * char.i
  if ctx.time < start_time then
    char.oy = (char.oy or 0) + data.y
    return
  end

  -- Physics update
  data.vel = data.vel + gravity * dt
  data.y = data.y + data.vel * dt

  -- Ground collision
  if data.y > 0 then
    data.y = 0
    data.vel = -data.vel * 0.5  -- Damping
    if math.abs(data.vel) < 10 then
      data.vel = 0
    end
  end

  char.oy = (char.oy or 0) + data.y

  if data.vel == 0 and data.y == 0 then
    char.effect_finished = char.effect_finished or {}
    char.effect_finished.bounce = true
  end
end, { 20, 700, 0.1 })

-- scramble: Random character cycling
-- Params: duration, stagger, rate (changes per second)
effects.register("scramble", function(ctx, dt, char, duration, stagger, rate)
  if not char.created_at then
    char.created_at = ctx.time
  end

  char.effect_data.scramble = char.effect_data.scramble or {}
  local data = char.effect_data.scramble

  local elapsed = ctx.time - char.created_at - char.i * stagger

  if elapsed < duration and elapsed >= 0 then
    if not data.last_change or (ctx.time - data.last_change) >= (1 / rate) then
      data.last_change = ctx.time
      -- Random printable ASCII (33-126)
      char.codepoint = string.char(33 + math.random(93))
    end
  else
    char.codepoint = nil  -- Show original
  end

  if elapsed >= duration then
    char.effect_finished = char.effect_finished or {}
    char.effect_finished.scramble = true
  end
end, { 0.4, 0.1, 15 })

return effects
```

**Step 2: Commit**

```bash
git add assets/scripts/ui/text_effects/oneshot.lua
git commit -m "feat(text): add one-shot effects (pop, slide, bounce, scramble)"
```

---

## Task 5: Create Juicy Effects Module

**Files:**
- Create: `assets/scripts/ui/text_effects/juicy.lua`

**Step 1: Write juicy/playful effects**

```lua
-- assets/scripts/ui/text_effects/juicy.lua
-- Playful, bouncy, exaggerated effects

local effects = require("ui.text_effects")
local Easing = effects.easing

-- jelly: Squash/stretch with hue shift
-- Params: squash, speed, stagger
effects.register("jelly", function(ctx, dt, char, squash, speed, stagger)
  local t = ctx.time * speed + char.i * stagger
  local wave = math.sin(t)

  char.scaleX = 1 + wave * squash
  char.scaleY = 1 - wave * squash

  -- Warm on squash, cool on stretch
  local hue_shift = wave * 15
  if char.color then
    char.color = effects.shift_hue(char.color, hue_shift)
  end
end, { 0.3, 8, 0.2 })

-- hop: Quick up-down hops
-- Params: height, speed, stagger
effects.register("hop", function(ctx, dt, char, height, speed, stagger)
  local t = ctx.time * speed + char.i * stagger
  local raw = math.sin(t)
  -- Only hop upward (positive part of sine)
  local hop = raw > 0 and raw * raw * height or 0
  char.oy = (char.oy or 0) - hop
end, { 6, 5, 0.3 })

-- rubberband: Overshoot scale with flash
-- Params: intensity, speed, overshoot_color
effects.register("rubberband", function(ctx, dt, char, intensity, speed, overshoot_color)
  if not char.created_at then
    char.created_at = ctx.time
  end

  local elapsed = ctx.time - char.created_at
  local t = math.min(1, elapsed * speed)
  local scale = Easing.outElastic.f(t) * intensity

  char.scale = 0.5 + scale * 0.5

  -- Flash at peak
  if t < 0.3 then
    local flash = effects.get_color(overshoot_color)
    char.color = effects.lerp_color(char.color or effects.colors.white, flash, (0.3 - t) / 0.3)
  end
end, { 1.5, 6, "yellow" })

-- swing: Pendulum with light/dark shift
-- Params: angle, speed, stagger
effects.register("swing", function(ctx, dt, char, angle, speed, stagger)
  local t = ctx.time * speed + char.i * stagger
  local swing = math.sin(t)
  char.rotation = swing * angle

  -- Darken on back swing, lighten on forward
  local brightness = 1 + swing * 0.15
  if char.color then
    char.color = Col(
      math.min(255, math.floor(char.color.r * brightness)),
      math.min(255, math.floor(char.color.g * brightness)),
      math.min(255, math.floor(char.color.b * brightness)),
      char.color.a
    )
  end
end, { 20, 3, 0.2 })

-- tremble: Fast micro-shake with tint
-- Params: intensity, speed, tint
effects.register("tremble", function(ctx, dt, char, intensity, speed, tint)
  local t = ctx.time * speed + char.i
  char.ox = (char.ox or 0) + math.sin(t * 7) * intensity
  char.oy = (char.oy or 0) + math.cos(t * 11) * intensity * 0.5

  -- Apply fear/anger tint
  local tint_color = effects.get_color(tint)
  char.color = effects.lerp_color(char.color or effects.colors.white, tint_color, 0.3)
end, { 1, 30, "red" })

-- pop_rotate: Spin-in with flash on landing
-- Params: duration, stagger, spins, flash_color
effects.register("pop_rotate", function(ctx, dt, char, duration, stagger, spins, flash_color)
  if not char.created_at then
    char.created_at = ctx.time
  end

  local time_alive = ctx.time - char.created_at
  local time_offset = char.i * stagger
  local local_time = math.max(0, time_alive - time_offset)
  local t = math.min(1, local_time / duration)

  local eased = Easing.outBack.f(t)
  char.scale = eased
  char.rotation = (1 - eased) * 360 * spins

  -- Flash on landing
  if t > 0.8 and t < 1 then
    local flash = effects.get_color(flash_color)
    local flash_t = (t - 0.8) / 0.2
    char.color = effects.lerp_color(flash, char.color or effects.colors.white, flash_t)
  end

  if t >= 1 then
    char.effect_finished = char.effect_finished or {}
    char.effect_finished.pop_rotate = true
  end
end, { 0.4, 0.08, 1, "white" })

-- slam: Start huge, slam to normal
-- Params: duration, stagger, start_scale, impact_color
effects.register("slam", function(ctx, dt, char, duration, stagger, start_scale, impact_color)
  if not char.created_at then
    char.created_at = ctx.time
  end

  local time_alive = ctx.time - char.created_at
  local time_offset = char.i * stagger
  local local_time = math.max(0, time_alive - time_offset)
  local t = math.min(1, local_time / duration)

  local eased = Easing.outBounce.f(t)
  char.scale = start_scale - (start_scale - 1) * eased

  -- Impact color burst
  if t < 0.2 then
    local impact = effects.get_color(impact_color)
    char.color = effects.lerp_color(impact, char.color or effects.colors.white, t / 0.2)
  end

  if t >= 1 then
    char.effect_finished = char.effect_finished or {}
    char.effect_finished.slam = true
  end
end, { 0.25, 0.05, 2, "orange" })

-- wave: Traveling sine wave
-- Params: amplitude, speed, wavelength
effects.register("wave", function(ctx, dt, char, amplitude, speed, wavelength)
  local t = ctx.time * speed - char.i * wavelength
  char.oy = (char.oy or 0) + math.sin(t) * amplitude
end, { 8, 4, 0.5 })

-- heartbeat: Lub-dub rhythm
-- Params: scale, speed, color
effects.register("heartbeat", function(ctx, dt, char, peak_scale, speed, color)
  local t = (ctx.time * speed) % 1

  -- Two pulses: lub at 0.0, dub at 0.15, rest until 1.0
  local scale = 1
  if t < 0.08 then
    scale = 1 + (peak_scale - 1) * Easing.outQuad.f(t / 0.08)
  elseif t < 0.16 then
    scale = peak_scale - (peak_scale - 1) * Easing.inQuad.f((t - 0.08) / 0.08)
  elseif t < 0.22 then
    scale = 1 + (peak_scale - 1) * 0.7 * Easing.outQuad.f((t - 0.16) / 0.06)
  elseif t < 0.30 then
    scale = 1 + (peak_scale - 1) * 0.7 * (1 - Easing.inQuad.f((t - 0.22) / 0.08))
  end

  char.scale = scale

  -- Warm color throb
  if scale > 1.05 then
    local throb_color = effects.get_color(color)
    char.color = effects.lerp_color(char.color or effects.colors.white, throb_color, (scale - 1) / (peak_scale - 1) * 0.5)
  end
end, { 1.3, 2, "pink" })

-- squish: Horizontal squish
-- Params: amount, speed
effects.register("squish", function(ctx, dt, char, amount, speed)
  local t = ctx.time * speed + char.i * 0.3
  local squish = math.sin(t)
  char.scaleX = 1 - squish * amount
  char.scaleY = 1 + squish * amount * 0.5
end, { 0.2, 8 })

return effects
```

**Step 2: Commit**

```bash
git add assets/scripts/ui/text_effects/juicy.lua
git commit -m "feat(text): add juicy effects (jelly, hop, rubberband, swing, tremble, pop_rotate, slam, wave, heartbeat, squish)"
```

---

## Task 6: Create Magical Effects Module

**Files:**
- Create: `assets/scripts/ui/text_effects/magical.lua`

**Step 1: Write magical/fantasy effects**

```lua
-- assets/scripts/ui/text_effects/magical.lua
-- Ethereal, glowing, fantasy effects

local effects = require("ui.text_effects")
local Easing = effects.easing

-- glow_pulse: Alpha pulse with glow color
-- Params: min_alpha (0-1), max_alpha (0-1), speed, color
effects.register("glow_pulse", function(ctx, dt, char, min_alpha, max_alpha, speed, color)
  local t = ctx.time * speed + char.i * 0.3
  local wave = (math.sin(t) + 1) * 0.5
  local alpha = min_alpha + (max_alpha - min_alpha) * wave

  char.alpha = math.floor(alpha * 255)

  -- Tint toward glow color
  local glow = effects.get_color(color)
  char.color = effects.lerp_color(char.color or effects.colors.white, glow, wave * 0.4)
end, { 0.5, 1, 2, "gold" })

-- shimmer: Rapid flicker between colors
-- Params: speed, stagger, colors (comma-separated string)
effects.register("shimmer", function(ctx, dt, char, speed, stagger, colors_str)
  local t = ctx.time * speed + char.i * stagger
  local flicker = (math.sin(t * 7) + math.sin(t * 11)) * 0.25 + 0.5

  -- Parse colors
  local color_names = {}
  for name in string.gmatch(colors_str or "silver,white", "[^,]+") do
    table.insert(color_names, name:match("^%s*(.-)%s*$"))
  end

  local idx = math.floor(t % #color_names) + 1
  local shimmer_color = effects.get_color(color_names[idx])

  char.color = effects.lerp_color(char.color or effects.colors.white, shimmer_color, flicker * 0.6)
  char.alpha = math.floor((0.7 + flicker * 0.3) * 255)
end, { 12, 0.1, "silver,white" })

-- float_drift: 2D float with ethereal tint
-- Params: amp_x, amp_y, speed, tint
effects.register("float_drift", function(ctx, dt, char, amp_x, amp_y, speed, tint)
  local t = ctx.time * speed + char.i * 0.5
  char.ox = (char.ox or 0) + math.sin(t * 0.7) * amp_x
  char.oy = (char.oy or 0) + math.sin(t) * amp_y

  -- Ethereal tint
  local drift_color = effects.get_color(tint)
  local wave = (math.sin(t) + 1) * 0.25
  char.color = effects.lerp_color(char.color or effects.colors.white, drift_color, wave)
end, { 3, 5, 1.5, "cyan" })

-- sparkle: Random flash from color palette
-- Params: chance (0-1), colors (comma-separated)
effects.register("sparkle", function(ctx, dt, char, chance, colors_str)
  char.effect_data.sparkle = char.effect_data.sparkle or {}
  local data = char.effect_data.sparkle

  -- Random sparkle trigger
  if math.random() < chance then
    data.flash_until = ctx.time + 0.1
    local color_names = {}
    for name in string.gmatch(colors_str or "white,gold,cyan", "[^,]+") do
      table.insert(color_names, name:match("^%s*(.-)%s*$"))
    end
    data.flash_color = effects.get_color(color_names[math.random(#color_names)])
  end

  if data.flash_until and ctx.time < data.flash_until then
    char.color = data.flash_color
    char.scale = 1.2
  else
    char.scale = 1
  end
end, { 0.03, "white,gold,cyan" })

-- enchant: Float + shimmer + rotation + magic color
-- Params: speed, stagger, color
effects.register("enchant", function(ctx, dt, char, speed, stagger, color)
  local t = ctx.time * speed + char.i * stagger

  -- Float
  char.oy = (char.oy or 0) + math.sin(t) * 4
  char.ox = (char.ox or 0) + math.sin(t * 0.7) * 2

  -- Gentle rotation
  char.rotation = math.sin(t * 0.5) * 5

  -- Shimmer alpha
  char.alpha = math.floor((0.7 + math.sin(t * 8) * 0.15 + 0.15) * 255)

  -- Magic color
  local magic = effects.get_color(color)
  local wave = (math.sin(t * 2) + 1) * 0.25
  char.color = effects.lerp_color(char.color or effects.colors.white, magic, wave)
end, { 3, 0.3, "purple" })

-- rise: Drift upward and fade
-- Params: speed (pixels/sec), fade (bool), stagger, color
effects.register("rise", function(ctx, dt, char, speed, fade, stagger, color)
  if not char.created_at then
    char.created_at = ctx.time
  end

  local elapsed = ctx.time - char.created_at - char.i * stagger
  if elapsed < 0 then return end

  char.oy = (char.oy or 0) - elapsed * speed

  if fade then
    char.alpha = math.max(0, math.floor(255 * (1 - elapsed * 0.5)))
  end

  -- Ascension color
  local rise_color = effects.get_color(color)
  char.color = effects.lerp_color(char.color or effects.colors.white, rise_color, math.min(1, elapsed * 0.5))
end, { 30, true, 0.1, "white" })

-- waver: Heat shimmer with warm tint
-- Params: amplitude, speed, stagger, heat_color
effects.register("waver", function(ctx, dt, char, amplitude, speed, stagger, heat_color)
  local t = ctx.time * speed + char.i * stagger
  local wave = math.sin(t)
  char.ox = (char.ox or 0) + wave * amplitude

  -- Heat tint at extremes
  local extreme = math.abs(wave)
  local heat = effects.get_color(heat_color)
  char.color = effects.lerp_color(char.color or effects.colors.white, heat, extreme * 0.4)
end, { 3, 2, 0.15, "orange" })

-- phase: Ghostly fade with spectral tint
-- Params: min_alpha (0-1), max_alpha (0-1), speed, ghost_color
effects.register("phase", function(ctx, dt, char, min_alpha, max_alpha, speed, ghost_color)
  local t = ctx.time * speed + char.i * 0.4
  local wave = (math.sin(t) + 1) * 0.5
  char.alpha = math.floor((min_alpha + (max_alpha - min_alpha) * wave) * 255)

  -- Ghostly tint
  local ghost = effects.get_color(ghost_color)
  char.color = effects.lerp_color(char.color or effects.colors.white, ghost, 0.4)
end, { 0.3, 1, 1.5, "lightblue" })

-- orbit: Each char orbits its base position
-- Params: radius, speed, stagger
effects.register("orbit", function(ctx, dt, char, radius, speed, stagger)
  local t = ctx.time * speed + char.i * stagger
  char.ox = (char.ox or 0) + math.cos(t) * radius
  char.oy = (char.oy or 0) + math.sin(t) * radius
end, { 3, 2, 0.5 })

-- cascade: Waterfall reveal
-- Params: delay (per char), duration, start_color
effects.register("cascade", function(ctx, dt, char, delay, duration, start_color)
  if not char.created_at then
    char.created_at = ctx.time
  end

  local time_alive = ctx.time - char.created_at
  local char_delay = char.i * delay
  local local_time = math.max(0, time_alive - char_delay)
  local t = math.min(1, local_time / duration)

  local eased = Easing.outQuad.f(t)

  -- Start above, fall into place
  char.oy = (char.oy or 0) - (1 - eased) * 20
  char.alpha = math.floor(eased * 255)

  -- Color transition
  local start = effects.get_color(start_color)
  char.color = effects.lerp_color(start, char.color or effects.colors.white, eased)

  if t >= 1 then
    char.effect_finished = char.effect_finished or {}
    char.effect_finished.cascade = true
  end
end, { 0.08, 0.3, "white" })

return effects
```

**Step 2: Commit**

```bash
git add assets/scripts/ui/text_effects/magical.lua
git commit -m "feat(text): add magical effects (glow_pulse, shimmer, float_drift, sparkle, enchant, rise, waver, phase, orbit, cascade)"
```

---

## Task 7: Create Elemental Effects Module

**Files:**
- Create: `assets/scripts/ui/text_effects/elemental.lua`

**Step 1: Write elemental effects**

```lua
-- assets/scripts/ui/text_effects/elemental.lua
-- Element-themed visual effects (fire, ice, poison, etc.)

local effects = require("ui.text_effects")
local Easing = effects.easing

-- burn: Orange to red to black, shrivel
-- Params: speed, stagger
effects.register("burn", function(ctx, dt, char, speed, stagger)
  if not char.created_at then
    char.created_at = ctx.time
  end

  local elapsed = ctx.time - char.created_at - char.i * stagger
  if elapsed < 0 then return end

  local t = math.min(1, elapsed * speed)

  -- Color: orange -> red -> black
  local orange = effects.colors.orange
  local red = effects.colors.red
  local black = effects.colors.black

  local color
  if t < 0.5 then
    color = effects.lerp_color(orange, red, t * 2)
  else
    color = effects.lerp_color(red, black, (t - 0.5) * 2)
  end
  char.color = color

  -- Shrivel
  char.scale = 1 - t * 0.4
  char.scaleY = 1 - t * 0.6

  -- Jitter
  char.ox = (char.ox or 0) + math.sin(elapsed * 20) * (1 - t) * 2
end, { 2, 0.15 })

-- freeze: Blue tint spreading, vibrate then stop
-- Params: duration, stagger
effects.register("freeze", function(ctx, dt, char, duration, stagger)
  if not char.created_at then
    char.created_at = ctx.time
  end

  local elapsed = ctx.time - char.created_at - char.i * stagger
  if elapsed < 0 then return end

  local t = math.min(1, elapsed / duration)

  -- Blue tint spreads
  local ice = effects.colors.ice
  char.color = effects.lerp_color(char.color or effects.colors.white, ice, t)

  -- Vibrate then stop
  local vibrate = math.max(0, 1 - t * 2)
  char.ox = (char.ox or 0) + math.sin(elapsed * 40) * vibrate * 2

  if t >= 1 then
    char.effect_finished = char.effect_finished or {}
    char.effect_finished.freeze = true
  end
end, { 0.5, 0.1 })

-- poison: Green/purple pulse with drip
-- Params: speed, intensity
effects.register("poison", function(ctx, dt, char, speed, intensity)
  local t = ctx.time * speed + char.i * 0.5
  local wave = (math.sin(t) + 1) * 0.5

  -- Alternate green and purple
  local green = effects.colors.poison
  local purple = effects.colors.purple
  local poison_color = effects.lerp_color(green, purple, (math.sin(t * 0.5) + 1) * 0.5)
  char.color = effects.lerp_color(char.color or effects.colors.white, poison_color, intensity)

  -- Drip effect
  char.oy = (char.oy or 0) + math.max(0, math.sin(t)) * 3
end, { 3, 0.5 })

-- electric: Fast jitter with cyan flashes
-- Params: speed, jitter, color
effects.register("electric", function(ctx, dt, char, speed, jitter, color)
  local t = ctx.time * speed + char.i

  -- Chaotic jitter
  char.ox = (char.ox or 0) + math.sin(t * 13) * jitter
  char.oy = (char.oy or 0) + math.cos(t * 17) * jitter * 0.5

  -- Random flashes
  local flash_color = effects.get_color(color)
  local flash = math.random() < 0.1
  if flash then
    char.color = flash_color
    char.scale = 1.1
  else
    char.color = effects.lerp_color(char.color or effects.colors.white, flash_color, 0.3)
    char.scale = 1
  end
end, { 20, 2, "cyan" })

-- holy: Gold glow + rise + scale pulse
-- Params: speed, stagger
effects.register("holy", function(ctx, dt, char, speed, stagger)
  local t = ctx.time * speed + char.i * stagger

  -- Gentle rise
  char.oy = (char.oy or 0) + math.sin(t * 0.5) * 3

  -- Scale pulse
  char.scale = 1 + math.sin(t) * 0.1

  -- Gold glow
  local gold = effects.colors.holy
  local wave = (math.sin(t * 2) + 1) * 0.5
  char.color = effects.lerp_color(char.color or effects.colors.white, gold, 0.4 + wave * 0.3)
  char.alpha = math.floor((0.8 + wave * 0.2) * 255)
end, { 2, 0.2 })

-- void: Purple/black desaturation + inward pull
-- Params: speed, stagger
effects.register("void", function(ctx, dt, char, speed, stagger)
  local t = ctx.time * speed + char.i * stagger

  -- Desaturate to void purple
  local void_color = effects.colors.void
  local wave = (math.sin(t) + 1) * 0.5
  char.color = effects.lerp_color(char.color or effects.colors.white, void_color, 0.5 + wave * 0.3)

  -- Subtle inward pull (scale down slightly)
  char.scale = 1 - wave * 0.15

  -- Alpha flicker
  char.alpha = math.floor((0.7 + math.sin(t * 3) * 0.15) * 255)
end, { 1.5, 0.3 })

-- fire: Orange/yellow/red cycle + upward jitter
-- Params: speed, flicker
effects.register("fire", function(ctx, dt, char, speed, flicker)
  local t = ctx.time * speed + char.i * 0.4

  -- Color cycling: orange -> yellow -> red
  local h = (t * 30) % 60  -- Hue between 0-60 (red-yellow range)
  local r, g, b = effects.hsv_to_rgb(h, 1, 1)
  char.color = Col(r, g, b, char.alpha or 255)

  -- Upward jitter
  char.oy = (char.oy or 0) - math.abs(math.sin(t * 5)) * flicker
  char.ox = (char.ox or 0) + math.sin(t * 7) * flicker * 0.3

  -- Scale flicker
  char.scale = 1 + math.sin(t * 8) * 0.1
end, { 8, 3 })

-- ice: Cyan/white shimmer + horizontal crackle
-- Params: speed
effects.register("ice", function(ctx, dt, char, speed)
  local t = ctx.time * speed + char.i * 0.3

  -- Shimmer between cyan and white
  local ice = effects.colors.ice
  local white = effects.colors.white
  local wave = (math.sin(t * 4) + 1) * 0.5
  char.color = effects.lerp_color(ice, white, wave * 0.6)

  -- Horizontal crackle (subtle)
  char.ox = (char.ox or 0) + math.sin(t * 15) * 0.5

  -- Alpha shimmer
  char.alpha = math.floor((0.85 + wave * 0.15) * 255)
end, { 1 })

return effects
```

**Step 2: Commit**

```bash
git add assets/scripts/ui/text_effects/elemental.lua
git commit -m "feat(text): add elemental effects (burn, freeze, poison, electric, holy, void, fire, ice)"
```

---

## Task 8: Update command_buffer_text.lua - Character Model

**Files:**
- Modify: `assets/scripts/ui/command_buffer_text.lua`

**Step 1: Update character initialization in _format_characters**

Find the section where characters are initialized (around line 227-233) and add new properties:

```lua
-- In _format_characters, where ch.x, ch.y are set, add:
      ch.x, ch.y, ch.line = cx, cy, line
      ch.r = 0
      ch.ox, ch.oy = 0, 0
      ch.w, ch.h = w, line_height
      -- NEW: Extended properties
      ch.rotation = 0
      ch.scale = 1
      ch.scaleX = 1
      ch.scaleY = 1
      ch.alpha = 255
      ch.codepoint = nil
      ch.effect_data = {}
      ch.effect_finished = nil
```

**Step 2: Update the space character handling too (around line 221-225)**

```lua
      ch.x, ch.y, ch.line = cx, cy, line
      ch.r = 0
      ch.ox, ch.oy = 0, 0
      ch.w, ch.h = space_w, line_height
      -- NEW: Extended properties
      ch.rotation = 0
      ch.scale = 1
      ch.scaleX = 1
      ch.scaleY = 1
      ch.alpha = 255
      ch.codepoint = nil
      ch.effect_data = {}
      ch.effect_finished = nil
```

**Step 3: Commit**

```bash
git add assets/scripts/ui/command_buffer_text.lua
git commit -m "feat(text): extend character model with rotation, scale, alpha, codepoint"
```

---

## Task 9: Update command_buffer_text.lua - Effect System Integration

**Files:**
- Modify: `assets/scripts/ui/command_buffer_text.lua`

**Step 1: Add require for effects at top of file**

After the existing requires (around line 15-17), add:

```lua
local text_effects = require("ui.text_effects")
-- Load all effect modules
require("ui.text_effects.static")
require("ui.text_effects.continuous")
require("ui.text_effects.oneshot")
require("ui.text_effects.juicy")
require("ui.text_effects.magical")
require("ui.text_effects.elemental")
```

**Step 2: Update DEFAULT_EFFECTS to use registry**

Replace the existing DEFAULT_EFFECTS table (around line 63-87) with:

```lua
local function get_time()
  if main_loop and main_loop.getTime then
    return main_loop.getTime()
  end
  return os.clock()
end

local DEFAULT_EFFECTS = {
  -- Fallback for legacy color effect
  color = function(_, dt, char, color)
    char.color = text_effects.get_color(color)
  end,
}

local function merge_effects(custom)
  -- Start with registry effects, then add custom
  local merged = {}
  for name, entry in pairs(text_effects.list()) do
    merged[name] = function(self, dt, char, ...)
      local ctx = {
        time = get_time(),
        char_count = #self.characters,
        text_w = self.text_w,
        text_h = self.text_h,
        first_frame = self.first_frame,
      }
      text_effects.apply(name, ctx, dt, char, {...})
    end
  end
  -- Override with custom effects
  for k, v in pairs(DEFAULT_EFFECTS) do merged[k] = v end
  for k, v in pairs(custom or {}) do merged[k] = v end
  return merged
end
```

Wait, this approach is getting complex. Let me simplify by updating the update() method instead.

**Step 2 (Revised): Update the update() method to use the new effect system**

Find the effect application loop in update() (around line 352-359) and update to:

```lua
    -- Reset per-frame properties
    ch.ox, ch.oy = 0, 0
    ch.rotation = 0
    ch.scale = 1
    ch.scaleX = 1
    ch.scaleY = 1
    ch.alpha = 255
    -- Don't reset: ch.color (set by base_color), ch.effect_data (persistent), ch.codepoint

    if ch.effects and #ch.effects > 0 then
      -- Build context for effects
      local ctx = {
        time = get_time(),
        char_count = #self.characters,
        text_w = self.text_w,
        text_h = self.text_h,
        first_frame = self.first_frame,
      }

      for _, eff in ipairs(ch.effects) do
        local name = eff[1]
        -- Try registry first, then custom effects
        local registered = text_effects.get(name)
        if registered then
          local args = {}
          for i = 2, #eff do args[i-1] = eff[i] end
          text_effects.apply(name, ctx, dt, ch, args)
        else
          local fn = name and self.text_effects[name]
          if fn then
            fn(self, dt or 0, ch, unpack(eff, 2))
          end
        end
      end
    end
```

**Step 3: Commit**

```bash
git add assets/scripts/ui/command_buffer_text.lua
git commit -m "feat(text): integrate effect registry into update loop"
```

---

## Task 10: Update command_buffer_text.lua - Rendering with Matrix Transforms

**Files:**
- Modify: `assets/scripts/ui/command_buffer_text.lua`

**Step 1: Update the rendering section to use queueTextPro with matrix transforms for scale**

Find the command_buffer.queueDrawText call (around line 365-373) and replace with:

```lua
    local draw_x = origin_x + (ch.x or 0) + (ch.ox or 0)
    local draw_y = origin_y + (ch.y or 0) + (ch.oy or 0)
    local draw_char = ch.codepoint or ch.c
    local draw_rotation = ch.rotation or 0
    local draw_scale = (ch.scale or 1)
    local draw_scaleX = draw_scale * (ch.scaleX or 1)
    local draw_scaleY = draw_scale * (ch.scaleY or 1)
    local draw_color = ch.color or default_color
    if ch.alpha and ch.alpha < 255 then
      draw_color = Col(draw_color.r, draw_color.g, draw_color.b, ch.alpha)
    end

    local needs_scale = draw_scaleX ~= 1 or draw_scaleY ~= 1
    local char_z = self.z or 0

    if needs_scale then
      -- Use matrix transforms for scale
      command_buffer.queuePushMatrix(layer_handle, function(c) end, char_z, self.render_space)
      command_buffer.queueTranslate(layer_handle, function(c)
        c.x = draw_x
        c.y = draw_y
      end, char_z, self.render_space)
      command_buffer.queueScale(layer_handle, function(c)
        c.x = draw_scaleX
        c.y = draw_scaleY
      end, char_z, self.render_space)
      command_buffer.queueTextPro(layer_handle, function(c)
        c.text = draw_char
        c.font = font_ref
        c.x = 0
        c.y = 0
        c.origin = { x = (ch.w or 0) / 2, y = (ch.h or 0) / 2 }
        c.rotation = draw_rotation
        c.fontSize = self.font_size
        c.spacing = self.letter_spacing or 1
        c.color = draw_color
      end, char_z, self.render_space)
      command_buffer.queuePopMatrix(layer_handle, function(c) end, char_z, self.render_space)
    else
      -- Simple case: just rotation, no scale
      command_buffer.queueTextPro(layer_handle, function(c)
        c.text = draw_char
        c.font = font_ref
        c.x = draw_x
        c.y = draw_y
        c.origin = { x = (ch.w or 0) / 2, y = (ch.h or 0) / 2 }
        c.rotation = draw_rotation
        c.fontSize = self.font_size
        c.spacing = self.letter_spacing or 1
        c.color = draw_color
      end, char_z, self.render_space)
    end
```

**Step 2: Commit**

```bash
git add assets/scripts/ui/command_buffer_text.lua
git commit -m "feat(text): add matrix transform rendering for scale effects"
```

---

## Task 11: Add get_time Helper

**Files:**
- Modify: `assets/scripts/ui/command_buffer_text.lua`

**Step 1: Add get_time function near the top of the file (after requires)**

```lua
local function get_time()
  if main_loop and main_loop.getTime then
    return main_loop.getTime()
  end
  return os.clock()
end
```

**Step 2: Commit**

```bash
git add assets/scripts/ui/command_buffer_text.lua
git commit -m "feat(text): add get_time helper for effect timing"
```

---

## Task 12: Create Effect Demo/Test Script

**Files:**
- Create: `assets/scripts/ui/text_effects_demo.lua`

**Step 1: Write demo script to test all effects**

```lua
-- assets/scripts/ui/text_effects_demo.lua
-- Demo script for testing text effects
-- Usage: local demo = require("ui.text_effects_demo")
--        demo.show_all()

local Text = require("ui.command_buffer_text")
local text_effects = require("ui.text_effects")

local demo = {}
local active_demos = {}

function demo.create_sample(effect_name, y_offset)
  local sample_text = string.format("[%s](%s)", effect_name, effect_name)

  local t = Text({
    text = sample_text,
    w = 400,
    x = 320,
    y = 100 + (y_offset or 0),
    layer = layers and layers.ui,
    font_size = 24,
    alignment = "center",
    anchor = "center",
  })

  return t
end

function demo.show_all()
  -- Clear existing demos
  active_demos = {}

  local effects_list = text_effects.list()
  local y = 0
  local spacing = 35

  for _, name in ipairs(effects_list) do
    local t = demo.create_sample(name, y)
    table.insert(active_demos, t)
    y = y + spacing
  end

  return active_demos
end

function demo.show_category(category)
  active_demos = {}

  local categories = {
    static = { "color", "fan" },
    continuous = { "shake", "float", "pulse", "bump", "wiggle", "rotate", "spin", "fade", "rainbow", "highlight", "expand" },
    oneshot = { "pop", "slide", "bounce", "scramble" },
    juicy = { "jelly", "hop", "rubberband", "swing", "tremble", "pop_rotate", "slam", "wave", "heartbeat", "squish" },
    magical = { "glow_pulse", "shimmer", "float_drift", "sparkle", "enchant", "rise", "waver", "phase", "orbit", "cascade" },
    elemental = { "burn", "freeze", "poison", "electric", "holy", "void", "fire", "ice" },
  }

  local effects = categories[category]
  if not effects then return end

  local y = 0
  for _, name in ipairs(effects) do
    local t = demo.create_sample(name, y)
    table.insert(active_demos, t)
    y = y + 35
  end

  return active_demos
end

function demo.update_all(dt)
  for _, t in ipairs(active_demos) do
    t:update(dt)
  end
end

function demo.clear()
  active_demos = {}
end

return demo
```

**Step 2: Commit**

```bash
git add assets/scripts/ui/text_effects_demo.lua
git commit -m "feat(text): add text effects demo script"
```

---

## Task 13: Final Integration Test

**Step 1: Run the game and test effects**

Run: `just build-debug && ./build/raylib-cpp-cmake-template`

Expected: Game launches without Lua errors

**Step 2: Test in-game (if debug console available)**

```lua
local demo = require("ui.text_effects_demo")
demo.show_category("juicy")
```

Expected: Text samples with juicy effects appear on screen

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat(text): complete text effects Lua port with 38 effects"
```

---

## Summary

**38 Total Effects:**

| Category | Count | Effects |
|----------|-------|---------|
| Static | 2 | color, fan |
| Continuous | 11 | shake, float, pulse, bump, wiggle, rotate, spin, fade, rainbow, highlight, expand |
| One-Shot | 4 | pop, slide, bounce, scramble |
| Juicy | 10 | jelly, hop, rubberband, swing, tremble, pop_rotate, slam, wave, heartbeat, squish |
| Magical | 10 | glow_pulse, shimmer, float_drift, sparkle, enchant, rise, waver, phase, orbit, cascade |
| Elemental | 8 | burn, freeze, poison, electric, holy, void, fire, ice |

**Key Features:**
- Smart defaults with easy overrides
- Color integration (not just positioning)
- Matrix transforms for proper scaling
- Persistent effect state via `ch.effect_data`
- One-shot effect completion tracking via `ch.effect_finished`
