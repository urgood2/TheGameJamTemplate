# bd-2qf.21: [Descent] D2b-H Snapshot hash implementation

## Implementation Summary

Implemented canonical snapshot hashing for determinism verification using FNV-1a 32-bit hash.

## Files Created

### `assets/scripts/descent/snapshot.lua`

**Hash Format (per §5.3):**
1. Version (1 byte)
2. Seed (4 bytes, big-endian)
3. Floor (1 byte)
4. Width/Height (2 bytes each)
5. Tiles (row-major, 1 byte per tile type)
6. Entity count (2 bytes) + sorted entity strings
7. Item count (2 bytes) + sorted item strings

**FNV-1a 32-bit:**
- Prime: 16777619
- Offset basis: 2166136261
- XOR-then-multiply per byte

**Tile Encoding:**
- floor=0, wall=1, door=2
- stairs_up=3, stairs_down=4
- shop=5, altar=6, water=7, lava=8
- unknown=255

**Entity/Item Serialization:**
- Entity: `type:id:x:y:hp`
- Item: `template:id:x:y:qty`
- Sorted by ID for determinism

**Public API:**
- `create_snapshot(state)` - Extract snapshot from game state
- `compute_hash(snapshot)` - FNV-1a hash
- `hash_to_hex(hash)` - Format as 8-char hex
- `compare(snap1, snap2)` - Compare by hash
- `get_summary(snapshot)` - Debug text
- `validate(snapshot)` - Format validation

## Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Version/seed/floor/size/tiles/entities/items format | ✅ Complete |
| FNV-1a 32-bit hash | ✅ Implemented |
| Hash deterministic across runs | ✅ Canonical ordering |

## Usage

```lua
local snapshot = require("descent.snapshot")

-- From game state
local hash = snapshot.compute_hash({
    seed = 42,
    floor = 1,
    width = 15,
    height = 15,
    tiles = map.tiles,
    entities = enemies,
    items = ground_items,
})

print(snapshot.hash_to_hex(hash))  -- e.g., "a1b2c3d4"

-- Compare two runs
assert(snapshot.compare(run1_state, run2_state))
```

## Agent

- Agent: RedEagle (claude-code/opus-4.5)
- Date: 2026-02-01
