# bd-2qf.69: [Descent] S8 Movement 4-way vs 8-way (spec decision)

## Implementation Summary

### File Created

**`assets/scripts/descent/movement.lua`** (6 KB)

#### Features Per Spec

| Spec Setting | Value | Implementation |
|--------------|-------|----------------|
| `movement.eight_way` | `true` | 8-directional enabled |
| `movement.diagonal.allow` | `true` | Diagonals allowed |
| `movement.diagonal.corner_cutting` | `"block_if_either_cardinal_blocked"` | Validated in `check_corner_cutting()` |

### Corner-Cutting Rules

For diagonal movement from (x, y) by (dx, dy):

```
Block if EITHER adjacent cardinal is blocked:
- Check (x + dx, y) - horizontal cardinal
- Check (x, y + dy) - vertical cardinal

Example: Moving NE from (5,5) to (6,4)
- Check (6,5) - must be walkable
- Check (5,4) - must be walkable
```

### API

| Function | Description |
|----------|-------------|
| `can_move(map, x, y, dx, dy)` | Returns (valid, reason) |
| `get_valid_moves(map, x, y)` | Returns array of valid {dx, dy} |
| `is_diagonal(dx, dy)` | Check if movement is diagonal |
| `get_move_cost(dx, dy)` | Get turn cost for movement |
| `get_direction_name(dx, dy)` | Get direction name string |

### Key Bindings (from spec.movement.bindings)

```lua
north = { "W", "Up", "Numpad8" }
south = { "S", "Down", "Numpad2" }
west = { "A", "Left", "Numpad4" }
east = { "D", "Right", "Numpad6" }
northwest = { "Q", "Numpad7" }
northeast = { "E", "Numpad9" }
southwest = { "Z", "Numpad1" }
southeast = { "C", "Numpad3" }
```

### Usage

```lua
local movement = require("descent.movement")

-- Check if move is valid
local valid, reason = movement.can_move(map, player.x, player.y, 1, -1)
if not valid then
    print("Cannot move: " .. reason)
end

-- Get all valid moves
local moves = movement.get_valid_moves(map, player.x, player.y)
```

## Agent

- **Agent**: FuchsiaFalcon
- **Date**: 2026-02-01
