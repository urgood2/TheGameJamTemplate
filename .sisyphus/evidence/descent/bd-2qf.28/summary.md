# bd-2qf.28: [Descent] E2-2 Enemy: Skeleton

## Implementation Summary

Created skeleton enemy module with spawn configuration and loot tables.

## Files Created

### `assets/scripts/descent/enemies/skeleton.lua`

**Stats:**
- HP: 12, STR: 6, DEX: 8
- Evasion: 5, Weapon Base: 4
- Speed: normal, AI: melee

**Spawn Config:**
- Floors: 2, 3, 4
- Weight: F2=8, F3=10, F4=5
- Pack: 1-2 skeletons

**Loot:**
- Gold: 5-12
- Drop chance: 15%
- Pool: short_sword, health_potion, scroll_identify

**API:**
- `create(x, y)` - Spawn skeleton
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
