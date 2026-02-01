-- assets/scripts/tests/test_descent_procgen_validation.lua
--[[
================================================================================
DESCENT PROCGEN VALIDATION TESTS
================================================================================
Validates Descent procgen output for seeds 1-10:
  - Walkable start/stairs
  - Reachable stairs from start
  - Quotas (enemies, shop/altar/miniboss/boss)
  - No overlapping placements
  - Fallback behavior when max attempts is zero
]]

local t = require("tests.test_runner")
local Procgen = require("descent.procgen")
local Spec = require("descent.spec")
local Map = require("descent.map")
local Pathfinding = require("descent.pathfinding")

local function pos_key(pos)
  return tostring(pos.x) .. "," .. tostring(pos.y)
end

local function add_position(list, label, pos)
  if pos then
    table.insert(list, { label = label, x = pos.x, y = pos.y })
  end
end

local function collect_positions(placements)
  local list = {}
  add_position(list, "start", placements.player_start)
  add_position(list, "stairs_down", placements.stairs_down)
  add_position(list, "stairs_up", placements.stairs_up)
  add_position(list, "shop", placements.shop)
  add_position(list, "altar", placements.altar)
  add_position(list, "miniboss", placements.miniboss)
  add_position(list, "boss", placements.boss)
  if placements.enemies then
    for i, enemy in ipairs(placements.enemies) do
      add_position(list, "enemy_" .. tostring(i), enemy)
    end
  end
  return list
end

local function assert_in_bounds(map, pos, label)
  if not Map.in_bounds(map, pos.x, pos.y) then
    error("Placement out of bounds: " .. tostring(label) .. " at " .. pos_key(pos), 2)
  end
end

local function assert_walkable(map, pos, label)
  if not Map.is_walkable(map, pos.x, pos.y) then
    error("Placement not walkable: " .. tostring(label) .. " at " .. pos_key(pos), 2)
  end
end

local function assert_reachable(map, start, goal, label)
  local path = Pathfinding.find_path(map, start.x, start.y, goal.x, goal.y)
  if not path then
    error("Unreachable target: " .. tostring(label) .. " from start", 2)
  end
end

local function assert_no_overlaps(positions, seed, floor)
  local seen = {}
  for _, pos in ipairs(positions) do
    local key = pos_key(pos)
    if seen[key] then
      error(string.format(
        "Overlap at %s (seed %d, floor %d): %s and %s",
        key, seed, floor, tostring(seen[key]), tostring(pos.label)
      ), 2)
    end
    seen[key] = pos.label
  end
end

local function validate_floor_data(seed, floor, floor_data)
  local floor_spec = Spec.floors.floors[floor]
  local map = floor_data.map
  local placements = floor_data.placements or {}

  if map.w ~= floor_spec.width or map.h ~= floor_spec.height then
    error(string.format(
      "Map size mismatch (seed %d, floor %d): got %dx%d expected %dx%d",
      seed, floor, map.w, map.h, floor_spec.width, floor_spec.height
    ), 2)
  end

  if not placements.player_start then
    error(string.format("Missing player start (seed %d, floor %d)", seed, floor), 2)
  end
  assert_in_bounds(map, placements.player_start, "start")
  assert_walkable(map, placements.player_start, "start")

  if floor_spec.stairs_down then
    if not placements.stairs_down then
      error(string.format("Missing stairs down (seed %d, floor %d)", seed, floor), 2)
    end
    assert_in_bounds(map, placements.stairs_down, "stairs_down")
    assert_walkable(map, placements.stairs_down, "stairs_down")
    assert_reachable(map, placements.player_start, placements.stairs_down, "stairs_down")
  else
    t.expect(placements.stairs_down).to_be_nil()
  end

  if floor_spec.stairs_up then
    if not placements.stairs_up then
      error(string.format("Missing stairs up (seed %d, floor %d)", seed, floor), 2)
    end
    assert_in_bounds(map, placements.stairs_up, "stairs_up")
    assert_walkable(map, placements.stairs_up, "stairs_up")
    assert_reachable(map, placements.player_start, placements.stairs_up, "stairs_up")
  else
    t.expect(placements.stairs_up).to_be_nil()
  end

  local enemies = placements.enemies or {}
  if #enemies < floor_spec.enemies_min or #enemies > floor_spec.enemies_max then
    error(string.format(
      "Enemy count out of range (seed %d, floor %d): %d not in [%d,%d]",
      seed, floor, #enemies, floor_spec.enemies_min, floor_spec.enemies_max
    ), 2)
  end
  for i, enemy in ipairs(enemies) do
    assert_in_bounds(map, enemy, "enemy_" .. tostring(i))
    assert_walkable(map, enemy, "enemy_" .. tostring(i))
  end

  if floor_spec.shop then
    if not placements.shop then
      error(string.format("Missing shop placement (seed %d, floor %d)", seed, floor), 2)
    end
    assert_in_bounds(map, placements.shop, "shop")
    assert_walkable(map, placements.shop, "shop")
  else
    t.expect(placements.shop).to_be_nil()
  end

  if floor_spec.altar then
    if not placements.altar then
      error(string.format("Missing altar placement (seed %d, floor %d)", seed, floor), 2)
    end
    assert_in_bounds(map, placements.altar, "altar")
    assert_walkable(map, placements.altar, "altar")
  else
    t.expect(placements.altar).to_be_nil()
  end

  if floor_spec.miniboss then
    if not placements.miniboss then
      error(string.format("Missing miniboss placement (seed %d, floor %d)", seed, floor), 2)
    end
    assert_in_bounds(map, placements.miniboss, "miniboss")
    assert_walkable(map, placements.miniboss, "miniboss")
  else
    t.expect(placements.miniboss).to_be_nil()
  end

  if floor_spec.boss then
    if not placements.boss then
      error(string.format("Missing boss placement (seed %d, floor %d)", seed, floor), 2)
    end
    assert_in_bounds(map, placements.boss, "boss")
    assert_walkable(map, placements.boss, "boss")
  else
    t.expect(placements.boss).to_be_nil()
  end

  local positions = collect_positions(placements)
  assert_no_overlaps(positions, seed, floor)
end

local function generate_with_zero_attempts(floor, seed)
  local old_max = Spec.floors.max_gen_attempts
  local old_procgen = package.loaded["descent.procgen"]

  Spec.floors.max_gen_attempts = 0
  package.loaded["descent.procgen"] = nil

  local ok, result, warning = pcall(function()
    local procgen_zero = require("descent.procgen")
    return procgen_zero.generate(floor, seed)
  end)

  Spec.floors.max_gen_attempts = old_max
  package.loaded["descent.procgen"] = old_procgen

  if not ok then
    error(result, 2)
  end

  return result, warning
end

t.describe("Descent procgen validation", function()
  t.it("generates valid floors for seeds 1-10", function()
    for seed = 1, 10 do
      for floor = 1, Spec.floors.total do
        local floor_data = Procgen.generate(floor, seed)
        if not floor_data then
          error(string.format("Procgen returned nil (seed %d, floor %d)", seed, floor), 2)
        end
        validate_floor_data(seed, floor, floor_data)
      end
    end
  end)

  t.it("falls back when max attempts is zero", function()
    local floor = 1
    local seed = 7
    local floor_data, warning = generate_with_zero_attempts(floor, seed)

    t.expect(floor_data.fallback).to_be_truthy()
    t.expect(warning).to_be_truthy()
    t.expect(floor_data.placements).to_be_truthy()
    t.expect(floor_data.map).to_be_truthy()

    local placements = floor_data.placements
    t.expect(placements.player_start).to_be_truthy()
    assert_walkable(floor_data.map, placements.player_start, "start")

    local floor_spec = Spec.floors.floors[floor]
    if floor_spec.stairs_down then
      t.expect(placements.stairs_down).to_be_truthy()
      assert_walkable(floor_data.map, placements.stairs_down, "stairs_down")
    end
    if floor_spec.stairs_up then
      t.expect(placements.stairs_up).to_be_truthy()
      assert_walkable(floor_data.map, placements.stairs_up, "stairs_up")
    end
  end)
end)
