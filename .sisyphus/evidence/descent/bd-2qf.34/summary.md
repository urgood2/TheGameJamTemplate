# bd-2qf.34: [Descent] F1 Player stats + XP/leveling

## Implementation Summary

### File Created

**`assets/scripts/descent/player.lua`** (9.6 KB)

#### Features
- **Player Creation**: `create(opts)` with species/background support
- **XP System**: `add_xp()` with automatic level-up handling
- **XP Thresholds**: Pre-calculated, uses formula `sum(level * base_xp)`
- **Level-up**: Recalculates HP/MP max per spec, heals the difference
- **HP/MP Management**: `heal()`, `damage()`, `restore_mp()`, `spend_mp()`
- **Equipment Integration**: `update_equipment_stats(state, inventory)`
- **Spell System**: `add_spell()`, `knows_spell()`, max 3 spells
- **Event Hooks**: `on_level_up()`, `on_spell_select()`, `on_death()`

### Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| XP thresholds match spec | ✅ Uses `spec.stats.xp.base` |
| Level-up recalculations per spec | ✅ HP/MP use spec formulas |
| Emits spell selection event hook | ✅ `on_spell_select` callback |

### Spec Integration

From `spec.stats`:
- `starting_level = 1`
- `base_attributes = { str = 10, dex = 10, int = 10 }`
- `hp.base = 10`, `hp.level_multiplier = 0.15`
- `mp.base = 5`, `mp.level_multiplier = 0.10`
- `xp.base = 10`

### XP Threshold Calculation

```lua
-- Level N requires: sum from 2 to N of (level * base_xp)
-- Level 2: 20 XP (2 * 10)
-- Level 3: 50 XP (20 + 30)
-- Level 4: 90 XP (50 + 40)
```

### Event Hooks

```lua
player.on_level_up(function(state, new_level)
    -- Called on each level gained
end)

player.on_spell_select(function(state, level)
    -- Called when player can choose a spell (< max_spells)
end)
```

## Agent

- **Agent**: BoldMountain
- **Date**: 2026-02-01
