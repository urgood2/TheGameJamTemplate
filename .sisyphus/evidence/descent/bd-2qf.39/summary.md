# bd-2qf.39: [Descent] F3 Scroll identification

## Implementation Summary

Created scroll identification system for Descent roguelike mode.

## Files Created

### `assets/scripts/descent/items_scrolls.lua`

**Scroll Types:**
- identify: Reveals item properties
- teleport: Random teleport on floor
- magic_mapping: Reveals floor layout
- fear: Causes enemies to flee
- enchant_weapon: +1 weapon bonus
- enchant_armor: +1 armor bonus

**Label System:**
- Labels from spec.scrolls.label_pool
- Shuffled deterministically per run seed
- Unique assignment (no duplicates)
- Subseed: `run_seed + 7777`

**Identification:**
- `init(seed)` - Initialize with run seed
- `identify(scroll_type)` - Mark type as known
- `is_identified(scroll_type)` - Query state
- `get_display_name(type)` - Returns true name if ID'd
- `get_label(type)` - Returns "scroll of <label>"

**Persistence:**
- `get_identification_state()` / `load_identification_state()`
- `get_label_state()` / `load_label_state()`

## Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Labels randomized per run seed | ✅ Fisher-Yates shuffle |
| Labels unique within run | ✅ Sequential assignment |
| Identification persists | ✅ state.identified table |
| Updates display | ✅ get_display_name() |

## Usage

```lua
local scrolls = require("descent.items_scrolls")
scrolls.init(12345)  -- Run seed

-- Before identification
print(scrolls.get_display_name("identify"))  -- "scroll of ashen"

-- After using scroll
scrolls.identify("identify")
print(scrolls.get_display_name("identify"))  -- "Scroll of Identify"

-- Progress
local id, total = scrolls.get_identification_progress()
print(id .. "/" .. total .. " scrolls identified")
```

## Agent

- Agent: RedEagle (claude-code/opus-4.5)
- Date: 2026-02-01
