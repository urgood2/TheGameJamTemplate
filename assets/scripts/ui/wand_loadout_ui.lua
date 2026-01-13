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
local signal = require("external.hump.signal")
local signal_group = require("core.signal_group")
local component_cache = require("core.component_cache")
local timer = require("core.timer")
local InventoryGridInit = require("ui.inventory_grid_init")
local z_orders = require("core.z_orders")

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

local function createHeader()
    return dsl.hbox {
        config = {
            color = "dark_lavender",
            padding = { 10, 6 },
            emboss = 2,
            minWidth = PANEL_WIDTH - PANEL_PADDING * 2,
        },
        children = {
            dsl.text(getLocalizedText("ui.wand_loadout.title", "Wand Loadout"), {
                fontSize = 16,
                color = "gold",
                shadow = true,
            }),
            dsl.spacer(1),
        },
    }
end

--------------------------------------------------------------------------------
-- UI Creation: Trigger Section
--------------------------------------------------------------------------------

local function createTriggerSection()
    local triggerGridDef = dsl.inventoryGrid {
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

    return dsl.vbox {
        config = {
            padding = 4,
        },
        children = {
            dsl.text(getLocalizedText("ui.wand_loadout.trigger", "Trigger"), {
                fontSize = 12,
                color = "light_gray",
            }),
            dsl.spacer(TRIGGER_SLOT_SIZE + 8, 4),
            triggerGridDef,
        },
    }
end

--------------------------------------------------------------------------------
-- UI Creation: Action Slots Section
--------------------------------------------------------------------------------

local function createActionSection()
    local actionGridDef = dsl.inventoryGrid {
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

    return dsl.vbox {
        config = {
            padding = 4,
        },
        children = {
            dsl.text(getLocalizedText("ui.wand_loadout.actions", "Actions"), {
                fontSize = 12,
                color = "light_gray",
            }),
            dsl.spacer(ACTION_GRID_WIDTH, 4),
            actionGridDef,
        },
    }
end

--------------------------------------------------------------------------------
-- UI Creation: Close Button
--------------------------------------------------------------------------------

local function createCloseButton(panelX, panelY, panelWidth)
    local closeButtonDef = dsl.button("X", {
        id = "wand_loadout_close_btn",
        minWidth = 24,
        minHeight = 24,
        fontSize = 14,
        color = "darkred",
        hover = true,
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
    return dsl.root {
        config = {
            id = PANEL_ID,
            color = "blackberry",
            padding = PANEL_PADDING,
            emboss = 3,
            minWidth = PANEL_WIDTH,
            maxWidth = PANEL_WIDTH,
        },
        children = {
            createHeader(),
            dsl.spacer(PANEL_WIDTH - PANEL_PADDING * 2, SECTION_SPACING),
            createTriggerSection(),
            dsl.spacer(PANEL_WIDTH - PANEL_PADDING * 2, SECTION_SPACING),
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

    -- Grid item events
    state.handlers:on("grid_item_added", function(gridEntity, slotIndex, itemEntity)
        if gridEntity == state.triggerGridEntity then
            log_debug("[WandLoadoutUI] Trigger card added")
        elseif gridEntity == state.actionGridEntity then
            log_debug("[WandLoadoutUI] Action card added to slot " .. slotIndex)
        end
    end)

    state.handlers:on("grid_item_removed", function(gridEntity, slotIndex, itemEntity)
        if gridEntity == state.triggerGridEntity then
            log_debug("[WandLoadoutUI] Trigger card removed")
        elseif gridEntity == state.actionGridEntity then
            log_debug("[WandLoadoutUI] Action card removed from slot " .. slotIndex)
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
-- Module Load
--------------------------------------------------------------------------------

log_debug("[WandLoadoutUI] Module loaded")

return WandLoadoutUI
