-- assets/scripts/core/procgen/terrain.lua
-- Terrain generation using noise-based heightmaps and biome assignment
--
-- Usage:
--   local TerrainBuilder = require("core.procgen.terrain")
--   local grid = TerrainBuilder.new(100, 80, {seed = 12345})
--     :heightmap({scale = 0.1, octaves = 4})
--     :biomes({
--       {maxHeight = 0.3, value = 1},  -- Water
--       {maxHeight = 0.5, value = 2},  -- Sand
--       {maxHeight = 0.7, value = 3},  -- Grass
--       {maxHeight = 1.0, value = 4}   -- Mountain
--     })
--     :build()

local TerrainBuilder = {}
TerrainBuilder.__index = TerrainBuilder

local vendor = require("core.procgen.vendor")
local Grid = vendor.Grid

-- Default options
local DEFAULT_OPTS = {
    scale = 0.1,       -- Noise scale (lower = smoother)
    octaves = 4,       -- Number of noise octaves for detail
    persistence = 0.5, -- How much each octave contributes
    lacunarity = 2.0,  -- Frequency multiplier per octave
}

--- Simple value noise implementation (deterministic from coordinates)
-- Uses a hash-based approach for reproducible results
-- Note: Uses bit library for LuaJIT/Lua 5.4 compatibility (from init/bit_compat.lua)
local function hash(x, y, seed)
    -- Simple hash combining coordinates and seed
    local n = x + y * 57 + seed * 131

    -- Use bit library if available (works with both LuaJIT and Lua 5.4 via bit_compat)
    if bit and bit.bxor and bit.lshift then
        n = bit.bxor(n, bit.lshift(n, 13))
    else
        -- Fallback for environments without bit library
        -- Use multiplication-based mixing instead
        n = n * 1103515245 + 12345
    end

    n = n * (n * n * 15731 + 789221) + 1376312589
    -- Normalize to 0-1
    return math.abs(n % 1000000) / 1000000
end

--- Smoothstep interpolation
local function smoothstep(t)
    return t * t * (3 - 2 * t)
end

--- Linear interpolation
local function lerp(a, b, t)
    return a + (b - a) * t
end

--- 2D value noise at continuous coordinates
local function valueNoise(x, y, seed)
    local x0 = math.floor(x)
    local y0 = math.floor(y)
    local x1 = x0 + 1
    local y1 = y0 + 1

    local sx = smoothstep(x - x0)
    local sy = smoothstep(y - y0)

    local n00 = hash(x0, y0, seed)
    local n10 = hash(x1, y0, seed)
    local n01 = hash(x0, y1, seed)
    local n11 = hash(x1, y1, seed)

    local nx0 = lerp(n00, n10, sx)
    local nx1 = lerp(n01, n11, sx)

    return lerp(nx0, nx1, sy)
end

--- Fractal Brownian Motion noise (multi-octave noise)
local function fbmNoise(x, y, seed, octaves, persistence, lacunarity)
    local total = 0
    local maxValue = 0
    local amplitude = 1
    local frequency = 1

    for _ = 1, octaves do
        total = total + valueNoise(x * frequency, y * frequency, seed) * amplitude
        maxValue = maxValue + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * lacunarity
    end

    return total / maxValue  -- Normalize to 0-1
end

--- Create a new TerrainBuilder
-- @param w number Terrain width
-- @param h number Terrain height
-- @param opts table? Options: seed, scale, octaves, persistence, lacunarity
-- @return TerrainBuilder
function TerrainBuilder.new(w, h, opts)
    local self = setmetatable({}, TerrainBuilder)
    self._w = w
    self._h = h
    self._opts = {}

    -- Merge defaults with provided options
    for k, v in pairs(DEFAULT_OPTS) do
        self._opts[k] = v
    end
    if opts then
        for k, v in pairs(opts) do
            self._opts[k] = v
        end
    end

    -- Apply seed if provided
    if self._opts.seed then
        math.randomseed(self._opts.seed)
    end

    -- Initialize grid with zeros
    self._grid = Grid(w, h, 0)
    self._seed = self._opts.seed or math.random(1, 1000000)

    return self
end

--- Generate a heightmap using fractal noise
-- @param opts table? Options: scale, octaves, persistence, lacunarity
-- @return TerrainBuilder self for chaining
function TerrainBuilder:heightmap(opts)
    opts = opts or {}
    local scale = opts.scale or self._opts.scale
    local octaves = opts.octaves or self._opts.octaves
    local persistence = opts.persistence or self._opts.persistence
    local lacunarity = opts.lacunarity or self._opts.lacunarity

    for x = 1, self._w do
        for y = 1, self._h do
            local nx = x * scale
            local ny = y * scale
            local value = fbmNoise(nx, ny, self._seed, octaves, persistence, lacunarity)
            self._grid:set(x, y, value)
        end
    end

    return self
end

--- Apply a threshold to convert continuous values to discrete
-- @param threshold number Cutoff value (0-1)
-- @param aboveValue any Value for cells above threshold
-- @param belowValue any Value for cells at or below threshold
-- @return TerrainBuilder self for chaining
function TerrainBuilder:threshold(threshold, aboveValue, belowValue)
    self._grid:apply(function(g, x, y)
        local val = g:get(x, y)
        if val > threshold then
            g:set(x, y, aboveValue)
        else
            g:set(x, y, belowValue)
        end
    end)
    return self
end

--- Assign biome values based on height ranges
-- @param biomeRanges table Array of {maxHeight, value} sorted by maxHeight ascending
-- @return TerrainBuilder self for chaining
function TerrainBuilder:biomes(biomeRanges)
    self._grid:apply(function(g, x, y)
        local height = g:get(x, y)
        local biomeValue = biomeRanges[#biomeRanges].value  -- Default to highest

        for _, biome in ipairs(biomeRanges) do
            if height <= biome.maxHeight then
                biomeValue = biome.value
                break
            end
        end

        g:set(x, y, biomeValue)
    end)
    return self
end

--- Apply erosion simulation (simple thermal erosion)
-- @param iterations number Number of erosion passes
-- @return TerrainBuilder self for chaining
function TerrainBuilder:erode(iterations)
    iterations = iterations or 1
    local talusAngle = 0.1  -- How much height difference triggers erosion

    for _ = 1, iterations do
        local changes = Grid(self._w, self._h, 0)

        self._grid:apply(function(g, x, y)
            local height = g:get(x, y)

            -- Check 4 neighbors
            local neighbors = {
                {x - 1, y}, {x + 1, y},
                {x, y - 1}, {x, y + 1}
            }

            for _, n in ipairs(neighbors) do
                local nx, ny = n[1], n[2]
                if nx >= 1 and nx <= self._w and ny >= 1 and ny <= self._h then
                    local nHeight = g:get(nx, ny)
                    local diff = height - nHeight

                    if diff > talusAngle then
                        local transfer = (diff - talusAngle) / 2
                        changes:set(x, y, changes:get(x, y) - transfer)
                        changes:set(nx, ny, changes:get(nx, ny) + transfer)
                    end
                end
            end
        end)

        -- Apply changes
        self._grid:apply(function(g, x, y)
            local newVal = g:get(x, y) + changes:get(x, y)
            g:set(x, y, math.max(0, math.min(1, newVal)))
        end)
    end

    return self
end

--- Build and return the final Grid
-- @return Grid The constructed terrain grid
function TerrainBuilder:build()
    return self._grid
end

--- Reset the builder for reuse
-- @return TerrainBuilder self for chaining
function TerrainBuilder:reset()
    if self._opts.seed then
        math.randomseed(self._opts.seed)
    end
    self._grid = Grid(self._w, self._h, 0)
    self._seed = self._opts.seed or math.random(1, 1000000)
    return self
end

return TerrainBuilder
