# bd-2qf.35: [Descent] F1-T Player leveling tests

## Implementation Summary

### File Verified

**`assets/scripts/tests/test_descent_player.lua`** (1.6 KB)

#### Test Coverage

1. **XP thresholds** - uses spec.stats.xp.base with species modifier
2. **HP/MP recalculation** - level up triggers stat recalc
3. **Event emission** - level-up and spell selection events fire

### Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| XP thresholds tested | OK spec.stats.xp.base |
| Level-up stats tested | OK HP/MP recalculated |
| Event emission tested | OK on_level_up, on_spell_select |

## Agent

- **Agent**: BoldMountain
- **Date**: 2026-02-01
