# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Workflow Reminders

- **Always show full file paths.** When referencing files, always display the complete absolute path (e.g., `/Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/docs/specs/example.md`), not just the relative path.
- **Always dispatch a new agent for review purposes at the end of a feature.** Use the `superpowers:requesting-code-review` skill.
- **Save progress before context compaction.** Commit WIP changes, note current task/next steps, push to remote.
- **Sync WezTerm config changes to repo.** After modifying `~/.config/wezterm/wezterm.lua`, sync to the wezterm-devbox-config repo:
  ```bash
  cp ~/.config/wezterm/wezterm.lua ~/Projects/wezterm-devbox-config/
  cd ~/Projects/wezterm-devbox-config && git add -A && git commit -m "feat: <description>" && git push
  ```
  Repo: https://github.com/urgood2/wezterm-devbox-config
- **Sync flywheel script changes.** After modifying the flywheel system on the VPS (`~/.local/bin/flywheel`, `~/.local/bin/flywheel-watchdog`), update the local flywheel-workflow repo and cheatsheet:
  ```bash
  # On VPS: Copy current script
  cat ~/.local/bin/flywheel

  # Locally: Update the repo
  cd ~/Projects/flywheel-workflow
  # Update setup-feature.sh or create flywheel-vps.sh with changes
  git add -A && git commit -m "feat: <description>" && git push
  ```
  VPS location: `ubuntu@161.97.94.111:~/.local/bin/flywheel`
  Local repo: `~/Projects/flywheel-workflow`

## Engine Quirks

For comprehensive documentation of engine gotchas and workarounds, see [Engine Quirks](docs/quirks.md).

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

## C++ Bindings vs Lua Modules

Canonical guidance lives in [Engine Quirks](docs/quirks.md) under "Lua / C++ Bindings". Keep this file lean and link to quirks for details.

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

See [Engine Quirks](docs/quirks.md) for the canonical list of engine gotchas and required ordering patterns.

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
