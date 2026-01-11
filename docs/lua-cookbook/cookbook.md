# Quick Start

**New to the engine?** Here's how to create a game entity from scratch in 10 seconds.

```lua
-- 1. Load modules (or use imports.all() - see below)
local EntityBuilder = require("core.entity_builder")
local PhysicsBuilder = require("core.physics_builder")

-- 2. Create entity with everything in one call
local entity, script = EntityBuilder.create({
    sprite = "kobold",
    position = { x = 100, y = 200 },
    size = { 64, 64 },
    data = { health = 100, faction = "enemy", damage = 10 },
    interactive = {
        click = function(reg, clickedEntity)
            print("Clicked entity:", clickedEntity)
            local script = getScriptTableFromEntityID(clickedEntity)
            if script then
                script.health = script.health - 10
                print("Health remaining:", script.health)
            end
        end
    }
})

-- 3. Add physics in one call
PhysicsBuilder.for_entity(entity)
    :rectangle()
    :tag("enemy")
    :collideWith({ "player", "projectile" })
    :apply()
```

**That's it!** The entity now:
- Renders with animation
- Stores custom data in its script table
- Has physics and collisions
- Responds to clicks

**New builders reduce 60+ lines to 15 lines!**

### Alternative: Manual Pattern (Old Way)

See the Entity Creation and Physics chapters for the low-level manual patterns if you need more control.

### Using Imports Bundle

```lua
-- Load common modules in one line
local imports = require("core.imports")
local EntityBuilder, PhysicsBuilder = imports.entity()[3], imports.physics()[2]
-- Or: local i = imports.all()  -- i.EntityBuilder, i.PhysicsBuilder

-- Even simpler:
local component_cache, entity_cache, timer, signal = imports.core()
```

**Critical rules:**
1. Always assign data to script table BEFORE calling `attach_ecs()` (EntityBuilder does this for you!)
2. Always use `PhysicsManager.get_world("world")` instead of `globals.physicsWorld` (PhysicsBuilder does this for you!)
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
| Attach child entity to parent | \pageref{recipe:child-builder} |
| Link entity lifecycle (die when target dies) | \pageref{recipe:entity-links} |
| **Movement & Physics** | |
| Add physics to existing entity | \pageref{recipe:add-physics} |
| Set collision tags and masks | \pageref{recipe:collision-masks} |
| Enable bullet mode for fast objects | \pageref{recipe:bullet-mode} |
| **Timers & Events** | |
| Delay an action | \pageref{recipe:timer-after} |
| Repeat an action | \pageref{recipe:timer-every} |
| Chain timer actions fluently | \pageref{recipe:timer-chain} |
| Group timers for cleanup | \pageref{recipe:timer-scope} |
| Synchronize with physics steps | \pageref{recipe:timer-physics} |
| Emit and handle events | \pageref{recipe:signals} |
| Group event handlers for cleanup | \pageref{recipe:signal-group} |
| Bridge combat bus to signals | \pageref{recipe:event-bridge} |
| Show popup text (damage, heal, etc.) | \pageref{recipe:popup} |
| Use state machine for entity behavior | \pageref{recipe:fsm} |
| Animate properties with easing | \pageref{recipe:tween} |
| Chain visual effects (flash, shake, particles) | \pageref{recipe:fx} |
| Pool objects for performance | \pageref{recipe:pool} |
| Visualize debug information | \pageref{recipe:debug} |
| Add dynamic lighting to layers | \pageref{recipe:lighting} |
| **Rendering & Shaders** | |
| Add shader to entity | \pageref{recipe:add-shader} |
| Stack multiple shaders | \pageref{recipe:stack-shaders} |
| Batch render entities with shared shaders | \pageref{recipe:render-groups} |
| Draw text | \pageref{recipe:draw-text} |
| Spawn dynamic text (damage numbers) | \pageref{recipe:text-builder} |
| Flash entity on hit | \pageref{recipe:hitfx} |
| **Particles** | |
| Define particle effect | \pageref{recipe:particle-builder} |
| Configure emission (where/how) | \pageref{recipe:particle-emission} |
| Stream continuous particles | \pageref{recipe:particle-stream} |
| Mix multiple particle types | \pageref{recipe:particle-mix} |
| **UI** | |
| Create UI with DSL | \pageref{recipe:ui-dsl} |
| Add tooltip on hover | \pageref{recipe:tooltip} |
| Use tooltip registry (reusable templates) | \pageref{recipe:tooltip-registry} |
| Use TooltipV2 3-box system for cards | \pageref{recipe:tooltip-v2} |
| Add rarity-based text effects to tooltips | \pageref{recipe:tooltip-effects} |
| Create grid layout | \pageref{recipe:ui-grid} |
| Create tabbed UI panels | \pageref{recipe:tabs-ui} |
| Show modal dialogs (alert/confirm) | \pageref{recipe:modal} |
| Create inventory grid | \pageref{recipe:inventory-grid} |
| Use styled localization for colored text | \pageref{recipe:styled-localization} |
| Create localized tooltip with color codes | \pageref{recipe:localized-tooltip} |
| **Combat** | |
| Define enemy behaviors declaratively | \pageref{recipe:enemy-behaviors} |
| Spawn projectile | \pageref{recipe:spawn-projectile} |
| Configure projectile behavior | \pageref{recipe:projectile-preset} |
| **Cards & Wands** | |
| Define action card | \pageref{recipe:card-action} |
| Define modifier card | \pageref{recipe:card-modifier} |
| Define trigger card | \pageref{recipe:card-trigger} |
| Define cards with CardFactory DSL | \pageref{recipe:card-factory} |
| Get card metadata (rarity/tags) | \pageref{recipe:card-metadata} |
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
| **Status Effects & Equipment** | |
| Define status effect (DoT/buff/mark) | \pageref{recipe:define-status-effect} |
| Use trigger constants | \pageref{recipe:define-trigger-constants} |
| Define equipment with procs | \pageref{recipe:define-equipment} |
| **AI** | |
| Create AI entity | \pageref{recipe:ai-entity-type} |
| Define AI action | \pageref{recipe:ai-action} |
| **Validation & Utilities** | |
| Validate data schemas | \pageref{recipe:schema-validate} |
| Quick transform helpers (Q.lua) | \pageref{recipe:q-helpers} |
| Type-safe constants | \pageref{recipe:constants} |
| Hot-reload modules (dev) | \pageref{recipe:hot-reload} |
| **Persistence** | |
| Save/load game state | \pageref{recipe:save-manager} |
| Track statistics (kills, playtime) | \pageref{recipe:statistics} |
| Handle save file migrations | \pageref{recipe:save-migrations} |

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

***

## Import Bundles (Reduce Boilerplate)

\label{recipe:imports}

**When to use:** Tired of typing 5-10 require statements at the top of every file? Use import bundles.

```lua
local imports = require("core.imports")

-- Core bundle (most common - 5 modules)
local component_cache, entity_cache, timer, signal, z_orders = imports.core()

-- Entity creation bundle (4 modules)
local Node, animation_system, EntityBuilder, spawn = imports.entity()

-- Physics bundle (2 modules)
local PhysicsManager, PhysicsBuilder = imports.physics()

-- UI bundle (3 modules)
local dsl, z_orders, util = imports.ui()

-- Shader bundle (2 modules)
local ShaderBuilder, draw = imports.shaders()

-- Draw bundle (3 modules) - rendering utilities
local draw, ShaderBuilder, z_orders = imports.draw()

-- Combat bundle (3 modules) - combat and wand systems
local combat_system, projectile_system, wand_executor = imports.combat()

-- Util bundle (3 modules) - utilities and helpers
local util, Easing, palette = imports.util()

-- Everything as a table (for selective access)
local i = imports.all()
-- Access: i.timer, i.signal, i.EntityBuilder, i.PhysicsBuilder, i.draw, etc.
```

*— from core/imports.lua*

**Real usage example:**

```lua
-- Old way (verbose)
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")
local timer = require("core.timer")
local signal = require("external.hump.signal")
local z_orders = require("core.z_orders")

-- New way (one line!)
local component_cache, entity_cache, timer, signal, z_orders = imports.core()
```

**Gotcha:** Import bundles return values in a fixed order. Use multiple assignment to unpack them.

**Gotcha:** Some modules (like PhysicsManager) may be nil if not available in the current context.

***

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

***

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

***

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

***

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

***

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

***

## Timer: Fluent Chaining (TimerChain)

\label{recipe:timer-chain}

**When to use:** Avoid deeply nested timer callbacks by chaining steps fluently.

```lua
local TimerChain = require("core.timer_chain")

-- Basic sequence
TimerChain.new("my_animation")
    :wait(0.5)
    :do_now(function() print("start") end)
    :wait(0.3)
    :do_now(function() print("middle") end)
    :wait(0.2)
    :do_now(function() print("end") end)
    :onComplete(function() print("done!") end)
    :start()

-- With timer types
TimerChain.new()
    :after(1.0, function() print("1 second") end)
    :every(0.5, function() print("tick") end, 3)  -- 3 ticks
    :tween(1.0,
        function() return entity.alpha end,
        function(v) entity.alpha = v end,
        0)  -- fade out
    :onComplete(function() destroy(entity) end)
    :start()
```

*— from core/timer_chain.lua:66-410*

**TimerChain methods:**

| Method | Description |
|--------|-------------|
| `:wait(delay)` | Pause for delay seconds |
| `:do_now(fn)` | Execute immediately (alias for `:after(0, fn)`) |
| `:after(delay, fn)` | One-shot delay |
| `:every(interval, fn, times?, immediate?, after?)` | Repeating |
| `:cooldown(delay, condition, fn, ...)` | Conditional repeat |
| `:for_time(duration, fn_dt, after?)` | Run every frame for duration |
| `:tween(duration, getter, setter, target, ...)` | Animate value |
| `:fork(chain)` | Launch parallel chain |
| `:onComplete(fn)` | Final callback |
| `:start()` | Execute the chain |
| `:pause()` / `:resume()` / `:cancel()` | Control |

**Real usage example:**

```lua
-- Animate card flip
TimerChain.new("card_flip")
    :tween(0.15,
        function() return transform.scaleX end,
        function(v) transform.scaleX = v end,
        0)
    :do_now(function() swapCardFace() end)
    :tween(0.15,
        function() return transform.scaleX end,
        function(v) transform.scaleX = v end,
        1)
    :start()
```

**Gotcha:** Call `:start()` to execute — the chain does nothing until started.

**Gotcha:** Steps execute sequentially with accumulated delays. Use `:fork()` for parallel.

***

## Timer Scopes (Automatic Cleanup)

\label{recipe:timer-scope}

**When to use:** Group timers for automatic cleanup when a system/entity is destroyed.

```lua
local TimerScope = require("core.timer_scope")

-- Create a scope for a system/feature
local scope = TimerScope.new("my_feature")
scope:after(2.0, function() print("delayed") end)
scope:every(0.5, function() print("repeating") end)

-- Later, clean up all timers with one call
scope:destroy()
```

*— from core/timer_scope.lua*

### Entity-Bound Scopes

```lua
-- Scope tied to an entity's lifecycle
local entityScope = TimerScope.for_entity(entity)
entityScope:after(1.0, function() doSomething() end)
-- Automatically cleaned when entity is destroyed (if integrated with lifecycle)
```

### Scope Methods

| Method | Description |
|--------|-------------|
| `TimerScope.new(name)` | Create named scope |
| `TimerScope.for_entity(entity)` | Create entity-bound scope |
| `scope:after(delay, fn, tag?)` | Schedule delayed action |
| `scope:every(delay, fn, times?, immediate?, after?, tag?)` | Schedule repeating action |
| `scope:cancel(tag)` | Cancel specific timer |
| `scope:destroy()` | Cancel ALL timers in scope |
| `scope:count()` | Get active timer count |
| `scope:active()` | Check if scope is still active |

**Gotcha:** After `scope:destroy()`, the scope cannot accept new timers.

**Real usage example:**

```lua
-- AI agent with scoped timers
local function createAgent(entity)
    local scope = TimerScope.for_entity(entity)

    scope:every(1.0, function()
        updateAILogic(entity)
    end)

    -- When entity dies, all timers are cleaned up
    signal.register("entity_destroyed", function(eid)
        if eid == entity then
            scope:destroy()
        end
    end)
end
```

***

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

***

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

***

## Event Bridge (Combat Bus → Signals)

\label{recipe:event-bridge}

**When to use:** Connect combat system events (ctx.bus) to the signal system so both can respond to the same events.

**Why this exists:** The combat system uses its own EventBus (`ctx.bus:emit`), while other systems like wave director use `signal.emit`. Without bridging, events only reach listeners of their own system.

```lua
local EventBridge = require("core.event_bridge")

-- After creating combat context:
EventBridge.attach(combat_context)

-- Now combat events are automatically forwarded:
-- ctx.bus:emit("OnDeath", data)  →  signal.emit("enemy_killed", entityId)
```

*— from core/event_bridge.lua:17-23*

**Bridged Events:**

| Combat Bus Event | Signal Event | Notes |
|------------------|--------------|-------|
| `OnEnemySpawned` | `enemy_spawned` | Enemy lifecycle |
| `OnHitResolved` | `combat_hit` | Damage applied |
| `OnDodge` | `combat_dodge` | Attack dodged |
| `OnMiss` | `combat_miss` | Attack missed |
| `OnCrit` | `combat_crit` | Critical hit |
| `OnHealed` | `combat_healed` | Healing applied |
| `OnStatusApplied` | `status_applied` | Status effect added |
| `OnStatusRemoved` | `status_removed` | Status effect removed |

**Special case — OnDeath:**

`OnDeath` is NOT auto-bridged because combat bus passes a combat actor, not an entity ID. Handle manually:

```lua
-- In gameplay.lua
ctx.bus:on("OnDeath", function(data)
    local enemyEntity = combatActorToEntity[data.entity]
    signal.emit("enemy_killed", enemyEntity)  -- Wave system expects entity ID
end)
```

*— See gameplay.lua:5234*

**Adding new bridges:**

Add entries to `BRIDGED_EVENTS` in `event_bridge.lua`:

```lua
{
    bus_event = "OnMyEvent",
    signal_event = "my_event",  -- Optional: defaults to snake_case of bus_event
    transform = function(data) return modified_data end  -- Optional
}
```

**Gotcha:** Bridge is one-way (bus → signal) to avoid loops.

**Gotcha:** Only explicitly listed events are bridged. Add to `BRIDGED_EVENTS` for new events.

***

## Signal Groups (Scoped Cleanup)

\label{recipe:signal-group}

**When to use:** Register event handlers that need cleanup when a module, entity, or scene is destroyed.

```lua
local signal_group = require("core.signal_group")

-- Create a group for this module/entity
local handlers = signal_group.new("combat_ui")

-- Register handlers (same API as hump.signal)
handlers:on("enemy_killed", function(entity)
    updateKillCount()
end)

handlers:on("player_damaged", function(entity, data)
    showDamageFlash()
end)

-- When done (e.g., scene unload, entity destroyed):
handlers:cleanup()  -- Removes ALL handlers in this group at once
```

*— from core/signal_group.lua:1-164*

**Why use signal_group:**
- Prevents memory leaks from orphaned handlers
- Single cleanup call removes all handlers
- Tracks count of registered handlers for debugging

**API Reference:**

| Method | Description |
|--------|-------------|
| `signal_group.new(name?)` | Create a new group |
| `group:on(event, handler)` | Register handler (alias: `:register`) |
| `group:off(event, handler)` | Remove specific handler (alias: `:remove`) |
| `group:cleanup()` | Remove ALL handlers in group |
| `group:count()` | Get number of registered handlers |
| `group:isCleanedUp()` | Check if already cleaned up |
| `group:getName()` | Get group name (for debugging) |

**Real usage example:**

```lua
-- Entity with scoped event handlers
function createEnemy(entity)
    local handlers = signal_group.new("enemy_" .. entity)

    handlers:on("wave_complete", function()
        -- React to wave ending
    end)

    -- When entity dies, clean up all handlers
    signal.register("entity_destroyed", function(eid)
        if eid == entity then
            handlers:cleanup()
        end
    end)
end
```

**Gotcha:** After `:cleanup()`, the group will warn if you try to register new handlers.

***

## Popup Helpers

\label{recipe:popup}

**When to use:** Quick damage/heal numbers and floating text without Text Builder boilerplate.

```lua
local popup = require("core.popup")

-- Damage numbers (red, above entity)
popup.damage(entity, 25)

-- Heal numbers (green, above entity)
popup.heal(entity, 50)

-- Custom text above entity
popup.above(entity, "CRITICAL!", { color = "gold" })

-- Text at specific position
popup.at(100, 200, "Hello!", { color = "white" })
```

*— from core/popup.lua:1-217*

**Convenience functions:**

```lua
-- Combat feedback
popup.damage(entity, amount)           -- Red damage number
popup.heal(entity, amount)             -- Green heal number
popup.critical(entity, amount)         -- Orange with pop effect
popup.miss(entity)                     -- Gray "Miss!" text
popup.blocked(entity)                  -- Gray "Blocked!" text

-- Resource changes
popup.mana(entity, amount)             -- Blue mana change
popup.gold(entity, amount)             -- Gold currency change
popup.xp(entity, amount)               -- Purple XP gain

-- Generic
popup.above(entity, text, opts)        -- Above entity center
popup.below(entity, text, opts)        -- Below entity center
popup.at(x, y, text, opts)             -- At specific position
popup.status(entity, text, opts)       -- Status text (shorter duration)
```

**Options:**

| Option | Type | Description |
|--------|------|-------------|
| `color` | string | Color name (e.g., "red", "gold", "pastel_blue") |
| `duration` | number | Display duration in seconds (default: 3.0) |
| `effect` | string | Text effects (e.g., "pop=0.2;shake=2") |
| `offset_y` | number | Vertical offset from entity center |
| `critical` | boolean | Add pop effect for critical hits |

**Configuration (defaults):**

```lua
popup.defaults = {
    duration = 3.0,
    heal_color = "pastel_pink",
    damage_color = "red",
    mana_color = "pastel_blue",
    gold_color = "gold",
    xp_color = "pastel_purple",
    offset_y = -20,
}
```

**Gotcha:** Uses `Q.visualCenter()` internally, so popups appear at the rendered position (not physics position).

***

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

***

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

***

## Timer Options API (Advanced)

**When to use:** Clearer than positional parameters for complex timers.

```lua
local timer = require("core.timer")

-- After with options
timer.after_opts({
    delay = 2.0,
    action = function() print("done") end,
    tag = "my_timer"
})

-- Every with options
timer.every_opts({
    delay = 0.5,
    action = updateHealth,
    times = 10,           -- 0 = infinite
    immediate = true,     -- run once immediately
    tag = "health_update"
})

-- Cooldown
timer.cooldown_opts({
    delay = 1.0,
    condition = function() return canAttack end,
    action = doAttack,
    times = 3,
    tag = "attack_cd"
})
```

*— Documented in CLAUDE.md, wrapper functions around timer.after/every/cooldown with named parameters*

**Gotcha:** Options API uses table syntax. Don't forget the curly braces!

**Gotcha:** These are convenience wrappers. You can always fall back to the positional parameter versions (`timer.after()`, `timer.every()`, etc.) if preferred.

***

## Q.lua: Quick Transform Helpers

\label{recipe:q-helpers}

**When to use:** Quick transform operations without verbose component access.

```lua
local Q = require("core.Q")

-- Position & Movement
Q.move(entity, 100, 200)       -- Move to absolute position
Q.offset(entity, 10, 0)        -- Move relative to current position

-- Center Points
local cx, cy = Q.center(entity)         -- Authoritative physics position
local vx, vy = Q.visualCenter(entity)   -- Visual/rendered position (for effects)

-- Dimensions
local w, h = Q.size(entity)    -- Get width, height

-- Bounding Boxes
local x, y, w, h = Q.bounds(entity)        -- Authoritative bounds
local vx, vy, vw, vh = Q.visualBounds(entity)  -- Visual bounds

-- Rotation
local rad = Q.rotation(entity)         -- Get rotation in radians
Q.setRotation(entity, math.pi / 4)     -- Set absolute rotation
Q.rotate(entity, 0.1)                  -- Rotate by delta

-- Entity Validation
if Q.isValid(entity) then ... end      -- Check if entity exists
Q.ensure(entity, "spawn_explosion")    -- Assert valid or error with context

-- Spatial Queries
local dist = Q.distance(e1, e2)                    -- Distance between entities
local dist = Q.distanceToPoint(entity, x, y)       -- Distance to point
if Q.isInRange(e1, e2, 100) then ... end           -- Range check
local dx, dy = Q.direction(e1, e2)                 -- Normalized direction vector

-- Component Access
local transform = Q.getTransform(entity)   -- Safe component get (returns nil if invalid)
Q.withTransform(entity, function(t)        -- Execute only if valid
    t.actualX = t.actualX + 10
end)
```

*— from core/Q.lua:1-272*

### Visual vs Authoritative Position

**Use `Q.center()` for:**
- Physics calculations
- Collision detection
- AI pathfinding
- Gameplay logic

**Use `Q.visualCenter()` for:**
- Spawning visual effects (particles, damage numbers)
- Screen-space UI positioning
- Camera following smoothed position

**Example:**
```lua
-- Wrong: effect lags behind fast-moving entity
local cx, cy = Q.center(enemy)
spawnParticles(cx, cy)  -- Appears at physics position

-- Right: effect spawns at rendered location
local vx, vy = Q.visualCenter(enemy)
spawnParticles(vx, vy)  -- Appears where player sees entity
```

**Replace verbose patterns:**

```lua
-- OLD (4 lines)
local transform = component_cache.get(entity, Transform)
if transform then
    transform.actualX = x
    transform.actualY = y
end

-- NEW (1 line)
Q.move(entity, x, y)
```

**API Reference:**

| Function | Returns | Description |
|----------|---------|-------------|
| `Q.move(entity, x, y)` | boolean | Set absolute position |
| `Q.center(entity)` | x, y or nil | Get authoritative center point |
| `Q.visualCenter(entity)` | x, y or nil | Get visual/rendered center point |
| `Q.offset(entity, dx, dy)` | boolean | Move relative to current position |
| `Q.size(entity)` | w, h or nil | Get entity dimensions |
| `Q.bounds(entity)` | x, y, w, h or nil | Get authoritative bounding box |
| `Q.visualBounds(entity)` | x, y, w, h or nil | Get visual bounding box |
| `Q.rotation(entity)` | radians or nil | Get rotation in radians |
| `Q.setRotation(entity, rad)` | boolean | Set absolute rotation |
| `Q.rotate(entity, delta)` | boolean | Rotate by delta radians |
| `Q.isValid(entity)` | boolean | Check if entity exists |
| `Q.ensure(entity, ctx?)` | entity or nil | Assert valid with optional error context |
| `Q.distance(e1, e2)` | number or nil | Distance between entities |
| `Q.distanceToPoint(e, x, y)` | number or nil | Distance to point |
| `Q.isInRange(e1, e2, range)` | boolean | Check if within range |
| `Q.direction(e1, e2)` | dx, dy or nil | Normalized direction vector |
| `Q.getTransform(entity)` | Transform or nil | Get Transform component |
| `Q.withTransform(e, fn)` | boolean | Execute callback with transform if valid |

**Gotcha:** All functions return `false` or `nil` if the entity has no Transform component. Check return values when you need to know if the operation succeeded.

***

## Constants: Type-Safe Magic Strings

\label{recipe:constants}

**When to use:** Avoid typos and enable IDE autocomplete for collision tags, states, damage types, and other frequently-used strings.

```lua
local C = require("core.constants")

-- Collision tags
PhysicsBuilder.for_entity(entity)
    :tag(C.CollisionTags.ENEMY)
    :collideWith({ C.CollisionTags.PLAYER, C.CollisionTags.PROJECTILE })
    :apply()

-- State tags
add_state_tag(entity, C.States.PLANNING)

-- Damage types
card.damage_type = C.DamageTypes.FIRE

-- Card types
if card.type == C.CardTypes.ACTION then
    -- process action card
end

-- Content tags
if card.tags[C.Tags.FIRE] then
    applyBurnEffect()
end
```

*— from core/constants.lua:1-247*

**Available constant groups:**

| Group | Example Values | Usage |
|-------|----------------|-------|
| `C.CollisionTags` | PLAYER, ENEMY, PROJECTILE, BULLET, WORLD | Physics tags |
| `C.States` | PLANNING, ACTION, MENU, PAUSED, GAME_OVER | Game states |
| `C.DamageTypes` | FIRE, ICE, LIGHTNING, POISON, ARCANE | Damage calculations |
| `C.Tags` | Fire, Ice, Projectile, AoE, Buff, Debuff | Content tags |
| `C.CardTypes` | ACTION, MODIFIER, TRIGGER | Card categorization |
| `C.Rarities` | COMMON, UNCOMMON, RARE, LEGENDARY | Item rarities |
| `C.Shaders` | DISSOLVE, OUTLINE, HOLOGRAM | Shader names |
| `C.DrawSpace` | WORLD, SCREEN | Render spaces |
| `C.SyncModes` | PHYSICS, TRANSFORM | Physics sync modes |

**Utility functions:**

```lua
-- Get all values as array
local allDamageTypes = Constants.values(C.DamageTypes)

-- Check if value is valid
if Constants.is_valid(C.DamageTypes, "fire") then
    -- Valid damage type
end
```

**Gotcha:** Constants are lowercase strings internally (e.g., `C.DamageTypes.FIRE` → `"fire"`). This matches the existing codebase conventions.

**Gotcha:** Use `C.States.ACTION` instead of the internal string `"SURVIVORS"` — the constant abstracts implementation details.

***

## FSM: Declarative State Machine

\label{recipe:fsm}

**When to use:** Manage entity states (idle, chase, attack) with automatic state tag syncing and clean transition callbacks.

```lua
local FSM = require("core.fsm")

-- Define state machine structure
local enemyFSM = FSM.define {
    initial = "idle",
    states = {
        idle = {
            enter = function(self) print("entering idle") end,
            update = function(self, dt)
                if self:seePlayer() then
                    self:transition("chase")
                end
            end,
            exit = function(self) print("leaving idle") end,
        },
        chase = {
            enter = function(self) self.speed = 100 end,
            update = function(self, dt)
                Q.chase(self.entity, player, self.speed)
                if self:inRange() then
                    self:transition("attack")
                end
            end,
        },
        attack = {
            enter = function(self) self:startAttack() end,
            update = function(self, dt) end,
        },
    },
}

-- Create instance for an entity
local fsm = enemyFSM:new(entity, { speed = 50 })

-- In update loop
fsm:update(dt)

-- Manual transition
fsm:transition("chase")

-- Check current state
if fsm:is("idle") then ... end
local state = fsm:getState()

-- Pause/resume
fsm:pause()
fsm:resume()
```

*— from core/fsm.lua:1-151*

**API Reference:**

| Method | Description |
|--------|-------------|
| `FSM.define(config)` | Create state machine definition |
| `definition:new(entity, data)` | Create instance for entity |
| `instance:transition(state)` | Switch to new state |
| `instance:update(dt)` | Run current state's update |
| `instance:is(state)` | Check if in state |
| `instance:getState()` | Get current state name |
| `instance:pause() / :resume()` | Control updates |

**Gotcha:** FSM state names are independent of global constants (PLANNING_STATE, etc.). The FSM auto-syncs with ECS state tags via `add_state_tag()` if available.

***

## Tween: Property Animation

\label{recipe:tween}

**When to use:** Animate entity properties (position, scale, alpha) with easing functions.

```lua
local Tween = require("core.tween")

-- Animate entity transform
Tween.to(entity, 0.5, { x = 100, y = 200 })
    :ease("outQuad")
    :onComplete(function() print("done!") end)
    :start()

-- Animate scale with bounce
Tween.to(entity, 0.3, { scale = 1.2 })
    :ease("outBack")
    :start()

-- Fade out
Tween.to(entity, 0.5, { alpha = 0 })
    :ease("outQuad")
    :onComplete(function() destroy(entity) end)
    :start()

-- Animate arbitrary value
Tween.value(0, 100, 1.0, function(v) bar.width = v end)
    :ease("outBounce")
    :start()

-- Convenience presets
Tween.fadeOut(entity, 0.3)
Tween.fadeIn(entity, 0.3)
Tween.popIn(entity, 0.2)
```

*— from core/tween.lua:1-200*

**Available Easing Functions:**

| Name | Description |
|------|-------------|
| `linear` | Constant speed |
| `inQuad`, `outQuad`, `inOutQuad` | Quadratic |
| `inCubic`, `outCubic`, `inOutCubic` | Cubic |
| `outBack` | Overshoot then settle |
| `outElastic` | Spring-like bounce |
| `outBounce` | Bouncing ball |

**Gotcha:** Don't forget to call `:start()` — the tween won't run until started.

**Gotcha:** Tweens use timer internally. Use `:tag("name")` if you need to cancel.

***

## Fx: Unified Visual Effects

\label{recipe:fx}

**When to use:** Combine flash, shake, particles, sound, and popups in one fluent chain.

```lua
local Fx = require("core.fx")

-- Fluent chaining (deferred execution)
Fx.at(enemy)
    :flash(0.2)
    :shake(5, 0.3)
    :particles("spark", 10)
    :sound("hit_01")
    :go()

-- Presets for common effects
Fx.hit(enemy)           -- flash + shake + sparks
Fx.death(enemy)         -- explosion particles + sound
Fx.damage(enemy, 25)    -- flash + damage number
Fx.heal(entity, 50)     -- green particles + heal number

-- Position-based effects
Fx.point(100, 200)
    :particles("explosion", 20)
    :shake(10, 0.5)
    :go()
```

*— from core/fx.lua:1-200*

**Chain Methods:**

| Method | Description |
|--------|-------------|
| `:flash(duration)` | Flash entity white |
| `:shake(intensity, duration)` | Screen shake |
| `:particles(name, count)` | Spawn particles |
| `:sound(name, category?)` | Play sound effect |
| `:popup(text, opts)` | Show floating text |
| `:damage(amount, opts)` | Show damage number |
| `:heal(amount, opts)` | Show heal number |
| `:delay(seconds)` | Wait before next action |
| `:go()` | Execute the chain |

**Gotcha:** Call `:go()` to execute the chain. Without it, nothing happens.

***

## Pool: Object Pooling

\label{recipe:pool}

**When to use:** Reuse frequently created/destroyed objects (projectiles, particles) to reduce garbage collection.

```lua
local Pool = require("core.pool")

-- Create a pool
local bulletPool = Pool.create({
    name = "bullets",
    factory = function() return createBulletEntity() end,
    reset = function(entity) resetBullet(entity) end,
    initial = 20,   -- Pre-create 20 objects
    max = 100,      -- Maximum pool size
})

-- Acquire object from pool
local bullet = bulletPool:acquire()
if bullet then
    initBullet(bullet, x, y, direction)
end

-- Release back to pool when done
bulletPool:release(bullet)

-- Auto-release after duration
bulletPool:acquireFor(1.5, function(bullet)
    -- bullet auto-releases after 1.5 seconds
    initBullet(bullet, x, y, direction)
end)

-- Pool stats
local available = bulletPool:availableCount()
local active = bulletPool:activeCount()
```

*— from core/pool.lua:1-120*

**Configuration Options:**

| Option | Type | Description |
|--------|------|-------------|
| `name` | string | Pool identifier (for debugging) |
| `factory` | function | Creates new object when pool is empty |
| `reset` | function | Resets object state before reuse |
| `onAcquire` | function | Called when object is acquired |
| `onRelease` | function | Called when object is released |
| `initial` | number | Pre-created objects (default: 0) |
| `max` | number | Maximum pool size (default: 100) |

**Gotcha:** Always call `release()` when done with an object. Leaking objects defeats the purpose of pooling.

**Gotcha:** `acquire()` returns `nil` if pool is at max capacity. Check the return value.

***

## Debug: Visual Debugging

\label{recipe:debug}

**When to use:** Visualize bounds, velocities, colliders, and paths during development.

```lua
local Debug = require("core.debug")

-- Enable debug rendering
Debug.enabled = true

-- In update loop
function update(dt)
    Debug.bounds(entity)          -- Green rectangle around entity
    Debug.velocity(entity)        -- Yellow arrow showing velocity
    Debug.circle(x, y, radius)    -- Circle outline
    Debug.text(entity, "HP: 100") -- Text label above entity
    Debug.collider(entity)        -- Red collision shape
    Debug.point(x, y)             -- Small marker at position
    Debug.line(x1, y1, x2, y2)    -- Line between points
    Debug.path(points)            -- Connected path visualization
end

-- Customize colors
Debug.colors.bounds = { r = 0, g = 255, b = 0, a = 128 }
Debug.colors.velocity = { r = 255, g = 255, b = 0, a = 200 }
```

*— from core/debug.lua:1-150*

**Available Functions:**

| Function | Description |
|----------|-------------|
| `Debug.bounds(entity)` | Draw bounding box |
| `Debug.velocity(entity)` | Draw velocity vector |
| `Debug.circle(x, y, r)` | Draw circle outline |
| `Debug.text(entity, str)` | Draw text label |
| `Debug.collider(entity)` | Draw collision shape |
| `Debug.point(x, y)` | Draw point marker |
| `Debug.line(x1, y1, x2, y2)` | Draw line |
| `Debug.path(points)` | Draw connected points |

**Gotcha:** Set `Debug.enabled = false` in production builds. Debug drawing has performance cost.

***

## Lighting: Dynamic Layer Lights

\label{recipe:lighting}

**When to use:** Add dynamic point lights and spotlights to render layers with real-time shadows.

```lua
local Lighting = require("core.lighting")

-- Enable lighting on a layer
Lighting.enable("sprites", { mode = "subtractive" })
Lighting.setAmbient("sprites", 0.1)  -- Dim ambient (0-1)

-- Create a point light attached to player
local light = Lighting.point()
    :attachTo(playerEntity)
    :radius(200)
    :intensity(1.0)
    :color("orange")
    :layer("sprites")
    :create()

-- Create a spotlight
local spot = Lighting.spot()
    :at(400, 300)
    :direction(90)      -- degrees
    :angle(45)          -- cone angle
    :radius(300)
    :layer("sprites")
    :create()

-- Animate light
timer.every(0.1, function()
    light:setIntensity(0.8 + math.random() * 0.4)  -- Flickering
end)

-- Move light
light:setPosition(x, y)

-- Cleanup
light:destroy()
Lighting.removeAll("sprites")
Lighting.disable("sprites")
```

*— from core/lighting.lua:1-400*

**Light Builder Methods:**

| Method | Description |
|--------|-------------|
| `:at(x, y)` | Set position |
| `:attachTo(entity)` | Follow entity (auto-updates) |
| `:radius(pixels)` | Light reach distance |
| `:intensity(0-1)` | Light brightness |
| `:color(name/rgb)` | Light color |
| `:layer(name)` | Target render layer |
| `:direction(degrees)` | Spotlight direction |
| `:angle(degrees)` | Spotlight cone angle |
| `:create()` | Finalize and add to scene |

**Named Colors:** `white`, `orange`, `fire`, `ice`, `electric`, `gold`, `red`, `blue`, etc.

**Gotcha:** Max 16 lights per layer (shader limit). Lights auto-cleanup when attached entities are destroyed.

\newpage

# Entity Creation

This chapter covers how to create and configure game entities with sprites, data, interactivity, and physics.

## EntityBuilder (Recommended)

\label{recipe:entity-builder}

**When to use:** Creating entities with common patterns. Reduces 15-30 lines to 3-5 lines.

### EntityBuilder.create() - Static API

**Best for:** One-shot entity creation with all options.

```lua
local EntityBuilder = require("core.entity_builder")

-- Full options
local entity, script = EntityBuilder.create({
    sprite = "kobold",
    position = { x = 100, y = 200 },  -- or { 100, 200 }
    size = { 64, 64 },                -- width, height
    shadow = true,
    data = { health = 100, faction = "enemy" },
    interactive = {
        hover = { title = "Enemy", body = "A dangerous kobold" },
        click = function(reg, eid) print("clicked!") end,
        drag = true,
        collision = true
    },
    state = PLANNING_STATE,
    shaders = { "3d_skew_holo", { "dissolve", { dissolve = 0.5 } } }
})
```

*— from core/entity_builder.lua:137-227*

**Gotcha:** Data is assigned BEFORE attach_ecs automatically — no need to worry about the order!

**Gotcha:** The `script` return value is only present if you passed `data` option. Otherwise it's nil.

***

### EntityBuilder.simple() - Minimal Version

**Best for:** Quick entity creation with just sprite + position.

```lua
local EntityBuilder = require("core.entity_builder")

-- Minimal version (sprite, x, y, w, h)
local entity = EntityBuilder.simple("kobold", 100, 200, 64, 64)
```

*— from core/entity_builder.lua:236-243*

***

### EntityBuilder.interactive() - Interactive Entities

**Best for:** Creating buttons, clickable items, draggable objects.

```lua
local EntityBuilder = require("core.entity_builder")

local entity, script = EntityBuilder.interactive({
    sprite = "button",
    position = { 100, 100 },
    size = { 80, 40 },
    hover = { title = "Click me", body = "Description" },
    click = function(reg, eid)
        print("Button clicked!")
    end,
    drag = true  -- enable dragging
})
```

*— from core/entity_builder.lua:249-261*

***

### EntityBuilder.new() - Fluent API

**Best for:** Step-by-step construction with escape hatches for manual operations.

```lua
local EntityBuilder = require("core.entity_builder")

-- Fluent chaining
local builder = EntityBuilder.new("kobold")
    :at(100, 200)
    :size(64, 64)
    :shadow(true)
    :withData({ health = 100 })
    :withHover("Enemy", "A dangerous kobold")
    :onClick(function(reg, eid) print("clicked!") end)

-- ESCAPE HATCH: Get entity before finishing
local entity = builder:getEntity()

-- Manual operations
local transform = builder:getTransform()
transform.actualR = math.rad(45)  -- rotate 45 degrees

-- Continue building
builder:withShaders({ "3d_skew_holo" })

-- Finalize
local entity, script = builder:build()
```

*— from core/entity_builder.lua:276-368*

**Gotcha:** Escape hatches (`getEntity()`, `getTransform()`, `getGameObject()`, `getScript()`) return raw objects — mix builder + manual operations freely!

***

## ChildBuilder (Parent-Child Attachment)

\label{recipe:child-builder}

**When to use:** Attach child entities to parents with transform inheritance (e.g., weapons following players, effects attached to characters).

```lua
local ChildBuilder = require("core.child_builder")

-- Attach weapon to player with offset and rotation inheritance
ChildBuilder.for_entity(weapon)
    :attachTo(player)
    :offset(20, 0)              -- 20px right of parent center
    :rotateWith()               -- rotate with parent
    :apply()

-- Attach with eased following (smooth movement)
ChildBuilder.for_entity(floatingOrb)
    :attachTo(player)
    :offset(0, -40)
    :eased()                    -- smooth position following
    :scaleWith()                -- scale with parent
    :apply()

-- Named child for lookup
ChildBuilder.for_entity(shield)
    :attachTo(player)
    :offset(-30, 0)
    :named("shield")
    :permanent()                -- survives parent death
    :apply()
```

*— from core/child_builder.lua:66-180*

### Builder Methods

| Method | Description |
|--------|-------------|
| `:attachTo(parent)` | Set parent entity |
| `:offset(x, y)` | Position offset from parent center |
| `:rotateWith()` | Inherit parent rotation |
| `:scaleWith()` | Inherit parent scale |
| `:eased()` | Smooth position following |
| `:instant()` | Instant position snap (default) |
| `:named(name)` | Name for lookup |
| `:permanent()` | Persist after parent death |
| `:apply()` | Apply configuration |

### Static Helpers

```lua
-- Immediately change offset
ChildBuilder.setOffset(weapon, 10, 5)

-- Get current offset
local ox, oy = ChildBuilder.getOffset(weapon)

-- Get parent entity
local parent = ChildBuilder.getParent(weapon)

-- Detach from parent
ChildBuilder.detach(weapon)

-- Animate offset (weapon swing)
ChildBuilder.animateOffset(weapon, {
    to = { x = -20, y = 30 },
    duration = 0.2,
    ease = "outQuad"
})

-- Orbit animation (circular swing)
ChildBuilder.orbit(weapon, {
    radius = 30,
    startAngle = 0,
    endAngle = math.pi/2,
    duration = 0.2
})
```

**Gotcha:** `:apply()` must be called to finalize the attachment.

**Gotcha:** Offset is relative to parent center, not parent origin.

**Gotcha:** Use `:permanent()` for children that should survive parent death (e.g., dropped loot).

***

## EntityLinks (Lifecycle Dependencies)

\label{recipe:entity-links}

**When to use:** Make entities automatically die when their "owner" entity is destroyed (e.g., projectiles linked to caster, buffs linked to source).

```lua
local EntityLinks = require("core.entity_links")

-- Projectile dies when owner dies
EntityLinks.link(projectile, owner)

-- Remove specific link
EntityLinks.unlink(projectile, owner)

-- Remove all links for entity
EntityLinks.unlinkAll(projectile)

-- Check if linked
if EntityLinks.isLinkedTo(projectile, owner) then
    print("Projectile will die when owner dies")
end

-- Get all targets this entity is linked to
local targets = EntityLinks.getLinkedTargets(projectile)
```

*— from core/entity_links.lua:42-120*

### From Script Instance

```lua
-- behavior_script_v2 has built-in link methods
local projectile = spawn.projectile("fireball", x, y, angle)

-- Link to owner
projectile:linkTo(owner)

-- Unlink
projectile:unlinkFrom(owner)

-- Clear all links
projectile:unlinkAll()
```

*— from monobehavior/behavior_script_v2.lua:320-340*

**Use Cases:**

| Scenario | Pattern |
|----------|---------|
| Projectile cleanup | `EntityLinks.link(projectile, caster)` |
| Buff tied to source | `EntityLinks.link(buffEffect, buffSource)` |
| Summon tied to summoner | `EntityLinks.link(summon, summoner)` |
| UI tied to entity | `EntityLinks.link(healthBar, enemy)` |

**Gotcha:** Links are one-way: dependent dies when target dies, not vice versa.

**Gotcha:** Links are automatically cleaned up when either entity is destroyed.

**Gotcha:** This is "horizontal" linking (peer entities). For "vertical" parent-child relationships, use ChildBuilder instead.

***

## Create Entity with Sprite (Manual Pattern)

\label{recipe:entity-sprite}

**When to use:** Need low-level control or EntityBuilder doesn't fit your use case.

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

***

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

***

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

***

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

***

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

***

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

***

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

***

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

***

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

**Gotcha:** Follow the order: Create -> Script Setup -> Attach -> Position -> Interactivity -> State Tags.

\newpage

# Physics

This chapter covers physics integration using Chipmunk2D: creating physics bodies, collision detection, applying forces, and physics constraints.

## PhysicsBuilder (Recommended)

\label{recipe:physics-builder}

**When to use:** Adding physics to entities. Reduces 10-15 lines to 3-5 lines.

### PhysicsBuilder.for_entity() - Fluent API

**Best for:** Setting up physics with method chaining.

```lua
local PhysicsBuilder = require("core.physics_builder")

-- Fluent API
PhysicsBuilder.for_entity(entity)
    :circle()                           -- or :rectangle()
    :tag("projectile")
    :bullet()                           -- high-speed collision detection
    :friction(0)
    :restitution(0.5)                   -- bounciness
    :fixedRotation()                    -- lock rotation
    :syncMode("physics")                -- "physics" or "transform"
    :collideWith({ "enemy", "WORLD" })
    :apply()
```

*— from core/physics_builder.lua:275-319*

**All available methods:**

| Method | Description |
|--------|-------------|
| `:circle()` | Circle collider shape |
| `:rectangle()` | Rectangle collider shape |
| `:shape(name)` | Custom shape name |
| `:tag(string)` | Collision tag |
| `:sensor(bool)` | Is sensor (no physical response) |
| `:density(number)` | Body density |
| `:friction(number)` | Surface friction (0-1) |
| `:restitution(number)` | Bounciness (0-1) |
| `:bullet(bool)` | CCD for fast objects |
| `:fixedRotation(bool)` | Lock rotation |
| `:syncMode(string)` | "physics" or "transform" |
| `:collideWith(table)` | Tags to collide with |
| `:world(name)` | Physics world name (default "world") |
| `:apply()` | Apply all settings |

**Gotcha:** Must call `:apply()` to finalize the physics setup!

***

### PhysicsBuilder.quick() - Options Table

**Best for:** One-shot physics setup with an options table.

```lua
local PhysicsBuilder = require("core.physics_builder")

-- Quick setup
PhysicsBuilder.quick(entity, {
    shape = "circle",
    tag = "projectile",
    bullet = true,
    friction = 0,
    collideWith = { "enemy", "WORLD" }
})
```

*— from core/physics_builder.lua:303-319*

***

### Escape Hatches

**PhysicsBuilder provides escape hatches for manual operations:**

```lua
local builder = PhysicsBuilder.for_entity(entity)
    :circle()
    :tag("projectile")

-- Get raw objects for manual operations
local world = builder:getWorld()        -- physics world
local entity = builder:getEntity()      -- entity ID
local config = builder:getConfig()      -- current config table

-- Manual operations
physics.SetLinearDamping(world, entity, 0.5)

-- Then continue with builder
builder:apply()
```

*— from core/physics_builder.lua:150-188*

**Gotcha:** Escape hatches return raw objects — no opaque wrappers! Mix builder + manual operations freely.

***

## Get Physics World (Manual Pattern)

\label{recipe:get-physics-world}

**When to use:** Need low-level control or PhysicsBuilder doesn't fit your use case.

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

***

## Create Physics Body (Manual Pattern)

\label{recipe:add-physics}

**When to use:** Need low-level control or PhysicsBuilder doesn't fit your use case.

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

***

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

**Gotcha:** Collision setup is bidirectional. If A should collide with B, you must enable A->B and B->A.

**Gotcha:** The special "WORLD" tag is used for static geometry and screen bounds.

***

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

***

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

***

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

***

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

***

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

***

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

***

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

***

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

***

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

***

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

***

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

**Gotcha:** Follow the order: Create sprite -> Position -> Create physics -> Configure properties -> Set sync mode -> Setup collision masks.

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

**Gotcha:** The shader name must match a shader file in `assets/shaders/` (e.g., "3d_skew_holo" -> `3d_skew_holo_fragment.fs` + `3d_skew_holo_vertex.vs`).

***

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

***

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

***

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

***

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

***

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

***

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

***

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

***

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

***

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

***

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

***

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

**Gotcha:** Follow the order: Create sprite -> Position -> Apply shaders -> Add local draw commands. Local commands added before shaders may not render correctly.

***

## Hit Flash Effects (hitfx)

\label{recipe:hitfx}

**When to use:** Flash an entity white when hit by damage, with proper per-entity timing.

```lua
local hitfx = require("core.hitfx")

-- Flash entity for default duration (0.2s)
hitfx.flash(enemy)

-- Flash with custom duration
hitfx.flash(enemy, 0.3)  -- 300ms flash

-- Get cancel function to stop early
local cancel = hitfx.flash(enemy, 0.5)
-- Later...
cancel()  -- Stop flash immediately

-- Flash indefinitely until manually stopped
local stop = hitfx.flash_start(enemy)
-- When damage animation ends:
stop()

-- Or stop by entity
hitfx.flash_stop(enemy)
```

*— from core/hitfx.lua:94-151*

**API Reference:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `hitfx.flash(entity, duration?)` | entity, duration (default 0.2) | cancel function | Flash and auto-stop after duration |
| `hitfx.flash_start(entity)` | entity | cancel function | Flash indefinitely until stopped |
| `hitfx.flash_stop(entity)` | entity | - | Stop any active flash on entity |

**How it works:**

1. Adds `flash` shader pass to entity's shader pipeline
2. Sets per-entity `flashStartTime` uniform to current time (so flash starts at white)
3. Schedules removal of shader pass after duration
4. Returns cancel function for early termination

**Real usage example:**

```lua
-- When enemy takes damage
signal.register("combat_hit", function(entity, data)
    if entity_cache.valid(entity) then
        hitfx.flash(entity, 0.15)
    end
end)

-- In damage application
function applyDamage(target, amount)
    local script = safe_script_get(target)
    if script then
        script.health = script.health - amount
        hitfx.flash(target)  -- Visual feedback
        popup.damage(target, amount)  -- Damage number
    end
end
```

**Gotcha:** hitfx automatically manages shader components. You don't need to pre-add the flash shader.

**Gotcha:** Multiple rapid flashes on the same entity will restart the timer each time, keeping the entity flashing.

**Gotcha:** If the entity is destroyed, the scheduled cleanup is automatically skipped.

***

## Render Groups (Batch Shader Rendering)

\label{recipe:render-groups}

**When to use:** Batch-render multiple entities with shared shaders for better performance. Ideal for enemy groups, particle-like systems, or any scenario where many entities share the same shader effects.

**Pattern:** Create a render group with default shaders, add entities to it, then queue batch draws via command buffer.

```lua
-- 1. Create a render group with default shaders
render_groups.create("enemies", {"flash", "outline"})

-- 2. Add entities to the group
render_groups.add("enemies", enemy1)           -- Uses group defaults
render_groups.add("enemies", enemy2, {"3d_skew"})  -- Custom shaders

-- 3. Queue batch render in draw loop
command_buffer.queueDrawRenderGroup(layers.sprites, function(cmd)
    cmd.registry = registry
    cmd.groupName = "enemies"
    cmd.autoOptimize = true
end, 100, layer.DrawCommandSpace.World)
```

*— from src/systems/render_groups/render_groups.cpp:145-196, tests/test_render_groups.lua*

**API Reference:**

| Function | Parameters | Description |
|----------|------------|-------------|
| `render_groups.create(name, {shaders})` | group name, default shader list | Create a render group |
| `render_groups.add(group, entity)` | group name, entity | Add entity with group's default shaders |
| `render_groups.add(group, entity, {shaders})` | group name, entity, shader list | Add entity with custom shaders |
| `render_groups.remove(group, entity)` | group name, entity | Remove entity from group |
| `render_groups.removeFromAll(entity)` | entity | Remove entity from all groups |
| `render_groups.clearGroup(group)` | group name | Clear all entities from group |
| `render_groups.clearAll()` | - | Clear all groups |

**Per-entity shader manipulation:**

| Function | Parameters | Description |
|----------|------------|-------------|
| `render_groups.addShader(group, entity, shader)` | group, entity, shader name | Add shader to entity's list |
| `render_groups.removeShader(group, entity, shader)` | group, entity, shader name | Remove shader from entity |
| `render_groups.setShaders(group, entity, {shaders})` | group, entity, shader list | Replace entity's shader list |
| `render_groups.resetToDefault(group, entity)` | group, entity | Reset to group's default shaders |

**Complete example with visual test:**

```lua
local testGroup = "visual_test_3d_skew"

-- Initialize: create group and add entity
function init()
    render_groups.create(testGroup, {"3d_skew_holo"})
    
    local entity = animation_system.createAnimatedObjectWithTransform(
        "enemy_type_1.png", true
    )
    animation_system.resizeAnimationObjectsInEntityToFit(entity, 128, 128)
    
    local transform = component_cache.get(entity, Transform)
    transform.actualX = globals.screenWidth() / 2
    transform.actualY = 100
    
    render_groups.add(testGroup, entity)
end

-- Draw: queue the batch render
function draw()
    command_buffer.queueDrawRenderGroup(layers.sprites, function(cmd)
        cmd.registry = registry
        cmd.groupName = testGroup
        cmd.autoOptimize = true
    end, 1000, layer.DrawCommandSpace.World)
end

-- Cleanup: remove entities before destruction
function cleanup()
    render_groups.removeFromAll(entity)
    registry:destroy(entity)
    render_groups.clearGroup(testGroup)
end
```

*— from tests/test_render_groups_visual.lua*

**Gotcha:** Always call `render_groups.removeFromAll(entity)` or `render_groups.remove(group, entity)` before destroying an entity. The render group holds entity references.

**Gotcha:** Empty shader list in `add()` uses group defaults. To render without shaders, create a group with empty defaults.

**Gotcha:** `queueDrawRenderGroup` requires `cmd.registry`, `cmd.groupName`, and optionally `cmd.autoOptimize` in the callback.

***

## Text Builder (Fluent API)

\label{recipe:text-builder}

**When to use:** Spawn dynamic game text (damage numbers, notifications, labels) using a fluent particle-like API.

**Pattern:** Three-layer API: Recipe (define appearance) → Spawner (position) → Handle (lifecycle).

```lua
local Text = require("core.text")

-- Define a reusable text recipe
local damageText = Text.define()
    :content("[%d](color=red)")   -- Template with value placeholder
    :size(20)
    :fade()                        -- Alpha fades over lifetime
    :lifespan(0.8)

-- Spawn damage number above enemy
damageText:spawn(25):above(enemy, 10)  -- Shows "25" above enemy

-- In game loop, update all active text handles
function love.update(dt)
    Text.update(dt)
end
```

*— from core/text.lua*

### Recipe Configuration

```lua
local Text = require("core.text")

local recipe = Text.define()
    -- Content
    :content("Hello!")             -- Literal text
    :content("[%d](color=gold)")   -- Template (value passed to :spawn())
    :content(function(v) return tostring(v) end)  -- Callback

    -- Appearance
    :size(20)                      -- Font size
    :color("white")                -- Base color
    :effects("shake=2;float")      -- Per-character effects

    -- Behavior
    :fade()                        -- Alpha fade over lifetime
    :fadeIn(0.2)                   -- 20% of lifespan for fade-in
    :fadeOut(0.3)                  -- 30% of lifespan for fade-out (independent)
    :pop(0.15)                     -- Pop-in animation (scale 0→1 over 15% of lifespan)
    :lifespan(1.0)                 -- Auto-destroy after 1 second
    :lifespan(0.8, 1.2)            -- Random between 0.8-1.2

    -- Layout
    :width(200)                    -- Wrap width for multi-line
    :anchor("center")              -- "center" or "topleft"
    :align("center")               -- "left", "center", "right", "justify"

    -- Render settings
    :layer(myLayer)                -- Render layer
    :z(100)                        -- Z-index
    :space("world")                -- "world" or "screen"
    :font(myFont)                  -- Custom font
```

### Spawner Methods

```lua
local recipe = Text.define():content("Hit!"):size(16):fade():lifespan(0.5)

-- Position methods (each triggers spawn and returns Handle)
recipe:spawn():at(100, 200)            -- Absolute position
recipe:spawn():above(entity, 10)       -- Above entity with offset
recipe:spawn():below(entity, 5)        -- Below entity
recipe:spawn():center(entity)          -- Entity center
recipe:spawn():follow(entity, 0, -20)  -- Follow entity with offset

-- Spawn with value
recipe:spawn(42):above(enemy, 10)      -- "42" for damage numbers
```

### Handle Methods

```lua
local handle = recipe:spawn(10):above(enemy, 10)

-- Update content
handle:update("New text")              -- Change text
handle:update(99)                      -- Update value (if template)

-- Move position
handle:moveTo(200, 300)                -- Absolute position
handle:moveBy(10, -5)                  -- Relative offset

-- Lifecycle
handle:destroy()                       -- Immediate removal
handle:isAlive()                       -- Check if still active

-- Tags and bulk operations
local handles = recipe:spawn(10):at(100, 100):tag("damage")
Text.destroy_by_tag("damage")          -- Destroy all with tag
Text.get_by_tag("damage")              -- Get all handles with tag
```

### Entity Mode (Attach to Entity)

```lua
-- Create text as entity (for shader pipeline integration)
local handle = recipe:spawn("Label")
    :asEntity()                        -- Enable entity mode
    :shaders({ "3d_skew_holo" })       -- Add shaders
    :at(100, 200)

-- Text is now an entity with Transform component
-- Shaders will apply to the text
```

### Attach to Entity Lifecycle

```lua
-- Text auto-destroys when entity is destroyed
local handle = recipe:spawn("HP: 100")
    :attachTo(entity)
    :above(entity, 20)

-- When entity is destroyed, text is automatically cleaned up
```

**API Reference:**

| Recipe Method | Description |
|---------------|-------------|
| `:content(str/fn)` | Set text content or template |
| `:size(n)` | Font size |
| `:color(name)` | Base color |
| `:effects(str)` | Default character effects |
| `:fade()` | Enable alpha fade |
| `:fadeIn(pct)` | Fade-in percentage (0-1) |
| `:fadeOut(pct)` | Fade-out percentage (0-1), independent of fadeIn |
| `:pop(pct)` | Pop-in entrance animation (scale 0→1) |
| `:lifespan(min, max?)` | Auto-destroy lifespan |
| `:width(n)` | Wrap width |
| `:anchor("center"/"topleft")` | Anchor point |
| `:align("left"/"center"/"right")` | Text alignment |
| `:layer(obj)` | Render layer |
| `:z(n)` | Z-index |
| `:space("world"/"screen")` | Render space |
| `:spawn(value?)` | Create spawner |

| Spawner Method | Description |
|----------------|-------------|
| `:at(x, y)` | Spawn at position |
| `:above(entity, offset?)` | Spawn above entity |
| `:below(entity, offset?)` | Spawn below entity |
| `:center(entity)` | Spawn at entity center |
| `:follow(entity, dx?, dy?)` | Follow entity |
| `:asEntity()` | Create as entity |
| `:shaders({...})` | Add shaders (entity mode) |
| `:attachTo(entity)` | Bind lifecycle |
| `:tag(str)` | Add tag for bulk operations |

| Handle Method | Description |
|---------------|-------------|
| `:update(content)` | Change text/value |
| `:moveTo(x, y)` | Move to position |
| `:moveBy(dx, dy)` | Move by offset |
| `:destroy()` | Remove immediately |
| `:isAlive()` | Check if active |

| Global | Description |
|--------|-------------|
| `Text.update(dt)` | Update all handles (call in game loop) |
| `Text.destroy_by_tag(tag)` | Destroy handles with tag |
| `Text.get_by_tag(tag)` | Get handles with tag |

**Provenance:** See `assets/scripts/core/text.lua:1-600` for implementation.

**Gotcha:** Call `Text.update(dt)` in your game loop — text won't fade/expire without it.

**Gotcha:** Templates use `[%d]` for value placeholder. The value is passed to `:spawn(value)`.

***

## Particle Builder (Fluent API)

\label{recipe:particle-builder}

**When to use:** Spawn particle effects using composable recipes instead of verbose CreateParticle calls.

```lua
local Particles = require("core.particles")

-- Define a reusable particle recipe
local spark = Particles.define()
    :shape("circle")
    :size(4, 8)               -- random size between 4-8
    :color("orange", "red")   -- gradient from orange to red
    :fade()                   -- alpha fades over lifetime
    :lifespan(0.3)

-- Spawn a burst of 10 particles at position
spark:burst(10):at(x, y)
```

*— from core/particles.lua:9-19*

**Real usage example:**

```lua
-- Fire effect with smoke
local fire = Particles.define()
    :shape("circle")
    :size(4, 8)
    :color("orange", "red")
    :velocity(50, 100)
    :gravity(-50)             -- float upward
    :fade()
    :lifespan(0.5)

local smoke = Particles.define()
    :shape("circle")
    :size(8, 16)
    :color("gray")
    :velocity(20, 40)
    :gravity(-30)
    :fade()
    :lifespan(1.0)

-- Mix multiple recipes in one emission
Particles.mix({ fire, smoke })
    :burst(10, 5)             -- 10 fire, 5 smoke
    :at(x, y)
```

*— from core/particles.lua:22-28*

**Gotcha:** Recipes are immutable definitions. Create multiple recipes for different effect variations.

**Gotcha:** Use `:burst(count):at(x, y)` to spawn particles. The `at()` call triggers the spawn.

***

### Recipe Methods

\label{recipe:particle-recipe-methods}

| Method | Description | Example |
|--------|-------------|---------|
| `:shape(type, spriteId?)` | Set shape: "circle", "rect", "line", "sprite" | `:shape("circle")` |
| `:size(min, max?)` | Size or random range | `:size(4, 8)` |
| `:color(start, end?)` | Color or gradient | `:color("orange", "red")` |
| `:lifespan(min, max?)` | Lifetime in seconds | `:lifespan(0.3, 0.5)` |
| `:velocity(min, max?)` | Speed in pixels/sec | `:velocity(50, 100)` |
| `:gravity(strength)` | Gravity (positive = down) | `:gravity(200)` |
| `:drag(factor)` | Velocity damping per frame | `:drag(0.95)` |
| `:fade()` | Alpha fades to 0 | `:fade()` |
| `:fadeIn(pct)` | Fade in then out | `:fadeIn(0.3)` |
| `:shrink()` | Scale shrinks to 0 | `:shrink()` |
| `:grow(start, end)` | Scale interpolation | `:grow(0.5, 2.0)` |
| `:spin(min, max?)` | Rotation speed (deg/sec) | `:spin(90, 180)` |
| `:wiggle(amount, freq?)` | Lateral oscillation | `:wiggle(10, 5)` |
| `:stretch()` | Velocity-based stretching | `:stretch()` |
| `:bounce(restitution, groundY?)` | Bounce off ground | `:bounce(0.8, 400)` |
| `:homing(strength, target?)` | Seek toward target | `:homing(0.5, targetEntity)` |
| `:trail(recipe, rate)` | Spawn trail particles | `:trail(trailRecipe, 0.05)` |
| `:flash(...)` | Cycle through colors | `:flash("red", "yellow", "white")` |
| `:z(order)` | Draw order | `:z(100)` |
| `:space(name)` | "world" or "screen" | `:space("world")` |
| `:shaders(list)` | Apply shaders | `:shaders({"glow"})` |
| `:drawCommand(fn)` | Custom draw function | `:drawCommand(myDrawFn)` |

*— from core/particles.lua:56-386*

***

### Emission Methods

\label{recipe:particle-emission}

**When to use:** Configure where and how particles spawn.

```lua
local spark = Particles.define():shape("circle"):size(4):fade():lifespan(0.3)

-- Spawn at point
spark:burst(10):at(100, 200)

-- Spawn within circle (uniform distribution)
spark:burst(20):inCircle(centerX, centerY, radius)

-- Spawn within rectangle
spark:burst(15):inRect(x, y, width, height)

-- Spawn from origin toward target
spark:burst(10):from(startX, startY):toward(targetX, targetY)

-- Control direction
spark:burst(10)
    :angle(0, 360)            -- random angle range
    :spread(30)               -- ±30 degrees from base
    :outward()                -- point away from center
    :at(x, y)

-- Per-particle customization
spark:burst(10)
    :override({ velocity = 200 })        -- override recipe defaults
    :each(function(i, total)             -- per-particle overrides
        return { size = 4 + i * 2 }      -- size increases per particle
    end)
    :at(x, y)
```

*— from core/particles.lua:392-498*

**Gotcha:** `:at()`, `:inCircle()`, `:inRect()`, and `:toward()` trigger immediate spawn.

**Gotcha:** `:outward()` and `:inward()` require a spawn center (from `:inCircle()` or similar).

***

### Streaming Particles

\label{recipe:particle-stream}

**When to use:** Continuous particle emission over time.

```lua
local spark = Particles.define()
    :shape("circle")
    :size(2, 4)
    :velocity(50, 100)
    :fade()
    :lifespan(0.5)

-- Create streaming emission
local stream = spark:burst(3)
    :at(x, y)
    :stream()
    :every(0.1)               -- emit every 0.1 seconds
    :for_(2.0)                -- total duration (nil = infinite)
    :times(20)                -- max spawn count (nil = infinite)
    :attachTo(entity)         -- stop when entity destroyed

-- Update in game loop
function update(dt)
    stream:update(dt)
end

-- Manual control
stream:stop()                 -- stop emission
stream:isActive()             -- check if still running
```

*— from core/particles.lua:906-1063*

**Gotcha:** Call `:update(dt)` every frame to manage stream timing.

**Gotcha:** Stream stops automatically when duration, times, or attached entity is exhausted.

***

### Mixed Emissions

\label{recipe:particle-mix}

**When to use:** Combine multiple particle types in one emission (fire + smoke, sparks + debris).

```lua
local fire = Particles.define():shape("circle"):size(4,8):color("orange"):fade()
local smoke = Particles.define():shape("circle"):size(8,16):color("gray"):fade()

-- Mix with per-recipe counts
Particles.mix({ fire, smoke })
    :burst(10, 5)             -- 10 fire, 5 smoke per emission
    :spread(45)               -- apply to all
    :outward()
    :inCircle(x, y, 20)

-- Stream mixed particles
local fireStream = Particles.mix({ fire, smoke })
    :burst(3, 2)
    :at(x, y)
    :stream()
    :every(0.1)

function update(dt)
    fireStream:update(dt)
end
```

*— from core/particles.lua:1066-1278*

**Gotcha:** `:burst(...)` takes per-recipe counts in order, or single count for uniform distribution.

***

### Shader Particles

\label{recipe:particle-shaders}

**When to use:** Apply shader effects to individual particles.

```lua
local glowParticle = Particles.define()
    :shape("circle")
    :size(8, 16)
    :color("cyan")
    :fade()
    :lifespan(0.5)
    :shaders({ "glow_fragment" })
    :shaderUniforms({ glow_fragment = { glow_intensity = 2.0 } })

glowParticle:burst(5):at(x, y)
```

*— from core/particles.lua:351-365, 1282-1314*

**Gotcha:** Shader particles use entity-based rendering (more expensive but supports effects).

**Gotcha:** Particles with shaders get `ShaderParticleTag` to prevent double-rendering.

***

### Callbacks

\label{recipe:particle-callbacks}

**When to use:** React to particle lifecycle events.

```lua
local spark = Particles.define()
    :shape("circle")
    :size(4)
    :fade()
    :lifespan(0.5)
    :onSpawn(function(particle, entity)
        print("Particle spawned:", entity)
    end)
    :onUpdate(function(particle, dt, entity)
        -- Custom per-frame logic
    end)
    :onDeath(function(particle, entity)
        print("Particle died")
    end)

spark:burst(1):at(x, y)
```

*— from core/particles.lua:311-333*

**Gotcha:** Callbacks are optional. They're only called if the recipe has enhanced features.

**Gotcha:** `onUpdate` receives delta time; use for custom physics or visual effects.

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

***

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

***

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

***

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

***

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

***

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

***

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

***

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

***

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

***

## Tooltip Registry (Reusable Templates)

\label{recipe:tooltip-registry}

**When to use:** Define tooltip templates once and attach them to entities by name, with parameterized content.

**Pattern:** Register templates with `{param}` placeholders, attach to entities for automatic hover behavior.

```lua
local tooltips = require("core.tooltip_registry")

-- 1. Register a tooltip template (usually at startup)
tooltips.register("fire_damage", {
    title = "Fire Damage",
    body = "Deals {damage|red} fire damage to the target"
})

-- 2. Attach to entity (shows on hover automatically)
tooltips.attachToEntity(enemy, "fire_damage", { damage = 25 })

-- 3. Programmatic show/hide (optional)
tooltips.showFor(enemy)
tooltips.hide()

-- 4. Cleanup when entity is destroyed
tooltips.detachFromEntity(enemy)
```

*— from core/tooltip_registry.lua:93-171*

**Template Syntax:**

| Syntax | Description | Example |
|--------|-------------|---------|
| `{param}` | Simple substitution | `"Deals {damage} damage"` → `"Deals 25 damage"` |
| `{param\|color}` | Substitution with color | `"Deals {damage\|red} damage"` → `"Deals [25](color=red) damage"` |

**API Reference:**

| Function | Parameters | Description |
|----------|------------|-------------|
| `tooltips.register(name, def)` | name: string, def: { title, body, opts? } | Register a named template |
| `tooltips.isRegistered(name)` | name: string | Check if template exists |
| `tooltips.attachToEntity(entity, name, params?)` | entity, tooltipName, params table | Attach tooltip with params |
| `tooltips.detachFromEntity(entity)` | entity | Remove tooltip attachment |
| `tooltips.showFor(entity)` | entity | Manually show attached tooltip |
| `tooltips.hide()` | - | Hide current tooltip |
| `tooltips.getActiveTooltip()` | - | Get current tooltip entity ID |
| `tooltips.clearAll()` | - | Detach all tooltips and hide |

**Real usage example:**

```lua
-- At game startup, register all tooltip templates
local tooltips = require("core.tooltip_registry")

tooltips.register("enemy_stats", {
    title = "{name}",
    body = "HP: {hp|red}\nDamage: {damage|gold}"
})

tooltips.register("item_pickup", {
    title = "{item_name|gold}",
    body = "{description}"
})

-- When spawning enemies
function spawnEnemy(def)
    local entity = EntityBuilder.create({
        sprite = def.sprite,
        position = { x = def.x, y = def.y }
    })

    tooltips.attachToEntity(entity, "enemy_stats", {
        name = def.name,
        hp = def.hp,
        damage = def.damage
    })

    return entity
end
```

**How it works:**

1. `register()` stores template definitions by name
2. `attachToEntity()` wraps the entity's hover handlers
3. On hover, template is interpolated with params and shown via `showSimpleTooltipAbove()`
4. On stop hover, tooltip is hidden via `hideSimpleTooltip()`

**Gotcha:** Original hover handlers are preserved and called before showing the tooltip.

**Gotcha:** Templates are cached by name + params for efficient reuse.

**Gotcha:** Call `tooltips.clearAll()` when resetting the game to prevent stale attachments.

***

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

***

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

***

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

***

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

***

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

***

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

***

## Tabs UI (Tabbed Panels)

\label{recipe:tabs-ui}

**When to use:** Create tabbed interfaces where users switch between content panels (e.g., inventory tabs, settings categories, stats panels).

```lua
local dsl = require("ui.ui_syntax_sugar")

-- Basic tabs
local tabsUI = dsl.tabs {
    id = "inventory_tabs",
    tabs = {
        {
            id = "weapons",
            label = "Weapons",
            content = function()
                return dsl.vbox {
                    children = {
                        dsl.text("Sword of Fire"),
                        dsl.text("Ice Dagger"),
                    }
                }
            end
        },
        {
            id = "armor",
            label = "Armor",
            content = function()
                return dsl.vbox {
                    children = {
                        dsl.text("Steel Plate"),
                        dsl.text("Leather Boots"),
                    }
                }
            end
        },
        {
            id = "items",
            label = "Items",
            content = function()
                return dsl.text("Health Potion x3")
            end
        }
    }
}

-- Spawn the tabs UI
local boxID = dsl.spawn({ x = 100, y = 100 }, tabsUI, "ui", 900)
```

*— from ui/ui_syntax_sugar.lua:tabs*

### Tab Definition Structure

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique tab identifier |
| `label` | string | Button text shown to user |
| `content` | function | Returns DSL definition for tab content |

### Options

```lua
dsl.tabs {
    id = "my_tabs",           -- Container ID for cleanup/state
    activeTab = "second",     -- Start with specific tab active (default: first)
    tabs = { ... }
}
```

### Programmatic Control

```lua
-- Get active tab ID
local activeId = dsl.getActiveTab("inventory_tabs")

-- Switch to a tab programmatically
dsl.setActiveTab("inventory_tabs", "armor")

-- Cleanup when done
dsl.cleanupTabs("inventory_tabs")
```

### Visual Structure

```
┌─────────────────────────────────────────┐
│ [Weapons] [Armor] [Items]               │  ← Tab buttons (horizontal)
├─────────────────────────────────────────┤
│                                         │
│   Content for selected tab appears      │  ← Content area
│   here and switches when tabs clicked   │
│                                         │
└─────────────────────────────────────────┘
```

**Gotcha:** The `content` field must be a function that returns a DSL definition, not a raw definition. This allows lazy evaluation when switching tabs.

**Gotcha:** Tab switching uses ReplaceChildren internally for efficient DOM-style updates without recreating the entire UI.

**Gotcha:** Call `dsl.cleanupTabs(id)` when destroying the UI to clean up internal state tracking.

***

## Styled Localization

\label{recipe:styled-localization}

**When to use:** Create color-coded text in tooltips and UI using localization keys.

**Pattern:** Define templates in JSON with `{param|color}` syntax, then substitute values via `localization.getStyled()`.

### JSON Template Syntax

```json
{
  "tooltip": {
    "attack_desc": "Deal {damage|red} {element|fire} damage"
  }
}
```

### Lua Usage

```lua
-- Uses JSON default colors
local text = localization.getStyled("tooltip.attack_desc", {
    damage = 25,
    element = "Fire"
})
-- Result: "Deal [25](color=red) [Fire](color=fire) damage"

-- Override color at runtime
local text = localization.getStyled("tooltip.attack_desc", {
    damage = { value = 25, color = "gold" }
})
-- Result: "Deal [25](color=gold) [Fire](color=fire) damage"
```

*— from core/localization_styled.lua:15-54*

**Named Colors:**

| Color Name | Hex | Usage |
|------------|-----|-------|
| `red` | #FF5555 | Damage, danger |
| `gold` | #FFD700 | Legendary, currency |
| `green` | #55FF55 | Healing, success |
| `blue` | #5555FF | Mana, water |
| `cyan` | #55FFFF | Info, ice |
| `purple` | #AA55FF | Rare, arcane |
| `fire` | #FF6622 | Fire damage |
| `ice` | #88CCFF | Ice damage |
| `poison` | #88FF44 | Poison damage |
| `holy` | #FFFFAA | Holy damage |
| `void` | #AA44FF | Void damage |
| `electric` | #FFFF44 | Lightning |

**Gotcha:** If a parameter is missing, the placeholder `{param|color}` is preserved in output.

**Gotcha:** Color names must match the palette in `util.getColor()`. Unknown colors fall back to white.

***

## Localized Tooltips

\label{recipe:localized-tooltip}

**When to use:** Create tooltips with color-coded text from localization keys.

**Pattern:** `makeLocalizedTooltip()` combines styled localization with tooltip rendering.

```lua
-- Basic usage
local boxID = makeLocalizedTooltip("tooltip.attack_desc", {
    damage = card.damage,
    element = card.element
}, {
    title = card.name  -- Optional title
})

-- With style overrides
local boxID = makeLocalizedTooltip("tooltip.card_stats", {
    damage = { value = 50, color = "gold" },  -- Override default color
    cost = card.mana_cost
}, {
    title = "Card Details",
    maxWidth = 400,
    bodyFontSize = 14
})
```

*— from core/gameplay.lua:584-601*

**Options:**

| Option | Type | Description |
|--------|------|-------------|
| `title` | string | Tooltip header text |
| `maxWidth` | number | Max width in pixels (default: 320) |
| `bodyColor` | Color | Override body text color |
| `bodyFont` | Font | Override body font |
| `bodyFontSize` | number | Override font size |

**Gotcha:** The `bodyCoded = true` is set internally, enabling `[text](effects)` parsing.

**Gotcha:** Returns the tooltip box entity ID for positioning/lifecycle management.

**Real usage example:**

```lua
-- From card hover handler
local tooltip = makeLocalizedTooltip("card.desc." .. card.id, {
    damage = card.base_damage * damageMultiplier,
    cost = card.mana_cost,
    duration = card.effect_duration
}, { title = localization.get("card.name." .. card.id) })

-- Position above the card
showSimpleTooltipAbove(cardEntity, tooltip)
```

***

## TooltipV2: 3-Box Card Tooltip System

\label{recipe:tooltip-v2}

**When to use:** Display rich, structured card tooltips with rarity effects, stats, and tags using the new 3-box vertical stack design.

**Pattern:** TooltipV2 uses a 3-box architecture: name box (with effects), description box (with color markup), and info box (stats grid + tag pills).

```lua
local TooltipV2 = require("ui.tooltip_v2")

-- Show tooltip for any entity
TooltipV2.show(anchorEntity, {
    name = "Fireball",
    nameEffects = "pop=0.2,0.04,in;rainbow=40,8,0",  -- Optional: C++ text effects
    description = "Deal [25](color=red) fire damage to target enemy",
    info = {
        stats = {
            { label = "Damage", value = 25 },
            { label = "Mana", value = 12 },
        },
        tags = { "Fire", "Projectile", "AoE" }
    }
})

-- Hide tooltip
TooltipV2.hide(anchorEntity)

-- Card-specific helper (auto-applies rarity-based effects)
TooltipV2.showCard(anchorEntity, cardDef)
```

*— from ui/tooltip_v2.lua:1-300*

### Visual Structure

```
┌─────────────────────────┐
│       CARD NAME         │  ← Box 1: Name (larger font + pop entrance)
└─────────────────────────┘
           4px gap
┌─────────────────────────┐
│   Effect description    │  ← Box 2: Description (supports [text](color) markup)
│   text goes here...     │
└─────────────────────────┘
           4px gap
┌─────────────────────────┐
│ Damage: 25    Mana: 12  │  ← Box 3: Info (stats grid + tag pills)
│ [Fire] [Projectile]     │
└─────────────────────────┘
```

### Positioning

TooltipV2 auto-positions with priority order: RIGHT → LEFT → ABOVE → BELOW

- Never covers anchor entity
- Top-aligns with anchor, shifts down if clipping
- 12px minimum edge gap

### API Reference

| Function | Parameters | Description |
|----------|------------|-------------|
| `TooltipV2.show(entity, opts)` | entity, options table | Show tooltip attached to entity |
| `TooltipV2.hide(entity)` | entity | Hide tooltip for entity |
| `TooltipV2.showCard(entity, cardDef)` | entity, card definition | Show with auto rarity effects |
| `TooltipV2.clearCache()` | - | Clear all cached tooltips |

**Gotcha:** TooltipV2 is enabled when `USE_TOOLTIP_V2 = true` is set in gameplay.lua.

**Gotcha:** The tooltip_registry module automatically uses TooltipV2 when enabled.

***

## Tooltip Effects: Rarity-Based Text Effects

\label{recipe:tooltip-effects}

**When to use:** Apply entrance animations and persistent effects to tooltip text based on content type or rarity.

**Pattern:** Use predefined presets or build custom effect combinations for styled text.

```lua
local TooltipEffects = require("core.tooltip_effects")

-- Get effect string for a rarity
local effects = TooltipEffects.get("legendary")
-- Result: "pop=0.25,0.04,in;rainbow=50,6,0;pulse=0.93,1.07,1.2,0.05"

-- Get rarity color
local color = TooltipEffects.getColor("legendary")
-- Result: "gold"

-- Build styled text for C++ text system
local styledText = TooltipEffects.styledText("Fireball", "legendary")
-- Result: "[Fireball](pop=0.25,0.04,in;rainbow=50,6,0;pulse=0.93,1.07,1.2,0.05;color=gold)"

-- Combine multiple effects
local combined = TooltipEffects.combine("pop_in", "gentle_float")
-- Result: "pop=0.2,0.05,in;float=2,3,0.2"
```

*— from core/tooltip_effects.lua:1-112*

### Effect Presets by Rarity

| Rarity | Effects | Description |
|--------|---------|-------------|
| `common` | `pop=0.15,0.02,in` | Simple pop entrance |
| `uncommon` | `pop=0.18,0.025,in;highlight=3,0.15,0.2,right` | Pop + subtle shimmer |
| `rare` | `pop=0.2,0.03,in;highlight=2.5,0.25,0.15,right,bleed;pulse=0.97,1.03,2,0.08` | Pop + highlight + pulse |
| `epic` | `slide=0.22,0.035,in,l;highlight=2,0.35,0.12,right,bleed;pulse=0.95,1.05,1.5,0.06` | Slide + strong effects |
| `legendary` | `pop=0.25,0.04,in;rainbow=50,6,0;pulse=0.93,1.07,1.2,0.05` | Pop + rainbow + pulse |
| `mythic` | `scramble=0.25,0.03,12;rainbow=80,8,0;pulse=0.9,1.1,1,0.04;wiggle=4,2,0.3` | Full chaos effects |

### Rarity Colors

| Rarity | Color | Hex |
|--------|-------|-----|
| common | white | #FFFFFF |
| uncommon | lime | #00FF00 |
| rare | cyan | #00FFFF |
| epic | purple | #AA00FF |
| legendary | gold | #FFD700 |
| mythic | magenta | #FF00FF |

### Available Effect Types

**Entrance Effects** (one-time animations):
- `pop_in` - Scale up entrance
- `slide_left`, `slide_right`, `slide_up` - Directional slides
- `bounce` - Bounce entrance
- `scramble` - Character scramble reveal

**Persistent Effects** (continuous animations):
- `gentle_float` - Subtle floating motion
- `pulse` - Size pulsing
- `wiggle` - Side-to-side wiggle
- `rainbow` - Color cycling
- `highlight`, `shimmer` - Moving highlight

**Gotcha:** Effect strings are passed to the C++ text rendering system. Invalid effects are ignored.

**Gotcha:** Use `TooltipEffects.combine()` to merge multiple effects into a single string.

***

## Modal Dialogs

\label{recipe:modal}

**When to use:** Show alerts, confirmations, or custom dialogs that overlay the game.

```lua
local modal = require("core.modal")

-- Simple alert (one OK button)
modal.alert("Something happened!")
modal.alert("Error!", { title = "Warning", color = "red" })

-- Confirm dialog (two buttons)
modal.confirm("Are you sure?", {
    onConfirm = function() doThing() end,
    onCancel = function() print("cancelled") end,
    confirmText = "Yes",
    cancelText = "No"
})

-- Custom content modal
modal.show({
    title = "Custom Modal",
    width = 600,
    height = 400,
    content = function(dsl)
        return dsl.vbox {
            children = {
                dsl.text("Line 1"),
                dsl.text("Line 2")
            }
        }
    end,
    buttons = {
        { text = "Action", color = "blue", action = function() end },
        { text = "Close" }
    }
})

-- Close current modal
modal.close()

-- Check if modal is open
if modal.isOpen() then ... end
```

*— from core/modal.lua:1-505*

**API Reference:**

| Function | Description |
|----------|-------------|
| `modal.alert(message, opts?)` | Simple alert with OK button |
| `modal.confirm(message, opts)` | Confirm/Cancel dialog |
| `modal.show(config)` | Custom modal with full config |
| `modal.close()` | Close current modal |
| `modal.isOpen()` | Check if a modal is open |
| `modal.update(dt)` | Call from game loop for ESC handling |
| `modal.draw(dt)` | Call from game loop for backdrop rendering |

**Alert/Confirm Options:**

| Option | Type | Description |
|--------|------|-------------|
| `title` | string | Modal title |
| `color` | string | Background color |
| `onClose` | function | Callback when closed |
| `onConfirm` | function | Callback on confirm (confirm only) |
| `onCancel` | function | Callback on cancel (confirm only) |
| `confirmText` | string | Confirm button text (default: "OK") |
| `cancelText` | string | Cancel button text (default: "Cancel") |

**Show Config:**

| Option | Type | Description |
|--------|------|-------------|
| `title` | string | Modal title |
| `width` | number | Modal width (default: 400) |
| `height` | number | Modal height (default: 250) |
| `color` | string | Background color |
| `content` | function/table | Content builder function or DSL table |
| `buttons` | table | Array of button definitions |
| `onClose` | function | Callback when closed |

**Button Definition:**

```lua
{ text = "Action", color = "blue", action = function() end, closeOnClick = true }
```

**Gotcha:** Only one modal can be open at a time. Opening a new modal closes the previous one.

**Gotcha:** ESC key and backdrop click close the modal. Use `_type = "confirm"` in config to disable backdrop dismiss.

**Gotcha:** Call `modal.update(dt)` and `modal.draw(dt)` from your game loop for full functionality.

***

## Inventory Grid

\label{recipe:inventory-grid}

**When to use:** Create grid-based inventories for items, cards, or equipment.

```lua
local grid = require("core.inventory_grid")

-- After creating grid with dsl.inventoryGrid():

-- Get dimensions
local rows, cols = grid.getDimensions(gridEntity)
local capacity = grid.getCapacity(gridEntity)

-- Item access
local item = grid.getItemAtIndex(gridEntity, slotIndex)  -- By slot (1-based)
local item = grid.getItemAt(gridEntity, row, col)        -- By row/col (1-based)
local items = grid.getAllItems(gridEntity)               -- { [slotIndex] = item }

-- Slot access
local slotEntity = grid.getSlotEntity(gridEntity, slotIndex)
local usedCount = grid.getUsedSlotCount(gridEntity)
local emptyCount = grid.getEmptySlotCount(gridEntity)

-- Find operations
local slotIndex = grid.findSlotContaining(gridEntity, itemEntity)
local slotIndex = grid.findEmptySlot(gridEntity)

-- Item operations (emit events)
local success, slot, action = grid.addItem(gridEntity, itemEntity, slotIndex?)
local item = grid.removeItem(gridEntity, slotIndex)
local success = grid.moveItem(gridEntity, fromSlot, toSlot)
local success = grid.swapItems(gridEntity, slot1, slot2)

-- Stack operations (for stackable grids)
local count = grid.getStackCount(gridEntity, slotIndex)
local success = grid.addToStack(gridEntity, slotIndex, amount)
local success, transferred = grid.mergeStacks(gridEntity, fromSlot, toSlot)

-- Slot state
grid.setSlotLocked(gridEntity, slotIndex, true)
local canAccept = grid.canSlotAccept(gridEntity, slotIndex, itemEntity)

-- Cleanup
grid.cleanup(gridEntity)  -- Call when destroying grid
```

*— from core/inventory_grid.lua:1-590*

**Events (via hump.signal):**

| Event | Parameters | Description |
|-------|------------|-------------|
| `"grid_item_added"` | gridEntity, slotIndex, itemEntity | Item placed in slot |
| `"grid_item_removed"` | gridEntity, slotIndex, itemEntity | Item removed from slot |
| `"grid_item_moved"` | gridEntity, fromSlot, toSlot, itemEntity | Item moved within grid |
| `"grid_items_swapped"` | gridEntity, slot1, slot2, item1, item2 | Two items swapped |
| `"grid_stack_changed"` | gridEntity, slotIndex, itemEntity, oldCount, newCount | Stack count changed |
| `"grid_stack_split"` | gridEntity, slotIndex, amount, newItemEntity | Stack was split |

**Listening to Events:**

```lua
local signal = require("external.hump.signal")

signal.register("grid_item_added", function(gridEntity, slotIndex, itemEntity)
    print("Item added to slot", slotIndex)
end)

signal.register("grid_items_swapped", function(gridEntity, s1, s2, item1, item2)
    print("Swapped items between slots", s1, "and", s2)
end)
```

**Grid Configuration (via DSL):**

```lua
local dsl = require("ui.ui_syntax_sugar")

local gridDef = dsl.inventoryGrid {
    rows = 3,
    cols = 4,
    slotSize = 64,
    spacing = 4,
    stackable = true,       -- Enable stacking
    maxStackSize = 99,      -- Max items per stack
    filter = function(item, slotIndex)
        -- Return true if item can be placed in slot
        return true
    end,
    onSlotClick = function(gridEntity, slotIndex, item)
        print("Clicked slot", slotIndex)
    end
}
```

**Slot-Specific Configuration:**

```lua
-- Configure individual slots
local slots = {
    [1] = { locked = true },                    -- Locked slot
    [5] = { filter = function(item) return item.type == "weapon" end },
    [10] = { background = "slot_special.png" }  -- Custom background
}

dsl.inventoryGrid {
    rows = 2, cols = 5,
    slots = slots
}
```

**Gotcha:** Slot indices are 1-based and sequential (1 to rows*cols).

**Gotcha:** `addItem` without slotIndex auto-finds first empty slot.

**Gotcha:** Stack operations require `stackable = true` in grid config.

**Gotcha:** Call `grid.cleanup(gridEntity)` when destroying the grid to free internal data.

\newpage

# Combat & Projectiles

This chapter covers the projectile system, enemy behavior composition, and combat mechanics.

## Enemy Behavior Library (Declarative Composition)

\label{recipe:enemy-behaviors}

**When to use:** Define enemy AI behaviors declaratively instead of writing repetitive timer-based code.

**Pattern:** Define behaviors as arrays in enemy data, library handles timers and cleanup automatically.

### Defining Enemies with Behaviors

```lua
-- In data/enemies.lua
enemies.goblin = {
    sprite = "enemy_type_1.png",
    hp = 30, speed = 60, damage = 5,
    size = { 32, 32 },

    behaviors = {
        "chase",  -- Simple: uses ctx.speed, default interval
    },
}

enemies.dasher = {
    sprite = "enemy_type_1.png",
    hp = 25, speed = 50, dash_speed = 300, dash_cooldown = 3.0,

    behaviors = {
        "wander",
        { "dash", cooldown = "dash_cooldown", speed = "dash_speed" },
    },
}

enemies.summoner = {
    sprite = "enemy_type_2.png",
    hp = 40, speed = 30, summon_cooldown = 5.0,

    behaviors = {
        { "summon", cooldown = "summon_cooldown" },
        "flee",
    },
}
```

*— from core/behaviors.lua:8-29*

### Built-in Behaviors

| Behavior | Default Config | Description |
|----------|----------------|-------------|
| `"chase"` | interval=0.5, speed=ctx.speed | Move toward player |
| `"wander"` | interval=0.5, speed=ctx.speed | Random movement |
| `"flee"` | interval=0.5, distance=150 | Move away from player |
| `"kite"` | interval=0.5, range=ctx.range | Maintain distance (ranged) |
| `"dash"` | cooldown=ctx.dash_cooldown | Periodic dash attack |
| `"trap"` | cooldown=ctx.trap_cooldown | Drop hazards |
| `"summon"` | cooldown=ctx.summon_cooldown | Spawn minions |
| `"rush"` | interval=0.3 | Fast chase (aggressive) |

### Config Value Resolution

Config values can reference enemy context fields:

```lua
behaviors = {
    -- String value = lookup from ctx
    { "dash", speed = "dash_speed" },  -- Uses ctx.dash_speed

    -- Number value = use directly
    { "chase", interval = 0.3 },       -- 0.3 second interval

    -- Function value = computed
    { "flee", distance = function(ctx) return ctx.hp * 2 end },
}
```

*— from core/behaviors.lua:75-89*

### Registering Custom Behaviors

```lua
local behaviors = require("core.behaviors")

behaviors.register("teleport", {
    -- Default config values
    defaults = {
        interval = 5.0,
        range = 100
    },

    -- Called once when behavior starts
    on_start = function(e, ctx, helpers, config)
        print("Teleport behavior started for", e)
    end,

    -- Called each interval (timer-based)
    on_tick = function(e, ctx, helpers, config)
        local angle = math.random() * math.pi * 2
        local dx = math.cos(angle) * config.range
        local dy = math.sin(angle) * config.range
        helpers.teleport(e, dx, dy)
    end,

    -- Called when behavior stops
    on_stop = function(e, ctx, helpers, config)
        print("Teleport behavior stopped")
    end,
})
```

*— from core/behaviors.lua:122-148*

### API Reference

| Function | Parameters | Description |
|----------|------------|-------------|
| `behaviors.register(name, def)` | name: string, def: table | Register a named behavior |
| `behaviors.is_registered(name)` | name: string | Check if behavior exists |
| `behaviors.list()` | - | Get all registered behavior names |
| `behaviors.apply(e, ctx, helpers, list)` | entity, context, helpers, behavior_list | Apply behaviors to entity |
| `behaviors.cleanup(e)` | entity | Stop all behaviors for entity |

### Behavior Definition Structure

```lua
{
    -- Default config values (optional)
    defaults = {
        interval = 0.5,    -- Timer interval in seconds
        speed = "speed",   -- String = lookup from ctx
    },

    -- Called once when behavior starts (optional)
    on_start = function(e, ctx, helpers, config) end,

    -- Called each interval (required for timer-based behaviors)
    on_tick = function(e, ctx, helpers, config) end,

    -- Called when behavior stops (optional)
    on_stop = function(e, ctx, helpers, config) end,
}
```

**Auto-Cleanup:**

- All behavior timers are tagged with entity ID
- `behaviors.cleanup(e)` cancels all timers for that entity
- Call cleanup when entity is destroyed to prevent memory leaks

**Real usage example:**

```lua
-- In EnemyFactory.spawn()
local behaviors = require("core.behaviors")

function EnemyFactory.spawn(def, x, y)
    local entity, script = EntityBuilder.create({
        sprite = def.sprite,
        position = { x = x, y = y },
        data = { hp = def.hp, speed = def.speed, damage = def.damage }
    })

    -- Build context from enemy definition
    local ctx = {
        speed = def.speed,
        dash_speed = def.dash_speed,
        dash_cooldown = def.dash_cooldown,
        -- ... other properties
    }

    -- Apply behaviors
    if def.behaviors then
        behaviors.apply(entity, ctx, wave_helpers, def.behaviors)
    end

    -- Cleanup on death
    signal.register("entity_destroyed", function(eid)
        if eid == entity then
            behaviors.cleanup(entity)
        end
    end)

    return entity
end
```

**Gotcha:** Behavior names must match registered behaviors exactly. Use `behaviors.list()` to see available behaviors.

**Gotcha:** Config strings that match ctx field names are auto-resolved. Use literal strings with different names to avoid accidental resolution.

**Gotcha:** The `helpers` object provides utility functions like `move_toward_player`, `teleport`, etc. These are passed from the wave system.

***

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

***

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

***

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

***

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

***

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

***

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

***

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

***

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

***

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

***

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

***

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

***

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

***

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

***

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

**Gotcha:** `id` must exactly match the table key (`Cards.MY_LIGHTNING_BOLT` -> `id = "MY_LIGHTNING_BOLT"`).

**Gotcha:** `test_label` uses `\n` for line breaks in UI, not actual newlines.

**Gotcha:** `radius_of_effect = 0` means single-target; any value > 0 creates AoE explosion.

***

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

***

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

**Gotcha:** Trigger cards split the wand into blocks: [before trigger] -> [after trigger fires].

**Gotcha:** Actions after a trigger execute at the trigger position, not cast position.

**Gotcha:** Multiple triggers can chain: timer -> hit -> death creates 3 sub-casts.

***

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

***

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

***

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

***

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

**Gotcha:** Cards execute in order: modifiers -> action -> trigger -> [trigger payload].

**Gotcha:** `triggerType` parameter should match the wand's trigger type for debugging.

***

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

***

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

**Gotcha:** Tags are normalized: `"fire"` -> `"Fire"`, `" Lightning "` -> `"Lightning"`.

**Gotcha:** Invalid tags (nil, empty string) are skipped, not errored.

**Gotcha:** `count_tags()` only counts cards that exist in card registry.

***

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

***

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

***

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

**Gotcha:** Single-action casts check multicast -> speed/damage -> delay.

**Gotcha:** Multi-action casts check element tags -> type diversity -> cost/damage.

***

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

***

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

***

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

***

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

***

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

***

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

***

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

***

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

***

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

***

## AI System Flow

\label{recipe:ai-system-flow}

**When to use:** Understand how the AI system executes each frame.

**Frame-by-frame execution:**

1. **Worldstate updaters** run (update worldstate from blackboard/sensory data)
2. **Goal selector** runs (choose current goal based on worldstate)
3. **GOAP planner** finds action sequence to reach goal (if needed)
4. **Current action** `update()` runs (executes behavior, returns SUCCESS/RUNNING/FAILURE)
5. **Action completes** -> postconditions applied to worldstate -> next action starts
6. **Worldstate change detected** (if action has `watch` list) -> abort current action -> replan

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
  - GOAP planner has no more actions -> goal reached

Frame 52:
  - worldstate_updaters.can_dig_for_gold() sets candigforgold=false (cooldown active)
  - goal_selector sets goal { wander = true } (fallback to IDLE)
  - GOAP planner finds action "wander"
  - Action "wander" start() called
```

**Gotcha:** If worldstate changes mid-action (e.g., `hungry` becomes true while digging), action is aborted and replanned.

**Gotcha:** Actions with `watch = "*"` abort on any worldstate change; `watch = { "hungry" }` aborts only if `hungry` changes.

***

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

***

## Card Metadata (Rarity & Tags)

\label{recipe:card-metadata}

**When to use:** Enrich card instances with rarity and tags at runtime without modifying the original card definitions.

```lua
local CardMeta = require("core.card_metadata")

-- Get metadata for a card by ID
local meta = CardMeta.get("ACTION_BASIC_PROJECTILE")
-- Returns: { rarity = "common", tags = {"brute"} }

-- Check if metadata exists
if meta then
    print("Rarity:", meta.rarity)  -- "common", "uncommon", "rare"
    print("Tags:", table.concat(meta.tags, ", "))
end

-- Enrich a card instance with metadata
local enrichedCard = CardMeta.enrich(cardInstance)
-- Adds .rarity and .tags fields to the card

-- Register all cards with the shop system
CardMeta.registerAllWithShop(ShopSystem)
```

*— from core/card_metadata.lua:1-50*

**CardMetadata API:**

| Function | Description |
|----------|-------------|
| `CardMeta.get(cardId)` | Get metadata table `{rarity, tags}` for card ID |
| `CardMeta.enrich(card)` | Add rarity/tags fields to card instance |
| `CardMeta.registerAllWithShop(shop)` | Register all cards with shop system |
| `CardMeta.data` | Raw metadata table (direct access) |

**Rarity values:** `"common"`, `"uncommon"`, `"rare"`

**Gotcha:** This module provides metadata separately from card definitions in `data/cards.lua`. Use it to add rarity/tags without modifying the original data file.

***

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

***

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

***

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

***

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

***

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

***

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

***

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

***

## Define Status Effect

\label{recipe:define-status-effect}

**When to use:** Creating DoTs (damage over time), buffs, debuffs, or detonatable marks.

**Pattern:** Status effects define ongoing effects applied to entities with visual feedback, stacking behavior, and optional particle/shader effects.

**Example:**

```lua
-- In assets/scripts/data/status_effects.lua

local Particles = require("core.particles")

StatusEffects.burning = {
    id = "burning",
    dot_type = true,             -- Is this a DoT effect?
    damage_type = "fire",
    stack_mode = "intensity",    -- replace/time_extend/intensity/count
    max_stacks = 99,
    duration = 5,
    base_dps = 5,
    scaling = "linear",

    -- Visual feedback
    icon = "status-burn.png",
    icon_position = "above",
    icon_offset = { x = 0, y = -12 },
    icon_scale = 0.5,
    icon_bob = true,
    show_stacks = true,

    -- Optional shader
    shader = "fire_overlay",
    shader_uniforms = { intensity = 0.8 },

    -- Particle effect
    particles = function()
        return Particles.define()
            :shape("circle")
            :size(3, 6)
            :color("orange", "red")
            :velocity(20, 40)
            :lifespan(0.2, 0.4)
            :fade()
    end,
    particle_rate = 0.08,
}
```

**Status effect fields:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier |
| `dot_type` | boolean | True for damage-over-time effects |
| `is_mark` | boolean | True for detonatable marks |
| `damage_type` | string | fire/ice/lightning/poison/arcane/holy/void |
| `stack_mode` | string | How stacks interact (see below) |
| `max_stacks` | number | Maximum stack count |
| `duration` | number | Duration in seconds |
| `base_dps` | number | Base damage per second (for DoTs) |
| `scaling` | string | "linear" or "exponential" |
| `icon` | string | Status icon sprite |
| `icon_position` | string | "above" or "below" entity |
| `icon_offset` | table | `{ x, y }` offset from position |
| `icon_scale` | number | Icon scale factor |
| `icon_bob` | boolean | Enable gentle bobbing animation |
| `show_stacks` | boolean | Display stack count on icon |
| `shader` | string | Shader to apply to affected entity |
| `shader_uniforms` | table | Shader uniform values |
| `particles` | function | Returns particle recipe |
| `particle_rate` | number | Seconds between particle emissions |
| `particle_orbit` | boolean | Particles orbit entity |

**Stack modes:**

| Mode | Behavior |
|------|----------|
| `"replace"` | New application replaces existing |
| `"time_extend"` | New application extends duration |
| `"intensity"` | Stacks increase effect power |
| `"count"` | Independent stacks with separate timers |

**Detonatable marks:**

```lua
StatusEffects.static_charge = {
    id = "static_charge",
    is_mark = true,
    duration = 8,
    max_stacks = 5,
    stack_mode = "count",

    -- Detonation trigger
    triggers = "lightning",  -- or "any", "on_damaged", {"fire", "lightning"}

    -- Effect on detonate
    on_detonate = function(ctx, target, stacks)
        local damage = 20 * stacks
        ctx.deal_damage(target, damage, "lightning")
    end,

    icon = "status-static.png",
}
```

**Trigger options for marks:**

- `"lightning"`, `"fire"`, etc.: Damage type triggers detonation
- `"any"`: Any damage triggers detonation
- `"on_damaged"`: Entity taking damage triggers it (defensive)
- `{ "fire", "lightning" }`: Array of damage types
- `function(hit)`: Custom function returning true to detonate

**Provenance:** See `assets/scripts/data/status_effects.lua:22-180` for examples.

**Gotcha:** `dot_type = true` and `is_mark = true` are mutually exclusive.

**Gotcha:** Marks with `triggers = "on_damaged"` are defensive (trigger when target takes damage).

***

## Define Trigger Constants

\label{recipe:define-trigger-constants}

**When to use:** Reference standardized trigger events in equipment, jokers, or custom systems.

**Pattern:** The Triggers module provides categorized constants for all game events.

**Example:**

```lua
-- Using triggers in equipment procs
local Triggers = require("data.triggers")

Equipment.flaming_sword = {
    procs = {
        {
            trigger = Triggers.COMBAT.ON_HIT,
            chance = 30,
            effect = function(ctx, src, ev)
                -- Apply burn on hit
            end,
        },
        {
            trigger = Triggers.COMBAT.ON_KILL,
            effect = function(ctx, src, ev)
                -- Trigger on every kill
            end,
        },
    },
}
```

**Trigger categories:**

**Combat triggers (Triggers.COMBAT):**

| Constant | Value | Description |
|----------|-------|-------------|
| `ON_ATTACK` | "on_attack" | When attack is initiated |
| `ON_HIT` | "on_hit" | When attack connects |
| `ON_KILL` | "on_kill" | When attack kills target |
| `ON_CRIT` | "on_crit" | When attack crits |
| `ON_MISS` | "on_miss" | When attack misses |
| `ON_BASIC_ATTACK` | "on_basic_attack" | Auto-attack only |
| `ON_SPELL_CAST` | "on_spell_cast" | Any spell cast |
| `ON_CHAIN_HIT` | "on_chain_hit" | Chain lightning/pierce hit |
| `ON_PROJECTILE_HIT` | "on_projectile_hit" | Projectile impact |
| `ON_PROJECTILE_SPAWN` | "on_projectile_spawn" | Projectile created |

**Defensive triggers (Triggers.DEFENSIVE):**

| Constant | Value | Description |
|----------|-------|-------------|
| `ON_BEING_ATTACKED` | "on_being_attacked" | When targeted by attack |
| `ON_BEING_HIT` | "on_being_hit" | When damage received |
| `ON_PLAYER_DAMAGED` | "on_player_damaged" | Player takes damage |
| `ON_BLOCK` | "on_block" | Attack blocked |
| `ON_DODGE` | "on_dodge" | Attack dodged |

**Status triggers (Triggers.STATUS):**

| Constant | Value | Description |
|----------|-------|-------------|
| `ON_APPLY_STATUS` | "on_apply_status" | Any status applied |
| `ON_REMOVE_STATUS` | "on_remove_status" | Any status removed |
| `ON_DOT_TICK` | "on_dot_tick" | DoT deals damage |
| `ON_MARK_DETONATED` | "on_mark_detonated" | Mark triggered |
| `ON_APPLY_BURN` | "on_apply_burn" | Burn specifically applied |
| `ON_APPLY_FREEZE` | "on_apply_freeze" | Freeze applied |

**Progression triggers (Triggers.PROGRESSION):**

| Constant | Value | Description |
|----------|-------|-------------|
| `ON_WAVE_START` | "on_wave_start" | Wave begins |
| `ON_WAVE_CLEAR` | "on_wave_clear" | Wave completed |
| `ON_LEVEL_UP` | "on_level_up" | Player levels up |
| `ON_EXPERIENCE_GAINED` | "on_experience_gained" | XP received |

**Resource triggers (Triggers.RESOURCE):**

| Constant | Value | Description |
|----------|-------|-------------|
| `ON_HEAL` | "on_heal" | Healing received |
| `ON_MANA_SPENT` | "on_mana_spent" | Mana consumed |
| `ON_LOW_HEALTH` | "on_low_health" | HP falls below threshold |
| `ON_FULL_HEALTH` | "on_full_health" | HP reaches 100% |

**Provenance:** See `assets/scripts/data/triggers.lua:1-100` for all categories.

**Gotcha:** Use constants instead of string literals to avoid typos and enable refactoring.

***

## Define Equipment

\label{recipe:define-equipment}

**When to use:** Creating weapons, armor, and accessories with stats, proc effects, and damage conversions.

**Pattern:** Equipment defines stat bonuses, proc triggers, and damage type conversions.

**Example:**

```lua
-- In assets/scripts/data/equipment.lua
local Triggers = require("data.triggers")

Equipment.flaming_sword = {
    id = "flaming_sword",
    name = "Flaming Sword",
    slot = "main_hand",      -- main_hand, off_hand, head, chest, gloves, boots, ring, amulet
    rarity = "Rare",

    -- Base stats
    stats = {
        weapon_min = 50,
        weapon_max = 80,
        fire_damage = 20,
        attack_speed = 0.1,  -- +10% attack speed
    },

    -- Attribute requirements
    requires = { attribute = "physique", value = 20, mode = "sole" },

    -- Proc effects (trigger-based abilities)
    procs = {
        {
            trigger = Triggers.COMBAT.ON_HIT,
            chance = 30,  -- 30% chance
            effect = function(ctx, src, ev)
                local StatusEngine = require("combat.combat_system").StatusEngine
                StatusEngine.apply(ctx, ev.target, "burning", {
                    stacks = 3,
                    source = src,
                })
            end,
        },
    },

    -- Damage conversions
    conversions = {
        { from = "physical", to = "fire", pct = 50 },  -- 50% physical → fire
    },
}
```

**Equipment fields:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier |
| `name` | string | Display name |
| `slot` | string | Equipment slot |
| `rarity` | string | Common/Uncommon/Rare/Epic/Legendary |
| `stats` | table | Stat bonuses |
| `requires` | table | Attribute requirements |
| `procs` | table | Trigger-based effects |
| `conversions` | table | Damage type conversions |

**Equipment slots:**

- `main_hand`: Primary weapon
- `off_hand`: Shield or secondary
- `head`: Helmet
- `chest`: Armor
- `gloves`: Gauntlets
- `boots`: Footwear
- `ring`: Ring slot (2 available)
- `amulet`: Necklace

**Common stats:**

| Stat | Description |
|------|-------------|
| `weapon_min`, `weapon_max` | Weapon damage range |
| `fire_damage`, `ice_damage`, etc. | Flat elemental damage |
| `attack_speed` | % bonus attack speed |
| `crit_chance` | % critical chance |
| `crit_damage` | % critical damage multiplier |
| `armor` | Flat armor |
| `hp_bonus` | Flat HP |
| `hp_percent` | % HP bonus |
| `mana_regen` | Mana per second |

**Proc structure:**

```lua
{
    trigger = Triggers.COMBAT.ON_HIT,  -- When to trigger
    chance = 30,                        -- Optional: % chance (omit for 100%)
    cooldown = 2.0,                     -- Optional: seconds between procs
    effect = function(ctx, src, ev)
        -- ctx: combat context
        -- src: entity that equipped this
        -- ev: trigger event data
    end,
}
```

**Damage conversions:**

```lua
conversions = {
    { from = "physical", to = "fire", pct = 50 },   -- 50% converted
    { from = "physical", to = "lightning", pct = 25 },
}
-- Total: 75% physical converted, 25% remains physical
```

**Requirement modes:**

- `"sole"`: Only this attribute counts
- `"primary"`: Must be highest attribute
- `"either"`: One of multiple attributes (use array)

**Provenance:** See `assets/scripts/data/equipment.lua:10-150` for examples.

**Gotcha:** Procs without `chance` field trigger every time.

**Gotcha:** Conversions are calculated before damage bonuses apply.

**Gotcha:** Multiple items can have procs on the same trigger; they all fire independently.

***

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

***

## Schema Validation

\label{recipe:schema-validate}

**When to use:** Validate data tables at load time to catch typos, missing fields, and wrong types.

**Pattern:** The Schema module defines field specs and validates against them.

**Example:**

```lua
local Schema = require("core.schema")

-- Check a card definition (returns errors/warnings)
local ok, errors, warnings = Schema.check(card, Schema.CARD)
if not ok then
    for _, err in ipairs(errors) do
        print(err)  -- "Missing required field: id"
    end
end

-- Validate with automatic error throwing
Schema.validate(card, Schema.CARD, "Card:FIREBALL")
-- Throws error if invalid

-- Validate all items in a table
Schema.validateAll(Cards, Schema.CARD, "Card")
```

*— from core/schema.lua*

**Built-in Schemas:**

| Schema | Required Fields | Description |
|--------|-----------------|-------------|
| `Schema.CARD` | id, type, tags | Card definitions |
| `Schema.JOKER` | id, name, description, rarity | Joker definitions |
| `Schema.PROJECTILE` | id | Projectile presets |
| `Schema.ENEMY` | id | Enemy definitions |

**Field Spec Format:**

```lua
-- How schema fields are defined
field_name = {
    type = "string",      -- "string", "number", "table", "function", "boolean"
    required = true,      -- Field must be present
    enum = { "a", "b" }   -- Optional: value must be one of these
}
```

**API:**

| Function | Description |
|----------|-------------|
| `Schema.check(data, schema)` | Returns `ok, errors, warnings` |
| `Schema.validate(data, schema, name?)` | Throws error if invalid |
| `Schema.validateAll(table, schema, prefix?)` | Validate all items in table |
| `Schema.ENABLED` | Set to `false` to disable (production) |

**Provenance:** See `assets/scripts/core/schema.lua:1-150` for implementation.

**Gotcha:** Warnings are generated for unknown fields (typo detection). Errors are for missing/wrong-type fields.

**Gotcha:** Set `Schema.ENABLED = false` in production to skip validation overhead.

***

## CardFactory DSL

\label{recipe:card-factory}

**When to use:** Defining multiple cards with less boilerplate.

**Pattern:** CardFactory auto-sets id from key, applies type-specific defaults, and generates test_label.

**Example:**

```lua
local CardFactory = require("core.card_factory")

-- Minimal definition (id auto-set from key, defaults applied)
local card = CardFactory.create("FIREBALL", {
    type = "action",
    damage = 25,
    damage_type = "fire",
    tags = { "Fire", "Projectile" },
})
-- card.id = "FIREBALL"
-- card.test_label = "FIREBALL" (auto-generated)

-- Type-specific shortcuts
local proj = CardFactory.projectile("ICE_BOLT", {
    damage = 20,
    tags = { "Ice", "Projectile" },
})

local mod = CardFactory.modifier("DAMAGE_BOOST", {
    damage_modifier = 10,
    tags = { "Buff" },
})

local trig = CardFactory.trigger("ON_HIT_EXPLODE", {
    trigger_on_collision = true,
    tags = { "AoE" },
})
```

*— from core/card_factory.lua*

### Batch Processing

```lua
-- Process multiple cards at once
local Cards = CardFactory.batch({
    FIREBALL = { type = "action", damage = 25, tags = { "Fire" } },
    ICE_BOLT = { type = "action", damage = 20, tags = { "Ice" } },
}, { validate = true })  -- Optional validation
```

### Custom Presets

```lua
-- Register reusable presets
CardFactory.register_presets({
    basic_fire = {
        type = "action",
        damage = 20,
        damage_type = "fire",
        projectile_speed = 350,
        tags = { "Fire", "Projectile" },
    },
})

-- Create from preset with overrides
local card = CardFactory.from_preset("MEGA_FIREBALL", "basic_fire", {
    damage = 50,  -- Override damage
})

-- Extend an existing card
local variant = CardFactory.extend("FIREBALL_PLUS", existingCard, {
    damage = existingCard.damage * 1.5,
})
```

**API:**

| Function | Description |
|----------|-------------|
| `CardFactory.create(id, def, opts?)` | Create card with defaults |
| `CardFactory.projectile(id, def, opts?)` | Create action card |
| `CardFactory.modifier(id, def, opts?)` | Create modifier card |
| `CardFactory.trigger(id, def, opts?)` | Create trigger card |
| `CardFactory.batch(cards, opts?)` | Process multiple cards |
| `CardFactory.register_presets(presets)` | Register reusable base definitions |
| `CardFactory.from_preset(id, preset, overrides?, opts?)` | Create from preset |
| `CardFactory.extend(id, base, overrides, opts?)` | Extend existing card |
| `CardFactory.get_presets()` | Get all registered presets |

**Options:**
- `opts.validate = true`: Run Schema validation after creation

**Provenance:** See `assets/scripts/core/card_factory.lua:1-192` for implementation.

**Gotcha:** `test_label` is auto-generated from ID if not provided (SNAKE_CASE → multi-line).

**Gotcha:** Tags default to empty table `{}` if not provided.

***

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

***

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

## HotReload: Development Module Reloading

\label{recipe:hot-reload}

**When to use:** Reload Lua modules during development without restarting the game.

```lua
local HotReload = require("core.hot_reload")

-- Reload a single module
HotReload.reload("data.cards")  -- Reloads and re-requires

-- Reload all modules matching a pattern
HotReload.reload_pattern("^data%.")   -- All data modules
HotReload.reload_pattern("^ui%.")     -- All UI modules

-- Convenience presets
HotReload.reload_data()    -- All data/*.lua
HotReload.reload_ui()      -- All ui/*.lua
HotReload.reload_combat()  -- All combat/*.lua
HotReload.reload_wand()    -- All wand/*.lua

-- Clear module from cache without reloading
HotReload.clear("data.cards")
HotReload.clear_pattern("^combat%.")
```

*— from core/hot_reload.lua:72-214*

**Protection System:**

Some modules should never be reloaded (those with runtime state):

```lua
-- Check if module is protected
if HotReload.is_protected("core.timer") then
    print("Timer module cannot be reloaded")
end

-- Protect a custom module
HotReload.protect("my_singleton_module")

-- Unprotect (use carefully!)
HotReload.unprotect("my_singleton_module")
```

**Default protected modules:**
- `core.hot_reload` — Self-protection
- `core.main` — Entry point
- `core.component_cache` — Cached references
- `core.entity_cache` — Entity tracking
- `core.timer` — Active timers
- `monobehavior.behavior_script_v2` — Attached scripts

**API Reference:**

| Function | Description |
|----------|-------------|
| `HotReload.reload(path)` | Clear and re-require module |
| `HotReload.clear(path)` | Clear from package.loaded (no re-require) |
| `HotReload.reload_pattern(pattern)` | Reload all modules matching Lua pattern |
| `HotReload.clear_pattern(pattern)` | Clear all modules matching pattern |
| `HotReload.reload_data()` | Reload all data/*.lua |
| `HotReload.reload_ui()` | Reload all ui/*.lua |
| `HotReload.reload_combat()` | Reload all combat/*.lua |
| `HotReload.reload_wand()` | Reload all wand/*.lua |
| `HotReload.protect(path)` | Mark module as non-reloadable |
| `HotReload.unprotect(path)` | Allow module to be reloaded |
| `HotReload.is_protected(path)` | Check if module is protected |

**Gotcha:** Hot-reload is for **development only**. Modules with initialization code or global state may behave unexpectedly after reload.

**Gotcha:** After reloading, existing `local` references in other modules still point to old code. Use `require()` again or access via globals.

**Gotcha:** Protected modules return `false, "Module is protected"` when you try to clear/reload them.

***

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

***

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

***

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

***

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

***

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

-- Tag support (log_info and log_warn only)
log_info("physics", "Body created for entity", eid)
-- Output: "[physics] Body created for entity 42"

log_warn("combat", "Target out of range")
-- Output: "[combat] Target out of range"

-- Tags must be short lowercase strings (<=20 chars, only a-z and _)
-- If first arg doesn't look like a tag, it's treated as a message
log_info("Game started")  -- No tag, logs as "[general] Game started"
```

*— from chugget_code_definitions.lua:385-431 (stubs), C++ bindings in src/systems/scripting/scripting_functions.cpp:1324-1420*

**Gotcha:** Log functions accept varargs but don't auto-format; use `string.format()` for structured output.

**Gotcha:** `log_debug()` may be compiled out in release builds; use `log_info()` for important messages.

**Gotcha:** Tags only work with `log_info()` and `log_warn()`. The tag must be short and lowercase (e.g., "physics", "combat", "ai").

***

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

***

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

***

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

***

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

***

## forma: Not Used

\label{recipe:forma}

**When to use:** Don't use (present in codebase but unused).

The `external/forma` library exists but is not actively used. Stick to lume/knife for functional programming.

***

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

***

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

***

\newpage

# Chapter 11: Game Systems

## Spawn System

\label{recipe:spawn-system}

**When to use:** One-line entity spawning from presets (enemies, projectiles, pickups, effects).

The spawn module provides convenient one-line functions to create entities using data-driven presets. Built on EntityBuilder and PhysicsBuilder, it eliminates boilerplate for common entity types.

**Basic usage:**

```lua
local spawn = require("core.spawn")

-- Spawn enemy at position
local entity, script = spawn.enemy("kobold", 100, 200)

-- Spawn projectile with direction
local projectile = spawn.projectile("fireball", x, y, math.pi/4)

-- Spawn pickup
local pickup = spawn.pickup("exp_orb", x, y)

-- Spawn effect (auto-destroys after lifetime)
local effect = spawn.effect("explosion", x, y)
```

*— from core/spawn.lua, examples/spawn_example.lua*

### Using Overrides

Override preset defaults at spawn time:

```lua
-- Stronger enemy with custom stats
local boss, boss_script = spawn.enemy("kobold", 400, 200, {
    data = {
        health = 200,        -- Override health
        max_health = 200,
        damage = 25,         -- Override damage
        xp_value = 50,
    }
})

-- Projectile with custom owner and damage
local bolt = spawn.projectile("basic_bolt", x, y, direction, {
    owner = playerEntity,
    damage = 50
})

-- Pickup with custom value
local gold = spawn.pickup("gold_coin", x, y, {
    data = { value = 25 }
})
```

*— from examples/spawn_example.lua:41-67*

**Gotcha:** Overrides use deep merge; nested tables are merged, not replaced.

### Generic Spawn Function

All spawn functions delegate to `spawn.from_preset()`:

```lua
-- Generic spawn with category + preset ID
local entity, script = spawn.from_preset(
    "enemies",      -- category: enemies, projectiles, pickups, effects
    "kobold",       -- preset_id within category
    100,            -- x position
    200,            -- y position
    { }             -- overrides (optional)
)
```

*— from core/spawn.lua:169-230*

**When to use:** Custom spawn categories or when building spawn systems.

### Spawn Events

Each spawn function emits events via `signal`:

| Function | Event | Parameters |
|----------|-------|------------|
| `spawn.enemy()` | `"enemy_spawned"` | `entity, { preset_id }` |
| `spawn.projectile()` | `"projectile_spawned"` | `entity, { preset_id, direction, speed, owner }` |
| `spawn.pickup()` | `"pickup_spawned"` | `entity, { preset_id, pickup_type }` |
| `spawn.effect()` | `"effect_spawned"` | `entity, { preset_id, effect_type }` |

*— from core/spawn.lua:243-335*

**Usage:**

```lua
local signal = require("external.hump.signal")

-- React to spawns
signal.register("enemy_spawned", function(entity, data)
    print("Enemy spawned:", data.preset_id)
    add_to_wave_tracker(entity)
end)

signal.register("projectile_spawned", function(entity, data)
    if data.owner == playerEntity then
        increment_shots_fired()
    end
end)
```

*— from examples/spawn_example.lua:150-174*

**Gotcha:** Events fire after entity creation; entity is guaranteed valid.

### How Presets Work

Presets are defined in `data.spawn_presets` by category:

```lua
local SpawnPresets = require("data.spawn_presets")

-- Access presets directly
local kobold = SpawnPresets.enemies.kobold
local fireball = SpawnPresets.projectiles.fireball
local exp_orb = SpawnPresets.pickups.exp_orb
local explosion = SpawnPresets.effects.explosion
```

**Preset structure:**

```lua
SpawnPresets.enemies.kobold = {
    sprite = "b1060.png",
    size = { 32, 32 },
    shadow = true,
    physics = {
        shape = "rectangle",
        tag = "enemy",
        collideWith = { "player", "projectile" },
    },
    data = {
        health = 50,
        damage = 10,
        faction = "enemy",
        -- ... other script data
    },
    interactive = {
        hover = { title = "Kobold", body = "Basic melee enemy" },
        collision = true
    }
}
```

*— from data/spawn_presets.lua:47-79*

**Adding new presets:**

1. Edit `data/spawn_presets.lua`
2. Add to appropriate category table
3. Spawn via `spawn.enemy("new_preset_id", x, y)`

***

## Shop System

\label{recipe:shop-system}

**When to use:** Between-round card shop for roguelike progression loops.

The Shop System manages all shop mechanics including card offerings with rarity-based pricing, interest calculation, lock/reroll mechanics, and card upgrade/removal services. It provides a complete economy system for roguelike deck-building games.

**Quick start:**

```lua
local ShopSystem = require("core.shop_system")

-- Generate shop for player
local shop = ShopSystem.generateShop(playerLevel, playerGold)

-- Player purchases a card
local success, card = ShopSystem.purchaseCard(shop, 1, player)

-- Calculate interest before next round
local interest = ShopSystem.calculateInterest(player.gold)
```

*— from core/shop_system.lua:1-36*

### Generating a Shop

Create a shop instance with randomized offerings:

```lua
local ShopSystem = require("core.shop_system")

-- Generate shop (5 card offerings by default)
local shop = ShopSystem.generateShop(playerLevel, playerGold)

-- Shop structure:
-- shop.offerings       -- Array of 5 card offerings
-- shop.locks           -- Boolean array tracking locked slots
-- shop.rerollCount     -- Number of times rerolled
-- shop.rerollCost      -- Current reroll cost (escalates)
-- shop.interest        -- Interest earned this round
```

*— from core/shop_system.lua:264-289*

**How offerings are generated:**

1. **Rarity selection** - Weighted random (60% common, 30% uncommon, 9% rare, 1% legendary)
2. **Card type selection** - Weighted by config (15% trigger, 40% modifier, 45% action)
3. **Card selection** - Random from matching pool (type + rarity)
4. **Pricing** - Based on rarity (common=3g, uncommon=5g, rare=8g, legendary=12g)

*— from core/shop_system.lua:73-98, 188-258*

### Purchasing Cards

Buy cards from shop offerings:

```lua
-- Player must have { gold, cards } fields
local player = {
    gold = 20,
    cards = {}
}

-- Purchase from slot 1 (1-indexed)
local success, cardInstance = ShopSystem.purchaseCard(shop, 1, player)

if success then
    print("Purchased:", cardInstance.id)
    print("Gold remaining:", player.gold)
    print("Deck size:", #player.cards)
else
    print("Purchase failed (insufficient gold or empty slot)")
end
```

*— from core/shop_system.lua:327-363*

**Card instances** are deep copies of card definitions with upgrade tracking initialized. They're automatically added to `player.cards`.

**Gotcha:** Once purchased, offerings are marked `sold = true` and `isEmpty = true`, preventing duplicate purchases.

### Locking Offerings

Lock offerings to preserve them during rerolls:

```lua
-- Lock slot 3 (keep this offering across rerolls)
ShopSystem.lockOffering(shop, 3)

-- Unlock later if needed
ShopSystem.unlockOffering(shop, 3)

-- Check lock status
if shop.locks[3] then
    print("Slot 3 is locked")
end
```

*— from core/shop_system.lua:365-379*

**Usage pattern:**

```lua
-- Player sees good offering but can't afford yet
ShopSystem.lockOffering(shop, 2)

-- Reroll other slots
ShopSystem.rerollOfferings(shop, player)

-- Locked offering remains, others are new
```

**Gotcha:** Sold offerings are never rerolled, even if unlocked.

### Rerolling Offerings

Refresh unlocked slots with new random offerings:

```lua
-- Reroll costs escalate: 5g, 6g, 7g, 8g...
local success = ShopSystem.rerollOfferings(shop, player)

if success then
    print("Rerolled! Cost:", shop.rerollCost - 1)  -- Previous cost
    print("Next reroll will cost:", shop.rerollCost)

    -- Unlocked, non-sold offerings are now different
    for i, offering in ipairs(shop.offerings) do
        if not shop.locks[i] and not offering.sold then
            print("New offering in slot", i, ":", offering.cardDef.id)
        end
    end
else
    print("Insufficient gold to reroll")
end
```

*— from core/shop_system.lua:381-408*

**Reroll mechanics:**

- **Base cost:** 5g (configurable via `ShopSystem.config.baseRerollCost`)
- **Cost increase:** +1g per reroll (configurable via `ShopSystem.config.rerollCostIncrease`)
- **Progression:** 5g → 6g → 7g → 8g → 9g... (escalates each time)
- **Locked slots:** Never rerolled
- **Sold slots:** Never rerolled

**Strategy tip:** Locking high-value offerings while fishing for specific cards is core to shop strategy.

### Interest System

Earn passive gold based on savings:

```lua
-- Calculate interest (1g per 10g, max 5g)
local interest = ShopSystem.calculateInterest(player.gold)

-- Examples:
-- 0-9g   → 0g interest
-- 10-19g → 1g interest
-- 20-29g → 2g interest
-- 30-39g → 3g interest
-- 40-49g → 4g interest
-- 50+g   → 5g interest (capped)

-- Apply interest at round end
local interestEarned = ShopSystem.applyInterest(player)
print("Earned", interestEarned, "gold in interest")
```

*— from core/shop_system.lua:488-516*

**Interest configuration:**

```lua
ShopSystem.config = {
    interestRate = 1,         -- 1 gold per threshold
    interestThreshold = 10,   -- Gold needed for 1 interest
    maxInterest = 5,          -- Maximum interest per round
    interestCap = 50,         -- Max gold that counts (50g = 5g interest)
}
```

*— from core/shop_system.lua:49-56*

**Gotcha:** Interest is calculated on current gold, not gold at round start. Spend wisely!

### Card Upgrade Service

Upgrade cards using the shop:

```lua
-- Upgrade a card from player's collection
local card = player.cards[1]

local success, upgradedCard = ShopSystem.upgradeCard(card, player)

if success then
    print("Upgraded!")
    -- upgradedCard has enhanced stats
    -- Original card is modified in-place
else
    print("Upgrade failed (insufficient gold or max level)")
end
```

*— from core/shop_system.lua:414-447*

**Integration:** Uses `wand/card_upgrade_system.lua` for upgrade logic. Cost is determined by `CardUpgrade.getUpgradeCost(card)`.

### Card Removal Service

Remove unwanted cards from deck:

```lua
-- Remove a card (default cost: 2g)
local card = player.cards[5]

local success = ShopSystem.removeCard(card, player)

if success then
    print("Card removed from deck")
    print("Deck size:", #player.cards)
else
    print("Removal failed (insufficient gold or card not found)")
end
```

*— from core/shop_system.lua:449-482*

**Configuration:**

```lua
ShopSystem.config.removalCost = 2  -- Cost to remove a card
```

**Gotcha:** Card must exist in `player.cards` array. Uses reference equality.

### Shop Configuration

Customize shop behavior:

```lua
-- Modify shop parameters
ShopSystem.config = {
    -- Offerings
    offerSlots = 5,              -- Number of card offerings

    -- Reroll system
    baseRerollCost = 5,          -- Starting reroll cost
    rerollCostIncrease = 1,      -- Cost increase per reroll

    -- Interest system
    interestRate = 1,            -- Gold earned per threshold
    interestThreshold = 10,      -- Gold needed for 1 interest
    maxInterest = 5,             -- Maximum interest per round
    interestCap = 50,            -- Max gold counted for interest

    -- Services
    removalCost = 2,             -- Cost to remove a card

    -- Card type distribution
    typeWeights = {
        trigger = 15,            -- 15% triggers
        modifier = 40,           -- 40% modifiers
        action = 45              -- 45% actions
    }
}
```

*— from core/shop_system.lua:49-67*

**Rarity weights:**

```lua
ShopSystem.rarities = {
    common = {
        name = "Common",
        color = "#CCCCCC",
        weight = 60,       -- 60% chance
        baseCost = 3
    },
    uncommon = {
        name = "Uncommon",
        color = "#4A90E2",
        weight = 30,       -- 30% chance
        baseCost = 5
    },
    rare = {
        name = "Rare",
        color = "#9B59B6",
        weight = 9,        -- 9% chance
        baseCost = 8
    },
    legendary = {
        name = "Legendary",
        color = "#F39C12",
        weight = 1,        -- 1% chance
        baseCost = 12
    }
}
```

*— from core/shop_system.lua:73-98*

**Modifying weights:**

```lua
-- Make rare cards more common
ShopSystem.rarities.rare.weight = 20

-- Make triggers more common
ShopSystem.config.typeWeights.trigger = 30
ShopSystem.config.typeWeights.modifier = 35
ShopSystem.config.typeWeights.action = 35
```

### Registering Cards

Populate the shop card pool:

```lua
local Cards = require("data.cards")

-- Register all cards at initialization
for _, cardDef in pairs(Cards) do
    ShopSystem.registerCard(cardDef)
end

-- Cards must have: id, type, rarity
-- Example card definition:
local cardDef = {
    id = "FIREBALL",
    type = "action",       -- action, modifier, trigger
    rarity = "common",     -- common, uncommon, rare, legendary
    -- ... other card fields
}

ShopSystem.registerCard(cardDef)
```

*— from core/shop_system.lua:131-169*

**Card pool structure:**

```lua
ShopSystem.cardPool = {
    trigger = { common = {}, uncommon = {}, rare = {}, legendary = {} },
    modifier = { common = {}, uncommon = {}, rare = {}, legendary = {} },
    action = { common = {}, uncommon = {}, rare = {}, legendary = {} }
}
```

**Check pool counts:**

```lua
local counts = ShopSystem.getPoolCounts()
-- Returns: { trigger = { common = 5, uncommon = 3, ... }, ... }
```

*— from core/shop_system.lua:172-182*

### Shop Display Utilities

Format shop for debugging or UI:

```lua
-- Print formatted shop display
local formatted = ShopSystem.formatShop(shop)
print(formatted)

-- Output:
-- === SHOP ===
-- Reroll Cost: 5g | Interest: 2g
--
-- 1. [Common] SPARK - 3g
-- 2. [Uncommon] FIREBALL - 5g [LOCKED]
-- 3. [SOLD]
-- 4. [Rare] CHAIN_LIGHTNING - 8g
-- 5. [Common] FROST_BOLT - 3g
```

*— from core/shop_system.lua:552-577*

**Get shop statistics:**

```lua
local stats = ShopSystem.getShopStats(shop)

print("Total offerings:", stats.totalOfferings)  -- 5
print("Sold:", stats.sold)                      -- 1
print("Locked:", stats.locked)                  -- 1
print("Reroll count:", stats.rerollCount)       -- 3
```

*— from core/shop_system.lua:579-600*

### Complete Shop Flow Example

Full round-to-round shop lifecycle:

```lua
local ShopSystem = require("core.shop_system")
local Cards = require("data.cards")

-- Initialize shop system (once at game start)
for _, cardDef in pairs(Cards) do
    ShopSystem.registerCard(cardDef)
end
ShopSystem.init()

-- Player state
local player = {
    gold = 25,
    cards = {},
    level = 3
}

-- === ROUND START ===

-- Generate shop
local shop = ShopSystem.generateShop(player.level, player.gold)
print(ShopSystem.formatShop(shop))

-- Player locks interesting offering
ShopSystem.lockOffering(shop, 2)

-- Player rerolls rest
ShopSystem.rerollOfferings(shop, player)

-- Player purchases a card
local success, card = ShopSystem.purchaseCard(shop, 1, player)
if success then
    print("Purchased:", card.id)
end

-- Player upgrades existing card
local upgradeSuccess = ShopSystem.upgradeCard(player.cards[1], player)

-- === ROUND END ===

-- Apply interest
local interest = ShopSystem.applyInterest(player)
print("Earned", interest, "gold in interest")
print("Total gold:", player.gold)

-- Next round starts with new shop
shop = ShopSystem.generateShop(player.level, player.gold)
```

*— combining patterns from core/shop_system.lua*

**Gotcha:** Shop instances are ephemeral - generate new shop each round. Don't persist across rounds.

### API Reference

**Shop Generation:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `generateShop(level, gold)` | `number, number` | `table` | Creates shop with random offerings |
| `generateOffering(level)` | `number` | `table` | Generates single offering |

**Shop Actions:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `purchaseCard(shop, slot, player)` | `table, number, table` | `boolean, table` | Purchase card from slot |
| `lockOffering(shop, slot)` | `table, number` | - | Lock offering (prevent reroll) |
| `unlockOffering(shop, slot)` | `table, number` | - | Unlock offering |
| `rerollOfferings(shop, player)` | `table, table` | `boolean` | Reroll unlocked slots |

**Services:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `upgradeCard(card, player)` | `table, table` | `boolean, table` | Upgrade card (uses CardUpgrade) |
| `removeCard(card, player)` | `table, table` | `boolean` | Remove card from deck |

**Interest:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `calculateInterest(gold)` | `number` | `number` | Calculate interest for gold amount |
| `applyInterest(player)` | `table` | `number` | Add interest to player gold |

**Card Pool:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `registerCard(cardDef)` | `table` | - | Add card to shop pool |
| `getPoolCounts()` | - | `table` | Get card counts by type/rarity |

**Utilities:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `formatShop(shop)` | `table` | `string` | Format shop for display |
| `getShopStats(shop)` | `table` | `table` | Get shop statistics |

***

## Stat System

\label{recipe:stat-system}

**When to use:** Managing character progression through core stats that derive gameplay effects.

The Stat System provides an extensible framework for mapping core character stats (physique, cunning, spirit) to gameplay stats. It centralizes stat derivations, provides stat impact previews for UI tooltips, handles level-up application, and integrates with the combat system's Stats class for automatic recomputation.

**Quick start:**

```lua
local StatSystem = require("core.stat_system")

-- Initialize with default derivations
StatSystem.init()

-- Apply level-up
StatSystem.applyLevelUp(player, "physique", 1)

-- Preview stat impact for UI
local impact = StatSystem.getStatImpact("spirit", currentValue, 1)
-- Returns: { energy = 10, energy_regen = 0.5, ... }
```

*— from core/stat_system.lua:1-36*

### Core Stats

The system defines three primary stats that players can increase through level-ups:

```lua
StatSystem.stats = {
    physique = {
        name = "Physique",
        description = "Increases health and survivability",
        icon = "icon_physique",
        color = "#E74C3C"   -- Red
    },
    cunning = {
        name = "Cunning",
        description = "Increases damage and critical strikes",
        icon = "icon_cunning",
        color = "#F39C12"   -- Orange
    },
    spirit = {
        name = "Spirit",
        description = "Increases energy and elemental power",
        icon = "icon_spirit",
        color = "#9B59B6"   -- Purple
    }
}
```

*— from core/stat_system.lua:36-55*

**Stat effects:**

| Stat | Primary Effects |
|------|-----------------|
| **Physique** | Health (+10 per point), health regen (after 10 points) |
| **Cunning** | Offensive ability, physical/pierce damage, bleed/trauma duration |
| **Spirit** | Health (+2 per point), energy (+10 per point), energy regen (+0.5 per point), elemental damage |

### Registering Derivations

Add custom stat-to-gameplay mappings:

```lua
-- Register a new derivation
StatSystem.registerDerivation("physique", "dash_distance", function(value, entity)
    return value * 2  -- +2 dash distance per physique point
end)

-- Register context-aware derivation
StatSystem.registerDerivation("cunning", "crit_damage", function(value, entity)
    local base = value * 5
    -- Can use entity context for conditional logic
    if entity and entity.hasAmulet then
        return base * 1.2
    end
    return base
end)
```

*— from core/stat_system.lua:73-85*

**How it works:**

1. Derivations are stored in `StatSystem.derivations[statName][derivedStatName]`
2. Multiple derivations per stat are supported (physique → health, health_regen, etc.)
3. Derivation functions receive `(value, entity)` parameters
4. Entity context is optional - use for conditional derivations

**Pattern:** Derivation functions are called during stat recomputation. Return the derived stat's total value (not the delta).

### Applying Level-Ups

Increase player stats and trigger automatic recomputation:

```lua
-- Player must have .stats (Stats instance from combat_system)
local player = {
    stats = Stats.new(),
    name = "Player"
}

-- Apply +1 physique
StatSystem.applyLevelUp(player, "physique", 1)

-- Apply multiple points
StatSystem.applyLevelUp(player, "spirit", 3)

-- Stats automatically recompute via on_recompute hooks
```

*— from core/stat_system.lua:206-227*

**Integration with combat_system:**

```lua
-- When creating player stats, attach derivations
local Stats = require("combat.stats")
local player = { stats = Stats.new() }

-- Attach stat system derivations
StatSystem.attachToStatsInstance(player.stats)

-- Now level-ups will auto-trigger derivations
StatSystem.applyLevelUp(player, "cunning", 1)
```

*— from core/stat_system.lua:233-259*

**Gotcha:** `applyLevelUp` modifies the base stat and lets the Stats instance handle recomputation. Don't manually recompute - the system does it automatically.

### Previewing Stat Impact

Show players what they'll gain before committing to level-up:

```lua
-- Preview +1 spirit impact
local currentSpirit = player.stats:get_raw('spirit').base
local impact = StatSystem.getStatImpact("spirit", currentSpirit, 1)

-- Returns table of derivedStatName -> deltaValue
-- Example: { health = 2, energy = 10, energy_regen = 0.5, fire_modifier_pct = 0, ... }

-- Format for UI display
local formatted = StatSystem.formatStatImpact(impact)
print(formatted)
-- Output:
--   energy: +10.00
--   energy_regen: +0.50
--   health: +2.00

-- Only non-zero changes are included
for statName, delta in pairs(impact) do
    if delta > 0 then
        print(string.format("+%.1f %s", delta, statName))
    end
end
```

*— from core/stat_system.lua:161-200*

**Preview mechanics:**

1. Calculate derived stats at current value
2. Calculate derived stats at current + delta
3. Return differences (only non-zero changes)
4. Use for tooltips, confirmation dialogs, stat screens

**Example use case:**

```lua
-- Level-up UI tooltip
local function showLevelUpTooltip(statName)
    local current = player.stats:get_raw(statName).base
    local impact = StatSystem.getStatImpact(statName, current, 1)

    local lines = { "Level up " .. statName .. ":" }
    for stat, delta in pairs(impact) do
        table.insert(lines, string.format("  +%.1f %s", delta, stat))
    end

    return table.concat(lines, "\n")
end
```

### Default Derivations

The system initializes with derivations matching combat_system.lua:

```lua
StatSystem.initializeDefaultDerivations()

-- PHYSIQUE derivations:
-- health: 100 + value * 10
-- health_regen: (value - 10) * 0.2  (only after 10 physique)

-- CUNNING derivations:
-- offensive_ability: value * 1
-- physical_modifier_pct: floor(value / 5) * 1
-- pierce_modifier_pct: floor(value / 5) * 1
-- bleed_duration_pct: floor(value / 5) * 1
-- trauma_duration_pct: floor(value / 5) * 1

-- SPIRIT derivations:
-- health: value * 2
-- energy: value * 10
-- energy_regen: value * 0.5
-- fire_modifier_pct: floor(value / 5) * 1
-- cold_modifier_pct: floor(value / 5) * 1
-- lightning_modifier_pct: floor(value / 5) * 1
-- (... all elemental types)
-- burn_duration_pct: floor(value / 5) * 1
-- frostburn_duration_pct: floor(value / 5) * 1
-- (... all DoT types)
```

*— from core/stat_system.lua:91-155*

**Elemental types:** fire, cold, lightning, acid, vitality, aether, chaos

**DoT types:** burn, frostburn, electrocute, poison, vitality_decay

**Breakpoint mechanics:** Cunning and Spirit derivations use `floor(value / 5)` for breakpoints at 5, 10, 15, 20... This creates strategic level-up thresholds.

### Stat Flow to Gameplay

How stats flow through the system:

```
1. Player gains XP → Level up
                ↓
2. StatSystem.applyLevelUp(player, "physique", 1)
                ↓
3. player.stats:add_base("physique", 1)
                ↓
4. Stats instance triggers on_recompute hooks
                ↓
5. StatSystem derivations run:
   - Read raw base values (physique, cunning, spirit)
   - Apply derivation functions
   - Call S:derived_add_base() for each derived stat
                ↓
6. Gameplay systems read final computed stats:
   - Combat uses health, energy, damage modifiers
   - Movement uses dash_distance (if registered)
   - UI displays final values
```

**Example end-to-end:**

```lua
local Stats = require("combat.stats")
local StatSystem = require("core.stat_system")

-- Setup
StatSystem.init()
local player = { stats = Stats.new() }
StatSystem.attachToStatsInstance(player.stats)

-- Starting stats: 10 physique
player.stats:add_base("physique", 10)

-- Health is now: 100 + 10*10 = 200
local health = player.stats:get("health")  -- 200

-- Player levels up physique
StatSystem.applyLevelUp(player, "physique", 1)

-- Health is now: 100 + 11*10 = 210
health = player.stats:get("health")  -- 210
```

### Debugging Derivations

Inspect registered derivations:

```lua
-- List all derivations
StatSystem.listDerivations()
-- Output:
-- [StatSystem] Registered Derivations:
--   physique:
--     -> health
--     -> health_regen
--   cunning:
--     -> offensive_ability
--     -> physical_modifier_pct
--     -> pierce_modifier_pct
--     ...

-- Get derivations for specific stat
local physiqueDerivs = StatSystem.getDerivations("physique")
for derivedStatName, derivationFunc in pairs(physiqueDerivs) do
    print(derivedStatName, derivationFunc(15))  -- Test with value 15
end
```

*— from core/stat_system.lua:265-281*

### API Reference

**Initialization:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `init()` | - | - | Initialize with default derivations |
| `initializeDefaultDerivations()` | - | - | Register default stat derivations |

**Derivation Registration:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `registerDerivation(statName, derivedStatName, func)` | `string, string, function` | - | Register stat derivation |
| `getDerivations(statName)` | `string` | `table` | Get all derivations for stat |

**Level-Up:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `applyLevelUp(entity, statName, amount)` | `table, string, number` | - | Apply stat increase (default 1) |

**Stat Impact:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `getStatImpact(statName, currentValue, delta, entity)` | `string, number, number, table?` | `table` | Calculate stat changes |
| `formatStatImpact(impact)` | `table` | `string` | Format impact for display |

**Integration:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `attachToStatsInstance(statsInstance)` | `table` | - | Attach derivations to Stats instance |

**Debugging:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `listDerivations()` | - | - | Print all registered derivations |

***

## Save System

\label{recipe:save-system}

**When to use:** Persisting game state across sessions (progress, statistics, settings).

The Save System provides a cross-platform persistence layer that works on desktop and web (via IDBFS). It uses a collector pattern where modules register themselves to provide and receive save data.

### SaveManager

\label{recipe:save-manager}

**When to use:** Register your module's data for automatic save/load.

```lua
local SaveManager = require("core.save_manager")

-- Register a collector for your module
SaveManager.register("my_module", {
    -- Called when saving - return your data
    collect = function()
        return {
            level = currentLevel,
            unlocks = unlockedItems,
            settings = userSettings,
        }
    end,

    -- Called when loading - receive your data
    distribute = function(data)
        currentLevel = data.level or 1
        unlockedItems = data.unlocks or {}
        userSettings = data.settings or {}
    end
})

-- Trigger a save (debounced, queues if save in progress)
SaveManager.save()

-- Load saved data (calls all distribute functions)
SaveManager.load()
```

*— from core/save_manager.lua:35-88*

### Statistics Module

\label{recipe:statistics}

**When to use:** Track persistent gameplay statistics (kills, playtime, high scores).

```lua
local Statistics = require("core.statistics")

-- Increment a stat (auto-saves)
Statistics.increment("total_kills")
Statistics.increment("total_gold_earned", 100)

-- Set high score (only updates if higher, auto-saves)
Statistics.set_high("highest_wave", currentWave)

-- Read stats
print("Kills:", Statistics.total_kills)
print("Best wave:", Statistics.highest_wave)
```

*— from core/statistics.lua:1-54*

**Available statistics:**

| Stat | Type | Description |
|------|------|-------------|
| `runs_completed` | counter | Number of completed runs |
| `highest_wave` | high score | Highest wave reached |
| `total_kills` | counter | Total enemies killed |
| `total_gold_earned` | counter | Total gold accumulated |
| `playtime_seconds` | counter | Total play time |

### Save Migrations

\label{recipe:save-migrations}

**When to use:** Handle save file format changes between game versions.

```lua
local migrations = require("core.save_migrations")

-- Register a migration from version 1 to 2
migrations.register(1, 2, function(data)
    -- Transform old format to new format
    data.settings = data.settings or {}
    data.settings.volume = data.sound_volume or 1.0
    data.sound_volume = nil  -- Remove old key
    return data
end)
```

*— from core/save_migrations.lua*

The SaveManager automatically applies migrations when loading older save files.

### SaveManager API Reference

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `register(key, collector)` | `string, {collect, distribute}` | - | Register save data collector |
| `save()` | - | - | Queue a save operation |
| `load()` | `boolean?` | `boolean` | Load and distribute save data |
| `collect_all()` | - | `table` | Collect data from all collectors |
| `has_save()` | - | `boolean` | Check if save file exists |
| `delete_save()` | - | `boolean` | Delete save file |

**Gotcha:** Collectors must handle missing data gracefully (use `data.key or default`).

**Gotcha:** Web builds use IDBFS which is asynchronous. The engine handles this, but avoid calling `load()` immediately after `save()`.

***

## LDtk Integration

\label{recipe:ldtk-integration}

LDtk (Level Designer Toolkit) is a modern 2D level editor. The engine provides comprehensive Lua bindings to load LDtk projects, spawn entities, build physics colliders, and query level data.

### Configuration

Create a JSON config file to map your LDtk project:

```lua
-- assets/ldtk_config.json
{
  "project_path": "world.ldtk",
  "asset_dir": "assets",
  "collider_layers": ["Collisions"],
  "entity_prefabs": {
    "Player": "spawnPlayer",
    "Enemy": "EnemySystem.spawn"
  }
}
```

Load the config at startup:

```lua
ldtk.load_config("ldtk_config.json")
```

**Config Fields:**
- `project_path`: Path to `.ldtk` file
- `asset_dir`: Base directory for assets
- `collider_layers`: IntGrid layers to generate colliders from
- `entity_prefabs`: Map entity names to Lua spawner functions

### Loading Levels

Activate a level and trigger entity spawning + collider generation:

```lua
-- Full level load with colliders and entity spawning
ldtk.set_active_level("Level_0", "world", true, true, "WORLD")
-- Parameters: levelName, physicsWorldName, buildColliders, spawnEntities, physicsTag

-- Check active level
if ldtk.has_active_level() then
    local levelName = ldtk.active_level()
    print("Active level:", levelName)
end

-- Check if level exists before loading
if ldtk.level_exists("Level_1") then
    ldtk.set_active_level("Level_1", "world", true, true, "WORLD")
end
```

### Entity Spawning

Register a global entity spawner callback that fires for each entity in the level:

```lua
ldtk.set_spawner(function(name, px, py, layerName, gx, gy, fields)
    -- name: entity identifier from LDtk
    -- px, py: pixel position
    -- layerName: layer the entity is on
    -- gx, gy: grid coordinates
    -- fields: table of custom fields from LDtk

    local prefab = ldtk.prefab_for(name)
    if prefab and _G[prefab] then
        _G[prefab](px, py, fields)
    end
end)
```

**Entity Field Types:**

LDtk custom fields are automatically converted to Lua:

| LDtk Type | Lua Type | Example Access |
|-----------|----------|----------------|
| Int | `number` | `fields.health` |
| Float | `number` | `fields.speed` |
| Bool | `boolean` | `fields.hostile` |
| String | `string` | `fields.dialog` |
| Color | `table` | `fields.tint.r, .g, .b, .a` |
| Point | `table` | `fields.target.x, .y` |
| Enum | `table` | `fields.type.name, .id` |
| FilePath | `string` | `fields.texture` |
| EntityRef | `table` | `fields.owner.entity_iid` |
| Array[T] | `table` | `fields.items[1], fields.items[2]` |

### IntGrid Iteration

Iterate over IntGrid cells for custom collision logic or procedural content:

```lua
ldtk.each_intgrid("Level_0", "Collisions", function(x, y, value)
    -- x, y: grid coordinates
    -- value: IntGrid cell value (0 = empty)

    if value == 1 then
        -- Solid wall
    elseif value == 2 then
        -- Platform (one-way collision)
    end
end)
```

### Physics Colliders

Build static colliders from IntGrid layers:

```lua
-- Build colliders for active level
local colliderLayers = ldtk.collider_layers()  -- Returns: {"Collisions", "Platforms"}
ldtk.build_colliders("Level_0", "world", "WORLD")

-- Clear colliders (useful when switching levels)
ldtk.clear_colliders("Level_0", "world")
```

Colliders are automatically generated from non-zero IntGrid cells and tagged with the specified physics tag (e.g., `"WORLD"`).

### Level Metadata

Query level properties for camera bounds, background colors, and navigation:

```lua
-- Get level bounds
local bounds = ldtk.get_level_bounds("Level_0")
print(bounds.x, bounds.y, bounds.width, bounds.height)

-- Get level metadata
local meta = ldtk.get_level_meta("Level_0")
print("Size:", meta.width, "x", meta.height)
print("World position:", meta.world_x, meta.world_y)
print("Background:", meta.bg_color.r, meta.bg_color.g, meta.bg_color.b)
print("Depth:", meta.depth)  -- Multi-world z-order

-- Get neighboring levels (for seamless world streaming)
local neighbors = ldtk.get_neighbors("Level_0")
if neighbors.north then
    print("North level:", neighbors.north)
end
if neighbors.east then
    print("East level:", neighbors.east)
end
-- Also: .south, .west, .overlap (array of overlapping levels)
```

### Entity Queries

Query entities by name or IID (Instance Identifier):

```lua
-- Get all entities of a specific type
local enemies = ldtk.get_entities_by_name("Level_0", "Enemy")
for _, ent in ipairs(enemies) do
    print("Enemy at", ent.x, ent.y)
    print("Size:", ent.width, ent.height)
    print("IID:", ent.iid)
    print("Tags:", table.concat(ent.tags, ", "))

    -- Access custom fields
    if ent.fields.health then
        print("Health:", ent.fields.health)
    end
end

-- Get entity position by IID
local pos = ldtk.get_entity_position("Level_0", "abc123-def-456")
if pos then
    print("Entity at:", pos.x, pos.y)
end
```

### Procedural Generation

Use LDtk auto-rules on runtime-generated IntGrid data:

```lua
-- Create procedural IntGrid (e.g., from noise or cellular automata)
local width, height = 32, 24
local grid = {}

for y = 1, height do
    for x = 1, width do
        local idx = (y - 1) * width + x
        grid[idx] = (math.random() > 0.7) and 1 or 0  -- Random walls
    end
end

-- Apply LDtk auto-rules to generate tile results
local gridTable = {
    width = width,
    height = height,
    cells = grid
}

local tileResults = ldtk.apply_rules(gridTable, "TileLayer")
-- Returns: array of {tile_id, x, y, flip_x, flip_y}

-- Build colliders from procedural grid (without LDtk level)
ldtk.build_colliders_from_grid(gridTable, "world", "WORLD", {1})
-- Parameters: gridTable, physicsWorldName, physicsTag, solidValues
```

**Layer Query API:**

```lua
local layerCount = ldtk.get_layer_count()
for i = 0, layerCount - 1 do
    local name = ldtk.get_layer_name(i)
    print("Layer", i, ":", name)
end

local idx = ldtk.get_layer_index("TileLayer")
print("TileLayer index:", idx)
```

**Tile Grid Access:**

```lua
local grid = ldtk.get_tile_grid(layerIdx)
-- Returns: {width, height, tiles={...}}
-- Each tile: {tile_id, x, y, flip_x, flip_y}
```

**Cleanup:**

```lua
-- Clean up procedurally generated level data
ldtk.cleanup_procedural()
```

### Event System Integration

Use signal emitter for level load/entity spawn events:

```lua
local signal = require("external.hump.signal")

-- Set up signal emitter
ldtk.set_signal_emitter(function(eventName, data)
    signal.emit(eventName, data)
end)

-- Register handlers
signal.register("ldtk_level_loaded", function(data)
    print("Level loaded:", data.level_name)
    print("Colliders built:", data.colliders_built)
end)

signal.register("ldtk_colliders_built", function(data)
    print("Colliders for:", data.level_name)
    print("Physics tag:", data.physics_tag)
end)

signal.register("ldtk_entity_spawned", function(data)
    print("Spawned:", data.entity_name, "at", data.px, data.py)
end)

-- Load level with signal emission
ldtk.set_active_level_with_signals("Level_0", "world", true, true, "WORLD")

-- Manually emit entity spawned event (from spawner callback)
ldtk.emit_entity_spawned("Enemy", 100, 200, "Entities", {type = "goblin"})
```

### Rendering Procedural Tiles

Draw procedurally generated tiles using the shader pipeline:

```lua
-- Draw single procedural layer
-- Parameters: layerIdx (int), targetLayerName (string), offsetX (optional float),
--             offsetY (optional float), zLevel (optional int), opacity (optional float)
ldtk.draw_procedural_layer(layerIdx, "WORLD", 0, 0, 0, 1.0)

-- Draw all procedural layers
-- Parameters: targetLayerName (string), offsetX (optional float), offsetY (optional float),
--             baseZLevel (optional int), opacity (optional float)
ldtk.draw_all_procedural_layers("WORLD", 0, 0, 0, 1.0)

-- Draw with Y-sorting (for isometric/top-down)
-- Parameters: layerIdx (int), targetLayerName (string), offsetX (optional float),
--             offsetY (optional float), baseZLevel (optional int), zPerRow (optional int),
--             opacity (optional float)
ldtk.draw_procedural_layer_ysorted(layerIdx, "WORLD", 0, 0, 0, 1, 1.0)

-- Draw with tile filtering
-- Parameters: layerIdx (int), targetLayerName (string), tileIds (table),
--             offsetX (optional float), offsetY (optional float), zLevel (optional int),
--             opacity (optional float)
-- tileIds: Lua table of allowed tile IDs, e.g., {1, 2, 5, 10}
ldtk.draw_procedural_layer_filtered(layerIdx, "WORLD", {1, 2, 3}, 0, 0, 0, 1.0)

-- Draw individual tile
-- Parameters: layerIdx (int), tileId (int), targetLayerName (string), worldX (float),
--             worldY (float), zLevel (int), flipX (optional bool), flipY (optional bool),
--             opacity (optional float)
ldtk.draw_tile(layerIdx, tileId, "WORLD", 100, 200, 0, false, false, 1.0)

-- Get tileset info
local info = ldtk.get_tileset_info(layerIdx)
print("Tileset:", info.path)
print("Tile size:", info.tile_size)
print("Grid size:", info.grid_width, "x", info.grid_height)
```

### Complete Example

Full level loading system with entity spawning and event handling:

```lua
local LevelManager = {}

function LevelManager.init()
    -- Load config
    ldtk.load_config("ldtk_config.json")

    -- Set up entity spawner
    ldtk.set_spawner(function(name, px, py, layerName, gx, gy, fields)
        local prefab = ldtk.prefab_for(name)
        if prefab and _G[prefab] then
            local entity = _G[prefab](px, py)

            -- Apply custom fields
            if entity and fields then
                local script = getScriptTableFromEntityID(entity)
                if script then
                    for k, v in pairs(fields) do
                        script[k] = v
                    end
                end
            end
        end
    end)

    -- Set up event system
    local signal = require("external.hump.signal")
    ldtk.set_signal_emitter(function(eventName, data)
        signal.emit(eventName, data)
    end)

    signal.register("ldtk_level_loaded", function(data)
        print("Level ready:", data.level_name)
        LevelManager.onLevelReady(data.level_name)
    end)
end

function LevelManager.loadLevel(levelName)
    if not ldtk.level_exists(levelName) then
        print("Level not found:", levelName)
        return false
    end

    -- Clear old level colliders
    local currentLevel = ldtk.active_level()
    if currentLevel ~= "" then
        ldtk.clear_colliders(currentLevel, "world")
    end

    -- Load new level
    ldtk.set_active_level_with_signals(levelName, "world", true, true, "WORLD")
    return true
end

function LevelManager.onLevelReady(levelName)
    -- Set camera bounds
    local bounds = ldtk.get_level_bounds(levelName)
    CameraSystem.setBounds(bounds.x, bounds.y, bounds.width, bounds.height)

    -- Set background color
    local meta = ldtk.get_level_meta(levelName)
    BackgroundSystem.setColor(meta.bg_color)
end

function LevelManager.transitionTo(direction)
    local currentLevel = ldtk.active_level()
    local neighbors = ldtk.get_neighbors(currentLevel)
    local nextLevel = neighbors[direction]

    if nextLevel then
        LevelManager.loadLevel(nextLevel)
    end
end

return LevelManager
```

### API Reference

**Configuration:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `load_config(path)` | `string` | - | Load LDtk project config JSON |
| `collider_layers()` | - | `table` | Get collider layer names from config |
| `prefab_for(entityName)` | `string` | `string` | Look up prefab mapping for entity |

**Level Management:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `set_active_level(name, world, colliders, spawn, tag)` | `string, string, bool, bool, string` | - | Activate level and optionally build colliders/spawn entities |
| `set_active_level_with_signals(...)` | Same as above | - | Like `set_active_level` but emits signals |
| `active_level()` | - | `string` | Get active level name |
| `has_active_level()` | - | `boolean` | Check if level is active |
| `level_exists(name)` | `string` | `boolean` | Check if level exists in project |

**Entity Spawning:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `set_spawner(callback)` | `function` | - | Register entity spawner callback |
| `get_entities_by_name(level, name)` | `string, string` | `table` | Query entities by name |
| `get_entity_position(level, iid)` | `string, string` | `table` | Get entity position by IID |

**IntGrid & Colliders:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `each_intgrid(level, layer, callback)` | `string, string, function` | - | Iterate IntGrid cells |
| `build_colliders(level, world, tag)` | `string, string, string` | - | Build physics colliders from IntGrid |
| `clear_colliders(level, world)` | `string, string` | - | Clear level colliders |
| `build_colliders_from_grid(grid, world, tag, solidVals)` | `table, string, string, table` | - | Build colliders from Lua IntGrid |

**Metadata:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `get_level_bounds(name)` | `string` | `table` | Get `{x, y, width, height}` |
| `get_level_meta(name)` | `string` | `table` | Get `{width, height, world_x, world_y, bg_color, depth}` |
| `get_neighbors(name)` | `string` | `table` | Get `{north, south, east, west, overlap}` |

**Procedural Generation:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `apply_rules(grid, layer)` | `table, string` | `table` | Apply LDtk auto-rules to IntGrid |
| `get_layer_count()` | - | `number` | Get layer count |
| `get_layer_name(idx)` | `number` | `string` | Get layer name by index |
| `get_layer_index(name)` | `string` | `number` | Get layer index by name |
| `get_tile_grid(layerIdx)` | `number` | `table` | Get tile results for layer |
| `get_tileset_info(layerIdx)` | `number` | `table` | Get tileset metadata |
| `cleanup_procedural()` | - | - | Clean up procedural data |

**Rendering:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `draw_procedural_layer(idx, name, x, y, tileset, space)` | `number, string, number, number, string, number` | - | Draw procedural layer |
| `draw_all_procedural_layers(x, y, space)` | `number, number, number` | - | Draw all layers |
| `draw_procedural_layer_filtered(idx, name, x, y, tileset, filterFn, space)` | `..., function, ...` | - | Draw with filter callback |
| `draw_procedural_layer_ysorted(idx, name, x, y, tileset, sortFn, space)` | `..., function, ...` | - | Draw with Y-sorting |
| `draw_tile(id, x, y, size, tileset, flipX, flipY, space)` | `number, number, number, number, string, bool, bool, number` | - | Draw single tile |

**Events:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `set_signal_emitter(callback)` | `function` | - | Register signal emitter for events |
| `emit_entity_spawned(name, x, y, layer, fields)` | `string, number, number, string, table` | - | Emit entity spawn event |

**Events Emitted:**
- `ldtk_level_loaded`: `{level_name, colliders_built, entities_spawned}`
- `ldtk_colliders_built`: `{level_name, physics_tag}`
- `ldtk_entity_spawned`: `{entity_name, px, py, layer_name, fields}`

***

## Loot System

\label{recipe:loot-system}

The Loot System manages the spawning and collection of loot drops from defeated enemies, including XP orbs, gold, health potions, ability cards, and equipment. It provides configurable loot tables, multiple collection modes (auto-collect, click, magnet), and integrates with the combat system's event bus and leveling mechanics.

### Creating a Loot System

Initialize a loot system with configuration options:

```lua
local LootSystem = require("combat.loot_system")

local loot_system = LootSystem.new({
    combat_context = combat_ctx,        -- Combat context (for event bus)
    player_entity = player_eid,         -- Player entity ID
    loot_tables = {                     -- Custom loot tables (optional)
        goblin = {
            gold = { min = 1, max = 3, chance = 100 },
            xp = { base = 10, variance = 2, chance = 100 },
            items = {
                { type = "health_potion", chance = 10 }
            }
        }
    },
    default_collection_mode = LootSystem.CollectionModes.AUTO_COLLECT,  -- or CLICK, MAGNET
    magnet_range = 150,                 -- Range for magnet collection (pixels)
    despawn_time = 30,                  -- Auto-despawn timeout (seconds)
    on_loot_collected = function(player, loot_type, amount)
        print("Collected", amount, loot_type)
    end
})
```

**Configuration Fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `combat_context` | `table` | Required | Combat context with event bus |
| `player_entity` | `entity_id` | Required | Player entity for collection |
| `loot_tables` | `table` | Auto-generated | Loot tables per enemy type |
| `default_collection_mode` | `string` | `"auto_collect"` | Collection mode (see below) |
| `magnet_range` | `number` | `150` | Magnet attraction range (pixels) |
| `despawn_time` | `number` | `30` | Auto-despawn timeout (seconds) |
| `on_loot_collected` | `function` | `nil` | Callback on collection |

### Loot Types

The system supports five loot types:

```lua
-- Access via LootSystem.LootTypes
LootSystem.LootTypes.GOLD            -- Currency
LootSystem.LootTypes.XP_ORB          -- Experience points
LootSystem.LootTypes.HEALTH_POTION   -- Restores 50 HP
LootSystem.LootTypes.CARD            -- Ability card
LootSystem.LootTypes.ITEM            -- Equipment item
```

### Collection Modes

Three collection modes control how players interact with loot:

```lua
-- Auto-collect: Immediate collection after 0.3s delay
LootSystem.CollectionModes.AUTO_COLLECT

-- Click-to-collect: Player must click loot entity
LootSystem.CollectionModes.CLICK

-- Magnet: Loot flies towards player when in range
LootSystem.CollectionModes.MAGNET
```

**Collection Mode Behavior:**

| Mode | Interaction | Use Case |
|------|-------------|----------|
| `AUTO_COLLECT` | Automatic after delay | Fast-paced action games |
| `CLICK` | Manual click required | Strategic looting decisions |
| `MAGNET` | Attracts within range | Hybrid: intentional movement |

### Spawning Loot

Spawn loot when enemies die:

```lua
-- Spawn loot from loot table
loot_system:spawn_loot_for_enemy(
    "goblin",                -- Enemy type (looks up loot table)
    { x = 300, y = 200 },    -- Spawn position
    combat_context           -- Optional combat context
)

-- Spawn specific loot types manually
loot_system:spawn_gold({ x = 100, y = 100 }, 5)           -- 5 gold
loot_system:spawn_xp({ x = 100, y = 100 }, 25)            -- 25 XP
loot_system:spawn_item({ x = 100, y = 100 }, "card_rare") -- Rare card
```

### Loot Tables

Define loot tables for enemy types:

```lua
local loot_tables = {
    goblin = {
        gold = { min = 1, max = 3, chance = 100 },        -- Always drops 1-3 gold
        xp = { base = 10, variance = 2, chance = 100 },   -- Always drops 8-12 XP
        items = {
            { type = "health_potion", chance = 10 }       -- 10% chance for potion
        }
    },
    orc = {
        gold = { min = 3, max = 7, chance = 100 },
        xp = { base = 25, variance = 5, chance = 100 },
        items = {
            { type = "health_potion", chance = 15 },
            { type = "card_common", chance = 5 }
        }
    },
    boss = {
        gold = { min = 20, max = 50, chance = 100 },
        xp = { base = 100, variance = 20, chance = 100 },
        items = {
            { type = "card_rare", chance = 50 },
            { type = "card_uncommon", chance = 100 },
            { type = "health_potion", chance = 100 }
        }
    },
    unknown = {
        gold = { min = 1, max = 2, chance = 80 },         -- Fallback for unknown enemies
        xp = { base = 5, variance = 1, chance = 80 }
    }
}
```

**Loot Table Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `gold.min` | `number` | Minimum gold drop |
| `gold.max` | `number` | Maximum gold drop |
| `gold.chance` | `number` | Drop chance (0-100) |
| `xp.base` | `number` | Base XP amount |
| `xp.variance` | `number` | Random variance (+/-) |
| `xp.chance` | `number` | Drop chance (0-100) |
| `items` | `table` | Array of item drops |
| `items[n].type` | `string` | Loot type or item ID |
| `items[n].chance` | `number` | Drop chance (0-100) |

### Integration with Combat System

Hook up loot spawning to enemy death events:

```lua
local signal = require("external.hump.signal")

-- Register enemy death handler
signal.register("OnEnemyDeath", function(enemy_entity, enemy_data)
    local transform = component_cache.get(enemy_entity, Transform)
    if transform then
        local position = {
            x = transform.actualX + transform.actualW * 0.5,
            y = transform.actualY + transform.actualH * 0.5
        }

        -- Spawn loot based on enemy type
        local enemy_type = enemy_data.type or "unknown"
        loot_system:spawn_loot_for_enemy(enemy_type, position, combat_context)
    end
end)
```

### Event System

The loot system emits events via the combat context event bus:

```lua
-- Register event handlers
if combat_context.bus then
    combat_context.bus:on("OnLootDropped", function(data)
        -- data: { loot_entity, loot_type, amount, position }
        print("Loot dropped:", data.loot_type, "at", data.position.x, data.position.y)
    end)

    combat_context.bus:on("OnLootCollected", function(data)
        -- data: { player, loot_type, amount }
        print("Player collected:", data.amount, data.loot_type)
    end)
end
```

**Events Emitted:**

| Event | Data | Description |
|-------|------|-------------|
| `OnLootDropped` | `{ loot_entity, loot_type, amount, position }` | Loot spawned |
| `OnLootCollected` | `{ player, loot_type, amount }` | Loot collected |

### Cleanup

Clean up all active loot (useful for level transitions):

```lua
-- Despawn all loot entities
loot_system:cleanup_all_loot()
```

### Complete Example

Full integration with combat system:

```lua
local LootSystem = require("combat.loot_system")
local signal = require("external.hump.signal")
local component_cache = require("core.component_cache")

-- Custom loot tables
local loot_tables = {
    skeleton = {
        gold = { min = 2, max = 5, chance = 100 },
        xp = { base = 15, variance = 3, chance = 100 },
        items = {
            { type = "health_potion", chance = 8 },
            { type = "card_common", chance = 3 }
        }
    },
    dragon = {
        gold = { min = 50, max = 100, chance = 100 },
        xp = { base = 500, variance = 50, chance = 100 },
        items = {
            { type = "card_legendary", chance = 25 },
            { type = "card_rare", chance = 100 },
            { type = "health_potion", chance = 100 }
        }
    }
}

-- Initialize loot system
local loot_system = LootSystem.new({
    combat_context = combat_ctx,
    player_entity = player_eid,
    loot_tables = loot_tables,
    default_collection_mode = LootSystem.CollectionModes.MAGNET,
    magnet_range = 200,
    despawn_time = 60,
    on_loot_collected = function(player, loot_type, amount)
        -- Play sound effect
        if loot_type == LootSystem.LootTypes.GOLD then
            playSound("coin_pickup")
        elseif loot_type == LootSystem.LootTypes.XP_ORB then
            playSound("xp_gain")
        end
    end
})

-- Hook up enemy death event
signal.register("OnEnemyDeath", function(enemy_entity, enemy_data)
    local transform = component_cache.get(enemy_entity, Transform)
    if not transform then return end

    local position = {
        x = transform.actualX + transform.actualW * 0.5,
        y = transform.actualY + transform.actualH * 0.5
    }

    loot_system:spawn_loot_for_enemy(enemy_data.type or "unknown", position, combat_ctx)
end)

-- Clean up on level transition
signal.register("OnLevelTransition", function()
    loot_system:cleanup_all_loot()
end)
```

### API Reference

**Constructor:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `LootSystem.new(config)` | `table` | `LootSystem` | Create new loot system |

**Loot Spawning:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `spawn_loot_for_enemy(type, pos, ctx)` | `string, table, table` | - | Spawn loot from table |
| `spawn_gold(pos, amount)` | `table, number` | - | Spawn gold drops |
| `spawn_xp(pos, amount)` | `table, number` | `entity_id` | Spawn XP orb |
| `spawn_item(pos, item_type)` | `table, string` | `entity_id` | Spawn item drop |

**Management:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `cleanup_all_loot()` | - | - | Despawn all active loot |
| `despawn_loot(entity_id)` | `entity_id` | - | Despawn specific loot |

**Internal Helpers:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `get_default_loot_tables()` | - | `table` | Get built-in loot tables |
| `roll_chance(chance)` | `number` | `boolean` | Roll percentage (0-100) |
| `collect_loot(eid, type, amount)` | `entity_id, string, number` | - | Apply loot collection |

***

## Animation System

\label{recipe:animation-system}

The Animation System provides functions for creating animated entities from sprite sheets and animation definitions. It handles sprite animation playback, entity creation with visual components, and sizing utilities for both gameplay entities and UI elements.

### Creating Animated Entities

The primary function for creating entities with animations is `createAnimatedObjectWithTransform()`:

```lua
local animation_system = require("core.animation_system")

-- Create entity with animation
local entity = animation_system.createAnimatedObjectWithTransform(
    "kobold",  -- Animation ID or sprite UUID
    true,      -- true = use first param as animation ID, false = generate animation from sprite UUID
    100,       -- x position (optional, default: 0)
    200,       -- y position (optional, default: 0)
    nil,       -- shader config function (optional)
    true       -- shadow enabled (optional, default: true)
)
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `defaultAnimationIDOrSpriteUUID` | `string` | Required | Animation ID or sprite UUID |
| `generateNewAnimFromSprite` | `boolean` | `false` | `true` = use first param as animation ID, `false` = generate animation from sprite UUID |
| `x` | `number` | `0` | Initial x position |
| `y` | `number` | `0` | Initial y position |
| `shaderPassConfigFunc` | `function` | `nil` | Custom shader setup callback |
| `shadowEnabled` | `boolean` | `true` | Enable drop shadow |

> **Note:** Despite the parameter name, `generateNewAnimFromSprite=true` means "use as animation ID" (no generation), while `false` means "generate a new animation from a sprite UUID."

**What this function creates:**

- Entity with `Transform` component (position, size, rotation)
- `AnimationQueueComponent` (animation state and playback)
- `GameObject` component (interaction callbacks)
- Optional shadow entity (if `shadowEnabled = true`)

**Important:** The function automatically sets the entity's size based on the animation's first frame dimensions.

### Animation vs Sprite UUID

The second parameter determines whether to use an animation definition or create a still image from a sprite:

```lua
-- Use animation definition (animated sprite)
local animated = animation_system.createAnimatedObjectWithTransform(
    "kobold_walk",  -- Animation ID from animations.json
    true            -- Use animation
)

-- Use sprite UUID (still image)
local still = animation_system.createAnimatedObjectWithTransform(
    "sprite_uuid_12345",  -- Sprite UUID from sprite sheet
    false                 -- Generate animation from single sprite
)
```

**When to use each:**

- **Animation ID** (`true`): For animated sprites with multiple frames (characters, effects, UI animations)
- **Sprite UUID** (`false`): For static images (icons, backgrounds, single-frame objects)

### Resizing Animations

After creating an animated entity, you can resize it to fit specific dimensions:

```lua
-- Resize animation to fit target dimensions
animation_system.resizeAnimationObjectsInEntityToFit(
    entity,     -- Entity with AnimationQueueComponent
    64,         -- Target width
    64          -- Target height
)
```

**Resize behavior:**

- Preserves aspect ratio (uses smallest scale factor)
- Updates the entity's `Transform` component size
- Scales all animation objects in the entity's queue

**Example:**

```lua
local card = animation_system.createAnimatedObjectWithTransform("fire_card", true)

-- Card's original size might be 128x180
-- Resize to fit 64x64 slot (will scale proportionally)
animation_system.resizeAnimationObjectsInEntityToFit(card, 64, 64)

-- Result: Card scaled to fit 64x64, maintaining aspect ratio
local transform = component_cache.get(card, Transform)
-- transform.actualW and transform.actualH now reflect scaled size
```

### UI-Specific Resizing

For UI elements, use the centering variant:

```lua
-- Resize and center within UI bounds
animation_system.resizeAnimationObjectsInEntityToFitAndCenterUI(
    entity,          -- Entity to resize
    100,             -- Target width
    100,             -- Target height
    true,            -- Center horizontally (optional, default: true)
    true             -- Center vertically (optional, default: true)
)
```

**Use case:** When you need animations to fit precisely within UI boxes while maintaining visual centering.

### Custom Shader Configuration

Pass a shader configuration function to apply shaders during entity creation:

```lua
local entity = animation_system.createAnimatedObjectWithTransform(
    "card_glow",
    true,
    0, 0,
    function(e)  -- Shader config callback
        local ShaderBuilder = require("core.shader_builder")
        ShaderBuilder.for_entity(e)
            :add("3d_skew_holo")
            :add("glow", { intensity = 1.5 })
            :apply()
    end,
    true
)
```

**Callback receives:** The newly created entity ID.

### Integration with EntityBuilder

`EntityBuilder` uses `animation_system` internally. When you call `EntityBuilder.create()`, it delegates to `createAnimatedObjectWithTransform()`:

```lua
local EntityBuilder = require("core.entity_builder")

-- EntityBuilder wraps animation_system
local entity = EntityBuilder.create({
    sprite = "kobold",  -- Passed to createAnimatedObjectWithTransform()
    position = { x = 100, y = 200 },
    size = { 64, 64 },  -- Triggers resizeAnimationObjectsInEntityToFit()
    shadow = true
})
```

**Advantages of EntityBuilder:**

- Declarative options table (vs positional parameters)
- Automatic script table initialization
- Built-in interaction setup
- Shader application via `shaders` field

**When to use animation_system directly:**

- Fine-grained control over shader callbacks
- Custom animation object manipulation
- Performance-critical spawning (fewer abstractions)

### Still Animations from Sprites

Create a `AnimationObject` (not an entity) from a sprite UUID:

```lua
-- Create AnimationObject for use in components
local anim_obj = animation_system.createStillAnimationFromSpriteUUID(
    "sprite_uuid_12345",
    Color.WHITE,  -- Foreground tint (optional)
    Color.BLACK   -- Background tint (optional)
)

-- Use in AnimationQueueComponent
local queue = registry:get(entity, AnimationQueueComponent)
queue.defaultAnimation = anim_obj
```

**Use case:** Dynamically changing an entity's sprite without creating a new entity.

### Resetting UI Render Scale

If you've manipulated UI render scale and need to reset:

```lua
-- Reset to default intrinsic scale
animation_system.resetAnimationUIRenderScale(entity)
```

**When to use:** After applying custom `uiRenderScale` to `AnimationObject` and needing to restore defaults.

### Common Patterns

**Pattern 1: Create entity and resize**

```lua
local enemy = animation_system.createAnimatedObjectWithTransform("orc", true)
animation_system.resizeAnimationObjectsInEntityToFit(enemy, 48, 48)

local transform = component_cache.get(enemy, Transform)
transform.actualX = spawn_x
transform.actualY = spawn_y
```

**Pattern 2: UI icon with centering**

```lua
local icon = animation_system.createAnimatedObjectWithTransform("icon_sword", false)
animation_system.resizeAnimationObjectsInEntityToFitAndCenterUI(icon, 32, 32)
```

**Pattern 3: Card with shader effects**

```lua
local card = animation_system.createAnimatedObjectWithTransform(
    card_anim_id,
    true,
    0, 0,
    function(e)
        ShaderBuilder.for_entity(e):add("3d_skew_holo"):apply()
    end,
    true
)
animation_system.resizeAnimationObjectsInEntityToFit(card, CARD_WIDTH, CARD_HEIGHT)
```

### API Reference

**Entity Creation:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `createAnimatedObjectWithTransform(id, useAnim, x, y, shaderFn, shadow)` | `string, bool, num?, num?, fn?, bool?` | `entity_id` | Create animated entity |
| `createStillAnimationFromSpriteUUID(uuid, fg, bg)` | `string, Color?, Color?` | `AnimationObject` | Create still animation object |

**Resizing:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `resizeAnimationObjectsInEntityToFit(entity, w, h)` | `entity_id, number, number` | - | Resize animation to fit dimensions |
| `resizeAnimationObjectsInEntityToFitAndCenterUI(entity, w, h, centerX, centerY)` | `entity_id, num, num, bool?, bool?` | - | Resize and center for UI |
| `resetAnimationUIRenderScale(entity)` | `entity_id` | - | Reset UI scale to default |
| `resizeAnimationObjectToFit(animObj, w, h)` | `AnimationObject, number, number` | - | Resize single animation object |

**Utility:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `setFGColorForAllAnimationObjects(entity, color)` | `entity_id, Color` | - | Tint all animations in entity |
| `getNinepatchUIBorderInfo(uuid)` | `string` | `NPatchInfo, Texture2D` | Get nine-patch data for UUID |

### Gotchas

**Gotcha 1:** Don't manually emplace components created by `createAnimatedObjectWithTransform()`

```lua
-- WRONG: Components already exist!
local entity = animation_system.createAnimatedObjectWithTransform("sprite", true)
registry:emplace(entity, Transform)  -- Error: already exists!
registry:emplace(entity, GameObject) -- Error: already exists!

-- CORRECT: Just use the entity
local transform = component_cache.get(entity, Transform)
transform.actualX = 100
```

**Gotcha 2:** Resizing must happen after entity creation

```lua
-- WRONG: Entity doesn't exist yet
animation_system.resizeAnimationObjectsInEntityToFit(entity, 64, 64)
local entity = animation_system.createAnimatedObjectWithTransform("sprite", true)

-- CORRECT: Create first, then resize
local entity = animation_system.createAnimatedObjectWithTransform("sprite", true)
animation_system.resizeAnimationObjectsInEntityToFit(entity, 64, 64)
```

**Gotcha 3:** Shader callback runs during creation, not after

```lua
-- The shader callback runs BEFORE createAnimatedObjectWithTransform() returns
local entity = animation_system.createAnimatedObjectWithTransform(
    "sprite", true, 0, 0,
    function(e)
        -- e is the entity being created (partially initialized)
        -- You can safely add shaders here
        ShaderBuilder.for_entity(e):add("glow"):apply()
    end
)
-- At this point, shaders are already applied
```

***

## Physics Manager

\label{recipe:physics-manager}

The Physics Manager is a centralized system for managing multiple physics worlds, their lifecycle, and entity interactions across worlds. It provides safe access to physics worlds by name, manages stepping and debug visualization, and handles navmesh-based pathfinding. Always use `PhysicsManager.get_world("world")` instead of accessing `globals.physicsWorld` directly.

### Why Use PhysicsManager?

**Benefits over direct world access:**

- **Safety**: Returns `nil` if world doesn't exist (no crashes)
- **Multi-world support**: Manage separate physics spaces (e.g., "world", "ui_drag", "menu")
- **State binding**: Automatically pause/resume worlds based on game state
- **Debug control**: Toggle debug draw per-world
- **Migration**: Safely move entities between physics worlds

**Deprecated pattern:**

```lua
-- DON'T USE: Direct global access (unsafe, single-world)
if globals.physicsWorld then
    physics.create_physics_for_transform(globals.physicsWorld, entity, "dynamic")
end
```

**Correct pattern:**

```lua
-- USE: PhysicsManager access (safe, multi-world)
local PhysicsManager = require("core.physics_manager")
local world = PhysicsManager.get_world("world")
if world then
    -- Use world safely
end
```

### Getting a Physics World

The primary function you'll use is `get_world()`:

```lua
local PhysicsManager = require("core.physics_manager")

-- Get the main game physics world
local world = PhysicsManager.get_world("world")
if not world then
    log_warn("Physics world not available")
    return
end

-- Now use world with physics functions
physics.SetVelocity(world, entity, vx, vy)
```

**What it returns:**

- A `PhysicsWorld` userdata if the world exists and is registered
- `nil` if the world doesn't exist

**Common world names:**

- `"world"` - Main gameplay physics world (default)
- Additional worlds can be registered via `PhysicsManager.add_world()`

### Creating Physics Bodies

When creating physics bodies for entities, use the correct API signature with `PhysicsManager.get_world()`:

```lua
local PhysicsManager = require("core.physics_manager")

-- Create entity with transform
local entity = animation_system.createAnimatedObjectWithTransform("sprite", true)

-- Define physics configuration
local config = {
    shape = "circle",       -- "circle", "rectangle", "polygon", "chain"
    tag = "projectile",     -- Collision tag
    sensor = false,         -- Is sensor (no physical response)
    density = 1.0,          -- Body density
    inflate_px = 0          -- Inflate/deflate collider by pixels
}

-- Create physics body (correct signature)
physics.create_physics_for_transform(
    registry,                    -- Global registry
    physics_manager_instance,    -- Global physics_manager instance
    entity,
    "world",                     -- World name (not the world object!)
    config
)
```

**Important:** The fourth parameter is the world *name* (string), not the world object. The C++ function internally calls `PhysicsManager.get_world()`.

### Physics Sync Modes

Physics bodies can sync between Transform and physics in different modes:

```lua
-- Set sync mode using correct API
physics.set_sync_mode(registry, entity, physics.PhysicsSyncMode.AuthoritativePhysics)
```

**Available sync modes:**

| Mode | Transform → Physics | Physics → Transform | Use Case |
|------|---------------------|---------------------|----------|
| `AuthoritativePhysics` | Initial only | Every frame | Dynamic physics objects (projectiles, enemies) |
| `AuthoritativeTransform` | Every frame | Never | Kinematic objects (platforms, UI drag) |
| `Bidirectional` | Every frame | Every frame | Hybrid (rare, expensive) |

**Example: Dynamic enemy**

```lua
-- Enemy controlled by physics (AI applies forces)
physics.set_sync_mode(registry, enemy, physics.PhysicsSyncMode.AuthoritativePhysics)

-- Physics updates position, Transform reads from physics
local world = PhysicsManager.get_world("world")
physics.ApplyImpulse(world, enemy, fx, fy)
```

**Example: Draggable UI card**

```lua
-- Card position controlled by UI drag (Transform updated manually)
physics.set_sync_mode(registry, card, physics.PhysicsSyncMode.AuthoritativeTransform)

-- Transform drives physics, physics body follows
local transform = component_cache.get(card, Transform)
transform.actualX = mouseX
transform.actualY = mouseY
```

### Common Physics Operations

After getting the world, use it with physics functions:

```lua
local world = PhysicsManager.get_world("world")

-- Set velocity
physics.SetVelocity(world, entity, vx, vy)

-- Apply impulse (instant force)
physics.ApplyImpulse(world, entity, ix, iy)

-- Apply force (continuous over time)
physics.ApplyForce(world, entity, fx, fy)

-- Set physical properties
physics.SetFriction(world, entity, 0.3)
physics.SetRestitution(world, entity, 0.8)  -- Bounciness
physics.SetDensity(world, entity, 2.0)

-- Enable high-speed collision detection
physics.SetBullet(world, entity, true)

-- Lock rotation
physics.SetFixedRotation(world, entity, true)

-- Change body type
physics.SetBodyType(world, entity, "dynamic")  -- "static", "kinematic", "dynamic"
```

### Collision Masks (Per-Entity)

Collision masks determine which entities can collide. These are set **per-entity** when creating physics bodies, not globally:

```lua
local world = PhysicsManager.get_world("world")

-- Enable bidirectional collision between tags
physics.enable_collision_between_many(world, "projectile", { "enemy", "WORLD" })
physics.enable_collision_between_many(world, "enemy", { "projectile", "player" })

-- Update collision masks for all entities with these tags
physics.update_collision_masks_for(world, "projectile", { "enemy", "WORLD" })
physics.update_collision_masks_for(world, "enemy", { "projectile", "player" })
```

**Why per-entity?**

- Different projectile types can have different collision behavior
- Allows dynamic collision changes (e.g., enemy becomes intangible)
- More flexible than global collision matrices

**Common pattern:**

```lua
-- In entity creation function (not in system init)
local function spawnProjectile(x, y)
    local entity = animation_system.createAnimatedObjectWithTransform("bullet", true)

    local config = { shape = "circle", tag = "projectile" }
    physics.create_physics_for_transform(registry, physics_manager_instance, entity, "world", config)

    -- Set collision masks for this entity
    local world = PhysicsManager.get_world("world")
    physics.enable_collision_between_many(world, "projectile", { "enemy" })
    physics.update_collision_masks_for(world, "projectile", { "enemy" })

    return entity
end
```

### PhysicsBuilder Integration

`PhysicsBuilder` wraps PhysicsManager internally for fluent API:

```lua
local PhysicsBuilder = require("core.physics_builder")

-- PhysicsBuilder uses PhysicsManager.get_world() internally
PhysicsBuilder.for_entity(entity)
    :circle()
    :tag("enemy")
    :bullet()
    :syncMode("physics")
    :collideWith({ "player", "projectile" })
    :apply()
```

**When to use PhysicsBuilder vs direct API:**

- **PhysicsBuilder**: Quick setup, declarative, less boilerplate
- **Direct API**: Fine-grained control, custom collision logic, performance-critical

### Multi-World Management

PhysicsManager can manage multiple physics worlds:

```lua
-- Register a new physics world
local uiWorld = physics.create_world()
PhysicsManager.add_world("ui_drag", uiWorld, "planning")  -- Bind to "planning" state

-- Check if world exists
if PhysicsManager.has_world("ui_drag") then
    print("UI world available")
end

-- Check if world is active (step enabled + state active)
if PhysicsManager.is_world_active("ui_drag") then
    print("UI world stepping")
end

-- Toggle stepping
PhysicsManager.enable_step("ui_drag", false)  -- Pause
PhysicsManager.enable_step("ui_drag", true)   -- Resume

-- Toggle debug draw
PhysicsManager.enable_debug_draw("world", true)

-- Move entity between worlds
PhysicsManager.move_entity_to_world(entity, "ui_drag")
```

### Navmesh and Pathfinding

PhysicsManager includes integrated navmesh for pathfinding:

```lua
local world = PhysicsManager.get_world("world")

-- Configure navmesh inflation (clearance around obstacles)
PhysicsManager.set_nav_config("world", { default_inflate_px = 10 })

-- Mark entity as navmesh obstacle
PhysicsManager.set_nav_obstacle(wallEntity, true)

-- Rebuild navmesh (happens automatically, but can force)
PhysicsManager.mark_navmesh_dirty("world")
PhysicsManager.rebuild_navmesh("world")

-- Find path from (sx, sy) to (dx, dy)
local path = PhysicsManager.find_path("world", sx, sy, dx, dy)
if path then
    for i, point in ipairs(path) do
        print("Waypoint", i, point.x, point.y)
    end
end

-- Compute visibility polygon (line-of-sight)
local visiblePolygon = PhysicsManager.vision_fan("world", sx, sy, radius)
```

### API Reference

**World Access:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `get_world(name)` | `string` | `PhysicsWorld\|nil` | Get world by name |
| `has_world(name)` | `string` | `boolean` | Check if world exists |
| `is_world_active(name)` | `string` | `boolean` | Check if world is stepping |

**World Management:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `add_world(name, world, state)` | `string, PhysicsWorld, string?` | - | Register world with optional state binding |
| `enable_step(name, on)` | `string, boolean` | - | Enable/disable stepping |
| `enable_debug_draw(name, on)` | `string, boolean` | - | Enable/disable debug visualization |
| `step_all(dt)` | `number` | - | Step all active worlds |
| `draw_all()` | - | - | Debug-draw all active worlds |

**Entity Migration:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `move_entity_to_world(entity, dst)` | `entity_id, string` | - | Move entity to another world |

**Navmesh:**

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `get_nav_config(world)` | `string` | `table` | Get navmesh config |
| `set_nav_config(world, cfg)` | `string, table` | - | Set navmesh config |
| `mark_navmesh_dirty(world)` | `string` | - | Mark for rebuild |
| `rebuild_navmesh(world)` | `string` | - | Force immediate rebuild |
| `find_path(world, sx, sy, dx, dy)` | `string, num×4` | `table` | Find path (returns waypoints) |
| `vision_fan(world, sx, sy, radius)` | `string, num×3` | `table` | Compute visibility polygon |
| `set_nav_obstacle(entity, include)` | `entity_id, boolean` | - | Tag entity as obstacle |

### Common Patterns

**Pattern 1: Safe world access**

```lua
local PhysicsManager = require("core.physics_manager")

local function updateEntity(entity, dt)
    local world = PhysicsManager.get_world("world")
    if not world then return end  -- Graceful fallback

    physics.SetVelocity(world, entity, 100, 0)
end
```

**Pattern 2: Dynamic projectile with collisions**

```lua
local function spawnProjectile(owner, x, y, vx, vy)
    local entity = animation_system.createAnimatedObjectWithTransform("bullet", true)

    -- Position
    local transform = component_cache.get(entity, Transform)
    transform.actualX, transform.actualY = x, y

    -- Physics
    local config = { shape = "circle", tag = "projectile", sensor = false }
    physics.create_physics_for_transform(registry, physics_manager_instance, entity, "world", config)

    -- Sync mode
    physics.set_sync_mode(registry, entity, physics.PhysicsSyncMode.AuthoritativePhysics)

    -- Collision masks
    local world = PhysicsManager.get_world("world")
    physics.enable_collision_between_many(world, "projectile", { "enemy" })
    physics.update_collision_masks_for(world, "projectile", { "enemy" })

    -- Initial velocity
    physics.SetVelocity(world, entity, vx, vy)
    physics.SetBullet(world, entity, true)  -- Fast-moving

    return entity
end
```

**Pattern 3: AI pathfinding**

```lua
local function findPathToPlayer(enemy)
    local enemyT = component_cache.get(enemy, Transform)
    local playerT = component_cache.get(survivorEntity, Transform)

    local path = PhysicsManager.find_path(
        "world",
        enemyT.actualX, enemyT.actualY,
        playerT.actualX, playerT.actualY
    )

    if path and #path > 1 then
        local nextWaypoint = path[2]  -- [1] is start position
        return nextWaypoint.x, nextWaypoint.y
    end
    return nil
end
```

### Gotchas

**Gotcha 1:** Don't store the world reference long-term

```lua
-- WRONG: World reference can become invalid
local MySystem = {}
MySystem.world = PhysicsManager.get_world("world")  -- Cached

function MySystem.update(dt)
    physics.SetVelocity(MySystem.world, entity, vx, vy)  -- May crash if world destroyed
end

-- CORRECT: Fetch world each time (negligible overhead)
function MySystem.update(dt)
    local world = PhysicsManager.get_world("world")
    if not world then return end
    physics.SetVelocity(world, entity, vx, vy)
end
```

**Gotcha 2:** World name vs world object in `create_physics_for_transform()`

```lua
-- WRONG: Passing world object (5th param expects string)
local world = PhysicsManager.get_world("world")
physics.create_physics_for_transform(registry, physics_manager_instance, entity, world, config)

-- CORRECT: Passing world name (string)
physics.create_physics_for_transform(registry, physics_manager_instance, entity, "world", config)
```

**Gotcha 3:** Collision masks must be bidirectional

```lua
-- WRONG: Only one direction enabled
physics.enable_collision_between_many(world, "projectile", { "enemy" })
physics.update_collision_masks_for(world, "projectile", { "enemy" })
-- Result: Projectiles detect enemies, but enemies don't detect projectiles!

-- CORRECT: Enable both directions
physics.enable_collision_between_many(world, "projectile", { "enemy" })
physics.enable_collision_between_many(world, "enemy", { "projectile" })
physics.update_collision_masks_for(world, "projectile", { "enemy" })
physics.update_collision_masks_for(world, "enemy", { "projectile" })
```

***

## AI Blackboard API

\label{recipe:ai-blackboard}

The AI Blackboard is a per-entity key-value store for AI agent state and memory. It provides type-safe storage for common data types (float, int, bool, string, Vector2) and integrates with GOAP (Goal-Oriented Action Planning) systems for behavior planning. Use the blackboard to store agent state, target information, decision-making data, and any per-entity AI memory.

### What is the Blackboard?

The blackboard pattern is a shared memory system used in AI for storing and retrieving information that multiple behaviors or systems need to access. In this engine, each AI entity with a `GOAPComponent` has its own blackboard instance.

**Use cases:**

- **Target tracking**: Store current target entity, position, distance
- **State memory**: Remember last seen player position, patrol waypoints
- **Behavior flags**: Track if agent is alerted, investigating, retreating
- **Decision data**: Store calculated values used across multiple AI frames
- **Communication**: Share information between AI behaviors/actions

**Key features:**

- **Type-safe**: Separate functions for each data type prevent type errors
- **Per-entity**: Each AI agent has its own isolated blackboard
- **Optional returns**: Get functions return `nil` if key doesn't exist (safe to check)
- **GOAP integration**: Works alongside world state for planning systems

### Supported Data Types

The blackboard supports five data types:

| Type | Set Function | Get Function | Use Case |
|------|--------------|--------------|----------|
| `float` | `setBlackboardFloat()` | `getBlackboardFloat()` | Health percentages, distances, timers |
| `int` | `setBlackboardInt()` | `getBlackboardInt()` | Entity IDs, counts, enums |
| `bool` | `setBlackboardBool()` | `getBlackboardBool()` | State flags, conditions |
| `string` | `setBlackboardString()` | `getBlackboardString()` | State names, target types |
| `Vector2` | `setBlackboardVector2()` | `getBlackboardVector2()` | Positions, velocities, directions |

### Setting Values

All set functions follow the same pattern: `set[Type](entity, key, value)`

```lua
-- Store target position
setBlackboardVector2(enemyEntity, "last_seen_player_pos", { x = 100, y = 200 })

-- Store alert state
setBlackboardBool(enemyEntity, "is_alerted", true)

-- Store target entity ID
setBlackboardInt(enemyEntity, "target_entity", playerEntity)

-- Store distance to target
setBlackboardFloat(enemyEntity, "distance_to_target", 150.5)

-- Store current behavior state
setBlackboardString(enemyEntity, "behavior_state", "patrolling")
```

**Notes:**

- Entity must have a `GOAPComponent` (added when AI system is initialized)
- Setting a key that already exists will overwrite the previous value
- Keys are strings and can be any valid identifier

### Getting Values

All get functions return `nil` if the key doesn't exist, allowing safe conditional checks:

```lua
-- Check if entity has a target
local targetID = getBlackboardInt(enemyEntity, "target_entity")
if targetID then
    -- Entity has a target, use it
    local targetPos = component_cache.get(targetID, Transform)
    -- ...
end

-- Get last seen position with fallback
local lastSeenPos = getBlackboardVector2(enemyEntity, "last_seen_player_pos")
if not lastSeenPos then
    -- Never seen player, use default patrol position
    lastSeenPos = { x = 0, y = 0 }
end

-- Check alert state (defaults to false if not set)
local isAlerted = getBlackboardBool(enemyEntity, "is_alerted")
if isAlerted then
    -- Agent is alerted, play alert behavior
end

-- Get distance (with nil check)
local distance = getBlackboardFloat(enemyEntity, "distance_to_target")
if distance and distance < 50 then
    -- Close enough to attack
end
```

**Important:** Always check for `nil` when getting values, or ensure the key is always set before reading.

### Complete AI Agent Example

Combining blackboard with component access and AI logic:

```lua
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")

function updateEnemyAI(enemyEntity, dt)
    -- Validate entity
    if not entity_cache.valid(enemyEntity) then return end

    -- Get player position
    local playerEntity = getBlackboardInt(enemyEntity, "target_entity")
    if not playerEntity then
        -- No target set, enter patrol mode
        setBlackboardString(enemyEntity, "behavior_state", "patrol")
        return
    end

    -- Calculate distance to player
    local enemyTransform = component_cache.get(enemyEntity, Transform)
    local playerTransform = component_cache.get(playerEntity, Transform)

    if not enemyTransform or not playerTransform then return end

    local dx = playerTransform.actualX - enemyTransform.actualX
    local dy = playerTransform.actualY - enemyTransform.actualY
    local distance = math.sqrt(dx * dx + dy * dy)

    -- Store distance in blackboard
    setBlackboardFloat(enemyEntity, "distance_to_target", distance)

    -- Update last seen position
    setBlackboardVector2(enemyEntity, "last_seen_player_pos", {
        x = playerTransform.actualX,
        y = playerTransform.actualY
    })

    -- Behavior logic based on distance
    if distance < 50 then
        setBlackboardString(enemyEntity, "behavior_state", "attack")
        setBlackboardBool(enemyEntity, "is_alerted", true)
    elseif distance < 200 then
        setBlackboardString(enemyEntity, "behavior_state", "pursue")
        setBlackboardBool(enemyEntity, "is_alerted", true)
    else
        -- Return to patrol if player escapes
        setBlackboardString(enemyEntity, "behavior_state", "patrol")
        setBlackboardBool(enemyEntity, "is_alerted", false)
    end
end
```

### World State for GOAP Planning

The blackboard stores arbitrary data, but GOAP systems also use **world state** - boolean key-value pairs representing the state of the world and goals. Use world state for planning, blackboard for memory.

**Current World State** (what is true right now):

```lua
-- Set current state facts
setCurrentWorldStateValue(entity, "has_weapon", true)
setCurrentWorldStateValue(entity, "enemy_visible", false)
setCurrentWorldStateValue(entity, "at_cover", true)

-- Read current state
local hasWeapon = getCurrentWorldStateValue(entity, "has_weapon")  -- true/false

-- Clear all current world state
clearCurrentWorldState(entity)
```

**Goal World State** (what the agent wants to be true):

```lua
-- Set goal conditions
setGoalWorldStateValue(entity, "enemy_dead", true)
setGoalWorldStateValue(entity, "has_ammo", true)

-- Read goal state
local wantsEnemyDead = getGoalWorldStateValue(entity, "enemy_dead")  -- true/false

-- Clear all goal world state
clearGoalWorldState(entity)
```

**When to use each:**

| System | Data Type | Use Case |
|--------|-----------|----------|
| **Blackboard** | Any (float, int, bool, string, Vector2) | Agent memory, target data, calculated values |
| **Current World State** | Bool only | Facts about the world for GOAP planning |
| **Goal World State** | Bool only | Desired outcome for GOAP planner |

**GOAP integration example:**

```lua
-- Blackboard: Store where the enemy is
setBlackboardVector2(entity, "enemy_position", { x = 100, y = 200 })
setBlackboardInt(entity, "enemy_entity_id", enemyID)

-- World State: Facts for planning
setCurrentWorldStateValue(entity, "enemy_visible", true)
setCurrentWorldStateValue(entity, "has_weapon", true)
setCurrentWorldStateValue(entity, "in_range", false)

-- Goal State: What we want to achieve
setGoalWorldStateValue(entity, "enemy_dead", true)

-- GOAP planner will create action sequence to make "enemy_dead" true
-- Actions will use blackboard data (enemy position, ID) during execution
```

### Common Patterns

**Pattern 1: Target tracking**

```lua
-- Store target when acquiring
local function acquireTarget(aiEntity, targetEntity)
    setBlackboardInt(aiEntity, "target_id", targetEntity)
    setBlackboardBool(aiEntity, "has_target", true)

    local targetTransform = component_cache.get(targetEntity, Transform)
    if targetTransform then
        setBlackboardVector2(aiEntity, "target_pos", {
            x = targetTransform.actualX,
            y = targetTransform.actualY
        })
    end
end

-- Clear target when lost
local function loseTarget(aiEntity)
    setBlackboardBool(aiEntity, "has_target", false)
    -- Keep last known position for investigation
end
```

**Pattern 2: State machine with blackboard**

```lua
local function updateStateMachine(entity)
    local state = getBlackboardString(entity, "state") or "idle"

    if state == "idle" then
        -- Check for target
        if getBlackboardBool(entity, "has_target") then
            setBlackboardString(entity, "state", "chase")
        end
    elseif state == "chase" then
        local distance = getBlackboardFloat(entity, "distance_to_target")
        if distance and distance < 50 then
            setBlackboardString(entity, "state", "attack")
        elseif not getBlackboardBool(entity, "has_target") then
            setBlackboardString(entity, "state", "idle")
        end
    elseif state == "attack" then
        -- Attack logic...
    end
end
```

**Pattern 3: Behavior timers**

```lua
-- Start a timer
setBlackboardFloat(entity, "attack_cooldown", 2.0)

-- Update and check timer
local function updateTimers(entity, dt)
    local cooldown = getBlackboardFloat(entity, "attack_cooldown")
    if cooldown then
        cooldown = cooldown - dt
        if cooldown <= 0 then
            -- Cooldown finished
            setBlackboardBool(entity, "can_attack", true)
            -- Remove timer
            setBlackboardFloat(entity, "attack_cooldown", 0)
        else
            setBlackboardFloat(entity, "attack_cooldown", cooldown)
        end
    end
end
```

### Common Gotchas

**Gotcha 1:** Entity must have GOAPComponent

```lua
-- WRONG: Using blackboard on entity without GOAPComponent
local entity = registry:create()
setBlackboardInt(entity, "health", 100)  -- Crash! No GOAPComponent

-- CORRECT: Ensure entity has GOAPComponent (usually added by AI system init)
-- Or add manually:
registry:emplace(entity, GOAPComponent)
setBlackboardInt(entity, "health", 100)
```

**Gotcha 2:** Type mismatch

```lua
-- WRONG: Storing float, retrieving as int
setBlackboardFloat(entity, "value", 10.5)
local value = getBlackboardInt(entity, "value")  -- Returns nil (type mismatch)

-- CORRECT: Use matching types
setBlackboardFloat(entity, "value", 10.5)
local value = getBlackboardFloat(entity, "value")  -- Returns 10.5
```

**Gotcha 3:** Forgetting nil checks

```lua
-- WRONG: Assuming key always exists
local distance = getBlackboardFloat(entity, "distance")
if distance < 50 then  -- Crash if distance is nil!
    -- ...
end

-- CORRECT: Check for nil
local distance = getBlackboardFloat(entity, "distance")
if distance and distance < 50 then
    -- ...
end
```

**Gotcha 4:** Confusing blackboard with world state

```lua
-- WRONG: Trying to store Vector2 in world state
setCurrentWorldStateValue(entity, "position", { x = 10, y = 20 })  -- Error! Only accepts bool

-- CORRECT: Use blackboard for complex types
setBlackboardVector2(entity, "position", { x = 10, y = 20 })

-- World state is for boolean facts only
setCurrentWorldStateValue(entity, "at_position", true)
```

### Integration with AI System

The blackboard works seamlessly with the AI system documented in **Chapter 8: AI System**. While Chapter 8 covers behavior trees, GOAP planning, and AI architecture, this section focuses specifically on the data storage API.

**Quick reference:**

- **Chapter 8**: AI behavior implementation, planning algorithms, action execution
- **This section**: Data storage API for AI agents (blackboard, world state)

Use the blackboard to store data that AI behaviors need to access and modify, and world state for GOAP planning conditions.

***

## Card Discovery & Progression

\label{recipe:card-discovery}

The Card Discovery & Progression system provides roguelike meta-progression by tracking player discoveries across runs. It records tag thresholds reached, spell types cast, tag patterns encountered, and avatar unlocks. These discoveries persist between runs, creating "Balatro-style" celebration moments when players hit milestones for the first time.

### What is Tracked?

The discovery system tracks three main categories:

1. **Tag Thresholds**: When a player reaches 3/5/7/9 cards with the same tag (e.g., Fire, Defense, Mobility)
2. **Spell Types**: When a player casts specific spell patterns (e.g., "Twin Cast", "Mono-Element", "Combo Chain")
3. **Tag Patterns**: Future system for curated card combinations with special names
4. **Avatar Unlocks**: Character unlocks based on tag thresholds or gameplay metrics

All discoveries are stored persistently in `player.tag_discoveries` and can be saved/loaded between sessions.

### Discovery Journal - Viewing Discoveries

The `DiscoveryJournal` provides a UI-friendly interface to view and query all player discoveries.

**Getting organized summary:**

```lua
local DiscoveryJournal = require("wand.discovery_journal")

-- Get summary for UI display
local summary = DiscoveryJournal.getSummary(player)

-- summary.stats contains:
--   total_discoveries - Total count
--   tag_thresholds - Count of tag threshold discoveries
--   spell_types - Count of spell type discoveries
--   tag_patterns - Count of tag pattern discoveries

print("Total discoveries:", summary.stats.total_discoveries)

-- summary.tag_thresholds is an array of:
for _, discovery in ipairs(summary.tag_thresholds) do
    print(discovery.display_name)  -- e.g., "Fire x3"
    print(discovery.tag)           -- "Fire"
    print(discovery.threshold)     -- 3
    print(discovery.timestamp)     -- Unix timestamp
end

-- summary.spell_types is an array of spell type discoveries
for _, discovery in ipairs(summary.spell_types) do
    print(discovery.spell_type)    -- e.g., "Twin Cast"
    print(discovery.timestamp)
end
```

**Getting recent discoveries (for notification feed):**

```lua
-- Get last 10 discoveries
local recent = DiscoveryJournal.getRecent(player, 10)

for _, discovery in ipairs(recent) do
    if discovery.type == "tag_threshold" then
        print("Discovered:", discovery.tag, "x" .. discovery.threshold)
    elseif discovery.type == "spell_type" then
        print("Discovered:", discovery.spell_type)
    end
end
```

**Checking specific discoveries:**

```lua
-- Check if player has discovered a specific tag threshold
local hasFirex5 = DiscoveryJournal.hasDiscovered(player, "tag_threshold", "Fire", 5)

-- Check if player has discovered a spell type
local hasTwinCast = DiscoveryJournal.hasDiscovered(player, "spell_type", "Twin Cast")

-- Get completion percentage for a category
local completion = DiscoveryJournal.getCompletionPercentage(
    player,
    "tag_thresholds",
    36  -- Total possible (6 tags × 4 thresholds + 12 elements × 4)
)
print("Tag threshold completion:", completion .. "%")
```

### Tag Discovery System - Tracking Milestones

The `TagDiscoverySystem` is the underlying tracker that detects and records new discoveries. It's automatically called by the wand and tag evaluation systems.

**Manual tag threshold checking:**

```lua
local TagDiscoverySystem = require("wand.tag_discovery_system")

-- Check for new tag threshold discoveries
-- tag_counts is a table of tag -> count (e.g., { Fire = 5, Defense = 3 })
local newDiscoveries = TagDiscoverySystem.checkTagThresholds(player, tag_counts)

-- newDiscoveries is an array of newly discovered thresholds
for _, discovery in ipairs(newDiscoveries) do
    print("NEW:", discovery.tag, "x" .. discovery.threshold)
    print("Current count:", discovery.count)

    -- Signal is automatically emitted:
    -- signal.emit("tag_threshold_discovered", { tag, threshold, count })
end
```

**Spell type discovery during casting:**

```lua
-- Check if spell type is new (called by WandExecutor during cast)
local discovery = TagDiscoverySystem.checkSpellType(player, "Twin Cast")

if discovery then
    print("First time casting:", discovery.spell_type)
    -- Signal automatically emitted: signal.emit("spell_type_discovered", { spell_type })
end
```

**Discovery statistics:**

```lua
local stats = TagDiscoverySystem.getStats(player)
print("Total:", stats.total_discoveries)
print("Tag thresholds:", stats.tag_thresholds)
print("Spell types:", stats.spell_types)
print("Tag patterns:", stats.tag_patterns)
```

**Get all discoveries by type:**

```lua
-- Get all tag threshold discoveries
local thresholds = TagDiscoverySystem.getDiscoveriesByType(player, "tag_threshold")

-- Get all spell type discoveries
local spellTypes = TagDiscoverySystem.getDiscoveriesByType(player, "spell_type")
```

**Clear discoveries (for testing):**

```lua
TagDiscoverySystem.clearDiscoveries(player)
```

### Spell Type Evaluator - Identifying Patterns

The `SpellTypeEvaluator` analyzes a cast block (list of actions and modifiers) and identifies the spell pattern being cast. This is the "Poker Hand" equivalent for the wand system.

**Spell type categories:**

| Type | Description | Example |
|------|-------------|---------|
| `Simple Cast` | 1 action, no modifiers | Single fireball |
| `Twin Cast` | 1 action, multicast x2 | Two projectiles |
| `Scatter Cast` | 1 action, multicast > 2 + spread | Shotgun pattern |
| `Precision Cast` | 1 action, speed/damage mod, no spread | Sniper shot |
| `Rapid Fire` | 1 action, low cast delay | Machine gun |
| `Mono-Element` | 3+ actions, same element | All Fire spells |
| `Combo Chain` | 3+ actions, different types | Fire + Ice + Lightning |
| `Heavy Barrage` | 3+ actions, high cost/damage | Expensive spell combo |
| `Chaos Cast` | Fallback for undefined patterns | Mixed/unusual combos |

**Evaluating spell types:**

```lua
local SpellTypeEvaluator = require("wand.spell_type_evaluator")

-- Cast block from wand execution
local block = {
    actions = {
        { id = "FIREBALL", tags = { "Fire", "Projectile" }, mana_cost = 10 },
        { id = "ICE_SHARD", tags = { "Ice", "Projectile" }, mana_cost = 8 }
    },
    modifiers = {
        multicastCount = 1,
        projectile_speed_multiplier = 1.0,
        damage_multiplier = 1.5,
        cast_delay_multiplier = 1.0
    }
}

local spellType = SpellTypeEvaluator.evaluate(block)
print("Spell type:", spellType)  -- e.g., "Combo Chain"

-- Check for discovery
TagDiscoverySystem.checkSpellType(player, spellType)
```

**Analyzing tag composition:**

```lua
-- Get detailed tag metrics for the cast
local tagAnalysis = SpellTypeEvaluator.analyzeTags(block.actions)

print("Primary tag:", tagAnalysis.primary_tag)        -- Most common tag
print("Primary count:", tagAnalysis.primary_count)    -- How many times
print("Diversity:", tagAnalysis.diversity)            -- Number of distinct tags
print("Total tags:", tagAnalysis.total_tags)          -- Total tag instances

-- Threshold flags for joker reactions
if tagAnalysis.is_tag_heavy then
    print("3+ actions with same tag!")
end

if tagAnalysis.is_mono_tag then
    print("All actions share one tag!")
end

if tagAnalysis.is_diverse then
    print("3+ different tag types!")
end
```

### Card Synergy System - Set Bonuses

The `CardSynergy` system detects tag-based sets and curated combos, applying bonuses when thresholds are met. This works alongside the discovery system.

**Detecting active sets:**

```lua
local CardSynergy = require("wand.card_synergy_system")

-- Detect tag counts from card list
local cardList = {
    { id = "FIREBALL", tags = { "Fire", "Projectile" } },
    { id = "FLAME_WALL", tags = { "Fire", "Hazard" } },
    { id = "INFERNO", tags = { "Fire", "AoE" } }
}

local tagCounts = CardSynergy.detectSets(cardList)
-- Returns: { Fire = 3, Projectile = 1, Hazard = 1, AoE = 1 }

-- Get active bonuses (thresholds: 3, 6, 9)
local activeBonuses = CardSynergy.getActiveBonuses(tagCounts)

for tagName, bonusData in pairs(activeBonuses) do
    print("Active:", tagName, "tier", bonusData.tier)
    print("Description:", bonusData.bonus.description)
end
```

**Getting bonus info for UI:**

```lua
local bonusInfo = CardSynergy.getActiveBonusInfo(tagCounts)

for _, info in ipairs(bonusInfo) do
    print(info.displayName)   -- "Mobility"
    print(info.tier)          -- 3, 6, or 9
    print(info.count)         -- Actual card count
    print(info.description)   -- "Swift Caster I: +10% cast speed, ..."
    print(info.color)         -- "#4A90E2"
    print(info.icon)          -- "icon_mobility"
end
```

**Checking progress to next tier:**

```lua
local nextThreshold, cardsNeeded = CardSynergy.getProgressToNextTier("Fire", 4)
if nextThreshold then
    print("Need", cardsNeeded, "more Fire cards to reach tier", nextThreshold)
else
    print("Already at max tier!")
end
```

**Detecting curated combos:**

```lua
-- Check for specific card combinations
local activeCombos = CardSynergy.detectCuratedCombos(cardList)

for _, comboId in ipairs(activeCombos) do
    local comboDef = CardSynergy.curatedCombos[comboId]
    print("Active combo:", comboDef.name)
    print("Effect:", comboDef.description)
end
```

### Avatar System - Character Unlocks

The `AvatarSystem` tracks unlock progress for playable avatars based on tag thresholds and gameplay metrics.

**Checking unlocks:**

```lua
local AvatarSystem = require("wand.avatar_system")

-- Check for new unlocks (called when deck changes or metrics update)
local newUnlocks = AvatarSystem.check_unlocks(player, {
    tag_counts = { Fire = 7, Defense = 5 },  -- Optional tag counts
    metrics = { kills = 100, wins = 5 }      -- Optional metrics (falls back to player.avatar_progress)
})

-- newUnlocks is an array of avatar IDs
for _, avatarId in ipairs(newUnlocks) do
    print("Unlocked avatar:", avatarId)
    -- Signal automatically emitted: signal.emit("avatar_unlocked", { avatar_id })
end
```

**Recording progress:**

```lua
-- Increment a metric and check for unlocks
local newUnlocks = AvatarSystem.record_progress(
    player,
    "kills_with_fire",  -- Metric name
    1,                  -- Delta (amount to add)
    { tag_counts = player.tag_counts }  -- Optional context
)
```

**Equipping avatars:**

```lua
-- Equip an already-unlocked avatar
local success, error = AvatarSystem.equip(player, "fire_mage")

if not success then
    print("Cannot equip:", error)  -- "avatar_locked"
end

-- Get currently equipped avatar
local equippedId = AvatarSystem.get_equipped(player)
if equippedId then
    print("Playing as:", equippedId)
end
```

**Avatar unlock conditions (data-driven):**

Avatars are defined in `assets/scripts/data/avatars.lua` with unlock conditions:

```lua
-- Example avatar definition
fire_mage = {
    id = "fire_mage",
    name = "Fire Mage",
    unlock = {
        fire_tags = 7,           -- Primary condition: 7+ Fire tags
        OR_wins = 3              -- Alternative: 3 wins
    }
}

-- Unlock logic:
-- - Primary path: ALL non-OR conditions must be met
-- - Alternative path: ANY OR_ condition is sufficient
-- Player unlocks if (primary_path OR alternative_path)
```

### Events Emitted

The discovery and progression systems emit signals for UI notifications:

| Event | Parameters | When Emitted |
|-------|------------|--------------|
| `"tag_threshold_discovered"` | `{ tag, threshold, count }` | First time reaching tag threshold |
| `"spell_type_discovered"` | `{ spell_type }` | First time casting spell type |
| `"tag_pattern_discovered"` | `{ pattern_id, pattern_name }` | First time encountering tag pattern |
| `"avatar_unlocked"` | `{ avatar_id }` | Avatar unlock conditions met |

**Listening to events:**

```lua
local signal = require("external.hump.signal")

signal.register("tag_threshold_discovered", function(data)
    print("NEW DISCOVERY:", data.tag, "x" .. data.threshold)
    print("You now have", data.count, data.tag, "cards!")
    -- Show celebration UI
end)

signal.register("spell_type_discovered", function(data)
    print("NEW SPELL TYPE:", data.spell_type)
    -- Show tutorial or achievement
end)

signal.register("avatar_unlocked", function(data)
    print("AVATAR UNLOCKED:", data.avatar_id)
    -- Show unlock animation
end)
```

### Persistence - Save/Load

**Exporting discoveries for save file:**

```lua
-- Get all discoveries in save-friendly format
local saveData = DiscoveryJournal.exportForSave(player)

-- saveData is a table that can be serialized to JSON/file
-- Structure: { ["tag_Fire_3"] = { type, tag, threshold, timestamp }, ... }
```

**Importing discoveries from save file:**

```lua
-- Load discoveries from save data
DiscoveryJournal.importFromSave(player, saveData)

-- Player's tag_discoveries table is now populated
```

**Avatar progress persistence:**

```lua
-- Avatar state is stored in player.avatar_state:
player.avatar_state = {
    unlocked = { fire_mage = true, ice_mage = true },
    equipped = "fire_mage"
}

-- Avatar progress metrics in player.avatar_progress:
player.avatar_progress = {
    kills_with_fire = 50,
    wins = 3,
    distance_traveled = 1000
}
```

### Integration Example - Complete Flow

```lua
local TagDiscoverySystem = require("wand.tag_discovery_system")
local DiscoveryJournal = require("wand.discovery_journal")
local CardSynergy = require("wand.card_synergy_system")
local AvatarSystem = require("wand.avatar_system")
local signal = require("external.hump.signal")

-- Called when player's deck changes
function onDeckChanged(player, cardList)
    -- Detect tag counts
    local tagCounts = CardSynergy.detectSets(cardList)

    -- Check for new tag threshold discoveries
    local newThresholds = TagDiscoverySystem.checkTagThresholds(player, tagCounts)

    -- Check for avatar unlocks
    local newAvatars = AvatarSystem.check_unlocks(player, {
        tag_counts = tagCounts
    })

    -- Apply set bonuses
    CardSynergy.applySetBonuses(player, tagCounts)

    -- Update UI with discoveries
    local summary = DiscoveryJournal.getSummary(player)
    updateDiscoveryUI(summary)
end

-- Called during wand execution
function onSpellCast(player, castBlock)
    -- Evaluate spell type
    local SpellTypeEvaluator = require("wand.spell_type_evaluator")
    local spellType = SpellTypeEvaluator.evaluate(castBlock)

    -- Check for spell type discovery
    local discovery = TagDiscoverySystem.checkSpellType(player, spellType)

    if discovery then
        -- First time casting this spell type!
        signal.emit("spell_type_discovered", discovery)
    end
end

-- Listen for discovery events
signal.register("tag_threshold_discovered", function(data)
    -- Show celebration popup
    showDiscoveryPopup(string.format("%s x%d Discovered!", data.tag, data.threshold))
end)

signal.register("avatar_unlocked", function(data)
    showAvatarUnlockAnimation(data.avatar_id)
end)
```

### Common Patterns

**Pattern 1: Discovery notification feed**

```lua
-- Show recent discoveries in UI
local function updateDiscoveryFeed(player)
    local recent = DiscoveryJournal.getRecent(player, 5)

    for i, discovery in ipairs(recent) do
        local text = ""
        if discovery.type == "tag_threshold" then
            text = string.format("%s x%d", discovery.tag, discovery.threshold)
        elseif discovery.type == "spell_type" then
            text = discovery.spell_type
        end

        displayNotification(text, discovery.timestamp)
    end
end
```

**Pattern 2: Progress bar to next tier**

```lua
-- Show progress to next Fire tag tier
local function getTagProgress(tagCounts, tagName)
    local count = tagCounts[tagName] or 0
    local nextThreshold, needed = CardSynergy.getProgressToNextTier(tagName, count)

    if nextThreshold then
        return {
            current = count,
            next = nextThreshold,
            progress = count / nextThreshold,
            cardsNeeded = needed
        }
    else
        return { maxed = true }
    end
end
```

**Pattern 3: First-time tutorial triggers**

```lua
-- Show tutorial when player discovers certain spell types
signal.register("spell_type_discovered", function(data)
    if data.spell_type == "Twin Cast" then
        showTutorial("multicast_modifiers")
    elseif data.spell_type == "Mono-Element" then
        showTutorial("elemental_synergy")
    end
end)
```

### Common Gotchas

**Gotcha 1:** Discovery tracking requires player table with tag_discoveries

```lua
-- WRONG: Using entity ID directly
local discoveries = TagDiscoverySystem.checkTagThresholds(playerEntityID, tagCounts)

-- CORRECT: Pass player table (script table or entity with discoveries)
local player = getScriptTableFromEntityID(playerEntityID)
local discoveries = TagDiscoverySystem.checkTagThresholds(player, tagCounts)
```

**Gotcha 2:** Tag thresholds are 3/5/7/9 by default

```lua
-- These thresholds trigger discoveries:
-- 3, 5, 7, 9 (defined in TagDiscoverySystem.DISCOVERY_THRESHOLDS)

-- If you have 4 Fire cards, only the x3 discovery triggers
-- You need 5 cards for the next discovery
```

**Gotcha 3:** Discoveries are persistent - never discovered twice

```lua
-- Once discovered, won't trigger again
TagDiscoverySystem.checkTagThresholds(player, { Fire = 5 })  -- Discovers Fire x3, Fire x5
TagDiscoverySystem.checkTagThresholds(player, { Fire = 5 })  -- Returns empty array

-- To reset for testing:
TagDiscoverySystem.clearDiscoveries(player)
```

**Gotcha 4:** Spell type evaluation requires properly formatted block

```lua
-- WRONG: Missing required fields
local block = { actions = { card1, card2 } }
local spellType = SpellTypeEvaluator.evaluate(block)  -- May return nil or "Chaos Cast"

-- CORRECT: Include modifiers aggregate
local block = {
    actions = { card1, card2 },
    modifiers = {
        multicastCount = 1,
        projectile_speed_multiplier = 1.0,
        damage_multiplier = 1.0,
        cast_delay_multiplier = 1.0
    }
}
```

### Related Systems

- **Tag Evaluator** (`wand.tag_evaluator`): Calculates tag bonuses at thresholds (documented in CLAUDE.md)
- **Wand Executor** (`wand.wand_executor`): Executes spell casts and calls spell type evaluation
- **Joker System** (`wand.joker_system`): Reacts to tag counts and spell types (Chapter 10)
- **Card Registry** (`wand.card_registry`): Card definitions with tags (Chapter 10)

***

## Input System

\label{recipe:input-system}

The Input System provides a flexible action-binding framework for keyboard, mouse, and gamepad input. Instead of hardcoding specific keys, you bind **actions** (like "Jump", "Attack", "Menu") to input devices with triggers (Pressed, Released, Held) and poll them in your game logic. This allows for remapping, context switching (gameplay vs menu), and unified input handling.

### Action Binding - Mapping Inputs to Actions

The core workflow is:
1. **Bind** an action name to a device + key/button/axis + trigger type + context
2. **Poll** the action state in your game loop using `input.action_pressed()`, `input.action_down()`, etc.

**Basic binding examples:**

```lua
-- Keyboard bindings
input.bind("jump", {
    device = "keyboard",
    key = KeyboardKey.KEY_SPACE,
    trigger = "Pressed",
    context = "gameplay"
})

input.bind("move_left", {
    device = "keyboard",
    key = KeyboardKey.KEY_A,
    trigger = "Held",
    context = "gameplay"
})

-- Mouse bindings
input.bind("shoot", {
    device = "mouse",
    key = MouseButton.BUTTON_LEFT,
    trigger = "Pressed",
    context = "gameplay"
})

-- Gamepad button bindings
input.bind("confirm", {
    device = "gamepad_button",
    key = GamepadButton.GAMEPAD_BUTTON_RIGHT_FACE_DOWN,  -- A on Xbox, Cross on PS
    trigger = "Pressed",
    context = "menu"
})

-- Gamepad axis bindings (for analog sticks)
input.bind("move_right", {
    device = "gamepad_axis",
    axis = GamepadAxis.GAMEPAD_AXIS_LEFT_X,
    trigger = "AxisPos",
    threshold = 0.2,  -- Deadzone
    context = "gameplay"
})

input.bind("move_left", {
    device = "gamepad_axis",
    axis = GamepadAxis.GAMEPAD_AXIS_LEFT_X,
    trigger = "AxisNeg",
    threshold = 0.2,
    context = "gameplay"
})
```

**Binding options:**

| Field | Type | Description |
|-------|------|-------------|
| `device` | string | `"keyboard"`, `"mouse"`, `"gamepad_button"`, `"gamepad_axis"` |
| `key` | enum | `KeyboardKey.*`, `MouseButton.*`, `GamepadButton.*` (for non-axis devices) |
| `axis` | enum | `GamepadAxis.*` (for `gamepad_axis` device) |
| `trigger` | string | `"Pressed"`, `"Released"`, `"Held"`, `"Repeat"`, `"AxisPos"`, `"AxisNeg"` |
| `threshold` | number | Deadzone for axis triggers (default: 0.5) |
| `context` | string | Context name (default: `"global"`) - see Context Switching below |
| `modifiers` | table | Optional modifier keys (keyboard only), e.g., `{ KeyboardKey.KEY_LEFT_SHIFT }` |

### Polling Input - Checking Action State

After binding, poll actions in your update loop:

```lua
local timer = require("core.timer")

-- Poll every frame
timer.every(0.016, function()
    -- Check if action was pressed THIS FRAME (one-frame pulse)
    if input.action_pressed("jump") then
        player.velocity.y = -500
        print("Player jumped!")
    end

    -- Check if action is held down (continuous)
    if input.action_down("move_left") then
        player.position.x -= 200 * dt
    end

    -- Check if action was released THIS FRAME
    if input.action_released("shoot") then
        print("Released trigger")
    end

    -- Get analog axis value (for gamepad axes)
    local moveX = input.action_value("move_right") + input.action_value("move_left")
    player.position.x += moveX * 200 * dt
end)
```

**Polling functions:**

| Function | Returns | Description |
|----------|---------|-------------|
| `input.action_pressed(name)` | boolean | True for ONE FRAME when action is pressed |
| `input.action_released(name)` | boolean | True for ONE FRAME when action is released |
| `input.action_down(name)` | boolean | True while action is held (latched from press to release) |
| `input.action_value(name)` | number | Axis value (for analog inputs), resets each frame |

### Trigger Types - Edge Detection vs Continuous

Triggers control when a binding fires:

| Trigger | Behavior | Use Case |
|---------|----------|----------|
| `"Pressed"` | Fires once on press, latches `down=true` | Jump, single actions |
| `"Released"` | Fires once on release | Charge attacks, release timing |
| `"Held"` | Fires continuously while held | Movement, continuous actions |
| `"Repeat"` | Placeholder for auto-repeat | Not yet implemented |
| `"AxisPos"` | Fires when axis > threshold | Analog stick right/up |
| `"AxisNeg"` | Fires when axis < -threshold | Analog stick left/down |

**Important lifecycle:** `Pressed` trigger sets both `pressed=true` (one frame) AND `down=true` (latched). Use `action_pressed()` for single-frame detection, `action_down()` for held state.

### Context Switching - Gameplay vs Menu

Contexts allow different bindings for different game states (e.g., "gameplay", "menu", "inventory").

```lua
-- Bind same key to different actions in different contexts
input.bind("confirm", {
    device = "keyboard",
    key = KeyboardKey.KEY_ENTER,
    trigger = "Pressed",
    context = "menu"
})

input.bind("interact", {
    device = "keyboard",
    key = KeyboardKey.KEY_ENTER,
    trigger = "Pressed",
    context = "gameplay"
})

-- Switch context at runtime
input.set_context("gameplay")  -- Only "gameplay" bindings active

-- Later, switch to menu
input.set_context("menu")      -- Only "menu" bindings active
```

**Context rules:**
- Only bindings matching the **active context** OR `"global"` context are evaluated
- Use `"global"` for bindings that should work everywhere (e.g., pause, screenshot)
- Default context is `"global"`

### Key and Button Constants

The engine exposes Raylib enums for all input devices:

**Keyboard keys:** `KeyboardKey.KEY_*`

```lua
-- Letter keys
KeyboardKey.KEY_A, KEY_B, ..., KEY_Z

-- Number keys
KeyboardKey.KEY_ZERO, KEY_ONE, ..., KEY_NINE

-- Special keys
KeyboardKey.KEY_SPACE, KEY_ENTER, KEY_ESCAPE, KEY_TAB, KEY_BACKSPACE

-- Arrow keys
KeyboardKey.KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT

-- Function keys
KeyboardKey.KEY_F1, KEY_F2, ..., KEY_F12

-- Modifier keys
KeyboardKey.KEY_LEFT_SHIFT, KEY_RIGHT_SHIFT, KEY_LEFT_CONTROL, KEY_RIGHT_CONTROL
KeyboardKey.KEY_LEFT_ALT, KEY_RIGHT_ALT, KEY_LEFT_SUPER, KEY_RIGHT_SUPER
```

**Mouse buttons:** `MouseButton.BUTTON_*`

```lua
MouseButton.BUTTON_LEFT
MouseButton.BUTTON_RIGHT
MouseButton.BUTTON_MIDDLE
MouseButton.BUTTON_SIDE      -- Side button (forward)
MouseButton.BUTTON_EXTRA     -- Extra button (back)
```

**Gamepad buttons:** `GamepadButton.GAMEPAD_BUTTON_*`

```lua
-- Face buttons (Xbox layout)
GamepadButton.GAMEPAD_BUTTON_RIGHT_FACE_DOWN   -- A
GamepadButton.GAMEPAD_BUTTON_RIGHT_FACE_RIGHT  -- B
GamepadButton.GAMEPAD_BUTTON_RIGHT_FACE_LEFT   -- X
GamepadButton.GAMEPAD_BUTTON_RIGHT_FACE_UP     -- Y

-- D-Pad
GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_UP, ..._DOWN, ..._LEFT, ..._RIGHT

-- Shoulder buttons
GamepadButton.GAMEPAD_BUTTON_LEFT_TRIGGER_1    -- LB
GamepadButton.GAMEPAD_BUTTON_RIGHT_TRIGGER_1   -- RB
GamepadButton.GAMEPAD_BUTTON_LEFT_TRIGGER_2    -- LT
GamepadButton.GAMEPAD_BUTTON_RIGHT_TRIGGER_2   -- RT

-- Menu buttons
GamepadButton.GAMEPAD_BUTTON_MIDDLE_LEFT       -- Back/Select
GamepadButton.GAMEPAD_BUTTON_MIDDLE_RIGHT      -- Start
GamepadButton.GAMEPAD_BUTTON_MIDDLE            -- Guide/Home
```

**Gamepad axes:** `GamepadAxis.GAMEPAD_AXIS_*`

```lua
GamepadAxis.GAMEPAD_AXIS_LEFT_X
GamepadAxis.GAMEPAD_AXIS_LEFT_Y
GamepadAxis.GAMEPAD_AXIS_RIGHT_X
GamepadAxis.GAMEPAD_AXIS_RIGHT_Y
GamepadAxis.GAMEPAD_AXIS_LEFT_TRIGGER    -- LT analog (0 to 1)
GamepadAxis.GAMEPAD_AXIS_RIGHT_TRIGGER   -- RT analog (0 to 1)
```

### Legacy Input - Direct Key Polling

For simple cases, you can check keys directly (not recommended for production):

```lua
-- Check if a key is pressed THIS FRAME
if isKeyPressed("W") then
    print("W key pressed!")
end

-- Note: Case-insensitive, uses magic_enum conversion
-- Returns boolean
```

**Why use action bindings instead?**
- Remappable controls
- Context-aware (menu vs gameplay)
- Unified gamepad + keyboard support
- Works with modifiers and chords

### Input Remapping - Runtime Rebinding

Allow players to remap controls:

```lua
-- Start listening for next input
input.start_rebind("jump", function(ok, binding)
    if ok then
        print("Rebound jump to:", binding.device, binding.code, binding.trigger)
        -- binding contains: { device, code, trigger, context, modifiers }
        -- Save to config file
    else
        print("Rebind cancelled")
    end
end)

-- While listening, the next raw input (key/button/axis) will:
-- 1. Populate the binding table with device/code/trigger
-- 2. Call the callback with ok=true
```

### Common Patterns

**Pattern 1: WASD + Gamepad movement**

```lua
-- Keyboard WASD
input.bind("move_up",    { device = "keyboard", key = KeyboardKey.KEY_W, trigger = "Held" })
input.bind("move_down",  { device = "keyboard", key = KeyboardKey.KEY_S, trigger = "Held" })
input.bind("move_left",  { device = "keyboard", key = KeyboardKey.KEY_A, trigger = "Held" })
input.bind("move_right", { device = "keyboard", key = KeyboardKey.KEY_D, trigger = "Held" })

-- Gamepad left stick
input.bind("move_up",    { device = "gamepad_axis", axis = GamepadAxis.GAMEPAD_AXIS_LEFT_Y, trigger = "AxisNeg", threshold = 0.2 })
input.bind("move_down",  { device = "gamepad_axis", axis = GamepadAxis.GAMEPAD_AXIS_LEFT_Y, trigger = "AxisPos", threshold = 0.2 })
input.bind("move_left",  { device = "gamepad_axis", axis = GamepadAxis.GAMEPAD_AXIS_LEFT_X, trigger = "AxisNeg", threshold = 0.2 })
input.bind("move_right", { device = "gamepad_axis", axis = GamepadAxis.GAMEPAD_AXIS_LEFT_X, trigger = "AxisPos", threshold = 0.2 })

-- Poll in update
local function updateMovement(dt)
    local dx = 0
    local dy = 0

    if input.action_down("move_right") then dx += 1 end
    if input.action_down("move_left")  then dx -= 1 end
    if input.action_down("move_down")  then dy += 1 end
    if input.action_down("move_up")    then dy -= 1 end

    -- For analog, add axis values
    dx += input.action_value("move_right") + input.action_value("move_left")
    dy += input.action_value("move_down") + input.action_value("move_up")

    player.position.x += dx * 200 * dt
    player.position.y += dy * 200 * dt
end
```

**Pattern 2: Context-aware pause menu**

```lua
-- Pause works in gameplay, ESC works in menu
input.bind("pause", { device = "keyboard", key = KeyboardKey.KEY_ESCAPE, trigger = "Pressed", context = "gameplay" })
input.bind("back",  { device = "keyboard", key = KeyboardKey.KEY_ESCAPE, trigger = "Pressed", context = "menu" })

-- Switch contexts when toggling pause
local paused = false

if input.action_pressed("pause") then
    paused = true
    input.set_context("menu")
    showPauseMenu()
end

if input.action_pressed("back") then
    paused = false
    input.set_context("gameplay")
    hidePauseMenu()
end
```

**Pattern 3: Charge attack with release timing**

```lua
input.bind("attack_start", { device = "mouse", key = MouseButton.BUTTON_LEFT, trigger = "Pressed" })
input.bind("attack_release", { device = "mouse", key = MouseButton.BUTTON_LEFT, trigger = "Released" })

local charge_time = 0

timer.every(0.016, function(dt)
    -- Track how long button is held
    if input.action_down("attack_start") then
        charge_time += dt
    end

    -- Release to fire charged attack
    if input.action_released("attack_release") then
        local damage = 10 + (charge_time * 50)  -- More damage for longer charge
        fireProjectile(damage)
        charge_time = 0
    end
end)
```

### Accessing InputState (Advanced)

For advanced use cases, you can access the global InputState:

```lua
local inputState = globals.inputState

-- Cursor position (world coordinates)
local cursorPos = inputState.cursor_position
print("Mouse at:", cursorPos.x, cursorPos.y)

-- Check which entity is under cursor
local hoveredEntity = inputState.cursor_hovering_target

-- Check key/button states directly (not recommended - use actions instead)
local pressedKeys = inputState.keysPressedThisFrame
local heldKeys = inputState.keysHeldThisFrame
local releasedKeys = inputState.keysReleasedThisFrame
```

### Common Gotchas

**Gotcha 1:** `action_pressed` vs `action_down`

```lua
-- WRONG: Using action_pressed for held movement
if input.action_pressed("move_left") then
    player.x -= 5  -- Only moves ONE FRAME when key is pressed!
end

-- CORRECT: Use action_down for continuous actions
if input.action_down("move_left") then
    player.x -= 5  -- Moves every frame while held
end
```

**Gotcha 2:** Forgetting to set context

```lua
-- Bind with "gameplay" context
input.bind("jump", { device = "keyboard", key = KeyboardKey.KEY_SPACE, context = "gameplay" })

-- WRONG: Polling without setting context (defaults to "global")
if input.action_pressed("jump") then  -- Won't work! Context mismatch
    player.jump()
end

-- CORRECT: Set context first
input.set_context("gameplay")
if input.action_pressed("jump") then  -- Now it works
    player.jump()
end

-- OR: Use "global" context for always-active bindings
input.bind("jump", { device = "keyboard", key = KeyboardKey.KEY_SPACE, context = "global" })
```

**Gotcha 3:** Axis triggers require proper threshold

```lua
-- WRONG: Axis trigger with no threshold (uses default 0.5)
input.bind("move_right", { device = "gamepad_axis", axis = GamepadAxis.GAMEPAD_AXIS_LEFT_X, trigger = "AxisPos" })
-- May feel sluggish - requires >50% stick movement

-- CORRECT: Lower threshold for responsive controls
input.bind("move_right", { device = "gamepad_axis", axis = GamepadAxis.GAMEPAD_AXIS_LEFT_X, trigger = "AxisPos", threshold = 0.15 })
```

**Gotcha 4:** Input polling before binding

```lua
-- WRONG: Polling before binding exists
if input.action_pressed("jump") then  -- Returns false, no error
    player.jump()
end
input.bind("jump", { device = "keyboard", key = KeyboardKey.KEY_SPACE })  -- Too late!

-- CORRECT: Bind during initialization, poll during gameplay
function init()
    input.bind("jump", { device = "keyboard", key = KeyboardKey.KEY_SPACE, context = "gameplay" })
    input.set_context("gameplay")
end

function update(dt)
    if input.action_pressed("jump") then
        player.jump()
    end
end
```

### Related Systems

- **Controller Navigation** (`src/systems/input/controller_nav.cpp`): UI focus and navigation
- **Text Input** (`input.HookTextInput()`, `input.UnhookTextInput()`): Text field input
- **Input Action Binding Documentation** (`src/systems/input/input_action_binding_usage.md`): Full C++ API reference

### See Also

For detailed action binding usage (including mouse wheel as pseudo-axis, modifiers, chording), see `src/systems/input/input_action_binding_usage.md`.

***

## Game Control

\label{recipe:game-control}

The Game Control API provides essential functions for managing game lifecycle: pausing/unpausing gameplay and resetting game state. These are low-level functions exposed directly from C++ for controlling the game loop and AI systems.

### Pausing and Unpausing

The engine provides simple pause/unpause functions that control the game's update loop. When paused, gameplay updates stop but rendering continues (useful for pause menus).

```lua
-- Pause the game
pauseGame()

-- Resume the game
unpauseGame()
```

**Behavior:**
- `pauseGame()` sets `game::isPaused = true`, halting gameplay updates
- `unpauseGame()` sets `game::isPaused = false`, resuming normal updates
- Rendering and UI continue to work while paused
- No return value (void functions)

### Hard Reset

The `hardReset()` function requests a full reset of the AI system state. This is useful for clearing all AI state and starting fresh.

```lua
-- Reset the AI system
hardReset()
```

**Important:** This only resets the AI system (`ai_system::requestAISystemReset()`). For full game resets, you may need to manually reset other systems (physics, entities, etc.).

### Common Patterns

**Pattern 1: Pause menu with input context switching**

```lua
local paused = false

-- Bind pause key (works in gameplay context)
input.bind("pause", {
    device = "keyboard",
    key = KeyboardKey.KEY_ESCAPE,
    trigger = "Pressed",
    context = "gameplay"
})

-- Bind resume key (works in menu context)
input.bind("resume", {
    device = "keyboard",
    key = KeyboardKey.KEY_ESCAPE,
    trigger = "Pressed",
    context = "menu"
})

-- Toggle pause state
timer.every(0.016, function()
    if input.action_pressed("pause") and not paused then
        pauseGame()
        paused = true
        input.set_context("menu")
        showPauseMenu()
    end

    if input.action_pressed("resume") and paused then
        unpauseGame()
        paused = false
        input.set_context("gameplay")
        hidePauseMenu()
    end
end)
```

**Pattern 2: Conditional pause (only pause if not already paused)**

```lua
local function togglePause()
    if paused then
        unpauseGame()
        paused = false
    else
        pauseGame()
        paused = true
    end
end
```

**Pattern 3: Reset game state on player death**

```lua
local signal = require("external.hump.signal")

signal.register("player_death", function()
    -- Pause the game
    pauseGame()

    -- Show death screen
    showDeathScreen()

    -- Reset AI after delay
    timer.after(2.0, function()
        hardReset()
        -- Additional cleanup...
        unpauseGame()
    end)
end)
```

### API Reference

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `pauseGame()` | None | nil | Pauses gameplay updates |
| `unpauseGame()` | None | nil | Resumes gameplay updates |
| `hardReset()` | None | nil | Resets AI system state |

### Implementation Details

These functions are thin wrappers around C++ game state:

```cpp
// From scripting_functions.cpp
auto pauseGame() -> void {
  game::isPaused = true;
  SPDLOG_INFO("Game paused.");
}

auto unpauseGame() -> void {
  game::isPaused = false;
  SPDLOG_INFO("Game unpaused.");
}

// hardReset calls:
ai_system::requestAISystemReset();
```

### Related Systems

- **Input System** (Recipe \pageref{recipe:input-system}): Use input contexts to handle pause/resume input
- **Timer System** (Recipe \pageref{recipe:timer-system}): Timers respect pause state
- **Signal System**: Emit custom events when pausing/resuming for UI updates

***

## Screen & Camera Globals

\label{recipe:screen-camera}

The engine provides global functions for querying screen dimensions, timing information, and coordinate transformations between world and screen space. These are essential for UI positioning, camera-relative rendering, and input handling.

### Screen Dimensions

Get the virtual screen resolution (independent of actual window size):

```lua
local width = GetScreenWidth()   -- Returns virtual width (e.g., 1280)
local height = GetScreenHeight() -- Returns virtual height (e.g., 720)

-- Center UI element on screen
local centerX = width / 2
local centerY = height / 2
```

**Note:** These return `globals::VIRTUAL_WIDTH` and `globals::VIRTUAL_HEIGHT`, not the physical window dimensions. The engine handles scaling to match the actual window.

### Timing Functions

Access frame timing and total elapsed time:

```lua
-- Delta time since last frame (smoothed)
local dt = GetFrameTime()  -- Returns seconds (e.g., 0.016 for 60 FPS)

-- Total elapsed time since game start
local elapsed = GetTime()  -- Returns seconds

-- Example: animate entity with delta time
local speed = 100  -- pixels per second
transform.actualX = transform.actualX + (speed * dt)
```

**Timing Details:**
- `GetFrameTime()` returns smoothed delta time from `main_loop::mainLoop.smoothedDeltaTime`
- `GetTime()` returns total elapsed time from `main_loop::getTime()`
- Both return `float` values in seconds

### Camera Access

The global camera is available via `globals.camera`:

```lua
-- Access camera properties
local cam = globals.camera

-- Read camera state
print("Offset:", cam.offset.x, cam.offset.y)     -- Camera displacement from target
print("Target:", cam.target.x, cam.target.y)     -- Camera focus point
print("Rotation:", cam.rotation)                 -- Rotation in degrees
print("Zoom:", cam.zoom)                          -- Zoom level (1.0 = default)

-- Modify camera (example: shake effect)
cam.offset.x = math.random(-5, 5)
cam.offset.y = math.random(-5, 5)
```

**Camera2D Fields:**
| Field | Type | Description |
|-------|------|-------------|
| `offset` | Vector2 | Camera offset (displacement from target) |
| `target` | Vector2 | Camera target (rotation and zoom origin) |
| `rotation` | number | Camera rotation in degrees |
| `zoom` | number | Camera zoom (1.0 = default scale) |

### Coordinate Conversion

Convert between world coordinates (game space) and screen coordinates (pixel space):

```lua
local cam = globals.camera

-- World to screen (e.g., render world entity label at screen position)
local worldPos = { x = 500, y = 300 }
local screenPos = GetWorldToScreen2D(worldPos, cam)
print("Screen position:", screenPos.x, screenPos.y)

-- Screen to world (e.g., convert mouse click to world position)
local mouseX, mouseY = GetMousePosition()
local mouseScreen = { x = mouseX, y = mouseY }
local mouseWorld = GetScreenToWorld2D(mouseScreen, cam)
print("World position:", mouseWorld.x, mouseWorld.y)
```

**Use Cases:**
- **World to Screen:** Render UI elements at entity positions, draw health bars above characters
- **Screen to World:** Handle mouse input in world space, place entities at cursor position

### Common Patterns

**Pattern 1: Center UI element on screen**

```lua
local width = GetScreenWidth()
local height = GetScreenHeight()

local boxWidth = 200
local boxHeight = 100

-- Center the box
local x = (width - boxWidth) / 2
local y = (height - boxHeight) / 2

-- Spawn UI at centered position
dsl.spawn({ x = x, y = y }, myUIDefinition)
```

**Pattern 2: Mouse position in world coordinates**

```lua
local function getMouseWorldPosition()
    local mouseX, mouseY = GetMousePosition()
    local mouseScreen = { x = mouseX, y = mouseY }
    return GetScreenToWorld2D(mouseScreen, globals.camera)
end

-- Use in click handler
local worldPos = getMouseWorldPosition()
print("Clicked world position:", worldPos.x, worldPos.y)
```

**Pattern 3: Render text at entity position (world to screen)**

```lua
local function drawEntityLabel(entity, text)
    local transform = component_cache.get(entity, Transform)
    if not transform then return end

    -- Convert entity world position to screen coordinates
    local worldPos = { x = transform.actualX, y = transform.actualY }
    local screenPos = GetWorldToScreen2D(worldPos, globals.camera)

    -- Draw text at screen position
    draw.textPro(UI_LAYER, {
        text = text,
        x = screenPos.x,
        y = screenPos.y - 20,  -- Offset above entity
        fontSize = 16
    }, z_orders.UI)
end
```

**Pattern 4: Smooth camera follow**

```lua
local function updateCamera(playerEntity, dt)
    local transform = component_cache.get(playerEntity, Transform)
    if not transform then return end

    local cam = globals.camera
    local targetX = transform.actualX
    local targetY = transform.actualY

    -- Smooth lerp (adjust 0.1 for smoothing factor)
    local lerpFactor = 1.0 - math.exp(-10 * dt)
    cam.target.x = cam.target.x + (targetX - cam.target.x) * lerpFactor
    cam.target.y = cam.target.y + (targetY - cam.target.y) * lerpFactor
end
```

**Pattern 5: Screen-shake effect**

```lua
local function screenShake(duration, intensity)
    local shakeTimer = 0

    timer.every(0.016, function(dt)
        shakeTimer = shakeTimer + dt
        if shakeTimer >= duration then
            -- Reset camera offset
            globals.camera.offset.x = 0
            globals.camera.offset.y = 0
            return false  -- Stop timer
        end

        -- Apply random offset
        local factor = 1.0 - (shakeTimer / duration)  -- Decay over time
        globals.camera.offset.x = (math.random() * 2 - 1) * intensity * factor
        globals.camera.offset.y = (math.random() * 2 - 1) * intensity * factor
    end)
end

-- Trigger shake on impact
signal.register("player_hit", function()
    screenShake(0.3, 10)  -- 0.3 seconds, intensity 10
end)
```

### API Reference

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `GetScreenWidth()` | None | integer | Virtual screen width in pixels |
| `GetScreenHeight()` | None | integer | Virtual screen height in pixels |
| `GetFrameTime()` | None | number | Smoothed delta time since last frame (seconds) |
| `GetTime()` | None | number | Total elapsed time since game start (seconds) |
| `GetWorldToScreen2D()` | position: Vector2, camera: Camera2D | Vector2 | Convert world position to screen coordinates |
| `GetScreenToWorld2D()` | position: Vector2, camera: Camera2D | Vector2 | Convert screen position to world coordinates |

**Global:**
| Global | Type | Description |
|--------|------|-------------|
| `globals.camera` | Camera2D | Main camera instance (offset, target, rotation, zoom) |

### Implementation Details

These functions are exposed from C++ via the scripting system:

```cpp
// From scripting_functions.cpp
lua["GetScreenWidth"] = []() -> int { return globals::VIRTUAL_WIDTH; };
lua["GetScreenHeight"] = []() -> int { return globals::VIRTUAL_HEIGHT; };

lua["GetFrameTime"] = []() -> float {
    return main_loop::mainLoop.smoothedDeltaTime;
};

lua["GetTime"] = []() -> float {
    return main_loop::getTime();
};

lua["GetWorldToScreen2D"] = [](Vector2 position, Camera2D camera) -> Vector2 {
    return GetWorldToScreen2D(position, camera);
};

lua["GetScreenToWorld2D"] = [](Vector2 position, Camera2D camera) -> Vector2 {
    return GetScreenToWorld2D(position, camera);
};

// Camera binding (static Camera2D instance)
lua["globals"]["camera"] = []() -> Camera2D & { return std::ref(camera2D); };
```

### Related Systems

- **Input System** (Recipe \pageref{recipe:input-system}): Use `GetScreenToWorld2D()` for mouse input in world space
- **UI DSL** (Recipe \pageref{recipe:ui-dsl}): Use screen dimensions for positioning UI elements
- **Timer System** (Recipe \pageref{recipe:timer-system}): Use `GetFrameTime()` for smooth animations

***

## Entity Alias System

\label{recipe:entity-alias}

The entity alias system provides named lookups for important entities, allowing you to retrieve entities by string identifiers instead of storing entity handles globally. This is useful for referencing key entities like the player, boss enemies, or UI containers across different systems.

### Setting an Alias

Assign a string alias to an entity using `setEntityAlias()`:

```lua
-- Create player entity
local player = animation_system.createAnimatedObjectWithTransform("player_sprite", true)

-- Assign alias for later retrieval
setEntityAlias("player", player)

-- Alias a boss entity
local boss = createBossEnemy()
setEntityAlias("current_boss", boss)

-- Alias UI container
local inventoryUI = createInventoryPanel()
setEntityAlias("inventory_panel", inventoryUI)
```

**Function Signature:**
```lua
setEntityAlias(alias, entity)
-- alias: string - The name to use for lookup
-- entity: Entity - The entity to alias (must be valid)
```

**Validation:** The function validates that the entity is valid before setting the alias. Invalid or null entities will log an error and be rejected.

### Getting Entity by Alias

Retrieve an entity by its alias using `getEntityByAlias()`:

```lua
-- Retrieve player entity from anywhere in code
local player = getEntityByAlias("player")
if player ~= entt_null then
    local transform = component_cache.get(player, Transform)
    print("Player position:", transform.actualX, transform.actualY)
end

-- Check if boss exists
local boss = getEntityByAlias("current_boss")
if boss == entt_null then
    print("No boss currently active")
else
    -- Boss exists, do something
    applyDamage(boss, 100)
end
```

**Function Signature:**
```lua
local entity = getEntityByAlias(alias)
-- alias: string - The alias to look up
-- Returns: Entity - The aliased entity, or entt_null if not found
```

**Note:** `getEntityByAlias()` returns `entt_null` if the alias doesn't exist. Always check the result before using.

### Common Patterns

**Player Entity:**
```lua
-- Set player alias during initialization
function initPlayer()
    local player = createPlayerEntity()
    setEntityAlias("player", player)
    return player
end

-- Retrieve player from any system
function damagePlayer(amount)
    local player = getEntityByAlias("player")
    if ensure_entity(player) then
        applyDamage(player, amount)
    end
end
```

**Boss Entity:**
```lua
-- Set boss alias when spawning
function spawnBoss(bossType)
    local boss = createBossEntity(bossType)
    setEntityAlias("current_boss", boss)
    signal.emit("boss_spawned", boss)
end

-- Clear boss alias when defeated
signal.register("boss_defeated", function(bossEntity)
    -- Alias still points to dead entity, can be overwritten
    -- or you can set it to null to indicate no boss
    local currentBoss = getEntityByAlias("current_boss")
    if currentBoss == bossEntity then
        -- No API to remove alias, but it will be overwritten by next boss
        print("Current boss defeated")
    end
end)
```

**UI Containers:**
```lua
-- Alias UI panels for cross-system access
function createGameUI()
    local healthBar = createHealthBarPanel()
    setEntityAlias("ui_healthbar", healthBar)

    local inventory = createInventoryPanel()
    setEntityAlias("ui_inventory", inventory)

    local minimap = createMinimapPanel()
    setEntityAlias("ui_minimap", minimap)
end

-- Update UI from any system
function updateHealthDisplay(currentHealth, maxHealth)
    local healthBar = getEntityByAlias("ui_healthbar")
    if ensure_entity(healthBar) then
        local script = getScriptTableFromEntityID(healthBar)
        if script then
            script.currentHealth = currentHealth
            script.maxHealth = maxHealth
        end
    end
end
```

### Lifecycle Considerations

**Entity Destruction:**
- The alias map does NOT automatically remove aliases when entities are destroyed
- If an aliased entity is destroyed, the alias will point to an invalid entity
- Always validate entities returned from `getEntityByAlias()` using `ensure_entity()` or `entity_cache.valid()`

```lua
-- Safe usage pattern
local boss = getEntityByAlias("current_boss")
if ensure_entity(boss) then
    -- Entity exists and is valid
    applyDamage(boss, 50)
else
    -- Entity was destroyed or alias doesn't exist
    print("No valid boss entity")
end
```

**Alias Reuse:**
- Aliases can be reassigned by calling `setEntityAlias()` with the same alias name
- This is useful for "current_boss" or "active_npc" patterns where the entity changes

```lua
-- First boss
local boss1 = spawnBoss("goblin_king")
setEntityAlias("current_boss", boss1)

-- Later, after boss1 is defeated, spawn new boss
local boss2 = spawnBoss("dragon")
setEntityAlias("current_boss", boss2)  -- Overwrites previous alias
```

### API Reference

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `setEntityAlias()` | alias: string, entity: Entity | nil | Assigns a string alias to a valid entity |
| `getEntityByAlias()` | alias: string | Entity \| nil | Retrieves entity by alias, returns `entt_null` if not found |

### Related Systems

- **Entity Validation** (Recipe \pageref{recipe:validate-entity}): Use `ensure_entity()` to validate aliased entities
- **Component Cache** (Recipe \pageref{recipe:component-cache}): Access components on aliased entities
- **Signal System** (Recipe \pageref{recipe:signal-system}): Emit events when important aliased entities change

***

## Avatar System
\label{recipe:avatar-system}

The **Avatar System** manages character unlocks and selection through a lightweight, data-driven framework. Avatars are powerful character transformations unlocked mid-run by meeting specific conditions (tag thresholds, gameplay metrics). This section covers the runtime API for tracking progress, checking unlocks, and equipping avatars.

For avatar data format and unlock condition syntax, see Chapter 9, Section "Avatar System - Character Unlocks".

### Core Concepts

**State Storage:**
- Player entities store avatar state in `player.avatar_state` table:
  - `unlocked`: Table of `avatar_id -> true` for unlocked avatars
  - `equipped`: Currently equipped avatar ID (or `nil`)
- Progress metrics stored in `player.avatar_progress` (e.g., `kills_with_fire`, `damage_blocked`)

**Unlock Conditions:**
- Defined in `assets/scripts/data/avatars.lua` with dual-path logic:
  - **Primary path**: All non-OR conditions must be met
  - **Alternative path**: Any `OR_` prefixed condition is sufficient
- Conditions can reference tag counts (`fire_tags`) or metrics (`kills_with_fire`)

### Checking for Unlocks

Use `AvatarSystem.check_unlocks()` to evaluate unlock conditions and update state:

```lua
local AvatarSystem = require("wand.avatar_system")

-- Check unlocks with current player state
local newlyUnlocked = AvatarSystem.check_unlocks(player)

-- Check with explicit context (overrides player state)
local newlyUnlocked = AvatarSystem.check_unlocks(player, {
    tag_counts = { Fire = 7, Defense = 5 },
    metrics = { kills_with_fire = 100, damage_blocked = 5000 }
})

-- Process newly unlocked avatars
for _, avatarId in ipairs(newlyUnlocked) do
    print("Unlocked:", avatarId)
    -- Signal "avatar_unlocked" automatically emitted for each unlock
end
```

**When to call:**
- After deck changes (tag counts may have changed)
- After significant gameplay events (boss kill, level up)
- Periodically during gameplay (if tracking distance, time, etc.)

### Recording Progress

Increment progress metrics and automatically check for unlocks:

```lua
-- Record progress for a specific metric
local newlyUnlocked = AvatarSystem.record_progress(
    player,
    "kills_with_fire",  -- Metric name
    1                   -- Delta (increment by 1)
)

-- With explicit tag counts for unlock check
local newlyUnlocked = AvatarSystem.record_progress(
    player,
    "damage_blocked",
    250,  -- Blocked 250 damage
    { tag_counts = player.tag_counts }
)
```

**Common metrics:**
- `kills_with_fire`, `kills_with_ice`, etc. (elemental kills)
- `damage_blocked` (total damage blocked)
- `distance_moved` (movement distance)
- `crits_dealt` (critical hit count)
- `mana_spent` (total mana used)
- `hp_lost` (damage taken)

### Equipping Avatars

Players can equip unlocked avatars to activate their effects:

```lua
-- Equip an avatar (must be already unlocked)
local success, error = AvatarSystem.equip(player, "wildfire")

if not success then
    print("Cannot equip:", error)  -- "avatar_locked" if not unlocked
else
    print("Avatar equipped!")
end

-- Get currently equipped avatar
local equippedId = AvatarSystem.get_equipped(player)
if equippedId then
    print("Playing as:", equippedId)

    -- Load avatar definition to apply effects
    local avatarDefs = require("data.avatars")
    local avatarDef = avatarDefs[equippedId]

    if avatarDef and avatarDef.effects then
        -- Apply avatar effects to player stats/rules
        -- (Effect application is game-specific implementation)
    end
end
```

### Unlock Condition Logic

Avatar unlock conditions support flexible dual-path logic:

```lua
-- Example avatar definition (from data/avatars.lua)
wildfire = {
    name = "Avatar of Wildfire",
    unlock = {
        kills_with_fire = 100,  -- Primary: must have 100 fire kills
        OR_fire_tags = 7        -- Alternative: OR have 7 Fire tags
    },
    effects = { ... }
}

-- Unlock evaluation:
-- 1. Primary path: kills_with_fire >= 100
-- 2. Alternative path: fire_tags >= 7
-- Player unlocks if EITHER path is satisfied
```

**Condition types:**
- **Tag-based**: `fire_tags`, `defense_tags`, `mobility_tags`, etc.
  - Tag name extracted from `{tag}_tags` pattern
  - Matched against `tag_counts` parameter (e.g., `Fire`, `Defense`)
- **Metric-based**: `kills_with_fire`, `damage_blocked`, `distance_moved`, etc.
  - Matched against `metrics` parameter or `player.avatar_progress`
- **OR conditions**: Prefix with `OR_` for alternative unlock paths
  - `OR_fire_tags`, `OR_wins`, etc.

### Events

The Avatar System emits signals when avatars are unlocked:

```lua
local signal = require("external.hump.signal")

-- Listen for avatar unlocks
signal.register("avatar_unlocked", function(data)
    local avatarId = data.avatar_id
    print("AVATAR UNLOCKED:", avatarId)

    -- Load definition to show name
    local avatarDefs = require("data.avatars")
    local avatarDef = avatarDefs[avatarId]
    if avatarDef then
        print("Name:", avatarDef.name)
        print("Description:", avatarDef.description)
    end

    -- Show celebration UI, achievement notification, etc.
end)
```

**Event payload:**
- `avatar_unlocked`: `{ avatar_id = "wildfire" }`

### API Reference

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `AvatarSystem.check_unlocks()` | player: table, opts?: table | string[] | Evaluates unlock conditions, updates state, returns newly unlocked avatar IDs |
| `AvatarSystem.record_progress()` | player: table, metric: string, delta: number, opts?: table | string[] | Increments progress metric, calls `check_unlocks()` |
| `AvatarSystem.equip()` | player: table, avatar_id: string | boolean, string? | Equips an unlocked avatar, returns `(success, error)` |
| `AvatarSystem.get_equipped()` | player: table | string? | Returns currently equipped avatar ID or `nil` |

**Options table (opts):**
- `tag_counts`: `table<string, number>` - Tag counts to use for unlock evaluation (overrides player state)
- `metrics`: `table<string, number>` - Metrics to use for unlock evaluation (overrides `player.avatar_progress`)

### Integration Example

Complete example showing avatar system integration in a game loop:

```lua
local AvatarSystem = require("wand.avatar_system")
local signal = require("external.hump.signal")

-- Initialize player state (done once at game start)
function initPlayer(player)
    player.avatar_state = { unlocked = {}, equipped = nil }
    player.avatar_progress = {}
    player.tag_counts = {}
end

-- Track gameplay events
function onEnemyKilled(enemy, damageType)
    local player = getPlayer()

    -- Record metric for kill
    local metricName = "kills_with_" .. string.lower(damageType)
    local newUnlocks = AvatarSystem.record_progress(
        player,
        metricName,
        1,
        { tag_counts = player.tag_counts }
    )

    -- New unlocks automatically trigger "avatar_unlocked" signal
end

-- Re-check unlocks when deck changes
function onDeckChanged(player, newTagCounts)
    player.tag_counts = newTagCounts
    local newUnlocks = AvatarSystem.check_unlocks(player, {
        tag_counts = newTagCounts
    })
end

-- Avatar selection UI callback
function onAvatarSelected(avatarId)
    local player = getPlayer()
    local success, error = AvatarSystem.equip(player, avatarId)

    if success then
        -- Apply avatar effects
        applyAvatarEffects(player, avatarId)
    else
        showError("Avatar locked!")
    end
end
```

### Related Systems

- **Chapter 9** (Avatar Data Definitions): Data format, unlock condition syntax, effects structure
- **Signal System** (Recipe \pageref{recipe:signal-system}): Event handling for unlocks
- **Tag Evaluator** (Recipe \pageref{recipe:tag-evaluator}): Tag counting and threshold tracking

***

## Combat State Machine
\label{recipe:combat-state-machine}

The **Combat State Machine** orchestrates the combat loop, managing transitions between wave phases, handling victory/defeat conditions, and coordinating with the Wave Manager. It provides a structured framework for multi-wave encounters with automatic progression and event-driven state changes.

This system is part of the Entity Lifecycle & Combat Loop Framework. For wave configuration and enemy spawning, see the Wave Manager documentation.

### Core Concepts

**State Flow:**
The combat state machine follows this progression:
1. **INIT** - Initial state before combat begins
2. **WAVE_START** - Initialize wave, prepare systems
3. **SPAWNING** - Enemies being spawned
4. **COMBAT** - Active battle phase
5. **VICTORY** - Wave cleared, calculate rewards
6. **INTERMISSION** - Between waves, prepare for next
7. **DEFEAT** / **GAME_WON** / **GAME_OVER** - Terminal states

**Integration Points:**
- **Wave Manager**: Tracks wave progression, enemy counts, rewards
- **Event Bus**: Emits state change events (`OnCombatStateChanged`, `OnCombatStart`, etc.)
- **Timer System**: Manages automatic state transitions with delays
- **Player Health**: Monitors defeat conditions

### Creating a State Machine

Use `CombatStateMachine.new()` to create an instance with callbacks and configuration:

```lua
local CombatStateMachine = require("combat.combat_state_machine")

local stateMachine = CombatStateMachine.new({
    wave_manager = waveManager,           -- WaveManager instance
    combat_context = combatContext,       -- Event bus container
    player_entity = playerEntity,         -- Player entity ID

    -- State callbacks
    on_wave_start = function(wave_number)
        print("Wave", wave_number, "starting!")
        showWaveUI(wave_number)
    end,

    on_combat_start = function()
        print("Combat phase begun!")
    end,

    on_victory = function(wave_stats)
        print("Wave complete! XP:", wave_stats.total_xp)
        displayRewards(wave_stats)
    end,

    on_defeat = function()
        print("Player defeated!")
        showGameOverScreen()
    end,

    on_intermission = function(next_wave)
        print("Intermission. Next wave:", next_wave)
    end,

    on_game_won = function(total_stats)
        print("All waves complete! Total kills:", total_stats.total_enemies_killed)
    end,

    -- Condition checkers
    is_player_alive = function()
        local hp = getBlackboardFloat(playerEntity, "health")
        return hp and hp > 0
    end,

    -- Auto-progress timings
    victory_delay = 2.0,           -- Delay before intermission (default: 2.0)
    intermission_duration = 5.0,   -- Auto-start next wave after 5s (default: 5.0, 0 = manual)
    defeat_delay = 2.0             -- Delay before game over (default: 2.0)
})
```

**Configuration Options:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `wave_manager` | WaveManager | Yes | Wave manager instance |
| `combat_context` | table | Yes | Must have `.bus` field with event emitter |
| `player_entity` | Entity | Yes | Player entity ID for health checks |
| `on_wave_start` | function(wave_number) | No | Called when wave initializes |
| `on_combat_start` | function() | No | Called when COMBAT state begins |
| `on_victory` | function(wave_stats) | No | Called when wave is cleared |
| `on_defeat` | function() | No | Called when player dies |
| `on_intermission` | function(next_wave) | No | Called between waves |
| `on_game_won` | function(total_stats) | No | Called when all waves complete |
| `is_player_alive` | function() -> boolean | No | Health check function (default: always returns true) |
| `victory_delay` | number | No | Seconds before transitioning to intermission (default: 2.0) |
| `intermission_duration` | number | No | Seconds before auto-starting next wave (0 = manual, default: 5.0) |
| `defeat_delay` | number | No | Seconds before game over screen (default: 2.0) |

### Running the State Machine

Start the machine and update it every frame:

```lua
-- Start combat (transitions to WAVE_START)
stateMachine:start()

-- Update every frame (place in game loop)
function update(dt)
    stateMachine:update(dt)
end
```

**State Transitions:**
The state machine automatically handles transitions based on conditions:
- **WAVE_START → SPAWNING**: After 0.5s delay
- **SPAWNING → COMBAT**: When `wave_manager.spawner.spawn_complete` is true
- **COMBAT → VICTORY**: When `wave_manager:is_wave_complete()` is true
- **COMBAT → DEFEAT**: When `is_player_alive()` returns false
- **VICTORY → INTERMISSION**: After `victory_delay` seconds (if more waves exist)
- **VICTORY → GAME_WON**: After `victory_delay` seconds (if no more waves)
- **INTERMISSION → WAVE_START**: After `intermission_duration` seconds (or manual trigger)
- **DEFEAT → GAME_OVER**: After `defeat_delay` seconds

### State Management

Query and control the current state:

```lua
-- Get current state
local currentState = stateMachine:get_current_state()
print(currentState)  -- "COMBAT", "VICTORY", etc.

-- Check if in specific state
if stateMachine:is_in_state(stateMachine.States.COMBAT) then
    print("Battle is active!")
end

-- Get time in current state
local stateTime = stateMachine:get_state_time()
print("In current state for", stateTime, "seconds")

-- Available state constants
local States = CombatStateMachine.States
-- States.INIT, States.WAVE_START, States.SPAWNING, States.COMBAT,
-- States.VICTORY, States.INTERMISSION, States.DEFEAT,
-- States.GAME_WON, States.GAME_OVER
```

### Manual Controls

Control state machine execution and progression:

```lua
-- Pause combat (stops update loop)
stateMachine:pause()

-- Resume combat
stateMachine:resume()

-- Stop combat (halts execution, cancels timers)
stateMachine:stop()

-- Reset to initial state
stateMachine:reset()

-- Manually progress to next wave (from INTERMISSION state)
local success = stateMachine:progress_to_next_wave()
if success then
    print("Starting next wave now!")
else
    print("Cannot progress - not in intermission state")
end

-- Retry current wave (from DEFEAT or GAME_OVER state)
local success = stateMachine:retry_wave()
if success then
    print("Retrying wave...")
end
```

**Use Cases:**
- **pause()/resume()**: Menu overlay, cutscene, inventory screen
- **progress_to_next_wave()**: "Ready!" button to skip intermission timer
- **retry_wave()**: "Try Again" button after defeat

### Event System Integration

The state machine emits events through the combat context's event bus:

```lua
-- Setup event listeners before starting combat
local bus = combatContext.bus

-- Listen for state changes
bus:on("OnCombatStateChanged", function(event)
    print("State:", event.from, "→", event.to)

    -- React to specific transitions
    if event.to == "COMBAT" then
        playBattleMusic()
    elseif event.to == "INTERMISSION" then
        pauseBattleMusic()
    end
end)

-- Combat start event
bus:on("OnCombatStart", function(event)
    print("Combat started! Wave:", event.wave_number)
end)

-- Combat end event (emitted for both victory and defeat)
bus:on("OnCombatEnd", function(event)
    if event.victory then
        print("Victory! Stats:", event.stats)
    else
        print("Defeat on wave:", event.wave_number)
    end
end)

-- Player death event (emitted during DEFEAT transition)
bus:on("OnPlayerDeath", function(event)
    print("Player entity died:", event.player)
    spawnDeathAnimation(event.player)
end)

-- Intermission event
bus:on("OnIntermission", function(event)
    print("Preparing for wave", event.next_wave)
    showIntermissionUI(event.next_wave)
end)
```

**Event Payloads:**

| Event | Payload Fields | Description |
|-------|---------------|-------------|
| `OnCombatStateChanged` | `from`, `to` | State transition (state names as strings) |
| `OnCombatStart` | `wave_number` | Combat phase started |
| `OnCombatEnd` | `victory` (bool), `stats` or `wave_number` | Combat ended (victory or defeat) |
| `OnPlayerDeath` | `player` (entity) | Player entity died |
| `OnIntermission` | `next_wave` (number) | Between waves |

### Complete Integration Example

Full example showing combat loop setup with state machine:

```lua
local CombatStateMachine = require("combat.combat_state_machine")
local WaveManager = require("combat.wave_manager")

-- Create event bus
local eventBus = {
    listeners = {},
    on = function(self, event, callback)
        self.listeners[event] = self.listeners[event] or {}
        table.insert(self.listeners[event], callback)
    end,
    emit = function(self, event, data)
        if self.listeners[event] then
            for _, callback in ipairs(self.listeners[event]) do
                callback(data)
            end
        end
    end
}

local combatContext = { bus = eventBus }

-- Define waves
local waves = {
    { wave_number = 1, type = "instant", enemies = { {type = "kobold", count = 5} } },
    { wave_number = 2, type = "instant", enemies = { {type = "kobold", count = 8} } }
}

-- Create wave manager
local waveManager = WaveManager.new({
    waves = waves,
    combat_context = combatContext,
    entity_factory_fn = create_ai_entity
})

-- Create state machine
local stateMachine = CombatStateMachine.new({
    wave_manager = waveManager,
    combat_context = combatContext,
    player_entity = playerEntity,

    on_wave_start = function(wave_number)
        print("=== Wave", wave_number, "===")
    end,

    on_victory = function(stats)
        print("Wave clear! Rewards: XP", stats.total_xp, "/ Gold", stats.total_gold)
    end,

    on_defeat = function()
        print("Game Over!")
    end,

    on_game_won = function(total_stats)
        print("Victory! Total waves:", total_stats.waves_completed)
    end,

    is_player_alive = function()
        local hp = getBlackboardFloat(playerEntity, "health")
        return hp and hp > 0
    end,

    intermission_duration = 3.0  -- 3 second break between waves
})

-- Setup event listeners
eventBus:on("OnCombatStateChanged", function(event)
    print("State:", event.from, "→", event.to)
end)

eventBus:on("OnEntityDeath", function(event)
    -- Track enemy deaths in wave manager
    waveManager:on_enemy_death(event.entity)
end)

-- Start combat
stateMachine:start()

-- Update loop
function update(dt)
    stateMachine:update(dt)
end
```

### Common Patterns

**Intermission UI with Manual Progression:**

```lua
-- Set intermission_duration = 0 to disable auto-start
local stateMachine = CombatStateMachine.new({
    -- ...
    intermission_duration = 0,  -- Manual progression only

    on_intermission = function(next_wave)
        showIntermissionUI(next_wave, function()
            -- "Ready!" button callback
            stateMachine:progress_to_next_wave()
        end)
    end
})
```

**Defeat with Retry:**

```lua
local stateMachine = CombatStateMachine.new({
    -- ...
    on_defeat = function()
        showDefeatScreen({
            onRetry = function()
                stateMachine:retry_wave()
            end,
            onQuit = function()
                returnToMainMenu()
            end
        })
    end
})
```

**Boss Wave with Custom State Logic:**

```lua
-- Listen for state changes to implement boss phase transitions
eventBus:on("OnCombatStateChanged", function(event)
    if event.to == "COMBAT" then
        local wave = waveManager:get_current_wave_number()
        if wave == 5 then  -- Boss wave
            spawnBossEntity()
            playBossMusic()
        end
    end
end)
```

**Conditional Victory Bonuses:**

```lua
local stateMachine = CombatStateMachine.new({
    -- ...
    on_victory = function(stats)
        -- Perfect clear bonus
        if stats.perfect_clear then
            grantPerfectBonus(stats.perfect_bonus)
        end

        -- Speed bonus
        if stats.duration < stats.target_time then
            local timeBonus = calculateSpeedBonus(stats)
            grantSpeedBonus(timeBonus)
        end
    end
})
```

### API Reference

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `CombatStateMachine.new()` | config: table | CombatStateMachine | Creates new state machine instance |
| `:start()` | - | - | Start combat (transition to WAVE_START) |
| `:update()` | dt: number | - | Update state machine (call every frame) |
| `:pause()` | - | - | Pause execution (stops update loop) |
| `:resume()` | - | - | Resume execution |
| `:stop()` | - | - | Stop combat (halt execution, cancel timers) |
| `:reset()` | - | - | Reset to INIT state |
| `:get_current_state()` | - | string | Returns current state name |
| `:is_in_state()` | state: string | boolean | Check if in specific state |
| `:get_state_time()` | - | number | Seconds in current state |
| `:progress_to_next_wave()` | - | boolean | Manually start next wave from intermission |
| `:retry_wave()` | - | boolean | Retry current wave from defeat/game over |

### State Constants

Access state constants via `CombatStateMachine.States`:

```lua
local States = CombatStateMachine.States

States.INIT           -- Initial state
States.WAVE_START     -- Wave initialization
States.SPAWNING       -- Enemies spawning
States.COMBAT         -- Active combat
States.VICTORY        -- Wave cleared
States.INTERMISSION   -- Between waves
States.DEFEAT         -- Player death
States.GAME_WON       -- All waves complete
States.GAME_OVER      -- Final defeat state
```

### Related Systems

- **Wave Manager**: Manages wave progression, enemy tracking, reward calculation
- **Combat Loop Integration** (`combat.combat_loop_integration`): High-level wrapper combining state machine, wave manager, and loot system
- **Signal System** (Recipe \pageref{recipe:signal-system}): Alternative event handling approach
- **Timer System** (Recipe \pageref{recipe:timer-system}): Used internally for state transitions

***

\newpage
\appendix

# Appendix A: Function Index

\label{appendix:function-index}

Alphabetical listing of all documented functions and APIs.

| Function | Module | Recipe |
|----------|--------|--------|
| `add_state_tag()` | `util.lua` | \pageref{recipe:validate-entity} |
| `animation_system.createAnimatedObjectWithTransform()` | `core.animation_system` | \pageref{recipe:animation-system} |
| `animation_system.createStillAnimationFromSpriteUUID()` | `core.animation_system` | \pageref{recipe:animation-system} |
| `animation_system.resizeAnimationObjectsInEntityToFit()` | `core.animation_system` | \pageref{recipe:animation-system} |
| `animation_system.resizeAnimationObjectsInEntityToFitAndCenterUI()` | `core.animation_system` | \pageref{recipe:animation-system} |
| `behaviors.apply()` | `core.behaviors` | \pageref{recipe:enemy-behaviors} |
| `behaviors.cleanup()` | `core.behaviors` | \pageref{recipe:enemy-behaviors} |
| `behaviors.is_registered()` | `core.behaviors` | \pageref{recipe:enemy-behaviors} |
| `behaviors.list()` | `core.behaviors` | \pageref{recipe:enemy-behaviors} |
| `behaviors.register()` | `core.behaviors` | \pageref{recipe:enemy-behaviors} |
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
| `Equipment.<id>` | `data.equipment` | \pageref{recipe:define-equipment} |
| `getScriptTableFromEntityID()` | `util.lua` | \pageref{recipe:script-table} |
| `GetFrameTime()` | Global | \pageref{recipe:screen-camera} |
| `GetScreenHeight()` | Global | \pageref{recipe:screen-camera} |
| `GetScreenToWorld2D()` | Global | \pageref{recipe:screen-camera} |
| `GetScreenWidth()` | Global | \pageref{recipe:screen-camera} |
| `GetTime()` | Global | \pageref{recipe:screen-camera} |
| `GetWorldToScreen2D()` | Global | \pageref{recipe:screen-camera} |
| `globals.camera` | Global | \pageref{recipe:screen-camera} |
| `hardReset()` | Global | \pageref{recipe:game-control} |
| `hitfx.flash()` | `core.hitfx` | \pageref{recipe:hitfx} |
| `hitfx.flash_start()` | `core.hitfx` | \pageref{recipe:hitfx} |
| `hitfx.flash_stop()` | `core.hitfx` | \pageref{recipe:hitfx} |
| `is_state_active()` | `util.lua` | \pageref{recipe:validate-entity} |
| `JokerSystem.add_joker()` | `wand.joker_system` | \pageref{recipe:joker-manage} |
| `JokerSystem.clear_jokers()` | `wand.joker_system` | \pageref{recipe:joker-manage} |
| `JokerSystem.definitions` | `wand.joker_system` | \pageref{recipe:joker-define} |
| `JokerSystem.remove_joker()` | `wand.joker_system` | \pageref{recipe:joker-manage} |
| `JokerSystem.trigger_event()` | `wand.joker_system` | \pageref{recipe:joker-trigger} |
| `knife.chain()` | `external.knife.chain` | \pageref{recipe:knife-chain} |
| `lume.*` | `external.lume` | \pageref{recipe:lume-tables}, \pageref{recipe:lume-math} |
| `pauseGame()` | Global | \pageref{recipe:game-control} |
| `PhysicsBuilder.for_entity()` | `core.physics_builder` | \pageref{recipe:add-physics} |
| `PhysicsBuilder.quick()` | `core.physics_builder` | \pageref{recipe:add-physics} |
| `physics.create_physics_for_transform()` | `physics.physics_lua_api` | \pageref{recipe:physics-manager} |
| `physics.enable_collision_between_many()` | `physics.physics_lua_api` | \pageref{recipe:physics-manager} |
| `physics.set_sync_mode()` | `physics.physics_lua_api` | \pageref{recipe:physics-manager} |
| `physics.SetBullet()` | `physics.physics_lua_api` | \pageref{recipe:physics-manager} |
| `physics.SetVelocity()` | `physics.physics_lua_api` | \pageref{recipe:physics-manager} |
| `physics.update_collision_masks_for()` | `physics.physics_lua_api` | \pageref{recipe:physics-manager} |
| `PhysicsManager.add_world()` | `core.physics_manager` | \pageref{recipe:physics-manager} |
| `PhysicsManager.enable_debug_draw()` | `core.physics_manager` | \pageref{recipe:physics-manager} |
| `PhysicsManager.enable_step()` | `core.physics_manager` | \pageref{recipe:physics-manager} |
| `PhysicsManager.find_path()` | `core.physics_manager` | \pageref{recipe:physics-manager} |
| `PhysicsManager.get_world()` | `core.physics_manager` | \pageref{recipe:physics-manager} |
| `PhysicsManager.has_world()` | `core.physics_manager` | \pageref{recipe:physics-manager} |
| `PhysicsManager.is_world_active()` | `core.physics_manager` | \pageref{recipe:physics-manager} |
| `PhysicsManager.move_entity_to_world()` | `core.physics_manager` | \pageref{recipe:physics-manager} |
| `PhysicsManager.rebuild_navmesh()` | `core.physics_manager` | \pageref{recipe:physics-manager} |
| `PhysicsManager.set_nav_obstacle()` | `core.physics_manager` | \pageref{recipe:physics-manager} |
| `PhysicsManager.vision_fan()` | `core.physics_manager` | \pageref{recipe:physics-manager} |
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
| `StatusEffects.<id>` | `data.status_effects` | \pageref{recipe:define-status-effect} |
| `StatusEffects.STACK_MODE` | `data.status_effects` | \pageref{recipe:define-status-effect} |
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
| `tooltips.attachToEntity()` | `core.tooltip_registry` | \pageref{recipe:tooltip-registry} |
| `tooltips.clearAll()` | `core.tooltip_registry` | \pageref{recipe:tooltip-registry} |
| `tooltips.detachFromEntity()` | `core.tooltip_registry` | \pageref{recipe:tooltip-registry} |
| `tooltips.getActiveTooltip()` | `core.tooltip_registry` | \pageref{recipe:tooltip-registry} |
| `tooltips.hide()` | `core.tooltip_registry` | \pageref{recipe:tooltip-registry} |
| `tooltips.isRegistered()` | `core.tooltip_registry` | \pageref{recipe:tooltip-registry} |
| `tooltips.register()` | `core.tooltip_registry` | \pageref{recipe:tooltip-registry} |
| `tooltips.showFor()` | `core.tooltip_registry` | \pageref{recipe:tooltip-registry} |
| `TooltipEffects.combine()` | `core.tooltip_effects` | \pageref{recipe:tooltip-effects} |
| `TooltipEffects.get()` | `core.tooltip_effects` | \pageref{recipe:tooltip-effects} |
| `TooltipEffects.getColor()` | `core.tooltip_effects` | \pageref{recipe:tooltip-effects} |
| `TooltipEffects.styledText()` | `core.tooltip_effects` | \pageref{recipe:tooltip-effects} |
| `TooltipV2.clearCache()` | `ui.tooltip_v2` | \pageref{recipe:tooltip-v2} |
| `TooltipV2.hide()` | `ui.tooltip_v2` | \pageref{recipe:tooltip-v2} |
| `TooltipV2.show()` | `ui.tooltip_v2` | \pageref{recipe:tooltip-v2} |
| `TooltipV2.showCard()` | `ui.tooltip_v2` | \pageref{recipe:tooltip-v2} |
| `Triggers.COMBAT.*` | `data.triggers` | \pageref{recipe:define-trigger-constants} |
| `Triggers.DEFENSIVE.*` | `data.triggers` | \pageref{recipe:define-trigger-constants} |
| `Triggers.STATUS.*` | `data.triggers` | \pageref{recipe:define-trigger-constants} |
| `Triggers.PROGRESSION.*` | `data.triggers` | \pageref{recipe:define-trigger-constants} |
| `Triggers.RESOURCE.*` | `data.triggers` | \pageref{recipe:define-trigger-constants} |
| `unpauseGame()` | Global | \pageref{recipe:game-control} |
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

***

*End of Cookbook*
