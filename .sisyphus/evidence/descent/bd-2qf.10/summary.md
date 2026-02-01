# bd-2qf.10: [Descent] C2-T Map grid tests

## Implementation Summary

### File Verified

**`assets/scripts/tests/test_descent_map.lua`** (1.7 KB)

#### Test Coverage

1. **Floor map creation** - creates maps with spec sizes for all floors
2. **Index conversion** - to_index/from_index deterministic and bounds-safe
3. **Grid/world conversions** - coordinate transforms are reversible
4. **Occupancy overlaps** - prevents placing on occupied tiles

### Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Grid creation tested | OK new_for_floor() |
| Occupancy checks tested | OK is_occupied, place, remove |
| Bounds validation tested | OK returns nil for OOB |
| Coordinate conversions tested | OK grid_to_world, world_to_grid |

### Key Tests

```lua
-- Index conversion
t.expect(Map.to_index(map, 3, 2)).to_be(8)
t.expect(Map.to_index(map, 0, 1)).to_be_nil()  -- OOB

-- Occupancy
t.expect(Map.place(map, "player", 2, 2)).to_be(true)
t.expect(Map.place(map, "enemy", 2, 2)).to_be(false)  -- Overlap blocked

-- Coordinate conversion
local wx, wy = Map.grid_to_world(map, 2, 2, 16, 0, 0)
local gx, gy = Map.world_to_grid(map, wx, wy, 16, 0, 0)
t.expect(gx).to_be(2)  -- Reversible
```

## Agent

- **Agent**: BoldMountain
- **Date**: 2026-02-01
