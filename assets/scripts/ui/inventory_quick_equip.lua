--[[
================================================================================
INVENTORY QUICK EQUIP - Right-Click to Equip Cards to Wand Slots
================================================================================

Handles right-click on inventory cards to quickly equip them to the first
available wand slot. Works with both player inventory and wand loadout grids.

USAGE:
------
local QuickEquip = require("ui.inventory_quick_equip")

-- Call in game loop or via timer to check for right-clicks
QuickEquip.update()

-- Or manually trigger equip
QuickEquip.equipToWand(cardEntity)

EVENTS (via hump.signal):
-------------------------
"quick_equip_success"    (cardEntity, targetGrid, targetSlot)
"quick_equip_failed"     (cardEntity, reason)

================================================================================
]]

local QuickEquip = {}

local signal = require("external.hump.signal")
local timer = require("core.timer")
local grid = require("core.inventory_grid")
local transfer = require("core.grid_transfer")
local component_cache = require("core.component_cache")
local itemRegistry = require("core.item_location_registry")
local InventoryGridInit = require("ui.inventory_grid_init")

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local TIMER_GROUP = "inventory_quick_equip"

--------------------------------------------------------------------------------
-- Module State
--------------------------------------------------------------------------------

local state = {
    initialized = false,
    playerInventoryModule = nil,  -- Will be lazy-loaded to avoid circular deps
    wandLoadoutModule = nil,      -- Will be lazy-loaded
    wandPanelModule = nil,        -- Optional new WandPanel UI
    signalHandlers = {},
    lastHandledFrame = nil,
}

--------------------------------------------------------------------------------
-- Lazy Module Loading (avoids circular dependencies)
--------------------------------------------------------------------------------

local function getPlayerInventory()
    if not state.playerInventoryModule then
        local ok, mod = pcall(require, "ui.player_inventory")
        if ok then
            state.playerInventoryModule = mod
        end
    end
    return state.playerInventoryModule
end

local function getWandLoadout()
    if not state.wandLoadoutModule then
        local ok, mod = pcall(require, "ui.wand_loadout_ui")
        if ok then
            state.wandLoadoutModule = mod
        end
    end
    return state.wandLoadoutModule
end

local function getWandPanel()
    if not state.wandPanelModule then
        local ok, mod = pcall(require, "ui.wand_panel")
        if ok then
            state.wandPanelModule = mod
        end
    end
    return state.wandPanelModule
end

--------------------------------------------------------------------------------
-- Grid Access Helpers
--------------------------------------------------------------------------------

--- Get all player inventory grid entities
local function getPlayerInventoryGrids()
    local PlayerInventory = getPlayerInventory()
    if PlayerInventory and PlayerInventory.getGrids then
        return PlayerInventory.getGrids()
    end
    return {}
end

--- Check if a grid belongs to player inventory
local function isPlayerInventoryGrid(gridEntity)
    local grids = getPlayerInventoryGrids()
    for _, ge in pairs(grids) do
        if ge == gridEntity then
            return true
        end
    end
    return false
end

--- Get wand action grid (first available wand)
local function getWandActionGrid()
    local WandPanel = getWandPanel()
    if WandPanel and WandPanel.getActionGrid then
        local gridEntity = WandPanel.getActionGrid()
        if gridEntity then
            return gridEntity
        end
    end

    local WandLoadout = getWandLoadout()
    if WandLoadout and WandLoadout.getActionGrid then
        return WandLoadout.getActionGrid()
    end
    return nil
end

--- Get wand trigger grid
local function getWandTriggerGrid()
    local WandPanel = getWandPanel()
    if WandPanel and WandPanel.getTriggerGrid then
        local gridEntity = WandPanel.getTriggerGrid()
        if gridEntity then
            return gridEntity
        end
    end

    local WandLoadout = getWandLoadout()
    if WandLoadout and WandLoadout.getTriggerGrid then
        return WandLoadout.getTriggerGrid()
    end
    return nil
end

local function isWandPanelGrid(gridEntity)
    if not gridEntity then return false end
    local WandPanel = getWandPanel()
    if not WandPanel then return false end
    if WandPanel.getActionGrid and WandPanel.getActionGrid() == gridEntity then
        return true
    end
    if WandPanel.getTriggerGrid and WandPanel.getTriggerGrid() == gridEntity then
        return true
    end
    return false
end

local function isWandLoadoutGrid(gridEntity)
    if not gridEntity then return false end
    local WandLoadout = getWandLoadout()
    if not WandLoadout then return false end
    if WandLoadout.getActionGrid and WandLoadout.getActionGrid() == gridEntity then
        return true
    end
    if WandLoadout.getTriggerGrid and WandLoadout.getTriggerGrid() == gridEntity then
        return true
    end
    return false
end

--- Check if a grid belongs to the wand loadout/panel
local function isWandGrid(gridEntity)
    return isWandPanelGrid(gridEntity) or isWandLoadoutGrid(gridEntity)
end

--------------------------------------------------------------------------------
-- Card Type Detection
--------------------------------------------------------------------------------

--- Check if a card is a trigger card based on its data
local function isTriggerCard(cardEntity)
    local script = getScriptTableFromEntityID(cardEntity)
    if not script then return false end

    -- Check for trigger card indicators
    if script.cardType == "trigger" then return true end
    if script.isTrigger then return true end
    if script.category == "trigger" or script.category == "triggers" then return true end

    -- Check the card definition
    if script.cardID and WandEngine and WandEngine.trigger_card_defs then
        if WandEngine.trigger_card_defs[script.cardID] then
            return true
        end
    end

    return false
end

--- Map card entity to inventory tab category
local function getInventoryCategoryForCard(cardEntity)
    local script = getScriptTableFromEntityID(cardEntity)
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

--- Resolve the best inventory grid for a card (based on its category)
local function isInventoryOpen(PlayerInventory)
    return PlayerInventory and PlayerInventory.isOpen and PlayerInventory.isOpen()
end

local function getActiveInventoryGrid(PlayerInventory)
    if not PlayerInventory or not PlayerInventory.getActiveTab or not PlayerInventory.getGridForTab then
        return nil, nil
    end
    local activeTab = PlayerInventory.getActiveTab()
    if not activeTab then return nil, nil end
    local activeGrid = PlayerInventory.getGridForTab(activeTab)
    return activeGrid, activeTab
end

local function setCardVisible(cardEntity, visible)
    if not cardEntity or not registry:valid(cardEntity) then return end
    if visible then
        if add_state_tag then
            add_state_tag(cardEntity, "default_state")
        end
    else
        if clear_state_tags then
            clear_state_tags(cardEntity)
        end
    end
end

local function findAcceptingSlot(gridEntity, itemEntity)
    if not gridEntity then return nil end
    local capacity = grid.getCapacity and grid.getCapacity(gridEntity)
    if not capacity then
        local dims = grid.getDimensions and { grid.getDimensions(gridEntity) }
        if dims and dims[1] and dims[2] then
            capacity = dims[1] * dims[2]
        end
    end
    capacity = capacity or 0
    for slotIndex = 1, capacity do
        if not grid.getItemAtIndex(gridEntity, slotIndex) then
            if not grid.canSlotAccept or grid.canSlotAccept(gridEntity, slotIndex, itemEntity) then
                return slotIndex
            end
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- Core Equip Functions
--------------------------------------------------------------------------------

--- Attempt to equip a card to the first available wand slot.
-- @param cardEntity Entity ID of the card to equip
-- @return boolean success, string|nil reason
function QuickEquip.equipToWand(cardEntity)
    if not cardEntity or not registry:valid(cardEntity) then
        return false, "invalid_card"
    end

    -- Determine if this is a trigger card or action card
    local isTrigger = isTriggerCard(cardEntity)
    local targetGrid

    if isTrigger then
        targetGrid = getWandTriggerGrid()
        if not targetGrid then
            return false, "no_trigger_grid"
        end
    else
        targetGrid = getWandActionGrid()
        if not targetGrid then
            return false, "no_action_grid"
        end
    end

    -- Check if target grid has empty slots
    local targetSlot = nil
    if isTrigger then
        targetSlot = 1
        if grid.canSlotAccept and not grid.canSlotAccept(targetGrid, targetSlot, cardEntity) then
            return false, "filter_rejected"
        end
        local existing = grid.getItemAtIndex(targetGrid, targetSlot)
        if existing then
            -- Try to return existing trigger to inventory before equipping
            local returned, returnReason = QuickEquip.returnToInventory(existing)
            if not returned then
                log_debug("[QuickEquip] Cannot replace trigger - return failed: " .. tostring(returnReason))
                return false, returnReason or "target_slot_occupied"
            end
        end
    else
        targetSlot = findAcceptingSlot(targetGrid, cardEntity)
        if not targetSlot then
            local slotType = "action"
            log_debug("[QuickEquip] No empty " .. slotType .. " slots available")
            return false, "no_empty_slot"
        end
    end

    -- Use transfer module for atomic transfer
    local result = transfer.transferItemTo({
        item = cardEntity,
        toGrid = targetGrid,
        toSlot = targetSlot,
        onSuccess = function(res)
            log_debug("[QuickEquip] Successfully equipped card to slot " .. res.toSlot)
            signal.emit("quick_equip_success", cardEntity, targetGrid, res.toSlot)

            -- Center on target slot for visual consistency
            if InventoryGridInit and InventoryGridInit.centerItemOnSlot then
                local slotEntity = grid.getSlotEntity(targetGrid, res.toSlot)
                if slotEntity then
                    InventoryGridInit.centerItemOnSlot(cardEntity, slotEntity)
                end
            end

            -- Play success sound
            if playSoundEffect then
                playSoundEffect("effects", "button-click")
            end
        end,
        onFail = function(reason)
            log_debug("[QuickEquip] Failed to equip card: " .. tostring(reason))
            signal.emit("quick_equip_failed", cardEntity, reason)
        end,
    })

    return result.success, result.reason
end

--- Attempt to return a wand card back to inventory
-- @param cardEntity Entity ID of the card to return
-- @return boolean success, string|nil reason
function QuickEquip.returnToInventory(cardEntity)
    if not cardEntity or not registry:valid(cardEntity) then
        return false, "invalid_card"
    end

    local PlayerInventory = getPlayerInventory()
    if not PlayerInventory or not PlayerInventory.addCard then
        return false, "inventory_unavailable"
    end

    local inventoryOpen = isInventoryOpen(PlayerInventory)
    local activeGrid, activeTab = getActiveInventoryGrid(PlayerInventory)
    local category = getInventoryCategoryForCard(cardEntity)

    -- Prefer visible active grid if inventory is open and has space
    if inventoryOpen and activeGrid then
        local activeSlot = findAcceptingSlot(activeGrid, cardEntity)
        if activeSlot then
            local result = transfer.transferItemTo({
                item = cardEntity,
                toGrid = activeGrid,
                toSlot = activeSlot,
                onSuccess = function(res)
                    log_debug("[QuickEquip] Returned card to active inventory slot " .. res.toSlot)

                    if InventoryGridInit and InventoryGridInit.centerItemOnSlot then
                        local slotEntity = grid.getSlotEntity(activeGrid, res.toSlot)
                        if slotEntity then
                            InventoryGridInit.centerItemOnSlot(cardEntity, slotEntity)
                        end
                    end

                    setCardVisible(cardEntity, true)

                    if playSoundEffect then
                        playSoundEffect("effects", "button-click")
                    end
                end,
                onFail = function(reason)
                    log_debug("[QuickEquip] Failed to return to active grid: " .. tostring(reason))
                end,
            })

            return result.success, result.reason
        end
    end

    -- Try category grid if it's currently injected and has space
    local categoryGrid = PlayerInventory.getGridForTab and PlayerInventory.getGridForTab(category)
    if categoryGrid then
        local categorySlot = findAcceptingSlot(categoryGrid, cardEntity)
        if categorySlot then
            local result = transfer.transferItemTo({
                item = cardEntity,
                toGrid = categoryGrid,
                toSlot = categorySlot,
                onSuccess = function(res)
                    log_debug("[QuickEquip] Returned card to inventory slot " .. res.toSlot)

                    if InventoryGridInit and InventoryGridInit.centerItemOnSlot then
                        local slotEntity = grid.getSlotEntity(categoryGrid, res.toSlot)
                        if slotEntity then
                            InventoryGridInit.centerItemOnSlot(cardEntity, slotEntity)
                        end
                    end

                    setCardVisible(cardEntity, inventoryOpen and activeTab == category)

                    if playSoundEffect then
                        playSoundEffect("effects", "button-click")
                    end
                end,
                onFail = function(reason)
                    log_debug("[QuickEquip] Failed to return card: " .. tostring(reason))
                end,
            })

            return result.success, result.reason
        end
    end

    -- Fallback: remove from wand grid and add to inventory storage
    local location = itemRegistry.getLocation(cardEntity)
    local removed = false
    if location and location.grid and location.slot then
        removed = grid.removeItem(location.grid, location.slot) ~= nil
    end

    if not removed then
        return false, "source_removal_failed"
    end

    local targetTab = inventoryOpen and activeTab or category
    local added = PlayerInventory.addCard(cardEntity, targetTab)
    if added then
        -- If we added to active tab while open, it should already be visible.
        if not (inventoryOpen and activeTab == targetTab) then
            setCardVisible(cardEntity, false)
        end
        return true, nil
    end

    -- Attempt to restore to original slot if inventory add failed
    if location and location.grid and location.slot then
        grid.addItem(location.grid, cardEntity, location.slot)
        if InventoryGridInit and InventoryGridInit.centerItemOnSlot then
            local slotEntity = grid.getSlotEntity(location.grid, location.slot)
            if slotEntity then
                InventoryGridInit.centerItemOnSlot(cardEntity, slotEntity)
            end
        end
    end

    return false, "inventory_full"
end

--- Show feedback message when equip fails
local function showEquipFeedback(cardEntity, reason)
    local message

    if reason == "no_empty_slot" then
        message = "No empty wand slots!"
    elseif reason == "no_action_grid" or reason == "no_trigger_grid" then
        message = "Wand loadout not available"
    elseif reason == "filter_rejected" then
        message = "Card type not accepted"
    else
        message = "Cannot equip card"
    end

    -- Play error sound
    if playSoundEffect then
        playSoundEffect("effects", "error_buzz", 0.8)
    end

    -- Show popup text above the card if possible
    local popup = require("core.popup")
    if popup and popup.above and cardEntity and registry:valid(cardEntity) then
        popup.above(cardEntity, message, { color = "red" })
    end

    log_debug("[QuickEquip] Feedback: " .. message)
end

--- Show feedback message when return fails
local function showReturnFeedback(cardEntity, reason)
    local message

    if reason == "no_empty_slot" or reason == "inventory_full" then
        message = "Inventory is full!"
    elseif reason == "inventory_unavailable" then
        message = "Inventory not available"
    elseif reason == "source_removal_failed" then
        message = "Couldn't remove card"
    else
        message = "Cannot return card"
    end

    if playSoundEffect then
        playSoundEffect("effects", "error_buzz", 0.8)
    end

    local popup = require("core.popup")
    if popup and popup.above and cardEntity and registry:valid(cardEntity) then
        popup.above(cardEntity, message, { color = "red" })
    end

    log_debug("[QuickEquip] Return feedback: " .. message)
end

--------------------------------------------------------------------------------
-- Right-Click Detection
--------------------------------------------------------------------------------

local hoveredCard = nil
local hoveredLocation = nil
local hoveredSource = nil

local function getRenderFrame()
    if main_loop and main_loop.data and main_loop.data.renderFrame then
        return main_loop.data.renderFrame
    end
    if globals and globals.frameCount then
        return globals.frameCount
    end
    return nil
end

local function handleRightClick(cardEntity)
    if not cardEntity or not registry:valid(cardEntity) then
        return
    end

    local success, reason = QuickEquip.equipToWand(cardEntity)
    if not success then
        showEquipFeedback(cardEntity, reason)
    end

    local frame = getRenderFrame()
    if frame then
        state.lastHandledFrame = frame
    end
end

local function resolveHoveredCard(inputState)
    if not inputState then return nil, nil end

    local hovered = inputState.cursor_hovering_target
    if not (hovered and registry:valid(hovered)) then
        hovered = inputState.current_designated_hover_target
    end
    if not (hovered and registry:valid(hovered)) then
        return nil, nil
    end

    local location = itemRegistry.getLocation(hovered)
    if location then
        return hovered, location
    end

    if InventoryGridInit and InventoryGridInit.getSlotMetadata then
        local meta = InventoryGridInit.getSlotMetadata(hovered)
        if meta and meta.parentGrid and meta.slotIndex then
            local item = grid.getItemAtIndex(meta.parentGrid, meta.slotIndex)
            if item and registry:valid(item) then
                return item, itemRegistry.getLocation(item)
            end
        end
    end

    return nil, nil
end

--- Update hover tracking for right-click detection
local function updateHoverTracking()
    -- Get current hovered entity from input system
    local inputState = input and input.getState and input.getState()
    if not inputState and globals then
        inputState = globals.inputState
    end
    local currentHovered, location = resolveHoveredCard(inputState)

    if currentHovered and registry:valid(currentHovered) and location and location.grid then
        if isPlayerInventoryGrid(location.grid) then
            hoveredCard = currentHovered
            hoveredLocation = location
            hoveredSource = "inventory"
        elseif isWandPanelGrid(location.grid) then
            hoveredCard = currentHovered
            hoveredLocation = location
            hoveredSource = "wand_panel"
        elseif isWandLoadoutGrid(location.grid) then
            hoveredCard = currentHovered
            hoveredLocation = location
            hoveredSource = "wand_loadout"
        else
            hoveredCard = nil
            hoveredLocation = nil
            hoveredSource = nil
        end
    else
        hoveredCard = nil
        hoveredLocation = nil
        hoveredSource = nil
    end
end

--- Check for right-click on hovered card
local function checkRightClick()
    local frame = getRenderFrame()
    if frame and state.lastHandledFrame == frame then
        return
    end

    if not hoveredCard then return end
    if not registry:valid(hoveredCard) then
        hoveredCard = nil
        hoveredLocation = nil
        hoveredSource = nil
        return
    end

    -- Check for right-click (Raylib detection)
    local rightClick = input and input.isMousePressed and input.isMousePressed(MouseButton.MOUSE_BUTTON_RIGHT)

    -- Also support Alt+Left-click as alternative
    local altHeld = input and input.isKeyDown and (
        input.isKeyDown(KeyboardKey.KEY_LEFT_ALT) or
        input.isKeyDown(KeyboardKey.KEY_RIGHT_ALT)
    )
    local leftClick = input and input.isMousePressed and input.isMousePressed(MouseButton.MOUSE_BUTTON_LEFT)
    local altClick = altHeld and leftClick

    -- Ctrl+Left-click or Cmd+Left-click for Mac support
    -- (macOS uses Ctrl+Click as right-click alternative, Cmd+Click is also common)
    local ctrlHeld = input and input.isKeyDown and (
        input.isKeyDown(KeyboardKey.KEY_LEFT_CONTROL) or
        input.isKeyDown(KeyboardKey.KEY_RIGHT_CONTROL)
    )
    local cmdHeld = input and input.isKeyDown and (
        input.isKeyDown(KeyboardKey.KEY_LEFT_SUPER) or
        input.isKeyDown(KeyboardKey.KEY_RIGHT_SUPER)
    )
    local ctrlClick = ctrlHeld and leftClick
    local cmdClick = cmdHeld and leftClick

    -- Debug: log when any modifier is detected with a click
    if leftClick and (ctrlHeld or cmdHeld or altHeld) then
        log_debug("[QuickEquip] Modifier+click: ctrl=" .. tostring(ctrlHeld) .. " cmd=" .. tostring(cmdHeld) .. " alt=" .. tostring(altHeld))
    end
    if rightClick then
        log_debug("[QuickEquip] Native right-click detected")
    end

    if rightClick or altClick or ctrlClick or cmdClick then
        if hoveredSource == "inventory" then
            log_debug("[QuickEquip] Quick equip from inventory: " .. tostring(hoveredCard))
            handleRightClick(hoveredCard)
        elseif hoveredSource == "wand_panel" then
            -- WandPanel handles native right-click via onSlotClick; only handle modifier+left-click.
            if altClick or ctrlClick or cmdClick then
                log_debug("[QuickEquip] Quick return from wand panel: " .. tostring(hoveredCard))
                local success, reason = QuickEquip.returnToInventory(hoveredCard)
                if not success then
                    showReturnFeedback(hoveredCard, reason)
                end
                local frame = getRenderFrame()
                if frame then
                    state.lastHandledFrame = frame
                end
            end
        elseif hoveredSource == "wand_loadout" then
            log_debug("[QuickEquip] Quick return from wand loadout: " .. tostring(hoveredCard))
            local success, reason = QuickEquip.returnToInventory(hoveredCard)
            if not success then
                showReturnFeedback(hoveredCard, reason)
            end
            local frame = getRenderFrame()
            if frame then
                state.lastHandledFrame = frame
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Update Loop
--------------------------------------------------------------------------------

--- Call this every frame to handle right-click equip
function QuickEquip.update()
    updateHoverTracking()
    checkRightClick()
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

--- Initialize the quick equip system
function QuickEquip.init()
    if state.initialized then return end

    state.lastHandledFrame = nil
    state.signalHandlers.gridSlotClicked = function(gridEntity, slotIndex, button)
        if button ~= "right" then return end
        local item = grid.getItemAtIndex(gridEntity, slotIndex)
        if not (item and registry:valid(item)) then return end

        if isPlayerInventoryGrid(gridEntity) then
            handleRightClick(item)
            return
        end

        if isWandLoadoutGrid(gridEntity) then
            local success, reason = QuickEquip.returnToInventory(item)
            if not success then
                showReturnFeedback(item, reason)
            end
            local frame = getRenderFrame()
            if frame then
                state.lastHandledFrame = frame
            end
        end
    end
    signal.register("grid_slot_clicked", state.signalHandlers.gridSlotClicked)

    -- Setup per-frame update timer
    timer.run_every_render_frame(function()
        QuickEquip.update()
    end, nil, "quick_equip_update", TIMER_GROUP)

    state.initialized = true
    log_debug("[QuickEquip] Initialized")
end

--- Cleanup
function QuickEquip.destroy()
    timer.kill_group(TIMER_GROUP)
    if state.signalHandlers.gridSlotClicked then
        signal.remove("grid_slot_clicked", state.signalHandlers.gridSlotClicked)
        state.signalHandlers.gridSlotClicked = nil
    end
    state.lastHandledFrame = nil
    state.initialized = false
    state.playerInventoryModule = nil
    state.wandLoadoutModule = nil
    state.wandPanelModule = nil
    hoveredCard = nil
    hoveredLocation = nil
    hoveredSource = nil
    log_debug("[QuickEquip] Destroyed")
end

--- Check if initialized
function QuickEquip.isInitialized()
    return state.initialized
end

--------------------------------------------------------------------------------
-- Module Load
--------------------------------------------------------------------------------

log_debug("[QuickEquip] Module loaded")

return QuickEquip
