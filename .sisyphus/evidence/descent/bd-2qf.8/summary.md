# bd-2qf.8: [Descent] C1-T Turn manager tests

## Implementation Summary

### File Created

**`assets/scripts/tests/test_descent_turn_manager.lua`** (7.5 KB)

#### Test Suites

1. **Descent Turn Manager FSM** - 7 tests
   - Starts in player turn phase
   - Starts at turn 0
   - is_player_turn returns true initially
   - Transitions to enemy turn after valid action
   - Returns to player turn after enemy phase
   - advance_turns manually advances counter
   - pause and resume work correctly

2. **Descent Turn Manager Invalid Input** - 10 tests
   - Rejects nil action
   - Rejects action without type
   - Rejects move with zero delta
   - Rejects move without dx/dy
   - Rejects attack without target
   - Rejects use_item without item_id
   - Rejects drop without item_id
   - Rejects unknown action type
   - Rejects action during enemy turn
   - Invalid action doesn't change turn count

3. **Descent Turn Manager DT Independence** - 4 tests
   - update returns false when no pending action
   - Multiple updates without input don't advance turns
   - Turn advances only on valid action submission
   - update returns false when not initialized

4. **Descent Turn Manager Callbacks** - 5 tests
   - on_turn_start fires on init
   - on_phase_change fires during transitions
   - on_player_action fires when action executed
   - on_turn_end and on_turn_start fire on turn completion
   - off removes callback

5. **Descent Turn Manager State** - 3 tests
   - get_state returns correct snapshot
   - get_state reflects pending action
   - reset clears all state

### Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| FSM transitions tested | OK 7 tests |
| Invalid input handling tested | OK 10 tests |
| dt independence tested | OK 4 tests |
| Edge cases covered | OK callbacks, state |

## Agent

- **Agent**: BoldMountain
- **Date**: 2026-02-01
