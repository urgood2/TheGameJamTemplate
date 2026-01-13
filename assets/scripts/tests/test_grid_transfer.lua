--[[
Grid Transfer Tests - TDD
Tests for cross-grid item transfer with rollback safety
]]

local TestRunner = require("tests.test_runner")
local describe = TestRunner.describe
local it = TestRunner.it
local assert_equals = TestRunner.assert_equals
local assert_true = TestRunner.assert_true
local assert_nil = TestRunner.assert_nil
local assert_not_nil = TestRunner.assert_not_nil

local dsl = require("ui.ui_syntax_sugar")
local grid = require("core.inventory_grid")
local transfer = require("core.grid_transfer")
local itemRegistry = require("core.item_location_registry")
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
    local entity = registry:create()
    local go = GameObject.new()
    go.state.dragEnabled = true
    registry:emplace(entity, go)

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
-- SUITE: Basic Transfer Operations
--------------------------------------------------------------------------------

describe("Grid Transfer Basic Operations", function()

    it("transfers item between two grids", function()
        local sourceGridDef = createTestGrid(2, 2)
        local targetGridDef = createTestGrid(2, 2)
        local sourceGrid = spawnTestGrid(sourceGridDef)
        local targetGrid = spawnTestGrid(targetGridDef)
        local item = createTestItem({ id = "test_card" })

        -- Add item to source
        grid.addItem(sourceGrid, item, 1)
        itemRegistry.register(item, sourceGrid, 1)

        -- Transfer to target
        local result = transfer.transferItem({
            item = item,
            fromGrid = sourceGrid,
            fromSlot = 1,
            toGrid = targetGrid,
            toSlot = 2,
        })

        assert_true(result.success, "transfer should succeed")
        assert_nil(grid.getItemAtIndex(sourceGrid, 1), "source should be empty")
        assert_equals(item, grid.getItemAtIndex(targetGrid, 2), "target should have item")
    end)

    it("transfers to first empty slot when toSlot is nil", function()
        local sourceGridDef = createTestGrid(2, 2)
        local targetGridDef = createTestGrid(2, 2)
        local sourceGrid = spawnTestGrid(sourceGridDef)
        local targetGrid = spawnTestGrid(targetGridDef)
        local item = createTestItem()
        local blocker = createTestItem()

        grid.addItem(sourceGrid, item, 1)
        itemRegistry.register(item, sourceGrid, 1)

        -- Fill slot 1 in target
        grid.addItem(targetGrid, blocker, 1)

        local result = transfer.transferItem({
            item = item,
            fromGrid = sourceGrid,
            fromSlot = 1,
            toGrid = targetGrid,
        })

        assert_true(result.success, "transfer should succeed")
        assert_equals(2, result.toSlot, "should transfer to first empty slot (2)")
    end)

    it("updates item location registry after transfer", function()
        local sourceGridDef = createTestGrid(2, 2)
        local targetGridDef = createTestGrid(2, 2)
        local sourceGrid = spawnTestGrid(sourceGridDef)
        local targetGrid = spawnTestGrid(targetGridDef)
        local item = createTestItem()

        grid.addItem(sourceGrid, item, 1)
        itemRegistry.register(item, sourceGrid, 1)

        transfer.transferItem({
            item = item,
            fromGrid = sourceGrid,
            fromSlot = 1,
            toGrid = targetGrid,
            toSlot = 3,
        })

        local location = itemRegistry.getLocation(item)
        assert_not_nil(location, "location should exist")
        assert_equals(targetGrid, location.grid, "registry should show target grid")
        assert_equals(3, location.slot, "registry should show correct slot")
    end)

end)

--------------------------------------------------------------------------------
-- SUITE: Rollback Safety
--------------------------------------------------------------------------------

describe("Grid Transfer Rollback Safety", function()

    it("leaves source unchanged when target slot is occupied", function()
        local sourceGridDef = createTestGrid(2, 2)
        local targetGridDef = createTestGrid(2, 2)
        local sourceGrid = spawnTestGrid(sourceGridDef)
        local targetGrid = spawnTestGrid(targetGridDef)
        local item = createTestItem()
        local blocker = createTestItem()

        grid.addItem(sourceGrid, item, 1)
        itemRegistry.register(item, sourceGrid, 1)
        grid.addItem(targetGrid, blocker, 2)

        local result = transfer.transferItem({
            item = item,
            fromGrid = sourceGrid,
            fromSlot = 1,
            toGrid = targetGrid,
            toSlot = 2,
        })

        assert_true(not result.success, "transfer should fail")
        assert_equals("target_slot_occupied", result.reason)
        assert_equals(item, grid.getItemAtIndex(sourceGrid, 1), "source should still have item")
    end)

    it("leaves source unchanged when target slot is locked", function()
        local sourceGridDef = createTestGrid(2, 2)
        local targetGridDef = createTestGrid(2, 2)
        local sourceGrid = spawnTestGrid(sourceGridDef)
        local targetGrid = spawnTestGrid(targetGridDef)
        local item = createTestItem()

        grid.addItem(sourceGrid, item, 1)
        itemRegistry.register(item, sourceGrid, 1)
        grid.setSlotLocked(targetGrid, 2, true)

        local result = transfer.transferItem({
            item = item,
            fromGrid = sourceGrid,
            fromSlot = 1,
            toGrid = targetGrid,
            toSlot = 2,
        })

        assert_true(not result.success, "transfer should fail")
        assert_equals("target_slot_locked", result.reason)
        assert_equals(item, grid.getItemAtIndex(sourceGrid, 1), "source should still have item")
    end)

    it("leaves source unchanged when filter rejects item", function()
        local sourceGridDef = createTestGrid(2, 2)
        local targetGridDef = createTestGrid(2, 2, {
            filter = function(item)
                local script = getScriptTableFromEntityID(item)
                return script and script.category == "spell"
            end
        })
        local sourceGrid = spawnTestGrid(sourceGridDef)
        local targetGrid = spawnTestGrid(targetGridDef)
        local item = createTestItem({ category = "weapon" })

        grid.addItem(sourceGrid, item, 1)
        itemRegistry.register(item, sourceGrid, 1)

        local result = transfer.transferItem({
            item = item,
            fromGrid = sourceGrid,
            fromSlot = 1,
            toGrid = targetGrid,
            toSlot = 1,
        })

        assert_true(not result.success, "transfer should fail")
        assert_equals("filter_rejected", result.reason)
        assert_equals(item, grid.getItemAtIndex(sourceGrid, 1), "source should still have item")
    end)

    it("fails when target grid has no empty slots", function()
        local sourceGridDef = createTestGrid(2, 2)
        local targetGridDef = createTestGrid(1, 1)
        local sourceGrid = spawnTestGrid(sourceGridDef)
        local targetGrid = spawnTestGrid(targetGridDef)
        local item = createTestItem()
        local blocker = createTestItem()

        grid.addItem(sourceGrid, item, 1)
        itemRegistry.register(item, sourceGrid, 1)
        grid.addItem(targetGrid, blocker, 1)

        local result = transfer.transferItem({
            item = item,
            fromGrid = sourceGrid,
            fromSlot = 1,
            toGrid = targetGrid,
            -- No toSlot specified, will try to find empty
        })

        assert_true(not result.success, "transfer should fail")
        assert_equals("no_empty_slot", result.reason)
        assert_equals(item, grid.getItemAtIndex(sourceGrid, 1), "source should still have item")
    end)

end)

--------------------------------------------------------------------------------
-- SUITE: Validation Errors
--------------------------------------------------------------------------------

describe("Grid Transfer Validation", function()

    it("fails with invalid item", function()
        local sourceGridDef = createTestGrid(2, 2)
        local targetGridDef = createTestGrid(2, 2)
        local sourceGrid = spawnTestGrid(sourceGridDef)
        local targetGrid = spawnTestGrid(targetGridDef)

        local result = transfer.transferItem({
            item = nil,
            fromGrid = sourceGrid,
            fromSlot = 1,
            toGrid = targetGrid,
        })

        assert_true(not result.success)
        assert_equals("invalid_item", result.reason)
    end)

    it("fails when item not at specified source slot", function()
        local sourceGridDef = createTestGrid(2, 2)
        local targetGridDef = createTestGrid(2, 2)
        local sourceGrid = spawnTestGrid(sourceGridDef)
        local targetGrid = spawnTestGrid(targetGridDef)
        local item = createTestItem()

        -- Item is at slot 2, but we claim slot 1
        grid.addItem(sourceGrid, item, 2)
        itemRegistry.register(item, sourceGrid, 2)

        local result = transfer.transferItem({
            item = item,
            fromGrid = sourceGrid,
            fromSlot = 1,  -- Wrong slot!
            toGrid = targetGrid,
        })

        assert_true(not result.success)
        assert_equals("item_not_in_source", result.reason)
    end)

end)

--------------------------------------------------------------------------------
-- SUITE: Callbacks
--------------------------------------------------------------------------------

describe("Grid Transfer Callbacks", function()

    it("calls onSuccess callback on successful transfer", function()
        local sourceGridDef = createTestGrid(2, 2)
        local targetGridDef = createTestGrid(2, 2)
        local sourceGrid = spawnTestGrid(sourceGridDef)
        local targetGrid = spawnTestGrid(targetGridDef)
        local item = createTestItem()

        grid.addItem(sourceGrid, item, 1)
        itemRegistry.register(item, sourceGrid, 1)

        local callbackResult = nil
        transfer.transferItem({
            item = item,
            fromGrid = sourceGrid,
            fromSlot = 1,
            toGrid = targetGrid,
            toSlot = 2,
            onSuccess = function(result)
                callbackResult = result
            end,
        })

        assert_not_nil(callbackResult, "onSuccess should be called")
        assert_true(callbackResult.success)
        assert_equals(2, callbackResult.toSlot)
    end)

    it("calls onFail callback on failed transfer", function()
        local sourceGridDef = createTestGrid(2, 2)
        local targetGridDef = createTestGrid(2, 2)
        local sourceGrid = spawnTestGrid(sourceGridDef)
        local targetGrid = spawnTestGrid(targetGridDef)
        local item = createTestItem()
        local blocker = createTestItem()

        grid.addItem(sourceGrid, item, 1)
        itemRegistry.register(item, sourceGrid, 1)
        grid.addItem(targetGrid, blocker, 2)

        local failReason = nil
        transfer.transferItem({
            item = item,
            fromGrid = sourceGrid,
            fromSlot = 1,
            toGrid = targetGrid,
            toSlot = 2,
            onFail = function(reason)
                failReason = reason
            end,
        })

        assert_equals("target_slot_occupied", failReason)
    end)

end)

--------------------------------------------------------------------------------
-- SUITE: Signals
--------------------------------------------------------------------------------

describe("Grid Transfer Signals", function()

    it("emits grid_transfer_success on successful transfer", function()
        local received = nil
        local handler = signal.register("grid_transfer_success", function(item, fromGrid, fromSlot, toGrid, toSlot)
            received = {
                item = item,
                fromGrid = fromGrid,
                fromSlot = fromSlot,
                toGrid = toGrid,
                toSlot = toSlot,
            }
        end)

        local sourceGridDef = createTestGrid(2, 2)
        local targetGridDef = createTestGrid(2, 2)
        local sourceGrid = spawnTestGrid(sourceGridDef)
        local targetGrid = spawnTestGrid(targetGridDef)
        local item = createTestItem()

        grid.addItem(sourceGrid, item, 1)
        itemRegistry.register(item, sourceGrid, 1)

        transfer.transferItem({
            item = item,
            fromGrid = sourceGrid,
            fromSlot = 1,
            toGrid = targetGrid,
            toSlot = 3,
        })

        assert_not_nil(received, "signal should be received")
        assert_equals(item, received.item)
        assert_equals(sourceGrid, received.fromGrid)
        assert_equals(1, received.fromSlot)
        assert_equals(targetGrid, received.toGrid)
        assert_equals(3, received.toSlot)

        signal.remove(handler)
    end)

    it("emits grid_transfer_failed on failed transfer", function()
        local received = nil
        local handler = signal.register("grid_transfer_failed", function(item, fromGrid, toGrid, reason)
            received = {
                item = item,
                fromGrid = fromGrid,
                toGrid = toGrid,
                reason = reason,
            }
        end)

        local sourceGridDef = createTestGrid(2, 2)
        local targetGridDef = createTestGrid(2, 2)
        local sourceGrid = spawnTestGrid(sourceGridDef)
        local targetGrid = spawnTestGrid(targetGridDef)
        local item = createTestItem()
        local blocker = createTestItem()

        grid.addItem(sourceGrid, item, 1)
        itemRegistry.register(item, sourceGrid, 1)
        grid.addItem(targetGrid, blocker, 2)

        transfer.transferItem({
            item = item,
            fromGrid = sourceGrid,
            fromSlot = 1,
            toGrid = targetGrid,
            toSlot = 2,
        })

        assert_not_nil(received, "signal should be received")
        assert_equals(item, received.item)
        assert_equals("target_slot_occupied", received.reason)

        signal.remove(handler)
    end)

end)

--------------------------------------------------------------------------------
-- SUITE: Convenience Functions
--------------------------------------------------------------------------------

describe("Grid Transfer Convenience Functions", function()

    it("transferItemTo finds item location automatically", function()
        local sourceGridDef = createTestGrid(2, 2)
        local targetGridDef = createTestGrid(2, 2)
        local sourceGrid = spawnTestGrid(sourceGridDef)
        local targetGrid = spawnTestGrid(targetGridDef)
        local item = createTestItem()

        grid.addItem(sourceGrid, item, 3)
        itemRegistry.register(item, sourceGrid, 3)

        -- Use transferItemTo which auto-finds location
        local result = transfer.transferItemTo({
            item = item,
            toGrid = targetGrid,
            toSlot = 1,
        })

        assert_true(result.success, "transfer should succeed")
        assert_equals(3, result.fromSlot, "should report correct source slot")
        assert_nil(grid.getItemAtIndex(sourceGrid, 3), "source should be empty")
        assert_equals(item, grid.getItemAtIndex(targetGrid, 1), "target should have item")
    end)

    it("transferItemTo fails when item not registered", function()
        local targetGridDef = createTestGrid(2, 2)
        local targetGrid = spawnTestGrid(targetGridDef)
        local item = createTestItem()

        -- Item not registered anywhere
        local result = transfer.transferItemTo({
            item = item,
            toGrid = targetGrid,
        })

        assert_true(not result.success)
        assert_equals("item_not_registered", result.reason)
    end)

    it("canTransfer checks without modifying state", function()
        local sourceGridDef = createTestGrid(2, 2)
        local targetGridDef = createTestGrid(2, 2)
        local sourceGrid = spawnTestGrid(sourceGridDef)
        local targetGrid = spawnTestGrid(targetGridDef)
        local item = createTestItem()

        grid.addItem(sourceGrid, item, 1)
        itemRegistry.register(item, sourceGrid, 1)

        -- Check if transfer would succeed
        local canDo, reason = transfer.canTransfer({
            item = item,
            fromGrid = sourceGrid,
            fromSlot = 1,
            toGrid = targetGrid,
            toSlot = 2,
        })

        assert_true(canDo, "canTransfer should return true")

        -- Verify nothing changed
        assert_equals(item, grid.getItemAtIndex(sourceGrid, 1), "item should still be in source")
        assert_nil(grid.getItemAtIndex(targetGrid, 2), "target should still be empty")
    end)

    it("canTransfer returns reason when transfer would fail", function()
        local sourceGridDef = createTestGrid(2, 2)
        local targetGridDef = createTestGrid(2, 2)
        local sourceGrid = spawnTestGrid(sourceGridDef)
        local targetGrid = spawnTestGrid(targetGridDef)
        local item = createTestItem()

        grid.addItem(sourceGrid, item, 1)
        itemRegistry.register(item, sourceGrid, 1)
        grid.setSlotLocked(targetGrid, 2, true)

        local canDo, reason = transfer.canTransfer({
            item = item,
            fromGrid = sourceGrid,
            fromSlot = 1,
            toGrid = targetGrid,
            toSlot = 2,
        })

        assert_true(not canDo, "canTransfer should return false")
        assert_equals("target_slot_locked", reason)
    end)

end)

--------------------------------------------------------------------------------
-- SUITE: Swap Between Grids
--------------------------------------------------------------------------------

describe("Grid Transfer Swap Between Grids", function()

    it("swaps items between two grids", function()
        local grid1Def = createTestGrid(2, 2)
        local grid2Def = createTestGrid(2, 2)
        local grid1 = spawnTestGrid(grid1Def)
        local grid2 = spawnTestGrid(grid2Def)
        local item1 = createTestItem({ name = "sword" })
        local item2 = createTestItem({ name = "shield" })

        grid.addItem(grid1, item1, 1)
        grid.addItem(grid2, item2, 2)
        itemRegistry.register(item1, grid1, 1)
        itemRegistry.register(item2, grid2, 2)

        local result = transfer.swapBetweenGrids({
            item1 = item1,
            grid1 = grid1,
            slot1 = 1,
            item2 = item2,
            grid2 = grid2,
            slot2 = 2,
        })

        assert_true(result.success, "swap should succeed")

        -- Verify items swapped positions
        assert_equals(item2, grid.getItemAtIndex(grid1, 1), "grid1 slot 1 should have item2")
        assert_equals(item1, grid.getItemAtIndex(grid2, 2), "grid2 slot 2 should have item1")

        -- Verify registry updated
        local loc1 = itemRegistry.getLocation(item1)
        local loc2 = itemRegistry.getLocation(item2)
        assert_equals(grid2, loc1.grid)
        assert_equals(2, loc1.slot)
        assert_equals(grid1, loc2.grid)
        assert_equals(1, loc2.slot)
    end)

    it("fails swap when slot is locked", function()
        local grid1Def = createTestGrid(2, 2)
        local grid2Def = createTestGrid(2, 2)
        local grid1 = spawnTestGrid(grid1Def)
        local grid2 = spawnTestGrid(grid2Def)
        local item1 = createTestItem()
        local item2 = createTestItem()

        grid.addItem(grid1, item1, 1)
        grid.addItem(grid2, item2, 2)
        itemRegistry.register(item1, grid1, 1)
        itemRegistry.register(item2, grid2, 2)

        grid.setSlotLocked(grid1, 1, true)

        local result = transfer.swapBetweenGrids({
            item1 = item1,
            grid1 = grid1,
            slot1 = 1,
            item2 = item2,
            grid2 = grid2,
            slot2 = 2,
        })

        assert_true(not result.success)
        assert_equals("slot_locked", result.reason)

        -- Verify items unchanged
        assert_equals(item1, grid.getItemAtIndex(grid1, 1))
        assert_equals(item2, grid.getItemAtIndex(grid2, 2))
    end)

end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

return function()
    print("\n========================================")
    print("GRID TRANSFER TESTS")
    print("========================================")
    return TestRunner.run_all()
end
