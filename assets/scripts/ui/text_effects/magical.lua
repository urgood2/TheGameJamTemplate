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
