-- assets/scripts/core/procgen/presets/cave.lua
-- One-liner cave generation preset using cellular automata
--
-- Usage:
--   local cave = require("core.procgen.presets.cave")
--
--   -- Generate a cave with default settings
--   local result = cave.generate(80, 60)
--   -- result.grid   - Grid with 0=floor, 1=wall
--   -- result.pattern - Forma pattern of floor cells
--
--   -- Generate with custom options
--   local result = cave.generate(100, 80, {
--     fillDensity = 0.45,    -- Initial noise density
--     rule = "B5678/S45678", -- CA rule
--     iterations = 30,       -- CA iterations
--     seed = 12345          -- Random seed
--   })

local cave = {}

local procgen = require("core.procgen")

-- Default cave generation options
local DEFAULT_OPTS = {
    fillDensity = 0.45,      -- Initial random fill density
    rule = "B5678/S45678",   -- Cave generation CA rule
    iterations = 30,         -- Number of CA iterations
    keepLargest = true,      -- Only keep largest connected component
    wallValue = 1,
    floorValue = 0,
}

--- Generate a cave using cellular automata
-- @param w number Cave width
-- @param h number Cave height
-- @param opts table? Options: fillDensity, rule, iterations, keepLargest, seed
-- @return table {grid, pattern}
function cave.generate(w, h, opts)
    opts = opts or {}

    -- Merge defaults
    local config = {}
    for k, v in pairs(DEFAULT_OPTS) do
        config[k] = v
    end
    for k, v in pairs(opts) do
        config[k] = v
    end

    -- Apply seed
    if config.seed then
        math.randomseed(config.seed)
    end

    -- Build cave pattern using PatternBuilder
    local builder = procgen.pattern()
        :square(w, h)
        :sample(math.floor(w * h * config.fillDensity))
        :automata(config.rule, config.iterations)

    if config.keepLargest then
        builder:keepLargest()
    end

    local pattern = builder:build()

    -- Convert pattern to grid
    -- Start with walls everywhere, then carve floor where pattern has cells
    local grid = procgen.Grid(w, h, config.wallValue)

    -- Pattern is 0-indexed, grid is 1-indexed
    procgen.coords.patternToGrid(pattern, grid, config.floorValue, 1, 1)

    return {
        grid = grid,
        pattern = pattern
    }
end

--- Generate a cave and return just the grid
-- Convenience function for simple use cases
-- @param w number Cave width
-- @param h number Cave height
-- @param opts table? Options (same as generate)
-- @return Grid Cave grid with 0=floor, 1=wall
function cave.grid(w, h, opts)
    return cave.generate(w, h, opts).grid
end

--- Generate a cave and return just the pattern
-- Useful for further pattern operations
-- @param w number Cave width
-- @param h number Cave height
-- @param opts table? Options (same as generate)
-- @return pattern Forma pattern of floor cells
function cave.pattern(w, h, opts)
    return cave.generate(w, h, opts).pattern
end

return cave
