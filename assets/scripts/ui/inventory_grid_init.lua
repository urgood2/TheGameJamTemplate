--[[
================================================================================
Inventory Grid Initialization
================================================================================
Hooks into the UI spawning system to initialize inventory grids.
Called after dsl.spawn() creates the UIBox entity.

Usage:
    -- In ui_syntax_sugar.lua spawn function or after spawning:
    local InventoryGridInit = require("ui.inventory_grid_init")
    InventoryGridInit.initializeIfGrid(boxEntity, "my_grid_id")
================================================================================
]]

local InventoryGridInit = {}

local grid = require("core.inventory_grid")
local component_cache = require("core.component_cache")
local signal = require("external.hump.signal")

--------------------------------------------------------------------------------
-- Check if entity is an inventory grid and initialize it
--------------------------------------------------------------------------------

function InventoryGridInit.initializeIfGrid(boxEntity, gridId)
    if not registry:valid(boxEntity) then
        return false
    end
    
    -- Get grid config from DSL registry (not C++ component)
    local dsl = require("ui.ui_syntax_sugar")
    
    -- Try to find gridId from UIConfig if not provided
    if not gridId then
        local uiConfig = component_cache.get(boxEntity, UIConfig)
        if uiConfig and uiConfig.id then
            gridId = uiConfig.id
        end
    end
    
    if not gridId then
        log_warn("[InventoryGridInit] No gridId provided or found")
        return false
    end
    
    -- Get grid config from DSL registry
    local gridData = dsl.getGridConfig(gridId)
    if not gridData then
        log_warn("[InventoryGridInit] Grid not found in DSL registry: " .. tostring(gridId))
        return false
    end
    
    local rows = gridData.rows or 3
    local cols = gridData.cols or 3
    local gridConfig = gridData.config or {}
    local slotsConfig = gridData.slotsConfig or {}
    
    -- Initialize grid data
    grid.initializeGrid(boxEntity, rows, cols, gridConfig, slotsConfig)
    
    -- Find and register slot entities
    InventoryGridInit.registerSlotEntities(boxEntity, gridId, rows, cols)
    
    grid.setCallbacks(boxEntity, {
        onSlotChange = gridData.onSlotChange,
        onSlotClick = gridData.onSlotClick,
        onItemStack = gridData.onItemStack,
    })
    
    log_debug("[InventoryGridInit] Initialized grid: " .. tostring(gridId) .. " (" .. rows .. "x" .. cols .. ")")
    
    return true
end

--------------------------------------------------------------------------------
-- Register slot entities with the grid
--------------------------------------------------------------------------------

function InventoryGridInit.registerSlotEntities(gridEntity, gridId, rows, cols)
    -- Find each slot entity by ID and register it
    for i = 1, rows * cols do
        local slotId = gridId .. "_slot_" .. i
        local slotEntity = ui.box.GetUIEByID(registry, gridEntity, slotId)
        
        if slotEntity then
            grid.setSlotEntity(gridEntity, i, slotEntity)
            InventoryGridInit.setupSlotInteraction(gridEntity, slotEntity, i)
        else
            log_warn("[InventoryGridInit] Could not find slot entity: " .. slotId)
        end
    end
end

--------------------------------------------------------------------------------
-- Setup drag-drop interaction for a slot
--------------------------------------------------------------------------------

local _slotMetadata = {}

function InventoryGridInit.setupSlotInteraction(gridEntity, slotEntity, slotIndex)
    local go = component_cache.get(slotEntity, GameObject)
    if not go then return end
    
    go.state.collisionEnabled = true
    go.state.hoverEnabled = true
    go.state.triggerOnReleaseEnabled = true
    
    _slotMetadata[tostring(slotEntity)] = {
        parentGrid = gridEntity,
        slotIndex = slotIndex,
    }
    
    go.methods.onRelease = function(releasedOn, released)
        InventoryGridInit.handleItemDrop(gridEntity, slotIndex, released)
    end
    
    local originalOnClick = go.methods.onClick
    go.methods.onClick = function(entity)
        signal.emit("grid_slot_clicked", gridEntity, slotIndex, "left", {})
        if originalOnClick then
            originalOnClick(entity)
        end
    end
end

function InventoryGridInit.getSlotMetadata(slotEntity)
    return _slotMetadata[tostring(slotEntity)]
end

function InventoryGridInit.cleanupSlotMetadata(slotEntity)
    _slotMetadata[tostring(slotEntity)] = nil
end

--------------------------------------------------------------------------------
-- Handle item dropped on slot
--------------------------------------------------------------------------------

function InventoryGridInit.handleItemDrop(gridEntity, slotIndex, droppedEntity)
    if not registry:valid(droppedEntity) then
        return
    end
    
    local go = component_cache.get(droppedEntity, GameObject)
    if not go or not go.state.dragEnabled then
        return  -- Not a draggable item
    end
    
    -- Check if can accept
    if not grid.canSlotAccept(gridEntity, slotIndex, droppedEntity) then
        -- Return item to original position (or handle rejection)
        log_debug("[InventoryGridInit] Slot " .. slotIndex .. " rejected item")
        return
    end
    
    -- Check if item came from another slot in this grid
    local sourceSlot = grid.findSlotContaining(gridEntity, droppedEntity)
    
    if sourceSlot then
        -- Moving within same grid
        if sourceSlot == slotIndex then
            return  -- Dropped on same slot, no action
        end
        
        local targetItem = grid.getItemAtIndex(gridEntity, slotIndex)
        if targetItem then
            -- Swap items
            grid.swapItems(gridEntity, sourceSlot, slotIndex)
        else
            -- Move to empty slot
            grid.moveItem(gridEntity, sourceSlot, slotIndex)
        end
    else
        -- Item from outside - try to add
        local success = grid.addItem(gridEntity, droppedEntity, slotIndex)
        if success then
            -- Center item in slot
            local slotEntity = grid.getSlotEntity(gridEntity, slotIndex)
            if slotEntity then
                game.centerInventoryItemOnTargetUI(droppedEntity, slotEntity)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Helper: Make an entity draggable and add to grid
--------------------------------------------------------------------------------

function InventoryGridInit.makeItemDraggable(itemEntity)
    local go = component_cache.get(itemEntity, GameObject)
    if not go then return end
    
    go.state.dragEnabled = true
    go.state.collisionEnabled = true
end

return InventoryGridInit
