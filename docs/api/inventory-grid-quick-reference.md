# Inventory Grid & Sprite Panel Quick Reference

Copy-paste patterns for common UI tasks.

---

## Global UI Scale

Set in `core/constants.lua`:

```lua
Constants.UI = {
    SCALE = 2.0,               -- Change this to scale all UI
    SLOT_BASE_SIZE = 32,       -- 32 * 2.0 = 64px slots
    SLOT_HOVER_SIZE = 34,      -- 34 * 2.0 = 68px hover (1px glow border)
}
```

**Usage:**
```lua
local C = require("core.constants")
local scaledSlotSize = C.UI.SLOT_BASE_SIZE * C.UI.SCALE  -- 64
```

---

## Inventory Grid

### Basic Grid

```lua
local dsl = require("ui.ui_syntax_sugar")
local C = require("core.constants")

local gridDef = dsl.inventoryGrid {
    id = "my_inventory",
    rows = 3,
    cols = 4,
    slotSize = {
        w = C.UI.SLOT_BASE_SIZE * C.UI.SCALE,  -- 64
        h = C.UI.SLOT_BASE_SIZE * C.UI.SCALE   -- 64
    },
    slotSpacing = 4,

    config = {
        allowDragIn = true,
        allowDragOut = true,
        slotSprite = "test-inventory-square-single.png",  -- Optional: custom slot sprite
        padding = 4,
        backgroundColor = "blackberry",
    },
}

local gridEntity = dsl.spawn({ x = 100, y = 100 }, gridDef, "sprites", 100)
```

### Per-Slot Customization

```lua
local gridDef = dsl.inventoryGrid {
    id = "filtered_inventory",
    rows = 2, cols = 3,
    slotSize = { w = 64, h = 64 },

    slots = {
        [1] = {
            filter = function(item) return getElement(item) == "Fire" end,
            color = util.getColor("fiery_red"),
        },
        [2] = { locked = true, color = util.getColor("gray") },
        [6] = { color = util.getColor("gold") },  -- Special slot
    },

    onSlotClick = function(gridEntity, slotIndex, button)
        if button == 2 then  -- Right-click
            -- Handle right-click action
        end
    end,
}
```

### Grid API

```lua
local grid = require("core.inventory_grid")

-- Add/remove items
grid.addItem(gridEntity, itemEntity)           -- First empty slot
grid.addItem(gridEntity, itemEntity, 5)        -- Specific slot
grid.removeItem(gridEntity, slotIndex)

-- Query
local item = grid.getItemAtIndex(gridEntity, slotIndex)
local slotEntity = grid.getSlotEntity(gridEntity, slotIndex)
local count = grid.getUsedSlotCount(gridEntity)
local capacity = grid.getCapacity(gridEntity)
```

---

## Sprite Panels (9-Patch)

Stretch sprites while keeping corners intact.

```lua
dsl.spritePanel {
    sprite = "panel-frame.png",
    borders = { 8, 8, 8, 8 },  -- left, top, right, bottom (non-stretching regions)
    sizing = "fit_content",    -- or "fit_sprite" for fixed size

    children = {
        dsl.text("Panel Content"),
    }
}
```

### Sizing Modes

| Mode | Behavior |
|------|----------|
| `fit_content` | Stretches to fit children (default) |
| `fit_sprite` | Uses original sprite dimensions |

---

## Sprite Buttons (4-State)

Automatic hover/press/disabled states.

### Explicit States

```lua
dsl.spriteButton {
    id = "my_button",
    states = {
        normal = "button-normal.png",
        hover = "button-hover.png",
        pressed = "button-pressed.png",
        disabled = "button-disabled.png",
    },
    borders = { 6, 6, 6, 6 },
    label = "Click Me",
    fontSize = 12,
    minWidth = 80,
    minHeight = 32,
    onClick = function() print("Clicked!") end,
}
```

### Auto-Discovery

```lua
-- Just provide base name, system finds:
--   button-normal.png, button-hover.png, button-pressed.png, button-disabled.png
dsl.spriteButton {
    sprite = "button",  -- Base name
    borders = { 6, 6, 6, 6 },
    label = "Auto",
    onClick = function() end,
}
```

---

## Hover Overlays

Show sprite when hovering over a slot.

**IMPORTANT:** You must call `UIDecorations.draw()` in a render loop for overlays to be visible.

```lua
local UIDecorations = require("ui.ui_decorations")
local C = require("core.constants")

UIDecorations.addOverlay(slotEntity, {
    id = "hover_overlay",
    sprite = "inventory-grid-hover.png",
    position = UIDecorations.Position.CENTER,
    size = {
        w = C.UI.SLOT_HOVER_SIZE * C.UI.SCALE,  -- 68
        h = C.UI.SLOT_HOVER_SIZE * C.UI.SCALE   -- 68
    },
    z = 5,
    visible = function(eid)
        local globalInput = input and input.getState and input.getState()
        return globalInput and globalInput.cursor_hovering_target == eid
    end,
})

-- Render loop (REQUIRED for overlays to show)
timer.every_opts({
    delay = 0.016,  -- ~60fps
    tag = "overlay_render",
    group = "my_timer_group",
    action = function()
        for i = 1, slotCount do
            local slotEntity = grid.getSlotEntity(gridEntity, i)
            if slotEntity and registry:valid(slotEntity) then
                UIDecorations.draw(slotEntity, baseZ)
            end
        end
    end,
})
```

### Position Constants

```lua
UIDecorations.Position.TOP_LEFT
UIDecorations.Position.TOP_CENTER
UIDecorations.Position.TOP_RIGHT
UIDecorations.Position.CENTER_LEFT
UIDecorations.Position.CENTER
UIDecorations.Position.CENTER_RIGHT
UIDecorations.Position.BOTTOM_LEFT
UIDecorations.Position.BOTTOM_CENTER
UIDecorations.Position.BOTTOM_RIGHT
```

---

## Decorations (Badges)

Add corner badges to UI elements.

```lua
UIDecorations.addBadge(slotEntity, {
    id = "stack_count",
    text = "5",
    position = UIDecorations.Position.BOTTOM_RIGHT,
    offset = { x = -2, y = -2 },
    size = { w = 18, h = 18 },
    backgroundColor = "charcoal",
    textColor = "white",
})

-- Update badge text
UIDecorations.setBadgeText(slotEntity, "stack_count", "10")
```

---

## Common Patterns

### Tabbed Inventory Panel

```lua
local TAB_CONFIG = {
    equipment = { id = "inv_equipment", label = "Equipment", rows = 3, cols = 7 },
    actions = { id = "inv_actions", label = "Actions", rows = 3, cols = 7 },
}

local state = {
    grids = {},
    activeTab = "equipment",
}

-- Create grids (one per tab)
for tabId, cfg in pairs(TAB_CONFIG) do
    local visible = (tabId == state.activeTab)
    state.grids[tabId] = createGridForTab(tabId, x, y, visible)
end

-- Switch tab visibility
local function switchTab(tabId)
    for id, gridEntity in pairs(state.grids) do
        setGridVisible(gridEntity, id == tabId, onscreenX)
    end
    state.activeTab = tabId
end
```

### Cleanup on Close

```lua
function cleanup()
    timer.kill_group("my_timer_group")

    for tabId, gridEntity in pairs(state.grids) do
        if gridEntity and registry:valid(gridEntity) then
            -- Cleanup slot decorations
            local capacity = grid.getCapacity(gridEntity)
            for i = 1, capacity do
                local slotEntity = grid.getSlotEntity(gridEntity, i)
                if slotEntity then
                    UIDecorations.cleanup(slotEntity)
                end
            end
            grid.cleanup(gridEntity)
            dsl.cleanupGrid(TAB_CONFIG[tabId].id)
            ui.box.Remove(registry, gridEntity)
        end
    end
end
```

---

## Files Reference

| File | Purpose |
|------|---------|
| `core/constants.lua` | UI scale constants |
| `ui/player_inventory.lua` | Working inventory implementation |
| `ui/ui_syntax_sugar.lua` | DSL for grids, panels, buttons |
| `ui/ui_decorations.lua` | Badges and overlays |
| `core/inventory_grid.lua` | Grid data management API |
| `ui/inventory_grid_init.lua` | Grid initialization |
| `docs/api/sprite-panels.md` | Full sprite panel docs |

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
