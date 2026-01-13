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
local shader_pipeline = _G.shader_pipeline

local TIMER_GROUP = "player_inventory"
local PANEL_ID = "player_inventory_panel"

local TAB_CONFIG = {
    equipment = {
        id = "inv_equipment",
        label = "Equipment",
        icon = "E",
        rows = 4,
        cols = 4,
    },
    wands = {
        id = "inv_wands",
        label = "Wands",
        icon = "W",
        rows = 4,
        cols = 4,
    },
    triggers = {
        id = "inv_triggers",
        label = "Triggers",
        icon = "T",
        rows = 4,
        cols = 4,
    },
    actions = {
        id = "inv_actions",
        label = "Actions",
        icon = "A",
        rows = 4,
        cols = 4,
    },
}

local TAB_ORDER = { "equipment", "wands", "triggers", "actions" }

local SLOT_WIDTH = 64
local SLOT_HEIGHT = 64
local SLOT_SPACING = 4
local GRID_ROWS = 4
local GRID_COLS = 4
local GRID_PADDING = 8
local GRID_WIDTH = GRID_COLS * SLOT_WIDTH + (GRID_COLS - 1) * SLOT_SPACING + GRID_PADDING * 2
local GRID_HEIGHT = GRID_ROWS * SLOT_HEIGHT + (GRID_ROWS - 1) * SLOT_SPACING + GRID_PADDING * 2
local HEADER_HEIGHT = 40
local TABS_HEIGHT = 40
local FOOTER_HEIGHT = 50
local VERTICAL_MARGINS = 30
local PANEL_WIDTH = GRID_WIDTH + 60
local PANEL_HEIGHT = HEADER_HEIGHT + TABS_HEIGHT + GRID_HEIGHT + FOOTER_HEIGHT + VERTICAL_MARGINS
local RENDER_LAYER = "sprites"

local state = {
    initialized = false,
    isVisible = false,
    panelEntity = nil,
    closeButtonEntity = nil,
    grids = {},
    tabButtons = {},
    activeTab = "actions",
    searchFilter = "",
    sortField = nil,
    sortAsc = true,
    lockedCards = {},
    cardRegistry = {},
    signalHandlers = {},
    panelX = 0,
    panelY = nil,
    gridX = 0,
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

local function createSimpleCard(spriteName, x, y, cardData)
    local entity = animation_system.createAnimatedObjectWithTransform(
        spriteName, true, x or 0, y or 0, nil, true
    )
    
    if not entity or not registry:valid(entity) then
        log_warn("[PlayerInventory] Failed to create card entity for: " .. tostring(spriteName))
        return nil
    end
    
    animation_system.resizeAnimationObjectsInEntityToFit(entity, 56, 78)
    
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
    
    transform.set_space(entity, "screen")
    
    local go = component_cache.get(entity, GameObject)
    if go then
        go.state.dragEnabled = true
        go.state.collisionEnabled = true
        go.state.hoverEnabled = true
    end
    
    if shader_pipeline and shader_pipeline.ShaderPipelineComponent then
        local shaderPipelineComp = registry:emplace(entity, shader_pipeline.ShaderPipelineComponent)
        shaderPipelineComp:addPass("3d_skew")
        
        local skewSeed = math.random() * 10000
        local passes = shaderPipelineComp.passes
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
    
    local scriptData = {
        entity = entity,
        id = cardData.id,
        name = cardData.name,
        element = cardData.element,
        stackId = cardData.stackId,
        category = "card",
        cardData = cardData,
    }
    
    if setScriptTableForEntityID then
        setScriptTableForEntityID(entity, scriptData)
    end
    
    state.cardRegistry[entity] = scriptData
    
    return entity
end

local function createGridForTab(tabId, x, y, visible)
    local cfg = TAB_CONFIG[tabId]
    if not cfg then return nil end
    
    local spawnX = visible and x or -9999
    
    local gridDef = dsl.inventoryGrid {
        id = cfg.id,
        rows = GRID_ROWS,
        cols = GRID_COLS,
        slotSize = { w = SLOT_WIDTH, h = SLOT_HEIGHT },
        slotSpacing = SLOT_SPACING,
        
        config = {
            allowDragIn = true,
            allowDragOut = true,
            stackable = false,
            slotSprite = "test-inventory-square-single.png",
            padding = GRID_PADDING,
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
                end
            end
        end,
    }
    
    local gridEntity = dsl.spawn({ x = spawnX, y = y }, gridDef, RENDER_LAYER, 150)
    if ui and ui.box and ui.box.set_draw_layer then
        ui.box.set_draw_layer(gridEntity, RENDER_LAYER)
    end
    
    local success = InventoryGridInit.initializeIfGrid(gridEntity, cfg.id)
    if success then
        log_debug("[PlayerInventory] Grid '" .. tabId .. "' initialized at x=" .. spawnX)
    else
        log_warn("[PlayerInventory] Grid '" .. tabId .. "' init failed!")
    end
    
    return gridEntity
end



local function switchTab(tabId)
    if state.activeTab == tabId then return end
    
    local oldTab = state.activeTab
    state.activeTab = tabId
    
    for id, gridEntity in pairs(state.grids) do
        local isActive = (id == tabId)
        setEntityVisible(gridEntity, isActive and state.isVisible, state.gridX)
        setGridItemsVisible(gridEntity, isActive and state.isVisible)
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
        },
    }
end

local function createCloseButton(panelX, panelY, panelWidth)
    local closeButtonDef = dsl.button("X", {
        id = "close_btn",
        minWidth = 28,
        minHeight = 28,
        fontSize = 16,
        color = "darkred",
        hover = true,
        onClick = function()
            PlayerInventory.close()
        end,
    })
    
    local closeX = panelX + panelWidth - 36
    local closeY = panelY + 6
    
    local closeEntity = dsl.spawn({ x = closeX, y = closeY }, closeButtonDef, RENDER_LAYER, 200)
    if ui and ui.box and ui.box.set_draw_layer then
        ui.box.set_draw_layer(closeEntity, RENDER_LAYER)
    end
    
    return closeEntity
end

local function createTabs()
    local tabChildren = {}
    
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
            minWidth = PANEL_WIDTH - 20,
        },
        children = {
            dsl.button("Name v", {
                id = "sort_name_btn",
                minWidth = 60,
                minHeight = 26,
                fontSize = 11,
                color = "purple_slate",
                hover = true,
                onClick = function()
                    log_debug("[PlayerInventory] Sort by name clicked")
                end,
            }),
            dsl.spacer(4),
            dsl.button("Cost v", {
                id = "sort_cost_btn",
                minWidth = 60,
                minHeight = 26,
                fontSize = 11,
                color = "purple_slate",
                hover = true,
                onClick = function()
                    log_debug("[PlayerInventory] Sort by cost clicked")
                end,
            }),
            dsl.spacer(1),
            dsl.text("0 / 16", { id = "slot_count_text", fontSize = 11, color = "light_gray" }),
        },
    }
end

local function createPanelDefinition()
    return dsl.root {
        config = {
            id = PANEL_ID,
            color = "blackberry",
            padding = 10,
            emboss = 3,
            minWidth = PANEL_WIDTH,
            maxWidth = PANEL_WIDTH,
            minHeight = PANEL_HEIGHT,
        },
        children = {
            createHeader(),
            dsl.spacer(PANEL_WIDTH - 20, 5),
            createTabs(),
            dsl.spacer(PANEL_WIDTH - 20, GRID_HEIGHT + 30),
            createFooter(),
        },
    }
end

local function snapItemsToSlots()
    local activeGrid = state.grids[state.activeTab]
    if not activeGrid then return end
    
    local inputState = input and input.getState and input.getState()
    local draggedEntity = inputState and inputState.cursor_dragging_target
    
    local items = grid.getAllItems(activeGrid)
    for slotIndex, itemEntity in pairs(items) do
        if itemEntity and registry:valid(itemEntity) then
            if itemEntity ~= draggedEntity then
                local slotEntity = grid.getSlotEntity(activeGrid, slotIndex)
                if slotEntity then
                    InventoryGridInit.centerItemOnSlot(itemEntity, slotEntity)
                end
            end
        end
    end
end

local function isCardInActiveGrid(eid)
    local activeGrid = state.grids[state.activeTab]
    if not activeGrid then return true end
    
    for tabId, gridEntity in pairs(state.grids) do
        if gridEntity then
            local slotIndex = grid.findSlotContaining(gridEntity, eid)
            if slotIndex then
                return tabId == state.activeTab
            end
        end
    end
    return true
end

local function setupCardRenderTimer()
    local UI_CARD_Z = (z_orders and z_orders.ui_tooltips or 900) + 500
    
    timer.run_every_render_frame(function()
        if not state.isVisible then return end
        
        snapItemsToSlots()
        
        local batchedCardBuckets = {}
        
        if not (command_buffer and command_buffer.queueDrawBatchedEntities and layers and layers.ui) then
            return
        end
        
        for eid, cardScript in pairs(state.cardRegistry) do
            if eid and registry:valid(eid) and isCardInActiveGrid(eid) then
                local hasPipeline = shader_pipeline and shader_pipeline.ShaderPipelineComponent
                    and registry:has(eid, shader_pipeline.ShaderPipelineComponent)
                local animComp = component_cache.get(eid, AnimationQueueComponent)
                
                if animComp then
                    animComp.drawWithLegacyPipeline = true
                end
                
                if hasPipeline and animComp and not animComp.noDraw then
                    local zToUse = UI_CARD_Z
                    
                    local bucket = batchedCardBuckets[zToUse]
                    if not bucket then
                        bucket = {}
                        batchedCardBuckets[zToUse] = bucket
                    end
                    bucket[#bucket + 1] = eid
                    animComp.drawWithLegacyPipeline = false
                end
            end
        end
        
        if next(batchedCardBuckets) then
            local zKeys = {}
            for z, entityList in pairs(batchedCardBuckets) do
                if #entityList > 0 then
                    table.insert(zKeys, z)
                end
            end
            table.sort(zKeys)
            
            for _, z in ipairs(zKeys) do
                local entityList = batchedCardBuckets[z]
                if entityList and #entityList > 0 then
                    command_buffer.queueDrawBatchedEntities(layers.ui, function(cmd)
                        cmd.registry = registry
                        cmd.entities = entityList
                        cmd.autoOptimize = true
                    end, z, layer.DrawCommandSpace.World)
                end
            end
        end
        
    end, nil, "inventory_card_render_timer", TIMER_GROUP)
end

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
            log_debug("[PlayerInventory] Item added to slot " .. slotIndex)
            if playSoundEffect then
                playSoundEffect("effects", "button-click")
            end
        end
    end)
    
    registerHandler("grid_item_removed", function(gridEntity, slotIndex, itemEntity)
        if isOurGrid(gridEntity) then
            log_debug("[PlayerInventory] Item removed from slot " .. slotIndex)
        end
    end)
    
    registerHandler("grid_item_moved", function(gridEntity, fromSlot, toSlot, itemEntity)
        if isOurGrid(gridEntity) then
            log_debug("[PlayerInventory] Item moved from slot " .. fromSlot .. " to " .. toSlot)
        end
    end)
    
    registerHandler("grid_items_swapped", function(gridEntity, slot1, slot2, item1, item2)
        if isOurGrid(gridEntity) then
            log_debug("[PlayerInventory] Items swapped between slots " .. slot1 .. " and " .. slot2)
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

local function initializeInventory()
    if state.initialized then return end
    
    local screenW = globals.screenWidth()
    local screenH = globals.screenHeight()
    
    state.panelX = 0 --(screenW - PANEL_WIDTH) / 2
    state.panelY = 0 -- (screenH - PANEL_HEIGHT) / 2
    state.gridX = state.panelX + 20
    state.gridY = state.panelY + HEADER_HEIGHT + TABS_HEIGHT + 25
    
    local panelDef = createPanelDefinition()
    state.panelEntity = dsl.spawn({ x = -9999, y = state.panelY }, panelDef, RENDER_LAYER, 100)
    
    if ui and ui.box and ui.box.set_draw_layer then
        ui.box.set_draw_layer(state.panelEntity, RENDER_LAYER)
    end
    
    state.closeButtonEntity = createCloseButton(state.panelX, state.panelY, PANEL_WIDTH)
    setEntityVisible(state.closeButtonEntity, false, state.panelX + PANEL_WIDTH - 36)
    
    state.tabButtons = {}
    for _, tabId in ipairs(TAB_ORDER) do
        local btnEntity = ui.box.GetUIEByID(registry, state.panelEntity, "tab_" .. tabId)
        if btnEntity then
            state.tabButtons[tabId] = btnEntity
        end
    end
    
    for _, tabId in ipairs(TAB_ORDER) do
        local visible = false
        local gridEntity = createGridForTab(tabId, state.gridX, state.gridY, visible)
        state.grids[tabId] = gridEntity
    end
    
    setupSignalHandlers()
    setupCardRenderTimer()
    
    state.initialized = true
    log_debug("[PlayerInventory] Initialized (hidden)")
end

function PlayerInventory.open()
    if not state.initialized then
        initializeInventory()
    end
    
    if state.isVisible then return end
    
    setEntityVisible(state.panelEntity, true, state.panelX)
    setEntityVisible(state.closeButtonEntity, true, state.panelX + PANEL_WIDTH - 36)
    
    for tabId, gridEntity in pairs(state.grids) do
        local isActive = (tabId == state.activeTab)
        setEntityVisible(gridEntity, isActive, state.gridX)
        setGridItemsVisible(gridEntity, isActive)
    end
    
    state.isVisible = true
    signal.emit("player_inventory_opened")
    
    if playSoundEffect then
        playSoundEffect("effects", "button-click")
    end
    
    log_debug("[PlayerInventory] Opened")
end

function PlayerInventory.close()
    if not state.isVisible then return end
    
    setEntityVisible(state.panelEntity, false, state.panelX)
    setEntityVisible(state.closeButtonEntity, false, state.panelX + PANEL_WIDTH - 36)
    
    for tabId, gridEntity in pairs(state.grids) do
        setEntityVisible(gridEntity, false, state.gridX)
        setGridItemsVisible(gridEntity, false)
    end
    
    state.isVisible = false
    signal.emit("player_inventory_closed")
    
    log_debug("[PlayerInventory] Closed (hidden)")
end

function PlayerInventory.toggle()
    if state.isVisible then
        PlayerInventory.close()
    else
        PlayerInventory.open()
    end
end

function PlayerInventory.isOpen()
    return state.isVisible
end

function PlayerInventory.destroy()
    if not state.initialized then return end
    
    log_debug("[PlayerInventory] Destroying...")
    
    cleanupSignalHandlers()
    timer.kill_group(TIMER_GROUP)
    
    for _, cardEntity in pairs(state.cardRegistry) do
        if cardEntity and registry:valid(cardEntity) then
            registry:destroy(cardEntity)
        end
    end
    state.cardRegistry = {}
    
    for tabId, gridEntity in pairs(state.grids) do
        if gridEntity and registry:valid(gridEntity) then
            local cfg = TAB_CONFIG[tabId]
            if cfg then
                local slotCount = GRID_ROWS * GRID_COLS
                for i = 1, slotCount do
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
    
    if state.closeButtonEntity and registry:valid(state.closeButtonEntity) then
        if ui and ui.box and ui.box.Remove then
            ui.box.Remove(registry, state.closeButtonEntity)
        end
    end
    state.closeButtonEntity = nil
    
    if state.panelEntity and registry:valid(state.panelEntity) then
        if ui and ui.box and ui.box.Remove then
            ui.box.Remove(registry, state.panelEntity)
        end
    end
    state.panelEntity = nil
    state.tabButtons = {}
    
    state.initialized = false
    state.isVisible = false
    
    log_debug("[PlayerInventory] Destroyed")
end

function PlayerInventory.addCard(cardEntity, category, cardData)
    if not state.initialized then
        initializeInventory()
    end
    
    category = category or state.activeTab
    local gridEntity = state.grids[category]
    if not gridEntity then
        log_warn("[PlayerInventory] Unknown category: " .. tostring(category))
        return false
    end
    
    if cardData then
        state.cardRegistry[cardEntity] = cardData
    end
    
    if ObjectAttachedToUITag and not registry:has(cardEntity, ObjectAttachedToUITag) then
        registry:emplace(cardEntity, ObjectAttachedToUITag)
    end
    
    if transform and transform.set_space then
        transform.set_space(cardEntity, "screen")
    end
    
    local go = component_cache.get(cardEntity, GameObject)
    if go then
        go.state.dragEnabled = true
        go.state.collisionEnabled = true
        go.state.hoverEnabled = true
    end
    
    local success, slotIndex = grid.addItem(gridEntity, cardEntity)
    if success then
        local slotEntity = grid.getSlotEntity(gridEntity, slotIndex)
        if slotEntity then
            InventoryGridInit.centerItemOnSlot(cardEntity, slotEntity)
        end
        log_debug("[PlayerInventory] Added card to " .. category .. " slot " .. slotIndex)
        return true
    end
    
    return false
end

function PlayerInventory.removeCard(cardEntity)
    for tabId, gridEntity in pairs(state.grids) do
        local slotIndex = grid.findSlotContaining(gridEntity, cardEntity)
        if slotIndex then
            grid.removeItem(gridEntity, slotIndex)
            state.cardRegistry[cardEntity] = nil
            state.lockedCards[cardEntity] = nil
            log_debug("[PlayerInventory] Removed card from " .. tabId .. " slot " .. slotIndex)
            return true
        end
    end
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
    if not state.initialized then
        initializeInventory()
    end
    
    local cards = {
        { id = "fireball", name = "Fireball", sprite = "card-new-test-action.png", element = "Fire", stackId = "fireball" },
        { id = "ice_shard", name = "Ice Shard", sprite = "card-new-test-action.png", element = "Ice", stackId = "ice_shard" },
        { id = "trigger", name = "Trigger", sprite = "card-new-test-trigger.png", element = nil, stackId = "trigger" },
        { id = "modifier", name = "Modifier", sprite = "card-new-test-modifier.png", element = nil, stackId = "modifier" },
    }
    
    for i, cardDef in ipairs(cards) do
        local entity = createSimpleCard(cardDef.sprite, -9999, -9999, cardDef)
        if entity then
            local activeGrid = state.grids[state.activeTab]
            if activeGrid then
                local success, slotIndex = grid.addItem(activeGrid, entity)
                if success then
                    local slotEntity = grid.getSlotEntity(activeGrid, slotIndex)
                    if slotEntity then
                        InventoryGridInit.centerItemOnSlot(entity, slotEntity)
                    end
                    log_debug("[PlayerInventory] Added dummy card " .. cardDef.name .. " to slot " .. slotIndex)
                end
            end
        end
    end
    
    log_debug("[PlayerInventory] Spawned " .. #cards .. " dummy cards")
end

log_debug("[PlayerInventory] Module loaded")

return PlayerInventory
