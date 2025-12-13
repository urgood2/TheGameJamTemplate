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

# Core Foundations

This chapter covers the fundamental systems you'll use in almost every script.

## Requiring Modules

\label{recipe:require-module}

**When to use:** Every script needs to import dependencies.

```lua
-- Standard require pattern
local timer = require("core.timer")
local signal = require("external.hump.signal")
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")
```

*— Path convention: dots for directories, matches filesystem under assets/scripts/*

**Gotcha:** Don't use `require("assets.scripts.core.timer")` — paths are relative to assets/scripts/.

---

## Validating Entities

\label{recipe:validate-entity}

**When to use:** Before accessing any entity, especially in callbacks or delayed code.

```lua
local entity_cache = require("core.entity_cache")

-- Check if entity reference is valid
if not entity_cache.valid(entity) then
    return  -- Entity was destroyed
end

-- Check if entity is active (valid + not disabled)
if not entity_cache.active(entity) then
    return
end
```

*— from core/entity_cache.lua:60-72*

### Global Helpers (Preferred)

```lua
-- Shorter syntax available globally after util.lua loads
if not ensure_entity(eid) then return end

-- For entities that must have scripts
if not ensure_scripted_entity(eid) then return end
```

*— from util/util.lua:64-72*

**Gotcha:** Always validate in callbacks — the entity may have been destroyed between when you scheduled the callback and when it runs.

**Real usage example:**

```lua
-- From ui/level_up_screen.lua:76
if ctx and ctx.playerEntity and entity_cache.valid(ctx.playerEntity) then
    -- Safe to use playerEntity
end

-- From core/gameplay.lua:1339
if ensure_entity(globals.inputState.cursor_hovering_target) then
    -- Entity is valid
end
```

---

## Getting Components

\label{recipe:get-component}

**When to use:** Access Transform, GameObject, or any ECS component.

```lua
local component_cache = require("core.component_cache")

-- Get component (returns nil if missing)
local transform = component_cache.get(entity, Transform)
if transform then
    transform.actualX = 100
    transform.actualY = 200
    transform.actualW = 64
    transform.actualH = 64
    transform.actualR = 0  -- rotation in radians
end

-- Common components
local gameObj = component_cache.get(entity, GameObject)
local animComp = component_cache.get(entity, AnimationQueueComponent)
```

*— from core/component_cache.lua:87-132*

**Gotcha:** Component names are globals (Transform, GameObject, etc.) — don't quote them.

**Real usage example:**

```lua
-- From ui/ui_defs.lua:1197
local animComp = component_cache.get(icon, AnimationQueueComponent)

-- From ui/avatar_joker_strip.lua:79
local go = component_cache.get(entity, GameObject)
```

---

## Timer: Delayed Action

\label{recipe:timer-after}

**When to use:** Run code after a delay.

```lua
local timer = require("core.timer")

-- Basic delay (seconds)
timer.after(2.0, function()
    print("2 seconds elapsed")
end)

-- With tag (for cancellation)
timer.after(2.0, function()
    print("done")
end, "my_timer")

-- Cancel by tag
timer.cancel("my_timer")
```

*— from core/timer.lua:83-93*

**Real usage example:**

```lua
-- From core/gameplay.lua:1128
timer.after(duration * 0.05, function()
    -- Delayed animation step
end)

-- From core/main.lua:384
timer.after(
    0.2,
    function()
        -- Delayed initialization
    end
)
```

---

## Timer: Repeating Action

\label{recipe:timer-every}

**When to use:** Run code repeatedly at intervals.

```lua
local timer = require("core.timer")

-- Basic repeat (runs forever)
timer.every(1.0, function()
    print("Every second")
end)

-- With limited iterations
timer.every(
    0.5,             -- delay
    function()       -- action
        print("tick")
    end,
    10,              -- times (0 = infinite)
    false,           -- immediate (run once now)
    function()       -- after (callback when done)
        print("finished")
    end,
    "my_timer"       -- tag
)
```

*— from core/timer.lua:112-128*

**Real usage example:**

```lua
-- From ui/ui_defs.lua:717
timer.every(1, function()
    -- Update UI every second
end)

-- From core/gameplay.lua:2175
timer.every(0.016, function()
    -- Update every frame (~60fps)
end)
```

**Gotcha:** If `times` is 0 or nil, the timer runs forever until cancelled.

---

## Timer: Physics Step

\label{recipe:timer-physics}

**When to use:** Synchronize code with physics simulation steps.

```lua
local timer = require("core.timer")

-- Run every physics step
timer.every_physics_step(function()
    print("Physics tick:", physicsTickCounter)
end)

-- Run on next physics step only
timer.on_new_physics_step(function()
    physics.ApplyImpulse(world, eid, 100, 0)
end)

-- Cancel physics step timer
timer.cancel_physics_step("my_physics_timer")
```

*— from core/timer.lua:508-531*

**Gotcha:** Physics step timers are separate from regular timers. Use `cancel_physics_step()`, not `cancel()`.

---

## Signals: Emit Event

\label{recipe:signals}

**When to use:** Decouple systems via pub/sub events.

```lua
local signal = require("external.hump.signal")

-- Emit event (first param: entity, second: data table)
signal.emit("projectile_spawned", entity, {
    owner = ownerEntity,
    position = { x = 100, y = 200 },
    damage = 50
})

-- Emit simple event
signal.emit("player_level_up")
signal.emit("on_bump_enemy", enemyEntity)
```

*— from external/hump/signal.lua:41-45, usage in core/gameplay.lua:101*

**Real usage example:**

```lua
-- From core/gameplay.lua:101
signal.emit("spell_type_discovered", { spell_type = "Twin Cast" })

-- From ui/test_cast_feed_discoveries.lua:14
signal.emit("on_spell_cast", {
    damage = 150,
    tags = { Fire = true, AoE = true }
})
```

---

## Signals: Handle Event

```lua
local signal = require("external.hump.signal")

-- Register handler
signal.register("projectile_spawned", function(entity, data)
    print("Projectile at", data.position.x, data.position.y)
end)

-- Handler with just entity
signal.register("on_bump_enemy", function(enemyEntity)
    -- React to collision
end)
```

*— from external/hump/signal.lua:36-39*

**Gotcha:** Use `signal.emit()`, NOT `publishLuaEvent()` (deprecated).

---

## Safe Script Table Access

\label{recipe:safe-script}

**When to use:** Access script data without crashing on nil.

```lua
-- Safe get (returns nil if missing)
local script = safe_script_get(eid)

-- Safe get with warning log
local script = safe_script_get(eid, true)

-- Get field with default value
local health = script_field(eid, "health", 100)
```

*— from util/util.lua:39-57*

**Real implementation:**

```lua
-- From util/util.lua:39
function safe_script_get(eid, warn_on_nil)
    local script = getScriptTableFromEntityID(eid)
    if not script and warn_on_nil then
        log_debug(("safe_script_get: Script table missing for entity %s"):format(tostring(eid)))
    end
    return script
end

-- From util/util.lua:52
function script_field(eid, field, default)
    local script = getScriptTableFromEntityID(eid)
    if not script then return default end
    local value = script[field]
    if value == nil then return default end
    return value
end
```

---

## Common Pattern: Defensive Entity Access

**When to use:** Start of any entity operation.

```lua
-- Standard pattern for any entity operation
if not ensure_entity(eid) then return end

local script = safe_script_get(eid)
if not script then return end

local transform = component_cache.get(eid, Transform)
if not transform then return end

-- Now safe to use eid, script, transform
```

**Real usage example:**

```lua
-- From ui/avatar_joker_strip.lua:144
if not ensure_entity(entity) then
    return
end
local go = component_cache.get(entity, GameObject)
-- ... use go safely
```

---

## Timer Options API (Advanced)

**When to use:** Clearer than positional parameters for complex timers.

```lua
local timer = require("core.timer")

-- After with options
timer.after_opts({
    delay = 2.0,
    action = function() print("done") end,
    tag = "my_timer",
    group = "gameplay"
})

-- Every with options
timer.every_opts({
    delay = 0.5,
    action = updateHealth,
    times = 10,           -- 0 = infinite
    immediate = true,     -- run once immediately
    tag = "health_update",
    group = "gameplay"
})

-- Cooldown (only runs when condition is true)
timer.cooldown_opts({
    delay = 1.0,
    condition = function() return canAttack end,
    action = doAttack,
    times = 3,
    tag = "attack_cd"
})
```

*— Note: These are wrapper functions around timer.after/every/cooldown with named parameters*

**Gotcha:** Options API uses table syntax. Don't forget the curly braces!

\newpage
