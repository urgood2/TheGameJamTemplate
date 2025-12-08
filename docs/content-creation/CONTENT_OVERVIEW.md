# Content Creation Overview

Quick index for adding new content to the game.

## What Do You Want to Add?

| Content Type | Guide | Data File |
|--------------|-------|-----------|
| Card (action/modifier/trigger) | [ADDING_CARDS.md](ADDING_CARDS.md) | `assets/scripts/data/cards.lua` |
| Joker (passive artifact) | [ADDING_JOKERS.md](ADDING_JOKERS.md) | `assets/scripts/data/jokers.lua` |
| Projectile preset | [ADDING_PROJECTILES.md](ADDING_PROJECTILES.md) | `assets/scripts/data/projectiles.lua` |
| Avatar (ascension) | [ADDING_AVATARS.md](ADDING_AVATARS.md) | `assets/scripts/data/avatars.lua` |

## Quick Start (30 seconds)

### Add a Card
```lua
-- In data/cards.lua, copy an existing card and modify:
Cards.MY_NEW_CARD = {
    id = "MY_NEW_CARD",
    type = "action",        -- "action", "modifier", or "trigger"
    mana_cost = 10,
    damage = 20,
    tags = { "Fire", "Projectile" },
    test_label = "MY\nnew\ncard",
}
```

### Add a Joker
```lua
-- In data/jokers.lua, copy an existing joker and modify:
my_joker = {
    id = "my_joker",
    name = "My Joker",
    description = "+10 damage to Fire spells",
    rarity = "Common",
    calculate = function(self, context)
        if context.event == "on_spell_cast" and context.tags and context.tags.Fire then
            return { damage_mod = 10, message = "My Joker!" }
        end
    end
}
```

### Add a Projectile
```lua
-- In data/projectiles.lua:
my_projectile = {
    id = "my_projectile",
    speed = 500,
    damage_type = "fire",
    movement = "straight",
    collision = "explode",
    explosion_radius = 60,
    tags = { "Fire", "Projectile" },
}
```

## ID Naming Conventions

Different content types use different naming conventions for IDs and table keys:

| Content Type | ID Convention | Example |
|--------------|---------------|---------|
| Cards | SCREAMING_SNAKE_CASE | `Cards.FIREBALL`, `id = "FIREBALL"` |
| Jokers | snake_case | `pyromaniac = { id = "pyromaniac" }` |
| Projectiles | snake_case | `basic_bolt = { id = "basic_bolt" }` |
| Avatars | snake_case | `fire_mage = { name = "Fire Mage" }` |

**Important:** The table key should match the `id` field (or `name` for avatars) to avoid validation warnings.

## Testing Your Content

### Validation
```lua
-- Run the content validator to check for errors:
dofile("assets/scripts/tools/content_validator.lua")
```

### ImGui Debug Panel
The Content Debug Panel (in-game) has tabs for:
- **Joker Tester** - Add/remove jokers, trigger test events
- **Projectile Spawner** - Spawn projectiles with parameter tweaking
- **Tag Inspector** - View tag counts and active bonuses

## Standard Tags

Use these tags for joker synergies:

**Elements:** `Fire`, `Ice`, `Lightning`, `Poison`, `Arcane`, `Holy`, `Void`

**Mechanics:** `Projectile`, `AoE`, `Hazard`, `Summon`, `Buff`, `Debuff`

**Playstyle:** `Mobility`, `Defense`, `Brute`

## Related Systems

| System | Data File | Description |
|--------|-----------|-------------|
| Disciplines | `data/disciplines.lua` | Card pool restrictions per run |
| Origins | `data/origins.lua` | Starting passives + prayer |
| Wand Frames | `data/wand_frames.lua` | Cast block size, cooldowns, triggers |
| Prayers | `data/prayers.lua` | Active abilities |
