--[[
================================================================================
ITEM LOCATION REGISTRY - Single Source of Truth for Item Locations
================================================================================

Tracks which grid contains each item to prevent card duplication across grids.
Items can only exist in one grid slot at a time.

QUICK REFERENCE:
---------------
local itemRegistry = require("core.item_location_registry")

-- Register item in a grid slot
itemRegistry.register(itemEntity, gridEntity, slotIndex)

-- Unregister item (when removed from grid)
itemRegistry.unregister(itemEntity)

-- Query item location
local location = itemRegistry.getLocation(itemEntity)  -- { grid, slot } or nil

-- Check if item is in any grid
if itemRegistry.isInAnyGrid(itemEntity) then ... end

-- Get all items in a specific grid
local items = itemRegistry.getItemsInGrid(gridEntity)  -- { [slot] = item }

INTEGRATION:
-----------
Called by inventory_grid.lua when items are added/removed:
- grid.addItem() should call itemRegistry.register()
- grid.removeItem() should call itemRegistry.unregister()

================================================================================
]]

local itemRegistry = {}

-- Internal storage: itemEntity -> { grid = gridEntity, slot = slotIndex }
local _itemLocations = {}

-- Reverse lookup: gridEntity -> { [slotIndex] = itemEntity }
local _gridContents = {}

--------------------------------------------------------------------------------
-- Core Registration Functions
--------------------------------------------------------------------------------

--- Register an item's location in a grid slot.
-- If the item is already registered elsewhere, it will be unregistered first.
-- @param itemEntity Entity ID of the item
-- @param gridEntity Entity ID of the grid containing the item
-- @param slotIndex Slot index within the grid (1-based)
-- @return boolean Success
function itemRegistry.register(itemEntity, gridEntity, slotIndex)
    if not itemEntity or not gridEntity or not slotIndex then
        log_warn("[ItemLocationRegistry] register() called with nil parameters")
        return false
    end

    -- Validate entity if registry is available
    if registry and registry.valid and not registry:valid(itemEntity) then
        log_warn("[ItemLocationRegistry] Cannot register invalid item entity")
        return false
    end

    if registry and registry.valid and not registry:valid(gridEntity) then
        log_warn("[ItemLocationRegistry] Cannot register to invalid grid entity")
        return false
    end

    -- If item is already registered somewhere, unregister it first
    local existingLocation = _itemLocations[itemEntity]
    if existingLocation then
        itemRegistry.unregister(itemEntity)
    end

    -- Register the item at the new location
    _itemLocations[itemEntity] = {
        grid = gridEntity,
        slot = slotIndex
    }

    -- Update reverse lookup
    local gridKey = tostring(gridEntity)
    if not _gridContents[gridKey] then
        _gridContents[gridKey] = {}
    end
    _gridContents[gridKey][slotIndex] = itemEntity

    return true
end

--- Unregister an item, removing it from location tracking.
-- @param itemEntity Entity ID of the item to unregister
-- @return boolean Success (true if item was registered and removed)
function itemRegistry.unregister(itemEntity)
    if not itemEntity then
        return false
    end

    local location = _itemLocations[itemEntity]
    if not location then
        return false  -- Item wasn't registered
    end

    -- Remove from reverse lookup
    local gridKey = tostring(location.grid)
    if _gridContents[gridKey] then
        _gridContents[gridKey][location.slot] = nil

        -- Clean up empty grid entries
        if next(_gridContents[gridKey]) == nil then
            _gridContents[gridKey] = nil
        end
    end

    -- Remove from primary lookup
    _itemLocations[itemEntity] = nil

    return true
end

--------------------------------------------------------------------------------
-- Query Functions
--------------------------------------------------------------------------------

--- Get the current location of an item.
-- @param itemEntity Entity ID of the item
-- @return table|nil { grid = gridEntity, slot = slotIndex } or nil if not in any grid
function itemRegistry.getLocation(itemEntity)
    if not itemEntity then
        return nil
    end

    local location = _itemLocations[itemEntity]
    if not location then
        return nil
    end

    -- Return a copy to prevent external modification
    return {
        grid = location.grid,
        slot = location.slot
    }
end

--- Check if an item is currently in any grid.
-- @param itemEntity Entity ID of the item
-- @return boolean True if item is registered in a grid
function itemRegistry.isInAnyGrid(itemEntity)
    if not itemEntity then
        return false
    end

    return _itemLocations[itemEntity] ~= nil
end

--- Get all items in a specific grid.
-- @param gridEntity Entity ID of the grid
-- @return table { [slotIndex] = itemEntity } for all occupied slots
function itemRegistry.getItemsInGrid(gridEntity)
    if not gridEntity then
        return {}
    end

    local gridKey = tostring(gridEntity)
    local contents = _gridContents[gridKey]

    if not contents then
        return {}
    end

    -- Return a copy to prevent external modification
    local result = {}
    for slot, item in pairs(contents) do
        result[slot] = item
    end
    return result
end

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

--- Clear all registrations for a specific grid (call when grid is destroyed).
-- @param gridEntity Entity ID of the grid to clear
function itemRegistry.clearGrid(gridEntity)
    if not gridEntity then
        return
    end

    local gridKey = tostring(gridEntity)
    local contents = _gridContents[gridKey]

    if contents then
        -- Remove all items in this grid from primary lookup
        for _, itemEntity in pairs(contents) do
            _itemLocations[itemEntity] = nil
        end

        -- Remove grid from reverse lookup
        _gridContents[gridKey] = nil
    end
end

--- Get count of items currently tracked.
-- @return number Total items registered
function itemRegistry.getItemCount()
    local count = 0
    for _ in pairs(_itemLocations) do
        count = count + 1
    end
    return count
end

--- Get count of grids currently tracked.
-- @return number Total grids with registered items
function itemRegistry.getGridCount()
    local count = 0
    for _ in pairs(_gridContents) do
        count = count + 1
    end
    return count
end

--- Debug: Print all registered items and their locations.
function itemRegistry.debugPrint()
    print("=== Item Location Registry ===")
    print("Total items: " .. itemRegistry.getItemCount())
    print("Total grids: " .. itemRegistry.getGridCount())

    for itemEntity, location in pairs(_itemLocations) do
        print(string.format("  Item %s -> Grid %s, Slot %d",
            tostring(itemEntity),
            tostring(location.grid),
            location.slot))
    end
    print("==============================")
end

return itemRegistry
