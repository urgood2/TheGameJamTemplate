# Lua API Cookbook PDF Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Generate a comprehensive, task-oriented PDF cookbook for the Lua codebase with ~76 pages of recipes.

**Architecture:** Markdown source files → Pandoc with LaTeX → PDF. Each chapter written by subagent, reviewed by fresh agent, then assembled.

**Tech Stack:** Pandoc, XeLaTeX, Markdown, Bash

---

## Task 1: Create Directory Structure and Pandoc Config

**Files:**
- Create: `docs/lua-cookbook/metadata.yaml`
- Create: `docs/lua-cookbook/build.sh`
- Create: `docs/lua-cookbook/output/.gitkeep`

**Step 1: Create directory structure**

```bash
mkdir -p docs/lua-cookbook/output
touch docs/lua-cookbook/output/.gitkeep
```

**Step 2: Create metadata.yaml**

Create `docs/lua-cookbook/metadata.yaml`:

```yaml
title: "Lua API Cookbook"
subtitle: "TheGameJamTemplate Quick Reference"
author: "Auto-generated from codebase"
date: 2025-12-14
documentclass: report
classoption:
  - oneside
geometry:
  - margin=1in
  - headheight=14pt
fontsize: 11pt
mainfont: "Helvetica Neue"
sansfont: "Helvetica Neue"
monofont: "Menlo"
monofontoptions:
  - Scale=0.85
linkcolor: "blue"
urlcolor: "blue"
toc: true
toc-depth: 2
numbersections: true
highlight-style: tango
header-includes:
  - \usepackage{fancyhdr}
  - \pagestyle{fancy}
  - \fancyhead[L]{\leftmark}
  - \fancyhead[R]{\thepage}
  - \fancyfoot[C]{}
  - \usepackage{awesomebox}
  - \usepackage{listings}
  - \lstset{breaklines=true, basicstyle=\ttfamily\small}
```

**Step 3: Create build.sh**

Create `docs/lua-cookbook/build.sh`:

```bash
#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Building Lua Cookbook PDF..."

pandoc cookbook.md \
  --metadata-file=metadata.yaml \
  --pdf-engine=xelatex \
  --toc \
  --resource-path=.:.. \
  -o output/lua-cookbook.pdf

echo "Done! Output: docs/lua-cookbook/output/lua-cookbook.pdf"
```

**Step 4: Make build script executable**

```bash
chmod +x docs/lua-cookbook/build.sh
```

**Step 5: Verify Pandoc is installed**

Run: `pandoc --version`
Expected: Version info (if missing: `brew install pandoc`)

Run: `xelatex --version`
Expected: Version info (if missing: `brew install --cask mactex-no-gui`)

**Step 6: Commit setup**

```bash
git add docs/lua-cookbook/
git commit -m "chore: set up Lua cookbook PDF generation structure"
```

---

## Task 2: Write Front Matter (Title, Quick Start, Task Index Placeholder)

**Files:**
- Create: `docs/lua-cookbook/cookbook.md`

**Step 1: Extract a real working example from codebase**

Search for EntityBuilder usage:
```bash
grep -r "EntityBuilder.create" assets/scripts/ --include="*.lua" -l | head -3
```

Read a real example to base Quick Start on.

**Step 2: Write front matter**

Create `docs/lua-cookbook/cookbook.md`:

```markdown
---
title: Lua API Cookbook
---

# Quick Start: Your First Entity in 60 Seconds

```lua
-- 1. Import what you need
local EntityBuilder = require("core.entity_builder")
local PhysicsBuilder = require("core.physics_builder")

-- 2. Create an entity with a sprite
local entity, script = EntityBuilder.create({
    sprite = "kobold",           -- animation/sprite ID
    position = { 100, 200 },     -- x, y coordinates
    size = { 64, 64 },           -- width, height
    shadow = true,               -- optional shadow
})

-- 3. Add physics (optional)
PhysicsBuilder.for_entity(entity)
    :circle()
    :tag("enemy")
    :apply()

-- 4. Add interactivity (optional)
local nodeComp = registry:get(entity, GameObject)
nodeComp.state.clickEnabled = true
nodeComp.methods.onClick = function()
    print("Clicked!")
end
```

**That's it!** The entity now renders, has physics, and responds to clicks.

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
| Chain actions in sequence | \pageref{recipe:timer-sequence} |
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
```

**Step 3: Test PDF generation (should work even with partial content)**

```bash
cd docs/lua-cookbook && ./build.sh
```
Expected: PDF generated at `output/lua-cookbook.pdf`

**Step 4: Commit front matter**

```bash
git add docs/lua-cookbook/cookbook.md
git commit -m "docs: add cookbook front matter with quick start and task index"
```

---

## Task 3: Write Chapter 1 — Core Foundations

**Files:**
- Modify: `docs/lua-cookbook/cookbook.md` (append)

**Step 1: Extract actual API patterns from codebase**

Search for patterns in these files:
- `assets/scripts/core/timer.lua` — timer API
- `assets/scripts/core/entity_cache.lua` — validation
- `assets/scripts/core/component_cache.lua` — component access
- `assets/scripts/external/hump/signal.lua` — events
- `assets/scripts/core/imports.lua` — imports bundle (if exists)

For each, extract:
1. Public function signatures
2. Real usage examples from gameplay.lua or other files
3. Note file:line for provenance

**Step 2: Write Chapter 1 content**

Append to `docs/lua-cookbook/cookbook.md`:

```markdown
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

## Imports Bundle

\label{recipe:imports-bundle}

**When to use:** Reduce boilerplate when you need multiple core modules.

```lua
local imports = require("core.imports")

-- Core bundle (most common)
local component_cache, entity_cache, timer, signal, z_orders = imports.core()

-- Entity creation bundle
local Node, animation_system, EntityBuilder = imports.entity()

-- Physics bundle
local PhysicsManager, PhysicsBuilder = imports.physics()

-- UI bundle
local dsl, z_orders, util = imports.ui()

-- Everything as table
local i = imports.all()
-- Access: i.timer, i.EntityBuilder, i.signal, etc.
```

*— from core/imports.lua*

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

*— from core/entity_cache.lua*

### Global Helpers (Preferred)

```lua
-- Shorter syntax available globally after util.lua loads
if not ensure_entity(eid) then return end

-- For entities that must have scripts
if not ensure_scripted_entity(eid) then return end
```

*— from globals.lua*

**Gotcha:** Always validate in callbacks — the entity may have been destroyed between when you scheduled the callback and when it runs.

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

*— from core/component_cache.lua*

**Gotcha:** Component names are globals (Transform, GameObject, etc.) — don't quote them.

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

-- With options (tag for cancellation)
timer.after_opts({
    delay = 2.0,
    action = function() print("done") end,
    tag = "my_timer"
})

-- Cancel by tag
timer.cancel("my_timer")
```

*— from core/timer.lua*

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

-- With options
timer.every_opts({
    delay = 0.5,
    action = updateHealth,
    times = 10,           -- limit iterations (0 = infinite)
    immediate = true,     -- run once immediately
    tag = "health_update"
})
```

*— from core/timer.lua*

---

## Timer: Chained Sequence

\label{recipe:timer-sequence}

**When to use:** Multiple delayed actions in order (avoids nested callbacks).

```lua
local timer = require("core.timer")

-- Fluent chaining
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

*— from core/timer.lua or core/timer_chain.lua*

**Gotcha:** Don't forget `:start()` at the end — sequence won't run without it.

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

*— from external/hump/signal.lua, usage in gameplay.lua:3569-3625*

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

*— from globals.lua*

---

## Common Pattern: Defensive Entity Access

```lua
-- Standard pattern for any entity operation
if not ensure_entity(eid) then return end

local script = safe_script_get(eid)
if not script then return end

local transform = component_cache.get(eid, Transform)
if not transform then return end

-- Now safe to use eid, script, transform
```

\newpage
```

**Step 3: Verify code snippets against actual source**

For each snippet, grep to confirm API exists:
```bash
grep -n "timer.after" assets/scripts/core/timer.lua | head -3
grep -n "signal.emit" assets/scripts/ -r --include="*.lua" | head -3
grep -n "entity_cache.valid" assets/scripts/core/entity_cache.lua
```

**Step 4: Build PDF to verify formatting**

```bash
cd docs/lua-cookbook && ./build.sh
open output/lua-cookbook.pdf
```

**Step 5: Commit Chapter 1**

```bash
git add docs/lua-cookbook/cookbook.md
git commit -m "docs: add Chapter 1 - Core Foundations"
```

---

## Task 4: Write Chapter 2 — Entity Creation

**Files:**
- Modify: `docs/lua-cookbook/cookbook.md` (append)

**Step 1: Extract patterns from codebase**

Search these files:
- `assets/scripts/core/entity_builder.lua`
- `assets/scripts/core/entity_factory.lua`
- `assets/scripts/core/animation_system.lua` (if exists, or find in core/)
- `assets/scripts/monobehavior/behavior_script_v2.lua`

Find real usage:
```bash
grep -r "EntityBuilder.create" assets/scripts/ --include="*.lua" -A 10 | head -50
grep -r "attach_ecs" assets/scripts/ --include="*.lua" -B 5 -A 3 | head -40
```

**Step 2: Write Chapter 2 content**

Append to `docs/lua-cookbook/cookbook.md`:

```markdown
# Entity Creation

## EntityBuilder: Full Options

\label{recipe:entity-sprite}

**When to use:** Create game entities with sprites, physics, interactivity.

```lua
local EntityBuilder = require("core.entity_builder")

local entity, script = EntityBuilder.create({
    sprite = "kobold",              -- animation/sprite ID
    position = { x = 100, y = 200 },-- or { 100, 200 }
    size = { 64, 64 },              -- width, height (default: 32x32)
    shadow = true,                  -- enable shadow
    data = {                        -- script table data
        health = 100,
        faction = "enemy"
    },
    interactive = {                 -- interaction config
        hover = { title = "Enemy", body = "A dangerous kobold" },
        click = function(reg, eid) print("clicked!") end,
        drag = true,
        collision = true
    },
    state = PLANNING_STATE,         -- state tag to add
    shaders = { "3d_skew_holo" }    -- shader list
})
```

*— from core/entity_builder.lua*

---

## EntityBuilder: Simple Creation

\label{recipe:entity-simple}

**When to use:** Quick entity with just sprite and position.

```lua
local EntityBuilder = require("core.entity_builder")

-- Minimal: sprite, x, y, width, height
local entity = EntityBuilder.simple("kobold", 100, 200, 64, 64)
```

---

## EntityBuilder: Interactive Entity

\label{recipe:entity-interactive}

**When to use:** Entity with hover tooltip and click handler.

```lua
local EntityBuilder = require("core.entity_builder")

local entity, script = EntityBuilder.interactive({
    sprite = "button",
    position = { 100, 100 },
    hover = { title = "Click me", body = "Description text" },
    click = function() print("clicked!") end
})
```

---

## Script Table Pattern (Node)

\label{recipe:script-table}

**When to use:** Store custom data on an entity that persists and is accessible via `getScriptTableFromEntityID()`.

```lua
local Node = require("monobehavior.behavior_script_v2")

-- 1. Create entity
local entity = registry:create()

-- 2. Create script instance
local EntityType = Node:extend()
local entityScript = EntityType {}

-- 3. Assign data BEFORE attach_ecs (CRITICAL!)
entityScript.customData = { foo = "bar" }
entityScript.health = 100

-- 4. Attach to entity LAST
entityScript:attach_ecs {
    create_new = false,
    existing_entity = entity
}

-- Now getScriptTableFromEntityID(entity) returns entityScript
```

*— Pattern from CLAUDE.md, usage throughout gameplay.lua*

**Gotchas:**

- Data MUST be assigned BEFORE `attach_ecs()` — order matters!
- After `attach_ecs()`, use the `entityScript` variable directly
- Don't call `getScriptTableFromEntityID()` immediately after attach — may return nil

---

## Animation System: Create Animated Entity

**When to use:** Lower-level entity creation with animation.

```lua
local animation_system = require("core.animation_system")

-- Create entity with animated sprite
local entity = animation_system.createAnimatedObjectWithTransform(
    "sprite_animation_id",  -- animation ID from assets
    true                    -- true = animation ID, false = sprite ID
)

-- Resize animation to fit
animation_system.resizeAnimationObjectsInEntityToFit(
    entity,
    64,   -- target width
    64    -- target height
)
```

---

## GameObject Callbacks

**When to use:** Add click/hover/drag behavior to existing entity.

```lua
-- Get GameObject (already exists on entities)
local nodeComp = registry:get(entity, GameObject)

-- Enable interaction modes
nodeComp.state.hoverEnabled = true
nodeComp.state.clickEnabled = true
nodeComp.state.dragEnabled = true
nodeComp.state.collisionEnabled = true

-- Set callbacks
nodeComp.methods.onClick = function(registry, clickedEntity)
    print("Clicked:", clickedEntity)
end

nodeComp.methods.onHover = function()
    print("Hovering")
end

nodeComp.methods.onDrag = function()
    print("Dragging")
end

nodeComp.methods.onStopDrag = function()
    print("Stopped dragging")
end
```

*— from gameplay.lua*

**Gotcha:** Don't emplace GameObject — it already exists on entities created via animation_system or EntityBuilder.

---

## State Tags

**When to use:** Control entity visibility/behavior based on game state.

```lua
-- Add state tag
add_state_tag(entity, PLANNING_STATE)

-- Remove default state
remove_default_state_tag(entity)

-- Check state
if is_state_active(PLANNING_STATE) then
    -- Do something
end

-- Activate/deactivate
activate_state(PLANNING_STATE)
deactivate_state(PLANNING_STATE)
```

\newpage
```

**Step 3: Verify against source**

```bash
grep -n "EntityBuilder.create" assets/scripts/core/entity_builder.lua | head -5
grep -n "attach_ecs" assets/scripts/monobehavior/ -r | head -5
```

**Step 4: Build and verify**

```bash
cd docs/lua-cookbook && ./build.sh
```

**Step 5: Commit**

```bash
git add docs/lua-cookbook/cookbook.md
git commit -m "docs: add Chapter 2 - Entity Creation"
```

---

## Task 5: Write Chapter 3 — Physics

**Files:**
- Modify: `docs/lua-cookbook/cookbook.md` (append)

**Step 1: Extract from codebase**

Search:
- `assets/scripts/core/physics_builder.lua`
- `assets/scripts/core/physics_manager.lua`
- Usage in gameplay.lua for real patterns

```bash
grep -r "PhysicsBuilder" assets/scripts/ --include="*.lua" -A 5 | head -40
grep -r "PhysicsManager.get_world" assets/scripts/ --include="*.lua" | head -10
```

**Step 2: Write Chapter 3**

Append to `docs/lua-cookbook/cookbook.md`:

```markdown
# Physics

## Get Physics World

\label{recipe:physics-world}

**When to use:** Before any physics operation.

```lua
local PhysicsManager = require("core.physics_manager")

local world = PhysicsManager.get_world("world")
if not world then
    log_warn("Physics world not available")
    return
end
```

*— from core/physics_manager.lua*

**Gotcha:** Use `PhysicsManager.get_world("world")`, NOT `globals.physicsWorld` (deprecated).

---

## PhysicsBuilder: Add Physics to Entity

\label{recipe:add-physics}
\label{recipe:entity-physics}

**When to use:** Make an entity participate in physics simulation.

```lua
local PhysicsBuilder = require("core.physics_builder")

PhysicsBuilder.for_entity(entity)
    :circle()                       -- or :rectangle()
    :tag("enemy")                   -- collision tag
    :apply()
```

---

## PhysicsBuilder: Full Options

```lua
local PhysicsBuilder = require("core.physics_builder")

PhysicsBuilder.for_entity(entity)
    :circle()                           -- shape: circle or rectangle
    :tag("projectile")                  -- collision tag
    :sensor(false)                      -- true = no physical response
    :density(1.0)                       -- mass density
    :friction(0.0)                      -- surface friction
    :restitution(0.5)                   -- bounciness
    :bullet()                           -- CCD for fast objects
    :fixedRotation()                    -- lock rotation
    :syncMode("physics")                -- "physics" or "transform"
    :collideWith({ "enemy", "WORLD" })  -- tags to collide with
    :apply()
```

*— from core/physics_builder.lua*

---

## PhysicsBuilder: Quick Setup

**When to use:** One-liner physics with options table.

```lua
local PhysicsBuilder = require("core.physics_builder")

PhysicsBuilder.quick(entity, {
    shape = "circle",
    tag = "projectile",
    bullet = true,
    collideWith = { "enemy", "WORLD" }
})
```

---

## Collision Tags and Masks

\label{recipe:collision-masks}

**When to use:** Control what collides with what.

```lua
local PhysicsManager = require("core.physics_manager")
local world = PhysicsManager.get_world("world")

-- Enable collision between tags
physics.enable_collision_between_many(world, "projectile", { "enemy" })
physics.enable_collision_between_many(world, "enemy", { "projectile" })

-- Update masks for affected tags
physics.update_collision_masks_for(world, "projectile", { "enemy" })
physics.update_collision_masks_for(world, "enemy", { "projectile" })
```

**Gotcha:** Collision masks are per-entity. Set them when creating each entity's physics, not globally in init.

---

## Bullet Mode (Fast Objects)

\label{recipe:bullet-mode}

**When to use:** Prevent fast-moving objects from tunneling through walls.

```lua
-- Via PhysicsBuilder
PhysicsBuilder.for_entity(entity)
    :circle()
    :tag("bullet")
    :bullet()  -- enables CCD
    :apply()

-- Or direct API
local world = PhysicsManager.get_world("world")
physics.SetBullet(world, entity, true)
```

---

## Sync Modes

**When to use:** Control whether physics or transform is authoritative.

```lua
-- Physics controls position (default for dynamic bodies)
physics.set_sync_mode(registry, entity, physics.PhysicsSyncMode.AuthoritativePhysics)

-- Transform controls position (for kinematic/scripted movement)
physics.set_sync_mode(registry, entity, physics.PhysicsSyncMode.AuthoritativeTransform)
```

**Gotcha:** Use `physics.set_sync_mode()`, NOT manual PhysicsSyncConfig emplacement.

---

## Physics Properties

```lua
local world = PhysicsManager.get_world("world")

-- Set properties
physics.SetFriction(world, entity, 0.0)
physics.SetRestitution(world, entity, 0.5)
physics.SetFixedRotation(world, entity, true)

-- Apply impulse
physics.ApplyImpulse(world, entity, forceX, forceY)

-- Set velocity directly
physics.SetLinearVelocity(world, entity, vx, vy)
```

\newpage
```

**Step 3: Verify and commit**

```bash
grep -n "PhysicsBuilder" assets/scripts/core/physics_builder.lua | head -10
cd docs/lua-cookbook && ./build.sh
git add docs/lua-cookbook/cookbook.md
git commit -m "docs: add Chapter 3 - Physics"
```

---

## Task 6: Write Chapter 4 — Rendering & Shaders

**Files:**
- Modify: `docs/lua-cookbook/cookbook.md` (append)

**Step 1: Extract from codebase**

```bash
grep -r "ShaderBuilder" assets/scripts/ --include="*.lua" -A 5 | head -40
grep -r "draw.textPro\|draw.local_command" assets/scripts/ --include="*.lua" | head -20
cat assets/scripts/core/shader_builder.lua | head -100
cat assets/scripts/core/draw.lua | head -100
```

**Step 2: Write Chapter 4**

Append to `docs/lua-cookbook/cookbook.md`:

```markdown
# Rendering & Shaders

## ShaderBuilder: Add Shader

\label{recipe:add-shader}

**When to use:** Apply visual effects to entities.

```lua
local ShaderBuilder = require("core.shader_builder")

ShaderBuilder.for_entity(entity)
    :add("3d_skew_holo")
    :apply()
```

*— from core/shader_builder.lua*

---

## ShaderBuilder: With Uniforms

**When to use:** Customize shader parameters.

```lua
local ShaderBuilder = require("core.shader_builder")

ShaderBuilder.for_entity(entity)
    :add("3d_skew_holo", { sheen_strength = 1.5 })
    :add("dissolve", { dissolve = 0.5 })
    :apply()
```

---

## ShaderBuilder: Stack Multiple Shaders

\label{recipe:stack-shaders}

```lua
local ShaderBuilder = require("core.shader_builder")

ShaderBuilder.for_entity(entity)
    :add("3d_skew_holo")
    :add("outline")
    :add("dissolve", { dissolve = 0.3 })
    :apply()
```

---

## ShaderBuilder: Clear and Rebuild

```lua
local ShaderBuilder = require("core.shader_builder")

ShaderBuilder.for_entity(entity)
    :clear()
    :add("3d_skew_prismatic")
    :apply()
```

---

## Shader Families

Shaders with matching prefix get automatic defaults:

| Prefix | Family | Defaults |
|--------|--------|----------|
| `3d_skew_*` | Card shaders | regionRate, pivot, etc. |
| `liquid_*` | Fluid effects | wave_speed, wave_amplitude |

Register custom family:
```lua
ShaderBuilder.register_family("energy", {
    uniforms = { "pulse_speed", "glow_intensity" },
    defaults = { pulse_speed = 1.0 },
})
```

---

## Draw: Text

\label{recipe:draw-text}

**When to use:** Render text to screen or world.

```lua
local draw = require("core.draw")

-- Table-based (preferred)
draw.textPro(layer, {
    text = "Hello",
    x = 100,
    y = 200,
    fontSize = 16,
    color = WHITE
}, z, space)
```

*— from core/draw.lua*

---

## Draw: Local Command (Shader Pipeline)

**When to use:** Draw through entity's shader pipeline.

```lua
local draw = require("core.draw")

draw.local_command(entity, "text_pro", {
    text = "Shaded text",
    x = 10,
    y = 20,
    fontSize = 20,
}, { z = 1, preset = "shaded_text" })
```

---

## Render Presets

| Preset | Effect |
|--------|--------|
| `"shaded_text"` | textPass=true, uvPassthrough=true |
| `"sticker"` | stickerPass=true, uvPassthrough=true |
| `"world"` | space=World |
| `"screen"` | space=Screen |

---

## Z-Ordering

```lua
local z_orders = require("core.z_orders")

-- Use predefined z-orders for consistency
-- Lower = rendered first (behind)
-- Higher = rendered last (in front)
```

\newpage
```

**Step 3: Verify and commit**

```bash
cd docs/lua-cookbook && ./build.sh
git add docs/lua-cookbook/cookbook.md
git commit -m "docs: add Chapter 4 - Rendering & Shaders"
```

---

## Task 7: Write Chapter 5 — UI System

**Files:**
- Modify: `docs/lua-cookbook/cookbook.md` (append)

**Step 1: Extract from codebase**

```bash
cat assets/scripts/ui/ui_syntax_sugar.lua | head -150
grep -r "dsl.root\|dsl.vbox\|dsl.hbox" assets/scripts/ --include="*.lua" -A 10 | head -60
```

**Step 2: Write Chapter 5**

Append to `docs/lua-cookbook/cookbook.md`:

```markdown
# UI System

## UI DSL: Basic Structure

\label{recipe:ui-dsl}

**When to use:** Build UI layouts declaratively.

```lua
local dsl = require("ui.ui_syntax_sugar")

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
            config = { spacing = 6 },
            children = {
                dsl.text("Title", { fontSize = 24 }),
                dsl.text("Subtitle", { fontSize = 16 })
            }
        }
    }
}

-- Spawn at position
local boxID = dsl.spawn({ x = 200, y = 200 }, myUI)
```

*— from ui/ui_syntax_sugar.lua*

---

## DSL: Horizontal Layout

```lua
dsl.hbox {
    config = { spacing = 4 },
    children = {
        dsl.text("Left"),
        dsl.text("Right")
    }
}
```

---

## DSL: Text Element

```lua
-- Simple
dsl.text("Hello", { fontSize = 16, color = "white" })

-- With hover tooltip
dsl.text("Hover me", {
    hover = {
        title = "Tooltip Title",
        body = "Tooltip description"
    }
})

-- With click handler
dsl.text("Click me", {
    onClick = function() print("clicked") end
})
```

---

## DSL: Animated Sprite

```lua
dsl.anim("sprite_id", {
    w = 40,
    h = 40,
    shadow = true
})
```

---

## DSL: Grid Layout

\label{recipe:ui-grid}

```lua
-- Uniform grid
dsl.grid(3, 4, function(row, col)
    return dsl.text(string.format("(%d,%d)", row, col))
end)
```

---

## DSL: Dynamic Text

**When to use:** Text that updates automatically.

```lua
dsl.dynamicText(
    function() return "Score: " .. getScore() end,
    16,      -- fontSize
    "juicy", -- text effect (optional)
    {}       -- additional opts
)
```

---

## Spawning UI

```lua
local dsl = require("ui.ui_syntax_sugar")

-- Basic spawn
local boxID = dsl.spawn({ x = 200, y = 200 }, uiDefinition)

-- With layer and z-index
local boxID = dsl.spawn(
    { x = 200, y = 200 },
    uiDefinition,
    "ui_layer",  -- layer name
    100          -- z-index
)
```

---

## Tooltips

\label{recipe:tooltip}

```lua
-- On any DSL element
dsl.text("Hover", {
    hover = {
        title = "Title",
        body = "Description",
        id = "unique_id"  -- optional
    }
})

-- Or via EntityBuilder
EntityBuilder.create({
    sprite = "item",
    interactive = {
        hover = { title = "Item", body = "An item" }
    }
})
```

---

## Text Effects

```lua
-- Available effects (from ui/text_effects/)
-- "static"     - No animation
-- "juicy"      - Bounce/scale effects
-- "magical"    - Sparkle/glow
-- "elemental"  - Fire/ice/etc themed
-- "continuous" - Looping animations
-- "oneshot"    - Play-once animations
```

\newpage
```

**Step 3: Verify and commit**

```bash
cd docs/lua-cookbook && ./build.sh
git add docs/lua-cookbook/cookbook.md
git commit -m "docs: add Chapter 5 - UI System"
```

---

## Task 8: Write Chapter 6 — Combat & Projectiles

**Files:**
- Modify: `docs/lua-cookbook/cookbook.md` (append)

**Step 1: Extract from codebase**

```bash
cat assets/scripts/combat/projectile_system.lua | head -200
cat assets/scripts/data/projectiles.lua | head -100
grep -r "spawn.*projectile\|create.*projectile" assets/scripts/ --include="*.lua" -i | head -20
```

**Step 2: Write Chapter 6**

Append to `docs/lua-cookbook/cookbook.md`:

```markdown
# Combat & Projectiles

## Spawn Projectile from Preset

\label{recipe:spawn-projectile}

**When to use:** Fire a projectile with predefined behavior.

```lua
local ProjectileSystem = require("combat.projectile_system")

ProjectileSystem.spawn({
    preset = "fireball",        -- from data/projectiles.lua
    x = startX,
    y = startY,
    targetX = targetX,
    targetY = targetY,
    owner = playerEntity,
    damage = 50
})
```

*— from combat/projectile_system.lua*

---

## Projectile Preset Structure

\label{recipe:projectile-config}

Define in `assets/scripts/data/projectiles.lua`:

```lua
my_projectile = {
    id = "my_projectile",
    speed = 400,
    damage_type = "fire",
    movement = "straight",      -- straight, homing, arc, orbital
    collision = "explode",      -- destroy, pierce, bounce, explode, pass_through, chain
    explosion_radius = 60,      -- for "explode" collision
    lifetime = 2000,            -- ms before auto-destroy
    tags = { "Fire", "Projectile", "AoE" },
}
```

---

## Movement Types

| Type | Behavior |
|------|----------|
| `"straight"` | Linear path to target |
| `"homing"` | Tracks target entity |
| `"arc"` | Parabolic trajectory |
| `"orbital"` | Circles around owner |

---

## Collision Types

| Type | Behavior |
|------|----------|
| `"destroy"` | Destroy on hit |
| `"pierce"` | Pass through, keep going |
| `"bounce"` | Reflect off surfaces |
| `"explode"` | AoE damage on hit |
| `"pass_through"` | No collision response |
| `"chain"` | Jump to nearby targets |

---

## Standard Tags

**Elements:** `Fire`, `Ice`, `Lightning`, `Poison`, `Arcane`, `Holy`, `Void`

**Mechanics:** `Projectile`, `AoE`, `Hazard`, `Summon`, `Buff`, `Debuff`

**Playstyle:** `Mobility`, `Defense`, `Brute`

---

## Loot System

```lua
local LootSystem = require("combat.loot_system")

-- Drop loot at position
LootSystem.drop({
    x = enemy.x,
    y = enemy.y,
    table = "common_drops",  -- loot table ID
    count = 3
})
```

\newpage
```

**Step 3: Verify and commit**

```bash
cd docs/lua-cookbook && ./build.sh
git add docs/lua-cookbook/cookbook.md
git commit -m "docs: add Chapter 6 - Combat & Projectiles"
```

---

## Task 9: Write Chapter 7 — Wand & Cards

**Files:**
- Modify: `docs/lua-cookbook/cookbook.md` (append)

**Step 1: Extract from codebase**

```bash
cat assets/scripts/data/cards.lua | head -100
cat assets/scripts/data/jokers.lua | head -100
cat assets/scripts/wand/wand_executor.lua | head -100
cat assets/scripts/wand/joker_system.lua | head -100 2>/dev/null || echo "File not found"
```

**Step 2: Write Chapter 7**

Append to `docs/lua-cookbook/cookbook.md`:

```markdown
# Wand & Cards

## Define a Card

\label{recipe:define-card}

Add to `assets/scripts/data/cards.lua`:

```lua
Cards.MY_FIREBALL = {
    id = "MY_FIREBALL",
    type = "action",           -- "action", "modifier", "trigger"
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

*— from data/cards.lua*

---

## Card Types

| Type | Purpose |
|------|---------|
| `"action"` | Spell that does something |
| `"modifier"` | Modifies next card |
| `"trigger"` | Conditional activation |

---

## Define a Joker

\label{recipe:define-joker}

Add to `assets/scripts/data/jokers.lua`:

```lua
my_joker = {
    id = "my_joker",
    name = "My Joker",
    description = "+10 damage to Fire spells",
    rarity = "Common",         -- Common, Uncommon, Rare, Epic, Legendary
    calculate = function(self, context)
        if context.event == "on_spell_cast"
           and context.tags
           and context.tags.Fire then
            return {
                damage_mod = 10,
                message = "My Joker!"
            }
        end
    end
}
```

*— from data/jokers.lua*

---

## Joker Events

Emit events for jokers to react to:

```lua
local JokerSystem = require("wand.joker_system")

local effects = JokerSystem.trigger_event("on_spell_cast", {
    player = playerEntity,
    tags = { Fire = true },
    damage = baseDamage
})

-- Aggregate effects
for _, effect in ipairs(effects) do
    if effect.damage_mod then
        damage = damage + effect.damage_mod
    end
end
```

---

## Tag Synergy Thresholds

Tags grant bonuses at breakpoints (3/5/7/9 cards):

```lua
-- In wand/tag_evaluator.lua
local TAG_BREAKPOINTS = {
    Fire = {
        [3] = { type = "stat", stat = "damage_pct", value = 10 },
        [5] = { type = "proc", proc_id = "burn_on_hit" },
        [7] = { type = "stat", stat = "crit_chance_pct", value = 15 },
        [9] = { type = "proc", proc_id = "meteor_shower" },
    },
}
```

---

## Card Behavior Registry

For complex card logic:

```lua
local BehaviorRegistry = require("wand.card_behavior_registry")

BehaviorRegistry.register("my_behavior", function(ctx)
    -- Custom card execution logic
    -- ctx contains: caster, target, card_data, etc.
end)

-- In card definition:
Cards.SPECIAL_CARD = {
    -- ...
    behavior_id = "my_behavior"
}
```

---

## Wand Executor Flow

1. Player activates wand
2. `wand_executor` processes card queue
3. Each card: modifiers applied → triggers checked → action executed
4. Jokers react to events during execution

\newpage
```

**Step 3: Verify and commit**

```bash
cd docs/lua-cookbook && ./build.sh
git add docs/lua-cookbook/cookbook.md
git commit -m "docs: add Chapter 7 - Wand & Cards"
```

---

## Task 10: Write Chapter 8 — AI System

**Files:**
- Modify: `docs/lua-cookbook/cookbook.md` (append)

**Step 1: Extract from codebase**

```bash
ls assets/scripts/ai/
cat assets/scripts/ai/actions/*.lua | head -100
cat assets/scripts/ai/entity_types/*.lua | head -100
cat assets/scripts/ai/blackboard_init/*.lua | head -50
```

**Step 2: Write Chapter 8**

Append to `docs/lua-cookbook/cookbook.md`:

```markdown
# AI System

## AI Entity Types

\label{recipe:ai-entity}

Define in `assets/scripts/ai/entity_types/`:

```lua
-- ai/entity_types/my_enemy.lua
return {
    id = "my_enemy",
    blackboard_init = "my_enemy_blackboard",
    goal_selector = "aggressive",
    actions = {
        "idle",
        "chase_player",
        "attack_melee"
    }
}
```

---

## Define an Action

\label{recipe:ai-action}

Add to `assets/scripts/ai/actions/`:

```lua
-- ai/actions/chase_player.lua
return {
    id = "chase_player",

    -- Can this action run?
    precondition = function(blackboard)
        return blackboard.target ~= nil
            and blackboard.distance_to_target > 50
    end,

    -- What state does this action achieve?
    effect = function(blackboard)
        blackboard.near_target = true
    end,

    -- Execute the action
    execute = function(entity, blackboard, dt)
        -- Move toward target
        local tx = blackboard.target_x
        local ty = blackboard.target_y
        -- ... movement logic

        return "running"  -- or "success", "failure"
    end
}
```

---

## Blackboard Initialization

Define in `assets/scripts/ai/blackboard_init/`:

```lua
-- ai/blackboard_init/my_enemy_blackboard.lua
return function(entity)
    return {
        target = nil,
        target_x = 0,
        target_y = 0,
        distance_to_target = math.huge,
        health = 100,
        aggro_range = 200,
        attack_range = 50
    }
end
```

---

## Goal Selectors

Define in `assets/scripts/ai/goal_selectors/`:

```lua
-- ai/goal_selectors/aggressive.lua
return function(blackboard)
    if blackboard.health < 20 then
        return "flee"
    elseif blackboard.target then
        return "kill_target"
    else
        return "patrol"
    end
end
```

---

## AI State Machine Flow

1. **Goal Selector** picks current goal based on blackboard
2. **Planner** finds action sequence to achieve goal
3. **Actions** execute in sequence
4. **Blackboard** updated each frame with world state

\newpage
```

**Step 3: Verify and commit**

```bash
cd docs/lua-cookbook && ./build.sh
git add docs/lua-cookbook/cookbook.md
git commit -m "docs: add Chapter 8 - AI System"
```

---

## Task 11: Write Chapter 9 — Data Definitions

**Files:**
- Modify: `docs/lua-cookbook/cookbook.md` (append)

**Step 1: Extract from codebase**

```bash
head -50 assets/scripts/data/cards.lua
head -50 assets/scripts/data/jokers.lua
head -50 assets/scripts/data/projectiles.lua
ls assets/scripts/data/
```

**Step 2: Write Chapter 9**

Append to `docs/lua-cookbook/cookbook.md`:

```markdown
# Data Definitions

## cards.lua Structure

```lua
-- assets/scripts/data/cards.lua
local Cards = {}

Cards.FIREBALL = {
    id = "FIREBALL",
    type = "action",
    mana_cost = 10,
    damage = 20,
    damage_type = "fire",
    projectile_speed = 400,
    lifetime = 2000,
    radius_of_effect = 0,
    tags = { "Fire", "Projectile" },
    test_label = "Fire\nball",
}

-- ... more cards

return Cards
```

---

## jokers.lua Structure

```lua
-- assets/scripts/data/jokers.lua
local Jokers = {}

Jokers.flame_heart = {
    id = "flame_heart",
    name = "Flame Heart",
    description = "+15% Fire damage",
    rarity = "Common",
    calculate = function(self, context)
        if context.tags and context.tags.Fire then
            return { damage_mult = 1.15 }
        end
    end
}

return Jokers
```

---

## projectiles.lua Structure

```lua
-- assets/scripts/data/projectiles.lua
local Projectiles = {}

Projectiles.fireball = {
    id = "fireball",
    speed = 400,
    damage_type = "fire",
    movement = "straight",
    collision = "explode",
    explosion_radius = 60,
    lifetime = 2000,
    sprite = "fireball_anim",
    tags = { "Fire", "Projectile" },
}

return Projectiles
```

---

## avatars.lua Structure

```lua
-- assets/scripts/data/avatars.lua
local Avatars = {}

Avatars.pyromancer = {
    id = "pyromancer",
    name = "Pyromancer",
    description = "Master of fire magic",
    sprite = "avatar_pyromancer",
    unlock_condition = function()
        return stats.fire_kills >= 100
    end,
    starting_cards = { "FIREBALL", "EMBER" },
    passive = { fire_damage_bonus = 0.1 }
}

return Avatars
```

---

## Content Validator

Run to check all definitions:

```lua
-- In-game or standalone
dofile("assets/scripts/tools/content_validator.lua")

-- Checks:
-- - Required fields present
-- - IDs are unique
-- - References exist (sprite IDs, etc.)
-- - Tag consistency
```

\newpage
```

**Step 3: Verify and commit**

```bash
cd docs/lua-cookbook && ./build.sh
git add docs/lua-cookbook/cookbook.md
git commit -m "docs: add Chapter 9 - Data Definitions"
```

---

## Task 12: Write Chapter 10 — Utilities & External

**Files:**
- Modify: `docs/lua-cookbook/cookbook.md` (append)

**Step 1: Extract from codebase**

```bash
cat assets/scripts/external/hump/signal.lua | head -80
ls assets/scripts/external/
ls assets/scripts/util/
```

**Step 2: Write Chapter 10**

Append to `docs/lua-cookbook/cookbook.md`:

```markdown
# Utilities & External Libraries

## hump/signal (Events)

Full API reference:

```lua
local signal = require("external.hump.signal")

-- Register handler
signal.register("event_name", handler_function)

-- Register with priority (lower = called first)
signal.register("event_name", handler, priority)

-- Emit event
signal.emit("event_name", arg1, arg2, ...)

-- Remove specific handler
signal.remove("event_name", handler_function)

-- Remove all handlers for event
signal.clear("event_name")

-- Remove all handlers
signal.clearAll()
```

*— from external/hump/signal.lua*

---

## knife (Utilities)

If available, knife provides:

```lua
local knife = require("external.knife")

-- Table utilities
knife.map(table, fn)
knife.filter(table, predicate)
knife.reduce(table, fn, initial)

-- Function utilities
knife.debounce(fn, delay)
knife.throttle(fn, interval)
knife.memoize(fn)
```

---

## forma (Procedural Generation)

If available:

```lua
local forma = require("external.forma")

-- Dungeon generation, noise, etc.
-- See external/forma/ for specific modules
```

---

## Common Util Functions

From `globals.lua` and `util/`:

```lua
-- Color utilities
util.getColor("blackberry")  -- Get named color
util.hexToColor("#FF5500")   -- Hex to color

-- Math utilities
util.lerp(a, b, t)           -- Linear interpolation
util.clamp(val, min, max)    -- Clamp value
util.distance(x1, y1, x2, y2) -- Distance between points

-- Table utilities
util.deepcopy(table)         -- Deep copy
util.merge(t1, t2)           -- Merge tables

-- String utilities
util.split(str, delimiter)   -- Split string
util.trim(str)               -- Trim whitespace
```

---

## Global Functions

Available everywhere after init:

```lua
-- Logging
log_info("message")
log_warn("message")
log_error("message")

-- Entity helpers
ensure_entity(eid)           -- Validate entity
ensure_scripted_entity(eid)  -- Validate + has script
safe_script_get(eid)         -- Get script or nil
script_field(eid, "field", default)

-- State management
is_state_active(STATE)
activate_state(STATE)
deactivate_state(STATE)
add_state_tag(entity, STATE)
```

\newpage
```

**Step 3: Verify and commit**

```bash
cd docs/lua-cookbook && ./build.sh
git add docs/lua-cookbook/cookbook.md
git commit -m "docs: add Chapter 10 - Utilities & External"
```

---

## Task 13: Write Back Matter (Function Index, Cheat Sheet)

**Files:**
- Modify: `docs/lua-cookbook/cookbook.md` (append)

**Step 1: Compile function index**

Extract all documented functions from previous chapters.

**Step 2: Write back matter**

Append to `docs/lua-cookbook/cookbook.md`:

```markdown
# Appendix A: Function Index

*Alphabetical listing of all documented functions.*

| Function | Module | Page |
|----------|--------|------|
| `activate_state()` | globals | \pageref{recipe:validate-entity} |
| `add_state_tag()` | globals | \pageref{recipe:validate-entity} |
| `component_cache.get()` | core.component_cache | \pageref{recipe:get-component} |
| `dsl.anim()` | ui.ui_syntax_sugar | \pageref{recipe:ui-dsl} |
| `dsl.grid()` | ui.ui_syntax_sugar | \pageref{recipe:ui-grid} |
| `dsl.hbox()` | ui.ui_syntax_sugar | \pageref{recipe:ui-dsl} |
| `dsl.root()` | ui.ui_syntax_sugar | \pageref{recipe:ui-dsl} |
| `dsl.spawn()` | ui.ui_syntax_sugar | \pageref{recipe:ui-dsl} |
| `dsl.text()` | ui.ui_syntax_sugar | \pageref{recipe:ui-dsl} |
| `dsl.vbox()` | ui.ui_syntax_sugar | \pageref{recipe:ui-dsl} |
| `ensure_entity()` | globals | \pageref{recipe:validate-entity} |
| `entity_cache.active()` | core.entity_cache | \pageref{recipe:validate-entity} |
| `entity_cache.valid()` | core.entity_cache | \pageref{recipe:validate-entity} |
| `EntityBuilder.create()` | core.entity_builder | \pageref{recipe:entity-sprite} |
| `EntityBuilder.interactive()` | core.entity_builder | \pageref{recipe:entity-interactive} |
| `EntityBuilder.simple()` | core.entity_builder | \pageref{recipe:entity-simple} |
| `PhysicsBuilder.for_entity()` | core.physics_builder | \pageref{recipe:add-physics} |
| `PhysicsBuilder.quick()` | core.physics_builder | \pageref{recipe:add-physics} |
| `PhysicsManager.get_world()` | core.physics_manager | \pageref{recipe:physics-world} |
| `safe_script_get()` | globals | \pageref{recipe:safe-script} |
| `script_field()` | globals | \pageref{recipe:safe-script} |
| `ShaderBuilder.for_entity()` | core.shader_builder | \pageref{recipe:add-shader} |
| `signal.emit()` | external.hump.signal | \pageref{recipe:signals} |
| `signal.register()` | external.hump.signal | \pageref{recipe:signals} |
| `timer.after()` | core.timer | \pageref{recipe:timer-after} |
| `timer.after_opts()` | core.timer | \pageref{recipe:timer-after} |
| `timer.every()` | core.timer | \pageref{recipe:timer-every} |
| `timer.every_opts()` | core.timer | \pageref{recipe:timer-every} |
| `timer.sequence()` | core.timer | \pageref{recipe:timer-sequence} |

\newpage

# Appendix B: Common Patterns Cheat Sheet

## Entity Lifecycle

```lua
-- Create
local e, s = EntityBuilder.create({ sprite="x", position={0,0} })

-- Add physics
PhysicsBuilder.for_entity(e):circle():tag("t"):apply()

-- Add shader
ShaderBuilder.for_entity(e):add("shader_name"):apply()

-- Destroy
registry:destroy(e)
```

## Defensive Access

```lua
if not ensure_entity(eid) then return end
local script = safe_script_get(eid)
if not script then return end
```

## Timer Patterns

```lua
timer.after(1.0, fn)                    -- delay
timer.every(0.5, fn)                    -- repeat
timer.sequence("tag"):wait(1):do_now(fn):start()
```

## Events

```lua
signal.emit("event", entity, { data = 1 })
signal.register("event", function(e, d) end)
```

## UI Quick

```lua
local ui = dsl.root { children = { dsl.text("Hi") } }
dsl.spawn({ x=100, y=100 }, ui)
```

---

*End of Cookbook*
```

**Step 3: Final build**

```bash
cd docs/lua-cookbook && ./build.sh
open output/lua-cookbook.pdf
```

**Step 4: Commit**

```bash
git add docs/lua-cookbook/cookbook.md
git commit -m "docs: add back matter - function index and cheat sheet"
```

---

## Task 14: Final Review and Polish

**Step 1: Review PDF for issues**

- Check page references resolve
- Verify code highlighting works
- Check TOC is accurate
- Scan for formatting issues

**Step 2: Fix any issues found**

Update cookbook.md as needed.

**Step 3: Final commit**

```bash
git add docs/lua-cookbook/
git commit -m "docs: finalize Lua API Cookbook PDF"
```

---

## Summary

| Task | Description |
|------|-------------|
| 1 | Setup directory + Pandoc config |
| 2 | Front matter (quick start, task index) |
| 3 | Chapter 1: Core Foundations |
| 4 | Chapter 2: Entity Creation |
| 5 | Chapter 3: Physics |
| 6 | Chapter 4: Rendering & Shaders |
| 7 | Chapter 5: UI System |
| 8 | Chapter 6: Combat & Projectiles |
| 9 | Chapter 7: Wand & Cards |
| 10 | Chapter 8: AI System |
| 11 | Chapter 9: Data Definitions |
| 12 | Chapter 10: Utilities & External |
| 13 | Back matter (index, cheat sheet) |
| 14 | Final review and polish |
