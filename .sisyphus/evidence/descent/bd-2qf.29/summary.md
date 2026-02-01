# bd-2qf.29: [Descent] E2-3 Enemy: Orc

## Implementation Summary

Created orc enemy module with spawn configuration and loot tables.

## Files Created

### `assets/scripts/descent/enemies/orc.lua`

**Stats:**
- HP: 20, STR: 10, DEX: 6
- Evasion: 3, Weapon Base: 6
- Speed: slow, AI: melee

**Spawn Config:**
- Floors: 3, 4, 5
- Weight: F3=5, F4=10, F5=8
- Pack: 1-2 orcs

**Loot:**
- Gold: 10-20
- Drop chance: 20%
- Pool: battle_axe, leather_armor, health_potion

**API:**
- `create(x, y)` - Spawn orc
- `can_spawn_on_floor(f)` - Check spawn
- `get_spawn_weight(f)` - Get weight
- `get_pack_size()` - Pack range
- `generate_gold(rng)` - Roll gold
- `roll_drop(rng)` - Roll loot

## Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Stats match spec | ✅ Uses enemy.lua template |
| Spawns correctly | ✅ create() function |
| Behaves correctly | ✅ Uses melee AI |

## Agent

- Agent: RedEagle (claude-code/opus-4.5)
- Date: 2026-02-01
