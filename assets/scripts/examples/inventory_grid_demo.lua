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

-- Demo state
local demoState = {
    gridEntity = nil,
    infoBoxEntity = nil,
    mockCards = {},
    signalHandlers = {},
    timerGroup = "inventory_demo",
}

--------------------------------------------------------------------------------
-- Helper: Create a simple draggable card entity
--------------------------------------------------------------------------------

local function createSimpleCard(spriteName, x, y, cardData)
    -- Use animation_system to create a sprite entity
    local entity = animation_system.createAnimatedObjectWithTransform(
        spriteName, true, x or 0, y or 0, nil, true
    )
    
    if not entity or not registry:valid(entity) then
        log_warn("[InventoryGridDemo] Failed to create card entity for: " .. tostring(spriteName))
        return nil
    end
    
    -- Resize to card size
    animation_system.resizeAnimationObjectsInEntityToFit(entity, 60, 84)
    
    -- Setup GameObject for drag-drop
    local go = component_cache.get(entity, GameObject)
    if go then
        go.state.dragEnabled = true
        go.state.collisionEnabled = true
        go.state.hoverEnabled = true
    end
    
    if setScriptTableForEntityID then
        setScriptTableForEntityID(entity, {
            entity = entity,
            id = cardData.id,
            name = cardData.name,
            element = cardData.element,
            stackId = cardData.stackId,
            category = "card",
            cardData = cardData,
        })
    end
    
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
    
    -- Position demo elements
    local gridX = screenW - 380
    local gridY = 80
    
    -- Create grid
    InventoryGridDemo.createMainGrid(gridX, gridY)
    
    -- Create info box
    InventoryGridDemo.createInfoBox(gridX - 220, gridY)
    
    -- Setup signal handlers
    InventoryGridDemo.setupSignalHandlers()
    
    -- Spawn mock cards after a short delay (give UI time to initialize)
    timer.after_opts({
        delay = 0.3,
        tag = "demo_spawn_cards",
        group = demoState.timerGroup,
        action = function()
            InventoryGridDemo.spawnMockCards()
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
            slotColor = "darkgray",
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
-- Setup Signal Handlers
--------------------------------------------------------------------------------

function InventoryGridDemo.setupSignalHandlers()
    -- Listen for grid item added
    demoState.signalHandlers.itemAdded = signal.register("grid_item_added", function(gridEntity, slotIndex, itemEntity)
        if gridEntity == demoState.gridEntity then
            log_debug("[Demo Signal] Item added to slot " .. slotIndex)
            if playSoundEffect then
                playSoundEffect("effects", "button-click")
            end
        end
    end)
    
    -- Listen for grid item removed
    demoState.signalHandlers.itemRemoved = signal.register("grid_item_removed", function(gridEntity, slotIndex, itemEntity)
        if gridEntity == demoState.gridEntity then
            log_debug("[Demo Signal] Item removed from slot " .. slotIndex)
        end
    end)
    
    -- Listen for slot clicked
    demoState.signalHandlers.slotClicked = signal.register("grid_slot_clicked", function(gridEntity, slotIndex, button, modifiers)
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
    
    -- Spawn cards in a row above the grid
    local startX = screenW - 500
    local startY = 400
    
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
    for _, entity in ipairs(demoState.mockCards) do
        if entity and registry:valid(entity) then
            registry:destroy(entity)
        end
    end
    demoState.mockCards = {}
    
    -- Destroy UI elements
    if demoState.gridEntity and ui.box and ui.box.Remove then
        dsl.cleanupGrid("demo_inventory")
        ui.box.Remove(registry, demoState.gridEntity)
        demoState.gridEntity = nil
    end
    
    if demoState.infoBoxEntity and ui.box and ui.box.Remove then
        ui.box.Remove(registry, demoState.infoBoxEntity)
        demoState.infoBoxEntity = nil
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
