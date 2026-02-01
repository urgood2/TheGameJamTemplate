# Chain Lightning Implementation Design

**Date:** 2025-12-23
**Status:** Ready for Implementation

## Overview

Chain Lightning is an action card that fires a projectile which, on hit, instantly arcs lightning to nearby enemies dealing bonus damage.

## Core Mechanics

- **Primary projectile** travels normally (affected by homing, speed mods, etc.)
- **On hit**: Find up to N nearby enemies within range, draw lightning arcs, deal instant damage
- **Damage falloff**: Each chain deals `baseDamage × chainDamageMult` (default 50%)

## Card Definition

```lua
Cards.ACTION_CHAIN_LIGHTNING = {
    id = "ACTION_CHAIN_LIGHTNING",
    type = "action",
    mana_cost = 15,
    damage = 20,
    damage_type = "lightning",
    projectile_speed = 600,
    lifetime = 2000,
    cast_delay = 100,

    chain_count = 3,           -- max enemies to chain to
    chain_range = 150,         -- pixels to search for targets
    chain_damage_mult = 0.5,   -- 50% damage per chain

    tags = { "Lightning", "Projectile" },
    sprite = "action-chain-lightning.png",
}
```

## Modifier Interactions

| Modifier | Behavior |
|----------|----------|
| MOD_DAMAGE_UP | Applies to chain damage (via baseDamage) |
| MOD_HEAL_ON_HIT | Heals for each chain hit |
| MOD_FORCE_CRIT | Each chain crits (×2 damage) |
| MOD_BIG_SLOW | Increases chain range via sizeMultiplier |
| MOD_BLOOD_TO_DAMAGE | Already in damageBonus, applies to chains |
| MOD_HOMING | Primary projectile only |
| MOD_EXPLOSIVE | Primary hit only |
| MOD_TRIGGER_ON_HIT | Primary hit only |
| MOD_DOUBLE_CAST | Two primaries, each chains independently |

## Damage Integration

Uses `ActionAPI.damage(ctx, source, target, amount, "lightning")` for:
- Proper resistance/armor calculations
- Joker trigger support
- Death event emission
- Damage popups

## Visual Effects

- Jagged lightning arcs (6 segments, 10px jitter)
- Cyan/white color with fade over 0.15s
- Impact flash at each target

## Implementation Files

1. `assets/scripts/data/cards.lua` - Card definition
2. `assets/scripts/wand/wand_actions.lua` - Main implementation:
   - `findEnemiesInRange()` helper
   - `drawLightningArc()` visual
   - `WandActions.spawnChainLightning()` main function
   - Update `handleProjectileHit()` to detect chain cards

## Testing Checklist

- [ ] Primary projectile spawns and travels correctly
- [ ] Chain arcs appear on hit
- [ ] Chain damage applies to nearby enemies
- [ ] MOD_DAMAGE_UP increases chain damage
- [ ] MOD_HEAL_ON_HIT heals per chain
- [ ] MOD_FORCE_CRIT doubles chain damage
- [ ] MOD_BIG_SLOW increases chain range
- [ ] MOD_DOUBLE_CAST spawns two independent chains
- [ ] No chain to primary target (excluded)
- [ ] Chains respect max count limit

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
