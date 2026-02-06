-- assets/scripts/core/procgen/init.lua
-- Main entry point for the procgen (procedural generation) module
--
-- Provides unified access to Graph, Grid, and Forma libraries with:
--   - Normalized imports (no global dependency)
--   - Coordinate conversion utilities
--   - LDtk integration bridges
--   - High-level builder patterns (Phase 2+)
--
-- Usage:
--   local procgen = require("core.procgen")
--   local grid = procgen.Grid(100, 100, 0)
--   local graph = procgen.Graph()
--   local pattern = procgen.forma.pattern.new()

local vendor = require("core.procgen.vendor")
local coords = require("core.procgen.coords")
local ldtk_bridge = require("core.procgen.ldtk_bridge")
local tiled_bridge = require("core.procgen.tiled_bridge")
local ldtk_rules = require("core.procgen.ldtk_rules")
local GridBuilder = require("core.procgen.grid_builder")
local GraphBuilder = require("core.procgen.graph_builder")
local PatternBuilder = require("core.procgen.pattern_builder")
local spawner = require("core.procgen.spawner")
local physics_bridge = require("core.procgen.physics_bridge")
local influence = require("core.procgen.influence")
local DungeonBuilder = require("core.procgen.dungeon")
local TerrainBuilder = require("core.procgen.terrain")
local procgenDebug = require("core.procgen.debug")

local procgen = {}

-- Re-export underlying libraries
procgen.Graph = vendor.Graph
procgen.Grid = vendor.Grid
procgen.forma = vendor.forma

-- Re-export utility modules
procgen.coords = coords
procgen.ldtk_bridge = ldtk_bridge
procgen.tiled_bridge = tiled_bridge
procgen.ldtk_rules = ldtk_rules

-- Re-export Phase 3 modules
procgen.spawner = spawner
procgen.physics_bridge = physics_bridge
procgen.influence = influence

-- Re-export Phase 5 debug module
procgen.debug = procgenDebug

-- Re-export builder classes for direct use
procgen.GridBuilder = GridBuilder
procgen.GraphBuilder = GraphBuilder
procgen.PatternBuilder = PatternBuilder
procgen.DungeonBuilder = DungeonBuilder
procgen.TerrainBuilder = TerrainBuilder

--- Create a new GridBuilder for fluent grid construction
-- @param w number Grid width
-- @param h number Grid height
-- @param default any Default fill value (default: 0)
-- @return GridBuilder
function procgen.grid(w, h, default)
    return GridBuilder.new(w, h, default)
end

--- Create a new GraphBuilder for fluent graph construction
-- @return GraphBuilder
function procgen.graph()
    return GraphBuilder.new()
end

--- Create a new PatternBuilder for fluent pattern construction
-- @return PatternBuilder
function procgen.pattern()
    return PatternBuilder.new()
end

--- Create a new DungeonBuilder for high-level dungeon generation
-- @param w number Dungeon width
-- @param h number Dungeon height
-- @param opts table? Options: roomMinSize, roomMaxSize, maxRooms, corridorWidth, seed
-- @return DungeonBuilder
function procgen.dungeon(w, h, opts)
    return DungeonBuilder.new(w, h, opts)
end

--- Create a new TerrainBuilder for noise-based terrain generation
-- @param w number Terrain width
-- @param h number Terrain height
-- @param opts table? Options: seed, scale, octaves, persistence, lacunarity
-- @return TerrainBuilder
function procgen.terrain(w, h, opts)
    return TerrainBuilder.new(w, h, opts)
end

return procgen
