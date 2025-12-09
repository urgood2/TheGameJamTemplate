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
