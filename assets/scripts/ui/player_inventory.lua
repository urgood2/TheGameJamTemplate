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

local dsl = require("ui.ui_syntax_sugar")
local grid = require("core.inventory_grid")
local signal = require("external.hump.signal")
local component_cache = require("core.component_cache")
local timer = require("core.timer")
local InventoryGridInit = require("ui.inventory_grid_init")

local TIMER_GROUP = "player_inventory"
local PANEL_ID = "player_inventory_panel"

local TAB_CONFIG = {
    equipment = {
        id = "inv_equipment",
        label = "Equipment",
        icon = "E",
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

local state = {
    isOpen = false,
    panelEntity = nil,
    grids = {},
    tabButtons = {},
    activeTab = "actions",
    searchFilter = "",
    sortField = nil,
    sortAsc = true,
    lockedCards = {},
    cardRegistry = {},
    signalHandlers = {},
    panelX = nil,
    panelY = nil,
    gridX = nil,
    gridY = nil,
}

local function getLocalizedText(key, fallback)
    if localization and localization.get then
        local text = localization.get(key)
        if text and text ~= key then
            return text
        end
    end
    return fallback or key
end

local SLOT_WIDTH = 48
local SLOT_HEIGHT = 48
local SLOT_SPACING = 4
local PANEL_WIDTH = 400
local PANEL_HEIGHT = 280

local function createGridForTab(tabId, x, y, visible)
    local cfg = TAB_CONFIG[tabId]
    if not cfg then return nil end
    
    local spawnX = visible and x or -9999
    
    local gridDef = dsl.inventoryGrid {
        id = cfg.id,
        rows = cfg.rows,
        cols = cfg.cols,
        slotSize = { w = SLOT_WIDTH, h = SLOT_HEIGHT },
        slotSpacing = SLOT_SPACING,
        
        config = {
            allowDragIn = true,
            allowDragOut = true,
            stackable = false,
            slotSprite = "test-inventory-square-single.png",
            padding = 4,
            backgroundColor = "blackberry",
        },
        
        onSlotChange = function(gridEntity, slotIndex, oldItem, newItem)
            log_debug("[PlayerInventory:" .. tabId .. "] Slot " .. slotIndex .. " changed")
        end,
        
        onSlotClick = function(gridEntity, slotIndex, button)
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
    
    for id, gridEntity in pairs(state.grids) do
        local isActive = (id == tabId)
        setGridVisible(gridEntity, isActive, state.gridX)
    end
    
    for id, btnEntity in pairs(state.tabButtons or {}) do
        if btnEntity and registry:valid(btnEntity) then
            local isActive = (id == tabId)
            local uiCfg = component_cache.get(btnEntity, UIConfig)
            if uiCfg and _G.util and _G.util.getColor then
                uiCfg.color = isActive and _G.util.getColor("steel_blue") or _G.util.getColor("gray")
            end
        end
    end
    
    log_debug("[PlayerInventory] Switched tab: " .. oldTab .. " -> " .. tabId)
end

local function createHeader()
    return dsl.hbox {
        config = {
            color = "dark_lavender",
            padding = { 12, 8 },
            emboss = 2,
        },
        children = {
            dsl.text("Inventory", {
                fontSize = 18,
                color = "gold",
                shadow = true,
            }),
            dsl.spacer(1),
            dsl.button("X", {
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
        local label = cfg.icon .. " " .. cfg.label
        
        table.insert(tabChildren, dsl.button(label, {
            id = "tab_" .. tabId,
            minWidth = 80,
            minHeight = 28,
            fontSize = 10,
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
            dsl.button("Name v", {
                id = "sort_name_btn",
                minWidth = 50,
                minHeight = 22,
                fontSize = 10,
                color = "purple_slate",
                hover = true,
                onClick = function()
                    log_debug("[PlayerInventory] Sort by name clicked")
                end,
            }),
            dsl.spacer(4),
            dsl.button("Cost v", {
                id = "sort_cost_btn",
                minWidth = 50,
                minHeight = 22,
                fontSize = 10,
                color = "purple_slate",
                hover = true,
                onClick = function()
                    log_debug("[PlayerInventory] Sort by cost clicked")
                end,
            }),
            dsl.spacer(1),
            dsl.text("0 / 21", { fontSize = 10, color = "light_gray" }),
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
            minWidth = PANEL_WIDTH,
            maxWidth = PANEL_WIDTH,
            minHeight = PANEL_HEIGHT,
            maxHeight = PANEL_HEIGHT,
        },
        children = {
            createHeader(),
            createTabs(),
            dsl.vbox {
                config = {
                    padding = 4,
                    minHeight = 180,
                    color = "blackberry",
                },
                children = {
                    dsl.text("", { fontSize = 1 }),
                },
            },
            createFooter(),
        },
    }
end

function PlayerInventory.open()
    if state.isOpen then return end
    
    local screenW = globals.screenWidth()
    local screenH = globals.screenHeight()
    
    state.panelX = (screenW - PANEL_WIDTH) / 2
    state.panelY = screenH - PANEL_HEIGHT - 20
    state.gridX = state.panelX + 10
    state.gridY = state.panelY + 70
    
    local panelDef = createPanelDefinition()
    state.panelEntity = dsl.spawn({ x = state.panelX, y = state.panelY }, panelDef, "ui", 100)
    
    if ui and ui.box and ui.box.set_draw_layer then
        ui.box.set_draw_layer(state.panelEntity, "ui")
    end
    
    state.tabButtons = {}
    for _, tabId in ipairs(TAB_ORDER) do
        local btnEntity = ui.box.GetUIEByID(registry, state.panelEntity, "tab_" .. tabId)
        if btnEntity then
            state.tabButtons[tabId] = btnEntity
        end
    end
    
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
    
    timer.kill_group(TIMER_GROUP)
    
    for tabId, gridEntity in pairs(state.grids) do
        if gridEntity and registry:valid(gridEntity) then
            local cfg = TAB_CONFIG[tabId]
            if cfg then
                local capacity = grid.getCapacity(gridEntity) or 21
                for i = 1, capacity do
                    local slotEntity = grid.getSlotEntity(gridEntity, i)
                    if slotEntity then
                        InventoryGridInit.cleanupSlotMetadata(slotEntity)
                    end
                end
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
    log_debug("[PlayerInventory] addCard() called - Phase 3")
    return false
end

function PlayerInventory.removeCard(cardEntity)
    log_debug("[PlayerInventory] removeCard() called - Phase 3")
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

function PlayerInventory.spawnDummyCards()
    if not state.isOpen then
        log_warn("[PlayerInventory] spawnDummyCards: inventory not open")
        return
    end
    
    local activeGrid = state.grids[state.activeTab]
    if not activeGrid then
        log_warn("[PlayerInventory] spawnDummyCards: no active grid")
        return
    end
    
    local testCardIds = { "ACTION_CHAIN_LIGHTNING", "TEST_PROJECTILE", "TEST_DAMAGE_BOOST" }
    local CardSpaceConverter = require("ui.card_space_converter")
    
    for i, cardId in ipairs(testCardIds) do
        if createNewCard then
            local card = createNewCard(cardId, -9999, -9999, nil)
            if card and registry:valid(card) then
                CardSpaceConverter.toScreenSpace(card)
                
                local go = component_cache.get(card, GameObject)
                if go then
                    go.state.dragEnabled = true
                    go.state.collisionEnabled = true
                    go.state.hoverEnabled = true
                end
                
                local success, slotIndex = grid.addItem(activeGrid, card)
                if success then
                    local slotEntity = grid.getSlotEntity(activeGrid, slotIndex)
                    if slotEntity then
                        InventoryGridInit.centerItemOnSlot(card, slotEntity)
                    end
                    log_debug("[PlayerInventory] Added test card " .. cardId .. " to slot " .. slotIndex)
                else
                    log_warn("[PlayerInventory] Failed to add test card " .. cardId)
                end
            end
        else
            log_warn("[PlayerInventory] createNewCard not available")
        end
    end
end

log_debug("[PlayerInventory] Module loaded")

return PlayerInventory
