# bd-2qf.13: [Descent] C4 FOV + explored tracking

## Implementation Summary

Created recursive shadowcasting FOV system for Descent roguelike mode.

## Files Created

### `assets/scripts/descent/fov.lua`

**Algorithm:** Recursive Shadowcasting
- 8 octant division for symmetric visibility
- Row-by-row scanning from center outward
- Shadow angle tracking for occlusion

**Spec Compliance:**
- `radius`: 8 (from spec.fov.radius)
- `shape`: "circle" (circular FOV)
- `diagonal_blocking`: "no_corner_peek"
- `explored_persists`: true

**Core API:**
- `init(map)` - Initialize with map reference
- `compute(x, y)` - Calculate FOV from origin
- `is_visible(x, y)` - Check current visibility
- `is_explored(x, y)` - Check ever-seen status
- `get_visibility(x, y)` - Returns "visible"/"explored"/"unknown"

**Additional API:**
- `mark_explored(x, y)` - Manual exploration
- `clear_explored()` - Floor transitions
- `save_explored()`/`load_explored(data)` - Persistence
- `get_visible_tiles()`/`get_explored_tiles()` - Batch queries
- `get_origin()`, `get_radius()` - State queries

**Features:**
- Bounds checking (edges/corners safe)
- Wall occlusion via `blocks_vision()`
- Circle-shaped radius check
- Explored state persistence
- Floor transition support

## Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Shadowcasting FOV per spec | ✅ Recursive 8-octant |
| Occlusion correct | ✅ blocks_vision + shadow angles |
| Bounds safe (edges/corners) | ✅ in_bounds checks |
| Explored persists after LOS loss | ✅ explored_persists=true |

## Usage

```lua
local fov = require("descent.fov")
fov.init(map)
fov.compute(player.x, player.y)

if fov.is_visible(tile.x, tile.y) then
    -- Render normally
elseif fov.is_explored(tile.x, tile.y) then
    -- Render dimmed/remembered
end
```

## Agent

- Agent: RedEagle (claude-code/opus-4.5)
- Date: 2026-02-01
