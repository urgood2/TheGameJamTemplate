-- assets/scripts/tests/test_descent_targeting.lua
--[[
================================================================================
DESCENT TARGETING UI TESTS
================================================================================
Validates targeting range, target filtering, and cancel behavior.
]]

local t = require("tests.test_runner")
local Targeting = require("descent.ui.targeting")
local Map = require("descent.map")

local function count_entries(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

t.describe("Descent Targeting UI", function()
    t.it("computes range and valid tiles in tile mode", function()
        local map = Map.new(5, 5, { default_tile = Map.TILE.FLOOR })
        Targeting.open({
            map = map,
            origin = { x = 3, y = 3 },
            range = 1,
            mode = "tile",
        })

        local range = Targeting.get_range_tiles()
        t.expect(#range).to_be(9)

        local valid = Targeting.get_valid_tiles()
        t.expect(count_entries(valid)).to_be(9)

        Targeting.close()
    end)

    t.it("filters entity targets by range", function()
        local map = Map.new(7, 7, { default_tile = Map.TILE.FLOOR })
        local targets = {
            { id = 1, x = 4, y = 3 },
            { id = 2, x = 5, y = 5 },
            { id = 3, x = 7, y = 7 },
        }

        Targeting.open({
            map = map,
            origin = { x = 3, y = 3 },
            range = 2,
            mode = "entity",
            targets = targets,
        })

        local list = Targeting.get_targets()
        t.expect(#list).to_be(2)

        Targeting.close()
    end)

    t.it("cancel exits targeting", function()
        local map = Map.new(3, 3, { default_tile = Map.TILE.FLOOR })
        Targeting.open({
            map = map,
            origin = { x = 2, y = 2 },
            range = 1,
        })

        local consumed, action = Targeting.handle_input("Escape")
        t.expect(consumed).to_be(true)
        t.expect(action).to_be("cancel")
        t.expect(Targeting.is_active()).to_be(false)
    end)
end)

