-- assets/scripts/core/procgen/tiled_bridge.lua
-- Bridge between procgen Grid and Tiled engine bindings.
--
-- Tiled C++ bindings (when available):
--   tiled.load_rule_defs(path)
--   tiled.apply_rules(gridTable, rulesetId)
--   tiled.draw_all_layers(targetLayer, opts)
--   tiled.draw_all_layers_ysorted(targetLayer, opts)
--   tiled.draw_layer(layerName, targetLayer, opts)
--   tiled.draw_layer_ysorted(layerName, targetLayer, opts)
--   tiled.object_count([mapId])
--   tiled.get_objects([mapId])
--   tiled.set_spawner(fn)
--   tiled.spawn_objects([mapId])
--   tiled.build_colliders_from_grid(grid, world, tag, solidValues, cellSize)
--   tiled.cleanup_procedural()

local tiled_bridge = {}

--- Convert Grid instance to Tiled grid table format.
-- @param grid table Grid instance with w, h, and to_table()
-- @return table { width, height, cells }
function tiled_bridge.gridToTileGrid(grid)
    return {
        width = grid.w,
        height = grid.h,
        cells = grid:to_table(),
    }
end

--- Load runtime rule definitions (rules.txt + runtime_json fallback).
-- @param rulesPath string
-- @return string rulesetId
function tiled_bridge.loadRuleDefs(rulesPath)
    local tiled = _G.tiled
    assert(tiled and tiled.load_rule_defs, "tiled bindings not available - requires engine runtime")
    return tiled.load_rule_defs(rulesPath)
end

--- Apply Tiled ruleset to a procgen Grid.
-- @param grid table Grid instance
-- @param rulesetId string
-- @return table Procedural tile results
function tiled_bridge.applyRules(grid, rulesetId)
    local tiled = _G.tiled
    assert(tiled and tiled.apply_rules, "tiled bindings not available - requires engine runtime")
    return tiled.apply_rules(tiled_bridge.gridToTileGrid(grid), rulesetId)
end

--- Draw all visible map tile layers to the target render layer.
-- @param targetLayer string
-- @param opts table?
-- @return number queued tile draw commands
function tiled_bridge.drawAllLayers(targetLayer, opts)
    local tiled = _G.tiled
    assert(tiled and tiled.draw_all_layers, "tiled draw bindings not available - requires engine runtime")
    return tiled.draw_all_layers(targetLayer, opts)
end

--- Draw all visible map tile layers with per-row z sorting.
-- @param targetLayer string
-- @param opts table?
-- @return number queued tile draw commands
function tiled_bridge.drawAllLayersYSorted(targetLayer, opts)
    local tiled = _G.tiled
    assert(tiled and tiled.draw_all_layers_ysorted, "tiled draw bindings not available - requires engine runtime")
    return tiled.draw_all_layers_ysorted(targetLayer, opts)
end

--- Draw one named map layer.
-- @param mapLayerName string
-- @param targetLayer string
-- @param opts table?
-- @return number queued tile draw commands
function tiled_bridge.drawLayer(mapLayerName, targetLayer, opts)
    local tiled = _G.tiled
    assert(tiled and tiled.draw_layer, "tiled draw bindings not available - requires engine runtime")
    return tiled.draw_layer(mapLayerName, targetLayer, opts)
end

--- Draw one named map layer with per-row z sorting.
-- @param mapLayerName string
-- @param targetLayer string
-- @param opts table?
-- @return number queued tile draw commands
function tiled_bridge.drawLayerYSorted(mapLayerName, targetLayer, opts)
    local tiled = _G.tiled
    assert(tiled and tiled.draw_layer_ysorted, "tiled draw bindings not available - requires engine runtime")
    return tiled.draw_layer_ysorted(mapLayerName, targetLayer, opts)
end

--- Return Tiled object-layer objects from map (or active map).
-- @param mapId string?
-- @return table
function tiled_bridge.getObjects(mapId)
    local tiled = _G.tiled
    assert(tiled and tiled.get_objects, "tiled object bindings not available - requires engine runtime")
    if mapId then
        return tiled.get_objects(mapId)
    end
    return tiled.get_objects()
end

--- Spawn objects using a registered or provided spawner callback.
-- @param mapId string?
-- @param spawner function?
-- @return number
function tiled_bridge.spawnObjects(mapId, spawner)
    local tiled = _G.tiled
    assert(tiled and tiled.spawn_objects and tiled.set_spawner, "tiled object bindings not available - requires engine runtime")

    if spawner then
        tiled.set_spawner(spawner)
    end

    if mapId then
        return tiled.spawn_objects(mapId)
    end
    return tiled.spawn_objects()
end

--- Build static colliders from a procgen Grid.
-- @param grid table Grid instance
-- @param opts table? { worldName, physicsTag, solidValues, cellSize }
-- @return number created collider entities
function tiled_bridge.buildColliders(grid, opts)
    opts = opts or {}
    local tiled = _G.tiled
    assert(tiled and tiled.build_colliders_from_grid, "tiled collider bindings not available - requires engine runtime")

    return tiled.build_colliders_from_grid(
        tiled_bridge.gridToTileGrid(grid),
        opts.worldName or "world",
        opts.physicsTag or "WORLD",
        opts.solidValues or { 1 },
        opts.cellSize
    )
end

--- Clear generated procedural state + generated colliders.
function tiled_bridge.cleanup()
    local tiled = _G.tiled
    if tiled and tiled.cleanup_procedural then
        tiled.cleanup_procedural()
    end
end

return tiled_bridge
