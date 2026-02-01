# bd-2qf.17: [Descent] D2a Pathfinding (deterministic)

## Implementation Summary

### File Verified

**`assets/scripts/descent/pathfinding.lua`** (12 KB)

#### Features
- **Algorithms**: BFS and A* pathfinding
- **Neighbor Order**: Canonical NESW then diagonals (N, E, S, W, NE, SE, SW, NW)
- **Determinism**: Same input always produces same output
- **Unreachable**: Returns nil for unreachable destinations
- **Options**: 4-way or 8-way movement, diagonal blocking modes

### Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| BFS/A* returns stable path | ✅ Implemented |
| Neighbor order explicit and tested | ✅ Canonical order documented |
| Unreachable returns nil | ✅ Callers handle without crash |

### Canonical Neighbor Order

```
N(0,-1), E(1,0), S(0,1), W(-1,0), NE(1,-1), SE(1,1), SW(-1,1), NW(-1,-1)
```

This order is explicitly documented and must remain stable for determinism.

## Agent

- **Agent**: BoldMountain
- **Date**: 2026-02-01
