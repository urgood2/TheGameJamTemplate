# Adding Cards

Cards are spells that go into wands. There are three types:
- **Action** - Does something (fires projectile, heals, summons)
- **Modifier** - Modifies the next action (damage boost, multicast, homing)
- **Trigger** - Determines when the wand fires (timer, on dash, on bump)

## Implementation Status

| Feature | Status | Notes |
|---------|--------|-------|
| Card definitions | ✅ Implemented | `data/cards.lua` |
| Wand execution | ✅ Implemented | `wand/wand_executor.lua` |
| Tag synergies | ✅ Implemented | Works with joker system |
| **Custom behaviors** | ✅ Extensible | Via `BehaviorRegistry` |
| **Custom fields** | ✅ Extensible | Any field name works |

The card system is **fully extensible**. You can add custom fields to cards and create complex behaviors via the BehaviorRegistry.

## Quick Start

Add to `assets/scripts/data/cards.lua`:

```lua
Cards.MY_FIREBALL = {
    id = "MY_FIREBALL",
    type = "action",
    mana_cost = 12,
    damage = 25,
    damage_type = "fire",
    projectile_speed = 400,
    lifetime = 2000,
    radius_of_effect = 50,
    cast_delay = 150,
    tags = { "Fire", "Projectile", "AoE" },
    test_label = "MY\nfireball",
}
```

## Field Reference

### Required Fields (All Cards)

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier (must match table key) |
| `type` | string | `"action"`, `"modifier"`, or `"trigger"` |
| `mana_cost` | number | Mana consumed when cast |
| `tags` | table | Array of tag strings for joker synergies |
| `test_label` | string | Display name (use `\n` for line breaks) |

### Action Card Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `damage` | number | 0 | Base damage dealt |
| `damage_type` | string | "physical" | `"physical"`, `"fire"`, `"ice"`, `"lightning"`, `"poison"`, `"arcane"`, `"holy"`, `"void"` |
| `projectile_speed` | number | 500 | Projectile velocity |
| `lifetime` | number | 2000 | Projectile duration (ms) |
| `radius_of_effect` | number | 0 | Explosion/AoE radius (0 = no AoE) |
| `spread_angle` | number | 0 | Random spread in degrees |
| `cast_delay` | number | 100 | Delay before firing (ms) |
| `recharge_time` | number | 0 | Cooldown after cast (ms) |
| `max_uses` | number | -1 | Uses before discarded (-1 = infinite) |
| `weight` | number | 1 | Rarity weight for shop/drops |

### Special Action Fields

| Field | Type | Status | Description |
|-------|------|--------|-------------|
| `ricochet_count` | number | ✅ | Bounces before despawning (`wand_modifiers.lua:237`) |
| `trigger_on_collision` | bool | ✅ | Casts next card on hit (`wand_executor.lua:595`) |
| `trigger_on_timer` | bool | ✅ | Casts next card after `timer_ms` (`wand_executor.lua:853`) |
| `trigger_on_death` | bool | ✅ | Casts next card when projectile expires (`wand_actions.lua:516`) |
| `timer_ms` | number | ✅ | Timer duration for trigger (used with `trigger_on_timer`) |
| `gravity_affected` | bool | ✅ | Projectile uses ARC movement (`wand_actions.lua:325`) |
| `homing_strength` | number | ✅ | Tracking strength (1-15, applied in `wand_actions.lua:367`) |
| `teleport_on_hit` | bool | ⚠️ STUB | Detection exists, execution needs implementation |
| `leave_hazard` | bool | ⚠️ STUB | Detection exists, hazard system needs implementation |
| `heal_amount` | number | ✅ | HP restored (`wand_actions.lua:564`) |
| `shield_strength` | number | ✅ | Shield HP granted (`wand_actions.lua:580`) |
| `summon_entity` | string | ⚠️ STUB | Detection exists, spawning system needs implementation |

**How triggers work**: When a card has `trigger_on_collision`, `trigger_on_timer`, or `trigger_on_death`, the wand executor collects subsequent cards as a "sub-cast block" that fires when the trigger condition is met. The triggered cards inherit context from the triggering projectile.

### Modifier Card Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `damage_modifier` | number | 0 | Added to action damage |
| `spread_modifier` | number | 0 | Added to spread angle |
| `speed_modifier` | number | 0 | Added to projectile speed (multiplier) |
| `lifetime_modifier` | number | 0 | Added to lifetime (multiplier) |
| `critical_hit_chance_modifier` | number | 0 | Added crit chance % |
| `multicast_count` | number | 1 | Number of times to cast next action |
| `revisit_limit` | number | 2 | Max times this mod can apply per cast |

### Special Modifier Fields

| Field | Type | Status | Description |
|-------|------|--------|-------------|
| `seek_strength` | number | ✅ | Alias for homing (`wand_modifiers.lua:161`) |
| `make_explosive` | bool | ✅ | Adds explosion on impact (`wand_modifiers.lua:230`) |
| `force_crit_next` | bool | ✅ | Next action always crits (`wand_modifiers.lua:270`) |
| `size_multiplier` | number | ✅ | Projectile scale factor (`wand_actions.lua:434`) |
| `heal_on_hit` | number | ✅ | HP restored on hit (`wand_actions.lua:476`) |
| `auto_aim` | bool | ✅ | Auto-targets nearest enemy (`wand_actions.lua:323`) |
| `wand_refresh` | bool | ✅ | Resets wand cooldown |

### Trigger Card Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Trigger type: `"every_N_seconds"`, `"on_bump_enemy"`, `"on_dash"`, `"on_distance_traveled"` |

## Templates

### Basic Projectile
```lua
Cards.TEMPLATE_BASIC_PROJECTILE = {
    id = "TEMPLATE_BASIC_PROJECTILE",
    type = "action",
    mana_cost = 5,
    damage = 10,
    damage_type = "physical",
    projectile_speed = 500,
    lifetime = 2000,
    cast_delay = 100,
    tags = { "Projectile" },
    test_label = "TEMPLATE\nbasic",
}
```

### Explosive AoE
```lua
Cards.TEMPLATE_EXPLOSIVE = {
    id = "TEMPLATE_EXPLOSIVE",
    type = "action",
    mana_cost = 15,
    damage = 30,
    damage_type = "fire",
    projectile_speed = 400,
    lifetime = 2000,
    radius_of_effect = 60,
    cast_delay = 150,
    tags = { "Fire", "Projectile", "AoE" },
    test_label = "TEMPLATE\nexplosive",
}
```

### Homing Missile
```lua
Cards.TEMPLATE_HOMING = {
    id = "TEMPLATE_HOMING",
    type = "action",
    mana_cost = 10,
    damage = 15,
    damage_type = "arcane",
    projectile_speed = 350,
    lifetime = 3000,
    homing_strength = 8,
    cast_delay = 120,
    tags = { "Arcane", "Projectile" },
    test_label = "TEMPLATE\nhoming",
}
```

### Bouncing Ball
```lua
Cards.TEMPLATE_BOUNCING = {
    id = "TEMPLATE_BOUNCING",
    type = "action",
    mana_cost = 10,
    damage = 15,
    damage_type = "physical",
    projectile_speed = 450,
    lifetime = 2500,
    ricochet_count = 3,
    cast_delay = 120,
    tags = { "Projectile" },
    test_label = "TEMPLATE\nbouncing",
}
```

### Trigger-on-Hit (Casts Next Card)
```lua
Cards.TEMPLATE_TRIGGER_HIT = {
    id = "TEMPLATE_TRIGGER_HIT",
    type = "action",
    mana_cost = 12,
    damage = 10,
    damage_type = "physical",
    projectile_speed = 500,
    lifetime = 2000,
    trigger_on_collision = true,
    cast_delay = 100,
    tags = { "Projectile" },
    test_label = "TEMPLATE\ntrigger\nhit",
}
```

### Damage Boost Modifier
```lua
Cards.TEMPLATE_DAMAGE_MOD = {
    id = "TEMPLATE_DAMAGE_MOD",
    type = "modifier",
    mana_cost = 5,
    damage_modifier = 10,
    tags = { "Buff" },
    test_label = "TEMPLATE\ndamage\nmod",
}
```

### Multicast Modifier
```lua
Cards.TEMPLATE_MULTICAST = {
    id = "TEMPLATE_MULTICAST",
    type = "modifier",
    mana_cost = 10,
    multicast_count = 2,
    tags = { "Arcane" },
    test_label = "TEMPLATE\nmulticast",
}
```

## Testing

1. **Validate syntax:**
   ```lua
   dofile("assets/scripts/tools/content_validator.lua")
   ```

2. **Spawn in game:**
   - Open ImGui Card Spawner
   - Find your card in the list
   - Click to spawn to inventory or action board

3. **Check tags work:**
   - Open Tag Inspector tab in Content Debug Panel
   - Add card to wand
   - Verify tag counts update

## Common Mistakes

1. **ID mismatch** - `id` field must match the table key exactly
   ```lua
   -- WRONG
   Cards.MY_CARD = { id = "MYCARD", ... }

   -- RIGHT
   Cards.MY_CARD = { id = "MY_CARD", ... }
   ```

2. **Missing tags** - Without `tags`, joker synergies won't trigger
   ```lua
   -- WRONG (no tags)
   Cards.FIRE_BOLT = { damage_type = "fire", ... }

   -- RIGHT
   Cards.FIRE_BOLT = { damage_type = "fire", tags = { "Fire", "Projectile" }, ... }
   ```

3. **Unknown tag names** - Typos break synergies silently
   ```lua
   -- WRONG (typo)
   tags = { "Frie", "Projectile" }

   -- RIGHT
   tags = { "Fire", "Projectile" }
   ```

4. **Wrong type** - Modifiers with damage, actions with multicast
   ```lua
   -- WRONG (modifier shouldn't have base damage)
   Cards.MY_MOD = { type = "modifier", damage = 10, ... }

   -- RIGHT (use damage_modifier instead)
   Cards.MY_MOD = { type = "modifier", damage_modifier = 10, ... }
   ```

## Extending the System

### Adding Custom Card Fields

You can add any field to a card. The wand executor passes the full card definition to behaviors:

```lua
Cards.MY_CUSTOM_CARD = {
    id = "MY_CUSTOM_CARD",
    type = "action",
    mana_cost = 10,
    tags = { "Projectile" },

    -- Standard fields
    damage = 15,

    -- Custom fields (your own)
    my_custom_field = "some_value",
    special_data = { foo = 1, bar = 2 },
    test_label = "MY\ncustom",
}
```

Then access it in your behavior:
```lua
if card.my_custom_field == "some_value" then
    -- Do something special
end
```

### Using BehaviorRegistry for Complex Logic

For behaviors that need executable code (not just data), use the BehaviorRegistry:

1. **Register a behavior:**
   ```lua
   local BehaviorRegistry = require("wand.card_behavior_registry")

   BehaviorRegistry.register("chain_explosion", function(ctx)
       local damage = ctx.damage
       local radius = ctx.params.radius or 60
       local maxChains = ctx.params.max_chains or 3

       -- Your complex logic here
       local chainsTriggered = 0
       -- ... spawning explosions, finding targets, etc.

       return chainsTriggered
   end, "Chain explosions that spread to nearby enemies")
   ```

2. **Reference it from a card:**
   ```lua
   Cards.CHAIN_EXPLOSION_CARD = {
       id = "CHAIN_EXPLOSION_CARD",
       type = "action",
       mana_cost = 20,
       damage = 25,
       behavior_id = "chain_explosion",  -- Reference the behavior
       behavior_params = {               -- Pass parameters
           radius = 80,
           max_chains = 5,
       },
       tags = { "Fire", "AoE" },
       test_label = "CHAIN\nexplosion",
   }
   ```

3. **Execute in your wand code:**
   ```lua
   if card.behavior_id then
       local ctx = {
           damage = card.damage,
           position = projectile_position,
           params = card.behavior_params or {},
       }
       BehaviorRegistry.execute(card.behavior_id, ctx)
   end
   ```

### Adding New Damage Types

Damage types are strings. To add a new type:

1. Use it in cards:
   ```lua
   damage_type = "void",
   ```

2. Handle it in damage calculation:
   ```lua
   if damage_type == "void" then
       -- Void damage ignores armor, etc.
   end
   ```

3. (Optional) Add to validator's known list to suppress warnings.

### Adding New Tags

Tags are just strings. To add a new tag:

1. Add to cards:
   ```lua
   tags = { "MyNewTag", "Fire" },
   ```

2. React to it in jokers:
   ```lua
   if context.tags and context.tags.MyNewTag then
       return { damage_mult = 1.5 }
   end
   ```

Standard tags: `Fire`, `Ice`, `Lightning`, `Poison`, `Arcane`, `Holy`, `Void`, `Projectile`, `AoE`, `Hazard`, `Summon`, `Buff`, `Debuff`, `Mobility`, `Defense`, `Brute`
