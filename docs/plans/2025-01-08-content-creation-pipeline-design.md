# Content Creation Pipeline Design

**Date:** 2025-01-08
**Status:** Approved
**Goal:** Set up frictionless content creation for cards, jokers, projectiles, and avatars

## Context

The game has a strong foundation:
- 60+ cards in `data/cards.lua`
- 8 jokers in `data/jokers.lua`
- 6 avatars in `data/avatars.lua`
- 4 disciplines, 4 origins
- Existing Card Spawner ImGui panel
- Test harnesses for most systems

But content creation has friction:
- Cards lack `tags` field (breaks joker synergies)
- `projectiles.lua` is empty (no reusable presets)
- No validation (typos cause silent failures)
- No content creation documentation
- Missing ImGui panels for jokers, projectiles, tags

## Deliverables

### Documentation (5 files)

Location: `docs/content-creation/`

| File | Purpose | ~Lines |
|------|---------|--------|
| `CONTENT_OVERVIEW.md` | Index to all guides | 50 |
| `ADDING_CARDS.md` | Card fields + templates | 150 |
| `ADDING_JOKERS.md` | Event hooks + templates | 120 |
| `ADDING_PROJECTILES.md` | Movement/collision + templates | 130 |
| `ADDING_AVATARS.md` | Unlock conditions + templates | 100 |

Each guide follows this format:
1. Quick Start - Minimal copy-paste example
2. Field Reference - Table of all fields
3. Templates - Code blocks for common patterns
4. Testing - How to verify it works
5. Common Mistakes - Gotchas to avoid

### Code Changes (4 files)

#### 1. Add tags to cards (`data/cards.lua`)

Add `tags` field to all 60+ cards:

```lua
Cards.ACTION_EXPLOSIVE_FIRE_PROJECTILE = {
    id = "ACTION_EXPLOSIVE_FIRE_PROJECTILE",
    type = "action",
    damage_type = "fire",
    tags = { "Fire", "Projectile", "AoE" },  -- NEW
    -- ... rest unchanged
}
```

Standard tag vocabulary:
- **Elements:** `Fire`, `Ice`, `Lightning`, `Poison`, `Arcane`, `Holy`, `Void`
- **Mechanics:** `Projectile`, `AoE`, `Hazard`, `Summon`, `Buff`, `Debuff`
- **Playstyle:** `Mobility`, `Defense`, `Brute`

#### 2. Populate projectile presets (`data/projectiles.lua`)

12 presets covering:
- Basic (1): `basic_bolt`
- Elemental (3): `fireball`, `ice_shard`, `lightning_bolt`
- Behaviors (4): `homing_missile`, `bouncing_ball`, `gravity_bomb`, `piercing_arrow`
- Special (4): `orbital_orb`, `poison_cloud`, `void_rift`, `holy_beam`

```lua
fireball = {
    id = "fireball",
    speed = 400,
    damage_type = "fire",
    movement = "straight",
    collision = "explode",
    explosion_radius = 60,
    lifetime = 2000,
    tags = { "Fire", "Projectile", "AoE" },
}
```

#### 3. Content validator (`tools/content_validator.lua`)

Two modes:
- **Standalone:** Run with `dofile()`, outputs full report
- **Runtime:** Called on init, prints warnings only

Validates:
| Content Type | Checks |
|--------------|--------|
| Cards | Required fields, valid type enum, tags is table, known tag names |
| Jokers | Required fields, calculate is function, valid rarity |
| Projectiles | Required fields, valid movement/collision enums |
| Avatars | Required fields, unlock has conditions |

#### 4. Unified ImGui debug panel (`ui/content_debug_panel.lua`)

Single window with 3 tabs:

**Tab 1: Joker Tester**
- List active jokers with remove button
- List available jokers with add button
- Trigger test event button
- Show last calculation result

**Tab 2: Projectile Spawner**
- Dropdown to select preset
- Sliders to override parameters
- Spawn buttons (at cursor, at player)
- Shows last spawned entity ID

**Tab 3: Tag Inspector**
- Bar chart of tag counts
- Threshold indicators (3/5/7/9)
- Active synergy bonuses
- Last spell type analysis

### Integration (2 files)

| File | Change |
|------|--------|
| `gameplay.lua` | Call validator on init, render debug panel |
| `CLAUDE.md` | Add content creation quick-reference section |

## Implementation Order

1. Documentation (can be done independently)
2. Add tags to `cards.lua`
3. Populate `projectiles.lua`
4. Create `content_validator.lua`
5. Create `content_debug_panel.lua`
6. Integration into `gameplay.lua`
7. Update `CLAUDE.md`

## Success Criteria

- [ ] Can add a new card by copying template, filling fields, reloading
- [ ] Can add a new joker by copying template, filling fields, reloading
- [ ] Validator catches missing fields and typos
- [ ] ImGui panel shows active jokers and tag counts
- [ ] ImGui panel can spawn test projectiles
