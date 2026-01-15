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

TestRunner.describe("UIValidator Containment Rule", function()

    TestRunner.it("checkContainment returns no violations for contained children", function()
        local UIValidator = require("core.ui_validator")
        local dsl = require("ui.ui_syntax_sugar")

        -- Parent 200x200, child should fit inside
        local ui = dsl.root {
            config = { padding = 20, minWidth = 200, minHeight = 200 },
            children = {
                dsl.text("Small text", { fontSize = 12 })
            }
        }
        local entity = dsl.spawn({ x = 100, y = 100 }, ui)

        local violations = UIValidator.checkContainment(entity)

        TestRunner.assert_not_nil(violations, "should return violations array")
        TestRunner.assert_equals(0, #violations, "should have no violations for contained children")

        dsl.remove(entity)
    end)

    TestRunner.it("checkContainment detects child escaping parent", function()
        local UIValidator = require("core.ui_validator")

        -- Mock bounds where child escapes parent
        local mockBounds = {
            parent = { x = 100, y = 100, w = 50, h = 50 },
            child = { x = 140, y = 100, w = 30, h = 30 }, -- Escapes right edge (140+30 > 100+50)
        }

        local violations = UIValidator.checkContainmentWithBounds(
            "parent", mockBounds.parent,
            "child", mockBounds.child
        )

        TestRunner.assert_true(#violations > 0, "should detect child escaping parent")
        TestRunner.assert_equals("containment", violations[1].type, "violation type should be containment")
    end)

    TestRunner.it("respects allowEscape flag", function()
        local UIValidator = require("core.ui_validator")

        local mockBounds = {
            parent = { x = 100, y = 100, w = 50, h = 50 },
            child = { x = 140, y = 100, w = 30, h = 30, allowEscape = true },
        }

        local violations = UIValidator.checkContainmentWithBounds(
            "parent", mockBounds.parent,
            "child", mockBounds.child
        )

        TestRunner.assert_equals(0, #violations, "should allow escape when flag set")
    end)

end)

TestRunner.describe("UIValidator Window Bounds Rule", function()

    TestRunner.it("checkWindowBounds returns no violations for UI inside window", function()
        local UIValidator = require("core.ui_validator")
        local dsl = require("ui.ui_syntax_sugar")

        -- Small UI in center of screen
        local ui = dsl.root {
            config = { padding = 10, minWidth = 100, minHeight = 100 },
            children = {}
        }
        local entity = dsl.spawn({ x = 200, y = 200 }, ui)

        local violations = UIValidator.checkWindowBounds(entity)

        TestRunner.assert_not_nil(violations, "should return violations array")
        TestRunner.assert_equals(0, #violations, "should have no violations for UI inside window")

        dsl.remove(entity)
    end)

    TestRunner.it("checkWindowBounds detects UI outside window", function()
        local UIValidator = require("core.ui_validator")

        -- Mock bounds outside window (assuming 1280x720 window)
        local mockBounds = { x = 1300, y = 100, w = 100, h = 100 }
        local windowBounds = { x = 0, y = 0, w = 1280, h = 720 }

        local violations = UIValidator.checkWindowBoundsWithBounds("test_entity", mockBounds, windowBounds)

        TestRunner.assert_true(#violations > 0, "should detect UI outside window")
        TestRunner.assert_equals("window_bounds", violations[1].type, "violation type should be window_bounds")
    end)

end)
