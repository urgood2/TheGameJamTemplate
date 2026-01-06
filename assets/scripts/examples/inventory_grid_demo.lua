--[[
================================================================================
Inventory Grid Demo
================================================================================
Demonstrates all features of the new inventory grid system:
- dsl.inventoryGrid() with drag-drop slots
- dsl.customPanel() with custom rendering
- UIBackground for per-element backgrounds with states
- UIDecorations for badges and overlays
- Signal events for grid interactions

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
local UIBackground = require("ui.ui_background")
local UIDecorations = require("ui.ui_decorations")
local signal = require("external.hump.signal")
local component_cache = require("core.component_cache")
local timer = require("core.timer")

-- Demo state
local demoState = {
    gridEntity = nil,
    customPanelEntity = nil,
    infoBoxEntity = nil,
    mockCards = {},
    selectedSlot = nil,
    signalHandlers = {},
    timerGroup = "inventory_demo",
}

-- Sprite references (using existing assets)
local SPRITES = {
    cardAction = "card-new-test-action.png",
    cardTrigger = "card-new-test-trigger.png", 
    cardModifier = "card-new-test-modifier.png",
    cardBack = "card_back.png",
    iconStar = "modern_icons_363.png",
    iconFire = "modern_icons_102.png",
    iconIce = "modern_icons_103.png",
    iconLock = "modern_icons_116.png",
}

-- Card definitions for mock items
local MOCK_CARDS = {
    { id = "fireball", name = "Fireball", sprite = "card-new-test-action.png", element = "Fire", stackId = "fireball" },
    { id = "ice_shard", name = "Ice Shard", sprite = "card-new-test-action.png", element = "Ice", stackId = "ice_shard" },
    { id = "trigger_click", name = "On Click", sprite = "card-new-test-trigger.png", element = nil, stackId = "trigger_click" },
    { id = "modifier_double", name = "Double Cast", sprite = "card-new-test-modifier.png", element = nil, stackId = "modifier_double" },
    { id = "heal", name = "Heal", sprite = "card-new-test-action.png", element = "Holy", stackId = "heal" },
}

--------------------------------------------------------------------------------
-- Helper: Create a mock card entity
--------------------------------------------------------------------------------

local function createMockCard(cardDef, x, y)
    -- Create animated sprite entity
    local entity = animation_system.createAnimatedObjectWithTransform(
        cardDef.sprite, true, x or 0, y or 0, nil, true
    )
    
    -- Resize to card size
    animation_system.resizeAnimationObjectsInEntityToFit(entity, 60, 84)
    
    -- Setup GameObject for drag-drop
    local go = component_cache.get(entity, GameObject)
    if go then
        go.state.dragEnabled = true
        go.state.collisionEnabled = true
        go.state.hoverEnabled = true
        
        -- Store card data in config
        go.config = go.config or {}
        go.config.cardData = cardDef
    end
    
    -- Store script-like data for stacking
    local script = {
        entity = entity,
        id = cardDef.id,
        name = cardDef.name,
        element = cardDef.element,
        stackId = cardDef.stackId,
        category = "card",
    }
    
    -- Register with script table system if available
    if setScriptTableForEntityID then
        setScriptTableForEntityID(entity, script)
    end
    
    return entity, script
end

--------------------------------------------------------------------------------
-- Initialize Demo
--------------------------------------------------------------------------------

function InventoryGridDemo.init()
    log_debug("[InventoryGridDemo] Initializing...")
    
    local screenW = globals.screenWidth()
    local screenH = globals.screenHeight()
    
    -- Position demo on right side of screen
    local demoX = screenW - 400
    local demoY = 100
    
    InventoryGridDemo.createMainGrid(demoX, demoY)
    InventoryGridDemo.createCustomPanel(demoX, demoY + 350)
    InventoryGridDemo.createInfoBox(demoX - 220, demoY)
    InventoryGridDemo.setupSignalHandlers()
    InventoryGridDemo.spawnMockCards()
    
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
            
            -- Grid-wide filter: only accept cards
            filter = function(item, slotIndex)
                local script = getScriptTableFromEntityID(item)
                return script and script.category == "card"
            end,
            
            slotColor = "darkgray",
            slotEmboss = 2,
            padding = 8,
            backgroundColor = "blackberry",
        },
        
        -- Per-slot configuration
        slots = {
            -- Slot 1: Fire cards only (with special background)
            [1] = {
                filter = function(item)
                    local script = getScriptTableFromEntityID(item)
                    return script and script.element == "Fire"
                end,
                color = util.getColor("fiery_red"),
                tooltip = { title = "Fire Slot", body = "Only fire element cards" },
            },
            -- Slot 2: Ice cards only
            [2] = {
                filter = function(item)
                    local script = getScriptTableFromEntityID(item)
                    return script and script.element == "Ice"
                end,
                color = util.getColor("baby_blue"),
                tooltip = { title = "Ice Slot", body = "Only ice element cards" },
            },
            -- Slot 12: Locked slot
            [12] = {
                locked = true,
                color = util.getColor("gray"),
                tooltip = { title = "Locked", body = "This slot is locked" },
            },
        },
        
        onSlotChange = function(gridEntity, slotIndex, oldItem, newItem)
            log_debug("[Demo] Slot " .. slotIndex .. " changed")
            InventoryGridDemo.updateInfoBox()
        end,
        
        onSlotClick = function(gridEntity, slotIndex, button)
            log_debug("[Demo] Slot " .. slotIndex .. " clicked with " .. button)
            demoState.selectedSlot = slotIndex
            InventoryGridDemo.updateInfoBox()
        end,
    }
    
    -- Spawn grid
    demoState.gridEntity = dsl.spawn({ x = x, y = y }, gridDef, "ui", 100)
    
    -- Initialize grid data
    local InventoryGridInit = require("ui.inventory_grid_init")
    InventoryGridInit.initializeIfGrid(demoState.gridEntity)
    
    -- Add decorations to slots
    InventoryGridDemo.decorateSlots()
    
    log_debug("[InventoryGridDemo] Grid created at " .. x .. ", " .. y)
end

--------------------------------------------------------------------------------
-- Decorate Slots with Badges and Overlays
--------------------------------------------------------------------------------

function InventoryGridDemo.decorateSlots()
    -- Add element icons to filtered slots
    local slot1Entity = grid.getSlotEntity(demoState.gridEntity, 1)
    if slot1Entity then
        UIDecorations.addBadge(slot1Entity, {
            id = "fire_badge",
            icon = SPRITES.iconFire,
            position = "top_left",
            offset = { x = 2, y = 2 },
            size = { w = 16, h = 16 },
        })
    end
    
    local slot2Entity = grid.getSlotEntity(demoState.gridEntity, 2)
    if slot2Entity then
        UIDecorations.addBadge(slot2Entity, {
            id = "ice_badge",
            icon = SPRITES.iconIce,
            position = "top_left",
            offset = { x = 2, y = 2 },
            size = { w = 16, h = 16 },
        })
    end
    
    -- Add lock icon to locked slot
    local slot12Entity = grid.getSlotEntity(demoState.gridEntity, 12)
    if slot12Entity then
        UIDecorations.addBadge(slot12Entity, {
            id = "lock_badge",
            icon = SPRITES.iconLock,
            position = "center",
            size = { w = 24, h = 24 },
        })
    end
end

--------------------------------------------------------------------------------
-- Create Custom Panel (demonstrates dsl.customPanel)
--------------------------------------------------------------------------------

function InventoryGridDemo.createCustomPanel(x, y)
    local panelDef = dsl.customPanel {
        id = "demo_custom_panel",
        minWidth = 300,
        minHeight = 80,
        
        onDraw = function(self, px, py, pw, ph, dt)
            local z = 101
            local space = "screen"
            
            -- Draw background
            command_buffer.queueDrawRoundedRect(layers.ui, function(c)
                c.x = px
                c.y = py
                c.w = pw
                c.h = ph
                c.fillColor = Col(30, 30, 40, 230)
                c.borderColor = util.getColor("apricot_cream")
                c.borderWidth = 2
                c.cornerRadius = 8
            end, z, space)
            
            -- Draw title
            command_buffer.queueDrawText(layers.ui, function(c)
                c.text = "Custom Panel Demo"
                c.x = px + 10
                c.y = py + 10
                c.fontSize = 16
                c.color = util.getColor("white")
            end, z + 1, space)
            
            -- Draw animated element
            local time = globals.main_menu_elapsed_time or 0
            local pulse = 0.8 + 0.2 * math.sin(time * 3)
            
            command_buffer.queueDrawCircleFilled(layers.ui, function(c)
                c.x = px + pw - 40
                c.y = py + ph / 2
                c.radius = 15 * pulse
                c.color = util.getColor("mint_green")
            end, z + 1, space)
            
            -- Draw selection indicator if slot selected
            if demoState.selectedSlot then
                command_buffer.queueDrawText(layers.ui, function(c)
                    c.text = "Selected: Slot " .. demoState.selectedSlot
                    c.x = px + 10
                    c.y = py + 35
                    c.fontSize = 12
                    c.color = util.getColor("gold")
                end, z + 1, space)
            end
        end,
        
        onUpdate = function(self, dt)
            -- Custom update logic here
        end,
        
        config = {
            hover = true,
            canCollide = true,
        },
    }
    
    demoState.customPanelEntity = dsl.spawn({ x = x, y = y }, panelDef, "ui", 100)
    
    log_debug("[InventoryGridDemo] Custom panel created")
end

--------------------------------------------------------------------------------
-- Create Info Box (demonstrates UIBackground with states)
--------------------------------------------------------------------------------

function InventoryGridDemo.createInfoBox(x, y)
    local infoDef = dsl.vbox {
        config = {
            id = "demo_info_box",
            color = util.getColor("blackberry"),
            padding = 12,
            emboss = 3,
            minWidth = 200,
            minHeight = 300,
        },
        children = {
            dsl.text("Inventory Demo", { fontSize = 18, color = "white", shadow = true }),
            dsl.spacer(10),
            dsl.divider("horizontal", { color = "apricot_cream", thickness = 1, length = 180 }),
            dsl.spacer(10),
            dsl.text("Drag cards between slots", { fontSize = 12, color = "light_gray" }),
            dsl.text("Stack identical cards (max 5)", { fontSize = 12, color = "light_gray" }),
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
    
    -- Apply background with hover state
    UIBackground.apply(demoState.infoBoxEntity, {
        normal = {
            type = "color",
            color = "blackberry",
        },
        hover = {
            type = "color", 
            color = "plum",
        },
    })
    
    -- Add star badge to info box
    UIDecorations.addBadge(demoState.infoBoxEntity, {
        id = "info_star",
        icon = SPRITES.iconStar,
        position = "top_right",
        offset = { x = -8, y = 8 },
        size = { w = 20, h = 20 },
    })
    
    log_debug("[InventoryGridDemo] Info box created")
end

--------------------------------------------------------------------------------
-- Update Info Box (refresh dynamic content)
--------------------------------------------------------------------------------

function InventoryGridDemo.updateInfoBox()
    -- Dynamic text updates automatically via callback
    -- This function can be extended for additional updates
end

--------------------------------------------------------------------------------
-- Setup Signal Handlers
--------------------------------------------------------------------------------

function InventoryGridDemo.setupSignalHandlers()
    -- Listen for grid item added
    demoState.signalHandlers.itemAdded = signal.register("grid_item_added", function(gridEntity, slotIndex, itemEntity)
        if gridEntity == demoState.gridEntity then
            log_debug("[Demo Signal] Item added to slot " .. slotIndex)
            playSound("inventory_item_drop")
            
            -- Flash effect on slot
            local slotEntity = grid.getSlotEntity(gridEntity, slotIndex)
            if slotEntity then
                -- Could add flash decoration here
            end
        end
    end)
    
    -- Listen for grid item removed
    demoState.signalHandlers.itemRemoved = signal.register("grid_item_removed", function(gridEntity, slotIndex, itemEntity)
        if gridEntity == demoState.gridEntity then
            log_debug("[Demo Signal] Item removed from slot " .. slotIndex)
            playSound("inventory_item_pickup")
        end
    end)
    
    -- Listen for grid stack changed
    demoState.signalHandlers.stackChanged = signal.register("grid_stack_changed", function(gridEntity, slotIndex, itemEntity, oldCount, newCount)
        if gridEntity == demoState.gridEntity then
            log_debug("[Demo Signal] Stack changed: " .. oldCount .. " -> " .. newCount)
            
            -- Update stack badge
            local slotEntity = grid.getSlotEntity(gridEntity, slotIndex)
            if slotEntity and newCount > 1 then
                UIDecorations.setBadgeText(slotEntity, "stack_count", "x" .. newCount)
            end
        end
    end)
    
    -- Listen for slot clicked
    demoState.signalHandlers.slotClicked = signal.register("grid_slot_clicked", function(gridEntity, slotIndex, button, modifiers)
        if gridEntity == demoState.gridEntity then
            log_debug("[Demo Signal] Slot " .. slotIndex .. " clicked")
            demoState.selectedSlot = slotIndex
        end
    end)
    
    log_debug("[InventoryGridDemo] Signal handlers registered")
end

--------------------------------------------------------------------------------
-- Spawn Mock Cards
--------------------------------------------------------------------------------

function InventoryGridDemo.spawnMockCards()
    -- Spawn cards at staggered positions near the grid
    local baseX = globals.screenWidth() - 500
    local baseY = 150
    
    for i, cardDef in ipairs(MOCK_CARDS) do
        local x = baseX + ((i - 1) % 3) * 80
        local y = baseY + math.floor((i - 1) / 3) * 110
        
        local entity, script = createMockCard(cardDef, x, y)
        table.insert(demoState.mockCards, { entity = entity, script = script })
        
        log_debug("[Demo] Spawned mock card: " .. cardDef.name .. " at " .. x .. ", " .. y)
    end
    
    -- Add some cards directly to grid slots
    timer.after_opts({
        delay = 0.5,
        tag = "demo_populate_grid",
        group = demoState.timerGroup,
        action = function()
            -- Add fireball to fire slot
            if demoState.mockCards[1] then
                grid.addItem(demoState.gridEntity, demoState.mockCards[1].entity, 1)
            end
            -- Add ice shard to ice slot
            if demoState.mockCards[2] then
                grid.addItem(demoState.gridEntity, demoState.mockCards[2].entity, 2)
            end
        end,
    })
    
    log_debug("[InventoryGridDemo] Mock cards spawned")
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

function InventoryGridDemo.cleanup()
    log_debug("[InventoryGridDemo] Cleaning up...")
    
    -- Remove signal handlers
    for name, handler in pairs(demoState.signalHandlers) do
        if handler then
            signal.remove(handler)
        end
    end
    demoState.signalHandlers = {}
    
    -- Cancel timers
    timer.kill_group(demoState.timerGroup)
    
    -- Destroy mock cards
    for _, card in ipairs(demoState.mockCards) do
        if card.entity and registry:valid(card.entity) then
            registry:destroy(card.entity)
        end
    end
    demoState.mockCards = {}
    
    -- Destroy UI elements
    if demoState.gridEntity and ui.box and ui.box.Remove then
        dsl.cleanupGrid("demo_inventory")
        ui.box.Remove(registry, demoState.gridEntity)
        demoState.gridEntity = nil
    end
    
    if demoState.customPanelEntity and ui.box and ui.box.Remove then
        ui.box.Remove(registry, demoState.customPanelEntity)
        demoState.customPanelEntity = nil
    end
    
    if demoState.infoBoxEntity and ui.box and ui.box.Remove then
        ui.box.Remove(registry, demoState.infoBoxEntity)
        demoState.infoBoxEntity = nil
    end
    
    demoState.selectedSlot = nil
    
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
