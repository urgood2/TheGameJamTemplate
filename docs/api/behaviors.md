# Enemy Behavior Library

Declarative behavior composition for enemies. Replaces repetitive timer boilerplate with composable behavior definitions.

## Basic Usage

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

## Built-in Behaviors

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

## Config Resolution

String values like `"dash_speed"` lookup `ctx.dash_speed`. Numbers used directly.

```lua
behaviors = {
    { "dash", cooldown = "dash_cooldown", speed = "dash_speed" },
    -- Looks up ctx.dash_cooldown and ctx.dash_speed
}
```

## Auto-cleanup

All behavior timers are automatically cancelled when entity is destroyed.

## Register Custom Behaviors

```lua
local behaviors = require("core.behaviors")

behaviors.register("teleport", {
    defaults = { interval = 5.0, range = 100 },
    on_tick = function(e, ctx, helpers, config)
        helpers.teleport_random(e, config.range)
    end,
})
```

## Complete Enemy Definition

```lua
enemies.elite_mage = {
    sprite = "mage_elite.png",
    hp = 100,
    speed = 40,
    damage = 15,
    range = 200,
    summon_cooldown = 8.0,
    teleport_cooldown = 5.0,
    behaviors = {
        "kite",                                           -- Maintain distance
        { "summon", cooldown = "summon_cooldown" },       -- Spawn minions
        { "teleport", cooldown = "teleport_cooldown" },   -- Custom behavior
    },
}
```
