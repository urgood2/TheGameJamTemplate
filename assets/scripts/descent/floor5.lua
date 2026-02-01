-- assets/scripts/descent/floor5.lua
-- Boss floor arena + boss phase helpers for Descent.

local Floor5 = {}

local Map = require("descent.map")
local spec = require("descent.spec")

local callbacks = {
  on_victory = nil,
  on_error = nil,
}

local function safe_call(fn, ...)
  local ok, result = pcall(fn, ...)
  if ok then
    return true, result
  end
  if callbacks.on_error then
    callbacks.on_error(result)
  else
    local log_fn = log_warn or print
    log_fn("[Floor5] error: " .. tostring(result))
  end
  return false, result
end

local function make_boss()
  return {
    hp = spec.boss.stats.hp,
    hp_max = spec.boss.stats.hp,
    damage = spec.boss.stats.damage,
    speed = spec.boss.stats.speed,
    phase = 1,
    damage_multiplier = 1.0,
    summon_count = spec.boss.phases[2].summon_count,
    summon_interval_turns = spec.boss.phases[2].summon_interval_turns,
  }
end

local function update_boss_phase(boss)
  local hp_max = boss.hp_max > 0 and boss.hp_max or 1
  local pct = boss.hp / hp_max
  local p1 = spec.boss.phases[1].hp_pct_min
  local p2 = spec.boss.phases[2].hp_pct_min
  if pct >= p1 then
    boss.phase = 1
    boss.damage_multiplier = 1.0
    return boss.phase
  end
  if pct >= p2 then
    boss.phase = 2
    boss.damage_multiplier = 1.0
    return boss.phase
  end
  boss.phase = 3
  boss.damage_multiplier = spec.boss.phases[3].damage_multiplier or 1.5
  return boss.phase
end

function Floor5.generate(seed)
  local map = Map.new_for_floor(spec.boss.floor)
  -- carve arena: walls border, floor interior
  for y = 2, map.h - 1 do
    for x = 2, map.w - 1 do
      map.set_tile(x, y, Map.TILE.FLOOR)
    end
  end

  local cx = math.floor(map.w / 2)
  local cy = math.floor(map.h / 2)

  local placements = {
    player_start = { x = 3, y = 3 },
    stairs_up = { x = 2, y = 2 },
    boss = { x = cx, y = cy },
    guards = {},
  }

  map.set_tile(placements.stairs_up.x, placements.stairs_up.y, Map.TILE.STAIRS_UP)

  -- Simple guard ring around boss
  local guard_positions = {
    { x = cx - 1, y = cy },
    { x = cx + 1, y = cy },
    { x = cx, y = cy - 1 },
    { x = cx, y = cy + 1 },
    { x = cx - 1, y = cy - 1 },
  }
  for i = 1, math.min(spec.boss.guards, #guard_positions) do
    table.insert(placements.guards, guard_positions[i])
  end

  return {
    floor_num = spec.boss.floor,
    map = map,
    placements = placements,
    boss = make_boss(),
    seed = seed,
  }
end

function Floor5.apply_boss_phase(boss)
  return update_boss_phase(boss)
end

function Floor5.check_victory(game_state)
  local boss = game_state and game_state.boss or nil
  if boss and boss.hp <= 0 then
    if callbacks.on_victory then
      callbacks.on_victory(game_state)
    end
    return true
  end
  return false
end

function Floor5.on_victory(callback)
  callbacks.on_victory = callback
end

function Floor5.on_error(callback)
  callbacks.on_error = callback
end

function Floor5.safe_call(fn, ...)
  return safe_call(fn, ...)
end

return Floor5
