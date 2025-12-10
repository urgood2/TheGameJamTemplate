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
