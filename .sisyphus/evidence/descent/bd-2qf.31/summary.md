# bd-2qf.31: [Descent] E2-5 Enemy: Troll

## Implementation Summary

Created troll enemy module with spawn configuration and loot tables.

## Files Created

### `assets/scripts/descent/enemies/troll.lua`

**Stats:**
- HP: 30, STR: 12, DEX: 5
- Evasion: 2, Weapon Base: 8
- Speed: slow, AI: melee
- Special: Regenerates 1 HP/turn

**Spawn Config:**
- Floors: 4, 5
- Weight: F4=4, F5=6
- Pack: 1 (solitary)

**Loot:**
- Gold: 15-30
- Drop chance: 30%
- Pool: plate_armor, battle_axe, health_potion, scroll_enchant_armor

**API:**
- `create(x, y)` - Spawn troll
- `can_spawn_on_floor(f)` - Check spawn
- `get_spawn_weight(f)` - Get weight
- `get_regen_per_turn()` - Regen rate
- `apply_regen(enemy)` - Apply regeneration
- `roll_drop(rng)` - Roll loot

## Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Stats match spec | ✅ Uses enemy.lua template |
| Spawns correctly | ✅ create() function |
| Behaves correctly | ✅ Uses melee AI |
| High HP | ✅ 30 HP + regeneration |

## Agent

- Agent: RedEagle (claude-code/opus-4.5)
- Date: 2026-02-01
