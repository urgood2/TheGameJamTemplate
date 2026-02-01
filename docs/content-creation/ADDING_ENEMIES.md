# Adding Enemies

This guide covers how to create enemies using the declarative behavior system.

## Quick Start

Add a new enemy to `assets/scripts/data/enemies.lua`:

```lua
enemies.my_enemy = {
    sprite = "enemy_sprite.png",
    hp = 30,
    speed = 60,
    damage = 5,
    size = { 32, 32 },

    behaviors = {
        "chase",
    },

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("enemy_death", e)
    end,
}
```

Spawn it with EnemyFactory:

```lua
local EnemyFactory = require("combat.enemy_factory")
local enemy, ctx = EnemyFactory.spawn("my_enemy", { x = 100, y = 200 })
```

## Enemy Definition Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `sprite` | string | Yes | Animation/sprite ID |
| `hp` | number | Yes | Starting health |
| `speed` | number | Yes | Movement speed (pixels/sec) |
| `damage` | number | Yes | Contact damage to player |
| `size` | {w, h} | No | Override sprite dimensions |
| `behaviors` | table | Yes | Array of behavior specs |
| `on_death` | function | No | Called when enemy dies |
| `on_spawn` | function | No | Called after spawn (legacy) |
| `on_hit` | function | No | Called when enemy takes damage |
| `on_contact_player` | function | No | Called on player collision |

## Available Behaviors

### Movement Behaviors

| Behavior | Description | Config |
|----------|-------------|--------|
| `chase` | Move toward player | `interval`, `speed` |
| `wander` | Random movement | `interval`, `speed` |
| `flee` | Move away from player | `distance`, `speed` |
| `kite` | Maintain distance (ranged) | `range`, `speed` |
| `rush` | Fast chase (aggressive) | `interval=0.3`, `speed` |
| `orbit` | Circle around player | `radius`, `angular_speed`, `speed` |
| `strafe` | Move perpendicular to player | `speed`, `direction_change_chance` |
| `patrol` | Follow waypoints | `waypoints`, `speed`, `loop` |
| `zigzag` | Erratic movement | `speed`, `zigzag_amplitude`, `zigzag_frequency` |
| `ambush` | Hide until player is close | `trigger_range`, `speed` |
| `teleport` | Periodic teleportation | `interval`, `min_distance`, `max_distance` |

### Attack Behaviors

| Behavior | Description | Config |
|----------|-------------|--------|
| `dash` | Burst toward player | `cooldown`, `speed`, `duration` |
| `ranged_attack` | Fire single projectile | `interval`, `range`, `projectile`, `damage` |
| `spread_shot` | Fire projectile fan | `interval`, `range`, `count`, `spread_angle` |
| `ring_shot` | Fire projectiles in all directions | `interval`, `count` |
| `burst_fire` | Rapid fire burst | `burst_cooldown`, `burst_count`, `burst_delay` |
| `trap` | Drop hazards | `cooldown`, `damage`, `lifetime` |
| `summon` | Spawn minions | `cooldown`, `enemy_type`, `count` |

## Behavior Configuration

Behaviors accept config via table syntax:

```lua
behaviors = {
    "chase",                                    -- Uses defaults
    { "dash", cooldown = 2.0, speed = 300 },    -- Override specific values
    { "ranged_attack", interval = "attack_cooldown" },  -- Reference ctx field
}
```

### Config Value Resolution

- **Numbers/tables**: Used directly
- **Strings**: If matching a ctx field, uses that value
- **Functions**: Called with (ctx) to compute value

```lua
enemies.example = {
    hp = 30,
    attack_cooldown = 1.5,  -- ctx field

    behaviors = {
        { "ranged_attack", interval = "attack_cooldown" },  -- Uses ctx.attack_cooldown = 1.5
        { "ranged_attack", interval = 2.0 },                -- Uses literal 2.0
    },
}
```

## Common Enemy Patterns

### Basic Chaser

```lua
enemies.goblin = {
    sprite = "goblin.png",
    hp = 30, speed = 60, damage = 5,
    behaviors = { "chase" },
}
```

### Ranged Attacker

```lua
enemies.archer = {
    sprite = "archer.png",
    hp = 20, speed = 40, damage = 8,
    attack_range = 200,
    attack_cooldown = 1.5,
    projectile_preset = "enemy_arrow",

    behaviors = {
        { "kite", range = "attack_range" },
        { "ranged_attack", interval = "attack_cooldown", range = "attack_range", projectile = "projectile_preset" },
    },
}
```

### Dasher

```lua
enemies.dasher = {
    sprite = "dasher.png",
    hp = 25, speed = 50, damage = 12,
    dash_speed = 300,
    dash_cooldown = 3.0,

    behaviors = {
        "wander",
        { "dash", cooldown = "dash_cooldown", speed = "dash_speed", duration = 0.3 },
    },
}
```

### Orbiter (Circle + Shoot)

```lua
enemies.orbiter = {
    sprite = "orbiter.png",
    hp = 25, speed = 80, damage = 6,
    orbit_radius = 120,
    orbit_speed = 1.5,
    attack_cooldown = 2.0,

    behaviors = {
        { "orbit", radius = "orbit_radius", angular_speed = "orbit_speed" },
        { "ranged_attack", interval = "attack_cooldown", range = 200 },
    },
}
```

### Summoner

```lua
enemies.summoner = {
    sprite = "summoner.png",
    hp = 50, speed = 25, damage = 2,
    summon_cooldown = 5.0,
    summon_type = "goblin",
    summon_count = 2,

    behaviors = {
        { "flee", distance = 150 },
        { "summon", cooldown = "summon_cooldown", enemy_type = "summon_type", count = "summon_count" },
    },
}
```

### Exploder

```lua
enemies.exploder = {
    sprite = "exploder.png",
    hp = 15, speed = 80, damage = 0,
    explosion_radius = 60,
    explosion_damage = 25,

    behaviors = { "rush" },

    on_death = function(e, ctx, helpers)
        helpers.explode(e, ctx.explosion_radius, ctx.explosion_damage)
        helpers.screen_shake(0.2, 5)
    end,

    on_contact_player = function(e, ctx, helpers)
        helpers.kill_enemy(e)
    end,
}
```

### Burst Shooter

```lua
enemies.burst_shooter = {
    sprite = "shooter.png",
    hp = 28, speed = 40, damage = 4,
    burst_cooldown = 2.5,
    attack_range = 200,

    behaviors = {
        { "kite", range = "attack_range" },
        { "burst_fire", interval = "burst_cooldown", range = "attack_range", burst_count = 4, burst_delay = 0.15 },
    },
}
```

## Elite Modifiers

Add modifiers when spawning to create elite variants:

```lua
local elite, ctx = EnemyFactory.spawn("goblin", pos, { "tanky", "fast" })
```

### Available Modifiers

| Modifier | Effect |
|----------|--------|
| `tanky` | 2x HP, 1.3x size |
| `fast` | 1.5x speed |
| `deadly` | 1.75x damage |
| `armored` | 50% damage reduction |
| `vampiric` | Heals on hit |
| `explosive_death` | Explodes on death |
| `summoner_mod` | Spawns minions periodically |
| `enraged` | Gets stronger at low HP |
| `shielded` | Invulnerable for 3 seconds |
| `regenerating` | Slowly heals |
| `teleporter` | Teleports near player |

## Death Effects Shorthand

Use strings for common death effects:

```lua
on_death = "particles:enemy_death",     -- Spawn particle effect
on_death = "explode:60:25",             -- Explode with radius 60, damage 25
```

## Wave Helper Functions

All helpers are available in behavior callbacks and `on_*` functions:

### Movement
- `helpers.move_toward_player(e, speed)`
- `helpers.flee_from_player(e, speed, distance)`
- `helpers.kite_from_player(e, speed, range)`
- `helpers.wander(e, speed)`
- `helpers.dash_toward_player(e, speed, duration)`
- `helpers.move_toward_point(e, x, y, speed)`
- `helpers.move_in_direction(e, angle, speed)`
- `helpers.strafe_around_player(e, speed, direction)`

### Distance/Range
- `helpers.distance_to_player(e)` → number
- `helpers.distance_between(e1, e2)` → number
- `helpers.is_in_range(e, range)` → boolean
- `helpers.direction_to_player(e)` → {x, y}
- `helpers.angle_to_player(e)` → radians

### Projectiles
- `helpers.fire_projectile(e, preset, damage, opts)`
- `helpers.fire_projectile_leading(e, preset, damage, speed)`
- `helpers.fire_projectile_spread(e, preset, damage, count, spread_angle)`
- `helpers.fire_projectile_ring(e, preset, damage, count)`

### Combat
- `helpers.deal_damage_to_player(damage)`
- `helpers.heal_enemy(e, amount)`
- `helpers.kill_enemy(e)`
- `helpers.get_hp_percent(e)` → 0.0-1.0
- `helpers.set_invulnerable(e, bool)`

### Spawning
- `helpers.drop_trap(e, damage, lifetime)`
- `helpers.summon_enemies(e, enemy_type, count)`
- `helpers.explode(e, radius, damage)`

### Visual
- `helpers.spawn_particles(effect, e_or_pos)`
- `helpers.screen_shake(duration, intensity)`
- `helpers.set_shader(e, shader_name)`
- `helpers.clear_shader(e)`
- `helpers.spawn_telegraph(pos, enemy_type, duration)`

### Position
- `helpers.get_player_position()` → {x, y}
- `helpers.get_entity_position(e)` → {x, y}
- `helpers.get_player_velocity()` → {x, y}

## Behavior Composition

For complex AI patterns, use composite behaviors:

### Sequence (do A, then B, then C)

```lua
behaviors.register_composite("hit_and_run", {
    type = "sequence",
    loop = true,
    steps = {
        { "dash", duration = 0.3 },
        { "flee", duration = 2.0 },
    },
})
```

### Selector (if A else B else C)

```lua
behaviors.register_composite("sniper", {
    type = "selector",
    interval = 0.3,
    conditions = {
        {
            check = function(e, ctx, helpers)
                return helpers.is_in_range(e, ctx.attack_range)
            end,
            behavior = "ranged_attack",
        },
        {
            check = function(e, ctx, helpers)
                return helpers.distance_to_player(e) < ctx.min_range
            end,
            behavior = "flee",
        },
    },
    fallback = "kite",
})
```

### Parallel (do A and B simultaneously)

```lua
behaviors.register_composite("gunner", {
    type = "parallel",
    behaviors = {
        "strafe",
        { "ranged_attack", interval = 1.0 },
    },
})
```

## Custom Behaviors

Register new behaviors in your game code:

```lua
local behaviors = require("core.behaviors")

behaviors.register("laser_charge", {
    defaults = {
        interval = 0.1,
        charge_time = 2.0,
        damage = 50,
    },
    on_start = function(e, ctx, helpers, config)
        ctx._laser_charge = 0
        helpers.set_shader(e, "charge_glow")
    end,
    on_tick = function(e, ctx, helpers, config)
        ctx._laser_charge = ctx._laser_charge + config.interval
        if ctx._laser_charge >= config.charge_time then
            helpers.fire_projectile(e, "laser_beam", config.damage)
            ctx._laser_charge = 0
        end
    end,
    on_stop = function(e, ctx, helpers, config)
        helpers.clear_shader(e)
    end,
})
```

## Testing

Run the behavior tests:

```bash
lua assets/scripts/tests/test_enemy_behaviors.lua
```

## Files Reference

| File | Purpose |
|------|---------|
| `assets/scripts/data/enemies.lua` | Enemy definitions |
| `assets/scripts/data/elite_modifiers.lua` | Elite modifier definitions |
| `assets/scripts/core/behaviors.lua` | Behavior registry and built-ins |
| `assets/scripts/combat/wave_helpers.lua` | Helper functions |
| `assets/scripts/combat/enemy_factory.lua` | Enemy spawning |

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
