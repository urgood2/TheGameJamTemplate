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
