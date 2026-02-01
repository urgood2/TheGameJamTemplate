# bd-2qf.65: [Descent] S4 Integration test: full run seed 42

## Implementation Summary

### File Created

**`assets/scripts/tests/descent/test_integration.lua`** (8 KB)

#### Test Categories
- **Core Determinism**: seed 42 map, enemy spawns, player start, combat
- **All Floors**: determinism across floors 1-5
- **Different Seeds**: different seeds produce different results
- **Edge Cases**: seed 0, large seeds, sequential seeds
- **Consistency**: state unchanged after operations

### Test List

| Test | Description |
|------|-------------|
| seed_42_map_deterministic | Same seed produces same map hash |
| seed_42_enemy_spawn_deterministic | Same seed spawns enemies at same positions |
| seed_42_player_start_deterministic | Same seed places player at same position |
| seed_42_combat_deterministic | Same seed produces same combat rolls |
| seed_42_full_state_deterministic | Full state hash matches for same seed |
| all_floors_deterministic | All floors (1-5) deterministic |
| different_seeds_different_maps | Different seeds produce different maps |
| different_seeds_different_combat | Different seeds produce different combat |
| seed_0_works | Edge case: seed 0 works |
| large_seed_works | Edge case: max int seed works |
| sequential_seeds_different | Seeds 1-10 all produce unique hashes |
| consistency_after_combat | Map hash unchanged after combat |
| multi_floor_consistency | Regeneration produces same hashes |

### Usage

```lua
local tests = require("tests.descent.test_integration")
tests.run_all()
```

### Acceptance Criteria

Same seed = identical game verified by:
- Map hash matching
- Enemy position matching
- Player start matching
- Combat roll matching
- Full state hash matching

## Agent

- **Agent**: FuchsiaFalcon
- **Date**: 2026-02-01
