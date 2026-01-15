local TestRunner = require("tests.test_runner")

TestRunner.describe("UIValidator Module", function()

    TestRunner.it("module loads without error", function()
        local UIValidator = require("core.ui_validator")
        TestRunner.assert_not_nil(UIValidator, "UIValidator module should load")
    end)

    TestRunner.it("has enable/disable API", function()
        local UIValidator = require("core.ui_validator")
        TestRunner.assert_not_nil(UIValidator.enable, "should have enable function")
        TestRunner.assert_not_nil(UIValidator.disable, "should have disable function")
        TestRunner.assert_not_nil(UIValidator.isEnabled, "should have isEnabled function")
    end)

    TestRunner.it("has validate API", function()
        local UIValidator = require("core.ui_validator")
        TestRunner.assert_not_nil(UIValidator.validate, "should have validate function")
    end)

end)

TestRunner.describe("UIValidator Bounds Extraction", function()

    TestRunner.it("getBounds returns entity bounds", function()
        local UIValidator = require("core.ui_validator")
        local dsl = require("ui.ui_syntax_sugar")

        -- Create simple UI
        local ui = dsl.root {
            config = { padding = 0, minWidth = 100, minHeight = 50 },
            children = {}
        }
        local entity = dsl.spawn({ x = 200, y = 150 }, ui)

        -- Wait a frame for layout
        -- (In tests, layout is immediate after spawn)

        local bounds = UIValidator.getBounds(entity)

        TestRunner.assert_not_nil(bounds, "should return bounds table")
        TestRunner.assert_not_nil(bounds.x, "should have x")
        TestRunner.assert_not_nil(bounds.y, "should have y")
        TestRunner.assert_not_nil(bounds.w, "should have width")
        TestRunner.assert_not_nil(bounds.h, "should have height")

        -- Cleanup
        dsl.remove(entity)
    end)

    TestRunner.it("getAllBounds returns bounds for entity and children", function()
        local UIValidator = require("core.ui_validator")
        local dsl = require("ui.ui_syntax_sugar")

        local ui = dsl.root {
            config = { padding = 10 },
            children = {
                dsl.text("Hello", { id = "test_text" })
            }
        }
        local entity = dsl.spawn({ x = 100, y = 100 }, ui)

        local allBounds = UIValidator.getAllBounds(entity)

        TestRunner.assert_not_nil(allBounds, "should return bounds map")
        TestRunner.assert_true(type(allBounds) == "table", "should be table")

        -- Should have at least the root
        local count = 0
        for _, _ in pairs(allBounds) do
            count = count + 1
        end
        TestRunner.assert_true(count >= 1, "should have at least root bounds")

        dsl.remove(entity)
    end)

end)
