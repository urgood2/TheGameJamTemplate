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

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------

local TIMER_GROUP = "wand_panel"
local PANEL_ID = "wand_panel_id"
local RENDER_LAYER = "sprites"
local ui_scale = require("ui.ui_scale")

-- Z-ORDER HIERARCHY (MUST match player_inventory.lua)
local PANEL_Z = 800
local GRID_Z = 850

-- Load z_orders for card z-index calculation
local z_orders_ok, z_orders_module = pcall(require, "core.z_orders")
local UI_TOOLTIPS_Z = (z_orders_ok and z_orders_module and z_orders_module.ui_tooltips) or 900

-- Must match UI_CARD_Z in inventory_grid_init.lua to avoid z-order reset conflicts.
local CARD_Z = UI_TOOLTIPS_Z + 100
local DRAG_Z = UI_TOOLTIPS_Z + 500  -- Dragged cards above all

local UI = ui_scale.ui

-- Panel positioning
local TOP_MARGIN = UI(16)

-- Tab marker (panel reopen tab)
local TAB_MARKER_WIDTH = UI(64)
local TAB_MARKER_HEIGHT = UI(64)
local TAB_MARKER_MARGIN = UI(6)
local DEFAULT_HIDDEN_OFFSET = UI(-800)

-- LAYOUT CONSTANTS
local SPRITE_BASE_W = 32
local SPRITE_BASE_H = 32
local SPRITE_SCALE = ui_scale.SPRITE_SCALE
local SLOT_WIDTH = ui_scale.sprite(SPRITE_BASE_W)   -- 80px
local SLOT_HEIGHT = ui_scale.sprite(SPRITE_BASE_H)  -- 80px
local SLOT_SPACING = UI(4)
local GRID_PADDING = UI(6)

local ACTION_GRID_COLS = 4  -- Fixed column count for action grids

local TAB_WIDTH = UI(48)
local TAB_HEIGHT = UI(64)
local TAB_SPACING = UI(4)
local TAB_OFFSET_X = -TAB_WIDTH - UI(8)  -- Position left of panel with gap

local HEADER_HEIGHT = UI(32)
local SECTION_HEADER_HEIGHT = UI(24)
local PANEL_PADDING = UI(12)
local COLUMN_SPACING = UI(12)
local STATS_BOX_WIDTH = UI(190)

--------------------------------------------------------------------------------
-- MODULE STATE (single source of truth)
--------------------------------------------------------------------------------

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
    tabMarkerEntity = nil,
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
    gameStateHandlerRegistered = false,
    suspendSync = false,

    -- Position cache
    panelX = 0,
    panelY = 0,
    panelWidth = 0,
    panelHeight = 0,
}

-- Forward declaration for use in slot click callbacks (defined later)
local returnCardToInventory

--------------------------------------------------------------------------------
-- INTERNAL HELPERS
--------------------------------------------------------------------------------

--- Calculate grid dimensions based on wand definition and grid type
--- @param wandDef table Wand definition with total_card_slots
--- @param gridType string "trigger" or "action"
--- @return number rows, number cols
local function getGridDimensions(wandDef, gridType)
    if gridType == "trigger" then
        -- Trigger grid: single slot (current engine supports 1 trigger card per wand)
        return 1, 1
    else
        -- Action grid: single row with all slots
        -- Minimum of 1 slot to prevent zero-col grids
        local totalSlots = math.max(wandDef.total_card_slots or 8, 1)
        local rows = 1
        local cols = totalSlots
        return rows, cols
    end
end

--- Calculate panel dimensions based on active wand
--- @param wandDef table Wand definition
--- @return number width, number height
local function calculatePanelDimensions(wandDef)
    local triggerRows, triggerCols = getGridDimensions(wandDef, "trigger")
    local actionRows, actionCols = getGridDimensions(wandDef, "action")

    local triggerGridWidth = triggerCols * SLOT_WIDTH + (triggerCols - 1) * SLOT_SPACING + GRID_PADDING * 2
    local actionGridWidth = actionCols * SLOT_WIDTH + (actionCols - 1) * SLOT_SPACING + GRID_PADDING * 2

    local triggerGridHeight = triggerRows * SLOT_HEIGHT + (triggerRows - 1) * SLOT_SPACING + GRID_PADDING * 2
    local actionGridHeight = actionRows * SLOT_HEIGHT + (actionRows - 1) * SLOT_SPACING + GRID_PADDING * 2

    local triggerSectionHeight = SECTION_HEADER_HEIGHT + triggerGridHeight
    local actionSectionHeight = SECTION_HEADER_HEIGHT + actionGridHeight
    local statsBoxHeight = math.max(triggerSectionHeight, actionSectionHeight)

    local contentWidth = triggerGridWidth + actionGridWidth + STATS_BOX_WIDTH + (COLUMN_SPACING * 2)
    local contentHeight = math.max(triggerSectionHeight, actionSectionHeight, statsBoxHeight)

    return contentWidth + PANEL_PADDING * 2, contentHeight + PANEL_PADDING * 2
end

--- Compute hidden Y offset so the tab marker stays visible at the top edge
local function getHiddenPanelOffset()
    if state.panelHeight and state.panelHeight > 0 then
        local keepVisible = TAB_MARKER_HEIGHT + TAB_MARKER_MARGIN
        return -math.max(0, state.panelHeight - keepVisible)
    end
    return DEFAULT_HIDDEN_OFFSET
end

--- Get tab marker offsets relative to panel
local function getTabMarkerOffsets()
    local offsetX = math.floor((state.panelWidth - TAB_MARKER_WIDTH) / 2)
    local offsetY = math.max(0, (state.panelHeight - TAB_MARKER_HEIGHT - TAB_MARKER_MARGIN))
    return offsetX, offsetY
end

--------------------------------------------------------------------------------
-- VISIBILITY CONTROL
--------------------------------------------------------------------------------

--- Set entity visibility by moving it on/off screen
--- @param entity number Entity ID
--- @param visible boolean Whether to show
--- @param onscreenX number X position when visible
--- @param onscreenY number Y position when visible
--- @param dbgLabel string? Debug label
local function setEntityVisible(entity, visible, onscreenX, onscreenY, dbgLabel)
    if not entity then return end

    -- Check if registry is available (runtime only)
    if not _G.registry or not _G.registry.valid then return end
    if not _G.registry:valid(entity) then return end

    local targetX = onscreenX
    -- For top-of-screen panel: hide by moving UP while leaving tab visible
    local targetY = visible and onscreenY or (onscreenY + getHiddenPanelOffset())

    -- Update Transform for the main entity
    local component_cache = _G.component_cache
    if component_cache and component_cache.get then
        local t = component_cache.get(entity, _G.Transform)
        if t then
            t.actualX = targetX
            t.actualY = targetY
        end

        -- Update InheritedProperties offset (used by layout system)
        local role = component_cache.get(entity, _G.InheritedProperties)
        if role and role.offset then
            role.offset.x = targetX
            role.offset.y = targetY
        end

        -- CRITICAL: For UIBox entities, also update the uiRoot
        local boxComp = component_cache.get(entity, _G.UIBoxComponent)
        if boxComp and boxComp.uiRoot and _G.registry:valid(boxComp.uiRoot) then
            local rt = component_cache.get(boxComp.uiRoot, _G.Transform)
            if rt then
                rt.actualX = targetX
                rt.actualY = targetY
            end
            local rootRole = component_cache.get(boxComp.uiRoot, _G.InheritedProperties)
            if rootRole and rootRole.offset then
                rootRole.offset.x = targetX
                rootRole.offset.y = targetY
            end

            -- Force layout recalculation
            if _G.ui and _G.ui.box and _G.ui.box.RenewAlignment then
                _G.ui.box.RenewAlignment(_G.registry, entity)
            end
        end
    end
end

--- Set card entity visibility using state tags
--- @param itemEntity number Entity ID
--- @param visible boolean Whether to show
local function setCardEntityVisible(itemEntity, visible)
    if not itemEntity then return end
    if not _G.registry or not _G.registry.valid then return end
    if not _G.registry:valid(itemEntity) then return end

    if visible then
        if _G.add_state_tag then
            _G.add_state_tag(itemEntity, "default_state")
        end
    else
        if _G.clear_state_tags then
            _G.clear_state_tags(itemEntity)
        end
    end
end

--- Set all cards in registry visible/hidden
--- @param visible boolean Whether to show
local function setAllCardsVisible(visible)
    for itemEntity in pairs(state.cardRegistry) do
        setCardEntityVisible(itemEntity, visible)
    end
end

--- Toggle tab marker visibility
local function setTabMarkerVisible(visible)
    if not state.tabMarkerEntity then return end
    if not _G.registry or not _G.registry.valid then return end
    if not _G.registry:valid(state.tabMarkerEntity) then return end

    if _G.ui and _G.ui.box and _G.ui.box.AddStateTagToUIBox and _G.ui.box.ClearStateTagsFromUIBox then
        if visible then
            _G.ui.box.AddStateTagToUIBox(_G.registry, state.tabMarkerEntity, "default_state")
        else
            _G.ui.box.ClearStateTagsFromUIBox(_G.registry, state.tabMarkerEntity)
        end
        return
    end

    if visible then
        if _G.add_state_tag then
            _G.add_state_tag(state.tabMarkerEntity, "default_state")
        end
    else
        if _G.clear_state_tags then
            _G.clear_state_tags(state.tabMarkerEntity)
        end
    end
end

--- Update the panel header title for the active wand
local function updateHeaderTitle()
    if not state.panelEntity then return end
    if not _G.registry or not _G.registry.valid then return end
    if not _G.registry:valid(state.panelEntity) then return end

    local wandDef = state.wandDefs[state.activeWandIndex]
    if not wandDef then return end

    local titleText = wandDef.name or ("Wand " .. state.activeWandIndex)

    if _G.ui and _G.ui.box and _G.ui.box.GetUIEByID then
        local titleEntity = _G.ui.box.GetUIEByID(_G.registry, state.panelEntity, "wand_panel_title")
        if titleEntity and _G.component_cache and _G.UITextComponent then
            local uiText = _G.component_cache.get(titleEntity, _G.UITextComponent)
            if uiText then
                uiText.text = titleText
            end
        end
    end
end

--- Set all items in a grid visible/hidden
--- @param gridEntity number Grid entity ID
--- @param visible boolean Whether to show
local function setGridItemsVisible(gridEntity, visible)
    if not gridEntity then return end

    -- Try to get grid module
    local ok, grid = pcall(require, "core.inventory_grid")
    if not ok then return end

    local items = grid.getAllItems(gridEntity)
    if items then
        for _, itemEntity in pairs(items) do
            setCardEntityVisible(itemEntity, visible)
        end
    end
end

--- Remove all items from a grid (optionally hide removed items)
--- @param gridEntity number Grid entity ID
--- @param hideItems boolean Whether to hide items after removal
--- @return number count Removed item count
local function clearGridItems(gridEntity, hideItems)
    if not gridEntity then return 0 end
    local grid_ok, grid = pcall(require, "core.inventory_grid")
    if not grid_ok or not grid then return 0 end

    local items = grid.getAllItems(gridEntity)
    local count = 0
    if items then
        for slotIndex, itemEntity in pairs(items) do
            local removed = grid.removeItem(gridEntity, slotIndex)
            if removed then
                count = count + 1
                if hideItems then
                    setCardEntityVisible(removed, false)
                end
            end
        end
    end
    return count
end

--- Center an item on its slot if possible
--- @param gridEntity number Grid entity ID
--- @param itemEntity number Item entity ID
--- @param slotIndex number Slot index
local function centerItemOnSlot(gridEntity, itemEntity, slotIndex)
    if not gridEntity or not itemEntity or not slotIndex then return end
    local grid_ok, grid = pcall(require, "core.inventory_grid")
    local init_ok, InventoryGridInit = pcall(require, "ui.inventory_grid_init")
    if not grid_ok or not init_ok or not InventoryGridInit then return end

    local slotEntity = grid.getSlotEntity(gridEntity, slotIndex)
    if slotEntity and InventoryGridInit.centerItemOnSlot then
        InventoryGridInit.centerItemOnSlot(itemEntity, slotEntity, false)
    end
end

--------------------------------------------------------------------------------
-- TAB SYSTEM
--------------------------------------------------------------------------------

--- Get tab label from wand definition
--- @param wandDef table Wand definition
--- @param index number 1-based wand index
--- @return string Tab label (first 2 chars of name or index)
local function getTabLabel(wandDef, index)
    if wandDef.name and #wandDef.name > 0 then
        return string.sub(wandDef.name, 1, 2)
    end
    return tostring(index)
end

--- Create DSL definition for wand tabs (left-side folder tabs)
--- @return table DSL vbox definition with tab buttons
local function createWandTabs()
    local tabChildren = {}

    -- Try to load DSL module (may not be available in test environment)
    local dsl_ok, dsl = pcall(require, "ui.ui_syntax_sugar")
    local useDsl = dsl_ok and dsl and dsl.strict

    for i, wandDef in ipairs(state.wandDefs) do
        local isActive = (i == state.activeWandIndex)
        local tabLabel = getTabLabel(wandDef, i)

        if useDsl then
            table.insert(tabChildren, dsl.strict.button(tabLabel, {
                id = "wand_tab_" .. i,
                fontSize = UI(14),
                minWidth = TAB_WIDTH,
                minHeight = TAB_HEIGHT,
                padding = UI(4),
                color = isActive and "gold" or "gray",
                onClick = function()
                    WandPanel.selectWand(i)
                end,
            }))
        else
            -- Test stub: simple button representation
            table.insert(tabChildren, {
                type = "button",
                label = tabLabel,
                id = "wand_tab_" .. i,
                isActive = isActive,
            })
        end

        -- Add spacing between tabs
        if i < #state.wandDefs then
            if useDsl then
                table.insert(tabChildren, dsl.strict.spacer(TAB_SPACING))
            else
                table.insert(tabChildren, { type = "spacer", size = TAB_SPACING })
            end
        end
    end

    if useDsl then
        return dsl.strict.vbox {
            config = {
                id = "wand_tabs_container",
                padding = UI(4),
            },
            children = tabChildren,
        }
    else
        -- Test stub: minimal vbox structure
        return {
            type = "vbox",
            config = { id = "wand_tabs_container", padding = UI(4) },
            children = tabChildren,
        }
    end
end

--- Update tab button highlighting based on active wand
local function updateTabHighlighting()
    for i, tabEntity in pairs(state.tabEntities) do
        if tabEntity then
            -- Check if registry is available (runtime only)
            if _G.registry and _G.registry.valid and _G.registry:valid(tabEntity) then
                local isActive = (i == state.activeWandIndex)

                -- Update UIConfig color
                local component_cache = _G.component_cache
                if component_cache and component_cache.get then
                    local uiCfg = component_cache.get(tabEntity, _G.UIConfig)
                    if uiCfg and _G.util and _G.util.getColor then
                        uiCfg.color = isActive and _G.util.getColor("gold") or _G.util.getColor("gray")
                    end
                end
            end
        end
    end
end

--- Position tabs relative to panel using ChildBuilder
local function positionTabs()
    if not state.tabContainerEntity or not state.panelEntity then return end

    -- Check if registry is available (runtime only)
    if not _G.registry or not _G.registry.valid then return end
    if not _G.registry:valid(state.tabContainerEntity) then return end
    if not _G.registry:valid(state.panelEntity) then return end

    local ok, ChildBuilder = pcall(require, "core.child_builder")
    if ok and ChildBuilder and ChildBuilder.for_entity then
        ChildBuilder.for_entity(state.tabContainerEntity)
            :attachTo(state.panelEntity)
            :offset(TAB_OFFSET_X, 0)
            :apply()
    end
end

--------------------------------------------------------------------------------
-- GRID DEFINITIONS
--------------------------------------------------------------------------------

--- Create DSL definition for trigger grid (single slot)
--- @param wandDef table Wand definition
--- @return table Grid definition
local function createTriggerGridDefinition(wandDef)
    local rows, cols = getGridDimensions(wandDef, "trigger")
    local gridId = "wand_trigger_grid_" .. state.activeWandIndex

    -- Try to load DSL module
    local dsl_ok, dsl = pcall(require, "ui.ui_syntax_sugar")
    local useDsl = dsl_ok and dsl and dsl.strict

    -- Build config for grid
    local gridConfig = {
        allowDragIn = true,
        allowDragOut = true,
        stackable = false,
        slotSprite = "test-inventory-square-single.png",
        padding = GRID_PADDING,
        backgroundColor = "cyan_dark",  -- Trigger color theme
        snapVisual = false,
    }

    -- Add alignment flag if available
    if _G.AlignmentFlag then
        local bit_ok, bit = pcall(require, "bit_compat")
        if bit_ok and bit and bit.bor then
            gridConfig.align = bit.bor(_G.AlignmentFlag.HORIZONTAL_LEFT, _G.AlignmentFlag.VERTICAL_TOP)
        end
    end

    -- Filter: Only accept trigger cards
    local function canAcceptTrigger(gridEntity, itemEntity)
        if not _G.getScriptTableFromEntityID then
            return true  -- Allow in test environment
        end
        local script = _G.getScriptTableFromEntityID(itemEntity)
        local data = script and (script.cardData or script)
        return data ~= nil and data.type == "trigger"
    end

    -- Slot change callback
    local function onTriggerSlotChange(gridEntity, slotIndex, oldItem, newItem)
        if _G.log_debug then
            _G.log_debug("[WandPanel] Trigger slot " .. slotIndex .. " changed")
        end
        -- Sync to adapter will be added in Phase 5
    end

    -- Slot click callback (right-click to remove)
    local function onTriggerSlotClick(gridEntity, slotIndex, button)
        local rightButton = (_G.MouseButton and _G.MouseButton.MOUSE_BUTTON_RIGHT) or 1
        if button == rightButton then
            local grid_ok, grid = pcall(require, "core.inventory_grid")
            if grid_ok and grid then
                local item = grid.getItemAtIndex(gridEntity, slotIndex)
                if item then
                    local returned = returnCardToInventory(item)
                    if returned and _G.log_debug then
                        _G.log_debug("[WandPanel] Trigger card returned to inventory via right-click")
                    end
                end
            end
        end
    end

    if useDsl then
        return dsl.strict.inventoryGrid {
            id = gridId,
            rows = rows,
            cols = cols,
            slotSize = { w = SLOT_WIDTH, h = SLOT_HEIGHT },
            slotSpacing = SLOT_SPACING,
            config = gridConfig,
            canAcceptItem = canAcceptTrigger,
            onSlotChange = onTriggerSlotChange,
            onSlotClick = onTriggerSlotClick,
        }
    else
        -- Test stub: minimal grid structure
        return {
            type = "inventoryGrid",
            id = gridId,
            rows = rows,
            cols = cols,
            slotSize = { w = SLOT_WIDTH, h = SLOT_HEIGHT },
            slotSpacing = SLOT_SPACING,
            config = gridConfig,
            canAcceptItem = canAcceptTrigger,
            onSlotChange = onTriggerSlotChange,
            onSlotClick = onTriggerSlotClick,
        }
    end
end

--- Create DSL definition for action grid
--- @param wandDef table Wand definition
--- @return table Grid definition
local function createActionGridDefinition(wandDef)
    local rows, cols = getGridDimensions(wandDef, "action")
    local gridId = "wand_action_grid_" .. state.activeWandIndex

    -- Try to load DSL module
    local dsl_ok, dsl = pcall(require, "ui.ui_syntax_sugar")
    local useDsl = dsl_ok and dsl and dsl.strict

    -- Build config for grid
    local gridConfig = {
        allowDragIn = true,
        allowDragOut = true,
        stackable = false,
        slotSprite = "test-inventory-square-single.png",
        padding = GRID_PADDING,
        backgroundColor = "apricot_cream_dark",  -- Action color theme
        snapVisual = false,
    }

    -- Lock slots beyond total_card_slots (enforce wand capacity)
    local totalSlots = math.max(wandDef.total_card_slots or (rows * cols), 1)
    local slotsConfig = {}
    if totalSlots < (rows * cols) then
        for slotIndex = totalSlots + 1, rows * cols do
            slotsConfig[slotIndex] = { locked = true }
        end
        gridConfig.filter = function(_, slotIndex)
            return slotIndex <= totalSlots
        end
    end

    -- Add alignment flag if available
    if _G.AlignmentFlag then
        local bit_ok, bit = pcall(require, "bit_compat")
        if bit_ok and bit and bit.bor then
            gridConfig.align = bit.bor(_G.AlignmentFlag.HORIZONTAL_LEFT, _G.AlignmentFlag.VERTICAL_TOP)
        end
    end

    -- Filter: Only accept action/modifier cards
    local function canAcceptAction(gridEntity, itemEntity)
        if not _G.getScriptTableFromEntityID then
            return true  -- Allow in test environment
        end
        local script = _G.getScriptTableFromEntityID(itemEntity)
        local data = script and (script.cardData or script)
        local cardType = data and data.type
        return cardType == "action" or cardType == "modifier"
    end

    -- Slot change callback
    local function onActionSlotChange(gridEntity, slotIndex, oldItem, newItem)
        if _G.log_debug then
            _G.log_debug("[WandPanel] Action slot " .. slotIndex .. " changed")
        end
        -- Sync to adapter will be added in Phase 5
    end

    -- Slot click callback (right-click to remove)
    local function onActionSlotClick(gridEntity, slotIndex, button)
        local rightButton = (_G.MouseButton and _G.MouseButton.MOUSE_BUTTON_RIGHT) or 1
        if button == rightButton then
            local grid_ok, grid = pcall(require, "core.inventory_grid")
            if grid_ok and grid then
                local item = grid.getItemAtIndex(gridEntity, slotIndex)
                if item then
                    local returned = returnCardToInventory(item)
                    if returned and _G.log_debug then
                        _G.log_debug("[WandPanel] Action card returned to inventory via right-click")
                    end
                end
            end
        end
    end

    if useDsl then
        return dsl.strict.inventoryGrid {
            id = gridId,
            rows = rows,
            cols = cols,
            slotSize = { w = SLOT_WIDTH, h = SLOT_HEIGHT },
            slotSpacing = SLOT_SPACING,
            config = gridConfig,
            slots = slotsConfig,
            canAcceptItem = canAcceptAction,
            onSlotChange = onActionSlotChange,
            onSlotClick = onActionSlotClick,
        }
    else
        -- Test stub: minimal grid structure
        return {
            type = "inventoryGrid",
            id = gridId,
            rows = rows,
            cols = cols,
            slotSize = { w = SLOT_WIDTH, h = SLOT_HEIGHT },
            slotSpacing = SLOT_SPACING,
            config = gridConfig,
            slots = slotsConfig,
            canAcceptItem = canAcceptAction,
            onSlotChange = onActionSlotChange,
            onSlotClick = onActionSlotClick,
        }
    end
end

--- Cleanup a grid entity and its associated resources
--- @param gridEntity number Grid entity ID
--- @param gridId string Grid identifier for DSL cleanup
local function cleanupGrid(gridEntity, gridId)
    if not gridEntity then return end

    -- Try to load required modules
    local grid_ok, grid = pcall(require, "core.inventory_grid")
    local init_ok, InventoryGridInit = pcall(require, "ui.inventory_grid_init")
    local dsl_ok, dsl = pcall(require, "ui.ui_syntax_sugar")
    local registry_ok, itemRegistry = pcall(require, "core.item_location_registry")

    -- STEP 1: Unregister from drag feedback system
    if init_ok and InventoryGridInit and InventoryGridInit.unregisterGridForDragFeedback then
        InventoryGridInit.unregisterGridForDragFeedback(gridEntity)
    end

    -- STEP 2: Clean up slot metadata
    if grid_ok and grid and init_ok and InventoryGridInit then
        local capacity = grid.getCapacity(gridEntity)
        if capacity then
            for i = 1, capacity do
                local slotEntity = grid.getSlotEntity(gridEntity, i)
                if slotEntity and InventoryGridInit.cleanupSlotMetadata then
                    InventoryGridInit.cleanupSlotMetadata(slotEntity)
                end
            end
        end
    end

    -- STEP 3: Clear item location registry for this grid
    if registry_ok and itemRegistry and itemRegistry.clearGrid then
        itemRegistry.clearGrid(gridEntity)
    end

    -- STEP 4: Clean up grid internal state
    if grid_ok and grid and grid.cleanup then
        grid.cleanup(gridEntity)
    end

    -- STEP 5: Clean up DSL grid registry
    if dsl_ok and dsl and dsl.cleanupGrid then
        dsl.cleanupGrid(gridId)
    end
end

--------------------------------------------------------------------------------
-- WAND STATS DISPLAY
--------------------------------------------------------------------------------

--- Format a stat value with optional suffix
--- @param value number? The stat value
--- @param suffix string? Optional suffix like "ms", "deg"
--- @return string? Formatted string or nil if value should not display
local function formatStatValue(value, suffix)
    if not value or value == 0 or value == -1 then
        return nil
    end
    if suffix then
        return tostring(value) .. suffix
    end
    return tostring(value)
end

--- Build stats text for the wand (multi-line)
--- @param wandDef table Wand definition
--- @return string
local function buildStatsText(wandDef)
    local lines = {}

    local function addLine(label, value, suffix)
        local formatted = formatStatValue(value, suffix)
        if formatted then
            table.insert(lines, label .. ": " .. formatted)
        end
    end

    addLine("Cast", wandDef.cast_delay, "ms")
    addLine("Recharge", wandDef.recharge_time, "ms")
    addLine("Spread", wandDef.spread_angle, "deg")
    addLine("Block", wandDef.cast_block_size, nil)
    addLine("Mana", wandDef.mana_max, nil)

    if wandDef.shuffle ~= nil then
        table.insert(lines, "Shuffle: " .. (wandDef.shuffle and "Yes" or "No"))
    end

    if wandDef.trigger_type then
        local triggerLabel = string.upper(string.gsub(wandDef.trigger_type, "_", " "))
        table.insert(lines, "Trigger: " .. triggerLabel)
    end

    if wandDef.always_cast_cards and #wandDef.always_cast_cards > 0 then
        table.insert(lines, "Always Cast: +" .. tostring(#wandDef.always_cast_cards))
    end

    if #lines == 0 then
        table.insert(lines, "No stats")
    end

    return table.concat(lines, "\n")
end

--- Create header section with title and close button
--- @param wandDef table Wand definition
--- @return table DSL definition
local function createHeader(wandDef)
    local titleText = wandDef.name or ("Wand " .. state.activeWandIndex)

    local dsl_ok, dsl = pcall(require, "ui.ui_syntax_sugar")
    local useDsl = dsl_ok and dsl and dsl.strict

    if useDsl then
        return dsl.strict.hbox {
            config = {
                id = "wand_panel_header",
                padding = UI(2),
            },
            children = {
                dsl.strict.text(titleText, {
                    id = "wand_panel_title",
                    fontSize = UI(14),
                    color = "gold",
                    shadow = true,
                }),
                dsl.strict.spacer(UI(1)),  -- flex spacer
                dsl.strict.button("X", {
                    id = "wand_panel_close_btn",
                    fontSize = UI(12),
                    minWidth = UI(22),
                    minHeight = UI(22),
                    color = "apricot_cream",
                    onClick = function()
                        WandPanel.close()
                    end,
                }),
            },
        }
    else
        -- Test stub
        return {
            type = "hbox",
            config = { id = "wand_panel_header", padding = UI(4) },
            children = {
                { type = "text", id = "wand_panel_title", content = titleText, color = "gold" },
                { type = "spacer", fill = true },
                { type = "button", id = "wand_panel_close_btn", label = "X" },
            },
        }
    end
end

--- Create DSL definition for wand stats box
--- @param wandDef table Wand definition
--- @param minHeight number? Optional minimum height for alignment
--- @return table DSL root definition with text box
local function createWandStatsRow(wandDef, minHeight)
    local statsText = buildStatsText(wandDef)

    -- Try to load DSL module
    local dsl_ok, dsl = pcall(require, "ui.ui_syntax_sugar")
    local useDsl = dsl_ok and dsl and dsl.strict

    if useDsl then
        local boxConfig = {
            id = "wand_stats_box",
            color = "dark_gray_slate",
            padding = UI(6),
            outlineThickness = UI(1),
            outlineColor = "apricot_cream",
            minWidth = STATS_BOX_WIDTH,
        }
        if minHeight and minHeight > 0 then
            boxConfig.minHeight = minHeight
        end

        return dsl.strict.root {
            config = boxConfig,
            children = {
                dsl.strict.vbox {
                    config = { padding = UI(2) },
                    children = {
                        createHeader(wandDef),
                        dsl.strict.spacer(UI(4)),
                        dsl.strict.text(statsText, {
                            id = "wand_stats_text",
                            fontSize = UI(10),
                            color = "light_gray",
                            shadow = true,
                        }),
                    }
                }
            }
        }
    else
        return {
            type = "root",
            config = { id = "wand_stats_box", minWidth = STATS_BOX_WIDTH, minHeight = minHeight },
            children = {
                createHeader(wandDef),
                { type = "text", id = "wand_stats_text", content = statsText, color = "light_gray" },
            },
        }
    end
end

--- Update the stats display with current wand data
local function updateStatsDisplay()
    local wandDef = state.wandDefs[state.activeWandIndex]
    if not wandDef then return end

    if not _G.registry or not _G.registry.valid then return end

    local statsText = buildStatsText(wandDef)
    if _G.ui and _G.ui.box and _G.ui.box.GetUIEByID then
        local textEntity = _G.ui.box.GetUIEByID(_G.registry, state.panelEntity, "wand_stats_text")
        if textEntity and _G.component_cache and _G.UITextComponent then
            local uiText = _G.component_cache.get(textEntity, _G.UITextComponent)
            if uiText then
                uiText.text = statsText
            end
        end
    end
end

--------------------------------------------------------------------------------
-- WAND ADAPTER SYNC
--------------------------------------------------------------------------------

--- Sync trigger card from grid to WandAdapter
--- @param wandIndex number? Optional wand index (defaults to active)
local function syncTriggerToAdapter(wandIndex)
    wandIndex = wandIndex or state.activeWandIndex
    if not state.triggerGridEntity then return end

    local adapter_ok, adapter = pcall(require, "ui.wand_grid_adapter")
    local grid_ok, grid = pcall(require, "core.inventory_grid")

    if not adapter_ok or not grid_ok then return end

    -- Get trigger card from grid slot 1
    local triggerCard = grid.getItemAtIndex(state.triggerGridEntity, 1)

    -- Update adapter
    if adapter.setTrigger then
        adapter.setTrigger(wandIndex, triggerCard)
    end

    if _G.log_debug then
        _G.log_debug("[WandPanel] Synced trigger to adapter for wand " .. wandIndex)
    end
end

--- Sync action cards from grid to WandAdapter
--- @param wandIndex number? Optional wand index (defaults to active)
local function syncActionsToAdapter(wandIndex)
    wandIndex = wandIndex or state.activeWandIndex
    if not state.actionGridEntity then return end

    local adapter_ok, adapter = pcall(require, "ui.wand_grid_adapter")
    local grid_ok, grid = pcall(require, "core.inventory_grid")

    if not adapter_ok or not grid_ok then return end

    -- Get capacity and sync each slot
    local capacity = grid.getCapacity(state.actionGridEntity)
    if not capacity then return end

    for slotIndex = 1, capacity do
        local actionCard = grid.getItemAtIndex(state.actionGridEntity, slotIndex)
        if adapter.setAction then
            adapter.setAction(wandIndex, slotIndex, actionCard)
        end
    end

    if _G.log_debug then
        _G.log_debug("[WandPanel] Synced " .. capacity .. " action slots to adapter for wand " .. wandIndex)
    end
end

--- Sync all cards (trigger + actions) from grids to WandAdapter
--- @param wandIndex number? Optional wand index (defaults to active)
local function syncAllToAdapter(wandIndex)
    syncTriggerToAdapter(wandIndex)
    syncActionsToAdapter(wandIndex)
end

--- Map card entity to inventory tab category
local function getInventoryCategoryForCard(cardEntity)
    if not _G.getScriptTableFromEntityID then
        return "equipment"
    end

    local script = _G.getScriptTableFromEntityID(cardEntity)
    if not script then return "equipment" end

    local data = script.cardData or script
    local cardType = data and (data.type or data.category or data.cardType)
    if cardType == "trigger" or cardType == "triggers" then
        return "triggers"
    elseif cardType == "action" or cardType == "actions" then
        return "actions"
    elseif cardType == "modifier" or cardType == "modifiers" then
        return "modifiers"
    end

    if data and data.isTrigger then
        return "triggers"
    end

    local cardID = data and (data.cardID or data.id or data.card_id)
    if cardID and _G.WandEngine then
        if _G.WandEngine.trigger_card_defs and _G.WandEngine.trigger_card_defs[cardID] then
            return "triggers"
        end
        if _G.WandEngine.card_defs and _G.WandEngine.card_defs[cardID] then
            local def = _G.WandEngine.card_defs[cardID]
            if def and def.type == "modifier" then
                return "modifiers"
            end
            return "actions"
        end
    end

    return "equipment"
end

--- Return a card entity to the player inventory
--- @param cardEntity number Entity ID of the card
--- @return boolean Success
local function returnCardToInventory(cardEntity)
    if not cardEntity then return false end

    -- Check if registry is available
    if not _G.registry or not _G.registry.valid then return false end
    if not _G.registry:valid(cardEntity) then return false end

    -- Try to get PlayerInventory module
    local inv_ok, PlayerInventory = pcall(require, "ui.player_inventory")
    if not inv_ok or not PlayerInventory then
        if _G.log_warn then
            _G.log_warn("[WandPanel] Cannot return card - PlayerInventory not available")
        end
        return false
    end

    local category = getInventoryCategoryForCard(cardEntity)
    local targetGrid = PlayerInventory.getGridForTab and PlayerInventory.getGridForTab(category)

    local grid_ok, grid = pcall(require, "core.inventory_grid")
    local transfer_ok, transfer = pcall(require, "core.grid_transfer")
    local registry_ok, itemRegistry = pcall(require, "core.item_location_registry")

    -- If target grid is active, do an atomic transfer
    if targetGrid and transfer_ok and transfer then
        local result = transfer.transferItemTo({
            item = cardEntity,
            toGrid = targetGrid,
            onSuccess = function(res)
                if _G.log_debug then
                    _G.log_debug("[WandPanel] Returned card to inventory slot " .. res.toSlot)
                end
                local slotEntity = grid_ok and grid and grid.getSlotEntity and grid.getSlotEntity(targetGrid, res.toSlot)
                if slotEntity then
                    centerItemOnSlot(targetGrid, cardEntity, res.toSlot)
                end
            end,
        })
        if result.success then
            return true
        end
    end

    -- Fallback: remove from wand grid manually and store in inventory
    local originalLocation = nil
    if registry_ok and itemRegistry and itemRegistry.getLocation then
        originalLocation = itemRegistry.getLocation(cardEntity)
    end

    if originalLocation and grid_ok and grid and grid.removeItem then
        grid.removeItem(originalLocation.grid, originalLocation.slot)
    end

    if PlayerInventory.addCard then
        local added = PlayerInventory.addCard(cardEntity, category)
        if added then
            if _G.log_debug then
                _G.log_debug("[WandPanel] Returned card to inventory (" .. tostring(category) .. ")")
            end
            return true
        end
    end

    -- Attempt to restore to original slot if add failed
    if originalLocation and grid_ok and grid and grid.addItem then
        local restored = grid.addItem(originalLocation.grid, cardEntity, originalLocation.slot)
        if restored then
            centerItemOnSlot(originalLocation.grid, cardEntity, originalLocation.slot)
        end
    end

    if _G.log_warn then
        _G.log_warn("[WandPanel] Inventory is full - cannot return card")
    end

    return false
end

--------------------------------------------------------------------------------
-- SIGNAL HANDLERS
--------------------------------------------------------------------------------

--- Register a signal handler and track for cleanup
--- @param eventName string Signal event name
--- @param handler function Handler function
local function registerHandler(eventName, handler)
    local ok, signal = pcall(require, "external.hump.signal")
    if not ok or not signal then return end

    signal.register(eventName, handler)
    table.insert(state.signalHandlers, { event = eventName, handler = handler })
end

--- Setup all signal handlers for wand panel
local function setupSignalHandlers()
    -- Grid item changes -> sync to adapter
    registerHandler("grid_item_added", function(gridEntity, slotIndex, itemEntity)
        if state.suspendSync then return end
        if gridEntity == state.triggerGridEntity then
            syncTriggerToAdapter()
            local ok, signal = pcall(require, "external.hump.signal")
            if ok and signal then
                signal.emit("wand_trigger_changed", itemEntity, nil, state.activeWandIndex)
            end
        elseif gridEntity == state.actionGridEntity then
            syncActionsToAdapter()
            local ok, signal = pcall(require, "external.hump.signal")
            if ok and signal then
                signal.emit("wand_action_changed", slotIndex, itemEntity, nil, state.activeWandIndex)
            end
        end
    end)

    registerHandler("grid_item_removed", function(gridEntity, slotIndex, itemEntity)
        if state.suspendSync then return end
        if gridEntity == state.triggerGridEntity then
            syncTriggerToAdapter()
            local ok, signal = pcall(require, "external.hump.signal")
            if ok and signal then
                signal.emit("wand_trigger_changed", nil, itemEntity, state.activeWandIndex)
            end
        elseif gridEntity == state.actionGridEntity then
            syncActionsToAdapter()
            local ok, signal = pcall(require, "external.hump.signal")
            if ok and signal then
                signal.emit("wand_action_changed", slotIndex, nil, itemEntity, state.activeWandIndex)
            end
        end
    end)

    registerHandler("grid_item_moved", function(gridEntity, fromSlot, toSlot, itemEntity)
        if state.suspendSync then return end
        if gridEntity == state.actionGridEntity then
            syncActionsToAdapter()
        end
    end)

    -- Wand selection -> update grids
    registerHandler("wand_selected", function(newIndex, oldIndex)
        updateTabHighlighting()
        updateStatsDisplay()
        updateHeaderTitle()
        -- Grid swapping will be implemented in Phase 9/10
    end)

    if _G.log_debug then
        _G.log_debug("[WandPanel] Signal handlers setup complete")
    end
end

local function cleanupSignalHandlers()
    local ok, signal = pcall(require, "external.hump.signal")
    if ok and signal then
        for _, entry in ipairs(state.signalHandlers) do
            if entry.event and entry.handler then
                signal.remove(entry.event, entry.handler)
            end
        end
    end
    state.signalHandlers = {}
    state.inputHandlerInitialized = false
end

--------------------------------------------------------------------------------
-- INPUT HANDLING
--------------------------------------------------------------------------------

--- Handle quick equip from inventory right-click
--- @param cardEntity number Entity ID of the card
--- @return boolean Success
local function handleQuickEquip(cardEntity)
    if not state.initialized then return false end
    if not _G.registry or not _G.registry.valid then return false end
    if not cardEntity or not _G.registry:valid(cardEntity) then return false end

    -- Determine card type
    local cardType = nil
    if _G.getScriptTableFromEntityID then
        local script = _G.getScriptTableFromEntityID(cardEntity)
        local data = script and (script.cardData or script)
        cardType = data and data.type
    end

    if not cardType then
        if _G.log_debug then
            _G.log_debug("[WandPanel] handleQuickEquip: Cannot determine card type")
        end
        return false
    end

    -- Route to appropriate grid
    local grid_ok, grid = pcall(require, "core.inventory_grid")
    if not grid_ok then return false end

    if cardType == "trigger" then
        if state.triggerGridEntity then
            -- Check if trigger slot is occupied
            local existing = grid.getItemAtIndex(state.triggerGridEntity, 1)
            if existing then
                -- Swap: return existing to inventory first
                local returned = returnCardToInventory(existing)
                if not returned then
                    return false
                end
            end
            -- Add new trigger card
            local success = grid.addItem(state.triggerGridEntity, cardEntity, 1)
            if success then
                centerItemOnSlot(state.triggerGridEntity, cardEntity, 1)
            end
            return success
        end
    elseif cardType == "action" or cardType == "modifier" then
        if state.actionGridEntity then
            -- Find first empty slot
            local success, slotIndex = grid.addItem(state.actionGridEntity, cardEntity)
            if success and slotIndex then
                centerItemOnSlot(state.actionGridEntity, cardEntity, slotIndex)
            end
            return success
        end
    end

    return false
end

--- Setup keyboard input handler for E key toggle
local function setupInputHandler()
    if state.inputHandlerInitialized then return end

    -- Check if timer system is available
    local timer_ok, timer = pcall(require, "core.timer")
    if not timer_ok or not timer or not timer.run_every_render_frame then
        if _G.log_debug then
            _G.log_debug("[WandPanel] Timer system not available - skipping input handler setup")
        end
        return
    end

    state.inputHandlerInitialized = true

    if _G.log_debug then
        _G.log_debug("[WandPanel] Setting up input handler for E key")
    end

    -- Use timer-based polling like player_inventory.lua
    timer.run_every_render_frame(function()
        local isKeyPressed = _G.isKeyPressed

        -- E key to toggle wand panel (when inventory is open)
        local ePressed = isKeyPressed and isKeyPressed("KEY_E")

        if ePressed then
            -- Only toggle if player inventory is open
            local inv_ok, PlayerInventory = pcall(require, "ui.player_inventory")
            if inv_ok and PlayerInventory and PlayerInventory.isOpen and PlayerInventory.isOpen() then
                WandPanel.toggle()
            end
        end

        -- ESC to close (if open)
        if state.isVisible and isKeyPressed and isKeyPressed("KEY_ESCAPE") then
            WandPanel.close()
        end
    end, nil, "wand_panel_input", TIMER_GROUP)

    if _G.log_debug then
        _G.log_debug("[WandPanel] Input handler setup complete (E key toggle)")
    end
end

--------------------------------------------------------------------------------
-- PANEL DEFINITION
--------------------------------------------------------------------------------

--- Create trigger section with label and grid container
--- @return table DSL definition
local function createTriggerSection()
    local dsl_ok, dsl = pcall(require, "ui.ui_syntax_sugar")
    local useDsl = dsl_ok and dsl and dsl.strict

    if useDsl then
        return dsl.strict.vbox {
            config = {
                id = "trigger_section",
                padding = UI(2),
            },
            children = {
                dsl.strict.text("TRIGGER", {
                    fontSize = UI(12),
                    color = "cyan",
                    shadow = true,
                }),
                dsl.strict.vbox {
                    config = {
                        id = "trigger_grid_container",
                        padding = 0,
                    },
                    children = {},  -- Grid injected at runtime
                },
            },
        }
    else
        return {
            type = "vbox",
            config = { id = "trigger_section", padding = UI(2) },
            children = {
                { type = "text", content = "TRIGGER", color = "cyan" },
                { type = "vbox", config = { id = "trigger_grid_container" }, children = {} },
            },
        }
    end
end

--- Create action section with label and grid container
--- @return table DSL definition
local function createActionSection()
    local dsl_ok, dsl = pcall(require, "ui.ui_syntax_sugar")
    local useDsl = dsl_ok and dsl and dsl.strict

    if useDsl then
        return dsl.strict.vbox {
            config = {
                id = "action_section",
                padding = UI(2),
            },
            children = {
                dsl.strict.text("ACTIONS", {
                    fontSize = UI(12),
                    color = "apricot_cream",
                    shadow = true,
                }),
                dsl.strict.vbox {
                    config = {
                        id = "action_grid_container",
                        padding = 0,
                    },
                    children = {},  -- Grid injected at runtime
                },
            },
        }
    else
        return {
            type = "vbox",
            config = { id = "action_section", padding = UI(2) },
            children = {
                { type = "text", content = "ACTIONS", color = "apricot_cream" },
                { type = "vbox", config = { id = "action_grid_container" }, children = {} },
            },
        }
    end
end

--- Create complete panel definition
--- @param wandDef table Wand definition
--- @return table DSL spritePanel definition
local function createPanelDefinition(wandDef)
    local dsl_ok, dsl = pcall(require, "ui.ui_syntax_sugar")
    local useDsl = dsl_ok and dsl and dsl.strict

    local triggerRows, triggerCols = getGridDimensions(wandDef, "trigger")
    local actionRows, actionCols = getGridDimensions(wandDef, "action")

    local triggerGridHeight = triggerRows * SLOT_HEIGHT + (triggerRows - 1) * SLOT_SPACING + GRID_PADDING * 2
    local actionGridHeight = actionRows * SLOT_HEIGHT + (actionRows - 1) * SLOT_SPACING + GRID_PADDING * 2
    local triggerSectionHeight = SECTION_HEADER_HEIGHT + triggerGridHeight
    local actionSectionHeight = SECTION_HEADER_HEIGHT + actionGridHeight
    local statsMinHeight = math.max(triggerSectionHeight, actionSectionHeight)

    local triggerSection = createTriggerSection()
    local actionSection = createActionSection()
    local statsRow = createWandStatsRow(wandDef, statsMinHeight)

    if useDsl then
        return dsl.strict.spritePanel {
            sprite = "inventory-back-panel.png",
            borders = { 0, 0, 0, 0 },
            sizing = "stretch",
            config = {
                id = PANEL_ID,
                padding = PANEL_PADDING,
            },
            children = {
                dsl.strict.hbox {
                    config = {
                        id = "wand_panel_row",
                        padding = 0,
                    },
                    children = {
                        triggerSection,
                        dsl.strict.spacer(COLUMN_SPACING),
                        actionSection,
                        dsl.strict.spacer(COLUMN_SPACING),
                        statsRow,
                    }
                }
            },
        }
    else
        return {
            type = "spritePanel",
            sprite = "inventory-back-panel.png",
            config = { id = PANEL_ID, padding = PANEL_PADDING },
            children = {
                {
                    type = "hbox",
                    config = { id = "wand_panel_row", padding = 0 },
                    children = {
                        triggerSection,
                        { type = "spacer", size = COLUMN_SPACING },
                        actionSection,
                        { type = "spacer", size = COLUMN_SPACING },
                        statsRow,
                    },
                }
            },
        }
    end
end

--- Create the small tab marker used to reopen the panel
local function createTabMarkerDefinition()
    local dsl_ok, dsl = pcall(require, "ui.ui_syntax_sugar")
    local useDsl = dsl_ok and dsl and dsl.strict

    if not useDsl then
        return {
            type = "hbox",
            config = { id = "wand_panel_tab_marker" },
            children = {
                { type = "anim", sprite = "inventory-tab-marker.png", w = TAB_MARKER_WIDTH, h = TAB_MARKER_HEIGHT },
            },
        }
    end

    return dsl.strict.hbox {
        config = {
            id = "wand_panel_tab_marker",
            canCollide = true,
            hover = true,
            padding = 0,
            buttonCallback = function()
                WandPanel.toggle()  -- Toggle open/close like inventory
            end,
        },
        children = {
            dsl.anim("inventory-tab-marker.png", { w = TAB_MARKER_WIDTH, h = TAB_MARKER_HEIGHT })
        }
    }
end

--- Position the tab marker relative to the panel
local function positionTabMarker()
    if not state.tabMarkerEntity or not state.panelEntity then return end
    if not _G.registry or not _G.registry.valid then return end
    if not _G.registry:valid(state.tabMarkerEntity) then return end
    if not _G.registry:valid(state.panelEntity) then return end

    local ok, ChildBuilder = pcall(require, "core.child_builder")
    if ok and ChildBuilder and ChildBuilder.for_entity then
        local offsetX, offsetY = getTabMarkerOffsets()
        ChildBuilder.for_entity(state.tabMarkerEntity)
            :attachTo(state.panelEntity)
            :offset(offsetX, offsetY)
            :apply()
    end
end

--- Update cached panel dimensions and position (centered at top)
local function updatePanelPosition(wandDef)
    local screenW = _G.GetScreenWidth and _G.GetScreenWidth() or 1280
    local panelW, panelH = calculatePanelDimensions(wandDef)

    state.panelWidth = panelW
    state.panelHeight = panelH
    state.panelX = math.max(8, math.floor((screenW - panelW) * 0.5))
    state.panelY = TOP_MARGIN

    if state.panelEntity then
        setEntityVisible(state.panelEntity, state.isVisible, state.panelX, state.panelY, "WandPanel")
    end

    positionTabMarker()
end

--------------------------------------------------------------------------------
-- LIFECYCLE MANAGEMENT
--------------------------------------------------------------------------------

--- Show panel by moving to onscreen position
local function showPanel()
    if not state.panelEntity then return end

    setEntityVisible(state.panelEntity, true, state.panelX, state.panelY, "WandPanel")
    setGridItemsVisible(state.triggerGridEntity, true)
    setGridItemsVisible(state.actionGridEntity, true)
    -- Tab marker stays visible for toggle functionality

    -- Reapply state tags for rendering
    if _G.ui and _G.ui.box and _G.ui.box.AddStateTagToUIBox then
        _G.ui.box.AddStateTagToUIBox(_G.registry, state.panelEntity, "default_state")
    end
end

--- Hide panel by moving to offscreen position
local function hidePanel()
    if not state.panelEntity then return end

    setEntityVisible(state.panelEntity, false, state.panelX, state.panelY, "WandPanel")
    setGridItemsVisible(state.triggerGridEntity, false)
    setGridItemsVisible(state.actionGridEntity, false)
    -- Tab marker stays visible for toggle functionality
end

--- Inject trigger grid into container
--- @param wandDef table Wand definition
--- @return number? Grid entity ID or nil
local function injectTriggerGrid(wandDef)
    if not state.triggerGridContainerEntity then return nil end

    -- Check if registry available
    if not _G.registry or not _G.registry.valid then return nil end
    if not _G.registry:valid(state.triggerGridContainerEntity) then
        if _G.log_warn then
            _G.log_warn("[WandPanel] Trigger grid container not valid")
        end
        return nil
    end

    local gridDef = createTriggerGridDefinition(wandDef)

    -- Replace children with grid
    if _G.ui and _G.ui.box and _G.ui.box.ReplaceChildren then
        local replaced = _G.ui.box.ReplaceChildren(state.triggerGridContainerEntity, gridDef)
        if not replaced then
            if _G.log_warn then
                _G.log_warn("[WandPanel] Failed to inject trigger grid")
            end
            return nil
        end
    end

    -- Reapply state tags
    if _G.ui and _G.ui.box and _G.ui.box.AddStateTagToUIBox then
        _G.ui.box.AddStateTagToUIBox(_G.registry, state.panelEntity, "default_state")
    end

    -- Force layout recalculation
    if _G.ui and _G.ui.box and _G.ui.box.RenewAlignment then
        _G.ui.box.RenewAlignment(_G.registry, state.panelEntity)
    end

    -- Find injected grid entity
    local gridId = "wand_trigger_grid_" .. state.activeWandIndex
    if _G.ui and _G.ui.box and _G.ui.box.GetUIEByID then
        local gridEntity = _G.ui.box.GetUIEByID(_G.registry, state.triggerGridContainerEntity, gridId)
        if gridEntity then
            -- Initialize grid
            local init_ok, InventoryGridInit = pcall(require, "ui.inventory_grid_init")
            if init_ok and InventoryGridInit and InventoryGridInit.initializeIfGrid then
                InventoryGridInit.initializeIfGrid(gridEntity, gridId)
            end
            return gridEntity
        end
    end

    return nil
end

--- Inject action grid into container
--- @param wandDef table Wand definition
--- @return number? Grid entity ID or nil
local function injectActionGrid(wandDef)
    if not state.actionGridContainerEntity then return nil end

    -- Check if registry available
    if not _G.registry or not _G.registry.valid then return nil end
    if not _G.registry:valid(state.actionGridContainerEntity) then
        if _G.log_warn then
            _G.log_warn("[WandPanel] Action grid container not valid")
        end
        return nil
    end

    local gridDef = createActionGridDefinition(wandDef)

    -- Replace children with grid
    if _G.ui and _G.ui.box and _G.ui.box.ReplaceChildren then
        local replaced = _G.ui.box.ReplaceChildren(state.actionGridContainerEntity, gridDef)
        if not replaced then
            if _G.log_warn then
                _G.log_warn("[WandPanel] Failed to inject action grid")
            end
            return nil
        end
    end

    -- Reapply state tags
    if _G.ui and _G.ui.box and _G.ui.box.AddStateTagToUIBox then
        _G.ui.box.AddStateTagToUIBox(_G.registry, state.panelEntity, "default_state")
    end

    -- Force layout recalculation
    if _G.ui and _G.ui.box and _G.ui.box.RenewAlignment then
        _G.ui.box.RenewAlignment(_G.registry, state.panelEntity)
    end

    -- Find injected grid entity
    local gridId = "wand_action_grid_" .. state.activeWandIndex
    if _G.ui and _G.ui.box and _G.ui.box.GetUIEByID then
        local gridEntity = _G.ui.box.GetUIEByID(_G.registry, state.actionGridContainerEntity, gridId)
        if gridEntity then
            -- Initialize grid
            local init_ok, InventoryGridInit = pcall(require, "ui.inventory_grid_init")
            if init_ok and InventoryGridInit and InventoryGridInit.initializeIfGrid then
                InventoryGridInit.initializeIfGrid(gridEntity, gridId)
            end
            return gridEntity
        end
    end

    return nil
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Initialize the wand panel (must be called before open)
function WandPanel.initialize()
    if state.initialized then return true end

    if #state.wandDefs == 0 then
        if _G.log_warn then
            _G.log_warn("[WandPanel] Cannot initialize - no wand definitions set")
        end
        return false
    end

    -- Check if DSL is available
    local dsl_ok, dsl = pcall(require, "ui.ui_syntax_sugar")
    if not dsl_ok or not dsl or not dsl.spawn then
        if _G.log_warn then
            _G.log_warn("[WandPanel] Cannot initialize - DSL not available")
        end
        return false
    end

    -- Calculate panel position (centered at top)
    local wandDef = state.wandDefs[state.activeWandIndex]
    updatePanelPosition(wandDef)

    -- Create panel definition
    local panelDef = createPanelDefinition(wandDef)

    -- Spawn panel offscreen initially
    state.panelEntity = dsl.spawn(
        { x = state.panelX, y = state.panelY + getHiddenPanelOffset() },
        panelDef,
        RENDER_LAYER,
        PANEL_Z
    )

    if not state.panelEntity then
        if _G.log_error then
            _G.log_error("[WandPanel] Failed to spawn panel entity")
        end
        return false
    end

    -- Set draw layer
    if _G.ui and _G.ui.box and _G.ui.box.set_draw_layer then
        _G.ui.box.set_draw_layer(state.panelEntity, RENDER_LAYER)
    end

    -- Spawn tab marker (reopen tab) - must be in front of panel for visibility
    local tabDef = createTabMarkerDefinition()
    if tabDef and dsl.spawn then
        state.tabMarkerEntity = dsl.spawn(
            { x = state.panelX, y = state.panelY },
            tabDef,
            RENDER_LAYER,
            PANEL_Z + 10  -- Above panel for visibility and clickability
        )
        if state.tabMarkerEntity and _G.ui and _G.ui.box and _G.ui.box.set_draw_layer then
            _G.ui.box.set_draw_layer(state.tabMarkerEntity, RENDER_LAYER)
        end
        positionTabMarker()
        setTabMarkerVisible(true)
    end

    -- Find container entities
    if _G.ui and _G.ui.box and _G.ui.box.GetUIEByID then
        state.triggerGridContainerEntity = _G.ui.box.GetUIEByID(_G.registry, state.panelEntity, "trigger_grid_container")
        state.actionGridContainerEntity = _G.ui.box.GetUIEByID(_G.registry, state.panelEntity, "action_grid_container")
        state.closeButtonEntity = _G.ui.box.GetUIEByID(_G.registry, state.panelEntity, "wand_panel_close_btn")
    end

    -- Spawn tabs if multiple wands - must be in front of panel for visibility
    if #state.wandDefs > 1 and dsl and dsl.spawn then
        local tabDef = createWandTabs()
        state.tabContainerEntity = dsl.spawn(
            { x = state.panelX + TAB_OFFSET_X, y = state.panelY + HEADER_HEIGHT },
            tabDef,
            RENDER_LAYER,
            PANEL_Z + 10  -- Above panel for visibility and clickability
        )
        if state.tabContainerEntity and _G.ui and _G.ui.box then
            if _G.ui.box.set_draw_layer then
                _G.ui.box.set_draw_layer(state.tabContainerEntity, RENDER_LAYER)
            end
            if _G.ui.box.AddStateTagToUIBox then
                _G.ui.box.AddStateTagToUIBox(_G.registry, state.tabContainerEntity, "default_state")
            end
        end
        if state.tabContainerEntity and _G.ui and _G.ui.box and _G.ui.box.GetUIEByID then
            state.tabEntities = {}
            for i = 1, #state.wandDefs do
                local tabEntity = _G.ui.box.GetUIEByID(_G.registry, state.tabContainerEntity, "wand_tab_" .. i)
                if tabEntity then
                    state.tabEntities[i] = tabEntity
                end
            end
        end
        positionTabs()
        updateTabHighlighting()
    end

    -- Inject grids
    state.triggerGridEntity = injectTriggerGrid(wandDef)
    state.actionGridEntity = injectActionGrid(wandDef)

    -- Load existing cards from adapter (if any)
    local function loadFromAdapter()
        local adapter_ok, adapter = pcall(require, "ui.wand_grid_adapter")
        local grid_ok, grid = pcall(require, "core.inventory_grid")
        if not adapter_ok or not adapter or not grid_ok or not grid then return end
        local loadout = adapter.getLoadout and adapter.getLoadout(state.activeWandIndex)
        if not loadout then return end

        state.suspendSync = true

        if state.triggerGridEntity and loadout.trigger and _G.registry and _G.registry.valid and _G.registry:valid(loadout.trigger) then
            local ok = grid.addItem(state.triggerGridEntity, loadout.trigger, 1)
            if ok then
                centerItemOnSlot(state.triggerGridEntity, loadout.trigger, 1)
                setCardEntityVisible(loadout.trigger, state.isVisible)
            end
        end

        if state.actionGridEntity and loadout.actions then
            for slotIndex, itemEntity in pairs(loadout.actions) do
                if itemEntity and _G.registry and _G.registry.valid and _G.registry:valid(itemEntity) then
                    local ok = grid.addItem(state.actionGridEntity, itemEntity, slotIndex)
                    if ok then
                        centerItemOnSlot(state.actionGridEntity, itemEntity, slotIndex)
                        setCardEntityVisible(itemEntity, state.isVisible)
                    end
                end
            end
        end

        state.suspendSync = false
    end

    loadFromAdapter()

    -- Setup signal handlers
    setupSignalHandlers()

    -- Setup input handler
    setupInputHandler()

    state.initialized = true

    if _G.log_debug then
        _G.log_debug("[WandPanel] Initialized with " .. #state.wandDefs .. " wands")
    end

    return true
end

--- Open the wand panel
function WandPanel.open()
    if state.isVisible then return end

    -- Try to initialize if not yet done
    if not state.initialized then
        if #state.wandDefs == 0 then
            if _G.log_warn then
                _G.log_warn("[WandPanel] Cannot open - no wand definitions set")
            end
            return
        end
        local success = WandPanel.initialize()
        if not success then
            return
        end
    end

    showPanel()
    state.isVisible = true

    -- Emit signal
    local ok, signal = pcall(require, "external.hump.signal")
    if ok and signal then
        signal.emit("wand_panel_opened")
    end

    if _G.log_debug then
        _G.log_debug("[WandPanel] Opened")
    end
end

--- Close the wand panel
function WandPanel.close()
    if not state.isVisible then return end

    -- Hide panel and cards
    hidePanel()
    state.isVisible = false

    -- Emit signal
    local ok, signal = pcall(require, "external.hump.signal")
    if ok and signal then
        signal.emit("wand_panel_closed")
    end

    if _G.log_debug then
        _G.log_debug("[WandPanel] Closed")
    end
end

--- Toggle the wand panel visibility
function WandPanel.toggle()
    if state.isVisible then
        WandPanel.close()
    else
        WandPanel.open()
    end
end

--- Check if the panel is open
--- @return boolean
function WandPanel.isOpen()
    return state.isVisible
end

--- Set wand definitions for the panel
--- @param wandDefs table[] Array of wand definition tables
function WandPanel.setWandDefs(wandDefs)
    if not wandDefs or #wandDefs == 0 then
        if _G.log_warn then
            _G.log_warn("[WandPanel] setWandDefs called with empty array")
        end
        return
    end

    state.wandDefs = wandDefs

    -- Initialize adapter with same definitions
    local ok, wandAdapter = pcall(require, "ui.wand_grid_adapter")
    if ok and wandAdapter and wandAdapter.init and (wandAdapter.getWandCount and wandAdapter.getWandCount() == 0) then
        wandAdapter.init(wandDefs)
    end

    -- If already initialized, reinitialize with new wands
    if state.initialized then
        WandPanel.destroy()
        -- TODO: Re-initialize (implemented in later phases)
    end

    if _G.log_debug then
        _G.log_debug("[WandPanel] Set " .. #wandDefs .. " wand definitions")
    end
end

--- Select a wand by index
--- @param index number 1-based wand index
function WandPanel.selectWand(index)
    if index < 1 or index > #state.wandDefs then
        if _G.log_warn then
            _G.log_warn("[WandPanel] Invalid wand index: " .. tostring(index))
        end
        return
    end

    if index == state.activeWandIndex then return end

    local oldIndex = state.activeWandIndex
    state.activeWandIndex = index

    -- Swap grids for new wand definition
    if state.initialized then
        local wandDef = state.wandDefs[state.activeWandIndex]

        updatePanelPosition(wandDef)

        -- Suspend adapter sync during internal swap
        state.suspendSync = true

        -- Clear old grids (hide removed items so they don't linger on screen)
        clearGridItems(state.triggerGridEntity, true)
        clearGridItems(state.actionGridEntity, true)

        -- Cleanup old grid resources
        if state.triggerGridEntity then
            cleanupGrid(state.triggerGridEntity, "wand_trigger_grid_" .. oldIndex)
            state.triggerGridEntity = nil
        end
        if state.actionGridEntity then
            cleanupGrid(state.actionGridEntity, "wand_action_grid_" .. oldIndex)
            state.actionGridEntity = nil
        end

        -- Inject new grids for active wand
        state.triggerGridEntity = injectTriggerGrid(wandDef)
        state.actionGridEntity = injectActionGrid(wandDef)

        state.suspendSync = false

        -- Load cards from adapter into new grids
        local adapter_ok, adapter = pcall(require, "ui.wand_grid_adapter")
        local grid_ok, grid = pcall(require, "core.inventory_grid")
        if adapter_ok and adapter and grid_ok and grid then
            local loadout = adapter.getLoadout and adapter.getLoadout(state.activeWandIndex)
            if loadout then
                state.suspendSync = true
                if state.triggerGridEntity and loadout.trigger and _G.registry and _G.registry.valid and _G.registry:valid(loadout.trigger) then
                    local ok = grid.addItem(state.triggerGridEntity, loadout.trigger, 1)
                    if ok then
                        centerItemOnSlot(state.triggerGridEntity, loadout.trigger, 1)
                        setCardEntityVisible(loadout.trigger, state.isVisible)
                    end
                end

                if state.actionGridEntity and loadout.actions then
                    for slotIndex, itemEntity in pairs(loadout.actions) do
                        if itemEntity and _G.registry and _G.registry.valid and _G.registry:valid(itemEntity) then
                            local ok = grid.addItem(state.actionGridEntity, itemEntity, slotIndex)
                            if ok then
                                centerItemOnSlot(state.actionGridEntity, itemEntity, slotIndex)
                                setCardEntityVisible(itemEntity, state.isVisible)
                            end
                        end
                    end
                end
                state.suspendSync = false
            end
        end

    end

    -- Emit signal
    local ok, signal = pcall(require, "external.hump.signal")
    if ok and signal then
        signal.emit("wand_selected", index, oldIndex)
    end

    if _G.log_debug then
        _G.log_debug("[WandPanel] Selected wand " .. index)
    end
end

--- Equip a trigger card to the active wand's trigger slot
--- @param cardEntity number Entity ID of the trigger card
--- @return boolean Success
function WandPanel.equipToTriggerSlot(cardEntity)
    if not state.initialized or not state.triggerGridEntity then
        return false
    end

    -- Check entity validity
    if not _G.registry or not _G.registry.valid then return false end
    if not cardEntity or not _G.registry:valid(cardEntity) then return false end

    -- Verify it's a trigger card
    if _G.getScriptTableFromEntityID then
        local script = _G.getScriptTableFromEntityID(cardEntity)
        local data = script and (script.cardData or script)
        if not data or data.type ~= "trigger" then
            if _G.log_debug then
                _G.log_debug("[WandPanel] equipToTriggerSlot: Not a trigger card")
            end
            return false
        end
    end

    -- Try to add to trigger grid
    local grid_ok, grid = pcall(require, "core.inventory_grid")
    if not grid_ok then return false end

    -- Check if slot 1 is occupied
    local existing = grid.getItemAtIndex(state.triggerGridEntity, 1)
    if existing then
        -- Swap: return existing to inventory first
        local returned = returnCardToInventory(existing)
        if not returned then
            return false
        end
    end

    -- Add new trigger card to slot 1
    local success = grid.addItem(state.triggerGridEntity, cardEntity, 1)
    if success then
        state.cardRegistry[cardEntity] = true
        centerItemOnSlot(state.triggerGridEntity, cardEntity, 1)
        if _G.log_debug then
            _G.log_debug("[WandPanel] Equipped trigger card to slot 1")
        end
    end
    return success
end

--- Equip an action/modifier card to the active wand's action grid
--- @param cardEntity number Entity ID of the action/modifier card
--- @return boolean Success
function WandPanel.equipToActionSlot(cardEntity)
    if not state.initialized or not state.actionGridEntity then
        return false
    end

    -- Check entity validity
    if not _G.registry or not _G.registry.valid then return false end
    if not cardEntity or not _G.registry:valid(cardEntity) then return false end

    -- Verify it's an action or modifier card
    if _G.getScriptTableFromEntityID then
        local script = _G.getScriptTableFromEntityID(cardEntity)
        local data = script and (script.cardData or script)
        if not data then
            return false
        end

        local cardType = data.type
        if cardType ~= "action" and cardType ~= "modifier" then
            if _G.log_debug then
                _G.log_debug("[WandPanel] equipToActionSlot: Not an action/modifier card")
            end
            return false
        end
    end

    -- Try to add to action grid (first empty slot)
    local grid_ok, grid = pcall(require, "core.inventory_grid")
    if not grid_ok then return false end

    local success, slotIndex = grid.addItem(state.actionGridEntity, cardEntity)
    if success then
        state.cardRegistry[cardEntity] = true
        if slotIndex then
            centerItemOnSlot(state.actionGridEntity, cardEntity, slotIndex)
        end
        if _G.log_debug then
            _G.log_debug("[WandPanel] Equipped action card to slot " .. slotIndex)
        end
    else
        if _G.log_debug then
            _G.log_debug("[WandPanel] Action grid is full")
        end
    end
    return success
end

--- Get the trigger grid entity for the active wand
--- @return number? Grid entity ID or nil
function WandPanel.getTriggerGrid()
    return state.triggerGridEntity
end

--- Get the action grid entity for the active wand
--- @return number? Grid entity ID or nil
function WandPanel.getActionGrid()
    return state.actionGridEntity
end

--- Destroy the panel and cleanup resources
function WandPanel.destroy()
    if not state.initialized then return end

    if _G.log_debug then
        _G.log_debug("[WandPanel] Destroying...")
    end

    -- Cleanup signals
    cleanupSignalHandlers()

    -- Kill all timers in group
    local ok, timer = pcall(require, "core.timer")
    if ok and timer and timer.kill_group then
        timer.kill_group(TIMER_GROUP)
    end

    -- Clear state
    state.cardRegistry = {}
    state.triggerCards = {}
    state.actionCards = {}
    state.triggerGridEntity = nil
    state.actionGridEntity = nil
    state.panelEntity = nil
    state.tabContainerEntity = nil
    state.tabMarkerEntity = nil
    state.tabEntities = {}
    state.initialized = false
    state.isVisible = false

    if _G.log_debug then
        _G.log_debug("[WandPanel] Destroyed")
    end
end

-- Export cleanup for gameplay.lua resetGameToStart()
WandPanel.cleanupSignalHandlers = cleanupSignalHandlers

--------------------------------------------------------------------------------
-- PLANNING PHASE AUTO-OPEN HOOK
--------------------------------------------------------------------------------

-- Setup planning phase entry hook (following PlayerInventory pattern)
-- Wrapped in pcall since signal module might not be loaded yet
do
    local ok, signal = pcall(require, "external.hump.signal")
    if ok and signal and not state.gameStateHandlerRegistered then
        state.gameStateHandlerRegistered = true

        local gameStateHandler = function(data)
            if not data or not data.current then
                return
            end

            -- Auto-open on entering planning phase
            if data.current == "PLANNING" then
                -- Only open if wand defs have been set
                if #state.wandDefs > 0 then
                    if _G.log_debug then
                        _G.log_debug("[WandPanel] Planning phase entered, auto-opening")
                    end
                    WandPanel.open()
                else
                    if _G.log_debug then
                        _G.log_debug("[WandPanel] Planning phase entered but no wand defs set")
                    end
                end
            end

            -- Auto-close when leaving planning phase (entering action, shop, etc.)
            if data.current ~= "PLANNING" and WandPanel.isOpen() then
                if _G.log_debug then
                    _G.log_debug("[WandPanel] Leaving planning phase, auto-closing")
                end
                WandPanel.close()
            end
        end

        signal.register("game_state_changed", gameStateHandler)
        table.insert(state.signalHandlers, { event = "game_state_changed", handler = gameStateHandler })

        if _G.log_debug then
            _G.log_debug("[WandPanel] Registered game_state_changed handler for auto-open")
        end
    end
end

-- Also check on module load in case already in planning phase (hot-reload scenario)
do
    local timer_ok, timer_module = pcall(require, "core.timer")
    if timer_ok and timer_module and timer_module.after_opts then
        timer_module.after_opts({
            delay = 0.1,
            action = function()
                if _G.is_state_active and _G.PLANNING_STATE and _G.is_state_active(_G.PLANNING_STATE) then
                    if #state.wandDefs > 0 and not WandPanel.isOpen() then
                        if _G.log_debug then
                            _G.log_debug("[WandPanel] Already in planning phase on module load, auto-opening")
                        end
                        WandPanel.open()
                    end
                end
            end,
            tag = "wand_panel_phase_setup"
        })
    end
end

--------------------------------------------------------------------------------
-- TEST HELPERS (for unit testing internal functions)
--------------------------------------------------------------------------------

WandPanel._test = {
    getGridDimensions = getGridDimensions,
    calculatePanelDimensions = calculatePanelDimensions,
    getState = function() return state end,
    -- Tab system helpers
    getTabLabel = getTabLabel,
    createWandTabs = createWandTabs,
    updateTabHighlighting = updateTabHighlighting,
    positionTabs = positionTabs,
    -- Grid definition helpers
    createTriggerGridDefinition = createTriggerGridDefinition,
    createActionGridDefinition = createActionGridDefinition,
    cleanupGrid = cleanupGrid,
    -- Stats display helpers
    formatStatValue = formatStatValue,
    buildStatsText = buildStatsText,
    createWandStatsRow = createWandStatsRow,
    updateStatsDisplay = updateStatsDisplay,
    -- WandAdapter sync helpers
    syncTriggerToAdapter = syncTriggerToAdapter,
    syncActionsToAdapter = syncActionsToAdapter,
    syncAllToAdapter = syncAllToAdapter,
    returnCardToInventory = returnCardToInventory,
    setupSignalHandlers = setupSignalHandlers,
    -- Input handling helpers
    handleQuickEquip = handleQuickEquip,
    setupInputHandler = setupInputHandler,
    -- Panel definition helpers
    createHeader = createHeader,
    createTriggerSection = createTriggerSection,
    createActionSection = createActionSection,
    createPanelDefinition = createPanelDefinition,
    -- Lifecycle helpers
    showPanel = showPanel,
    hidePanel = hidePanel,
    injectTriggerGrid = injectTriggerGrid,
    injectActionGrid = injectActionGrid,
}

return WandPanel
