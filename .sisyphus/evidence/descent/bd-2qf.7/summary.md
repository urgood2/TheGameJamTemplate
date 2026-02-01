# bd-2qf.7: [Descent] C1 Turn manager FSM

## Implementation Summary

### File Created

**`assets/scripts/descent/turn_manager.lua`**

### FSM States

| Phase | Description |
|-------|-------------|
| `IDLE` | Not active (paused or uninitialized) |
| `PLAYER_TURN` | Waiting for valid player input |
| `ENEMY_TURN` | Processing enemies in deterministic order |
| `ANIMATION` | Reserved for animation wait (optional) |

### Turn Cycle

```
PLAYER_TURN -> (valid action) -> ENEMY_TURN -> (all enemies processed) -> PLAYER_TURN
```

### Key Invariants

| Invariant | Implementation |
|-----------|----------------|
| Invalid input = 0 turns | `validate_action()` returns early without state change |
| No-op input = 0 turns | Move(0,0) rejected as invalid |
| dt-independent | `update()` returns false when no pending action |
| Deterministic enemy order | `get_sorted_enemies()` returns stable-sorted list |

### API

```lua
TurnManager.init()              -- Initialize
TurnManager.submit_action(a)    -- Submit player action (validates first)
TurnManager.update()            -- Process one step (call every frame)
TurnManager.get_phase()         -- Get current phase
TurnManager.get_turn_count()    -- Get turn number
TurnManager.is_player_turn()    -- Check if player turn
TurnManager.on(event, cb)       -- Register callback
```

### Callbacks

- `on_phase_change(new, old)` - Phase transition
- `on_turn_start(turn)` - New turn started
- `on_turn_end(turn)` - Turn completed
- `on_player_action(action)` - Player acted
- `on_enemy_action(enemy, action)` - Enemy acted

### Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Create `turn_manager.lua` | ✅ Created |
| PLAYER_TURN -> ENEMY_TURN -> PLAYER_TURN | ✅ Implemented |
| Invalid/no-op = 0 turns | ✅ validate_action() guards |
| dt-independent | ✅ update() returns false without input |

### Agent

- **Agent**: FuchsiaFalcon
- **Date**: 2026-02-01
