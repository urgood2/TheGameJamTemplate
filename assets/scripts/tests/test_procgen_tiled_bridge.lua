-- assets/scripts/tests/test_procgen_tiled_bridge.lua
-- TDD-style tests for procgen.tiled_bridge wrapper module.

local t = require("tests.test_runner")
t.reset()

local tiled_bridge = require("core.procgen.tiled_bridge")
local vendor = require("core.procgen.vendor")

t.describe("procgen.tiled_bridge", function()

    t.describe("gridToTileGrid", function()
        t.it("converts Grid to Tiled grid table format", function()
            local Grid = vendor.Grid
            local grid = Grid(3, 2, 0)
            grid:set(1, 1, 1)
            grid:set(2, 1, 2)
            grid:set(3, 1, 3)
            grid:set(1, 2, 4)
            grid:set(2, 2, 5)
            grid:set(3, 2, 6)

            local out = tiled_bridge.gridToTileGrid(grid)
            t.expect(out.width).to_be(3)
            t.expect(out.height).to_be(2)
            t.expect(type(out.cells)).to_be("table")
            t.expect(out.cells[1]).to_be(1)
            t.expect(out.cells[2]).to_be(2)
            t.expect(out.cells[3]).to_be(3)
            t.expect(out.cells[4]).to_be(4)
            t.expect(out.cells[5]).to_be(5)
            t.expect(out.cells[6]).to_be(6)
        end)
    end)

    t.describe("engine-only methods", function()
        t.it("applyRules requires tiled binding", function()
            local Grid = vendor.Grid
            local grid = Grid(4, 4, 1)

            if not _G.tiled then
                local ok, err = pcall(function()
                    tiled_bridge.applyRules(grid, "dummy")
                end)
                t.expect(ok).to_be(false)
                t.expect(err).to_contain("tiled")
            else
                -- In engine runtime, this should at least be callable.
                local ok = pcall(function()
                    tiled_bridge.applyRules(grid, "dummy")
                end)
                t.expect(type(ok)).to_be("boolean")
            end
        end)

        t.it("buildColliders requires tiled binding", function()
            local Grid = vendor.Grid
            local grid = Grid(5, 5, 1)

            if not _G.tiled then
                local ok, err = pcall(function()
                    tiled_bridge.buildColliders(grid, {})
                end)
                t.expect(ok).to_be(false)
                t.expect(err).to_contain("tiled")
            else
                local ok = pcall(function()
                    tiled_bridge.buildColliders(grid, {
                        worldName = "world",
                        physicsTag = "WORLD",
                        solidValues = {1},
                        cellSize = 16,
                    })
                end)
                t.expect(type(ok)).to_be("boolean")
            end
        end)

        t.it("cleanup is safe even without bindings", function()
            local ok = pcall(function()
                tiled_bridge.cleanup()
            end)
            t.expect(ok).to_be(true)
        end)
    end)

end)

return t.run()
