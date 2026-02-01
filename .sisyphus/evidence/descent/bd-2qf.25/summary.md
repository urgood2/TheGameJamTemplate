# bd-2qf.25: [Descent] E1-T Combat math tests

## Implementation Summary

### File Verified

**`assets/scripts/tests/test_descent_combat.lua`** (1.5 KB)

#### Test Coverage

1. **Clamps melee hit chance** - min 5%, max 95%
2. **Clamps magic hit chance** - with negative stat rejection
3. **Floors damage at zero after armor** - no negative damage
4. **Deterministic scripted RNG** - reproducible combat results
5. **Rejects negative stats with entity context** - error includes entity ID

### Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Clamp ranges tested | OK min/max hit chance |
| Damage floor tested | OK apply_armor returns 0 |
| Scripted RNG determinism tested | OK sequence-based |
| Negative stat rejection tested | OK with entity context |

### Key Tests

```lua
-- Clamp min
local chance = Combat.melee_hit_chance({ dex = 1 }, { evasion = 100 })
t.expect(chance).to_be(5)

-- Clamp max
chance = Combat.melee_hit_chance({ dex = 100 }, { evasion = 0 })
t.expect(chance).to_be(95)

-- Damage floor
local final = Combat.apply_armor(3, { armor = 10 })
t.expect(final).to_be(0)

-- Scripted RNG
local rng = Combat.scripted_rng({ 1, 100 })
local result = Combat.resolve_melee(attacker, defender, rng)
t.expect(result.hit).to_be(true)  -- Roll 1 <= 75
```

## Agent

- **Agent**: BoldMountain
- **Date**: 2026-02-01
