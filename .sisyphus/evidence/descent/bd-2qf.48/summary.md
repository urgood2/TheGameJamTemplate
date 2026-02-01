# bd-2qf.48: [Descent] G3 Spells + targeting + MP usage

## Implementation Summary

### File Created

**`assets/scripts/descent/spells.lua`** (14 KB)

#### Features
- **Spell Definitions**: magic_missile, heal, blink, fireball, lightning
- **Cast Validation**: MP, LOS, range, god restrictions
- **Deterministic Damage/Heal**: Uses math.floor, integrates with rng
- **Level-up Selection**: get_available_for_level, get_random_selection
- **Targeting Types**: self, enemy, tile

### Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Spell selection on level-up | OK get_available_for_level() |
| Casts validate MP | OK checks player.mp >= spell.mp_cost |
| Casts validate LOS | OK has_los() with Bresenham fallback |
| Casts validate range | OK in_range() with Chebyshev distance |
| Damage/heal deterministic | OK uses math.floor and rng module |

### Key Functions

- `Spells.can_cast(player, spell_id, target, map)` - Validate all requirements
- `Spells.cast(player, spell_id, target, map, game_state)` - Execute spell
- `Spells.get_available_for_level(level, known)` - Level-up spell pool
- `Spells.get_random_selection(level, known, count)` - Random selection

### Validation Flow

```lua
-- 1. Check player knows spell
-- 2. Check god restrictions (Trog blocks)
-- 3. Check MP >= cost
-- 4. Check range (Chebyshev distance)
-- 5. Check LOS (Bresenham)
-- 6. Check targeting requirements (walkable, empty for blink)
```

### Spell Templates

| Spell | MP | Range | Targeting | Level |
|-------|-----|-------|-----------|-------|
| magic_missile | 3 | 6 | enemy | 1 |
| heal | 5 | 0 | self | 1 |
| blink | 4 | 5 | tile | 2 |
| fireball | 8 | 6 | tile (AoE) | 3 |
| lightning | 6 | 8 | enemy (chain) | 3 |

## Agent

- **Agent**: FuchsiaFalcon
- **Date**: 2026-02-01
