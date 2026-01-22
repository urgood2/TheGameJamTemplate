--[[
================================================================================
TEST: Procedural Generation DSL - Layout
================================================================================
Tests for the procgen layout system for level generation definitions.

Note: This provides the DSL framework. Actual dungeon generation algorithms
(BSP, maze carving, etc.) would be implemented separately using these definitions.

TDD Approach:
- RED: Tests fail before implementation
- GREEN: Implement, tests pass

Run with: lua assets/scripts/tests/test_procgen_layout.lua
]]

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

-- Clear cached module
package.loaded["core.procgen"] = nil
_G.procgen = nil

local t = require("tests.test_runner")

--------------------------------------------------------------------------------
-- Tests: layout API existence
--------------------------------------------------------------------------------

t.describe("procgen.layout - API", function()

    t.it("has layout function", function()
        local procgen = require("core.procgen")
        t.expect(type(procgen.layout)).to_be("function")
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Basic layout definition
--------------------------------------------------------------------------------

t.describe("procgen.layout - Basic definition", function()

    t.it("creates a layout object from definition", function()
        local procgen = require("core.procgen")

        local layout = procgen.layout {
            type = "rooms_and_corridors",
            rooms = {
                count = procgen.range(5, 10),
                size = { min = {4, 4}, max = {8, 8} }
            }
        }

        t.expect(layout).to_be_truthy()
        t.expect(layout.type).to_be("rooms_and_corridors")
    end)

    t.it("stores rooms configuration", function()
        local procgen = require("core.procgen")

        local layout = procgen.layout {
            type = "dungeon",
            rooms = {
                count = procgen.range(5, 10),
                size = { min = {4, 4}, max = {8, 8} },
                types = {
                    { type = "combat", weight = 50 },
                    { type = "treasure", weight = 20 },
                    { type = "boss", weight = 5, max = 1 }
                }
            }
        }

        t.expect(layout.rooms).to_be_truthy()
        t.expect(layout.rooms.types).to_be_truthy()
        t.expect(#layout.rooms.types).to_be(3)
    end)

    t.it("stores corridors configuration", function()
        local procgen = require("core.procgen")

        local layout = procgen.layout {
            type = "dungeon",
            rooms = { count = 5 },
            corridors = {
                width = 2,
                style = "straight"
            }
        }

        t.expect(layout.corridors).to_be_truthy()
        t.expect(layout.corridors.width).to_be(2)
        t.expect(layout.corridors.style).to_be("straight")
    end)

    t.it("stores constraints", function()
        local procgen = require("core.procgen")

        local layout = procgen.layout {
            type = "dungeon",
            rooms = { count = 5 },
            constraints = {
                "boss room must be furthest from start",
                "treasure rooms need adjacent combat rooms"
            }
        }

        t.expect(layout.constraints).to_be_truthy()
        t.expect(#layout.constraints).to_be(2)
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Layout configuration resolution
--------------------------------------------------------------------------------

t.describe("procgen.layout - Configuration resolution", function()

    t.it("can resolve room count from range", function()
        local procgen = require("core.procgen")

        local layout = procgen.layout {
            type = "dungeon",
            rooms = {
                count = procgen.range(5, 10)
            }
        }

        local rng = procgen.create_rng(42)
        local config = layout:resolve({ rng = rng })

        t.expect(config.rooms).to_be_truthy()
        t.expect(config.rooms.count >= 5).to_be(true)
        t.expect(config.rooms.count <= 10).to_be(true)
    end)

    t.it("resolves to same values with same seed", function()
        local procgen = require("core.procgen")

        local layout = procgen.layout {
            type = "dungeon",
            rooms = {
                count = procgen.range(1, 100)
            }
        }

        local rng1 = procgen.create_rng(123)
        local rng2 = procgen.create_rng(123)

        local config1 = layout:resolve({ rng = rng1 })
        local config2 = layout:resolve({ rng = rng2 })

        t.expect(config1.rooms.count).to_be(config2.rooms.count)
    end)

    t.it("keeps fixed values unchanged", function()
        local procgen = require("core.procgen")

        local layout = procgen.layout {
            type = "dungeon",
            rooms = {
                count = 7
            },
            corridors = {
                width = 2
            }
        }

        local rng = procgen.create_rng(1)
        local config = layout:resolve({ rng = rng })

        t.expect(config.rooms.count).to_be(7)
        t.expect(config.corridors.width).to_be(2)
    end)
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

local success = t.run()
os.exit(success and 0 or 1)
