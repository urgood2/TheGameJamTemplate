# Wave System Design

**Date:** 2025-12-15
**Status:** Approved
**Branch:** `feature/enemy-spawn-waves-hook`

## Overview

A generic wave system for SNKRX-style gameplay: short wave sequences in an arena, optional elite at the end, then shop (with occasional rewards). Supports both hand-crafted stages and procedural endless mode.

## Goals

- Implement a fun gameplay loop quickly
- Configurable stages with sensible defaults
- Enemy variety through timer-based behaviors (not complex GOAP)
- Hooks for transitions between stages, rewards, and shop
- Procedural scaling for endless mode with hand-crafted overrides

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    StageProvider                        │
│  (sequence or endless - produces stage configs)         │
└─────────────────────┬───────────────────────────────────┘
                      │ stage config
                      ▼
┌─────────────────────────────────────────────────────────┐
│                    WaveDirector                         │
│  (orchestrates waves within a stage, handles elite,     │
│   spawn telegraphing, completion callbacks)             │
└─────────────────────┬───────────────────────────────────┘
                      │ spawn requests
                      ▼
┌─────────────────────────────────────────────────────────┐
│                    EnemyFactory                         │
│  (creates enemies from definitions, attaches            │
│   inline behaviors via timers)                          │
└─────────────────────────────────────────────────────────┘
```

**Data flow:**
1. `StageProvider.next()` returns a stage config
2. `WaveDirector` runs each wave in sequence, spawning enemies with 1s telegraph
3. When all waves + elite done, `WaveDirector` calls stage's `on_complete` callback
4. Game code decides: show rewards, go to shop, or next stage

---

## Stage Configuration

### Minimal Config (defaults handle the rest)

```lua
stage_config = {
    waves = {
        { "goblin", "goblin", "goblin" },
        { "goblin", "archer", "archer" },
        { "dasher", "trapper" },
    },
}
```

### Full Config (explicit overrides)

```lua
stage_config = {
    id = "stage_1",

    waves = {
        { "goblin", "goblin", "goblin" },
        { "goblin", "archer", "archer", delay_between = 0.2 },
        { "dasher", "trapper" },
    },

    -- Wave progression
    wave_advance = "on_clear",   -- "on_clear", "on_spawn_complete", "timed", or number (delay)

    -- Elite (optional)
    elite = "goblin_chief",      -- unique type
    -- OR: elite = { base = "goblin", modifiers = { "tanky" } }
    -- OR: elite = { base = "goblin", modifier_count = 2 }  -- random roll

    -- Spawn configuration
    spawn = "around_player",     -- shorthand
    -- OR: spawn = { type = "around_player", min_radius = 150, max_radius = 250 }

    -- Transition
    next = "shop",               -- shorthand
    -- OR: on_complete = function(results) ... end

    difficulty_scale = 1.2,      -- optional multiplier
}
```

### Defaults

| Field | Default |
|-------|---------|
| `wave_advance` | `"on_clear"` |
| `delay_between` | `0.5` seconds |
| `spawn` | `"around_player"` with 150-250 radius |
| `elite` | `nil` (no elite) |
| `next` | next stage in sequence |
| `difficulty_scale` | `1.0` |

### Announcements (automatic)

- Wave start: floating text "Wave N"
- Stage clear: floating text "Stage Complete!" + brief pause

---

## Wave Generation

Instead of explicit wave lists, use a generator for procedural stages:

```lua
wave_generator = {
    count = 4,                          -- number of waves

    enemy_pool = {
        { type = "goblin", weight = 3, cost = 1 },
        { type = "archer", weight = 2, cost = 2 },
        { type = "dasher", weight = 1, cost = 3 },
    },

    budget = {
        base = 5,                       -- starting budget
        per_wave = 2,                   -- +2 each wave
    },

    min_enemies = 2,
    max_enemies = 8,
    guaranteed = { [1] = { "goblin" } }, -- wave 1 always has a goblin
}
```

### Shorthand Generators

```lua
-- Quick escalating waves
wave_generator = generators.escalating({
    enemies = { "goblin", "archer", "dasher" },
    start = 3,
    add = 1,
    count = 4,
})

-- Budget-based with weights
wave_generator = generators.budget({
    pool = { goblin = 3, archer = 2, dasher = 1 },
    budget = "5+2n",
})
```

---

## Enemy Definitions

Enemies defined with inline timer-based behaviors:

```lua
-- assets/scripts/data/enemies.lua

enemies.goblin = {
    sprite = "goblin_idle",
    hp = 30,
    speed = 60,
    damage = 5,
    size = { 32, 32 },

    on_spawn = function(e, ctx)
        timer.every(0.5, function()
            if not entity_cache.valid(e) then return false end
            move_toward_player(e, ctx.speed)
        end, "enemy_" .. e)
    end,

    on_death = function(e, ctx)
        spawn_particles("goblin_death", e)
    end,
}

enemies.dasher = {
    sprite = "dasher_idle",
    hp = 25,
    speed = 50,
    dash_speed = 300,
    dash_cooldown = 3.0,
    damage = 12,
    size = { 32, 32 },

    on_spawn = function(e, ctx)
        timer.every(0.5, function()
            if not entity_cache.valid(e) then return false end
            wander(e, ctx.speed)
        end, "enemy_" .. e)

        timer.every(ctx.dash_cooldown, function()
            if not entity_cache.valid(e) then return false end
            dash_toward_player(e, ctx.dash_speed, 0.3)
        end, "enemy_" .. e .. "_dash")
    end,
}

enemies.trapper = {
    sprite = "trapper_idle",
    hp = 35,
    speed = 30,
    trap_cooldown = 4.0,
    trap_damage = 15,
    trap_lifetime = 10.0,
    size = { 32, 32 },

    on_spawn = function(e, ctx)
        timer.every(0.5, function()
            if not entity_cache.valid(e) then return false end
            wander(e, ctx.speed)
        end, "enemy_" .. e)

        timer.every(ctx.trap_cooldown, function()
            if not entity_cache.valid(e) then return false end
            drop_trap(e, ctx.trap_damage, ctx.trap_lifetime)
        end, "enemy_" .. e .. "_trap")
    end,
}

enemies.summoner = {
    sprite = "summoner_idle",
    hp = 50,
    speed = 25,
    summon_cooldown = 5.0,
    summon_type = "goblin",
    summon_count = 2,
    size = { 40, 40 },

    on_spawn = function(e, ctx)
        timer.every(0.5, function()
            if not entity_cache.valid(e) then return false end
            flee_from_player(e, ctx.speed, 150)
        end, "enemy_" .. e)

        timer.every(ctx.summon_cooldown, function()
            if not entity_cache.valid(e) then return false end
            summon_enemies(e, ctx.summon_type, ctx.summon_count)
        end, "enemy_" .. e .. "_summon")
    end,
}

enemies.exploder = {
    sprite = "exploder_idle",
    hp = 15,
    speed = 80,
    explosion_radius = 60,
    explosion_damage = 25,
    size = { 28, 28 },

    on_spawn = function(e, ctx)
        timer.every(0.3, function()
            if not entity_cache.valid(e) then return false end
            move_toward_player(e, ctx.speed)
        end, "enemy_" .. e)
    end,

    on_death = function(e, ctx)
        explode(e, ctx.explosion_radius, ctx.explosion_damage)
    end,

    on_contact_player = function(e, ctx)
        kill_enemy(e)
    end,
}
```

### Initial Enemy Behaviors (v1)

| Behavior | Description |
|----------|-------------|
| **Wander** | Random movement, basic fodder |
| **Chase** | Move toward player, melee on contact |
| **Kite** | Keep distance from player |
| **Dash** | Periodically charge at player |
| **Trap layer** | Drops hazards on timer |
| **Summoner** | Spawns smaller enemies |
| **Exploder** | Rushes player, explodes on death/contact |

---

## Elite System

Elites use a modifier pool (with option for unique types):

```lua
-- assets/scripts/data/elite_modifiers.lua

-- Stat modifiers
modifiers.tanky = {
    hp_mult = 2.0,
    size_mult = 1.3,
}

modifiers.fast = {
    speed_mult = 1.5,
}

modifiers.deadly = {
    damage_mult = 1.75,
}

-- Behavior modifiers
modifiers.vampiric = {
    on_apply = function(e, ctx)
        ctx.on_hit_player = function(e, ctx)
            heal_enemy(e, ctx.damage * 0.5)
        end
    end,
}

modifiers.explosive_death = {
    on_apply = function(e, ctx)
        local original = ctx.on_death
        ctx.on_death = function(e, ctx)
            if original then original(e, ctx) end
            explode(e, 50, 15)
        end
    end,
}

modifiers.summoner = {
    on_apply = function(e, ctx)
        timer.every(6.0, function()
            if not entity_cache.valid(e) then return false end
            summon_enemies(e, "goblin", 1)
        end, "elite_" .. e .. "_summon")
    end,
}

modifiers.enraged = {
    on_apply = function(e, ctx)
        local triggered = false
        timer.every(0.5, function()
            if not entity_cache.valid(e) then return false end
            if not triggered and get_hp_percent(e) < 0.3 then
                triggered = true
                ctx.speed = ctx.speed * 1.5
                ctx.damage = ctx.damage * 1.5
                set_shader(e, "rage_glow")
            end
        end, "elite_" .. e .. "_enrage")
    end,
}

modifiers.shielded = {
    on_apply = function(e, ctx)
        set_invulnerable(e, true)
        set_shader(e, "shield_bubble")
        timer.after(3.0, function()
            if entity_cache.valid(e) then
                set_invulnerable(e, false)
                clear_shader(e, "shield_bubble")
            end
        end, "elite_" .. e .. "_shield")
    end,
}
```

### Usage

```lua
elite = { base = "goblin", modifiers = { "tanky", "fast" } }
elite = { base = "goblin", modifier_count = 2 }  -- random roll
elite = "goblin_chief"  -- unique type
```

---

## Context Object

`ctx` is built when enemy spawns and passed to all callbacks:

```lua
local ctx = {
    -- From definition
    type = enemy_type,
    hp = def.hp,
    max_hp = def.hp,
    speed = def.speed,
    damage = def.damage,
    size = def.size,

    -- Runtime
    entity = e,
    is_elite = #modifiers > 0,
    modifiers = modifiers,

    -- Callbacks (can be wrapped by modifiers)
    on_death = def.on_death,
    on_hit = def.on_hit,
    on_hit_player = def.on_hit_player,
    on_contact_player = def.on_contact_player,
}
```

### Callback Signatures

```lua
on_spawn = function(e, ctx) end
on_hit = function(e, ctx, hit_info) end           -- hit_info: damage, source, damage_type, is_crit
on_death = function(e, ctx, death_info) end       -- death_info: killer, damage_type, overkill
on_hit_player = function(e, ctx, hit_info) end    -- hit_info: damage, target
on_contact_player = function(e, ctx) end
```

---

## Stage Providers

### Sequence (hand-crafted)

```lua
stage_provider = providers.sequence({
    stage_1, stage_2, stage_3, boss_stage
})
```

### Endless (procedural)

```lua
stage_provider = providers.endless({
    base_waves = 3,
    wave_scaling = function(n) return 3 + math.floor(n / 3) end,
    enemy_pool = { ... },
    budget_base = 8,
    budget_per_stage = 3,
    elite_every = 3,
    shop_every = 1,
    reward_every = 5,
})
```

### Hybrid (story then endless)

```lua
stage_provider = providers.hybrid(
    { stage_1, stage_2, boss_1 },  -- hand-crafted
    { elite_every = 3 }            -- endless config
)
```

---

## Signals

### Emitted by Wave System

| Signal | Parameters | When |
|--------|------------|------|
| `stage_started` | `stage_config` | Stage begins |
| `wave_started` | `wave_num, wave` | Wave begins |
| `wave_cleared` | `wave_num` | All enemies in wave dead |
| `elite_spawned` | `entity, ctx` | Elite spawns |
| `stage_completed` | `results` | All waves + elite done |
| `enemy_killed` | `entity, ctx` | Any enemy dies |
| `run_complete` | - | No more stages |

### Required from Combat System

| Signal | Parameters | Must emit when |
|--------|------------|----------------|
| `on_entity_damaged` | `target, hit_info` | Entity takes damage |
| `on_entity_death` | `target, death_info` | Entity HP <= 0 |

---

## Integration Requirements

### Required Helper Functions

```lua
-- Movement
move_toward_player(e, speed)
flee_from_player(e, speed, min_distance)
kite_from_player(e, speed, preferred_distance)
wander(e, speed)
dash_toward_player(e, dash_speed, duration)

-- Combat
deal_damage_to_player(damage)
heal_enemy(e, amount)
kill_enemy(e)

-- Spawning
drop_trap(e, damage, lifetime)
summon_enemies(e, enemy_type, count)
explode(e, radius, damage)

-- Visual
spawn_telegraph(position, enemy_type, duration)
show_floating_text(text, opts)
spawn_particles(effect_name, e_or_position)
screen_shake(duration, intensity)

-- Context storage
set_enemy_ctx(e, ctx)
get_enemy_ctx(e)
```

---

## File Structure

```
assets/scripts/
├── combat/
│   ├── wave_director.lua      -- Core orchestrator
│   ├── stage_providers.lua    -- Sequence/Endless/Hybrid
│   ├── enemy_factory.lua      -- Creates enemies, wires callbacks
│   └── wave_helpers.lua       -- Movement, combat, spawn helpers
├── data/
│   ├── enemies.lua            -- Enemy definitions
│   ├── elite_modifiers.lua    -- Modifier definitions
│   └── stages/
│       ├── campaign.lua
│       └── endless_config.lua
```

---

## Usage Examples

### Quick Test

```lua
stage_provider = providers.sequence({
    {
        waves = {
            { "goblin", "goblin", "goblin" },
            { "goblin", "goblin", "archer" },
        },
        next = "shop",
    },
})
WaveDirector.start_stage(stage_provider.next())
```

### Starting a Run

```lua
function start_run(mode)
    reset_player()

    if mode == "endless" then
        stage_provider = providers.endless({ elite_every = 3 })
    else
        stage_provider = providers.sequence(campaign_stages)
    end

    activate_state(ACTION_STATE)
    WaveDirector.start_stage(stage_provider.next())
end

function continue_from_shop()
    activate_state(ACTION_STATE)
    local next_stage = stage_provider.next()
    if next_stage then
        WaveDirector.start_stage(next_stage)
    else
        signal.emit("run_complete")
    end
end
```

### Listening to Events

```lua
signal.register("wave_started", function(wave_num, wave)
    play_sound("wave_start")
end)

signal.register("enemy_killed", function(e, ctx)
    spawn_xp_orb(e)
end)

signal.register("stage_completed", function(results)
    play_sound("stage_complete")
end)
```

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
