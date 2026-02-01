# Adding Jokers

Jokers are passive artifacts that react to game events and modify calculations. They're inspired by Balatro's Joker system - global observers that trigger on spell casts, damage calculations, and other events.

## Implementation Status

| Feature | Status | Notes |
|---------|--------|-------|
| Joker definitions | ✅ Implemented | `data/jokers.lua` |
| Event triggering | ✅ Implemented | `JokerSystem.trigger_event()` |
| Effect aggregation | ✅ Implemented | Combines all joker effects |
| **Custom events** | ✅ Extensible | Any event name works |
| **Custom effects** | ✅ Extensible | Add fields to return table |

The joker system is **fully extensible**. You can define new event types and new effect types without modifying the core system.

## Quick Start

Add to `assets/scripts/data/jokers.lua`:

```lua
my_joker = {
    id = "my_joker",
    name = "My Joker",
    description = "+10 damage to Fire spells",
    rarity = "Common",
    calculate = function(self, context)
        if context.event == "on_spell_cast" then
            if context.tags and context.tags.Fire then
                return { damage_mod = 10, message = "My Joker!" }
            end
        end
    end
}
```

## Field Reference

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier (must match table key) |
| `name` | string | Display name |
| `description` | string | Player-facing description |
| `rarity` | string | `"Common"`, `"Uncommon"`, `"Rare"`, `"Epic"`, `"Legendary"` |
| `calculate` | function | Callback that receives context and returns effects |

### Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `sprite` | string | Sprite/animation ID for visuals |
| `cost` | number | Shop price (if purchasable) |
| `unlock_condition` | table | Requirements to appear in shop |

## The Calculate Function

```lua
calculate = function(self, context)
    -- self = this joker definition
    -- context = event data (varies by event type)
    -- return = effect table or nil
end
```

### Event Types

> **Implementation Note**: Only `on_spell_cast` is currently triggered in production code. Other events (`calculate_damage`, `on_wave_start`, `on_kill`) are documented for future use - you can add them by calling `JokerSystem.trigger_event()` where appropriate.

#### `on_spell_cast` ✅ Implemented
Triggers when a spell is cast. Location: `wand/wand_executor.lua:654-662`

```lua
context = {
    event = "on_spell_cast",           -- auto-set by joker_system.lua

    -- Spell classification
    spell_type = "Mono-Element",       -- "Simple Cast", "Twin Cast", "Scatter Cast",
                                       -- "Precision Cast", "Rapid Fire", "Mono-Element",
                                       -- "Combo Chain", "Heavy Barrage", "Chaos Cast"

    -- Tags in this cast (hash table for fast lookup)
    tags = { Fire = true, Projectile = true, AoE = true },

    -- Detailed tag analysis (from spell_type_evaluator.lua)
    tag_analysis = {
        tag_counts = { Fire = 3, Ice = 2 },  -- tag name -> occurrence count
        primary_tag = "Fire",                 -- most frequent tag
        primary_count = 3,                    -- count of primary tag
        diversity = 2,                        -- number of distinct tag types
        total_tags = 5,                       -- total tag instances
        is_tag_heavy = true,                  -- primary_count >= 3
        is_mono_tag = false,                  -- diversity == 1
        is_diverse = false,                   -- diversity >= 3
        is_multi_tag = false,                 -- single action with 2+ tags
    },

    -- Player reference
    player = playerScript,             -- player entity or script table

    -- Wand info
    wand_id = "wand_1",                -- ID of the casting wand
}
```

#### `calculate_damage` ⚠️ NOT YET TRIGGERED
Defined in jokers but requires integration. Add trigger in damage calculation:

```lua
-- To implement: call this in your damage pipeline
local effects = JokerSystem.trigger_event("calculate_damage", {
    base_damage = 25,
    damage_type = "fire",
    tags = { Fire = true },
    player = {
        tag_counts = { Fire = 8, Projectile = 12 },
    },
})
```

#### `on_wave_start` ⚠️ NOT YET TRIGGERED
Add trigger in wave manager:

```lua
-- To implement: call this when wave starts
local effects = JokerSystem.trigger_event("on_wave_start", {
    wave_number = 3,
    enemy_count = 10,
})
```

#### `on_kill` ⚠️ NOT YET TRIGGERED
Add trigger in enemy death handler:

```lua
-- To implement: call this on enemy death
local effects = JokerSystem.trigger_event("on_kill", {
    enemy_type = "basic",
    damage_type = "fire",
    was_crit = true,
})
```

### Return Values

Return a table with any of these effects:

| Field | Type | Description |
|-------|------|-------------|
| `damage_mod` | number | Flat damage added |
| `damage_mult` | number | Damage multiplier (1.0 = no change, 1.5 = +50%) |
| `repeat_cast` | number | Cast the spell N additional times |
| `mana_restore` | number | Mana returned to player |
| `heal` | number | HP restored to player |
| `message` | string | Popup text shown when triggered |

Return `nil` if the joker doesn't trigger.

## Templates

### Tag-Based Damage Boost
```lua
fire_affinity = {
    id = "fire_affinity",
    name = "Fire Affinity",
    description = "+15 damage to Fire spells",
    rarity = "Common",
    calculate = function(self, context)
        if context.event == "on_spell_cast" then
            if context.tags and context.tags.Fire then
                return { damage_mod = 15, message = "Fire Affinity!" }
            end
        end
    end
}
```

### Spell Type Synergy
```lua
twin_soul = {
    id = "twin_soul",
    name = "Twin Soul",
    description = "Twin Casts deal +25% damage",
    rarity = "Uncommon",
    calculate = function(self, context)
        if context.event == "on_spell_cast" then
            if context.spell_type == "Twin Cast" then
                return { damage_mult = 1.25, message = "Twin Soul!" }
            end
        end
    end
}
```

### Scaling with Tag Counts
```lua
elemental_mastery = {
    id = "elemental_mastery",
    name = "Elemental Mastery",
    description = "+2% damage per elemental tag in deck",
    rarity = "Rare",
    calculate = function(self, context)
        if context.event == "calculate_damage" then
            local elem_count = 0
            if context.player and context.player.tag_counts then
                elem_count = (context.player.tag_counts.Fire or 0)
                           + (context.player.tag_counts.Ice or 0)
                           + (context.player.tag_counts.Lightning or 0)
            end
            if elem_count > 0 then
                local bonus = elem_count * 0.02
                return {
                    damage_mult = 1 + bonus,
                    message = string.format("Elemental! +%d%%", bonus * 100)
                }
            end
        end
    end
}
```

### Tag Density Bonus
```lua
focused_caster = {
    id = "focused_caster",
    name = "Focused Caster",
    description = "+30% damage if 3+ actions share the same tag",
    rarity = "Uncommon",
    calculate = function(self, context)
        if context.event == "on_spell_cast" then
            if context.tag_analysis and context.tag_analysis.is_tag_heavy then
                return { damage_mult = 1.3, message = "Focused!" }
            end
        end
    end
}
```

### Diversity Bonus
```lua
jack_of_all = {
    id = "jack_of_all",
    name = "Jack of All Trades",
    description = "+8% damage per distinct tag type in cast",
    rarity = "Rare",
    calculate = function(self, context)
        if context.event == "on_spell_cast" then
            if context.tag_analysis and context.tag_analysis.diversity > 1 then
                local bonus = context.tag_analysis.diversity * 0.08
                return {
                    damage_mult = 1 + bonus,
                    message = string.format("Variety! +%d%%", bonus * 100)
                }
            end
        end
    end
}
```

### Repeat Cast
```lua
echo_mage = {
    id = "echo_mage",
    name = "Echo Mage",
    description = "AoE spells cast twice",
    rarity = "Epic",
    calculate = function(self, context)
        if context.event == "on_spell_cast" then
            if context.tags and context.tags.AoE then
                return { repeat_cast = 1, message = "Echo!" }
            end
        end
    end
}
```

### On-Kill Effect
```lua
soul_harvest = {
    id = "soul_harvest",
    name = "Soul Harvest",
    description = "Restore 5 mana on kill",
    rarity = "Uncommon",
    calculate = function(self, context)
        if context.event == "on_kill" then
            return { mana_restore = 5, message = "Soul Harvest!" }
        end
    end
}
```

## Testing

1. **Validate syntax:**
   ```lua
   dofile("assets/scripts/tools/content_validator.lua")
   ```

2. **Test in game:**
   - Open Content Debug Panel → Joker Tester tab
   - Click [Add] next to your joker
   - Click [Test Event] to trigger `on_spell_cast`
   - Check "Last result" shows your effect

3. **Test with actual spells:**
   - Add joker via Joker Tester
   - Spawn a card with matching tags
   - Cast the spell
   - Verify damage/effect is modified

## Common Mistakes

1. **Missing return** - Always return a table or nil
   ```lua
   -- WRONG (no return)
   calculate = function(self, context)
       if context.tags.Fire then
           -- forgot return!
           { damage_mod = 10 }
       end
   end

   -- RIGHT
   calculate = function(self, context)
       if context.tags and context.tags.Fire then
           return { damage_mod = 10 }
       end
   end
   ```

2. **Not checking for nil** - Context fields may be missing
   ```lua
   -- WRONG (crashes if tags is nil)
   if context.tags.Fire then

   -- RIGHT
   if context.tags and context.tags.Fire then
   ```

3. **Wrong event name** - Event names are case-sensitive
   ```lua
   -- WRONG
   if context.event == "OnSpellCast" then

   -- RIGHT
   if context.event == "on_spell_cast" then
   ```

4. **Multiplier math** - 1.0 = no change, not 0
   ```lua
   -- WRONG (removes all damage)
   return { damage_mult = 0.25 }

   -- RIGHT (+25% damage)
   return { damage_mult = 1.25 }
   ```

5. **ID mismatch** - Table key must match `id` field
   ```lua
   -- WRONG
   my_joker = { id = "myjoker", ... }

   -- RIGHT
   my_joker = { id = "my_joker", ... }
   ```

## Extending the System

### Adding New Event Types

Event names are just strings. To add a new event:

1. **Call the event in your game code:**
   ```lua
   local JokerSystem = require("wand.joker_system")

   -- In your dodge mechanic:
   local effects = JokerSystem.trigger_event("on_dodge", {
       player = player,
       incoming_damage = 50,
       dodge_type = "roll",
   })

   -- Handle any effects jokers return
   if effects.heal then player.hp = player.hp + effects.heal end
   ```

2. **React to it in a joker:**
   ```lua
   nimble = {
       id = "nimble",
       name = "Nimble",
       description = "Heal 5 HP when dodging",
       rarity = "Uncommon",
       calculate = function(self, context)
           if context.event == "on_dodge" then
               return { heal = 5, message = "Nimble!" }
           end
       end
   }
   ```

No core system changes needed - just emit the event and jokers can react.

### Adding New Effect Types

Effect return values are aggregated by the system. Default aggregation:
- `damage_mod`: summed
- `damage_mult`: multiplied
- `repeat_cast`: summed
- `messages`: collected into array

To add a new effect type:

1. **Return it from your joker:**
   ```lua
   return { my_custom_effect = 10 }
   ```

2. **Handle it where you call `trigger_event`:**
   ```lua
   local effects = JokerSystem.trigger_event("on_spell_cast", context)

   -- Handle built-in effects
   local damage = base_damage + effects.damage_mod
   damage = damage * effects.damage_mult

   -- Handle your custom effect
   if effects.my_custom_effect then
       -- Do something with it
   end
   ```

3. **Optionally, update aggregation** in `joker_system.lua`:
   ```lua
   -- In trigger_event():
   if result.my_custom_effect then
       aggregate.my_custom_effect = (aggregate.my_custom_effect or 0) + result.my_custom_effect
   end
   ```

### Adding New Tags

Tags are just strings on cards. To add a new tag:

1. Add it to cards in `data/cards.lua`:
   ```lua
   my_card = {
       tags = { "MyNewTag", "Projectile" },
   }
   ```

2. React to it in jokers:
   ```lua
   if context.tags and context.tags.MyNewTag then
       return { damage_mult = 1.5 }
   end
   ```

The validator will warn about unknown tags, but they work. Add common tags to the validator's known list to suppress warnings.

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
