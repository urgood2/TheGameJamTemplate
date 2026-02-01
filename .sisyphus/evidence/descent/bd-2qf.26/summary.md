# bd-2qf.26: [Descent] E2 Enemy base + AI decision function

## Implementation Summary

### File Verified

**`assets/scripts/descent/enemy.lua`** (12 KB)

#### Features
- **AI Decision Priority**: 4-state decision tree per PLAN.md
- **Templates**: rat, goblin, orc, skeleton, troll predefined
- **Deterministic Order**: Sorted by instance_id in `process_all()`
- **Combat Integration**: Uses `combat.resolve_melee()`
- **Pathfinding Integration**: Uses `pathfinding.find_path()`
- **State Tracking**: last_seen_player, state machine

### Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Adjacent -> Attack | OK Lines 229-236 |
| Visible + path -> Move | OK Lines 247-255 |
| Visible + no path -> Idle | OK Lines 257-260 |
| Not visible -> Idle | OK Lines 263-265 |
| Deterministic processing order | OK `process_all()` sorts by instance_id |

### Key Functions

- `Enemy.create(template_id, x, y)` - Create enemy from template
- `Enemy.decide(e, game_state)` - AI decision (ATTACK/MOVE/IDLE)
- `Enemy.execute(e, decision, game_state)` - Execute decision
- `Enemy.process_all(enemies, game_state)` - Batch process in deterministic order

## Agent

- **Agent**: FuchsiaFalcon
- **Date**: 2026-02-01
