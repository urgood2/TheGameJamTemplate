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
| Create entity with physics | \pageref{recipe:add-physics} |
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
| Configure projectile behavior | \pageref{recipe:projectile-preset} |
| **Cards & Wands** | |
| Define action card | \pageref{recipe:card-action} |
| Define modifier card | \pageref{recipe:card-modifier} |
| Define trigger card | \pageref{recipe:card-trigger} |
| Define joker | \pageref{recipe:joker-define} |
| Trigger joker events | \pageref{recipe:joker-trigger} |
| Add/remove jokers | \pageref{recipe:joker-manage} |
| Execute wand | \pageref{recipe:wand-execute} |
| Define tag synergies | \pageref{recipe:tag-synergy} |
| Evaluate tag bonuses | \pageref{recipe:tag-evaluate} |
| Register custom behavior | \pageref{recipe:behavior-register} |
| Aggregate modifiers | \pageref{recipe:modifier-aggregate} |
| Detect spell type | \pageref{recipe:spell-type} |
| Register wand trigger | \pageref{recipe:wand-trigger} |
| **AI** | |
| Create AI entity | \pageref{recipe:ai-entity-type} |
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

# Physics

This chapter covers physics integration using Chipmunk2D: creating physics bodies, collision detection, applying forces, and physics constraints.

## Get Physics World

\label{recipe:get-physics-world}

**When to use:** Before any physics operation (required for most physics functions).

```lua
local PhysicsManager = require("core.physics_manager")

-- Get the physics world (required for most physics operations)
local world = PhysicsManager.get_world("world")
if not world then
    log_warn("Physics world not available")
    return
end

-- Use world with physics functions
physics.SetBullet(world, entity, true)
physics.GetVelocity(world, entity)
```

*— from core/physics_manager.lua (C++ binding), usage in core/gameplay.lua:2377*

**Real usage example:**

```lua
-- From core/gameplay.lua:2377
local world = PhysicsManager.get_world("world")

local info = { shape = "circle", tag = "bullet", sensor = false, density = 1.0, inflate_px = -4 }
physics.create_physics_for_transform(registry,
    physics_manager_instance,
    node:handle(),
    "world",
    info
)
```

**Gotcha:** Always use `PhysicsManager.get_world("world")` instead of `globals.physicsWorld` (deprecated).

**Gotcha:** The world parameter is the first argument to most physics property setters (SetVelocity, SetBullet, etc.).

---

## Create Physics Body

\label{recipe:add-physics}

**When to use:** Add physics collision and movement to an entity.

```lua
local PhysicsManager = require("core.physics_manager")

-- Get world reference
local world = PhysicsManager.get_world("world")

-- Configure physics body
local config = {
    shape = "circle",        -- "circle", "rectangle", "polygon", "chain"
    tag = "enemy",           -- collision tag for this entity
    sensor = false,          -- sensor = no physical response (ghost collision)
    density = 1.0,           -- mass density
    inflate_px = -4          -- shrink hitbox by 4px (negative = shrink, positive = expand)
}

-- Create physics body (uses globals from runtime)
physics.create_physics_for_transform(
    registry,                -- global registry
    physics_manager_instance, -- global physics_manager instance
    entity,
    "world",                 -- physics world identifier
    config
)
```

*— from combat/projectile_system.lua:774-780, core/gameplay.lua:2380-2385*

**Real usage example:**

```lua
-- From core/gameplay.lua:7104
local info = { shape = "rectangle", tag = "player", sensor = false, density = 1.0, inflate_px = -5 }
physics.create_physics_for_transform(registry,
    physics_manager_instance,
    survivorEntity,
    "world",
    info
)

-- From combat/projectile_system.lua:765
local config = {
    shape = params.shape or "circle",
    tag = ProjectileSystem.COLLISION_CATEGORY,
    sensor = params.sensor or false,
    density = params.density or 1.0
}
physics.create_physics_for_transform(
    registry,
    physics_manager_instance,
    entity,
    "world",
    config
)
```

**Gotcha:** Don't pass the world object to `create_physics_for_transform` — it takes the world *name* ("world") as a string.

**Gotcha:** The `inflate_px` parameter shrinks (negative) or expands (positive) the hitbox. Use negative values to prevent pixel-perfect collision issues.

---

## Set Collision Tags and Masks

\label{recipe:collision-masks}

**When to use:** Configure which physics entities can collide with each other (per-entity, not global).

**CRITICAL:** Collision masks are set **per entity** when creating physics bodies, not globally in system initialization.

```lua
local PhysicsManager = require("core.physics_manager")
local world = PhysicsManager.get_world("world")

-- Enable bidirectional collision between tags
physics.enable_collision_between_many(world, "projectile", { "enemy", "WORLD" })
physics.enable_collision_between_many(world, "enemy", { "projectile" })

-- Update collision masks for both tags (required!)
physics.update_collision_masks_for(world, "projectile", { "enemy", "WORLD" })
physics.update_collision_masks_for(world, "enemy", { "projectile" })
```

*— from combat/projectile_system.lua:812-822, core/gameplay.lua:2391-2394*

**Real usage example:**

```lua
-- From core/gameplay.lua:2391
physics.enable_collision_between_many(PhysicsManager.get_world("world"), "enemy", { "bullet" })
physics.enable_collision_between_many(PhysicsManager.get_world("world"), "bullet", { "enemy" })
physics.update_collision_masks_for(PhysicsManager.get_world("world"), "enemy", { "bullet" })
physics.update_collision_masks_for(PhysicsManager.get_world("world"), "bullet", { "enemy" })

-- From core/gameplay.lua:7113
physics.enable_collision_between_many(world, "WORLD", { "player", "projectile", "enemy" })
physics.enable_collision_between_many(world, "player", { "WORLD" })
physics.enable_collision_between_many(world, "projectile", { "WORLD" })
physics.enable_collision_between_many(world, "pickup", { "player" })
physics.enable_collision_between_many(world, "player", { "pickup" })

physics.update_collision_masks_for(world, "player", { "WORLD" })
physics.update_collision_masks_for(world, "enemy", { "WORLD" })
physics.update_collision_masks_for(world, "WORLD", { "player", "enemy" })
```

**Gotcha:** You must call both `enable_collision_between_many` AND `update_collision_masks_for` for collisions to work.

**Gotcha:** Collision setup is bidirectional. If A should collide with B, you must enable A→B and B→A.

**Gotcha:** The special "WORLD" tag is used for static geometry and screen bounds.

---

## Enable Bullet Mode (High-Speed Collision)

\label{recipe:bullet-mode}

**When to use:** Prevent fast-moving objects from tunneling through collision geometry.

```lua
local PhysicsManager = require("core.physics_manager")
local world = PhysicsManager.get_world("world")

-- Enable continuous collision detection for fast objects
physics.SetBullet(world, entity, true)
```

*— from combat/projectile_system.lua:784, core/gameplay.lua:2397*

**Real usage example:**

```lua
-- From combat/projectile_system.lua:784
physics.SetBullet(world, entity, true)

-- From core/gameplay.lua:2397
physics.SetBullet(world, node:handle(), true)
```

**Gotcha:** Only use bullet mode for genuinely fast-moving objects (projectiles, dashes) — it's more expensive than normal collision detection.

---

## Set Physics Sync Mode

**When to use:** Control whether physics or Transform is the authority for entity position.

```lua
-- Physics drives position (common for physics-simulated objects)
physics.set_sync_mode(registry, entity, physics.PhysicsSyncMode.AuthoritativePhysics)

-- Transform drives position (for kinematic objects)
physics.set_sync_mode(registry, entity, physics.PhysicsSyncMode.AuthoritativeTransform)
```

*— from combat/projectile_system.lua:801-806, core/gameplay.lua:7058*

**Real usage example:**

```lua
-- From combat/projectile_system.lua:801
local syncMode = physics.PhysicsSyncMode.AuthoritativePhysics
if params.movementType == ProjectileSystem.MovementType.ORBITAL
    or params.movementType == ProjectileSystem.MovementType.ARC then
    syncMode = physics.PhysicsSyncMode.AuthoritativeTransform
end
physics.set_sync_mode(registry, entity, syncMode)

-- From core/gameplay.lua:7058
physics.set_sync_mode(registry, maskEntity, physics.PhysicsSyncMode.AuthoritativePhysics)
```

**Gotcha:** Use `AuthoritativePhysics` when physics simulation controls movement. Use `AuthoritativeTransform` when you manually update Transform (e.g., scripted motion, orbital movement).

---

## Set Physics Properties

**When to use:** Configure friction, bounciness, rotation, and other physical properties.

```lua
local PhysicsManager = require("core.physics_manager")
local world = PhysicsManager.get_world("world")

-- Friction (0.0 = no friction, 1.0 = high friction)
physics.SetFriction(world, entity, 0.0)

-- Restitution / bounciness (0.0 = no bounce, 1.0 = perfect bounce)
physics.SetRestitution(world, entity, 0.5)

-- Fixed rotation (lock rotation axis)
physics.SetFixedRotation(world, entity, true)

-- Or use helper for transform-based fixed rotation
physics.use_transform_fixed_rotation(registry, entity)

-- Body type ("static", "dynamic", "kinematic")
physics.SetBodyType(world, entity, "dynamic")

-- Mass (kg)
physics.SetMass(world, entity, 1.0)

-- Moment of inertia (rotational resistance)
physics.SetMoment(world, entity, 0.01)

-- Damping (linear velocity damping)
physics.SetDamping(world, entity, 0.3)
```

*— from combat/projectile_system.lua:787-793, core/gameplay.lua:7002-7017*

**Real usage example:**

```lua
-- From combat/projectile_system.lua:787
physics.SetFriction(world, entity, params.friction or 0.0)
physics.SetRestitution(world, entity, params.restitution or 0.5)

if params.fixedRotation ~= false then
    physics.SetFixedRotation(world, entity, true)
end

-- From core/gameplay.lua:7002
physics.SetBodyType(world, maskEntity, "dynamic")
physics.SetMass(world, maskEntity, 0.01)
physics.SetMoment(world, maskEntity, 0.01)
```

**Gotcha:** `SetFixedRotation` prevents rotation completely. For player characters and projectiles, this is usually desired.

**Gotcha:** Damping applies to both linear and angular velocity. Higher values slow objects down faster.

---

## Get/Set Velocity

**When to use:** Read or modify entity velocity directly.

```lua
local PhysicsManager = require("core.physics_manager")
local world = PhysicsManager.get_world("world")

-- Get velocity (returns {x, y} table)
local vel = physics.GetVelocity(world, entity)
print("Speed:", vel.x, vel.y)

-- Set velocity
physics.SetVelocity(world, entity, vx, vy)
```

*— from core/gameplay.lua:2400-2418, combat/projectile_system.lua:859*

**Real usage example:**

```lua
-- From core/gameplay.lua:2400
local v = physics.GetVelocity(world, survivorEntity)
local vx = v.x
local vy = v.y
local speed = 300.0

-- Normalize and scale direction
if vx ~= 0 or vy ~= 0 then
    local mag = math.sqrt(vx * vx + vy * vy)
    vx = (vx / mag) * speed
    vy = (vy / mag) * speed
end

physics.SetVelocity(world, node:handle(), vx, vy)

-- From combat/projectile_system.lua:859
physics.SetVelocity(world, entity, behavior.velocity.x, behavior.velocity.y)
```

**Gotcha:** `GetVelocity` returns a table with `x` and `y` fields, not separate values.

**Gotcha:** `SetVelocity` takes separate `vx, vy` parameters, not a table.

---

## Get Position/Angle from Physics

**When to use:** Read physics body position/rotation (useful when physics is authoritative).

```lua
local PhysicsManager = require("core.physics_manager")
local world = PhysicsManager.get_world("world")

-- Get position from physics body
local pos = physics.GetPosition(world, entity)
print("Position:", pos.x, pos.y)

-- Get rotation angle (radians)
local angle = physics.GetAngle(world, entity)
```

*— from core/gameplay.lua:6957-7065*

**Real usage example:**

```lua
-- From core/gameplay.lua:6957
local ipos = physics.GetPosition(world, e)

-- From core/gameplay.lua:7065
local bodyAngle = physics.GetAngle(world, maskEntity)
local t = component_cache.get(maskEntity, Transform)
t.actualR = math.deg(bodyAngle)  -- Convert radians to degrees for Transform
```

**Gotcha:** `GetAngle` returns radians, but Transform.actualR expects degrees. Convert with `math.deg()`.

---

## Apply Forces and Impulses

**When to use:** Apply physics forces (continuous) or impulses (instant velocity change).

```lua
local PhysicsManager = require("core.physics_manager")
local world = PhysicsManager.get_world("world")

-- Apply impulse (instant velocity change)
physics.ApplyImpulse(world, entity, impulseX, impulseY)

-- Apply force (gradual acceleration)
physics.ApplyForce(world, entity, forceX, forceY)
```

*— from core/gameplay.lua:8238, combat/projectile_system.lua:1571*

**Real usage example:**

```lua
-- From core/gameplay.lua:8238
local DASH_STRENGTH = 150
physics.ApplyImpulse(world, survivorEntity, moveDir.x * DASH_STRENGTH, moveDir.y * DASH_STRENGTH)

-- From combat/projectile_system.lua:1571
local ENEMY_HIT_RECOIL_FORCE = 100
physics.ApplyImpulse(world, targetEntity, dirX * ENEMY_HIT_RECOIL_FORCE, dirY * ENEMY_HIT_RECOIL_FORCE)
```

**Gotcha:** Impulses are instant velocity changes (use for dashes, knockback). Forces are gradual (use for wind, thrust).

**Gotcha:** Both functions take world-space directional vectors, not angles.

---

## Physics Joints (Advanced)

**When to use:** Connect two physics bodies with constraints (e.g., ragdoll, chains, pendulums).

```lua
local PhysicsManager = require("core.physics_manager")
local world = PhysicsManager.get_world("world")

-- Pivot joint (hinge at a point)
local pivotJoint = physics.add_pivot_joint_world(
    world,
    parentEntity,
    childEntity,
    { x = worldX, y = worldY }  -- Anchor point in world coordinates
)

-- Damped rotary spring (rotational spring between bodies)
local rotarySpring = physics.add_damped_rotary_spring(
    world,
    parentEntity,
    childEntity,
    0,      -- Rest angle (radians)
    6000,   -- Stiffness (higher = stiffer)
    5       -- Damping (higher = less oscillation)
)

-- Damped spring (linear spring)
local spring = physics.add_damped_spring(
    world,
    parentEntity,
    { x = 0, y = 0 },    -- Anchor on parent (local coords)
    childEntity,
    { x = 0, y = 0 },    -- Anchor on child (local coords)
    0,                   -- Rest length
    500,                 -- Stiffness
    10                   -- Damping
)

-- Slide joint (constrained distance)
local slideJoint = physics.add_slide_joint(
    world,
    parentEntity,
    { x = 0, y = 0 },    -- Anchor on parent
    childEntity,
    { x = 0, y = 0 },    -- Anchor on child
    0,                   -- Min distance
    10                   -- Max distance
)
```

*— from core/gameplay.lua:7010-7055*

**Real usage example:**

```lua
-- From core/gameplay.lua:7010 (jointed mask system)
local pivotJoint = physics.add_pivot_joint_world(
    world,
    parentEntity,
    maskEntity,
    { x = maskT.actualX + maskT.actualW / 2, y = maskT.actualY + maskT.actualH / 2 }
)

physics.SetMoment(world, maskEntity, 0.01) -- Keep inertia tiny

local rotarySpring = physics.add_damped_rotary_spring(
    world,
    parentEntity,
    maskEntity,
    0,    -- Rest angle (upright)
    6000, -- Stiffness (lower = more floppy)
    5     -- Damping
)
```

**Gotcha:** Joints require both entities to have physics bodies.

**Gotcha:** Pivot joints use world coordinates for the anchor point, while spring/slide joints use local coordinates relative to each body.

---

## Add Screen Bounds

**When to use:** Create invisible walls around the play area.

```lua
local PhysicsManager = require("core.physics_manager")

-- Create static physics boundaries
physics.add_screen_bounds(
    PhysicsManager.get_world("world"),
    left,
    top,
    right,
    bottom,
    thickness,  -- wall thickness
    "WORLD"     -- collision tag
)
```

*— from core/gameplay.lua:7134-7141*

**Real usage example:**

```lua
-- From core/gameplay.lua:7134
local wallThickness = SCREEN_BOUND_THICKNESS or 30
physics.add_screen_bounds(
    PhysicsManager.get_world("world"),
    SCREEN_BOUND_LEFT - wallThickness,
    SCREEN_BOUND_TOP - wallThickness,
    SCREEN_BOUND_RIGHT + wallThickness,
    SCREEN_BOUND_BOTTOM + wallThickness,
    wallThickness,
    "WORLD"
)
```

**Gotcha:** Screen bounds are static bodies with the specified collision tag. Make sure entities have collision masks set up to collide with "WORLD".

---

## Query Physics World

**When to use:** Find physics entities at a point or in an area.

```lua
local PhysicsManager = require("core.physics_manager")
local world = PhysicsManager.get_world("world")

-- Point query (find nearest entity at point)
if physics and physics.point_query_nearest and physics.entity_from_ptr then
    local nearestHit = physics.point_query_nearest(world, { x = px, y = py }, radius)
    if nearestHit and nearestHit.shape then
        local hitEntity = physics.entity_from_ptr(nearestHit.shape)
        -- Use hitEntity
    end
end

-- Area query (find all entities in rectangle)
if physics.GetObjectsInArea then
    local candidates = physics.GetObjectsInArea(world, x1, y1, width, height)
    for _, entity in ipairs(candidates or {}) do
        local pos = physics.GetPosition(world, entity)
        -- Use entity and pos
    end
end
```

*— from core/gameplay.lua:762-782, core/gameplay.lua:6952-6957*

**Real usage example:**

```lua
-- From core/gameplay.lua:768
local nearestHit = physics.point_query_nearest(world, { x = px, y = py }, radius)
if nearestHit and nearestHit.shape then
    local hitEntity = physics.entity_from_ptr(nearestHit.shape)
    -- Found entity at cursor position
end

-- From core/gameplay.lua:6952
local candidates = physics.GetObjectsInArea(world, x1, y1, x2, y2)
for _, e in ipairs(candidates or {}) do
    if entity_cache.valid(e) then
        local ipos = physics.GetPosition(world, e)
        -- Process entity in area
    end
end
```

**Gotcha:** Always check if `nearestHit.shape` exists before calling `entity_from_ptr`.

**Gotcha:** `GetObjectsInArea` may return nil if no entities found. Use `candidates or {}` to avoid errors.

---

## Enable/Disable Physics Stepping

**When to use:** Pause physics simulation (e.g., during UI screens or cutscenes).

```lua
local PhysicsManager = require("core.physics_manager")

-- Pause physics
PhysicsManager.enable_step("world", false)

-- Resume physics
PhysicsManager.enable_step("world", true)
```

*— from ui/level_up_screen.lua:94-103*

**Real usage example:**

```lua
-- From ui/level_up_screen.lua:94
if PhysicsManager and PhysicsManager.enable_step then
    PhysicsManager.enable_step("world", false)  -- Pause during level up screen
end

-- From ui/level_up_screen.lua:102
if PhysicsManager and PhysicsManager.enable_step then
    PhysicsManager.enable_step("world", true)   -- Resume when closing screen
end
```

**Gotcha:** Don't forget to re-enable physics stepping when closing UI screens or the game will freeze!

---

## Complete Physics Setup Pattern

**When to use:** Create a fully-configured physics entity from scratch.

```lua
local PhysicsManager = require("core.physics_manager")
local animation_system = require("core.animation_system")
local component_cache = require("core.component_cache")

function createPhysicsEntity(x, y)
    -- 1. Create entity with sprite
    local entity = animation_system.createAnimatedObjectWithTransform("kobold", true)

    -- 2. Position entity
    local transform = component_cache.get(entity, Transform)
    if transform then
        transform.actualX = x
        transform.actualY = y
        transform.actualW = 64
        transform.actualH = 64
    end

    -- 3. Create physics body
    local world = PhysicsManager.get_world("world")
    local config = {
        shape = "circle",
        tag = "enemy",
        sensor = false,
        density = 1.0,
        inflate_px = -4
    }
    physics.create_physics_for_transform(
        registry,
        physics_manager_instance,
        entity,
        "world",
        config
    )

    -- 4. Configure physics properties
    physics.SetBullet(world, entity, true)  -- High-speed collision detection
    physics.SetFriction(world, entity, 0.0)
    physics.SetRestitution(world, entity, 0.5)
    physics.SetFixedRotation(world, entity, true)

    -- 5. Set sync mode
    physics.set_sync_mode(registry, entity, physics.PhysicsSyncMode.AuthoritativePhysics)

    -- 6. Setup collision masks
    physics.enable_collision_between_many(world, "enemy", { "player", "projectile" })
    physics.enable_collision_between_many(world, "player", { "enemy" })
    physics.enable_collision_between_many(world, "projectile", { "enemy" })
    physics.update_collision_masks_for(world, "enemy", { "player", "projectile" })
    physics.update_collision_masks_for(world, "player", { "enemy" })

    return entity
end
```

*— Combined pattern from core/gameplay.lua:7104-7123, combat/projectile_system.lua:765-822*

**Gotcha:** Follow the order: Create sprite → Position → Create physics → Configure properties → Set sync mode → Setup collision masks.

\newpage

# Rendering & Shaders

This chapter covers the shader system, draw commands, and rendering pipeline for visual effects, text rendering, and custom graphics.

## Add Shader to Entity

\label{recipe:add-shader}

**When to use:** Apply visual effects to entities (holo cards, glows, dissolves, iridescent effects).

```lua
local ShaderBuilder = require("core.shader_builder")

-- Basic shader application
ShaderBuilder.for_entity(entity)
    :add("3d_skew_holo")
    :apply()
```

*— from core/shader_builder.lua:9-11*

**Real usage example:**

```lua
-- From tests/shader_builder_visual_test.lua:131
ShaderBuilder.for_entity(entity1)
    :add("flash")
    :apply()

-- From tests/shader_builder_visual_test.lua:142
ShaderBuilder.for_entity(entity2)
    :add("glow_fragment", { glow_intensity = 2.0 })
    :apply()
```

**Gotcha:** The shader name must match a shader file in `assets/shaders/` (e.g., "3d_skew_holo" → `3d_skew_holo_fragment.fs` + `3d_skew_holo_vertex.vs`).

---

## Stack Multiple Shaders

\label{recipe:stack-shaders}

**When to use:** Combine multiple visual effects on one entity (e.g., holo + dissolve for card destruction).

```lua
local ShaderBuilder = require("core.shader_builder")

-- Stack shaders (executed in order)
ShaderBuilder.for_entity(entity)
    :add("3d_skew_holo", { sheen_strength = 1.5 })
    :add("dissolve", { dissolve = 0.5 })
    :apply()

-- Clear and rebuild shader pipeline
ShaderBuilder.for_entity(entity)
    :clear()
    :add("3d_skew_prismatic")
    :apply()
```

*— from core/shader_builder.lua:14-23*

**Gotcha:** Shader order matters! Earlier shaders process first, later shaders see the transformed output.

**Gotcha:** Use `:clear()` to remove all existing shaders before applying new ones.

---

## Set Shader Uniforms

**When to use:** Control shader parameters (colors, intensities, animation speeds).

```lua
local ShaderBuilder = require("core.shader_builder")

-- Uniforms via add() options
ShaderBuilder.for_entity(entity)
    :add("3d_skew_holo", {
        sheen_strength = 1.5,
        sheen_speed = 2.0
    })
    :apply()

-- Per-uniform override
ShaderBuilder.for_entity(entity)
    :add("3d_skew_holo")
    :withUniform("3d_skew_holo", "sheen_speed", 2.0)
    :apply()
```

*— from core/shader_builder.lua:14-29*

**Real usage example:**

```lua
-- From tests/shader_builder_visual_test.lua:142
ShaderBuilder.for_entity(entity2)
    :add("glow_fragment", { glow_intensity = 2.0 })
    :apply()
```

**Gotcha:** Uniform names must match the shader's GLSL uniform declarations. Check the `.fs` shader file to see what uniforms are available.

---

## Shader Families

**When to use:** Work with shader groups that share common uniforms (3d_skew_*, liquid_*, etc.).

```lua
local ShaderBuilder = require("core.shader_builder")

-- Check if a shader belongs to a family
local family = ShaderBuilder.get_shader_family("3d_skew_holo")
print(family)  -- "3d_skew"

-- Get all registered families
local families = ShaderBuilder.get_families()
for prefix, config in pairs(families) do
    print(prefix, config.uniforms)
end

-- Register a custom shader family
ShaderBuilder.register_family("energy", {
    uniforms = { "pulse_speed", "glow_intensity" },
    defaults = { pulse_speed = 1.0 }
})
```

*— from core/shader_builder.lua:56-87, 227-244*

**Built-in families:**

- `3d_skew` — Card shaders (regionRate, pivot, quad_center, quad_size, uv_passthrough, tilt_enabled, card_rotation)
- `liquid` — Fluid effects (wave_speed, wave_amplitude, distortion)

**Real usage example:**

```lua
-- From tests/shader_builder_visual_test.lua:26
ShaderBuilder.register_family("glow", {
    uniforms = { "glow_intensity", "glow_color" },
    defaults = { glow_intensity = 1.0 }
})

-- From tests/shader_builder_visual_test.lua:37
ShaderBuilder.register_family("flash", {
    uniforms = { "flash_color", "flash_intensity" },
    defaults = { flash_intensity = 1.0 }
})
```

**Gotcha:** Family detection is prefix-based. A shader named "3d_skew_holo" matches the "3d_skew" family automatically.

**Gotcha:** Family defaults are applied automatically when you add a shader from that family.

---

## Draw Text (Command Buffer)

\label{recipe:draw-text}

**When to use:** Draw text to a layer (UI labels, tooltips, HUD).

```lua
local draw = require("core.draw")

-- Basic text (uses smart defaults)
draw.textPro(layer, {
    text = "Hello",
    font = myFont,  -- optional (uses default if omitted)
    x = 100,
    y = 200,
    fontSize = 16,  -- optional (default: 16)
    color = WHITE,  -- optional (default: WHITE)
})

-- With rotation and origin
draw.textPro(layer, {
    text = "Rotated",
    x = 100,
    y = 200,
    rotation = math.rad(45),
    origin = { x = 0.5, y = 0.5 },  -- center pivot
}, 0, layer.DrawCommandSpace.Screen)
```

*— from core/draw.lua:23-28, 228*

**Gotcha:** The `font` field expects a Font object (from localization.getFont() or loaded via C++). Omit it to use the default font.

**Gotcha:** `rotation` is in radians, not degrees. Use `math.rad(degrees)` to convert.

---

## Draw Shapes (Command Buffer)

**When to use:** Draw primitives for debugging, UI backgrounds, or effects.

```lua
local draw = require("core.draw")

-- Rectangle
draw.rectangle(layer, {
    x = 100,
    y = 200,
    width = 50,
    height = 30,
    color = RED
})

-- Circle
draw.circleFilled(layer, {
    x = 100,
    y = 200,
    radius = 20,
    color = BLUE
})

-- Line
draw.line(layer, {
    startX = 0,
    startY = 0,
    endX = 100,
    endY = 100,
    color = GREEN,
    thickness = 2
})

-- Rectangle with rotation
draw.rectanglePro(layer, {
    rect = { x = 100, y = 200, width = 50, height = 30 },
    origin = { x = 25, y = 15 },  -- center
    rotation = math.rad(45),
    color = YELLOW
})
```

*— from core/draw.lua:235-270*

**Gotcha:** `rectanglePro` uses a `rect` table with `{x, y, width, height}`, not separate parameters.

---

## Local Draw Commands (Inside Shader Pipeline)

**When to use:** Draw graphics that render inside an entity's shader pipeline (e.g., text on a card with shaders applied).

```lua
local draw = require("core.draw")

-- Text that goes through entity's shaders
draw.local_command(entity, "text_pro", {
    text = "hello",
    font = localization.getFont(),
    x = 10,
    y = 20,
    fontSize = 20,
    color = WHITE
}, { z = 1, preset = "shaded_text" })

-- Rectangle inside shader pipeline
draw.local_command(entity, "draw_rectangle", {
    x = 0,
    y = 0,
    width = 64,
    height = 64,
    color = RED
}, { z = -1 })  -- z < 0 renders before sprite
```

*— from core/draw.lua:53-58, 287-348*

**Real usage example:**

```lua
-- From tests/shader_ergonomics_test.lua:449
draw.local_command(test_entity4, "text_pro", {
    text = "local text",
    font = localization.getFont(),
    x = 10, y = 20,
    fontSize = 20,
    color = WHITE
}, { z = 1, preset = "shaded_text" })
```

**Gotcha:** `z` determines render order relative to the entity's sprite. Negative values render before the sprite, non-negative values render after.

**Gotcha:** Local commands are part of the entity's shader pipeline. If the entity has shaders applied, the local commands will be processed through those shaders too.

---

## Render Presets

**When to use:** Use named presets for common render configurations instead of repeating options.

```lua
local draw = require("core.draw")

-- Shaded text preset (textPass + uvPassthrough)
draw.local_command(entity, "text_pro", {
    text = "hello",
    x = 10, y = 20
}, { preset = "shaded_text" })

-- Sticker preset (stickerPass + uvPassthrough)
draw.local_command(entity, "texture_pro", {
    texture = myTexture,
    dest = { x = 0, y = 0, width = 64, height = 64 }
}, { preset = "sticker" })

-- World space preset
draw.local_command(entity, "text_pro", {
    text = "world",
    x = 100, y = 200
}, { preset = "world" })

-- Screen space preset
draw.local_command(entity, "text_pro", {
    text = "screen",
    x = 100, y = 200
}, { preset = "screen" })
```

*— from core/draw.lua:168-183*

**Built-in presets:**

- `"shaded_text"` — textPass=true, uvPassthrough=true (for text that goes through 3d_skew shaders)
- `"sticker"` — stickerPass=true, uvPassthrough=true
- `"world"` — space=World (coordinates in world space)
- `"screen"` — space=Screen (coordinates in screen space)

**Register custom presets:**

```lua
draw.register_preset("my_preset", {
    textPass = true,
    uvPassthrough = false,
    space = layer.DrawCommandSpace.Screen
})
```

*— from core/draw.lua:368-375*

**Gotcha:** Preset options are applied first, then explicit options override them. So you can use a preset and still customize individual fields.

---

## Z-Ordering

**When to use:** Control rendering order (which entities/UI appear in front).

```lua
local z_orders = require("core.z_orders")

-- Use named z-order constants
local baseZ = z_orders.ui_tooltips  -- 900
local cardZ = z_orders.card         -- 101
local topCardZ = z_orders.top_card  -- 200 (for dragging)

-- Assign z-index to entity
layer_order_system.assignZIndexToEntity(entity, z_orders.ui_transition + 10)

-- Draw command with z-index
draw.textPro(layer, { text = "hello", x = 100, y = 200 }, z_orders.card_text)
```

*— from core/z_orders.lua:2-21*

**Available z-order constants:**

```lua
z_orders = {
    -- Card scene
    background = 0,
    board = 100,
    card = 101,
    top_card = 200,      -- dragging card
    card_text = 250,

    -- Game scene
    projectiles = 10,
    player_vfx = 20,
    enemies = 30,

    -- General
    particle_vfx = 0,
    player_char = 1,
    ui_transition = 1000,  -- modal screens
    ui_tooltips = 900,
}
```

**Real usage example:**

```lua
-- From ui/level_up_screen.lua:165
z = (z_orders.ui_transition or 1000) + 40

-- From ui/currency_display.lua:104
local baseZ = (z_orders.ui_tooltips or 0) - 4
```

**Gotcha:** Higher z-values render in front of lower z-values. UI elements typically use z > 900 to appear above gameplay.

**Gotcha:** Always use the named constants from `z_orders` instead of magic numbers. This makes rendering order easier to understand and maintain.

---

## Global Shader Uniforms

**When to use:** Set shader uniforms that apply globally (time, mouse position, screen resolution).

```lua
-- Set global uniform (affects all shaders using this uniform)
globalShaderUniforms:set("dissolve", "dissolve", 0.5)

-- Per-shader uniform via shader_builder automatically handles this
ShaderBuilder.for_entity(entity)
    :add("dissolve", { dissolve = 0.5 })
    :apply()
```

*— from core/shader_uniforms.lua:64-66*

**Gotcha:** Global uniforms are set via the `globalShaderUniforms` C++ binding. ShaderBuilder wraps this for convenience.

**Gotcha:** Uniforms set via `globalShaderUniforms` persist across frames until changed. Use ShaderBuilder for per-entity uniforms.

---

## Draw Command Defaults

**When to use:** Understand what values are used when you omit parameters.

```lua
local draw = require("core.draw")

-- Get defaults for a command type
local defaults = draw.get_defaults("text_pro")
-- Returns: { origin = {x=0, y=0}, rotation = 0, fontSize = 16, spacing = 1, color = WHITE }

-- These are equivalent:
draw.textPro(layer, { text = "hello", x = 100, y = 200 })
draw.textPro(layer, {
    text = "hello",
    x = 100, y = 200,
    origin = { x = 0, y = 0 },
    rotation = 0,
    fontSize = 16,
    spacing = 1,
    color = WHITE
})
```

*— from core/draw.lua:101-160, 377-397*

**Available defaults:**

- `textPro` — origin={0,0}, rotation=0, fontSize=16, spacing=1, color=WHITE
- `rectangle` — color=WHITE
- `texturePro` — origin={0,0}, rotation=0, tint=WHITE
- `rectanglePro` — origin={0,0}, rotation=0, color=WHITE
- `rectangleLinesPro` — origin={0,0}, rotation=0, color=WHITE, lineThick=1

**Gotcha:** Both camelCase (`textPro`) and snake_case (`text_pro`) variants have defaults. Use camelCase for command buffer wrappers, snake_case for local_command types.

---

## Complete Shader + Draw Example

**When to use:** Create a card with shaders and custom text rendering.

```lua
local ShaderBuilder = require("core.shader_builder")
local draw = require("core.draw")
local animation_system = require("core.animation_system")
local component_cache = require("core.component_cache")

function createShaderCard(x, y)
    -- 1. Create entity with sprite
    local entity = animation_system.createAnimatedObjectWithTransform("card_back", true)

    -- 2. Position entity
    local transform = component_cache.get(entity, Transform)
    if transform then
        transform.actualX = x
        transform.actualY = y
        transform.actualW = 64
        transform.actualH = 96
    end

    -- 3. Apply shaders
    ShaderBuilder.for_entity(entity)
        :add("3d_skew_holo", { sheen_strength = 1.2 })
        :apply()

    -- 4. Add local text (renders through shaders)
    draw.local_command(entity, "text_pro", {
        text = "FIRE\nCARD",
        font = localization.getFont(),
        x = 32,  -- center of 64px card
        y = 48,
        fontSize = 12,
        color = WHITE,
        origin = { x = 0.5, y = 0.5 }
    }, { z = 1, preset = "shaded_text" })

    return entity
end
```

*— Combined pattern from core/shader_builder.lua, core/draw.lua, tests/shader_builder_visual_test.lua*

**Gotcha:** Follow the order: Create sprite → Position → Apply shaders → Add local draw commands. Local commands added before shaders may not render correctly.

\newpage

# UI System

This chapter covers the declarative UI DSL for building layouts, tooltips, grids, and interactive UI elements.

## UI DSL: Basic Structure

\label{recipe:ui-dsl}

**When to use:** Build UI layouts declaratively instead of manually positioning elements.

```lua
local dsl = require("ui.ui_syntax_sugar")

-- Create a UI definition
local myUI = dsl.root {
    config = {
        color = util.getColor("blackberry"),
        padding = 10,
        align = bit.bor(
            AlignmentFlag.HORIZONTAL_CENTER,
            AlignmentFlag.VERTICAL_CENTER
        )
    },
    children = {
        dsl.vbox {
            config = { spacing = 6, padding = 6 },
            children = {
                dsl.text("Title", { fontSize = 24, color = "white" }),
                dsl.text("Subtitle", { fontSize = 16, color = "white" })
            }
        }
    }
}

-- Spawn at position
local boxID = dsl.spawn({ x = 200, y = 200 }, myUI)
```

*— from ui/ui_syntax_sugar.lua:36-39, 176-193*

**Real usage example:**

```lua
-- From core/gameplay.lua:3119
local root = dsl.root {
    config = {
        color = tooltipStyle.bgColor,
        align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
        padding = tooltipStyle.innerPadding,
        outlineThickness = 2,
        outlineColor = tooltipStyle.outlineColor,
        shadow = true,
    },
    children = { v }
}

local boxID = dsl.spawn({ x = 200, y = 200 }, root)
```

**Gotcha:** All DSL functions return UI definition tables — they don't create entities until you call `dsl.spawn()`.

**Gotcha:** `config` is where you set layout properties (padding, spacing, alignment, colors). `children` is an array of child UI elements.

---

## DSL: Vertical Layout

**When to use:** Stack UI elements vertically (menus, lists, tooltips).

```lua
local dsl = require("ui.ui_syntax_sugar")

-- Vertical box with spacing
dsl.vbox {
    config = {
        spacing = 6,  -- space between children
        padding = 4,  -- internal padding
        align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_TOP)
    },
    children = {
        dsl.text("Item 1"),
        dsl.text("Item 2"),
        dsl.text("Item 3")
    }
}
```

*— from ui/ui_syntax_sugar.lua:31-34*

**Real usage example:**

```lua
-- From core/gameplay.lua:3112
local v = dsl.vbox {
    config = {
        align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_TOP),
        color = tooltipStyle.innerColor,
        padding = tooltipStyle.innerPadding
    },
    children = rows
}
```

**Gotcha:** Children are laid out top to bottom. First child is at the top, last child at the bottom.

---

## DSL: Horizontal Layout

**When to use:** Arrange UI elements side by side (button groups, stat displays, icon rows).

```lua
local dsl = require("ui.ui_syntax_sugar")

-- Horizontal box
dsl.hbox {
    config = {
        spacing = 4,
        padding = 4,
        align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER)
    },
    children = {
        dsl.text("HP:"),
        dsl.text("100", { color = "red" })
    }
}
```

*— from ui/ui_syntax_sugar.lua:26-29*

**Real usage example:**

```lua
-- From core/gameplay.lua:3077
table.insert(rows, dsl.hbox {
    config = {
        align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
        padding = tooltipStyle.rowPadding
    },
    children = {
        makeTooltipPill("id: " .. tostring(wand_def.id), {
            background = tooltipStyle.idBg,
            color = tooltipStyle.idTextColor or tooltipStyle.labelColor
        })
    }
})
```

**Gotcha:** Children are laid out left to right. First child is leftmost, last child is rightmost.

---

## DSL: Text Element

**When to use:** Display static or dynamic text in UI.

```lua
local dsl = require("ui.ui_syntax_sugar")

-- Simple text
dsl.text("Hello World", { fontSize = 16, color = "white" })

-- Text with custom styling
dsl.text("Important!", {
    fontSize = 24,
    color = "red",
    fontName = "bold",
    shadow = true
})

-- Text with hover tooltip
dsl.text("Hover me", {
    fontSize = 16,
    hover = {
        title = "Tooltip Title",
        body = "Detailed description here"
    }
})

-- Text with click handler
dsl.text("Click me", {
    fontSize = 16,
    onClick = function()
        print("Text clicked!")
    end
})
```

*— from ui/ui_syntax_sugar.lua:44-61*

**Real usage example:**

```lua
-- From core/gameplay.lua:342-346
return dsl.hbox {
    config = cfg,
    children = { makeTooltipTextDef(text, textOpts) }
}
```

**Gotcha:** Color can be a string (color name from util.getColor) or a Color object.

**Gotcha:** Default alignment is HORIZONTAL_CENTER | VERTICAL_CENTER. Override with the `align` option.

---

## DSL: Animated Sprite

**When to use:** Embed animated sprites in UI (icons, decorations, item previews).

```lua
local dsl = require("ui.ui_syntax_sugar")

-- Sprite in UI
dsl.anim("kobold", {
    w = 40,
    h = 40,
    shadow = true  -- enable drop shadow
})

-- Larger sprite without shadow
dsl.anim("fireball_icon", {
    w = 64,
    h = 64,
    shadow = false
})
```

*— from ui/ui_syntax_sugar.lua:99-119*

**Real usage example:**

```lua
-- From ui/ui_syntax_sugar.lua:96-97 (inline comment examples)
-- dsl.anim("sprite.png",  { sprite = true,  w = 40, h = 40, shadow = false })
-- dsl.anim("walk_anim",   { sprite = false, w = 64, h = 64 })
```

**Gotcha:** The sprite ID must exist in the animation system (loaded from assets).

**Gotcha:** `shadow` defaults to `true`. Set `shadow = false` to disable the drop shadow.

**Gotcha:** The `isAnimation` option determines whether to treat the ID as an animation (true, default) or a raw sprite identifier (false).

---

## DSL: Dynamic Text

**When to use:** Text that updates automatically based on game state (health bars, timers, scores).

```lua
local dsl = require("ui.ui_syntax_sugar")

-- Dynamic text with function
dsl.dynamicText(
    function()
        return "Health: " .. player.health
    end,
    16,      -- fontSize
    "",      -- effect (text effect name, or "" for none)
    {}       -- additional opts
)

-- With text effect
dsl.dynamicText(
    function()
        return "LEVEL UP!"
    end,
    24,
    "juicy",  -- bouncy text effect
    { color = "gold" }
)

-- With auto-alignment refresh
dsl.dynamicText(
    function()
        return "Score: " .. getScore()
    end,
    20,
    "",
    {
        autoAlign = true,
        alignRate = 0.5  -- check alignment every 0.5s
    }
)
```

*— from ui/ui_syntax_sugar.lua:67-88*

**Gotcha:** The function is called every frame to get the current text. Keep it lightweight!

**Gotcha:** `autoAlign` triggers re-alignment when text width changes. Only use if the text length varies significantly.

---

## DSL: Grid Layout

\label{recipe:ui-grid}

**When to use:** Create uniform grids of UI elements (item inventories, skill trees, card grids).

```lua
local dsl = require("ui.ui_syntax_sugar")

-- 3x4 grid of items
local grid = dsl.grid(3, 4, function(row, col)
    return dsl.text(string.format("(%d,%d)", row, col))
end)

-- Grid of sprites
local iconGrid = dsl.grid(2, 3, function(row, col)
    local index = (row - 1) * 3 + col
    return dsl.anim("icon_" .. index, { w = 32, h = 32 })
end)

-- Use grid in UI
local myUI = dsl.root {
    config = { padding = 10 },
    children = grid  -- grid is already an array of rows
}
```

*— from ui/ui_syntax_sugar.lua:204-220*

**Real usage example:**

```lua
-- From ui/ui_syntax_sugar.lua:200-202 (inline comment example)
-- local grid = dsl.grid(3, 4, function(r, c)
--     return dsl.anim("icon_"..(r*c), { w = 48, h = 48 })
-- end)
```

**Gotcha:** The generator function receives `(row, col)` with 1-based indexing (row 1 = top, col 1 = left).

**Gotcha:** `dsl.grid()` returns an array of horizontal rows. You can insert it directly into a vbox's `children`.

---

## Spawning UI

**When to use:** Create the actual UI entity from a definition.

```lua
local dsl = require("ui.ui_syntax_sugar")

-- Basic spawn (minimal params)
local boxID = dsl.spawn({ x = 200, y = 200 }, myUIDefinition)

-- With layer name and z-index
local boxID = dsl.spawn(
    { x = 200, y = 200 },
    myUIDefinition,
    "ui",     -- layer name
    100       -- z-index (higher renders in front)
)

-- With resize callback
local boxID = dsl.spawn(
    { x = 200, y = 200 },
    myUIDefinition,
    "ui",
    100,
    {
        onBoxResize = function(boxEntity)
            print("UI box resized!")
        end
    }
)
```

*— from ui/ui_syntax_sugar.lua:176-193*

**Real usage example:**

```lua
-- From core/gameplay.lua:3130
local boxID = dsl.spawn({ x = 200, y = 200 }, root)

-- Set layer and state after spawn
ui.box.set_draw_layer(boxID, "ui")
ui.box.AssignStateTagsToUIBox(boxID, PLANNING_STATE)
remove_default_state_tag(boxID)
```

**Gotcha:** `dsl.spawn()` returns the box entity ID, not the definition.

**Gotcha:** Layer assignment can be done either via `dsl.spawn()` or by calling `ui.box.set_draw_layer()` afterward.

**Gotcha:** Z-index only applies if you specify a layer name. Without a layer, z-ordering is undefined.

---

## Tooltips

\label{recipe:tooltip}

**When to use:** Show information on hover for any UI element.

```lua
local dsl = require("ui.ui_syntax_sugar")

-- Tooltip on text
dsl.text("Item Name", {
    fontSize = 16,
    hover = {
        title = "Sword of Fire",
        body = "Deals 50 fire damage",
        id = "unique_tooltip_id"  -- optional
    }
})

-- Tooltip on sprite
dsl.anim("sword_icon", {
    w = 40,
    h = 40,
    hover = {
        title = "Legendary Sword",
        body = "A very powerful weapon"
    }
})

-- Custom tooltip positioning and styling
dsl.text("Info", {
    hover = {
        title = "Details",
        body = "Long description that wraps...",
        id = "info_tooltip"
    },
    onClick = function()
        print("Clicked!")
    end
})
```

*— from ui/ui_syntax_sugar.lua:126-152, 158-171*

**Real usage example:**

```lua
-- Tooltips are attached via hover handlers internally
-- When DSL spawns the UI, it calls dsl.applyHoverRecursive(entity)
-- which scans all children for .hover config
```

**Gotcha:** Tooltips use the global `showSimpleTooltipAbove()` and `hideSimpleTooltip()` functions. These must be available at runtime.

**Gotcha:** The tooltip appears when you hover, disappears when you stop hovering. The system handles this automatically.

**Gotcha:** Tooltip `title` and `body` are passed through `localization.get()` for translation support.

---

## Click Handlers on UI Elements

**When to use:** Make UI elements respond to clicks (buttons, cards, interactive icons).

```lua
local dsl = require("ui.ui_syntax_sugar")

-- Clickable text
dsl.text("Start Game", {
    fontSize = 20,
    color = "white",
    onClick = function()
        startGame()
    end
})

-- Button with hover and click
dsl.text("Shop", {
    fontSize = 18,
    hover = {
        title = "Shop",
        body = "Buy items and upgrades"
    },
    onClick = function()
        openShop()
    end
})

-- Interactive sprite
dsl.anim("close_button", {
    w = 32,
    h = 32,
    onClick = function()
        closeWindow()
    end
})
```

*— from ui/ui_syntax_sugar.lua:44-61 (onClick via buttonCallback)*

**Gotcha:** Click handlers are set via the `onClick` option in `dsl.text()` config.

**Gotcha:** The handler is called immediately when clicked — no entity ID parameter is passed to the callback.

**Gotcha:** To make sprites clickable, you need to set up GameObject callbacks manually after spawning (DSL doesn't auto-enable clicks for sprites).

---

## Text Effects

**When to use:** Add visual flair to text (bounces, glows, color shifts).

```lua
local dsl = require("ui.ui_syntax_sugar")

-- Dynamic text with effect
dsl.dynamicText(
    function() return "COMBO!" end,
    24,
    "juicy",  -- effect name
    { color = "yellow" }
)

-- Other available effects:
-- "static"     - No animation (default)
-- "juicy"      - Bounce/scale effects
-- "magical"    - Sparkle/glow
-- "elemental"  - Fire/ice/etc themed
-- "continuous" - Looping animations
-- "oneshot"    - Play-once animations
```

*— from ui/ui_syntax_sugar.lua:67-88, ui/text_effects/init.lua:98-134*

**Available text effects:**

- `continuous.lua` — Looping effects (wave, pulse, rainbow)
- `elemental.lua` — Element-themed effects (fire, ice, electric)
- `juicy.lua` — Bouncy, game-feel effects
- `magical.lua` — Sparkle, glow, mystic effects
- `oneshot.lua` — Play-once effects (fade in, pop)
- `static.lua` — No animation (default)

**Gotcha:** Text effects are only available via `dsl.dynamicText()`, not regular `dsl.text()`.

**Gotcha:** Effects are defined in `ui/text_effects/` and registered via `effects.register()`. Check those files to see available effect names.

---

## UI Box Alignment Flags

**When to use:** Control how UI elements align within their containers.

```lua
-- Common alignment combinations
local align_topleft = bit.bor(
    AlignmentFlag.HORIZONTAL_LEFT,
    AlignmentFlag.VERTICAL_TOP
)

local align_center = bit.bor(
    AlignmentFlag.HORIZONTAL_CENTER,
    AlignmentFlag.VERTICAL_CENTER
)

local align_bottomright = bit.bor(
    AlignmentFlag.HORIZONTAL_RIGHT,
    AlignmentFlag.VERTICAL_BOTTOM
)

-- Use in config
dsl.vbox {
    config = {
        align = align_center,
        padding = 10
    },
    children = { ... }
}
```

**Available alignment flags:**

- Horizontal: `HORIZONTAL_LEFT`, `HORIZONTAL_CENTER`, `HORIZONTAL_RIGHT`
- Vertical: `VERTICAL_TOP`, `VERTICAL_CENTER`, `VERTICAL_BOTTOM`

**Real usage example:**

```lua
-- From core/gameplay.lua:3078
config = {
    align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
    padding = tooltipStyle.rowPadding
}
```

**Gotcha:** Always use `bit.bor()` to combine flags, not `+` or `|`.

**Gotcha:** Alignment affects how children are positioned within the box, not the box itself.

---

## Complete UI Example (Tooltip)

**When to use:** Build a fully-styled tooltip with multiple rows.

```lua
local dsl = require("ui.ui_syntax_sugar")
local bit = require("bit")

function createItemTooltip(item)
    local rows = {}

    -- Title row
    table.insert(rows, dsl.hbox {
        config = { padding = 4 },
        children = {
            dsl.anim(item.icon, { w = 32, h = 32 }),
            dsl.text(item.name, { fontSize = 18, color = "gold" })
        }
    })

    -- Stats rows
    table.insert(rows, dsl.hbox {
        config = { padding = 2 },
        children = {
            dsl.text("Damage:", { fontSize = 14, color = "white" }),
            dsl.text(tostring(item.damage), { fontSize = 14, color = "red" })
        }
    })

    -- Build tooltip
    local v = dsl.vbox {
        config = {
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_TOP),
            color = util.getColor("blackberry"),
            padding = 8,
            spacing = 4
        },
        children = rows
    }

    local root = dsl.root {
        config = {
            color = util.getColor("black"),
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
            padding = 4,
            outlineThickness = 2,
            outlineColor = util.getColor("white"),
            shadow = true
        },
        children = { v }
    }

    -- Spawn at position
    local boxID = dsl.spawn({ x = 200, y = 200 }, root, "ui", 900)

    -- Finalize
    ui.box.RenewAlignment(registry, boxID)
    ui.box.AssignStateTagsToUIBox(boxID, PLANNING_STATE)
    remove_default_state_tag(boxID)

    return boxID
end
```

*— Combined pattern from core/gameplay.lua:3075-3140*

**Gotcha:** Call `ui.box.RenewAlignment()` after spawning to ensure proper layout before rendering.

**Gotcha:** Assign state tags so the UI only appears in the correct game states.

**Gotcha:** Use `remove_default_state_tag()` to prevent the UI from appearing in all states.

---

## UI DSL Color Options

**When to use:** Style UI boxes with colors, outlines, and shadows.

```lua
local dsl = require("ui.ui_syntax_sugar")

dsl.root {
    config = {
        color = util.getColor("blackberry"),     -- background color
        outlineThickness = 2,                    -- border width
        outlineColor = util.getColor("white"),   -- border color
        shadow = true,                           -- enable drop shadow
        padding = 10,
        -- ... other options
    },
    children = { ... }
}
```

**Gotcha:** `color` sets the background fill color of the box.

**Gotcha:** `outlineThickness = 0` disables the border.

**Gotcha:** `shadow = true` adds a subtle drop shadow for depth.

---

## Nested Layouts

**When to use:** Build complex UIs with multiple levels of nesting.

```lua
local dsl = require("ui.ui_syntax_sugar")

local ui = dsl.root {
    config = { padding = 10 },
    children = {
        dsl.vbox {
            config = { spacing = 8 },
            children = {
                dsl.text("Player Stats", { fontSize = 20 }),
                dsl.hbox {
                    config = { spacing = 4 },
                    children = {
                        dsl.text("HP:"),
                        dsl.text("100", { color = "red" })
                    }
                },
                dsl.hbox {
                    config = { spacing = 4 },
                    children = {
                        dsl.text("MP:"),
                        dsl.text("50", { color = "blue" })
                    }
                },
                dsl.grid(2, 2, function(r, c)
                    return dsl.anim("skill_icon", { w = 32, h = 32 })
                end)
            }
        }
    }
}
```

**Gotcha:** Deep nesting can make definitions hard to read. Consider extracting sub-components into local variables:

```lua
local statsRow = dsl.hbox { ... }
local skillGrid = dsl.grid(2, 2, ...)

local ui = dsl.root {
    children = { statsRow, skillGrid }
}
```

\newpage

\newpage

# Combat & Projectiles

This chapter covers the projectile system for spawning, moving, and destroying projectiles with various behaviors.

## Spawn Basic Projectile

\label{recipe:spawn-projectile}

**When to use:** Fire a simple straight-line projectile.

```lua
local ProjectileSystem = require("combat.projectile_system")

-- Spawn straight projectile
local entity = ProjectileSystem.spawn({
    -- Position & direction
    position = { x = 100, y = 200 },
    positionIsCenter = true,  -- position is center, not top-left
    angle = math.pi / 4,      -- direction in radians
    
    -- Movement
    movementType = ProjectileSystem.MovementType.STRAIGHT,
    baseSpeed = 400,          -- pixels per second
    
    -- Damage
    damage = 25,
    damageType = "fire",
    owner = playerEntity,     -- who spawned this projectile
    
    -- Collision
    collisionBehavior = ProjectileSystem.CollisionBehavior.DESTROY,
    
    -- Lifetime
    lifetime = 3.0,           -- seconds before auto-despawn
    
    -- Visual
    sprite = "fireball_anim",
    size = 16,                -- base size in pixels
    shadow = true
})
```

*— from combat/projectile_system.lua:411-480*

**Gotcha:** `position` is top-left by default. Set `positionIsCenter = true` to spawn at center coordinates.

**Gotcha:** `angle` is in radians, not degrees. Use `math.rad(degrees)` to convert.

---

## Helper: Quick Spawn

**When to use:** Spawn basic projectile without verbose options.

```lua
local ProjectileSystem = require("combat.projectile_system")

-- Quick spawn straight projectile
ProjectileSystem.spawnBasic(x, y, angle, speed, damage, owner)

-- Quick spawn homing projectile
ProjectileSystem.spawnHoming(x, y, targetEntity, speed, damage, owner)

-- Quick spawn arc projectile (affected by gravity)
ProjectileSystem.spawnArc(x, y, angle, speed, damage, owner)
```

*— from combat/projectile_system.lua:1819-1865*

---

## Movement Types

\label{recipe:projectile-movement}

**When to use:** Choose projectile movement pattern.

### Straight Movement

```lua
ProjectileSystem.spawn({
    position = { x = x, y = y },
    angle = angle,
    movementType = ProjectileSystem.MovementType.STRAIGHT,
    baseSpeed = 400
})
```

*— Travels in a straight line at constant speed*

### Homing Movement

```lua
ProjectileSystem.spawn({
    position = { x = x, y = y },
    movementType = ProjectileSystem.MovementType.HOMING,
    homingTarget = enemyEntity,
    baseSpeed = 300,
    homingStrength = 10.0,  -- turn rate (higher = faster turning)
    homingMaxSpeed = 500    -- max speed when chasing
})
```

*— from combat/projectile_examples.lua:74-90*

**Gotcha:** Homing requires a valid target entity. Check `entity_cache.valid(target)` before spawning.

**Gotcha:** Higher `homingStrength` = sharper turns. Use 5-15 for most cases.

### Arc Movement (Gravity)

```lua
ProjectileSystem.spawn({
    position = { x = x, y = y },
    angle = angle,
    movementType = ProjectileSystem.MovementType.ARC,
    baseSpeed = 400,
    gravityScale = 1.8  -- gravity multiplier (1.0 = normal, >1 = heavier)
})
```

*— from combat/projectile_examples.lua:240-249*

**Gotcha:** Arc projectiles are affected by gravity. Use for grenades, arrows with drop, etc.

### Orbital Movement

```lua
ProjectileSystem.spawn({
    position = { x = centerX, y = centerY },
    movementType = ProjectileSystem.MovementType.ORBITAL,
    orbitCenter = { x = centerX, y = centerY },
    orbitRadius = 80,       -- distance from center
    orbitSpeed = 3.0,       -- radians/second
    orbitAngle = 0          -- starting angle
})
```

*— from combat/projectile_examples.lua:285-305*

**Real usage:** Orbital shields, rotating projectiles around player/entity.

---

## Collision Behaviors

\label{recipe:projectile-collision}

**When to use:** Define what happens when projectile hits something.

### Destroy on Hit

```lua
collisionBehavior = ProjectileSystem.CollisionBehavior.DESTROY
```

*— Default behavior. Projectile is destroyed on first collision.*

### Pierce Through Enemies

```lua
collisionBehavior = ProjectileSystem.CollisionBehavior.PIERCE,
pierceCount = 0,          -- current pierce count
maxPierceCount = 3        -- destroy after piercing 3 enemies
```

*— from combat/projectile_examples.lua:142-160*

**Gotcha:** Set `pierceCount = 0` initially, `maxPierceCount` controls how many enemies it can pierce.

### Bounce Off Surfaces

```lua
collisionBehavior = ProjectileSystem.CollisionBehavior.BOUNCE,
bounceCount = 0,
maxBounces = 5,
bounceDampening = 0.9  -- lose 10% speed per bounce
```

*— from combat/projectile_examples.lua:189-209*

**Real usage:** Bouncing projectiles that ricochet off walls/enemies.

### Explode on Impact (AoE)

```lua
collisionBehavior = ProjectileSystem.CollisionBehavior.EXPLODE,
explosionRadius = 100,         -- radius in pixels
explosionDamageMult = 1.2      -- damage multiplier for explosion
```

*— from combat/projectile_examples.lua:240-259*

**Gotcha:** Explosion damage = `damage * damageMultiplier * explosionDamageMult`

**Real usage:** Grenades, fireballs, area-of-effect projectiles.

### Pass Through (No Collision)

```lua
collisionBehavior = ProjectileSystem.CollisionBehavior.PASS_THROUGH
```

*— Projectile ignores collision but can still deal damage.*

---

## Event Callbacks

\label{recipe:projectile-callbacks}

**When to use:** React to projectile lifecycle events.

```lua
ProjectileSystem.spawn({
    -- ... other params ...
    
    onSpawn = function(entity, params)
        print("Projectile spawned:", entity)
        -- Spawn particle trail
        -- Play spawn sound
    end,
    
    onHit = function(projectile, target, data)
        print("Hit target:", target)
        -- Apply status effect
        -- Play hit sound
        -- Reduce damage on pierce
        data.damageMultiplier = data.damageMultiplier * 0.8
    end,
    
    onDestroy = function(entity, data)
        print("Projectile destroyed")
        -- Spawn particles
        -- Clean up references
    end
})
```

*— from combat/projectile_examples.lua:47-63*

**Gotcha:** `onHit` is called BEFORE damage is applied. Modify `data.damageMultiplier` to change damage.

**Gotcha:** `onDestroy` is called when projectile is removed for any reason (timeout, hit, out of bounds).

---

## Lifetime Control

\label{recipe:projectile-lifetime}

**When to use:** Control when projectiles despawn.

```lua
ProjectileSystem.spawn({
    -- Time-based despawn
    lifetime = 3.0,  -- seconds
    
    -- Distance-based despawn
    maxDistance = 500,  -- pixels from spawn point
    
    -- Hit-count based despawn
    maxHits = 5  -- destroy after hitting 5 entities
})
```

*— from combat/projectile_system.lua:234-266*

**Gotcha:** All three conditions are checked. Projectile despawns when ANY condition is met.

**Gotcha:** Default lifetime varies by movement type (straight: 5s, homing: 10s, orbital: 12s).

---

## Damage & Modifiers

\label{recipe:projectile-damage}

**When to use:** Configure projectile damage properties.

```lua
ProjectileSystem.spawn({
    -- Base damage
    damage = 50,
    damageType = "fire",  -- "physical", "fire", "ice", "lightning", etc.
    
    -- Multipliers (applied to damage)
    damageMultiplier = 1.5,
    speedMultiplier = 1.2,
    sizeMultiplier = 1.1,
    
    -- Owner & faction
    owner = playerEntity,
    faction = "player",  -- "player", "enemy", "neutral"
    
    -- Modifiers from cards/wand system
    modifiers = {
        explosionOnHit = true,
        chainLightning = { count = 3, range = 100 }
    }
})
```

*— from combat/projectile_system.lua:161-189*

**Gotcha:** `damageMultiplier` affects final damage calculation. Use for scaling with stats.

**Gotcha:** `faction` controls friendly fire. Set to prevent hitting allies.

---

## Projectile Presets

\label{recipe:projectile-preset}

**When to use:** Define reusable projectile configurations.

Define in `assets/scripts/data/projectiles.lua`:

```lua
local Projectiles = {
    my_fireball = {
        id = "my_fireball",
        speed = 400,
        damage_type = "fire",
        movement = "straight",
        collision = "explode",
        explosion_radius = 60,
        lifetime = 2000,  -- milliseconds
        on_hit_effect = "burn",
        on_hit_duration = 3000,
        tags = { "Fire", "Projectile", "AoE" }
    },
    
    ice_shard = {
        id = "ice_shard",
        speed = 600,
        damage_type = "ice",
        movement = "straight",
        collision = "pierce",
        pierce_count = 2,
        lifetime = 1800,
        on_hit_effect = "freeze",
        on_hit_duration = 1000,
        tags = { "Ice", "Projectile" }
    }
}

return Projectiles
```

*— from data/projectiles.lua:1-65*

**Preset fields:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier |
| `speed` | number | Base speed (pixels/sec) |
| `damage_type` | string | Element/damage type |
| `movement` | string | "straight", "homing", "arc", "orbital" |
| `collision` | string | "destroy", "pierce", "bounce", "explode" |
| `explosion_radius` | number | AoE radius (for explode) |
| `pierce_count` | number | Max pierce count |
| `bounce_count` | number | Max bounce count |
| `lifetime` | number | Max lifetime (milliseconds) |
| `on_hit_effect` | string | Status effect to apply |
| `on_hit_duration` | number | Effect duration (ms) |
| `tags` | table | Tags for joker synergies |

**Standard tags:**
- **Elements:** `Fire`, `Ice`, `Lightning`, `Poison`, `Arcane`, `Holy`, `Void`
- **Mechanics:** `Projectile`, `AoE`, `Hazard`

---

## Collision Targets

\label{recipe:projectile-targets}

**When to use:** Control what projectiles can collide with.

```lua
ProjectileSystem.spawn({
    -- Collide with specific tags
    collideWithTags = { "enemy", "WORLD" },
    
    -- OR use default target + world
    targetCollisionTag = "enemy",  -- default target
    collideWithWorld = true        -- also collide with world bounds
})
```

*— from combat/projectile_system.lua:299-323*

**Gotcha:** By default, projectiles collide with "enemy" and "WORLD".

**Gotcha:** Use `collideWithTags` to override all collision targets.

**Gotcha:** Set `collideWithWorld = false` to pass through walls/boundaries.

---

## Physics Integration

**When to use:** Add physics properties to projectiles.

```lua
ProjectileSystem.spawn({
    -- Physics (enabled by default)
    usePhysics = true,
    
    -- Physics properties
    restitution = 0.5,   -- bounciness (0 = no bounce, 1 = perfect bounce)
    friction = 0.1,      -- surface friction
    gravityScale = 0,    -- gravity multiplier (0 = no gravity)
    fixedRotation = true -- lock rotation (for sprites that shouldn't rotate)
})
```

*— from combat/projectile_examples.lua:220-223*

**Gotcha:** `usePhysics = false` to disable physics integration (manual movement only).

**Gotcha:** `fixedRotation = false` makes projectile rotate based on velocity direction.

---

## Events & Signals

\label{recipe:projectile-signals}

**When to use:** React to projectile events across systems.

```lua
local signal = require("external.hump.signal")

-- Listen for projectile spawned
signal.register("projectile_spawned", function(entity, data)
    print("Projectile spawned:", entity)
    print("Owner:", data.owner)
    print("Damage:", data.damage)
end)

-- Listen for projectile hit
signal.register("projectile_hit", function(projectile, target, damage)
    print("Projectile", projectile, "hit", target, "for", damage)
end)

-- Listen for projectile exploded
signal.register("projectile_exploded", function(entity, data)
    print("Explosion at:", data.position.x, data.position.y)
    print("Radius:", data.radius)
    print("Damage:", data.damage)
    -- Camera shake
    -- Spawn particles
end)

-- Listen for projectile destroyed
signal.register("projectile_destroyed", function(entity, data)
    print("Projectile destroyed, reason:", data.reason)
    -- "timeout", "hit_count", "bounce_depleted", "world_bounds", etc.
end)
```

*— from combat/projectile_system.lua:1749-1797*

**Events emitted:**
- `"projectile_spawned"` (entity, data) — when projectile is created
- `"projectile_hit"` (projectile, target, damage) — when projectile hits entity
- `"projectile_exploded"` (entity, {position, radius, damage, owner}) — when explosion occurs
- `"projectile_destroyed"` (entity, {owner, reason}) — when projectile is removed

---

## Complete Example: Custom Grenade

**When to use:** Combine all features for complex projectile behavior.

```lua
local ProjectileSystem = require("combat.projectile_system")
local signal = require("external.hump.signal")

function spawnGrenade(x, y, targetX, targetY, owner)
    -- Calculate angle and distance
    local dx = targetX - x
    local dy = targetY - y
    local angle = math.atan(dy, dx)
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Spawn arc projectile with explosion
    local entity = ProjectileSystem.spawn({
        -- Position
        position = { x = x, y = y },
        positionIsCenter = true,
        angle = angle,
        
        -- Movement (arc with gravity)
        movementType = ProjectileSystem.MovementType.ARC,
        baseSpeed = 400,
        gravityScale = 1.8,
        
        -- Damage
        damage = 50,
        damageType = "fire",
        owner = owner,
        
        -- Collision (explode on impact)
        collisionBehavior = ProjectileSystem.CollisionBehavior.EXPLODE,
        explosionRadius = 100,
        explosionDamageMult = 1.2,
        
        -- Lifetime
        lifetime = 5.0,
        
        -- Visual
        sprite = "grenade_sprite.png",
        size = 16,
        shadow = true,
        fixedRotation = false,  -- tumbles through air
        
        -- Callbacks
        onSpawn = function(eid, params)
            print("Grenade launched!")
            -- Play throw sound
        end,
        
        onHit = function(projectile, target, data)
            print("Grenade impact!")
            -- Play explosion sound
            -- Camera shake
        end,
        
        onDestroy = function(eid, data)
            print("Grenade cleanup")
        end
    })
    
    return entity
end

-- Listen for explosion to apply effects
signal.register("projectile_exploded", function(entity, data)
    local script = getScriptTableFromEntityID(entity)
    if not script then return end
    
    -- Apply screen shake
    if camera then
        camera.shake(0.5, 10)
    end
    
    -- Spawn particle burst
    if particle then
        particle.createExplosion(data.position.x, data.position.y, data.radius)
    end
end)
```

*— Combined pattern from combat/projectile_examples.lua:239-276*

**Gotcha:** Arc projectiles need higher `baseSpeed` to reach distant targets.

**Gotcha:** Use `explosionDamageMult` to balance AoE vs direct damage.

**Gotcha:** `fixedRotation = false` makes grenade tumble realistically.

\newpage
# Chapter 7: Wand & Cards

\label{chapter:wand-cards}

*Spellcasting system with cards, modifiers, triggers, and jokers.*

---

## Overview

The Wand & Cards system is a deck-building spellcasting engine where:
- **Cards** define actions (spells), modifiers (buffs), and triggers (conditions)
- **Wands** execute cards in sequence when triggers fire
- **Jokers** are passive artifacts that react to events
- **Tags** provide synergy bonuses at breakpoints (3/5/7/9 cards)
- **Spell Types** classify cast patterns (Simple, Twin, Mono-Element, etc.)

**Key modules:**
- `data/cards.lua` — Card registry
- `data/jokers.lua` — Joker registry
- `wand/wand_executor.lua` — Orchestrates casting
- `wand/wand_modifiers.lua` — Modifier aggregation
- `wand/wand_triggers.lua` — Trigger system
- `wand/joker_system.lua` — Joker event handling
- `wand/tag_evaluator.lua` — Tag synergy thresholds
- `wand/spell_type_evaluator.lua` — Cast pattern detection
- `wand/card_behavior_registry.lua` — Custom behaviors

---

## Define a Basic Action Card

\label{recipe:card-action}

**When to use:** Add a new projectile spell to the game.

```lua
-- In assets/scripts/data/cards.lua

Cards.MY_LIGHTNING_BOLT = {
    -- Required fields
    id = "MY_LIGHTNING_BOLT",        -- Must match table key
    type = "action",                  -- "action", "modifier", or "trigger"
    mana_cost = 15,
    tags = { "Lightning", "Projectile" },
    test_label = "LIGHTNING\nbolt",   -- Display label (use \n for line breaks)

    -- Action-specific fields
    damage = 30,
    damage_type = "lightning",        -- fire/ice/lightning/poison/arcane/holy/void
    projectile_speed = 600,
    lifetime = 2000,                  -- milliseconds
    radius_of_effect = 0,             -- 0 = no AoE, >0 = explosion radius

    -- Optional fields
    spread_angle = 0,                 -- Degrees for spread shots
    cast_delay = 50,                  -- ms delay before cast
    homing_strength = 0,              -- 0-15 for homing
    ricochet_count = 0,               -- Bounces off walls
    timer_ms = 0,                     -- Timer trigger (0 = none)
}
```

*— Pattern from data/cards.lua:16-36*

**Gotcha:** `id` must exactly match the table key (`Cards.MY_LIGHTNING_BOLT` → `id = "MY_LIGHTNING_BOLT"`).

**Gotcha:** `test_label` uses `\n` for line breaks in UI, not actual newlines.

**Gotcha:** `radius_of_effect = 0` means single-target; any value > 0 creates AoE explosion.

---

## Define a Modifier Card

\label{recipe:card-modifier}

**When to use:** Create a card that modifies other spells (speed, damage, multicast).

```lua
-- In assets/scripts/data/cards.lua

Cards.MOD_TRIPLE_DAMAGE = {
    id = "MOD_TRIPLE_DAMAGE",
    type = "modifier",                -- Modifier type
    mana_cost = 20,
    tags = { "Buff" },
    test_label = "TRIPLE\ndamage",

    -- Modifier fields
    damage_modifier = 0,              -- Flat bonus (additive)
    damage_multiplier = 3.0,          -- Multiplicative bonus

    -- Can also modify:
    speed_modifier = 0,               -- Additive speed
    speed_multiplier = 1.0,           -- Multiplicative speed
    spread_modifier = 0,              -- Additive spread angle
    lifetime_modifier = 0,            -- Additive lifetime (ms)
    lifetime_multiplier = 1.0,
    critical_hit_chance_modifier = 0, -- Additive crit %
}

-- Multicast example
Cards.MOD_MULTICAST_5 = {
    id = "MOD_MULTICAST_5",
    type = "modifier",
    mana_cost = 25,
    tags = { "Arcane" },
    test_label = "5x\nCAST",

    -- Multicast
    multicast_count = 5,              -- Number of projectiles
    spread_angle = 45,                -- Total spread arc (degrees)
    circular_pattern = false,         -- true = 360° circle
}
```

*— Pattern from data/cards.lua:108-123, 458-489*

**Gotcha:** Modifiers apply to ALL actions after them in the wand sequence.

**Gotcha:** `damage_modifier` is additive (`+10`), `damage_multiplier` is multiplicative (`×2.0`).

**Gotcha:** `multicast_count` fires multiple projectiles simultaneously with `spread_angle` arc.

---

## Define a Trigger Card

\label{recipe:card-trigger}

**When to use:** Create a card that fires when conditions are met (timer, collision, death).

```lua
-- In assets/scripts/data/cards.lua

Cards.MOD_TRIGGER_ON_HIT = {
    id = "MOD_TRIGGER_ON_HIT",
    type = "modifier",                -- Triggers are modifiers
    mana_cost = 15,
    tags = { "Arcane" },
    test_label = "trigger\nON HIT",

    -- Trigger on collision
    trigger_on_collision = true,

    -- Cards after this trigger when projectile hits
}

Cards.MOD_TRIGGER_TIMER = {
    id = "MOD_TRIGGER_TIMER",
    type = "modifier",
    mana_cost = 12,
    tags = { "Arcane" },
    test_label = "trigger\nTIMER",

    -- Timer trigger
    timer_ms = 1000,                  -- Fire after 1 second

    -- Cards after this trigger when timer expires
}

Cards.MOD_TRIGGER_ON_DEATH = {
    id = "MOD_TRIGGER_ON_DEATH",
    type = "modifier",
    mana_cost = 18,
    tags = { "Void" },
    test_label = "trigger\nON DEATH",

    -- Trigger when projectile is destroyed
    trigger_on_death = true,
}
```

*— Pattern from data/cards.lua:403-456*

**Gotcha:** Trigger cards split the wand into blocks: [before trigger] → [after trigger fires].

**Gotcha:** Actions after a trigger execute at the trigger position, not cast position.

**Gotcha:** Multiple triggers can chain: timer → hit → death creates 3 sub-casts.

---

## Define a Joker (Passive Artifact)

\label{recipe:joker-define}

**When to use:** Create a passive modifier that reacts to game events.

```lua
-- In assets/scripts/data/jokers.lua

local Jokers = {
    -- Damage boost for Fire spells
    pyromaniac = {
        id = "pyromaniac",
        name = "Pyromaniac",
        description = "+10 Damage to Fire spells.",
        rarity = "Common",              -- Common/Uncommon/Rare/Epic/Legendary

        calculate = function(self, context)
            if context.event == "on_spell_cast" then
                if context.tags and context.tags.Fire then
                    return {
                        damage_mod = 10,    -- Flat bonus
                        message = "Pyromaniac!"
                    }
                end
            end
        end
    },

    -- Scaling with tag counts
    tag_master = {
        id = "tag_master",
        name = "Tag Master",
        description = "+1% Damage for every Tag you have.",
        rarity = "Uncommon",

        calculate = function(self, context)
            if context.event == "calculate_damage" then
                local tag_count = 0
                if context.player and context.player.tag_counts then
                    for _, count in pairs(context.player.tag_counts) do
                        tag_count = tag_count + count
                    end
                end

                if tag_count > 0 then
                    return {
                        damage_mult = 1 + (tag_count * 0.01),  -- Multiplicative
                        message = "Tag Master (" .. tag_count .. "%)"
                    }
                end
            end
        end
    },

    -- Special effect
    echo_chamber = {
        id = "echo_chamber",
        name = "Echo Chamber",
        description = "Twin Casts trigger twice.",
        rarity = "Rare",

        calculate = function(self, context)
            if context.event == "on_spell_cast" then
                if context.spell_type == "Twin Cast" then
                    return {
                        repeat_cast = 1,    -- Cast again
                        message = "Echo!"
                    }
                end
            end
        end
    },
}

return Jokers
```

*— Pattern from data/jokers.lua:8-97*

**Gotcha:** `calculate()` is called with `self` as first parameter (use `self, context`).

**Gotcha:** Return nil if joker doesn't apply to this event (not an empty table).

**Gotcha:** `damage_mod` is additive, `damage_mult` is multiplicative (stacks with others).

---

## Trigger Joker Events

\label{recipe:joker-trigger}

**When to use:** Fire joker calculations from game code.

```lua
local JokerSystem = require("wand.joker_system")

-- Trigger when spell is cast
local effects = JokerSystem.trigger_event("on_spell_cast", {
    spell_type = "Twin Cast",
    tags = { Fire = true, Projectile = true },
    damage = 50,
    player = playerEntity
})

-- Apply aggregated effects
local finalDamage = damage + effects.damage_mod
finalDamage = finalDamage * effects.damage_mult

-- Show messages
for _, msg in ipairs(effects.messages) do
    print(msg.joker .. ": " .. msg.text)
end

-- Repeat cast if requested
for i = 1, effects.repeat_cast do
    castSpellAgain()
end

-- Common events:
-- "on_spell_cast" — when casting starts
-- "calculate_damage" — before damage is dealt
-- "on_player_attack" — when player attacks
-- "on_low_health" — health drops below threshold
-- "on_dash" — player dashes
-- "on_pickup" — item collected
```

*— Pattern from wand/joker_system.lua:42-75*

**Gotcha:** Aggregate fields start at default values (damage_mod=0, damage_mult=1).

**Gotcha:** Multiple jokers stack: two +10 damage jokers = +20 total.

**Gotcha:** `effects.messages` is a list of `{ joker = name, text = message }` tables.

---

## Add/Remove Jokers

\label{recipe:joker-manage}

**When to use:** Give player jokers or remove them dynamically.

```lua
local JokerSystem = require("wand.joker_system")

-- Add a joker to player inventory
JokerSystem.add_joker("pyromaniac")
JokerSystem.add_joker("tag_master")

-- Remove a joker
JokerSystem.remove_joker("pyromaniac")

-- Clear all jokers (for testing/reset)
JokerSystem.clear_jokers()

-- Check active jokers
for _, joker in ipairs(JokerSystem.jokers) do
    print("Active:", joker.name)
end

-- Get joker definition
local def = JokerSystem.definitions["pyromaniac"]
if def then
    print(def.name, def.description, def.rarity)
end
```

*— Pattern from wand/joker_system.lua:16-40*

**Gotcha:** `add_joker()` takes the joker ID string, not the definition table.

**Gotcha:** Adding the same joker twice creates two instances (intentional for stacking).

**Gotcha:** Jokers are global — they affect all spells, not per-wand.

---

## Execute a Wand

\label{recipe:wand-execute}

**When to use:** Trigger a wand to cast its spell sequence.

```lua
local WandExecutor = require("wand.wand_executor")

-- Register a wand with cards
local wandId = "player_wand"
WandExecutor.activeWands[wandId] = {
    id = wandId,
    cards = {
        "MOD_TRIPLE_DAMAGE",      -- Modifier
        "MY_LIGHTNING_BOLT",       -- Action
        "MOD_TRIGGER_ON_HIT",      -- Trigger (splits here)
        "ACTION_EXPLOSIVE_FIRE_PROJECTILE"  -- Trigger payload
    },
    trigger = {
        type = "on_player_attack",
        params = {}
    },
    mana_capacity = 100,
    recharge_rate = 5,            -- mana/sec
    cast_delay = 0.1,             -- seconds between casts
    charges = -1,                 -- -1 = infinite
}

-- Execute the wand
local success = WandExecutor.execute(wandId, "on_player_attack")

if success then
    print("Wand cast successfully!")
else
    print("Cast failed (cooldown, mana, or charges)")
end

-- Check if wand can cast
if WandExecutor.canCast(wandId) then
    WandExecutor.execute(wandId)
end
```

*— Pattern from wand/wand_executor.lua:209-228*

**Gotcha:** `execute()` returns false if on cooldown, out of mana, or out of charges.

**Gotcha:** Cards execute in order: modifiers → action → trigger → [trigger payload].

**Gotcha:** `triggerType` parameter should match the wand's trigger type for debugging.

---

## Define Tag Synergies

\label{recipe:tag-synergy}

**When to use:** Create bonuses when player has 3/5/7/9 cards with a tag.

```lua
-- In assets/scripts/wand/tag_evaluator.lua (TAG_BREAKPOINTS table)

local TAG_BREAKPOINTS = {
    Fire = {
        [3] = { type = "stat", stat = "burn_damage_pct", value = 10 },
        [5] = { type = "stat", stat = "burn_tick_rate_pct", value = 15 },
        [7] = { type = "proc", proc_id = "burn_explosion_on_kill" },
        [9] = { type = "proc", proc_id = "burn_spread" }
    },

    MyNewTag = {
        [3] = { type = "stat", stat = "damage_pct", value = 10 },       -- +10% damage
        [5] = { type = "proc", proc_id = "my_custom_proc" },            -- Trigger proc
        [7] = { type = "stat", stat = "crit_chance_pct", value = 15 },  -- +15% crit
        [9] = { type = "proc", proc_id = "my_ultimate_proc" },          -- Ultimate proc
    },
}

-- Bonus types:
-- - "stat": Modifies player stat (damage_pct, crit_chance_pct, move_speed_pct, etc.)
-- - "proc": Triggers a proc effect (implement handler in combat system)

-- Default thresholds (can change):
local DEFAULT_THRESHOLDS = { 3, 5, 7, 9 }
```

*— Pattern from wand/tag_evaluator.lua:8-87*

**Gotcha:** Tag names are case-sensitive and should start with capital letter.

**Gotcha:** Thresholds check exact count: 3, 5, 7, 9 cards (not "at least 3").

**Gotcha:** `proc` bonuses require implementation in combat system to have effect.

---

## Evaluate Tag Bonuses

\label{recipe:tag-evaluate}

**When to use:** Check what bonuses a deck gets from tag synergies.

```lua
local TagEvaluator = require("wand.tag_evaluator")

-- Count tags in deck
local deck = {
    "MY_FIREBALL",           -- tags: Fire, Projectile
    "MY_LIGHTNING_BOLT",     -- tags: Lightning, Projectile
    "ACTION_EXPLOSIVE_FIRE_PROJECTILE",  -- tags: Fire, Projectile, AoE
}

local tagCounts = TagEvaluator.count_tags(deck)
-- Result: { Fire = 2, Lightning = 1, Projectile = 3, AoE = 1 }

-- Get active bonuses
local bonuses = TagEvaluator.evaluate_deck(deck)
-- Result: {
--   Projectile = {
--     count = 3,
--     thresholds_met = { 3 },  -- Hit the 3-card threshold
--     bonuses = { { type = "stat", stat = "damage_pct", value = 10 } }
--   }
-- }

-- Get thresholds for a tag
local thresholds = TagEvaluator.get_thresholds("Fire")
-- Result: { 3, 5, 7, 9 }

-- Check if tag has synergy
if TagEvaluator.has_synergy("Fire") then
    print("Fire tag has breakpoint bonuses!")
end
```

*— Pattern from wand/tag_evaluator.lua:103-247*

**Gotcha:** Tags are normalized: `"fire"` → `"Fire"`, `" Lightning "` → `"Lightning"`.

**Gotcha:** Invalid tags (nil, empty string) are skipped, not errored.

**Gotcha:** `count_tags()` only counts cards that exist in card registry.

---

## Register Custom Behavior

\label{recipe:behavior-register}

**When to use:** Add complex card logic that can't be expressed with fields.

```lua
local BehaviorRegistry = require("wand.card_behavior_registry")

-- Register a complex behavior
BehaviorRegistry.register("chain_explosion", function(ctx)
    local explosions = 0
    local maxChains = ctx.params.max_chains or 3

    local function explode(position, damage)
        if explosions >= maxChains then return end

        -- Find enemies in radius
        local targets = findEnemiesInRadius(position, ctx.params.radius)
        for _, target in ipairs(targets) do
            dealDamage(target, damage)

            -- Recursive chain
            if math.random(100) <= ctx.params.chain_chance then
                explosions = explosions + 1
                explode(target.position, damage * ctx.params.damage_mult)
            end
        end
    end

    explode(ctx.position, ctx.damage)
end, "Recursive chain explosions")

-- Execute behavior
local context = {
    position = { x = 100, y = 200 },
    damage = 50,
    params = {
        max_chains = 5,
        radius = 80,
        chain_chance = 50,       -- 50% chance per target
        damage_mult = 0.7,       -- 70% damage per chain
    }
}

BehaviorRegistry.execute("chain_explosion", context)

-- Use in card definition
Cards.CHAIN_EXPLOSION = {
    id = "CHAIN_EXPLOSION",
    type = "action",
    -- ... other fields ...
    behavior_id = "chain_explosion",
    behavior_params = {
        max_chains = 5,
        radius = 80,
        chain_chance = 50,
        damage_mult = 0.7,
    }
}
```

*— Pattern from wand/card_behavior_registry.lua:14-91*

**Gotcha:** Behaviors are global — register once at init, not per card.

**Gotcha:** Context structure is custom — define what your behavior needs.

**Gotcha:** Use `ctx.params` for card-specific parameters (max_chains, radius, etc.).

---

## Aggregate Modifiers

\label{recipe:modifier-aggregate}

**When to use:** Combine multiple modifier cards into final stats.

```lua
local WandModifiers = require("wand.wand_modifiers")

-- Create empty aggregate
local agg = WandModifiers.createAggregate()
-- Result: { speedMultiplier = 1.0, damageMultiplier = 1.0, ... }

-- Add modifier cards
local modifiers = {
    { speed_modifier = 50, damage_multiplier = 2.0 },
    { damage_modifier = 10, spread_modifier = 5 },
    { multicast_count = 3, spread_angle = 30 },
}

for _, mod in ipairs(modifiers) do
    WandModifiers.addModifier(agg, mod)
end

-- Apply to action card
local action = {
    projectile_speed = 400,
    damage = 25,
    spread_angle = 0,
}

WandModifiers.applyToAction(agg, action)

-- Result:
-- action.projectile_speed = 450  (base 400 + modifier 50)
-- action.damage = 60             (base 25 × multiplier 2.0 + modifier 10)
-- action.spread_angle = 5        (base 0 + modifier 5)
-- action.multicastCount = 3
```

*— Pattern from wand/wand_modifiers.lua:28-100*

**Gotcha:** Modifiers are additive first, then multiplicative: `(base + bonus) × multiplier`.

**Gotcha:** `multicastCount` defaults to 1 (single shot) if no multicast modifier.

**Gotcha:** Aggregates are mutable — `addModifier()` modifies in place.

---

## Detect Spell Type

\label{recipe:spell-type}

**When to use:** Classify a cast block as "Twin Cast", "Mono-Element", etc.

```lua
local SpellTypeEvaluator = require("wand.spell_type_evaluator")

-- Analyze a cast block
local block = {
    actions = {
        { id = "MY_FIREBALL", tags = {"Fire", "Projectile"}, damage = 25 },
    },
    modifiers = {
        multicastCount = 2,
        spreadAngleBonus = 0,
    }
}

local spellType = SpellTypeEvaluator.evaluate(block)
-- Result: "Twin Cast" (1 action, multicast x2)

-- Available spell types:
-- - "Simple Cast"      — 1 action, 0 modifiers
-- - "Twin Cast"        — 1 action, multicast x2
-- - "Scatter Cast"     — 1 action, multicast >2 + spread
-- - "Precision Cast"   — 1 action, speed/damage up, no spread
-- - "Rapid Fire"       — 1 action, low cast delay
-- - "Mono-Element"     — 3+ actions, same element tag
-- - "Combo Chain"      — 3+ actions, different types
-- - "Heavy Barrage"    — 3+ actions, high cost/damage
-- - "Chaos Cast"       — Fallback / mixed

-- Use in jokers
local Jokers = {
    echo_chamber = {
        calculate = function(self, context)
            if context.spell_type == "Twin Cast" then
                return { repeat_cast = 1 }  -- Cast twice!
            end
        end
    }
}
```

*— Pattern from wand/spell_type_evaluator.lua:5-95*

**Gotcha:** Spell type is determined by first matching pattern (order matters).

**Gotcha:** Single-action casts check multicast → speed/damage → delay.

**Gotcha:** Multi-action casts check element tags → type diversity → cost/damage.

---

## Register Wand Trigger

\label{recipe:wand-trigger}

**When to use:** Fire wand automatically when events occur (attack, timer, low health).

```lua
local WandTriggers = require("wand.wand_triggers")
local WandExecutor = require("wand.wand_executor")

-- Initialize trigger system (once at startup)
WandTriggers.init()

-- Register timer trigger (fires every N seconds)
WandTriggers.register(
    "auto_wand",              -- wandId
    {
        type = "every_N_seconds",
        interval = 2.0        -- Fire every 2 seconds
    },
    function(wandId)
        WandExecutor.execute(wandId, "timer")
    end,
    {
        canCast = function()
            return is_state_active(ACTION_STATE)
        end
    }
)

-- Register event trigger (fires on game event)
WandTriggers.register(
    "attack_wand",
    {
        type = "on_player_attack"
    },
    function(wandId)
        WandExecutor.execute(wandId, "on_player_attack")
    end
)

-- Other trigger types:
-- - "every_N_seconds" — Timer-based
-- - "on_player_attack" — Player attacks
-- - "on_bump_enemy" — Collision with enemy
-- - "on_dash" — Player dashes
-- - "on_low_health" — Health below threshold
-- - "on_pickup" — Item collected
-- - "on_distance_traveled" — Distance threshold

-- Update trigger system (every frame)
WandTriggers.update(dt)

-- Cleanup (on shutdown)
WandTriggers.cleanup()
```

*— Pattern from wand/wand_triggers.lua:91-110, 150-220*

**Gotcha:** Call `WandTriggers.init()` once at startup, `cleanup()` on shutdown.

**Gotcha:** `canCast` callback optional — checks if wand should fire (state, cooldown, etc.).

**Gotcha:** Timer triggers use `timer` system — ensure it's updated each frame.

---

## Complete Example: Custom Spell

**When to use:** Combine cards, modifiers, and jokers for complex spell behavior.

```lua
-- Step 1: Define cards
-- In assets/scripts/data/cards.lua

Cards.CHAIN_LIGHTNING = {
    id = "CHAIN_LIGHTNING",
    type = "action",
    mana_cost = 20,
    damage = 20,
    damage_type = "lightning",
    projectile_speed = 800,
    lifetime = 1000,
    radius_of_effect = 0,
    tags = { "Lightning", "Projectile", "Arcane" },
    test_label = "CHAIN\nlightning",

    -- Custom fields
    chain_targets = 3,
    chain_range = 150,
}

Cards.MOD_ARC_SPREAD = {
    id = "MOD_ARC_SPREAD",
    type = "modifier",
    mana_cost = 15,
    tags = { "Arcane" },
    test_label = "ARC\nspread",

    multicast_count = 5,
    spread_angle = 60,
    circular_pattern = false,
}

-- Step 2: Define joker
-- In assets/scripts/data/jokers.lua

lightning_amplifier = {
    id = "lightning_amplifier",
    name = "Lightning Amplifier",
    description = "+25% damage to Lightning spells with 3+ targets hit.",
    rarity = "Rare",

    calculate = function(self, context)
        if context.event == "on_spell_hit" then
            if context.tags and context.tags.Lightning then
                if context.targets_hit and context.targets_hit >= 3 then
                    return {
                        damage_mult = 1.25,
                        message = "Lightning Amplifier!"
                    }
                end
            end
        end
    end
}

-- Step 3: Setup wand
-- In game code

local WandExecutor = require("wand.wand_executor")
local WandTriggers = require("wand.wand_triggers")
local JokerSystem = require("wand.joker_system")

-- Add joker to player
JokerSystem.add_joker("lightning_amplifier")

-- Register wand
WandExecutor.activeWands["lightning_wand"] = {
    id = "lightning_wand",
    cards = {
        "MOD_ARC_SPREAD",     -- 5-way spread
        "CHAIN_LIGHTNING",    -- Lightning bolt
    },
    trigger = {
        type = "on_player_attack"
    },
    mana_capacity = 100,
    recharge_rate = 10,
    cast_delay = 0.2,
    charges = -1,
}

-- Register trigger
WandTriggers.register(
    "lightning_wand",
    { type = "on_player_attack" },
    function(wandId)
        WandExecutor.execute(wandId, "on_player_attack")
    end
)

-- Step 4: Handle execution
local signal = require("external.hump.signal")

signal.register("projectile_hit", function(projectile, target, damage)
    local script = getScriptTableFromEntityID(projectile)
    if not script or script.cardId ~= "CHAIN_LIGHTNING" then return end

    -- Count targets hit
    script.targetsHit = (script.targetsHit or 0) + 1

    -- Trigger joker event after 3+ hits
    if script.targetsHit >= 3 then
        local effects = JokerSystem.trigger_event("on_spell_hit", {
            tags = { Lightning = true, Projectile = true },
            targets_hit = script.targetsHit,
        })

        -- Apply bonus damage
        damage = damage * effects.damage_mult

        -- Show messages
        for _, msg in ipairs(effects.messages) do
            showFloatingText(target, msg.text)
        end
    end
end)

-- Result: Player attack fires 5 lightning bolts in arc, each chains to 3 targets,
-- and joker boosts damage by 25% after hitting 3+ enemies.
```

*— Combined pattern from data/cards.lua, data/jokers.lua, wand/wand_executor.lua*

**Gotcha:** Joker events must be triggered manually in game code (not automatic).

**Gotcha:** Card custom fields (chain_targets, chain_range) need implementation in projectile system.

**Gotcha:** `targetsHit` tracking requires script table on projectile entity.

\newpage

# Chapter 8: AI System

The AI system uses GOAP (Goal-Oriented Action Planning) with:
- **Entity types**: Define initial worldstate and goal state
- **Blackboard**: Per-entity storage for AI state (hunger, health, cooldowns)
- **Actions**: Reusable behaviors with preconditions, postconditions, and execution logic
- **Goal selectors**: Choose current goal based on worldstate (desire, veto, hysteresis)
- **Worldstate updaters**: Update worldstate from blackboard/sensory data each frame

## Define AI Entity Type

\label{recipe:ai-entity-type}

**When to use:** Create a new AI archetype with initial worldstate and default goal.

```lua
-- File: assets/scripts/ai/entity_types/gold_digger.lua
return {
    initial = {
        hungry = true,
        enemyvisible = false,
        resourceAvailable = false,
        underAttack = false,
        candigforgold = true  -- can dig for gold
    },
    goal = {
        hungry = false  -- default goal: satisfy hunger
    }
}
```

*— Pattern from ai/entity_types/gold_digger.lua*

**Gotcha:** `initial` defines the starting worldstate atoms (all boolean or comparable values).

**Gotcha:** `goal` defines the default target state for GOAP planner.

**Gotcha:** Entity type filename must match the ID used when spawning AI entities.

---

## Initialize AI Blackboard

\label{recipe:ai-blackboard-init}

**When to use:** Set up entity-specific AI state (hunger, health, timers).

```lua
-- File: assets/scripts/ai/blackboard_init/healer.lua
return function(entity)
    local bb = ai.get_blackboard(entity)

    -- Set initial values
    bb:set_float("hunger", 0.5)
    bb:set_float("health", 5)
    bb:set_float("max_health", 10)
    bb:set_float("last_heal_time", 0)

    log_debug("Blackboard initialized for healer entity: " .. tostring(entity))
end
```

*— Pattern from ai/blackboard_init/healer.lua*

**Gotcha:** Blackboard uses typed setters: `set_float()`, `set_int()`, `set_string()`, `set_bool()`.

**Gotcha:** This function is called once when the AI entity is created.

**Gotcha:** Use global helpers like `setBlackboardFloat(entity, "hunger", 0.5)` for convenience.

---

## Define AI Action

\label{recipe:ai-action}

**When to use:** Create reusable AI behavior (wander, attack, heal).

```lua
-- File: assets/scripts/ai/actions/eat.lua
return {
    name = "eat",
    cost = 1,  -- GOAP planning cost (lower = preferred)

    -- Preconditions: when this action is available
    pre = { hungry = true },

    -- Postconditions: worldstate after action completes
    post = { hungry = false },

    -- Called once when action starts
    start = function(e)
        log_debug("Entity", e, "is eating.")
    end,

    -- Called each frame while action runs
    -- Must return ActionResult.SUCCESS, RUNNING, or FAILURE
    update = function(e, dt)
        log_debug("Entity", e, "eat update.")
        wait(1.0)  -- coroutine: wait 1 second

        local bb = ai.get_blackboard(e)
        bb:set_float("hunger", bb:get_float("hunger") + 0.5)

        return ActionResult.SUCCESS
    end,

    -- Called once when action completes
    finish = function(e)
        log_debug("Done eating: entity", e)
    end
}
```

*— Pattern from ai/actions/eat.lua*

**Gotcha:** Action `name` must be unique (used for GOAP planning).

**Gotcha:** `update()` can use `wait()`, `coroutine.yield()`, or return immediately.

**Gotcha:** Preconditions/postconditions are matched against worldstate, not blackboard.

---

## AI Action with Coroutine

\label{recipe:ai-action-coroutine}

**When to use:** Long-running AI behavior (wander to location, cast spell).

```lua
-- File: assets/scripts/ai/actions/wander.lua
return {
    name = "wander",
    cost = 5,  -- higher cost = less preferred
    pre = { wander = false },
    post = { wander = true },

    start = function(e)
        log_debug("Entity", e, "is wandering.")
    end,

    update = function(e, dt)
        log_debug("Entity", e, "wander update.")
        wait(1.0)

        -- Pick random destination
        local goalLoc = Vec2(
            random_utils.random_float(0, globals.screenWidth()),
            random_utils.random_float(0, globals.screenHeight())
        )

        -- Start walk animation
        startEntityWalkMotion(e)

        -- Loop until destination reached
        while true do
            if moveEntityTowardGoalOneIncrement(e, goalLoc, dt) == false then
                log_debug("Entity", e, "has reached the wander target location.")
                break
            end
        end

        return ActionResult.SUCCESS
    end,

    finish = function(e)
        log_debug("Done wandering: entity", e)
    end
}
```

*— Pattern from ai/actions/wander.lua*

**Gotcha:** Use `while true` loops with `coroutine.yield()` or engine helpers for multi-frame behavior.

**Gotcha:** Higher `cost` makes action less desirable in GOAP planning.

---

## AI Action with Abort

\label{recipe:ai-action-abort}

**When to use:** Action that watches worldstate and aborts if conditions change.

```lua
-- File: assets/scripts/ai/actions/dig_for_gold.lua
return {
    name = "digforgold",
    cost = 1,
    pre = { candigforgold = true },
    post = { candigforgold = false },

    -- React to worldstate changes (abort if these atoms change)
    watch = { "hungry", "duplicator_available", "underAttack" },

    start = function(e)
        log_debug("Entity", e, "is digging for gold.")
    end,

    update = function(e, dt)
        log_debug("Entity", e, "dig update.")

        local doneDigging = false

        -- Shake animation with particles
        timer.every(0.5,
            function()
                if not registry:valid(e) or e == entt_null then
                    log_debug("Entity", e, "is no longer valid, stopping dig action.")
                    return ActionResult.FAILURE
                end

                local transform = registry:get(e, Transform)
                local offsetX = math.sin(os.clock() * 10) * 30
                transform.visualX = transform.visualX + offsetX

                playSoundEffect("effects", "dig-sound")
                spawnCircularBurstParticles(
                    transform.visualX + transform.visualW / 2,
                    transform.visualY + transform.visualH / 2,
                    3, 0.5
                )
            end,
            5,    -- 5 times
            true, -- immediate
            function() doneDigging = true end
        )

        -- Wait for animation
        while true do
            if doneDigging then break
            else coroutine.yield() end
        end

        -- Spawn gold coin, play effects...
        setBlackboardFloat(e, "last_dig_time", GetTime())

        return ActionResult.SUCCESS
    end,

    finish = function(e)
        log_debug("Done digging: entity", e)
    end,

    -- Called when planner aborts this action mid-run
    abort = function(e, reason)
        log_debug("digforgold abort on", e, "reason:", tostring(reason))
        -- Stop timers, clear particles, unlock resources, etc.
    end,
}
```

*— Pattern from ai/actions/dig_for_gold.lua*

**Gotcha:** `watch` defines worldstate atoms that trigger abort if changed mid-action.

**Gotcha:** `abort()` must clean up timers, particles, and any resources the action acquired.

**Gotcha:** Use `watch = "*"` to react to any worldstate change.

---

## Define Goal Selector

\label{recipe:ai-goal-selector}

**When to use:** Choose which goal the AI should pursue based on worldstate.

```lua
-- File: assets/scripts/ai/goal_selectors/healer.lua
return function(entity)
    if ai.get_worldstate(entity, "canhealother") then
        ai.set_goal(entity, { canhealother = false })  -- use heal_other action
    else
        ai.set_goal(entity, { wander = true })  -- use wander action (idle)
    end
end
```

*— Pattern from ai/goal_selectors/healer.lua*

**Gotcha:** Goal selector runs each frame to pick the current goal dynamically.

**Gotcha:** Call `ai.set_goal()` with the target worldstate (GOAP planner finds actions to reach it).

**Gotcha:** Simple selectors use if/else logic; complex selectors use desire + hysteresis.

---

## Goal Selector with Engine

\label{recipe:ai-goal-selector-engine}

**When to use:** Advanced goal selection with desire functions, hysteresis, and band arbitration.

```lua
-- File: assets/scripts/ai/goal_selectors/gold_digger.lua
local selector = require("ai.goal_selector_engine")

return function(e)
    local def = ai.get_entity_ai_def(e)

    -- Use shared policy/goals by default
    def.policy = def.policy or ai.policy
    def.goals  = def.goals  or ai.goals

    -- (Optional) Per-type tweaks:
    -- def.policy.band_rank = { COMBAT=4, SURVIVAL=3, WORK=3, IDLE=1 }
    -- def.goals.DIG_FOR_GOLD.persist = 0.10

    log_debug("Gold Digger Goal Selector for entity " .. tostring(e))

    selector.select_and_apply(e)
end
```

*— Pattern from ai/goal_selectors/gold_digger.lua*

**Global goal definitions (from ai/init.lua):**

```lua
ai.policy = {
    band_rank = { COMBAT=4, SURVIVAL=3, WORK=2, IDLE=1 }
}

ai.goals = {
    DIG_FOR_GOLD = {
        band = "WORK",
        persist = 0.08,  -- hysteresis: stick to current goal

        -- Desire function: 0.0 = no desire, 1.0 = max desire
        desire = function(e, S)
            return ai.get_worldstate(e, "candigforgold") and 1.0 or 0.0
        end,

        -- Veto function: return true to block this goal
        veto = function(e, S)
            -- return ai.get_worldstate(e, "underAttack")
        end,

        -- Apply goal: set target worldstate
        on_apply = function(e)
            ai.set_goal(e, { candigforgold = false })
        end
    },

    WANDER = {
        band = "IDLE",
        persist = 0.05,
        desire = function(e, S) return 0.2 end,
        on_apply = function(e)
            ai.patch_worldstate(e, "wander", false)  -- clear sticky toggle
            ai.set_goal(e, { wander = true })
        end
    },
}
```

*— Pattern from ai/init.lua*

**Gotcha:** `persist` adds hysteresis (prevents goal thrashing by boosting current goal's desire).

**Gotcha:** `band_rank` prioritizes goal categories (COMBAT > SURVIVAL > WORK > IDLE).

**Gotcha:** Higher-ranked bands can override if their desire is >= 0.4.

---

## Define Worldstate Updater

\label{recipe:ai-worldstate-updater}

**When to use:** Update worldstate from blackboard or sensory data each frame.

```lua
-- File: assets/scripts/ai/worldstate_updaters.lua
return {
    hunger_check = function(entity, dt)
        local bb = ai.get_blackboard(entity)

        if not bb:contains("hunger") then
            log_debug("Hunger key not found in blackboard for entity: " .. tostring(entity))
            return
        end

        local hunger = bb:get_float("hunger")
        bb:set_float("hunger", hunger - dt * 0.01)  -- decrement over time

        if hunger < 0 then hunger = 0 end

        if hunger < 0.3 then
            ai.set_worldstate(entity, "hungry", true)
            log_debug("Entity " .. tostring(entity) .. " is hungry.")
        end
    end,

    can_heal_other = function(entity, dt)
        if not blackboardContains(entity, "last_heal_time") then return end

        local heal_time = getBlackboardFloat(entity, "last_heal_time")
        local heal_cooldown = findInTable(globals.creature_defs, "id", "healer").heal_cooldown_seconds or 10

        if (GetTime() - heal_time) < heal_cooldown then
            ai.set_worldstate(entity, "canhealother", false)
            log_debug("can_heal_other: Entity " .. tostring(entity) .. " cannot heal yet.")
        else
            ai.set_worldstate(entity, "canhealother", true)
            log_debug("can_heal_other: Entity " .. tostring(entity) .. " can heal now.")
        end
    end,

    can_dig_for_gold = function(entity, dt)
        if not blackboardContains(entity, "last_dig_time") then return end

        local dig_time = getBlackboardFloat(entity, "last_dig_time")
        local dig_cooldown = findInTable(globals.creature_defs, "id", "gold_digger").dig_cooldown_seconds or 10

        if (GetTime() - dig_time) < dig_cooldown then
            ai.set_worldstate(entity, "candigforgold", false)
            log_debug("can_dig_for_gold: Entity " .. tostring(entity) .. " cannot dig for gold yet.")
        else
            ai.set_worldstate(entity, "candigforgold", true)
            log_debug("can_dig_for_gold: Entity " .. tostring(entity) .. " can dig for gold now.")
        end
    end,
}
```

*— Pattern from ai/worldstate_updaters.lua*

**Gotcha:** Worldstate updaters run every frame for each AI entity.

**Gotcha:** Use `ai.set_worldstate(entity, "atom", value)` to update worldstate atoms.

**Gotcha:** Blackboard stores continuous values (hunger, health); worldstate stores discrete atoms (hungry = true/false).

---

## AI System Flow

\label{recipe:ai-system-flow}

**When to use:** Understand how the AI system executes each frame.

**Frame-by-frame execution:**

1. **Worldstate updaters** run (update worldstate from blackboard/sensory data)
2. **Goal selector** runs (choose current goal based on worldstate)
3. **GOAP planner** finds action sequence to reach goal (if needed)
4. **Current action** `update()` runs (executes behavior, returns SUCCESS/RUNNING/FAILURE)
5. **Action completes** → postconditions applied to worldstate → next action starts
6. **Worldstate change detected** (if action has `watch` list) → abort current action → replan

**Example flow for gold_digger:**

```
Frame 1:
  - worldstate_updaters.can_dig_for_gold() sets candigforgold=true (cooldown expired)
  - goal_selector sets goal { candigforgold = false }
  - GOAP planner finds action "digforgold" (pre: candigforgold=true, post: candigforgold=false)
  - Action "digforgold" start() called

Frames 2-50:
  - Action "digforgold" update() runs (coroutine yields each frame)
  - Shake animation, particles, sound effects

Frame 51:
  - Action "digforgold" update() returns ActionResult.SUCCESS
  - Action "digforgold" finish() called
  - Postcondition applied: candigforgold=false
  - GOAP planner has no more actions → goal reached

Frame 52:
  - worldstate_updaters.can_dig_for_gold() sets candigforgold=false (cooldown active)
  - goal_selector sets goal { wander = true } (fallback to IDLE)
  - GOAP planner finds action "wander"
  - Action "wander" start() called
```

**Gotcha:** If worldstate changes mid-action (e.g., `hungry` becomes true while digging), action is aborted and replanned.

**Gotcha:** Actions with `watch = "*"` abort on any worldstate change; `watch = { "hungry" }` aborts only if `hungry` changes.

---

## AI API Reference

\label{recipe:ai-api}

**When to use:** Quick reference for AI system functions.

**Blackboard API:**

```lua
-- C++ API (typed)
local bb = ai.get_blackboard(entity)
bb:set_float("hunger", 0.5)
bb:set_int("gold", 100)
bb:set_string("target", "enemy_123")
bb:set_bool("alert", true)

local hunger = bb:get_float("hunger")
local gold = bb:get_int("gold")
local target = bb:get_string("target")
local alert = bb:get_bool("alert")

local hasHunger = bb:contains("hunger")

-- Lua helpers (use these for convenience)
setBlackboardFloat(entity, "hunger", 0.5)
setBlackboardInt(entity, "gold", 100)
setBlackboardString(entity, "target", "enemy_123")

local hunger = getBlackboardFloat(entity, "hunger")
local gold = getBlackboardInt(entity, "gold")
local target = getBlackboardString(entity, "target")

local hasHunger = blackboardContains(entity, "hunger")
```

**Worldstate API:**

```lua
-- Set worldstate atom
ai.set_worldstate(entity, "hungry", true)
ai.set_worldstate(entity, "candigforgold", false)

-- Get worldstate atom
local hungry = ai.get_worldstate(entity, "hungry")
local canDig = ai.get_worldstate(entity, "candigforgold")

-- Patch worldstate (update without replacing entire state)
ai.patch_worldstate(entity, "wander", false)

-- Set goal (target worldstate for GOAP planner)
ai.set_goal(entity, { hungry = false })
ai.set_goal(entity, { candigforgold = false, wander = true })
```

**Entity definition API:**

```lua
-- Get entity's AI definition (per-entity table with policy/goals)
local def = ai.get_entity_ai_def(entity)

-- Customize per-entity policy/goals
def.policy = { band_rank = { COMBAT=4, SURVIVAL=3, WORK=2, IDLE=1 } }
def.goals = ai.goals  -- use shared goals
def.goals.DIG_FOR_GOLD.persist = 0.15  -- increase hysteresis for this entity
```

**Action result enums:**

```lua
return ActionResult.SUCCESS   -- action completed successfully
return ActionResult.RUNNING   -- action still in progress
return ActionResult.FAILURE   -- action failed
```

**Gotcha:** Blackboard stores entity-specific data; worldstate stores planner-visible atoms.

**Gotcha:** Goal selector runs every frame; GOAP planner runs only when goal changes or action completes.

\newpage

# Chapter 9: Data Definitions

\label{chapter:data-definitions}

This chapter documents the structure of centralized data files that define game content: cards, jokers, projectiles, avatars, and shader presets. All data files are located in `assets/scripts/data/`.

**Key Principles:**

- **Centralized registry**: Each data file exports a single table containing all definitions
- **ID consistency**: Table keys must match the `id` field
- **Tag-based synergies**: Tags enable joker bonuses and tag threshold synergies
- **Extensibility**: Custom fields are allowed; validator only checks critical fields

**Validation:**

Use `assets/scripts/tools/content_validator.lua` to validate all content:

```lua
-- Standalone validation
dofile("assets/scripts/tools/content_validator.lua")

-- Runtime validation (warnings only)
local ContentValidator = require("tools.content_validator")
ContentValidator.validate_all(true)
```

---

## Define Action Card

\label{recipe:define-action-card}

**When to use:** Adding a new spell that casts projectiles or creates effects.

**Pattern:** Action cards define projectiles, AoE effects, and hazards. They are the "casting" portion of a wand.

**Example:**

```lua
-- In assets/scripts/data/cards.lua

Cards.MY_FIREBALL = {
    -- Required fields
    id = "MY_FIREBALL",              -- Must match table key
    type = "action",                  -- "action", "modifier", or "trigger"
    mana_cost = 12,
    tags = { "Fire", "Projectile" },
    test_label = "MY\nfireball",     -- Display label (use \n for line breaks)

    -- Action-specific fields
    damage = 25,
    damage_type = "fire",            -- fire/ice/lightning/poison/arcane/holy/void/magic
    projectile_speed = 400,
    lifetime = 2000,                 -- ms
    radius_of_effect = 50,           -- 0 = no AoE

    -- Optional fields
    spread_angle = 0,                -- Degrees for spread shots
    cast_delay = 0,                  -- ms delay before cast
    homing_strength = 0,             -- 0-15 for homing
    ricochet_count = 0,              -- Bounces
    max_uses = -1,                   -- -1 = infinite
    weight = 1,                      -- Spawn weight for random generation
}
```

**Action card fields:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier (must match table key) |
| `type` | string | "action" |
| `mana_cost` | number | Mana cost to cast |
| `tags` | table | Tag list for joker synergies |
| `test_label` | string | Display label (use `\n` for line breaks) |
| `damage` | number | Base damage |
| `damage_type` | string | fire/ice/lightning/poison/arcane/holy/void/magic |
| `projectile_speed` | number | Projectile velocity |
| `lifetime` | number | Projectile lifetime in milliseconds |
| `radius_of_effect` | number | AoE radius (0 = no AoE) |
| `spread_angle` | number | Degrees for spread shots |
| `cast_delay` | number | Milliseconds delay before cast |
| `homing_strength` | number | 0-15 for homing behavior |
| `ricochet_count` | number | Number of bounces |
| `max_uses` | number | -1 = infinite, N = limited uses |
| `weight` | number | Spawn weight for random generation |
| `timer_ms` | number | Timer trigger interval (for timed effects) |

**Provenance:** See `assets/scripts/data/cards.lua:15-42` for template, `cards.lua:60-102` for complete example.

**Gotcha:** `id` field must match table key. Validator warns if they don't match.

**Gotcha:** `test_label` uses `\n` for line breaks, not literal newlines.

**Gotcha:** `radius_of_effect = 0` means no AoE; set to positive value for area damage.

---

## Define Modifier Card

\label{recipe:define-modifier-card}

**When to use:** Adding modifiers that affect subsequent action cards in the wand.

**Pattern:** Modifier cards apply buffs/debuffs to actions that follow them in the wand sequence.

**Example:**

```lua
-- In assets/scripts/data/cards.lua

Cards.MOD_DAMAGE_UP = {
    id = "MOD_DAMAGE_UP",
    type = "modifier",
    max_uses = -1,
    mana_cost = 6,

    -- Modifier fields (additive bonuses)
    damage_modifier = 10,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 5,

    -- Modifier behavior
    multicast_count = 1,         -- How many times to cast next action
    revisit_limit = 2,           -- How many actions this modifier affects

    weight = 2,
    tags = { "Buff", "Brute" },
    test_label = "MOD\ndamage\nup",
}
```

**Modifier card fields:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier (must match table key) |
| `type` | string | "modifier" |
| `mana_cost` | number | Mana cost to cast |
| `tags` | table | Tag list for joker synergies |
| `test_label` | string | Display label |
| `damage_modifier` | number | Additive damage bonus |
| `spread_modifier` | number | Additive spread bonus (negative = tighter) |
| `speed_modifier` | number | Additive speed multiplier |
| `lifetime_modifier` | number | Additive lifetime multiplier |
| `critical_hit_chance_modifier` | number | Additive crit chance % |
| `seek_strength` | number | Homing strength (0-15) |
| `multicast_count` | number | How many times to cast next action |
| `revisit_limit` | number | How many actions this modifier affects |
| `teleport_cast_from_enemy` | boolean | Cast from nearest enemy position |
| `health_sacrifice_ratio` | number | % of health to sacrifice |
| `damage_bonus_ratio` | number | Damage bonus per sacrificed health |
| `wand_refresh` | boolean | Reset wand to beginning |

**Provenance:** See `assets/scripts/data/cards.lua:302-395` for examples.

**Gotcha:** Modifiers apply to the next `revisit_limit` actions in the wand sequence.

**Gotcha:** `multicast_count` repeats the next action N times (simultaneous or looped, depending on avatar).

---

## Define Trigger Card

\label{recipe:define-trigger-card}

**When to use:** Adding trigger conditions that auto-cast wands.

**Pattern:** Trigger cards define when a wand should automatically cast (e.g., every N seconds, on hit).

**Example:**

```lua
-- In assets/scripts/data/cards.lua

Cards.TRIGGER_TIMER = {
    id = "every_N_seconds",
    type = "trigger",
    max_uses = -1,
    mana_cost = 0,
    weight = 0,
    tags = {},
    description = "Casts spells automatically every few seconds",

    -- Trigger-specific fields
    trigger_interval = 2.0,      -- Seconds between auto-casts
    trigger_event = "timer",     -- "timer", "on_hit", "on_kill", etc.
}
```

**Trigger card fields:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier |
| `type` | string | "trigger" |
| `mana_cost` | number | Mana cost (usually 0) |
| `tags` | table | Tag list |
| `description` | string | Human-readable description |
| `trigger_interval` | number | Seconds between auto-casts |
| `trigger_event` | string | "timer", "on_hit", "on_kill", etc. |

**Provenance:** See `assets/scripts/data/cards.lua:945-965` for examples.

**Gotcha:** Trigger cards are typically assigned to wands, not directly cast.

---

## Define Joker

\label{recipe:define-joker}

**When to use:** Adding passive artifacts that modify gameplay rules or provide bonuses.

**Pattern:** Jokers use a `calculate()` function that reacts to events and returns modifier tables.

**Example:**

```lua
-- In assets/scripts/data/jokers.lua

Jokers.pyromaniac = {
    id = "pyromaniac",
    name = "Pyromaniac",
    description = "+10 Damage to Mono-Element (Fire) Spells.",
    rarity = "Common",

    calculate = function(self, context)
        -- React to spell cast events
        if context.event == "on_spell_cast" then
            if context.spell_type == "Mono-Element" and
               context.tags and context.tags.Fire then
                return {
                    damage_mod = 10,
                    message = "Pyromaniac!"
                }
            end
        end
    end
}
```

**Joker fields:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier (must match table key) |
| `name` | string | Display name |
| `description` | string | Human-readable description |
| `rarity` | string | "Common", "Uncommon", "Rare", "Epic", "Legendary" |
| `calculate` | function | Event handler returning modifiers |

**Context parameter:**

The `context` table passed to `calculate()` contains:

```lua
{
    event = "on_spell_cast",        -- Event type
    spell_type = "Mono-Element",    -- Spell classification
    tags = { Fire = true },         -- Tag presence map
    player = { tag_counts = {...} }, -- Player state
    damage = 100,                   -- Base damage (for calculate_damage)
}
```

**Return value:**

Return a table with modifier fields:

```lua
{
    damage_mod = 10,           -- Additive damage
    damage_mult = 1.5,         -- Multiplicative damage
    repeat_cast = 1,           -- Repeat cast N times
    message = "Joker name!"    -- Visual feedback message
}
```

**Common events:**

- `"on_spell_cast"`: When spell is cast
- `"calculate_damage"`: Before damage calculation
- `"on_hit"`: When projectile hits
- `"on_kill"`: When enemy dies

**Provenance:** See `assets/scripts/data/jokers.lua:10-75` for examples.

**Gotcha:** `calculate()` may be called multiple times per event; ensure idempotent logic.

**Gotcha:** Return `nil` if joker doesn't apply to current event (don't return empty table).

---

## Define Projectile Preset

\label{recipe:define-projectile-preset}

**When to use:** Creating reusable projectile configurations for cards.

**Pattern:** Projectile presets define visual and behavioral properties. Reference via `projectile_preset` field in cards.

**Example:**

```lua
-- In assets/scripts/data/projectiles.lua

Projectiles.fireball = {
    id = "fireball",
    speed = 400,
    damage_type = "fire",
    movement = "straight",
    collision = "explode",
    explosion_radius = 60,
    lifetime = 2000,

    -- On-hit effects
    on_hit_effect = "burn",
    on_hit_duration = 3000,

    tags = { "Fire", "Projectile", "AoE" },
}
```

**Projectile fields:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier |
| `speed` | number | Projectile velocity |
| `damage_type` | string | fire/ice/lightning/poison/arcane/holy/void/magic |
| `movement` | string | "straight", "homing", "arc", "orbital", "custom" |
| `collision` | string | "destroy", "pierce", "bounce", "explode", "pass_through", "chain" |
| `lifetime` | number | Milliseconds before despawn |
| `explosion_radius` | number | AoE radius (for collision="explode") |
| `pierce_count` | number | How many enemies to pierce |
| `chain_count` | number | How many enemies to chain to |
| `chain_range` | number | Chain range in pixels |
| `chain_damage_decay` | number | Damage multiplier per chain (0.7 = 30% reduction) |
| `homing_strength` | number | 0-15 homing intensity |
| `on_hit_effect` | string | "burn", "freeze", "poison", etc. |
| `on_hit_duration` | number | Effect duration in milliseconds |
| `tags` | table | Tag list |

**Valid movement types:**

- `"straight"`: Linear trajectory
- `"homing"`: Seeks nearest enemy
- `"arc"`: Parabolic trajectory
- `"orbital"`: Circles around caster
- `"custom"`: Requires custom behavior script

**Valid collision types:**

- `"destroy"`: Despawn on hit
- `"pierce"`: Pass through N enemies
- `"bounce"`: Ricochet off walls/enemies
- `"explode"`: Create AoE explosion
- `"pass_through"`: Ignore collisions
- `"chain"`: Jump to nearby enemies

**Provenance:** See `assets/scripts/data/projectiles.lua:14-80` for examples.

**Gotcha:** `explosion_radius` only applies if `collision = "explode"`.

**Gotcha:** `chain_damage_decay` is multiplicative (0.7 = 70% of previous damage).

---

## Define Avatar

\label{recipe:define-avatar}

**When to use:** Creating powerful mid-run transformations with global rule changes.

**Pattern:** Avatars unlock based on session stats and provide permanent effects.

**Example:**

```lua
-- In assets/scripts/data/avatars.lua

Avatars.wildfire = {
    name = "Avatar of Wildfire",
    description = "Your flames consume everything.",

    -- Unlock Condition (Session-based)
    unlock = {
        kills_with_fire = 100,
        OR_fire_tags = 7
    },

    -- Global Effects
    effects = {
        {
            type = "rule_change",
            rule = "multicast_loops",
            desc = "Multicast modifiers now Loop the cast block instead of simultaneous cast."
        },
        {
            type = "stat_buff",
            stat = "hazard_tick_rate_pct",
            value = 100  -- 2x tick speed
        }
    }
}
```

**Avatar fields:**

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Display name |
| `description` | string | Flavor text |
| `unlock` | table | Unlock conditions |
| `effects` | table | List of effect definitions |

**Unlock condition patterns:**

```lua
-- Single condition
unlock = {
    kills_with_fire = 100
}

-- OR condition (either satisfies)
unlock = {
    kills_with_fire = 100,
    OR_fire_tags = 7
}

-- Multiple OR conditions
unlock = {
    damage_blocked = 5000,
    OR_defense_tags = 7
}
```

**Effect types:**

**Rule Change:**

```lua
{
    type = "rule_change",
    rule = "multicast_loops",
    desc = "Multicast modifiers now Loop the cast block instead of simultaneous cast."
}
```

**Stat Buff:**

```lua
{
    type = "stat_buff",
    stat = "hazard_tick_rate_pct",
    value = 100  -- +100% = 2x tick speed
}
```

**Proc Effect:**

```lua
{
    type = "proc",
    trigger = "on_cast_4th",
    effect = "global_barrier",
    value = 10  -- 10% HP barrier
}
```

**Common unlock stats:**

- `kills_with_fire`, `kills_with_ice`, etc.
- `damage_blocked`, `damage_dealt`
- `distance_moved`, `mana_spent`
- `crits_dealt`, `hp_lost`
- Tag counts: `fire_tags`, `defense_tags`, `mobility_tags`, etc.

**Common rule changes:**

- `"multicast_loops"`: Multicast loops instead of simultaneous
- `"summons_inherit_block"`: Summons inherit block/thorns
- `"move_casts_trigger_onhit"`: Movement-triggered wands apply on-hit effects
- `"crit_chains"`: Crits chain to nearby enemies
- `"summon_cast_share"`: Summons copy your projectiles
- `"missing_hp_dmg"`: Damage scales with missing HP

**Provenance:** See `assets/scripts/data/avatars.lua:3-137` for all avatars.

**Gotcha:** Avatar effects are session-persistent once unlocked.

**Gotcha:** Unlock conditions use `OR_` prefix for alternative requirements.

---

## Define Shader Preset

\label{recipe:define-shader-preset}

**When to use:** Creating reusable shader configurations for visual effects.

**Pattern:** Shader presets define one or more shader passes with uniforms.

**Example:**

```lua
-- In assets/scripts/data/shader_presets.lua

ShaderPresets.holographic = {
    id = "holographic",
    passes = {"3d_skew_holo"},
    uniforms = {
        sheen_strength = 0.8,
        sheen_speed = 1.2,
        sheen_width = 0.3,
    },
}

-- Multi-pass preset
ShaderPresets.legendary_card = {
    id = "legendary_card",
    passes = {"3d_skew_holo", "3d_skew_foil"},
    uniforms = {
        sheen_strength = 1.0,
    },
    pass_uniforms = {
        ["3d_skew_foil"] = {
            sheen_speed = 0.5,
        },
    },
}
```

**Shader preset fields:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier |
| `passes` | table | List of shader names (applied in order) |
| `uniforms` | table | Uniforms applied to all passes |
| `pass_uniforms` | table | Per-pass uniform overrides |
| `needs_atlas_uniforms` | boolean | Auto-inject atlas uniforms (auto-detected for 3d_skew_*) |

**Usage:**

```lua
-- Replace all passes with preset
applyShaderPreset(registry, entity, "holographic", {
    sheen_strength = 1.0,  -- override uniform
})

-- Append preset passes to existing
addShaderPreset(registry, entity, "glow", { intensity = 1.5 })

-- Clear all passes
clearShaderPasses(registry, entity)

-- Add single pass directly
addShaderPass(registry, entity, "outline", { thickness = 2.0 })
```

**Common shader families:**

- `3d_skew_*`: Card shaders (holo, foil, polychrome, negative, prismatic)
- `liquid_*`: Fluid effects (oil, water, lava)
- `dissolve`: Card destruction effect

**Provenance:** See `assets/scripts/data/shader_presets.lua:20-85` for examples.

**Gotcha:** `pass_uniforms` allows per-pass customization in multi-pass presets.

**Gotcha:** Shader families with `3d_skew_` prefix auto-detect `needs_atlas_uniforms = true`.

---

## Validate Content Definitions

\label{recipe:validate-content}

**When to use:** After adding/modifying cards, jokers, projectiles, avatars, or shader presets.

**Pattern:** Use the content validator to catch errors and warnings.

**Example:**

```lua
-- Standalone validation (run in-game or via dofile)
dofile("assets/scripts/tools/content_validator.lua")

-- Runtime validation (warnings only, no errors)
local ContentValidator = require("tools.content_validator")
local results = ContentValidator.validate_all(true)  -- true = warnings only

-- Check results
if #results.errors > 0 then
    for _, err in ipairs(results.errors) do
        print(string.format("[%s] %s: %s", err.type, err.id, err.message))
    end
end

if #results.warnings > 0 then
    for _, warn in ipairs(results.warnings) do
        print(string.format("[%s] %s: %s", warn.type, warn.id, warn.message))
    end
end
```

**What it validates:**

**Cards:**
- Required fields: `id`, `type`, `mana_cost`, `tags`
- Valid `type`: "action", "modifier", "trigger"
- Valid `damage_type`: fire/ice/lightning/poison/arcane/holy/void/magic
- ID matches table key
- Unknown tags (suggests similar valid tags)

**Jokers:**
- Required fields: `id`, `name`, `description`, `rarity`, `calculate`
- Valid `rarity`: Common, Uncommon, Rare, Epic, Legendary
- `calculate` is a function
- ID matches table key

**Projectiles:**
- Required fields: `id`, `speed`, `movement`, `collision`
- Valid `movement`: straight, homing, arc, orbital, custom
- Valid `collision`: destroy, pierce, bounce, explode, pass_through, chain
- Valid `damage_type`

**Avatars:**
- Required fields: `name`, `description`, `unlock`, `effects`
- `unlock` is a table
- `effects` is a non-empty table

**Output:**

```
[Card] MY_FIREBALL: unknown tag 'Fyre' (did you mean 'Fire'?)
[Joker] pyromaniac: missing required field 'rarity'
[Projectile] my_proj: invalid movement type 'zigzag' (expected: straight, homing, arc, orbital, custom)
```

**Provenance:** See `assets/scripts/tools/content_validator.lua:1-300` for full implementation.

**Gotcha:** Validator allows custom fields for extensibility. Only critical fields are validated.

**Gotcha:** Unknown tags generate warnings with suggestions (fuzzy matching by lowercasing).

---

## Standard Tag Reference

\label{recipe:standard-tags}

**When to use:** Choosing tags for cards/projectiles.

**Pattern:** Use standard tags for joker synergies and tag threshold bonuses.

**Element Tags:**

- `"Fire"`: Fire damage and burning effects
- `"Ice"`: Ice damage and freezing effects
- `"Lightning"`: Lightning damage and chaining
- `"Poison"`: Poison damage and DoT
- `"Arcane"`: Magical effects
- `"Holy"`: Divine damage
- `"Void"`: Dark/shadow damage

**Mechanic Tags:**

- `"Projectile"`: Fires projectiles
- `"AoE"`: Area of effect damage
- `"Hazard"`: Creates hazards (pools, zones)
- `"Summon"`: Spawns allies
- `"Buff"`: Positive modifier
- `"Debuff"`: Negative modifier

**Playstyle Tags:**

- `"Mobility"`: Movement-related
- `"Defense"`: Defensive/blocking
- `"Brute"`: High damage, direct combat

**Tag Synergies:**

Tags grant bonuses at breakpoints (3/5/7/9 cards with that tag). See `assets/scripts/wand/tag_evaluator.lua` for thresholds.

**Example:**

```lua
-- Card with multiple tags
Cards.EXPLOSIVE_FIREBALL = {
    id = "EXPLOSIVE_FIREBALL",
    type = "action",
    tags = { "Fire", "Projectile", "AoE" },  -- Synergizes with Fire/AoE jokers
    -- ...
}
```

**Provenance:** See `assets/scripts/tools/content_validator.lua:19-27` for tag list.

**Gotcha:** Tags are case-sensitive. Use exact capitalization.

**Gotcha:** Custom tags are allowed but won't benefit from threshold bonuses unless added to `tag_evaluator.lua`.

---

## Extend Tag System

\label{recipe:extend-tag-system}

**When to use:** Adding new tag synergies with breakpoint bonuses.

**Pattern:** Define breakpoints in `tag_evaluator.lua` to grant bonuses at 3/5/7/9 card counts.

**Example:**

```lua
-- In assets/scripts/wand/tag_evaluator.lua

local TAG_BREAKPOINTS = {
    -- Existing tags...
    Fire = {
        [3] = { type = "stat", stat = "damage_pct", value = 10 },
        [5] = { type = "proc", proc_id = "fire_spread" },
        [7] = { type = "stat", stat = "burn_duration_pct", value = 50 },
        [9] = { type = "proc", proc_id = "fire_avatar" },
    },

    -- New custom tag
    MyNewTag = {
        [3] = { type = "stat", stat = "damage_pct", value = 10 },       -- +10% damage
        [5] = { type = "proc", proc_id = "my_custom_proc" },            -- Trigger proc
        [7] = { type = "stat", stat = "crit_chance_pct", value = 15 },  -- +15% crit
        [9] = { type = "proc", proc_id = "my_ultimate_proc" },          -- Ultimate proc
    },
}
```

**Bonus types:**

**Stat Bonus:**

```lua
{
    type = "stat",
    stat = "damage_pct",  -- Stat name (must exist in player stats)
    value = 10            -- Bonus value
}
```

**Proc Bonus:**

```lua
{
    type = "proc",
    proc_id = "fire_spread"  -- Proc identifier (implement handler in combat system)
}
```

**Common stat names:**

- `damage_pct`: Damage percentage
- `crit_chance_pct`: Critical hit chance
- `cast_speed`: Cast speed multiplier
- `hazard_tick_rate_pct`: Hazard tick rate
- `burn_duration_pct`: Burn effect duration

**Changing thresholds:**

Edit `DEFAULT_THRESHOLDS` in `tag_evaluator.lua`:

```lua
local DEFAULT_THRESHOLDS = { 3, 5, 7, 9 }  -- Default breakpoints
```

**API:**

```lua
local TagEvaluator = require("wand.tag_evaluator")

-- Get sorted threshold list for a tag
local thresholds = TagEvaluator.get_thresholds("Fire")  -- { 3, 5, 7, 9 }

-- Get all tag breakpoint definitions (read-only copy)
local breakpoints = TagEvaluator.get_breakpoints()
```

**Provenance:** See CLAUDE.md "Tag Synergy Thresholds" section.

**Gotcha:** Proc effects require implementing handlers in the combat system.

**Gotcha:** Stat names must exist in player stat system; invalid names silently fail.

**Gotcha:** Thresholds are cumulative (7-tag bonus includes 3 and 5 bonuses).

\newpage

\newpage

# Chapter 10: Utilities & External Libraries

## hump/signal: Full API

\label{recipe:signal-api}

**When to use:** Event system for decoupling components (pub/sub pattern).

```lua
local signal = require("external.hump.signal")

-- Emit event (any arguments)
signal.emit("event_name", arg1, arg2, ...)
signal.emit("projectile_hit", projectileEntity, { damage = 50 })
signal.emit("player_level_up")

-- Register handler
signal.register("event_name", function(arg1, arg2, ...)
    -- Handle event
end)

-- Remove specific handler
local handler = function() print("test") end
signal.register("my_event", handler)
signal.remove("my_event", handler)

-- Clear all handlers for event(s)
signal.clear("event_name")
signal.clear("event1", "event2", "event3")  -- clear multiple

-- Pattern matching (regex-like)
signal.emitPattern("^on_.*", data)           -- emit all events starting with "on_"
signal.registerPattern("^on_.*", handler)    -- register for all "on_" events
signal.removePattern("^on_.*", handler)      -- remove from pattern
signal.clearPattern("^on_.*")                -- clear all matching events

-- Check if event has listeners
if signal.exists("my_event") then
    print("Event has listeners")
end
```

*— from external/hump/signal.lua*

**Convention:** First parameter is the entity, second is a data table:

```lua
signal.emit("projectile_spawned", entity, {
    owner = ownerEntity,
    position = { x = 100, y = 200 },
    damage = 50
})
```

**Gotcha:** Handlers run in arbitrary order; don't assume execution sequence.

**Gotcha:** Use `signal.emit()`, NOT `publishLuaEvent()` (deprecated C++ binding).

**Provenance:** See gameplay.lua:3569-3625 for event usage patterns.

---

## lume: Math & Random

\label{recipe:lume-math}

**When to use:** Common math operations and random number utilities.

```lua
local lume = require("external.lume")

-- Clamp value between min and max
local health = lume.clamp(damage, 0, 100)

-- Round to nearest increment
local rounded = lume.round(42.7, 1)     -- 43
local snapped = lume.round(47, 10)      -- 50

-- Sign of number (-1, 0, or 1)
local direction = lume.sign(velocity)

-- Linear interpolation
local pos = lume.lerp(startPos, endPos, 0.5)  -- halfway between

-- Smooth interpolation (ease in/out)
local smoothPos = lume.smooth(a, b, 0.3)

-- Ping-pong (0-1-0 cycle)
local oscillate = lume.pingpong(time)

-- Distance between two points
local dist = lume.distance(x1, y1, x2, y2)
local distSquared = lume.distance(x1, y1, x2, y2, true)  -- faster (no sqrt)

-- Angle between two points (radians)
local angle = lume.angle(x1, y1, x2, y2)

-- Vector from angle and magnitude
local x, y = lume.vector(angle, magnitude)

-- Random number
local val = lume.random(1, 100)         -- integer 1-100
local val = lume.random(5.0, 10.0)      -- float 5.0-10.0
local val = lume.random(10)             -- integer 1-10

-- Random choice from table
local item = lume.randomchoice({ "fire", "ice", "lightning" })

-- Weighted random choice
local item = lume.weightedchoice({
    { "common", 70 },
    { "rare", 25 },
    { "legendary", 5 }
})
```

*— from external/lume.lua*

**Gotcha:** `lume.random()` uses Lua's math.random; seed with `math.randomseed()` if needed.

---

## lume: Table Operations

\label{recipe:lume-tables}

**When to use:** Array/table manipulation without boilerplate.

```lua
local lume = require("external.lume")

-- Find element in array (returns index or nil)
local idx = lume.find(enemies, targetEnemy)
if lume.find(globals.colonists, entity) then
    print("Is a colonist")
end

-- Push values to array (like table.insert but returns table)
lume.push(myArray, value1, value2, value3)

-- Remove value from array (removes first match)
lume.remove(enemies, deadEnemy)

-- Clear table (removes all keys)
lume.clear(myTable)

-- Extend table with values from other tables
lume.extend(allColonists, globals.colonists)
lume.extend(target, source1, source2)  -- merge multiple

-- Shuffle array in-place
lume.shuffle(deck)

-- Sort with custom comparator
lume.sort(entities, function(a, b)
    return a.priority > b.priority
end)

-- Create array from varargs
local arr = lume.array(1, 2, 3, 4)  -- { 1, 2, 3, 4 }

-- Filter array (returns new table)
local alive = lume.filter(enemies, function(e)
    return e.health > 0
end)

-- Reject (inverse of filter)
local dead = lume.reject(enemies, function(e)
    return e.health > 0
end)

-- Map (transform each element)
local healthValues = lume.map(enemies, function(e)
    return e.health
end)

-- Check if all elements match predicate
if lume.all(enemies, function(e) return e.health > 0 end) then
    print("All enemies alive")
end

-- Check if any element matches predicate
if lume.any(enemies, function(e) return e.isBoss end) then
    print("Boss present")
end

-- Reduce (fold/accumulate)
local totalHealth = lume.reduce(enemies, function(sum, e)
    return sum + e.health
end, 0)

-- Unique values (removes duplicates)
local uniqueTags = lume.unique({ "fire", "ice", "fire", "lightning" })
-- Result: { "fire", "ice", "lightning" }

-- Merge tables (creates new table with all key-value pairs)
local combined = lume.merge(defaults, overrides)

-- Concatenate arrays (creates new array)
local all = lume.concat(array1, array2, array3)
```

*— from external/lume.lua*

**Gotcha:** `lume.find()` is for arrays (indexed tables), not key-value tables.

**Gotcha:** Most functions return new tables; use in-place variants (`shuffle`, `clear`) for mutation.

**Provenance:** See gameplay.lua:2110, 2610, 7984 for usage examples.

---

## Global Helpers: Entity Validation

\label{recipe:global-helpers}

**When to use:** These functions are available globally after util.lua loads.

```lua
-- Validate entity exists
if ensure_entity(eid) then
    -- entity is valid and not entt_null
end

-- Validate entity has script component
if ensure_scripted_entity(eid) then
    -- entity is valid AND has ScriptComponent
end

-- Safe script table access
local script = safe_script_get(eid)           -- returns nil if missing
local script = safe_script_get(eid, true)     -- logs warning if missing

-- Safe field access with default
local health = script_field(eid, "health", 100)  -- returns 100 if missing
local name = script_field(eid, "name", "Unknown")
```

*— from util/util.lua:39-73*

**Replace verbose patterns:**

```lua
-- OLD (verbose)
if not entity or entity == entt_null or not entity_cache.valid(entity) then
    return
end

-- NEW (use the helper!)
if not ensure_entity(entity) then return end
```

**Gotcha:** `ensure_entity()` checks validity; `ensure_scripted_entity()` also checks for ScriptComponent.

**Gotcha:** `script_field()` returns the default if the script OR field is nil; check both cases.

---

## Global Helpers: Logging

\label{recipe:logging}

**When to use:** Debug output with log levels (defined in C++, exposed to Lua).

```lua
-- Log levels (from least to most severe)
log_debug("Position:", x, y)           -- Verbose debugging info
log_info("Game started")                -- General information
log_warn("Enemy not found")             -- Warning (non-critical)
log_error("Failed to load asset")       -- Error (critical)

-- Multiple arguments are concatenated
log_debug("Entity", eid, "at", x, y)
-- Output: "Entity 42 at 100 200"

-- Format strings
log_debug(("Health: %d/%d"):format(current, max))
```

*— from chugget_code_definitions.lua:385-405 (stubs), C++ bindings in scripting system*

**Gotcha:** Log functions accept varargs but don't auto-format; use `string.format()` for structured output.

**Gotcha:** `log_debug()` may be compiled out in release builds; use `log_info()` for important messages.

---

## util: Color Lookup

\label{recipe:util-colors}

**When to use:** Get predefined color by name (C++ color palette).

```lua
local util = require("util.util")  -- Usually not needed (often available globally)

-- Get color by name
local white = util.getColor("white")
local red = util.getColor("red")
local custom = util.getColor("apricot_cream")

-- Named colors (from color palette JSON)
local colors = {
    util.getColor("white"),
    util.getColor("black"),
    util.getColor("red"),
    util.getColor("green"),
    util.getColor("blue"),
    util.getColor("cyan"),
    util.getColor("magenta"),
    util.getColor("yellow"),
    util.getColor("gray"),
    util.getColor("orange"),
    util.getColor("pink"),
    util.getColor("purple"),
    -- Custom palette colors:
    util.getColor("apricot_cream"),
    util.getColor("mint_green"),
    util.getColor("gold"),
    util.getColor("blackberry"),
}

-- Use in draw commands or UI
local COLOR_READY = util.getColor("green")
local COLOR_COOLDOWN = util.getColor("gray")

-- Color has methods
local color = util.getColor("white")
color:setAlpha(128)  -- 50% transparent
```

*— from util/util.lua (C++ binding), usage in ui/wand_cooldown_ui.lua:1-4*

**Gotcha:** Color names are case-insensitive but prefer lowercase for consistency.

**Gotcha:** Returns a Color object (C++ userdata), not a table; use Color methods for manipulation.

**Provenance:** Color palette defined in `assets/graphics/colors.json` (or loaded from C++).

---

## util: Camera Smooth Pan

\label{recipe:util-camera}

**When to use:** Gradually move camera to target position (avoids jumps).

```lua
-- Smooth pan to target
camera_smooth_pan_to("main", targetX, targetY, {
    increments = 5,        -- number of steps (default: 2)
    interval = 0.01,       -- seconds between steps (default: 0.005)
    tag = "cam_move",      -- timer tag for cancellation
    after = function()     -- callback when complete
        print("Camera arrived")
    end
})
```

*— from util/util.lua:76-134*

**Gotcha:** Uses timer.every internally; calling again with same tag cancels previous pan.

**Gotcha:** Camera must exist; logs error if not found.

---

## util: Particle Helpers

\label{recipe:util-particles}

**When to use:** Spawn visual effects quickly (wrappers around particle system).

```lua
-- Radial burst (particles expand outward in all directions)
particle.spawnRadialParticles(x, y, count, seconds, {
    minRadius = 0,
    maxRadius = 100,
    minSpeed = 100,
    maxSpeed = 300,
    minScale = 5,
    maxScale = 15,
    colors = { util.getColor("red"), util.getColor("orange") },
    gravity = 200,
    lifetimeJitter = 0.2,  -- ±20% variance
    scaleJitter = 0.3,
    rotationSpeed = 90,    -- degrees/sec
    rotationJitter = 0.5,
    easing = "cubic",
    space = "world",
    z = 100
})

-- Image burst (uses sprites/animations instead of circles)
particle.spawnImageBurst(x, y, count, seconds, "spark", {
    minSpeed = 100,
    maxSpeed = 250,
    size = 16,
    useSpriteNotAnimation = false,  -- true = sprite ID, false = animation ID
    spriteUUID = "sprite_uuid",     -- if using sprite
    loop = false,
    easing = "quad",
    space = "screen"
})

-- Ring (particles arranged in circle)
particle.spawnRing(x, y, count, seconds, radius, {
    colors = { util.getColor("cyan") },
    expandFactor = 0.5,  -- ring grows by 50%
    size = 8,
    easing = "cubic",
    space = "world"
})

-- Rectangle area (particles spawn randomly inside rectangle)
particle.spawnRectAreaParticles(x, y, w, h, count, seconds, {
    minSpeed = 50,
    maxSpeed = 200,
    minScale = 4,
    maxScale = 10,
    angleSpread = 360,   -- degrees
    baseAngle = 0,
    colors = { util.getColor("white") }
})

-- Directional cone (particles shoot in direction with spread)
particle.spawnDirectionalCone(Vec2(x, y), count, seconds, {
    direction = Vec2(0, -1),  -- upward
    spread = 30,              -- degrees
    minSpeed = 100,
    maxSpeed = 300,
    minScale = 3,
    maxScale = 8,
    gravity = 100,
    colors = { util.getColor("yellow") }
})
```

*— from util/util.lua:143-497*

**Gotcha:** All particle functions use options tables; most fields have sensible defaults.

**Gotcha:** `space` can be "world" (moves with camera) or "screen" (fixed to viewport).

**Gotcha:** Easing names come from util/easing.lua (e.g., "linear", "quad", "cubic", "bounce").

---

## knife: Functional Chaining

\label{recipe:knife-chain}

**When to use:** Fluent functional programming on arrays/iterables.

```lua
local chain = require("external.knife.chain")

-- Method chaining on arrays
local result = chain(myArray)
    :filter(function(x) return x > 10 end)
    :map(function(x) return x * 2 end)
    :take(5)
    :result()

-- Works with iterators
local result = chain(pairs(myTable))
    :map(function(k, v) return v end)
    :filter(function(v) return v.active end)
    :result()
```

*— from external/knife/chain.lua*

**Gotcha:** Must call `:result()` at the end to get the final table/value.

**Gotcha:** Less common in this codebase than lume; prefer lume for consistency.

---

## forma: Not Used

\label{recipe:forma}

**When to use:** Don't use (present in codebase but unused).

The `external/forma` library exists but is not actively used. Stick to lume/knife for functional programming.

---

## Common Event Names

\label{recipe:common-events}

**When to use:** Standard events emitted throughout the engine.

| Event | Parameters | Purpose |
|-------|------------|---------|
| `"avatar_unlocked"` | `avatarId` | Avatar unlock |
| `"tag_threshold_discovered"` | `{ tagName, threshold }` | Tag synergy discovery |
| `"spell_type_discovered"` | `{ spell_type }` | Spell type discovery |
| `"deck_changed"` | `{ source }` | Inventory modification |
| `"player_level_up"` | `nil` | Level progression |
| `"stats_recomputed"` | `nil` | Stats recalculated |
| `"on_spell_cast"` | `{ ... }` | Spell cast event |
| `"on_joker_trigger"` | `{ jokerName, ... }` | Joker effect triggered |
| `"on_player_attack"` | `{ target }` | Player attacks |
| `"on_low_health"` | `{ healthPercent }` | Health drops low |
| `"on_dash"` | `{ player }` | Player dashes |
| `"on_bump_enemy"` | `enemyEntity` | Collision with enemy |
| `"on_pickup"` | `pickupEntity` | Item collected |
| `"projectile_spawned"` | `entity, { owner, ... }` | Projectile created |
| `"projectile_hit"` | `entity, { target, ... }` | Projectile collision |
| `"projectile_exploded"` | `entity, { radius, ... }` | Projectile explosion |

*— from gameplay.lua:57-76, 3569-3625, combat/projectile_system.lua:731, 1632, 1749*

**Usage:**

```lua
-- Listen to multiple related events
signal.register("on_spell_cast", handleSpellCast)
signal.register("on_joker_trigger", handleJokerTrigger)
signal.register("tag_threshold_discovered", handleTagDiscovery)

-- Clean up when system shuts down
signal.clear("on_spell_cast", "on_joker_trigger", "tag_threshold_discovered")
```

**Gotcha:** Event names are strings; typos won't error but handlers won't fire.

**Gotcha:** Some events pass entity as first param, others pass data table; check usage examples.

---

## Easing Functions

\label{recipe:easing}

**When to use:** Smooth interpolation for animations and transitions.

```lua
local Easing = require("util.easing")

-- Available easing curves
local easings = {
    "linear",
    "quad",      -- quadratic
    "cubic",
    "quart",     -- quartic
    "quint",     -- quintic
    "sine",
    "expo",      -- exponential
    "circ",      -- circular
    "back",      -- overshoots then settles
    "elastic",   -- bounces like spring
    "bounce"
}

-- Each has .f (ease function) and .d (derivative)
local t = 0.5  -- progress 0.0-1.0
local eased = Easing.cubic.f(t)        -- ease value
local velocity = Easing.cubic.d(t)     -- rate of change

-- Use in animations
local progress = math.min(age / lifetime, 1)
local eased = Easing.bounce.f(progress)
local currentScale = startScale + (endScale - startScale) * eased
```

*— from util/easing.lua, used in util/util.lua particle functions*

**Gotcha:** Easing functions expect input in range [0, 1]; clamp before calling.

**Gotcha:** `.d` (derivative) is useful for velocity-based effects (like particles).

---
\newpage
\appendix

# Appendix A: Function Index

\label{appendix:function-index}

Alphabetical listing of all documented functions and APIs.

| Function | Module | Recipe |
|----------|--------|--------|
| `add_state_tag()` | `util.lua` | \pageref{recipe:validate-entity} |
| `component_cache.get()` | `core.component_cache` | \pageref{recipe:get-component} |
| `dsl.anim()` | `ui.ui_syntax_sugar` | \pageref{recipe:ui-dsl} |
| `dsl.dynamic()` | `ui.ui_syntax_sugar` | \pageref{recipe:ui-dsl} |
| `dsl.grid()` | `ui.ui_syntax_sugar` | \pageref{recipe:ui-grid} |
| `dsl.hbox()` | `ui.ui_syntax_sugar` | \pageref{recipe:ui-dsl} |
| `dsl.root()` | `ui.ui_syntax_sugar` | \pageref{recipe:ui-dsl} |
| `dsl.spawn()` | `ui.ui_syntax_sugar` | \pageref{recipe:ui-dsl} |
| `dsl.text()` | `ui.ui_syntax_sugar` | \pageref{recipe:ui-dsl} |
| `dsl.vbox()` | `ui.ui_syntax_sugar` | \pageref{recipe:ui-dsl} |
| `ensure_entity()` | `util.lua` | \pageref{recipe:global-helpers} |
| `ensure_scripted_entity()` | `util.lua` | \pageref{recipe:global-helpers} |
| `entity_cache.active()` | `core.entity_cache` | \pageref{recipe:validate-entity} |
| `entity_cache.valid()` | `core.entity_cache` | \pageref{recipe:validate-entity} |
| `EntityBuilder.create()` | `core.entity_builder` | \pageref{recipe:entity-sprite} |
| `EntityBuilder.interactive()` | `core.entity_builder` | \pageref{recipe:entity-interactive} |
| `EntityBuilder.simple()` | `core.entity_builder` | \pageref{recipe:entity-sprite} |
| `getScriptTableFromEntityID()` | `util.lua` | \pageref{recipe:script-table} |
| `is_state_active()` | `util.lua` | \pageref{recipe:validate-entity} |
| `JokerSystem.add_joker()` | `wand.joker_system` | \pageref{recipe:joker-manage} |
| `JokerSystem.clear_jokers()` | `wand.joker_system` | \pageref{recipe:joker-manage} |
| `JokerSystem.definitions` | `wand.joker_system` | \pageref{recipe:joker-define} |
| `JokerSystem.remove_joker()` | `wand.joker_system` | \pageref{recipe:joker-manage} |
| `JokerSystem.trigger_event()` | `wand.joker_system` | \pageref{recipe:joker-trigger} |
| `knife.chain()` | `external.knife.chain` | \pageref{recipe:knife-chain} |
| `lume.*` | `external.lume` | \pageref{recipe:lume-tables}, \pageref{recipe:lume-math} |
| `PhysicsBuilder.for_entity()` | `core.physics_builder` | \pageref{recipe:add-physics} |
| `PhysicsBuilder.quick()` | `core.physics_builder` | \pageref{recipe:add-physics} |
| `physics.create_physics_for_transform()` | `physics.physics_lua_api` | \pageref{recipe:get-physics-world} |
| `physics.enable_collision_between_many()` | `physics.physics_lua_api` | \pageref{recipe:collision-masks} |
| `physics.set_sync_mode()` | `physics.physics_lua_api` | \pageref{recipe:get-physics-world} |
| `physics.SetBullet()` | `physics.physics_lua_api` | \pageref{recipe:bullet-mode} |
| `physics.update_collision_masks_for()` | `physics.physics_lua_api` | \pageref{recipe:collision-masks} |
| `PhysicsManager.get_world()` | `core.physics_manager` | \pageref{recipe:get-physics-world} |
| `ProjectileSystem.spawn()` | `combat.projectile_system` | \pageref{recipe:spawn-projectile} |
| `remove_default_state_tag()` | `util.lua` | \pageref{recipe:validate-entity} |
| `safe_script_get()` | `util.lua` | \pageref{recipe:safe-script} |
| `script_field()` | `util.lua` | \pageref{recipe:global-helpers} |
| `ShaderBuilder.for_entity()` | `core.shader_builder` | \pageref{recipe:add-shader} |
| `ShaderBuilder.register_family()` | `core.shader_builder` | \pageref{recipe:define-shader-preset} |
| `signal.emit()` | `external.hump.signal` | \pageref{recipe:signals} |
| `signal.register()` | `external.hump.signal` | \pageref{recipe:signals} |
| `signal.clear()` | `external.hump.signal` | \pageref{recipe:signal-api} |
| `signal.remove()` | `external.hump.signal` | \pageref{recipe:signal-api} |
| `TagEvaluator.count_tags()` | `wand.tag_evaluator` | \pageref{recipe:tag-evaluate} |
| `TagEvaluator.evaluate_deck()` | `wand.tag_evaluator` | \pageref{recipe:tag-evaluate} |
| `TagEvaluator.get_breakpoints()` | `wand.tag_evaluator` | \pageref{recipe:tag-synergy} |
| `TagEvaluator.get_thresholds()` | `wand.tag_evaluator` | \pageref{recipe:tag-synergy} |
| `timer.after()` | `core.timer` | \pageref{recipe:timer-after} |
| `timer.after_opts()` | `core.timer` | \pageref{recipe:timer-after} |
| `timer.cancel()` | `core.timer` | \pageref{recipe:timer-after} |
| `timer.cooldown_opts()` | `core.timer` | \pageref{recipe:timer-after} |
| `timer.every()` | `core.timer` | \pageref{recipe:timer-every} |
| `timer.every_opts()` | `core.timer` | \pageref{recipe:timer-every} |
| `timer.every_physics_step()` | `core.timer` | \pageref{recipe:timer-physics} |
| `util.getColor()` | `util.util` | \pageref{recipe:util-colors} |
| `util.makeSimpleTooltip()` | `util.util` | \pageref{recipe:tooltip} |

\newpage

# Appendix B: Common Patterns Cheat Sheet

\label{appendix:cheat-sheet}

## Entity Lifecycle

```lua
-- Create entity with sprite
local entity, script = EntityBuilder.create({
    sprite = "my_sprite",
    position = { x = 100, y = 200 },
    data = { health = 100 }  -- Assigned before attach_ecs
})

-- Validate before use
if not ensure_entity(entity) then return end

-- Get script table
local script = safe_script_get(entity)
if script then script.health = script.health - 10 end

-- Destroy
registry:destroy(entity)
```

## Defensive Access

```lua
-- Safe component access
local transform = component_cache.get(entity, Transform)
if transform then
    transform.actualX = x
end

-- Safe script access with default
local damage = script_field(entity, "damage", 0)

-- Safe entity validation
if not entity_cache.valid(entity) then return end
```

## Timer Patterns

```lua
-- One-shot
timer.after_opts({ delay = 2.0, action = fn, tag = "my_timer" })

-- Repeating
timer.every_opts({ delay = 1.0, action = fn, times = 5 })

-- Physics-synced
timer.every_physics_step(function(dt) updatePhysics(dt) end)

-- Cancel
timer.cancel("my_timer")
```

## Event System

```lua
-- Emit event
signal.emit("event_name", entity, { data = "value" })

-- Listen
signal.register("event_name", function(entity, data)
    print("Event fired:", data.data)
end)

-- Cleanup
signal.clear("event_name")
```

## Physics Quick

```lua
-- Add physics
PhysicsBuilder.quick(entity, {
    shape = "circle",
    tag = "projectile",
    bullet = true,
    collideWith = { "enemy", "WORLD" }
})

-- Fluent API
PhysicsBuilder.for_entity(entity)
    :circle():tag("player"):bullet():fixedRotation()
    :collideWith({"enemy"}):apply()
```

## UI Quick

```lua
-- Build UI tree
local ui = dsl.root {
    config = { padding = 10 },
    children = {
        dsl.vbox {
            config = { spacing = 6 },
            children = {
                dsl.text("Title", { fontSize = 24 }),
                dsl.hbox {
                    children = {
                        dsl.anim("icon", { w = 32, h = 32 }),
                        dsl.text("Subtitle")
                    }
                }
            }
        }
    }
}

-- Spawn
local boxID = dsl.spawn({ x = 100, y = 100 }, ui)
```

## Content Creation Quick

```lua
-- Define card
Cards.MY_CARD = {
    id = "MY_CARD",
    type = "action",
    mana_cost = 10,
    damage = 25,
    tags = { "Fire", "Projectile" }
}

-- Define joker
my_joker = {
    id = "my_joker",
    calculate = function(self, ctx)
        if ctx.tags and ctx.tags.Fire then
            return { damage_mod = 10 }
        end
    end
}

-- Spawn projectile
ProjectileSystem.spawn({
    owner = player,
    position = { x = x, y = y },
    velocity = { x = vx, y = vy },
    preset = "fireball"  -- or inline config
})
```

---

*End of Cookbook*
