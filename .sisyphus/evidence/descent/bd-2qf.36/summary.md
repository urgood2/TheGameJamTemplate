# bd-2qf.36: [Descent] F2 Items + inventory list UX

## Implementation Summary

Created comprehensive items and inventory system for Descent roguelike mode.

## Files Created

### 1. `assets/scripts/descent/items.lua`

Core items and inventory module.

**Item Types:**
- WEAPON, ARMOR, POTION, SCROLL, GOLD, FOOD, MISC

**Equipment Slots:**
- weapon, armor (per spec)

**Built-in Templates:**
- Weapons: short_sword, long_sword, dagger
- Armor: leather_armor, chain_mail
- Consumables: health_potion, mana_potion
- Gold (stackable)

**Inventory Operations:**
- `create_inventory(capacity?)` - Create inventory with spec capacity (20)
- `pickup(inv, item)` - Pick up item, block policy on full
- `drop(inv, id, qty?)` - Drop item or partial stack
- `use(inv, id, player?)` - Use consumable, apply effect
- `equip(inv, id)` - Equip to slot, swap if occupied
- `unequip(inv, slot)` - Unequip to inventory
- `get_equipment_stat(inv, stat)` - Sum equipment bonuses

**Turn Costs (from spec):**
- pickup: 100 (0 if full)
- drop: 100
- use: 100

### 2. `assets/scripts/descent/ui/inventory.lua`

List-based inventory UI (no grid/tetris per spec).

**Features:**
- Open/close/toggle
- Keyboard navigation (W/S/Up/Down/J/K)
- Actions: Use (U/Enter), Equip (E), Drop (D)
- Selection highlighting
- Scroll support for large inventories
- Equipment display section
- Gold display
- `format()` for console output

## Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Pickup works | ✅ M.pickup() with block policy |
| Drop works | ✅ M.drop() with stack splitting |
| Use works | ✅ M.use() consumes and applies effect |
| Equip works | ✅ M.equip() with swap support |
| Capacity enforcement | ✅ 20 items, block policy |
| Equip modifies combat stats | ✅ get_equipment_stat() |

## Usage

```lua
local items = require("descent.items")
items.init()

local inv = items.create_inventory()
local sword = items.create_item("short_sword")
items.pickup(inv, sword)
items.equip(inv, sword.instance_id)

-- UI
local inv_ui = require("descent.ui.inventory")
inv_ui.init(inv, player)
inv_ui.open()
```

## Agent

- Agent: RedEagle (claude-code/opus-4.5)
- Date: 2026-02-01
