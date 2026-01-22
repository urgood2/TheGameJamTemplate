-- assets/scripts/core/procgen/spawner.lua
-- Entity spawning utilities for procedural generation
--
-- Usage:
--   local spawner = require("core.procgen.spawner")
--   local EntityBuilder = require("core.entity_builder")
--
--   -- Spawn entities at pattern cells
--   spawner.spawnAtPattern(pattern, function(wx, wy, gx, gy, cell)
--     return EntityBuilder.new("wall_tile"):at(wx, wy):build()
--   end, { tileSize = 16 })
--
--   -- Spawn at grid cells with specific value
--   spawner.spawnAtGridValue(grid, 1, function(wx, wy, gx, gy)
--     return EntityBuilder.new("wall"):at(wx, wy):build()
--   end)
--
--   -- Spawn with Poisson-disc distribution for natural spacing
--   spawner.spawnPoisson(pattern, 5, function(wx, wy)
--     return EntityBuilder.new("tree"):at(wx, wy):build()
--   end)

local spawner = {}

local coords = require("core.procgen.coords")
local vendor = require("core.procgen.vendor")

--- Spawn entities at every cell in a pattern
-- @param pattern forma.pattern Pattern to spawn at
-- @param spawnFn function(wx, wy, gx, gy, cell) -> entity or nil
-- @param opts table? Options: tileSize, offsetGX, offsetGY
-- @return table Array of spawned entities (excludes nil returns)
function spawner.spawnAtPattern(pattern, spawnFn, opts)
    opts = opts or {}
    local entities = {}
    local tileSize = opts.tileSize or coords.TILE_SIZE
    local offsetGX = opts.offsetGX or 1
    local offsetGY = opts.offsetGY or 1

    for cell in pattern:cells() do
        -- Pattern is 0-indexed; map to 1-indexed grid coords before converting to world
        local gx, gy = cell.x + offsetGX, cell.y + offsetGY
        local wx, wy = coords.gridToWorld(gx, gy, tileSize)
        local entity = spawnFn(wx, wy, gx, gy, cell)
        if entity then
            table.insert(entities, entity)
        end
    end

    return entities
end

--- Spawn at grid cells matching a value
-- @param grid Grid Grid to search
-- @param value any Value to match
-- @param spawnFn function(wx, wy, gx, gy) -> entity or nil
-- @param opts table? Options: tileSize
-- @return table Array of spawned entities (excludes nil returns)
function spawner.spawnAtGridValue(grid, value, spawnFn, opts)
    opts = opts or {}
    local entities = {}
    local tileSize = opts.tileSize or coords.TILE_SIZE

    grid:apply(function(g, x, y)
        if g:get(x, y) == value then
            local wx, wy = coords.gridToWorld(x, y, tileSize)
            local entity = spawnFn(wx, wy, x, y)
            if entity then
                table.insert(entities, entity)
            end
        end
    end)

    return entities
end

--- Spawn with Poisson-disc distribution for natural spacing
-- Uses forma's sample_poisson to ensure minimum distance between spawns
-- @param pattern forma.pattern Pattern to sample from
-- @param minDistance number Minimum distance between spawns (in cells)
-- @param spawnFn function(wx, wy, gx, gy, cell) -> entity or nil
-- @param opts table? Options: tileSize, offsetGX, offsetGY
-- @return table Array of spawned entities
function spawner.spawnPoisson(pattern, minDistance, spawnFn, opts)
    local cell = vendor.forma.cell
    local sampled = pattern:sample_poisson(cell.euclidean, minDistance)
    return spawner.spawnAtPattern(sampled, spawnFn, opts)
end

return spawner
