--[[
Inventory Grid Tests - TDD
Tests for the new inventory grid DSL and helper API
]]

local TestRunner = require("tests.test_runner")
local describe = TestRunner.describe
local it = TestRunner.it
local assert_equals = TestRunner.assert_equals
local assert_true = TestRunner.assert_true
local assert_nil = TestRunner.assert_nil
local assert_not_nil = TestRunner.assert_not_nil

-- Will be implemented
local dsl = require("ui.ui_syntax_sugar")
local grid = require("core.inventory_grid")
local signal = require("external.hump.signal")

--------------------------------------------------------------------------------
-- Test Helpers
--------------------------------------------------------------------------------

local function createTestGrid(rows, cols, config)
    config = config or {}
    return dsl.inventoryGrid {
        id = "test_grid_" .. tostring(math.random(1000, 9999)),
        rows = rows,
        cols = cols,
        slotSize = { w = 64, h = 64 },
        slotSpacing = 4,
        config = config,
    }
end

local function createTestItem(props)
    props = props or {}
    -- Create a minimal entity with properties
    local entity = registry:create()
    local go = GameObject.new()
    go.state.dragEnabled = true
    registry:emplace(entity, go)
    
    -- Store props in a table we can access
    local script = { entity = entity }
    for k, v in pairs(props) do
        script[k] = v
    end
    
    return entity, script
end

local function spawnTestGrid(gridDef)
    return dsl.spawn({ x = 100, y = 100 }, gridDef)
end

--------------------------------------------------------------------------------
-- SUITE: Grid Creation
--------------------------------------------------------------------------------

describe("InventoryGrid Creation", function()
    
    it("creates grid with correct dimensions", function()
        local gridDef = createTestGrid(3, 4)
        local gridEntity = spawnTestGrid(gridDef)
        
        local rows, cols = grid.getDimensions(gridEntity)
        assert_equals(3, rows, "rows should be 3")
        assert_equals(4, cols, "cols should be 4")
    end)
    
    it("creates correct number of slot entities", function()
        local gridDef = createTestGrid(3, 4)
        local gridEntity = spawnTestGrid(gridDef)
        
        local slots = grid.getAllSlots(gridEntity)
        assert_equals(12, #slots, "should have 12 slots (3x4)")
    end)
    
    it("returns capacity correctly", function()
        local gridDef = createTestGrid(2, 5)
        local gridEntity = spawnTestGrid(gridDef)
        
        local capacity = grid.getCapacity(gridEntity)
        assert_equals(10, capacity, "capacity should be 10 (2x5)")
    end)
    
    it("starts with all slots empty", function()
        local gridDef = createTestGrid(2, 2)
        local gridEntity = spawnTestGrid(gridDef)
        
        local used = grid.getUsedSlotCount(gridEntity)
        local empty = grid.getEmptySlotCount(gridEntity)
        
        assert_equals(0, used, "no slots should be used")
        assert_equals(4, empty, "all 4 slots should be empty")
    end)
    
    it("assigns unique slot indices", function()
        local gridDef = createTestGrid(2, 3)
        local gridEntity = spawnTestGrid(gridDef)
        
        -- Check that we can access each slot by index
        for i = 1, 6 do
            local slot = grid.getSlotEntity(gridEntity, i)
            assert_not_nil(slot, "slot " .. i .. " should exist")
        end
    end)

end)

--------------------------------------------------------------------------------
-- SUITE: Item Operations
--------------------------------------------------------------------------------

describe("InventoryGrid Item Operations", function()
    
    it("adds item to empty slot", function()
        local gridDef = createTestGrid(2, 2)
        local gridEntity = spawnTestGrid(gridDef)
        local item = createTestItem({ id = "test_item" })
        
        local success = grid.addItem(gridEntity, item, 1)
        assert_true(success, "should successfully add item")
        
        local retrieved = grid.getItemAtIndex(gridEntity, 1)
        assert_equals(item, retrieved, "should retrieve same item")
    end)
    
    it("adds item to first empty slot when index is nil", function()
        local gridDef = createTestGrid(2, 2)
        local gridEntity = spawnTestGrid(gridDef)
        local item = createTestItem()
        
        local success, slotIndex = grid.addItem(gridEntity, item, nil)
        assert_true(success, "should add to first empty")
        assert_equals(1, slotIndex, "should be slot 1")
    end)
    
    it("returns false when adding to occupied slot without stacking", function()
        local gridDef = createTestGrid(2, 2, { stackable = false })
        local gridEntity = spawnTestGrid(gridDef)
        local item1 = createTestItem()
        local item2 = createTestItem()
        
        grid.addItem(gridEntity, item1, 1)
        local success = grid.addItem(gridEntity, item2, 1)
        
        assert_true(not success, "should fail to add to occupied slot")
    end)
    
    it("removes item from slot", function()
        local gridDef = createTestGrid(2, 2)
        local gridEntity = spawnTestGrid(gridDef)
        local item = createTestItem()
        
        grid.addItem(gridEntity, item, 1)
        local removed = grid.removeItem(gridEntity, 1)
        
        assert_equals(item, removed, "should return removed item")
        assert_nil(grid.getItemAtIndex(gridEntity, 1), "slot should be empty")
    end)
    
    it("gets item by row and column", function()
        local gridDef = createTestGrid(3, 3)
        local gridEntity = spawnTestGrid(gridDef)
        local item = createTestItem()
        
        -- Slot 5 should be row 2, col 2 (1-indexed)
        grid.addItem(gridEntity, item, 5)
        
        local retrieved = grid.getItemAt(gridEntity, 2, 2)
        assert_equals(item, retrieved, "should get item at row 2, col 2")
    end)
    
    it("swaps items between slots", function()
        local gridDef = createTestGrid(2, 2)
        local gridEntity = spawnTestGrid(gridDef)
        local item1 = createTestItem({ name = "item1" })
        local item2 = createTestItem({ name = "item2" })
        
        grid.addItem(gridEntity, item1, 1)
        grid.addItem(gridEntity, item2, 2)
        
        local success = grid.swapItems(gridEntity, 1, 2)
        assert_true(success, "swap should succeed")
        
        assert_equals(item2, grid.getItemAtIndex(gridEntity, 1))
        assert_equals(item1, grid.getItemAtIndex(gridEntity, 2))
    end)
    
    it("moves item to empty slot", function()
        local gridDef = createTestGrid(2, 2)
        local gridEntity = spawnTestGrid(gridDef)
        local item = createTestItem()
        
        grid.addItem(gridEntity, item, 1)
        local success = grid.moveItem(gridEntity, 1, 3)
        
        assert_true(success, "move should succeed")
        assert_nil(grid.getItemAtIndex(gridEntity, 1), "old slot empty")
        assert_equals(item, grid.getItemAtIndex(gridEntity, 3), "new slot has item")
    end)

end)

--------------------------------------------------------------------------------
-- SUITE: Find Operations
--------------------------------------------------------------------------------

describe("InventoryGrid Find Operations", function()
    
    it("finds slot containing item", function()
        local gridDef = createTestGrid(3, 3)
        local gridEntity = spawnTestGrid(gridDef)
        local item = createTestItem()
        
        grid.addItem(gridEntity, item, 5)
        
        local slotIndex = grid.findSlotContaining(gridEntity, item)
        assert_equals(5, slotIndex, "should find item at slot 5")
    end)
    
    it("returns nil when item not in grid", function()
        local gridDef = createTestGrid(2, 2)
        local gridEntity = spawnTestGrid(gridDef)
        local item = createTestItem()
        
        local slotIndex = grid.findSlotContaining(gridEntity, item)
        assert_nil(slotIndex, "should return nil for item not in grid")
    end)
    
    it("finds first empty slot", function()
        local gridDef = createTestGrid(2, 2)
        local gridEntity = spawnTestGrid(gridDef)
        
        grid.addItem(gridEntity, createTestItem(), 1)
        grid.addItem(gridEntity, createTestItem(), 2)
        
        local emptySlot = grid.findEmptySlot(gridEntity)
        assert_equals(3, emptySlot, "first empty should be slot 3")
    end)
    
    it("returns nil when no empty slots", function()
        local gridDef = createTestGrid(1, 2)
        local gridEntity = spawnTestGrid(gridDef)
        
        grid.addItem(gridEntity, createTestItem(), 1)
        grid.addItem(gridEntity, createTestItem(), 2)
        
        local emptySlot = grid.findEmptySlot(gridEntity)
        assert_nil(emptySlot, "should return nil when full")
    end)
    
    it("gets all items as table", function()
        local gridDef = createTestGrid(2, 2)
        local gridEntity = spawnTestGrid(gridDef)
        local item1 = createTestItem()
        local item2 = createTestItem()
        
        grid.addItem(gridEntity, item1, 1)
        grid.addItem(gridEntity, item2, 3)
        
        local items = grid.getAllItems(gridEntity)
        assert_equals(item1, items[1])
        assert_nil(items[2])
        assert_equals(item2, items[3])
    end)

end)

--------------------------------------------------------------------------------
-- SUITE: Filtering
--------------------------------------------------------------------------------

describe("InventoryGrid Filtering", function()
    
    it("rejects item when grid filter fails", function()
        local gridDef = createTestGrid(2, 2, {
            filter = function(item)
                local script = getScriptTableFromEntityID(item)
                return script and script.category == "card"
            end
        })
        local gridEntity = spawnTestGrid(gridDef)
        local item = createTestItem({ category = "weapon" })
        
        local success = grid.addItem(gridEntity, item, 1)
        assert_true(not success, "should reject non-card item")
    end)
    
    it("accepts item when grid filter passes", function()
        local gridDef = createTestGrid(2, 2, {
            filter = function(item)
                local script = getScriptTableFromEntityID(item)
                return script and script.category == "card"
            end
        })
        local gridEntity = spawnTestGrid(gridDef)
        local item = createTestItem({ category = "card" })
        
        local success = grid.addItem(gridEntity, item, 1)
        assert_true(success, "should accept card item")
    end)
    
    it("applies per-slot filter", function()
        local gridDef = dsl.inventoryGrid {
            id = "filter_test",
            rows = 2, cols = 2,
            slotSize = { w = 64, h = 64 },
            slots = {
                [1] = {
                    filter = function(item)
                        local script = getScriptTableFromEntityID(item)
                        return script and script.element == "Fire"
                    end
                }
            }
        }
        local gridEntity = spawnTestGrid(gridDef)
        
        local fireItem = createTestItem({ element = "Fire" })
        local iceItem = createTestItem({ element = "Ice" })
        
        assert_true(grid.addItem(gridEntity, fireItem, 1), "fire item should be accepted in slot 1")
        assert_true(not grid.addItem(gridEntity, iceItem, 1), "ice item should be rejected in slot 1")
        assert_true(grid.addItem(gridEntity, iceItem, 2), "ice item should be accepted in slot 2")
    end)
    
    it("checks canSlotAccept without adding", function()
        local gridDef = createTestGrid(2, 2, {
            filter = function(item)
                local script = getScriptTableFromEntityID(item)
                return script and script.valid == true
            end
        })
        local gridEntity = spawnTestGrid(gridDef)
        
        local validItem = createTestItem({ valid = true })
        local invalidItem = createTestItem({ valid = false })
        
        assert_true(grid.canSlotAccept(gridEntity, 1, validItem))
        assert_true(not grid.canSlotAccept(gridEntity, 1, invalidItem))
    end)

end)

--------------------------------------------------------------------------------
-- SUITE: Stacking
--------------------------------------------------------------------------------

describe("InventoryGrid Stacking", function()
    
    it("stacks identical items when stackable", function()
        local gridDef = createTestGrid(2, 2, { stackable = true })
        local gridEntity = spawnTestGrid(gridDef)
        
        local item1 = createTestItem({ id = "potion", stackId = "health_potion" })
        local item2 = createTestItem({ id = "potion", stackId = "health_potion" })
        
        grid.addItem(gridEntity, item1, 1)
        grid.addItem(gridEntity, item2, 1)
        
        assert_equals(2, grid.getStackCount(gridEntity, 1))
    end)
    
    it("does not stack items with different stackIds", function()
        local gridDef = createTestGrid(2, 2, { stackable = true })
        local gridEntity = spawnTestGrid(gridDef)
        
        local item1 = createTestItem({ stackId = "health_potion" })
        local item2 = createTestItem({ stackId = "mana_potion" })
        
        grid.addItem(gridEntity, item1, 1)
        local success = grid.addItem(gridEntity, item2, 1)
        
        assert_true(not success, "different items should not stack")
        assert_equals(1, grid.getStackCount(gridEntity, 1))
    end)
    
    it("respects maxStackSize", function()
        local gridDef = createTestGrid(2, 2, { 
            stackable = true,
            maxStackSize = 3
        })
        local gridEntity = spawnTestGrid(gridDef)
        
        for i = 1, 5 do
            grid.addItem(gridEntity, createTestItem({ stackId = "test" }), 1)
        end
        
        assert_equals(3, grid.getStackCount(gridEntity, 1), "should cap at maxStackSize")
    end)
    
    it("adds to stack count", function()
        local gridDef = createTestGrid(2, 2, { stackable = true })
        local gridEntity = spawnTestGrid(gridDef)
        local item = createTestItem({ stackId = "test" })
        
        grid.addItem(gridEntity, item, 1)
        grid.addToStack(gridEntity, 1, 5)
        
        assert_equals(6, grid.getStackCount(gridEntity, 1))
    end)
    
    it("removes from stack count", function()
        local gridDef = createTestGrid(2, 2, { stackable = true })
        local gridEntity = spawnTestGrid(gridDef)
        local item = createTestItem({ stackId = "test" })
        
        grid.addItem(gridEntity, item, 1)
        grid.addToStack(gridEntity, 1, 5)
        grid.removeFromStack(gridEntity, 1, 3)
        
        assert_equals(3, grid.getStackCount(gridEntity, 1))
    end)
    
    it("removes item when stack reaches zero", function()
        local gridDef = createTestGrid(2, 2, { stackable = true })
        local gridEntity = spawnTestGrid(gridDef)
        local item = createTestItem({ stackId = "test" })
        
        grid.addItem(gridEntity, item, 1)
        grid.removeFromStack(gridEntity, 1, 1)
        
        assert_nil(grid.getItemAtIndex(gridEntity, 1), "slot should be empty")
    end)

end)

--------------------------------------------------------------------------------
-- SUITE: Signal Events
--------------------------------------------------------------------------------

describe("InventoryGrid Signals", function()
    
    it("emits grid_item_added on add", function()
        local received = nil
        local handler = signal.register("grid_item_added", function(g, s, i)
            received = { grid = g, slot = s, item = i }
        end)
        
        local gridDef = createTestGrid(2, 2)
        local gridEntity = spawnTestGrid(gridDef)
        local item = createTestItem()
        
        grid.addItem(gridEntity, item, 1)
        
        assert_not_nil(received, "signal should be received")
        assert_equals(gridEntity, received.grid)
        assert_equals(1, received.slot)
        assert_equals(item, received.item)
        
        signal.remove(handler)
    end)
    
    it("emits grid_item_removed on remove", function()
        local received = nil
        local handler = signal.register("grid_item_removed", function(g, s, i)
            received = { grid = g, slot = s, item = i }
        end)
        
        local gridDef = createTestGrid(2, 2)
        local gridEntity = spawnTestGrid(gridDef)
        local item = createTestItem()
        
        grid.addItem(gridEntity, item, 1)
        grid.removeItem(gridEntity, 1)
        
        assert_not_nil(received, "signal should be received")
        assert_equals(gridEntity, received.grid)
        assert_equals(1, received.slot)
        assert_equals(item, received.item)
        
        signal.remove(handler)
    end)
    
    it("emits grid_item_moved on move", function()
        local received = nil
        local handler = signal.register("grid_item_moved", function(g, from, to, i)
            received = { grid = g, fromSlot = from, toSlot = to, item = i }
        end)
        
        local gridDef = createTestGrid(2, 2)
        local gridEntity = spawnTestGrid(gridDef)
        local item = createTestItem()
        
        grid.addItem(gridEntity, item, 1)
        grid.moveItem(gridEntity, 1, 3)
        
        assert_not_nil(received, "signal should be received")
        assert_equals(1, received.fromSlot)
        assert_equals(3, received.toSlot)
        assert_equals(item, received.item)
        
        signal.remove(handler)
    end)
    
    it("emits grid_stack_changed on stack change", function()
        local received = nil
        local handler = signal.register("grid_stack_changed", function(g, s, i, old, new)
            received = { grid = g, slot = s, item = i, oldCount = old, newCount = new }
        end)
        
        local gridDef = createTestGrid(2, 2, { stackable = true })
        local gridEntity = spawnTestGrid(gridDef)
        local item = createTestItem({ stackId = "test" })
        
        grid.addItem(gridEntity, item, 1)
        grid.addToStack(gridEntity, 1, 5)
        
        assert_not_nil(received, "signal should be received")
        assert_equals(1, received.oldCount)
        assert_equals(6, received.newCount)
        
        signal.remove(handler)
    end)

end)

--------------------------------------------------------------------------------
-- SUITE: Slot State
--------------------------------------------------------------------------------

describe("InventoryGrid Slot State", function()
    
    it("locks and unlocks slots", function()
        local gridDef = createTestGrid(2, 2)
        local gridEntity = spawnTestGrid(gridDef)
        
        assert_true(not grid.isSlotLocked(gridEntity, 1), "slot starts unlocked")
        
        grid.setSlotLocked(gridEntity, 1, true)
        assert_true(grid.isSlotLocked(gridEntity, 1), "slot should be locked")
        
        grid.setSlotLocked(gridEntity, 1, false)
        assert_true(not grid.isSlotLocked(gridEntity, 1), "slot should be unlocked")
    end)
    
    it("prevents adding to locked slot", function()
        local gridDef = createTestGrid(2, 2)
        local gridEntity = spawnTestGrid(gridDef)
        local item = createTestItem()
        
        grid.setSlotLocked(gridEntity, 1, true)
        local success = grid.addItem(gridEntity, item, 1)
        
        assert_true(not success, "should not add to locked slot")
    end)
    
    it("prevents removing from locked slot", function()
        local gridDef = createTestGrid(2, 2)
        local gridEntity = spawnTestGrid(gridDef)
        local item = createTestItem()
        
        grid.addItem(gridEntity, item, 1)
        grid.setSlotLocked(gridEntity, 1, true)
        
        local removed = grid.removeItem(gridEntity, 1)
        assert_nil(removed, "should not remove from locked slot")
    end)
    
    it("respects per-slot locked config", function()
        local gridDef = dsl.inventoryGrid {
            id = "locked_test",
            rows = 2, cols = 2,
            slotSize = { w = 64, h = 64 },
            slots = {
                [3] = { locked = true }
            }
        }
        local gridEntity = spawnTestGrid(gridDef)
        
        assert_true(not grid.isSlotLocked(gridEntity, 1), "slot 1 should be unlocked")
        assert_true(grid.isSlotLocked(gridEntity, 3), "slot 3 should be locked")
    end)

end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

return function()
    print("\n========================================")
    print("INVENTORY GRID TESTS")
    print("========================================")
    return TestRunner.run_all()
end
