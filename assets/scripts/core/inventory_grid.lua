--[[
================================================================================
INVENTORY GRID API - Core Grid Operations
================================================================================

Lua API for inventory grid manipulation. Use with dsl.inventoryGrid() for UI.

QUICK REFERENCE:
---------------
local grid = require("core.inventory_grid")

-- Dimensions
rows, cols = grid.getDimensions(gridEntity)
capacity = grid.getCapacity(gridEntity)

-- Item Access
item = grid.getItemAtIndex(gridEntity, slotIndex)    -- By slot number (1-based)
item = grid.getItemAt(gridEntity, row, col)          -- By row/col (1-based)
items = grid.getAllItems(gridEntity)                  -- { [slotIndex] = item }
list = grid.getItemList(gridEntity)                   -- { { slot=1, item=e }, ... }

-- Slot Access
slotEntity = grid.getSlotEntity(gridEntity, slotIndex)
slots = grid.getAllSlots(gridEntity)
usedCount = grid.getUsedSlotCount(gridEntity)
emptyCount = grid.getEmptySlotCount(gridEntity)

-- Find Operations
slotIndex = grid.findSlotContaining(gridEntity, itemEntity)
slotIndex = grid.findEmptySlot(gridEntity)
slots = grid.findSlotsMatching(gridEntity, function(slot, item) return ... end)

-- Item Operations (emit events)
success, slot, action = grid.addItem(gridEntity, itemEntity, slotIndex?)
item = grid.removeItem(gridEntity, slotIndex)
success = grid.moveItem(gridEntity, fromSlot, toSlot)
success = grid.swapItems(gridEntity, slot1, slot2)

-- Stack Operations (for stackable grids)
count = grid.getStackCount(gridEntity, slotIndex)
success = grid.addToStack(gridEntity, slotIndex, amount)
success = grid.removeFromStack(gridEntity, slotIndex, amount)
success, transferred = grid.mergeStacks(gridEntity, fromSlot, toSlot)
success, amount = grid.splitStack(gridEntity, slotIndex, amount, newItemEntity)

-- Slot State
isLocked = grid.isSlotLocked(gridEntity, slotIndex)
grid.setSlotLocked(gridEntity, slotIndex, true/false)
canAccept = grid.canSlotAccept(gridEntity, slotIndex, itemEntity)

-- Cleanup
grid.cleanup(gridEntity)  -- Call when destroying grid

-- Grid Resize (with overflow detection)
result = grid.resizeGrid(gridEntity, newRows, newCols)
    -- Returns: { success = bool, overflow = { {item=entity, oldSlot=N}, ... } }
overflowCount = grid.getOverflowCount(gridEntity, newRows, newCols)

EVENTS (via hump.signal):
------------------------
"grid_item_added"     (gridEntity, slotIndex, itemEntity)
"grid_item_removed"   (gridEntity, slotIndex, itemEntity)
"grid_item_moved"     (gridEntity, fromSlot, toSlot, itemEntity)
"grid_items_swapped"  (gridEntity, slot1, slot2, item1, item2)
"grid_stack_changed"  (gridEntity, slotIndex, itemEntity, oldCount, newCount)
"grid_stack_split"    (gridEntity, slotIndex, amount, newItemEntity)
"grid_resized"        (gridEntity, newRows, newCols, overflowItems)
"inventory_full"      (gridEntity, itemEntity)  -- emitted when grid has no empty slots

================================================================================
]]

local grid = {}

local signal = require("external.hump.signal")
local itemRegistry = require("core.item_location_registry")

local _gridDataRegistry = {}

local function getGridComponent(gridEntity)
    if not registry:valid(gridEntity) then
        return nil
    end
    local key = tostring(gridEntity)
    return _gridDataRegistry[key]
end

local function getOrCreateGridData(gridEntity)
    if not registry:valid(gridEntity) then
        return nil
    end
    local key = tostring(gridEntity)
    if not _gridDataRegistry[key] then
        _gridDataRegistry[key] = {
            rows = 0,
            cols = 0,
            slots = {},
            config = {},
        }
    end
    return _gridDataRegistry[key]
end

function grid.cleanup(gridEntity)
    if gridEntity then
        local key = tostring(gridEntity)
        _gridDataRegistry[key] = nil
    end
end

--------------------------------------------------------------------------------
-- Grid Dimensions
--------------------------------------------------------------------------------

function grid.getDimensions(gridEntity)
    local data = getGridComponent(gridEntity)
    if not data then return 0, 0 end
    return data.rows, data.cols
end

function grid.getCapacity(gridEntity)
    local rows, cols = grid.getDimensions(gridEntity)
    return rows * cols
end

--------------------------------------------------------------------------------
-- Slot Access
--------------------------------------------------------------------------------

function grid.getSlotEntity(gridEntity, slotIndex)
    local data = getGridComponent(gridEntity)
    if not data or not data.slots[slotIndex] then return nil end
    return data.slots[slotIndex].entity
end

function grid.getAllSlots(gridEntity)
    local data = getGridComponent(gridEntity)
    if not data then return {} end
    
    local result = {}
    for i = 1, data.rows * data.cols do
        if data.slots[i] then
            table.insert(result, data.slots[i].entity)
        end
    end
    return result
end

function grid.getUsedSlotCount(gridEntity)
    local data = getGridComponent(gridEntity)
    if not data then return 0 end
    
    local count = 0
    for _, slot in pairs(data.slots) do
        if slot.item then
            count = count + 1
        end
    end
    return count
end

function grid.getEmptySlotCount(gridEntity)
    return grid.getCapacity(gridEntity) - grid.getUsedSlotCount(gridEntity)
end

--------------------------------------------------------------------------------
-- Item Access
--------------------------------------------------------------------------------

function grid.getItemAtIndex(gridEntity, slotIndex)
    local data = getGridComponent(gridEntity)
    if not data or not data.slots[slotIndex] then return nil end
    return data.slots[slotIndex].item
end

function grid.getItemAt(gridEntity, row, col)
    local data = getGridComponent(gridEntity)
    if not data then return nil end
    local slotIndex = (row - 1) * data.cols + col
    return grid.getItemAtIndex(gridEntity, slotIndex)
end

function grid.getAllItems(gridEntity)
    local data = getGridComponent(gridEntity)
    if not data then return {} end
    
    local result = {}
    for i, slot in pairs(data.slots) do
        if slot.item then
            result[i] = slot.item
        end
    end
    return result
end

function grid.getItemList(gridEntity)
    local data = getGridComponent(gridEntity)
    if not data then return {} end
    
    local result = {}
    for i, slot in pairs(data.slots) do
        if slot.item then
            table.insert(result, { slot = i, item = slot.item })
        end
    end
    return result
end

--------------------------------------------------------------------------------
-- Find Operations
--------------------------------------------------------------------------------

function grid.findSlotContaining(gridEntity, itemEntity)
    local data = getGridComponent(gridEntity)
    if not data then return nil end
    
    for i, slot in pairs(data.slots) do
        if slot.item == itemEntity then
            return i
        end
    end
    return nil
end

function grid.findEmptySlot(gridEntity)
    local data = getGridComponent(gridEntity)
    if not data then return nil end
    
    for i = 1, data.rows * data.cols do
        if data.slots[i] and not data.slots[i].item then
            return i
        end
    end
    return nil
end

function grid.findSlotsMatching(gridEntity, predicate)
    local data = getGridComponent(gridEntity)
    if not data then return {} end
    
    local result = {}
    for i, slot in pairs(data.slots) do
        if predicate(slot, slot.item) then
            table.insert(result, i)
        end
    end
    return result
end

--------------------------------------------------------------------------------
-- Slot State
--------------------------------------------------------------------------------

function grid.isSlotLocked(gridEntity, slotIndex)
    local data = getGridComponent(gridEntity)
    if not data or not data.slots[slotIndex] then return false end
    return data.slots[slotIndex].locked == true
end

function grid.setSlotLocked(gridEntity, slotIndex, locked)
    local data = getGridComponent(gridEntity)
    if not data or not data.slots[slotIndex] then return end
    data.slots[slotIndex].locked = locked
end

function grid.canSlotAccept(gridEntity, slotIndex, itemEntity)
    local data = getGridComponent(gridEntity)
    if not data or not data.slots[slotIndex] then return false end
    
    local slot = data.slots[slotIndex]
    
    if slot.locked then
        return false
    end
    
    if slot.item and not data.config.stackable then
        return false
    end
    
    if data.config.filter then
        if not data.config.filter(itemEntity, slotIndex) then
            return false
        end
    end
    
    if slot.filter then
        if not slot.filter(itemEntity) then
            return false
        end
    end
    
    return true
end

--------------------------------------------------------------------------------
-- Item Operations
--------------------------------------------------------------------------------

local function getStackId(itemEntity)
    local script = getScriptTableFromEntityID(itemEntity)
    if script and script.stackId then
        return script.stackId
    end
    return nil
end

function grid.addItem(gridEntity, itemEntity, slotIndex)
    local data = getGridComponent(gridEntity)
    if not data then return false, nil end

    -- Find first empty slot if not specified
    if not slotIndex then
        slotIndex = grid.findEmptySlot(gridEntity)
        if not slotIndex then
            -- Grid is full - emit signal for user feedback
            signal.emit("inventory_full", gridEntity, itemEntity)
            return false, nil
        end
    end
    
    local slot = data.slots[slotIndex]
    if not slot then return false, nil end
    
    -- Check if can accept
    if slot.locked then
        return false, nil
    end
    
    -- Check filters
    if data.config.filter then
        if not data.config.filter(itemEntity, slotIndex) then
            return false, nil
        end
    end
    
    if slot.filter then
        if not slot.filter(itemEntity) then
            return false, nil
        end
    end
    
    if slot.item then
        if data.config.stackable then
            local existingStackId = getStackId(slot.item)
            local newStackId = getStackId(itemEntity)
            
            if existingStackId and newStackId and existingStackId == newStackId then
                local maxStack = data.config.maxStackSize or 999
                if slot.stackCount < maxStack then
                    local oldCount = slot.stackCount
                    slot.stackCount = math.min(slot.stackCount + 1, maxStack)
                    signal.emit("grid_stack_changed", gridEntity, slotIndex, slot.item, oldCount, slot.stackCount)
                    return true, slotIndex, "stacked"
                end
            end
        end
        return false, nil, nil
    end
    
    slot.item = itemEntity
    slot.stackCount = 1

    -- Register item location in the registry
    itemRegistry.register(itemEntity, gridEntity, slotIndex)

    signal.emit("grid_item_added", gridEntity, slotIndex, itemEntity)

    return true, slotIndex, "placed"
end

function grid.removeItem(gridEntity, slotIndex)
    local data = getGridComponent(gridEntity)
    if not data or not data.slots[slotIndex] then return nil end

    local slot = data.slots[slotIndex]

    if slot.locked then
        return nil
    end

    local item = slot.item
    if not item then return nil end

    slot.item = nil
    slot.stackCount = 0

    -- Unregister item from location registry
    itemRegistry.unregister(item)

    signal.emit("grid_item_removed", gridEntity, slotIndex, item)

    return item
end

function grid.moveItem(gridEntity, fromSlot, toSlot)
    local data = getGridComponent(gridEntity)
    if not data then return false end

    local sourceSlot = data.slots[fromSlot]
    local targetSlot = data.slots[toSlot]

    if not sourceSlot or not targetSlot then return false end
    if not sourceSlot.item then return false end
    if sourceSlot.locked or targetSlot.locked then return false end
    if targetSlot.item then return false end  -- Target must be empty

    local item = sourceSlot.item
    local stackCount = sourceSlot.stackCount

    sourceSlot.item = nil
    sourceSlot.stackCount = 0

    targetSlot.item = item
    targetSlot.stackCount = stackCount

    -- Update item location in registry (same grid, new slot)
    itemRegistry.register(item, gridEntity, toSlot)

    signal.emit("grid_item_moved", gridEntity, fromSlot, toSlot, item)

    return true
end

function grid.swapItems(gridEntity, slot1, slot2)
    local data = getGridComponent(gridEntity)
    if not data then return false end

    local s1 = data.slots[slot1]
    local s2 = data.slots[slot2]

    if not s1 or not s2 then return false end
    if s1.locked or s2.locked then return false end

    local tempItem = s1.item
    local tempCount = s1.stackCount

    s1.item = s2.item
    s1.stackCount = s2.stackCount

    s2.item = tempItem
    s2.stackCount = tempCount

    -- Update item locations in registry for both swapped items
    if s1.item then
        itemRegistry.register(s1.item, gridEntity, slot1)
    end
    if s2.item then
        itemRegistry.register(s2.item, gridEntity, slot2)
    end

    signal.emit("grid_items_swapped", gridEntity, slot1, slot2, s2.item, s1.item)

    return true
end

function grid.mergeStacks(gridEntity, fromSlot, toSlot)
    local data = getGridComponent(gridEntity)
    if not data then return false, 0 end
    if not data.config.stackable then return false, 0 end
    
    local source = data.slots[fromSlot]
    local target = data.slots[toSlot]
    
    if not source or not target then return false, 0 end
    if source.locked or target.locked then return false, 0 end
    if not source.item or not target.item then return false, 0 end
    
    local sourceStackId = getStackId(source.item)
    local targetStackId = getStackId(target.item)
    if not sourceStackId or sourceStackId ~= targetStackId then return false, 0 end
    
    local maxStack = data.config.maxStackSize or 999
    local available = maxStack - target.stackCount
    if available <= 0 then return false, 0 end
    
    local toTransfer = math.min(source.stackCount, available)
    local oldTargetCount = target.stackCount
    local oldSourceCount = source.stackCount
    
    target.stackCount = target.stackCount + toTransfer
    source.stackCount = source.stackCount - toTransfer
    
    signal.emit("grid_stack_changed", gridEntity, toSlot, target.item, oldTargetCount, target.stackCount)
    
    if source.stackCount <= 0 then
        local removedItem = source.item
        source.item = nil
        source.stackCount = 0
        signal.emit("grid_item_removed", gridEntity, fromSlot, removedItem)
    else
        signal.emit("grid_stack_changed", gridEntity, fromSlot, source.item, oldSourceCount, source.stackCount)
    end
    
    return true, toTransfer
end

function grid.splitStack(gridEntity, slotIndex, amount, newItemEntity)
    local data = getGridComponent(gridEntity)
    if not data then return false end
    
    local slot = data.slots[slotIndex]
    if not slot or not slot.item then return false end
    if slot.locked then return false end
    if slot.stackCount <= 1 then return false end
    
    amount = math.min(amount or 1, slot.stackCount - 1)
    if amount <= 0 then return false end
    
    local oldCount = slot.stackCount
    slot.stackCount = slot.stackCount - amount
    
    signal.emit("grid_stack_changed", gridEntity, slotIndex, slot.item, oldCount, slot.stackCount)
    signal.emit("grid_stack_split", gridEntity, slotIndex, amount, newItemEntity)
    
    return true, amount
end

--------------------------------------------------------------------------------
-- Stack Operations
--------------------------------------------------------------------------------

function grid.getStackCount(gridEntity, slotIndex)
    local data = getGridComponent(gridEntity)
    if not data or not data.slots[slotIndex] then return 0 end
    return data.slots[slotIndex].stackCount or 0
end

function grid.addToStack(gridEntity, slotIndex, amount)
    local data = getGridComponent(gridEntity)
    if not data or not data.slots[slotIndex] then return false end
    
    local slot = data.slots[slotIndex]
    if not slot.item then return false end
    
    local maxStack = data.config.maxStackSize or 999
    local oldCount = slot.stackCount
    slot.stackCount = math.min(slot.stackCount + amount, maxStack)
    
    if oldCount ~= slot.stackCount then
        signal.emit("grid_stack_changed", gridEntity, slotIndex, slot.item, oldCount, slot.stackCount)
    end
    
    return true
end

function grid.removeFromStack(gridEntity, slotIndex, amount)
    local data = getGridComponent(gridEntity)
    if not data or not data.slots[slotIndex] then return false end
    
    local slot = data.slots[slotIndex]
    if not slot.item then return false end
    
    local oldCount = slot.stackCount
    slot.stackCount = slot.stackCount - amount
    
    if slot.stackCount <= 0 then
        -- Remove item entirely
        local item = slot.item
        slot.item = nil
        slot.stackCount = 0
        signal.emit("grid_item_removed", gridEntity, slotIndex, item)
    else
        signal.emit("grid_stack_changed", gridEntity, slotIndex, slot.item, oldCount, slot.stackCount)
    end
    
    return true
end

--------------------------------------------------------------------------------
-- Grid Initialization (called by DSL)
--------------------------------------------------------------------------------

function grid.initializeGrid(gridEntity, rows, cols, config, slotsConfig)
    local data = getOrCreateGridData(gridEntity)
    if not data then return false end
    
    data.rows = rows
    data.cols = cols
    data.config = config or {}
    data.slots = {}
    
    -- Create slot data for each position
    for i = 1, rows * cols do
        local slotConfig = slotsConfig and slotsConfig[i] or {}
        data.slots[i] = {
            entity = nil,  -- Will be set when slot entities are created
            item = nil,
            stackCount = 0,
            locked = slotConfig.locked or false,
            filter = slotConfig.filter,
            background = slotConfig.background,
            tooltip = slotConfig.tooltip,
        }
    end
    
    return true
end

function grid.setSlotEntity(gridEntity, slotIndex, slotEntity)
    local data = getGridComponent(gridEntity)
    if not data or not data.slots[slotIndex] then return end
    data.slots[slotIndex].entity = slotEntity
end

function grid.setCallbacks(gridEntity, callbacks)
    local data = getGridComponent(gridEntity)
    if not data then return end
    data.callbacks = callbacks
end

function grid.getCallbacks(gridEntity)
    local data = getGridComponent(gridEntity)
    if not data then return nil end
    return data.callbacks
end

function grid.getConfig(gridEntity)
    local data = getGridComponent(gridEntity)
    if not data then return nil end
    return data.config
end

--------------------------------------------------------------------------------
-- Grid Resize (with overflow detection)
--------------------------------------------------------------------------------

--- Resize a grid, returning items that no longer fit (overflow).
-- Items in slots beyond the new capacity are removed and returned.
-- This does NOT update UI slot entities - caller must handle that.
-- @param gridEntity The grid entity to resize
-- @param newRows New number of rows
-- @param newCols New number of columns
-- @return table { success = bool, overflow = { {item=entity, oldSlot=N}, ... } }
function grid.resizeGrid(gridEntity, newRows, newCols)
    local data = getGridComponent(gridEntity)
    if not data then
        return { success = false, overflow = {} }
    end

    local oldCapacity = data.rows * data.cols
    local newCapacity = newRows * newCols

    local overflow = {}

    -- Collect items in slots that will be removed (slots > newCapacity)
    if newCapacity < oldCapacity then
        for slotIndex = newCapacity + 1, oldCapacity do
            local slot = data.slots[slotIndex]
            if slot and slot.item then
                local item = slot.item
                -- Remove from grid (this will emit grid_item_removed signal)
                local removedItem = grid.removeItem(gridEntity, slotIndex)
                if removedItem then
                    table.insert(overflow, {
                        item = removedItem,
                        oldSlot = slotIndex,
                    })
                end
            end
        end
    end

    -- Update dimensions
    data.rows = newRows
    data.cols = newCols

    -- Clean up slot data beyond new capacity
    for slotIndex = newCapacity + 1, oldCapacity do
        data.slots[slotIndex] = nil
    end

    -- Initialize any new slots (if grid expanded)
    for slotIndex = oldCapacity + 1, newCapacity do
        data.slots[slotIndex] = {
            entity = nil,
            item = nil,
            stackCount = 0,
            locked = false,
            filter = nil,
        }
    end

    -- Emit resize event with overflow info
    signal.emit("grid_resized", gridEntity, data.rows, data.cols, overflow)

    return { success = true, overflow = overflow }
end

--- Check if resizing would cause overflow (items would be displaced).
-- @param gridEntity The grid entity to check
-- @param newRows Proposed new rows
-- @param newCols Proposed new columns
-- @return number Count of items that would overflow
function grid.getOverflowCount(gridEntity, newRows, newCols)
    local data = getGridComponent(gridEntity)
    if not data then return 0 end

    local newCapacity = newRows * newCols
    local count = 0

    for slotIndex, slot in pairs(data.slots) do
        if slotIndex > newCapacity and slot.item then
            count = count + 1
        end
    end

    return count
end

return grid
