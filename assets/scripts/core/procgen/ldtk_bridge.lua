-- assets/scripts/core/procgen/ldtk_bridge.lua
-- Bridge between procgen Grid and LDtk engine bindings
-- Converts procedural grids to LDtk IntGrid format for tile rendering and colliders
--
-- LDtk C++ bindings (when available):
--   ldtk.apply_rules(gridTable, layerName) -> tile results
--   ldtk.build_colliders_from_grid(gridTable, worldName, physicsTag, solidValues, cellSize)
--   ldtk.cleanup_procedural()

local ldtk_bridge = {}

--- Convert Grid instance to LDtk IntGrid table format
-- @param grid table Grid instance with w, h properties and to_table() method
-- @return table LDtk IntGrid format {width, height, cells}
function ldtk_bridge.gridToIntGrid(grid)
    return {
        width = grid.w,
        height = grid.h,
        cells = grid:to_table(),
    }
end

--- Apply LDtk auto-tile rules to a procedural grid
-- Requires engine C++ ldtk binding to be available
-- @param grid table Grid instance
-- @param layerName string Name of the LDtk layer to apply rules from
-- @return table Array of tile results {tile_id, x, y, flip_x, flip_y}
function ldtk_bridge.applyRules(grid, layerName)
    local ldtk = _G.ldtk
    assert(ldtk and ldtk.apply_rules, "ldtk bindings not available - requires engine runtime")
    return ldtk.apply_rules(ldtk_bridge.gridToIntGrid(grid), layerName)
end

--- Build physics colliders from a procedural grid
-- Uses LDtk's optimized collider merging algorithm
-- Requires engine C++ ldtk binding to be available
-- @param grid table Grid instance
-- @param opts table Options {worldName, physicsTag, solidValues, cellSize}
function ldtk_bridge.buildColliders(grid, opts)
    opts = opts or {}
    local ldtk = _G.ldtk
    assert(ldtk and ldtk.build_colliders_from_grid, "ldtk bindings not available - requires engine runtime")
    ldtk.build_colliders_from_grid(
        ldtk_bridge.gridToIntGrid(grid),
        opts.worldName or "world",
        opts.physicsTag or "WORLD",
        opts.solidValues or { 1 },
        opts.cellSize
    )
end

--- Clean up procedural content (tiles, colliders)
-- Safe to call even without engine bindings
function ldtk_bridge.cleanup()
    local ldtk = _G.ldtk
    if ldtk and ldtk.cleanup_procedural then
        ldtk.cleanup_procedural()
    end
end

return ldtk_bridge
