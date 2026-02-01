# bd-2qf.22: [Descent] D3 Stairs + floor transitions 1->5

## Implementation Summary

### File Created

**`assets/scripts/descent/floor_transition.lua`** (8 KB)

#### Features
- **Stair Usage**: Validates player on correct stairs before transition
- **State Persistence**: HP/MP/XP/inventory/equipment/god/spells persist
- **Floor Cache**: Backtracking support per spec.backtracking
- **Boss Hook**: Floor 5 triggers on_boss_floor callback
- **Explored State**: Saves/restores explored tiles per spec

### Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Stair advances floor once per turn | OK returns spec.turn_cost.stairs |
| Player state persists | OK PERSISTENT_FIELDS list |
| Floor-local state resets | OK clears enemies/items/explored |
| Floor 5 triggers boss hook | OK on_boss_floor callback |

### Key Functions

- `Transition.use_stairs(game_state, direction)` - Main transition
- `Transition.can_use_stairs(game_state, direction)` - Validation
- `Transition.on_floor_change(callback)` - Event hook
- `Transition.on_boss_floor(callback)` - Boss floor hook

### Persistent Fields

```lua
PERSISTENT_FIELDS = {
    "hp", "hp_max", "mp", "mp_max",
    "xp", "level", "str", "dex", "int",
    "inventory", "equipment",
    "god", "piety", "spells",
    -- ...
}
```

### Floor Transition Flow

1. Validate player on correct stairs
2. Save current floor state (if backtracking enabled)
3. Extract persistent player state
4. Generate or load new floor from cache
5. Position player at appropriate stairs
6. Restore persistent player state
7. Trigger callbacks (on_floor_change, on_boss_floor)

## Agent

- **Agent**: FuchsiaFalcon
- **Date**: 2026-02-01
