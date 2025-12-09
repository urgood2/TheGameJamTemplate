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
