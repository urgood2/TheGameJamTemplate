# Inventory Grid API

Declarative inventory grid system with drag-drop support, stacking, and filtering.

## Quick Start

```lua
local dsl = require("ui.ui_syntax_sugar")
local grid = require("core.inventory_grid")

-- Create a 3x4 inventory grid
local inventoryUI = dsl.inventoryGrid {
    id = "player_inventory",
    rows = 3,
    cols = 4,
    slotSize = { w = 64, h = 64 },
    slotSpacing = 4,
    config = {
        allowDragIn = true,
        allowDragOut = true,
        stackable = true,
        maxStackSize = 99,
    },
}

local gridEntity = dsl.spawn({ x = 100, y = 100 }, inventoryUI)

-- Add an item
local success = grid.addItem(gridEntity, myItemEntity, 1)
```

## DSL: dsl.inventoryGrid

Creates a grid of slots for drag-drop inventory management.

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `id` | string | auto | Unique grid identifier |
| `rows` | number | 3 | Number of rows |
| `cols` | number | 3 | Number of columns |
| `slotSize` | table | `{w=64,h=64}` | Size of each slot |
| `slotSpacing` | number | 4 | Spacing between slots |
| `config` | table | `{}` | Grid-wide configuration |
| `slots` | table | `{}` | Per-slot overrides |
| `onSlotChange` | function | nil | Callback when slot changes |
| `onSlotClick` | function | nil | Callback when slot clicked |

### Config Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `allowDragIn` | bool | true | Allow dragging items into grid |
| `allowDragOut` | bool | true | Allow dragging items out of grid |
| `stackable` | bool | false | Allow item stacking |
| `maxStackSize` | number | 999 | Maximum stack size |
| `filter` | function | nil | Grid-wide item filter |
| `slotBackground` | string | nil | Default slot background |
| `slotColor` | string/Color | "gray" | Default slot color |
| `slotEmboss` | number | 1 | Slot emboss amount |

### Per-Slot Config

```lua
slots = {
    [1] = {
        filter = function(item) return item.type == "weapon" end,
        locked = true,
        background = "slot_special",
        tooltip = { title = "Weapon Slot", body = "Drag weapon here" },
    },
}
```

## Grid Helper API

```lua
local grid = require("core.inventory_grid")
```

### Dimensions

| Function | Returns | Description |
|----------|---------|-------------|
| `grid.getDimensions(e)` | rows, cols | Get grid size |
| `grid.getCapacity(e)` | number | Total slot count |
| `grid.getUsedSlotCount(e)` | number | Occupied slots |
| `grid.getEmptySlotCount(e)` | number | Empty slots |

### Item Access

| Function | Returns | Description |
|----------|---------|-------------|
| `grid.getItemAt(e, row, col)` | entity/nil | Get item by row/col |
| `grid.getItemAtIndex(e, idx)` | entity/nil | Get item by slot index |
| `grid.getAllItems(e)` | table | All items `{idx=entity}` |
| `grid.getItemList(e)` | array | Items as `{{slot,item},...}` |

### Find Operations

| Function | Returns | Description |
|----------|---------|-------------|
| `grid.findSlotContaining(e, item)` | idx/nil | Find slot with item |
| `grid.findEmptySlot(e)` | idx/nil | First empty slot |
| `grid.findSlotsMatching(e, fn)` | array | Slots matching predicate |

### Item Operations

| Function | Returns | Description |
|----------|---------|-------------|
| `grid.addItem(e, item, idx?)` | bool, idx | Add item (nil=first empty) |
| `grid.removeItem(e, idx)` | entity/nil | Remove and return item |
| `grid.moveItem(e, from, to)` | bool | Move item to empty slot |
| `grid.swapItems(e, s1, s2)` | bool | Swap two items |

### Stack Operations

| Function | Returns | Description |
|----------|---------|-------------|
| `grid.getStackCount(e, idx)` | number | Stack count at slot |
| `grid.addToStack(e, idx, amt)` | bool | Increase stack |
| `grid.removeFromStack(e, idx, amt)` | bool | Decrease stack |

### Slot State

| Function | Returns | Description |
|----------|---------|-------------|
| `grid.isSlotLocked(e, idx)` | bool | Check if locked |
| `grid.setSlotLocked(e, idx, bool)` | nil | Set lock state |
| `grid.canSlotAccept(e, idx, item)` | bool | Check if can accept |
| `grid.getSlotEntity(e, idx)` | entity/nil | Get slot UI entity |

## Signals

```lua
local signal = require("external.hump.signal")

signal.register("grid_item_added", function(gridEntity, slotIndex, itemEntity)
    playSound("item_drop")
end)

signal.register("grid_item_removed", function(gridEntity, slotIndex, itemEntity)
    playSound("item_pickup")
end)

signal.register("grid_item_moved", function(gridEntity, fromSlot, toSlot, itemEntity)
    -- Item moved within grid
end)

signal.register("grid_slot_clicked", function(gridEntity, slotIndex, button, modifiers)
    if button == "right" then
        showContextMenu(slotIndex)
    end
end)

signal.register("grid_stack_changed", function(gridEntity, slotIndex, itemEntity, oldCount, newCount)
    updateStackBadge(slotIndex, newCount)
end)
```

## Filtering

### Grid-wide Filter

```lua
config = {
    filter = function(item, slotIndex)
        local script = getScriptTableFromEntityID(item)
        return script and script.category == "card"
    end,
}
```

### Per-Slot Filter

```lua
slots = {
    [1] = {
        filter = function(item)
            local script = getScriptTableFromEntityID(item)
            return script and script.element == "Fire"
        end,
    },
}
```

## Stacking

Items stack when:
1. `config.stackable = true`
2. Both items have matching `stackId` property
3. Stack count < `maxStackSize`

```lua
-- Item entity needs stackId in script table
local itemScript = getScriptTableFromEntityID(item)
itemScript.stackId = "health_potion"  -- Items with same stackId will stack
```

## Example: Card Inventory

```lua
local dsl = require("ui.ui_syntax_sugar")
local grid = require("core.inventory_grid")

local cardInventory = dsl.inventoryGrid {
    id = "deck_builder",
    rows = 4,
    cols = 8,
    slotSize = { w = 80, h = 112 },
    slotSpacing = 6,
    config = {
        stackable = false,
        filter = function(item)
            local script = getScriptTableFromEntityID(item)
            return script and script.category == "card"
        end,
        slotColor = "darkgray",
    },
    onSlotChange = function(gridEntity, slot, oldItem, newItem)
        signal.emit("deck_changed", { source = "inventory" })
    end,
}

local inventoryBox = dsl.spawn({ x = 50, y = 100 }, cardInventory)

-- Transfer card to inventory
local card = createCardEntity("FIREBALL")
grid.addItem(inventoryBox, card)
```

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
