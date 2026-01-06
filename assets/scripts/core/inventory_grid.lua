--[[
================================================================================
Inventory Grid API
================================================================================
Helper functions for interacting with inventory grid entities.
Provides a clean Lua API for grid operations.

Usage:
    local grid = require("core.inventory_grid")
    
    local rows, cols = grid.getDimensions(gridEntity)
    local item = grid.getItemAt(gridEntity, 2, 3)
    grid.addItem(gridEntity, itemEntity, slotIndex)

Dependencies: signal (for events)
================================================================================
]]

local grid = {}

local signal = require("external.hump.signal")
local component_cache = require("core.component_cache")

--------------------------------------------------------------------------------
-- Internal: Get grid component
--------------------------------------------------------------------------------

local function getGridComponent(gridEntity)
    if not registry:valid(gridEntity) then
        return nil
    end
    -- Look for InventoryGridComponent (to be created in C++)
    -- For now, use GameObject.config as storage
    local go = component_cache.get(gridEntity, GameObject)
    if go and go.config and go.config._inventoryGrid then
        return go.config._inventoryGrid
    end
    return nil
end

local function getOrCreateGridData(gridEntity)
    local go = component_cache.get(gridEntity, GameObject)
    if not go then return nil end
    go.config = go.config or {}
    if not go.config._inventoryGrid then
        go.config._inventoryGrid = {
            rows = 0,
            cols = 0,
            slots = {},  -- slotIndex -> { entity, item, stackCount, locked, filter }
            config = {},
        }
    end
    return go.config._inventoryGrid
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
    
    -- Check if locked
    if slot.locked then
        return false
    end
    
    -- Check if occupied (and not stackable)
    if slot.item and not data.config.stackable then
        return false
    end
    
    -- Check grid-wide filter
    if data.config.filter then
        if not data.config.filter(itemEntity, slotIndex) then
            return false
        end
    end
    
    -- Check per-slot filter
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
            return false, nil  -- Grid is full
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
    
    -- Handle stacking
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
                    return true, slotIndex
                end
            end
        end
        return false, nil  -- Slot occupied, can't stack
    end
    
    -- Add item to empty slot
    slot.item = itemEntity
    slot.stackCount = 1
    
    signal.emit("grid_item_added", gridEntity, slotIndex, itemEntity)
    
    return true, slotIndex
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
    
    -- Swap
    local tempItem = s1.item
    local tempCount = s1.stackCount
    
    s1.item = s2.item
    s1.stackCount = s2.stackCount
    
    s2.item = tempItem
    s2.stackCount = tempCount
    
    return true
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

return grid
