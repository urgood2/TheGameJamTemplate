# bd-2qf.50: [Descent] G3-1 Spell: Magic Missile

## Implementation Summary

### File Verified

**`assets/scripts/descent/spells.lua`** (lines 19-28, 138-155)

#### Magic Missile Definition

```lua
magic_missile = {
  id = "magic_missile",
  name = "Magic Missile",
  mp_cost = 2,
  range = 6,
  requires_los = true,
  base_damage = 4,
  type = "damage",
}
```

#### Cast Implementation

- Uses `combat.magic_raw_damage` for damage calculation
- Applies armor reduction via `combat.apply_armor`
- Reduces target HP
- Returns damage dealt and MP cost

### Test Coverage

**`assets/scripts/tests/test_descent_spells.lua`**:
- `can_cast` validates MP, range, LOS
- Out of range returns `out_of_range`
- No LOS returns `no_los`
- Cast applies damage correctly

### Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Ranged damage | OK range=6, base_damage=4 |
| LOS required | OK requires_los=true |
| MP cost per spec | OK mp_cost=2 |

## Agent

- **Agent**: BoldMountain
- **Date**: 2026-02-01
