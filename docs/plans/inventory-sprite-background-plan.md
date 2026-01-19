# Plan: Inventory Panel Improvements

**Created**: 2026-01-19
**Status**: Ready for implementation



## Overview

Five tasks for the player inventory panel:
1. Use a sprite as the panel background (2x scaling, dynamic dimensions)
2. Fix right-click to equip cards to wand (not working on Mac)
3. Enable drag-drop between cells in the same tab
4. Hook up and test sort buttons (Name, Cost)
5. Auto-categorize cards into correct inventory tabs

---

## Task 1: Sprite Background for Inventory Panel

### Goal
Replace the color-based panel background with `inventory-back-panel.png`, reading dimensions dynamically and applying 2x scaling. No nine-patch - just stretch the sprite to fill.

### Current Implementation
- **File**: `assets/scripts/ui/player_inventory.lua`
- **Panel creation**: `createPanelDefinition()` at lines 686-703
- **Current background**: `dsl.root` with `color = "blackberry"` and `emboss = 3`
- **Panel sizing**: Static constants calculated from grid dimensions (~460×432px)

### New Implementation

#### 1. Add sprite constants (near line 87)
```lua
local INVENTORY_SPRITE = "inventory-back-panel.png"
local SPRITE_SCALE = 2
```

#### 2. Add helper function to read sprite dimensions dynamically
```lua
local function getSpriteDimensions(spriteName)
    local nPatchInfo = animation_system.getNinepatchUIBorderInfo(spriteName)
    if nPatchInfo and nPatchInfo.source then
        return nPatchInfo.source.width, nPatchInfo.source.height
    end
    log_warn("[PlayerInventory] Could not get dimensions for sprite: " .. tostring(spriteName))
    return 230, 216  -- fallback
end
```

#### 3. Replace `createPanelDefinition()` 
```lua
local function createPanelDefinition()
    local spriteW, spriteH = getSpriteDimensions(INVENTORY_SPRITE)
    local panelW = spriteW * SPRITE_SCALE
    local panelH = spriteH * SPRITE_SCALE
    
    return dsl.strict.spritePanel {
        id = PANEL_ID,
        sprite = INVENTORY_SPRITE,
        borders = { 0, 0, 0, 0 },  -- No nine-patch, full stretch
        minWidth = panelW,
        minHeight = panelH,
        maxWidth = panelW,
        maxHeight = panelH,
        padding = PANEL_PADDING,
        children = {
            createHeader(),
            createTabs(),
            createGridContainer(),
            createFooter(),
        },
    }
end
```

#### 4. Update position calculations to use dynamic dimensions
Replace static `PANEL_WIDTH`/`PANEL_HEIGHT` usage in `calculatePositions()` with dynamic values.

### Technical Details

- `animation_system.getNinepatchUIBorderInfo(spriteName)` returns `NPatchInfo` with `.source.width` and `.source.height`
- `dsl.spritePanel` with `borders = {0,0,0,0}` stretches the entire sprite (no nine-patch regions)
- Setting both `minWidth/minHeight` and `maxWidth/maxHeight` to same value forces exact size

### Asset Required
- **File**: `inventory-back-panel.png`
- **Location**: Add to graphics folder (will be packed by TexturePacker)
- **Size**: Base dimensions at 1x (will be scaled 2x in code)

---

## Task 2: Fix Right-Click on Mac

### Problem
Right-click to equip cards to wand doesn't work on Mac.

### Current Implementation
- **File**: `assets/scripts/ui/inventory_quick_equip.lua`
- **Function**: `checkRightClick()` at lines 254-280
- **Current triggers**: 
  - `MouseButton.MOUSE_BUTTON_RIGHT` (right-click)
  - Alt+Left-click (alternative)

### Analysis

**Potential causes:**
1. macOS Ctrl+Click is interpreted as right-click at OS level, but Raylib may receive raw Ctrl+Left
2. Hover detection (`hoveredCard`) may not be set when clicking
3. Input may be consumed by another system before reaching this code

### Fix: Add Ctrl+Click Support + Debug Logging

```lua
local function checkRightClick()
    if not hoveredCard then return end
    if not registry:valid(hoveredCard) then
        hoveredCard = nil
        return
    end

    -- Right-click (standard)
    local rightClick = input and input.isMousePressed and 
                       input.isMousePressed(MouseButton.MOUSE_BUTTON_RIGHT)

    -- Alt+Left-click (existing alternative)
    local altHeld = input and input.isKeyDown and (
        input.isKeyDown(KeyboardKey.KEY_LEFT_ALT) or
        input.isKeyDown(KeyboardKey.KEY_RIGHT_ALT)
    )
    local altClick = altHeld and input.isMousePressed(MouseButton.MOUSE_BUTTON_LEFT)

    -- Ctrl+Left-click (Mac-friendly alternative)
    local ctrlHeld = input and input.isKeyDown and (
        input.isKeyDown(KeyboardKey.KEY_LEFT_CONTROL) or
        input.isKeyDown(KeyboardKey.KEY_RIGHT_CONTROL)
    )
    local ctrlClick = ctrlHeld and input.isMousePressed(MouseButton.MOUSE_BUTTON_LEFT)

    if rightClick or altClick or ctrlClick then
        log_debug("[QuickEquip] Quick-equip triggered on card: " .. tostring(hoveredCard))
        local success, reason = QuickEquip.equipToWand(hoveredCard)
        if not success then
            showEquipFeedback(hoveredCard, reason)
        end
    end
end
```

### Debug Strategy (if still not working)

Add temporary debug logging to trace the issue:

```lua
-- At top of checkRightClick(), before the hoveredCard check:
local debugInput = input and input.isMousePressed
if debugInput then
    local leftPressed = debugInput(MouseButton.MOUSE_BUTTON_LEFT)
    local rightPressed = debugInput(MouseButton.MOUSE_BUTTON_RIGHT)
    if leftPressed or rightPressed then
        log_debug("[QuickEquip DEBUG] L=" .. tostring(leftPressed) .. 
                  " R=" .. tostring(rightPressed) ..
                  " hovered=" .. tostring(hoveredCard))
    end
end
```

---

## Files to Modify

| File | Changes |
|------|---------|
| `assets/scripts/ui/player_inventory.lua` | Add sprite constants, helper function, replace `createPanelDefinition()`, update position calculations |
| `assets/scripts/ui/inventory_quick_equip.lua` | Add Ctrl+Click support in `checkRightClick()` |

---

## Test Plan

| Test | Expected | Verify |
|------|----------|--------|
| Panel has sprite background | `inventory-back-panel.png` visible as background | Open inventory (I key) |
| Panel size = sprite × 2 | If sprite is 200×150, panel is 400×300 | Measure or log dimensions |
| Content fits in panel | Header, tabs, grid, footer all visible | Visual check |
| Right-click equips (Windows/Linux) | Card moves to wand | Right-click card |
| Ctrl+Click equips (Mac) | Card moves to wand | Ctrl+Left-click card |
| Alt+Click equips (all) | Card moves to wand | Alt+Left-click card |
| No empty slots feedback | "No empty wand slots!" popup | Try equip when wand full |

---

## Implementation Order

1. **Add Ctrl+Click to `inventory_quick_equip.lua`** - Quick fix, test immediately
2. **Add sprite asset** - User provides `inventory-back-panel.png`
3. **Update `player_inventory.lua`** - Implement sprite background
4. **Test and adjust** - Verify dimensions, content layout

---

## Rollback Plan

If sprite background causes issues:
- Revert `createPanelDefinition()` to use `dsl.root` with color
- Keep Ctrl+Click fix (no downside)

---

## Task 3: Enable Drag-Drop Between Cells in Same Tab

### Goal
Allow players to drag cards between slots within the same inventory tab to reorganize.

### Current Implementation
- **File**: `assets/scripts/ui/inventory_grid_init.lua`
- **Function**: `handleItemDrop()` at lines 174-298
- **Status**: Already implemented! Same-grid operations (move/swap/merge) work at lines 202-231

### Analysis
The code already handles same-grid drag-drop:
```lua
if sourceSlotInThisGrid then
    -- Item is already in this grid, move/swap/merge (same-grid operation)
    if sourceSlotInThisGrid == slotIndex then
        -- Dropped on same slot, mark as valid but no-op
        InventoryGridInit.markValidDrop(droppedEntity)
        return true
    end
    -- ... swap or move logic
end
```

### Debugging Steps
1. Test drag-drop between slots in same tab
2. Check if `dragEnabled` is set on card entities
3. Verify `grid.canSlotAccept()` isn't rejecting same-grid moves
4. Check console for `[DRAG-DEBUG]` logs

### Potential Issues
- Cards may not have `dragEnabled = true` in their GameObject
- Slot collision may not be detecting drops properly
- Filter function may be rejecting cards

### Fix (if needed)
Ensure cards are set up with drag enabled in `player_inventory.lua`:
```lua
local go = component_cache.get(cardEntity, GameObject)
if go then
    go.state.dragEnabled = true
    go.state.collisionEnabled = true
end
```

---

## Task 4: Hook Up Sort Buttons

### Goal
Make "Name" and "Cost" sort buttons functional in the inventory footer.

### Current Implementation
- **File**: `assets/scripts/ui/player_inventory.lua`
- **Function**: `createFooter()` at lines 636-671
- **Current state**: Buttons exist but only log debug messages

```lua
dsl.strict.button("Name", {
    id = "sort_name_btn",
    fontSize = 10,
    color = "purple_slate",
    onClick = function()
        log_debug("[PlayerInventory] Sort by name clicked")  -- TODO: implement
    end,
}),
```

### Reference Implementation
From `inventory_grid_demo.lua` lines 706-771:
```lua
local function applySorting()
    if not demoState.sortBy or not activeGrid then return end
    
    local items = grid.getAllItems(activeGrid)
    local itemsWithData = {}
    
    for slotIndex, entity in pairs(items) do
        local script = getScriptTableFromEntityID(entity)
        if script then
            table.insert(itemsWithData, {
                entity = entity,
                slot = slotIndex,
                name = script.name or "",
                element = script.element or "",
                manaCost = script.manaCost or 0,
            })
        end
    end
    
    local sortKey = demoState.sortBy
    table.sort(itemsWithData, function(a, b)
        if sortKey == "name" then
            return a.name < b.name
        elseif sortKey == "element" then
            return (a.element or "") < (b.element or "")
        end
        return false
    end)
    
    -- Reposition items
    for newSlot, itemData in ipairs(itemsWithData) do
        grid.moveItem(activeGrid, itemData.slot, newSlot)
    end
end
```

### New Implementation

Add sorting functions to `player_inventory.lua`:

```lua
local state = {
    -- ... existing state
    sortBy = nil,  -- "name" | "cost" | nil
}

local function sortActiveGrid(sortKey)
    local activeGrid = state.activeGrid
    if not activeGrid then return end
    
    state.sortBy = sortKey
    
    local items = grid.getAllItems(activeGrid)
    local itemsWithData = {}
    
    for slotIndex, entity in pairs(items) do
        local script = getScriptTableFromEntityID(entity)
        if script then
            table.insert(itemsWithData, {
                entity = entity,
                slot = slotIndex,
                name = script.name or script.cardID or "",
                manaCost = script.manaCost or 0,
            })
        end
    end
    
    table.sort(itemsWithData, function(a, b)
        if sortKey == "name" then
            return a.name < b.name
        elseif sortKey == "cost" then
            return a.manaCost < b.manaCost
        end
        return false
    end)
    
    -- Reposition items to sorted order
    for newSlot, itemData in ipairs(itemsWithData) do
        if itemData.slot ~= newSlot then
            grid.moveItem(activeGrid, itemData.slot, newSlot)
            -- Update itemData.slot for subsequent moves
            for _, other in ipairs(itemsWithData) do
                if other.slot == newSlot then
                    other.slot = itemData.slot
                    break
                end
            end
            itemData.slot = newSlot
        end
    end
    
    -- Snap all items to their new slots
    snapItemsToSlots()
    log_debug("[PlayerInventory] Sorted by " .. sortKey)
end
```

Update `createFooter()`:
```lua
dsl.strict.button("Name", {
    id = "sort_name_btn",
    fontSize = 10,
    color = state.sortBy == "name" and "steel_blue" or "purple_slate",
    onClick = function()
        sortActiveGrid("name")
    end,
}),
dsl.strict.button("Cost", {
    id = "sort_cost_btn",
    fontSize = 10,
    color = state.sortBy == "cost" and "steel_blue" or "purple_slate",
    onClick = function()
        sortActiveGrid("cost")
    end,
}),
```

---

## Task 5: Auto-Categorize Cards into Correct Tabs

### Goal
When cards are added to inventory, automatically place them in the correct tab based on card type.

### Current Implementation
- **File**: `assets/scripts/ui/player_inventory.lua`
- **Function**: `PlayerInventory.addCard()` at lines 1141-1205
- **Current behavior**: Cards go to specified category or `state.activeTab`

### Card Type Detection
From `inventory_quick_equip.lua` lines 122-140:
```lua
local function isTriggerCard(cardEntity)
    local script = getScriptTableFromEntityID(cardEntity)
    if not script then return false end

    if script.cardType == "trigger" then return true end
    if script.isTrigger then return true end
    if script.category == "trigger" or script.category == "triggers" then return true end

    if script.cardID and WandEngine and WandEngine.trigger_card_defs then
        if WandEngine.trigger_card_defs[script.cardID] then
            return true
        end
    end
    return false
end
```

### Tab Configuration
Current tabs in `player_inventory.lua`:
```lua
local TAB_CONFIG = {
    actions = { label = "Actions", rows = 3, cols = 7 },
    triggers = { label = "Triggers", rows = 3, cols = 7 },
    items = { label = "Items", rows = 3, cols = 7 },
}
```

### New Implementation

Add category detection helper:
```lua
local function detectCardCategory(cardEntity)
    local script = getScriptTableFromEntityID(cardEntity)
    if not script then return "items" end  -- default fallback
    
    -- Check explicit category first
    if script.category then
        if script.category == "trigger" or script.category == "triggers" then
            return "triggers"
        elseif script.category == "action" or script.category == "actions" then
            return "actions"
        elseif script.category == "item" or script.category == "items" then
            return "items"
        end
    end
    
    -- Check cardType
    if script.cardType == "trigger" then return "triggers" end
    if script.cardType == "action" then return "actions" end
    if script.isTrigger then return "triggers" end
    
    -- Check WandEngine definitions
    if script.cardID then
        if WandEngine and WandEngine.trigger_card_defs and WandEngine.trigger_card_defs[script.cardID] then
            return "triggers"
        end
        if WandEngine and WandEngine.card_defs and WandEngine.card_defs[script.cardID] then
            return "actions"
        end
    end
    
    return "items"  -- default for unknown cards
end
```

Update `PlayerInventory.addCard()`:
```lua
function PlayerInventory.addCard(cardEntity, category, cardData)
    if not cardEntity or not registry:valid(cardEntity) then
        log_warn("[PlayerInventory] Cannot add invalid card entity")
        return false
    end

    -- Auto-detect category if not specified
    category = category or detectCardCategory(cardEntity)
    
    local cfg = TAB_CONFIG[category]
    -- ... rest of function
end
```

---

## Updated Files to Modify

| File | Changes |
|------|---------|
| `assets/scripts/ui/player_inventory.lua` | Sprite background, sort functions, category detection |
| `assets/scripts/ui/inventory_quick_equip.lua` | Add Ctrl+Click support |
| `assets/scripts/ui/inventory_grid_init.lua` | Debug/verify drag-drop (may not need changes) |

---

## Updated Test Plan

| Test | Expected | Verify |
|------|----------|--------|
| Panel has sprite background | `inventory-back-panel.png` visible | Open inventory (I key) |
| Panel size = sprite × 2 | Correct dimensions | Measure or log |
| Right-click equips (Win/Linux) | Card moves to wand | Right-click card |
| Ctrl+Click equips (Mac) | Card moves to wand | Ctrl+Left-click |
| Drag card to empty slot | Card moves | Drag and drop |
| Drag card onto another card | Cards swap | Drag and drop |
| Click "Name" sort | Cards reorder A-Z | Click button |
| Click "Cost" sort | Cards reorder by mana | Click button |
| Add trigger card | Goes to Triggers tab | Add card via code |
| Add action card | Goes to Actions tab | Add card via code |
| Add unknown card | Goes to Items tab | Add card via code |

---

## Implementation Order

1. **Task 2**: Add Ctrl+Click to `inventory_quick_equip.lua` (quick fix)
2. **Task 3**: Test drag-drop, fix if needed
3. **Task 4**: Implement sort buttons
4. **Task 5**: Implement auto-categorization
5. **Task 1**: Add sprite background (requires asset)
