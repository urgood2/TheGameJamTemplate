# bd-2qf.32: [Descent] E3 Enemy turn execution

## Implementation Summary

Created enemy turn execution module that processes AI decisions and handles movement/attack resolution.

## Files Created

### `assets/scripts/descent/actions_enemy.lua`

**Key Features:**
- Integrates with turn_manager.lua (called via `decide_action`)
- Uses enemy.lua decisions (attack/move/idle)
- Occupied tile tracking to prevent overlaps
- Deterministic processing via spawn order

**Occupied Tile Handling:**
- `rebuild_occupied_cache()` - Rebuilds at turn start
- `is_occupied(x, y, exclude?)` - Collision check
- `update_occupied_cache()` - Updates after move

**Action Execution:**
- `execute_move(enemy, decision)` - Validates and moves
- `execute_attack(enemy, decision)` - Uses combat module
- `execute_idle(enemy, decision)` - No-op with reason

**Public API:**
- `init(player, enemy, combat, map)` - Set dependencies
- `decide_action(enemy)` - Single enemy turn (for turn_manager)
- `process_all_enemies()` - Batch process in order
- `begin_enemy_phase()` / `end_enemy_phase()` - Phase hooks
- `get_all_sorted()` - Enemies in spawn order

**Result Types:**
- `SUCCESS` - Action executed
- `BLOCKED` - Move blocked (wall/enemy)
- `NO_TARGET` - No target available
- `IDLE` - No action taken

## Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| No moves into occupied tiles | ✅ is_occupied() check |
| No overlaps after enemy phase | ✅ end_enemy_phase() validation |
| Iteration order stable | ✅ enemy.get_all() spawn order |
| Pathfinding nil handled (idle) | ✅ Returns IDLE with reason |

## Usage

```lua
local actions = require("descent.actions_enemy")
actions.init(player, enemy_module, combat, map)

-- Single enemy (turn_manager calls this)
local result = actions.decide_action(enemy)
-- result = { result = "success", action = "move", from = {...}, to = {...} }

-- Batch processing
actions.begin_enemy_phase()
local results = actions.process_all_enemies()
local no_overlaps = actions.end_enemy_phase()
```

## Agent

- Agent: RedEagle (claude-code/opus-4.5)
- Date: 2026-02-01
