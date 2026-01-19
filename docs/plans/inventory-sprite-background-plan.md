# Plan: Inventory Panel Sprite Background + Right-Click Fix

**Created**: 2026-01-19
**Status**: Ready for implementation

## Overview

Two related tasks for the player inventory panel:
1. Use a sprite as the panel background (2x scaling, dynamic dimensions)
2. Fix right-click to equip cards to wand (not working on Mac)

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
