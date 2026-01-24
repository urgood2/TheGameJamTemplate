# Integration Plan: Graph, Grid, and Forma Libraries

## Executive Summary

This document outlines a comprehensive integration plan for three external Lua libraries—**Graph.lua**, **Grid.lua**, and **Forma**—into the game engine codebase. These libraries provide powerful primitives for procedural generation, spatial reasoning, and graph-based data structures that can dramatically enhance gameplay systems.

The integration follows the codebase's existing conventions: Object-based inheritance, builder patterns, and the module system (`require("core.xxx")` / `require("external.xxx")`). A unified wrapper API layer (`procgen`) will provide dead-simple, discoverable access to all three libraries while bridging them to existing systems like ECS, physics, tilemaps, and AI.

Where possible, tile rendering and collider generation should route through the engine’s existing **LDtk Lua bindings** (`ldtk.apply_rules`, `ldtk.build_colliders_from_grid`) so procedural content uses the same pipeline as authored levels.

The plan is structured in five implementation phases, starting with coordinate conversion foundations and progressing to advanced features like procedural dungeon generation and AI influence maps. Each phase builds on the previous, ensuring incremental value delivery and testability.

---

## Part 0: Repo Reality Check (Current State)

### 0.1 Already Vendored Libraries

These libraries already exist in the repo:

- **Graph.lua**: `assets/scripts/external/graph.lua`
- **Grid.lua**: `assets/scripts/external/grid.lua`
- **Forma**: `assets/scripts/external/forma/` (modules are `require("forma.pattern")`, `require("forma.cell")`, etc.)

Related engine integration that we should leverage:

- **LDtk Lua bindings (C++ globals)**: `ldtk.apply_rules`, `ldtk.build_colliders_from_grid`, `ldtk.cleanup_procedural` (see `docs/lua-cookbook/cookbook.md`)

### 0.2 Import/Global Caveats (Important)

- `assets/scripts/external/graph.lua` / `assets/scripts/external/grid.lua` currently define globals (`Graph`, `Grid`) and do not `return` a module value.
- Both Graph/Grid rely on helpers (`table.any`, `table.deep_copy`) and a global/class dependency (`Object`) that are not guaranteed to exist unless we provide them.
- `assets/scripts/external/forma/init.lua` performs “lazy import into global space” and does not return a single `forma` table.

**Plan adjustment**: `core.procgen` should normalize these into clean, local values without relying on globals:

- `procgen.Graph` → Graph class/table (undirected/unweighted)
- `procgen.Grid` → Grid class/table
- `procgen.forma` → explicit table `{cell, pattern, primitives, automata, neighbourhood, raycasting}`

Nice-to-have: vendor-patch Graph/Grid/Forma init to behave like normal `require()` modules (`return Graph`, etc.), but wrappers are sufficient and lower risk.

### 0.3 Coordinate Conventions (Canonical)

To prevent off-by-one bugs, `procgen` should treat coordinate spaces explicitly:

- **Grid coords (Grid.lua / IntGrid / LDtk)**: **1-indexed** `(gx, gy)` where `1 ≤ gx ≤ w`, `1 ≤ gy ≤ h`
- **Pattern coords (Forma)**: **0-indexed** `(px, py)` where `0 ≤ px < w`, `0 ≤ py < h`
- **World coords**: pixels (float)

All `procgen.coords` APIs should treat `(gx, gy)` as 1-indexed unless explicitly named `pattern*`.

## Part 1: Use Cases & Applications

### 1.1 Graph.lua Use Cases

**Note**: The vendored Graph.lua implementation is an **undirected, unweighted** graph. Use it first for connectivity/adjacency problems (rooms, waypoints, social links). Directed/weighted use cases (quests, prerequisites, economy flow) require either a small extension/wrapper in `procgen` or a separate `procgen.digraph` type (defer until after Phase 2 unless immediately needed).

| # | Use Case | Description |
|---|----------|-------------|
| 1 | **Quest Dependency Trees** | Requires directed edges (not supported as-is). Use a `digraph` wrapper or separate adjacency map. |
| 2 | **Dialogue State Machines** | Requires directed edges (not supported as-is). |
| 3 | **Skill/Tech Trees** | Requires directed edges (not supported as-is). |
| 4 | **Room Connectivity** | Dungeon rooms as nodes, doors/corridors as edges. Ensure all rooms are reachable via BFS. |
| 5 | **AI Faction Relationships** | Requires weights (not supported as-is). Can model unweighted adjacency for “knows about” first. |
| 6 | **Crafting Recipes** | Requires directed edges (not supported as-is). |
| 7 | **Navigation Waypoints** | Strategic points connected by traversable paths. AI uses shortest_path_bfs for high-level navigation. |
| 8 | **Event Causality Chains** | Requires directed edges (not supported as-is). |
| 9 | **Social Networks** | NPCs connected by relationships. Find shortest "connection" path between any two NPCs. |
| 10 | **Spell Combo Trees** | Requires directed edges (not supported as-is). |
| 11 | **Economy Flow Visualization** | Requires directed and/or weighted edges (not supported as-is). |
| 12 | **Achievement Prerequisites** | Requires directed edges (not supported as-is). |

### 1.2 Grid.lua Use Cases

| # | Use Case | Description |
|---|----------|-------------|
| 1 | **Tile-Based Level Storage** | Store level data in a compact 2D grid. Export to tilemap renderer. |
| 2 | **Fog of War** | Grid tracks visibility state per tile. Update on player movement. |
| 3 | **Influence Maps** | AI scores each cell by danger/opportunity. Grid stores and queries values. |
| 4 | **Heat Maps** | Track where players spend time, die often, or find loot. Analytics overlay. |
| 5 | **Pathfinding Cost Grid** | Custom movement costs per tile for A* integration. |
| 6 | **Territory Control** | Strategy games: each cell belongs to a faction. flood_fill finds contiguous territory. |
| 7 | **Puzzle Board State** | Match-3 or sliding puzzles store state in Grid. rotate_clockwise for piece rotation. |
| 8 | **Minimap Data** | Compact grid mirrors world state for minimap rendering. |
| 9 | **Destructible Terrain** | Grid tracks which tiles are destroyed. apply() updates damage state. |
| 10 | **Room Templates** | Prefab rooms stored as small grids, stamped into larger world grid. |
| 11 | **Lighting Occlusion** | Grid stores light-blocking cells for simple shadow casting. |
| 12 | **Spawn Point Distribution** | Grid marks valid spawn locations; pick randomly from non-blocked cells. |

### 1.3 Forma Library Use Cases

| # | Use Case | Description |
|---|----------|-------------|
| 1 | **Cave Generation (CA)** | Cellular automata with B5678/S45678 rule creates organic caves. |
| 2 | **Dungeon Layout (BSP)** | Binary space partitioning divides area into rooms, connect with corridors. |
| 3 | **Biome Distribution** | Voronoi tessellation assigns biome types to regions. |
| 4 | **Terrain Height Maps** | Perlin noise sampling creates elevation variation. |
| 5 | **Lake/River Shapes** | Use erosion/dilation morphology to create natural water boundaries. |
| 6 | **FOV/Line-of-Sight** | raycasting.cast_360 computes what player can see. |
| 7 | **Explosion AOE** | primitives.circle defines blast radius; pattern - obstacles = affected area. |
| 8 | **Spell Targeting Cones** | Rasterize cone shape, filter by pattern intersection with enemies. |
| 9 | **Forest Placement** | Poisson-disc sampling ensures trees aren't too close together. |
| 10 | **Road Networks** | primitives.line connects cities; smooth with bezier curves. |
| 11 | **Island Archipelagos** | Generate base shape, connected_components separates islands. |
| 12 | **Wall Thinning** | pattern.thin() creates skeleton paths through thick walls. |
| 13 | **Procedural Coastlines** | Convex hull + noise creates varied shorelines. |
| 14 | **Enemy Spawn Zones** | Sample pattern for spawn points with minimum spacing. |
| 15 | **Tile Autotiling** | neighbourhood_categories determines which tile variant to use. |

### 1.4 Combined/Synergistic Use Cases

| # | Use Case | Libraries | Description |
|---|----------|-----------|-------------|
| 1 | **Full Dungeon Generator** | Forma + Graph + Grid | BSP rooms (Forma), connectivity graph (Graph), final tilemap (Grid) |
| 2 | **AI Tactical Planning** | Grid + Graph | Influence map (Grid), waypoint graph (Graph), combined scoring |
| 3 | **Dynamic World Erosion** | Forma + Grid | Forma morphology operations update Grid world state over time |
| 4 | **Quest-Gated Areas** | Graph + Forma | Quest graph unlocks areas; Forma generates area content |
| 5 | **Procedural Skill Effects** | Forma + Grid | Forma patterns define AOE; Grid stores affected cells |
| 6 | **Trade Route Optimization** | Graph + Grid | Cities on grid, routes in graph, shortest paths for traders |

---

## Part 2: API Design

### 2.1 Module Structure

```
assets/scripts/core/procgen/
├── init.lua              -- Main entry point, lazy-loads submodules
├── vendor.lua            -- Normalize Graph/Grid/Forma imports (no globals)
├── coords.lua            -- World <-> Grid coordinate conversion
├── ldtk_bridge.lua       -- Grid/Pattern -> LDtk IntGrid + auto-rules/colliders
├── grid_builder.lua      -- Builder pattern for Grid operations
├── graph_builder.lua     -- Builder pattern for Graph operations  
├── pattern_builder.lua   -- Builder pattern for Forma patterns
├── dungeon.lua           -- High-level dungeon generation
├── terrain.lua           -- Terrain generation utilities
├── physics_bridge.lua    -- Colliders from Grid via LDtk helpers
├── influence.lua         -- AI influence map utilities
├── spawner.lua           -- Entity spawning from patterns
├── presets/              -- Optional “one-liner” generator presets
│   └── cave.lua
└── debug.lua             -- Visualization helpers
```

### 2.2 Core API Reference

#### `procgen` (init.lua) - Main Entry Point

```lua
local procgen = require("core.procgen")

-- Access underlying libraries
procgen.Graph      -- Graph.lua class (undirected/unweighted)
procgen.Grid       -- Grid.lua class
procgen.forma      -- {cell, pattern, primitives, automata, neighbourhood, raycasting}
procgen.ldtk_bridge -- LDtk helpers (engine-only; wraps _G.ldtk)
procgen.spawner    -- Entity spawning helpers
procgen.influence  -- Influence map utilities

-- High-level builders
procgen.grid(w, h, default)     -- Returns GridBuilder
procgen.graph()                 -- Returns GraphBuilder  
procgen.pattern()               -- Returns PatternBuilder
procgen.dungeon(w, h, opts)     -- Returns DungeonBuilder

-- Coordinate utilities
procgen.coords.worldToGrid(wx, wy, tileSize)            -- -> gx, gy (1-indexed)
procgen.coords.gridToWorld(gx, gy, tileSize)            -- (1-indexed) -> wx, wy (cell center)
procgen.coords.patternToGrid(pattern, grid, value, offsetGX, offsetGY)  -- pattern(0-index) -> grid(1-index)
procgen.coords.gridToPattern(grid, matchValue)          -- grid(1-index) -> pattern(0-index)
```

#### `GridBuilder` - Fluent Grid Operations

```lua
local builder = procgen.grid(100, 100, 0)
  :fill(1)                           -- Fill all cells with value
  :rect(10, 10, 20, 20, 2)          -- Draw rectangle
  :circle(50, 50, 15, 3)            -- Draw filled circle
  :noise(0.3, {0, 1})               -- Random noise with density
  :stamp(otherGrid, 25, 25)         -- Paste another grid
  :apply(function(g, x, y)          -- Custom per-cell operation
    if g:get(x, y) == 1 then
      g:set(x, y, math.random(1, 3))
    end
  end)

local grid = builder:build()        -- Returns Grid instance
local islands = builder:findIslands(1)  -- Find connected components
```

#### `GraphBuilder` - Fluent Graph Operations

```lua
local builder = procgen.graph()
  :node("start", {type = "room", x = 0, y = 0})
  :node("boss", {type = "room", x = 100, y = 100})
  :node("treasure", {type = "room", x = 50, y = 80})
  :edge("start", "boss")
  :edge("start", "treasure")
  :edge("treasure", "boss")

local graph = builder:build()
local path = builder:shortestPath("start", "boss")
local neighbors = builder:neighbors("start")
```

#### `PatternBuilder` - Fluent Forma Operations

```lua
local builder = procgen.pattern()
  :square(80, 60)                    -- Start with rectangle domain
  :sample(400)                       -- Random seed points
  :automata("B5678/S45678", 50)      -- Cave generation CA
  :erode()                           -- Morphological erosion
  :keepLargest()                     -- Keep only largest component
  :translate(10, 10)                 -- Offset position

local pattern = builder:build()      -- Returns forma.pattern
local cells = builder:cells()        -- Iterator over cells
local components = builder:components()  -- Connected components
```

#### `DungeonBuilder` - High-Level Dungeon Generation

```lua
local dungeon = procgen.dungeon(100, 80, {
  roomMinSize = 8,
  roomMaxSize = 20,
  maxRooms = 12,
  corridorWidth = 2,
  seed = 12345
})
  :generateRooms()      -- BSP room placement
  :connectRooms()       -- Corridor generation
  :addDoors()           -- Door placement
  :populate({           -- Entity placement
    enemies = { min = 2, max = 5 },
    treasures = { min = 1, max = 3 }
  })

local result = dungeon:build()
-- result.grid       - Final Grid with tile values
-- result.graph      - Room connectivity Graph
-- result.rooms      - Array of room rectangles
-- result.spawnPoints - { enemies = {...}, treasures = {...} }
```

### 2.3 Builder Patterns

All builders follow this consistent pattern:

```lua
local Builder = Object:extend()

function Builder:init(...)
  self._state = {}  -- Internal state
  return self
end

function Builder:someOperation(...)
  -- Modify self._state
  return self  -- Enable chaining
end

function Builder:build()
  -- Return final result
  return self._state.result
end

-- Optional: reset for reuse
function Builder:reset()
  self._state = {}
  return self
end
```

### 2.4 Integration Bridges

#### Pattern → Entity Spawning

```lua
local procgen = require("core.procgen")
local spawner = require("core.procgen.spawner")
local EntityBuilder = require("core.entity_builder")

-- Spawn entities at pattern cells
-- spawnFn receives (wx, wy, gx, gy, cell)
spawner.spawnAtPattern(pattern, function(wx, wy)
  return EntityBuilder.new("wall_tile")
    :at(wx, wy)
    :build()
end, { tileSize = TILE_SIZE })

-- Spawn with Poisson distribution
spawner.spawnPoisson(domain, 5, function(wx, wy)
  return EntityBuilder.new("tree")
    :at(wx, wy)
    :build()
end, { tileSize = TILE_SIZE })
```

#### Grid → Tilemap

```lua
local ldtk_bridge = require("core.procgen.ldtk_bridge")

-- Convert Grid to LDtk IntGrid table and apply auto-rules
-- NOTE: ldtk is a C++ global binding (do not require()).
local tileResults = ldtk_bridge.applyRules(grid, "TileLayer")

-- Build physics colliders from the same procedural grid
ldtk_bridge.buildColliders(grid, {
  worldName = "world",
  physicsTag = "WORLD",
  solidValues = { 1 }, -- e.g. 1=wall
})
```

#### Graph → AI Navigation

```lua
local procgen = require("core.procgen")

-- High-level undirected connectivity graph for waypoints/rooms
local navBuilder = procgen.graph()
  :node("room_a", { gx = 10, gy = 10 })
  :node("room_b", { gx = 30, gy = 12 })
  :edge("room_a", "room_b")

local navGraph = navBuilder:build()

local pathIds = navBuilder:shortestPath("room_a", "room_b")
```

---

## Part 3: Integration Architecture

### 3.0 Vendor Normalization (Graph/Grid/Forma)

Because the vendored Graph/Grid libraries currently define globals and assume helpers exist, add a small normalization layer that:

- Ensures required globals/helpers exist (`Object`, `table.any`, `table.deep_copy`)
- Loads the libraries once
- Exposes clean, local references for the rest of `procgen`

```lua
-- assets/scripts/core/procgen/vendor.lua
local vendor = {}

-- Graph/Grid expect a global Object.
_G.Object = _G.Object or require("external.object")

-- Graph expects table.any; Grid expects table.deep_copy.
if type(table.any) ~= "function" then
  function table.any(t, pred)
    for _, v in ipairs(t) do
      if pred(v) then return true end
    end
    return false
  end
end

if type(table.deep_copy) ~= "function" then
  local util = require("util.util")
  table.deep_copy = util.deep_copy
end

-- Load libraries (they define globals)
require("external.graph") -- sets _G.Graph
require("external.grid")  -- sets _G.Grid

vendor.Graph = _G.Graph
vendor.Grid = _G.Grid

-- Forma: require modules directly (avoid global-import init.lua)
vendor.forma = {
  cell = require("forma.cell"),
  pattern = require("forma.pattern"),
  primitives = require("forma.primitives"),
  automata = require("forma.automata"),
  neighbourhood = require("forma.neighbourhood"),
  raycasting = require("forma.raycasting"),
}

return vendor
```

### 3.1 Coordinate System Bridge

```lua
-- assets/scripts/core/procgen/coords.lua
local coords = {}

-- Configuration (set once at game init)
coords.TILE_SIZE = 16
coords.ORIGIN_X = 0
coords.ORIGIN_Y = 0

function coords.worldToGrid(worldX, worldY, tileSize)
  tileSize = tileSize or coords.TILE_SIZE
  local gx = math.floor((worldX - coords.ORIGIN_X) / tileSize) + 1
  local gy = math.floor((worldY - coords.ORIGIN_Y) / tileSize) + 1
  return gx, gy
end

function coords.gridToWorld(gridX, gridY, tileSize)
  tileSize = tileSize or coords.TILE_SIZE
  local wx = (gridX - 1) * tileSize + coords.ORIGIN_X + tileSize / 2
  local wy = (gridY - 1) * tileSize + coords.ORIGIN_Y + tileSize / 2
  return wx, wy
end

function coords.gridToWorldRect(gridX, gridY, tileSize)
  tileSize = tileSize or coords.TILE_SIZE
  return {
    x = (gridX - 1) * tileSize + coords.ORIGIN_X,
    y = (gridY - 1) * tileSize + coords.ORIGIN_Y,
    w = tileSize,
    h = tileSize
  }
end

-- Convert forma pattern to Grid
function coords.patternToGrid(pattern, grid, value, offsetGX, offsetGY)
  offsetGX = offsetGX or 1
  offsetGY = offsetGY or 1
  value = value or 1
  for cell in pattern:cells() do
    -- Pattern is 0-indexed, Grid is 1-indexed
    grid:set(cell.x + offsetGX, cell.y + offsetGY, value)
  end
  return grid
end

-- Convert Grid to forma pattern
function coords.gridToPattern(grid, matchValue)
  local pattern = require("forma.pattern")
  local p = pattern.new()
  grid:apply(function(g, x, y)
    if g:get(x, y) == matchValue then
      p:insert(x - 1, y - 1)  -- Pattern is 0-indexed
    end
  end)
  return p
end

return coords
```

### 3.2 ECS Integration

```lua
-- assets/scripts/core/procgen/spawner.lua
local spawner = {}

local coords = require("core.procgen.coords")

-- Spawn entities at every cell in a pattern
function spawner.spawnAtPattern(pattern, spawnFn, opts)
  opts = opts or {}
  local entities = {}
  local tileSize = opts.tileSize or coords.TILE_SIZE
  local offsetGX = opts.offsetGX or 1
  local offsetGY = opts.offsetGY or 1
  
  for cell in pattern:cells() do
    -- Pattern is 0-indexed; map to 1-indexed grid coords before converting to world.
    local gx, gy = cell.x + offsetGX, cell.y + offsetGY
    local wx, wy = coords.gridToWorld(gx, gy, tileSize)
    local entity = spawnFn(wx, wy, gx, gy, cell)
    if entity then
      table.insert(entities, entity)
    end
  end
  
  return entities
end

-- Spawn at grid cells matching a value
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

-- Spawn with Poisson-disc distribution for natural spacing
function spawner.spawnPoisson(pattern, minDistance, spawnFn, opts)
  opts = opts or {}
  local cell = require("forma.cell")
  
  local sampled = pattern:sample_poisson(cell.euclidean, minDistance)
  return spawner.spawnAtPattern(sampled, spawnFn, opts)
end

return spawner
```

### 3.3 Physics Integration

```lua
-- assets/scripts/core/procgen/physics_bridge.lua
--
-- Prefer using the existing LDtk bindings for collider generation:
--   ldtk.build_colliders_from_grid(gridTable, worldName, physicsTag, solidValues)
-- This avoids bespoke collider merging logic and stays consistent with the engine's tile pipeline.
local physics_bridge = {}

local ldtk_bridge = require("core.procgen.ldtk_bridge")

function physics_bridge.buildColliders(grid, opts)
  opts = opts or {}
  local ldtk = _G.ldtk
  assert(ldtk and ldtk.build_colliders_from_grid, "ldtk bindings not available")
  local gridTable = ldtk_bridge.gridToIntGrid(grid)
  ldtk.build_colliders_from_grid(
    gridTable,
    opts.worldName or "world",
    opts.physicsTag or "WORLD",
    opts.solidValues or { 1 }
  )
end

return physics_bridge
```

### 3.4 LDtk Tilemap Integration

The engine already supports converting runtime-generated IntGrid data into rendered tiles and colliders via LDtk Lua bindings:

- `ldtk.apply_rules(gridTable, layerName)` → tile results `{tile_id, x, y, flip_x, flip_y}[]`
- `ldtk.build_colliders_from_grid(gridTable, worldName, physicsTag, solidValues)`

`assets/scripts/core/procgen/ldtk_bridge.lua` should be a thin conversion + convenience layer:

```lua
-- assets/scripts/core/procgen/ldtk_bridge.lua
local ldtk_bridge = {}

function ldtk_bridge.gridToIntGrid(grid)
  return {
    width = grid.w,
    height = grid.h,
    cells = grid:to_table(),
  }
end

function ldtk_bridge.applyRules(grid, layerName)
  local ldtk = _G.ldtk
  assert(ldtk and ldtk.apply_rules, "ldtk bindings not available")
  return ldtk.apply_rules(ldtk_bridge.gridToIntGrid(grid), layerName)
end

function ldtk_bridge.buildColliders(grid, opts)
  opts = opts or {}
  local ldtk = _G.ldtk
  assert(ldtk and ldtk.build_colliders_from_grid, "ldtk bindings not available")
  ldtk.build_colliders_from_grid(
    ldtk_bridge.gridToIntGrid(grid),
    opts.worldName or "world",
    opts.physicsTag or "WORLD",
    opts.solidValues or { 1 }
  )
end

function ldtk_bridge.cleanup()
  local ldtk = _G.ldtk
  if ldtk and ldtk.cleanup_procedural then
    ldtk.cleanup_procedural()
  end
end

return ldtk_bridge
```

### 3.5 AI System Integration

```lua
-- assets/scripts/core/procgen/influence.lua
local influence = {}

local vendor = require("core.procgen.vendor")
local Grid = vendor.Grid
local coords = require("core.procgen.coords")

-- Create influence map from entities
function influence.fromEntities(width, height, entities, opts)
  opts = opts or {}
  local grid = Grid(width, height, 0)
  local falloff = opts.falloff or 0.8
  local maxDist = opts.maxDistance or 10
  
  for _, entity in ipairs(entities) do
    local wx, wy = entity.x, entity.y  -- World coords
    local gx, gy = coords.worldToGrid(wx, wy)
    local strength = opts.getStrength and opts.getStrength(entity) or 1
    
    -- Flood fill influence with falloff
    influence.spreadFromPoint(grid, gx, gy, strength, falloff, maxDist)
  end
  
  return grid
end

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
      if current.x >= 1 and current.x <= grid.w and current.y >= 1 and current.y <= grid.h then
        local existing = grid:get(current.x, current.y) or 0
        grid:set(current.x, current.y, existing + current.str)

        local nextStr = current.str * falloff
        if nextStr > 0.01 then
          for _, dir in ipairs({{0,1}, {0,-1}, {1,0}, {-1,0}}) do
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

-- Query best position in influence map
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
```

---

## Part 4: Code Examples

### Example 1: Basic Cave Generation

```lua
local procgen = require("core.procgen")
local EntityBuilder = require("core.entity_builder")

-- Generate a cave using cellular automata
local cave = procgen.pattern()
  :square(80, 50)           -- 80x50 domain
  :sample(1500)             -- 1500 random seed points
  :automata("B5678/S45678", 30)  -- Cave CA rule, 30 iterations
  :keepLargest()            -- Remove small disconnected areas
  :build()

-- Convert to Grid (1-indexed) for game use: 1 = wall, 0 = floor
local grid = procgen.grid(80, 50, 1):build()
procgen.coords.patternToGrid(cave, grid, 0)

-- Spawn wall visuals (physics via LDtk colliders is recommended)
procgen.spawner.spawnAtGridValue(grid, 1, function(wx, wy)
  return EntityBuilder.new("wall_tile")
    :at(wx, wy)
    :build()
end, { tileSize = 16 })
```

### Example 2: BSP Dungeon with Room Graph

```lua
local procgen = require("core.procgen")
local EntityBuilder = require("core.entity_builder")

-- Generate dungeon
local result = procgen.dungeon(100, 80, {
  roomMinSize = 10,
  roomMaxSize = 25,
  maxRooms = 8
})
  :generateRooms()
  :connectRooms()
  :build()

-- result.rooms contains room data
for i, room in ipairs(result.rooms) do
  print(string.format("Room %d: (%d,%d) size %dx%d", 
    i, room.x, room.y, room.w, room.h))
end

-- Room graph for AI navigation
local roomGraph = result.graph
local path = roomGraph:shortest_path_bfs(result.rooms[1], result.rooms[#result.rooms])
print("Path from first to last room:", #path, "steps")

-- Spawn floor tiles
procgen.spawner.spawnAtGridValue(result.grid, 0, function(wx, wy)
  return EntityBuilder.new("floor")
    :at(wx, wy)
    :build()
end, { tileSize = 16 })
```

### Example 3: AI Influence Map

```lua
local procgen = require("core.procgen")
local influence = require("core.procgen.influence")

-- Get all enemies
local enemies = {}  -- Populate from ECS query

-- Create danger map
local dangerMap = influence.fromEntities(100, 100, enemies, {
  falloff = 0.7,
  maxDistance = 15,
  getStrength = function(enemy)
    return enemy.damage or 10
  end
})

-- Find safest position for player to retreat
local safeX, safeY = influence.findBest(dangerMap, "min")
local worldX, worldY = procgen.coords.gridToWorld(safeX, safeY, 16)
print("Safest retreat point:", worldX, worldY)
```

### Example 4: Spell AOE Pattern

```lua
local procgen = require("core.procgen")
local forma = procgen.forma

-- Create circular AOE
local center = forma.cell.new(50, 50)
local aoeRadius = 5
local aoePattern = forma.primitives.circle(aoeRadius):translate(center.x, center.y)

-- Get blocked cells (walls)
local walls = getCurrentWallPattern()  -- From tilemap

-- Actual affected area = AOE minus walls
local affectedArea = aoePattern - walls

-- Find enemies in affected area
local entitiesHit = {}
for cell in affectedArea:cells() do
  -- affectedArea cells are pattern coords (0-indexed)
  local wx, wy = procgen.coords.gridToWorld(cell.x + 1, cell.y + 1, 16)
  local entities = queryEntitiesAt(wx, wy)  -- ECS query
  for _, e in ipairs(entities) do
    if e:hasTag("enemy") then
      table.insert(entitiesHit, e)
    end
  end
end

-- Apply damage
for _, enemy in ipairs(entitiesHit) do
  enemy:takeDamage(spellDamage)
end
```

### Example 5: Procedural Forest with Poisson Distribution

```lua
local procgen = require("core.procgen")
local EntityBuilder = require("core.entity_builder")

-- Define forest area
local forestArea = procgen.pattern()
  :square(60, 40)
  :perlin(0.1, 2, {0.4})  -- Noise-based shape
  :build()

-- Spawn trees with natural spacing
local trees = procgen.spawner.spawnPoisson(forestArea, 4, function(wx, wy)
  local variants = {"tree_oak", "tree_pine", "tree_birch"}
  return EntityBuilder.new(variants[math.random(#variants)])
    :at(wx, wy)
    :build()
end, { tileSize = 16 })

print("Spawned", #trees, "trees")
```

### Example 6: Quest Dependencies (Directed) - Simple Adjacency Map

```lua
-- Graph.lua is undirected/unweighted; for prerequisites, use a directed structure
-- (or add a dedicated procgen.digraph wrapper in a later phase).
local prerequisites = {
  forest = { "intro" },
  cave = { "intro" },
  boss = { "forest", "cave" },
  epilogue = { "boss" },
}

local completed = {
  intro = true,
  forest = false,
  cave = false,
  boss = false,
  epilogue = false,
}

local function isQuestUnlockable(id)
  for _, req in ipairs(prerequisites[id] or {}) do
    if not completed[req] then
      return false
    end
  end
  return true
end

print("boss unlockable?", isQuestUnlockable("boss"))
```

### Example 7: Field of View Calculation

```lua
local procgen = require("core.procgen")
local forma = procgen.forma

-- Get player position
local playerX, playerY = player:getPosition()
local pgx, pgy = procgen.coords.worldToGrid(playerX, playerY, 16)

-- Get wall pattern
local wallPattern = getCurrentWallPattern()

-- Calculate visible area
local viewDistance = 12
-- worldToGrid returns 1-indexed grid coords; Forma patterns are 0-indexed
local playerCell = forma.cell.new(pgx - 1, pgy - 1)
local domain = forma.primitives.square(100, 100)  -- World bounds
local openSpace = domain - wallPattern

local visibleArea = forma.raycasting.cast_360(playerCell, openSpace, viewDistance)

-- Update fog of war
fogOfWarGrid:apply(function(g, x, y)
  if visibleArea:has_cell(x - 1, y - 1) then
    g:set(x, y, 2)  -- 2 = currently visible
  elseif g:get(x, y) == 2 then
    g:set(x, y, 1)  -- 1 = previously seen
  end
  -- 0 = never seen (default)
end)
```

### Example 8: Voronoi-Based Biome Distribution

```lua
local procgen = require("core.procgen")
local forma = procgen.forma

-- World domain
local worldSize = 200
local domain = forma.primitives.square(worldSize, worldSize)

-- Generate biome seed points with good spacing
local biomeSeeds = domain:sample_mitchell(forma.cell.euclidean, 8, 30)

-- Create Voronoi regions
local regions = forma.pattern.voronoi(biomeSeeds, domain, forma.cell.chebyshev)

-- Assign biome types to regions
local biomeTypes = {"forest", "desert", "swamp", "plains", "mountains", "tundra", "jungle", "volcanic"}

local biomeGrid = procgen.grid(worldSize, worldSize, 0):build()

for i = 1, regions:n_components() do
  local biomeType = biomeTypes[((i - 1) % #biomeTypes) + 1]
  local biomeId = i
  
  for cell in regions[i]:cells() do
    biomeGrid:set(cell.x + 1, cell.y + 1, biomeId)
  end
  
  print(string.format("Region %d: %s (%d cells)", i, biomeType, regions[i]:size()))
end
```

---

## Part 5: Implementation Phases

### Phase 1: Foundation (Week 1)

**Goal**: Vendor normalization + coordinate conventions

| Task | File | Dependencies | Priority |
|------|------|--------------|----------|
| Create procgen module structure | `assets/scripts/core/procgen/init.lua` | None | P0 |
| Normalize Graph/Grid/Forma imports | `assets/scripts/core/procgen/vendor.lua` | None | P0 |
| Implement coordinate bridge (1-indexed grid) | `assets/scripts/core/procgen/coords.lua` | vendor.lua | P0 |
| Add LDtk IntGrid helpers | `assets/scripts/core/procgen/ldtk_bridge.lua` | coords.lua | P1 |
| Re-export libs via procgen | `assets/scripts/core/procgen/init.lua` | vendor.lua | P0 |
| Basic unit tests | `assets/scripts/tests/test_procgen_coords.lua` | All above | P1 |

**Deliverable**: `require("core.procgen")` works; `procgen.coords` is consistent; `procgen.Grid`/`procgen.Graph`/`procgen.forma` are available without relying on globals.

### Phase 2: Core Builders (Week 2)

**Goal**: Builder pattern wrappers for each library

| Task | File | Dependencies | Priority |
|------|------|--------------|----------|
| GridBuilder implementation | `assets/scripts/core/procgen/grid_builder.lua` | Phase 1 | P0 |
| GraphBuilder implementation | `assets/scripts/core/procgen/graph_builder.lua` | Phase 1 | P0 |
| PatternBuilder implementation | `assets/scripts/core/procgen/pattern_builder.lua` | Phase 1 | P0 |
| Builder unit tests | `assets/scripts/tests/test_procgen_builders.lua` | All builders | P1 |
| Documentation comments | All builder files | All builders | P1 |

**Deliverable**: All three builders complete with fluent API

### Phase 3: System Bridges (Week 3)

**Goal**: Integration with ECS + LDtk (tile + colliders)

| Task | File | Dependencies | Priority |
|------|------|--------------|----------|
| Entity spawner | `assets/scripts/core/procgen/spawner.lua` | Phase 2 | P0 |
| LDtk bridge wrappers (rules + colliders) | `assets/scripts/core/procgen/ldtk_bridge.lua` | Phase 1 | P0 |
| Physics bridge (delegates to LDtk) | `assets/scripts/core/procgen/physics_bridge.lua` | LDtk bridge | P1 |
| Influence map utilities | `assets/scripts/core/procgen/influence.lua` | GridBuilder | P1 |
| Integration tests | `assets/scripts/tests/test_procgen_integration.lua` | All bridges | P1 |

**Deliverable**: Can generate an IntGrid at runtime, apply LDtk auto-rules, build colliders, and spawn entities from grid/patterns.

### Phase 4: High-Level Generators (Week 4)

**Goal**: Ready-to-use dungeon and terrain generators

| Task | File | Dependencies | Priority |
|------|------|--------------|----------|
| DungeonBuilder (BSP + corridors) | `assets/scripts/core/procgen/dungeon.lua` | Phase 3 | P0 |
| TerrainBuilder (biomes, heightmap) | `assets/scripts/core/procgen/terrain.lua` | Phase 3 | P1 |
| Cave generator preset | `assets/scripts/core/procgen/presets/cave.lua` | PatternBuilder | P1 |
| Example scene | `assets/scripts/examples/procgen_demo.lua` | All | P2 |

**Deliverable**: One-liner dungeon generation with full game integration

### Phase 5: Polish & Documentation (Week 5)

**Goal**: Production-ready, documented, tested

| Task | File | Dependencies | Priority |
|------|------|--------------|----------|
| Debug visualization | `assets/scripts/core/procgen/debug.lua` | All phases | P1 |
| API documentation | `docs/api/procgen_docs.md` | All phases | P1 |
| Performance profiling | N/A | All phases | P2 |
| Edge case handling | All files | All phases | P1 |
| README with examples | `docs/guides/procgen_guide.md` | All phases | P2 |

**Deliverable**: Complete, documented procgen system

---

## Part 6: Testing Strategy

### Standalone (Pure Lua) Tests

Use the repo’s built-in test runner (`assets/scripts/tests/test_runner.lua`) and place procgen tests under `assets/scripts/tests/`. Keep most procgen tests standalone-friendly (no engine-only globals like `registry` or `ldtk`).

Example: `assets/scripts/tests/test_procgen_coords.lua`

```lua
-- assets/scripts/tests/test_procgen_coords.lua
package.path = package.path .. ";./assets/scripts/?.lua"
package.path = package.path .. ";./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
t.reset()

local coords = require("core.procgen.coords")

t.describe("procgen.coords", function()
  t.it("worldToGrid returns 1-indexed coords", function()
    local gx, gy = coords.worldToGrid(0, 0, 16)
    t.expect(gx).to_be(1)
    t.expect(gy).to_be(1)
  end)

  t.it("gridToWorld returns cell center", function()
    local wx, wy = coords.gridToWorld(1, 1, 16)
    t.expect(wx).to_be(8)
    t.expect(wy).to_be(8)
  end)
end)

t.run()
```

Run standalone: `lua assets/scripts/tests/run_standalone.lua --filter procgen`

### Engine/Integration Tests

Some procgen bridges require engine-only bindings (C++ globals):

- `ldtk.apply_rules`, `ldtk.build_colliders_from_grid`
- ECS/physics integration via `registry`, physics world, etc.

Add an engine-only test (e.g. `assets/scripts/tests/test_procgen_ldtk_integration.lua`) that:

- Generates a small Grid, calls `ldtk_bridge.applyRules`, asserts tile results are non-empty.
- Calls `ldtk_bridge.buildColliders` and verifies it completes without errors.

### Visual Tests

- **Debug overlay**: Toggle to show grid cells, influence maps, room boundaries
- **Step-through mode**: Watch CA iterations visually
- **Diff view**: Compare generated vs expected output

---

## Part 7: Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| **Performance: Large grids slow** | Medium | High | Use Forma's spatial hashing; batch physics body creation; profile early |
| **Coordinate confusion** | High | Medium | Consistent 0-indexed vs 1-indexed; extensive tests; clear documentation |
| **Memory: Many small entities** | Medium | Medium | Object pooling; entity batching; LOD systems |
| **Forma CA non-convergence** | Low | Medium | Max iteration limits; fallback patterns; seeded RNG for reproducibility |
| **Graph limitations (undirected/unweighted)** | High | Medium | Scope Graph.lua usage to connectivity first; add `digraph`/weights only when needed |
| **Vendor import/globals mismatch** | Medium | High | Add `procgen/vendor.lua` normalization; constrain `_G.Object`/`_G.Graph`/`_G.Grid` usage to vendor.lua only |
| **LDtk bindings not available in standalone tests** | High | Low | Keep conversion logic standalone; guard integration calls behind `if _G.ldtk then ... end` |
| **LuaJIT 200 local limit** | Medium | Low | Use tables for large data; lazy require patterns |

### Mitigation Strategies

1. **Performance Profiling**: Add Tracy zones to all generation functions; benchmark with typical sizes
2. **Defensive Coding**: Assert preconditions; validate all inputs; provide clear error messages
3. **Incremental Rollout**: Feature flag new generators; A/B test with hand-made levels
4. **Vendor Normalization First**: Make Graph/Grid/Forma imports deterministic before building higher-level APIs
5. **Fallback Content**: If generation fails, load pre-made fallback level

---

## Appendix A: Quick Reference Card

```lua
-- IMPORTS
local procgen = require("core.procgen")

-- COORDINATE CONVERSION
local gx, gy = procgen.coords.worldToGrid(wx, wy, tileSize)
local wx, wy = procgen.coords.gridToWorld(gx, gy, tileSize)

-- GRID OPERATIONS
local grid = procgen.grid(w, h, default):fill(v):rect(x,y,w,h,v):build()
local islands = grid:flood_fill(value)

-- GRAPH OPERATIONS  
local gb = procgen.graph():node(id, data):edge(a, b)
local graph = gb:build()  -- Graph.lua is undirected/unweighted
local pathIds = gb:shortestPath("a", "b")

-- PATTERN OPERATIONS
local pattern = procgen.pattern():square(w,h):sample(n):automata(rule, iters):build()
for cell in pattern:cells() do ... end

-- DUNGEON GENERATION
local dungeon = procgen.dungeon(w, h, opts):generateRooms():connectRooms():build()
-- dungeon.grid, dungeon.graph, dungeon.rooms, dungeon.spawnPoints

-- ENTITY SPAWNING
procgen.spawner.spawnAtPattern(pattern, function(wx, wy) return entity end)
procgen.spawner.spawnPoisson(pattern, minDist, spawnFn)

-- LDtk TILE RULES + COLLIDERS (engine-only: requires _G.ldtk)
local ldtk_bridge = require("core.procgen.ldtk_bridge")
local tiles = ldtk_bridge.applyRules(grid, "TileLayer")
ldtk_bridge.buildColliders(grid, { worldName = "world", physicsTag = "WORLD", solidValues = { 1 } })

-- INFLUENCE MAPS
local influence = procgen.influence.fromEntities(w, h, entities, opts)
local bx, by = procgen.influence.findBest(grid, "min"|"max")
```

---

*Document Version: 1.1*
*Created: 2026-01-22*
*Status: PLAN - Ready for Implementation*
