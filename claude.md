# Claude Code Practices for This Project

This document contains important coding patterns and practices specific to this game engine codebase.

---

## Lua Entity Script Table Pattern

### ✅ Correct: Use Node-Based Script Tables

When creating entities that need Lua data storage, you **must** initialize a script table using the Node monobehavior system:

**CRITICAL: Data must be assigned to the script table BEFORE calling `attach_ecs()`!**

```lua
local Node = require("monobehavior.behavior_script_v2")

-- Create entity
local entity = registry:create()

-- Initialize script table (REQUIRED for getScriptTableFromEntityID to work)
local EntityType = Node:extend()
local entityScript = EntityType {}

-- Assign data to script table FIRST (before attach_ecs)
entityScript.customData = { foo = "bar" }
entityScript.someValue = 42

-- Call attach_ecs LAST (after all data assignment)
entityScript:attach_ecs { create_new = false, existing_entity = entity }
```

### ❌ Wrong: Storing Data Directly in GameObject Component

```lua
-- DON'T DO THIS:
if not registry:has(entity, GameObject) then
    registry:emplace(entity, GameObject)
end
local gameObj = component_cache.get(entity, GameObject)
gameObj.customData = { foo = "bar" }  -- Wrong!
```

### ⚠️ CRITICAL: Initialization Order and Usage

**Data assignment MUST come BEFORE `attach_ecs()` call!**

The correct order is:
1. Create Node instance: `local script = EntityType {}`
2. Assign all data to script table: `script.data = ...`
3. Call `attach_ecs()` LAST: `script:attach_ecs {...}`

If you call `attach_ecs()` before assigning data, the data will not persist and will be lost!

**IMPORTANT: After calling `attach_ecs()`, use the script variable directly!**

Don't call `getScriptTableFromEntityID()` immediately after `attach_ecs()` - it may return nil. Instead, continue using the `script` variable you already have:

```lua
-- Initialize script table
local EntityType = Node:extend()
local entityScript = EntityType {}

-- Assign data
entityScript.someData = {...}

-- Attach to entity
entityScript:attach_ecs { create_new = false, existing_entity = entity }

-- ✅ CORRECT: Use entityScript directly
entityScript.someData.value = 100

-- ❌ WRONG: Don't call getScriptTableFromEntityID immediately after attach
local script = getScriptTableFromEntityID(entity)  -- May return nil!
script.someData.value = 100  -- Error!
```

### Why This Matters

- `getScriptTableFromEntityID(entity)` only works if the entity has a Node-based script attached via `attach_ecs()`
- Without script initialization, `getScriptTableFromEntityID()` returns `nil`
- The GameObject component already exists - you don't need to emplace it
- Data must be assigned BEFORE `attach_ecs()` for it to stick
- This pattern is used consistently throughout the codebase (see [gameplay.lua:600-602](assets/scripts/core/gameplay.lua#L600-L602))

### Retrieving Script Tables

```lua
-- Later, to retrieve the script table:
local entityScript = getScriptTableFromEntityID(entity)
if entityScript then
    print(entityScript.customData.foo)  -- "bar"
end
```

---

## Event System: Signal Library

### ✅ Correct: Use signal.emit()

```lua
local signal = require("external.hump.signal")

-- Emit an event
signal.emit("projectile_spawned", entity, {
    owner = ownerEntity,
    position = {x = 100, y = 200},
    damage = 50
})

-- Register event handler
signal.register("projectile_spawned", function(entity, data)
    print("Projectile spawned at", data.position.x, data.position.y)
end)
```

### ❌ Wrong: Using publishLuaEvent()

```lua
-- DON'T DO THIS:
publishLuaEvent("projectile_spawned", {
    entity = entity,
    owner = ownerEntity,
    position = {x = 100, y = 200}
})
```

### Signal Pattern

The signal library follows this convention:
- **First parameter**: The entity being acted upon
- **Second parameter**: Additional data table (optional)

This allows handlers to easily access both the entity and associated metadata.

### Examples from Codebase

See [gameplay.lua:3569-3625](assets/scripts/core/gameplay.lua#L3569-L3625) for examples:
```lua
signal.register("player_level_up", function()
    -- Handle level up
end)

signal.register("on_pickup", function(pickupEntity)
    -- Handle pickup collection
end)

signal.emit("on_bump_enemy", enemyEntity)
```

---

## Component Access Pattern

### Getting Components

```lua
local component_cache = require("core.component_cache")

-- Get a component from an entity
local transform = component_cache.get(entity, Transform)
if transform then
    transform.actualX = 100
    transform.actualY = 200
end
```

### Common Components

- **Transform**: Position, size, rotation (`actualX`, `actualY`, `actualW`, `actualH`, `actualR`)
- **GameObject**: Contains `state` and `methods` for interaction callbacks
- **StateTag**: Game state management (see entity_gamestate_management)

---

## Entity Validation

### Always Validate Entities

```lua
local entity_cache = require("core.entity_cache")

-- Check if entity is valid before using
if not entity_cache.valid(entity) then
    return
end

-- Check if entity is active (not just valid)
if not entity_cache.active(entity) then
    return
end
```

---

## Physics Integration

### ✅ Getting the Physics World

**Always use `PhysicsManager.get_world("world")` instead of `globals.physicsWorld`:**

```lua
local PhysicsManager = require("core.physics_manager")

-- Get the physics world
local world = PhysicsManager.get_world("world")
if not world then
    log_warn("Physics world not available")
    return
end
```

### ❌ Wrong: Using globals.physicsWorld

```lua
-- DON'T DO THIS:
if physics and globals.physicsWorld then
    physics.create_physics_for_transform(globals.physicsWorld, entity, "dynamic")
end
```

### Setting Up Physics Bodies

**Correct signature for `create_physics_for_transform`:**

```lua
local world = PhysicsManager.get_world("world")

-- Create physics body using correct signature
local config = {
    shape = "circle",  -- or "rectangle", "polygon", "chain"
    tag = "projectile",
    sensor = false,
    density = 1.0
}

physics.create_physics_for_transform(
    registry,                    -- global registry
    physics_manager_instance,    -- global physics_manager instance
    entity,
    "world",                     -- world name
    config
)

-- Set additional physics properties
physics.SetBullet(world, entity, true)  -- High-speed collision detection
physics.SetFriction(world, entity, 0.0)
physics.SetRestitution(world, entity, 0.5)
physics.SetFixedRotation(world, entity, true)  -- Lock rotation
```

### ❌ Wrong: Old API signature

```lua
-- DON'T DO THIS:
physics.create_physics_for_transform(world, entity, "dynamic")
physics.AddCollider(world, entity, tag, "circle", radius, ...)
```

### Physics Sync Modes

When using physics bodies, set the sync mode using the correct API:

```lua
-- ✅ CORRECT: Use set_sync_mode (matches gameplay.lua)
physics.set_sync_mode(registry, entity, physics.PhysicsSyncMode.AuthoritativePhysics)
```

### ❌ Wrong: Manual PhysicsSyncConfig

```lua
-- DON'T DO THIS:
local PhysicsSyncConfig = {
    mode = "AuthoritativePhysics",
    pullPositionFromPhysics = true,
    -- ...
}
registry:emplace(entity, "PhysicsSyncConfig", PhysicsSyncConfig)
```

### Setting Up Collision Masks (Per-Entity)

Collision masks are set **per entity** when creating physics bodies, not globally in init:

```lua
local world = PhysicsManager.get_world("world")

-- Enable collisions between this entity's tag and other tags
physics.enable_collision_between_many(world, "projectile", { "enemy" })
physics.enable_collision_between_many(world, "enemy", { "projectile" })

-- Update collision masks for both tags
physics.update_collision_masks_for(world, "projectile", { "enemy" })
physics.update_collision_masks_for(world, "enemy", { "projectile" })
```

### ❌ Wrong: Setting global collision tags in init

```lua
-- DON'T DO THIS in system initialization:
function ProjectileSystem.init()
    physics.set_collision_tags(world, {"projectile", "enemy", "player"})
    physics.enable_collision_between(world, "projectile", "enemy")
end
```

**Why:** Collision masks are entity-specific. Set them when creating each entity's physics body.

---

## Animation System

### Creating Animated Entities

```lua
local animation_system = require("core.animation_system")

-- Create entity with animated sprite
local entity = animation_system.createAnimatedObjectWithTransform(
    "sprite_animation_id",  -- animation ID
    true                     -- use animation (not sprite identifier)
)

-- Resize animation to fit transform
animation_system.resizeAnimationObjectsInEntityToFit(
    entity,
    width,
    height
)
```

---

## Timer System

### Using Timers

```lua
local timer = require("core.timer")

-- One-shot timer
timer.after(2.0, function()
    print("2 seconds elapsed")
end)

-- Repeating timer
timer.every(1.0, function()
    print("Every second")
end)

-- Physics step timer (if available)
if timer.every_physics_step then
    timer.every_physics_step(function(dt)
        -- Update synchronized with physics
    end)
end
```

---

## GameObject Callbacks

### Setting Up Entity Interaction

```lua
-- Get GameObject component (already exists on entities)
local nodeComp = registry:get(entity, GameObject)
local gameObjectState = nodeComp.state

-- Enable interaction modes
gameObjectState.hoverEnabled = true
gameObjectState.collisionEnabled = true
gameObjectState.clickEnabled = true
gameObjectState.dragEnabled = true

-- Set callbacks
nodeComp.methods.onClick = function(registry, clickedEntity)
    print("Clicked entity:", clickedEntity)
end

nodeComp.methods.onHover = function()
    print("Hovering over entity")
end

nodeComp.methods.onDrag = function()
    print("Dragging entity")
end

nodeComp.methods.onStopDrag = function()
    print("Stopped dragging")
end
```

---

## State Tags

### Managing Entity States

```lua
-- Add state tag to entity
add_state_tag(entity, PLANNING_STATE)

-- Remove default state tag
remove_default_state_tag(entity)

-- Check if state is active
if is_state_active(PLANNING_STATE) then
    -- Do something
end

-- Activate/deactivate states
activate_state(PLANNING_STATE)
deactivate_state(PLANNING_STATE)
```

---

## Common Mistakes to Avoid

### ❌ Don't: Emplace GameObject
```lua
-- GameObject already exists on entities created via animation_system
if not registry:has(entity, GameObject) then
    registry:emplace(entity, GameObject)  -- Not needed!
end
```

### ❌ Don't: Store Data in Component Cache
```lua
-- This bypasses the script table system
local gameObj = component_cache.get(entity, GameObject)
gameObj.myData = {}  -- Don't do this
```

### ❌ Don't: Use getScriptTableFromEntityID Without Initialization
```lua
local entity = registry:create()
local script = getScriptTableFromEntityID(entity)  -- Returns nil!
script.data = {}  -- Crash!
```

### ✅ Do: Initialize Script Table with Correct Order
```lua
local entity = registry:create()
local EntityType = Node:extend()
local script = EntityType {}

-- Assign data BEFORE attach_ecs
script.data = {}
script.someValue = 42

-- Call attach_ecs LAST
script:attach_ecs { create_new = false, existing_entity = entity }
-- Now getScriptTableFromEntityID(entity) works!
```

---

## Complete Entity Creation Example

Combining all patterns for a fully-functional entity:

```lua
local Node = require("monobehavior.behavior_script_v2")
local signal = require("external.hump.signal")
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")
local animation_system = require("core.animation_system")

function createCustomEntity(x, y)
    -- Create entity with sprite
    local entity = animation_system.createAnimatedObjectWithTransform(
        "my_sprite_animation",
        true
    )

    -- Initialize script table and assign data BEFORE attach_ecs
    local EntityType = Node:extend()
    local entityScript = EntityType {}

    -- Store custom data in script table FIRST
    entityScript.customValue = 100
    entityScript.health = 50

    -- Call attach_ecs LAST
    entityScript:attach_ecs { create_new = false, existing_entity = entity }

    -- Set position
    local transform = component_cache.get(entity, Transform)
    if transform then
        transform.actualX = x
        transform.actualY = y
        transform.actualW = 32
        transform.actualH = 32
    end

    -- Enable interactions
    local nodeComp = registry:get(entity, GameObject)
    nodeComp.state.clickEnabled = true
    nodeComp.methods.onClick = function()
        entityScript.health -= 10
        signal.emit("entity_damaged", entity, { damage = 10 })
    end

    -- Add physics
    physics.create_physics_for_transform(globals.physicsWorld, entity, "dynamic")
    physics.AddCollider(globals.physicsWorld, entity, MY_COLLISION_CATEGORY,
        "circle", 16, 0, 0, 0, false)

    -- Emit creation event
    signal.emit("entity_created", entity, { type = "custom" })

    return entity
end
```

---

## References

- **Card Creation**: [gameplay.lua:577-1034](assets/scripts/core/gameplay.lua#L577-L1034)
- **Signal Usage**: [gameplay.lua:3569-3625](assets/scripts/core/gameplay.lua#L3569-L3625)
- **Projectile System**: [assets/scripts/combat/projectile_system.lua](assets/scripts/combat/projectile_system.lua)

---

**Last Updated**: 2025-11-21
**Context**: Critical ordering requirement for script table initialization - data assignment MUST come before `attach_ecs()`
