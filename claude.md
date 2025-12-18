# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Workflow Reminders

- **Always dispatch a new agent for review purposes at the end of a feature.** Use the `superpowers:requesting-code-review` skill.
- **Save progress before context compaction.** Commit WIP changes, note current task/next steps, push to remote.

## Notifications

**ALWAYS use terminal-notifier when requesting confirmation or permission:**

```bash
terminal-notifier -title "Claude Code" -message "Your message here"
```

## Build Commands

**Prefer incremental builds.** Avoid `just clean` unless necessary.

**Use exponential wait delays when checking builds.** When polling for build completion (e.g., background builds, CI checks), use exponential backoff (e.g., 1s → 2s → 4s → 8s) instead of fixed intervals to reduce unnecessary load.

```bash
just build-debug              # Debug build → ./build/raylib-cpp-cmake-template
just build-release            # Release build
just build-debug-ninja        # Ninja generator (faster)
just test                     # Run all tests
just test-asan                # With AddressSanitizer
just build-web                # Web build (requires emsdk)
```

## Architecture Overview

**Engine**: C++20 + Lua on Raylib 5.5, EnTT (ECS), Chipmunk (physics).

### Core Structure
- `src/core/` - Game loop, initialization, globals
- `src/components/` - ECS components (400+ in `components.hpp`)
- `src/systems/` - 37+ subsystems: ai, camera, collision, input, layer, physics, scripting, shaders, sound, ui
- `assets/scripts/` - Lua gameplay (core, combat, ui, ai, data)
- `assets/shaders/` - 200+ GLSL shaders

### Key Subsystems
| System | Location | Purpose |
|--------|----------|---------|
| Layer | `src/systems/layer/` | Render batching, depth sorting |
| Physics | `src/systems/physics/` | Chipmunk wrapper, collision masks |
| Scripting | `src/systems/scripting/` | Lua VM (Sol2), hot-reload |
| Shaders | `src/systems/shaders/` | Multi-pass pipeline |
| Combat | `assets/scripts/combat/` | Card/ability system, projectiles |

---

## Lua Entity Script Table Pattern

**CRITICAL: Data must be assigned BEFORE `attach_ecs()`!**

```lua
local Node = require("monobehavior.behavior_script_v2")

local entity = registry:create()
local EntityType = Node:extend()
local script = EntityType {}

-- Assign data FIRST
script.customData = { foo = "bar" }
script.someValue = 42

-- Call attach_ecs LAST
script:attach_ecs { create_new = false, existing_entity = entity }

-- Use script variable directly after attach (don't call getScriptTableFromEntityID immediately)
```

**Why:** `getScriptTableFromEntityID()` returns nil without proper initialization. Data assigned after `attach_ecs()` is lost.

---

## Event System: Signal Library

```lua
local signal = require("external.hump.signal")

-- Emit: entity first, then data table
signal.emit("projectile_spawned", entity, { owner = ownerEntity, damage = 50 })

-- Register handler
signal.register("projectile_spawned", function(entity, data)
    print("Damage:", data.damage)
end)
```

**Don't use `publishLuaEvent()`** - use `signal.emit()`.

---

## Physics Integration

### Getting Physics World

```lua
local PhysicsManager = require("core.physics_manager")
local world = PhysicsManager.get_world("world")  -- NOT globals.physicsWorld
```

### Creating Physics Bodies

```lua
local config = { shape = "circle", tag = "projectile", sensor = false, density = 1.0 }
physics.create_physics_for_transform(registry, physics_manager_instance, entity, "world", config)

-- Set sync mode
physics.set_sync_mode(registry, entity, physics.PhysicsSyncMode.AuthoritativePhysics)

-- Per-entity collision masks
physics.enable_collision_between_many(world, "projectile", { "enemy" })
physics.update_collision_masks_for(world, "projectile", { "enemy" })
```

### PhysicsBuilder (Fluent API)

```lua
local PhysicsBuilder = require("core.physics_builder")

PhysicsBuilder.for_entity(entity)
    :circle()
    :tag("projectile")
    :bullet()
    :friction(0)
    :collideWith({ "enemy", "WORLD" })
    :apply()
```

---

## Entity Builder API

```lua
local EntityBuilder = require("core.entity_builder")

-- Full options
local entity, script = EntityBuilder.create({
    sprite = "kobold",
    position = { x = 100, y = 200 },
    size = { 64, 64 },
    shadow = true,
    data = { health = 100, faction = "enemy" },
    interactive = {
        hover = { title = "Enemy", body = "A dangerous kobold" },
        click = function(reg, eid) print("clicked!") end,
        collision = true
    },
    state = PLANNING_STATE,
    shaders = { "3d_skew_holo" }
})

-- Simple version
local entity = EntityBuilder.simple("kobold", 100, 200, 64, 64)
```

---

## Shader Builder API

```lua
local ShaderBuilder = require("core.shader_builder")

ShaderBuilder.for_entity(entity)
    :add("3d_skew_holo", { sheen_strength = 1.5 })
    :add("dissolve", { dissolve = 0.5 })
    :apply()
```

**Shader families:** `3d_skew_*` (card shaders), `liquid_*` (fluid effects)

---

## Draw Commands API

```lua
local draw = require("core.draw")

-- Table-based (preferred)
draw.textPro(layer, { text = "hello", x = 100, y = 200 }, z, space)

-- Local commands for shader pipeline
draw.local_command(eid, "text_pro", {
    text = "hello", x = 10, y = 20, fontSize = 20,
}, { z = 1, preset = "shaded_text" })
```

**Presets:** `"shaded_text"`, `"sticker"`, `"world"`, `"screen"`

---

## Timer API

```lua
local timer = require("core.timer")

timer.after_opts({ delay = 2.0, action = function() end, tag = "my_timer" })
timer.every_opts({ delay = 0.5, action = fn, times = 10, immediate = true, tag = "update" })

-- Fluent sequences
timer.sequence("animation")
    :wait(0.5)
    :do_now(function() print("start") end)
    :wait(0.3)
    :do_now(function() print("end") end)
    :start()
```

---

## Text Builder API

See [docs/api/text-builder.md](docs/api/text-builder.md) for full documentation.

```lua
local Text = require("core.text")

-- Define reusable recipe
local damageRecipe = Text.define()
    :content("[%d](color=red;pop=0.2)")
    :size(20)
    :fade()
    :lifespan(0.8)

-- Fire-and-forget
damageRecipe:spawn(25):above(enemy, 10)

-- REQUIRED: call in game loop
Text.update(dt)
```

---

## Global Helper Functions

```lua
-- Entity validation
if ensure_entity(eid) then ... end
if ensure_scripted_entity(eid) then ... end

-- Safe script access
local script = safe_script_get(eid)
local health = script_field(eid, "health", 100)  -- with default
```

---

## UI DSL

```lua
local dsl = require("ui.ui_syntax_sugar")

local myUI = dsl.root {
    config = { padding = 10 },
    children = {
        dsl.vbox {
            children = {
                dsl.text("Title", { fontSize = 24 }),
                dsl.anim("sprite_id", { w = 40, h = 40 })
            }
        }
    }
}

local boxID = dsl.spawn({ x = 200, y = 200 }, myUI)
```

---

## Content Creation

See [docs/content-creation/](docs/content-creation/) for full guides.

### Quick Reference

**Card** (`assets/scripts/data/cards.lua`):
```lua
Cards.MY_FIREBALL = {
    id = "MY_FIREBALL", type = "action", mana_cost = 12, damage = 25,
    damage_type = "fire", tags = { "Fire", "Projectile" }
}
```

**Joker** (`assets/scripts/data/jokers.lua`):
```lua
my_joker = {
    id = "my_joker", name = "My Joker", rarity = "Common",
    calculate = function(self, context)
        if context.tags and context.tags.Fire then return { damage_mod = 10 } end
    end
}
```

**Standard Tags:**
- Elements: `Fire`, `Ice`, `Lightning`, `Poison`, `Arcane`, `Holy`, `Void`
- Mechanics: `Projectile`, `AoE`, `Hazard`, `Summon`, `Buff`, `Debuff`

---

## Common Mistakes to Avoid

### Don't: Store data in GameObject component
```lua
local gameObj = component_cache.get(entity, GameObject)
gameObj.myData = {}  -- WRONG - bypasses script table system
```

### Don't: Use getScriptTableFromEntityID without initialization
```lua
local entity = registry:create()
local script = getScriptTableFromEntityID(entity)  -- Returns nil!
```

### Don't: Call attach_ecs before assigning data
```lua
script:attach_ecs { ... }
script.data = {}  -- WRONG - data is lost!
```

### Do: Initialize properly
```lua
local script = EntityType {}
script.data = {}              -- Assign FIRST
script:attach_ecs { ... }     -- Attach LAST
```

---

## Common Events

| Event | Parameters | Purpose |
|-------|------------|---------|
| `"on_player_attack"` | `targetEntity` | Player attacks |
| `"on_bump_enemy"` | `enemyEntity` | Collision with enemy |
| `"player_level_up"` | `{ xp, level }` | Level progression |
| `"deck_changed"` | `{ source }` | Inventory modification |
| `"stats_recomputed"` | `nil` | Stats recalculated |

---

## References

- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Content Creation Guides](docs/content-creation/)
- [Text Builder API](docs/api/text-builder.md)
- [API Documentation](docs/api/)
