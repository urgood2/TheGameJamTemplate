# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Workflow Reminders

- **Always show full file paths.** When referencing files, always display the complete absolute path (e.g., `/Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/docs/specs/example.md`), not just the relative path.
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

### LuaJIT Backend (Optional)

The engine supports an optional LuaJIT 2.1 backend for improved Lua performance. Default is Lua 5.4.4.

```bash
cmake -B build-luajit -DUSE_LUAJIT=ON && cmake --build build-luajit  # LuaJIT
cmake -B build -DUSE_LUAJIT=OFF && cmake --build build               # Lua 5.4.4 (default)
```

**LuaJIT Limitations:**
- **Web builds**: LuaJIT does NOT work with Emscripten. Web builds force `USE_LUAJIT=OFF`.
- **200 local variable limit**: Per function scope (see Common Mistakes)
- **Bitwise operations**: Use `bit.bor()`, `bit.band()`, etc. from `bit_compat.lua` - NOT raw Lua 5.3+ operators

## Pixquare iPad Workflow

Sync pixel art from iPad (Pixquare app) via iCloud:

```bash
just watch-pixquare    # Watch mode (continuous)
just sync-pixquare-once # One-time sync
```

**Auto-start on login (recommended):**
```bash
just install-pixquare-service   # Install and start
just pixquare-service-status    # Check status
just uninstall-pixquare-service # Remove service
```

The service logs to `~/Library/Logs/pixquare-watcher.log`.

**iCloud folder setup (one-time):**
```bash
mkdir -p ~/Library/Mobile\ Documents/com~apple~CloudDocs/pixquare-animations
mkdir -p ~/Library/Mobile\ Documents/com~apple~CloudDocs/pixquare-sprites
```

**Workflow:**
- Animations: Export .aseprite to `pixquare-animations/` → auto-copied to `assets/animations/`
- Static sprites: Export .aseprite to `pixquare-sprites/` → layers merged into `auto_export_assets.aseprite`

Processed files are moved to `processed/` subfolder. To update an existing sprite, delete its `{name}_*` layers from `auto_export_assets.aseprite` first.

See `docs/plans/2026-02-03-pixquare-ipad-sync-design.md` for full design.

## Lua Runtime Debugging

```bash
# Auto-run and grep for errors:
(./build/raylib-cpp-cmake-template 2>&1 & sleep 8; kill $!) | grep -E "(error|Error|Lua)"

# Full output tail:
(./build/raylib-cpp-cmake-template 2>&1 & sleep 8; kill $!) | tail -80
```

**Common Lua error patterns:**
- `sol: cannot set (new_index)` → C++ userdata doesn't allow arbitrary keys. Use Lua-side registry table instead
- `attempt to index a nil value` → Component/entity not found or not initialized
- Stack traces show file:line → Read that exact location to find the bug

---

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

---

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

## Common Mistakes to Avoid

> **Full Reference**: See [COMMON_PITFALLS.md](docs/guides/COMMON_PITFALLS.md) for 183 documented pitfalls across 8 categories.

### Critical One-Liners (Most Frequent Causes of Bugs)

| Category | Pitfall | Quick Fix |
|----------|---------|-----------|
| **Data Loss** | Data assigned AFTER `attach_ecs()` | Assign ALL data BEFORE `attach_ecs()` |
| **UI Clicks** | Missing `ScreenSpaceCollisionMarker` | Add to ALL clickable UI entities |
| **UI Position** | Wrong `DrawCommandSpace` | Use `Screen` for HUD, `World` for game |
| **Callbacks** | Entity destroyed mid-callback | Always check `entity:valid()` first |
| **Physics** | Using old `globals.physicsWorld` | Use `PhysicsManager:getWorld("name")` |
| **Signals** | Using deprecated `publishLuaEvent()` | Use `signal.emit()` instead |
| **Timers** | Chain/tween never started | Call `:start()` or `:go()` to execute |
| **Timers** | Timer outlives entity | Use timer groups + `timer.kill_group()` |
| **Shaders** | Helper function used before defined | Define all functions before use in GLSL |
| **LuaJIT** | 200+ locals in one file | Group related locals into tables |
| **Jokers** | Effect returns nothing | Always return modified value |
| **Content** | Table key ≠ id field | Keep table key and `id` synchronized |

---

### Don't: Store data in GameObject component
```lua
local gameObj = component_cache.get(entity, GameObject)
gameObj.myData = {}  -- WRONG - bypasses script table system
```

### Don't: Call attach_ecs before assigning data
```lua
script:attach_ecs { ... }
script.data = {}  -- WRONG - data is lost!
```

### Do: Initialize properly (see [Entity Scripts Guide](docs/guides/entity-scripts.md))
```lua
local script = EntityType {}
script.data = {}              -- Assign FIRST
script:attach_ecs { ... }     -- Attach LAST
```

### Don't: Exceed LuaJIT's 200 local variable limit
```lua
-- WRONG: File-scope locals accumulate
local sound1, sound2, sound3 = ...  -- 197 more = CRASH

-- RIGHT: Group into tables
local sounds = { footsteps = { ... } }
```

### Don't: Forget ScreenSpaceCollisionMarker for UI elements
```lua
-- WRONG: UI element won't receive clicks
local button = createUIElement(...)

-- RIGHT: Add collision marker for click detection
registry:emplace(button, ScreenSpaceCollisionMarker {})
```

### Don't: Implement UI panels without reading the guide
**For ANY UI panel work (skill trees, equipment windows, inventory, character sheets):**
→ **READ FIRST**: [UI Panel Implementation Guide](docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md)

Critical patterns that WILL break if done wrong:
- Must move BOTH entity Transform AND `UIBoxComponent.uiRoot` for visibility
- Must call `ui.box.AddStateTagToUIBox` after spawn AND after `ReplaceChildren`
- Must call `ui.box.RenewAlignment` after ANY `ReplaceChildren` operation
- Must clean all 3 registries on grid destroy: `itemRegistry`, `grid`, `dsl.cleanupGrid`
- NEVER add `ObjectAttachedToUITag` to draggable cards/items

### Don't: Use ChildBuilder.setOffset on UIBox without RenewAlignment
```lua
-- WRONG: Children inside UIBox won't reposition after offset change
ChildBuilder.setOffset(uiContainer, x, y)

-- RIGHT: Call RenewAlignment after changing offset to force child layout update
ChildBuilder.setOffset(uiContainer, x, y)
ui.box.RenewAlignment(registry, uiContainer)
```

### Don't: Mix World and Screen DrawCommandSpace carelessly
```lua
-- WRONG: HUD follows camera
command_buffer.queueDraw(layers.ui, fn, z, layer.DrawCommandSpace.World)

-- RIGHT: Use Screen for fixed HUD
command_buffer.queueDraw(layers.ui, fn, z, layer.DrawCommandSpace.Screen)
```

### UI Decorations: Slot Underlays
- To render a slot decoration behind the slot sprite (e.g., wand trigger backdrop), use a decoration with `zOffset < 0` on a sprite-panel slot.
- Inventory grid slot decorations are supported via `slotConfig.decorations` or `gridConfig.slotDecorations`. When a slot uses a sprite panel, decorations are scaled by `ui_scale.SPRITE_SCALE` at definition time.

### Quick Diagnostic Checklist

**UI Not Responding?** → ScreenSpaceCollisionMarker? → DrawCommandSpace? → Z-order? → UIRoot transform?

**Entity Data Nil?** → Data before attach_ecs? → Using global component name (not string)? → Entity valid?

**Physics Broken?** → PhysicsManager:getWorld()? → Same world? → Collision categories match?

**Timer Not Firing?** → :start()/:go() called? → Scope not destroyed? → Entity valid in callback?

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

## Core Lua Module Quick Reference

All modules in `assets/scripts/core/` - import with `require("core.<name>")`:

| Module | Purpose | Docs |
|--------|---------|------|
| `Q` | Quick transform helpers | [Q_reference.md](docs/api/Q_reference.md) |
| `timer` | Centralized timing | [timer_docs.md](docs/api/timer_docs.md) |
| `draw` | Draw command API | [shader_draw_commands_doc.md](docs/api/shader_draw_commands_doc.md) |
| `text` | Animated text builder | [text-builder.md](docs/api/text-builder.md) |
| `popup` | Quick damage/heal numbers | [popup.md](docs/api/popup.md) |
| `ui_validator` | Rule-based UI validation | [ui-validation.md](docs/api/ui-validation.md) |
| `entity_builder` | Entity creation | [entity-builder.md](docs/api/entity-builder.md) |
| `physics_builder` | Fluent physics body creation | [physics_docs.md](docs/api/physics_docs.md) |
| `shader_builder` | Fluent shader attachment | [shader-builder.md](docs/api/shader-builder.md) |
| `behaviors` | Enemy behavior composition | [behaviors.md](docs/api/behaviors.md) |
| `signal_group` | Scoped event handlers | [signal_system.md](docs/api/signal_system.md) |
| `child_builder` | Child entity attachment | [child-builder.md](docs/api/child-builder.md) |
| `hitfx` | Hit effects | [hitfx_doc.md](docs/api/hitfx_doc.md) |
| `particles` | Particle system wrapper | [particles_doc.md](docs/api/particles_doc.md) |
| `localization_styled` | Color-coded localized text | [localization.md](docs/api/localization.md) |

---

## API Documentation Index

### Rendering & UI
- **[UI Panel Implementation Guide](docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md)** - **START HERE for any UI work** (skill trees, equipment windows, inventory panels). Bulletproof patterns from `player_inventory.lua`
- [Z-Order and Layer Rendering](docs/api/z-order-rendering.md) - Z-ordering, DrawCommandSpace, dual quadtree collision
- [UI DSL Reference](docs/api/ui-dsl-reference.md) - Declarative UI construction
- [UI Validation](docs/api/ui-validation.md) - Layout validation and testing
- [Sprite Panels](docs/api/sprite-panels.md) - Nine-patch panels and decorations
- [Render Groups](docs/api/render-groups.md) - Batched rendering

### Entity & Physics
- [Entity Scripts Guide](docs/guides/entity-scripts.md) - Script initialization, state tags, game phases
- [Entity Builder](docs/api/entity-builder.md) - Entity creation API
- [Child Builder](docs/api/child-builder.md) - Parent-child entity attachment
- [Physics](docs/api/physics_docs.md) - Physics bodies, collision masks

### Events & Timing
- [Event System (Signals)](docs/api/signal_system.md) - Signal library, event bridge
- [Timer API](docs/api/timer_docs.md) - Timing, sequences, chains

### Effects & Animation
- [Text Builder](docs/api/text-builder.md) - Animated text with rich formatting
- [HitFX](docs/api/hitfx_doc.md) - Flash, shake, freeze-frame effects
- [Particles](docs/api/particles_doc.md) - Particle system

### Shaders
- [Shader Builder](docs/api/shader-builder.md) - Attaching shaders to entities
- [Draw Commands](docs/api/shader_draw_commands_doc.md) - Shader pipeline draw API

### Content Creation
- [Content Overview](docs/content-creation/CONTENT_OVERVIEW.md) - Adding cards, enemies, jokers
- [Adding Cards](docs/content-creation/ADDING_CARDS.md)
- [Adding Enemies](docs/content-creation/ADDING_ENEMIES.md)
- [Adding Jokers](docs/content-creation/ADDING_JOKERS.md)
- [Adding Projectiles](docs/content-creation/ADDING_PROJECTILES.md)

### Combat
- [Combat Systems](docs/api/combat-systems.md) - Combat mechanics reference

### Other
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Lua API Reference](docs/api/lua_api_reference.md)
- [Camera](docs/api/lua_camera_docs.md)
- [Save System](docs/api/save-system.md)

---

**Note:** Always provide full executable path when done in a worktree (e.g., `/Users/joshuashin/Projects/TheGameJamTemplate/inventory-grid-ui/build/raylib-cpp-cmake-template`)
