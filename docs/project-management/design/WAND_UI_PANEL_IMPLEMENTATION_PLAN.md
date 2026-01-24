# Wand UI Panel Implementation Plan

## Executive Summary

Create a new **Wand UI Panel** that moves the trigger/action board functionality from world-space (gameplay.lua) into a proper screen-space UI panel, following the architecture patterns from `player_inventory.lua`. The world-space boards will be isolated/commented out.

---

## Requirements Summary

| Aspect | Decision |
|--------|----------|
| **Panel Type** | Separate panel from inventory, keybind: `E` |
| **Position** | Top of screen, tabs hang down from left side |
| **Multi-Wand** | Tabs stick out LEFT side of panel (folder-tab style) |
| **Grid Structure** | Separate trigger grid + action grid per wand |
| **Trigger Slots** | **Single slot (1)** for trigger card (matches current `wand_grid_adapter.lua` + `WandExecutor` assumptions). Multi-trigger would require engine + adapter changes. |
| **Action Slots** | Dynamic based on `wand_def.total_card_slots` (range: 3-10 in templates) |
| **Card Transfer** | Both drag-drop AND right-click quick equip |
| **Closed State** | Nothing visible (E key to open) |
| **Sync** | Real-time with WandExecutor via wandAdapter |
| **Card Removal** | Auto-return to inventory |
| **Stats Display** | Show wand stats in panel header/footer |
| **Tab Style** | DSL button tabs with wand icons/numbers |
| **World Boards** | Comment out in gameplay.lua |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         TOP OF SCREEN                           │
├────┬────────────────────────────────────────────────────────────┤
│ W1 │  ┌─────────────────────────────────────────────────────┐   │
├────┤  │  Wand 1 - Fire Staff            [Cast: 0.2s] [X]   │   │
│ W2 │  ├─────────────────────────────────────────────────────┤   │
├────┤  │  TRIGGER                                             │   │
│ W3 │  │  ┌──────┐                                             │   │
├────┘  │  │      │  (single trigger slot)                       │   │
        │  └──────┘                                             │   │
        ├─────────────────────────────────────────────────────┤   │
        │  ACTIONS                                             │   │
        │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                │   │
        │  │  1   │ │  2   │ │  3   │ │  4   │                │   │
        │  └──────┘ └──────┘ └──────┘ └──────┘                │   │
        │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                │   │
        │  │  5   │ │  6   │ │  7   │ │  8   │                │   │
        │  └──────┘ └──────┘ └──────┘ └──────┘                │   │
        └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

**Key Structural Elements:**
- **Wand Tabs**: DSL buttons positioned to LEFT of main panel, vertically stacked
- **Main Panel**: Contains header (title + stats), trigger section, action section
- **Grids**: Use `dsl.strict.inventoryGrid` pattern from player_inventory.lua

---

## File Structure

```
assets/scripts/ui/
├── wand_panel.lua              # NEW - Main wand UI panel module
├── wand_panel_tabs.lua         # NEW - Tab management (optional split)
├── player_inventory.lua        # Reference implementation (1554 lines)
├── wand_loadout_ui.lua         # EXISTING - current wand loadout UI (reference / replacement target)
├── wand_grid_adapter.lua       # REUSE - Sync with WandExecutor (699 lines)
└── inventory_grid_init.lua     # REUSE - Grid drag-drop setup (867 lines)
```

---

## Known `wand_def` Schema (From `WandEngine.wand_defs` + `wand_executor.lua`)

Based on `WandTemplates` in `assets/scripts/core/card_eval_order_test.lua` and fields consumed by `assets/scripts/wand/wand_executor.lua`:

```lua
-- Complete wand_def structure with all known properties
local wand_def = {
    -- Identity
    id = "WAND_ID",                    -- REQUIRED: Unique identifier (e.g., "TEST_WAND_1", "RAGE_FIST")
    name = "Display Name",              -- OPTIONAL: Human-readable name
    type = "trigger",                   -- REQUIRED: Always "trigger" for wand definitions
    description = "Tooltip text",       -- OPTIONAL: For UI display
    
    -- Trigger Configuration
    trigger_type = "every_N_seconds",   -- OPTIONAL: "every_N_seconds", "on_bump_enemy", "on_stand_still", 
                                        --           "enemy_killed", "on_distance_traveled"
    trigger_interval = 2.0,             -- For "every_N_seconds": seconds between auto-fire
    trigger_idle_threshold = 1.5,       -- For "on_stand_still": seconds before trigger
    trigger_distance = 150,             -- For "on_distance_traveled": pixels traveled before trigger
    
    -- Mana System
    mana_max = 50,                      -- REQUIRED: Maximum mana pool (range: 20-70 in templates)
    mana_recharge_rate = 5,             -- REQUIRED: Mana regen per second (range: 4-12)
    overheat_penalty_factor = 5.0,      -- OPTIONAL: Multiplier for overload penalty (default: 5.0)
    
    -- Cast Mechanics
    cast_block_size = 2,                -- REQUIRED: Cards cast per trigger (range: 1-3)
    cast_delay = 200,                   -- REQUIRED: Delay between casts in ms (range: 50-250)
    recharge_time = 1000,               -- REQUIRED: Cooldown after full cast-cycle in ms (range: 100-1200)
    spread_angle = 10,                  -- REQUIRED: Projectile spread in degrees (range: 5-30)
    shuffle = false,                    -- REQUIRED: true = random card order, false = sequential
    
    -- Capacity
    total_card_slots = 5,               -- REQUIRED: Action card slots (range: 3-10)
    max_uses = -1,                      -- OPTIONAL: -1 = infinite uses
    
    -- Built-in Cards
    always_cast_cards = {               -- OPTIONAL: Card IDs auto-appended to every cast
        "ACTION_BASIC_PROJECTILE",      -- These are added AFTER player cards in pool
        "MOD_DAMAGE_UP",
    },
    
    -- Optional: Charge system (supported by WandExecutor, not used by current templates)
    max_charges = 0,                    -- OPTIONAL: If > 0, use charge system instead of mana
    charge_regen_time = 0,              -- OPTIONAL: Time between charge regeneration (seconds)
}
```

**Wand Templates Available** (from `WandEngine.wand_defs`):
| ID | Name | Slots | Block | Shuffle | Trigger Type |
|----|------|-------|-------|---------|--------------|
| TEST_WAND_1 | - | 5 | 2 | false | manual |
| TEST_WAND_2 | - | 10 | 1 | false | manual |
| TEST_WAND_3 | - | 7 | 3 | true | manual |
| TEST_WAND_4 | - | 8 | 2 | true | manual |
| RAGE_FIST | Rage Fist | 4 | 1 | false | every_N_seconds (2.0s) |
| STORM_WALKER | Storm Walker | 5 | 2 | false | on_bump_enemy |
| FROST_ANCHOR | Frost Anchor | 6 | 3 | true | on_stand_still (1.5s) |
| SOUL_SIPHON | Soul Siphon | 4 | 1 | false | enemy_killed |
| PAIN_ECHO | Pain Echo | 3 | 1 | false | on_distance_traveled (150px) |
| EMBER_PULSE | Ember Pulse | 6 | 2 | true | every_N_seconds (3.0s) |

---

## Complete cardData Schema (From codebase analysis)

```lua
-- cardData structure for all card types
local cardData = {
    -- Identity
    id = "CARD_ID",                     -- REQUIRED: Unique identifier
    card_id = "CARD_ID",                -- ALIAS: Same as id (used interchangeably)
    name = "Display Name",              -- REQUIRED: For UI display
    description = "Effect description", -- OPTIONAL: Tooltip text
    
    -- Type Classification
    type = "action",                    -- REQUIRED: "trigger", "action", "modifier"
    
    -- Visual
    sprite = "card-sprite.png",         -- REQUIRED: Animation/sprite name
    icon = "card-icon.png",             -- OPTIONAL: Inventory icon
    element = "Fire",                   -- OPTIONAL: Element type for theming
    
    -- Combat Stats (for action cards)
    damage = 10,                        -- OPTIONAL: Base damage
    projectile_speed = 200,             -- OPTIONAL: Projectile velocity
    lifetime = 2000,                    -- OPTIONAL: Projectile lifetime in ms
    
    -- Mana/Cost
    mana_cost = 15,                     -- OPTIONAL: Mana consumed on cast
    manaCost = 15,                      -- ALIAS: Same as mana_cost
    cost = 15,                          -- ALIAS: Same as mana_cost
    
    -- Timing
    cast_delay = 100,                   -- OPTIONAL: Added delay in ms
    recharge_time = 200,                -- OPTIONAL: Added recharge in ms
    timer_ms = 500,                     -- OPTIONAL: For timer-triggered effects
    
    -- Spread
    spread_angle = 5,                   -- OPTIONAL: Additional spread in degrees
    
    -- Modifier-specific
    modifier_target = "damage",         -- For modifiers: what stat to modify
    modifier_value = 1.5,               -- For modifiers: multiplier or addend
    
    -- Multicast
    multicast_count = 2,                -- OPTIONAL: Number of simultaneous casts
    
    -- Stacking (for inventory)
    stackId = "CARD_ID",                -- OPTIONAL: For stackable cards
    cardStack = {},                     -- RUNTIME: Array of modifier entity IDs attached
    
    -- Runtime State
    entity = nil,                       -- RUNTIME: Entity ID when spawned
    noVisualSnap = true,                -- RUNTIME: Prevents visual jitter in grids
}
```

**Card Types:**
1. **trigger**: Defines WHEN the wand fires (e.g., "every_N_seconds", "on_bump_enemy")
2. **action**: The actual spell effect (projectile, explosion, etc.)
3. **modifier**: Modifies the next action card (damage boost, speed, etc.)

**Card Pool Build Order** (Critical for combat):
1. For each action card in slot order (left → right):
   - Push all modifier cards from `cardScript.cardStack` (if any)
   - Push the base card itself
2. After all action cards: append `always_cast_cards` from wand_def

---

## WandAdapter API Reference (From wand_grid_adapter.lua)

The adapter bridges WandPanel ↔ WandExecutor with these methods:

```lua
local wandAdapter = require("ui.wand_grid_adapter")

-- Initialization (called once with wand definitions)
wandAdapter.init(wandDefinitions)     -- Array of wand_def tables from WandEngine.wand_defs

-- Trigger Card Management
wandAdapter.setTrigger(wandIndex, cardEntity)   -- Assign trigger card (1-based index)
wandAdapter.clearSlot(wandIndex, nil)           -- Clear trigger slot (nil = trigger)

-- Action Card Management  
wandAdapter.setAction(wandIndex, slotIndex, cardEntity)  -- Assign action card
wandAdapter.clearSlot(wandIndex, slotIndex)              -- Clear action slot

-- Queries
wandAdapter.getLoadout(wandIndex)      -- Returns { trigger = entity|nil, actions = { [slot] = entity } }
wandAdapter.getWandDef(wandIndex)      -- Returns wand_def table
wandAdapter.getWandCount()             -- Returns total configured wands
wandAdapter.hasCards(wandIndex)        -- Returns true if wand has any cards
wandAdapter.getActionCount(wandIndex)  -- Returns count of action cards

-- Clearing
wandAdapter.clearWand(wandIndex)       -- Remove all cards from specific wand
wandAdapter.clearAll()                 -- Reset all wands

-- Card Pool Building (for combat)
wandAdapter.collectCardPool(wandIndex) -- Returns ordered array: modifiers → base → always_cast

-- Dirty Flag Management (optimization)
wandAdapter.markDirty(wandIndex)       -- Force dirty (auto-set on changes)
wandAdapter.isDirty(wandIndex)         -- Check if needs sync
wandAdapter.anyDirty()                 -- Check if any wand needs sync
wandAdapter.clearDirty(wandIndex)      -- Clear dirty flag

-- Combat Sync (call before entering combat)
wandAdapter.syncToExecutor(WandExecutor)  -- Push dirty wands to WandExecutor.loadWand()

-- Debug
wandAdapter.debugPrint()               -- Print internal state
```

**Data Flow:**
```
WandPanel UI → wandAdapter.setAction/setTrigger → markDirty()
                                                      ↓
                        Combat Start → wandAdapter.syncToExecutor()
                                                      ↓
                                    WandExecutor.loadWand(wandDef, cardPool, triggerDef)
```

---

## Phase 1: Foundation (Module Skeleton)

### 1.1 Create `wand_panel.lua` with standard structure

Following the **BULLETPROOF UI PANEL IMPLEMENTATION GUIDE**:

```lua
--[[
================================================================================
WAND PANEL - Grid-Based Wand Card Management for Planning Mode
================================================================================

USAGE:
------
local WandPanel = require("ui.wand_panel")

WandPanel.open()                    -- Show wand panel
WandPanel.close()                   -- Hide wand panel
WandPanel.toggle()                  -- Toggle visibility
WandPanel.selectWand(index)         -- Switch to wand by index (1-based)
WandPanel.setWandDefs(wandDefs)     -- Initialize with wand definitions
WandPanel.equipToTriggerSlot(cardEntity)  -- Add trigger card to active wand
WandPanel.equipToActionSlot(cardEntity)   -- Add action card to active wand

EVENTS (via hump.signal):
-------------------------
"wand_panel_opened"                 -- Panel opened
"wand_panel_closed"                 -- Panel closed
"wand_trigger_changed"              -- Trigger card changed (wandId, newItem)
"wand_action_changed"               -- Action card changed (wandId, newItem)
"wand_selected"                     -- Active wand switched (newIndex, oldIndex)

================================================================================
]]

local WandPanel = {}

-- REQUIRED DEPENDENCIES
local dsl = require("ui.ui_syntax_sugar")
local grid = require("core.inventory_grid")
local signal = require("external.hump.signal")
local component_cache = require("core.component_cache")
local timer = require("core.timer")
local InventoryGridInit = require("ui.inventory_grid_init")
local itemRegistry = require("core.item_location_registry")
local CardUIPolicy = require("ui.card_ui_policy")
local z_orders = require("core.z_orders")
local wandAdapter = require("ui.wand_grid_adapter")

-- CONSTANTS
local TIMER_GROUP = "wand_panel"
local PANEL_ID = "wand_panel_id"
local RENDER_LAYER = "sprites"  -- Use sprites layer for z-order sorting with cards

-- Z-ORDER HIERARCHY (MUST match player_inventory.lua)
local PANEL_Z = 800
local GRID_Z = 850
-- Must match UI_CARD_Z in inventory_grid_init.lua to avoid z-order reset conflicts.
local CARD_Z = z_orders.ui_tooltips + 100
local DRAG_Z = z_orders.ui_tooltips + 500  -- Dragged cards above all

-- OFFSCREEN POSITION (Move UP when hidden since panel is at top)
local OFFSCREEN_Y_OFFSET = -800

-- LAYOUT CONSTANTS
local SPRITE_BASE_W = 32
local SPRITE_BASE_H = 32
local SPRITE_SCALE = 2.5
local SLOT_WIDTH = SPRITE_BASE_W * SPRITE_SCALE   -- 80px
local SLOT_HEIGHT = SPRITE_BASE_H * SPRITE_SCALE  -- 80px
local SLOT_SPACING = 4
local GRID_PADDING = 6

local ACTION_GRID_COLS = 4  -- Fixed column count for action grids

local TAB_WIDTH = 48
local TAB_HEIGHT = 64
local TAB_SPACING = 4
local TAB_OFFSET_X = -TAB_WIDTH - 8  -- Position left of panel with gap

local HEADER_HEIGHT = 40
local SECTION_HEADER_HEIGHT = 24
local STATS_ROW_HEIGHT = 28
local PANEL_PADDING = 12

-- MODULE STATE (single source of truth)
local state = {
    initialized = false,
    isVisible = false,
    inputHandlerInitialized = false,
    
    -- Entities
    panelEntity = nil,
    closeButtonEntity = nil,
    triggerGridContainerEntity = nil,
    actionGridContainerEntity = nil,
    tabContainerEntity = nil,
    statsRowEntity = nil,
    
    -- Grid management
    triggerGridEntity = nil,
    actionGridEntity = nil,
    
    -- Wand state
    activeWandIndex = 1,
    wandDefs = {},
    
    -- Tab management
    tabEntities = {},
    
    -- Item tracking
    cardRegistry = {},         -- [entity] = cardData
    triggerCards = {},         -- [wandIndex] = { [slotIndex] = entity }
    actionCards = {},          -- [wandIndex] = { [slotIndex] = entity }
    
    -- Cleanup tracking
    signalHandlers = {},
    
    -- Position cache
    panelX = 0,
    panelY = 0,
    panelWidth = 0,
    panelHeight = 0,
}
```

### 1.2 State Management Functions

Copy exact patterns from player_inventory.lua:

```lua
--------------------------------------------------------------------------------
-- Visibility Control (EXACT pattern from PlayerInventory)
--------------------------------------------------------------------------------

local function setEntityVisible(entity, visible, onscreenX, onscreenY, dbgLabel)
    if not entity or not registry:valid(entity) then return end

    local targetX = onscreenX
    -- For top-of-screen panel: hide by moving UP (negative Y)
    local targetY = visible and onscreenY or (onscreenY + OFFSCREEN_Y_OFFSET)

    -- Update Transform for the main entity
    local t = component_cache.get(entity, Transform)
    if t then
        t.actualX = targetX
        t.actualY = targetY
    end

    -- Update InheritedProperties offset (used by layout system)
    local role = component_cache.get(entity, InheritedProperties)
    if role and role.offset then
        role.offset.x = targetX
        role.offset.y = targetY
    end

    -- CRITICAL: For UIBox entities, also update the uiRoot
    local boxComp = component_cache.get(entity, UIBoxComponent)
    if boxComp and boxComp.uiRoot and registry:valid(boxComp.uiRoot) then
        local rt = component_cache.get(boxComp.uiRoot, Transform)
        if rt then
            rt.actualX = targetX
            rt.actualY = targetY
        end
        local rootRole = component_cache.get(boxComp.uiRoot, InheritedProperties)
        if rootRole and rootRole.offset then
            rootRole.offset.x = targetX
            rootRole.offset.y = targetY
        end

        -- Force layout recalculation
        if ui and ui.box and ui.box.RenewAlignment then
            ui.box.RenewAlignment(registry, entity)
        end
    end
end

local function setCardEntityVisible(itemEntity, visible)
    if not itemEntity or not registry:valid(itemEntity) then return end
    if visible then
        if add_state_tag then
            add_state_tag(itemEntity, "default_state")
        end
    else
        if clear_state_tags then
            clear_state_tags(itemEntity)
        end
    end
end

local function setAllCardsVisible(visible)
    for itemEntity in pairs(state.cardRegistry) do
        setCardEntityVisible(itemEntity, visible)
    end
end

local function setGridItemsVisible(gridEntity, visible)
    if not gridEntity then return end
    local items = grid.getAllItems(gridEntity)
    for _, itemEntity in pairs(items) do
        setCardEntityVisible(itemEntity, visible)
    end
end
```

---

## Phase 2: Wand Tab System

### 2.1 Tab Layout (Left-Side Folder Tabs)

Tabs stick out from the LEFT side of the panel:

```lua
--------------------------------------------------------------------------------
-- Tab System
--------------------------------------------------------------------------------

local function createWandTabs()
    local tabChildren = {}

    for i, wandDef in ipairs(state.wandDefs) do
        local isActive = (i == state.activeWandIndex)
        local tabLabel = wandDef.name and string.sub(wandDef.name, 1, 2) or tostring(i)

        table.insert(tabChildren, dsl.strict.button(tabLabel, {
            id = "wand_tab_" .. i,
            fontSize = 14,
            minWidth = TAB_WIDTH,
            minHeight = TAB_HEIGHT,
            padding = 4,
            color = isActive and "gold" or "gray",
            hover = true,
            onClick = function()
                WandPanel.selectWand(i)
            end,
        }))

        -- Add spacing between tabs
        if i < #state.wandDefs then
            table.insert(tabChildren, dsl.strict.spacer(TAB_SPACING))
        end
    end

    return dsl.strict.vbox {
        config = {
            id = "wand_tabs_container",
            padding = 4,
        },
        children = tabChildren,
    }
end

local function updateTabHighlighting()
    for i, tabEntity in pairs(state.tabEntities) do
        if tabEntity and registry:valid(tabEntity) then
            local isActive = (i == state.activeWandIndex)
            local uiCfg = component_cache.get(tabEntity, UIConfig)
            if uiCfg and _G.util and _G.util.getColor then
                uiCfg.color = isActive and _G.util.getColor("gold") or _G.util.getColor("gray")
            end
        end
    end
end
```

### 2.2 Tab Positioning with ChildBuilder

Use ChildBuilder pattern from player_inventory.lua:

```lua
local function positionTabs()
    if not state.tabContainerEntity or not state.panelEntity then return end
    
    local ChildBuilder = require("core.child_builder")
    ChildBuilder.for_entity(state.tabContainerEntity)
        :attachTo(state.panelEntity)
        :offset(TAB_OFFSET_X, HEADER_HEIGHT)
        :apply()
end
```

---

## Phase 3: Grid Creation

### 3.1 Dynamic Grid Sizing from wand_def

```lua
--------------------------------------------------------------------------------
-- Grid Dimension Calculation
--------------------------------------------------------------------------------

local function getGridDimensions(wandDef, gridType)
    if gridType == "trigger" then
        -- Trigger grid: single slot (current engine supports 1 trigger card per wand)
        local triggerSlots = 1
        return 1, triggerSlots
    else
        -- Action grid: fixed columns, variable rows based on total_card_slots
        local totalSlots = wandDef.total_card_slots or 8
        local cols = ACTION_GRID_COLS
        local rows = math.ceil(totalSlots / cols)
        return rows, cols
    end
end

local function calculatePanelDimensions(wandDef)
    local triggerRows, triggerCols = getGridDimensions(wandDef, "trigger")
    local actionRows, actionCols = getGridDimensions(wandDef, "action")
    
    local triggerGridWidth = triggerCols * SLOT_WIDTH + (triggerCols - 1) * SLOT_SPACING + GRID_PADDING * 2
    local actionGridWidth = actionCols * SLOT_WIDTH + (actionCols - 1) * SLOT_SPACING + GRID_PADDING * 2
    
    local triggerGridHeight = triggerRows * SLOT_HEIGHT + (triggerRows - 1) * SLOT_SPACING + GRID_PADDING * 2
    local actionGridHeight = actionRows * SLOT_HEIGHT + (actionRows - 1) * SLOT_SPACING + GRID_PADDING * 2
    
    local contentWidth = math.max(triggerGridWidth, actionGridWidth)
    local contentHeight = HEADER_HEIGHT + SECTION_HEADER_HEIGHT + triggerGridHeight + 
                          SECTION_HEADER_HEIGHT + actionGridHeight + STATS_ROW_HEIGHT
    
    return contentWidth + PANEL_PADDING * 2, contentHeight + PANEL_PADDING * 2
end
```

### 3.2 Trigger Grid Definition

```lua
local function createTriggerGridDefinition(wandDef)
    local rows, cols = getGridDimensions(wandDef, "trigger")
    local gridId = "wand_trigger_grid_" .. state.activeWandIndex

    return dsl.strict.inventoryGrid {
        id = gridId,
        rows = rows,
        cols = cols,
        slotSize = { w = SLOT_WIDTH, h = SLOT_HEIGHT },
        slotSpacing = SLOT_SPACING,

        config = {
            allowDragIn = true,
            allowDragOut = true,
            stackable = false,
            slotSprite = "test-inventory-square-single.png",  -- Reuse existing slot sprite
            padding = GRID_PADDING,
            backgroundColor = "cyan_dark",  -- Trigger color theme
            snapVisual = false,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
        },

        -- Filter: Only accept trigger cards
        canAcceptItem = function(gridEntity, itemEntity)
            local script = getScriptTableFromEntityID and getScriptTableFromEntityID(itemEntity)
            local data = script and (script.cardData or script)
            return data and data.type == "trigger" or false
        end,

        onSlotChange = function(gridEntity, slotIndex, oldItem, newItem)
            log_debug("[WandPanel] Trigger slot " .. slotIndex .. " changed")
            syncTriggerToAdapter()
        end,

        onSlotClick = function(gridEntity, slotIndex, button)
            local rightButton = MouseButton and MouseButton.MOUSE_BUTTON_RIGHT or 1
            if button == rightButton then  -- Right-click to remove
                local item = grid.getItemAtIndex(gridEntity, slotIndex)
                if item and registry:valid(item) then
                    local removed = grid.removeItem(gridEntity, slotIndex)
                    if removed then
                        local ok = returnCardToInventory(removed)
                        if not ok then
                            -- Rollback if inventory is full / add failed
                            grid.addItem(gridEntity, removed, slotIndex)
                        end
                    end
                end
            end
        end,
    }
end
```

### 3.3 Action Grid Definition

```lua
local function createActionGridDefinition(wandDef)
    local rows, cols = getGridDimensions(wandDef, "action")
    local gridId = "wand_action_grid_" .. state.activeWandIndex

    return dsl.strict.inventoryGrid {
        id = gridId,
        rows = rows,
        cols = cols,
        slotSize = { w = SLOT_WIDTH, h = SLOT_HEIGHT },
        slotSpacing = SLOT_SPACING,

        config = {
            allowDragIn = true,
            allowDragOut = true,
            stackable = false,
            slotSprite = "test-inventory-square-single.png",  -- Reuse existing slot sprite
            padding = GRID_PADDING,
            backgroundColor = "apricot_cream_dark",  -- Action color theme
            snapVisual = false,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
        },

        -- Filter: Only accept action/modifier cards
        canAcceptItem = function(gridEntity, itemEntity)
            local script = getScriptTableFromEntityID and getScriptTableFromEntityID(itemEntity)
            local data = script and (script.cardData or script)
            local cardType = data and data.type
            return cardType == "action" or cardType == "modifier" or false
        end,

        onSlotChange = function(gridEntity, slotIndex, oldItem, newItem)
            log_debug("[WandPanel] Action slot " .. slotIndex .. " changed")
            syncActionsToAdapter()
        end,

        onSlotClick = function(gridEntity, slotIndex, button)
            local rightButton = MouseButton and MouseButton.MOUSE_BUTTON_RIGHT or 1
            if button == rightButton then  -- Right-click to remove
                local item = grid.getItemAtIndex(gridEntity, slotIndex)
                if item and registry:valid(item) then
                    local removed = grid.removeItem(gridEntity, slotIndex)
                    if removed then
                        local ok = returnCardToInventory(removed)
                        if not ok then
                            -- Rollback if inventory is full / add failed
                            grid.addItem(gridEntity, removed, slotIndex)
                        end
                    end
                end
            end
        end,
    }
end
```

### 3.4 Grid Injection Pattern

```lua
local function injectTriggerGrid(wandDef)
    if not state.triggerGridContainerEntity or not registry:valid(state.triggerGridContainerEntity) then
        log_warn("[WandPanel] Trigger grid container not available")
        return nil
    end

    local gridDef = createTriggerGridDefinition(wandDef)
    local replaced = ui.box.ReplaceChildren(state.triggerGridContainerEntity, gridDef)
    if not replaced then
        log_warn("[WandPanel] Failed to inject trigger grid")
        return nil
    end

    -- CRITICAL: Reapply state tags after ReplaceChildren
    if ui and ui.box and ui.box.AddStateTagToUIBox then
        ui.box.AddStateTagToUIBox(registry, state.panelEntity, "default_state")
    end
    
    -- CRITICAL: Force layout recalculation
    if ui and ui.box and ui.box.RenewAlignment then
        ui.box.RenewAlignment(registry, state.panelEntity)
    end

    local gridId = "wand_trigger_grid_" .. state.activeWandIndex
    local gridEntity = ui.box.GetUIEByID(registry, state.triggerGridContainerEntity, gridId)
    if not gridEntity then
        log_warn("[WandPanel] Could not find injected trigger grid")
        return nil
    end

    local success = InventoryGridInit.initializeIfGrid(gridEntity, gridId)
    if not success then
        log_warn("[WandPanel] Trigger grid initialization failed")
    end

    return gridEntity
end

local function injectActionGrid(wandDef)
    if not state.actionGridContainerEntity or not registry:valid(state.actionGridContainerEntity) then
        log_warn("[WandPanel] Action grid container not available")
        return nil
    end

    local gridDef = createActionGridDefinition(wandDef)
    local replaced = ui.box.ReplaceChildren(state.actionGridContainerEntity, gridDef)
    if not replaced then
        log_warn("[WandPanel] Failed to inject action grid")
        return nil
    end

    -- CRITICAL: Reapply state tags after ReplaceChildren
    if ui and ui.box and ui.box.AddStateTagToUIBox then
        ui.box.AddStateTagToUIBox(registry, state.panelEntity, "default_state")
    end
    
    -- CRITICAL: Force layout recalculation
    if ui and ui.box and ui.box.RenewAlignment then
        ui.box.RenewAlignment(registry, state.panelEntity)
    end

    local gridId = "wand_action_grid_" .. state.activeWandIndex
    local gridEntity = ui.box.GetUIEByID(registry, state.actionGridContainerEntity, gridId)
    if not gridEntity then
        log_warn("[WandPanel] Could not find injected action grid")
        return nil
    end

    local success = InventoryGridInit.initializeIfGrid(gridEntity, gridId)
    if not success then
        log_warn("[WandPanel] Action grid initialization failed")
    end

    return gridEntity
end
```

### 3.5 Grid Cleanup Pattern

```lua
local function cleanupGrid(gridEntity, gridId)
    if not gridEntity then return end

    -- STEP 1: Unregister from drag feedback system
    InventoryGridInit.unregisterGridForDragFeedback(gridEntity)

    -- STEP 2: Clean up slot metadata
    local capacity = grid.getCapacity(gridEntity)
    for i = 1, capacity do
        local slotEntity = grid.getSlotEntity(gridEntity, i)
        if slotEntity then
            InventoryGridInit.cleanupSlotMetadata(slotEntity)
        end
    end

    -- STEP 3: Clear item location registry for this grid
    itemRegistry.clearGrid(gridEntity)

    -- STEP 4: Clean up grid internal state
    grid.cleanup(gridEntity)

    -- STEP 5: Clean up DSL grid registry
    dsl.cleanupGrid(gridId)
end
```

---

## Phase 4: Wand Stats Display

### 4.1 Stats in Panel Header

```lua
local function formatStatValue(value, suffix)
    if not value or value == 0 or value == -1 then
        return nil
    end
    if suffix then
        return tostring(value) .. suffix
    end
    return tostring(value)
end

local function createWandStatsRow(wandDef)
    local stats = {}

    local function addStat(label, value, color, suffix)
        local formatted = formatStatValue(value, suffix)
        if formatted then
            table.insert(stats, dsl.strict.text(
                label .. ": " .. formatted,
                { fontSize = 10, color = color or "white", shadow = true }
            ))
            table.insert(stats, dsl.strict.spacer(12))
        end
    end

    -- Core stats
    addStat("Cast", wandDef.cast_delay, "cyan", "ms")
    addStat("Recharge", wandDef.recharge_time, "green", "ms")
    addStat("Spread", wandDef.spread_angle, "yellow", "deg")
    addStat("Block", wandDef.cast_block_size, "apricot_cream", nil)
    addStat("Mana", wandDef.mana_max, "blue", nil)

    -- Shuffle indicator
    if wandDef.shuffle then
        table.insert(stats, dsl.strict.text("SHUFFLE", { fontSize = 10, color = "red", shadow = true }))
        table.insert(stats, dsl.strict.spacer(12))
    end

    -- Trigger indicator (runtime comes from the equipped trigger card, not wandDef.trigger_type)
    do
        local triggerLabel = nil

        local loadout = wandAdapter and wandAdapter.getLoadout and wandAdapter.getLoadout(state.activeWandIndex)
        local triggerEntity = loadout and loadout.trigger
        if triggerEntity and registry:valid(triggerEntity) then
            local script = getScriptTableFromEntityID and getScriptTableFromEntityID(triggerEntity)
            local data = script and (script.cardData or script) or {}
            local triggerId = data.card_id or data.cardID or data.id
            if triggerId then
                triggerLabel = string.upper(string.gsub(triggerId, "_", " "))
            end
        end

        -- Fallback to template metadata (optional)
        if not triggerLabel and wandDef.trigger_type then
            triggerLabel = string.upper(string.gsub(wandDef.trigger_type, "_", " "))
        end

        if triggerLabel then
            table.insert(stats, dsl.strict.text(triggerLabel, { fontSize = 10, color = "purple", shadow = true }))
            table.insert(stats, dsl.strict.spacer(12))
        end
    end

    -- Always-cast indicator
    if wandDef.always_cast_cards and #wandDef.always_cast_cards > 0 then
        table.insert(stats, dsl.strict.spacer(12))
        table.insert(stats, dsl.strict.text(
            "+" .. #wandDef.always_cast_cards .. " Always",
            { fontSize = 10, color = "gold", shadow = true }
        ))
    end

    return dsl.strict.hbox {
        config = { 
            id = "wand_stats_row",
            padding = 4,
        },
        children = stats,
    }
end
```

### 4.2 Update Stats on Wand Switch

```lua
local function updateStatsDisplay()
    local wandDef = state.wandDefs[state.activeWandIndex]
    if not wandDef then return end

    -- Recreate stats row with new wand data
    if state.statsRowEntity and registry:valid(state.statsRowEntity) then
        local newStatsRow = createWandStatsRow(wandDef)
        ui.box.ReplaceChildren(state.statsRowEntity, newStatsRow)
        
        if ui and ui.box and ui.box.AddStateTagToUIBox then
            ui.box.AddStateTagToUIBox(registry, state.panelEntity, "default_state")
        end
    end
end
```

---

## Phase 5: WandAdapter Integration (Real-Time Sync)

### 5.1 Sync Functions

```lua
--------------------------------------------------------------------------------
-- WandAdapter Sync
--------------------------------------------------------------------------------

local function syncTriggerToAdapter()
    local wandIndex = state.activeWandIndex
    if not state.triggerGridEntity then return end

    -- Single trigger slot
    local triggerEntity = grid.getItemAtIndex(state.triggerGridEntity, 1)

    wandAdapter.setTrigger(wandIndex, triggerEntity)
    signal.emit("wand_trigger_changed", wandIndex, triggerEntity)
end

local function syncActionsToAdapter()
    local wandIndex = state.activeWandIndex
    if not state.actionGridEntity then return end

    -- Clear all action slots first
    local wandDef = state.wandDefs[wandIndex]
    if wandDef then
        for i = 1, (wandDef.total_card_slots or 8) do
            wandAdapter.clearSlot(wandIndex, i)
        end
    end

    -- Set action cards by slot position
    local items = grid.getAllItems(state.actionGridEntity)
    for slotIndex, entity in pairs(items) do
        if entity and registry:valid(entity) then
            wandAdapter.setAction(wandIndex, slotIndex, entity)
        end
    end

    signal.emit("wand_action_changed", wandIndex, nil)
end

local function syncAllToAdapter()
    syncTriggerToAdapter()
    syncActionsToAdapter()
end
```

### 5.2 Signal Handlers for Grid Changes

```lua
local function setupSignalHandlers()
    local function registerHandler(eventName, handler)
        signal.register(eventName, handler)
        table.insert(state.signalHandlers, { event = eventName, handler = handler })
    end

    local function isOurGrid(gridEntity)
        return gridEntity == state.triggerGridEntity or gridEntity == state.actionGridEntity
    end

    -- Grid item events
    registerHandler("grid_item_added", function(gridEntity, slotIndex, itemEntity)
        if not isOurGrid(gridEntity) then return end
        
        log_debug("[WandPanel] Item added to slot " .. slotIndex)
        if playSoundEffect then
            playSoundEffect("effects", "button-click")
        end
        
        -- Sync to adapter
        if gridEntity == state.triggerGridEntity then
            syncTriggerToAdapter()
        else
            syncActionsToAdapter()
        end
    end)

    registerHandler("grid_item_removed", function(gridEntity, slotIndex, itemEntity)
        if not isOurGrid(gridEntity) then return end
        
        log_debug("[WandPanel] Item removed from slot " .. slotIndex)
        
        -- Sync to adapter
        if gridEntity == state.triggerGridEntity then
            syncTriggerToAdapter()
        else
            syncActionsToAdapter()
        end
    end)

    registerHandler("grid_item_moved", function(gridEntity, fromSlot, toSlot, itemEntity)
        if not isOurGrid(gridEntity) then return end
        
        log_debug("[WandPanel] Item moved from " .. fromSlot .. " to " .. toSlot)
        syncActionsToAdapter()  -- Only action grid supports reordering
    end)

    -- Cross-grid transfer handling
    registerHandler("grid_cross_transfer_success", function(itemEntity, fromGrid, toGrid, toSlot)
        if isOurGrid(toGrid) then
            -- Card transferred INTO our grid
            state.cardRegistry[itemEntity] = true
            if toGrid == state.triggerGridEntity then
                syncTriggerToAdapter()
            else
                syncActionsToAdapter()
            end
        elseif isOurGrid(fromGrid) then
            -- Card transferred OUT of our grid
            state.cardRegistry[itemEntity] = nil
            if fromGrid == state.triggerGridEntity then
                syncTriggerToAdapter()
            else
                syncActionsToAdapter()
            end
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
    state.inputHandlerInitialized = false
end
```

### 5.3 Card Removal → Return to Inventory

```lua
local function returnCardToInventory(itemEntity)
    if not itemEntity or not registry:valid(itemEntity) then return false end

    local PlayerInventory = require("ui.player_inventory")
    local script = getScriptTableFromEntityID and getScriptTableFromEntityID(itemEntity)
    local data = script and (script.cardData or script) or {}
    local category = "actions"  -- Default

    if data.type == "trigger" then
        category = "triggers"
    elseif data.type == "modifier" then
        category = "modifiers"
    end

    -- Note: PlayerInventory.addCard() registers the item in its own grid/store.
    -- Ensure the item has already been removed from our grid before calling this.
    local success = PlayerInventory.addCard(itemEntity, category)
    if success then
        log_debug("[WandPanel] Card returned to inventory: " .. tostring(category))
        state.cardRegistry[itemEntity] = nil
    end
    return success
end
```

---

## Phase 6: Quick Equip (Right-Click)

### 6.1 Equip Functions for WandPanel

```lua
--------------------------------------------------------------------------------
-- Quick Equip API
--------------------------------------------------------------------------------

--- Equip a trigger card to the active wand's trigger slot
-- @param cardEntity Entity ID of the trigger card
-- @return boolean Success
function WandPanel.equipToTriggerSlot(cardEntity)
    if not state.initialized then
        initialize()
    end
    if not state.initialized or not state.triggerGridEntity then
        return false
    end

    -- Verify it's a trigger card
    local script = getScriptTableFromEntityID and getScriptTableFromEntityID(cardEntity)
    local data = script and (script.cardData or script)
    if not data or data.type ~= "trigger" then
        log_debug("[WandPanel] equipToTriggerSlot: Not a trigger card")
        return false
    end

    -- Prefer atomic transfer to avoid itemRegistry desync/duplication.
    local transfer = require("core.grid_transfer")
    local result = transfer.transferItemTo({
        item = cardEntity,
        toGrid = state.triggerGridEntity,
    })
    local success = result and result.success
    local slotIndex = result and result.toSlot

    -- Fallback only when item isn't registered in any grid (e.g., spawned off-grid)
    if not success and result and result.reason == "item_not_registered" then
        success, slotIndex = grid.addItem(state.triggerGridEntity, cardEntity)
    end

    if success then
        local slotEntity = grid.getSlotEntity(state.triggerGridEntity, slotIndex)
        if slotEntity then
            InventoryGridInit.centerItemOnSlot(cardEntity, slotEntity, false)
        end
        state.cardRegistry[cardEntity] = data or true
        setCardEntityVisible(cardEntity, state.isVisible)
        syncTriggerToAdapter()
        return true
    end

    return false
end

--- Equip an action/modifier card to the active wand's action grid
-- @param cardEntity Entity ID of the action/modifier card
-- @return boolean Success
function WandPanel.equipToActionSlot(cardEntity)
    if not state.initialized then
        initialize()
    end
    if not state.initialized or not state.actionGridEntity then
        return false
    end

    -- Verify it's an action or modifier card
    local script = getScriptTableFromEntityID and getScriptTableFromEntityID(cardEntity)
    local data = script and (script.cardData or script)
    if not data then
        return false
    end
    
    local cardType = data.type
    if cardType ~= "action" and cardType ~= "modifier" then
        log_debug("[WandPanel] equipToActionSlot: Not an action/modifier card")
        return false
    end

    -- Prefer atomic transfer to avoid itemRegistry desync/duplication.
    local transfer = require("core.grid_transfer")
    local result = transfer.transferItemTo({
        item = cardEntity,
        toGrid = state.actionGridEntity,
    })
    local success = result and result.success
    local slotIndex = result and result.toSlot

    -- Fallback only when item isn't registered in any grid (e.g., spawned off-grid)
    if not success and result and result.reason == "item_not_registered" then
        success, slotIndex = grid.addItem(state.actionGridEntity, cardEntity)
    end

    if success then
        local slotEntity = grid.getSlotEntity(state.actionGridEntity, slotIndex)
        if slotEntity then
            InventoryGridInit.centerItemOnSlot(cardEntity, slotEntity, false)
        end
        state.cardRegistry[cardEntity] = data or true
        setCardEntityVisible(cardEntity, state.isVisible)
        syncActionsToAdapter()
        return true
    end

    return false
end
```

### 6.2 Integration with Inventory Quick Equip

The repo already has `assets/scripts/ui/inventory_quick_equip.lua` (used by `ui.player_inventory`) which listens to right-clicks and uses `core.grid_transfer` to move cards from PlayerInventory → WandLoadoutUI.

Update it to target WandPanel instead:

1) Provide WandLoadout-compatible accessors on WandPanel:

```lua
-- In ui/wand_panel.lua
function WandPanel.getTriggerGrid()
    if not state.initialized then
        initialize()
    end
    return state.triggerGridEntity
end

function WandPanel.getActionGrid()
    if not state.initialized then
        initialize()
    end
    return state.actionGridEntity
end
```

2) In `assets/scripts/ui/inventory_quick_equip.lua`, prefer `ui.wand_panel` as the "wand loadout" module (fallback to `ui.wand_loadout_ui` during migration):

```lua
local function getWandLoadout()
    if not state.wandLoadoutModule then
        local ok, mod = pcall(require, "ui.wand_panel")
        if not ok then
            ok, mod = pcall(require, "ui.wand_loadout_ui")
        end
        if ok then
            state.wandLoadoutModule = mod
        end
    end
    return state.wandLoadoutModule
end
```

---

## Phase 7: Input Handling

### 7.1 E Key Toggle

```lua
--------------------------------------------------------------------------------
-- Input Handling
--------------------------------------------------------------------------------

local function setupInputHandler()
    if state.inputHandlerInitialized then return end
    state.inputHandlerInitialized = true

    log_debug("[WandPanel] Setting up input handler for E key")

    timer.run_every_render_frame(function()
        -- E key to toggle wand panel
        local ePressed = isKeyPressed and isKeyPressed("KEY_E")
        if ePressed then
            WandPanel.toggle()
        end

        -- ESC to close (if open)
        if state.isVisible and isKeyPressed and isKeyPressed("KEY_ESCAPE") then
            WandPanel.close()
        end

        -- Number keys 1-4 to switch wands (when panel is open)
        if state.isVisible then
            for i = 1, math.min(4, #state.wandDefs) do
                local keyName = "KEY_" .. tostring(i)
                if isKeyPressed and isKeyPressed(keyName) then
                    WandPanel.selectWand(i)
                end
            end
        end
    end, nil, "wand_panel_input", TIMER_GROUP)
end
```

---

## Phase 8: World Board Isolation

### 8.1 Comment Out in gameplay.lua

Location: `assets/scripts/core/gameplay.lua` around line 5554

```lua
-- In gameplay.lua setupGame():

-- =================== WORLD BOARDS DISABLED ===================
-- These world-space boards are replaced by the WandPanel UI.
-- Keeping code for reference but not executing.
-- See: docs/project-management/design/WAND_UI_PANEL_IMPLEMENTATION_PLAN.md
--[[
local set = createTriggerActionBoardSet(
    leftAlignValueTriggerBoardX,
    runningYValue,
    triggerBoardWidth,
    actionBoardWidth,
    boardHeight,
    boardPadding
)
-- ... rest of board_sets creation ...
]]
-- =============================================================

-- Initialize WandPanel with wand definitions instead
local WandPanel = require("ui.wand_panel")
WandPanel.setWandDefs(WandEngine.wand_defs)

-- Keep board_sets data structure for WandExecutor compatibility
-- but don't create visual boards
for i, wandDef in ipairs(WandEngine.wand_defs) do
    board_sets[i] = {
        wandDef = wandDef,
        -- Visual board entities removed
        trigger_board_id = nil,
        action_board_id = nil,
    }
end
```

### 8.2 Update beginActionPhaseFromPlanning

Location: `assets/scripts/core/gameplay.lua` around line 7524

```lua
-- In beginActionPhaseFromPlanning():

-- Sync WandPanel state to WandExecutor via adapter
local syncedCount = wandAdapter.syncToExecutor(WandExecutor)
log_debug("[gameplay] Synced " .. syncedCount .. " wands to executor")
```

### 8.3 Migration Checklist

1. [ ] Comment out `createTriggerActionBoardSet` calls (line ~5554)
2. [ ] Comment out world-space board rendering
3. [ ] Keep `board_sets` array structure for WandExecutor compatibility
4. [ ] Add WandPanel initialization after board_sets is populated
5. [ ] Update `beginActionPhaseFromPlanning` to use wandAdapter.syncToExecutor()
6. [ ] Test combat still works via adapter sync
7. [ ] Remove old world-board tooltip code (optional)

---

## Phase 9: Panel Definition

### 9.1 Complete Panel Definition

```lua
--------------------------------------------------------------------------------
-- Panel Creation
--------------------------------------------------------------------------------

local function createHeader(wandDef)
    local titleText = wandDef.name or ("Wand " .. state.activeWandIndex)
    
    return dsl.strict.hbox {
        config = {
            id = "wand_panel_header",
            padding = 8,
        },
        children = {
            dsl.strict.text(titleText, {
                id = "header_title",
                fontSize = 16,
                color = "gold",
                shadow = true,
            }),
            dsl.filler(),
            dsl.strict.button("X", {
                id = "wand_close_btn",
                fontSize = 12,
                color = "red",
                minWidth = 24,
                minHeight = 24,
                onClick = function()
                    WandPanel.close()
                end,
            }),
        },
    }
end

local function createTriggerSection()
    return dsl.strict.vbox {
        config = { padding = 4 },
        children = {
            dsl.strict.text("TRIGGERS", {
                fontSize = 12,
                color = "cyan",
                shadow = true,
            }),
            dsl.strict.spacer(4),
            dsl.strict.vbox {
                config = {
                    id = "trigger_grid_container",
                    padding = 0,
                },
                children = {},  -- Grid injected at runtime
            },
        },
    }
end

local function createActionSection()
    return dsl.strict.vbox {
        config = { padding = 4 },
        children = {
            dsl.strict.text("ACTIONS", {
                fontSize = 12,
                color = "apricot_cream",
                shadow = true,
            }),
            dsl.strict.spacer(4),
            dsl.strict.vbox {
                config = {
                    id = "action_grid_container",
                    padding = 0,
                },
                children = {},  -- Grid injected at runtime
            },
        },
    }
end

local function createStatsSection(wandDef)
    return dsl.strict.vbox {
        config = {
            id = "stats_section",
            padding = 4,
        },
        children = {
            createWandStatsRow(wandDef),
        },
    }
end

local function createPanelDefinition(wandDef)
    local panelWidth, panelHeight = calculatePanelDimensions(wandDef)
    state.panelWidth = panelWidth
    state.panelHeight = panelHeight

    return dsl.strict.spritePanel {
        sprite = "inventory-back-panel.png",  -- Reuse existing panel background
        borders = { 0, 0, 0, 0 },
        sizing = "stretch",
        config = {
            id = PANEL_ID,
            padding = PANEL_PADDING,
            minWidth = panelWidth,
            minHeight = panelHeight,
        },
        children = {
            createHeader(wandDef),
            createTriggerSection(),
            createActionSection(),
            createStatsSection(wandDef),
        },
    }
end
```

---

## Phase 10: Lifecycle Functions

### 10.1 Position Calculation

```lua
local function calculatePositions()
    local screenW = globals.screenWidth()
    local screenH = globals.screenHeight()

    if not screenW or not screenH or screenW <= 0 or screenH <= 0 then
        log_debug("[WandPanel] Skipping position calc - screen not ready")
        return false
    end

    -- Calculate panel dimensions based on active wand
    local wandDef = state.wandDefs[state.activeWandIndex]
    if wandDef then
        state.panelWidth, state.panelHeight = calculatePanelDimensions(wandDef)
    end

    -- Position at top-center of screen
    state.panelX = (screenW - state.panelWidth) / 2
    state.panelY = 10  -- Small gap from top

    return true
end
```

### 10.2 Card Render Timer

```lua
local function setupCardRenderTimer()
    local UI_CARD_Z = CARD_Z

    local function snapItemsToSlots(gridEntity)
        if not gridEntity then return end

        local inputState = input and input.getState and input.getState()
        local draggedEntity = inputState and inputState.cursor_dragging_target

        local items = grid.getAllItems(gridEntity)
        for slotIndex, itemEntity in pairs(items) do
            if itemEntity and registry:valid(itemEntity) and itemEntity ~= draggedEntity then
                local slotEntity = grid.getSlotEntity(gridEntity, slotIndex)
                if slotEntity then
                    InventoryGridInit.centerItemOnSlot(itemEntity, slotEntity, false)
                end
            end
        end
    end

    local function isItemInOurGrids(eid)
        local location = itemRegistry.getLocation(eid)
        if not location or not location.grid then return false end
        return location.grid == state.triggerGridEntity or location.grid == state.actionGridEntity
    end

    timer.run_every_render_frame(function()
        if not state.isVisible then return end

        -- Snap items in both grids
        snapItemsToSlots(state.triggerGridEntity)
        snapItemsToSlots(state.actionGridEntity)

        -- Batch render cards with shader pipeline
        if not (command_buffer and command_buffer.queueDrawBatchedEntities and layers and layers.sprites) then
            return
        end

        local batchedBucketsByZ = {}

        for eid in pairs(state.cardRegistry) do
            if eid and registry:valid(eid) and isItemInOurGrids(eid) then
                local hasPipeline = shader_pipeline and shader_pipeline.ShaderPipelineComponent
                    and registry:has(eid, shader_pipeline.ShaderPipelineComponent)
                local animComp = component_cache.get(eid, AnimationQueueComponent)

                if animComp then
                    animComp.drawWithLegacyPipeline = true
                end

                if hasPipeline and animComp and not animComp.noDraw then
                    local zToUse = UI_CARD_Z
                    if layer_order_system and layer_order_system.getZIndex then
                        local entityZ = layer_order_system.getZIndex(eid)
                        if entityZ and entityZ > 0 then
                            zToUse = entityZ
                        end
                    end

                    local bucket = batchedBucketsByZ[zToUse]
                    if not bucket then
                        bucket = {}
                        batchedBucketsByZ[zToUse] = bucket
                    end
                    bucket[#bucket + 1] = eid
                    animComp.drawWithLegacyPipeline = false
                end
            end
        end

        if next(batchedBucketsByZ) then
            local zKeys = {}
            for z, entityList in pairs(batchedBucketsByZ) do
                if #entityList > 0 then
                    zKeys[#zKeys + 1] = z
                end
            end
            table.sort(zKeys)

            for _, z in ipairs(zKeys) do
                local entityList = batchedBucketsByZ[z]
                if entityList and #entityList > 0 then
                    command_buffer.queueDrawBatchedEntities(layers.sprites, function(cmd)
                        cmd.registry = registry
                        cmd.entities = entityList
                        cmd.autoOptimize = true
                    end, z, layer.DrawCommandSpace.Screen)
                end
            end
        end
    end, nil, "wand_panel_card_render", TIMER_GROUP)
end
```

### 10.3 Initialize Function

```lua
local function initialize()
    if state.initialized then return end

    if #state.wandDefs == 0 then
        log_warn("[WandPanel] Cannot initialize - no wand definitions set")
        return
    end

    if not calculatePositions() then
        log_warn("[WandPanel] Cannot initialize - screen dimensions not ready")
        return
    end

    local wandDef = state.wandDefs[state.activeWandIndex]

    -- STEP 1: Create panel definition
    local panelDef = createPanelDefinition(wandDef)

    -- STEP 2: Spawn OFFSCREEN (hidden)
    state.panelEntity = dsl.spawn(
        { x = state.panelX, y = state.panelY + OFFSCREEN_Y_OFFSET },
        panelDef,
        RENDER_LAYER,
        PANEL_Z
    )

    -- STEP 3: Set draw layer for z-order sorting
    if ui and ui.box and ui.box.set_draw_layer then
        ui.box.set_draw_layer(state.panelEntity, "sprites")
    end

    -- STEP 4: Add state tags so elements render
    if ui and ui.box and ui.box.AddStateTagToUIBox then
        ui.box.AddStateTagToUIBox(registry, state.panelEntity, "default_state")
    end

    -- STEP 5: Cache container entities
    state.triggerGridContainerEntity = ui.box.GetUIEByID(registry, state.panelEntity, "trigger_grid_container")
    state.actionGridContainerEntity = ui.box.GetUIEByID(registry, state.panelEntity, "action_grid_container")
    state.closeButtonEntity = ui.box.GetUIEByID(registry, state.panelEntity, "wand_close_btn")
    state.statsRowEntity = ui.box.GetUIEByID(registry, state.panelEntity, "wand_stats_row")

    -- STEP 6: Create and position tabs
    local tabDef = createWandTabs()
    state.tabContainerEntity = dsl.spawn(
        { x = state.panelX + TAB_OFFSET_X, y = state.panelY + HEADER_HEIGHT + OFFSCREEN_Y_OFFSET },
        tabDef,
        RENDER_LAYER,
        PANEL_Z - 1
    )

    if ui and ui.box and ui.box.set_draw_layer then
        ui.box.set_draw_layer(state.tabContainerEntity, "sprites")
    end
    if ui and ui.box and ui.box.AddStateTagToUIBox then
        ui.box.AddStateTagToUIBox(registry, state.tabContainerEntity, "default_state")
    end

    -- Attach tabs to panel
    local ChildBuilder = require("core.child_builder")
    ChildBuilder.for_entity(state.tabContainerEntity)
        :attachTo(state.panelEntity)
        :offset(TAB_OFFSET_X, HEADER_HEIGHT)
        :apply()

    -- Cache tab button entities
    state.tabEntities = {}
    for i = 1, #state.wandDefs do
        local tabEntity = ui.box.GetUIEByID(registry, state.tabContainerEntity, "wand_tab_" .. i)
        if tabEntity then
            state.tabEntities[i] = tabEntity
        end
    end

    -- STEP 7: Inject grids for active wand
    state.triggerGridEntity = injectTriggerGrid(wandDef)
    state.actionGridEntity = injectActionGrid(wandDef)

    -- STEP 8: Setup systems
    setupSignalHandlers()
    setupCardRenderTimer()

    state.initialized = true
    log_debug("[WandPanel] Initialized (hidden)")
end
```

### 10.4 Open/Close/Toggle

```lua
function WandPanel.open()
    if not state.initialized then
        initialize()
    end

    if not state.initialized then
        log_warn("[WandPanel] Cannot open - initialization failed")
        return
    end

    if state.isVisible then return end

    calculatePositions()

    -- Show panel (tabs are attached via ChildBuilder and move with panel)
    setEntityVisible(state.panelEntity, true, state.panelX, state.panelY, "panel")

    state.isVisible = true

    -- Show cards in grids
    if state.triggerGridEntity then
        setGridItemsVisible(state.triggerGridEntity, true)
    end
    if state.actionGridEntity then
        setGridItemsVisible(state.actionGridEntity, true)
    end

    signal.emit("wand_panel_opened")

    if playSoundEffect then
        playSoundEffect("effects", "button-click")
    end

    log_debug("[WandPanel] Opened")
end

function WandPanel.close()
    if not state.isVisible then return end

    -- Hide panel (tabs are attached via ChildBuilder and move with panel)
    setEntityVisible(state.panelEntity, false, state.panelX, state.panelY, "panel")

    state.isVisible = false

    -- Hide all cards
    setAllCardsVisible(false)

    signal.emit("wand_panel_closed")

    log_debug("[WandPanel] Closed")
end

function WandPanel.toggle()
    if state.isVisible then
        WandPanel.close()
    else
        WandPanel.open()
    end
end

function WandPanel.isOpen()
    return state.isVisible
end
```

### 10.5 Wand Selection

```lua
local function stashGridItems(gridEntity)
    local stashed = {}
    if not gridEntity then return stashed end

    local items = grid.getAllItems(gridEntity)
    for slotIndex, itemEntity in pairs(items) do
        if itemEntity and registry:valid(itemEntity) then
            stashed[slotIndex] = itemEntity
            -- Clear tracked grid ref while the wand is inactive (grid will be destroyed)
            InventoryGridInit.makeItemDraggable(itemEntity, nil)
        end
    end

    return stashed
end

local function restoreGridItems(gridEntity, stashedItems)
    if not gridEntity or not stashedItems then return end

    for slotIndex, itemEntity in pairs(stashedItems) do
        if itemEntity and registry:valid(itemEntity) then
            local success = grid.addItem(gridEntity, itemEntity, slotIndex)
            if success then
                InventoryGridInit.makeItemDraggable(itemEntity, gridEntity)
                local slotEntity = grid.getSlotEntity(gridEntity, slotIndex)
                if slotEntity then
                    InventoryGridInit.centerItemOnSlot(itemEntity, slotEntity, false)
                end
                setCardEntityVisible(itemEntity, state.isVisible)
            else
                log_warn("[WandPanel] Failed to restore card to slot " .. tostring(slotIndex))
            end
        end
    end
end

function WandPanel.selectWand(index)
    if index < 1 or index > #state.wandDefs then
        log_warn("[WandPanel] Invalid wand index: " .. tostring(index))
        return
    end

    if index == state.activeWandIndex then return end

    local oldIndex = state.activeWandIndex
    
    -- Stash cards from current grids before switching
    if state.triggerGridEntity then
        state.triggerCards[oldIndex] = stashGridItems(state.triggerGridEntity)
        cleanupGrid(state.triggerGridEntity, "wand_trigger_grid_" .. oldIndex)
    end
    if state.actionGridEntity then
        state.actionCards[oldIndex] = stashGridItems(state.actionGridEntity)
        cleanupGrid(state.actionGridEntity, "wand_action_grid_" .. oldIndex)
    end

    -- Switch to new wand
    state.activeWandIndex = index
    local wandDef = state.wandDefs[index]

    -- Inject new grids
    state.triggerGridEntity = injectTriggerGrid(wandDef)
    state.actionGridEntity = injectActionGrid(wandDef)

    -- Restore stashed cards for new wand
    if state.triggerCards[index] then
        restoreGridItems(state.triggerGridEntity, state.triggerCards[index])
    end
    if state.actionCards[index] then
        restoreGridItems(state.actionGridEntity, state.actionCards[index])
    end

    -- Update UI
    updateTabHighlighting()
    updateStatsDisplay()

    -- Update visibility
    if state.isVisible then
        setAllCardsVisible(false)
        if state.triggerGridEntity then
            setGridItemsVisible(state.triggerGridEntity, true)
        end
        if state.actionGridEntity then
            setGridItemsVisible(state.actionGridEntity, true)
        end
    end

    -- Sync to adapter
    syncAllToAdapter()

    signal.emit("wand_selected", index, oldIndex)
    log_debug("[WandPanel] Selected wand " .. index)
end
```

### 10.6 Set Wand Definitions

```lua
function WandPanel.setWandDefs(wandDefs)
    if not wandDefs or #wandDefs == 0 then
        log_warn("[WandPanel] setWandDefs called with empty array")
        return
    end

    state.wandDefs = wandDefs
    
    -- Initialize adapter with same definitions
    wandAdapter.init(wandDefs)

    -- If already initialized, reinitialize with new wands
    if state.initialized then
        WandPanel.destroy()
        initialize()
    end

    log_debug("[WandPanel] Set " .. #wandDefs .. " wand definitions")
end
```

### 10.7 Destroy Function

```lua
function WandPanel.destroy()
    if not state.initialized then return end

    log_debug("[WandPanel] Destroying...")

    -- STEP 1: Cleanup signals
    cleanupSignalHandlers()

    -- STEP 2: Kill all timers in group
    timer.kill_group(TIMER_GROUP)

    -- STEP 3: Cleanup grids
    if state.triggerGridEntity then
        cleanupGrid(state.triggerGridEntity, "wand_trigger_grid_" .. state.activeWandIndex)
    end
    if state.actionGridEntity then
        cleanupGrid(state.actionGridEntity, "wand_action_grid_" .. state.activeWandIndex)
    end
    state.triggerGridEntity = nil
    state.actionGridEntity = nil

    -- STEP 4: Remove UI boxes
    if state.tabContainerEntity and registry:valid(state.tabContainerEntity) then
        if ui and ui.box and ui.box.Remove then
            ui.box.Remove(registry, state.tabContainerEntity)
        end
    end
    state.tabContainerEntity = nil
    state.tabEntities = {}

    if state.panelEntity and registry:valid(state.panelEntity) then
        if ui and ui.box and ui.box.Remove then
            ui.box.Remove(registry, state.panelEntity)
        end
    end
    state.panelEntity = nil
    state.triggerGridContainerEntity = nil
    state.actionGridContainerEntity = nil

    -- STEP 5: Clear state
    state.cardRegistry = {}
    state.triggerCards = {}
    state.actionCards = {}
    state.initialized = false
    state.isVisible = false

    log_debug("[WandPanel] Destroyed")
end

-- Export cleanup for gameplay.lua resetGameToStart()
WandPanel.cleanupSignalHandlers = cleanupSignalHandlers
```

---

## Phase 11: Testing & Verification

### 11.1 Manual Test Checklist

- [ ] E key opens/closes wand panel
- [ ] Panel appears at top of screen
- [ ] Panel hides completely when closed (no artifacts)
- [ ] Wand tabs visible on left side
- [ ] Clicking tabs switches active wand
- [ ] Number keys 1-4 switch wands when panel open
- [ ] Trigger grid accepts only trigger cards
- [ ] Action grid accepts only action/modifier cards
- [ ] Drag-drop from inventory to wand works
- [ ] Drag-drop from wand to inventory works
- [ ] Drag-drop between wand grids works (action to action)
- [ ] Right-click in inventory equips to wand
- [ ] Right-click in wand grid removes card (returns to inventory)
- [ ] Removing card from wand auto-returns to inventory
- [ ] Wand stats display correctly
- [ ] Stats update when switching wands
- [ ] Grid size matches wand_def.total_card_slots
- [ ] Card positions persist when switching wands
- [ ] Combat still works (wandAdapter sync)
- [ ] No z-order issues (cards render above panel)
- [ ] No memory leaks on repeated open/close

### 11.2 Automated Test Points

```lua
-- Test: Grid dimensions match wand_def
local function testGridDimensions()
    local wandDef = { total_card_slots = 12 }
    local rows, cols = getGridDimensions(wandDef, "action")
    assert(rows * cols >= 12, "Action grid too small: " .. rows .. "x" .. cols)

    local tRows, tCols = getGridDimensions(wandDef, "trigger")
    assert(tRows == 1 and tCols == 1, "Trigger grid should be 1x1: " .. tRows .. "x" .. tCols)
    
    print("[WandPanel Test] Grid dimensions: PASS")
end

-- Test: Card type filtering
local function testCardFiltering()
    -- Create mock cards
    local triggerCard = { type = "trigger" }
    local actionCard = { type = "action" }
    local modifierCard = { type = "modifier" }
    
    -- Trigger grid should accept trigger, reject action/modifier
    -- Action grid should accept action/modifier, reject trigger
    
    print("[WandPanel Test] Card filtering: PASS")
end

-- Test: Adapter sync
local function testAdapterSync()
    local WandPanel = require("ui.wand_panel")
    local wandAdapter = require("ui.wand_grid_adapter")
    
    -- After setting wand defs, adapter should be initialized
    WandPanel.setWandDefs(WandEngine.wand_defs)
    assert(wandAdapter.getWandCount() == #WandEngine.wand_defs, "Adapter wand count mismatch")
    
    print("[WandPanel Test] Adapter sync: PASS")
end
```

---

## Implementation Order

| Phase | Task | Priority | Est. Hours | Dependencies |
|-------|------|----------|------------|--------------|
| 1 | Module skeleton + state management | HIGH | 2 | None |
| 2 | Tab system (left-side buttons) | HIGH | 2 | Phase 1 |
| 3 | Dynamic grids (trigger + action) | HIGH | 3 | Phase 1, 2 |
| 4 | Wand stats display | MEDIUM | 1 | Phase 1, 3 |
| 5 | WandAdapter real-time sync | HIGH | 2 | Phase 3 |
| 6 | Quick equip (right-click) | MEDIUM | 1 | Phase 3, 5 |
| 7 | Input handling (E key) | HIGH | 0.5 | Phase 1 |
| 8 | World board isolation | HIGH | 1 | Phase 5 |
| 9 | Card render timer | HIGH | 1 | Phase 3 |
| 10 | Lifecycle (open/close/destroy) | HIGH | 1.5 | All above |
| 11 | Testing & polish | HIGH | 2 | All above |

**Total Estimated: ~17 hours**

---

## Risk Mitigation

### Risk 1: WandExecutor Dependency on board_sets

**Mitigation**: Keep `board_sets` data structure, just don't render world-space boards. WandPanel syncs to same wandDefs via wandAdapter. The adapter's `syncToExecutor()` calls `WandExecutor.loadWand()` directly.

### Risk 2: Z-Order Conflicts with Inventory

**Mitigation**: Use same z-order hierarchy as player_inventory.lua:
- Panel: `PANEL_Z = 800`
- Grids: `GRID_Z = 850`
- Cards: `CARD_Z = z_orders.ui_tooltips + 100` (must match `assets/scripts/ui/inventory_grid_init.lua`)
- Dragged: `DRAG_Z = z_orders.ui_tooltips + 500`

Panel at screen top naturally separates from bottom inventory.

### Risk 3: Card Duplication

**Mitigation**: Use itemRegistry as single source of truth for card locations. Grid transfer module handles atomic moves. When removing from wand, always return to inventory.

### Risk 4: Performance with Multiple Wands

**Mitigation**: Only render cards for active wand. Use dirty-flag optimization in wandAdapter. Batch card rendering in single render timer.

---

## Resolved Open Questions

1. **Slot sprites**: Reuse `test-inventory-square-single.png` from player_inventory.lua. Can add custom sprites later.

2. **Tab icons**: Use wand name abbreviation (first 2 chars) or number. Can add wand icon sprites later.

3. **Color theme**: Confirmed:
   - Triggers: `cyan_dark` (matches existing trigger theming)
   - Actions: `apricot_cream_dark` (matches existing action theming)
   - Stats: Various colors for different stats

4. **Replace `wand_loadout_ui.lua`**: Keep during migration for reference/parity checks, delete after WandPanel is stable and gameplay wiring is updated.

---

## References

- `assets/scripts/ui/player_inventory.lua` - Primary reference implementation (1554 lines)
- `docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md` - Architectural patterns (1085 lines)
- `assets/scripts/ui/wand_grid_adapter.lua` - Combat sync interface (699 lines)
- `assets/scripts/ui/inventory_grid_init.lua` - Grid drag-drop setup (867 lines)
- `assets/scripts/core/grid_transfer.lua` - Atomic cross-grid transfer (rollback-safe)
- `assets/scripts/ui/inventory_quick_equip.lua` - Right-click equip integration point
- `assets/scripts/ui/wand_loadout_ui.lua` - Existing wand loadout UI (replacement target)
- `assets/scripts/core/card_eval_order_test.lua` - Wand and card definitions
- `assets/scripts/core/gameplay.lua:5554` - Current world board implementation
- `assets/scripts/wand/wand_executor.lua` - Combat execution system
