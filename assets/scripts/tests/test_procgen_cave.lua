-- assets/scripts/tests/test_procgen_cave.lua
-- TDD: Tests for Phase 4 cave preset

local t = require("tests.test_runner")
t.reset()

local procgen = require("core.procgen")

t.describe("cave preset", function()
    local cave = require("core.procgen.presets.cave")

    t.describe("generate()", function()
        t.it("returns result with grid and pattern", function()
            math.randomseed(12345)
            local result = cave.generate(40, 30)

            t.expect(result.grid).to_be_truthy()
            t.expect(result.pattern).to_be_truthy()
        end)

        t.it("generates grid with correct dimensions", function()
            math.randomseed(12345)
            local result = cave.generate(50, 40)

            t.expect(result.grid.w).to_be(50)
            t.expect(result.grid.h).to_be(40)
        end)

        t.it("creates floor and wall cells", function()
            math.randomseed(12345)
            local result = cave.generate(40, 30)

            local hasFloor, hasWall = false, false
            result.grid:apply(function(g, x, y)
                local val = g:get(x, y)
                if val == 0 then hasFloor = true end
                if val == 1 then hasWall = true end
            end)

            t.expect(hasFloor).to_be(true)
            t.expect(hasWall).to_be(true)
        end)

        t.it("respects seed for reproducibility", function()
            local result1 = cave.generate(30, 30, {seed = 99999})
            local result2 = cave.generate(30, 30, {seed = 99999})

            -- Sample some positions
            t.expect(result1.grid:get(10, 10)).to_be(result2.grid:get(10, 10))
            t.expect(result1.grid:get(15, 15)).to_be(result2.grid:get(15, 15))
            t.expect(result1.grid:get(20, 20)).to_be(result2.grid:get(20, 20))
        end)

        t.it("uses custom fill density", function()
            math.randomseed(12345)
            -- Test with 0 iterations to verify density parameter directly
            -- (CA rules can eliminate cells, obscuring the density test)
            local sparse = cave.generate(30, 30, {fillDensity = 0.3, iterations = 0, keepLargest = false})
            local dense = cave.generate(30, 30, {fillDensity = 0.7, iterations = 0, keepLargest = false})

            -- Count floor cells
            local sparseFloor, denseFloor = 0, 0
            sparse.grid:apply(function(g, x, y)
                if g:get(x, y) == 0 then sparseFloor = sparseFloor + 1 end
            end)
            dense.grid:apply(function(g, x, y)
                if g:get(x, y) == 0 then denseFloor = denseFloor + 1 end
            end)

            -- With 0 iterations, density directly affects floor count
            -- sparse (30%) should have fewer cells than dense (70%)
            t.expect(sparseFloor > 0).to_be(true)
            t.expect(denseFloor > 0).to_be(true)
            t.expect(sparseFloor < denseFloor).to_be(true)
        end)
    end)

    t.describe("grid()", function()
        t.it("returns just the grid", function()
            math.randomseed(12345)
            local grid = cave.grid(40, 30)

            t.expect(grid.w).to_be(40)
            t.expect(grid.h).to_be(30)
            t.expect(type(grid.get)).to_be("function")
        end)
    end)

    t.describe("pattern()", function()
        t.it("returns just the pattern", function()
            math.randomseed(12345)
            local pattern = cave.pattern(40, 30)

            t.expect(type(pattern.cells)).to_be("function")
            t.expect(type(pattern.has_cell)).to_be("function")
        end)
    end)

    t.describe("keepLargest option", function()
        t.it("removes small disconnected regions by default", function()
            math.randomseed(12345)
            local result = cave.generate(50, 50, {keepLargest = true})

            -- Pattern should be a single connected component
            local components = procgen.forma.pattern.connected_components(
                result.pattern,
                procgen.forma.neighbourhood.moore()
            )

            -- Should have exactly 1 component (or 0 if empty)
            t.expect(#components <= 1).to_be(true)
        end)

        t.it("can disable keepLargest to preserve islands", function()
            math.randomseed(54321)
            local result = cave.generate(40, 40, {
                keepLargest = false,
                fillDensity = 0.3,
                iterations = 5
            })

            -- May have multiple components
            t.expect(result.grid).to_be_truthy()
        end)
    end)
end)

return t.run()
