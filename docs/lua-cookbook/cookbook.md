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
| Synchronize with physics steps | \pageref{recipe:timer-physics} |
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

**Note:** These are proposed wrapper patterns from CLAUDE.md, not actual functions. Use the standard `timer.after()` and `timer.every()` shown above.

**When to use:** Clearer than positional parameters for complex timers.

```lua
local timer = require("core.timer")

-- After with options (PROPOSED PATTERN - not implemented)
timer.after_opts({
    delay = 2.0,
    action = function() print("done") end,
    tag = "my_timer",
    group = "gameplay"
})

-- Every with options (PROPOSED PATTERN - not implemented)
timer.every_opts({
    delay = 0.5,
    action = updateHealth,
    times = 10,           -- 0 = infinite
    immediate = true,     -- run once immediately
    tag = "health_update",
    group = "gameplay"
})

-- Cooldown (PROPOSED PATTERN - not implemented)
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

# Entity Creation

This chapter covers how to create and configure game entities with sprites, data, interactivity, and physics.

## Create Entity with Sprite

\label{recipe:entity-sprite}

**When to use:** Every time you need a visible game object (characters, items, UI elements).

```lua
local animation_system = require("core.animation_system")
local component_cache = require("core.component_cache")

-- Create entity with sprite
local entity = animation_system.createAnimatedObjectWithTransform(
    "kobold",  -- animation/sprite ID from assets
    true       -- true = use animation, false = sprite identifier
)

-- Position and size the entity
local transform = component_cache.get(entity, Transform)
if transform then
    transform.actualX = 100
    transform.actualY = 200
    transform.actualW = 64
    transform.actualH = 64
end

-- Resize to fit specific dimensions
animation_system.resizeAnimationObjectsInEntityToFit(
    entity,
    64,  -- width
    64   -- height
)
```

*— from core/animation_system.lua (C++ binding), usage in core/gameplay.lua:1509-1512*

**Real usage example:**

```lua
-- From core/gameplay.lua:1509
local card = animation_system.createAnimatedObjectWithTransform(
    imageToUse, -- animation ID
    true        -- use animation, not sprite identifier
)

-- From core/entity_factory.lua:787
e = animation_system.createAnimatedObjectWithTransform(
    globals.currencies[currencyName].anim,
    false,
    x,
    y,
    nil,  -- shader pass
    true  -- shadow
)
```

**Gotcha:** `createAnimatedObjectWithTransform()` creates the entity AND adds Transform, GameObject, and animation components automatically. Don't manually emplace these!

---

## Initialize Script Table

\label{recipe:script-table}

**When to use:** Store custom data on an entity (health, state, timers, etc.).

**CRITICAL:** Data must be assigned to the script table BEFORE calling `attach_ecs()`. This is the #1 mistake developers make.

```lua
local Node = require("monobehavior.behavior_script_v2")

-- Create entity first
local entity = animation_system.createAnimatedObjectWithTransform("kobold", true)

-- Initialize script table
local EntityType = Node:extend()
local script = EntityType {}

-- Assign data BEFORE attach_ecs
script.health = 100
script.faction = "enemy"
script.customData = { damage = 10, speed = 200 }

-- Call attach_ecs LAST
script:attach_ecs { create_new = false, existing_entity = entity }

-- Now you can retrieve it elsewhere
local retrievedScript = getScriptTableFromEntityID(entity)
print(retrievedScript.health)  -- 100
```

*— from monobehavior/behavior_script_v2.lua:83-116, usage in core/gameplay.lua:1519-1535*

**Real usage example:**

```lua
-- From core/gameplay.lua:1519
local CardType = Node:extend()
local cardScript = CardType {}

-- Assign data BEFORE attach_ecs
cardScript.category = category
cardScript.cardID = id or "unknown"
cardScript.selected = false
cardScript.skewSeed = math.random() * 10000

-- Apply card definition properties
WandEngine.apply_card_properties(cardScript, WandEngine.card_defs[id] or {})

-- THEN attach (happens later in the function at line 1600)
cardScript:attach_ecs { create_new = false, existing_entity = card }
```

**Gotcha:** If you call `attach_ecs()` before assigning data, the data will not persist! Always assign FIRST, attach LAST.

**Gotcha:** Don't call `getScriptTableFromEntityID()` immediately after `attach_ecs()` — it may return nil. Use the script variable you already have instead.

---

## Script Table with Update Loop

**When to use:** Entity needs per-frame logic.

```lua
local Node = require("monobehavior.behavior_script_v2")

local EntityType = Node:extend()

-- Define update function (called every frame)
function EntityType:update(dt)
    self.age = (self.age or 0) + dt

    -- Access entity via self._eid
    local transform = component_cache.get(self._eid, Transform)
    if transform then
        transform.actualX = transform.actualX + self.speed * dt
    end
end

-- Create instance
local script = EntityType {
    speed = 100,
    age = 0
}

script:attach_ecs { create_new = false, existing_entity = entity }
```

*— from monobehavior/behavior_script_v2.lua:214-249*

**Real usage example:**

```lua
-- From core/gameplay.lua:2224
function PulseObjectType:update(dt)
    self.age = self.age + dt
    local alpha = 1.0 - Easing.outQuart.f(math.min(1.0, self.age / self.lifetime))
    local scale = 1.0 + addedScaleAmount * Easing.outQuart.f(math.min(1.0, self.age / self.lifetime))
    -- ... update visuals
end
```

**Gotcha:** The update function is ONLY called if the entity has an active state tag matching the current game state. See "Managing State Tags" below.

---

## Add Interactivity (Hover/Click)

\label{recipe:entity-interactive}

**When to use:** Make entities respond to mouse input.

```lua
-- Get GameObject component (already exists on entities created via animation_system)
local nodeComp = registry:get(entity, GameObject)
local gameObjectState = nodeComp.state

-- Enable interaction modes
gameObjectState.hoverEnabled = true
gameObjectState.clickEnabled = true
gameObjectState.dragEnabled = true
gameObjectState.collisionEnabled = true

-- Set callbacks
nodeComp.methods.onClick = function(registry, clickedEntity)
    print("Clicked!", clickedEntity)
    local script = getScriptTableFromEntityID(clickedEntity)
    if script then
        script.health = script.health - 10
    end
end

nodeComp.methods.onHover = function()
    print("Hovering")
    -- Show tooltip, highlight, etc.
end

nodeComp.methods.onStopHover = function()
    print("Stopped hovering")
end

nodeComp.methods.onDrag = function()
    print("Dragging")
end

nodeComp.methods.onStopDrag = function()
    print("Stopped dragging")
end
```

*— GameObject component C++ binding, usage in core/gameplay.lua:2028-2038*

**Real usage example:**

```lua
-- From core/gameplay.lua:2028
nodeComp.methods.onClick = function(registry, clickedEntity)
    cardScript.selected = not cardScript.selected
    nodeComp.state.isBeingFocused = cardScript.selected
end

nodeComp.methods.onHover = function()
    local hoveredCardScript = getScriptTableFromEntityID(card)
    if not hoveredCardScript then return end
    -- Show card tooltip...
end
```

**Gotcha:** Don't emplace GameObject — it's already created by `createAnimatedObjectWithTransform()`.

**Gotcha:** Enable the interaction modes (`clickEnabled`, `hoverEnabled`, etc.) or callbacks won't fire!

---

## Add State Tags

**When to use:** Control when entities are active/visible based on game state (planning vs action phase, shop screen, etc.).

```lua
-- Add entity to specific game states
add_state_tag(entity, PLANNING_STATE)
add_state_tag(entity, ACTION_STATE)

-- Remove default state tag if needed
remove_default_state_tag(entity)

-- Check if state is active
if is_state_active(PLANNING_STATE) then
    -- Do something
end

-- Activate/deactivate states globally
activate_state(PLANNING_STATE)
deactivate_state(ACTION_STATE)
```

*— Global functions (C++ bindings), usage in core/gameplay.lua:1515-1516*

**Real usage example:**

```lua
-- From core/gameplay.lua:1515
add_state_tag(card, gameStateToApply or PLANNING_STATE)
remove_default_state_tag(card)

-- From core/gameplay.lua:886
if is_state_active(PLANNING_STATE) then
    add_state_tag(cardEntityID, PLANNING_STATE)
end
```

**Gotcha:** Entities without active state tags won't render or update. By default, entities get a DEFAULT state tag. Use `remove_default_state_tag()` if you want explicit state control.

---

## Script Table with Auto-Destroy

**When to use:** Create temporary entities that destroy themselves after a condition (timer, distance, etc.).

```lua
local Node = require("monobehavior.behavior_script_v2")

local EffectType = Node:extend()

EffectType.lifetime = 2.0
EffectType.age = 0.0

function EffectType:update(dt)
    self.age = self.age + dt
    -- ... update effect visuals
end

-- Create instance
local effect = EffectType {}
effect:attach_ecs { create_new = true }

-- Auto-destroy when condition is met
effect:destroy_when(function(self, eid)
    return self.age >= self.lifetime
end)
```

*— from monobehavior/behavior_script_v2.lua:134-211, usage in core/gameplay.lua:2440*

**Real usage example:**

```lua
-- From core/gameplay.lua:2440
fireMarkNode:attach_ecs { create_new = true }
fireMarkNode:destroy_when(function(self, eid)
    return self.age >= self.lifetime
end)
```

**Advanced options:**

```lua
effect:destroy_when(condition, {
    interval = 0.1,   -- check every 0.1s (0 = every frame)
    grace = 0.5,      -- wait 0.5s after condition before destroying
    timeout = 10.0,   -- cancel watcher after 10s (no destroy)
    tag = "effect_cleanup"
})
```

**Gotcha:** The watcher timer is automatically cancelled if the entity is destroyed externally.

---

## Chainable Script Setup

**When to use:** Fluent API for configuring entities in one statement.

```lua
local Node = require("monobehavior.behavior_script_v2")

local EntityType = Node:extend()

function EntityType:update(dt)
    self.age = (self.age or 0) + dt
end

-- Chainable pattern
local script = EntityType { health = 100, age = 0 }
    :attach_ecs { create_new = true }
    :addStateTag(PLANNING_STATE)
    :addStateTag(ACTION_STATE)
    :destroy_when(function(self, eid) return self.age >= 5.0 end)
```

*— from monobehavior/behavior_script_v2.lua:252-266, usage in core/gameplay.lua:1183-1188*

**Real usage example:**

```lua
-- From core/gameplay.lua:1183
local transition = TransitionType {}
    :attach_ecs { create_new = true }
    :addStateTag(PLANNING_STATE)
    :addStateTag(ACTION_STATE)
    :addStateTag(SHOP_STATE)
    :destroy_when(function(self, eid) return self.age >= self.duration end)
```

**Gotcha:** All chainable methods return `self`, so order matters. Always call `:attach_ecs()` before methods that need the entity ID.

---

## Pure Script Entities (No Graphics)

**When to use:** Logic-only entities (timers, state managers, controllers).

```lua
local Node = require("monobehavior.behavior_script_v2")

local ManagerType = Node:extend()

ManagerType.timer = 0

function ManagerType:update(dt)
    self.timer = self.timer + dt
    if self.timer >= 1.0 then
        print("Tick")
        self.timer = 0
    end
end

-- Create entity without sprite
local manager = ManagerType {}
manager:attach_ecs { create_new = true }
manager:addStateTag(PLANNING_STATE)
```

*— from monobehavior/behavior_script_v2.lua:83-116*

**Gotcha:** These entities have no Transform or visual components. Use them for logic only.

---

## Complete Entity Creation Pattern

**When to use:** Full-featured game entity with sprite, data, interactivity, and lifecycle.

```lua
local Node = require("monobehavior.behavior_script_v2")
local animation_system = require("core.animation_system")
local component_cache = require("core.component_cache")

function createEnemy(x, y)
    -- 1. Create entity with sprite
    local entity = animation_system.createAnimatedObjectWithTransform("kobold", true)

    -- 2. Initialize script table and assign data BEFORE attach_ecs
    local EnemyType = Node:extend()
    local script = EnemyType {}

    script.health = 100
    script.maxHealth = 100
    script.faction = "enemy"
    script.damage = 10

    -- 3. Attach script LAST
    script:attach_ecs { create_new = false, existing_entity = entity }

    -- 4. Position entity
    local transform = component_cache.get(entity, Transform)
    if transform then
        transform.actualX = x
        transform.actualY = y
        transform.actualW = 64
        transform.actualH = 64
    end

    -- 5. Add interactivity
    local nodeComp = registry:get(entity, GameObject)
    nodeComp.state.clickEnabled = true
    nodeComp.methods.onClick = function(reg, clickedEntity)
        local s = getScriptTableFromEntityID(clickedEntity)
        if s then
            s.health = s.health - 10
            if s.health <= 0 then
                registry:destroy(clickedEntity)
            end
        end
    end

    -- 6. Add to appropriate game state
    add_state_tag(entity, ACTION_STATE)

    return entity
end
```

*— Combined pattern from core/gameplay.lua:1509-1600, core/entity_factory.lua:38-196*

**Gotcha:** Follow the order: Create → Script Setup → Attach → Position → Interactivity → State Tags.

\newpage
