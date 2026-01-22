# Lua API Migration Guide

This guide helps you migrate legacy code to the improved Lua APIs introduced in the API Usability Improvements update.

## Table of Contents

1. [Timer APIs - Dual Signature](#timer-apis---dual-signature)
2. [Constants Module](#constants-module)
3. [Component Cache - Debug Mode](#component-cache---debug-mode)
4. [Procedural Generation DSL](#procedural-generation-dsl)
5. [GOAP Debug Overlay](#goap-debug-overlay)
6. [Steering Debug Visualization](#steering-debug-visualization)

---

## Timer APIs - Dual Signature

Timer functions now accept **either** positional arguments (for backwards compatibility) **or** an options table (for readability).

### Before (still works)

```lua
-- Positional arguments
timer.after(0.5, callback, "my_tag")
timer.every(1.0, update_fn, "heartbeat", nil, true)
timer.cooldown(0.3, can_attack, do_attack, 5, nil, "attack_cd")
```

### After (preferred for clarity)

```lua
-- Options table
timer.after {
    delay = 0.5,
    action = callback,
    tag = "my_tag"
}

timer.every {
    delay = 1.0,
    action = update_fn,
    tag = "heartbeat",
    immediate = true
}

timer.cooldown {
    delay = 0.3,
    condition = can_attack,
    action = do_attack,
    times = 5,
    tag = "attack_cd"
}
```

### Migration Steps

1. **No action required** - Existing code continues to work
2. **Optional**: For complex calls with many parameters, convert to options table
3. **Benefit**: Self-documenting code, no more counting parameter positions

---

## Constants Module

New constant categories replace magic numbers throughout your code.

### Before

```lua
timer.after(0.5, ...)
entity.health = 100
local z = 200

if damage_type == "fire" then ...
```

### After

```lua
local C = require("core.constants")

timer.after(C.Timing.MEDIUM, ...)
entity.health = C.Stats.BASE_HEALTH
local z = C.UI.Z_OVERLAY

if damage_type == C.DamageTypes.FIRE then ...
```

### Available Categories

| Category | Examples |
|----------|----------|
| `C.Timing` | `FRAME`, `SHORT`, `MEDIUM`, `LONG`, `ATTACK_COOLDOWN`, `FADE_DURATION` |
| `C.Stats` | `BASE_HEALTH`, `BASE_DAMAGE`, `BASE_SPEED`, `CRIT_MULTIPLIER` |
| `C.UI` | `PADDING_SMALL`, `Z_BACKGROUND`, `Z_UI`, `Z_OVERLAY`, `FONT_SMALL` |
| `C.Colors` | `WHITE`, `BLACK`, `DAMAGE`, `HEAL`, `BUFF`, `UI_PRIMARY` |
| `C.CollisionTags` | `PLAYER`, `ENEMY`, `PROJECTILE`, `WORLD` |
| `C.DamageTypes` | `PHYSICAL`, `FIRE`, `ICE`, `LIGHTNING`, `POISON` |

### Migration Steps

1. Add `local C = require("core.constants")` to files with magic numbers
2. Replace magic numbers with appropriate constants
3. Use `C.is_valid(category, value)` to validate user input

---

## Component Cache - Debug Mode

The `component_cache.safe_get` function now supports debug mode for better error messages.

### Before

```lua
local transform = component_cache.safe_get(entity, Transform)
-- If nil, no information about why
```

### After

```lua
-- Enable debug mode (usually at startup)
component_cache.set_debug_mode(true)

-- When entity is invalid or missing component, logs:
-- "[component_cache] Entity 42 invalid when accessing Transform (from scripts/player.lua:123)"
local transform, valid = component_cache.safe_get(entity, Transform)

-- Or with explicit context:
local transform, valid = component_cache.safe_get_with_context(
    entity, Transform, "Player spawn handler"
)
-- Logs: "[component_cache] Entity 42 invalid when accessing Transform (Player spawn handler)"
```

### Migration Steps

1. Add `component_cache.set_debug_mode(true)` to your initialization code (debug builds only)
2. For hard-to-debug access patterns, use `safe_get_with_context`
3. No changes needed for existing `safe_get` calls

---

## Procedural Generation DSL

New declarative APIs replace imperative generation code.

### Loot Tables

#### Before

```lua
function roll_chest_loot(player)
    local items = {}
    local roll = math.random(100)
    if roll < 50 then
        table.insert(items, { item = "gold", amount = math.random(10, 50) })
    elseif roll < 80 then
        table.insert(items, { item = "health_potion", amount = 1 })
    else
        if player.level >= 5 then
            table.insert(items, { item = "rare_sword", amount = 1 })
        end
    end
    return items
end
```

#### After

```lua
local procgen = require("core.procgen")

local chest_loot = procgen.loot {
    { item = "gold", weight = 50, amount = procgen.range(10, 50) },
    { item = "health_potion", weight = 30 },
    { item = "rare_sword", weight = 5, condition = function(ctx)
        return ctx.player.level >= 5
    end },
    picks = 1
}

-- Usage
local rng = procgen.create_rng(seed)
local items = chest_loot:roll({ player = player, rng = rng })
```

### Enemy Waves

#### Before

```lua
function get_wave_enemies(wave_num, difficulty)
    local enemies = { "slime" }
    if wave_num >= 2 then
        table.insert(enemies, "archer")
    end
    for i = 1, difficulty do
        table.insert(enemies, "knight")
    end
    return enemies
end
```

#### After

```lua
local procgen = require("core.procgen")

local waves = procgen.waves {
    { enemies = { "slime" }, spawn_delay = 1.0 },
    { enemies = { "slime", "archer" }, spawn_delay = 0.8 },
    {
        enemies = procgen.scaled {
            base = { "slime", "archer" },
            per_difficulty = { "knight" },
            max_enemies = 8
        },
        spawn_delay = procgen.curve("difficulty", 1.0, 0.3)
    }
}

-- Usage
local rng = procgen.create_rng(seed)
local wave = waves:get_wave(wave_num, { difficulty = difficulty, rng = rng })
```

### Stat Scaling

#### Before

```lua
function calculate_enemy_stats(base_health, base_damage, difficulty, is_elite)
    local health = base_health * (1 + difficulty * 0.2)
    local damage = base_damage * (1 + difficulty * 0.1)
    if is_elite then
        health = health * 2
        damage = damage * 1.5
    end
    return { health = health, damage = damage }
end
```

#### After

```lua
local procgen = require("core.procgen")

local enemy_stats = procgen.stats {
    base = { health = 100, damage = 10, speed = 50 },
    scaling = {
        health = function(ctx) return ctx.base * (1 + ctx.difficulty * 0.2) end,
        damage = function(ctx) return ctx.base * (1 + ctx.difficulty * 0.1) end,
        speed = procgen.constant()  -- Doesn't scale
    },
    variants = {
        elite = { health = 2.0, damage = 1.5 },
        boss = { health = 5.0, damage = 2.0 }
    }
}

-- Usage
local rng = procgen.create_rng(seed)
local stats = enemy_stats:generate({
    difficulty = difficulty,
    variant = "elite",
    rng = rng
})
```

### Migration Steps

1. Identify procedural generation code (loot tables, wave definitions, stat calculations)
2. Convert to declarative procgen DSL
3. Use `procgen.create_rng(seed)` for deterministic results
4. **Benefit**: Easier to tune, debug, and understand

---

## GOAP Debug Overlay

New debug module for visualizing AI decision-making.

### Integration

```lua
local goap_debug = require("core.goap_debug")

-- Enable in debug builds
if DEBUG_MODE then
    goap_debug.enable()
end

-- In your GOAP planner, emit debug info:
function update_ai(entity)
    goap_debug.set_current_goal(entity, goal.name, goal.priority)
    goap_debug.set_plan(entity, plan_actions)
    goap_debug.set_plan_index(entity, current_step)
    goap_debug.set_world_state(entity, world_state)

    for _, rejected in ipairs(rejected_actions) do
        goap_debug.add_rejected_action(entity, rejected.action, rejected.reason)
    end

    -- Action selection breakdown
    goap_debug.set_current_action(entity, chosen_action)
    goap_debug.set_action_preconditions(entity, chosen_action, preconditions)
    goap_debug.set_action_cost(entity, chosen_action, total_cost, cost_breakdown)

    for _, competing in ipairs(other_actions) do
        goap_debug.add_competing_action(entity, competing.action, competing.cost, competing.reason)
    end
end

-- In your renderer:
function render_debug_overlay(entity)
    local info = goap_debug.get_entity_debug_info(entity)
    if info then
        -- Render goal, plan, world state, etc.
    end
end
```

### API Summary

| Function | Purpose |
|----------|---------|
| `enable()` / `disable()` | Toggle debug mode |
| `set_current_goal(entity, name, priority)` | Set current goal |
| `set_plan(entity, actions)` | Set current plan |
| `set_plan_index(entity, index)` | Set current step |
| `set_world_state(entity, state)` | Set world state |
| `add_rejected_action(entity, action, reason)` | Add rejected action (bounded) |
| `set_current_action(entity, action)` | Set executing action |
| `set_action_preconditions(entity, action, conditions)` | Set precondition status |
| `set_action_cost(entity, action, total, breakdown)` | Set cost breakdown |
| `add_competing_action(entity, action, cost, reason)` | Add competing action |
| `get_entity_debug_info(entity)` | Get all debug info |
| `select_entity(entity)` / `get_selected_entity()` | Selection for detailed view |

---

## Steering Debug Visualization

New debug module for visualizing steering behavior forces.

### Integration

```lua
local steering_debug = require("core.steering_debug")

-- Enable in debug builds
if DEBUG_MODE then
    steering_debug.enable()
end

-- Call at frame start
steering_debug.begin_frame()

-- In your steering system:
function update_steering(entity, position)
    steering_debug.set_entity_position(entity, position.x, position.y)

    -- Add each behavior's contribution
    local flee_force = calculate_flee(entity)
    steering_debug.add_behavior_vector(entity, "flee", flee_force.x, flee_force.y, 0.8,
        { r = 255, g = 0, b = 0 })  -- Red for flee

    local seek_force = calculate_seek(entity)
    steering_debug.add_behavior_vector(entity, "seek", seek_force.x, seek_force.y, 0.5,
        { r = 0, g = 255, b = 0 })  -- Green for seek

    -- Set final blended result
    local final = blend_forces(flee_force, seek_force)
    steering_debug.set_final_vector(entity, final.x, final.y)
end

-- In your renderer:
function render_steering_debug()
    for _, entity in ipairs(steering_debug.get_tracked_entities()) do
        local vectors = steering_debug.get_entity_vectors(entity)
        if vectors and vectors.position then
            -- Draw arrows from position for each behavior
            for _, behavior in ipairs(vectors.behaviors) do
                draw_arrow(vectors.position, behavior, behavior.color)
            end
            -- Draw final vector
            if vectors.final then
                draw_arrow(vectors.position, vectors.final, { r = 255, g = 255, b = 255 })
            end
        end
    end
end
```

### API Summary

| Function | Purpose |
|----------|---------|
| `enable()` / `disable()` | Toggle debug mode |
| `begin_frame()` | Clear data for new frame |
| `set_entity_position(entity, x, y)` | Set visualization origin |
| `add_behavior_vector(entity, name, x, y, weight, color?)` | Add behavior force |
| `set_final_vector(entity, x, y)` | Set blended result |
| `get_entity_vectors(entity)` | Get all vectors |
| `get_tracked_entities()` | Get entities with data |

---

## Type Annotations and LSP

The new type system provides better autocomplete and error detection.

### Enabling LSP Support

1. Ensure `.luarc.json` is configured (done automatically):
   ```json
   {
     "workspace.library": ["assets/scripts/types", "assets/scripts"],
     "diagnostics.globals": ["registry", "command_buffer", "layers", ...]
   }
   ```

2. Restart your editor's Lua language server

### Type Stubs Structure

```
assets/scripts/types/
├── init.lua              # Entrypoint
├── globals.lua           # C++ Sol2 bindings
├── modules.lua           # Lua module return types
├── builders.lua          # Builder APIs
└── components.generated.lua  # Generated component types
```

### Regenerating Component Types

```bash
python tools/lua-types/generate_component_types.py
```

This reads `chugget_code_definitions.lua` and generates type stubs for components.

---

## Summary

| Old Pattern | New Pattern | Benefit |
|-------------|-------------|---------|
| Positional timer args | Options table | Self-documenting |
| Magic numbers | `C.Timing.*`, `C.Stats.*` | No typos, autocomplete |
| Silent `safe_get` failures | Debug mode logging | Easier debugging |
| Imperative loot/waves | Declarative procgen DSL | Easier to tune |
| No AI debugging | `goap_debug` module | See decisions in real-time |
| No steering visualization | `steering_debug` module | See force vectors |

**All changes are backwards compatible.** Existing code continues to work unchanged.
