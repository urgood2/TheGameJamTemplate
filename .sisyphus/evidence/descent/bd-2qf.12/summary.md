# bd-2qf.12: [Descent] C3-T Input and movement tests

## Implementation Summary

### File Created

**`assets/scripts/tests/test_descent_input.lua`** (8.5 KB)

#### Test Suites

1. **Descent Input** - 8 tests
   - Direction key mapping
   - Nil on no keys
   - Key repeat prevention
   - Reset on new turn
   - Just pressed vs held detection
   - Wait key mapping
   - Pickup key mapping
   - Stairs key mapping

2. **Descent Player Actions** - 6 tests
   - Legal move consumes 1 turn
   - Illegal move consumes 0 turns
   - Zero delta is invalid
   - Wait consumes 1 turn
   - can_move returns correct status
   - get_action_at returns action type

3. **Descent Bump Attack** - 5 tests
   - Bump attack consumes 1 turn
   - Damage dealt to enemy
   - Killed enemy marked dead
   - get_action_at returns attack
   - can_move returns bump_attack reason

4. **Descent Key Repeat Policy** - 3 tests
   - Held key only triggers once
   - Different keys can trigger
   - No action when consumed this turn

### Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Legal move consumes 1 turn | OK tested |
| Illegal move consumes 0 turns | OK tested |
| Bump attack consumes 1 turn | OK tested |
| Key repeat policy enforced | OK tested |

### Key Test Patterns

```lua
-- Legal move test
local result = ActionsPlayer.execute({ type = "move", dx = 1, dy = 0 }, game_state)
t.expect(result.turns).to_be(1)

-- Illegal move test (wall)
local result = ActionsPlayer.execute({ type = "move", dx = 1, dy = 0 }, game_state)
t.expect(result.turns).to_be(0)

-- Key repeat test
Input.consume_action()
local action = Input.poll({ w = true })
t.expect(action).to_be(nil)
```

## Agent

- **Agent**: BoldMountain
- **Date**: 2026-02-01
