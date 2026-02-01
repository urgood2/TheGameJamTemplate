# bd-2qf.19: [Descent] D2b Procgen + validation + fallback

## Implementation Summary

### File Created

**`assets/scripts/descent/procgen.lua`** (14 KB)

#### Features
- **Room Generation**: BSP-lite algorithm with room carving and L-shaped corridors
- **Validation**: BFS path check from start to stairs
- **Quotas**: Enemies (min/max), shop, altar, miniboss, boss per floor spec
- **No Overlaps**: All placements checked against existing placements
- **Fallback**: Simple arena layout after MAX_ATTEMPTS (50)
- **Snapshot Hash**: Deterministic hash per §5.3 (djb2 algorithm)

### Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Generate floors to spec sizes | ✅ Uses `Map.new_for_floor()` |
| Walkable start/stairs (floors 1-4) | ✅ Validated in `validate_floor()` |
| Reachable start->stairs (BFS) | ✅ Uses `pathfinding.find_path()` |
| Quotas enforced | ✅ enemies_min/max, shop, altar, etc. |
| No overlaps | ✅ `is_valid_placement()` check |
| Fallback after MAX_ATTEMPTS | ✅ Logs warning, generates arena |
| Deterministic snapshot hash | ✅ `compute_hash()` |

### Key Functions

- `generate(floor_num, seed)` - Main generation entry point
- `generate_fallback(floor_num)` - Simple arena when generation fails
- `validate_floor(...)` - Validates start/stairs walkable and reachable
- `compute_hash(map, placements)` - Deterministic floor hash

### Floor Generation Flow

1. Create empty map filled with walls
2. Generate 3-12 rooms via random placement
3. Connect rooms with L-shaped corridors
4. Place player start in first room center
5. Place stairs in appropriate rooms
6. Validate paths (start -> stairs_down, start -> stairs_up)
7. Place enemies, shop, altar, miniboss, boss per spec
8. If validation fails, retry up to MAX_ATTEMPTS
9. On failure, generate fallback arena layout

## Agent

- **Agent**: BoldMountain
- **Date**: 2026-02-01
