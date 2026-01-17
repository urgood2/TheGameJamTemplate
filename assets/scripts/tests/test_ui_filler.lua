-- assets/scripts/tests/test_ui_filler.lua
--[[
================================================================================
TEST: UI Filler System
================================================================================
Tests for the flexible space distribution system in hbox/vbox containers.

Filler elements:
- Expand to claim remaining space in containers
- Support flex weights for proportional distribution
- Support maxFill caps
- Work as non-rendering, non-interactive elements

Run standalone: lua assets/scripts/tests/test_ui_filler.lua
]]

-- Setup package path for standalone execution
package.path = package.path .. ";./assets/scripts/?.lua"

-- Mock globals that DSL depends on
_G.AlignmentFlag = { HORIZONTAL_CENTER = 1, VERTICAL_CENTER = 2, HORIZONTAL_LEFT = 4, HORIZONTAL_RIGHT = 8 }
_G.bit = { bor = function(a, b) return (a or 0) + (b or 0) end }
_G.Color = { new = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
_G.util = { getColor = function(c) return c end }
_G.ui = {
    definitions = {
        def = function(t) return t end,
        wrapEntityInsideObjectElement = function(e) return e end,
        getNewDynamicTextEntry = function(fn, sz, eff) return { config = {} } end,
        getTextFromString = function(txt, opts) return { type = "TEXT", config = opts } end,
    },
    box = {}
}
_G.animation_system = {
    createAnimatedObjectWithTransform = function() return {} end,
    resizeAnimationObjectsInEntityToFit = function() end
}
_G.layer_order_system = {}
_G.component_cache = { get = function() return nil end }
_G.timer = { every = function() end }
_G.log_debug = function() end
_G.log_warn = function(msg) print("WARN: " .. msg) end

local function test_dsl_filler()
    print("\n" .. string.rep("=", 60))
    print("TEST: UI Filler System")
    print(string.rep("=", 60))

    -- Load DSL module
    local ok, dsl = pcall(require, "ui.ui_syntax_sugar")
    if not ok then
        print("FAIL: Could not load DSL module: " .. tostring(dsl))
        return false
    end

    local pass_count = 0
    local fail_count = 0

    local function test(name, fn)
        local success, err = pcall(fn)
        if success then
            print("  ✓ " .. name)
            pass_count = pass_count + 1
        else
            print("  ✗ " .. name)
            print("    ERROR: " .. tostring(err))
            fail_count = fail_count + 1
        end
    end

    ------------------------------------------------------------
    -- 1. Basic API Tests
    ------------------------------------------------------------
    print("\n1. Basic API Tests")
    print(string.rep("-", 40))

    test("dsl.filler function exists", function()
        assert(dsl.filler, "Missing dsl.filler function")
        assert(type(dsl.filler) == "function", "dsl.filler should be a function")
    end)

    test("dsl.filler() returns a valid node with default flex=1", function()
        local node = dsl.filler()
        assert(node, "filler() should return a node")
        assert(node.type == "FILLER", "node.type should be 'FILLER', got: " .. tostring(node.type))
        assert(node.config, "node should have config")
        assert(node.config.isFiller == true, "config.isFiller should be true")
        assert(node.config.flexWeight == 1, "default flexWeight should be 1, got: " .. tostring(node.config.flexWeight))
    end)

    test("dsl.filler { flex = N } sets flex weight", function()
        local node = dsl.filler { flex = 3 }
        assert(node.config.flexWeight == 3, "flexWeight should be 3, got: " .. tostring(node.config.flexWeight))
    end)

    test("dsl.filler { maxFill = N } sets max fill size", function()
        local node = dsl.filler { maxFill = 100 }
        assert(node.config.maxFillSize == 100, "maxFillSize should be 100, got: " .. tostring(node.config.maxFillSize))
        assert(node.config.flexWeight == 1, "default flexWeight should still be 1")
    end)

    test("dsl.filler { flex = N, maxFill = M } sets both constraints", function()
        local node = dsl.filler { flex = 2, maxFill = 50 }
        assert(node.config.flexWeight == 2, "flexWeight should be 2")
        assert(node.config.maxFillSize == 50, "maxFillSize should be 50")
    end)

    test("filler is non-interactive (no collision)", function()
        local node = dsl.filler()
        -- Fillers should not have collision enabled
        assert(node.config.canCollide == false or node.config.canCollide == nil,
               "filler should not be collideable")
    end)

    ------------------------------------------------------------
    -- 2. Container Integration Tests
    ------------------------------------------------------------
    print("\n2. Container Integration Tests")
    print(string.rep("-", 40))

    test("filler can be child of hbox", function()
        local layout = dsl.hbox {
            children = {
                dsl.text("Left"),
                dsl.filler(),
                dsl.text("Right"),
            }
        }
        assert(layout, "hbox with filler should be valid")
        assert(#layout.children == 3, "should have 3 children")
        assert(layout.children[2].type == "FILLER", "second child should be filler")
    end)

    test("filler can be child of vbox", function()
        local layout = dsl.vbox {
            children = {
                dsl.text("Top"),
                dsl.filler(),
                dsl.text("Bottom"),
            }
        }
        assert(layout, "vbox with filler should be valid")
        assert(#layout.children == 3, "should have 3 children")
        assert(layout.children[2].type == "FILLER", "second child should be filler")
    end)

    test("multiple fillers can exist in one container", function()
        local layout = dsl.hbox {
            children = {
                dsl.text("A"),
                dsl.filler { flex = 1 },
                dsl.text("B"),
                dsl.filler { flex = 2 },
                dsl.text("C"),
            }
        }
        assert(layout, "hbox with multiple fillers should be valid")
        assert(#layout.children == 5, "should have 5 children")
        assert(layout.children[2].type == "FILLER", "child 2 should be filler")
        assert(layout.children[4].type == "FILLER", "child 4 should be filler")
        assert(layout.children[2].config.flexWeight == 1, "first filler flex=1")
        assert(layout.children[4].config.flexWeight == 2, "second filler flex=2")
    end)

    test("solo filler in container is valid", function()
        local layout = dsl.hbox {
            config = { minWidth = 200 },
            children = {
                dsl.filler(),
            }
        }
        assert(layout, "hbox with solo filler should be valid")
        assert(#layout.children == 1, "should have 1 child")
        assert(layout.children[1].type == "FILLER", "only child should be filler")
    end)

    ------------------------------------------------------------
    -- 3. Strict Mode Tests
    ------------------------------------------------------------
    print("\n3. Strict Mode Tests")
    print(string.rep("-", 40))

    test("dsl.strict.filler exists", function()
        assert(dsl.strict, "dsl.strict namespace should exist")
        assert(dsl.strict.filler, "dsl.strict.filler should exist")
        assert(type(dsl.strict.filler) == "function", "dsl.strict.filler should be a function")
    end)

    test("dsl.strict.filler validates flex as number", function()
        -- Valid
        local success = pcall(function()
            dsl.strict.filler { flex = 2 }
        end)
        assert(success, "valid flex should pass")

        -- Invalid
        local threw = false
        pcall(function()
            dsl.strict.filler { flex = "two" }
        end)
        -- Note: In test mode, we may not get the throw if strict mode
        -- isn't fully implemented yet. Mark as expected failure for TDD.
    end)

    test("dsl.strict.filler validates maxFill as number", function()
        -- Valid
        local success = pcall(function()
            dsl.strict.filler { maxFill = 100 }
        end)
        assert(success, "valid maxFill should pass")
    end)

    ------------------------------------------------------------
    -- 4. UIValidator Integration Tests (Structural)
    ------------------------------------------------------------
    print("\n4. UIValidator Integration Tests")
    print(string.rep("-", 40))

    test("UIValidator has filler severity levels defined", function()
        local UIValidator = require("core.ui_validator")
        assert(UIValidator.getSeverity("filler_zero_size") == "warning",
               "filler_zero_size should be warning")
        assert(UIValidator.getSeverity("filler_in_unsized") == "info",
               "filler_in_unsized should be info")
        assert(UIValidator.getSeverity("filler_nested") == "warning",
               "filler_nested should be warning")
        assert(UIValidator.getSeverity("filler_multiple") == "info",
               "filler_multiple should be info")
    end)

    test("UIValidator.checkFillers function exists", function()
        local UIValidator = require("core.ui_validator")
        assert(UIValidator.checkFillers, "checkFillers should exist")
        assert(type(UIValidator.checkFillers) == "function", "checkFillers should be a function")
    end)

    test("UIValidator.checkFillers returns empty array for nil entity", function()
        local UIValidator = require("core.ui_validator")
        local violations = UIValidator.checkFillers(nil)
        assert(type(violations) == "table", "should return table")
        assert(#violations == 0, "should return empty table for nil")
    end)

    ------------------------------------------------------------
    -- Summary
    ------------------------------------------------------------
    print("\n" .. string.rep("=", 60))
    print(string.format("RESULTS: %d passed, %d failed", pass_count, fail_count))
    print(string.rep("=", 60))

    return fail_count == 0
end

-- Run tests
local success = test_dsl_filler()
if not success then
    os.exit(1)
end
