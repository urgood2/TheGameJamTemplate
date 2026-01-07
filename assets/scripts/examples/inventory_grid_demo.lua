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
    gridEntity = nil,
    infoBoxEntity = nil,
    customPanelEntity = nil,
    backgroundDemoEntity = nil,
    sortButtonsEntity = nil,
    decorationDemoEntity = nil,
    tabEntities = {},
    mockCards = {},
    signalHandlers = {},
    stackBadges = {},
    timerGroup = "inventory_demo",
    cardRegistry = {},
    customPanelState = nil,
    decoratedElementHovered = false,
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
        
        local function safeSetMethod(name, fn)
            local ok = pcall(function() go.methods[name] = fn end)
            if not ok then
                log_warn("[DRAG-DEBUG] Card " .. cardData.name .. " failed to set " .. name)
            end
        end
        
        safeSetMethod("onHoverStart", function(e)
            log_debug("[DRAG-DEBUG] Card " .. cardData.name .. " HOVER START")
        end)
        safeSetMethod("onHoverEnd", function(e)
            log_debug("[DRAG-DEBUG] Card " .. cardData.name .. " HOVER END")
        end)
        safeSetMethod("onDragStart", function(e)
            log_debug("[DRAG-DEBUG] Card " .. cardData.name .. " DRAG START at " .. 
                      (component_cache.get(e, Transform) and component_cache.get(e, Transform).actualX or "?") .. "," ..
                      (component_cache.get(e, Transform) and component_cache.get(e, Transform).actualY or "?"))
            if demoState.cardRegistry[e] then
                demoState.cardRegistry[e].isBeingDragged = true
            end
        end)
        safeSetMethod("onDragEnd", function(e)
            log_debug("[DRAG-DEBUG] Card " .. cardData.name .. " DRAG END at " ..
                      (component_cache.get(e, Transform) and component_cache.get(e, Transform).actualX or "?") .. "," ..
                      (component_cache.get(e, Transform) and component_cache.get(e, Transform).actualY or "?"))
            if demoState.cardRegistry[e] then
                demoState.cardRegistry[e].isBeingDragged = false
            end
        end)
        safeSetMethod("onClick", function(e)
            log_debug("[DRAG-DEBUG] Card " .. cardData.name .. " CLICKED")
        end)
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
    
    local gridX = screenW - 380
    local gridY = 80
    
    InventoryGridDemo.createPostItTabs(gridX, gridY, 320)
    InventoryGridDemo.createMainGrid(gridX, gridY)
    InventoryGridDemo.createInfoBox(gridX - 220, gridY)
    InventoryGridDemo.createSortButtons(gridX, gridY + 360)
    InventoryGridDemo.createCustomPanel(gridX - 220, gridY + 310)
    InventoryGridDemo.createBackgroundDemo(gridX - 220, gridY + 470)
    InventoryGridDemo.createDecorationDemo(gridX - 220, gridY + 580)
    InventoryGridDemo.setupSignalHandlers()
    InventoryGridDemo.setupDragDebugTimer()
    
    timer.after_opts({
        delay = 0.3,
        tag = "demo_spawn_cards",
        group = demoState.timerGroup,
        action = function()
            InventoryGridDemo.spawnMockCards()
            InventoryGridDemo.setupStackBadges()
            InventoryGridDemo.setupCardRenderTimer()
        end,
    })
    
    log_debug("[InventoryGridDemo] Initialized successfully")
end

--------------------------------------------------------------------------------
-- Create Main Inventory Grid (3x4)
--------------------------------------------------------------------------------

function InventoryGridDemo.createMainGrid(x, y)
    local gridDef = dsl.inventoryGrid {
        id = "demo_inventory",
        rows = 3,
        cols = 4,
        slotSize = { w = 72, h = 100 },
        slotSpacing = 6,
        
        config = {
            allowDragIn = true,
            allowDragOut = true,
            stackable = true,
            maxStackSize = 5,
            slotColor = "gray",
            slotEmboss = 2,
            padding = 8,
            backgroundColor = "blackberry",
        },
        
        -- Per-slot configuration
        slots = {
            -- Slot 1: Fire cards only (red tint)
            [1] = {
                filter = function(item)
                    local script = getScriptTableFromEntityID(item)
                    return script and script.element == "Fire"
                end,
                color = util.getColor("fiery_red"),
            },
            -- Slot 2: Ice cards only (blue tint)
            [2] = {
                filter = function(item)
                    local script = getScriptTableFromEntityID(item)
                    return script and script.element == "Ice"
                end,
                color = util.getColor("baby_blue"),
            },
            -- Slot 12: Locked slot (gray)
            [12] = {
                locked = true,
                color = util.getColor("gray"),
            },
        },
        
        onSlotChange = function(gridEntity, slotIndex, oldItem, newItem)
            log_debug("[Demo] Slot " .. slotIndex .. " changed")
        end,
        
        onSlotClick = function(gridEntity, slotIndex, button)
            log_debug("[Demo] Slot " .. slotIndex .. " clicked")
        end,
    }
    
    -- Spawn grid
    demoState.gridEntity = dsl.spawn({ x = x, y = y }, gridDef, "ui", 100)
    ui.box.set_draw_layer(demoState.gridEntity, "ui")
    
    -- Initialize grid data structure
    local InventoryGridInit = require("ui.inventory_grid_init")
    local success = InventoryGridInit.initializeIfGrid(demoState.gridEntity, "demo_inventory")
    
    if success then
        log_debug("[InventoryGridDemo] Grid initialized successfully")
    else
        log_warn("[InventoryGridDemo] Grid initialization failed!")
    end
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
            dsl.dynamicText(function()
                local used = grid.getUsedSlotCount(demoState.gridEntity) or 0
                local total = grid.getCapacity(demoState.gridEntity) or 12
                return "Slots: " .. used .. "/" .. total
            end, 12, nil, { id = "stats_slots", color = "white" }),
            dsl.dynamicText(function()
                local items = grid.getAllItems(demoState.gridEntity) or {}
                local count = 0
                for _ in pairs(items) do count = count + 1 end
                return "Items: " .. count
            end, 12, nil, { id = "stats_items", color = "white" }),
        },
    }
    
    demoState.infoBoxEntity = dsl.spawn({ x = x, y = y }, infoDef, "ui", 100)
    ui.box.set_draw_layer(demoState.infoBoxEntity, "ui")
end

--------------------------------------------------------------------------------
-- Create Custom Panel Demo (demonstrates immediate-mode rendering with HoverRegistry)
--------------------------------------------------------------------------------

function InventoryGridDemo.createCustomPanel(x, y)
    local HoverRegistry = require("ui.hover_registry")
    
    demoState.customPanelState = {
        x = x,
        y = y,
        w = 200,
        h = 140,
        isHovered = false,
        iconHovered = false,
    }
    
    local panelContainer = dsl.vbox {
        config = { 
            id = "demo_custom_panel_container",
            padding = 8,
            color = "blackberry",
            emboss = 2,
            minWidth = 200,
            minHeight = 140,
        },
        children = {
            dsl.text("Custom Panel", { fontSize = 12, color = "cyan", shadow = true }),
            dsl.spacer(4),
            dsl.text("Immediate-mode rendering", { fontSize = 10, color = "light_gray" }),
            dsl.text("+ HoverRegistry", { fontSize = 10, color = "light_gray" }),
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
    
    local panelX = state.x + 8
    local panelY = state.y + 60
    local panelW = state.w - 16
    local panelH = 60
    
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
-- Create Background Demo (demonstrates UIBackground state-based backgrounds)
--------------------------------------------------------------------------------

function InventoryGridDemo.createBackgroundDemo(x, y)
    local buttonDef = dsl.button("Hover Me!", {
        id = "demo_bg_button",
        minWidth = 120,
        minHeight = 40,
        color = "gray",
        hover = true,
    })
    
    local container = dsl.vbox {
        config = { 
            padding = 8,
            color = "blackberry",
            emboss = 2,
        },
        children = {
            dsl.text("UIBackground", { fontSize = 12, color = "gold", shadow = true }),
            dsl.spacer(4),
            buttonDef,
            dsl.spacer(4),
            dsl.text("(state changes)", { fontSize = 10, color = "light_gray" }),
        },
    }
    
    demoState.backgroundDemoEntity = dsl.spawn({ x = x, y = y }, container, "ui", 100)
    ui.box.set_draw_layer(demoState.backgroundDemoEntity, "ui")
    
    timer.after_opts({
        delay = 0.1,
        tag = "setup_bg_demo",
        group = demoState.timerGroup,
        action = function()
            local buttonEntity = ui.box.GetUIEByID(registry, demoState.backgroundDemoEntity, "demo_bg_button")
            if buttonEntity and registry:valid(buttonEntity) then
                UIBackground.apply(buttonEntity, {
                    normal = { type = "color", color = "gray" },
                    hover = { type = "color", color = "steel_blue" },
                    pressed = { type = "color", color = "midnight_blue" },
                })
                log_debug("[Demo] UIBackground applied to button")
            end
        end,
    })
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
            }),
            dsl.spacer(4),
            dsl.button("Type" .. getSortIndicator("element"), {
                id = "sort_type_btn",
                minWidth = 60,
                minHeight = 24,
                fontSize = 11,
                color = demoState.sortBy == "element" and "steel_blue" or "gray",
                hover = true,
            }),
        },
    }
    
    demoState.sortButtonsEntity = dsl.spawn({ x = x, y = y }, sortDef, "ui", 100)
    ui.box.set_draw_layer(demoState.sortButtonsEntity, "ui")
    
    timer.after_opts({
        delay = 0.1,
        tag = "setup_sort_buttons",
        group = demoState.timerGroup,
        action = function()
            local nameBtn = ui.box.GetUIEByID(registry, demoState.sortButtonsEntity, "sort_name_btn")
            local typeBtn = ui.box.GetUIEByID(registry, demoState.sortButtonsEntity, "sort_type_btn")
            
            if nameBtn then
                local go = component_cache.get(nameBtn, GameObject)
                if go then
                    go.state.collisionEnabled = true
                    pcall(function()
                        go.methods.onClick = function()
                            InventoryGridDemo.toggleSort("name")
                        end
                    end)
                end
            end
            
            if typeBtn then
                local go = component_cache.get(typeBtn, GameObject)
                if go then
                    go.state.collisionEnabled = true
                    pcall(function()
                        go.methods.onClick = function()
                            InventoryGridDemo.toggleSort("element")
                        end
                    end)
                end
            end
        end,
    })
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

function InventoryGridDemo.applySorting()
    if not demoState.sortBy or not demoState.gridEntity then return end
    
    local items = grid.getItemList(demoState.gridEntity)
    if not items or #items == 0 then
        log_debug("[Demo] No items to sort")
        return
    end
    
    local itemsWithData = {}
    for _, item in ipairs(items) do
        local script = getScriptTableFromEntityID(item.entity)
        if script then
            table.insert(itemsWithData, {
                entity = item.entity,
                slotIndex = item.slotIndex,
                name = script.name or "",
                element = script.element or "",
            })
        end
    end
    
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
        grid.removeItemFromSlot(demoState.gridEntity, item.slotIndex)
    end
    
    local targetSlot = 1
    for _, item in ipairs(itemsWithData) do
        while grid.isSlotLocked(demoState.gridEntity, targetSlot) and targetSlot <= 12 do
            targetSlot = targetSlot + 1
        end
        if targetSlot <= 12 then
            grid.addItem(demoState.gridEntity, item.entity, targetSlot)
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
    
    for i, tab in ipairs(tabs) do
        local isActive = (tab.id == demoState.activeTab)
        local tabX = startX + (i - 1) * (tabWidth + tabSpacing)
        
        local tabDef = dsl.hbox {
            config = {
                id = "tab_" .. tab.id,
                padding = 6,
                minWidth = tabWidth,
                minHeight = tabHeight,
                color = isActive and "steel_blue" or "gray",
                emboss = isActive and 2 or 1,
                hover = true,
                choice = true,
                chosen = isActive,
                group = "demo_tabs",
            },
            children = {
                dsl.text(tab.label, { 
                    fontSize = 11, 
                    color = isActive and "white" or "light_gray",
                    shadow = isActive,
                }),
            },
        }
        
        local tabEntity = dsl.spawn({ x = tabX, y = tabY }, tabDef, "ui", 50)
        ui.box.set_draw_layer(tabEntity, "ui")
        
        table.insert(demoState.tabEntities, tabEntity)
        
        timer.after_opts({
            delay = 0.1 + i * 0.02,
            tag = "setup_tab_" .. tab.id,
            group = demoState.timerGroup,
            action = function()
                local tabBtn = ui.box.GetUIEByID(registry, tabEntity, "tab_" .. tab.id)
                if tabBtn then
                    local go = component_cache.get(tabBtn, GameObject)
                    if go then
                        go.state.collisionEnabled = true
                        pcall(function()
                            go.methods.onClick = function()
                                InventoryGridDemo.switchTab(tab.id)
                            end
                        end)
                    end
                end
            end,
        })
    end
    
    log_debug("[Demo] Created " .. #tabs .. " post-it tabs")
end

function InventoryGridDemo.switchTab(tabId)
    if demoState.activeTab == tabId then return end
    
    local oldTab = demoState.activeTab
    demoState.activeTab = tabId
    
    for _, tabEntity in ipairs(demoState.tabEntities) do
        if tabEntity and registry:valid(tabEntity) then
            local uiConfig = component_cache.get(tabEntity, UIConfig)
            if uiConfig then
                local isActive = uiConfig.id and uiConfig.id:find(tabId)
                uiConfig.chosen = isActive or false
                uiConfig.color = isActive and util.getColor("steel_blue") or util.getColor("gray")
                uiConfig.emboss = isActive and 2 or 1
            end
            
            local children = ui.box.GetAllChildren(registry, tabEntity)
            for _, child in ipairs(children or {}) do
                local childConfig = component_cache.get(child, UIConfig)
                if childConfig and childConfig.id and childConfig.id:find("tab_") then
                    local isActive = childConfig.id:find(tabId)
                    childConfig.chosen = isActive or false
                    childConfig.color = isActive and util.getColor("steel_blue") or util.getColor("gray")
                end
            end
        end
    end
    
    signal.emit("tab_changed", tabId)
    log_debug("[Demo] Switched tab: " .. oldTab .. " -> " .. tabId)
end

--------------------------------------------------------------------------------
-- Create Decoration Demo (glowing border + badge)
--------------------------------------------------------------------------------

function InventoryGridDemo.createDecorationDemo(x, y)
    local container = dsl.vbox {
        config = {
            id = "decoration_demo_container",
            padding = 12,
            color = "midnight_blue",
            emboss = 2,
            minWidth = 150,
            minHeight = 100,
        },
        children = {
            dsl.text("Decoration Demo", { fontSize = 12, color = "cyan", shadow = true }),
            dsl.spacer(8),
            dsl.hbox {
                config = {
                    id = "decorated_element",
                    padding = 16,
                    color = "blackberry",
                    emboss = 1,
                    minWidth = 100,
                    minHeight = 50,
                },
                children = {
                    dsl.text("Hover me!", { fontSize = 11, color = "white" }),
                },
            },
        },
    }
    
    demoState.decorationDemoEntity = dsl.spawn({ x = x, y = y }, container, "ui", 100)
    ui.box.set_draw_layer(demoState.decorationDemoEntity, "ui")
    
    timer.after_opts({
        delay = 0.15,
        tag = "setup_decoration_demo",
        group = demoState.timerGroup,
        action = function()
            local decoratedElement = ui.box.GetUIEByID(registry, demoState.decorationDemoEntity, "decorated_element")
            if not decoratedElement or not registry:valid(decoratedElement) then
                log_warn("[Demo] Could not find decorated_element")
                return
            end
            
            UIDecorations.addBadge(decoratedElement, {
                id = "demo_badge",
                text = "NEW",
                position = UIDecorations.Position.TOP_RIGHT,
                offset = { x = 8, y = -8 },
                size = { w = 32, h = 18 },
                backgroundColor = "fiery_red",
                textColor = "white",
            })
            
            demoState.decoratedElementHovered = false
            
            UIDecorations.addCustomOverlay(decoratedElement, {
                id = "glow_border",
                z = 5,
                visible = function()
                    return demoState.decoratedElementHovered
                end,
                onDraw = function(entity, px, py, pw, ph, z)
                    local pulseTime = (globals.time or 0) * 3
                    local pulseAlpha = math.abs(math.sin(pulseTime)) * 0.5 + 0.5
                    local glowColor = Color.new(100, 200, 255, math.floor(pulseAlpha * 200))
                    
                    if command_buffer and command_buffer.queueDrawSteppedRoundedRect then
                        command_buffer.queueDrawSteppedRoundedRect(layers.ui or "ui", function(c)
                            c.x = px + pw / 2
                            c.y = py + ph / 2
                            c.w = pw + 8
                            c.h = ph + 8
                            c.fillColor = Color.new(0, 0, 0, 0)
                            c.borderColor = glowColor
                            c.borderWidth = 3
                            c.numSteps = 4
                        end, z, layer.DrawCommandSpace.Screen)
                    end
                end,
            })
            
            local go = component_cache.get(decoratedElement, GameObject)
            if go then
                go.state.hoverEnabled = true
                go.state.collisionEnabled = true
                pcall(function()
                    go.methods.onHover = function()
                        demoState.decoratedElementHovered = true
                    end
                    go.methods.onStopHover = function()
                        demoState.decoratedElementHovered = false
                    end
                end)
            end
            
            timer.every_opts({
                delay = 0.016,
                tag = "decoration_demo_render",
                group = demoState.timerGroup,
                action = function()
                    if decoratedElement and registry:valid(decoratedElement) then
                        local baseZ = (z_orders and z_orders.ui_tooltips or 800) + 150
                        UIDecorations.draw(decoratedElement, baseZ)
                    end
                end,
            })
            
            log_debug("[Demo] Decoration demo setup complete")
        end,
    })
end

--------------------------------------------------------------------------------
-- Setup Stack Count Badges (demonstrates UIDecorations)
--------------------------------------------------------------------------------

function InventoryGridDemo.setupStackBadges()
    for i = 1, 12 do
        local slotEntity = grid.getSlotEntity(demoState.gridEntity, i)
        if slotEntity and registry:valid(slotEntity) then
            local badgeId = UIDecorations.addBadge(slotEntity, {
                id = "stack_badge_" .. i,
                text = "",
                position = UIDecorations.Position.BOTTOM_RIGHT,
                offset = { x = -2, y = -2 },
                size = { w = 18, h = 18 },
                backgroundColor = "charcoal",
                textColor = "white",
            })
            demoState.stackBadges[i] = badgeId
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
    
    log_debug("[Demo] Stack badges created for all slots")
end

function InventoryGridDemo.drawStackBadges()
    if not demoState.gridEntity then return end
    
    local baseZ = (z_orders and z_orders.ui_tooltips or 800) + 100
    
    for i = 1, 12 do
        local slotEntity = grid.getSlotEntity(demoState.gridEntity, i)
        if slotEntity and registry:valid(slotEntity) then
            UIDecorations.draw(slotEntity, baseZ)
        end
    end
end

function InventoryGridDemo.updateStackBadge(slotIndex)
    local count = grid.getStackCount(demoState.gridEntity, slotIndex)
    local slotEntity = grid.getSlotEntity(demoState.gridEntity, slotIndex)
    if slotEntity and demoState.stackBadges[slotIndex] then
        local text = count > 1 and tostring(count) or ""
        UIDecorations.setBadgeText(slotEntity, demoState.stackBadges[slotIndex], text)
    end
end

--------------------------------------------------------------------------------
-- Setup Signal Handlers
--------------------------------------------------------------------------------

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
    
    registerHandler("grid_item_added", function(gridEntity, slotIndex, itemEntity)
        if gridEntity == demoState.gridEntity then
            log_debug("[Demo Signal] Item added to slot " .. slotIndex)
            InventoryGridDemo.updateStackBadge(slotIndex)
            if playSoundEffect then
                playSoundEffect("effects", "button-click")
            end
        end
    end)
    
    registerHandler("grid_item_removed", function(gridEntity, slotIndex, itemEntity)
        if gridEntity == demoState.gridEntity then
            log_debug("[Demo Signal] Item removed from slot " .. slotIndex)
            InventoryGridDemo.updateStackBadge(slotIndex)
        end
    end)
    
    registerHandler("grid_stack_changed", function(gridEntity, slotIndex, itemEntity, oldCount, newCount)
        if gridEntity == demoState.gridEntity then
            log_debug("[Demo Signal] Stack at slot " .. slotIndex .. " changed: " .. oldCount .. " -> " .. newCount)
            InventoryGridDemo.updateStackBadge(slotIndex)
        end
    end)
    
    registerHandler("grid_slot_clicked", function(gridEntity, slotIndex, button, modifiers)
        if gridEntity == demoState.gridEntity then
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
-- Card Render Timer (batched shader pipeline rendering)
--------------------------------------------------------------------------------

function InventoryGridDemo.setupCardRenderTimer()
    local UI_CARD_Z = (z_orders and z_orders.ui_tooltips or 900) + 500
    
    timer.run_every_render_frame(function()
        local batchedCardBuckets = {}
        local cardZCache = {}
        
        if not (command_buffer and command_buffer.queueDrawBatchedEntities and layers and layers.ui) then
            return
        end
        
        for eid, cardScript in pairs(demoState.cardRegistry) do
            if eid and registry:valid(eid) then
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
    
    if demoState.gridEntity then
        for i = 1, 12 do
            local slotEntity = grid.getSlotEntity(demoState.gridEntity, i)
            if slotEntity then
                UIDecorations.cleanup(slotEntity)
                InventoryGridInit.cleanupSlotMetadata(slotEntity)
            end
        end
        
        grid.cleanup(demoState.gridEntity)
        dsl.cleanupGrid("demo_inventory")
        
        if ui.box and ui.box.Remove then
            ui.box.Remove(registry, demoState.gridEntity)
        end
        demoState.gridEntity = nil
    end
    demoState.stackBadges = {}
    
    if demoState.backgroundDemoEntity then
        local buttonEntity = ui.box.GetUIEByID(registry, demoState.backgroundDemoEntity, "demo_bg_button")
        if buttonEntity then
            UIBackground.remove(buttonEntity)
        end
        if ui.box and ui.box.Remove then
            ui.box.Remove(registry, demoState.backgroundDemoEntity)
        end
        demoState.backgroundDemoEntity = nil
    end
    
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
    
    if demoState.decorationDemoEntity then
        local decoratedElement = ui.box.GetUIEByID(registry, demoState.decorationDemoEntity, "decorated_element")
        if decoratedElement then
            UIDecorations.cleanup(decoratedElement)
        end
        if ui.box and ui.box.Remove then
            ui.box.Remove(registry, demoState.decorationDemoEntity)
        end
        demoState.decorationDemoEntity = nil
    end
    demoState.decoratedElementHovered = false
    
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
