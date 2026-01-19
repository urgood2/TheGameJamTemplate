# Plan: Inventory Panel Improvements

**Created**: 2026-01-19  
**Status**: Updated for current inventory tabs + layout

## Scope Notes (Current Code Reality)

- `player_inventory.lua` now uses 5 tabs: **equipment, wands, triggers, actions, modifiers** (not just actions/triggers/items).
- `SPRITE_SCALE` already exists and is used for slot sizing. Avoid reusing this name for the panel background.
- Panel width/height are currently derived from grid constants (`PANEL_WIDTH`, `PANEL_HEIGHT`) and are referenced in `createHeader()` and `calculatePositions()`.

## Overview

Five tasks for the player inventory panel:
1. Use a sprite as the panel background (2x scaling, dynamic dimensions)
2. Fix right-click to equip cards to wand (not working on Mac)
3. Verify drag-drop between cells in the same tab (already implemented)
4. Hook up and test sort buttons (Name, Cost)
5. Auto-categorize cards into correct inventory tabs

---

## Task 1: Sprite Background for Inventory Panel

### Goal
Replace the color-based panel background with `inventory-back-panel.png`, reading dimensions dynamically and applying 2x scaling. No nine-patch slicing—just stretch the sprite.

### Current Implementation
- **File**: `assets/scripts/ui/player_inventory.lua`
- **Panel creation**: `createPanelDefinition()`  
- **Background**: `dsl.strict.root` with `color = "blackberry"` and `emboss = 3`
- **Sizing**: `PANEL_WIDTH`/`PANEL_HEIGHT` constants based on grid dimensions

### New Implementation (Updated)

#### 1) Add panel sprite constants (near existing size constants)
```lua
local PANEL_SPRITE = "inventory-back-panel.png"
local PANEL_SPRITE_SCALE = 2
```

#### 2) Add a helper to read sprite dimensions
```lua
local function getSpriteDimensions(spriteName)
    local nPatchInfo = select(1, animation_system.getNinepatchUIBorderInfo(spriteName))
    if nPatchInfo and nPatchInfo.source then
        return nPatchInfo.source.width, nPatchInfo.source.height
    end
    log_warn("[PlayerInventory] Could not get dimensions for sprite: " .. tostring(spriteName))
    return PANEL_WIDTH, PANEL_HEIGHT  -- fallback to current constants
end
```

#### 3) Compute panel size once (before layout + panel creation)
Use a helper so both `calculatePositions()` and `createPanelDefinition()` share the same sprite-derived size.

```lua
local function ensurePanelDimensions()
    if state.panelWidth and state.panelHeight then return end
    local spriteW, spriteH = getSpriteDimensions(PANEL_SPRITE)
    state.panelWidth = math.floor(spriteW * PANEL_SPRITE_SCALE)
    state.panelHeight = math.floor(spriteH * PANEL_SPRITE_SCALE)
end

local function createPanelDefinition()
    ensurePanelDimensions()
    local panelW = state.panelWidth or PANEL_WIDTH
    local panelH = state.panelHeight or PANEL_HEIGHT

    return dsl.strict.spritePanel {
        id = PANEL_ID,
        sprite = PANEL_SPRITE,
        borders = { 0, 0, 0, 0 },
        minWidth = panelW,
        minHeight = panelH,
        maxWidth = panelW,
        maxHeight = panelH,
        padding = PANEL_PADDING,
        children = {
            createHeader(panelW),
            createTabs(),
            createGridContainer(),
            createFooter(),
        },
    }
end
```

#### 4) Make `createHeader()` accept a width (avoid `PANEL_WIDTH`)
```lua
local function createHeader(panelWidth)
    local headerContentWidth = (panelWidth or PANEL_WIDTH) - 2 * PANEL_PADDING
    return dsl.hbox {
        config = {
            id = "inventory_header",
            color = "dark_lavender",
            padding = 8,
            minWidth = headerContentWidth,
        },
        children = { ... }
    }
end
```

#### 5) Update `calculatePositions()` to use sprite size
```lua
local function calculatePositions()
    ensurePanelDimensions()
    local panelW = state.panelWidth or PANEL_WIDTH
    local panelH = state.panelHeight or PANEL_HEIGHT
    ...
    state.panelX = (screenW - panelW) / 2
    state.panelY = screenH - panelH - 10
    ...
end
```

### Notes
- `animation_system.getNinepatchUIBorderInfo()` returns a frame even for non-ninepatch sprites; setting borders to `{0,0,0,0}` prevents slice margins.
- If any stretching artifacts appear, switch to `UIBackground` sprite mode (uses `UIStylingType.Sprite`) instead of `spritePanel`.

### Asset Required
- **File**: `inventory-back-panel.png`
- **Location**: Graphics folder (packed by TexturePacker)
- **Size**: Base dimensions at 1x (scaled 2x in code)

---

## Task 2: Fix Right-Click on Mac

### Problem
Right-click to equip cards to wand doesn't work on Mac.

### Current Implementation
- **File**: `assets/scripts/ui/inventory_quick_equip.lua`
- **Function**: `checkRightClick()`
- **Triggers**: Right-click + Alt+Left-click

### Fix: Add Ctrl+Click Support
```lua
local ctrlHeld = input and input.isKeyDown and (
    input.isKeyDown(KeyboardKey.KEY_LEFT_CONTROL) or
    input.isKeyDown(KeyboardKey.KEY_RIGHT_CONTROL)
)
local ctrlClick = ctrlHeld and input.isMousePressed(MouseButton.MOUSE_BUTTON_LEFT)

if rightClick or altClick or ctrlClick then
    ...
end
```

### Debug Strategy (if needed)
- Gate logs behind a local `DEBUG_QUICK_EQUIP` flag to avoid spam.
- Log `hoveredCard` + left/right pressed state on click frames only.

---

## Task 3: Verify Drag-Drop (Same Tab)

### Status
Already implemented in `inventory_grid_init.lua` (`handleItemDrop()` supports same-grid move/swap).

### Verification Checklist
1. Drag to empty slot → item moves
2. Drag onto another item → items swap
3. Verify `InventoryGridInit.makeItemDraggable()` is called (already in `PlayerInventory.addCard`)
4. If issues, inspect `grid.canSlotAccept()` and any filter rules

---

## Task 4: Hook Up Sort Buttons

### Goal
Make "Name" and "Cost" sort buttons functional.

### Use Existing State (No new fields)
Use `state.sortField` and `state.sortAsc` (already declared) rather than adding `sortBy`.

### Sort Logic (Rebuild Grid Safely)
- Use `grid.getItemList(activeGrid)` to get `{ slot, item }` pairs.
- Build a sortable list with computed keys.
- Remove all items, then re-add in sorted order with explicit slot indices.

```lua
local function getSortKeys(entity)
    local script = state.cardRegistry[entity] or (getScriptTableForEntityID and getScriptTableForEntityID(entity))
    local data = script and (script.cardData or script) or {}
    local name = (data.name or data.id or data.cardID or ""):lower()
    local cost = data.mana_cost or data.manaCost or 0
    return name, cost
end

local function sortActiveGrid(sortField)
    local activeGrid = state.activeGrid
    if not activeGrid then return end

    if state.sortField == sortField then
        state.sortAsc = not state.sortAsc
    else
        state.sortField = sortField
        state.sortAsc = true
    end

    local list = grid.getItemList(activeGrid)
    local items = {}
    for _, entry in ipairs(list) do
        local name, cost = getSortKeys(entry.item)
        table.insert(items, {
            entity = entry.item,
            name = name,
            cost = cost,
            slot = entry.slot,
        })
        grid.removeItem(activeGrid, entry.slot)
    end

    table.sort(items, function(a, b)
        if sortField == "name" then
            if a.name == b.name then return a.slot < b.slot end
            return state.sortAsc and (a.name < b.name) or (a.name > b.name)
        else
            if a.cost == b.cost then return a.slot < b.slot end
            return state.sortAsc and (a.cost < b.cost) or (a.cost > b.cost)
        end
    end)

    for slotIndex, item in ipairs(items) do
        grid.addItem(activeGrid, item.entity, slotIndex)
    end

    snapItemsToSlots()
end
```

### Button Wiring
- Update `createFooter()` to call `sortActiveGrid("name")` / `sortActiveGrid("cost")`
- Optional: add ▲/▼ indicator or color change based on `state.sortField/state.sortAsc`

---

## Task 5: Auto-Categorize Cards into Correct Tabs

### Goal
Auto-route cards based on metadata when `PlayerInventory.addCard()` is called without an explicit category.

### Current Tabs (from `TAB_CONFIG`)
`equipment`, `wands`, `triggers`, `actions`, `modifiers`

### Detection Logic (Updated)
```lua
local function detectCardCategory(cardEntity, cardData)
    local script = getScriptTableForEntityID and getScriptTableForEntityID(cardEntity)
    local data = cardData or (script and script.cardData) or script or {}

    -- Explicit category wins
    if data.category then
        local c = data.category
        if c == "trigger" or c == "triggers" then return "triggers" end
        if c == "action" or c == "actions" then return "actions" end
        if c == "modifier" or c == "modifiers" then return "modifiers" end
        if c == "wand" or c == "wands" then return "wands" end
        if c == "equipment" then return "equipment" end
    end

    -- Card data type (common for cards.lua)
    if data.type == "trigger" then return "triggers" end
    if data.type == "action" then return "actions" end
    if data.type == "modifier" then return "modifiers" end

    -- Legacy flags
    if script and script.isTrigger then return "triggers" end

    -- WandEngine definitions (if present)
    if data.cardID and WandEngine then
        if WandEngine.trigger_card_defs and WandEngine.trigger_card_defs[data.cardID] then
            return "triggers"
        end
        if WandEngine.card_defs and WandEngine.card_defs[data.cardID] then
            return "actions"
        end
    end

    return state.activeTab or "equipment"
end
```

### Update `PlayerInventory.addCard()`
```lua
category = category or detectCardCategory(cardEntity, cardData)
```

---

## Files to Modify

| File | Changes |
|------|---------|
| `assets/scripts/ui/player_inventory.lua` | Sprite background, dynamic sizing, sort logic, category detection |
| `assets/scripts/ui/inventory_quick_equip.lua` | Add Ctrl+Click support |
| `assets/scripts/ui/inventory_grid_init.lua` | Verification only (no expected changes) |

---

## Test Plan (Updated)

| Test | Expected | Verify |
|------|----------|--------|
| Panel has sprite background | `inventory-back-panel.png` visible | Open inventory (I key) |
| Panel size = sprite × 2 | Correct dimensions | Measure/log `state.panelWidth` |
| Content fits in panel | Header, tabs, grid, footer visible | Visual check |
| Right-click equips (Win/Linux) | Card moves to wand | Right-click card |
| Ctrl+Click equips (Mac) | Card moves to wand | Ctrl+Left-click card |
| Drag card to empty slot | Card moves | Drag and drop |
| Drag card onto another card | Cards swap | Drag and drop |
| Click "Name" sort | Cards reorder A→Z (toggle Z→A on second click) | Click button twice |
| Click "Cost" sort | Cards reorder low→high (toggle high→low) | Click button twice |
| Add trigger card | Goes to Triggers tab | Add card via code |
| Add modifier card | Goes to Modifiers tab | Add card via code |
| Add unknown card | Goes to active tab | Add card via code |

### UI Validation (Required)
- Run `UIValidator.validate(state.panelEntity, nil, { skipHidden = true })`
- Fix any `containment` or `window_bounds` errors before shipping

---

## Implementation Order

1. **Task 2**: Add Ctrl+Click support (quick fix)
2. **Task 3**: Verify drag-drop (no changes expected)
3. **Task 4**: Implement sorting
4. **Task 5**: Implement auto-categorization
5. **Task 1**: Sprite background (requires asset + layout adjustments)

---

## Rollback Plan

If the sprite panel causes layout issues:
- Revert `createPanelDefinition()` to `dsl.strict.root` with color/emboss
- Keep Ctrl+Click and sort fixes (low risk)
