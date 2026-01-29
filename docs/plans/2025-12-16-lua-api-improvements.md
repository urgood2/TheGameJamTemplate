# Lua API Improvements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix EntityBuilder bug, add documentation, and add type annotations to core Lua APIs.

**Architecture:** Direct modifications to existing modules. No new modules. Documentation added inline to CLAUDE.md and module headers.

**Tech Stack:** Lua, LuaLS annotations

---

## Task 1: Fix EntityBuilder State Tag Bug

**Files:**
- Modify: `assets/scripts/core/entity_builder.lua:203-206`

**Step 1: Read current code to verify line numbers**

Read `assets/scripts/core/entity_builder.lua` lines 200-210 to confirm exact location.

**Step 2: Apply the fix**

Change lines 203-206 from:
```lua
    -- Add state tag
    if state and add_state_tag then
        add_state_tag(entity, state)
    end
```

To:
```lua
    -- Add state tag (must also remove default per gameplay.lua pattern)
    if state and add_state_tag then
        add_state_tag(entity, state)
        if remove_default_state_tag then
            remove_default_state_tag(entity)
        end
    end
```

**Step 3: Verify syntax**

Run: `luac -p assets/scripts/core/entity_builder.lua`
Expected: No output (no syntax errors)

**Step 4: Commit**

```bash
git add assets/scripts/core/entity_builder.lua
git commit -m "fix(entity_builder): call remove_default_state_tag after adding state

Matches gameplay.lua:1518-1519 pattern where entities are removed
from default state after being assigned a specific state tag."
```

---

## Task 2: Add Timer Options-Table Documentation to CLAUDE.md

**Files:**
- Modify: `CLAUDE.md` (after line 734, end of Timer System section)

**Step 1: Read current Timer System section**

Read `CLAUDE.md` lines 711-740 to find exact insertion point.

**Step 2: Insert new documentation**

After line 734 (the closing ``` of the physics step example), insert:

```markdown

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
```

**Step 3: Verify markdown renders correctly**

Visual inspection - ensure code blocks are properly closed.

**Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add timer options-table API examples to CLAUDE.md

Documents timer.every_opts, timer.after_opts, timer.cooldown_opts
as recommended alternatives to positional parameter versions."
```

---

## Task 3: Add Troubleshooting Section to CLAUDE.md

**Files:**
- Modify: `CLAUDE.md` (before line 1043, the References section)

**Step 1: Read end of CLAUDE.md to find insertion point**

Read `CLAUDE.md` lines 1035-1050 to confirm References section location.

**Step 2: Insert Troubleshooting section**

Before the `## References` line, insert:

```markdown
---

## Troubleshooting

### Entity Issues

**"Entity disappeared" / Entity not rendering**
- Check `entity_cache.valid(entity)` returns true
- Check entity has correct state tag: `add_state_tag(entity, PLANNING_STATE)`
- Check `AnimationQueueComponent.noDraw` is not true
- Verify entity wasn't destroyed by another system

**"Data lost on script table"**
- Data MUST be assigned BEFORE `attach_ecs()`:
```lua
-- WRONG:
script:attach_ecs { existing_entity = e }
script.health = 100  -- Lost!

-- CORRECT:
script.health = 100  -- First
script:attach_ecs { existing_entity = e }  -- Last
```

**"getScriptTableFromEntityID returns nil"**
- Entity must have Node script attached via `attach_ecs()`
- Use the script variable directly after `attach_ecs()`, don't immediately call `getScriptTableFromEntityID`

### Physics Issues

**"Collisions not working"**
- Check `PhysicsManager.get_world("world")` returns non-nil
- Verify collision masks: `physics.update_collision_masks_for(world, tag, {other_tags})`
- Check entity has physics body: `physics.create_physics_for_transform(...)`
- Verify tags match between colliding entities

**"Physics world is nil"**
- Physics initializes after Lua scripts load
- Use `PhysicsManager.get_world("world")` not `globals.physicsWorld`
- Wrap physics code in nil check:
```lua
local world = PhysicsManager.get_world("world")
if not world then return end
```

### Rendering Issues

**"Entity not visible"**
- Check state tag matches active game state
- Check z-order isn't behind other elements
- Verify `AnimationQueueComponent` exists and `noDraw = false`
- Check entity position is within camera view

**"Wrong layer or z-order"**
- Use `layer_order_system.assignZIndexToEntity(entity, z)`
- Check `z_orders` table for correct values
- Cards use `z_orders.card`, UI uses `z_orders.ui_base`, etc.

### Common Lua Errors

**"attempt to index nil value"**
- Usually means `component_cache.get()` returned nil
- Always guard component access:
```lua
local transform = component_cache.get(entity, Transform)
if transform then
    transform.actualX = 100
end
```

**"attempt to call nil value"**
- Function doesn't exist or module not loaded
- Check require path is correct
- Check function name spelling

---

```

**Step 3: Verify markdown structure**

Ensure the `---` separator and `## References` follow correctly.

**Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add Troubleshooting section to CLAUDE.md

Covers common issues:
- Entity disappeared / data lost
- Physics collisions not working
- Rendering visibility issues
- Nil dereference patterns"
```

---

## Task 4: Add Header Documentation to ui/ui_syntax_sugar.lua

**Files:**
- Modify: `assets/scripts/ui/ui_syntax_sugar.lua:1-6`

**Step 1: Read current header**

Read `assets/scripts/ui/ui_syntax_sugar.lua` lines 1-10.

**Step 2: Replace header with comprehensive documentation**

Replace lines 1-6 with:

```lua
--[[
================================================================================
UI DSL (ui_syntax_sugar) - Declarative UI Tree Builder
================================================================================
Build UI hierarchies with readable, declarative syntax.

BASIC USAGE:
    local dsl = require("ui.ui_syntax_sugar")

    local myUI = dsl.root {
        config = { color = "blackberry", padding = 10 },
        children = {
            dsl.vbox {
                config = { spacing = 6 },
                children = {
                    dsl.text("Title", { fontSize = 24, color = "white" }),
                    dsl.hbox {
                        children = {
                            dsl.anim("sprite_id", { w = 40, h = 40 }),
                            dsl.text("Subtitle", { fontSize = 16 })
                        }
                    }
                }
            }
        }
    }

    local boxID = dsl.spawn({ x = 200, y = 200 }, myUI)

CONTAINERS:
    dsl.root { config, children }    -- Root container (required at top)
    dsl.vbox { config, children }    -- Vertical layout
    dsl.hbox { config, children }    -- Horizontal layout

ELEMENTS:
    dsl.text(text, opts)             -- Text element
        opts: { fontSize, color, align, onClick, hover }

    dsl.anim(id, opts)               -- Animated sprite
        opts: { w, h, shadow, isAnimation }

    dsl.dynamicText(fn, fontSize, effect, opts)  -- Auto-updating text
        fn: function returning string

HOVER/TOOLTIP:
    dsl.text("Button", {
        hover = { title = "Button Title", body = "Description" },
        onClick = function() print("clicked") end
    })

SPAWNING:
    dsl.spawn(pos, defNode, layerName?, zIndex?, opts?)
        pos: { x = number, y = number }
        Returns: boxID (entity)

Dependencies: ui.definitions, ui.box, layer_order_system, animation_system
]]
------------------------------------------------------------
```

**Step 3: Verify syntax**

Run: `luac -p assets/scripts/ui/ui_syntax_sugar.lua`
Expected: No output (no syntax errors)

**Step 4: Commit**

```bash
git add assets/scripts/ui/ui_syntax_sugar.lua
git commit -m "docs(ui): add comprehensive header to ui_syntax_sugar.lua

Documents all DSL functions with usage examples:
- Containers (root, vbox, hbox)
- Elements (text, anim, dynamicText)
- Hover/tooltip pattern
- spawn() function"
```

---

## Task 5: Add Header Documentation to combat/wave_helpers.lua

**Files:**
- Modify: `assets/scripts/combat/wave_helpers.lua:1-2`

**Step 1: Read current header**

Read `assets/scripts/combat/wave_helpers.lua` lines 1-10.

**Step 2: Replace header with API documentation**

Replace lines 1-2 with:

```lua
--[[
================================================================================
WAVE HELPERS - Enemy Behavior Helper Functions
================================================================================
Provides movement, combat, spawning, and visual helpers for enemy behaviors.
Used by enemy definitions in data/enemies.lua.

MOVEMENT HELPERS:
    WaveHelpers.move_toward_player(e, speed)     -- Chase player
    WaveHelpers.flee_from_player(e, speed, min_distance)  -- Run away
    WaveHelpers.kite_from_player(e, speed, preferred_distance)  -- Maintain distance
    WaveHelpers.wander(e, speed)                 -- Random movement
    WaveHelpers.dash_toward_player(e, dash_speed, duration)  -- Quick dash

POSITION HELPERS:
    WaveHelpers.get_player_position()            -- Returns {x, y}
    WaveHelpers.get_entity_position(e)           -- Returns {x, y} or nil
    WaveHelpers.get_spawn_positions(config, count)  -- Generate spawn points

COMBAT HELPERS:
    WaveHelpers.deal_damage_to_player(damage)    -- Emit damage event
    WaveHelpers.heal_enemy(e, amount)            -- Restore HP
    WaveHelpers.kill_enemy(e)                    -- Instant kill
    WaveHelpers.get_hp_percent(e)                -- Returns 0.0-1.0
    WaveHelpers.set_invulnerable(e, bool)        -- Toggle invulnerability

SPAWNING HELPERS:
    WaveHelpers.drop_trap(e, damage, lifetime)   -- Spawn trap at position
    WaveHelpers.summon_enemies(e, enemy_type, count)  -- Spawn minions
    WaveHelpers.explode(e, radius, damage)       -- AOE damage

VISUAL HELPERS:
    WaveHelpers.spawn_particles(effect_name, e_or_position)
    WaveHelpers.screen_shake(duration, intensity)
    WaveHelpers.set_shader(e, shader_name)
    WaveHelpers.clear_shader(e)
    WaveHelpers.spawn_telegraph(position, enemy_type, duration)

CONTEXT STORAGE:
    WaveHelpers.set_enemy_ctx(e, ctx)            -- Store enemy context
    WaveHelpers.get_enemy_ctx(e)                 -- Retrieve enemy context

USAGE IN data/enemies.lua:
    enemies.goblin = {
        sprite = "goblin.png",
        hp = 30,
        speed = 60,
        on_spawn = function(e, ctx, helpers)
            timer.every(0.5, function()
                if not entity_cache.valid(e) then return false end
                helpers.move_toward_player(e, ctx.speed)
            end, "enemy_" .. e)
        end
    }
]]
```

**Step 3: Verify syntax**

Run: `luac -p assets/scripts/combat/wave_helpers.lua`
Expected: No output (no syntax errors)

**Step 4: Commit**

```bash
git add assets/scripts/combat/wave_helpers.lua
git commit -m "docs(combat): add API documentation header to wave_helpers.lua

Documents all helper functions:
- Movement (move_toward, flee, kite, wander, dash)
- Combat (damage, heal, kill, hp_percent)
- Spawning (trap, summon, explode)
- Visual (particles, shake, shader)"
```

---

## Task 6: Add Header Documentation to combat/enemy_factory.lua

**Files:**
- Modify: `assets/scripts/combat/enemy_factory.lua:1-3`

**Step 1: Read current header**

Read `assets/scripts/combat/enemy_factory.lua` lines 1-10.

**Step 2: Replace header with API documentation**

Replace lines 1-3 with:

```lua
--[[
================================================================================
ENEMY FACTORY - Enemy Creation with Combat System Integration
================================================================================
Creates enemy entities from definitions in data/enemies.lua and integrates
them with the combat system (stats, weapons, health UI).

PUBLIC API:
    EnemyFactory.spawn(enemy_type, position, modifiers)
        enemy_type: string  -- Key from data/enemies.lua (e.g., "goblin")
        position: {x, y}    -- Spawn coordinates
        modifiers: string[] -- Optional elite modifiers from data/elite_modifiers.lua
        Returns: entity, ctx

    EnemyFactory.kill(e, ctx)
        e: entity           -- Enemy entity to kill
        ctx: table          -- Context returned from spawn()
        Triggers on_death callback and cleanup

USAGE:
    local EnemyFactory = require("combat.enemy_factory")

    -- Spawn basic enemy
    local enemy, ctx = EnemyFactory.spawn("goblin", { x = 100, y = 200 })

    -- Spawn elite enemy with modifiers
    local elite, ctx = EnemyFactory.spawn("goblin", { x = 100, y = 200 }, { "armored", "fast" })

    -- Kill enemy (triggers on_death, cleanup, signals)
    EnemyFactory.kill(enemy, ctx)

INTEGRATION:
    - Adds entity to ACTION_STATE
    - Creates combat actor with stats
    - Registers in enemyHealthUiState for HP bars
    - Sets up physics body with "enemy" tag
    - Registers steering for movement
    - Calls on_spawn from enemy definition

Dependencies: data/enemies.lua, data/elite_modifiers.lua, combat/wave_helpers.lua
]]
```

**Step 3: Verify syntax**

Run: `luac -p assets/scripts/combat/enemy_factory.lua`
Expected: No output (no syntax errors)

**Step 4: Commit**

```bash
git add assets/scripts/combat/enemy_factory.lua
git commit -m "docs(combat): add API documentation header to enemy_factory.lua

Documents spawn() and kill() functions with usage examples
and integration details."
```

---

## Task 7: Add Type Annotations to EntityBuilder

**Files:**
- Modify: `assets/scripts/core/entity_builder.lua:43-75` (before DEFAULTS section)

**Step 1: Read current file structure**

Read `assets/scripts/core/entity_builder.lua` lines 40-80 to find insertion point.

**Step 2: Insert type definitions after line 57 (after Node require)**

After line 57 (`local Node = require("monobehavior.behavior_script_v2")`), insert:

```lua

--------------------------------------------------------------------------------
-- TYPE DEFINITIONS (LuaLS)
--------------------------------------------------------------------------------

---@class EntityBuilderOpts
---@field sprite string? Animation/sprite ID
---@field fromSprite boolean? True=animation, false=sprite identifier (default: true)
---@field x number? X position (alternative to position)
---@field y number? Y position (alternative to position)
---@field position {x: number, y: number}|{[1]: number, [2]: number}? Position table
---@field size {[1]: number, [2]: number}|{w: number, h: number}? Size (default: 32x32)
---@field shadow boolean? Enable shadow (default: false)
---@field data table? Script table data (assigned before attach_ecs)
---@field interactive EntityBuilderInteractive? Interaction configuration
---@field state string? State tag to add (e.g., PLANNING_STATE)
---@field shaders (string|{[1]: string, [2]: table})[]? Shader names or {name, uniforms} pairs

---@class EntityBuilderInteractive
---@field hover {title: string, body: string, id: string?}? Tooltip configuration
---@field click fun(registry: any, entity: number)? Click callback
---@field drag boolean|fun()? Enable drag (true) or custom drag handler
---@field stopDrag fun()? Stop drag callback
---@field collision boolean? Enable collision detection
```

**Step 3: Update function annotations**

The existing function at line 137 already has `---@param opts table`. Update it to:

Find and replace lines 133-136:
```lua
--- Create an entity with all common setup in one call.
--- @param opts table Configuration options
--- @return number entity The created entity ID
--- @return table script The script table (if data provided)
```

With:
```lua
--- Create an entity with all common setup in one call.
---@param opts EntityBuilderOpts Configuration options
---@return number entity The created entity ID
---@return table? script The script table (nil if no data provided)
```

**Step 4: Verify syntax**

Run: `luac -p assets/scripts/core/entity_builder.lua`
Expected: No output (no syntax errors)

**Step 5: Commit**

```bash
git add assets/scripts/core/entity_builder.lua
git commit -m "feat(entity_builder): add LuaLS type annotations

Adds @class definitions for EntityBuilderOpts and EntityBuilderInteractive
for IDE autocomplete support."
```

---

## Task 8: Add Type Annotations to PhysicsBuilder

**Files:**
- Modify: `assets/scripts/core/physics_builder.lua:48-52` (after entity_cache require)

**Step 1: Read current file structure**

Read `assets/scripts/core/physics_builder.lua` lines 44-56.

**Step 2: Insert type definitions after line 48**

After line 48 (`local entity_cache = require("core.entity_cache")`), insert:

```lua

--------------------------------------------------------------------------------
-- TYPE DEFINITIONS (LuaLS)
--------------------------------------------------------------------------------

---@class PhysicsBuilderOpts
---@field shape "circle"|"rectangle"? Shape type (default: "circle")
---@field tag string? Collision tag (default: "default")
---@field sensor boolean? Is sensor/trigger (default: false)
---@field density number? Body density (default: 1.0)
---@field friction number? Surface friction (default: 0.3)
---@field restitution number? Bounciness (default: 0.0)
---@field bullet boolean? Enable CCD for fast objects (default: false)
---@field fixedRotation boolean? Lock rotation (default: false)
---@field syncMode "physics"|"transform"? Sync mode (default: "physics")
---@field collideWith string[]? Tags to collide with
```

**Step 3: Update quick() function annotation**

Find lines 299-302 and update:
```lua
--- Quick physics setup with common options
--- @param entity number Entity ID
--- @param opts table Options { shape, tag, bullet, collideWith, ... }
--- @return boolean success
```

To:
```lua
--- Quick physics setup with common options
---@param entity number Entity ID
---@param opts PhysicsBuilderOpts Options for physics setup
---@return boolean success
```

**Step 4: Verify syntax**

Run: `luac -p assets/scripts/core/physics_builder.lua`
Expected: No output (no syntax errors)

**Step 5: Commit**

```bash
git add assets/scripts/core/physics_builder.lua
git commit -m "feat(physics_builder): add LuaLS type annotations

Adds @class PhysicsBuilderOpts for IDE autocomplete support."
```

---

## Task 9: Add Type Annotations to Timer

**Files:**
- Modify: `assets/scripts/core/timer.lua:133-135` (before Options-Table API section)

**Step 1: Read current file structure**

Read `assets/scripts/core/timer.lua` lines 130-145.

**Step 2: Insert type definitions before line 133**

Before the `-- Options-Table API` comment, insert:

```lua
--------------------------------------------------------------------------------
-- TYPE DEFINITIONS (LuaLS)
--------------------------------------------------------------------------------

---@class TimerAfterOpts
---@field delay number|{[1]: number, [2]: number} Delay in seconds (or {min, max} for random)
---@field action fun() Callback function
---@field tag string? Timer tag for cancellation
---@field group string? Timer group

---@class TimerEveryOpts
---@field delay number|{[1]: number, [2]: number} Interval in seconds
---@field action fun():boolean? Callback (return false to stop)
---@field times number? Number of times to run (0 = infinite, default: 0)
---@field immediate boolean? Run once immediately (default: false)
---@field after fun()? Callback after all iterations complete
---@field tag string? Timer tag for cancellation
---@field group string? Timer group

---@class TimerCooldownOpts
---@field delay number|{[1]: number, [2]: number} Cooldown duration
---@field condition fun():boolean Condition to check
---@field action fun() Action when condition met after cooldown
---@field times number? Number of times (0 = infinite, default: 0)
---@field after fun()? Callback after all iterations
---@field tag string? Timer tag for cancellation
---@field group string? Timer group

```

**Step 3: Update function annotations**

Update line 140 (`function timer.after_opts(opts)`):
```lua
---@param opts TimerAfterOpts
---@return string tag The timer tag
function timer.after_opts(opts)
```

Update line 149 (`function timer.every_opts(opts)`):
```lua
---@param opts TimerEveryOpts
---@return string tag The timer tag
function timer.every_opts(opts)
```

Update line 166 (`function timer.cooldown_opts(opts)`):
```lua
---@param opts TimerCooldownOpts
---@return string tag The timer tag
function timer.cooldown_opts(opts)
```

**Step 4: Verify syntax**

Run: `luac -p assets/scripts/core/timer.lua`
Expected: No output (no syntax errors)

**Step 5: Commit**

```bash
git add assets/scripts/core/timer.lua
git commit -m "feat(timer): add LuaLS type annotations for opts functions

Adds @class definitions for TimerAfterOpts, TimerEveryOpts,
TimerCooldownOpts for IDE autocomplete support."
```

---

## Task 10: Add Type Annotations to EnemyFactory

**Files:**
- Modify: `assets/scripts/combat/enemy_factory.lua` (after requires, before basic_monster_weapon)

**Step 1: Read current file structure**

Read `assets/scripts/combat/enemy_factory.lua` lines 1-20.

**Step 2: Insert type definitions after line 13 (after requires)**

After the requires block (after `local elite_modifiers = require(...)`), insert:

```lua

--------------------------------------------------------------------------------
-- TYPE DEFINITIONS (LuaLS)
--------------------------------------------------------------------------------

---@class EnemyContext
---@field type string Enemy type from data/enemies.lua
---@field hp number Current health
---@field max_hp number Maximum health
---@field speed number Movement speed
---@field damage number Contact damage
---@field size {[1]: number, [2]: number} Width, height
---@field entity number Entity ID
---@field is_elite boolean Has elite modifiers
---@field modifiers string[] Applied modifier names
---@field invulnerable boolean Damage immunity flag
---@field on_death fun(e: number, ctx: EnemyContext, helpers: table)? Death callback
---@field on_hit fun(e: number, ctx: EnemyContext, damage: number, helpers: table)? Hit callback
---@field on_contact_player fun(e: number, ctx: EnemyContext, helpers: table)? Player contact callback
```

**Step 3: Update spawn function annotation**

Find the spawn function and update its annotation:
```lua
---@param enemy_type string Key from data/enemies.lua
---@param position {x: number, y: number} Spawn position
---@param modifiers string[]? Elite modifier names from data/elite_modifiers.lua
---@return number? entity Entity ID (nil on failure)
---@return EnemyContext? ctx Enemy context (nil on failure)
function EnemyFactory.spawn(enemy_type, position, modifiers)
```

**Step 4: Update kill function annotation**

Find the kill function and update:
```lua
---@param e number Enemy entity ID
---@param ctx EnemyContext? Enemy context from spawn()
function EnemyFactory.kill(e, ctx)
```

**Step 5: Verify syntax**

Run: `luac -p assets/scripts/combat/enemy_factory.lua`
Expected: No output (no syntax errors)

**Step 6: Commit**

```bash
git add assets/scripts/combat/enemy_factory.lua
git commit -m "feat(enemy_factory): add LuaLS type annotations

Adds @class EnemyContext and parameter annotations for
spawn() and kill() functions."
```

---

## Task 11: Final Verification

**Step 1: Run syntax check on all modified files**

```bash
luac -p assets/scripts/core/entity_builder.lua && \
luac -p assets/scripts/core/physics_builder.lua && \
luac -p assets/scripts/core/timer.lua && \
luac -p assets/scripts/ui/ui_syntax_sugar.lua && \
luac -p assets/scripts/combat/wave_helpers.lua && \
luac -p assets/scripts/combat/enemy_factory.lua && \
echo "All files pass syntax check"
```

Expected: "All files pass syntax check"

**Step 2: Build and run tests**

```bash
just build-debug && just test
```

Expected: Build succeeds, tests pass

**Step 3: Final commit with all changes**

If any files weren't committed individually:
```bash
git status
git add -A
git commit -m "chore: complete lua api improvements"
```

**Step 4: Push changes**

```bash
git push
```

---

## Summary

| Task | File | Change |
|------|------|--------|
| 1 | entity_builder.lua | Fix remove_default_state_tag bug |
| 2 | CLAUDE.md | Add timer opts documentation |
| 3 | CLAUDE.md | Add troubleshooting section |
| 4 | ui_syntax_sugar.lua | Add header documentation |
| 5 | wave_helpers.lua | Add header documentation |
| 6 | enemy_factory.lua | Add header documentation |
| 7 | entity_builder.lua | Add type annotations |
| 8 | physics_builder.lua | Add type annotations |
| 9 | timer.lua | Add type annotations |
| 10 | enemy_factory.lua | Add type annotations |
| 11 | All | Final verification |

**Total Tasks:** 11
**Estimated Time:** 4-5 hours

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
