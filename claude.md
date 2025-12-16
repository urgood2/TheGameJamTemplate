# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Workflow Reminders

- **Always dispatch a new agent for review purposes at the end of a feature.** Use the `superpowers:requesting-code-review` skill to have a fresh agent review the implementation before considering the work complete.

- **Save progress before context compaction.** When context is running low and compaction/summarization is imminent, always commit work-in-progress and document the current state so the next session can pick up exactly where we left off. This includes:
  - Committing any uncommitted changes (even WIP commits)
  - Noting the current task and next steps in a todo file or commit message
  - Pushing to remote so progress isn't lost

## Notifications

When you need to notify the user or ask for permission/input, use terminal-notifier:

```bash
terminal-notifier -title "Claude Code" -message "Your message here"
```

Use this for:
- Asking for user input/decisions
- Notifying completion of long-running tasks
- Permission requests
- Any situation where user attention is needed

## Build Commands

**Prefer incremental builds** to reduce build time. Avoid `just clean` or full rebuilds unless necessary. The build system (CMake) handles incremental compilation automatically.

```bash
# Native builds (requires CMake 3.14+, C++20 toolchain, and just)
just build-debug              # Debug build → ./build/raylib-cpp-cmake-template
just build-release            # Release build
just build-debug-fast         # Separate build dir (avoids cache churn)
just build-release-fast
just build-debug-ninja        # Ninja generator (faster)

# Run the game
./build/raylib-cpp-cmake-template

# Tests (GoogleTest)
just test                     # Run all tests
just test-asan                # With AddressSanitizer

# Web build (requires emsdk)
just build-web                # Output: build-emc/index.html

# Utilities
just clean                    # Remove build directories
just ccache-stats             # Show compiler cache stats
just docs                     # Generate Doxygen documentation
```

## Architecture Overview

**Engine**: C++20 + Lua game engine built on Raylib 5.5, using EnTT for ECS and Chipmunk for physics.

### Core Structure
- `src/core/` - Game loop (`game.cpp`), initialization (`init.cpp`), globals (`globals.cpp`)
- `src/components/` - ECS component definitions (400+ components in `components.hpp`)
- `src/systems/` - 37+ subsystems: ai, camera, collision, input, layer, physics, scripting, shaders, sound, ui, etc.
- `src/util/` - Common headers (PCH), utilities, error handling
- `assets/scripts/` - Lua gameplay code (core, combat, ui, ai, data)
- `assets/shaders/` - 200+ GLSL shaders with platform variants

### Key Subsystems
| System | Location | Purpose |
|--------|----------|---------|
| **Layer** | `src/systems/layer/` | Render batching, shader grouping, depth sorting |
| **Physics** | `src/systems/physics/` | Chipmunk wrapper, collision masks, sync modes |
| **Scripting** | `src/systems/scripting/` | Lua VM (Sol2), hot-reload, engine bindings |
| **Shaders** | `src/systems/shaders/` | Multi-pass pipeline, fullscreen effects |
| **UI** | `src/systems/ui/` | Layouts, controller nav, localization |
| **Combat** | `assets/scripts/combat/` | Card/ability system, wands, projectiles |

### Dependency Injection
Legacy `globals::` are being migrated to `EngineContext` (`src/core/engine_context.hpp`). Access via `globals::g_ctx`.

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

## Shader Builder API

### Fluent Shader Composition

```lua
local ShaderBuilder = require("core.shader_builder")

-- Basic usage
ShaderBuilder.for_entity(entity)
    :add("3d_skew_holo")
    :apply()

-- With custom uniforms
ShaderBuilder.for_entity(entity)
    :add("3d_skew_holo", { sheen_strength = 1.5 })
    :add("dissolve", { dissolve = 0.5 })
    :apply()

-- Clear and rebuild
ShaderBuilder.for_entity(entity)
    :clear()
    :add("3d_skew_prismatic")
    :apply()
```

### Shader Families

Convention-based prefix detection. Shaders with matching prefix get family defaults:
- `3d_skew_*`: Card shaders (regionRate, pivot, etc.)
- `liquid_*`: Fluid effects (wave_speed, wave_amplitude, distortion)

Register custom families:
```lua
ShaderBuilder.register_family("energy", {
    uniforms = { "pulse_speed", "glow_intensity" },
    defaults = { pulse_speed = 1.0 },
})
```

---

## Draw Commands API

### Table-Based Command Buffer Wrappers

```lua
local draw = require("core.draw")

-- Before (verbose callback)
command_buffer.queueTextPro(layer, function(c)
    c.text = "hello"
    c.x, c.y = 100, 200
    c.fontSize = 16
    c.color = WHITE
end, z, space)

-- After (table-based with defaults)
draw.textPro(layer, { text = "hello", x = 100, y = 200 }, z, space)
```

### Local Commands (Shader Pipeline)

```lua
-- Before (9 positional params)
shader_draw_commands.add_local_command(
    registry, eid, "text_pro", fn, 1, space, true, false, false
)

-- After (props + opts)
draw.local_command(eid, "text_pro", {
    text = "hello", x = 10, y = 20, fontSize = 20,
}, { z = 1, preset = "shaded_text" })
```

### Render Presets

Named presets for common configurations:
- `"shaded_text"`: textPass=true, uvPassthrough=true
- `"sticker"`: stickerPass=true, uvPassthrough=true
- `"world"`: space=World
- `"screen"`: space=Screen

---

## Entity Builder API

### Fluent Entity Creation

```lua
local EntityBuilder = require("core.entity_builder")

-- Full options
local entity, script = EntityBuilder.create({
    sprite = "kobold",
    position = { x = 100, y = 200 },  -- or { 100, 200 }
    size = { 64, 64 },
    shadow = true,
    data = { health = 100, faction = "enemy" },
    interactive = {
        hover = { title = "Enemy", body = "A dangerous kobold" },
        click = function(reg, eid) print("clicked!") end,
        drag = true,
        collision = true
    },
    state = PLANNING_STATE,
    shaders = { "3d_skew_holo" }
})

-- Simple version (just sprite + position)
local entity = EntityBuilder.simple("kobold", 100, 200, 64, 64)

-- Interactive with hover tooltip
local entity, script = EntityBuilder.interactive({
    sprite = "button",
    position = { 100, 100 },
    hover = { title = "Click me", body = "Description" },
    click = function() print("clicked!") end
})
```

### EntityBuilder.create Options

| Option | Type | Description |
|--------|------|-------------|
| `sprite` | string | Animation/sprite ID |
| `position` | table | `{ x, y }` or `{ x = n, y = n }` |
| `size` | table | `{ w, h }` (default: 32x32) |
| `shadow` | boolean | Enable shadow (default: false) |
| `data` | table | Script table data (assigned before attach_ecs) |
| `interactive` | table | Interaction config (see below) |
| `state` | string | State tag to add |
| `shaders` | table | List of shader names |

### Interactive Options

| Option | Type | Description |
|--------|------|-------------|
| `hover` | table | `{ title, body, id? }` for tooltip |
| `click` | function | onClick callback |
| `drag` | boolean/function | Enable drag or custom handler |
| `stopDrag` | function | onStopDrag callback |
| `collision` | boolean | Enable collision |

---

## Physics Builder API

### Fluent Physics Setup

```lua
local PhysicsBuilder = require("core.physics_builder")

-- Fluent API
PhysicsBuilder.for_entity(entity)
    :circle()                           -- or :rectangle()
    :tag("projectile")
    :bullet()                           -- high-speed collision detection
    :friction(0)
    :fixedRotation()
    :syncMode("physics")                -- or "transform"
    :collideWith({ "enemy", "WORLD" })
    :apply()

-- Quick setup with options table
PhysicsBuilder.quick(entity, {
    shape = "circle",
    tag = "projectile",
    bullet = true,
    collideWith = { "enemy", "WORLD" }
})
```

### PhysicsBuilder Methods

| Method | Description |
|--------|-------------|
| `:circle()` | Circle collider shape |
| `:rectangle()` | Rectangle collider shape |
| `:tag(string)` | Collision tag |
| `:sensor(bool)` | Is sensor (no physical response) |
| `:density(number)` | Body density |
| `:friction(number)` | Surface friction |
| `:restitution(number)` | Bounciness |
| `:bullet(bool)` | CCD for fast objects |
| `:fixedRotation(bool)` | Lock rotation |
| `:syncMode(string)` | "physics" or "transform" |
| `:collideWith(table)` | Tags to collide with |
| `:apply()` | Apply all settings |

---

## Timer Options API

### Options-Table Variants

```lua
local timer = require("core.timer")

-- Clearer than positional parameters
timer.after_opts({
    delay = 2.0,
    action = function() print("done") end,
    tag = "my_timer"
})

timer.every_opts({
    delay = 0.5,
    action = updateHealth,
    times = 10,           -- 0 = infinite
    immediate = true,     -- run once immediately
    tag = "health_update"
})

timer.cooldown_opts({
    delay = 1.0,
    condition = function() return canAttack end,
    action = doAttack,
    tag = "attack_cd"
})
```

### Timer Sequences (Fluent Chaining)

```lua
-- Avoid nested timer.after calls
timer.sequence("animation")
    :wait(0.5)
    :do_now(function() print("start") end)
    :wait(0.3)
    :do_now(function() print("middle") end)
    :wait(0.2)
    :do_now(function() print("end") end)
    :onComplete(function() print("done!") end)
    :start()
```

---

## Global Helper Functions

These functions are available globally after util.lua loads:

```lua
-- Entity validation (use instead of manual nil checks)
if ensure_entity(eid) then
    -- entity is valid
end

if ensure_scripted_entity(eid) then
    -- entity is valid AND has ScriptComponent
end

-- Safe script access
local script = safe_script_get(eid)           -- returns nil if missing
local script = safe_script_get(eid, true)     -- logs warning if missing

-- Safe field access with default
local health = script_field(eid, "health", 100)  -- returns 100 if missing
```

### Replace This Pattern

```lua
-- OLD (verbose)
if not entity or entity == entt_null or not entity_cache.valid(entity) then
    return
end

-- NEW (use the helper!)
if not ensure_entity(entity) then return end
```

---

## Imports Bundle

Reduce repetitive requires with bundled imports:

```lua
local imports = require("core.imports")

-- Core bundle (most common set)
local component_cache, entity_cache, timer, signal, z_orders = imports.core()

-- Entity creation
local Node, animation_system, EntityBuilder = imports.entity()

-- Physics
local PhysicsManager, PhysicsBuilder = imports.physics()

-- UI
local dsl, z_orders, util = imports.ui()

-- Everything as a table
local i = imports.all()
print(i.timer, i.EntityBuilder, i.signal)
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

### Options-Table API (Recommended)

Avoid positional parameter confusion with named options:

```lua
-- Instead of: timer.every(delay, action, times, immediate, after, tag, group)
-- Use named parameters:

timer.every_opts({
    delay = 0.5,
    action = function() print("tick") end,
    times = 10,        -- 0 = infinite (default)
    immediate = true,  -- run once immediately (default: false)
    tag = "my_timer"   -- for cancellation
})

timer.after_opts({
    delay = 2.0,
    action = function() print("done") end,
    tag = "one_shot"
})

timer.cooldown_opts({
    delay = 1.0,
    condition = function() return canAttack end,
    action = doAttack,
    tag = "attack_cd"
})

-- Cancel by tag
timer.cancel("my_timer")
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

    -- Add physics (use correct API)
    local PhysicsManager = require("core.physics_manager")
    local world = PhysicsManager.get_world("world")
    local config = { shape = "circle", tag = "custom", sensor = false, density = 1.0 }
    physics.create_physics_for_transform(registry, physics_manager_instance, entity, "world", config)

    -- Emit creation event
    signal.emit("entity_created", entity, { type = "custom" })

    return entity
end
```

---

## Content Creation (Cards, Jokers, Projectiles, Avatars)

Full documentation in `docs/content-creation/`. Quick reference below.

### Adding a Card

Add to `assets/scripts/data/cards.lua`:

```lua
Cards.MY_FIREBALL = {
    id = "MY_FIREBALL",
    type = "action",           -- "action", "modifier", or "trigger"
    mana_cost = 12,
    damage = 25,
    damage_type = "fire",
    projectile_speed = 400,
    lifetime = 2000,
    radius_of_effect = 50,     -- AoE radius (0 = no AoE)
    tags = { "Fire", "Projectile", "AoE" },
    test_label = "MY\nfireball",
    sprite = "fireball_icon",  -- Optional: custom sprite (default: sample_card.png)
}
```

### Adding a Joker

Add to `assets/scripts/data/jokers.lua`:

```lua
my_joker = {
    id = "my_joker",
    name = "My Joker",
    description = "+10 damage to Fire spells",
    rarity = "Common",         -- Common, Uncommon, Rare, Epic, Legendary
    sprite = "joker_my_joker", -- Optional: custom sprite (default: joker_sample.png)
    calculate = function(self, context)
        if context.event == "on_spell_cast" and context.tags and context.tags.Fire then
            return { damage_mod = 10, message = "My Joker!" }
        end
    end
}
```

### Adding a Projectile Preset

Add to `assets/scripts/data/projectiles.lua`:

```lua
my_projectile = {
    id = "my_projectile",
    speed = 400,
    damage_type = "fire",
    movement = "straight",     -- straight, homing, arc, orbital
    collision = "explode",     -- destroy, pierce, bounce, explode, pass_through, chain
    explosion_radius = 60,
    lifetime = 2000,
    tags = { "Fire", "Projectile", "AoE" },
}
```

### Standard Tags

**Elements:** `Fire`, `Ice`, `Lightning`, `Poison`, `Arcane`, `Holy`, `Void`
**Mechanics:** `Projectile`, `AoE`, `Hazard`, `Summon`, `Buff`, `Debuff`
**Playstyle:** `Mobility`, `Defense`, `Brute`

### Validation & Testing

```lua
-- Validate all content (run in-game or standalone)
dofile("assets/scripts/tools/content_validator.lua")

-- ImGui Content Debug Panel shows:
-- - Joker Tester: Add/remove jokers, trigger test events
-- - Projectile Spawner: Spawn with live parameter tweaking
-- - Tag Inspector: View tag counts and bonuses
```

### Extending the Systems

All content systems are designed to be extensible. You can add new mechanics without modifying core code.

#### Adding New Tags
Tags are just strings. Add to any card/projectile and react to them in jokers:
```lua
-- In card: tags = { "MyNewTag" }
-- In joker: if context.tags and context.tags.MyNewTag then return { damage_mult = 1.5 } end
```

#### Tag Synergy Thresholds
Tags grant bonuses at breakpoints (3/5/7/9 cards with that tag). Defined in `wand/tag_evaluator.lua`:

```lua
-- Add new tag with synergy breakpoints:
local TAG_BREAKPOINTS = {
    MyNewTag = {
        [3] = { type = "stat", stat = "damage_pct", value = 10 },       -- +10% damage
        [5] = { type = "proc", proc_id = "my_custom_proc" },            -- Trigger proc
        [7] = { type = "stat", stat = "crit_chance_pct", value = 15 },  -- +15% crit
        [9] = { type = "proc", proc_id = "my_ultimate_proc" },          -- Ultimate proc
    },
    -- ... existing tags
}
```

**Bonus types:**
- `stat`: Modifies player stat (e.g., `damage_pct`, `crit_chance_pct`)
- `proc`: Triggers a proc effect (implement handler in combat system)

**Changing thresholds:** Edit `DEFAULT_THRESHOLDS = { 3, 5, 7, 9 }` in tag_evaluator.lua.

**API:**
```lua
local TagEvaluator = require("wand.tag_evaluator")
TagEvaluator.get_thresholds("Fire")     -- Returns sorted threshold list
TagEvaluator.get_breakpoints()          -- Returns copy of all tag definitions
```

#### Adding New Joker Events
Event names are strings. Emit from any code, jokers react automatically:
```lua
local JokerSystem = require("wand.joker_system")
local effects = JokerSystem.trigger_event("on_dodge", { player = player })
```

#### Adding New Card Behaviors
Use BehaviorRegistry for complex logic:
```lua
local BehaviorRegistry = require("wand.card_behavior_registry")
BehaviorRegistry.register("my_behavior", function(ctx) ... end)
-- In card: behavior_id = "my_behavior"
```

#### Implementation Status Notes
| System | Fully Implemented | Needs Implementation |
|--------|------------------|---------------------|
| Cards | ✅ All fields work | - |
| Jokers | ✅ Events, aggregation | - |
| Projectiles | ✅ Movement, collision | - |
| Avatars | ✅ Unlock conditions | ⚠️ Effect application |

See `docs/content-creation/` for detailed extensibility guides.

---

## Troubleshooting

### Entity Issues

#### Entity Disappeared / Not Rendering

**Problem:** Entity was created but doesn't appear on screen.

**Common causes:**
1. Missing layer assignment
2. Wrong z-order (behind other entities)
3. Position outside camera view
4. Size too small (0 width/height)
5. Missing sprite/animation component

**Solution:**

```lua
local entity = animation_system.createAnimatedObjectWithTransform("kobold", true, 100, 200)

-- Verify entity is valid
if not entity_cache.valid(entity) then
    log_warn("Entity creation failed!")
    return
end

-- Check transform
local transform = component_cache.get(entity, Transform)
if not transform then
    log_warn("Entity missing Transform component!")
    return
end

-- Verify position and size
print("Position:", transform.actualX, transform.actualY)
print("Size:", transform.actualW, transform.actualH)

-- Check if entity has rendering components
local hasAnim = registry:has(entity, AnimationQueueComponent)
print("Has animation:", hasAnim)

-- Ensure reasonable size
if transform.actualW == 0 or transform.actualH == 0 then
    transform.actualW = 32
    transform.actualH = 32
end
```

#### Entity Data Lost / getScriptTableFromEntityID Returns Nil

**Problem:** `getScriptTableFromEntityID(entity)` returns `nil`.

**Cause:** Script table was not properly initialized, or data was assigned AFTER `attach_ecs()`.

**Solution:**

```lua
-- WRONG: This will fail
local entity = animation_system.createAnimatedObjectWithTransform("kobold", true)
local script = getScriptTableFromEntityID(entity)  -- Returns nil!
script.health = 100  -- Error: attempt to index nil value

-- CORRECT: Initialize script table with Node pattern
local Node = require("monobehavior.behavior_script_v2")
local entity = animation_system.createAnimatedObjectWithTransform("kobold", true)

local EntityType = Node:extend()
local entityScript = EntityType {}

-- CRITICAL: Assign data BEFORE attach_ecs
entityScript.health = 100
entityScript.maxHealth = 100
entityScript.faction = "enemy"

-- Call attach_ecs LAST
entityScript:attach_ecs { create_new = false, existing_entity = entity }

-- Now getScriptTableFromEntityID works
local script = getScriptTableFromEntityID(entity)
print(script.health)  -- 100
```

**Prevention:** Use EntityBuilder to handle this automatically:

```lua
local entity, script = EntityBuilder.create({
    sprite = "kobold",
    position = { 100, 200 },
    data = { health = 100, maxHealth = 100, faction = "enemy" }
})

-- script is already initialized and ready to use
print(script.health)  -- 100
```

#### Entity Validation Failures

**Problem:** Entity becomes invalid mid-execution.

**Solution:** Always validate before use:

```lua
-- Use global helpers (preferred)
if not ensure_entity(entity) then
    return
end

-- Or manual validation
local entity_cache = require("core.entity_cache")
if not entity or not entity_cache.valid(entity) then
    log_warn("Entity is invalid or destroyed")
    return
end

-- Check if entity has specific component
if not registry:has(entity, Transform) then
    log_warn("Entity missing Transform component")
    return
end
```

### Physics Issues

#### Collisions Not Working

**Problem:** Physics bodies pass through each other without colliding.

**Common causes:**
1. Missing collision masks setup
2. Wrong collision tags
3. Both bodies are sensors
4. Bodies on wrong physics world
5. Collision layers not configured

**Solution:**

```lua
local PhysicsManager = require("core.physics_manager")
local PhysicsBuilder = require("core.physics_builder")

-- Get the physics world
local world = PhysicsManager.get_world("world")
if not world then
    log_warn("Physics world not available!")
    return
end

-- Set up collision properly
PhysicsBuilder.for_entity(entity)
    :circle()
    :tag("projectile")
    :sensor(false)  -- NOT a sensor - has physical response
    :collideWith({ "enemy", "WORLD" })
    :apply()

-- Verify collision masks are set
local config = component_cache.get(entity, PhysicsBodyConfig)
if config then
    print("Tag:", config.tag)
    print("Is sensor:", config.isSensor)
end

-- Enable bidirectional collisions
physics.enable_collision_between_many(world, "projectile", { "enemy" })
physics.enable_collision_between_many(world, "enemy", { "projectile" })
physics.update_collision_masks_for(world, "projectile", { "enemy" })
physics.update_collision_masks_for(world, "enemy", { "projectile" })
```

#### Physics World Returns Nil

**Problem:** `PhysicsManager.get_world("world")` returns `nil`.

**Cause:** Physics system not initialized, or wrong world name.

**Solution:**

```lua
-- WRONG: Using old globals.physicsWorld pattern
if globals.physicsWorld then  -- May be nil or stale
    physics.create_physics_for_transform(globals.physicsWorld, entity, "dynamic")
end

-- CORRECT: Use PhysicsManager
local PhysicsManager = require("core.physics_manager")
local world = PhysicsManager.get_world("world")

if not world then
    log_warn("Physics world 'world' not available - check physics initialization")
    return
end

-- Use the world
local config = { shape = "circle", tag = "projectile", sensor = false, density = 1.0 }
physics.create_physics_for_transform(registry, physics_manager_instance, entity, "world", config)
```

#### Physics Body Not Moving

**Problem:** Physics body created but entity doesn't move.

**Cause:** Sync mode set to AuthoritativeTransform instead of AuthoritativePhysics.

**Solution:**

```lua
-- Set correct sync mode for physics-driven movement
PhysicsBuilder.for_entity(entity)
    :circle()
    :tag("projectile")
    :syncMode("physics")  -- Transform follows physics
    :apply()

-- Apply velocity
local world = PhysicsManager.get_world("world")
physics.SetLinearVelocity(world, entity, velocityX, velocityY)

-- Verify sync mode
local syncConfig = component_cache.get(entity, PhysicsSyncConfig)
if syncConfig then
    print("Pull from physics:", syncConfig.pullPositionFromPhysics)
    print("Push to physics:", syncConfig.pushPositionToPhysics)
end
```

### Rendering Issues

#### Entity Not Visible

**Problem:** Entity exists and has valid transform, but doesn't render.

**Common causes:**
1. Z-order behind other elements
2. Wrong rendering layer
3. Missing sprite/animation component
4. Entity outside camera bounds
5. Alpha/opacity set to 0

**Solution:**

```lua
local z_orders = require("core.z_orders")

-- Check z-order
local transform = component_cache.get(entity, Transform)
print("Current z-order:", transform.actualZ)

-- Move to foreground
transform.actualZ = z_orders.ui_foreground

-- Check layer assignment
local layerComp = registry:get(entity, EntityLayer)
if layerComp then
    print("Current layer:", layerComp.layer)
end

-- Verify animation component exists
if not registry:has(entity, AnimationQueueComponent) then
    log_warn("Entity missing AnimationQueueComponent - won't render!")
end

-- Check opacity
local sprite = component_cache.get(entity, Sprite)
if sprite then
    print("Sprite opacity:", sprite.opacity)
    sprite.opacity = 1.0  -- Ensure visible
end
```

#### Wrong Layer / Z-Order

**Problem:** Entity renders but at wrong depth (behind/in front of other elements).

**Solution:**

```lua
local z_orders = require("core.z_orders")
local transform = component_cache.get(entity, Transform)

-- Common z-order values (from lowest to highest)
transform.actualZ = z_orders.background        -- Far background
transform.actualZ = z_orders.enemies           -- Enemy entities
transform.actualZ = z_orders.player            -- Player layer
transform.actualZ = z_orders.projectiles       -- Projectiles above player
transform.actualZ = z_orders.ui_background     -- UI bottom layer
transform.actualZ = z_orders.ui_foreground     -- UI top layer
transform.actualZ = z_orders.tooltip           -- Tooltips on top

-- For UI elements, also set layer
local EntityLayer = _G.EntityLayer
if EntityLayer then
    if not registry:has(entity, EntityLayer) then
        registry:emplace(entity, EntityLayer)
    end
    local layer = registry:get(entity, EntityLayer)
    layer.layer = "ui"  -- or "world", "background", etc.
end
```

#### Shader Not Applying

**Problem:** Shader added but visual effect not visible.

**Solution:**

```lua
local ShaderBuilder = require("core.shader_builder")

-- Verify shader was added
local shaderComp = component_cache.get(entity, ShaderComponent)
if not shaderComp then
    log_warn("Entity missing ShaderComponent!")
end

-- Clear and rebuild shaders
ShaderBuilder.for_entity(entity)
    :clear()
    :add("3d_skew_holo", { sheen_strength = 1.5 })
    :apply()

-- Check if shader exists in system
local availableShaders = _G.shader_library or {}
if not availableShaders["3d_skew_holo"] then
    log_warn("Shader '3d_skew_holo' not found in shader library!")
end

-- Verify entity is in correct render pass
local localCmd = component_cache.get(entity, LocalDrawCommand)
if localCmd then
    print("Shader pass:", localCmd.shaderPass)
    print("UV passthrough:", localCmd.uvPassthrough)
end
```

### Common Lua Errors

#### "attempt to index a nil value"

**Problem:** Trying to access field on nil object.

**Common cases:**

```lua
-- WRONG: Component doesn't exist
local transform = component_cache.get(entity, Transform)
transform.actualX = 100  -- Error if transform is nil

-- CORRECT: Check before use
local transform = component_cache.get(entity, Transform)
if transform then
    transform.actualX = 100
end

-- WRONG: Script table not initialized
local script = getScriptTableFromEntityID(entity)
script.health = 100  -- Error if script is nil

-- CORRECT: Use safe accessor
local script = safe_script_get(entity)
if script then
    script.health = 100
end

-- Or use script_field with default
local health = script_field(entity, "health", 100)

-- WRONG: Module not available
local result = some_module.doSomething()

-- CORRECT: Check module exists
if some_module and some_module.doSomething then
    local result = some_module.doSomething()
end
```

#### "attempt to call a nil value"

**Problem:** Trying to call function that doesn't exist.

**Common cases:**

```lua
-- WRONG: Function doesn't exist on object
nodeComp.methods.onClick()  -- Error if onClick not set

-- CORRECT: Check before calling
if nodeComp.methods.onClick and type(nodeComp.methods.onClick) == "function" then
    nodeComp.methods.onClick(registry, entity)
end

-- WRONG: Global function not defined
myCustomFunction()  -- Error if not defined

-- CORRECT: Check existence
if _G.myCustomFunction then
    myCustomFunction()
end

-- WRONG: Module function doesn't exist
local timer = require("core.timer")
timer.nonexistent_function()

-- CORRECT: Verify before call
if timer.nonexistent_function then
    timer.nonexistent_function()
else
    log_warn("Function not available in timer module")
end
```

#### Stack Overflow / Infinite Recursion

**Problem:** Script crashes with "stack overflow" error.

**Common causes:**
1. Circular requires between modules
2. Infinite timer loops
3. Signal handlers that emit the same signal
4. Entity creation during entity iteration

**Solution:**

```lua
-- WRONG: Infinite signal loop
signal.register("on_damage", function(entity)
    signal.emit("on_damage", entity)  -- Infinite recursion!
end)

-- CORRECT: Guard against recursion
local _processing_damage = false
signal.register("on_damage", function(entity)
    if _processing_damage then return end
    _processing_damage = true
    -- Handle damage
    _processing_damage = false
end)

-- WRONG: Creating entities during view iteration
for entity in registry:view(Transform):each() do
    local newEntity = registry:create()  -- Can invalidate iterator!
end

-- CORRECT: Collect entities first, then create
local entities_to_process = {}
for entity in registry:view(Transform):each() do
    table.insert(entities_to_process, entity)
end
for _, entity in ipairs(entities_to_process) do
    local newEntity = registry:create()
end
```

#### Missing Component Errors

**Problem:** Accessing component that doesn't exist on entity.

**Solution:**

```lua
-- Always check component exists before accessing
local entity_cache = require("core.entity_cache")
local component_cache = require("core.component_cache")

-- Pattern 1: Early return if missing
local transform = component_cache.get(entity, Transform)
if not transform then
    log_warn("Entity missing Transform component:", entity)
    return
end

-- Pattern 2: Emplace if missing
if not registry:has(entity, GameObject) then
    registry:emplace(entity, GameObject)
end
local gameObj = registry:get(entity, GameObject)

-- Pattern 3: Try-get with default behavior
local script = safe_script_get(entity)
if not script then
    -- Create script table if needed
    local Node = require("monobehavior.behavior_script_v2")
    local EntityType = Node:extend()
    script = EntityType {}
    script:attach_ecs { create_new = false, existing_entity = entity }
end
```

---

## References

- **Card Creation**: [gameplay.lua:577-1034](assets/scripts/core/gameplay.lua#L577-L1034)
- **Signal Usage**: [gameplay.lua:3569-3625](assets/scripts/core/gameplay.lua#L3569-L3625)
- **Projectile System**: [assets/scripts/combat/projectile_system.lua](assets/scripts/combat/projectile_system.lua)

---

## UI DSL Pattern

### Declarative UI with ui_syntax_sugar

Use the DSL for building UIs instead of manual box construction:

```lua
local dsl = require("ui.ui_syntax_sugar")

local myUI = dsl.root {
    config = {
        color = util.getColor("blackberry"),
        padding = 10,
        align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER)
    },
    children = {
        dsl.vbox {
            config = { spacing = 6, padding = 6 },
            children = {
                dsl.text("Title", { fontSize = 24, color = "white" }),
                dsl.hbox {
                    config = { spacing = 4 },
                    children = {
                        dsl.anim("sprite_id", { w = 40, h = 40, shadow = true }),
                        dsl.text("Subtitle", { fontSize = 16 })
                    }
                }
            }
        }
    }
}

-- Spawn the UI
local boxID = dsl.spawn({ x = 200, y = 200 }, myUI)
```

### DSL Functions

- `dsl.root {}` - Root container
- `dsl.vbox {}` - Vertical layout
- `dsl.hbox {}` - Horizontal layout
- `dsl.text(text, opts)` - Text element
- `dsl.anim(id, opts)` - Animated sprite wrapper
- `dsl.dynamicText(fn, fontSize, effect, opts)` - Auto-updating text
- `dsl.grid(rows, cols, generator)` - Uniform grid
- `dsl.spawn(pos, defNode, layerName, zIndex)` - Create UI entity

### Hover/Tooltip Support

```lua
dsl.text("Button", {
    hover = {
        title = "Button Title",
        body = "Button description"
    },
    onClick = function() print("clicked") end
})
```

---

## Module Structure Pattern

### Standard Lua Module Layout

```lua
-- File: assets/scripts/systems/my_system.lua

local MySystem = {}

-- Require dependencies at top
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")
local signal = require("external.hump.signal")

-- Exposed state
MySystem.config = { ... }
MySystem.active_entities = {}

-- Internal state (local)
local _internal_state = {}

-- Private functions (prefix with _)
local function _privateHelper()
    -- ...
end

-- Public API
function MySystem.initialize()
    -- ...
end

function MySystem.update(dt)
    -- ...
end

function MySystem.getEntityData(entity)
    if not entity_cache.valid(entity) then return nil end
    return MySystem.active_entities[entity]
end

-- Return module at end
return MySystem
```

---

## Naming Conventions

### Variables
```lua
-- Entity identifiers
local entityID, eid, entity

-- Components
local transform, t          -- Transform
local gameObj, go           -- GameObject
local animComp              -- AnimationQueueComponent

-- UI
local boxID                 -- UI Box identifier

-- State
local isActive, _isActive   -- Boolean flags
local isBeingDragged        -- Boolean state
```

### Functions
```lua
-- Private functions: underscore prefix
local function _privateHelper() end

-- Public API: PascalCase or camelCase
function MySystem.doSomething() end
function MySystem.GetEntityData() end

-- Callbacks: on* prefix
nodeComp.methods.onClick = function() end
nodeComp.methods.onHover = function() end
```

### Constants
```lua
-- SCREAMING_SNAKE_CASE for constants
local PLANNING_STATE = "planning"
local ACTION_STATE = "action"
local MAX_HEALTH = 100
```

---

## Common Idioms

### Safe Access Pattern
```lua
-- Always check existence before accessing
if transform then
    transform.actualX = x
end

if not eid or not entity_cache.valid(eid) then
    return
end

-- Nil coalescing for defaults
local value = (obj and obj.field) or default_value

-- Type checking before call
if type(callback) == "function" then
    callback()
end
```

### Localize Globals for Performance
```lua
-- At top of file, localize frequently-used globals
local registry = _G.registry
local math_floor = math.floor
local table_insert = table.insert
```

### Global Exports
```lua
-- Expose utilities globally when needed across files
_G.makeSimpleTooltip = makeSimpleTooltip
_G.isEnemyEntity = isEnemyEntity

-- Feature flags
local DEBUG_MODE = rawget(_G, "DEBUG_MODE") or false
```

### Singleton Pattern
```lua
-- Prevent re-initialization
if _G.__MY_SYSTEM__ then
    return _G.__MY_SYSTEM__
end

local MySystem = {}
_G.__MY_SYSTEM__ = MySystem
-- ... rest of module
return MySystem
```

### Weak Tables for Auto-Cleanup
```lua
-- Entities auto-removed when GC'd
local entityToData = setmetatable({}, { __mode = "k" })
```

---

## Common Events

Events used throughout the codebase (emit with `signal.emit()`, handle with `signal.register()`):

| Event | Parameters | Purpose |
|-------|------------|---------|
| `"avatar_unlocked"` | `avatarId` | Avatar unlock |
| `"tag_threshold_discovered"` | `tagName, threshold` | Tag synergy discovery |
| `"on_player_attack"` | `targetEntity` | Player attacks |
| `"on_low_health"` | `healthPercent` | Health drops low |
| `"on_dash"` | `direction` | Player dashes |
| `"on_bump_enemy"` | `enemyEntity` | Collision with enemy |
| `"player_level_up"` | `{ xp, level }` | Level progression |
| `"deck_changed"` | `{ source }` | Inventory modification |
| `"stats_recomputed"` | `nil` | Stats recalculated |

---

## Testing

Tests are in `tests/unit/` using GoogleTest. Key test files:
- `test_engine_context.cpp` - Dependency injection
- `test_physics_manager.cpp` - Physics initialization
- `test_scripting_lifecycle.cpp` - Lua environment
- `test_controller_nav.cpp` - Controller focus/selection
- `test_error_handling.cpp` - C++/Lua error boundaries

Run a single test:
```bash
./build/unit_tests --gtest_filter="TestSuite.TestName"
```
