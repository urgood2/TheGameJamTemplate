# **BULLETPROOF UI PANEL IMPLEMENTATION GUIDE**
### Based on `assets/scripts/ui/player_inventory.lua` as Source of Truth

---

## **EXECUTIVE SUMMARY**

This guide enables you to implement **skill trees, equipment windows, character sheets**, or any grid-based UI panel that will work correctly **on the first try** by following the exact architectural patterns from `assets/scripts/ui/player_inventory.lua`.

**Core Architecture**: Module-level state → Initialize once (spawn hidden) → Show/hide by moving offscreen → Dynamic content via `ReplaceChildren()` → Timer-driven rendering → Grouped cleanup.

Note: Many identifiers in the snippets (`registry`, `ui`, `layers`, `layer_order_system`, `Transform`, etc.) are **C++ globals injected into the Lua VM**. Do not `require()` them.

---

## **1. PANEL STRUCTURE TEMPLATE**

### 1.1 File Skeleton (Copy This Exactly)

```lua
--[[
================================================================================
YOUR_PANEL_NAME - Brief description
================================================================================
]]

local YourPanel = {}

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

-- CONSTANTS
local TIMER_GROUP = "your_panel"  -- UNIQUE per panel
local PANEL_ID = "your_panel_id"
	local RENDER_LAYER = "ui"

	-- Z-ORDER HIERARCHY (DO NOT CHANGE THESE VALUES)
	local PANEL_Z = 800
	local GRID_Z = 850
	local CARD_Z = z_orders.ui_tooltips + 100  -- Keep in sync with InventoryGridInit/CardUIPolicy UI_CARD_Z
	local OFFSCREEN_Y_OFFSET = 600

-- LAYOUT CONSTANTS
local SLOT_WIDTH = 80
local SLOT_HEIGHT = 80
local SLOT_SPACING = 4
local GRID_ROWS = 3
local GRID_COLS = 6
local PANEL_PADDING = 10

-- MODULE STATE (single source of truth)
local state = {
    initialized = false,
    isVisible = false,
    
    -- Entities
    panelEntity = nil,
    closeButtonEntity = nil,
    gridContainerEntity = nil,
    
    -- Grid management
    activeGrid = nil,
    grids = {},
    activeTab = "default",
    tabItems = {},  -- Tab -> {[slotIndex] = itemEntity}
    
    -- Item tracking
    cardRegistry = {},
    
    -- Cleanup tracking
    signalHandlers = {},
    inputHandlerInitialized = false,
    
    -- Position cache
    panelX = 0,
    panelY = 0,
}
```

### 1.2 Tab Configuration Pattern

```lua
local TAB_CONFIG = {
    skills = {
        id = "skills_grid",
        label = "Skills",
        rows = 4,
        cols = 8,
    },
    passives = {
        id = "passives_grid",
        label = "Passives",
        rows = 3,
        cols = 6,
    },
}
local TAB_ORDER = { "skills", "passives" }
```

---

## **2. STATE MANAGEMENT PATTERN**

### 2.1 Visibility Control (THE Critical Function)

```lua
-- EXACT pattern from PlayerInventory - DO NOT MODIFY
local function setEntityVisible(entity, visible, onscreenX, onscreenY, dbgLabel)
    if not entity or not registry:valid(entity) then return end

    local targetX = onscreenX
    local targetY = visible and onscreenY or (GetScreenHeight())

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
```

### 2.2 Card/Item Visibility Control

```lua
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

## **3. GRID SYSTEM INTEGRATION**

### 3.1 Grid Definition Creation

```lua
local function createGridDefinition(tabId)
    local cfg = TAB_CONFIG[tabId]
    if not cfg then return nil end

    return dsl.strict.inventoryGrid {
        id = cfg.id,
        rows = cfg.rows or GRID_ROWS,
        cols = cfg.cols or GRID_COLS,
        slotSize = { w = SLOT_WIDTH, h = SLOT_HEIGHT },
        slotSpacing = SLOT_SPACING,

        config = {
            allowDragIn = true,
            allowDragOut = true,
            stackable = false,
            slotSprite = "test-inventory-square-single.png",  -- Your slot sprite
            padding = 6,
            backgroundColor = "blackberry",
            snapVisual = false,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
        },

        -- Optional callbacks
        onSlotChange = function(gridEntity, slotIndex, oldItem, newItem)
            log_debug("[YourPanel] Slot " .. slotIndex .. " changed")
        end,

        onSlotClick = function(gridEntity, slotIndex, button)
            if button == 2 then  -- Right-click
                local item = grid.getItemAtIndex(gridEntity, slotIndex)
                if item then
                    -- Handle right-click action (e.g., context menu)
                end
            end
        end,
    }
end
```

### 3.2 Grid Injection Pattern

```lua
local function injectGridForTab(tabId)
    if not state.gridContainerEntity or not registry:valid(state.gridContainerEntity) then
        log_warn("[YourPanel] Grid container not available for tab injection")
        return nil
    end

    local gridDef = createGridDefinition(tabId)
    if not gridDef then return nil end

    -- STEP 1: Replace container children with new grid
    local replaced = ui.box.ReplaceChildren(state.gridContainerEntity, gridDef)
    if not replaced then
        log_warn("[YourPanel] Failed to replace grid container children")
        return nil
    end

    -- STEP 2: CRITICAL - Reapply state tags so newly injected elements render
    if ui and ui.box and ui.box.AddStateTagToUIBox then
        ui.box.AddStateTagToUIBox(registry, state.panelEntity, "default_state")
    end
    
    -- STEP 3: CRITICAL - Force layout recalculation
    if ui and ui.box and ui.box.RenewAlignment then
        ui.box.RenewAlignment(registry, state.panelEntity)
    end

    -- STEP 4: Find the spawned grid entity
    local cfg = TAB_CONFIG[tabId]
    local gridEntity = ui.box.GetUIEByID(registry, state.gridContainerEntity, cfg.id)
    if not gridEntity then
        log_warn("[YourPanel] Could not find injected grid entity")
        return nil
    end

    -- STEP 5: Initialize grid for drag-drop interaction
    local success = InventoryGridInit.initializeIfGrid(gridEntity, cfg.id)
    if not success then
        log_warn("[YourPanel] Grid initialization failed")
    end

    return gridEntity
end
```

### 3.3 Grid Cleanup Function

```lua
local function cleanupGridEntity(gridEntity, tabId)
    if not gridEntity then return end

    -- STEP 1: Unregister from drag feedback system
    InventoryGridInit.unregisterGridForDragFeedback(gridEntity)

    -- STEP 2: Clean up slot metadata
    local cfg = TAB_CONFIG[tabId]
    if cfg then
        local slotCount = (cfg.rows or GRID_ROWS) * (cfg.cols or GRID_COLS)
        for i = 1, slotCount do
            local slotEntity = grid.getSlotEntity(gridEntity, i)
            if slotEntity then
                InventoryGridInit.cleanupSlotMetadata(slotEntity)
            end
        end
    end

    -- STEP 3: Clear item location registry for this grid
    itemRegistry.clearGrid(gridEntity)

    -- STEP 4: Clean up grid internal state
    grid.cleanup(gridEntity)

    -- STEP 5: Clean up DSL grid registry
    if cfg then
        dsl.cleanupGrid(cfg.id)
    end
end
```

---

## **4. TAB SYSTEM**

### 4.1 Tab Item Stashing (Before Switching)

```lua
local function getTabItemStore(tabId)
    if not state.tabItems[tabId] then
        state.tabItems[tabId] = {}
    end
    return state.tabItems[tabId]
end

local function stashGridItems(tabId, gridEntity)
    if not gridEntity then return end
    
    local store = getTabItemStore(tabId)
    -- Clear existing store
    for k in pairs(store) do
        store[k] = nil
    end

    -- Move items from grid to store
    local items = grid.getAllItems(gridEntity)
    for slotIndex, itemEntity in pairs(items) do
        if itemEntity and registry:valid(itemEntity) then
            store[slotIndex] = itemEntity
            grid.removeItem(gridEntity, slotIndex)
            setCardEntityVisible(itemEntity, false)
        end
    end
end
```

### 4.2 Tab Item Restoration (After Switching)

```lua
local function restoreGridItems(tabId, gridEntity)
    if not gridEntity then return end
    local store = state.tabItems[tabId]
    if not store then return end

    for slotIndex, itemEntity in pairs(store) do
        if itemEntity and registry:valid(itemEntity) then
            -- Re-setup draggable for new grid
            InventoryGridInit.makeItemDraggable(itemEntity, gridEntity)
            
            -- Add to grid
            local success, placedSlot = grid.addItem(gridEntity, itemEntity, slotIndex)
            if success then
                local slotEntity = grid.getSlotEntity(gridEntity, placedSlot or slotIndex)
                if slotEntity then
                    InventoryGridInit.centerItemOnSlot(itemEntity, slotEntity, false)
                end
                setCardEntityVisible(itemEntity, state.isVisible)
            end
        end
    end
end
```

### 4.3 Tab Switch Function

```lua
local function switchTab(tabId)
    if state.activeTab == tabId then return end

    local oldTab = state.activeTab
    local oldGrid = state.activeGrid

    -- STEP 1: Stash and cleanup old grid
    if oldGrid then
        stashGridItems(oldTab, oldGrid)
        cleanupGridEntity(oldGrid, oldTab)
        state.grids[oldTab] = nil
    end

    -- STEP 2: Update active tab
    state.activeTab = tabId

    -- STEP 3: Inject new grid
    state.activeGrid = injectGridForTab(tabId)
    state.grids[tabId] = state.activeGrid

    -- STEP 4: Restore items to new grid
    if state.activeGrid then
        restoreGridItems(tabId, state.activeGrid)
    end

    -- STEP 5: Update visibility
    if state.isVisible then
        setAllCardsVisible(false)
        if state.activeGrid then
            setGridItemsVisible(state.activeGrid, true)
        end
    end

    -- STEP 6: Update tab button highlighting
    for id, btnEntity in pairs(state.tabButtons or {}) do
        if btnEntity and registry:valid(btnEntity) then
            local isActive = (id == tabId)
            local uiCfg = component_cache.get(btnEntity, UIConfig)
            if uiCfg and _G.util and _G.util.getColor then
                uiCfg.color = isActive and _G.util.getColor("green") or _G.util.getColor("gray")
            end
        end
    end
end
```

---

## **5. SIGNAL INTEGRATION**

### 5.1 Signal Handler Registration

```lua
local function setupSignalHandlers()
    local function registerHandler(eventName, handler)
        signal.register(eventName, handler)
        table.insert(state.signalHandlers, { event = eventName, handler = handler })
    end
    
    local function isOurGrid(gridEntity)
        return gridEntity == state.activeGrid
    end
    
    -- Grid item events
    registerHandler("grid_item_added", function(gridEntity, slotIndex, itemEntity)
        if isOurGrid(gridEntity) then
            -- Update slot count, play sound, etc.
            if playSoundEffect then
                playSoundEffect("effects", "button-click")
            end
        end
    end)
    
    registerHandler("grid_item_removed", function(gridEntity, slotIndex, itemEntity)
        if isOurGrid(gridEntity) then
            -- Update UI as needed
        end
    end)

    registerHandler("grid_item_moved", function(gridEntity, fromSlot, toSlot, itemEntity)
        if isOurGrid(gridEntity) then
            -- Handle move
        end
    end)
end
```

### 5.2 Signal Cleanup

```lua
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

---

## **6. INPUT HANDLING**

### 6.1 Keyboard Input Setup

```lua
local function setupInputHandler()
    if state.inputHandlerInitialized then return end
    state.inputHandlerInitialized = true

    timer.run_every_render_frame(function()
        -- Toggle key (change KEY_K to your preferred key)
        local togglePressed = isKeyPressed and isKeyPressed("KEY_K")
        if togglePressed then
            YourPanel.toggle()
        end

        -- ESC to close (if open)
        if state.isVisible and isKeyPressed and isKeyPressed("KEY_ESCAPE") then
            YourPanel.close()
        end
    end, nil, "your_panel_input", TIMER_GROUP)
end
```

---

## **7. CARD/ITEM ENTITY CREATION**

### 7.1 Creating Draggable Items

```lua
local function createItem(spriteName, x, y, itemData, gridEntity)
    -- STEP 1: Create animated sprite entity
    local entity = animation_system.createAnimatedObjectWithTransform(
        spriteName, true, x or 0, y or 0, nil, true  -- shadow enabled
    )

    if not entity or not registry:valid(entity) then
        log_warn("[YourPanel] Failed to create item entity")
        return nil
    end

    -- STEP 2: DO NOT add ObjectAttachedToUITag - it breaks shader rendering!

    -- STEP 3: Set initial state tag for visibility
    if add_state_tag then
        add_state_tag(entity, "default_state")
    end

    -- STEP 4: Setup shader pipeline (optional, for 3D skew effect)
    if shader_pipeline and shader_pipeline.ShaderPipelineComponent then
        local shaderComp = registry:emplace(entity, shader_pipeline.ShaderPipelineComponent)
        shaderComp:addPass("3d_skew")
    end

    -- STEP 5: Store item data
    local scriptData = {
        entity = entity,
        id = itemData.id,
        name = itemData.name,
        itemData = itemData,
        noVisualSnap = true,  -- Prevents visual jitter
    }
    if setScriptTableForEntityID then
        setScriptTableForEntityID(entity, scriptData)
    end
    state.cardRegistry[entity] = scriptData

    -- STEP 6: CRITICAL - Setup for screen-space (z-order, size, collision)
    CardUIPolicy.setupForScreenSpace(entity)

    -- STEP 7: Make draggable
    InventoryGridInit.makeItemDraggable(entity, gridEntity)

    return entity
end
```

### 7.2 Adding Item to Grid

```lua
function YourPanel.addItem(itemEntity, category, itemData)
    if not state.initialized then
        initialize()
    end
    
    category = category or state.activeTab
    local cfg = TAB_CONFIG[category]
    if not cfg then return false end

    -- Store item data
    if itemData then
        state.cardRegistry[itemEntity] = itemData
    end

    -- Setup for screen-space
    CardUIPolicy.setupForScreenSpace(itemEntity)
    
    local gridEntity = state.grids[category]
    if gridEntity then
        InventoryGridInit.makeItemDraggable(itemEntity, gridEntity)
        
        local success, slotIndex = grid.addItem(gridEntity, itemEntity)
        if success then
            local slotEntity = grid.getSlotEntity(gridEntity, slotIndex)
            if slotEntity then
                InventoryGridInit.centerItemOnSlot(itemEntity, slotEntity, false)
            end
            setCardEntityVisible(itemEntity, state.isVisible)
            return true
        end
    end

    return false
end
```

---

## **8. PANEL DEFINITION**

### 8.1 Complete Panel Definition

```lua
local function createHeader()
    return dsl.strict.hbox {
        config = {
            id = "panel_header",
            padding = 8,
        },
        children = {
            dsl.strict.text("Your Panel Title", {
                id = "header_title",
                fontSize = 14,
                color = "gold",
                shadow = true,
            }),
            dsl.filler(),
            dsl.strict.button("X", {
                id = "close_btn",
                fontSize = 12,
                color = "red",
                minWidth = 24,
                minHeight = 24,
                onClick = function()
                    YourPanel.close()
                end,
            }),
        },
    }
end

local function createTabs()
    local tabChildren = {}
    for _, tabId in ipairs(TAB_ORDER) do
        local cfg = TAB_CONFIG[tabId]
        local isActive = (tabId == state.activeTab)

        table.insert(tabChildren, dsl.strict.button(cfg.label, {
            id = "tab_" .. tabId,
            fontSize = 10,
            padding = 7,
            color = isActive and "green" or "gray",
            onClick = function()
                switchTab(tabId)
            end,
        }))
    end

    return dsl.strict.hbox {
        config = { padding = 4 },
        children = tabChildren,
    }
end

local function createGridContainer()
    return dsl.strict.vbox {
        config = {
            id = "grid_container",  -- MUST have ID for injection
            padding = 0,
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_TOP),
        },
        children = {}  -- Empty - grid injected at runtime
    }
end

local function createPanelDefinition()
    return dsl.strict.spritePanel {
        sprite = "inventory-back-panel.png",  -- Your panel background
        borders = { 0, 0, 0, 0 },
        sizing = "stretch",
        config = {
            id = PANEL_ID,
            padding = PANEL_PADDING,
            minWidth = 560,  -- Calculate: GRID_COLS * SLOT_WIDTH + padding
            minHeight = 350,
        },
        children = {
            createHeader(),
            createTabs(),
            createGridContainer(),
        },
    }
end
```

---

## **9. LIFECYCLE FUNCTIONS**

### 9.1 Position Calculation

```lua
local function calculatePositions()
    local screenW = globals.screenWidth()
    local screenH = globals.screenHeight()

    if not screenW or not screenH or screenW <= 0 or screenH <= 0 then
        return false
    end

    local panelW = 560  -- Match your minWidth
    local panelH = 350  -- Match your minHeight

    state.panelX = (screenW - panelW) / 2  -- Centered
    state.panelY = screenH - panelH        -- Bottom-aligned

    return true
end
```

### 9.2 Per-Frame Render Loop (For Shader Pipeline Cards)

```lua
local function setupCardRenderTimer()
    local UI_CARD_Z = CARD_Z

    local function snapItemsToSlots()
        local activeGrid = state.activeGrid
        if not activeGrid then return end

        local inputState = input and input.getState and input.getState()
        local draggedEntity = inputState and inputState.cursor_dragging_target

        local items = grid.getAllItems(activeGrid)
        for slotIndex, itemEntity in pairs(items) do
            if itemEntity and registry:valid(itemEntity) and itemEntity ~= draggedEntity then
                local slotEntity = grid.getSlotEntity(activeGrid, slotIndex)
                if slotEntity then
                    InventoryGridInit.centerItemOnSlot(itemEntity, slotEntity, false)
                end
            end
        end
    end

    local function isItemInActiveGrid(eid)
        local activeGrid = state.activeGrid
        if not activeGrid then return false end
        local location = itemRegistry.getLocation(eid)
        return location and location.grid == activeGrid
    end

    timer.run_every_render_frame(function()
        if not state.isVisible then return end

        snapItemsToSlots()

        -- Batch render cards with shader pipeline (matches assets/scripts/ui/player_inventory.lua)
        if not (command_buffer and command_buffer.queueDrawBatchedEntities and layers and layers.sprites) then
            return
        end

        local batchedBucketsByZ = {}

        for eid, _ in pairs(state.cardRegistry) do
            if eid and registry:valid(eid) and isItemInActiveGrid(eid) then
                local hasPipeline = shader_pipeline and shader_pipeline.ShaderPipelineComponent
                    and registry:has(eid, shader_pipeline.ShaderPipelineComponent)
                local animComp = component_cache.get(eid, AnimationQueueComponent)

                if animComp then
                    animComp.drawWithLegacyPipeline = true
                end

                if hasPipeline and animComp and not animComp.noDraw then
                    -- Respect drag z-order changes by using the entity's assigned z.
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
                    -- Render to sprites layer (not ui) so z-ordering works with planning cards.
                    command_buffer.queueDrawBatchedEntities(layers.sprites, function(cmd)
                        cmd.registry = registry
                        cmd.entities = entityList
                        cmd.autoOptimize = true
                    end, z, layer.DrawCommandSpace.Screen)
                end
            end
        end
    end, nil, "card_render_timer", TIMER_GROUP)
end
```

### 9.3 Initialize Function

```lua
local function initialize()
    if state.initialized then return end

    if not calculatePositions() then
        log_warn("[YourPanel] Cannot initialize - screen dimensions not ready")
        return
    end

    -- STEP 1: Create panel definition
    local panelDef = createPanelDefinition()

    -- STEP 2: Spawn OFFSCREEN (hidden)
    state.panelEntity = dsl.spawn(
        { x = state.panelX, y = state.panelY + OFFSCREEN_Y_OFFSET },
        panelDef,
        RENDER_LAYER,
        PANEL_Z
    )

    -- STEP 3: CRITICAL - Set draw layer for z-order sorting
    if ui and ui.box and ui.box.set_draw_layer then
        ui.box.set_draw_layer(state.panelEntity, "sprites")
    end

    -- STEP 4: CRITICAL - Add state tags so elements render
    if ui and ui.box and ui.box.AddStateTagToUIBox then
        ui.box.AddStateTagToUIBox(registry, state.panelEntity, "default_state")
    end

    -- STEP 5: Cache important child entities
    state.gridContainerEntity = ui.box.GetUIEByID(registry, state.panelEntity, "grid_container")
    state.closeButtonEntity = ui.box.GetUIEByID(registry, state.panelEntity, "close_btn")

    -- STEP 6: Cache tab buttons
    state.tabButtons = {}
    for _, tabId in ipairs(TAB_ORDER) do
        local btnEntity = ui.box.GetUIEByID(registry, state.panelEntity, "tab_" .. tabId)
        if btnEntity then
            state.tabButtons[tabId] = btnEntity
        end
    end

    -- STEP 7: Inject first grid
    state.activeGrid = injectGridForTab(state.activeTab)
    if state.activeGrid then
        state.grids[state.activeTab] = state.activeGrid
    end

    -- STEP 8: Setup systems
    setupSignalHandlers()
    setupCardRenderTimer()

    state.initialized = true
end
```

### 9.4 Open/Close/Toggle

```lua
function YourPanel.open()
    if not state.initialized then
        initialize()
    end

    if state.isVisible then return end

    calculatePositions()
    setEntityVisible(state.panelEntity, true, state.panelX, state.panelY, "panel")

    state.isVisible = true

    -- Show cards in active grid
    setAllCardsVisible(false)
    if state.activeGrid then
        setGridItemsVisible(state.activeGrid, true)
    end

    signal.emit("your_panel_opened")

    if playSoundEffect then
        playSoundEffect("effects", "button-click")
    end
end

function YourPanel.close()
    if not state.isVisible then return end

    setEntityVisible(state.panelEntity, false, state.panelX, state.panelY, "panel")

    state.isVisible = false

    -- Hide all cards
    setAllCardsVisible(false)

    signal.emit("your_panel_closed")
end

function YourPanel.toggle()
    if state.isVisible then
        YourPanel.close()
    else
        YourPanel.open()
    end
end

function YourPanel.isOpen()
    return state.isVisible
end
```

### 9.5 Destroy Function

```lua
function YourPanel.destroy()
    if not state.initialized then return end

    -- STEP 1: Cleanup signals
    cleanupSignalHandlers()

    -- STEP 2: Kill all timers in group
    timer.kill_group(TIMER_GROUP)

    -- STEP 3: Destroy owned card entities
    for cardEntity in pairs(state.cardRegistry) do
        if cardEntity and registry:valid(cardEntity) then
            registry:destroy(cardEntity)
        end
    end
    state.cardRegistry = {}

    -- STEP 4: Cleanup active grid
    if state.activeGrid then
        stashGridItems(state.activeTab, state.activeGrid)
        cleanupGridEntity(state.activeGrid, state.activeTab)
    end
    state.activeGrid = nil
    state.grids = {}
    state.tabItems = {}

    -- STEP 5: Remove UI box
    if state.panelEntity and registry:valid(state.panelEntity) then
        if ui and ui.box and ui.box.Remove then
            ui.box.Remove(registry, state.panelEntity)
        end
    end
    state.panelEntity = nil
    state.gridContainerEntity = nil
    state.tabButtons = {}

    state.initialized = false
    state.isVisible = false
end
```

---

## **10. CLEANUP CHECKLIST**

### On `close()` (Hide but keep alive):
- [ ] Move panel offscreen via `setEntityVisible(panelEntity, false, ...)`
- [ ] Clear state tags on all card entities (`clear_state_tags`)
- [ ] Emit closed signal (optional)

### On `destroy()` (Full teardown):
- [ ] `cleanupSignalHandlers()` - Remove all registered handlers
- [ ] `timer.kill_group(TIMER_GROUP)` - Stop all timers
- [ ] For each grid:
  - [ ] `InventoryGridInit.unregisterGridForDragFeedback(gridEntity)`
  - [ ] For each slot: `InventoryGridInit.cleanupSlotMetadata(slotEntity)`
  - [ ] `itemRegistry.clearGrid(gridEntity)`
  - [ ] `grid.cleanup(gridEntity)`
  - [ ] `dsl.cleanupGrid(gridId)`
- [ ] Destroy owned card entities: `registry:destroy(cardEntity)`
- [ ] Remove UI boxes: `ui.box.Remove(registry, panelEntity)`
- [ ] Reset all state to initial values

---

## **11. COMMON PITFALLS (WILL BREAK IF DONE WRONG)**

| # | Pitfall | Symptom | Fix |
|---|---------|---------|-----|
| 1 | Adding `ObjectAttachedToUITag` to cards | Cards don't render via shader pipeline | **NEVER** add this tag to draggable items |
| 2 | Forgetting `default_state` tag | UI elements exist but don't render | Call `ui.box.AddStateTagToUIBox` after spawn AND after `ReplaceChildren` |
| 3 | Not moving `UIBoxComponent.uiRoot` | Visual moves but clicks don't work | Always move BOTH entity Transform AND uiRoot Transform |
| 4 | Skipping `ui.box.RenewAlignment` | Injected grids overlap/misaligned | Call after ANY `ReplaceChildren` operation |
| 5 | Not calling `InventoryGridInit.initializeIfGrid` | Grid looks correct but drag-drop fails | Always call after grid injection |
| 6 | Skipping `CardUIPolicy.setupForScreenSpace` | Wrong collision, wrong z-order, invisible | Always call when adding items to inventory |
| 7 | Not cleaning all 3 registries | Memory leaks, stale drag state, duplication | Must clear: `itemRegistry`, `grid`, `dsl.cleanupGrid` |
| 8 | Using wrong z-order values | Cards hidden behind panel/grid | Use the same hierarchy as the inventory (`PANEL_Z=800`, `GRID_Z=850`, `UI_CARD_Z=z_orders.ui_tooltips+100`, `DRAG_Z=z_orders.ui_tooltips+500`) |
| 9 | Not using timer groups | Timers keep running after destroy | Always use `TIMER_GROUP` and `timer.kill_group()` |
| 10 | Signal handler leak | Handlers accumulate on reinit | Track handlers and call `signal.remove()` on cleanup |

---

## **12. Z-ORDER REFERENCE**

```
BACKGROUND      = 0       -- World background
BOARD           = 100     -- Game board
CARD (world)    = 1001    -- Cards on planning board (base z; climbs per-area)
TOP_CARD        = 1002    -- Dragged planning card
STATUS_ICONS    = 850     -- Status effects
────────────────────────── UI LAYER ──────────────────────────
PANEL_Z         = 800     -- Inventory panel background
GRID_Z          = 850     -- Grid slot UI elements
ELEVATED_CARD_Z = z_orders.ui_tooltips        -- Planning cards when inventory open
UI_CARD_Z       = z_orders.ui_tooltips + 100  -- Cards inside inventory grids
UI_TRANSITION   = 1000                        -- Screen transitions
UI_TOOLTIPS     = 1100                        -- Tooltip popups (base)
DRAG_Z          = z_orders.ui_tooltips + 500  -- Currently dragged card (above ALL)
```

---

## **13. QUICK REFERENCE: DSL COMPONENTS**

| Component | Usage | Notes |
|-----------|-------|-------|
| `dsl.strict.vbox` | Vertical container | Use for stacking elements |
| `dsl.strict.hbox` | Horizontal container | Use for rows |
| `dsl.strict.text` | Static text | `color`, `fontSize`, `shadow` |
| `dsl.strict.button` | Clickable button | `onClick`, `color`, `disabled` |
| `dsl.strict.spritePanel` | Nine-patch background | `sprite`, `borders`, `sizing` |
| `dsl.strict.inventoryGrid` | Slot-based grid | `rows`, `cols`, `slotSize`, `config` |
| `dsl.filler` | Flexible space | Pushes adjacent elements apart |
| `dsl.spacer(w, h)` | Fixed space | Invisible padding |

---

## **14. MODULE EXPORT**

```lua
-- Ensure input handler runs after game systems ready
timer.after_opts({
    delay = 0.1,
    action = function()
        setupInputHandler()
    end,
    tag = "your_panel_input_setup",
    group = TIMER_GROUP
})

return YourPanel
```

---

## **15. SOURCE FILES REFERENCE**

This guide was derived from analyzing these source files:

| File | Lines | Purpose |
|------|-------|---------|
| `assets/scripts/ui/player_inventory.lua` | 1554 | **Source of truth** - Main panel with tabs, grids, cards |
| `assets/scripts/core/inventory_grid.lua` | 712 | Grid data layer - slots, items, stacking |
| `assets/scripts/ui/inventory_grid_init.lua` | 866 | Grid UI integration - drag-drop, z-order, callbacks |
| `assets/scripts/ui/ui_syntax_sugar.lua` | 2290 | DSL for declarative UI construction |
| `assets/scripts/core/item_location_registry.lua` | 242 | Single source of truth for item locations |
| `assets/scripts/ui/card_ui_policy.lua` | 433 | Card rendering policy - screen/world space, sizing |
| `assets/scripts/core/grid_transfer.lua` | 354 | Cross-grid transfers with rollback |
| `assets/scripts/ui/ui_decorations.lua` | 542 | Visual overlays and badges |
| `assets/scripts/core/z_orders.lua` | 23 | Z-order constants |

---

This guide covers **every pattern, caveat, and implementation detail** from `assets/scripts/ui/player_inventory.lua`. Follow it exactly, and your skill tree, equipment window, or any other grid-based panel will work correctly on the first try.
