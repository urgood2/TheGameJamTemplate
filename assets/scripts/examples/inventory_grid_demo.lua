--[[
================================================================================
Inventory Grid Demo (Simplified)
================================================================================
Demonstrates inventory grid system with drag-drop slots.

Usage:
    local InventoryGridDemo = require("examples.inventory_grid_demo")
    InventoryGridDemo.init()  -- Call from main menu initMainMenu()
    InventoryGridDemo.cleanup()  -- Call from clearMainMenu()
================================================================================
]]

local InventoryGridDemo = {}

-- Dependencies
local dsl = require("ui.ui_syntax_sugar")
local grid = require("core.inventory_grid")
local signal = require("external.hump.signal")
local component_cache = require("core.component_cache")
local timer = require("core.timer")
local UIBackground = require("ui.ui_background")
local UIDecorations = require("ui.ui_decorations")
local shader_pipeline = _G.shader_pipeline

local InventoryGridInit = require("ui.inventory_grid_init")

local demoState = {
    grids = {},
    gridEntity = nil,
    infoBoxEntity = nil,
    customPanelEntity = nil,
    sortButtonsEntity = nil,
    tabEntities = {},
    tabButtonEntities = {},
    mockCards = {},
    signalHandlers = {},
    stackBadges = {},
    timerGroup = "inventory_demo",
    cardRegistry = {},
    customPanelState = nil,
    sortBy = nil,
    sortAscending = true,
    activeTab = "inventory",
}

--------------------------------------------------------------------------------
-- Helper: Create a simple draggable card entity
--------------------------------------------------------------------------------

local function createSimpleCard(spriteName, x, y, cardData)
    local entity = animation_system.createAnimatedObjectWithTransform(
        spriteName, true, x or 0, y or 0, nil, true
    )
    
    if not entity or not registry:valid(entity) then
        log_warn("[InventoryGridDemo] Failed to create card entity for: " .. tostring(spriteName))
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
    
    -- ObjectAttachedToUITag: excludes from main sprite render (rendered by our custom timer)
    if ObjectAttachedToUITag and not registry:has(entity, ObjectAttachedToUITag) then
        registry:emplace(entity, ObjectAttachedToUITag)
    end
    
    -- Screen-space collision: cards are at screen coords, camera has zoom=0.8
    transform.set_space(entity, "screen")
    
    local go = component_cache.get(entity, GameObject)
    if go then
        go.state.dragEnabled = true
        go.state.collisionEnabled = true
        go.state.hoverEnabled = true
    end
    
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
    
    local scriptData = {
        entity = entity,
        id = cardData.id,
        name = cardData.name,
        element = cardData.element,
        stackId = cardData.stackId,
        category = "card",
        cardData = cardData,
        skewSeed = skewSeed,
    }
    
    if setScriptTableForEntityID then
        setScriptTableForEntityID(entity, scriptData)
    end
    
    demoState.cardRegistry[entity] = scriptData
    
    log_debug("[InventoryGridDemo] Created card: " .. cardData.name .. " at " .. x .. "," .. y)
    return entity
end

--------------------------------------------------------------------------------
-- Initialize Demo
--------------------------------------------------------------------------------

function InventoryGridDemo.init()
    log_debug("[InventoryGridDemo] Initializing...")
    
    local screenW = globals.screenWidth()
    local screenH = globals.screenHeight()
    
    local gridX = screenW - 350
    local gridY = 100
    
    local leftPanelX = 50
    local leftPanelY = 100
    
    InventoryGridDemo.createPostItTabs(gridX, gridY, 320)
    InventoryGridDemo.createMainGrid(gridX, gridY)
    InventoryGridDemo.createInfoBox(gridX - 220, gridY)
    InventoryGridDemo.createSortButtons(gridX - 220, gridY + 340)
    
    InventoryGridDemo.createCustomPanel(leftPanelX, leftPanelY + 200)
    
    InventoryGridDemo.setupSignalHandlers()
    InventoryGridDemo.setupDragDebugTimer()
    InventoryGridDemo.setupGridStateDebugTimer()
    
    timer.after_opts({
        delay = 0.3,
        tag = "demo_spawn_cards",
        group = demoState.timerGroup,
        action = function()
            InventoryGridDemo.spawnMockCards()
            InventoryGridDemo.setupStackBadges()
            InventoryGridDemo.setupSlotOverlays()
            InventoryGridDemo.setupCardRenderTimer()
        end,
    })
    
    log_debug("[InventoryGridDemo] Initialized successfully")
end

--------------------------------------------------------------------------------
-- Create All Inventory Grids (one per tab)
--------------------------------------------------------------------------------

local function getCardElement(item)
    local script = getScriptTableFromEntityID and getScriptTableFromEntityID(item)
    if script and script.element then
        return script.element
    end
    local cardData = demoState.cardRegistry[item]
    if cardData and cardData.element then
        return cardData.element
    end
    return nil
end

local TAB_CONFIGS = {
    inventory = {
        id = "demo_inventory",
        rows = 3, cols = 4,
        slots = {
            [1] = {
                filter = function(item)
                    local element = getCardElement(item)
                    local accepted = element == "Fire"
                    log_debug("[Filter:Slot1] item=" .. tostring(item) .. " element=" .. tostring(element) .. " accepted=" .. tostring(accepted))
                    return accepted
                end,
                color = util.getColor("fiery_red"),
            },
            [2] = {
                filter = function(item)
                    local element = getCardElement(item)
                    local accepted = element == "Ice"
                    log_debug("[Filter:Slot2] item=" .. tostring(item) .. " element=" .. tostring(element) .. " accepted=" .. tostring(accepted))
                    return accepted
                end,
                color = util.getColor("baby_blue"),
            },
            [12] = { locked = true, color = util.getColor("gray") },
        },
    },
    equipment = {
        id = "demo_equipment",
        rows = 2, cols = 3,
        slots = {},
    },
    crafting = {
        id = "demo_crafting",
        rows = 3, cols = 3,
        slots = {
            [5] = { color = util.getColor("gold") },
        },
    },
}

local OFFSCREEN_X = -9999

local function setGridVisible(gridEntity, visible, onscreenX)
    if not gridEntity or not registry:valid(gridEntity) then return end
    local transform = component_cache.get(gridEntity, Transform)
    if transform then
        transform.actualX = visible and onscreenX or OFFSCREEN_X
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

local function createSingleGrid(tabId, x, y, visible)
    local cfg = TAB_CONFIGS[tabId]
    if not cfg then return nil end
    
    local spawnX = visible and x or OFFSCREEN_X
    
    local gridDef = dsl.inventoryGrid {
        id = cfg.id,
        rows = cfg.rows,
        cols = cfg.cols,
        slotSize = { w = 72, h = 100 },
        slotSpacing = 6,
        
        config = {
            allowDragIn = true,
            allowDragOut = true,
            stackable = false,  -- TODO: stacking incomplete, needs visual stack count + merge logic
            maxStackSize = 5,
            slotColor = "gray",
            slotEmboss = 2,
            padding = 8,
            backgroundColor = "blackberry",
        },
        
        slots = cfg.slots,
        
        onSlotChange = function(gridEntity, slotIndex, oldItem, newItem)
            log_debug("[Demo:" .. tabId .. "] Slot " .. slotIndex .. " changed")
        end,
        
        onSlotClick = function(gridEntity, slotIndex, button)
            log_debug("[Demo:" .. tabId .. "] Slot " .. slotIndex .. " clicked")
        end,
    }
    
    local gridEntity = dsl.spawn({ x = spawnX, y = y }, gridDef, "ui", 100)
    ui.box.set_draw_layer(gridEntity, "ui")
    
    local success = InventoryGridInit.initializeIfGrid(gridEntity, cfg.id)
    if success then
        log_debug("[InventoryGridDemo] Grid '" .. tabId .. "' initialized at x=" .. spawnX)
    else
        log_warn("[InventoryGridDemo] Grid '" .. tabId .. "' init failed!")
    end
    
    return gridEntity
end

function InventoryGridDemo.createMainGrid(x, y)
    demoState.grids = {}
    demoState.stackBadges = {}
    demoState.gridOnscreenX = x
    demoState.gridOnscreenY = y
    
    local tabs = { "inventory", "equipment", "crafting" }
    for _, tabId in ipairs(tabs) do
        local visible = (tabId == demoState.activeTab)
        local gridEntity = createSingleGrid(tabId, x, y, visible)
        demoState.grids[tabId] = gridEntity
        demoState.stackBadges[tabId] = {}
    end
    
    demoState.gridEntity = demoState.grids[demoState.activeTab]
    log_debug("[InventoryGridDemo] All grids created, active: " .. demoState.activeTab)
end

--------------------------------------------------------------------------------
-- Create Info Box
--------------------------------------------------------------------------------

function InventoryGridDemo.createInfoBox(x, y)
    local infoDef = dsl.vbox {
        config = {
            id = "demo_info_box",
            color = util.getColor("blackberry"),
            padding = 12,
            emboss = 3,
            minWidth = 200,
            minHeight = 280,
        },
        children = {
            dsl.text("Inventory Demo", { fontSize = 18, color = "white", shadow = true }),
            dsl.spacer(10),
            dsl.divider("horizontal", { color = "apricot_cream", thickness = 1, length = 180 }),
            dsl.spacer(10),
            dsl.text("Drag cards to slots", { fontSize = 12, color = "light_gray" }),
            dsl.text("Stack same cards (max 5)", { fontSize = 12, color = "light_gray" }),
            dsl.spacer(8),
            dsl.text("Slot 1: Fire only", { fontSize = 12, color = "fiery_red" }),
            dsl.text("Slot 2: Ice only", { fontSize = 12, color = "baby_blue" }),
            dsl.text("Slot 12: Locked", { fontSize = 12, color = "gray" }),
            dsl.spacer(15),
            dsl.text("Stats:", { fontSize = 14, color = "gold" }),
            dsl.text("Slots: 0/12", { id = "stats_slots", fontSize = 12, color = "white" }),
            dsl.text("Items: 0", { id = "stats_items", fontSize = 12, color = "white" }),
        },
    }
    
    demoState.infoBoxEntity = dsl.spawn({ x = x, y = y }, infoDef, "ui", 100)
    ui.box.set_draw_layer(demoState.infoBoxEntity, "ui")
    
    timer.after_opts({
        delay = 0.2,
        tag = "setup_stats_textgetter",
        group = demoState.timerGroup,
        action = function()
            InventoryGridDemo.setupStatsTextGetters()
        end,
    })
end

function InventoryGridDemo.setupStatsTextGetters()
    demoState.statsSlotEntity = ui.box.GetUIEByID(registry, demoState.infoBoxEntity, "stats_slots")
    demoState.statsItemEntity = ui.box.GetUIEByID(registry, demoState.infoBoxEntity, "stats_items")
    
    timer.every_opts({
        delay = 0.1,
        tag = "stats_update",
        group = demoState.timerGroup,
        action = function()
            InventoryGridDemo.updateStatsText()
        end,
    })
    
    log_debug("[Demo] Stats timer configured")
end

function InventoryGridDemo.updateStatsText()
    local ge = demoState.grids[demoState.activeTab]
    if not ge then return end
    
    local slotsEntity = demoState.statsSlotEntity
    local itemsEntity = demoState.statsItemEntity
    
    if slotsEntity and registry:valid(slotsEntity) then
        local uiConfig = component_cache.get(slotsEntity, UIConfig)
        if uiConfig then
            local used = grid.getUsedSlotCount(ge) or 0
            local total = grid.getCapacity(ge) or 12
            local newText = "Slots: " .. used .. "/" .. total
            if uiConfig.text ~= newText then
                uiConfig.text = newText
            end
        end
    end
    
    if itemsEntity and registry:valid(itemsEntity) then
        local uiConfig = component_cache.get(itemsEntity, UIConfig)
        if uiConfig then
            local items = grid.getAllItems(ge) or {}
            local count = 0
            for _ in pairs(items) do count = count + 1 end
            local newText = "Items: " .. count
            if uiConfig.text ~= newText then
                uiConfig.text = newText
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Custom Panel Demo
-- 
-- DEMONSTRATES: Immediate-mode UI rendering with HoverRegistry
-- 
-- USE CASE: When DSL/retained-mode UI is too rigid and you need pixel-perfect
-- control over rendering (e.g., custom health bars, minimap, skill trees).
--
-- KEY CONCEPTS:
-- 1. HoverRegistry: Register hover regions by ID each frame, then call update()
--    to determine which region is hovered based on z-order
-- 2. command_buffer: Queue draw commands (circles, rects, text) for batched rendering
-- 3. timer.every_opts: Re-render every frame (~0.016s) for smooth animations
--
-- PATTERN:
--   timer.every_opts({ delay = 0.016, action = function()
--       HoverRegistry.clear()
--       -- Queue draw commands
--       -- Register hover regions
--       HoverRegistry.update()
--   end})
--------------------------------------------------------------------------------

function InventoryGridDemo.createCustomPanel(x, y)
    local HoverRegistry = require("ui.hover_registry")
    
    demoState.customPanelState = {
        x = x,
        y = y,
        w = 200,
        h = 145,
        isHovered = false,
        iconHovered = false,
    }
    
    local panelContainer = dsl.vbox {
        config = { 
            id = "demo_custom_panel_container",
            padding = 10,
            color = "blackberry",
            emboss = 2,
            minWidth = 200,
            minHeight = 145,
        },
        children = {
            dsl.text("Custom Panel", { fontSize = 12, color = "gold", shadow = true }),
            dsl.spacer(4),
            dsl.text("(immediate-mode + hover)", { fontSize = 10, color = "light_gray" }),
        },
    }
    
    demoState.customPanelEntity = dsl.spawn({ x = x, y = y }, panelContainer, "ui", 100)
    ui.box.set_draw_layer(demoState.customPanelEntity, "ui")
    
    timer.every_opts({
        delay = 0.016,
        tag = "custom_panel_render",
        group = demoState.timerGroup,
        action = function()
            HoverRegistry.clear()
            InventoryGridDemo.renderCustomPanel()
            HoverRegistry.update()
        end,
    })
end

function InventoryGridDemo.renderCustomPanel()
    local HoverRegistry = require("ui.hover_registry")
    local state = demoState.customPanelState
    if not state then return end
    
    local baseZ = (z_orders and z_orders.ui_tooltips or 800) + 200
    local SPACE = layer.DrawCommandSpace.Screen
    local uiLayer = layers.ui or "ui"
    
    local panelX = state.x + 10
    local panelY = state.y + 50
    local panelW = state.w - 20
    local panelH = 75
    
    local pulseTime = (globals.time or 0) * 2
    local pulseAlpha = math.abs(math.sin(pulseTime)) * 0.3 + 0.5
    
    local bgColor = state.isHovered 
        and Color.new(80, 120, 180, math.floor(pulseAlpha * 255))
        or Color.new(40, 60, 100, math.floor(pulseAlpha * 200))
    
    if command_buffer and command_buffer.queueDrawSteppedRoundedRect then
        command_buffer.queueDrawSteppedRoundedRect(uiLayer, function(c)
            c.x = panelX + panelW / 2
            c.y = panelY + panelH / 2
            c.w = panelW
            c.h = panelH
            c.fillColor = bgColor
            c.borderColor = state.isHovered and Color.new(150, 200, 255, 255) or Color.new(80, 100, 140, 255)
            c.borderWidth = 2
            c.numSteps = 4
        end, baseZ, SPACE)
    end
    
    HoverRegistry.region({
        id = "custom_panel_bg",
        x = panelX,
        y = panelY,
        w = panelW,
        h = panelH,
        z = baseZ,
        data = { state = state },
        onHover = function(data)
            data.state.isHovered = true
        end,
        onUnhover = function(data)
            data.state.isHovered = false
        end,
    })
    
    local iconX = panelX + 20
    local iconY = panelY + panelH / 2
    local iconRadius = 12
    
    local iconColor = state.iconHovered
        and Color.new(255, 220, 100, 255)
        or Color.new(200, 180, 80, 200)
    
    if command_buffer and command_buffer.queueDrawCircleFilled then
        command_buffer.queueDrawCircleFilled(uiLayer, function(c)
            c.x = iconX
            c.y = iconY
            c.radius = iconRadius
            c.color = iconColor
        end, baseZ + 1, SPACE)
    end
    
    HoverRegistry.region({
        id = "custom_panel_icon",
        x = iconX - iconRadius,
        y = iconY - iconRadius,
        w = iconRadius * 2,
        h = iconRadius * 2,
        z = baseZ + 10,
        data = { state = state },
        onHover = function(data)
            data.state.iconHovered = true
        end,
        onUnhover = function(data)
            data.state.iconHovered = false
        end,
    })
    
    local font = localization and localization.getFont and localization.getFont()
    local labelText = state.iconHovered and "Icon Hovered!" or (state.isHovered and "Panel Hovered" or "Hover me")
    local fontSize = 14
    local textX = iconX + iconRadius + 12
    local textY = iconY - fontSize / 2
    
    if command_buffer and command_buffer.queueDrawText and font then
        command_buffer.queueDrawText(uiLayer, function(c)
            c.text = labelText
            c.font = font
            c.x = textX
            c.y = textY
            c.color = Color.new(255, 255, 255, 255)
            c.fontSize = fontSize
        end, baseZ + 2, SPACE)
    end
end

--------------------------------------------------------------------------------
-- Create Sort Buttons
--------------------------------------------------------------------------------

function InventoryGridDemo.createSortButtons(x, y)
    local function getSortIndicator(key)
        if demoState.sortBy ~= key then return "" end
        return demoState.sortAscending and " ↑" or " ↓"
    end
    
    local sortDef = dsl.hbox {
        config = {
            id = "demo_sort_buttons",
            padding = 4,
            color = "blackberry",
            emboss = 2,
        },
        children = {
            dsl.text("Sort:", { fontSize = 11, color = "light_gray" }),
            dsl.spacer(4),
            dsl.button("Name" .. getSortIndicator("name"), {
                id = "sort_name_btn",
                minWidth = 60,
                minHeight = 24,
                fontSize = 11,
                color = demoState.sortBy == "name" and "steel_blue" or "gray",
                hover = true,
                onClick = function()
                    InventoryGridDemo.toggleSort("name")
                end,
            }),
            dsl.spacer(4),
            dsl.button("Type" .. getSortIndicator("element"), {
                id = "sort_type_btn",
                minWidth = 60,
                minHeight = 24,
                fontSize = 11,
                color = demoState.sortBy == "element" and "steel_blue" or "gray",
                hover = true,
                onClick = function()
                    InventoryGridDemo.toggleSort("element")
                end,
            }),
        },
    }
    
    demoState.sortButtonsEntity = dsl.spawn({ x = x, y = y }, sortDef, "ui", 100)
    ui.box.set_draw_layer(demoState.sortButtonsEntity, "ui")
    log_debug("[Demo] Sort buttons created at " .. x .. ", " .. y)
end

function InventoryGridDemo.toggleSort(sortKey)
    if demoState.sortBy == sortKey then
        demoState.sortAscending = not demoState.sortAscending
    else
        demoState.sortBy = sortKey
        demoState.sortAscending = true
    end
    
    log_debug("[Demo] Sort changed: " .. tostring(sortKey) .. " " .. (demoState.sortAscending and "ASC" or "DESC"))
    
    InventoryGridDemo.applySorting()
    InventoryGridDemo.updateSortButtonLabels()
end

local function getCardData(eid)
    local script = getScriptTableFromEntityID and getScriptTableFromEntityID(eid)
    if script then return script end
    return demoState.cardRegistry[eid]
end

function InventoryGridDemo.applySorting()
    local activeGrid = demoState.grids[demoState.activeTab]
    if not demoState.sortBy or not activeGrid then return end
    
    local cfg = TAB_CONFIGS[demoState.activeTab]
    local maxSlots = cfg and (cfg.rows * cfg.cols) or 12
    
    local items = grid.getItemList(activeGrid)
    if not items or #items == 0 then
        log_debug("[Demo] No items to sort")
        return
    end
    
    local itemsWithData = {}
    for _, itemEntry in ipairs(items) do
        local entity = itemEntry.item
        local cardData = getCardData(entity)
        table.insert(itemsWithData, {
            entity = entity,
            slotIndex = itemEntry.slot,
            name = cardData and cardData.name or "",
            element = cardData and cardData.element or "",
        })
    end
    
    log_debug("[Demo] Sorting " .. #itemsWithData .. " items by " .. demoState.sortBy)
    
    local sortKey = demoState.sortBy
    local ascending = demoState.sortAscending
    
    table.sort(itemsWithData, function(a, b)
        local valA = a[sortKey] or ""
        local valB = b[sortKey] or ""
        if ascending then
            return valA < valB
        else
            return valA > valB
        end
    end)
    
    for _, item in ipairs(itemsWithData) do
        grid.removeItem(activeGrid, item.slotIndex)
    end
    
    local targetSlot = 1
    for _, item in ipairs(itemsWithData) do
        while targetSlot <= maxSlots do
            local slotData = cfg.slots and cfg.slots[targetSlot]
            local isLocked = grid.isSlotLocked(activeGrid, targetSlot)
            local hasFilter = slotData and slotData.filter
            if not isLocked and not hasFilter then
                break
            end
            targetSlot = targetSlot + 1
        end
        if targetSlot <= maxSlots then
            grid.addItem(activeGrid, item.entity, targetSlot)
            targetSlot = targetSlot + 1
        end
    end
    
    log_debug("[Demo] Sorted " .. #itemsWithData .. " items by " .. sortKey)
end

function InventoryGridDemo.updateSortButtonLabels()
    if not demoState.sortButtonsEntity then return end
    
    local function getLabel(key, text)
        if demoState.sortBy ~= key then return text end
        return text .. (demoState.sortAscending and " ↑" or " ↓")
    end
    
    local nameBtn = ui.box.GetUIEByID(registry, demoState.sortButtonsEntity, "sort_name_btn")
    local typeBtn = ui.box.GetUIEByID(registry, demoState.sortButtonsEntity, "sort_type_btn")
    
    if nameBtn then
        local uiCfg = component_cache.get(nameBtn, UIConfig)
        if uiCfg then
            uiCfg.text = getLabel("name", "Name")
            uiCfg.color = demoState.sortBy == "name" and util.getColor("steel_blue") or util.getColor("gray")
        end
    end
    
    if typeBtn then
        local uiCfg = component_cache.get(typeBtn, UIConfig)
        if uiCfg then
            uiCfg.text = getLabel("element", "Type")
            uiCfg.color = demoState.sortBy == "element" and util.getColor("steel_blue") or util.getColor("gray")
        end
    end
end

--------------------------------------------------------------------------------
-- Create Post-it Style Tabs (protruding above window)
--------------------------------------------------------------------------------

function InventoryGridDemo.createPostItTabs(windowX, windowY, windowW)
    local tabs = {
        { id = "inventory", label = "Inventory" },
        { id = "equipment", label = "Equipment" },
        { id = "crafting", label = "Crafting" },
    }
    
    local tabHeight = 28
    local tabWidth = 80
    local tabOverlap = 8
    local tabSpacing = 4
    local startX = windowX + 10
    local tabY = windowY - tabHeight + tabOverlap
    
    demoState.tabButtonEntities = {}
    
    for i, tab in ipairs(tabs) do
        local isActive = (tab.id == demoState.activeTab)
        local tabX = startX + (i - 1) * (tabWidth + tabSpacing)
        local tabId = tab.id
        
        local tabDef = dsl.button(tab.label, {
            id = "tab_" .. tab.id,
            minWidth = tabWidth,
            minHeight = tabHeight,
            fontSize = 11,
            color = isActive and "steel_blue" or "gray",
            hover = true,
            onClick = function()
                InventoryGridDemo.switchTab(tabId)
            end,
        })
        
        local tabEntity = dsl.spawn({ x = tabX, y = tabY }, tabDef, "ui", 50)
        ui.box.set_draw_layer(tabEntity, "ui")
        
        table.insert(demoState.tabEntities, tabEntity)
        demoState.tabButtonEntities[tabId] = tabEntity
        log_debug("[Demo] Created tab button: " .. tab.id .. " at " .. tabX .. ", " .. tabY)
    end
    
    log_debug("[Demo] Created " .. #tabs .. " post-it tabs")
end

function InventoryGridDemo.switchTab(tabId)
    if demoState.activeTab == tabId then return end
    
    local oldTab = demoState.activeTab
    demoState.activeTab = tabId
    
    local tabs = { "inventory", "equipment", "crafting" }
    for _, id in ipairs(tabs) do
        local gridEntity = demoState.grids[id]
        local isActive = (id == tabId)
        
        if gridEntity and registry:valid(gridEntity) then
            setGridVisible(gridEntity, isActive, demoState.gridOnscreenX)
            setGridItemsVisible(gridEntity, isActive)
        end
        
        local tabBoxEntity = demoState.tabButtonEntities[id]
        if tabBoxEntity and registry:valid(tabBoxEntity) then
            local buttonEntity = ui.box.GetUIEByID(registry, tabBoxEntity, "tab_" .. id)
            if buttonEntity and registry:valid(buttonEntity) then
                local newColor = isActive and util.getColor("steel_blue") or util.getColor("gray")
                
                if registry:has(buttonEntity, UIStyleConfig) then
                    local styleConfig = registry:get(buttonEntity, UIStyleConfig)
                    styleConfig.color = newColor
                    styleConfig.emboss = isActive and 2 or 1
                end
                
                if registry:has(buttonEntity, UIConfig) then
                    local uiConfig = registry:get(buttonEntity, UIConfig)
                    uiConfig.chosen = isActive
                    uiConfig.color = newColor
                end
            end
        end
    end
    
    demoState.gridEntity = demoState.grids[tabId]
    
    signal.emit("tab_changed", tabId)
    log_debug("[Demo] Switched tab: " .. oldTab .. " -> " .. tabId)
end

--------------------------------------------------------------------------------
-- Setup Stack Count Badges (demonstrates UIDecorations)
--------------------------------------------------------------------------------

function InventoryGridDemo.setupStackBadges()
    for tabId, gridEntity in pairs(demoState.grids) do
        if gridEntity and registry:valid(gridEntity) then
            local cfg = TAB_CONFIGS[tabId]
            local slotCount = cfg and (cfg.rows * cfg.cols) or 12
            demoState.stackBadges[tabId] = {}
            
            for i = 1, slotCount do
                local slotEntity = grid.getSlotEntity(gridEntity, i)
                if slotEntity and registry:valid(slotEntity) then
                    local badgeId = UIDecorations.addBadge(slotEntity, {
                        id = "stack_badge_" .. tabId .. "_" .. i,
                        text = "",
                        position = UIDecorations.Position.BOTTOM_RIGHT,
                        offset = { x = -2, y = -2 },
                        size = { w = 18, h = 18 },
                        backgroundColor = "charcoal",
                        textColor = "white",
                    })
                    demoState.stackBadges[tabId][i] = badgeId
                end
            end
        end
    end
    
    timer.every_opts({
        delay = 0.016,
        tag = "demo_badge_draw",
        group = demoState.timerGroup,
        action = function()
            InventoryGridDemo.drawStackBadges()
        end,
    })
    
    log_debug("[Demo] Stack badges created for all grids")
end

function InventoryGridDemo.setupSlotOverlays()
    for tabId, gridEntity in pairs(demoState.grids) do
        if gridEntity and registry:valid(gridEntity) then
            local cfg = TAB_CONFIGS[tabId]
            local slotCount = cfg and (cfg.rows * cfg.cols) or 12
            
            for i = 1, slotCount do
                local slotEntity = grid.getSlotEntity(gridEntity, i)
                if slotEntity and registry:valid(slotEntity) then
                    UIDecorations.addCustomOverlay(slotEntity, {
                        id = "hover_rect_" .. tabId .. "_" .. i,
                        z = -1,
                        visible = function(eid)
                            local inputState = component_cache.get(eid, InputState)
                            return inputState and inputState.cursor_hovering_target
                        end,
                        onDraw = function(eid, x, y, w, h, z)
                            if command_buffer and command_buffer.queueDrawRectangle then
                                command_buffer.queueDrawRectangle(
                                    layers.ui or "ui", function() end,
                                    x + 2, y + 2, w - 4, h - 4,
                                    Color.new(100, 150, 255, 60),
                                    z, layer.DrawCommandSpace.Screen
                                )
                            end
                        end,
                    })
                end
            end
        end
    end
    
    log_debug("[Demo] Slot hover overlays created")
end

function InventoryGridDemo.drawStackBadges()
    local activeGrid = demoState.grids[demoState.activeTab]
    if not activeGrid then return end
    
    local baseZ = (z_orders and z_orders.ui_tooltips or 800) + 100
    local cfg = TAB_CONFIGS[demoState.activeTab]
    local slotCount = cfg and (cfg.rows * cfg.cols) or 12
    
    for i = 1, slotCount do
        local slotEntity = grid.getSlotEntity(activeGrid, i)
        if slotEntity and registry:valid(slotEntity) then
            UIDecorations.draw(slotEntity, baseZ)
        end
    end
end

function InventoryGridDemo.updateStackBadge(slotIndex, gridEntity)
    gridEntity = gridEntity or demoState.gridEntity
    if not gridEntity then return end
    
    local tabId = nil
    for id, ge in pairs(demoState.grids) do
        if ge == gridEntity then tabId = id break end
    end
    if not tabId then return end
    
    local count = grid.getStackCount(gridEntity, slotIndex)
    local slotEntity = grid.getSlotEntity(gridEntity, slotIndex)
    local badges = demoState.stackBadges[tabId]
    if slotEntity and badges and badges[slotIndex] then
        local text = count > 1 and tostring(count) or ""
        UIDecorations.setBadgeText(slotEntity, badges[slotIndex], text)
    end
end

--------------------------------------------------------------------------------
-- Setup Signal Handlers
--------------------------------------------------------------------------------

function InventoryGridDemo.setupGridStateDebugTimer()
    timer.every_opts({
        delay = 2.0,
        tag = "grid_state_debug",
        group = demoState.timerGroup,
        action = function()
            local ge = demoState.grids[demoState.activeTab]
            if not ge then
                log_debug("[GRID-STATE] active grid is nil! tab=" .. tostring(demoState.activeTab))
                return
            end
            local used = grid.getUsedSlotCount(ge) or 0
            local total = grid.getCapacity(ge) or 0
            local items = grid.getAllItems(ge) or {}
            local itemCount = 0
            for k, v in pairs(items) do
                itemCount = itemCount + 1
                log_debug("[GRID-STATE] Slot " .. k .. " has item " .. tostring(v))
            end
            log_debug("[GRID-STATE] tab=" .. demoState.activeTab .. " used=" .. used .. "/" .. total .. " items=" .. itemCount)
        end,
    })
end

function InventoryGridDemo.setupDragDebugTimer()
    local lastDragState = nil
    local debugFrameCounter = 0
    
    timer.every_opts({
        delay = 0.1,
        tag = "drag_debug_timer",
        group = demoState.timerGroup,
        action = function()
            debugFrameCounter = debugFrameCounter + 1
            
            local inputState = input and input.getState and input.getState()
            if not inputState then return end
            
            local dragging = inputState.cursor_dragging_target
            local hovering = inputState.cursor_hovering_target
            local collisionList = inputState.collision_list or {}
            
            local isDragging = dragging and registry:valid(dragging)
            
            if isDragging and (lastDragState ~= "dragging" or debugFrameCounter % 10 == 0) then
                local dragT = component_cache.get(dragging, Transform)
                local collisionStr = ""
                for i, e in ipairs(collisionList) do
                    local go = component_cache.get(e, GameObject)
                    local uiCfg = component_cache.get(e, UIConfig)
                    local name = (uiCfg and uiCfg.id) or "entity"
                    local triggerOnRelease = go and go.state and go.state.triggerOnReleaseEnabled or false
                    collisionStr = collisionStr .. name .. "(tOR=" .. tostring(triggerOnRelease) .. ") "
                    if i >= 5 then collisionStr = collisionStr .. "..." break end
                end
                
                log_debug("[DRAG-DEBUG] DRAGGING entity=" .. tostring(dragging) ..
                         " pos=" .. (dragT and math.floor(dragT.actualX) or "?") .. "," .. (dragT and math.floor(dragT.actualY) or "?") ..
                         " collisions=[" .. collisionStr .. "]")
                lastDragState = "dragging"
            elseif not isDragging and lastDragState == "dragging" then
                log_debug("[DRAG-DEBUG] STOPPED dragging")
                lastDragState = nil
            end
        end,
    })
end

function InventoryGridDemo.setupSignalHandlers()
    local function registerHandler(eventName, handler)
        signal.register(eventName, handler)
        table.insert(demoState.signalHandlers, { event = eventName, handler = handler })
    end
    
    local function isOurGrid(gridEntity)
        for _, ge in pairs(demoState.grids) do
            if ge == gridEntity then return true end
        end
        return false
    end
    
    registerHandler("grid_item_added", function(gridEntity, slotIndex, itemEntity)
        if isOurGrid(gridEntity) then
            log_debug("[Demo Signal] Item added to slot " .. slotIndex)
            InventoryGridDemo.updateStackBadge(slotIndex, gridEntity)
            if playSoundEffect then
                playSoundEffect("effects", "button-click")
            end
        end
    end)
    
    registerHandler("grid_item_removed", function(gridEntity, slotIndex, itemEntity)
        if isOurGrid(gridEntity) then
            log_debug("[Demo Signal] Item removed from slot " .. slotIndex)
            InventoryGridDemo.updateStackBadge(slotIndex, gridEntity)
        end
    end)
    
    registerHandler("grid_stack_changed", function(gridEntity, slotIndex, itemEntity, oldCount, newCount)
        if isOurGrid(gridEntity) then
            log_debug("[Demo Signal] Stack at slot " .. slotIndex .. " changed: " .. oldCount .. " -> " .. newCount)
            InventoryGridDemo.updateStackBadge(slotIndex, gridEntity)
        end
    end)
    
    registerHandler("grid_item_moved", function(gridEntity, fromSlot, toSlot, itemEntity)
        if isOurGrid(gridEntity) then
            log_debug("[Demo Signal] Item moved from slot " .. fromSlot .. " to " .. toSlot)
            InventoryGridDemo.updateStackBadge(fromSlot, gridEntity)
            InventoryGridDemo.updateStackBadge(toSlot, gridEntity)
        end
    end)
    
    registerHandler("grid_items_swapped", function(gridEntity, slot1, slot2, item1, item2)
        if isOurGrid(gridEntity) then
            log_debug("[Demo Signal] Items swapped between slots " .. slot1 .. " and " .. slot2)
            InventoryGridDemo.updateStackBadge(slot1, gridEntity)
            InventoryGridDemo.updateStackBadge(slot2, gridEntity)
        end
    end)
    
    registerHandler("grid_slot_clicked", function(gridEntity, slotIndex, button, modifiers)
        if isOurGrid(gridEntity) then
            log_debug("[Demo Signal] Slot " .. slotIndex .. " clicked")
        end
    end)
    
    log_debug("[InventoryGridDemo] Signal handlers registered")
end

--------------------------------------------------------------------------------
-- Spawn Mock Cards
--------------------------------------------------------------------------------

function InventoryGridDemo.spawnMockCards()
    local screenW = globals.screenWidth()
    
    -- Card definitions
    local cards = {
        { id = "fireball", name = "Fireball", sprite = "card-new-test-action.png", element = "Fire", stackId = "fireball" },
        { id = "ice_shard", name = "Ice Shard", sprite = "card-new-test-action.png", element = "Ice", stackId = "ice_shard" },
        { id = "trigger", name = "Trigger", sprite = "card-new-test-trigger.png", element = nil, stackId = "trigger" },
        { id = "modifier", name = "Modifier", sprite = "card-new-test-modifier.png", element = nil, stackId = "modifier" },
    }
    
    local screenH = globals.screenHeight()
    local startX = screenW - 370
    local startY = screenH - 120
    
    for i, cardDef in ipairs(cards) do
        local x = startX + (i - 1) * 80
        local y = startY
        
        local entity = createSimpleCard(cardDef.sprite, x, y, cardDef)
        if entity then
            table.insert(demoState.mockCards, entity)
        end
    end
    
    log_debug("[InventoryGridDemo] Spawned " .. #demoState.mockCards .. " mock cards")
end

--------------------------------------------------------------------------------
-- Per-frame snapping: keep items centered on their slots
--------------------------------------------------------------------------------

function InventoryGridDemo.snapItemsToSlots()
    local activeGrid = demoState.grids[demoState.activeTab]
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

--------------------------------------------------------------------------------
-- Card Render Timer (batched shader pipeline rendering)
--------------------------------------------------------------------------------

local function isCardInActiveGrid(eid)
    local activeGrid = demoState.grids[demoState.activeTab]
    if not activeGrid then return true end
    
    for tabId, gridEntity in pairs(demoState.grids) do
        if gridEntity then
            local slotIndex = grid.findSlotContaining(gridEntity, eid)
            if slotIndex then
                return tabId == demoState.activeTab
            end
        end
    end
    return true
end

function InventoryGridDemo.setupCardRenderTimer()
    local UI_CARD_Z = (z_orders and z_orders.ui_tooltips or 900) + 500
    
    timer.run_every_render_frame(function()
        InventoryGridDemo.snapItemsToSlots()
        
        local batchedCardBuckets = {}
        local cardZCache = {}
        
        if not (command_buffer and command_buffer.queueDrawBatchedEntities and layers and layers.ui) then
            return
        end
        
        for eid, cardScript in pairs(demoState.cardRegistry) do
            if eid and registry:valid(eid) and isCardInActiveGrid(eid) then
                local hasPipeline = shader_pipeline and shader_pipeline.ShaderPipelineComponent
                    and registry:has(eid, shader_pipeline.ShaderPipelineComponent)
                local animComp = component_cache.get(eid, AnimationQueueComponent)
                
                if animComp then
                    animComp.drawWithLegacyPipeline = true
                end
                
                if hasPipeline and animComp and not animComp.noDraw then
                    local zToUse = UI_CARD_Z
                    if cardScript and cardScript.isBeingDragged then
                        zToUse = UI_CARD_Z + 100
                    end
                    cardZCache[eid] = zToUse
                    
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
    end, nil, "demo_card_render_timer", demoState.timerGroup)
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

function InventoryGridDemo.cleanup()
    log_debug("[InventoryGridDemo] Cleaning up...")
    
    for _, entry in ipairs(demoState.signalHandlers) do
        if entry.event and entry.handler then
            signal.remove(entry.event, entry.handler)
        end
    end
    demoState.signalHandlers = {}
    
    timer.kill_group(demoState.timerGroup)
    
    for _, entity in ipairs(demoState.mockCards) do
        if entity and registry:valid(entity) then
            registry:destroy(entity)
        end
    end
    demoState.mockCards = {}
    demoState.cardRegistry = {}
    
    for tabId, gridEntity in pairs(demoState.grids or {}) do
        if gridEntity and registry:valid(gridEntity) then
            local cfg = TAB_CONFIGS[tabId]
            local slotCount = cfg and (cfg.rows * cfg.cols) or 12
            for i = 1, slotCount do
                local slotEntity = grid.getSlotEntity(gridEntity, i)
                if slotEntity then
                    UIDecorations.cleanup(slotEntity)
                    InventoryGridInit.cleanupSlotMetadata(slotEntity)
                end
            end
            
            grid.cleanup(gridEntity)
            if cfg then
                dsl.cleanupGrid(cfg.id)
            end
            
            if ui.box and ui.box.Remove then
                ui.box.Remove(registry, gridEntity)
            end
        end
    end
    demoState.grids = {}
    demoState.gridEntity = nil
    demoState.stackBadges = {}
    
    if demoState.infoBoxEntity and ui.box and ui.box.Remove then
        ui.box.Remove(registry, demoState.infoBoxEntity)
        demoState.infoBoxEntity = nil
    end
    
    if demoState.customPanelEntity and ui.box and ui.box.Remove then
        ui.box.Remove(registry, demoState.customPanelEntity)
        demoState.customPanelEntity = nil
    end
    demoState.customPanelState = nil
    
    if demoState.sortButtonsEntity and ui.box and ui.box.Remove then
        ui.box.Remove(registry, demoState.sortButtonsEntity)
        demoState.sortButtonsEntity = nil
    end
    demoState.sortBy = nil
    demoState.sortAscending = true
    
    for _, tabEntity in ipairs(demoState.tabEntities or {}) do
        if tabEntity and registry:valid(tabEntity) and ui.box and ui.box.Remove then
            ui.box.Remove(registry, tabEntity)
        end
    end
    demoState.tabEntities = {}
    demoState.activeTab = "inventory"
    
    log_debug("[InventoryGridDemo] Cleanup complete")
end

--------------------------------------------------------------------------------
-- Toggle Demo (for testing from console)
--------------------------------------------------------------------------------

function InventoryGridDemo.toggle()
    if demoState.gridEntity then
        InventoryGridDemo.cleanup()
    else
        InventoryGridDemo.init()
    end
end

return InventoryGridDemo
