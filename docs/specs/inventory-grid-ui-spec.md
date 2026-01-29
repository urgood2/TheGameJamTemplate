# Inventory Grid UI System - Technical Specification

**Version**: 1.0 | **Status**: Draft | **Date**: 2026-01-06

## 1. Executive Summary

New **Inventory Grid UI System** providing:
1. **InventoryGrid DSL** - Declarative grid creation with drag-drop slots
2. **Custom-Rendered UI** - Custom draw functions within UI hierarchy
3. **Enhanced UI Styling** - Per-element backgrounds, ninepatch, badges

## 2. Requirements

### 2.1 Inventory Grid (HIGH)
- Slot entities: Separate entity per slot, visually distinct
- Generic items: Accept any draggable game object
- Stacking: Count badge display
- Filters: Per-slot and grid-wide rules
- Interactions: Click, double-click, right-click, drag-in/out
- Lua API: grid.getItemAt(), grid.getAllItems(), etc.
- Events: grid_item_added, grid_item_removed, grid_item_moved, grid_slot_clicked

### 2.2 Custom-Rendered UI (MEDIUM)
- Custom overlays (e.g., "selected" status)
- Layout participation, focus/input events
- UI hierarchy children
- LayerOrderComponent + TreeOrderComponent

### 2.3 Enhanced Styling (MEDIUM)
- Per-element backgrounds with states
- Inline ninepatch (corners in config)
- Corner badges, overlays
- Better layout flexibility

## 3. Design

### 3.1 dsl.inventoryGrid

```lua
dsl.inventoryGrid {
    id = "player_inventory",
    rows = 3, cols = 4,
    slotSize = { w = 64, h = 64 },
    slotSpacing = 4,
    config = {
        allowDragIn = true, allowDragOut = true,
        stackable = true, maxStackSize = 99,
        filter = function(item, slotIndex) return item.category == "card" end,
        slotBackground = "slot_empty",
    },
    slots = { [1] = { filter = fn, background = "slot_fire" } },
    onSlotChange = function(grid, slot, old, new) end,
}
```

### 3.2 Lua Helper API

```lua
local grid = require("core.inventory_grid")
grid.getItemAt(gridEntity, row, col)
grid.getItemAtIndex(gridEntity, slotIndex)
grid.getAllItems(gridEntity)
grid.findSlotContaining(gridEntity, itemEntity)
grid.findEmptySlot(gridEntity)
grid.addItem(gridEntity, itemEntity, slotIndex)
grid.removeItem(gridEntity, slotIndex)
grid.moveItem(gridEntity, fromSlot, toSlot)
grid.swapItems(gridEntity, slot1, slot2)
grid.getStackCount(gridEntity, slotIndex)
grid.getDimensions(gridEntity)
grid.getCapacity(gridEntity)
```

### 3.3 Signals

```lua
signal.register("grid_item_added", function(grid, slot, item) end)
signal.register("grid_item_removed", function(grid, slot, item) end)
signal.register("grid_item_moved", function(grid, from, to, item) end)
signal.register("grid_slot_clicked", function(grid, slot, button) end)
signal.register("grid_stack_changed", function(grid, slot, item, old, new) end)
```

### 3.4 dsl.customPanel

```lua
dsl.customPanel {
    id = "custom_display",
    minWidth = 200, minHeight = 300,
    onDraw = function(self, x, y, w, h, dt)
        local z = self:getZIndex()
        -- custom rendering with command_buffer
    end,
    onUpdate = function(self, dt) end,
    onInput = function(self, event) return false end,
    focusable = true,
}
```

### 3.5 Overlays for Standard Elements

```lua
dsl.button("Attack", {
    overlays = {
        {
            id = "selected",
            visible = function(self) return isSelected(self) end,
            onDraw = function(self, x, y, w, h, z) end
        },
    }
})
```

### 3.6 Enhanced Styling

```lua
-- Per-element background with states
background = {
    normal = { type = "ninepatch", sprite = "button" },
    hover = { type = "ninepatch", sprite = "button_hover" },
}

-- Inline ninepatch
ninepatch = {
    sprite = "panel.png",
    borders = { left = 8, right = 8, top = 8, bottom = 8 },
    -- OR corners:
    corners = { tl = "...", t = "...", tr = "...", l = "...", c = "...", r = "...", bl = "...", b = "...", br = "..." },
}

-- Badge
badge = { icon = "star", position = "top_right", offset = { x = -4, y = 4 } }

-- Layout flex
distribute = "space_between"  -- space_around, space_evenly
grow = 1, shrink = 1
```

## 4. Implementation Plan

Phase 1: Core Grid - Components, DSL, drag-drop, API, signals
Phase 2: Custom Panels - UITypeEnum, callbacks, layout, overlays  
Phase 3: Styling - States, ninepatch, decorations, flex

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
