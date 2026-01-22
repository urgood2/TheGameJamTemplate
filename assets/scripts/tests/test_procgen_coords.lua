-- assets/scripts/tests/test_procgen_coords.lua
-- TDD: Tests written FIRST, before implementation

local t = require("tests.test_runner")
t.reset()

-- This will fail until coords.lua is implemented
local coords = require("core.procgen.coords")

t.describe("procgen.coords", function()

    t.describe("worldToGrid", function()
        t.it("returns 1-indexed coords for origin (0,0)", function()
            local gx, gy = coords.worldToGrid(0, 0, 16)
            t.expect(gx).to_be(1)
            t.expect(gy).to_be(1)
        end)

        t.it("converts world position inside first tile to grid (1,1)", function()
            local gx, gy = coords.worldToGrid(8, 8, 16)
            t.expect(gx).to_be(1)
            t.expect(gy).to_be(1)
        end)

        t.it("converts world position at tile boundary to next tile", function()
            local gx, gy = coords.worldToGrid(16, 16, 16)
            t.expect(gx).to_be(2)
            t.expect(gy).to_be(2)
        end)

        t.it("handles negative world coordinates", function()
            local gx, gy = coords.worldToGrid(-8, -8, 16)
            t.expect(gx).to_be(0)
            t.expect(gy).to_be(0)
        end)

        t.it("uses default tile size from coords.TILE_SIZE", function()
            local originalTileSize = coords.TILE_SIZE
            coords.TILE_SIZE = 16
            local gx, gy = coords.worldToGrid(32, 48)
            t.expect(gx).to_be(3)
            t.expect(gy).to_be(4)
            coords.TILE_SIZE = originalTileSize
        end)

        t.it("respects custom origin offset", function()
            local originalOriginX = coords.ORIGIN_X
            local originalOriginY = coords.ORIGIN_Y
            coords.ORIGIN_X = 100
            coords.ORIGIN_Y = 100
            local gx, gy = coords.worldToGrid(100, 100, 16)
            t.expect(gx).to_be(1)
            t.expect(gy).to_be(1)
            -- Restore
            coords.ORIGIN_X = originalOriginX
            coords.ORIGIN_Y = originalOriginY
        end)
    end)

    t.describe("gridToWorld", function()
        t.it("returns cell center for grid (1,1)", function()
            local wx, wy = coords.gridToWorld(1, 1, 16)
            t.expect(wx).to_be(8)
            t.expect(wy).to_be(8)
        end)

        t.it("returns cell center for grid (2,3)", function()
            local wx, wy = coords.gridToWorld(2, 3, 16)
            -- (2-1)*16 + 0 + 8 = 24
            -- (3-1)*16 + 0 + 8 = 40
            t.expect(wx).to_be(24)
            t.expect(wy).to_be(40)
        end)

        t.it("uses default tile size from coords.TILE_SIZE", function()
            local originalTileSize = coords.TILE_SIZE
            coords.TILE_SIZE = 16
            local wx, wy = coords.gridToWorld(3, 4)
            t.expect(wx).to_be(40)  -- (3-1)*16 + 8 = 40
            t.expect(wy).to_be(56)  -- (4-1)*16 + 8 = 56
            coords.TILE_SIZE = originalTileSize
        end)

        t.it("respects custom origin offset", function()
            local originalOriginX = coords.ORIGIN_X
            local originalOriginY = coords.ORIGIN_Y
            coords.ORIGIN_X = 100
            coords.ORIGIN_Y = 200
            local wx, wy = coords.gridToWorld(1, 1, 16)
            t.expect(wx).to_be(108)  -- 100 + 8
            t.expect(wy).to_be(208)  -- 200 + 8
            -- Restore
            coords.ORIGIN_X = originalOriginX
            coords.ORIGIN_Y = originalOriginY
        end)
    end)

    t.describe("gridToWorldRect", function()
        t.it("returns rectangle with top-left corner and size", function()
            local rect = coords.gridToWorldRect(1, 1, 16)
            t.expect(rect.x).to_be(0)
            t.expect(rect.y).to_be(0)
            t.expect(rect.w).to_be(16)
            t.expect(rect.h).to_be(16)
        end)

        t.it("calculates correct rect for grid (3, 2)", function()
            local rect = coords.gridToWorldRect(3, 2, 16)
            t.expect(rect.x).to_be(32)  -- (3-1)*16
            t.expect(rect.y).to_be(16)  -- (2-1)*16
            t.expect(rect.w).to_be(16)
            t.expect(rect.h).to_be(16)
        end)
    end)

    t.describe("roundtrip conversions", function()
        t.it("worldToGrid -> gridToWorld returns cell center", function()
            local wx, wy = 25, 37  -- Arbitrary world position
            local gx, gy = coords.worldToGrid(wx, wy, 16)
            local cx, cy = coords.gridToWorld(gx, gy, 16)
            -- Should return center of the cell containing (25, 37)
            -- gx = floor(25/16) + 1 = 2, gy = floor(37/16) + 1 = 3
            t.expect(gx).to_be(2)
            t.expect(gy).to_be(3)
            t.expect(cx).to_be(24)  -- (2-1)*16 + 8
            t.expect(cy).to_be(40)  -- (3-1)*16 + 8
        end)
    end)

end)

t.describe("procgen.coords pattern/grid conversion", function()

    t.describe("patternToGrid", function()
        t.it("converts 0-indexed pattern cells to 1-indexed grid", function()
            -- This test requires vendor.lua to be working
            local vendor = require("core.procgen.vendor")
            local Grid = vendor.Grid
            local forma = vendor.forma

            local grid = Grid(10, 10, 0)
            local pattern = forma.pattern.new()
            -- Add cells at pattern coords (0,0), (1,1), (2,2)
            pattern:insert(0, 0)
            pattern:insert(1, 1)
            pattern:insert(2, 2)

            coords.patternToGrid(pattern, grid, 1)

            -- Pattern (0,0) -> Grid (1,1)
            t.expect(grid:get(1, 1)).to_be(1)
            -- Pattern (1,1) -> Grid (2,2)
            t.expect(grid:get(2, 2)).to_be(1)
            -- Pattern (2,2) -> Grid (3,3)
            t.expect(grid:get(3, 3)).to_be(1)
            -- Other cells should remain 0
            t.expect(grid:get(5, 5)).to_be(0)
        end)

        t.it("supports custom offset", function()
            local vendor = require("core.procgen.vendor")
            local Grid = vendor.Grid
            local forma = vendor.forma

            local grid = Grid(10, 10, 0)
            local pattern = forma.pattern.new()
            pattern:insert(0, 0)

            coords.patternToGrid(pattern, grid, 1, 5, 5)

            -- Pattern (0,0) with offset (5,5) -> Grid (5,5)
            t.expect(grid:get(5, 5)).to_be(1)
            t.expect(grid:get(1, 1)).to_be(0)
        end)

        t.it("handles empty pattern gracefully", function()
            local vendor = require("core.procgen.vendor")
            local Grid = vendor.Grid
            local forma = vendor.forma

            local grid = Grid(5, 5, 0)
            local emptyPattern = forma.pattern.new()

            -- Should not error with empty pattern
            local result = coords.patternToGrid(emptyPattern, grid, 1)

            t.expect(result).to_be(grid)
            -- Grid should remain unchanged
            t.expect(grid:get(1, 1)).to_be(0)
            t.expect(grid:get(3, 3)).to_be(0)
        end)
    end)

    t.describe("gridToPattern", function()
        t.it("converts 1-indexed grid cells to 0-indexed pattern", function()
            local vendor = require("core.procgen.vendor")
            local Grid = vendor.Grid

            local grid = Grid(10, 10, 0)
            grid:set(1, 1, 1)
            grid:set(2, 2, 1)
            grid:set(3, 3, 1)

            local pattern = coords.gridToPattern(grid, 1)

            -- Grid (1,1) -> Pattern (0,0)
            t.expect(pattern:has_cell(0, 0)).to_be_truthy()
            -- Grid (2,2) -> Pattern (1,1)
            t.expect(pattern:has_cell(1, 1)).to_be_truthy()
            -- Grid (3,3) -> Pattern (2,2)
            t.expect(pattern:has_cell(2, 2)).to_be_truthy()
            -- Cell not set should not be in pattern
            t.expect(pattern:has_cell(4, 4)).to_be_falsy()
        end)
    end)

end)

return t.run()
