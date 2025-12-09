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
  if not color then return effects.colors.white end
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
