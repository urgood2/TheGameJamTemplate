# bd-2qf.37: [Descent] F2-UI Inventory UI

## Implementation Summary

### File Verified

**`assets/scripts/descent/ui/inventory.lua`** (393 lines, 10 KB)

#### Features Implemented

1. **List-based UX** (no grid/tetris)
   - Simple item list with selection index
   - Navigation with up/down keys
   - Scrolling for long lists

2. **Shows Items**
   - Item name display
   - Quantity indicator for stacks
   - Selection highlight

3. **Equipped Indicator**
   - Separate equipped section
   - Shows `[slot] item_name` format
   - Empty slots marked

4. **Capacity Display**
   - Header: `Inventory (count/capacity)`
   - Gold display

5. **Cancel/Back**
   - Escape and I keys close UI
   - Action mode can be canceled

#### Key Bindings

```lua
close = { "Escape", "I" }
up = { "W", "Up", "K" }
down = { "S", "Down", "J" }
use = { "U", "Enter" }
equip = { "E" }
drop = { "D" }
```

### Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| List-based UX | OK no grid/tetris |
| Shows items | OK with selection |
| Equipped indicator | OK [slot] format |
| Capacity | OK header display |
| Cancel/back | OK Escape/I keys |

## Agent

- **Agent**: BoldMountain
- **Date**: 2026-02-01
