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

-- Grid configuration: 7 columns x 3 rows = 21 slots per tab
local TAB_CONFIG = {
    equipment = {
        id = "inv_equipment",
        label = "Equipment",
        icon = "E",  -- Using letter instead of emoji for compatibility
        rows = 3,
        cols = 7,
    },
    wands = {
        id = "inv_wands",
        label = "Wands",
        icon = "W",
        rows = 3,
        cols = 7,
    },
    triggers = {
        id = "inv_triggers",
        label = "Triggers",
        icon = "T",
        rows = 3,
        cols = 7,
    },
    actions = {
        id = "inv_actions",
        label = "Actions",
        icon = "A",
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
    tabButtons = {},            -- { [tabId] = buttonEntity }
    activeTab = "actions",      -- Default to actions tab
    searchFilter = "",
    sortField = nil,            -- "name" | "cost" | nil
    sortAsc = true,
    lockedCards = {},           -- Set of locked card entity IDs
    cardRegistry = {},          -- { [entityId] = cardData }
    signalHandlers = {},
    panelX = nil,
    panelY = nil,
    gridX = nil,
    gridY = nil,
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
    log_debug("[PlayerInventory] open() called - Phase 1 stub")
    state.isOpen = true
    signal.emit("player_inventory_opened")
end

function PlayerInventory.close()
    log_debug("[PlayerInventory] close() called - Phase 1 stub")
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
    log_debug("[PlayerInventory] addCard() called - Phase 1 stub")
    return false
end

function PlayerInventory.removeCard(cardEntity)
    log_debug("[PlayerInventory] removeCard() called - Phase 1 stub")
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
