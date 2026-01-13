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
local z_orders = require("core.z_orders")

--------------------------------------------------------------------------------
-- Z-Order constants for drag operations
--------------------------------------------------------------------------------
local UI_CARD_Z = z_orders.ui_tooltips - 100      -- Normal cards in inventory
local DRAG_Z = z_orders.ui_tooltips + 500         -- Dragged cards (above everything)

--------------------------------------------------------------------------------
-- Drag state tracking for return-to-origin behavior
--------------------------------------------------------------------------------
local _dragState = {}  -- [entityKey] = { originSlot, originGrid, originX, originY }

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
    local gridZ = 0
    if layer_order_system and layer_order_system.getZIndex then
        gridZ = layer_order_system.getZIndex(gridEntity)
    end

    for i = 1, rows * cols do
        local slotId = gridId .. "_slot_" .. i
        local slotEntity = ui.box.GetUIEByID(registry, gridEntity, slotId)
        
        if slotEntity then
            grid.setSlotEntity(gridEntity, i, slotEntity)
            
            if layer_order_system and layer_order_system.assignZIndexToEntity then
                layer_order_system.assignZIndexToEntity(slotEntity, gridZ + 1)
            end

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
        return false
    end

    local go = component_cache.get(droppedEntity, GameObject)
    if not go then
        log_debug("[DRAG-DEBUG] REJECTED: droppedEntity has no GameObject")
        return false
    end
    if not go.state.dragEnabled then
        log_debug("[DRAG-DEBUG] REJECTED: dragEnabled=" .. tostring(go.state.dragEnabled))
        return false
    end

    if not grid.canSlotAccept(gridEntity, slotIndex, droppedEntity) then
        log_debug("[DRAG-DEBUG] REJECTED by canSlotAccept")
        return false
    end

    local sourceSlot = grid.findSlotContaining(gridEntity, droppedEntity)
    local success = false

    if sourceSlot then
        -- Item is already in this grid, move/swap/merge
        if sourceSlot == slotIndex then
            -- Dropped on same slot, mark as valid but no-op
            InventoryGridInit.markValidDrop(droppedEntity)
            return true
        end

        local targetItem = grid.getItemAtIndex(gridEntity, slotIndex)
        if targetItem then
            local sourceStackId = InventoryGridInit._getStackId(droppedEntity)
            local targetStackId = InventoryGridInit._getStackId(targetItem)
            if sourceStackId and sourceStackId == targetStackId then
                success = grid.mergeStacks(gridEntity, sourceSlot, slotIndex)
            else
                success = grid.swapItems(gridEntity, sourceSlot, slotIndex)
            end
        else
            success = grid.moveItem(gridEntity, sourceSlot, slotIndex)
        end

        if success then
            -- Snap moved/swapped item to new slot
            local slotEntity = grid.getSlotEntity(gridEntity, slotIndex)
            if slotEntity then
                InventoryGridInit.centerItemOnSlot(droppedEntity, slotEntity)
            end
        end
    else
        -- New item being dropped into grid
        local slot, action
        success, slot, action = grid.addItem(gridEntity, droppedEntity, slotIndex)
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

    -- Mark drop as valid to prevent snap-back to origin
    if success then
        InventoryGridInit.markValidDrop(droppedEntity)
        log_debug("[DRAG-DEBUG] Valid drop, marked to prevent snap-back")
    end

    return success
end

function InventoryGridInit._getStackId(entity)
    local script = getScriptTableFromEntityID(entity)
    return script and script.stackId
end

--------------------------------------------------------------------------------
-- Drag state management: z-order and return-to-origin
--------------------------------------------------------------------------------

--- Called when a drag starts on a card. Stores origin and raises z-order.
function InventoryGridInit.onDragStart(itemEntity, gridEntity)
    if not registry:valid(itemEntity) then return end

    local key = tostring(itemEntity)
    local t = component_cache.get(itemEntity, Transform)
    local originSlot = gridEntity and grid.findSlotContaining(gridEntity, itemEntity) or nil

    -- Store origin information for potential return
    _dragState[key] = {
        originSlot = originSlot,
        originGrid = gridEntity,
        originX = t and t.actualX or 0,
        originY = t and t.actualY or 0,
        wasDroppedOnValidSlot = false,
    }

    -- Raise z-order so dragged card appears above all other UI
    if layer_order_system and layer_order_system.assignZIndexToEntity then
        layer_order_system.assignZIndexToEntity(itemEntity, DRAG_Z)
    end

    signal.emit("grid_item_drag_start", gridEntity, itemEntity, originSlot)
    log_debug("[DRAG] Started dragging entity=" .. key .. " from slot=" .. tostring(originSlot))
end

--- Called when a drag ends. Either snaps to new slot or returns to origin.
function InventoryGridInit.onDragEnd(itemEntity)
    if not registry:valid(itemEntity) then return end

    local key = tostring(itemEntity)
    local dragInfo = _dragState[key]

    if not dragInfo then
        -- No drag state, just reset z-order
        if layer_order_system and layer_order_system.assignZIndexToEntity then
            layer_order_system.assignZIndexToEntity(itemEntity, UI_CARD_Z)
        end
        return
    end

    -- Reset z-order back to normal
    if layer_order_system and layer_order_system.assignZIndexToEntity then
        layer_order_system.assignZIndexToEntity(itemEntity, UI_CARD_Z)
    end

    -- If dropped on invalid location, return to original position
    if not dragInfo.wasDroppedOnValidSlot then
        local originGrid = dragInfo.originGrid
        local originSlot = dragInfo.originSlot

        if originGrid and originSlot then
            -- Snap back to original slot
            local slotEntity = grid.getSlotEntity(originGrid, originSlot)
            if slotEntity then
                InventoryGridInit.centerItemOnSlot(itemEntity, slotEntity)
                log_debug("[DRAG] Returned to original slot=" .. originSlot)
            end
        else
            -- No grid origin, return to exact position
            local t = component_cache.get(itemEntity, Transform)
            if t then
                t.actualX = dragInfo.originX
                t.actualY = dragInfo.originY
                log_debug("[DRAG] Returned to original position")
            end
        end

        signal.emit("grid_item_drag_cancelled", dragInfo.originGrid, itemEntity, originSlot)
    end

    -- Clear drag state
    _dragState[key] = nil
    signal.emit("grid_item_drag_end", dragInfo.originGrid, itemEntity)
end

--- Marks an entity as having been dropped on a valid slot (prevents snap-back)
function InventoryGridInit.markValidDrop(itemEntity)
    local key = tostring(itemEntity)
    if _dragState[key] then
        _dragState[key].wasDroppedOnValidSlot = true
    end
end

--- Gets drag state for an entity (for external inspection)
function InventoryGridInit.getDragState(itemEntity)
    return _dragState[tostring(itemEntity)]
end

--------------------------------------------------------------------------------
-- Helper: Make an entity draggable with full drag support
--------------------------------------------------------------------------------

function InventoryGridInit.makeItemDraggable(itemEntity, gridEntity)
    local go = component_cache.get(itemEntity, GameObject)
    if not go then return end

    go.state.dragEnabled = true
    go.state.collisionEnabled = true
    go.state.hoverEnabled = true

    -- Setup drag start handler
    local existingOnDrag = go.methods.onDrag
    go.methods.onDrag = function(reg, entity)
        -- Only trigger drag start once (check if we already have state)
        local key = tostring(entity)
        if not _dragState[key] then
            InventoryGridInit.onDragStart(entity, gridEntity)
        end
        if existingOnDrag then
            existingOnDrag(reg, entity)
        end
    end

    -- Setup drag end handler
    local existingOnStopDrag = go.methods.onStopDrag
    go.methods.onStopDrag = function(reg, entity)
        InventoryGridInit.onDragEnd(entity)
        if existingOnStopDrag then
            existingOnStopDrag(reg, entity)
        end
    end
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
