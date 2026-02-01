# bd-2qf.11: [Descent] C3 Input + player action selection

## Implementation Summary

### Files

**`assets/scripts/descent/input.lua`** (5.9 KB, created by FuchsiaFalcon)

#### Features
- Key bindings from spec.movement.bindings
- Key repeat prevention (1 action per player turn)
- Direction mappings (8-way movement)
- Action types: move, wait, pickup, stairs

**`assets/scripts/descent/actions_player.lua`** (13 KB)

#### Features
- Action execution with turn consumption
- Bump-attack when moving into enemy
- Map occupancy integration
- Combat resolution via combat.resolve_melee()

### Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Legal move consumes 1 turn | OK execute_move() returns turns=1 |
| Illegal move consumes 0 turns | OK returns turns=0 for blocked/invalid |
| Bump enemy creates melee action | OK execute_bump_attack() via get_enemy_at() |
| Key repeat: 1 action per player turn | OK input.is_action_consumed() check |

### Key Functions

**input.lua:**
- `Input.poll(keys_pressed)` - Convert key input to action intent
- `Input.on_turn_start(turn)` - Reset action consumed flag
- `Input.consume_action()` - Mark action consumed this turn

**actions_player.lua:**
- `M.execute(action, game_state)` - Execute any player action
- `M.can_move(dx, dy, game_state)` - Check if move is valid
- `M.get_action_at(dx, dy, game_state)` - Get action type at direction

### Turn Consumption Logic

```lua
-- Legal move/attack = 1 turn
return { result = M.RESULT.SUCCESS, action = "move", turns = 1 }

-- Illegal move = 0 turns  
return { result = M.RESULT.BLOCKED, reason = "unwalkable", turns = 0 }

-- Bump attack = 1 turn
return { result = M.RESULT.SUCCESS, action = "attack", turns = 1 }
```

### Key Repeat Prevention

```lua
-- In input.poll():
if _state.action_consumed_this_turn then
    return nil  -- No action until next turn
end

-- In actions_player.execute_*():
local inp = get_input()
if inp and inp.consume_action then
    inp.consume_action()
end
```

## Agent

- **Agent**: BoldMountain
- **Date**: 2026-02-01
