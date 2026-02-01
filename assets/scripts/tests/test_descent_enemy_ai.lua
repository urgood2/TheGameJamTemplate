-- assets/scripts/tests/test_descent_enemy_ai.lua
--[[
================================================================================
DESCENT ENEMY AI TESTS
================================================================================
Validates decision priority rules for enemy AI.
]]

local t = require("tests.test_runner")
local Map = require("descent.map")
local Enemy = require("descent.enemy")

local function make_open_map(w, h)
  local map = Map.new(w, h, { default_tile = Map.TILE.FLOOR })
  for y = 1, h do
    for x = 1, w do
      Map.set_tile(map, x, y, Map.TILE.FLOOR)
    end
  end
  return map
end

t.describe("Descent Enemy AI", function()
  t.it("attacks when adjacent to player", function()
    local map = make_open_map(5, 5)
    local enemy = Enemy.create("goblin", 2, 2)
    local game_state = {
      player = { x = 3, y = 2 },
      map = map,
      fov = { is_visible = function() return true end },
    }

    local decision = Enemy.decide(enemy, game_state)
    t.expect(decision.type).to_be(Enemy.DECISION.ATTACK)
  end)

  t.it("moves toward player when visible and path exists", function()
    local map = make_open_map(5, 5)
    local enemy = Enemy.create("goblin", 2, 2)
    local game_state = {
      player = { x = 5, y = 2 },
      map = map,
      fov = { is_visible = function() return true end },
    }

    local decision = Enemy.decide(enemy, game_state)
    t.expect(decision.type).to_be(Enemy.DECISION.MOVE)
    t.expect(decision.target_x).to_be(3)
    t.expect(decision.target_y).to_be(2)
  end)

  t.it("idles when visible but no path", function()
    local map = make_open_map(3, 3)
    -- Block goal tile so pathfinding fails
    Map.set_tile(map, 3, 2, Map.TILE.WALL)

    local enemy = Enemy.create("goblin", 1, 2)
    local game_state = {
      player = { x = 3, y = 2 },
      map = map,
      fov = { is_visible = function() return true end },
    }

    local decision = Enemy.decide(enemy, game_state)
    t.expect(decision.type).to_be(Enemy.DECISION.IDLE)
  end)

  t.it("idles when player not visible", function()
    local map = make_open_map(5, 5)
    local enemy = Enemy.create("goblin", 2, 2)
    local game_state = {
      player = { x = 5, y = 5 },
      map = map,
      fov = { is_visible = function() return false end },
    }

    local decision = Enemy.decide(enemy, game_state)
    t.expect(decision.type).to_be(Enemy.DECISION.IDLE)
  end)
end)
