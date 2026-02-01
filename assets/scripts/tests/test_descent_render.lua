-- assets/scripts/tests/test_descent_render.lua
--[[
================================================================================
DESCENT RENDER TESTS
================================================================================
Validates wall/floor rendering with visibility and explored distinctions.
]]

local t = require("tests.test_runner")
local Render = require("descent.render")
local Map = require("descent.map")
local FOV = require("descent.fov")

local function make_open_map(w, h)
    local map = Map.new(w, h, { default_tile = Map.TILE.FLOOR })
    for y = 1, h do
        for x = 1, w do
            Map.set_tile(map, x, y, Map.TILE.FLOOR)
        end
    end
    return map
end

t.describe("Descent Render", function()
    t.it("hides unseen tiles", function()
        local map = make_open_map(30, 30)
        local state = {
            map = map,
            player = { x = 15, y = 15 },
            enemies = { list = {} },
        }

        Render.init(state)

        local unseen = Render.get_tile_render(30, 30)
        t.expect(unseen.char).to_be(" ")
        t.expect(unseen.visible).to_be(false)
        t.expect(unseen.explored).to_be(false)
    end)

    t.it("renders walls and explored floor tiles", function()
        local map = make_open_map(30, 30)
        Map.set_tile(map, 16, 15, Map.TILE.WALL)

        local state = {
            map = map,
            player = { x = 15, y = 15 },
            enemies = { list = {} },
        }

        Render.init(state)

        local wall = Render.get_tile_render(16, 15)
        t.expect(wall.char).to_be(Render.get_config().chars.wall)
        t.expect(wall.visible).to_be(true)

        -- Move FOV origin so the player tile is explored but not visible
        FOV.compute(1, 1)

        local explored = Render.get_tile_render(15, 15)
        t.expect(explored.char).to_be(Render.get_config().chars.floor)
        t.expect(explored.visible).to_be(false)
        t.expect(explored.explored).to_be(true)
    end)
end)

