-- assets/scripts/core/procgen/physics_bridge.lua
-- Physics collider generation from procedural grids
--
-- Delegates to the existing LDtk C++ bindings for collider generation.
-- This avoids bespoke collider merging logic and stays consistent with
-- the engine's tile pipeline.
--
-- Usage:
--   local physics_bridge = require("core.procgen.physics_bridge")
--
--   physics_bridge.buildColliders(grid, {
--     worldName = "world",
--     physicsTag = "WORLD",
--     solidValues = { 1 }
--   })

local physics_bridge = {}

local ldtk_bridge = require("core.procgen.ldtk_bridge")

--- Build physics colliders from a procedural grid
-- Uses the LDtk bindings to generate merged rectangle colliders
-- @param grid Grid The grid with tile values
-- @param opts table? Options:
--   - worldName: string (default "world")
--   - physicsTag: string (default "WORLD")
--   - solidValues: table (default {1})
--   - cellSize: number (defaults to engine default)
function physics_bridge.buildColliders(grid, opts)
    opts = opts or {}
    local ldtk = _G.ldtk
    assert(ldtk and ldtk.build_colliders_from_grid, "ldtk bindings not available")

    local gridTable = ldtk_bridge.gridToIntGrid(grid)
    ldtk.build_colliders_from_grid(
        gridTable,
        opts.worldName or "world",
        opts.physicsTag or "WORLD",
        opts.solidValues or { 1 },
        opts.cellSize
    )
end

return physics_bridge
