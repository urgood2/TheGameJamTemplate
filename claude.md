# CLAUDE.md

## REQUIRED

- **NEVER use `rm -rf`** - blocked by hook. Use `trash folder-name` instead
- **Use terminal-notifier** for confirmations: `terminal-notifier -title "Claude Code" -message "Your message"`

## Workflow

- **Dispatch code review agent** at end of features via `superpowers:requesting-code-review`
- **Save before context compaction**: commit WIP, note task/next steps, push to remote
- **Prefer incremental builds** - avoid `just clean` unless necessary
- **Exponential backoff** when polling builds (1s → 2s → 4s → 8s)

## Build Commands

```bash
just build-debug              # Debug build → ./build/raylib-cpp-cmake-template
just build-release            # Release build
just build-debug-ninja        # Ninja (faster)
just test                     # Run tests
just build-web                # Web build (requires emsdk)
```

## Lua Debugging

```bash
# Auto-run and grep errors
(./build/raylib-cpp-cmake-template 2>&1 & sleep 8; kill $!) | grep -E "(error|Error|Lua)"

# Full output
(./build/raylib-cpp-cmake-template 2>&1 & sleep 8; kill $!) | tail -80
```

**Common errors:**
- `sol: cannot set (new_index)` → Use Lua-side registry, not `go.config.foo = bar`
- `attempt to index a nil value` → Component/entity not initialized

---

## C++ Bindings vs Lua Modules (CRITICAL)

```lua
-- WRONG: require() on C++ globals
local registry = require("core.registry")  -- ERROR!

-- CORRECT: Access C++ bindings directly
local registry = _G.registry  -- or just `registry`
```

**C++ Globals** (use directly): `registry`, `component_cache`, `shader_pipeline`, `physics`, `globals`, `localization`, `animation_system`, `layer_order_system`, `command_buffer`, `layers`, `z_orders`

**Lua Modules** (use require):
- `require("core.timer")`, `require("core.Q")`, `require("core.entity_builder")`
- `require("ui.ui_syntax_sugar")`, `require("external.hump.signal")`

---

## Architecture

**Engine**: C++20 + Lua on Raylib 5.5, EnTT (ECS), Chipmunk (physics)

- `src/core/` - Game loop, init, globals
- `src/components/` - 400+ ECS components
- `src/systems/` - 37+ subsystems (layer, physics, scripting, shaders, etc.)
- `assets/scripts/` - Lua gameplay (core, combat, ui, data)
- `assets/shaders/` - 200+ GLSL shaders

---

## Entity Script Pattern (CRITICAL)

**Data must be assigned BEFORE `attach_ecs()`!**

```lua
-- WRONG: data lost!
script:attach_ecs { ... }
script.data = {}

-- CORRECT
local script = EntityType {}
script.data = {}              -- Assign FIRST
script:attach_ecs { ... }     -- Attach LAST

-- BEST: Use factory methods
local script = Node.quick(entity, { health = 100 })  -- Existing entity
local script = Node.create({ health = 100 })         -- New entity
```

### State Management
```lua
script:setState(PLANNING_STATE)  -- Auto-clears previous state
```

### State Tags for Visibility
```lua
add_state_tag(entity, PLANNING_STATE)     -- Visible in planning phase
remove_state_tag(entity, PLANNING_STATE)  -- Hide from planning phase
-- Constants: PLANNING_STATE, ACTION_STATE, SHOP_STATE
```

For DSL UI boxes:
```lua
ui.box.AssignStateTagsToUIBox(entity, PLANNING_STATE)
remove_default_state_tag(entity)  -- Required for state visibility to work!
```

---

## Z-Order & Rendering

```lua
layer_order_system.assignZIndexToEntity(entity, z_orders.ui_tooltips + 100)
```

| Constant | Value | Purpose |
|----------|-------|---------|
| `z_orders.background` | ~0 | Background |
| `z_orders.card` | ~100 | Cards |
| `z_orders.ui_tooltips` | 900 | Tooltips |

### DrawCommandSpace
| Space | Use For |
|-------|---------|
| `layer.DrawCommandSpace.World` | Game objects (follows camera) |
| `layer.DrawCommandSpace.Screen` | HUD (fixed to viewport) |

### Dual Quadtree Collision
- **WITHOUT** `ScreenSpaceCollisionMarker` → World quadtree (game entities)
- **WITH** `ScreenSpaceCollisionMarker` → UI quadtree (buttons, UI)
- `FindAllEntitiesAtPoint()` queries both automatically

---

## Core APIs (Brief)

### Timer
```lua
local timer = require("core.timer")
timer.sequence("attack")
    :do_now(function() playSound("wind_up") end)
    :wait(0.3)
    :do_now(function() dealDamage(target, 50) end)
    :start()  -- REQUIRED!

timer.after_opts({ delay = 2.0, action = fn, tag = "my_timer" })
timer.kill_group("attack")
```

### Signal Events
```lua
local signal = require("external.hump.signal")
signal.emit("enemy_killed", entity)
signal.register("enemy_killed", function(e) ... end)

-- With cleanup
local signal_group = require("core.signal_group")
local handlers = signal_group.new("combat")
handlers:on("event", fn)
handlers:cleanup()  -- Remove all at once
```

### Q.lua (Transform Helpers)
```lua
local Q = require("core.Q")
Q.move(entity, x, y)
local cx, cy = Q.center(entity)      -- Physics position
local vx, vy = Q.visualCenter(entity) -- Rendered position (for effects)
local w, h = Q.size(entity)
```

### EntityBuilder
```lua
local EntityBuilder = require("core.entity_builder")
local entity = EntityBuilder.simple("sprite", x, y, w, h)
local entity, script = EntityBuilder.create({
    sprite = "kobold", position = { x = 100, y = 200 },
    data = { health = 100 }, state = PLANNING_STATE
})
```

### PhysicsBuilder
```lua
local PhysicsBuilder = require("core.physics_builder")
PhysicsBuilder.for_entity(entity)
    :circle():tag("projectile"):bullet()
    :collideWith({ "enemy" }):apply()
```

### UI DSL
```lua
local dsl = require("ui.ui_syntax_sugar")
local myUI = dsl.root {
    config = { padding = 10 },
    children = { dsl.text("Hello", { fontSize = 24 }) }
}
local entity = dsl.spawn({ x = 200, y = 200 }, myUI)
```

---

## Common Mistakes

| Don't | Do |
|-------|-----|
| `gameObj.myData = {}` | Use script table system |
| `getScriptTableFromEntityID()` without init | Use `Node.quick()` or `Node.create()` |
| `attach_ecs()` before data | Assign data first, attach last |
| 200+ local variables in file | Group into tables (LuaJIT limit) |
| UI without `ScreenSpaceCollisionMarker` | Add marker for click detection |
| HUD with `DrawCommandSpace.World` | Use `.Screen` for fixed HUD |

---

## Shaders

**GLSL**: Define helpers BEFORE use (no forward declarations).
**RenderTextures**: Flip Y in shader: `vec2(uv.x, 1.0 - uv.y)`
**Update both**: `assets/shaders/` AND `assets/shaders/web/`

---

## Common Events

| Event | Parameters |
|-------|------------|
| `"enemy_killed"` | entity |
| `"player_level_up"` | `{ xp, level }` |
| `"deck_changed"` | `{ source }` |
| `"stats_recomputed"` | nil |

---

## Core Module Index

| Module | Purpose | Docs |
|--------|---------|------|
| `Q` | Transform helpers | [Q_reference.md](docs/api/Q_reference.md) |
| `timer` | Timing, sequences | [timer_docs.md](docs/api/timer_docs.md) |
| `draw` | Draw commands | [shader_draw_commands_doc.md](docs/api/shader_draw_commands_doc.md) |
| `text` | Animated text | [text-builder.md](docs/api/text-builder.md) |
| `popup` | Damage/heal numbers | [popup.md](docs/api/popup.md) |
| `entity_builder` | Entity creation | [entity-builder.md](docs/api/entity-builder.md) |
| `physics_builder` | Physics bodies | [physics_docs.md](docs/api/physics_docs.md) |
| `shader_builder` | Shader attachment | [shader-builder.md](docs/api/shader-builder.md) |
| `behaviors` | Enemy AI composition | [behaviors.md](docs/api/behaviors.md) |
| `signal_group` | Scoped event handlers | [signal_system.md](docs/api/signal_system.md) |
| `ui_validator` | UI validation | [ui-validation.md](docs/api/ui-validation.md) |

---

## API Documentation

| Topic | Doc |
|-------|-----|
| Z-Order & Layers | [z-order-rendering.md](docs/api/z-order-rendering.md) |
| UI DSL | [ui-dsl-reference.md](docs/api/ui-dsl-reference.md) |
| Sprite Panels | [sprite-panels.md](docs/api/sprite-panels.md) |
| ChildBuilder | [child-builder.md](docs/api/child-builder.md) |
| Localization | [localization.md](docs/api/localization.md) |
| HitFX | [hitfx_doc.md](docs/api/hitfx_doc.md) |
| Particles | [particles_doc.md](docs/api/particles_doc.md) |
| Camera | [lua_camera_docs.md](docs/api/lua_camera_docs.md) |
| Combat Systems | [combat-systems.md](docs/api/combat-systems.md) |
| Inventory Grid | [inventory-grid.md](docs/api/inventory-grid.md) |

---

## References

- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Content Creation](docs/content-creation/)
