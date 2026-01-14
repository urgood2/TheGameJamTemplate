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
local transfer = require("core.grid_transfer")
local itemRegistry = require("core.item_location_registry")
local UIDecorations = require("ui.ui_decorations")

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

    -- Register grid for invalid drag target feedback (US-017)
    InventoryGridInit.registerGridForDragFeedback(boxEntity, rows, cols)

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

    -- Check if item is in THIS grid or a DIFFERENT grid
    local sourceSlotInThisGrid = grid.findSlotContaining(gridEntity, droppedEntity)
    local success = false

    if sourceSlotInThisGrid then
        -- Item is already in this grid, move/swap/merge (same-grid operation)
        if sourceSlotInThisGrid == slotIndex then
            -- Dropped on same slot, mark as valid but no-op
            InventoryGridInit.markValidDrop(droppedEntity)
            return true
        end

        local targetItem = grid.getItemAtIndex(gridEntity, slotIndex)
        if targetItem then
            local sourceStackId = InventoryGridInit._getStackId(droppedEntity)
            local targetStackId = InventoryGridInit._getStackId(targetItem)
            if sourceStackId and sourceStackId == targetStackId then
                success = grid.mergeStacks(gridEntity, sourceSlotInThisGrid, slotIndex)
            else
                success = grid.swapItems(gridEntity, sourceSlotInThisGrid, slotIndex)
            end
        else
            success = grid.moveItem(gridEntity, sourceSlotInThisGrid, slotIndex)
        end

        if success then
            -- Snap moved/swapped item to new slot
            local slotEntity = grid.getSlotEntity(gridEntity, slotIndex)
            if slotEntity then
                InventoryGridInit.centerItemOnSlot(droppedEntity, slotEntity)
            end
            -- Update location registry for same-grid moves
            itemRegistry.register(droppedEntity, gridEntity, slotIndex)
        end
    else
        -- Item is NOT in this grid - check if it's coming from another grid (cross-grid transfer)
        local sourceLocation = itemRegistry.getLocation(droppedEntity)

        if sourceLocation and sourceLocation.grid and sourceLocation.grid ~= gridEntity then
            -- CROSS-GRID TRANSFER: Use atomic transfer module
            log_debug("[DRAG-DEBUG] Cross-grid transfer from grid=" .. tostring(sourceLocation.grid) ..
                      " slot=" .. sourceLocation.slot .. " to grid=" .. tostring(gridEntity) .. " slot=" .. slotIndex)

            local result = transfer.transferItem({
                item = droppedEntity,
                fromGrid = sourceLocation.grid,
                fromSlot = sourceLocation.slot,
                toGrid = gridEntity,
                toSlot = slotIndex,
                onSuccess = function(res)
                    log_debug("[DRAG-DEBUG] Cross-grid transfer SUCCESS to slot " .. res.toSlot)
                    -- Emit cross-grid transfer event for wand adapter integration
                    signal.emit("grid_cross_transfer_success", droppedEntity, sourceLocation.grid, gridEntity, res.toSlot)
                end,
                onFail = function(reason)
                    log_debug("[DRAG-DEBUG] Cross-grid transfer FAILED: " .. tostring(reason))
                end,
            })

            success = result.success

            if success then
                -- Snap to new slot
                local slotEntity = grid.getSlotEntity(gridEntity, result.toSlot or slotIndex)
                if slotEntity then
                    InventoryGridInit.centerItemOnSlot(droppedEntity, slotEntity)
                end
                -- Update draggable reference to new grid
                InventoryGridInit.updateDraggableGridRef(droppedEntity, gridEntity)
            end
        else
            -- New item being dropped into grid (not from any registered grid)
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
                    -- Register new item in location registry
                    itemRegistry.register(droppedEntity, gridEntity, slot)
                    -- Update draggable reference
                    InventoryGridInit.updateDraggableGridRef(droppedEntity, gridEntity)
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
-- Invalid Drag Target Feedback (US-017)
-- Shows red border on slots that cannot accept the currently dragged item
--------------------------------------------------------------------------------

local _invalidSlotOverlays = {}  -- [gridEntityKey][slotIndex] = overlayId
local _registeredGrids = {}      -- Track grids for drag feedback

--- Register a grid for invalid slot feedback during drag operations.
-- Called automatically during grid initialization.
-- @param gridEntity The grid entity
-- @param rows Number of rows
-- @param cols Number of columns
function InventoryGridInit.registerGridForDragFeedback(gridEntity, rows, cols)
    if not gridEntity or not registry:valid(gridEntity) then return end

    local gridKey = tostring(gridEntity)
    if _registeredGrids[gridKey] then return end  -- Already registered

    _registeredGrids[gridKey] = {
        entity = gridEntity,
        rows = rows,
        cols = cols,
    }
    _invalidSlotOverlays[gridKey] = {}

    -- Add invalid drag overlay to each slot
    local slotCount = rows * cols
    for i = 1, slotCount do
        local slotEntity = grid.getSlotEntity(gridEntity, i)
        if slotEntity and registry:valid(slotEntity) then
            local overlayId = UIDecorations.addCustomOverlay(slotEntity, {
                id = "invalid_drag_overlay_" .. gridKey .. "_" .. i,
                z = 10,  -- Above normal hover overlays
                visible = function(slotEid)
                    return InventoryGridInit._isSlotInvalidForCurrentDrag(gridEntity, i, slotEid)
                end,
                onDraw = function(slotEid, x, y, w, h, z)
                    InventoryGridInit._drawInvalidSlotFeedback(slotEid, x, y, w, h, z)
                end,
            })
            _invalidSlotOverlays[gridKey][i] = overlayId
        end
    end

    log_debug("[InventoryGridInit] Registered grid " .. gridKey .. " for drag feedback (" .. slotCount .. " slots)")
end

--- Unregister a grid from drag feedback (call during cleanup)
-- @param gridEntity The grid entity
function InventoryGridInit.unregisterGridForDragFeedback(gridEntity)
    if not gridEntity then return end

    local gridKey = tostring(gridEntity)
    local gridInfo = _registeredGrids[gridKey]
    if not gridInfo then return end

    -- Remove overlays from slots
    local overlays = _invalidSlotOverlays[gridKey]
    if overlays then
        for i, overlayId in pairs(overlays) do
            local slotEntity = grid.getSlotEntity(gridEntity, i)
            if slotEntity then
                UIDecorations.remove(slotEntity, overlayId)
            end
        end
    end

    _invalidSlotOverlays[gridKey] = nil
    _registeredGrids[gridKey] = nil

    log_debug("[InventoryGridInit] Unregistered grid " .. gridKey .. " from drag feedback")
end

--- Check if a slot is invalid for the currently dragged item.
-- Used by the visibility function of invalid drag overlays.
-- @param gridEntity The grid entity
-- @param slotIndex The slot index
-- @param slotEntity The slot entity (for hover detection)
-- @return true if slot should show invalid feedback
function InventoryGridInit._isSlotInvalidForCurrentDrag(gridEntity, slotIndex, slotEntity)
    -- Only show feedback during active drag
    local inputState = input and input.getState and input.getState()
    if not inputState then return false end

    local draggedEntity = inputState.cursor_dragging_target
    if not draggedEntity or not registry:valid(draggedEntity) then
        return false
    end

    -- Only show feedback when hovering over this slot
    local hoveredEntity = inputState.cursor_hovering_target
    if hoveredEntity ~= slotEntity then
        return false
    end

    -- Check if the dragged entity is a draggable item
    local go = component_cache.get(draggedEntity, GameObject)
    if not go or not go.state.dragEnabled then
        return false
    end

    -- Check if this slot can accept the dragged item
    local canAccept = grid.canSlotAccept(gridEntity, slotIndex, draggedEntity)

    -- Show invalid feedback when canSlotAccept returns false
    return not canAccept
end

--- Draw invalid slot feedback (red border/indicator).
-- Called by the custom overlay's onDraw function.
-- @param slotEntity The slot entity
-- @param x Slot x position
-- @param y Slot y position
-- @param w Slot width
-- @param h Slot height
-- @param z Base z-order
function InventoryGridInit._drawInvalidSlotFeedback(slotEntity, x, y, w, h, z)
    if not command_buffer or not command_buffer.queueDrawRectangle then return end

    local uiLayer = layers and layers.ui or "ui"
    local space = layer and layer.DrawCommandSpace and layer.DrawCommandSpace.Screen

    -- Draw red border indicating invalid drop target
    local borderColor = Color.new(220, 60, 60, 200)  -- Semi-transparent red
    local borderWidth = 3

    -- Top border
    command_buffer.queueDrawRectangle(uiLayer, function() end,
        x, y, w, borderWidth, borderColor, z, space)
    -- Bottom border
    command_buffer.queueDrawRectangle(uiLayer, function() end,
        x, y + h - borderWidth, w, borderWidth, borderColor, z, space)
    -- Left border
    command_buffer.queueDrawRectangle(uiLayer, function() end,
        x, y, borderWidth, h, borderColor, z, space)
    -- Right border
    command_buffer.queueDrawRectangle(uiLayer, function() end,
        x + w - borderWidth, y, borderWidth, h, borderColor, z, space)

    -- Draw semi-transparent red overlay
    local overlayColor = Color.new(180, 50, 50, 80)  -- Light red tint
    command_buffer.queueDrawRectangle(uiLayer, function() end,
        x + borderWidth, y + borderWidth,
        w - borderWidth * 2, h - borderWidth * 2,
        overlayColor, z - 1, space)
end

--- Get currently dragged entity (helper for external use)
-- @return draggedEntity or nil
function InventoryGridInit.getCurrentlyDraggedEntity()
    local inputState = input and input.getState and input.getState()
    if not inputState then return nil end

    local dragged = inputState.cursor_dragging_target
    if dragged and registry:valid(dragged) then
        return dragged
    end
    return nil
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

    -- Store initial grid reference
    InventoryGridInit.updateDraggableGridRef(itemEntity, gridEntity)

    -- Setup drag start handler
    local existingOnDrag = go.methods.onDrag
    go.methods.onDrag = function(reg, entity)
        -- Only trigger drag start once (check if we already have state)
        local key = tostring(entity)
        if not _dragState[key] then
            -- CRITICAL: Resolve current grid from registry or ref, NOT from captured closure
            -- This ensures correct origin after cross-grid transfers
            local currentGrid = nil
            local location = itemRegistry.getLocation(entity)
            if location and location.grid then
                currentGrid = location.grid
            else
                -- Fallback to tracked grid ref (updated after cross-grid transfer)
                currentGrid = InventoryGridInit.getItemGridRef(entity)
            end
            InventoryGridInit.onDragStart(entity, currentGrid)
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

--------------------------------------------------------------------------------
-- Item-to-grid reference tracking (for cross-grid drag updates)
--------------------------------------------------------------------------------
local _itemGridRef = {}  -- [entityKey] = gridEntity

--- Update an item's grid reference after cross-grid transfer.
-- This ensures future drags reference the correct source grid.
-- @param itemEntity Entity ID of the item
-- @param newGridEntity Entity ID of the new grid
function InventoryGridInit.updateDraggableGridRef(itemEntity, newGridEntity)
    if not itemEntity then return end

    local key = tostring(itemEntity)
    _itemGridRef[key] = newGridEntity

    log_debug("[InventoryGridInit] Updated grid ref for entity=" .. key .. " to grid=" .. tostring(newGridEntity))
end

--- Get the grid reference for an item.
-- @param itemEntity Entity ID of the item
-- @return gridEntity or nil
function InventoryGridInit.getItemGridRef(itemEntity)
    if not itemEntity then return nil end
    return _itemGridRef[tostring(itemEntity)]
end

--- Clear grid reference when item is destroyed or removed from all grids.
-- @param itemEntity Entity ID of the item
function InventoryGridInit.clearItemGridRef(itemEntity)
    if not itemEntity then return end
    _itemGridRef[tostring(itemEntity)] = nil
end

--------------------------------------------------------------------------------
-- Inventory Full Feedback Handler
--------------------------------------------------------------------------------

local _inventoryFullHandlerRegistered = false

--- Show user feedback when inventory is full.
-- Displays popup message and plays error sound.
-- @param gridEntity The grid that is full
-- @param itemEntity The item that couldn't be added
local function onInventoryFull(gridEntity, itemEntity)
    log_debug("[InventoryGridInit] Inventory full - grid=" .. tostring(gridEntity) .. " item=" .. tostring(itemEntity))

    -- Play error sound
    if playSoundEffect then
        playSoundEffect("effects", "error_buzz", 0.8)
    end

    -- Show popup above the item if it has a valid transform
    if itemEntity and registry:valid(itemEntity) then
        local popup = require("core.popup")
        if popup and popup.above then
            popup.above(itemEntity, "Inventory full!", { color = "red" })
        end
    end
end

--- Register the inventory full handler (called once at module load)
function InventoryGridInit.registerInventoryFullHandler()
    if _inventoryFullHandlerRegistered then return end

    signal.register("inventory_full", onInventoryFull)
    _inventoryFullHandlerRegistered = true
    log_debug("[InventoryGridInit] Registered inventory_full handler")
end

-- Auto-register the handler when module loads
InventoryGridInit.registerInventoryFullHandler()

return InventoryGridInit
