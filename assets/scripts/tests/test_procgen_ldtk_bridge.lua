-- assets/scripts/tests/test_procgen_ldtk_bridge.lua
-- TDD: Tests written FIRST, before implementation
-- Note: Tests for gridToIntGrid are standalone; applyRules/buildColliders require engine

local t = require("tests.test_runner")
t.reset()

local ldtk_bridge = require("core.procgen.ldtk_bridge")
local vendor = require("core.procgen.vendor")

t.describe("procgen.ldtk_bridge", function()

    t.describe("gridToIntGrid", function()
        t.it("converts Grid to LDtk IntGrid table format", function()
            local Grid = vendor.Grid
            local grid = Grid(3, 2, 0)
            grid:set(1, 1, 1)
            grid:set(2, 1, 2)
            grid:set(3, 1, 3)
            grid:set(1, 2, 4)
            grid:set(2, 2, 5)
            grid:set(3, 2, 6)

            local intGrid = ldtk_bridge.gridToIntGrid(grid)

            t.expect(intGrid.width).to_be(3)
            t.expect(intGrid.height).to_be(2)
            t.expect(type(intGrid.cells)).to_be("table")
            -- Grid uses row-major: w*(j-1) + i
            -- So for 3x2 grid: [1,2,3,4,5,6]
            t.expect(intGrid.cells[1]).to_be(1)
            t.expect(intGrid.cells[2]).to_be(2)
            t.expect(intGrid.cells[3]).to_be(3)
            t.expect(intGrid.cells[4]).to_be(4)
            t.expect(intGrid.cells[5]).to_be(5)
            t.expect(intGrid.cells[6]).to_be(6)
        end)

        t.it("handles grid with default fill value", function()
            local Grid = vendor.Grid
            local grid = Grid(2, 2, 99)

            local intGrid = ldtk_bridge.gridToIntGrid(grid)

            t.expect(intGrid.width).to_be(2)
            t.expect(intGrid.height).to_be(2)
            t.expect(intGrid.cells[1]).to_be(99)
            t.expect(intGrid.cells[2]).to_be(99)
            t.expect(intGrid.cells[3]).to_be(99)
            t.expect(intGrid.cells[4]).to_be(99)
        end)

        t.it("preserves grid dimensions", function()
            local Grid = vendor.Grid
            local grid = Grid(10, 5, 0)

            local intGrid = ldtk_bridge.gridToIntGrid(grid)

            t.expect(intGrid.width).to_be(10)
            t.expect(intGrid.height).to_be(5)
            t.expect(#intGrid.cells).to_be(50)
        end)
    end)

    t.describe("applyRules (engine-only)", function()
        t.it("requires _G.ldtk binding", function()
            -- This test verifies the function exists and handles missing ldtk gracefully
            local Grid = vendor.Grid
            local grid = Grid(5, 5, 0)

            -- Without engine, ldtk should not be available
            if not _G.ldtk then
                local success, err = pcall(function()
                    ldtk_bridge.applyRules(grid, "TestLayer")
                end)
                t.expect(success).to_be(false)
                t.expect(err).to_contain("ldtk")
            else
                -- Engine is available, should work
                local result = ldtk_bridge.applyRules(grid, "TestLayer")
                t.expect(result).to_be_truthy()
            end
        end)
    end)

    t.describe("buildColliders (engine-only)", function()
        t.it("requires _G.ldtk binding", function()
            local Grid = vendor.Grid
            local grid = Grid(5, 5, 1)

            if not _G.ldtk then
                local success, err = pcall(function()
                    ldtk_bridge.buildColliders(grid, {})
                end)
                t.expect(success).to_be(false)
                t.expect(err).to_contain("ldtk")
            else
                -- Engine is available
                local success = pcall(function()
                    ldtk_bridge.buildColliders(grid, {
                        worldName = "test",
                        physicsTag = "TEST",
                        solidValues = {1}
                    })
                end)
                t.expect(success).to_be_truthy()
            end
        end)
    end)

    t.describe("cleanup", function()
        t.it("calls ldtk.cleanup_procedural if available", function()
            -- Should not error even without ldtk
            local success = pcall(function()
                ldtk_bridge.cleanup()
            end)
            t.expect(success).to_be(true)
        end)
    end)

end)

return t.run()
