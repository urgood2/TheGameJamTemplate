-- assets/scripts/tests/test_procgen_spawner.lua
-- TDD: Tests written FIRST for Phase 3 Spawner module

local t = require("tests.test_runner")
t.reset()

local procgen = require("core.procgen")

t.describe("spawner module", function()
    local spawner = require("core.procgen.spawner")

    t.describe("spawnAtPattern()", function()
        t.it("calls spawnFn for each cell in pattern", function()
            local builder = procgen.pattern()
            builder._pattern = procgen.forma.pattern.new()
            builder._pattern:insert(0, 0)
            builder._pattern:insert(1, 0)
            builder._pattern:insert(0, 1)
            local pattern = builder:build()

            local spawned = {}
            local entities = spawner.spawnAtPattern(pattern, function(wx, wy, gx, gy, cell)
                table.insert(spawned, {wx = wx, wy = wy, gx = gx, gy = gy})
                return {id = #spawned}  -- Mock entity
            end, {tileSize = 16})

            t.expect(#spawned).to_be(3)
            t.expect(#entities).to_be(3)
        end)

        t.it("converts pattern 0-indexed to grid 1-indexed", function()
            local builder = procgen.pattern()
            builder._pattern = procgen.forma.pattern.new()
            builder._pattern:insert(0, 0)  -- Pattern (0,0) -> Grid (1,1)
            local pattern = builder:build()

            local captured = {}
            spawner.spawnAtPattern(pattern, function(wx, wy, gx, gy)
                captured.gx = gx
                captured.gy = gy
                return {id = 1}
            end)

            t.expect(captured.gx).to_be(1)
            t.expect(captured.gy).to_be(1)
        end)

        t.it("uses custom offsetGX/offsetGY", function()
            local builder = procgen.pattern()
            builder._pattern = procgen.forma.pattern.new()
            builder._pattern:insert(0, 0)
            local pattern = builder:build()

            local captured = {}
            spawner.spawnAtPattern(pattern, function(wx, wy, gx, gy)
                captured.gx = gx
                captured.gy = gy
                return {id = 1}
            end, {offsetGX = 5, offsetGY = 10})

            t.expect(captured.gx).to_be(5)
            t.expect(captured.gy).to_be(10)
        end)

        t.it("calculates world coordinates from grid", function()
            local builder = procgen.pattern()
            builder._pattern = procgen.forma.pattern.new()
            builder._pattern:insert(0, 0)
            local pattern = builder:build()

            local captured = {}
            spawner.spawnAtPattern(pattern, function(wx, wy, gx, gy)
                captured.wx = wx
                captured.wy = wy
                return {id = 1}
            end, {tileSize = 16})

            -- Grid (1,1) -> World (0 + 8, 0 + 8) = (8, 8) center of tile
            t.expect(captured.wx).to_be(8)
            t.expect(captured.wy).to_be(8)
        end)

        t.it("excludes nil returns from spawnFn", function()
            local builder = procgen.pattern()
            builder._pattern = procgen.forma.pattern.new()
            builder._pattern:insert(0, 0)
            builder._pattern:insert(1, 0)
            local pattern = builder:build()

            local count = 0
            local entities = spawner.spawnAtPattern(pattern, function(wx, wy, gx, gy)
                count = count + 1
                if count == 1 then return nil end  -- Skip first
                return {id = count}
            end)

            t.expect(#entities).to_be(1)  -- Only second entity
        end)

        t.it("returns empty array for empty pattern", function()
            local pattern = procgen.forma.pattern.new()
            local entities = spawner.spawnAtPattern(pattern, function()
                return {id = 1}
            end)

            t.expect(#entities).to_be(0)
        end)
    end)

    t.describe("spawnAtGridValue()", function()
        t.it("calls spawnFn for cells matching value", function()
            local grid = procgen.Grid(5, 5, 0)
            grid:set(2, 2, 1)
            grid:set(3, 3, 1)
            grid:set(4, 4, 2)  -- Different value

            local spawned = {}
            local entities = spawner.spawnAtGridValue(grid, 1, function(wx, wy, gx, gy)
                table.insert(spawned, {gx = gx, gy = gy})
                return {id = #spawned}
            end, {tileSize = 16})

            t.expect(#spawned).to_be(2)
            t.expect(#entities).to_be(2)
        end)

        t.it("calculates correct world coordinates", function()
            local grid = procgen.Grid(5, 5, 0)
            grid:set(1, 1, 1)

            local captured = {}
            spawner.spawnAtGridValue(grid, 1, function(wx, wy, gx, gy)
                captured.wx = wx
                captured.wy = wy
                captured.gx = gx
                captured.gy = gy
                return {id = 1}
            end, {tileSize = 16})

            t.expect(captured.gx).to_be(1)
            t.expect(captured.gy).to_be(1)
            -- Grid (1,1) -> World (8, 8) center
            t.expect(captured.wx).to_be(8)
            t.expect(captured.wy).to_be(8)
        end)

        t.it("excludes nil returns from spawnFn", function()
            local grid = procgen.Grid(3, 3, 1)  -- All cells = 1

            local count = 0
            local entities = spawner.spawnAtGridValue(grid, 1, function(wx, wy, gx, gy)
                count = count + 1
                if count <= 5 then return nil end  -- Skip first 5
                return {id = count}
            end)

            t.expect(#entities).to_be(4)  -- 9 cells - 5 skipped = 4
        end)

        t.it("returns empty array when no cells match", function()
            local grid = procgen.Grid(5, 5, 0)

            local entities = spawner.spawnAtGridValue(grid, 99, function()
                return {id = 1}
            end)

            t.expect(#entities).to_be(0)
        end)
    end)

    t.describe("spawnPoisson()", function()
        t.it("spawns with Poisson-disc distribution", function()
            math.randomseed(12345)
            local pattern = procgen.pattern()
                :square(20, 20)
                :build()

            local spawned = {}
            local entities = spawner.spawnPoisson(pattern, 3, function(wx, wy, gx, gy)
                table.insert(spawned, {gx = gx, gy = gy})
                return {id = #spawned}
            end, {tileSize = 16})

            -- Poisson sampling should produce fewer entities than total cells
            t.expect(#spawned > 0).to_be(true)
            t.expect(#spawned < 400).to_be(true)  -- 20*20 = 400
        end)

        t.it("respects minimum distance between spawns", function()
            math.randomseed(12345)
            local pattern = procgen.pattern()
                :square(20, 20)
                :build()

            local positions = {}
            spawner.spawnPoisson(pattern, 4, function(wx, wy, gx, gy)
                table.insert(positions, {x = gx, y = gy})
                return {id = #positions}
            end)

            -- Verify minimum distance (approximate due to Poisson algorithm)
            -- Note: May not be exact due to grid snapping, but should be close
            for i = 1, #positions do
                for j = i + 1, #positions do
                    local dx = positions[i].x - positions[j].x
                    local dy = positions[i].y - positions[j].y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    -- Allow some tolerance due to sampling algorithm
                    t.expect(dist >= 2).to_be(true)
                end
            end
        end)
    end)
end)

return t.run()
