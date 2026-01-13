--[[
================================================================================
GRID TRANSFER - Atomic Cross-Grid Item Transfers with Rollback
================================================================================

Provides safe transfer operations between inventory grids. Validates target
acceptance BEFORE modifying source, ensuring failed transfers leave source
unchanged.

QUICK REFERENCE:
---------------
local transfer = require("core.grid_transfer")

-- Transfer item between grids
local result = transfer.transferItem({
    item = itemEntity,          -- Required: item to transfer
    fromGrid = sourceGrid,      -- Required: source grid entity
    fromSlot = sourceSlot,      -- Required: source slot index
    toGrid = targetGrid,        -- Required: target grid entity
    toSlot = targetSlot,        -- Optional: target slot (nil = first empty)
    onSuccess = function(result) end,  -- Optional callback
    onFail = function(reason) end,     -- Optional callback
})

-- Result structure:
-- { success = true/false, reason = "string", fromSlot = N, toSlot = N }

-- Quick transfer (finds item's current location automatically)
local result = transfer.transferItemTo({
    item = itemEntity,
    toGrid = targetGrid,
    toSlot = targetSlot,        -- Optional
})

EVENTS (via hump.signal):
------------------------
"grid_transfer_success"  (itemEntity, fromGrid, fromSlot, toGrid, toSlot)
"grid_transfer_failed"   (itemEntity, fromGrid, toGrid, reason)

FAILURE REASONS:
---------------
"invalid_item"          - Item entity is nil or invalid
"invalid_source_grid"   - Source grid entity is invalid
"invalid_target_grid"   - Target grid entity is invalid
"item_not_in_source"    - Item not found at specified source slot
"target_slot_locked"    - Target slot is locked
"target_slot_occupied"  - Target slot already has an item (non-stackable)
"filter_rejected"       - Grid or slot filter rejected the item
"no_empty_slot"         - No empty slots available in target grid

================================================================================
]]

local transfer = {}

local signal = require("external.hump.signal")
local grid = require("core.inventory_grid")
local itemRegistry = require("core.item_location_registry")

--------------------------------------------------------------------------------
-- Validation Helpers
--------------------------------------------------------------------------------

local function validateEntity(entity, name)
    if not entity then
        return false, "invalid_" .. name
    end
    if registry and registry.valid and not registry:valid(entity) then
        return false, "invalid_" .. name
    end
    return true, nil
end

local function validateTransferParams(params)
    -- Validate item
    local valid, reason = validateEntity(params.item, "item")
    if not valid then return false, reason end

    -- Validate source grid
    valid, reason = validateEntity(params.fromGrid, "source_grid")
    if not valid then return false, reason end

    -- Validate target grid
    valid, reason = validateEntity(params.toGrid, "target_grid")
    if not valid then return false, reason end

    -- Validate source slot
    if not params.fromSlot then
        return false, "invalid_source_slot"
    end

    return true, nil
end

--------------------------------------------------------------------------------
-- Core Transfer Function
--------------------------------------------------------------------------------

--- Transfer an item from one grid to another with rollback on failure.
-- Validates target can accept item BEFORE removing from source.
-- @param params Table with transfer parameters:
--   - item: Entity ID of item to transfer
--   - fromGrid: Source grid entity
--   - fromSlot: Source slot index
--   - toGrid: Target grid entity
--   - toSlot: (optional) Target slot index, nil = first empty
--   - onSuccess: (optional) Callback function(result)
--   - onFail: (optional) Callback function(reason)
-- @return table { success, reason, fromSlot, toSlot }
function transfer.transferItem(params)
    local result = {
        success = false,
        reason = nil,
        fromSlot = params.fromSlot,
        toSlot = params.toSlot,
    }

    -- Step 1: Validate all parameters
    local valid, reason = validateTransferParams(params)
    if not valid then
        result.reason = reason
        if params.onFail then params.onFail(reason) end
        signal.emit("grid_transfer_failed", params.item, params.fromGrid, params.toGrid, reason)
        return result
    end

    -- Step 2: Verify item exists at source slot
    local sourceItem = grid.getItemAtIndex(params.fromGrid, params.fromSlot)
    if sourceItem ~= params.item then
        result.reason = "item_not_in_source"
        if params.onFail then params.onFail(result.reason) end
        signal.emit("grid_transfer_failed", params.item, params.fromGrid, params.toGrid, result.reason)
        return result
    end

    -- Step 3: Determine target slot
    local targetSlot = params.toSlot
    if not targetSlot then
        targetSlot = grid.findEmptySlot(params.toGrid)
        if not targetSlot then
            result.reason = "no_empty_slot"
            if params.onFail then params.onFail(result.reason) end
            signal.emit("grid_transfer_failed", params.item, params.fromGrid, params.toGrid, result.reason)
            return result
        end
    end
    result.toSlot = targetSlot

    -- Step 4: CRITICAL - Validate target can accept BEFORE modifying source
    -- This is the rollback-safe validation step
    if not grid.canSlotAccept(params.toGrid, targetSlot, params.item) then
        -- Determine specific reason
        if grid.isSlotLocked(params.toGrid, targetSlot) then
            result.reason = "target_slot_locked"
        elseif grid.getItemAtIndex(params.toGrid, targetSlot) then
            result.reason = "target_slot_occupied"
        else
            result.reason = "filter_rejected"
        end
        if params.onFail then params.onFail(result.reason) end
        signal.emit("grid_transfer_failed", params.item, params.fromGrid, params.toGrid, result.reason)
        return result
    end

    -- Step 5: All validations passed - execute the transfer
    -- Remove from source
    local removedItem = grid.removeItem(params.fromGrid, params.fromSlot)
    if not removedItem then
        -- This shouldn't happen after our validation, but handle gracefully
        result.reason = "source_removal_failed"
        if params.onFail then params.onFail(result.reason) end
        signal.emit("grid_transfer_failed", params.item, params.fromGrid, params.toGrid, result.reason)
        return result
    end

    -- Add to target
    local addSuccess, actualSlot = grid.addItem(params.toGrid, params.item, targetSlot)
    if not addSuccess then
        -- ROLLBACK: Put item back in source
        grid.addItem(params.fromGrid, params.item, params.fromSlot)
        result.reason = "target_add_failed"
        if params.onFail then params.onFail(result.reason) end
        signal.emit("grid_transfer_failed", params.item, params.fromGrid, params.toGrid, result.reason)
        return result
    end

    -- Step 6: Update item location registry
    -- The registry.register() auto-unregisters from old location
    itemRegistry.register(params.item, params.toGrid, actualSlot)

    -- Step 7: Success!
    result.success = true
    result.toSlot = actualSlot

    if params.onSuccess then params.onSuccess(result) end
    signal.emit("grid_transfer_success", params.item, params.fromGrid, params.fromSlot, params.toGrid, actualSlot)

    return result
end

--------------------------------------------------------------------------------
-- Convenience Functions
--------------------------------------------------------------------------------

--- Transfer an item to a target grid, automatically finding its current location.
-- Uses item_location_registry to find where the item currently is.
-- @param params Table with:
--   - item: Entity ID of item to transfer
--   - toGrid: Target grid entity
--   - toSlot: (optional) Target slot index
--   - onSuccess/onFail: (optional) Callbacks
-- @return table { success, reason, fromSlot, toSlot }
function transfer.transferItemTo(params)
    if not params.item then
        local result = { success = false, reason = "invalid_item" }
        if params.onFail then params.onFail(result.reason) end
        return result
    end

    -- Look up current location from registry
    local location = itemRegistry.getLocation(params.item)
    if not location then
        local result = { success = false, reason = "item_not_registered" }
        if params.onFail then params.onFail(result.reason) end
        signal.emit("grid_transfer_failed", params.item, nil, params.toGrid, result.reason)
        return result
    end

    -- Delegate to full transfer function
    return transfer.transferItem({
        item = params.item,
        fromGrid = location.grid,
        fromSlot = location.slot,
        toGrid = params.toGrid,
        toSlot = params.toSlot,
        onSuccess = params.onSuccess,
        onFail = params.onFail,
    })
end

--- Swap items between two grids.
-- Both items must exist; performs two transfers atomically.
-- @param params Table with:
--   - item1, grid1, slot1: First item and location
--   - item2, grid2, slot2: Second item and location
--   - onSuccess/onFail: (optional) Callbacks
-- @return table { success, reason }
function transfer.swapBetweenGrids(params)
    local result = { success = false, reason = nil }

    -- Validate both items exist
    local item1 = grid.getItemAtIndex(params.grid1, params.slot1)
    local item2 = grid.getItemAtIndex(params.grid2, params.slot2)

    if not item1 or item1 ~= params.item1 then
        result.reason = "item1_not_found"
        if params.onFail then params.onFail(result.reason) end
        return result
    end

    if not item2 or item2 ~= params.item2 then
        result.reason = "item2_not_found"
        if params.onFail then params.onFail(result.reason) end
        return result
    end

    -- Validate both slots can accept the swapped items
    -- (We need to check if slot1 can accept item2 and slot2 can accept item1)
    -- For swap, we need to temporarily ignore occupancy checks
    if grid.isSlotLocked(params.grid1, params.slot1) or grid.isSlotLocked(params.grid2, params.slot2) then
        result.reason = "slot_locked"
        if params.onFail then params.onFail(result.reason) end
        return result
    end

    -- Remove both items
    local removed1 = grid.removeItem(params.grid1, params.slot1)
    local removed2 = grid.removeItem(params.grid2, params.slot2)

    if not removed1 or not removed2 then
        -- Rollback: put items back
        if removed1 then grid.addItem(params.grid1, removed1, params.slot1) end
        if removed2 then grid.addItem(params.grid2, removed2, params.slot2) end
        result.reason = "removal_failed"
        if params.onFail then params.onFail(result.reason) end
        return result
    end

    -- Add items to swapped positions
    local add1Success = grid.addItem(params.grid2, removed1, params.slot2)
    local add2Success = grid.addItem(params.grid1, removed2, params.slot1)

    if not add1Success or not add2Success then
        -- Rollback: restore original positions
        grid.removeItem(params.grid2, params.slot2)
        grid.removeItem(params.grid1, params.slot1)
        grid.addItem(params.grid1, removed1, params.slot1)
        grid.addItem(params.grid2, removed2, params.slot2)
        result.reason = "add_failed"
        if params.onFail then params.onFail(result.reason) end
        return result
    end

    -- Update registry for both items
    itemRegistry.register(removed1, params.grid2, params.slot2)
    itemRegistry.register(removed2, params.grid1, params.slot1)

    result.success = true
    if params.onSuccess then params.onSuccess(result) end

    signal.emit("grid_transfer_success", removed1, params.grid1, params.slot1, params.grid2, params.slot2)
    signal.emit("grid_transfer_success", removed2, params.grid2, params.slot2, params.grid1, params.slot1)

    return result
end

--- Check if a transfer would succeed without executing it.
-- @param params Same as transferItem
-- @return boolean canTransfer, string|nil reason
function transfer.canTransfer(params)
    -- Validate parameters
    local valid, reason = validateTransferParams(params)
    if not valid then return false, reason end

    -- Verify item exists at source
    local sourceItem = grid.getItemAtIndex(params.fromGrid, params.fromSlot)
    if sourceItem ~= params.item then
        return false, "item_not_in_source"
    end

    -- Determine target slot
    local targetSlot = params.toSlot
    if not targetSlot then
        targetSlot = grid.findEmptySlot(params.toGrid)
        if not targetSlot then
            return false, "no_empty_slot"
        end
    end

    -- Check if target can accept
    if not grid.canSlotAccept(params.toGrid, targetSlot, params.item) then
        if grid.isSlotLocked(params.toGrid, targetSlot) then
            return false, "target_slot_locked"
        elseif grid.getItemAtIndex(params.toGrid, targetSlot) then
            return false, "target_slot_occupied"
        else
            return false, "filter_rejected"
        end
    end

    return true, nil
end

return transfer
