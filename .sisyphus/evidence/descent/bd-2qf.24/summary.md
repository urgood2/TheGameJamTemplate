# bd-2qf.24: [Descent] E1 Combat math (spec-locked)

## Implementation Summary

Created spec-locked combat math module for Descent roguelike mode.

## Files Created

### `assets/scripts/descent/combat.lua`

**Hit Chance (from spec):**
- Melee: base(70) + dex*2 - evasion*2, clamp [5, 95]
- Magic: base(80) + skill*3, clamp [5, 95]

**Damage (from spec):**
- Melee: weapon_base + str_modifier + species_bonus, floor
- Magic: spell_base * (1 + int * 0.05) * species_mult, floor
- Armor: max(0, floor(raw - armor_value))
- Evasion: 10 + (dex * 2) + dodge_skill

**Validation:**
- Negative stats rejected with entity id/type in error
- Missing required stats (hp, max_hp) cause error
- Nil entities cause error with context

**Combat Functions:**
- `melee_attack(attacker, defender)` - Full melee combat
- `magic_attack(caster, target, spell)` - Full magic combat
- `calc_melee_hit_chance(attacker, defender)` - Hit chance only
- `calc_melee_damage(attacker)` - Raw damage only
- `apply_armor(damage, defender)` - Armor reduction
- `heal(entity, amount)` - Apply healing
- `is_dead(entity)` - Check HP <= 0

**Results:**
- RESULT.HIT, RESULT.MISS, RESULT.KILL, RESULT.ERROR
- Includes hit_roll, hit_chance, damage, raw_damage, hp_after

## Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Hit chance clamp per spec | ✅ [5, 95] for both melee/magic |
| Damage floors at 0 after armor | ✅ max(0, floor(raw - armor)) |
| Scripted RNG deterministic | ✅ Uses descent.rng module |
| Negative stats rejected | ✅ Error with entity id/type |

## Agent

- Agent: RedEagle (claude-code/opus-4.5)
- Date: 2026-02-01
