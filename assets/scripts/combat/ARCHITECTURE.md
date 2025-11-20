# Entity Lifecycle & Combat Loop Framework Architecture

## Overview

This document describes the Entity Lifecycle & Combat Loop Framework for the game. The system manages enemy spawning, wave progression, combat state management, entity death/cleanup, and loot drops to enable a full autobattle gameplay loop.

## System Components

### 1. Combat State Machine
The core state management system that orchestrates the combat loop.

#### State Diagram
```
┌─────────────────────────────────────────────────────────────────────┐
│                         COMBAT STATE MACHINE                         │
└─────────────────────────────────────────────────────────────────────┘

    [INIT]
      │
      ├──> [WAVE_START]
      │         │
      │         ├──> Initialize wave data
      │         ├──> Emit OnWaveStart event
      │         └──> Transition to SPAWNING
      │
      ├──> [SPAWNING]
      │         │
      │         ├──> Spawn enemies based on wave config
      │         ├──> Apply spawn patterns (timed, budget, instant)
      │         └──> When spawning complete -> COMBAT
      │
      ├──> [COMBAT]
      │         │
      │         ├──> Active battle (AI, player actions, damage)
      │         ├──> Continue spawning if wave uses timed spawns
      │         ├──> Monitor enemy count
      │         │
      │         ├──> All enemies dead? -> VICTORY
      │         └──> Player dead? -> DEFEAT
      │
      ├──> [VICTORY]
      │         │
      │         ├──> Calculate rewards (XP, gold, interest)
      │         ├──> Spawn loot drops
      │         ├──> Emit OnWaveComplete event
      │         ├──> Wait for loot collection
      │         │
      │         ├──> Last wave? -> GAME_WON
      │         └──> More waves? -> INTERMISSION
      │
      ├──> [INTERMISSION]
      │         │
      │         ├──> Display wave summary
      │         ├──> Optional: Shop/upgrade phase
      │         ├──> Player ready? -> WAVE_START (next wave)
      │         └──> Auto-progress after timer
      │
      ├──> [DEFEAT]
      │         │
      │         ├──> Player death animation/effects
      │         ├──> Show death screen
      │         │
      │         ├──> Retry? -> WAVE_START (same wave)
      │         └──> Quit? -> GAME_OVER
      │
      ├──> [GAME_WON]
      │         │
      │         └──> Victory screen, final rewards
      │
      └──> [GAME_OVER]
                │
                └──> Return to menu or end

```

### 2. Enemy Spawner System

#### Spawn Patterns

**Instant Wave:**
- Spawns all enemies immediately at wave start
- Budget-based: allocate points, fill with enemy types
- Use case: Boss fights, fixed encounters

**Timed Wave:**
- Spawns enemies over time according to schedule
- Schedule format: `{ {delay=0, enemy="goblin", count=3}, {delay=5, enemy="orc", count=2} }`
- Continues during COMBAT state

**Budget-Based:**
- Each wave has a budget (points)
- Each enemy type has a cost
- Spawner fills budget with enemy types
- Supports weighted random selection

**Continuous/Survival:**
- Spawns enemies indefinitely until timer expires
- Difficulty increases over time
- Use case: Survival modes

#### Spawn Point Management

```lua
SpawnPointTypes = {
    RANDOM_AREA = "random_area",      -- Random position in defined area
    FIXED_POINTS = "fixed_points",     -- Specific coordinates
    OFF_SCREEN = "off_screen",         -- Just outside camera view
    AROUND_PLAYER = "around_player",   -- Circle around player
    PATH_BASED = "path_based"          -- Along a predefined path
}
```

### 3. Wave Manager

#### Wave Configuration Schema

```lua
Wave = {
    wave_number = 1,

    -- Wave type determines spawn pattern
    type = "timed" | "instant" | "budget" | "survival" | "boss",

    -- Enemy composition
    enemies = {
        { type = "goblin", count = 5, cost = 1 },
        { type = "orc", count = 2, cost = 3 }
    },

    -- Budget mode
    budget = 20,  -- Total points to spend

    -- Timed mode spawn schedule
    spawn_schedule = {
        { delay = 0, enemy = "goblin", count = 3 },
        { delay = 5, enemy = "orc", count = 2 },
        { delay = 10, enemy = "goblin", count = 5 }
    },

    -- Survival mode
    survival_duration = 60,  -- seconds
    spawn_interval = 3,      -- spawn every N seconds

    -- Spawn locations
    spawn_config = {
        type = "random_area",
        area = { x = 100, y = 100, w = 800, h = 600 },
        -- OR
        type = "fixed_points",
        points = { {x=100, y=100}, {x=700, y=500} }
    },

    -- Difficulty modifiers
    difficulty_scale = 1.0,  -- Multiplier for enemy stats

    -- Rewards
    rewards = {
        base_xp = 100,
        base_gold = 50,
        interest_per_second = 1  -- Bonus gold per second survived
    },

    -- Optional callbacks
    on_wave_start = function(wave_manager, wave) end,
    on_wave_complete = function(wave_manager, wave, stats) end,
    on_enemy_spawned = function(wave_manager, enemy_entity) end
}
```

#### Difficulty Scaling

```lua
-- Formula for wave difficulty
difficulty = base_difficulty * (1 + wave_number * 0.2)

-- Applied to:
-- - Enemy HP: hp * difficulty
-- - Enemy damage: damage * difficulty
-- - Enemy count: count * (1 + wave_number * 0.1)
```

### 4. Entity Death & Cleanup System

#### Death Flow

```
Enemy HP <= 0
    │
    ├──> Emit OnEntityDeath event
    │
    ├──> Trigger death effects
    │         │
    │         ├──> Death animation
    │         ├──> Death sound
    │         └──> Death particles
    │
    ├──> Spawn loot drops
    │         │
    │         ├──> Roll loot table
    │         ├──> Spawn XP orbs
    │         ├──> Spawn gold coins
    │         └──> Spawn item drops (rare)
    │
    ├──> Cleanup entity components
    │         │
    │         ├──> Remove physics bodies
    │         ├──> Cancel timers (tag: entity_id)
    │         ├──> Remove from tracking lists
    │         ├──> Clear AI references
    │         └──> Remove UI elements (health bars)
    │
    └──> Destroy entity (registry:destroy)
```

#### Cleanup Checklist
- Physics bodies (Chipmunk2D)
- Timers (timer.cancel by tag)
- Event listeners
- UI attachments (health bars, nameplate)
- References in global tables (enemies list, targets)
- Animation state
- AI behavior trees
- Combat system references

### 5. Loot Drop System

#### Loot Types

```lua
LootType = {
    GOLD = "gold",           -- Currency
    XP_ORB = "xp_orb",      -- Experience
    HEALTH_POTION = "health_potion",
    CARD = "card",          -- Ability cards
    ITEM = "item"           -- Equipment
}
```

#### Loot Drop Configuration

```lua
LootDrop = {
    type = "xp_orb",
    amount = 10,            -- XP or gold amount

    -- Visual config
    sprite = "xp_orb_anim",
    size = { w = 32, h = 32 },

    -- Pickup behavior
    pickup_type = "auto_collect" | "click_to_collect" | "magnet",

    -- Magnet behavior
    magnet_range = 150,     -- Pixels from player
    magnet_speed = 200,     -- Pixels per second

    -- Collection delay
    spawn_delay = 0.3,      -- Can't be picked up immediately
    lifetime = 30,          -- Despawn after 30s if not collected

    -- Callbacks
    on_collect = function(player, loot) end
}
```

#### Loot Tables

```lua
enemy_loot_tables = {
    goblin = {
        gold = { min = 1, max = 3, chance = 100 },
        xp = { base = 10, variance = 2, chance = 100 },
        items = {
            { type = "health_potion", chance = 10 },
            { type = "card_common", chance = 5 }
        }
    },
    orc = {
        gold = { min = 5, max = 10, chance = 100 },
        xp = { base = 25, variance = 5, chance = 100 },
        items = {
            { type = "card_uncommon", chance = 15 }
        }
    },
    boss = {
        gold = { min = 50, max = 100, chance = 100 },
        xp = { base = 200, variance = 20, chance = 100 },
        items = {
            { type = "card_rare", chance = 50 },
            { type = "card_uncommon", chance = 100 }
        }
    }
}
```

### 6. Wave Timer & Performance Metrics

#### Tracked Metrics

```lua
WaveStats = {
    wave_number = 1,

    -- Time tracking
    start_time = 0,
    end_time = 0,
    duration = 0,

    -- Combat stats
    enemies_spawned = 0,
    enemies_killed = 0,
    damage_dealt = 0,
    damage_taken = 0,

    -- Performance metrics
    time_survived = 0,
    perfect_clear = false,  -- No damage taken
    speed_bonus = 0,        -- Bonus for fast clear

    -- Rewards
    base_xp = 100,
    base_gold = 50,
    interest_gold = 0,      -- Time-based bonus
    total_xp = 0,
    total_gold = 0
}
```

#### Interest Calculation

```lua
-- Interest: bonus gold for surviving longer
interest = math.floor(time_survived * interest_rate)

-- Speed bonus: bonus for clearing quickly
if duration < target_time then
    speed_bonus = (target_time - duration) * speed_multiplier
end

total_rewards = base_rewards + interest + speed_bonus
```

## Event System Integration

### Combat Loop Events

```lua
-- Wave events
"OnWaveStart"      -- { wave_number, wave_config }
"OnWaveComplete"   -- { wave_number, stats }
"OnWavesFailed"    -- { wave_number }

-- Spawn events
"OnEnemySpawned"   -- { entity, enemy_type, wave_number }
"OnEnemyDeath"     -- { entity, killer, wave_number }

-- Loot events
"OnLootDropped"    -- { loot_entity, loot_type, source_entity }
"OnLootCollected"  -- { player, loot_type, amount }

-- State transitions
"OnCombatStart"    -- { wave_number }
"OnCombatEnd"      -- { victory, stats }
"OnIntermission"   -- { next_wave }

-- Player events
"OnPlayerDeath"    -- { player }
"OnPlayerRevive"   -- { player }
```

## Data Flow

```
Wave Config → Wave Manager
    │
    ├──> Enemy Spawner
    │       │
    │       ├──> Entity Factory → Spawn Enemy
    │       │                         │
    │       │                         ├──> Physics Body
    │       │                         ├──> AI Component
    │       │                         ├──> Combat Stats
    │       │                         └──> Visual (sprite/animation)
    │       │
    │       └──> Track in enemies list
    │
    └──> Combat State Machine
            │
            ├──> Monitor enemy count
            ├──> Check win/loss conditions
            │
            └──> State Transitions
                    │
                    ├──> Victory
                    │       │
                    │       ├──> Calculate Rewards
                    │       └──> Spawn Loot
                    │
                    └──> Defeat
                            │
                            └──> Handle Game Over
```

## Integration Points

### With Existing Combat System

```lua
-- Listen for death events
combat_context.bus:on("OnEntityDeath", function(event)
    combat_loop.handle_entity_death(event.entity, event.killer)
end)

-- Track damage for stats
combat_context.bus:on("OnHitResolved", function(event)
    wave_stats.damage_dealt = wave_stats.damage_dealt + event.damage
end)
```

### With Timer System

```lua
-- Wave timer
timer.every(1.0, function()
    wave_manager.update(dt)
    spawner.update(dt)
end, 0, true, nil, "wave_update")

-- Timed spawns
for _, spawn in ipairs(wave.spawn_schedule) do
    timer.after(spawn.delay, function()
        spawner.spawn_enemy(spawn.enemy, spawn.count)
    end, "wave_spawn_" .. wave.wave_number)
end
```

### With Entity Factory

```lua
-- Spawn enemy using existing factory
local enemy = create_ai_entity(enemy_type)

-- Apply wave difficulty scaling
local combat_stats = enemy.stats
combat_stats:add_base("health", base_hp * wave.difficulty_scale)
combat_stats:add_base("attack", base_atk * wave.difficulty_scale)
combat_stats:recompute()

-- Track for wave management
wave_manager.track_enemy(enemy)
```

## Performance Considerations

### Pooling
- Reuse entity IDs when possible
- Pre-allocate common enemy types
- Pool loot drop entities

### Batch Operations
- Batch spawn multiple enemies per frame
- Defer cleanup to end of frame
- Batch loot calculations

### Memory Management
- Clear references promptly on death
- Cancel timers immediately
- Limit max enemies on screen

## Testing Strategy

### Unit Tests
- State machine transitions
- Spawn pattern generation
- Loot table rolling
- Difficulty calculations

### Integration Tests
- Full wave cycle (spawn → combat → victory)
- Death and cleanup flow
- Loot drop and collection
- Event bus integration

### Scenario Tests
- 2-wave progression test
- Boss wave test
- Survival mode test
- Performance stress test (100 enemies)

## Configuration Example

```lua
-- Simple 2-wave test scenario
test_waves = {
    {
        wave_number = 1,
        type = "instant",
        enemies = {
            { type = "goblin", count = 5 }
        },
        spawn_config = {
            type = "random_area",
            area = { x = 200, y = 200, w = 600, h = 400 }
        },
        difficulty_scale = 1.0,
        rewards = { base_xp = 50, base_gold = 20 }
    },
    {
        wave_number = 2,
        type = "timed",
        spawn_schedule = {
            { delay = 0, enemy = "goblin", count = 3 },
            { delay = 5, enemy = "orc", count = 2 },
            { delay = 10, enemy = "goblin", count = 3 }
        },
        spawn_config = {
            type = "off_screen",
            margin = 50
        },
        difficulty_scale = 1.3,
        rewards = { base_xp = 100, base_gold = 50, interest_per_second = 2 }
    }
}
```

## Future Extensions

- Multiple spawn groups per wave
- Dynamic difficulty adjustment
- Elite/champion enemy variants
- Wave modifiers (buffs/debuffs)
- Conditional wave branching
- Mini-boss sub-waves
- Environmental hazards during waves
- Player choice of next wave (risk/reward)
