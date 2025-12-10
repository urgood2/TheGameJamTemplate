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
