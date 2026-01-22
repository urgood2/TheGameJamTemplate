-- assets/scripts/core/procgen/influence.lua
-- AI influence map utilities for tactical planning
--
-- Influence maps allow AI to make spatial decisions based on danger,
-- opportunity, or other factors spread across the game world.
--
-- Usage:
--   local influence = require("core.procgen.influence")
--
--   -- Create danger map from enemies
--   local enemies = { {x = 100, y = 100}, {x = 200, y = 150} }
--   local dangerMap = influence.fromEntities(100, 80, enemies, {
--     falloff = 0.7,
--     maxDistance = 10,
--     getStrength = function(e) return e.threat or 1 end
--   })
--
--   -- Find safest position
--   local safeX, safeY, danger = influence.findBest(dangerMap, "min")
--
--   -- Find most dangerous position
--   local hotX, hotY, maxDanger = influence.findBest(dangerMap, "max")

local influence = {}

local vendor = require("core.procgen.vendor")
local Grid = vendor.Grid
local coords = require("core.procgen.coords")

--- Spread influence from a single point with falloff
-- Uses flood-fill to propagate influence with diminishing strength
-- @param grid Grid Grid to modify (values are accumulated)
-- @param cx number Center X (grid coords, 1-indexed)
-- @param cy number Center Y (grid coords, 1-indexed)
-- @param strength number Initial strength at center
-- @param falloff number Multiplier per step (0-1)
-- @param maxDist number Maximum distance to spread
function influence.spreadFromPoint(grid, cx, cy, strength, falloff, maxDist)
    local queue = {{x = cx, y = cy, str = strength, dist = 0}}
    local qh = 1
    local visited = {}

    while qh <= #queue do
        local current = queue[qh]
        qh = qh + 1
        local key = current.x .. "," .. current.y

        if not visited[key] and current.dist <= maxDist then
            visited[key] = true
            if current.x >= 1 and current.x <= grid.w and
               current.y >= 1 and current.y <= grid.h then
                local existing = grid:get(current.x, current.y) or 0
                grid:set(current.x, current.y, existing + current.str)

                local nextStr = current.str * falloff
                if nextStr > 0.01 then
                    -- 4-directional spread (von Neumann neighborhood)
                    for _, dir in ipairs({{0, 1}, {0, -1}, {1, 0}, {-1, 0}}) do
                        table.insert(queue, {
                            x = current.x + dir[1],
                            y = current.y + dir[2],
                            str = nextStr,
                            dist = current.dist + 1
                        })
                    end
                end
            end
        end
    end
end

--- Create influence map from entities
-- Each entity contributes influence based on its position and strength
-- @param width number Grid width
-- @param height number Grid height
-- @param entities table Array of entities with x, y world coordinates
-- @param opts table? Options:
--   - falloff: number (default 0.8) - strength multiplier per cell distance
--   - maxDistance: number (default 10) - max spread distance
--   - getStrength: function(entity) -> number (default returns 1)
--   - tileSize: number (default coords.TILE_SIZE) - for world->grid conversion
-- @return Grid Influence map grid
function influence.fromEntities(width, height, entities, opts)
    opts = opts or {}
    local grid = Grid(width, height, 0)
    local falloff = opts.falloff or 0.8
    local maxDist = opts.maxDistance or 10
    local tileSize = opts.tileSize or coords.TILE_SIZE

    for _, entity in ipairs(entities) do
        local wx, wy = entity.x, entity.y
        local gx, gy = coords.worldToGrid(wx, wy, tileSize)
        local strength = opts.getStrength and opts.getStrength(entity) or 1

        -- Spread influence from this entity's position
        influence.spreadFromPoint(grid, gx, gy, strength, falloff, maxDist)
    end

    return grid
end

--- Find best position in influence map (min or max)
-- @param grid Grid Influence map to search
-- @param minOrMax string "min" for lowest value, "max" for highest
-- @return number, number, number Best x, y grid coords and the value
function influence.findBest(grid, minOrMax)
    local bestVal = minOrMax == "min" and math.huge or -math.huge
    local bestX, bestY = 1, 1

    grid:apply(function(g, x, y)
        local val = g:get(x, y)
        if minOrMax == "min" and val < bestVal then
            bestVal = val
            bestX, bestY = x, y
        elseif minOrMax == "max" and val > bestVal then
            bestVal = val
            bestX, bestY = x, y
        end
    end)

    return bestX, bestY, bestVal
end

return influence
