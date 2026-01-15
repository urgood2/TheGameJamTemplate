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

TestRunner.describe("UIValidator Sibling Overlap Rule", function()

    TestRunner.it("checkSiblingOverlap returns no violations for non-overlapping siblings", function()
        local UIValidator = require("core.ui_validator")

        local siblings = {
            { id = "a", bounds = { x = 0, y = 0, w = 50, h = 50 } },
            { id = "b", bounds = { x = 60, y = 0, w = 50, h = 50 } }, -- No overlap
        }

        local violations = UIValidator.checkSiblingOverlapWithBounds(siblings)

        TestRunner.assert_equals(0, #violations, "should have no violations for non-overlapping siblings")
    end)

    TestRunner.it("checkSiblingOverlap detects overlapping siblings", function()
        local UIValidator = require("core.ui_validator")

        local siblings = {
            { id = "a", bounds = { x = 0, y = 0, w = 50, h = 50 } },
            { id = "b", bounds = { x = 40, y = 0, w = 50, h = 50 } }, -- Overlaps by 10px
        }

        local violations = UIValidator.checkSiblingOverlapWithBounds(siblings)

        TestRunner.assert_true(#violations > 0, "should detect overlapping siblings")
        TestRunner.assert_equals("sibling_overlap", violations[1].type, "violation type should be sibling_overlap")
    end)

    TestRunner.it("respects allowOverlap flag", function()
        local UIValidator = require("core.ui_validator")

        local siblings = {
            { id = "a", bounds = { x = 0, y = 0, w = 50, h = 50 } },
            { id = "b", bounds = { x = 40, y = 0, w = 50, h = 50, allowOverlap = true } },
        }

        local violations = UIValidator.checkSiblingOverlapWithBounds(siblings)

        TestRunner.assert_equals(0, #violations, "should allow overlap when flag set")
    end)

end)

TestRunner.describe("UIValidator Z-Order Rule", function()

    TestRunner.it("checkZOrder returns no violations for correct hierarchy", function()
        local UIValidator = require("core.ui_validator")

        -- Children have higher z than parent
        local hierarchy = {
            { id = "parent", z = 100, children = { "child1", "child2" } },
            { id = "child1", z = 101, children = {} },
            { id = "child2", z = 102, children = {} },
        }

        local violations = UIValidator.checkZOrderWithHierarchy(hierarchy)

        TestRunner.assert_equals(0, #violations, "should have no violations for correct z-order")
    end)

    TestRunner.it("checkZOrder detects child behind parent", function()
        local UIValidator = require("core.ui_validator")

        -- Child has lower z than parent
        local hierarchy = {
            { id = "parent", z = 100, children = { "child1" } },
            { id = "child1", z = 50, children = {} }, -- Behind parent
        }

        local violations = UIValidator.checkZOrderWithHierarchy(hierarchy)

        TestRunner.assert_true(#violations > 0, "should detect child behind parent")
        TestRunner.assert_equals("z_order_hierarchy", violations[1].type, "violation type should be z_order_hierarchy")
    end)

end)

TestRunner.describe("UIValidator Full Validation", function()

    TestRunner.it("validate runs all rules by default", function()
        local UIValidator = require("core.ui_validator")
        local dsl = require("ui.ui_syntax_sugar")

        local ui = dsl.root {
            config = { padding = 10, minWidth = 100, minHeight = 100 },
            children = {
                dsl.text("Test", { fontSize = 14 })
            }
        }
        local entity = dsl.spawn({ x = 200, y = 200 }, ui)

        local violations = UIValidator.validate(entity)

        TestRunner.assert_not_nil(violations, "should return violations array")
        TestRunner.assert_true(type(violations) == "table", "should be table")

        dsl.remove(entity)
    end)

    TestRunner.it("validate accepts specific rules filter", function()
        local UIValidator = require("core.ui_validator")
        local dsl = require("ui.ui_syntax_sugar")

        local ui = dsl.root {
            config = { padding = 10 },
            children = {}
        }
        local entity = dsl.spawn({ x = 200, y = 200 }, ui)

        -- Only check containment
        local violations = UIValidator.validate(entity, { "containment" })

        TestRunner.assert_not_nil(violations, "should return violations array")

        dsl.remove(entity)
    end)

    TestRunner.it("getErrors filters to error severity only", function()
        local UIValidator = require("core.ui_validator")

        local violations = {
            { type = "containment", severity = "error", entity = 1, message = "test" },
            { type = "sibling_overlap", severity = "warning", entity = 2, message = "test" },
        }

        local errors = UIValidator.getErrors(violations)

        TestRunner.assert_equals(1, #errors, "should return only errors")
        TestRunner.assert_equals("error", errors[1].severity, "should be error severity")
    end)

    TestRunner.it("getWarnings filters to warning severity only", function()
        local UIValidator = require("core.ui_validator")

        local violations = {
            { type = "containment", severity = "error", entity = 1, message = "test" },
            { type = "sibling_overlap", severity = "warning", entity = 2, message = "test" },
        }

        local warnings = UIValidator.getWarnings(violations)

        TestRunner.assert_equals(1, #warnings, "should return only warnings")
        TestRunner.assert_equals("warning", warnings[1].severity, "should be warning severity")
    end)

end)

TestRunner.describe("UITestUtils Module", function()

    TestRunner.it("module loads without error", function()
        local UITestUtils = require("tests.ui_test_utils")
        TestRunner.assert_not_nil(UITestUtils, "UITestUtils module should load")
    end)

    TestRunner.it("spawnAndWait spawns UI and returns entity", function()
        local UITestUtils = require("tests.ui_test_utils")
        local dsl = require("ui.ui_syntax_sugar")

        local ui = dsl.root {
            config = { padding = 10 },
            children = {}
        }

        local entity = UITestUtils.spawnAndWait(ui, { x = 100, y = 100 })

        TestRunner.assert_not_nil(entity, "should return entity")
        TestRunner.assert_true(registry:valid(entity), "entity should be valid")

        dsl.remove(entity)
    end)

    TestRunner.it("assertNoErrors passes for valid UI", function()
        local UITestUtils = require("tests.ui_test_utils")
        local dsl = require("ui.ui_syntax_sugar")

        local ui = dsl.root {
            config = { padding = 10, minWidth = 100, minHeight = 100 },
            children = {}
        }
        local entity = UITestUtils.spawnAndWait(ui, { x = 200, y = 200 })

        -- Should not throw
        local success = pcall(function()
            UITestUtils.assertNoErrors(entity)
        end)

        TestRunner.assert_true(success, "assertNoErrors should pass for valid UI")

        dsl.remove(entity)
    end)

end)

TestRunner.describe("UIValidator Tracked Render Wrappers", function()

    TestRunner.it("trackRender records render info", function()
        local UIValidator = require("core.ui_validator")

        -- Clear previous log
        UIValidator.clearRenderLog()

        -- Mock entities (using numbers as IDs)
        local parentUI = 1000
        local card1 = 1001
        local card2 = 1002

        -- Track renders
        UIValidator.trackRender(parentUI, "layers.ui", { card1, card2 }, 500, "Screen")

        local log = UIValidator.getRenderLog()

        TestRunner.assert_not_nil(log[card1], "card1 should be in render log")
        TestRunner.assert_not_nil(log[card2], "card2 should be in render log")
        TestRunner.assert_equals(parentUI, log[card1].parent, "should track parent")
        TestRunner.assert_equals("layers.ui", log[card1].layer, "should track layer")
        TestRunner.assert_equals(500, log[card1].z, "should track z-order")
        TestRunner.assert_equals("Screen", log[card1].space, "should track space")
    end)

    TestRunner.it("checkRenderConsistency detects layer mismatch", function()
        local UIValidator = require("core.ui_validator")

        UIValidator.clearRenderLog()

        local parentUI = 2000
        local card1 = 2001

        -- Parent renders to ui layer
        UIValidator.trackRender(nil, "layers.ui", { parentUI }, 100, "Screen")
        -- Card renders to different layer
        UIValidator.trackRender(parentUI, "layers.sprites", { card1 }, 200, "Screen")

        local violations = UIValidator.checkRenderConsistency(parentUI)

        TestRunner.assert_true(#violations > 0, "should detect layer mismatch")
        TestRunner.assert_equals("layer_consistency", violations[1].type, "type should be layer_consistency")
    end)

    TestRunner.it("checkRenderConsistency detects space mismatch", function()
        local UIValidator = require("core.ui_validator")

        UIValidator.clearRenderLog()

        local parentUI = 3000
        local card1 = 3001

        -- Parent uses Screen space
        UIValidator.trackRender(nil, "layers.ui", { parentUI }, 100, "Screen")
        -- Card uses World space (mismatch!)
        UIValidator.trackRender(parentUI, "layers.ui", { card1 }, 200, "World")

        local violations = UIValidator.checkRenderConsistency(parentUI)

        TestRunner.assert_true(#violations > 0, "should detect space mismatch")
        TestRunner.assert_equals("space_consistency", violations[1].type, "type should be space_consistency")
    end)

    TestRunner.it("validate surfaces layer mismatch via default rules", function()
        local UIValidator = require("core.ui_validator")

        UIValidator.clearRenderLog()

        local parentUI = 4000
        local child = 4001

        UIValidator.trackRender(nil, "layers.ui", { parentUI }, 10, "Screen")
        UIValidator.trackRender(parentUI, "layers.fx", { child }, 20, "Screen")

        local violations = UIValidator.validate(parentUI)

        local found = false
        for _, v in ipairs(violations) do
            if v.type == "layer_consistency" then
                found = true
                break
            end
        end

        TestRunner.assert_true(found, "should surface layer mismatch via default validate rules")
    end)

end)

-- Run tests when executed directly
return function()
    TestRunner.reset()
    TestRunner.run_all()
end
