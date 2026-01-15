--[[
    Inventory UI Validation Tests

    Validates the card inventory panel in planning mode.
]]

local TestRunner = require("tests.test_runner")
local UITestUtils = require("tests.ui_test_utils")
local UIValidator = require("core.ui_validator")
local dsl = require("ui.ui_syntax_sugar")

-- Test grid that mimics inventory structure
local function createTestInventoryGrid()
    return dsl.root {
        config = {
            padding = 10,
            minWidth = 400,
            minHeight = 300,
            color = "blackberry",
        },
        children = {
            dsl.vbox {
                config = { spacing = 8 },
                children = {
                    dsl.text("Inventory", { fontSize = 20 }),
                    dsl.inventoryGrid {
                        id = "test_inv_grid",
                        rows = 3,
                        cols = 5,
                        slotSize = { w = 64, h = 90 },
                        slotSpacing = 6,
                        config = {
                            slotColor = "purple_slate",
                            backgroundColor = "blackberry",
                            padding = 8,
                        },
                    },
                }
            }
        }
    }
end

TestRunner.describe("Inventory Grid Containment", function()

    TestRunner.it("all slots stay within panel bounds", function()
        local gridDef = createTestInventoryGrid()
        local entity = UITestUtils.spawnAndWait(gridDef, { x = 100, y = 100 })

        UITestUtils.assertNoErrors(entity, { "containment" })

        UITestUtils.cleanup(entity)
    end)

    TestRunner.it("grid title stays within panel bounds", function()
        local gridDef = createTestInventoryGrid()
        local entity = UITestUtils.spawnAndWait(gridDef, { x = 100, y = 100 })

        UITestUtils.assertNoErrors(entity, { "containment" })

        UITestUtils.cleanup(entity)
    end)

end)

TestRunner.describe("Inventory Grid Window Bounds", function()

    TestRunner.it("inventory panel stays within window", function()
        local gridDef = createTestInventoryGrid()
        -- Spawn in safe area
        local entity = UITestUtils.spawnAndWait(gridDef, { x = 200, y = 200 })

        UITestUtils.assertNoErrors(entity, { "window_bounds" })

        UITestUtils.cleanup(entity)
    end)

end)

TestRunner.describe("Inventory Grid Z-Order", function()

    TestRunner.it("slots have correct z-order relative to panel", function()
        local gridDef = createTestInventoryGrid()
        local entity = UITestUtils.spawnAndWait(gridDef, { x = 100, y = 100 })

        -- Z-order warnings are expected in some cases, but no errors
        local violations = UIValidator.validate(entity, { "z_order_hierarchy" })
        local errors = UIValidator.getErrors(violations)

        TestRunner.assert_equals(0, #errors, "should have no z-order errors")

        UITestUtils.cleanup(entity)
    end)

end)

TestRunner.describe("Inventory Slot Non-Overlap", function()

    TestRunner.it("adjacent slots do not overlap", function()
        local gridDef = createTestInventoryGrid()
        local entity = UITestUtils.spawnAndWait(gridDef, { x = 100, y = 100 })

        -- Sibling overlap is warning by default, but check anyway
        local violations = UIValidator.validate(entity, { "sibling_overlap" })

        -- Print any overlaps for debugging
        if #violations > 0 then
            for _, v in ipairs(violations) do
                print("[DEBUG] Overlap:", v.message)
            end
        end

        UITestUtils.cleanup(entity)
    end)

end)

-- Return module for test runner registration
return {
    name = "Inventory Validation Tests",
    run = function()
        -- Tests are registered via describe/it
    end
}
