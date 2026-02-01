-- assets/scripts/tests/test_descent_fov.lua
--[[
================================================================================
DESCENT FOV TESTS
================================================================================
Validates FOV algorithm: occlusion, bounds safety, explored persistence.

Acceptance criteria:
- Occlusion blocks vision
- Bounds are safe (no crashes OOB)
- Explored persists across computations
- Corner cases handled
]]

local t = require("tests.test_runner")
local FOV = require("descent.fov")
local Map = require("descent.map")

local function make_open_map(w, h)
    local map = Map.new(w, h, { default_tile = Map.TILE.FLOOR })
    for y = 1, h do
        for x = 1, w do
            Map.set_tile(map, x, y, Map.TILE.FLOOR)
        end
    end
    return map
end

--------------------------------------------------------------------------------
-- Basic FOV Tests
--------------------------------------------------------------------------------

t.describe("Descent FOV Basic", function()
    t.it("origin is always visible", function()
        local map = make_open_map(10, 10)
        FOV.init(map)
        FOV.set_dimensions(10, 10)
        FOV.compute(5, 5)
        
        t.expect(FOV.is_visible(5, 5)).to_be(true)
    end)

    t.it("adjacent tiles are visible", function()
        local map = make_open_map(10, 10)
        FOV.init(map)
        FOV.set_dimensions(10, 10)
        FOV.compute(5, 5)
        
        -- Cardinal directions
        t.expect(FOV.is_visible(5, 4)).to_be(true)
        t.expect(FOV.is_visible(5, 6)).to_be(true)
        t.expect(FOV.is_visible(4, 5)).to_be(true)
        t.expect(FOV.is_visible(6, 5)).to_be(true)
        
        -- Diagonal
        t.expect(FOV.is_visible(4, 4)).to_be(true)
        t.expect(FOV.is_visible(6, 6)).to_be(true)
    end)

    t.it("tiles beyond radius not visible", function()
        local map = make_open_map(30, 30)
        FOV.init(map)
        FOV.set_dimensions(30, 30)
        FOV.compute(15, 15)
        
        local radius = FOV.get_radius()
        -- Tile far beyond radius
        t.expect(FOV.is_visible(15 + radius + 5, 15)).to_be(false)
    end)

    t.it("get_origin returns compute origin", function()
        local map = make_open_map(10, 10)
        FOV.init(map)
        FOV.set_dimensions(10, 10)
        FOV.compute(3, 7)
        
        local x, y = FOV.get_origin()
        t.expect(x).to_be(3)
        t.expect(y).to_be(7)
    end)
end)

--------------------------------------------------------------------------------
-- Occlusion Tests
--------------------------------------------------------------------------------

t.describe("Descent FOV Occlusion", function()
    t.it("wall blocks vision", function()
        local map = make_open_map(10, 10)
        Map.set_tile(map, 5, 5, Map.TILE.WALL)
        
        FOV.init(map)
        FOV.set_dimensions(10, 10)
        FOV.compute(3, 5)  -- Looking east
        
        -- Wall itself might be visible
        -- But tiles behind wall should be blocked
        -- Testing tile at x=7 (behind wall at x=5)
        t.expect(FOV.is_visible(7, 5)).to_be(false)
    end)

    t.it("wall shadow extends behind obstacle", function()
        local map = make_open_map(15, 15)
        Map.set_tile(map, 8, 8, Map.TILE.WALL)
        
        FOV.init(map)
        FOV.set_dimensions(15, 15)
        FOV.compute(5, 8)  -- Looking east at wall
        
        -- Tiles in the shadow of the wall
        t.expect(FOV.is_visible(10, 8)).to_be(false)
        t.expect(FOV.is_visible(11, 8)).to_be(false)
    end)

    t.it("can see around corners", function()
        local map = make_open_map(10, 10)
        Map.set_tile(map, 5, 5, Map.TILE.WALL)
        
        FOV.init(map)
        FOV.set_dimensions(10, 10)
        FOV.compute(3, 5)
        
        -- Can see tiles not blocked by wall (different angles)
        t.expect(FOV.is_visible(5, 3)).to_be(true)
        t.expect(FOV.is_visible(5, 7)).to_be(true)
    end)
end)

--------------------------------------------------------------------------------
-- Bounds Safety Tests
--------------------------------------------------------------------------------

t.describe("Descent FOV Bounds Safety", function()
    t.it("handles origin at edge", function()
        local map = make_open_map(10, 10)
        FOV.init(map)
        FOV.set_dimensions(10, 10)
        
        -- Should not crash
        FOV.compute(1, 1)
        t.expect(FOV.is_visible(1, 1)).to_be(true)
        
        FOV.compute(10, 10)
        t.expect(FOV.is_visible(10, 10)).to_be(true)
    end)

    t.it("is_visible returns false for OOB", function()
        local map = make_open_map(10, 10)
        FOV.init(map)
        FOV.set_dimensions(10, 10)
        FOV.compute(5, 5)
        
        t.expect(FOV.is_visible(0, 5)).to_be(false)
        t.expect(FOV.is_visible(11, 5)).to_be(false)
        t.expect(FOV.is_visible(5, 0)).to_be(false)
        t.expect(FOV.is_visible(5, 11)).to_be(false)
    end)

    t.it("is_explored returns false for OOB", function()
        local map = make_open_map(10, 10)
        FOV.init(map)
        FOV.set_dimensions(10, 10)
        FOV.compute(5, 5)
        
        t.expect(FOV.is_explored(-1, 5)).to_be(false)
        t.expect(FOV.is_explored(100, 5)).to_be(false)
    end)

    t.it("handles very small map", function()
        local map = make_open_map(3, 3)
        FOV.init(map)
        FOV.set_dimensions(3, 3)
        
        FOV.compute(2, 2)
        t.expect(FOV.is_visible(2, 2)).to_be(true)
        t.expect(FOV.is_visible(1, 1)).to_be(true)
        t.expect(FOV.is_visible(3, 3)).to_be(true)
    end)
end)

--------------------------------------------------------------------------------
-- Explored Persistence Tests
--------------------------------------------------------------------------------

t.describe("Descent FOV Explored Persistence", function()
    t.it("visible tiles become explored", function()
        local map = make_open_map(10, 10)
        FOV.init(map)
        FOV.set_dimensions(10, 10)
        FOV.compute(5, 5)
        
        t.expect(FOV.is_explored(5, 5)).to_be(true)
        t.expect(FOV.is_explored(6, 5)).to_be(true)
    end)

    t.it("explored persists after moving", function()
        local map = make_open_map(20, 20)
        FOV.init(map)
        FOV.set_dimensions(20, 20)
        
        -- First position
        FOV.compute(5, 5)
        t.expect(FOV.is_explored(6, 5)).to_be(true)
        
        -- Move to new position
        FOV.compute(15, 15)
        
        -- Old position still explored
        t.expect(FOV.is_explored(5, 5)).to_be(true)
        t.expect(FOV.is_explored(6, 5)).to_be(true)
        
        -- Old position not visible anymore
        t.expect(FOV.is_visible(5, 5)).to_be(false)
    end)

    t.it("clear_explored resets explored state", function()
        local map = make_open_map(10, 10)
        FOV.init(map)
        FOV.set_dimensions(10, 10)
        FOV.compute(5, 5)
        
        t.expect(FOV.is_explored(5, 5)).to_be(true)
        
        FOV.clear_explored()
        
        t.expect(FOV.is_explored(5, 5)).to_be(false)
    end)

    t.it("save and load explored state", function()
        local map = make_open_map(10, 10)
        FOV.init(map)
        FOV.set_dimensions(10, 10)
        FOV.compute(5, 5)
        
        local saved = FOV.save_explored()
        
        FOV.clear_explored()
        t.expect(FOV.is_explored(5, 5)).to_be(false)
        
        FOV.load_explored(saved)
        t.expect(FOV.is_explored(5, 5)).to_be(true)
    end)
end)

--------------------------------------------------------------------------------
-- Visibility State Tests
--------------------------------------------------------------------------------

t.describe("Descent FOV Visibility State", function()
    t.it("get_visibility returns correct state", function()
        local map = make_open_map(20, 20)
        FOV.init(map)
        FOV.set_dimensions(20, 20)
        
        -- Compute at one position
        FOV.compute(5, 5)
        
        -- Move to new position
        FOV.compute(15, 15)
        
        -- Current position is visible
        t.expect(FOV.get_visibility(15, 15)).to_be("visible")
        
        -- Old position is explored but not visible
        t.expect(FOV.get_visibility(5, 5)).to_be("explored")
        
        -- Far corner never seen
        t.expect(FOV.get_visibility(1, 1)).to_be("unknown")
    end)

    t.it("mark_explored manually marks tile", function()
        local map = make_open_map(10, 10)
        FOV.init(map)
        FOV.set_dimensions(10, 10)
        
        t.expect(FOV.is_explored(8, 8)).to_be(false)
        
        FOV.mark_explored(8, 8)
        
        t.expect(FOV.is_explored(8, 8)).to_be(true)
    end)

    t.it("get_visible_tiles returns array", function()
        local map = make_open_map(10, 10)
        FOV.init(map)
        FOV.set_dimensions(10, 10)
        FOV.compute(5, 5)
        
        local tiles = FOV.get_visible_tiles()
        t.expect(type(tiles)).to_be("table")
        t.expect(#tiles).to_be_greater_than(0)
        
        -- Origin should be in visible tiles
        local found_origin = false
        for _, tile in ipairs(tiles) do
            if tile.x == 5 and tile.y == 5 then
                found_origin = true
                break
            end
        end
        t.expect(found_origin).to_be(true)
    end)
end)
