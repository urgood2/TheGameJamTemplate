-- assets/scripts/tests/test_procgen_terrain.lua
-- TDD: Tests written FIRST for Phase 4 TerrainBuilder

local t = require("tests.test_runner")
t.reset()

local procgen = require("core.procgen")

t.describe("TerrainBuilder", function()
    local TerrainBuilder = require("core.procgen.terrain")

    t.describe("construction", function()
        t.it("creates builder with dimensions", function()
            local builder = TerrainBuilder.new(100, 80)
            t.expect(builder).to_be_truthy()
            t.expect(builder._w).to_be(100)
            t.expect(builder._h).to_be(80)
        end)

        t.it("accepts seed for reproducibility", function()
            local builder = TerrainBuilder.new(50, 50, {seed = 12345})
            t.expect(builder._opts.seed).to_be(12345)
        end)
    end)

    t.describe("fluent API", function()
        t.it("heightmap() returns self for chaining", function()
            local builder = TerrainBuilder.new(50, 50)
            local result = builder:heightmap({scale = 0.1})
            t.expect(result).to_be(builder)
        end)

        t.it("threshold() returns self for chaining", function()
            local builder = TerrainBuilder.new(50, 50):heightmap()
            local result = builder:threshold(0.5, 1, 0)
            t.expect(result).to_be(builder)
        end)

        t.it("supports method chaining", function()
            local builder = TerrainBuilder.new(50, 50)
                :heightmap()
                :threshold(0.3, 1, 0)
            t.expect(builder).to_be_truthy()
        end)
    end)

    t.describe("heightmap()", function()
        t.it("generates noise-based terrain values", function()
            math.randomseed(12345)
            local builder = TerrainBuilder.new(20, 20):heightmap({scale = 0.2})

            -- Values should be between 0 and 1
            local minVal, maxVal = 1, 0
            builder._grid:apply(function(g, x, y)
                local val = g:get(x, y)
                if val < minVal then minVal = val end
                if val > maxVal then maxVal = val end
            end)

            t.expect(minVal >= 0).to_be(true)
            t.expect(maxVal <= 1).to_be(true)
            t.expect(maxVal > minVal).to_be(true)  -- Should have variety
        end)

        t.it("uses octaves for detail", function()
            math.randomseed(12345)
            local builder = TerrainBuilder.new(30, 30)
                :heightmap({scale = 0.1, octaves = 4})

            -- Should produce varied terrain
            local values = {}
            builder._grid:apply(function(g, x, y)
                table.insert(values, g:get(x, y))
            end)

            t.expect(#values).to_be(900)  -- 30*30
        end)
    end)

    t.describe("threshold()", function()
        t.it("converts heightmap to discrete values", function()
            math.randomseed(12345)
            local builder = TerrainBuilder.new(20, 20)
                :heightmap()
                :threshold(0.5, 1, 0)

            -- All values should be 0 or 1
            local hasZero, hasOne = false, false
            builder._grid:apply(function(g, x, y)
                local val = g:get(x, y)
                if val == 0 then hasZero = true end
                if val == 1 then hasOne = true end
                t.expect(val == 0 or val == 1).to_be(true)
            end)

            t.expect(hasZero).to_be(true)
            t.expect(hasOne).to_be(true)
        end)
    end)

    t.describe("biomes()", function()
        t.it("assigns biome values based on height ranges", function()
            math.randomseed(12345)
            local builder = TerrainBuilder.new(30, 30)
                :heightmap()
                :biomes({
                    {maxHeight = 0.3, value = 1},  -- Water
                    {maxHeight = 0.5, value = 2},  -- Sand
                    {maxHeight = 0.7, value = 3},  -- Grass
                    {maxHeight = 1.0, value = 4}   -- Mountain
                })

            -- Should have multiple biome types
            local counts = {[1] = 0, [2] = 0, [3] = 0, [4] = 0}
            builder._grid:apply(function(g, x, y)
                local val = g:get(x, y)
                if counts[val] then
                    counts[val] = counts[val] + 1
                end
            end)

            -- At least some variety (may not hit all biomes in small grid)
            local nonZeroCount = 0
            for _, count in pairs(counts) do
                if count > 0 then nonZeroCount = nonZeroCount + 1 end
            end
            t.expect(nonZeroCount >= 2).to_be(true)
        end)
    end)

    t.describe("build()", function()
        t.it("returns Grid instance", function()
            math.randomseed(12345)
            local grid = TerrainBuilder.new(20, 20)
                :heightmap()
                :build()

            t.expect(grid.w).to_be(20)
            t.expect(grid.h).to_be(20)
            t.expect(type(grid.get)).to_be("function")
        end)
    end)

    t.describe("seed reproducibility", function()
        t.it("same seed produces same terrain", function()
            local grid1 = TerrainBuilder.new(20, 20, {seed = 55555})
                :heightmap()
                :build()

            local grid2 = TerrainBuilder.new(20, 20, {seed = 55555})
                :heightmap()
                :build()

            -- Sample some values
            t.expect(grid1:get(5, 5)).to_be(grid2:get(5, 5))
            t.expect(grid1:get(10, 10)).to_be(grid2:get(10, 10))
            t.expect(grid1:get(15, 15)).to_be(grid2:get(15, 15))
        end)
    end)
end)

t.describe("procgen.terrain() factory", function()
    t.it("returns TerrainBuilder instance", function()
        local builder = procgen.terrain(50, 50)
        t.expect(builder).to_be_truthy()
        t.expect(type(builder.heightmap)).to_be("function")
        t.expect(type(builder.threshold)).to_be("function")
        t.expect(type(builder.biomes)).to_be("function")
        t.expect(type(builder.build)).to_be("function")
    end)
end)

return t.run()
