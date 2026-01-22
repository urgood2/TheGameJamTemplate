-- assets/scripts/tests/test_procgen_influence.lua
-- TDD: Tests written FIRST for Phase 3 Influence module

local t = require("tests.test_runner")
t.reset()

local procgen = require("core.procgen")

t.describe("influence module", function()
    local influence = require("core.procgen.influence")

    t.describe("spreadFromPoint()", function()
        t.it("sets strength at center point", function()
            local grid = procgen.Grid(10, 10, 0)
            influence.spreadFromPoint(grid, 5, 5, 10, 0.5, 5)

            t.expect(grid:get(5, 5)).to_be(10)
        end)

        t.it("spreads with falloff to neighbors", function()
            local grid = procgen.Grid(10, 10, 0)
            influence.spreadFromPoint(grid, 5, 5, 10, 0.5, 5)

            -- Adjacent cells should have falloff applied
            local adjacent = grid:get(5, 6)
            t.expect(adjacent > 0).to_be(true)
            t.expect(adjacent < 10).to_be(true)
            t.expect(adjacent).to_be(5)  -- 10 * 0.5
        end)

        t.it("stops spreading at maxDist", function()
            local grid = procgen.Grid(20, 20, 0)
            influence.spreadFromPoint(grid, 10, 10, 10, 0.9, 2)

            -- Within range
            t.expect(grid:get(10, 10) > 0).to_be(true)
            t.expect(grid:get(11, 10) > 0).to_be(true)
            t.expect(grid:get(12, 10) > 0).to_be(true)

            -- Beyond maxDist of 2
            t.expect(grid:get(13, 10)).to_be(0)
        end)

        t.it("accumulates strength from multiple sources", function()
            local grid = procgen.Grid(10, 10, 0)
            influence.spreadFromPoint(grid, 5, 5, 10, 0.5, 3)
            influence.spreadFromPoint(grid, 5, 5, 5, 0.5, 3)

            -- Should accumulate: 10 + 5 = 15
            t.expect(grid:get(5, 5)).to_be(15)
        end)

        t.it("respects grid boundaries", function()
            local grid = procgen.Grid(5, 5, 0)
            -- Spread from corner - should not error
            influence.spreadFromPoint(grid, 1, 1, 10, 0.8, 10)

            t.expect(grid:get(1, 1)).to_be(10)
            -- Shouldn't crash or access out of bounds
        end)

        t.it("stops when strength falls below threshold", function()
            local grid = procgen.Grid(20, 20, 0)
            influence.spreadFromPoint(grid, 10, 10, 1, 0.1, 100)

            -- After just a few steps, strength should fall below 0.01
            -- Far cells should remain 0
            t.expect(grid:get(15, 10)).to_be(0)
        end)
    end)

    t.describe("fromEntities()", function()
        t.it("creates influence map from entity positions", function()
            local entities = {
                {x = 80, y = 80},   -- World coords
                {x = 160, y = 160}
            }

            local grid = influence.fromEntities(20, 20, entities, {
                tileSize = 16,
                falloff = 0.5,
                maxDistance = 3
            })

            t.expect(grid.w).to_be(20)
            t.expect(grid.h).to_be(20)
            -- Entity at (80,80) -> grid (5,5) with default tile size 16
            -- Actually (80/16)+1 = 6 for 1-indexed
            t.expect(grid:get(6, 6) > 0).to_be(true)
        end)

        t.it("uses default falloff and maxDistance", function()
            local entities = {{x = 80, y = 80}}
            local grid = influence.fromEntities(20, 20, entities)

            -- Should not error with defaults
            t.expect(grid:get(6, 6) > 0).to_be(true)
        end)

        t.it("uses custom getStrength function", function()
            local entities = {
                {x = 80, y = 80, danger = 5},
                {x = 160, y = 160, danger = 20}
            }

            local grid = influence.fromEntities(20, 20, entities, {
                getStrength = function(e) return e.danger end,
                falloff = 0.5,
                maxDistance = 2
            })

            -- Entity with danger=20 should have higher influence
            local pos1 = grid:get(6, 6)   -- danger=5 entity
            local pos2 = grid:get(11, 11) -- danger=20 entity

            t.expect(pos2 > pos1).to_be(true)
        end)

        t.it("handles empty entities array", function()
            local grid = influence.fromEntities(10, 10, {})

            -- All cells should be 0
            local total = 0
            grid:apply(function(g, x, y)
                total = total + g:get(x, y)
            end)
            t.expect(total).to_be(0)
        end)
    end)

    t.describe("findBest()", function()
        t.it("finds minimum value position", function()
            local grid = procgen.Grid(5, 5, 10)
            grid:set(2, 3, 0)  -- Minimum at (2,3)

            local x, y, val = influence.findBest(grid, "min")
            t.expect(x).to_be(2)
            t.expect(y).to_be(3)
            t.expect(val).to_be(0)
        end)

        t.it("finds maximum value position", function()
            local grid = procgen.Grid(5, 5, 0)
            grid:set(4, 4, 100)  -- Maximum at (4,4)

            local x, y, val = influence.findBest(grid, "max")
            t.expect(x).to_be(4)
            t.expect(y).to_be(4)
            t.expect(val).to_be(100)
        end)

        t.it("returns first match when multiple equal values", function()
            local grid = procgen.Grid(3, 3, 5)
            -- All cells are 5, should return a valid position

            local x, y, val = influence.findBest(grid, "min")
            t.expect(x >= 1 and x <= 3).to_be(true)
            t.expect(y >= 1 and y <= 3).to_be(true)
            t.expect(val).to_be(5)
        end)

        t.it("handles negative values", function()
            local grid = procgen.Grid(5, 5, 0)
            grid:set(1, 1, -50)
            grid:set(3, 3, 50)

            local minX, minY, minVal = influence.findBest(grid, "min")
            t.expect(minVal).to_be(-50)

            local maxX, maxY, maxVal = influence.findBest(grid, "max")
            t.expect(maxVal).to_be(50)
        end)
    end)

    t.describe("integration: danger map scenario", function()
        t.it("creates danger map and finds safe position", function()
            -- Simulate enemies creating a danger field
            local enemies = {
                {x = 160, y = 160}  -- Enemy at center-ish
            }

            local dangerMap = influence.fromEntities(20, 20, enemies, {
                falloff = 0.7,
                maxDistance = 8
            })

            -- Find safest position (minimum danger)
            local safeX, safeY, danger = influence.findBest(dangerMap, "min")

            -- Safe position should be far from enemy at (11,11)
            local dx = safeX - 11
            local dy = safeY - 11
            local dist = math.sqrt(dx * dx + dy * dy)
            t.expect(dist > 5).to_be(true)  -- Should be far from enemy
            t.expect(danger).to_be(0)  -- Should have zero danger
        end)
    end)
end)

return t.run()
