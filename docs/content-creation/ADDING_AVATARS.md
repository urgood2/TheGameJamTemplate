# Adding Avatars

Avatars are "Ascensions" or "Ultimate Forms" that players unlock mid-run. They provide powerful global rule changes that fundamentally alter gameplay.

## Implementation Status

| Feature | Status | Notes |
|---------|--------|-------|
| Avatar definitions | ✅ Implemented | `data/avatars.lua` |
| Unlock condition parsing | ✅ Implemented | Supports `OR_` prefix, `_tags` suffix |
| Progress tracking | ✅ Implemented | `record_progress()`, `check_unlocks()` |
| Equip state | ✅ Implemented | `equip()`, `get_equipped()` |
| **Effect application** | ⚠️ NOT IMPLEMENTED | See [Implementing Effects](#implementing-effects) |

The avatar system currently tracks unlock progress and equip state, but **does not apply effects when equipped**. The `effects` array is stored in the definition but requires runtime handlers to actually modify gameplay.

## Quick Start

Add to `assets/scripts/data/avatars.lua`:

```lua
my_avatar = {
    name = "Avatar of Flame",
    description = "Your fire consumes all.",

    unlock = {
        kills_with_fire = 50,
        OR_fire_tags = 7,
    },

    effects = {
        {
            type = "stat_buff",
            stat = "fire_damage_pct",
            value = 25,
        },
        {
            type = "rule_change",
            rule = "fire_spreads",
            desc = "Fire damage spreads to nearby enemies.",
        },
    },
}
```

## Field Reference

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Display name |
| `description` | string | Flavor text |
| `unlock` | table | Conditions to unlock (see below) |
| `effects` | table | Array of effects when equipped |

### Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `sprite` | string | Visual sprite/animation ID |
| `color` | table | Accent color `{ r, g, b }` |

## Unlock Conditions

Avatars unlock when **any** condition is met. Use `OR_` prefix for alternative paths.

### Metric-Based Unlocks

| Metric | Description |
|--------|-------------|
| `kills_with_fire` | Enemies killed with fire damage |
| `kills_with_ice` | Enemies killed with ice damage |
| `kills_with_lightning` | Enemies killed with lightning damage |
| `kills_with_poison` | Enemies killed with poison damage |
| `damage_blocked` | Total damage blocked/absorbed |
| `damage_dealt` | Total damage dealt |
| `distance_moved` | Distance traveled (units) |
| `crits_dealt` | Critical hits landed |
| `mana_spent` | Total mana consumed |
| `hp_lost` | Total HP lost |
| `enemies_killed` | Total enemies killed |
| `waves_completed` | Combat waves survived |

### Tag-Based Unlocks

Use `OR_<tag>_tags = N` for tag threshold unlocks:

```lua
unlock = {
    kills_with_fire = 100,  -- Primary path
    OR_fire_tags = 7,       -- Alternative: have 7+ Fire tags in deck
}
```

### Examples

```lua
-- Unlock by killing OR by tag collection
unlock = {
    kills_with_fire = 100,
    OR_fire_tags = 7,
}

-- Unlock by tanking damage OR defensive build
unlock = {
    damage_blocked = 5000,
    OR_defense_tags = 7,
}

-- Multiple metrics (all must be met within the group)
unlock = {
    crits_dealt = 50,
    OR_arcane_tags = 7,
}
```

## Effect Types

### Stat Buff

Permanent stat increase while equipped.

```lua
{
    type = "stat_buff",
    stat = "fire_damage_pct",  -- Stat to modify
    value = 25,                -- Amount (positive = buff)
}
```

Common stats:
- `fire_damage_pct`, `ice_damage_pct`, `lightning_damage_pct`, `poison_damage_pct`
- `cast_speed` (multiplier, 0.5 = +50% faster)
- `hazard_tick_rate_pct` (100 = 2x tick speed)
- `block_chance_pct`
- `crit_chance_pct`
- `mana_regen_pct`

### Rule Change

Modifies core game rules.

```lua
{
    type = "rule_change",
    rule = "multicast_loops",
    desc = "Multicast modifiers Loop the cast block instead of simultaneous cast.",
}
```

Common rules:
- `multicast_loops` - Multicast becomes sequential
- `crit_chains` - Crits chain to nearby enemies
- `fire_spreads` - Fire damage spreads to nearby enemies
- `summons_inherit_block` - Summons get your Block/Thorns
- `move_casts_trigger_onhit` - Movement wands trigger on-hit effects
- `summon_cast_share` - Summons copy your projectiles
- `missing_hp_dmg` - Damage scales with missing HP

### Proc Effect

Triggered ability on specific events.

```lua
{
    type = "proc",
    trigger = "on_cast_4th",  -- Every 4th cast
    effect = "global_barrier",
    value = 10,               -- 10% HP barrier
}
```

Triggers:
- `on_cast_Nth` - Every Nth spell cast
- `on_kill` - When killing an enemy
- `on_hit` - When dealing damage
- `on_wave_start` - When wave begins
- `distance_moved_Nm` - Every N meters moved

Effects:
- `global_barrier` - Shield based on % HP
- `heal` - Flat HP restore
- `mana_restore` - Flat mana restore
- `poison_spread` - AoE poison (uses `radius`)
- `damage_burst` - AoE damage (uses `radius`, `damage`)

## Templates

### Offensive Avatar (Element Focus)
```lua
inferno_lord = {
    name = "Inferno Lord",
    description = "Master of flame and destruction.",

    unlock = {
        kills_with_fire = 100,
        OR_fire_tags = 7,
    },

    effects = {
        {
            type = "stat_buff",
            stat = "fire_damage_pct",
            value = 30,
        },
        {
            type = "rule_change",
            rule = "fire_spreads",
            desc = "Fire damage spreads to nearby enemies.",
        },
    },
}
```

### Defensive Avatar
```lua
iron_bastion = {
    name = "Iron Bastion",
    description = "Unmovable. Unbreakable.",

    unlock = {
        damage_blocked = 5000,
        OR_defense_tags = 7,
    },

    effects = {
        {
            type = "stat_buff",
            stat = "block_chance_pct",
            value = 15,
        },
        {
            type = "proc",
            trigger = "on_cast_4th",
            effect = "global_barrier",
            value = 10,
        },
        {
            type = "rule_change",
            rule = "summons_inherit_block",
            desc = "Summons inherit 100% of your Block Chance.",
        },
    },
}
```

### Mobility Avatar
```lua
wind_dancer = {
    name = "Wind Dancer",
    description = "Never stop moving.",

    unlock = {
        distance_moved = 500,
        OR_mobility_tags = 5,
    },

    effects = {
        {
            type = "stat_buff",
            stat = "move_speed_pct",
            value = 20,
        },
        {
            type = "rule_change",
            rule = "move_casts_trigger_onhit",
            desc = "Movement-triggered wands now trigger On-Hit effects.",
        },
        {
            type = "proc",
            trigger = "distance_moved_5m",
            effect = "damage_burst",
            radius = 60,
            damage = 15,
        },
    },
}
```

### Crit Avatar
```lua
storm_striker = {
    name = "Storm Striker",
    description = "Lightning never misses.",

    unlock = {
        crits_dealt = 50,
        OR_arcane_tags = 7,
    },

    effects = {
        {
            type = "stat_buff",
            stat = "crit_chance_pct",
            value = 15,
        },
        {
            type = "stat_buff",
            stat = "cast_speed",
            value = 0.3,
        },
        {
            type = "rule_change",
            rule = "crit_chains",
            desc = "Critical hits always Chain to a nearby enemy.",
        },
    },
}
```

### Summoner Avatar
```lua
legion_master = {
    name = "Legion Master",
    description = "Your army fights as one.",

    unlock = {
        enemies_killed = 500,
        OR_summon_tags = 6,
    },

    effects = {
        {
            type = "stat_buff",
            stat = "summon_hp_pct",
            value = 50,
        },
        {
            type = "rule_change",
            rule = "summon_cast_share",
            desc = "When you cast a projectile, your Summons also cast a copy.",
        },
    },
}
```

### Risk/Reward Avatar
```lua
blood_god = {
    name = "Blood God",
    description = "Pain is power.",

    unlock = {
        hp_lost = 500,
        OR_brute_tags = 7,
    },

    effects = {
        {
            type = "rule_change",
            rule = "missing_hp_dmg",
            desc = "Gain +1% Damage for every 1% missing HP.",
        },
        {
            type = "proc",
            trigger = "on_kill",
            effect = "heal",
            value = 5,
        },
    },
}
```

## Testing

1. **Validate syntax:**
   ```lua
   dofile("assets/scripts/tools/content_validator.lua")
   ```

2. **Test unlock conditions:**
   - Open Content Debug Panel → Avatar tab (if available)
   - Use metric simulation buttons
   - Or manually: `avatar_system.record_progress(player, "kills_with_fire", 100)`

3. **Test effects:**
   - Equip avatar: `avatar_system.equip(player, "my_avatar")`
   - Verify stat buffs apply
   - Trigger proc conditions
   - Test rule changes with actual gameplay

## Implementing Effects

The avatar system stores effect definitions but **does not apply them automatically**. You must add runtime handlers in the appropriate systems.

### Adding a Stat Buff Effect

Stat buffs require integration with the stat system. In `wand/avatar_system.lua`:

```lua
-- Add this function to apply stat buffs when equipped
function AvatarSystem.apply_effects(player)
    local avatarId = AvatarSystem.get_equipped(player)
    if not avatarId then return end

    local def = loadDefs()[avatarId]
    if not def or not def.effects then return end

    for _, effect in ipairs(def.effects) do
        if effect.type == "stat_buff" then
            -- Integration point: connect to your stat system
            -- Example: player.stats[effect.stat] = (player.stats[effect.stat] or 0) + effect.value
        end
    end
end
```

### Adding a Rule Change Effect

Rule changes modify global game behavior. Check them where the rule applies:

```lua
-- In your combat/casting code:
local function should_fire_spread()
    local avatarId = AvatarSystem.get_equipped(globals.player)
    if not avatarId then return false end

    local def = require("data.avatars")[avatarId]
    for _, effect in ipairs(def.effects or {}) do
        if effect.type == "rule_change" and effect.rule == "fire_spreads" then
            return true
        end
    end
    return false
end
```

### Adding a Proc Effect

Procs require event hooks. The trigger names like `on_cast_4th` or `distance_moved_5m` need parsing:

```lua
-- Parse trigger string
local function parse_trigger(trigger)
    local nth = trigger:match("on_cast_(%d+)")
    if nth then return "on_cast", tonumber(nth) end

    local meters = trigger:match("distance_moved_(%d+)m")
    if meters then return "distance", tonumber(meters) end

    return trigger, nil
end

-- Hook into joker system events
signal.register("on_spell_cast", function(context)
    local avatarId = AvatarSystem.get_equipped(globals.player)
    if not avatarId then return end

    local def = require("data.avatars")[avatarId]
    for _, effect in ipairs(def.effects or {}) do
        if effect.type == "proc" then
            local triggerType, value = parse_trigger(effect.trigger)
            -- Check condition and execute effect
        end
    end
end)
```

### Adding New Effect Types

To add a completely new effect type:

1. Define the effect in your avatar:
   ```lua
   { type = "my_custom_effect", custom_param = 100 }
   ```

2. Handle it in the appropriate system:
   ```lua
   for _, effect in ipairs(def.effects or {}) do
       if effect.type == "my_custom_effect" then
           -- Your custom logic
       end
   end
   ```

The system is fully extensible - any effect type string works, you just need to add the handler code.

## Common Mistakes

1. **Missing unlock conditions** - Avatar can never be unlocked
   ```lua
   -- WRONG (no unlock)
   my_avatar = {
       name = "My Avatar",
       effects = { ... },
   }

   -- RIGHT
   my_avatar = {
       name = "My Avatar",
       unlock = { enemies_killed = 100 },
       effects = { ... },
   }
   ```

2. **Empty effects** - Avatar does nothing when equipped
   ```lua
   -- WRONG
   effects = {}

   -- RIGHT
   effects = {
       { type = "stat_buff", stat = "damage_pct", value = 10 },
   }
   ```

3. **Invalid stat name** - Effect silently fails
   ```lua
   -- WRONG (typo)
   stat = "fire_dmg_pct",

   -- RIGHT
   stat = "fire_damage_pct",
   ```

4. **Wrong OR_ prefix format** - Alternative path doesn't work
   ```lua
   -- WRONG
   OR_Fire_tags = 7,  -- capital F
   or_fire_tags = 7,  -- lowercase or

   -- RIGHT
   OR_fire_tags = 7,
   ```

5. **Proc without value** - Effect magnitude undefined
   ```lua
   -- WRONG
   { type = "proc", trigger = "on_kill", effect = "heal" }

   -- RIGHT
   { type = "proc", trigger = "on_kill", effect = "heal", value = 5 }
   ```
