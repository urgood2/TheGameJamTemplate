# LDTK Lua Integration Expansion Design

**Date:** 2025-12-09
**Status:** Approved
**Use Cases:** Connected worlds with door/signal transitions + procedural generation via auto-rules

---

## Overview

Expand the existing LDTK Lua integration to support:
1. Full entity field access (all LDtk field types)
2. Level neighbor queries for transitions
3. Procedural rule runner exposure
4. Helper functions and signals for orchestration

Approach: **Lua-First** — expose everything to Lua, let scripts handle orchestration. Fits existing signal/Node patterns.

---

## Section 1: Entity Field Access

### Current State
Spawner callback receives `(name, px, py, layerName, gx, gy, tags)` — no custom fields.

### Proposed Change
Spawner receives a rich `fields` table as 7th parameter:

```lua
function spawner(name, px, py, layerName, gx, gy, fields)
    -- fields.health        → 100 (int)
    -- fields.spawn_delay   → 2.5 (float)
    -- fields.dialog_key    → "intro" (string)
    -- fields.patrol_path   → {{x=10,y=20}, {x=50,y=20}} (point array)
    -- fields.target_door   → {entity_iid="abc123", level="Level_2"} (entity ref)
    -- fields.enemy_type    → "Goblin" (enum as string)
    -- fields.tint          → {r=255, g=128, b=0, a=255} (color)
end
```

### C++ Work
In `ForEachEntity`, extract `ent.getFields()` from LDtkLoader, convert each field type to sol2-compatible Lua tables.

### Integration Pattern
```lua
local EntityType = Node:extend()
local script = EntityType {}

-- Store LDtk fields in script table BEFORE attach_ecs
script.ldtk_fields = fields
script.health = fields.health or 100

script:attach_ecs { create_new = false, existing_entity = entity }
```

---

## Section 2: Level Neighbors & Transitions

### Proposed Lua API

```lua
-- Get neighbor data for a level
local neighbors = ldtk.get_neighbors("Level_0")
-- Returns:
-- {
--   north = "Level_1",  -- or nil if no neighbor
--   south = nil,
--   east = "Level_2",
--   west = nil,
--   overlap = {}  -- for free-form world layouts
-- }

-- Get level bounds (useful for edge detection)
local bounds = ldtk.get_level_bounds("Level_0")
-- Returns: { x = 0, y = 0, width = 400, height = 400 }
```

### Door Entity Pattern
In LDtk, create a `Door` entity with fields:
- `target_level` (string)
- `target_spawn` (entity ref or string ID)
- `requires_key` (string, optional)

Spawner creates interactive object:

```lua
function spawn_door(name, px, py, layerName, gx, gy, fields)
    local entity = animation_system.createAnimatedObjectWithTransform("door_sprite", true)

    local DoorType = Node:extend()
    local script = DoorType {}
    script.target_level = fields.target_level
    script.target_spawn = fields.target_spawn
    script:attach_ecs { create_new = false, existing_entity = entity }

    local nodeComp = registry:get(entity, GameObject)
    nodeComp.state.collisionEnabled = true
    nodeComp.methods.onCollision = function(_, other)
        signal.emit("door_entered", entity, {
            target_level = script.target_level,
            target_spawn = script.target_spawn,
            player = other
        })
    end
end
```

Global handler:

```lua
signal.register("door_entered", function(doorEntity, data)
    ldtk.set_active_level(data.target_level, "world", true, true)
    local spawn_pos = ldtk.get_entity_position(data.target_level, data.target_spawn)
    player_set_position(spawn_pos.x, spawn_pos.y)
end)
```

---

## Section 3: Procedural Rule Runner

### Proposed Lua API

```lua
-- Step 1: Create an IntGrid in Lua (procedural dungeon output)
local grid = {
    width = 20,
    height = 15,
    cells = {}  -- 1D array, row-major: cells[y * width + x + 1] = value
}

-- Fill procedurally
for y = 0, grid.height - 1 do
    for x = 0, grid.width - 1 do
        local idx = y * grid.width + x + 1
        grid.cells[idx] = is_wall(x, y) and 1 or 0
    end
end

-- Step 2: Apply LDtk auto-rules to produce tile output
local tiles = ldtk.apply_rules(grid, "TileLayer")
-- Returns:
-- {
--   width = 20, height = 15,
--   cells = {
--     [1] = {{tile_id = 7, flip_x = false, flip_y = false, alpha = 1.0}},
--     ...
--   }
-- }

-- Step 3: Build colliders from the IntGrid
ldtk.build_colliders_from_grid(grid, "world", "WORLD")

-- Step 4: Render tiles using command buffer (call every frame in update/draw)
ldtk.draw_all_procedural_layers("sprites", offsetX, offsetY, 0, 1.0)
-- Or render specific layers:
ldtk.draw_procedural_layer(0, "sprites", offsetX, offsetY, 0, 1.0)
```

### Rendering Workflow

Procedural rendering uses the same command buffer pattern as normal LDTK rendering:

1. **Queue Phase (Update)**: Call `draw_procedural_layer` or `draw_all_procedural_layers` to queue `CmdTexturePro` commands
2. **Execute Phase (Render)**: Commands are drawn when the layer system executes its command buffers

```lua
-- In your update loop:
function update_procedural_level(dt)
    -- Generate tiles once
    if not tiles then
        tiles = ldtk.apply_rules(grid, "TileLayer")
    end

    -- Render every frame (commands are queued, executed during render)
    ldtk.draw_all_procedural_layers("sprites", level_offset_x, level_offset_y)
end
```

### C++ Work
1. Expose `ldtk_rule_import::RunRules` with Lua-provided IntGrid
2. Create `Level` object from Lua table at runtime
3. Return tile results as nested Lua table
4. Add `DrawProceduralLayer` using existing layer command buffer (`layer::QueueCommand<CmdTexturePro>`)

---

## Section 4: Helper Functions & Signals

### Additional Lua API

```lua
-- Get entity position by IID (for entity references)
local pos = ldtk.get_entity_position("Level_0", "entity_iid_abc123")
-- Returns: { x = 128, y = 64 } or nil

-- Get all entities of a type (without spawning)
local spawns = ldtk.get_entities_by_name("Level_0", "EnemySpawn")
-- Returns: { {x=100, y=50, fields={...}}, ... }

-- Get level metadata
local meta = ldtk.get_level_meta("Level_0")
-- Returns: { width, height, bg_color, world_x, world_y, field_instances }

-- Check if level exists
local exists = ldtk.level_exists("Level_99")
```

### Signal Emission Support

Set up a signal emitter callback to receive LDTK events:

```lua
local signal = require("external.hump.signal")

-- Connect LDTK events to signal library
ldtk.set_signal_emitter(function(eventName, data)
    signal.emit(eventName, data)
end)

-- Use set_active_level_with_signals for automatic signal emission
ldtk.set_active_level_with_signals("Level_0", "world", true, true, "WORLD")

-- Or manually emit entity spawned signals from your spawner
ldtk.set_spawner(function(name, px, py, layerName, gx, gy, fields)
    -- Create entity...
    ldtk.emit_entity_spawned(name, px, py, layerName, { fields = fields })
end)
```

### Signals Emitted

| Signal | Parameters | When |
|--------|-----------|------|
| `ldtk_level_loaded` | `{level_name, world_name, colliders_built, entities_spawned}` | After `set_active_level_with_signals` completes |
| `ldtk_colliders_built` | `{level_name, world_name, physics_tag}` | After colliders generated (with signals) |
| `ldtk_entity_spawned` | `{entity_name, px, py, layer, extra}` | When `emit_entity_spawned` called |

---

## Section 5: Complete API Reference

### Entity Fields (enhanced spawner)
```lua
ldtk.set_spawner(function(name, px, py, layerName, gx, gy, fields) ... end)
```

### Level Queries
```lua
ldtk.get_neighbors(levelName)           -- → {north, south, east, west, overlap}
ldtk.get_level_bounds(levelName)        -- → {x, y, width, height}
ldtk.get_level_meta(levelName)          -- → {width, height, bg_color, world_x, world_y, field_instances}
ldtk.level_exists(levelName)            -- → bool
```

### Entity Queries
```lua
ldtk.get_entity_position(levelName, iid)           -- → {x, y} or nil
ldtk.get_entities_by_name(levelName, entityName)   -- → {{x, y, fields}, ...}
```

### Procedural Rule Runner
```lua
ldtk.apply_rules(gridTable, layerDefName)          -- → tileResultTable
ldtk.build_colliders_from_grid(gridTable, worldName, tag)
```

### Procedural Rendering (Command Buffer)
```lua
-- Draw a single procedural layer to a named layer command buffer
ldtk.draw_procedural_layer(
    layerIdx,           -- Layer index (0-based) from apply_rules result
    targetLayerName,    -- Command buffer layer name (e.g., "sprites")
    offsetX,            -- Optional: X offset in pixels (default: 0)
    offsetY,            -- Optional: Y offset in pixels (default: 0)
    zLevel,             -- Optional: Z-order for rendering (default: 0)
    opacity             -- Optional: Alpha multiplier 0.0-1.0 (default: 1.0)
)

-- Draw all procedural layers to a named layer command buffer
ldtk.draw_all_procedural_layers(
    targetLayerName,    -- Command buffer layer name (e.g., "sprites")
    offsetX,            -- Optional: X offset in pixels (default: 0)
    offsetY,            -- Optional: Y offset in pixels (default: 0)
    baseZLevel,         -- Optional: Starting Z-order (default: 0)
    opacity             -- Optional: Alpha multiplier 0.0-1.0 (default: 1.0)
)

-- Get tileset info for a layer (for custom rendering)
ldtk.get_tileset_info(layerIdx)
-- Returns: { tile_size = 16, width = 256, height = 256, image_path = "..." }
```

### Layer Queries
```lua
ldtk.get_layer_count()                    -- → number of layers
ldtk.get_layer_name(layerIdx)             -- → layer name string
ldtk.get_layer_type(layerIdx)             -- → "IntGrid", "AutoLayer", "Tiles", "Entities"
ldtk.get_layer_grid_size(layerIdx)        -- → tile size in pixels
```

---

## Implementation Order

1. **Entity field extraction** — unblocks door/spawn workflows
2. **Level neighbor queries** — unblocks transitions
3. **Entity query helpers** — unblocks spawn point lookup
4. **Rule runner exposure** — unblocks procedural generation
5. **Signal emissions** — polish

---

## Testing Strategy

1. Unit test: field extraction for all LDtk types
2. Integration test: load level, spawn door entity, verify fields accessible
3. Integration test: procedural grid → apply_rules → verify tile output
4. End-to-end: door transition between two levels
