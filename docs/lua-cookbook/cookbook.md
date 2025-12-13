---
title: Lua API Cookbook
---

# Quick Start

**New to the engine?** Here's how to create a game entity from scratch in 30 seconds.

```lua
-- 1. Load required modules
local Node = require("monobehavior.behavior_script_v2")
local animation_system = require("core.animation_system")
local component_cache = require("core.component_cache")
local physics = require("physics.physics_lua_api")
local PhysicsManager = require("core.physics_manager")

-- 2. Create an entity with a sprite
local entity = animation_system.createAnimatedObjectWithTransform(
    "kobold",  -- animation/sprite ID
    true       -- use animation (true) vs sprite identifier (false)
)

-- 3. Initialize script table for custom data (BEFORE attach_ecs!)
local EntityType = Node:extend()
local script = EntityType {}

-- Assign data to script table
script.health = 100
script.faction = "enemy"
script.customData = { damage = 10 }

-- Attach to entity (call LAST, after data assignment)
script:attach_ecs { create_new = false, existing_entity = entity }

-- 4. Position the entity
local transform = component_cache.get(entity, Transform)
if transform then
    transform.actualX = 100
    transform.actualY = 200
    transform.actualW = 64
    transform.actualH = 64
end

-- 5. Add physics (optional)
local config = {
    shape = "rectangle",
    tag = "enemy",
    sensor = false,
    density = 1.0,
    inflate_px = -4  -- shrink hitbox slightly
}
physics.create_physics_for_transform(
    registry,                -- global registry
    physics_manager_instance, -- global physics manager
    entity,
    "world",                 -- physics world identifier
    config
)

-- Update collision masks for this tag
local world = PhysicsManager.get_world("world")
physics.update_collision_masks_for(world, "enemy", { "player", "projectile" })

-- 6. Add interactivity (optional)
local nodeComp = registry:get(entity, GameObject)
nodeComp.state.clickEnabled = true
nodeComp.methods.onClick = function(reg, clickedEntity)
    print("Clicked entity:", clickedEntity)
    local script = getScriptTableFromEntityID(clickedEntity)
    if script then
        script.health = script.health - 10
        print("Health remaining:", script.health)
    end
end
```

**That's it!** The entity now:
- Renders with animation
- Stores custom data in its script table
- Has physics and collisions
- Responds to clicks

**Critical rules:**
1. Always assign data to script table BEFORE calling `attach_ecs()`
2. Always use `PhysicsManager.get_world("world")` instead of `globals.physicsWorld`
3. Always validate entities before use: `if not entity_cache.valid(entity) then return end`
4. Use `signal.emit()` for events, not `publishLuaEvent()`

\newpage

# Task Index

*Quick lookup: find what you need by task.*

| Task | Page |
|------|------|
| **Creating Things** | |
| Create entity with sprite | \pageref{recipe:entity-sprite} |
| Create entity with physics | \pageref{recipe:entity-physics} |
| Create interactive entity (hover/click) | \pageref{recipe:entity-interactive} |
| Initialize script table for data | \pageref{recipe:script-table} |
| **Movement & Physics** | |
| Add physics to existing entity | \pageref{recipe:add-physics} |
| Set collision tags and masks | \pageref{recipe:collision-masks} |
| Enable bullet mode for fast objects | \pageref{recipe:bullet-mode} |
| **Timers & Events** | |
| Delay an action | \pageref{recipe:timer-after} |
| Repeat an action | \pageref{recipe:timer-every} |
| Chain actions in sequence | \pageref{recipe:timer-sequence} |
| Emit and handle events | \pageref{recipe:signals} |
| **Rendering & Shaders** | |
| Add shader to entity | \pageref{recipe:add-shader} |
| Stack multiple shaders | \pageref{recipe:stack-shaders} |
| Draw text | \pageref{recipe:draw-text} |
| **UI** | |
| Create UI with DSL | \pageref{recipe:ui-dsl} |
| Add tooltip on hover | \pageref{recipe:tooltip} |
| Create grid layout | \pageref{recipe:ui-grid} |
| **Combat** | |
| Spawn projectile | \pageref{recipe:spawn-projectile} |
| Configure projectile behavior | \pageref{recipe:projectile-config} |
| **Cards & Wands** | |
| Define a new card | \pageref{recipe:define-card} |
| Define a joker | \pageref{recipe:define-joker} |
| **AI** | |
| Create AI entity | \pageref{recipe:ai-entity} |
| Define AI action | \pageref{recipe:ai-action} |

\newpage
