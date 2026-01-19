--[[
================================================================================
CARD INVENTORY PANEL - UI-Based Card Management
================================================================================

A tabbed inventory panel for organizing cards across 4 categories:
- Equipment
- Wands
- Trigger Cards
- Action/Modifier Cards

Features:
- Drag-drop between slots (within same tab)
- Hover tooltips with card details
- Sort by name or cost
- Search/filter cards
- Lock cards to prevent accidental moves

Based on: docs/ui-specs/card-inventory-grid.md

USAGE:
------
local CardInventoryPanel = require("ui.card_inventory_panel")

-- Open the panel
CardInventoryPanel.open()

-- Close the panel
CardInventoryPanel.close()

-- Toggle visibility
CardInventoryPanel.toggle()

-- Add a card to a category
CardInventoryPanel.addCard(cardEntity, "wands")

-- Remove a card
CardInventoryPanel.removeCard(cardEntity)

EVENTS (via hump.signal):
-------------------------
signal.register("inventory_opened", function() end)
signal.register("inventory_closed", function() end)
signal.register("card_moved", function(cardEntity, fromSlot, toSlot) end)
signal.register("card_locked", function(cardEntity) end)
signal.register("card_unlocked", function(cardEntity) end)

================================================================================
]]

local CardInventoryPanel = {}

--------------------------------------------------------------------------------
-- Dependencies
--------------------------------------------------------------------------------

local dsl = require("ui.ui_syntax_sugar")
local grid = require("core.inventory_grid")
local signal = require("external.hump.signal")
local component_cache = require("core.component_cache")
local timer = require("core.timer")
local InventoryGridInit = require("ui.inventory_grid_init")
local shader_pipeline = _G.shader_pipeline

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local TIMER_GROUP = "card_inventory_panel"
local PANEL_ID = "card_inventory_panel"

local TAB_CONFIG = {
    equipment = {
        id = "inv_equipment",
        icon = "⚔️",
        rows = 3,
        cols = 5,
    },
    wands = {
        id = "inv_wands",
        icon = "🪄",
        rows = 3,
        cols = 5,
    },
    triggers = {
        id = "inv_triggers",
        icon = "⚡",
        rows = 3,
        cols = 5,
    },
    actions = {
        id = "inv_actions",
        icon = "🎴",
        rows = 3,
        cols = 5,
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
    activeTab = "equipment",
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

local function getCardData(entity)
    if state.cardRegistry[entity] then
        return state.cardRegistry[entity]
    end
    if getScriptTableFromEntityID then
        local script = getScriptTableFromEntityID(entity)
        if script then
            return script
        end
    end
    return nil
end

local function isCardLocked(entity)
    return state.lockedCards[entity] == true
end

local function setCardLocked(entity, locked)
    state.lockedCards[entity] = locked or nil
    if locked then
        signal.emit("card_locked", entity)
    else
        signal.emit("card_unlocked", entity)
    end
end

local function toggleCardLock(entity)
    setCardLocked(entity, not isCardLocked(entity))
end

--------------------------------------------------------------------------------
-- Grid Creation
--------------------------------------------------------------------------------

local function createGridForTab(tabId, x, y, visible)
    local cfg = TAB_CONFIG[tabId]
    if not cfg then return nil end
    
    local spawnX = visible and x or -9999
    
    local gridDef = dsl.strict.inventoryGrid {
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
            if oldItem and newItem then
                signal.emit("card_moved", newItem, slotIndex, slotIndex)
            end
        end,
        
        onSlotClick = function(gridEntity, slotIndex, button)
            -- Right-click to toggle lock
            if button == 2 then -- Right mouse button
                local item = grid.getItemAt(gridEntity, slotIndex)
                if item and registry:valid(item) then
                    if not isCardLocked(item) then
                        toggleCardLock(item)
                    else
                        toggleCardLock(item)
                    end
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
        log_debug("[CardInventoryPanel] Grid '" .. tabId .. "' initialized")
    else
        log_warn("[CardInventoryPanel] Grid '" .. tabId .. "' init failed!")
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
        setGridVisible(gridEntity, isActive, state.panelX + 10)
    end
    
    log_debug("[CardInventoryPanel] Switched tab: " .. oldTab .. " -> " .. tabId)
end

--------------------------------------------------------------------------------
-- Sorting
--------------------------------------------------------------------------------

local function applySorting()
    local activeGrid = state.grids[state.activeTab]
    if not state.sortField or not activeGrid then return end
    
    local cfg = TAB_CONFIG[state.activeTab]
    local maxSlots = cfg.rows * cfg.cols
    
    local items = grid.getItemList(activeGrid)
    if not items or #items == 0 then return end
    
    -- Collect items with their data
    local itemsWithData = {}
    for _, itemEntry in ipairs(items) do
        local entity = itemEntry.item
        if not isCardLocked(entity) then
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
            local existingItem = grid.getItemAt(activeGrid, targetSlot)
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
    
    log_debug("[CardInventoryPanel] Sorted by " .. sortKey)
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

--------------------------------------------------------------------------------
-- Filtering
--------------------------------------------------------------------------------

local function applyFilter(searchText)
    state.searchFilter = searchText or ""
    -- TODO: Hide/show cards based on filter
    -- For now, filtering is visual only via future implementation
    log_debug("[CardInventoryPanel] Filter: " .. state.searchFilter)
end

--------------------------------------------------------------------------------
-- Panel UI Creation
--------------------------------------------------------------------------------

local function createHeader()
    return dsl.strict.hbox {
        config = {
            color = "dark_lavender",
            padding = 12,  -- Changed from {12, 8} - DSL expects single number
            emboss = 2,
        },
        children = {
            dsl.strict.text(getLocalizedText("ui.inventory.title", "Card Inventory"), {
                fontSize = 18,
                color = "gold",
                shadow = true,
            }),
            dsl.strict.spacer(1), -- flex spacer
            dsl.strict.button("✕", {
                id = "close_btn",
                minWidth = 28,
                minHeight = 28,
                fontSize = 16,
                color = "darkred",
                onClick = function()
                    CardInventoryPanel.close()
                end,
            }),
        },
    }
end

local function createFilterBar()
    return dsl.strict.hbox {
        config = {
            color = "blackberry",
            padding = 8,
        },
        children = {
            -- Search input placeholder (simplified as text for now)
            dsl.strict.text("🔍", { fontSize = 14, color = "gray" }),
            dsl.strict.spacer(8),
            -- Sort buttons
            dsl.strict.button(getLocalizedText("ui.inventory.sort_name", "Name") .. " ↕", {
                id = "sort_name_btn",
                minWidth = 60,
                minHeight = 24,
                fontSize = 11,
                color = "purple_slate",
                onClick = function()
                    toggleSort("name")
                end,
            }),
            dsl.strict.spacer(4),
            dsl.strict.button(getLocalizedText("ui.inventory.sort_cost", "Cost") .. " ↕", {
                id = "sort_cost_btn",
                minWidth = 60,
                minHeight = 24,
                fontSize = 11,
                color = "purple_slate",
                onClick = function()
                    toggleSort("cost")
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
        local labelKey = "ui.inventory.tab_" .. tabId
        local label = cfg.icon .. " " .. getLocalizedText(labelKey, tabId:gsub("^%l", string.upper))
        
        table.insert(tabChildren, dsl.strict.button(label, {
            id = "tab_" .. tabId,
            minWidth = 90,
            minHeight = 32,
            fontSize = 11,
            color = isActive and "steel_blue" or "gray",
            onClick = function()
                switchTab(tabId)
            end,
        }))
        
        if tabId ~= TAB_ORDER[#TAB_ORDER] then
            table.insert(tabChildren, dsl.strict.spacer(2))
        end
    end
    
    return dsl.strict.hbox {
        config = {
            color = "blackberry",
            padding = 4,
        },
        children = tabChildren,
    }
end

local function createFooter()
    return dsl.strict.hbox {
        config = {
            color = "dark_lavender",
            padding = 8,
        },
        children = {
            dsl.strict.dynamicText(function()
                local activeGrid = state.grids[state.activeTab]
                if activeGrid then
                    local used = grid.getUsedSlotCount(activeGrid) or 0
                    local total = grid.getCapacity(activeGrid) or 15
                    return used .. " / " .. total .. " slots"
                end
                return "0 / 15 slots"
            end, 11, nil, { color = "light_gray" }),
            dsl.strict.spacer(1),
            dsl.strict.button(getLocalizedText("ui.inventory.sort_all", "Sort All"), {
                id = "sort_all_btn",
                minWidth = 70,
                minHeight = 24,
                fontSize = 11,
                color = "jade_green",
                onClick = function()
                    if not state.sortField then
                        state.sortField = "name"
                    end
                    applySorting()
                end,
            }),
        },
    }
end

local function createPanelDefinition()
    return dsl.strict.root {
        config = {
            id = PANEL_ID,
            color = "blackberry",
            padding = 0,
            emboss = 3,
            minWidth = 420,
        },
        children = {
            createHeader(),
            createFilterBar(),
            createTabs(),
            -- Grid content area (placeholder - actual grids are separate entities)
            dsl.strict.vbox {
                config = {
                    padding = 8,
                    minHeight = 300,
                    color = "blackberry",
                },
                children = {
                    dsl.strict.text("", { fontSize = 1 }), -- Invisible placeholder
                },
            },
            createFooter(),
        },
    }
end

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
            log_debug("[CardInventoryPanel] Card added to slot " .. slotIndex)
        end
    end)
    
    registerHandler("grid_item_removed", function(gridEntity, slotIndex, itemEntity)
        if isOurGrid(gridEntity) then
            log_debug("[CardInventoryPanel] Card removed from slot " .. slotIndex)
        end
    end)
    
    registerHandler("grid_item_moved", function(gridEntity, fromSlot, toSlot, itemEntity)
        if isOurGrid(gridEntity) then
            signal.emit("card_moved", itemEntity, fromSlot, toSlot)
            log_debug("[CardInventoryPanel] Card moved: " .. fromSlot .. " -> " .. toSlot)
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

--------------------------------------------------------------------------------
-- Card Rendering Timer
--------------------------------------------------------------------------------

local function setupCardRenderTimer()
    local UI_CARD_Z = (z_orders and z_orders.ui_tooltips or 900) - 100
    
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
        
        -- Batch render cards
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
            command_buffer.queueDrawBatchedEntities(layers.ui, function(cmd)
                cmd.registry = registry
                cmd.entities = cardList
                cmd.autoOptimize = true
            end, z, layer.DrawCommandSpace.Screen)
        end
    end, nil, "card_inventory_render", TIMER_GROUP)
end

--------------------------------------------------------------------------------
-- Keyboard Handler
--------------------------------------------------------------------------------

local function setupKeyboardHandler()
    timer.every_opts({
        delay = 0.05,
        tag = "inventory_keyboard",
        group = TIMER_GROUP,
        action = function()
            if isKeyPressed and isKeyPressed("KEY_I") then
                CardInventoryPanel.toggle()
            end
            
            if state.isOpen and isKeyPressed and isKeyPressed("KEY_ESCAPE") then
                CardInventoryPanel.close()
            end
        end,
    })
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Open the inventory panel
function CardInventoryPanel.open()
    if state.isOpen then return end
    
    local screenW = globals.screenWidth()
    local screenH = globals.screenHeight()
    
    state.panelX = screenW - 450
    state.panelY = 80
    
    -- Create main panel UI
    local panelDef = createPanelDefinition()
    state.panelEntity = dsl.spawn({ x = state.panelX, y = state.panelY }, panelDef, "ui", 100)
    
    if ui and ui.box and ui.box.set_draw_layer then
        ui.box.set_draw_layer(state.panelEntity, "ui")
    end
    
    -- Create grids for each tab
    local gridY = state.panelY + 120 -- Below header/tabs
    for _, tabId in ipairs(TAB_ORDER) do
        local visible = (tabId == state.activeTab)
        local gridEntity = createGridForTab(tabId, state.panelX + 10, gridY, visible)
        state.grids[tabId] = gridEntity
    end
    
    -- Setup handlers
    setupSignalHandlers()
    setupCardRenderTimer()
    setupKeyboardHandler()
    
    state.isOpen = true
    signal.emit("inventory_opened")
    
    if playSoundEffect then
        playSoundEffect("effects", "button-click")
    end
    
    log_debug("[CardInventoryPanel] Opened successfully")
end

--- Close the inventory panel
function CardInventoryPanel.close()
    if not state.isOpen then return end
    
    log_debug("[CardInventoryPanel] Closing...")
    
    -- Cleanup signal handlers
    cleanupSignalHandlers()
    
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
    
    -- Destroy panel
    if state.panelEntity and registry:valid(state.panelEntity) then
        if ui and ui.box and ui.box.Remove then
            ui.box.Remove(registry, state.panelEntity)
        end
    end
    state.panelEntity = nil
    
    state.isOpen = false
    signal.emit("inventory_closed")
    
    log_debug("[CardInventoryPanel] Closed")
end

--- Toggle panel visibility
function CardInventoryPanel.toggle()
    if state.isOpen then
        CardInventoryPanel.close()
    else
        CardInventoryPanel.open()
    end
end

--- Check if panel is open
--- @return boolean
function CardInventoryPanel.isOpen()
    return state.isOpen
end

--- Add a card to a specific category
--- @param cardEntity number Entity ID of the card
--- @param category string Category: "equipment", "wands", "triggers", "actions"
--- @param cardData table|nil Optional card data to cache
--- @return boolean success
function CardInventoryPanel.addCard(cardEntity, category, cardData)
    if not cardEntity or not registry:valid(cardEntity) then
        return false
    end
    
    local gridEntity = state.grids[category]
    if not gridEntity then
        log_warn("[CardInventoryPanel] Unknown category: " .. tostring(category))
        return false
    end
    
    -- Cache card data
    if cardData then
        state.cardRegistry[cardEntity] = cardData
    end
    
    -- Setup card for UI rendering
    if ObjectAttachedToUITag and not registry:has(cardEntity, ObjectAttachedToUITag) then
        registry:emplace(cardEntity, ObjectAttachedToUITag)
    end
    
    if transform and transform.set_space then
        transform.set_space(cardEntity, "screen")
    end
    
    -- Add shader if not present
    if shader_pipeline and shader_pipeline.ShaderPipelineComponent then
        if not registry:has(cardEntity, shader_pipeline.ShaderPipelineComponent) then
            local shaderComp = registry:emplace(cardEntity, shader_pipeline.ShaderPipelineComponent)
            shaderComp:addPass("3d_skew")
        end
    end
    
    -- Enable drag
    local go = component_cache.get(cardEntity, GameObject)
    if go then
        go.state.dragEnabled = true
        go.state.collisionEnabled = true
        go.state.hoverEnabled = true
    end
    
    -- Add to grid
    local slotIndex = grid.addItem(gridEntity, cardEntity)
    return slotIndex ~= nil
end

--- Remove a card from the inventory
--- @param cardEntity number Entity ID
--- @return boolean success
function CardInventoryPanel.removeCard(cardEntity)
    for _, gridEntity in pairs(state.grids) do
        local slotIndex = grid.findSlotContaining(gridEntity, cardEntity)
        if slotIndex then
            grid.removeItem(gridEntity, slotIndex)
            state.cardRegistry[cardEntity] = nil
            state.lockedCards[cardEntity] = nil
            return true
        end
    end
    return false
end

--- Get active tab ID
--- @return string
function CardInventoryPanel.getActiveTab()
    return state.activeTab
end

--- Set active tab
--- @param tabId string
function CardInventoryPanel.setActiveTab(tabId)
    switchTab(tabId)
end

--- Lock a card
--- @param cardEntity number
function CardInventoryPanel.lockCard(cardEntity)
    setCardLocked(cardEntity, true)
end

--- Unlock a card
--- @param cardEntity number
function CardInventoryPanel.unlockCard(cardEntity)
    setCardLocked(cardEntity, false)
end

--- Check if card is locked
--- @param cardEntity number
--- @return boolean
function CardInventoryPanel.isCardLocked(cardEntity)
    return isCardLocked(cardEntity)
end

local function createDummyCard(spriteName, cardData)
    local entity = animation_system.createAnimatedObjectWithTransform(
        spriteName, true, 0, 0, nil, true
    )
    
    if not entity or not registry:valid(entity) then
        log_warn("[CardInventoryPanel] Failed to create dummy card: " .. tostring(spriteName))
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
    
    if ObjectAttachedToUITag and not registry:has(entity, ObjectAttachedToUITag) then
        registry:emplace(entity, ObjectAttachedToUITag)
    end
    
    if transform and transform.set_space then
        transform.set_space(entity, "screen")
    end
    
    local go = component_cache.get(entity, GameObject)
    if go then
        go.state.dragEnabled = true
        go.state.collisionEnabled = true
        go.state.hoverEnabled = true
    end
    
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
    
    state.cardRegistry[entity] = cardData
    
    if setScriptTableForEntityID then
        setScriptTableForEntityID(entity, cardData)
    end
    
    return entity
end

function CardInventoryPanel.spawnDummyCards()
    local dummyCards = {
        { sprite = "card-new-test-action.png", name = "Fireball", element = "Fire", manaCost = 12, category = "wands" },
        { sprite = "card-new-test-action.png", name = "Ice Shard", element = "Ice", manaCost = 8, category = "wands" },
        { sprite = "card-new-test-action.png", name = "Lightning", element = "Lightning", manaCost = 15, category = "wands" },
        { sprite = "card-new-test-trigger.png", name = "On Hit", element = nil, manaCost = 5, category = "triggers" },
        { sprite = "card-new-test-trigger.png", name = "On Kill", element = nil, manaCost = 10, category = "triggers" },
        { sprite = "card-new-test-modifier.png", name = "Damage Up", element = nil, manaCost = 3, category = "actions" },
        { sprite = "card-new-test-modifier.png", name = "Speed Up", element = nil, manaCost = 4, category = "actions" },
        { sprite = "frame0012.png", name = "Basic Sword", element = nil, manaCost = 0, category = "equipment" },
        { sprite = "frame0012.png", name = "Shield", element = nil, manaCost = 0, category = "equipment" },
    }
    
    for _, cardDef in ipairs(dummyCards) do
        local entity = createDummyCard(cardDef.sprite, {
            name = cardDef.name,
            element = cardDef.element,
            manaCost = cardDef.manaCost,
            description = "A " .. cardDef.name .. " card.",
        })
        
        if entity then
            local gridEntity = state.grids[cardDef.category]
            if gridEntity then
                local slotIndex = grid.addItem(gridEntity, entity)
                if slotIndex then
                    log_debug("[CardInventoryPanel] Added " .. cardDef.name .. " to " .. cardDef.category .. " slot " .. slotIndex)
                end
            end
        end
    end
    
    log_debug("[CardInventoryPanel] Spawned dummy cards")
end

function CardInventoryPanel.init()
    CardInventoryPanel.open()
    
    timer.after_opts({
        delay = 0.5,
        tag = "spawn_dummy_cards",
        group = TIMER_GROUP,
        action = function()
            CardInventoryPanel.spawnDummyCards()
        end,
    })
    
    log_debug("[CardInventoryPanel] Init complete")
end

return CardInventoryPanel
