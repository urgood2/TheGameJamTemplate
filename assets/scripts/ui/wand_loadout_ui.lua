--[[
================================================================================
WAND LOADOUT UI - Grid-Based Wand Card Management Panel
================================================================================

Displays the equipped wand cards in a dedicated loadout panel.
Opened/closed with the E key.

USAGE:
------
local WandLoadoutUI = require("ui.wand_loadout_ui")

WandLoadoutUI.open()           -- Show loadout panel
WandLoadoutUI.close()          -- Hide loadout panel
WandLoadoutUI.toggle()         -- Toggle visibility (E key handler)
WandLoadoutUI.isOpen()         -- Check if visible

EVENTS (via hump.signal):
-------------------------
"wand_loadout_opened"          -- Panel opened
"wand_loadout_closed"          -- Panel closed
"wand_trigger_changed"         -- Trigger card changed
"wand_action_changed"          -- Action card changed
"wand_slots_reduced"           -- (newRows, newCols, overflowItems) Wand slots reduced
"wand_slots_overflow"          -- (overflowItems, transferredCount) Cards returned to inventory

SLOT MANAGEMENT:
---------------
WandLoadoutUI.reduceActionSlots(newRows, newCols)  -- Reduce slots, overflow → inventory
WandLoadoutUI.getActionGridDimensions()            -- Get current (rows, cols)
WandLoadoutUI.previewOverflowCount(newRows, newCols)  -- Check overflow before resize

LAYOUT:
-------
+---------------------------+
|    Wand Loadout [X]       |  <- Header with close button
+---------------------------+
|  [Trigger]                |  <- Trigger slot (1x1)
+---------------------------+
|  [ ][ ][ ][ ]             |  <- Action slots (2x4)
|  [ ][ ][ ][ ]             |
+---------------------------+

================================================================================
]]

local WandLoadoutUI = {}

local dsl = require("ui.ui_syntax_sugar")
local grid = require("core.inventory_grid")
local transfer = require("core.grid_transfer")
local signal = require("external.hump.signal")
local signal_group = require("core.signal_group")
local component_cache = require("core.component_cache")
local timer = require("core.timer")
local InventoryGridInit = require("ui.inventory_grid_init")
local z_orders = require("core.z_orders")
local wandAdapter = require("ui.wand_grid_adapter")
local popup = require("core.popup")

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local TIMER_GROUP = "wand_loadout_ui"
local PANEL_ID = "wand_loadout_panel"

-- Grid dimensions
local ACTION_ROWS = 2
local ACTION_COLS = 4
local SLOT_WIDTH = 56
local SLOT_HEIGHT = 78
local SLOT_SPACING = 4

-- Layout calculations
local ACTION_GRID_WIDTH = ACTION_COLS * SLOT_WIDTH + (ACTION_COLS - 1) * SLOT_SPACING + 16
local ACTION_GRID_HEIGHT = ACTION_ROWS * SLOT_HEIGHT + (ACTION_ROWS - 1) * SLOT_SPACING + 16
local TRIGGER_SLOT_SIZE = 78
local HEADER_HEIGHT = 36
local SECTION_SPACING = 12
local PANEL_PADDING = 12

local PANEL_WIDTH = ACTION_GRID_WIDTH + PANEL_PADDING * 2
local PANEL_HEIGHT = HEADER_HEIGHT + SECTION_SPACING + TRIGGER_SLOT_SIZE + SECTION_SPACING + ACTION_GRID_HEIGHT + PANEL_PADDING * 2

local RENDER_LAYER = "sprites"

--------------------------------------------------------------------------------
-- Module State
--------------------------------------------------------------------------------

local state = {
    initialized = false,
    isVisible = false,
    panelEntity = nil,
    closeButtonEntity = nil,
    triggerGridEntity = nil,
    actionGridEntity = nil,
    panelX = 0,
    panelY = 0,
    handlers = nil,  -- signal_group for cleanup
    currentWandIndex = 1,  -- Currently selected wand (1-based)
    wandCount = 1,  -- Total number of wands available
}

--------------------------------------------------------------------------------
-- Helper Functions
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

local function setEntityVisible(entity, visible, onscreenX)
    if not entity or not registry:valid(entity) then return end
    local t = component_cache.get(entity, Transform)
    if t then
        t.actualX = visible and onscreenX or -9999
    end
end

local function setGridItemsVisible(gridEntity, visible)
    if not gridEntity then return end
    local items = grid.getAllItems(gridEntity)
    for _, itemEntity in pairs(items) do
        if itemEntity and registry:valid(itemEntity) then
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
    end
end

--------------------------------------------------------------------------------
-- UI Creation: Header
--------------------------------------------------------------------------------

local function getWandTitle()
    if state.wandCount <= 1 then
        return getLocalizedText("ui.wand_loadout.title", "Wand Loadout")
    end
    return string.format("%s %d/%d", getLocalizedText("ui.wand_loadout.title", "Wand"), state.currentWandIndex, state.wandCount)
end

local function createHeader()
    local children = {
        dsl.strict.text(getWandTitle(), {
            id = "wand_title_text",
            fontSize = 16,
            color = "gold",
            shadow = true,
        }),
        dsl.strict.spacer(1),
    }

    if state.wandCount > 1 then
        table.insert(children, 1, dsl.strict.button("<", {
            id = "prev_wand_btn",
            fontSize = 14,
            color = "light_gray",
            onClick = function()
                WandLoadoutUI.selectWand(state.currentWandIndex - 1)
            end,
        }))
        table.insert(children, dsl.strict.button(">", {
            id = "next_wand_btn",
            fontSize = 14,
            color = "light_gray",
            onClick = function()
                WandLoadoutUI.selectWand(state.currentWandIndex + 1)
            end,
        }))
    end

    return dsl.strict.hbox {
        config = {
            color = "dark_lavender",
            padding = 10,
            emboss = 2,
            minWidth = PANEL_WIDTH - PANEL_PADDING * 2,
        },
        children = children,
    }
end

--------------------------------------------------------------------------------
-- UI Creation: Trigger Section
--------------------------------------------------------------------------------

local function createTriggerSection()
    local triggerGridDef = dsl.strict.inventoryGrid {
        id = "wand_trigger_grid",
        rows = 1,
        cols = 1,
        slotSize = { w = TRIGGER_SLOT_SIZE, h = TRIGGER_SLOT_SIZE },
        slotSpacing = 0,

        config = {
            allowDragIn = true,
            allowDragOut = true,
            stackable = false,
            slotSprite = "test-inventory-square-single.png",
            padding = 4,
            backgroundColor = "blackberry",
            slotType = "trigger",
        },

        onSlotChange = function(gridEntity, slotIndex, oldItem, newItem)
            log_debug("[WandLoadoutUI] Trigger slot changed")
            signal.emit("wand_trigger_changed", newItem, oldItem)
        end,
    }

    return dsl.strict.vbox {
        config = {
            padding = 4,
        },
        children = {
            dsl.strict.text(getLocalizedText("ui.wand_loadout.trigger", "Trigger"), {
                fontSize = 12,
                color = "light_gray",
            }),
            dsl.strict.spacer(TRIGGER_SLOT_SIZE + 8, 4),
            triggerGridDef,
        },
    }
end

--------------------------------------------------------------------------------
-- UI Creation: Action Slots Section
--------------------------------------------------------------------------------

local function createActionSection()
    local actionGridDef = dsl.strict.inventoryGrid {
        id = "wand_action_grid",
        rows = ACTION_ROWS,
        cols = ACTION_COLS,
        slotSize = { w = SLOT_WIDTH, h = SLOT_HEIGHT },
        slotSpacing = SLOT_SPACING,

        config = {
            allowDragIn = true,
            allowDragOut = true,
            stackable = false,
            slotSprite = "test-inventory-square-single.png",
            padding = 4,
            backgroundColor = "blackberry",
            slotType = "action",
        },

        onSlotChange = function(gridEntity, slotIndex, oldItem, newItem)
            log_debug("[WandLoadoutUI] Action slot " .. slotIndex .. " changed")
            signal.emit("wand_action_changed", slotIndex, newItem, oldItem)
        end,
    }

    return dsl.strict.vbox {
        config = {
            padding = 4,
        },
        children = {
            dsl.strict.text(getLocalizedText("ui.wand_loadout.actions", "Actions"), {
                fontSize = 12,
                color = "light_gray",
            }),
            dsl.strict.spacer(ACTION_GRID_WIDTH, 4),
            actionGridDef,
        },
    }
end

--------------------------------------------------------------------------------
-- UI Creation: Close Button
--------------------------------------------------------------------------------

local function createCloseButton(panelX, panelY, panelWidth)
    local closeButtonDef = dsl.strict.button("X", {
        id = "wand_loadout_close_btn",
        minWidth = 24,
        minHeight = 24,
        fontSize = 14,
        color = "darkred",
        onClick = function()
            WandLoadoutUI.close()
        end,
    })

    local closeX = panelX + panelWidth - 32
    local closeY = panelY + 6

    local closeEntity = dsl.spawn({ x = closeX, y = closeY }, closeButtonDef, RENDER_LAYER, 200)
    if ui and ui.box and ui.box.set_draw_layer then
        ui.box.set_draw_layer(closeEntity, RENDER_LAYER)
    end

    return closeEntity
end

--------------------------------------------------------------------------------
-- UI Creation: Main Panel Definition
--------------------------------------------------------------------------------

local function createPanelDefinition()
    return dsl.strict.root {
        config = {
            id = PANEL_ID,
            color = "blackberry",
            padding = PANEL_PADDING,
        },
        children = {
            createHeader(),
            dsl.strict.spacer(PANEL_WIDTH - PANEL_PADDING * 2, SECTION_SPACING),
            createTriggerSection(),
            dsl.strict.spacer(PANEL_WIDTH - PANEL_PADDING * 2, SECTION_SPACING),
            createActionSection(),
        },
    }
end

--------------------------------------------------------------------------------
-- Grid Initialization
--------------------------------------------------------------------------------

local function initializeGrids()
    -- Initialize trigger grid
    local triggerGridEntity = ui.box.GetUIEByID(registry, state.panelEntity, "wand_trigger_grid")
    if triggerGridEntity then
        state.triggerGridEntity = triggerGridEntity
        local success = InventoryGridInit.initializeIfGrid(triggerGridEntity, "wand_trigger_grid")
        if success then
            log_debug("[WandLoadoutUI] Trigger grid initialized")
        else
            log_warn("[WandLoadoutUI] Trigger grid init failed!")
        end
    end

    -- Initialize action grid
    local actionGridEntity = ui.box.GetUIEByID(registry, state.panelEntity, "wand_action_grid")
    if actionGridEntity then
        state.actionGridEntity = actionGridEntity
        local success = InventoryGridInit.initializeIfGrid(actionGridEntity, "wand_action_grid")
        if success then
            log_debug("[WandLoadoutUI] Action grid initialized")
        else
            log_warn("[WandLoadoutUI] Action grid init failed!")
        end
    end
end

--------------------------------------------------------------------------------
-- Event Handlers Setup (using signal_group)
--------------------------------------------------------------------------------

local function setupSignalHandlers()
    -- Create signal group for automatic cleanup
    state.handlers = signal_group.new("wand_loadout_ui")

    -- Helper to check if a grid belongs to this wand loadout
    local function isOurGrid(gridEntity)
        return gridEntity == state.triggerGridEntity or gridEntity == state.actionGridEntity
    end

    state.handlers:on("grid_item_added", function(gridEntity, slotIndex, itemEntity)
        if gridEntity == state.triggerGridEntity then
            log_debug("[WandLoadoutUI] Trigger card added for wand " .. state.currentWandIndex)
            wandAdapter.setTrigger(state.currentWandIndex, itemEntity)
            signal.emit("wand_trigger_changed", itemEntity, nil, state.currentWandIndex)
        elseif gridEntity == state.actionGridEntity then
            log_debug("[WandLoadoutUI] Action card added to slot " .. slotIndex .. " for wand " .. state.currentWandIndex)
            wandAdapter.setAction(state.currentWandIndex, slotIndex, itemEntity)
            signal.emit("wand_action_changed", slotIndex, itemEntity, nil, state.currentWandIndex)
        end
    end)

    state.handlers:on("grid_item_removed", function(gridEntity, slotIndex, itemEntity)
        if gridEntity == state.triggerGridEntity then
            log_debug("[WandLoadoutUI] Trigger card removed from wand " .. state.currentWandIndex)
            wandAdapter.clearSlot(state.currentWandIndex, nil)
            signal.emit("wand_trigger_changed", nil, itemEntity, state.currentWandIndex)
        elseif gridEntity == state.actionGridEntity then
            log_debug("[WandLoadoutUI] Action card removed from slot " .. slotIndex .. " for wand " .. state.currentWandIndex)
            wandAdapter.clearSlot(state.currentWandIndex, slotIndex)
            signal.emit("wand_action_changed", slotIndex, nil, itemEntity, state.currentWandIndex)
        end
    end)

    state.handlers:on("grid_cross_transfer_success", function(itemEntity, fromGrid, toGrid, toSlot)
        if toGrid == state.triggerGridEntity then
            log_debug("[WandLoadoutUI] Cross-grid transfer: card equipped to trigger slot for wand " .. state.currentWandIndex)
            wandAdapter.setTrigger(state.currentWandIndex, itemEntity)
            signal.emit("wand_trigger_changed", itemEntity, nil, state.currentWandIndex)
        elseif toGrid == state.actionGridEntity then
            log_debug("[WandLoadoutUI] Cross-grid transfer: card equipped to action slot " .. toSlot .. " for wand " .. state.currentWandIndex)
            wandAdapter.setAction(state.currentWandIndex, toSlot, itemEntity)
            signal.emit("wand_action_changed", toSlot, itemEntity, nil, state.currentWandIndex)
        end
    end)

    state.handlers:on("grid_transfer_success", function(itemEntity, fromGrid, fromSlot, toGrid, toSlot)
        if not isOurGrid(toGrid) then return end

        if toGrid == state.triggerGridEntity then
            log_debug("[WandLoadoutUI] Transfer success: card to trigger slot for wand " .. state.currentWandIndex)
            wandAdapter.setTrigger(state.currentWandIndex, itemEntity)
        elseif toGrid == state.actionGridEntity then
            log_debug("[WandLoadoutUI] Transfer success: card to action slot " .. toSlot .. " for wand " .. state.currentWandIndex)
            wandAdapter.setAction(state.currentWandIndex, toSlot, itemEntity)
        end
    end)
end

--------------------------------------------------------------------------------
-- Input Handling: E Key Toggle
--------------------------------------------------------------------------------

local function setupInputHandler()
    timer.run_every_render_frame(function()
        -- E key toggle
        if isKeyPressed and isKeyPressed("KEY_E") then
            -- Don't toggle if player inventory or other modal is open
            -- (Add exclusion checks here if needed)
            WandLoadoutUI.toggle()
        end

        -- ESC to close (if open)
        if state.isVisible and isKeyPressed and isKeyPressed("KEY_ESCAPE") then
            WandLoadoutUI.close()
        end
    end, nil, "wand_loadout_input", TIMER_GROUP)
end

--------------------------------------------------------------------------------
-- Click Outside Detection
--------------------------------------------------------------------------------

local function setupClickOutsideHandler()
    timer.run_every_render_frame(function()
        if not state.isVisible then return end

        -- Check for mouse click
        local mousePressed = IsMouseButtonPressed and IsMouseButtonPressed(0)
        if not mousePressed then return end

        -- Get mouse position
        local mx = GetMouseX and GetMouseX() or 0
        local my = GetMouseY and GetMouseY() or 0

        -- Check if click is outside panel bounds
        local panelT = state.panelEntity and component_cache.get(state.panelEntity, Transform)
        if panelT then
            local px = panelT.actualX or panelT.visualX or state.panelX
            local py = panelT.actualY or panelT.visualY or state.panelY
            local pw = panelT.actualW or PANEL_WIDTH
            local ph = panelT.actualH or PANEL_HEIGHT

            -- If click is outside panel, close it
            if mx < px or mx > px + pw or my < py or my > py + ph then
                -- Small delay to avoid closing immediately on the click that might have opened it
                timer.after_opts({
                    delay = 0.05,
                    action = function()
                        if state.isVisible then
                            WandLoadoutUI.close()
                        end
                    end,
                    tag = "close_check",
                })
            end
        end
    end, nil, "wand_loadout_click_outside", TIMER_GROUP)
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

local function initializePanel()
    if state.initialized then return end

    local screenW = globals and globals.screenWidth and globals.screenWidth() or 1920
    local screenH = globals and globals.screenHeight and globals.screenHeight() or 1080

    -- Position panel on right side of screen
    state.panelX = screenW - PANEL_WIDTH - 20
    state.panelY = (screenH - PANEL_HEIGHT) / 2

    -- Create panel definition and spawn (hidden initially)
    local panelDef = createPanelDefinition()
    state.panelEntity = dsl.spawn({ x = -9999, y = state.panelY }, panelDef, RENDER_LAYER, 100)

    if ui and ui.box and ui.box.set_draw_layer then
        ui.box.set_draw_layer(state.panelEntity, RENDER_LAYER)
    end

    -- Create close button
    state.closeButtonEntity = createCloseButton(state.panelX, state.panelY, PANEL_WIDTH)
    setEntityVisible(state.closeButtonEntity, false, state.panelX + PANEL_WIDTH - 32)

    -- Initialize grids
    initializeGrids()

    -- Setup event handlers
    setupSignalHandlers()

    -- Setup input handling
    setupInputHandler()

    -- Setup click-outside detection
    setupClickOutsideHandler()

    state.initialized = true
    log_debug("[WandLoadoutUI] Initialized (hidden)")
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function WandLoadoutUI.open()
    if not state.initialized then
        initializePanel()
    end

    if state.isVisible then return end

    -- Show panel
    setEntityVisible(state.panelEntity, true, state.panelX)
    setEntityVisible(state.closeButtonEntity, true, state.panelX + PANEL_WIDTH - 32)

    -- Show grid items
    setGridItemsVisible(state.triggerGridEntity, true)
    setGridItemsVisible(state.actionGridEntity, true)

    state.isVisible = true
    signal.emit("wand_loadout_opened")

    if playSoundEffect then
        playSoundEffect("effects", "button-click")
    end

    log_debug("[WandLoadoutUI] Opened")
end

function WandLoadoutUI.close()
    if not state.isVisible then return end

    -- Hide panel
    setEntityVisible(state.panelEntity, false, state.panelX)
    setEntityVisible(state.closeButtonEntity, false, state.panelX + PANEL_WIDTH - 32)

    -- Hide grid items
    setGridItemsVisible(state.triggerGridEntity, false)
    setGridItemsVisible(state.actionGridEntity, false)

    state.isVisible = false
    signal.emit("wand_loadout_closed")

    log_debug("[WandLoadoutUI] Closed")
end

function WandLoadoutUI.toggle()
    if state.isVisible then
        WandLoadoutUI.close()
    else
        WandLoadoutUI.open()
    end
end

function WandLoadoutUI.isOpen()
    return state.isVisible
end

--------------------------------------------------------------------------------
-- Grid Access API (for integration with wand_grid_adapter)
--------------------------------------------------------------------------------

function WandLoadoutUI.getTriggerGrid()
    return state.triggerGridEntity
end

function WandLoadoutUI.getActionGrid()
    return state.actionGridEntity
end

function WandLoadoutUI.getTriggerCard()
    if not state.triggerGridEntity then return nil end
    return grid.getItemAtIndex(state.triggerGridEntity, 1)
end

function WandLoadoutUI.getActionCards()
    if not state.actionGridEntity then return {} end
    return grid.getAllItems(state.actionGridEntity)
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

function WandLoadoutUI.destroy()
    if not state.initialized then return end

    log_debug("[WandLoadoutUI] Destroying...")

    -- Cleanup signal handlers via signal_group
    if state.handlers then
        state.handlers:cleanup()
        state.handlers = nil
    end

    -- Kill all timers in our group
    timer.kill_group(TIMER_GROUP)

    -- Cleanup grids
    if state.triggerGridEntity and registry:valid(state.triggerGridEntity) then
        grid.cleanup(state.triggerGridEntity)
        dsl.cleanupGrid("wand_trigger_grid")
    end

    if state.actionGridEntity and registry:valid(state.actionGridEntity) then
        grid.cleanup(state.actionGridEntity)
        dsl.cleanupGrid("wand_action_grid")
    end

    -- Destroy close button
    if state.closeButtonEntity and registry:valid(state.closeButtonEntity) then
        if ui and ui.box and ui.box.Remove then
            ui.box.Remove(registry, state.closeButtonEntity)
        end
    end

    -- Destroy panel
    if state.panelEntity and registry:valid(state.panelEntity) then
        if ui and ui.box and ui.box.Remove then
            ui.box.Remove(registry, state.panelEntity)
        end
    end

    -- Reset state
    state.initialized = false
    state.isVisible = false
    state.panelEntity = nil
    state.closeButtonEntity = nil
    state.triggerGridEntity = nil
    state.actionGridEntity = nil

    log_debug("[WandLoadoutUI] Destroyed")
end

--------------------------------------------------------------------------------
-- Wand Slot Resize & Overflow Handling
--------------------------------------------------------------------------------

--- Get the player inventory grid to return overflow cards to.
-- Tries to get the "actions" tab grid as the default destination.
-- @return number|nil Grid entity for player inventory, or nil if unavailable
local function getPlayerInventoryGrid()
    -- Lazy-load PlayerInventory to avoid circular dependency
    local ok, PlayerInventory = pcall(require, "ui.player_inventory")
    if not ok or not PlayerInventory then
        log_warn("[WandLoadoutUI] Could not load PlayerInventory module")
        return nil
    end

    -- Try to get the actions grid (default destination for overflow cards)
    if PlayerInventory.getGridForTab then
        local actionsGrid = PlayerInventory.getGridForTab("actions")
        if actionsGrid then
            return actionsGrid
        end
    end

    -- Fall back to getting any available grid
    if PlayerInventory.getGrids then
        local grids = PlayerInventory.getGrids()
        if grids then
            -- Return first available grid
            for _, gridEntity in pairs(grids) do
                if gridEntity then
                    return gridEntity
                end
            end
        end
    end

    return nil
end

--- Transfer overflow items to player inventory using atomic grid_transfer.
-- @param overflowItems table Array of { item = entity, oldSlot = N }
-- @return number Number of items successfully transferred
local function transferOverflowToInventory(overflowItems)
    if not overflowItems or #overflowItems == 0 then
        return 0
    end

    local inventoryGrid = getPlayerInventoryGrid()
    if not inventoryGrid then
        log_warn("[WandLoadoutUI] No player inventory grid available for overflow")
        return 0
    end

    local successCount = 0

    for _, overflow in ipairs(overflowItems) do
        local itemEntity = overflow.item

        if itemEntity and registry:valid(itemEntity) then
            -- Use transferItemTo for atomic transfer (finds item location automatically)
            local result = transfer.transferItemTo({
                item = itemEntity,
                toGrid = inventoryGrid,
                onSuccess = function(res)
                    log_debug("[WandLoadoutUI] Overflow card transferred to inventory slot " .. res.toSlot)
                    successCount = successCount + 1

                    -- Center item on new slot
                    local slotEntity = grid.getSlotEntity(inventoryGrid, res.toSlot)
                    if slotEntity then
                        InventoryGridInit.centerItemOnSlot(itemEntity, slotEntity)
                    end
                end,
                onFail = function(reason)
                    log_warn("[WandLoadoutUI] Failed to transfer overflow card: " .. reason)

                    -- Show feedback to player
                    if popup and popup.above then
                        popup.above(itemEntity, "No space!", { color = "red" })
                    end
                end,
            })

            if result.success then
                successCount = successCount + 1
            end
        end
    end

    return successCount
end

--- Reduce the number of action slots on the wand.
-- Cards in removed slots are automatically transferred to player inventory.
-- @param newRows number New row count (must be >= 1)
-- @param newCols number New column count (must be >= 1)
-- @return table { success = bool, overflowCount = N, transferredCount = N }
function WandLoadoutUI.reduceActionSlots(newRows, newCols)
    if not state.initialized or not state.actionGridEntity then
        log_warn("[WandLoadoutUI] Cannot reduce slots - not initialized")
        return { success = false, overflowCount = 0, transferredCount = 0 }
    end

    -- Validate minimum size
    newRows = math.max(1, newRows or 1)
    newCols = math.max(1, newCols or 1)

    -- Check how many items would overflow
    local overflowCount = grid.getOverflowCount(state.actionGridEntity, newRows, newCols)

    log_debug(string.format(
        "[WandLoadoutUI] Reducing action slots to %dx%d (%d items will overflow)",
        newRows, newCols, overflowCount
    ))

    -- Resize grid - this removes items from overflow slots and returns them
    local result = grid.resizeGrid(state.actionGridEntity, newRows, newCols)

    if not result.success then
        log_warn("[WandLoadoutUI] Grid resize failed")
        return { success = false, overflowCount = overflowCount, transferredCount = 0 }
    end

    -- Transfer overflow items to player inventory
    local transferredCount = 0
    if result.overflow and #result.overflow > 0 then
        transferredCount = transferOverflowToInventory(result.overflow)

        for _, overflow in ipairs(result.overflow) do
            wandAdapter.clearSlot(state.currentWandIndex, overflow.oldSlot)
        end

        -- Emit event for external listeners
        signal.emit("wand_slots_overflow", result.overflow, transferredCount)

        -- Show player feedback
        if transferredCount > 0 and popup and popup.above and state.panelEntity then
            popup.above(state.panelEntity,
                string.format("%d card(s) returned to inventory", transferredCount),
                { color = "gold" }
            )
        end
    end

    -- Emit slot reduction event
    signal.emit("wand_slots_reduced", newRows, newCols, result.overflow)

    log_debug(string.format(
        "[WandLoadoutUI] Slot reduction complete: %d/%d items transferred to inventory",
        transferredCount, overflowCount
    ))

    return {
        success = true,
        overflowCount = overflowCount,
        transferredCount = transferredCount,
    }
end

--- Get the current action grid dimensions.
-- @return number, number Current rows and columns
function WandLoadoutUI.getActionGridDimensions()
    if not state.actionGridEntity then
        return ACTION_ROWS, ACTION_COLS  -- Return defaults
    end
    return grid.getDimensions(state.actionGridEntity)
end

function WandLoadoutUI.previewOverflowCount(newRows, newCols)
    if not state.actionGridEntity then
        return 0
    end
    return grid.getOverflowCount(state.actionGridEntity, newRows, newCols)
end

function WandLoadoutUI.getWandCount()
    return state.wandCount
end

function WandLoadoutUI.getCurrentWandIndex()
    return state.currentWandIndex
end

function WandLoadoutUI.setWandCount(count)
    state.wandCount = math.max(1, count or 1)
    log_debug("[WandLoadoutUI] Wand count set to " .. state.wandCount)
end

local function loadCardsFromAdapter()
    if not state.initialized then return 0 end

    local loadout = wandAdapter.getLoadout(state.currentWandIndex)
    if not loadout then return 0 end

    local count = 0

    if state.triggerGridEntity then
        grid.clearGrid(state.triggerGridEntity)
        if loadout.trigger and registry:valid(loadout.trigger) then
            local ok = grid.addItemToSlot(state.triggerGridEntity, 1, loadout.trigger)
            if ok then count = count + 1 end
        end
    end

    if state.actionGridEntity then
        grid.clearGrid(state.actionGridEntity)
        if loadout.actions then
            for slotIndex, itemEntity in pairs(loadout.actions) do
                if itemEntity and registry:valid(itemEntity) then
                    local ok = grid.addItemToSlot(state.actionGridEntity, slotIndex, itemEntity)
                    if ok then count = count + 1 end
                end
            end
        end
    end

    return count
end

function WandLoadoutUI.selectWand(wandIndex)
    if not state.initialized then
        log_warn("[WandLoadoutUI] Cannot select wand - not initialized")
        return false
    end

    local newIndex = wandIndex
    if newIndex < 1 then
        newIndex = state.wandCount
    elseif newIndex > state.wandCount then
        newIndex = 1
    end

    if newIndex == state.currentWandIndex then
        return true
    end

    local oldIndex = state.currentWandIndex
    state.currentWandIndex = newIndex

    log_debug("[WandLoadoutUI] Switched from wand " .. oldIndex .. " to wand " .. newIndex)

    local loadedFromAdapter = loadCardsFromAdapter()
    if loadedFromAdapter then
        log_debug("[WandLoadoutUI] Loaded " .. loadedFromAdapter .. " cards from wand adapter")
    end

    signal.emit("wand_selected", newIndex, oldIndex)

    return true
end

--------------------------------------------------------------------------------
-- Module Load
--------------------------------------------------------------------------------

log_debug("[WandLoadoutUI] Module loaded")

return WandLoadoutUI
