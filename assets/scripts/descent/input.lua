-- assets/scripts/descent/input.lua
-- Input mapping helper for Descent (engine-agnostic).

local Input = {}

local spec = require("descent.spec")

local MOVE_BINDINGS = {
  { names = {"move_north", "move_up"}, dx = 0, dy = -1, keys = spec.movement.bindings.north },
  { names = {"move_south", "move_down"}, dx = 0, dy = 1, keys = spec.movement.bindings.south },
  { names = {"move_west", "move_left"}, dx = -1, dy = 0, keys = spec.movement.bindings.west },
  { names = {"move_east", "move_right"}, dx = 1, dy = 0, keys = spec.movement.bindings.east },
  { names = {"move_northwest", "move_upleft"}, dx = -1, dy = -1, keys = spec.movement.bindings.northwest },
  { names = {"move_northeast", "move_upright"}, dx = 1, dy = -1, keys = spec.movement.bindings.northeast },
  { names = {"move_southwest", "move_downleft"}, dx = -1, dy = 1, keys = spec.movement.bindings.southwest },
  { names = {"move_southeast", "move_downright"}, dx = 1, dy = 1, keys = spec.movement.bindings.southeast },
}

local function has_key(state, key)
  if not state then return false end
  if state.keys and state.keys[key] then return true end
  if state.keys_down and state.keys_down[key] then return true end
  if state.keys_pressed and state.keys_pressed[key] then return true end
  return false
end

local function action_active(state, name)
  if not state then return false end
  if type(state.action_pressed) == "function" then
    return state.action_pressed(name) == true
  end
  if state.actions and state.actions[name] then
    return true
  end
  if state.input and type(state.input.action_pressed) == "function" then
    return state.input.action_pressed(name) == true
  end
  if _G.input and type(_G.input.action_pressed) == "function" then
    return _G.input.action_pressed(name) == true
  end
  return false
end

function Input.poll(state)
  state = state or {}

  if state.intent then
    return state.intent
  end

  if state.dx or state.dy then
    return { type = "move", dx = state.dx or 0, dy = state.dy or 0 }
  end

  if state.wait or action_active(state, "wait") or has_key(state, ".") then
    return { type = "wait" }
  end

  for _, binding in ipairs(MOVE_BINDINGS) do
    local matched = false
    for _, name in ipairs(binding.names) do
      if action_active(state, name) then
        matched = true
        break
      end
    end
    if not matched and binding.keys then
      for _, key in ipairs(binding.keys) do
        if has_key(state, key) then
          matched = true
          break
        end
      end
    end
    if matched then
      return { type = "move", dx = binding.dx, dy = binding.dy }
    end
  end

  return nil
end

return Input
