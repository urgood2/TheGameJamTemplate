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
    if not go then 
        return 
    end
    
    go.state.collisionEnabled = true
    go.state.hoverEnabled = true
    go.state.triggerOnReleaseEnabled = true
    
    if add_state_tag then
        add_state_tag(slotEntity, "default_state")
    end
    
    if transform.set_space then
        transform.set_space(slotEntity, "screen")
    end
    
    _slotMetadata[tostring(slotEntity)] = {
        parentGrid = gridEntity,
        slotIndex = slotIndex,
    }
    
    go.methods.onRelease = function(reg, releasedOn, dragged)
        InventoryGridInit.handleItemDrop(gridEntity, slotIndex, dragged)
    end
    
    go.methods.onClick = function(reg, entity)
        signal.emit("grid_slot_clicked", gridEntity, slotIndex, "left", {})
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
    log_debug("[DRAG-DEBUG] handleItemDrop: grid=" .. tostring(gridEntity) .. 
              " slot=" .. slotIndex .. " dropped=" .. tostring(droppedEntity))
    
    if not registry:valid(droppedEntity) then
        log_debug("[DRAG-DEBUG] REJECTED: droppedEntity invalid")
        return
    end
    
    local go = component_cache.get(droppedEntity, GameObject)
    if not go then
        log_debug("[DRAG-DEBUG] REJECTED: droppedEntity has no GameObject")
        return
    end
    if not go.state.dragEnabled then
        log_debug("[DRAG-DEBUG] REJECTED: dragEnabled=" .. tostring(go.state.dragEnabled))
        return
    end
    
    if not grid.canSlotAccept(gridEntity, slotIndex, droppedEntity) then
        log_debug("[DRAG-DEBUG] REJECTED by canSlotAccept")
        return
    end
    
    local sourceSlot = grid.findSlotContaining(gridEntity, droppedEntity)
    
    if sourceSlot then
        -- Item is already in this grid, move/swap/merge
        if sourceSlot == slotIndex then
            return
        end
        
        local targetItem = grid.getItemAtIndex(gridEntity, slotIndex)
        if targetItem then
            local sourceStackId = InventoryGridInit._getStackId(droppedEntity)
            local targetStackId = InventoryGridInit._getStackId(targetItem)
            if sourceStackId and sourceStackId == targetStackId then
                grid.mergeStacks(gridEntity, sourceSlot, slotIndex)
            else
                grid.swapItems(gridEntity, sourceSlot, slotIndex)
            end
        else
            grid.moveItem(gridEntity, sourceSlot, slotIndex)
        end
    else
        -- New item being dropped into grid
        local success, slot, action = grid.addItem(gridEntity, droppedEntity, slotIndex)
        if success then
            if action == "stacked" then
                if registry:valid(droppedEntity) then
                    registry:destroy(droppedEntity)
                end
            elseif action == "placed" then
                local slotEntity = grid.getSlotEntity(gridEntity, slotIndex)
                if slotEntity then
                    InventoryGridInit.centerItemOnSlot(droppedEntity, slotEntity)
                end
            end
        end
    end
end

function InventoryGridInit._getStackId(entity)
    local script = getScriptTableFromEntityID(entity)
    return script and script.stackId
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

function InventoryGridInit.centerItemOnSlot(itemEntity, slotEntity)
    if not registry:valid(itemEntity) or not registry:valid(slotEntity) then
        return
    end
    
    local slotTransform = component_cache.get(slotEntity, Transform)
    local itemTransform = component_cache.get(itemEntity, Transform)
    
    if not slotTransform or not itemTransform then
        return
    end
    
    local slotX = slotTransform.visualX or slotTransform.actualX or 0
    local slotY = slotTransform.visualY or slotTransform.actualY or 0
    local slotW = slotTransform.actualW or 64
    local slotH = slotTransform.actualH or 64
    
    local itemW = itemTransform.actualW or 64
    local itemH = itemTransform.actualH or 64
    
    local centerX = slotX + (slotW - itemW) / 2
    local centerY = slotY + (slotH - itemH) / 2
    
    itemTransform.actualX = centerX
    itemTransform.actualY = centerY
end

return InventoryGridInit
