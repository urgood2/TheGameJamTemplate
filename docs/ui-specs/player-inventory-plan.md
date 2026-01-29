# Player Inventory System - Implementation Plan

**Status**: Planning  
**Created**: 2026-01-11  
**Target**: Replace world-space card inventory with UI grid system

---

## Overview

Replace the current world-space inventory boards in planning mode with a proper UI-based grid system using `dsl.inventoryGrid`. The new system will support:

- 4 tabbed categories (Equipment, Wands, Triggers, Actions)
- 7×3 grid (21 slots) per tab
- Drag-drop within inventory
- Drag-drop TO/FROM active planning boards
- Sprite panel backgrounds with decorations
- Sorting and filtering
- Card locking

---

## Quick Reference: Key Files to Study

Before implementing, review these files:

| File | Purpose | Key Patterns |
|------|---------|--------------|
| `examples/inventory_grid_demo.lua` | Complete working demo | Tab switching, card creation, grid setup |
| `ui/card_inventory_panel.lua` | Existing tabbed panel | Panel structure, sorting, locking |
| `core/inventory_grid.lua` | Grid API | `addItem`, `removeItem`, `findSlotContaining` |
| `ui/inventory_grid_init.lua` | Grid initialization | Slot setup, drop handling |
| `ui/sprite_ui_showcase.lua` | Sprite panels | `dsl.spritePanel`, decorations |
| `core/gameplay.lua:2140-2280` | Card creation | `createNewCard()`, shader setup |
| `core/gameplay.lua:5500-5700` | Board creation | `inventoryBoard`, `triggerInventoryBoard` |

---

## Visual Layout

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         PLANNING MODE SCREEN                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────┐  ┌───────────────────────────────────────────┐    │
│  │ TRIGGER BOARD   │  │ ACTION BOARD (World-Space)                │    │
│  │ (World-Space)   │  │                                           │    │
│  │ ┌─────────────┐ │  │ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐      │    │
│  │ │ [Trigger]   │ │  │ │Action│ │Action│ │ Mod  │ │ Mod  │ ...  │    │
│  │ └─────────────┘ │  │ └──────┘ └──────┘ └──────┘ └──────┘      │    │
│  └─────────────────┘  └───────────────────────────────────────────┘    │
│         ↑                              ↑                                │
│         │    DRAG CARDS BETWEEN        │                                │
│         ↓                              ↓                                │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ ╔═══════════════════════════════════════════════════════════╗   │   │
│  │ ║  PLAYER INVENTORY                               [Sort] [X]║   │   │
│  │ ╠═══════════════════════════════════════════════════════════╣   │   │
│  │ ║ [⚔ Equipment] [🪄 Wands] [⚡ Triggers] [🎴 Actions]       ║   │   │
│  │ ╠═══════════════════════════════════════════════════════════╣   │   │
│  │ ║ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐         ║   │   │
│  │ ║ │Card│ │Card│ │Card│ │Card│ │Card│ │Card│ │Card│  Row 1  ║   │   │
│  │ ║ └────┘ └────┘ └────┘ └────┘ └────┘ └────┘ └────┘         ║   │   │
│  │ ║ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐         ║   │   │
│  │ ║ │Card│ │Card│ │Card│ │    │ │    │ │    │ │    │  Row 2  ║   │   │
│  │ ║ └────┘ └────┘ └────┘ └────┘ └────┘ └────┘ └────┘         ║   │   │
│  │ ║ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐         ║   │   │
│  │ ║ │    │ │    │ │    │ │    │ │    │ │    │ │    │  Row 3  ║   │   │
│  │ ║ └────┘ └────┘ └────┘ └────┘ └────┘ └────┘ └────┘         ║   │   │
│  │ ╠═══════════════════════════════════════════════════════════╣   │   │
│  │ ║ [Name ↕] [Cost ↕]                    Slots: 9/21         ║   │   │
│  │ ╚═══════════════════════════════════════════════════════════╝   │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

---

# PHASE 1: Core Infrastructure

## Goal
Create the skeleton files and placeholder assets. Verify everything loads without errors.

---

## Step 1.1: Create `player_inventory.lua`

**File:** `assets/scripts/ui/player_inventory.lua`

```lua
--[[
================================================================================
PLAYER INVENTORY - Grid-Based Card Management for Planning Mode
================================================================================

Replaces the world-space inventory board with a proper UI grid system.

USAGE:
------
local PlayerInventory = require("ui.player_inventory")

PlayerInventory.open()           -- Show inventory panel
PlayerInventory.close()          -- Hide inventory panel
PlayerInventory.toggle()         -- Toggle visibility
PlayerInventory.addCard(entity, "actions")   -- Add card to category
PlayerInventory.removeCard(entity)           -- Remove card from inventory

EVENTS (via hump.signal):
-------------------------
"player_inventory_opened"        -- Panel opened
"player_inventory_closed"        -- Panel closed
"card_equipped_to_board"         -- Card moved from inventory to board
"card_returned_to_inventory"     -- Card moved from board to inventory

================================================================================
]]

local PlayerInventory = {}

--------------------------------------------------------------------------------
-- Dependencies
--------------------------------------------------------------------------------

local dsl = require("ui.ui_syntax_sugar")
local grid = require("core.inventory_grid")
local signal = require("external.hump.signal")
local component_cache = require("core.component_cache")
local timer = require("core.timer")
local InventoryGridInit = require("ui.inventory_grid_init")

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local TIMER_GROUP = "player_inventory"
local PANEL_ID = "player_inventory_panel"

-- Grid configuration: 7 columns × 3 rows = 21 slots per tab
local TAB_CONFIG = {
    equipment = {
        id = "inv_equipment",
        label = "Equipment",
        icon = "⚔",
        rows = 3,
        cols = 7,
    },
    wands = {
        id = "inv_wands",
        label = "Wands",
        icon = "🪄",
        rows = 3,
        cols = 7,
    },
    triggers = {
        id = "inv_triggers",
        label = "Triggers",
        icon = "⚡",
        rows = 3,
        cols = 7,
    },
    actions = {
        id = "inv_actions",
        label = "Actions",
        icon = "🎴",
        rows = 3,
        cols = 7,
    },
}

local TAB_ORDER = { "equipment", "wands", "triggers", "actions" }

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local state = {
    isOpen = false,
    panelEntity = nil,
    grids = {},                 -- { [tabId] = gridEntity }
    activeTab = "actions",      -- Default to actions tab
    searchFilter = "",
    sortField = nil,            -- "name" | "cost" | nil
    sortAsc = true,
    lockedCards = {},           -- Set of locked card entity IDs
    cardRegistry = {},          -- { [entityId] = cardData }
    signalHandlers = {},
    panelX = nil,
    panelY = nil,
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function getLocalizedText(key, fallback)
    if localization and localization.get then
        local text = localization.get(key)
        if text and text ~= key then
            return text
        end
    end
    return fallback or key
end

--------------------------------------------------------------------------------
-- Public API (Stubs for Phase 1)
--------------------------------------------------------------------------------

function PlayerInventory.open()
    log_debug("[PlayerInventory] open() called - NOT YET IMPLEMENTED")
    state.isOpen = true
    signal.emit("player_inventory_opened")
end

function PlayerInventory.close()
    log_debug("[PlayerInventory] close() called - NOT YET IMPLEMENTED")
    state.isOpen = false
    signal.emit("player_inventory_closed")
end

function PlayerInventory.toggle()
    if state.isOpen then
        PlayerInventory.close()
    else
        PlayerInventory.open()
    end
end

function PlayerInventory.isOpen()
    return state.isOpen
end

function PlayerInventory.addCard(cardEntity, category, cardData)
    log_debug("[PlayerInventory] addCard() called - NOT YET IMPLEMENTED")
    return false
end

function PlayerInventory.removeCard(cardEntity)
    log_debug("[PlayerInventory] removeCard() called - NOT YET IMPLEMENTED")
    return false
end

function PlayerInventory.getActiveTab()
    return state.activeTab
end

function PlayerInventory.getGrids()
    return state.grids
end

function PlayerInventory.getLockedCards()
    return state.lockedCards
end

--------------------------------------------------------------------------------
-- Module Init (called once on require)
--------------------------------------------------------------------------------

log_debug("[PlayerInventory] Module loaded")

return PlayerInventory
```

---

## Step 1.2: Create `card_space_converter.lua`

**File:** `assets/scripts/ui/card_space_converter.lua`

```lua
--[[
================================================================================
CARD SPACE CONVERTER
================================================================================

Converts card entities between screen-space (inventory UI) and world-space 
(planning boards).

USAGE:
------
local CardSpaceConverter = require("ui.card_space_converter")

-- When moving card FROM inventory TO board:
CardSpaceConverter.toWorldSpace(cardEntity)

-- When moving card FROM board TO inventory:
CardSpaceConverter.toScreenSpace(cardEntity)

COORDINATE SPACES:
-----------------
- Screen-space: Fixed to screen, ignores camera. Used for UI inventory.
  - Has ObjectAttachedToUITag
  - transform.set_space(entity, "screen")
  - Collision via UI quadtree

- World-space: Follows camera. Used for planning boards.
  - NO ObjectAttachedToUITag
  - transform.set_space(entity, "world")
  - Collision via world quadtree
  - Has PLANNING_STATE tag

================================================================================
]]

local CardSpaceConverter = {}

local component_cache = require("core.component_cache")

--------------------------------------------------------------------------------
-- Convert to World Space (Inventory → Board)
--------------------------------------------------------------------------------

--- Convert card from screen-space (inventory) to world-space (board)
--- @param cardEntity number Entity ID of the card
--- @return boolean success
function CardSpaceConverter.toWorldSpace(cardEntity)
    if not registry:valid(cardEntity) then 
        log_warn("[CardSpaceConverter] toWorldSpace: invalid entity")
        return false 
    end
    
    -- 1. Remove screen-space markers
    if ObjectAttachedToUITag and registry:has(cardEntity, ObjectAttachedToUITag) then
        registry:remove(cardEntity, ObjectAttachedToUITag)
    end
    
    -- 2. Set transform to world space
    if transform and transform.set_space then
        transform.set_space(cardEntity, "world")
    end
    
    -- 3. Update state tags for planning mode visibility
    if clear_state_tags then
        clear_state_tags(cardEntity)
    end
    if add_state_tag and PLANNING_STATE then
        add_state_tag(cardEntity, PLANNING_STATE)
    end
    if remove_default_state_tag then
        remove_default_state_tag(cardEntity)
    end
    
    -- 4. Ensure collision is enabled for world quadtree
    local go = component_cache.get(cardEntity, GameObject)
    if go then
        go.state.collisionEnabled = true
        go.state.dragEnabled = true
        go.state.hoverEnabled = true
    end
    
    log_debug("[CardSpaceConverter] Converted to world-space: " .. tostring(cardEntity))
    return true
end

--------------------------------------------------------------------------------
-- Convert to Screen Space (Board → Inventory)
--------------------------------------------------------------------------------

--- Convert card from world-space (board) to screen-space (inventory)
--- @param cardEntity number Entity ID of the card
--- @return boolean success
function CardSpaceConverter.toScreenSpace(cardEntity)
    if not registry:valid(cardEntity) then 
        log_warn("[CardSpaceConverter] toScreenSpace: invalid entity")
        return false 
    end
    
    -- 1. Add screen-space markers
    if ObjectAttachedToUITag and not registry:has(cardEntity, ObjectAttachedToUITag) then
        registry:emplace(cardEntity, ObjectAttachedToUITag)
    end
    
    -- 2. Set transform to screen space
    if transform and transform.set_space then
        transform.set_space(cardEntity, "screen")
    end
    
    -- 3. Update state tags (screen-space UI uses default_state)
    if clear_state_tags then
        clear_state_tags(cardEntity)
    end
    if add_state_tag then
        add_state_tag(cardEntity, "default_state")
    end
    
    -- 4. Ensure collision is enabled for UI quadtree
    local go = component_cache.get(cardEntity, GameObject)
    if go then
        go.state.collisionEnabled = true
        go.state.hoverEnabled = true
        go.state.dragEnabled = true
    end
    
    log_debug("[CardSpaceConverter] Converted to screen-space: " .. tostring(cardEntity))
    return true
end

--------------------------------------------------------------------------------
-- Utility: Check Current Space
--------------------------------------------------------------------------------

--- Check if card is in screen-space
--- @param cardEntity number Entity ID
--- @return boolean
function CardSpaceConverter.isScreenSpace(cardEntity)
    if not registry:valid(cardEntity) then return false end
    return ObjectAttachedToUITag and registry:has(cardEntity, ObjectAttachedToUITag)
end

--- Check if card is in world-space
--- @param cardEntity number Entity ID
--- @return boolean
function CardSpaceConverter.isWorldSpace(cardEntity)
    return not CardSpaceConverter.isScreenSpace(cardEntity)
end

return CardSpaceConverter
```

---

## Step 1.3: Create `player_inventory_bridge.lua`

**File:** `assets/scripts/ui/player_inventory_bridge.lua`

```lua
--[[
================================================================================
PLAYER INVENTORY BRIDGE
================================================================================

Handles drag-drop between PlayerInventory (screen-space) and Planning Boards 
(world-space). This is the "glue" that makes cards transferable between the 
two coordinate systems.

RESPONSIBILITIES:
----------------
1. Setup planning boards as drop targets for inventory cards
2. Handle drops from boards onto inventory
3. Coordinate with CardSpaceConverter for coordinate transforms
4. Emit signals for external systems

USAGE:
------
local Bridge = require("ui.player_inventory_bridge")

-- Call during planning phase initialization:
Bridge.setupBoardDropTargets(board_sets)

-- Call when inventory grid receives a drop:
Bridge.handleDropOnInventory(gridEntity, slotIndex, droppedEntity)

================================================================================
]]

local Bridge = {}

local CardSpaceConverter = require("ui.card_space_converter")
local grid = require("core.inventory_grid")
local signal = require("external.hump.signal")
local component_cache = require("core.component_cache")

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local registeredBoards = {}  -- { [boardId] = { acceptedCategories = {...} } }

--------------------------------------------------------------------------------
-- Board Drop Target Setup
--------------------------------------------------------------------------------

--- Setup a planning board to accept drops from inventory
--- @param boardEntity number The board entity ID
--- @param boardId number The board's ID (same as entity usually)
--- @param acceptedCategories table List of accepted card categories (e.g., {"trigger"})
function Bridge.setupBoardAsDropTarget(boardEntity, boardId, acceptedCategories)
    if not registry:valid(boardEntity) then
        log_warn("[Bridge] setupBoardAsDropTarget: invalid board entity")
        return
    end
    
    local go = component_cache.get(boardEntity, GameObject)
    if not go then
        log_warn("[Bridge] setupBoardAsDropTarget: board has no GameObject")
        return
    end
    
    -- Enable as drop target
    go.state.collisionEnabled = true
    go.state.triggerOnReleaseEnabled = true
    
    -- Store configuration
    registeredBoards[boardId] = {
        entity = boardEntity,
        acceptedCategories = acceptedCategories,
    }
    
    -- Set up onRelease handler
    go.methods.onRelease = function(reg, releasedOn, droppedEntity)
        Bridge.handleDropOnBoard(boardId, droppedEntity)
    end
    
    log_debug("[Bridge] Registered board " .. tostring(boardId) .. " as drop target for: " .. table.concat(acceptedCategories, ", "))
end

--- Setup all planning boards as drop targets
--- @param board_sets table Array of board sets from gameplay.lua
function Bridge.setupBoardDropTargets(board_sets)
    if not board_sets then
        log_warn("[Bridge] setupBoardDropTargets: no board_sets provided")
        return
    end
    
    for _, boardSet in ipairs(board_sets) do
        -- Trigger board accepts only triggers
        if boardSet.trigger_board_id then
            Bridge.setupBoardAsDropTarget(
                boardSet.trigger_board_id,
                boardSet.trigger_board_id,
                { "trigger" }
            )
        end
        
        -- Action board accepts actions and modifiers
        if boardSet.action_board_id then
            Bridge.setupBoardAsDropTarget(
                boardSet.action_board_id,
                boardSet.action_board_id,
                { "action", "modifier" }
            )
        end
    end
    
    log_debug("[Bridge] Setup drop targets for " .. #board_sets .. " board sets")
end

--------------------------------------------------------------------------------
-- Drop Handlers
--------------------------------------------------------------------------------

--- Handle a drop on a planning board (from inventory)
--- @param boardId number The board that received the drop
--- @param droppedEntity number The dropped card entity
function Bridge.handleDropOnBoard(boardId, droppedEntity)
    if not registry:valid(droppedEntity) then
        log_debug("[Bridge] handleDropOnBoard: invalid dropped entity")
        return
    end
    
    local boardConfig = registeredBoards[boardId]
    if not boardConfig then
        log_debug("[Bridge] handleDropOnBoard: board not registered")
        return
    end
    
    -- Get card data
    local script = getScriptTableFromEntityID(droppedEntity)
    if not script then
        log_debug("[Bridge] handleDropOnBoard: dropped entity has no script")
        return
    end
    
    -- Check if card category is accepted
    local category = script.category
    local accepted = false
    for _, cat in ipairs(boardConfig.acceptedCategories) do
        if cat == category then
            accepted = true
            break
        end
    end
    
    if not accepted then
        log_debug("[Bridge] handleDropOnBoard: rejected category " .. tostring(category))
        -- TODO: Snap card back to original position
        return
    end
    
    -- Check if card came from inventory (screen-space)
    if CardSpaceConverter.isScreenSpace(droppedEntity) then
        -- Card is from inventory - need to convert
        log_debug("[Bridge] Moving card from inventory to board " .. tostring(boardId))
        
        -- 1. Remove from inventory grid
        local PlayerInventory = require("ui.player_inventory")
        PlayerInventory.removeCard(droppedEntity)
        
        -- 2. Convert to world-space
        CardSpaceConverter.toWorldSpace(droppedEntity)
        
        -- 3. Add to board (uses existing gameplay.lua function)
        if addCardToBoard then
            addCardToBoard(droppedEntity, boardId)
        end
        
        -- 4. Emit event
        signal.emit("card_equipped_to_board", droppedEntity, boardId)
    else
        -- Card is already world-space (moving between boards)
        log_debug("[Bridge] Moving card between boards")
        -- Existing board-to-board logic in gameplay.lua handles this
    end
end

--- Handle a drop on inventory grid (from board)
--- @param gridEntity number The inventory grid entity
--- @param slotIndex number The slot that received the drop
--- @param droppedEntity number The dropped card entity
function Bridge.handleDropOnInventory(gridEntity, slotIndex, droppedEntity)
    if not registry:valid(droppedEntity) then
        log_debug("[Bridge] handleDropOnInventory: invalid dropped entity")
        return
    end
    
    -- Check if this card came from a planning board (world-space)
    if CardSpaceConverter.isWorldSpace(droppedEntity) then
        log_debug("[Bridge] Moving card from board to inventory")
        
        -- 1. Find which board it came from and remove it
        if findBoardContainingCard and removeCardFromBoard then
            local sourceBoard = findBoardContainingCard(droppedEntity)
            if sourceBoard then
                removeCardFromBoard(droppedEntity, sourceBoard)
            end
        end
        
        -- 2. Convert to screen-space
        CardSpaceConverter.toScreenSpace(droppedEntity)
        
        -- 3. Add to inventory grid
        local success = grid.addItem(gridEntity, droppedEntity, slotIndex)
        
        if success then
            -- 4. Center on slot
            local InventoryGridInit = require("ui.inventory_grid_init")
            local slotEntity = grid.getSlotEntity(gridEntity, slotIndex)
            if slotEntity then
                InventoryGridInit.centerItemOnSlot(droppedEntity, slotEntity)
            end
            
            -- 5. Emit event
            signal.emit("card_returned_to_inventory", droppedEntity)
            
            log_debug("[Bridge] Card moved from board to inventory slot " .. slotIndex)
        end
    else
        -- Card is already screen-space (moving within inventory)
        -- Standard grid handling applies (already handled by inventory_grid_init.lua)
    end
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

function Bridge.cleanup()
    registeredBoards = {}
    log_debug("[Bridge] Cleanup complete")
end

return Bridge
```

---

## Step 1.4: Create Placeholder Sprite Assets

Create simple colored rectangle images as placeholders. You can use any image editor.

**Directory:** `assets/sprites/ui/`

| File | Size | Color | Purpose |
|------|------|-------|---------|
| `inventory-panel-bg.png` | 64×64 | Dark purple (#2a1a3a) | Nine-patch background |
| `inventory-slot-bg.png` | 64×90 | Dark gray (#3a3a4a) | Slot background |
| `tab-button-normal.png` | 32×32 | Gray (#5a5a6a) | Tab normal state |
| `tab-button-hover.png` | 32×32 | Light gray (#7a7a8a) | Tab hover |
| `tab-button-active.png` | 32×32 | Blue (#4a6a9a) | Tab selected |

**Quick method:** Copy an existing test asset and rename it:
```bash
cd assets/sprites
cp ui-decor-test-1.png ui/inventory-panel-bg.png
cp ui-decor-test-2.png ui/inventory-slot-bg.png
cp button-test-normal.png ui/tab-button-normal.png
cp button-test-hover.png ui/tab-button-hover.png
cp button-test-pressed.png ui/tab-button-active.png
```

---

## Step 1.5: Test Phase 1

**Run the game and verify:**

1. No errors on startup related to the new files
2. In console, test:
   ```lua
   local PlayerInventory = require("ui.player_inventory")
   PlayerInventory.open()   -- Should print debug message
   PlayerInventory.close()  -- Should print debug message
   
   local Converter = require("ui.card_space_converter")
   print(Converter)  -- Should print table address
   
   local Bridge = require("ui.player_inventory_bridge")
   print(Bridge)  -- Should print table address
   ```

**Expected output:**
```
[PlayerInventory] Module loaded
[PlayerInventory] open() called - NOT YET IMPLEMENTED
[PlayerInventory] close() called - NOT YET IMPLEMENTED
```

### ✅ REVIEW CHECKPOINT: Verify files load without errors

---

# PHASE 2: Basic Panel

## Goal
Create the visible panel with tabs and grids. No card functionality yet.

---

## Step 2.1: Implement Panel Structure

Update `player_inventory.lua` with the full panel implementation:

```lua
-- Add these to player_inventory.lua, replacing the stub functions

--------------------------------------------------------------------------------
-- Grid Creation
--------------------------------------------------------------------------------

local function createGridForTab(tabId, x, y, visible)
    local cfg = TAB_CONFIG[tabId]
    if not cfg then return nil end
    
    local spawnX = visible and x or -9999  -- Offscreen if not visible
    
    local gridDef = dsl.inventoryGrid {
        id = cfg.id,
        rows = cfg.rows,
        cols = cfg.cols,
        slotSize = { w = 64, h = 90 },
        slotSpacing = 6,
        
        config = {
            allowDragIn = true,
            allowDragOut = true,
            stackable = false,
            slotColor = "purple_slate",
            slotEmboss = 2,
            padding = 8,
            backgroundColor = "blackberry",
        },
        
        onSlotChange = function(gridEntity, slotIndex, oldItem, newItem)
            log_debug("[PlayerInventory:" .. tabId .. "] Slot " .. slotIndex .. " changed")
        end,
        
        onSlotClick = function(gridEntity, slotIndex, button)
            -- Right-click to toggle lock
            if button == 2 then
                local item = grid.getItemAtIndex(gridEntity, slotIndex)
                if item and registry:valid(item) then
                    local isLocked = state.lockedCards[item]
                    state.lockedCards[item] = not isLocked
                    signal.emit(isLocked and "card_unlocked" or "card_locked", item)
                    log_debug("[PlayerInventory] Card " .. (isLocked and "unlocked" or "locked"))
                end
            end
        end,
    }
    
    local gridEntity = dsl.spawn({ x = spawnX, y = y }, gridDef, "ui", 150)
    if ui and ui.box and ui.box.set_draw_layer then
        ui.box.set_draw_layer(gridEntity, "ui")
    end
    
    local success = InventoryGridInit.initializeIfGrid(gridEntity, cfg.id)
    if success then
        log_debug("[PlayerInventory] Grid '" .. tabId .. "' initialized")
    else
        log_warn("[PlayerInventory] Grid '" .. tabId .. "' init failed!")
    end
    
    return gridEntity
end

--------------------------------------------------------------------------------
-- Tab Switching
--------------------------------------------------------------------------------

local function setGridVisible(gridEntity, visible, onscreenX)
    if not gridEntity or not registry:valid(gridEntity) then return end
    local t = component_cache.get(gridEntity, Transform)
    if t then
        t.actualX = visible and onscreenX or -9999
    end
end

local function switchTab(tabId)
    if state.activeTab == tabId then return end
    
    local oldTab = state.activeTab
    state.activeTab = tabId
    
    -- Hide all grids except the active one
    for id, gridEntity in pairs(state.grids) do
        local isActive = (id == tabId)
        setGridVisible(gridEntity, isActive, state.gridX)
    end
    
    -- Update tab button colors
    for id, btnEntity in pairs(state.tabButtons or {}) do
        if btnEntity and registry:valid(btnEntity) then
            local isActive = (id == tabId)
            local uiCfg = component_cache.get(btnEntity, UIConfig)
            if uiCfg then
                uiCfg.color = isActive and util.getColor("steel_blue") or util.getColor("gray")
            end
        end
    end
    
    log_debug("[PlayerInventory] Switched tab: " .. oldTab .. " -> " .. tabId)
end

--------------------------------------------------------------------------------
-- UI Creation Functions
--------------------------------------------------------------------------------

local function createHeader()
    return dsl.hbox {
        config = {
            color = "dark_lavender",
            padding = { 12, 8 },
            emboss = 2,
        },
        children = {
            dsl.text(getLocalizedText("ui.player_inventory.title", "Inventory"), {
                fontSize = 18,
                color = "gold",
                shadow = true,
            }),
            dsl.spacer(1), -- flex spacer
            dsl.button("✕", {
                id = "close_btn",
                minWidth = 28,
                minHeight = 28,
                fontSize = 16,
                color = "darkred",
                hover = true,
                onClick = function()
                    PlayerInventory.close()
                end,
            }),
        },
    }
end

local function createTabs()
    local tabChildren = {}
    state.tabButtons = state.tabButtons or {}
    
    for _, tabId in ipairs(TAB_ORDER) do
        local cfg = TAB_CONFIG[tabId]
        local isActive = (tabId == state.activeTab)
        local label = cfg.icon .. " " .. getLocalizedText("ui.player_inventory.tab_" .. tabId, cfg.label)
        
        table.insert(tabChildren, dsl.button(label, {
            id = "tab_" .. tabId,
            minWidth = 100,
            minHeight = 32,
            fontSize = 11,
            color = isActive and "steel_blue" or "gray",
            hover = true,
            onClick = function()
                switchTab(tabId)
            end,
        }))
        
        if tabId ~= TAB_ORDER[#TAB_ORDER] then
            table.insert(tabChildren, dsl.spacer(2))
        end
    end
    
    return dsl.hbox {
        config = {
            color = "blackberry",
            padding = 4,
        },
        children = tabChildren,
    }
end

local function createFooter()
    return dsl.hbox {
        config = {
            color = "dark_lavender",
            padding = 8,
        },
        children = {
            dsl.button(getLocalizedText("ui.player_inventory.sort_name", "Name") .. " ↕", {
                id = "sort_name_btn",
                minWidth = 60,
                minHeight = 24,
                fontSize = 11,
                color = "purple_slate",
                hover = true,
                onClick = function()
                    -- TODO: Implement sorting in Phase 3
                    log_debug("[PlayerInventory] Sort by name clicked")
                end,
            }),
            dsl.spacer(4),
            dsl.button(getLocalizedText("ui.player_inventory.sort_cost", "Cost") .. " ↕", {
                id = "sort_cost_btn",
                minWidth = 60,
                minHeight = 24,
                fontSize = 11,
                color = "purple_slate",
                hover = true,
                onClick = function()
                    -- TODO: Implement sorting in Phase 3
                    log_debug("[PlayerInventory] Sort by cost clicked")
                end,
            }),
            dsl.spacer(1), -- flex
            dsl.dynamicText(function()
                local activeGrid = state.grids[state.activeTab]
                if activeGrid then
                    local used = grid.getUsedSlotCount(activeGrid) or 0
                    local total = grid.getCapacity(activeGrid) or 21
                    return used .. " / " .. total
                end
                return "0 / 21"
            end, 11, nil, { color = "light_gray" }),
        },
    }
end

local function createPanelDefinition()
    return dsl.root {
        config = {
            id = PANEL_ID,
            color = "blackberry",
            padding = 0,
            emboss = 3,
            minWidth = 540,  -- 7 slots × 70px + padding
        },
        children = {
            createHeader(),
            createTabs(),
            -- Grid content area (placeholder - actual grids are separate entities)
            dsl.vbox {
                config = {
                    padding = 8,
                    minHeight = 310,  -- 3 rows × ~96px + padding
                    color = "blackberry",
                },
                children = {
                    dsl.text("", { fontSize = 1 }), -- Invisible placeholder
                },
            },
            createFooter(),
        },
    }
end

--------------------------------------------------------------------------------
-- Public API (Full Implementation)
--------------------------------------------------------------------------------

function PlayerInventory.open()
    if state.isOpen then return end
    
    local screenW = globals.screenWidth()
    local screenH = globals.screenHeight()
    
    -- Position at bottom-center of screen
    state.panelX = (screenW - 540) / 2
    state.panelY = screenH - 420
    state.gridX = state.panelX + 10
    state.gridY = state.panelY + 80
    
    -- Create main panel UI
    local panelDef = createPanelDefinition()
    state.panelEntity = dsl.spawn({ x = state.panelX, y = state.panelY }, panelDef, "ui", 100)
    
    if ui and ui.box and ui.box.set_draw_layer then
        ui.box.set_draw_layer(state.panelEntity, "ui")
    end
    
    -- Store tab button entities for later color updates
    state.tabButtons = {}
    for _, tabId in ipairs(TAB_ORDER) do
        local btnEntity = ui.box.GetUIEByID(registry, state.panelEntity, "tab_" .. tabId)
        if btnEntity then
            state.tabButtons[tabId] = btnEntity
        end
    end
    
    -- Create grids for each tab
    for _, tabId in ipairs(TAB_ORDER) do
        local visible = (tabId == state.activeTab)
        local gridEntity = createGridForTab(tabId, state.gridX, state.gridY, visible)
        state.grids[tabId] = gridEntity
    end
    
    state.isOpen = true
    signal.emit("player_inventory_opened")
    
    if playSoundEffect then
        playSoundEffect("effects", "button-click")
    end
    
    log_debug("[PlayerInventory] Opened successfully")
end

function PlayerInventory.close()
    if not state.isOpen then return end
    
    log_debug("[PlayerInventory] Closing...")
    
    -- Kill timers
    timer.kill_group(TIMER_GROUP)
    
    -- Destroy grids
    for tabId, gridEntity in pairs(state.grids) do
        if gridEntity and registry:valid(gridEntity) then
            local cfg = TAB_CONFIG[tabId]
            if cfg then
                grid.cleanup(gridEntity)
                dsl.cleanupGrid(cfg.id)
            end
            if ui and ui.box and ui.box.Remove then
                ui.box.Remove(registry, gridEntity)
            end
        end
    end
    state.grids = {}
    state.tabButtons = {}
    
    -- Destroy panel
    if state.panelEntity and registry:valid(state.panelEntity) then
        if ui and ui.box and ui.box.Remove then
            ui.box.Remove(registry, state.panelEntity)
        end
    end
    state.panelEntity = nil
    
    state.isOpen = false
    signal.emit("player_inventory_closed")
    
    log_debug("[PlayerInventory] Closed")
end
```

---

## Step 2.2: Test Phase 2

**Run the game and test in console:**

```lua
local PlayerInventory = require("ui.player_inventory")
PlayerInventory.open()
```

**Verify:**
1. Panel appears at bottom-center of screen
2. 4 tabs visible (Equipment, Wands, Triggers, Actions)
3. Clicking tabs switches between them (grid moves, colors change)
4. Close button (✕) works
5. Sort buttons are visible (not functional yet)
6. Slot counter shows "0 / 21"

**To close:**
```lua
PlayerInventory.close()
```

### ✅ REVIEW CHECKPOINT: Verify panel renders and tabs switch

---

# PHASE 3: Inventory Operations

## Goal
Add drag-drop, sorting, locking functionality within the inventory.

---

## Step 3.1: Add Card Rendering Timer

Add to `player_inventory.lua`:

```lua
--------------------------------------------------------------------------------
-- Card Rendering Timer
--------------------------------------------------------------------------------

local function setupCardRenderTimer()
    local UI_CARD_Z = (z_orders and z_orders.ui_tooltips or 900) + 500
    local shader_pipeline = _G.shader_pipeline
    
    timer.run_every_render_frame(function()
        if not state.isOpen then return end
        
        local activeGrid = state.grids[state.activeTab]
        if not activeGrid then return end
        
        -- Snap items to slots
        local inputState = input and input.getState and input.getState()
        local draggedEntity = inputState and inputState.cursor_dragging_target
        
        local items = grid.getAllItems(activeGrid)
        for slotIndex, itemEntity in pairs(items) do
            if itemEntity and registry:valid(itemEntity) and itemEntity ~= draggedEntity then
                local slotEntity = grid.getSlotEntity(activeGrid, slotIndex)
                if slotEntity then
                    InventoryGridInit.centerItemOnSlot(itemEntity, slotEntity)
                end
            end
        end
        
        -- Batch render cards with shader pipeline
        if not (command_buffer and command_buffer.queueDrawBatchedEntities and layers and layers.ui) then
            return
        end
        
        local cardList = {}
        for slotIndex, itemEntity in pairs(items) do
            if itemEntity and registry:valid(itemEntity) then
                local animComp = component_cache.get(itemEntity, AnimationQueueComponent)
                if animComp then
                    animComp.drawWithLegacyPipeline = false
                    table.insert(cardList, itemEntity)
                end
            end
        end
        
        if #cardList > 0 then
            local z = UI_CARD_Z
            -- Dragged card renders on top
            if draggedEntity and state.cardRegistry[draggedEntity] then
                z = UI_CARD_Z + 100
            end
            
            command_buffer.queueDrawBatchedEntities(layers.ui, function(cmd)
                cmd.registry = registry
                cmd.entities = cardList
                cmd.autoOptimize = true
            end, z, layer.DrawCommandSpace.Screen)
        end
    end, nil, "player_inventory_render", TIMER_GROUP)
end
```

---

## Step 3.2: Add Sorting Implementation

Add to `player_inventory.lua`:

```lua
--------------------------------------------------------------------------------
-- Sorting
--------------------------------------------------------------------------------

local function getCardData(entity)
    if state.cardRegistry[entity] then
        return state.cardRegistry[entity]
    end
    if getScriptTableFromEntityID then
        return getScriptTableFromEntityID(entity)
    end
    return nil
end

local function applySorting()
    local activeGrid = state.grids[state.activeTab]
    if not state.sortField or not activeGrid then return end
    
    local cfg = TAB_CONFIG[state.activeTab]
    local maxSlots = cfg.rows * cfg.cols
    
    local items = grid.getItemList(activeGrid)
    if not items or #items == 0 then return end
    
    -- Collect items with their data (skip locked cards)
    local itemsWithData = {}
    for _, itemEntry in ipairs(items) do
        local entity = itemEntry.item
        if not state.lockedCards[entity] then
            local cardData = getCardData(entity)
            table.insert(itemsWithData, {
                entity = entity,
                slotIndex = itemEntry.slot,
                name = cardData and cardData.name or "",
                cost = cardData and (cardData.manaCost or cardData.cost or 0) or 0,
            })
        end
    end
    
    -- Sort
    local sortKey = state.sortField
    local ascending = state.sortAsc
    
    table.sort(itemsWithData, function(a, b)
        local valA = a[sortKey] or ""
        local valB = b[sortKey] or ""
        if ascending then
            return valA < valB
        else
            return valA > valB
        end
    end)
    
    -- Remove all unlocked items
    for _, item in ipairs(itemsWithData) do
        grid.removeItem(activeGrid, item.slotIndex)
    end
    
    -- Re-add in sorted order
    local targetSlot = 1
    for _, item in ipairs(itemsWithData) do
        while targetSlot <= maxSlots do
            local existingItem = grid.getItemAtIndex(activeGrid, targetSlot)
            if not existingItem then
                break
            end
            targetSlot = targetSlot + 1
        end
        if targetSlot <= maxSlots then
            grid.addItem(activeGrid, item.entity, targetSlot)
            targetSlot = targetSlot + 1
        end
    end
    
    signal.emit("inventory_sorted", state.activeTab, state.sortField, state.sortAsc)
    log_debug("[PlayerInventory] Sorted by " .. sortKey)
end

local function toggleSort(sortKey)
    if state.sortField == sortKey then
        state.sortAsc = not state.sortAsc
    else
        state.sortField = sortKey
        state.sortAsc = true
    end
    applySorting()
end
```

Then update the footer sort buttons to call `toggleSort`:

```lua
-- In createFooter(), update the onClick handlers:
onClick = function()
    toggleSort("name")
end,
-- and
onClick = function()
    toggleSort("cost")
end,
```

---

## Step 3.3: Add Dummy Card Spawning for Testing

Add to `player_inventory.lua`:

```lua
--------------------------------------------------------------------------------
-- Dummy Card Creation (for testing)
--------------------------------------------------------------------------------

local function createDummyCard(spriteName, cardData)
    local shader_pipeline = _G.shader_pipeline
    
    local entity = animation_system.createAnimatedObjectWithTransform(
        spriteName, true, 0, 0, nil, true
    )
    
    if not entity or not registry:valid(entity) then
        log_warn("[PlayerInventory] Failed to create dummy card")
        return nil
    end
    
    animation_system.resizeAnimationObjectsInEntityToFit(entity, 60, 84)
    
    if add_state_tag then
        add_state_tag(entity, "default_state")
    end
    
    if layer_order_system and layer_order_system.assignZIndexToEntity then
        local z = (z_orders and z_orders.ui_tooltips or 800) + 500
        layer_order_system.assignZIndexToEntity(entity, z)
    end
    
    -- Screen-space setup
    if ObjectAttachedToUITag and not registry:has(entity, ObjectAttachedToUITag) then
        registry:emplace(entity, ObjectAttachedToUITag)
    end
    
    if transform and transform.set_space then
        transform.set_space(entity, "screen")
    end
    
    -- Enable drag
    local go = component_cache.get(entity, GameObject)
    if go then
        go.state.dragEnabled = true
        go.state.collisionEnabled = true
        go.state.hoverEnabled = true
    end
    
    -- Add shader
    if shader_pipeline and shader_pipeline.ShaderPipelineComponent then
        local shaderComp = registry:emplace(entity, shader_pipeline.ShaderPipelineComponent)
        shaderComp:addPass("3d_skew")
        
        local skewSeed = math.random() * 10000
        local passes = shaderComp.passes
        if passes and #passes >= 1 then
            local pass = passes[#passes]
            if pass and pass.shaderName and pass.shaderName:sub(1, 7) == "3d_skew" then
                pass.customPrePassFunction = function()
                    if globalShaderUniforms then
                        globalShaderUniforms:set(pass.shaderName, "rand_seed", skewSeed)
                    end
                end
            end
        end
    end
    
    -- Store card data
    state.cardRegistry[entity] = cardData
    
    if setScriptTableForEntityID then
        setScriptTableForEntityID(entity, cardData)
    end
    
    return entity
end

--- Spawn dummy cards for testing (call after open())
function PlayerInventory.spawnDummyCards()
    if not state.isOpen then
        log_warn("[PlayerInventory] Must open inventory before spawning dummy cards")
        return
    end
    
    local dummyCards = {
        { sprite = "card-new-test-action.png", name = "Fireball", manaCost = 12, category = "action" },
        { sprite = "card-new-test-action.png", name = "Ice Shard", manaCost = 8, category = "action" },
        { sprite = "card-new-test-action.png", name = "Lightning", manaCost = 15, category = "action" },
        { sprite = "card-new-test-action.png", name = "Heal", manaCost = 5, category = "action" },
        { sprite = "card-new-test-trigger.png", name = "On Hit", manaCost = 5, category = "trigger" },
        { sprite = "card-new-test-trigger.png", name = "On Kill", manaCost = 10, category = "trigger" },
        { sprite = "card-new-test-modifier.png", name = "Damage Up", manaCost = 3, category = "action" },
    }
    
    for _, cardDef in ipairs(dummyCards) do
        local entity = createDummyCard(cardDef.sprite, cardDef)
        if entity then
            -- Add to actions tab for testing
            local gridEntity = state.grids["actions"]
            if gridEntity then
                grid.addItem(gridEntity, entity)
            end
        end
    end
    
    log_debug("[PlayerInventory] Spawned " .. #dummyCards .. " dummy cards")
end
```

---

## Step 3.4: Setup Signal Handlers and Render Timer

Update `PlayerInventory.open()` to call setup functions:

```lua
-- Add at the end of PlayerInventory.open(), before the success log:

    -- Setup card render timer
    setupCardRenderTimer()
    
    -- Setup signal handlers
    setupSignalHandlers()
```

And add the signal handler setup:

```lua
--------------------------------------------------------------------------------
-- Signal Handlers
--------------------------------------------------------------------------------

local function setupSignalHandlers()
    local function registerHandler(eventName, handler)
        signal.register(eventName, handler)
        table.insert(state.signalHandlers, { event = eventName, handler = handler })
    end
    
    local function isOurGrid(gridEntity)
        for _, ge in pairs(state.grids) do
            if ge == gridEntity then return true end
        end
        return false
    end
    
    registerHandler("grid_item_added", function(gridEntity, slotIndex, itemEntity)
        if isOurGrid(gridEntity) then
            log_debug("[PlayerInventory] Card added to slot " .. slotIndex)
            if playSoundEffect then
                playSoundEffect("effects", "button-click")
            end
        end
    end)
    
    registerHandler("grid_item_removed", function(gridEntity, slotIndex, itemEntity)
        if isOurGrid(gridEntity) then
            log_debug("[PlayerInventory] Card removed from slot " .. slotIndex)
        end
    end)
    
    registerHandler("grid_item_moved", function(gridEntity, fromSlot, toSlot, itemEntity)
        if isOurGrid(gridEntity) then
            log_debug("[PlayerInventory] Card moved: " .. fromSlot .. " -> " .. toSlot)
        end
    end)
end

local function cleanupSignalHandlers()
    for _, entry in ipairs(state.signalHandlers) do
        if entry.event and entry.handler then
            signal.remove(entry.event, entry.handler)
        end
    end
    state.signalHandlers = {}
end
```

Update `PlayerInventory.close()` to cleanup signal handlers:

```lua
-- Add at the start of PlayerInventory.close(), after the guard:
    cleanupSignalHandlers()
```

---

## Step 3.5: Test Phase 3

**Run the game and test:**

```lua
local PlayerInventory = require("ui.player_inventory")
PlayerInventory.open()
PlayerInventory.spawnDummyCards()
```

**Verify:**
1. Dummy cards appear in the Actions tab
2. Cards can be dragged between slots
3. Clicking "Name ↕" sorts cards alphabetically
4. Clicking "Cost ↕" sorts cards by mana cost
5. Slot counter updates (e.g., "7 / 21")
6. Right-clicking a card shows "locked" debug message

### ✅ REVIEW CHECKPOINT: Test drag-drop/sorting/locking

---

# PHASE 4: Board Integration

## Goal
Enable drag-drop between inventory (screen-space) and planning boards (world-space).

---

## Step 4.1: Update Bridge to Handle Bidirectional Drops

The `player_inventory_bridge.lua` is already set up. Now we need to:

1. Hook the bridge into the inventory's drop handler
2. Setup boards as drop targets during planning init

---

## Step 4.2: Modify Inventory Grid Init to Use Bridge

Update `ui/inventory_grid_init.lua` to check for world-space cards:

Find the `handleItemDrop` function and add bridge handling:

```lua
-- In handleItemDrop, after the existing logic:

-- Check if this is a world-space card being dropped
local Bridge = require("ui.player_inventory_bridge")
local CardSpaceConverter = require("ui.card_space_converter")

if CardSpaceConverter.isWorldSpace(droppedEntity) then
    Bridge.handleDropOnInventory(gridEntity, slotIndex, droppedEntity)
    return
end
```

---

## Step 4.3: Setup Boards During Planning Init

In `core/gameplay.lua`, find `initPlanningPhase()` and add:

```lua
-- After board creation (around line 5700+):

-- Setup bridge for inventory ↔ board drag-drop
local Bridge = require("ui.player_inventory_bridge")
Bridge.setupBoardDropTargets(board_sets)
```

---

## Step 4.4: Test Phase 4

**Run the game, enter planning mode, then test:**

```lua
-- First, open inventory and spawn test cards
local PlayerInventory = require("ui.player_inventory")
PlayerInventory.open()
PlayerInventory.spawnDummyCards()
```

**Verify:**
1. Drag a card from inventory grid toward an action board
2. Card should convert to world-space and appear on board
3. Drag a card from board toward inventory
4. Card should convert to screen-space and appear in inventory slot
5. Check console for debug messages confirming conversions

### ✅ REVIEW CHECKPOINT: Test dragging cards between inventory and boards in both directions

---

# PHASE 5: Planning Mode Integration

## Goal
Replace the old inventory boards with the new PlayerInventory system.

---

## Step 5.1: Modify `initPlanningPhase()` 

In `core/gameplay.lua`, find where `inventory_board_id` is created and:

1. Comment out or remove the old board creation
2. Add PlayerInventory initialization
3. Populate with player cards

```lua
-- Replace the inventory board creation section with:

-- Create new PlayerInventory UI
local PlayerInventory = require("ui.player_inventory")
PlayerInventory.open()

-- Populate with player's cards
local playerCards = globals.player and globals.player.cards or {}
for _, cardId in ipairs(playerCards) do
    -- Determine category from card definition
    local cardDef = WandEngine.card_defs[cardId] or WandEngine.trigger_card_defs[cardId]
    local category = "actions"  -- default
    if WandEngine.trigger_card_defs[cardId] then
        category = "triggers"
    end
    
    -- Create card entity for inventory (screen-space)
    local card = createNewCard(cardId, 0, 0, nil)  -- Will be positioned by grid
    
    -- Convert to screen-space
    local CardSpaceConverter = require("ui.card_space_converter")
    CardSpaceConverter.toScreenSpace(card)
    
    -- Add to inventory
    PlayerInventory.addCard(card, category)
end
```

---

## Step 5.2: Implement `addCard` and `removeCard`

Update `player_inventory.lua` with full implementations:

```lua
function PlayerInventory.addCard(cardEntity, category, cardData)
    if not cardEntity or not registry:valid(cardEntity) then
        return false
    end
    
    local gridEntity = state.grids[category]
    if not gridEntity then
        log_warn("[PlayerInventory] Unknown category: " .. tostring(category))
        return false
    end
    
    -- Cache card data
    if cardData then
        state.cardRegistry[cardEntity] = cardData
    end
    
    -- Ensure screen-space setup
    local CardSpaceConverter = require("ui.card_space_converter")
    if CardSpaceConverter.isWorldSpace(cardEntity) then
        CardSpaceConverter.toScreenSpace(cardEntity)
    end
    
    -- Enable drag
    local go = component_cache.get(cardEntity, GameObject)
    if go then
        go.state.dragEnabled = true
        go.state.collisionEnabled = true
        go.state.hoverEnabled = true
    end
    
    -- Add to grid
    local success, slotIndex = grid.addItem(gridEntity, cardEntity)
    if success then
        log_debug("[PlayerInventory] Added card to " .. category .. " slot " .. tostring(slotIndex))
    end
    return success
end

function PlayerInventory.removeCard(cardEntity)
    for tabId, gridEntity in pairs(state.grids) do
        local slotIndex = grid.findSlotContaining(gridEntity, cardEntity)
        if slotIndex then
            grid.removeItem(gridEntity, slotIndex)
            state.cardRegistry[cardEntity] = nil
            state.lockedCards[cardEntity] = nil
            log_debug("[PlayerInventory] Removed card from " .. tabId)
            return true
        end
    end
    return false
end
```

---

## Step 5.3: Test Phase 5

**Run the game, start a new game to trigger planning phase:**

**Verify:**
1. New inventory panel appears automatically
2. Player's cards are populated in correct tabs
3. Old inventory board is hidden/removed
4. Cards can still be dragged to active boards
5. Game state is preserved when moving cards

### ✅ REVIEW CHECKPOINT: Verify inventory auto-populates with player cards

---

# PHASE 6: Visual Polish

## Goal
Add animations, final sprites, and visual feedback.

---

## Step 6.1: Create Final Sprite Assets

Replace placeholder sprites with properly designed assets:

| Asset | Description |
|-------|-------------|
| `inventory-panel-bg.png` | Dark themed nine-patch panel |
| `inventory-slot-bg.png` | Subtle slot background |
| `tab-button-*.png` | Themed tab buttons |
| Corner ornaments | Decorative corners |

---

## Step 6.2: Add Slide-In Animation

```lua
-- In PlayerInventory.open(), add animation:

local targetY = state.panelY
local startY = globals.screenHeight() + 50  -- Start offscreen

-- Set initial position
local t = component_cache.get(state.panelEntity, Transform)
if t then
    t.actualY = startY
end

-- Animate to target
timer.after_opts({
    delay = 0.01,
    tag = "slide_in",
    group = TIMER_GROUP,
    action = function()
        local duration = 0.3
        local elapsed = 0
        timer.every_opts({
            delay = 0.016,
            tag = "slide_in_tick",
            group = TIMER_GROUP,
            action = function()
                elapsed = elapsed + 0.016
                local progress = math.min(elapsed / duration, 1)
                -- Ease out
                local eased = 1 - math.pow(1 - progress, 3)
                local currentY = startY + (targetY - startY) * eased
                
                local t = component_cache.get(state.panelEntity, Transform)
                if t then
                    t.actualY = currentY
                end
                
                -- Update grid positions too
                for _, gridEntity in pairs(state.grids) do
                    local gt = component_cache.get(gridEntity, Transform)
                    if gt and gt.actualX > 0 then  -- Only visible grid
                        gt.actualY = currentY + 80
                    end
                end
                
                if progress >= 1 then
                    timer.cancel("slide_in_tick")
                end
            end,
        })
    end,
})
```

---

## Step 6.3: Add Hover Effects on Slots

Add slot hover overlay rendering in the card render timer.

---

## Step 6.4: Test Phase 6

**Verify:**
1. Panel slides in from bottom when opened
2. Sprite backgrounds look correct
3. Hover effects work on slots
4. Cards render with 3D skew shader

### ✅ REVIEW CHECKPOINT: Verify visual polish and animations

---

# PHASE 7: Testing Checklist

## Functional Tests

- [ ] Drag within inventory (same tab)
- [ ] Drag inventory → trigger board
- [ ] Drag inventory → action board  
- [ ] Drag trigger board → inventory
- [ ] Drag action board → inventory
- [ ] Test with empty inventory
- [ ] Test with full inventory (21 cards per tab)
- [ ] Sorting preserves locked cards
- [ ] Card tooltips work
- [ ] Tab switching preserves cards

## Edge Cases

- [ ] Drag to occupied slot (should swap)
- [ ] Drag to locked slot (should reject)
- [ ] Multiple rapid tab switches
- [ ] Opening/closing inventory multiple times
- [ ] Cards persist after combat phase

### ✅ FINAL REVIEW: Full playthrough of planning mode with new inventory system

---

# Appendix: Complete File Listing

After all phases, you should have:

```
assets/scripts/ui/
├── player_inventory.lua           # ~500 lines
├── card_space_converter.lua       # ~100 lines
├── player_inventory_bridge.lua    # ~150 lines
├── inventory_grid_init.lua        # EXISTING (modified)
└── ...

assets/sprites/ui/
├── inventory-panel-bg.png
├── inventory-slot-bg.png
├── tab-button-normal.png
├── tab-button-hover.png
├── tab-button-active.png
└── ...
```

---

# Troubleshooting

## Cards don't appear in inventory
- Check `ObjectAttachedToUITag` is added
- Verify `transform.set_space(entity, "screen")`
- Check render timer is running

## Cards can't be dragged
- Verify `go.state.dragEnabled = true`
- Check `go.state.collisionEnabled = true`
- Ensure card has `GameObject` component

## Cards don't transfer to boards
- Check board is registered as drop target
- Verify card category matches accepted categories
- Check `CardSpaceConverter` is converting properly

## Sorting doesn't work
- Verify cards have `name` or `manaCost` in their script table
- Check `state.sortField` is being set
- Ensure locked cards are being skipped

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
