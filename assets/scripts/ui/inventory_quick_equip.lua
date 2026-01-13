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
    local WandLoadout = getWandLoadout()
    if WandLoadout and WandLoadout.getActionGrid then
        return WandLoadout.getActionGrid()
    end
    return nil
end

--- Get wand trigger grid
local function getWandTriggerGrid()
    local WandLoadout = getWandLoadout()
    if WandLoadout and WandLoadout.getTriggerGrid then
        return WandLoadout.getTriggerGrid()
    end
    return nil
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
    local emptySlot = grid.findEmptySlot(targetGrid)
    if not emptySlot then
        local slotType = isTrigger and "trigger" or "action"
        log_debug("[QuickEquip] No empty " .. slotType .. " slots available")
        return false, "no_empty_slot"
    end

    -- Use transfer module for atomic transfer
    local result = transfer.transferItemTo({
        item = cardEntity,
        toGrid = targetGrid,
        toSlot = emptySlot,
        onSuccess = function(res)
            log_debug("[QuickEquip] Successfully equipped card to slot " .. res.toSlot)
            signal.emit("quick_equip_success", cardEntity, targetGrid, res.toSlot)

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

--------------------------------------------------------------------------------
-- Right-Click Detection
--------------------------------------------------------------------------------

local hoveredCard = nil

--- Update hover tracking for right-click detection
local function updateHoverTracking()
    -- Get current hovered entity from input system
    local inputState = input and input.getState and input.getState()
    local currentHovered = inputState and inputState.cursor_over_target

    -- Only track if it's a card in player inventory
    if currentHovered and registry:valid(currentHovered) then
        local location = itemRegistry.getLocation(currentHovered)
        if location and location.grid and isPlayerInventoryGrid(location.grid) then
            hoveredCard = currentHovered
        else
            hoveredCard = nil
        end
    else
        hoveredCard = nil
    end
end

--- Check for right-click on hovered card
local function checkRightClick()
    if not hoveredCard then return end
    if not registry:valid(hoveredCard) then
        hoveredCard = nil
        return
    end

    -- Check for right-click
    local rightClick = input and input.isMousePressed and input.isMousePressed(MouseButton.MOUSE_BUTTON_RIGHT)

    -- Also support Alt+Left-click as alternative
    local altHeld = input and input.isKeyDown and (
        input.isKeyDown(KeyboardKey.KEY_LEFT_ALT) or
        input.isKeyDown(KeyboardKey.KEY_RIGHT_ALT)
    )
    local altClick = altHeld and input.isMousePressed(MouseButton.MOUSE_BUTTON_LEFT)

    if rightClick or altClick then
        log_debug("[QuickEquip] Right-click detected on card: " .. tostring(hoveredCard))

        local success, reason = QuickEquip.equipToWand(hoveredCard)
        if not success then
            showEquipFeedback(hoveredCard, reason)
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
    state.initialized = false
    state.playerInventoryModule = nil
    state.wandLoadoutModule = nil
    hoveredCard = nil
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
