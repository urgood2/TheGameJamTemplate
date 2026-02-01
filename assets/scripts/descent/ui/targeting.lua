-- assets/scripts/descent/ui/targeting.lua
--[[
================================================================================
DESCENT TARGETING UI
================================================================================
Target selection UI for spells and abilities.

Features:
- Highlights range and valid targets
- Cursor-based selection with movement keys
- Confirm and cancel actions
- Supports tile and entity targeting modes

Usage:
  local targeting = require("descent.ui.targeting")
  targeting.open({
    map = map,
    origin = { x = player.x, y = player.y },
    range = 6,
    mode = "entity", -- or "tile"
    targets = enemies, -- array of entities with x/y
    requires_los = true,
    fov = fov,
    on_confirm = function(target) ... end,
    on_cancel = function() ... end,
  })
================================================================================
]]

local M = {}

local Map = require("descent.map")
local spec = require("descent.spec")

local state = {
  active = false,
  mode = "tile",
  map = nil,
  fov = nil,
  origin = { x = 1, y = 1 },
  range = 0,
  cursor = { x = 1, y = 1 },
  range_tiles = {},
  valid_tiles = {},
  targets = {},
  targets_source = {},
  target_index = 1,
  on_confirm = nil,
  on_cancel = nil,
  allow_self = false,
  requires_los = false,
  is_valid_tile = nil,
  is_valid_target = nil,
  los_fn = nil,
}

local bindings = {
  cancel = { "Escape", "Backspace" },
  confirm = { "Enter", "Return", "Space" },
  next = { "Tab" },
  prev = { "BackTab" },
}

local directions = {
  { dx = 0, dy = -1, keys = spec.movement.bindings.north },
  { dx = 0, dy = 1, keys = spec.movement.bindings.south },
  { dx = -1, dy = 0, keys = spec.movement.bindings.west },
  { dx = 1, dy = 0, keys = spec.movement.bindings.east },
  { dx = -1, dy = -1, keys = spec.movement.bindings.northwest },
  { dx = 1, dy = -1, keys = spec.movement.bindings.northeast },
  { dx = -1, dy = 1, keys = spec.movement.bindings.southwest },
  { dx = 1, dy = 1, keys = spec.movement.bindings.southeast },
}

local function key_matches(key, list)
  if not key or not list then return false end
  for _, k in ipairs(list) do
    if k == key then
      return true
    end
  end
  return false
end

local function direction_for_key(key)
  for _, dir in ipairs(directions) do
    if key_matches(key, dir.keys) then
      return dir.dx, dir.dy
    end
  end
  return nil, nil
end

local function tile_key(x, y)
  return tostring(x) .. "," .. tostring(y)
end

local function chebyshev_distance(a, b)
  return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
end

local function in_bounds(map, x, y)
  if not map then return true end
  return Map.in_bounds(map, x, y)
end

local function has_los(origin, target)
  if state.los_fn then
    return state.los_fn(origin, target) ~= false
  end
  if state.fov and state.fov.is_visible then
    return state.fov.is_visible(target.x, target.y)
  end
  return true
end

local function reset_state()
  state.active = false
  state.mode = "tile"
  state.map = nil
  state.fov = nil
  state.origin = { x = 1, y = 1 }
  state.range = 0
  state.cursor = { x = 1, y = 1 }
  state.range_tiles = {}
  state.valid_tiles = {}
  state.targets = {}
  state.targets_source = {}
  state.target_index = 1
  state.on_confirm = nil
  state.on_cancel = nil
  state.allow_self = false
  state.requires_los = false
  state.is_valid_tile = nil
  state.is_valid_target = nil
  state.los_fn = nil
end

local function push_range_tile(x, y)
  table.insert(state.range_tiles, { x = x, y = y })
end

local function push_valid_tile(x, y, target)
  local key = tile_key(x, y)
  state.valid_tiles[key] = target or true
end

local function build_range_tiles()
  state.range_tiles = {}
  if not state.origin then return end

  local r = math.max(0, state.range or 0)
  for dx = -r, r do
    for dy = -r, r do
      local distance = math.max(math.abs(dx), math.abs(dy))
      if distance <= r then
        local x = state.origin.x + dx
        local y = state.origin.y + dy
        if in_bounds(state.map, x, y) then
          push_range_tile(x, y)
        end
      end
    end
  end
end

local function build_valid_targets()
  state.valid_tiles = {}
  state.targets = {}
  state.target_index = 1

  if not state.origin then return end

  if state.mode == "entity" then
    for _, target in ipairs(state.targets_source or {}) do
      local tx, ty = target.x, target.y
      if tx and ty then
        local tpos = { x = tx, y = ty }
        local distance = chebyshev_distance(state.origin, tpos)
        if distance <= state.range then
          local is_self = (tx == state.origin.x and ty == state.origin.y)
          if not is_self or state.allow_self then
            local los_ok = (not state.requires_los) or has_los(state.origin, tpos)
            local custom_ok = (not state.is_valid_target) or state.is_valid_target(target)
            if los_ok and custom_ok then
              local entry = { x = tx, y = ty, entity = target }
              table.insert(state.targets, entry)
              push_valid_tile(tx, ty, entry)
            end
          end
        end
      end
    end
    return
  end

  for _, tile in ipairs(state.range_tiles) do
    local tpos = { x = tile.x, y = tile.y }
    local los_ok = (not state.requires_los) or has_los(state.origin, tpos)
    local valid_tile = true
    if state.is_valid_tile then
      valid_tile = state.is_valid_tile(tile.x, tile.y) == true
    elseif state.map then
      valid_tile = Map.is_walkable(state.map, tile.x, tile.y)
    end
    if los_ok and valid_tile then
      local entry = { x = tile.x, y = tile.y }
      push_valid_tile(tile.x, tile.y, entry)
      table.insert(state.targets, entry)
    end
  end
end

local function pick_initial_cursor()
  if #state.targets > 0 then
    local first = state.targets[1]
    state.cursor = { x = first.x, y = first.y }
    state.target_index = 1
  else
    state.cursor = { x = state.origin.x, y = state.origin.y }
    state.target_index = 1
  end
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function M.open(opts)
  opts = opts or {}

  state.active = true
  state.mode = opts.mode or "tile"
  state.map = opts.map
  state.fov = opts.fov
  state.origin = opts.origin or { x = 1, y = 1 }
  state.range = opts.range or 0
  state.on_confirm = opts.on_confirm
  state.on_cancel = opts.on_cancel
  state.allow_self = opts.allow_self or false
  state.requires_los = opts.requires_los or false
  state.is_valid_tile = opts.is_valid_tile
  state.is_valid_target = opts.is_valid_target
  state.los_fn = opts.has_los

  state.targets_source = opts.targets or {}

  build_range_tiles()
  build_valid_targets()
  pick_initial_cursor()
end

function M.close()
  reset_state()
end

function M.cancel()
  if not state.active then return false end
  local cb = state.on_cancel
  M.close()
  if cb then cb() end
  return true
end

function M.is_active()
  return state.active
end

function M.get_origin()
  return { x = state.origin.x, y = state.origin.y }
end

function M.get_cursor()
  return { x = state.cursor.x, y = state.cursor.y }
end

function M.get_range_tiles()
  return state.range_tiles
end

function M.get_valid_tiles()
  return state.valid_tiles
end

function M.get_targets()
  return state.targets
end

function M.is_valid_at(x, y)
  return state.valid_tiles[tile_key(x, y)] ~= nil
end

function M.get_selected_target()
  local key = tile_key(state.cursor.x, state.cursor.y)
  local entry = state.valid_tiles[key]
  if entry == true then
    return { x = state.cursor.x, y = state.cursor.y }
  end
  return entry
end

function M.select_next_target()
  if #state.targets == 0 then return end
  state.target_index = state.target_index + 1
  if state.target_index > #state.targets then
    state.target_index = 1
  end
  local entry = state.targets[state.target_index]
  if entry then
    state.cursor = { x = entry.x, y = entry.y }
  end
end

function M.select_prev_target()
  if #state.targets == 0 then return end
  state.target_index = state.target_index - 1
  if state.target_index < 1 then
    state.target_index = #state.targets
  end
  local entry = state.targets[state.target_index]
  if entry then
    state.cursor = { x = entry.x, y = entry.y }
  end
end

function M.move_cursor(dx, dy)
  if not state.active then return false end
  local nx = state.cursor.x + dx
  local ny = state.cursor.y + dy
  if not in_bounds(state.map, nx, ny) then
    return false
  end

  local distance = math.max(math.abs(nx - state.origin.x), math.abs(ny - state.origin.y))
  if distance > state.range then
    return false
  end

  state.cursor = { x = nx, y = ny }
  return true
end

function M.confirm()
  if not state.active then return false end

  local selected = M.get_selected_target()
  if not selected then
    return false, "no_target"
  end

  local cb = state.on_confirm
  M.close()
  if cb then cb(selected) end
  return true, selected
end

function M.refresh(opts)
  if opts then
    for k, v in pairs(opts) do
      state[k] = v
    end
  end
  build_range_tiles()
  build_valid_targets()
  pick_initial_cursor()
end

function M.handle_input(key)
  if not state.active then
    return false, nil, nil
  end

  if key_matches(key, bindings.cancel) then
    M.cancel()
    return true, "cancel", nil
  end

  if key_matches(key, bindings.confirm) then
    local ok, target = M.confirm()
    return true, ok and "confirm" or "invalid", target
  end

  if key_matches(key, bindings.next) then
    M.select_next_target()
    return true, "next", M.get_selected_target()
  end

  if key_matches(key, bindings.prev) then
    M.select_prev_target()
    return true, "prev", M.get_selected_target()
  end

  local dx, dy = direction_for_key(key)
  if dx then
    local moved = M.move_cursor(dx, dy)
    return true, moved and "move" or "blocked", M.get_cursor()
  end

  return false, nil, nil
end

function M.overlay()
  return {
    range = state.range_tiles,
    valid = state.valid_tiles,
    cursor = { x = state.cursor.x, y = state.cursor.y },
    origin = { x = state.origin.x, y = state.origin.y },
  }
end

function M.format()
  if not state.active then
    return "Targeting inactive"
  end

  local lines = {}
  table.insert(lines, string.format("Targeting (%s)", state.mode))
  table.insert(lines, string.format("Origin: %d,%d", state.origin.x, state.origin.y))
  table.insert(lines, string.format("Range: %d", state.range))
  table.insert(lines, string.format("Cursor: %d,%d", state.cursor.x, state.cursor.y))
  table.insert(lines, string.format("Targets: %d", #state.targets))

  if #state.targets > 0 then
    table.insert(lines, "Valid targets:")
    for i, tgt in ipairs(state.targets) do
      local mark = (tgt.x == state.cursor.x and tgt.y == state.cursor.y) and ">" or " "
      table.insert(lines, string.format("%s %d) %d,%d", mark, i, tgt.x, tgt.y))
    end
  end

  return table.concat(lines, "\n")
end

return M
