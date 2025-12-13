# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Workflow Reminders

- **Always dispatch a new agent for review purposes at the end of a feature.** Use the `superpowers:requesting-code-review` skill to have a fresh agent review the implementation before considering the work complete.

## Build Commands

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
