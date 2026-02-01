-- assets/scripts/tests/test_descent_pathfinding.lua
--[[
================================================================================
DESCENT PATHFINDING TESTS
================================================================================
Validates deterministic paths, neighbor order, and unreachable handling.
]]

local t = require("tests.test_runner")
local Map = require("descent.map")
local Pathfinding = require("descent.pathfinding")

local function make_open_map(w, h)
  local map = Map.new(w, h, { default_tile = Map.TILE.FLOOR })
  for y = 1, h do
    for x = 1, w do
      Map.set_tile(map, x, y, Map.TILE.FLOOR)
    end
  end
  return map
end

t.describe("Descent Pathfinding", function()
  t.it("exposes canonical neighbor order", function()
    local order = Pathfinding.get_neighbor_order()
    t.expect(order[1].dx).to_be(0)
    t.expect(order[1].dy).to_be(-1)
    t.expect(order[2].dx).to_be(1)
    t.expect(order[2].dy).to_be(0)
    t.expect(order[3].dx).to_be(0)
    t.expect(order[3].dy).to_be(1)
    t.expect(order[4].dx).to_be(-1)
    t.expect(order[4].dy).to_be(0)
  end)

  t.it("returns deterministic BFS path with explicit neighbor order", function()
    local map = make_open_map(3, 3)
    local path = Pathfinding.find_path_bfs(map, 1, 1, 2, 2, { allow_diagonal = false })
    t.expect(#path).to_be(3)
    t.expect(path[1].x).to_be(1)
    t.expect(path[1].y).to_be(1)
    t.expect(path[2].x).to_be(2)
    t.expect(path[2].y).to_be(1)
    t.expect(path[3].x).to_be(2)
    t.expect(path[3].y).to_be(2)

    local path2 = Pathfinding.find_path_bfs(map, 1, 1, 2, 2, { allow_diagonal = false })
    t.expect(#path2).to_be(#path)
    t.expect(path2[2].x).to_be(path[2].x)
    t.expect(path2[2].y).to_be(path[2].y)
  end)

  t.it("returns nil when unreachable", function()
    local map = make_open_map(3, 3)
    -- Block both cardinal exits from start
    Map.set_tile(map, 2, 1, Map.TILE.WALL)
    Map.set_tile(map, 1, 2, Map.TILE.WALL)

    local path = Pathfinding.find_path_bfs(map, 1, 1, 2, 2, { allow_diagonal = false })
    t.expect(path).to_be(nil)
  end)
end)
