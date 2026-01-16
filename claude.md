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

## Lua Runtime Debugging

**Auto-run and grep for errors:**
```bash
(./build/raylib-cpp-cmake-template 2>&1 & sleep 8; kill $!) | grep -E "(error|Error|Lua)"
```

**Full output tail (last N lines):**
```bash
(./build/raylib-cpp-cmake-template 2>&1 & sleep 8; kill $!) | tail -80
```

**Common Lua error patterns:**
- `sol: cannot set (new_index)` → C++ userdata doesn't allow arbitrary keys. Use Lua-side registry table instead of `go.config.foo = bar`
- `attempt to index a nil value` → Component/entity not found or not initialized
- Stack traces show file:line → Read that exact location to find the bug

## C++ Bindings vs Lua Modules (CRITICAL)

**Many "modules" are C++ globals, NOT Lua files you can `require()`!**

```lua
-- WRONG: These will fail with "module not found"
local shader_pipeline = require("shaders.shader_pipeline")  -- ERROR!
local registry = require("core.registry")                    -- ERROR!

-- CORRECT: Access C++ bindings from _G
local shader_pipeline = _G.shader_pipeline
local registry = _G.registry  -- or just use `registry` directly
```

### C++ Globals (use `_G.name` or bare name)
| Global | Purpose |
|--------|---------|
| `registry` | EnTT entity registry |
| `component_cache` | Cached component access |
| `shader_pipeline` | Shader pipeline manager |
| `physics` | Physics system bindings |
| `globals` | Game state and screen dimensions |
| `localization` | Localization system |
| `animation_system` | Animation creation/control |
| `layer_order_system` | Z-ordering system |
| `command_buffer` | Draw command queue |
| `layers` | Layer references (sprites, ui, etc.) |
| `z_orders` | Z-order constants |
| `globalShaderUniforms` | Shader uniform manager |

### Lua Modules (use `require()`)
| Module | Path |
|--------|------|
| Timer | `require("core.timer")` |
| Signal | `require("external.hump.signal")` |
| Component Cache | `require("core.component_cache")` |
| UI DSL | `require("ui.ui_syntax_sugar")` |
| EntityBuilder | `require("core.entity_builder")` |
| ShaderBuilder | `require("core.shader_builder")` |

**Rule of thumb:** If it's defined in C++ (check `chugget_code_definitions.lua` for hints), use `_G.name`. If it's a `.lua` file in `assets/scripts/`, use `require()`.

## Z-Order and Layer Rendering

### Setting Entity Z-Level

Use `layer_order_system.assignZIndexToEntity()` to set an entity's z-order:

```lua
-- Set entity z-level (modifies LayerOrderComponent)
layer_order_system.assignZIndexToEntity(entity, z_orders.ui_tooltips + 100)

-- Get current z-level
local z = layer_order_system.getZIndex(entity)
```

### DrawCommandSpace (Camera Awareness)

| Space | Behavior | Use For |
|-------|----------|---------|
| `layer.DrawCommandSpace.World` | Follows camera (camera-aware) | Game objects, cards in world, anything that should move with camera |
| `layer.DrawCommandSpace.Screen` | Fixed to screen (ignores camera) | HUD, fixed UI elements, screen overlays |

```lua
-- Camera-aware rendering (moves with camera)
command_buffer.queueDrawBatchedEntities(layers.ui, function(cmd)
    cmd.entities = entityList
end, z, layer.DrawCommandSpace.World)

-- Fixed to screen (ignores camera)
command_buffer.queueDrawRectangle(layers.ui, function(c)
    c.x, c.y, c.w, c.h = 10, 10, 100, 50
end, z, layer.DrawCommandSpace.Screen)
```

### Common Z-Order Values (from `core/z_orders.lua`)

| Constant | Value | Purpose |
|----------|-------|---------|
| `z_orders.background` | ~0 | Background layers |
| `z_orders.card` | ~100 | Normal cards |
| `z_orders.top_card` | 200 | Dragged/focused cards |
| `z_orders.ui_tooltips` | 900 | UI tooltips |

**For UI cards above everything:** Use `z_orders.ui_tooltips + 500` (~1400).

### World-Space vs Screen-Space Collision (Dual Quadtree)

The engine uses **two separate quadtrees** for collision detection:

| Quadtree | Entities | Marker |
|----------|----------|--------|
| `quadtreeWorld` | Game entities, cards, enemies | NO `ScreenSpaceCollisionMarker` |
| `quadtreeUI` | UI elements, buttons, slots | HAS `ScreenSpaceCollisionMarker` |

**`FindAllEntitiesAtPoint()` queries BOTH quadtrees automatically**, enabling world-space cards to collide with screen-space UI.

```lua
-- World-space card that renders above UI but collides with UI slots:
local entity = createCard(...)

-- 1. Do NOT add ObjectAttachedToUITag (stays in world quadtree)
-- 2. Render to UI layer with World space (camera-aware, above UI)
command_buffer.queueDrawBatchedEntities(layers.ui, function(cmd)
    cmd.entities = { entity }
end, z_orders.ui_tooltips + 500, layer.DrawCommandSpace.World)

-- 3. UI slots (screen-space) get ScreenSpaceCollisionMarker automatically
-- 4. Drag-drop works: input system queries both quadtrees
```

**Key component:** `ObjectAttachedToUITag` / `ScreenSpaceCollisionMarker`
- **WITH tag**: Entity is screen-space (UI quadtree), uses screen coordinates
- **WITHOUT tag**: Entity is world-space (world quadtree), uses camera-transformed coordinates

### UI Element Not Responding to Clicks - Debugging Checklist

When UI elements don't respond to clicks, check in order:

1. **ScreenSpaceCollisionMarker present?**
   ```lua
   local hasMarker = registry:any_of(entity, ScreenSpaceCollisionMarker)
   print("Has collision marker:", hasMarker)
   ```

2. **Collision bounds correct?**
   ```lua
   local coll = component_cache.get(entity, CollisionShape2D)
   print("Collision bounds:", coll.aabb_min_x, coll.aabb_min_y, coll.aabb_max_x, coll.aabb_max_y)
   ```

3. **Z-order high enough?**
   ```lua
   local z = layer_order_system.getZIndex(entity)
   print("Z-order:", z)  -- Should be > anything overlapping
   ```

4. **Correct DrawCommandSpace?**
   - HUD elements: `layer.DrawCommandSpace.Screen`
   - Game elements: `layer.DrawCommandSpace.World`

5. **In correct quadtree?**
   - WITH `ScreenSpaceCollisionMarker`: UI quadtree (screen coords)
   - WITHOUT: World quadtree (camera-transformed coords)

6. **Parent blocking input?**
   - Check if parent element has `consumes_input = true`

7. **Debug render the collision box:**
   ```lua
   draw.debug_bounds(entity, "red")  -- Should align with visual bounds
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

### Node.quick() and Node.create() - Safer Alternatives

To prevent the data-loss bug, use these factory methods instead of manual initialization:

```lua
local Node = require("monobehavior.behavior_script_v2")

-- For existing entity: assigns data BEFORE attach_ecs
local script = Node.quick(entity, { health = 100, damage = 10 })

-- For new entity: creates entity and attaches script
local script = Node.create({ health = 100, damage = 10 })
local entity = script:handle()

-- With extended class
local EntityType = Node:extend()
local script = EntityType.quick(entity, { customData = { foo = "bar" } })
```

**Benefits:**
- Guarantees correct initialization order
- Cleaner syntax than manual attach_ecs
- Works with both base Node and extended classes

### State Management

Use `script:setState()` instead of manual state tag manipulation:

```lua
-- Instead of:
clear_state_tags(entity)
add_state_tag(entity, PLANNING_STATE)

-- Use:
script:setState(PLANNING_STATE)
```

**Benefits:**
- Automatically clears previous state tags
- Shorter, more readable syntax
- Works with all state constants (PLANNING_STATE, COMBAT_STATE, etc.)

### Entity Links (Horizontal Dependencies)

Use `script:linkTo()` for "die when target dies" behavior:

```lua
local projectile = spawn.projectile("fireball", x, y, angle)
projectile:linkTo(owner)  -- Projectile dies when owner dies
```

Or use EntityLinks directly:

```lua
local EntityLinks = require("core.entity_links")
EntityLinks.link(projectile, owner)
EntityLinks.unlink(projectile, owner)
EntityLinks.unlinkAll(projectile)
```

---

## Child Entity Attachment (ChildBuilder)

Fluent API for attaching child entities to parents:

```lua
local ChildBuilder = require("core.child_builder")

ChildBuilder.for_entity(weapon)
    :attachTo(player)
    :offset(20, 0)
    :rotateWith()
    :apply()
```

### Animate Child Offset (Weapon Swing)

```lua
ChildBuilder.animateOffset(weapon, {
    to = { x = -20, y = 30 },
    duration = 0.2,
    ease = "outQuad"
})

ChildBuilder.orbit(weapon, {
    radius = 30,
    startAngle = 0,
    endAngle = math.pi/2,
    duration = 0.2
})
```

### ChildBuilder Methods

| Method | Purpose |
|--------|---------|
| `:attachTo(parent)` | Set parent entity |
| `:offset(x, y)` | Position offset from parent center |
| `:rotateWith()` | Rotate with parent |
| `:scaleWith()` | Scale with parent |
| `:eased()` | Smooth position following |
| `:named(name)` | Name for lookup |
| `:permanent()` | Persist after parent death |
| `:apply()` | Apply configuration |

### Static Helpers

| Function | Purpose |
|----------|---------|
| `ChildBuilder.setOffset(entity, x, y)` | Immediate offset change |
| `ChildBuilder.getOffset(entity)` | Get current offset |
| `ChildBuilder.getParent(entity)` | Get parent entity |
| `ChildBuilder.detach(entity)` | Remove from parent |
| `ChildBuilder.animateOffset(entity, opts)` | Tween offset |
| `ChildBuilder.orbit(entity, opts)` | Arc/circular animation |

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

### Scoped Signal Groups (Recommended for Cleanup)

Use `signal_group` when handlers need cleanup (e.g., per-entity or per-scene):

```lua
local signal_group = require("core.signal_group")

-- Create a group for this module/entity
local handlers = signal_group.new("combat_ui")

-- Register handlers (tracked for cleanup)
handlers:on("enemy_killed", function(entity)
    updateKillCount()
end)

handlers:on("player_damaged", function(entity, data)
    showDamageFlash()
end)

-- When done (e.g., entity destroyed, scene unloaded):
handlers:cleanup()  -- Removes ALL handlers in this group at once
```

**Why use signal_group:**
- Prevents memory leaks from orphaned handlers
- Single cleanup call removes all handlers
- Tracks count of registered handlers for debugging

### Two Event Systems (IMPORTANT)

The codebase has **two separate event systems** that must be kept in sync:

| System | Usage | Example |
|--------|-------|---------|
| `signal` (hump.signal) | Gameplay events, wave system, UI | `signal.emit("enemy_killed", entity)` |
| `ctx.bus` (combat EventBus) | Combat system internals | `ctx.bus:emit("OnDeath", { entity = actor })` |

**The Event Bridge** (`core/event_bridge.lua`) automatically forwards most combat bus events to the signal system. This prevents disconnection bugs where one system doesn't know about events from the other.

**When adding new combat events:**
1. If the event should be visible outside combat system, add it to `BRIDGED_EVENTS` in `event_bridge.lua`
2. If the event data contains combat actors (not entity IDs), handle it manually like `OnDeath` in `gameplay.lua:5234`

**Special case - OnDeath:**
```lua
-- Combat bus emits actor (NOT entity ID):
ctx.bus:emit('OnDeath', { entity = combatActor, killer = src })

-- gameplay.lua converts to entity ID for signal:
local enemyEntity = combatActorToEntity[actor]
signal.emit("enemy_killed", enemyEntity)  -- Wave system expects entity ID
```

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

-- Validated (prevents data-after-attach bug)
local script = EntityBuilder.validated(MyScript, entity, { health = 100 })
```

**Why `validated()`:** When extending scripts manually, use `validated()` to ensure data is assigned before `attach_ecs()`. This prevents the data-loss bug where fields assigned after `attach_ecs()` become inaccessible.

---

## Enemy Behavior Library

Declarative behavior composition for enemies. Replaces repetitive timer boilerplate with composable behavior definitions.

```lua
local enemies = {}

-- Simple: single behavior using ctx.speed
enemies.goblin = {
    sprite = "enemy_type_1.png",
    hp = 30, speed = 60, damage = 5,
    behaviors = { "chase" },
}

-- Composite: multiple behaviors with config
enemies.dasher = {
    sprite = "enemy_type_1.png",
    hp = 25, speed = 50, dash_speed = 300, dash_cooldown = 3.0,
    behaviors = {
        "wander",
        { "dash", cooldown = "dash_cooldown", speed = "dash_speed" },
    },
}
```

**Built-in Behaviors:**
| Behavior | Default Config | Description |
|----------|----------------|-------------|
| `chase` | interval=0.5, speed=ctx.speed | Move toward player |
| `wander` | interval=0.5, speed=ctx.speed | Random movement |
| `flee` | interval=0.5, distance=150 | Move away from player |
| `kite` | interval=0.5, range=ctx.range | Maintain distance (ranged) |
| `dash` | cooldown=ctx.dash_cooldown | Periodic dash attack |
| `trap` | cooldown=ctx.trap_cooldown | Drop hazards |
| `summon` | cooldown=ctx.summon_cooldown | Spawn minions |
| `rush` | interval=0.3 | Fast chase (aggressive) |

**Config Resolution:** String values like `"dash_speed"` lookup `ctx.dash_speed`. Numbers used directly.

**Auto-cleanup:** All behavior timers are automatically cancelled when entity is destroyed.

**Register Custom Behaviors:**
```lua
local behaviors = require("core.behaviors")

behaviors.register("teleport", {
    defaults = { interval = 5.0, range = 100 },
    on_tick = function(e, ctx, helpers, config)
        helpers.teleport_random(e, config.range)
    end,
})
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

### RenderTexture Y-Coordinate Handling

RenderTextures have inverted Y coordinates compared to screen coordinates (Raylib Y=0 at top, OpenGL Y=0 at bottom).

**Fix in fragment shader, NOT in Lua:**

```glsl
// In fragment shader
vec2 flippedTexCoord = vec2(fragTexCoord.x, 1.0 - fragTexCoord.y);
vec4 color = texture(texture0, flippedTexCoord);
```

**Remember:** Update BOTH desktop and web shader versions (`assets/shaders/` and `assets/shaders/web/`).

### GLSL Function Declaration Order

Unlike C/C++, GLSL has no forward declarations. Helper functions must be defined BEFORE first use.

```glsl
// WRONG: rotate2d used before definition
void main() {
    vec2 rotated = rotate2d(uv, angle);  // ERROR: undeclared identifier
}
mat2 rotate2d(float angle) { ... }

// RIGHT: define helper first
mat2 rotate2d(float angle) {
    return mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
}
void main() {
    vec2 rotated = rotate2d(uv, angle);  // Works
}
```

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

**PREFER `timer.sequence()` for multi-step animations!** Avoids callback hell and provides built-in cancellation.

### timer.sequence() - Fluent Chain Builder (Recommended)

```lua
local timer = require("core.timer")

-- Basic sequence with group for cleanup
timer.sequence("attack_animation")
    :do_now(function() playSound("wind_up") end)
    :wait(0.3)
    :do_now(function() dealDamage(target, 50) end)
    :wait(0.2)
    :do_now(function() playSound("impact") end)
    :onComplete(function() print("animation done!") end)
    :start()  -- REQUIRED! Chain won't run without :start()

-- Cancel entire sequence by group
timer.kill_group("attack_animation")

-- Pause/resume all timers in group
timer.pause_group("attack_animation")
timer.resume_group("attack_animation")
```

### Key Methods

| Method | Purpose |
|--------|---------|
| `:wait(delay)` | Pause for N seconds |
| `:do_now(fn)` | Execute function immediately |
| `:after(delay, fn)` | Execute after delay |
| `:onComplete(fn)` | Callback when chain finishes |
| `:start()` | **REQUIRED** - actually runs the chain |
| `:cancel()` | Stop all timers in this chain |

### Single Timers (opts API)

For one-off timers, use the `_opts` variants with named parameters:

```lua
-- Better than timer.after(delay, action, tag, group)
timer.after_opts({ delay = 2.0, action = function() end, tag = "my_timer" })
timer.every_opts({ delay = 0.5, action = fn, times = 10, immediate = true, tag = "update" })
```

### ⚠️ Avoid: Positional API

```lua
-- DON'T: 7 parameters are hard to remember!
timer.every(delay, action, times, immediate, after, tag, group)

-- DO: Use _opts or sequence instead
timer.every_opts({ delay = 0.5, action = fn, times = 10, tag = "pulse" })
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

## Styled Localization

For color-coded text in tooltips, use `localization.getStyled()`:

### JSON Syntax
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

### Tooltip Helper
```lua
local tooltip = makeLocalizedTooltip("tooltip.attack_desc", {
  damage = card.damage,
  element = card.element
}, { title = card.name })
```

**Named Colors:** `red`, `gold`, `green`, `blue`, `cyan`, `purple`, `fire`, `ice`, `poison`, `holy`, `void`, `electric`

---

## Global Helper Functions

**C++ bindings are globals—don't `require()` them:** `registry`, `component_cache`, `localization`, `physics`, `globals` are exposed from C++ and available everywhere without import.

```lua
-- Entity validation
if ensure_entity(eid) then ... end
if ensure_scripted_entity(eid) then ... end

-- Safe script access
local script = safe_script_get(eid)
local health = script_field(eid, "health", 100)  -- with default
```

---

## Q.lua - Quick Convenience Helpers

Single-letter import for minimal friction transform operations:

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

-- Component Access
local transform = Q.getTransform(entity)   -- Safe component get (returns nil if invalid)
Q.withTransform(entity, function(t)        -- Execute only if valid
    t.actualX = t.actualX + 10
end)
```

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
popup.damage(enemy, 25)  -- Appears at physics position

-- Right: effect spawns at rendered location
local vx, vy = Q.visualCenter(enemy)
-- popup.damage uses visualCenter internally
```

**Replaces this boilerplate:**
```lua
-- Old way (4 lines)
local transform = component_cache.get(entity, Transform)
if transform then
    transform.actualX = x
    transform.actualY = y
end

-- New way (1 line)
Q.move(entity, x, y)
```

---

## Popup Helpers

Quick damage/heal numbers with automatic styling and positioning:

```lua
local popup = require("core.popup")

-- Damage numbers (red, descending)
popup.damage(entity, 25)

-- Heal numbers (green, ascending)
popup.heal(entity, 50)

-- Custom text above entity
popup.above(entity, "CRITICAL!", { color = "gold" })
popup.above(entity, "+10 XP", { color = "cyan", offset = 20 })
```

**Features:**
- Automatically uses visual position (not physics position)
- Built-in animations (pop, fade, drift)
- Color-coded by type (damage=red, heal=green)
- Offsets prevent overlap when spawning multiple popups

**Equivalent Text Builder code:**
```lua
-- popup.damage(entity, 25) replaces:
local vx, vy = Q.visualCenter(entity)
Text.define():content("[25](color=red;pop=0.2)"):size(20):fade():lifespan(0.8):spawn():at(vx, vy - 10)
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

### Sprite Panels & Decorations

See [docs/api/sprite-panels.md](docs/api/sprite-panels.md) for full documentation.

```lua
-- Sprite panel with nine-patch stretching
dsl.spritePanel {
    sprite = "ui-panel-frame.png",
    borders = { 8, 8, 8, 8 },  -- left, top, right, bottom
    decorations = {
        { sprite = "corner.png", position = "top_left", offset = { -4, -4 } },
        { sprite = "gem.png", position = "top_center", scale = { 0.6, 0.6 } },
    },
    children = { dsl.text("Content") }
}

-- Sprite button with 4 states
dsl.spriteButton {
    sprite = "button.png",  -- auto-discovers button-hover.png, button-pressed.png, etc.
    borders = { 6, 6, 6, 6 },
    onClick = function() print("clicked!") end,
    children = { dsl.text("Click Me") }
}
```

**Decoration anchors:** `top_left`, `top_center`, `top_right`, `middle_left`, `center`, `middle_right`, `bottom_left`, `bottom_center`, `bottom_right`

**Decoration options:** `offset`, `scale`, `rotation`, `flip` (x/y/both), `opacity`, `tint`

---

## UI Validation (MANDATORY)

**ALWAYS validate UI after creating or modifying UI components.** Use `UIValidator` to catch layout bugs before they become visual issues.

### Validation Workflow

```lua
local UIValidator = require("core.ui_validator")
local dsl = require("ui.ui_syntax_sugar")

-- 1. Create UI
local myPanel = dsl.root {
    config = { padding = 10, minWidth = 200, minHeight = 150 },
    children = { dsl.text("Hello") }
}
local entity = dsl.spawn({ x = 100, y = 100 }, myPanel)

-- 2. ALWAYS validate after spawn
local violations = UIValidator.validate(entity)
local errors = UIValidator.getErrors(violations)

if #errors > 0 then
    print("[UI ERROR] Found " .. #errors .. " validation errors:")
    for _, e in ipairs(errors) do
        print("  " .. e.type .. ": " .. e.message)
    end
end
```

### Quick Validation Patterns

```lua
-- Validate with skipHidden (for tab-based UIs with off-screen content)
local violations = UIValidator.validate(entity, nil, { skipHidden = true })

-- Validate specific rules only
local violations = UIValidator.validate(entity, { "containment", "window_bounds" })

-- Check cross-hierarchy overlaps (elements from different entity trees)
local globalViolations = UIValidator.checkGlobalOverlap({ panelEntity, gridEntity })

-- Check explicit z-order assertions (card should render above grid)
local pairs = { { front = cardEntity, behind = gridEntity } }
local zViolations = UIValidator.checkZOrderOcclusion(pairs)
```

### Violation Types and Fixes

| Violation | Severity | Cause | Fix |
|-----------|----------|-------|-----|
| `containment` | error | Child escapes parent bounds | Increase parent `minWidth`/`minHeight`, add padding, or set `allowEscape = true` on child |
| `window_bounds` | error | UI outside screen | Clamp spawn position, use responsive positioning like `screenWidth() - width` |
| `sibling_overlap` | warning | Same-parent siblings overlap | Increase `spacing` in vbox/hbox, or set `allowOverlap = true` if intentional |
| `z_order_hierarchy` | warning | Child z-order ≤ parent | Use `layer_order_system.assignZIndexToEntity(child, parentZ + 10)` |
| `global_overlap` | warning | Cross-hierarchy elements overlap | Adjust layout/positions, or increase z-order of element that should be on top |
| `z_order_occlusion` | error | Entity expected in front has lower z-order | Increase z-order of "front" entity |
| `layer_consistency` | error | Parent/child on different render layers | Ensure all related UI renders to same layer (e.g., all to `layers.ui`) |
| `space_consistency` | error | Mixed Screen/World DrawCommandSpace | Ensure all related UI uses same space (Screen for HUD, World for game UI) |
| `text_zero_offset` | warning | Text element has no padding from parent | Add padding to parent container or text element |

### Opt-Out Flags

For intentional violations, use config flags:

```lua
-- Child intentionally escapes parent (tooltips, dropdowns)
dsl.box {
    config = { allowEscape = true },
    children = { ... }
}

-- Siblings intentionally overlap (stacked cards)
dsl.box {
    config = { allowOverlap = true },
    children = { ... }
}
```

### UITestUtils for Test-Driven UI

```lua
local UITestUtils = require("tests.ui_test_utils")
local dsl = require("ui.ui_syntax_sugar")

-- Spawn and wait for layout to complete
local entity = UITestUtils.spawnAndWait(myUIDef, { x = 100, y = 100 })

-- Assert no validation errors (throws on failure)
UITestUtils.assertNoErrors(entity)

-- Assert no errors for specific rules
UITestUtils.assertNoErrors(entity, { "containment", "window_bounds" })

-- Cleanup when done
UITestUtils.cleanup(entity)
```

### Integrating with Existing UI Modules

When modifying UI modules like `player_inventory.lua`, add getters for test access:

```lua
-- In your UI module
function MyUI.getPanelEntity()
    return state.panelEntity
end

function MyUI.getGrids()
    return state.grids
end
```

Then validate in tests:

```lua
local panelEntity = MyUI.getPanelEntity()
local violations = UIValidator.validate(panelEntity, nil, { skipHidden = true })
```

### Running UI Tests

**IMPORTANT: Always kill the app process after testing.** The game window stays open unless explicitly killed.

**Test different game states:**
- `MAIN_MENU` - Test main menu UI
- `IN_GAME` (planning phase) - Test inventory, deck builder, etc.
- `IN_GAME` (action phase) - Test combat UI, health bars, etc.

**Running the PlayerInventory validation test:**

```bash
# Run test and auto-exit (RECOMMENDED)
AUTO_START_MAIN_GAME=1 RUN_REAL_INVENTORY_TEST=1 AUTO_EXIT_AFTER_TEST=1 ./build/raylib-cpp-cmake-template

# With output capture and process kill (if AUTO_EXIT fails)
(AUTO_START_MAIN_GAME=1 RUN_REAL_INVENTORY_TEST=1 AUTO_EXIT_AFTER_TEST=1 ./build/raylib-cpp-cmake-template 2>&1 & sleep 15; kill $!) | grep -E "(VALIDATION|PASS|FAIL|warning|error)"
```

**Environment variables for testing:**
| Variable | Purpose |
|----------|---------|
| `AUTO_START_MAIN_GAME=1` | Skip main menu, go directly to IN_GAME state |
| `RUN_REAL_INVENTORY_TEST=1` | Run PlayerInventory UI validation test |
| `AUTO_EXIT_AFTER_TEST=1` | Exit app after test completes (prevents hanging) |

**Pattern for running tests that need specific game states:**

```bash
# Always use this pattern to avoid leaving app running:
(ENVVARS ./build/raylib-cpp-cmake-template 2>&1 & sleep N; kill $!) | grep/tail

# The subshell with & runs app in background
# sleep N waits for test to complete
# kill $! kills the app process
# Pipe to grep/tail filters output
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

### Don't: Exceed LuaJIT's 200 local variable limit

```lua
-- WRONG: File-scope locals accumulate in large files
local sound1 = loadSound("step1.wav")
local sound2 = loadSound("step2.wav")
local sound3 = loadSound("step3.wav")
-- ... 197 more locals = CRASH

-- RIGHT: Group related locals into tables
local sounds = {
    footsteps = {
        loadSound("step1.wav"),
        loadSound("step2.wav"),
        loadSound("step3.wav"),
    }
}
```

**Why:** LuaJIT has a hard limit of 200 local variables per function scope. Large files like `gameplay.lua` can hit this limit. Error message: `too many local variables (limit is 200)`.

### Don't: Forget ScreenSpaceCollisionMarker for UI elements

```lua
-- WRONG: UI element won't receive clicks
local button = createUIElement(...)
-- Missing collision marker!

-- RIGHT: Add collision marker for click detection
local button = createUIElement(...)
registry:emplace(button, ScreenSpaceCollisionMarker {})
```

**Why:** The engine uses dual quadtrees - `quadtreeWorld` for game objects and `quadtreeUI` for screen-space elements. `ScreenSpaceCollisionMarker` places entities in the UI quadtree for click detection.

### Don't: Mix World and Screen DrawCommandSpace carelessly

```lua
-- WRONG: HUD element follows camera
command_buffer.queueDraw(layers.ui, function(c)
    c.x, c.y = 10, 10  -- Screen position
end, z, layer.DrawCommandSpace.World)  -- Wrong! Will move with camera

-- RIGHT: Use Screen for fixed HUD
command_buffer.queueDraw(layers.ui, function(c)
    c.x, c.y = 10, 10
end, z, layer.DrawCommandSpace.Screen)  -- Fixed to viewport
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

## Core Lua Module Quick Reference

All modules in `assets/scripts/core/` - import with `require("core.<name>")`:

| Module | Purpose |
|--------|---------|
| `Q` | Quick transform helpers: position, rotation, bounds, physics velocity |
| `timer` | Centralized timing: `after`, `every`, `sequence`, `delay`, `loop`, `pulse` |
| `timer_chain` | Fluent sequential animations (used via `timer.sequence()`) |
| `draw` | Draw command API for rendering primitives, text, sprites |
| `text` | Animated text builder with rich formatting, fades, pops |
| `popup` | Quick damage/heal numbers with auto-positioning |
| `fx` | Unified visual effects: flash, shake, particles (NEW) |
| `tween` | Simplified property tweening with easing (NEW) |
| `fsm` | Declarative finite state machine (NEW) |
| `pool` | Generic object pooling for allocation reduction (NEW) |
| `debug` | Visual debugging: draw bounds, velocities, labels (NEW) |
| `ui_validator` | Rule-based UI validation: containment, z-order, overlaps |
| `entity_builder` | Entity creation with `create()`, `spawn()`, `quickSpawn()` |
| `physics_builder` | Fluent physics body creation |
| `shader_builder` | Fluent shader attachment |
| `behaviors` | Declarative enemy behavior composition |
| `signal_group` | Scoped event handlers with cleanup |
| `event_bridge` | Bridges combat bus events to signal system |
| `component_cache` | Cached ECS component access |
| `entity_cache` | Entity lookup by tag/name |
| `hitfx` | Hit effects (flash, shake, freeze-frame) |
| `particles` | Particle system wrapper |
| `localization_styled` | Color-coded localized text |
| `save_manager` | Save/load game state |
| `stat_system` | Character stats with modifiers |
| `globals` | Global game state and constants |
| `constants` | Game-wide constant values |

**NEW modules** added in this session provide friction-reducing APIs for common patterns.

---

## References

- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Content Creation Guides](docs/content-creation/)
- [Text Builder API](docs/api/text-builder.md)
- [API Documentation](docs/api/)
- Always provide full executable path in single line when done in a worktree (e.g., /Users/joshuashin/Projects/TheGameJamTemplate/inventory-grid-ui/build/raylib-cpp-cmake-template)
