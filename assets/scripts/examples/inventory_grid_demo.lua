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
    mockCards = {},
    signalHandlers = {},
    stackBadges = {},
    timerGroup = "inventory_demo",
    cardRegistry = {}, -- Track cards for shader rendering
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
    
    if ObjectAttachedToUITag and not registry:has(entity, ObjectAttachedToUITag) then
        registry:emplace(entity, ObjectAttachedToUITag)
    end
    
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
    
    local gridX = screenW - 380
    local gridY = 80
    
    InventoryGridDemo.createMainGrid(gridX, gridY)
    InventoryGridDemo.createInfoBox(gridX - 220, gridY)
    InventoryGridDemo.createCustomPanel(gridX - 220, gridY + 300)
    InventoryGridDemo.createBackgroundDemo(gridX - 220, gridY + 420)
    InventoryGridDemo.setupSignalHandlers()
    
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
-- Create Custom Panel Demo (demonstrates dsl.customPanel with onDraw)
--------------------------------------------------------------------------------

function InventoryGridDemo.createCustomPanel(x, y)
    local customDef = dsl.customPanel {
        id = "demo_custom_panel",
        minWidth = 120,
        minHeight = 80,
        config = {
            color = "midnight_blue",
            hover = true,
            canCollide = true,
        },
        onDraw = function(entity, px, py, pw, ph, z)
            if command_buffer and command_buffer.queueDrawRectangle then
                local pulseAlpha = math.abs(math.sin((globals.time or 0) * 2)) * 0.3 + 0.2
                local pulseColor = Color and Color.new(100, 200, 255, math.floor(pulseAlpha * 255)) or nil
                if pulseColor then
                    command_buffer.queueDrawRectangle(
                        layers.ui or "ui",
                        function() end,
                        px + 4, py + 4, pw - 8, ph - 8,
                        pulseColor, z + 1, layer.DrawCommandSpace.Screen
                    )
                end
            end
        end,
        onUpdate = function(entity, dt)
        end,
    }
    
    local panelContainer = dsl.vbox {
        config = { padding = 4 },
        children = {
            dsl.text("Custom Panel", { fontSize = 10, color = "cyan" }),
            customDef,
            dsl.text("(animated draw)", { fontSize = 8, color = "light_gray" }),
        },
    }
    
    demoState.customPanelEntity = dsl.spawn({ x = x, y = y }, panelContainer, "ui", 100)
    ui.box.set_draw_layer(demoState.customPanelEntity, "ui")
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
        config = { padding = 4 },
        children = {
            dsl.text("UIBackground", { fontSize = 10, color = "gold" }),
            buttonDef,
            dsl.text("(state changes)", { fontSize = 8, color = "light_gray" }),
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
                    end, z, layer.DrawCommandSpace.Screen)
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
