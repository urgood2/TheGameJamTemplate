-- assets/scripts/tests/test_dot_filler.lua
--[[
================================================================================
TEST: Dot Filler DSL Element
================================================================================
Tests for the dotFiller element that fills remaining space with visible dots.

Usage: "Attack Power......125"
- Fills horizontal space with configurable dot character
- Scales with font size
- Configurable spacing and minimum dot count
- Dynamically recomputes on layout changes

Run standalone: lua assets/scripts/tests/test_dot_filler.lua
]]

-- Setup package path for standalone execution
package.path = package.path .. ";./assets/scripts/?.lua"

--------------------------------------------------------------------------------
-- Mock Setup
--------------------------------------------------------------------------------

-- Mock globals that DSL depends on
_G.AlignmentFlag = {
    HORIZONTAL_CENTER = 1,
    VERTICAL_CENTER = 2,
    HORIZONTAL_LEFT = 4,
    HORIZONTAL_RIGHT = 8
}
_G.bit = { bor = function(a, b) return (a or 0) + (b or 0) end }
_G.Color = { new = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
_G.util = { getColor = function(c) return c end }
_G.ui = {
    definitions = {
        def = function(t) return t end,
        wrapEntityInsideObjectElement = function(e) return e end,
        getNewDynamicTextEntry = function(fn, sz, eff)
            return { type = "DYNAMIC_TEXT", config = { fetchText = fn, fontSize = sz } }
        end,
        getTextFromString = function(txt, opts) return { type = "TEXT", config = opts } end,
    },
    box = {
        GetUIEByID = function() return nil end,
    }
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
_G.log_error = function(msg) print("ERROR: " .. msg) end

--------------------------------------------------------------------------------
-- Tests
--------------------------------------------------------------------------------

local function test_dot_filler()
    print("\n" .. string.rep("=", 70))
    print("TEST: Dot Filler DSL Element")
    print(string.rep("=", 70))

    -- Load DSL module
    package.loaded["ui.ui_syntax_sugar"] = nil
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
            print("  \27[32m✓\27[0m " .. name)
            pass_count = pass_count + 1
        else
            print("  \27[31m✗\27[0m " .. name)
            print("    ERROR: " .. tostring(err))
            fail_count = fail_count + 1
        end
    end

    ----------------------------------------------------------------------------
    -- 1. Basic API Tests
    ----------------------------------------------------------------------------
    print("\n1. Basic API Tests")
    print(string.rep("-", 50))

    test("dsl.dotFiller function exists", function()
        assert(dsl.dotFiller, "Missing dsl.dotFiller function")
        assert(type(dsl.dotFiller) == "function", "dsl.dotFiller should be a function")
    end)

    test("dsl.dotFiller() returns a valid node with defaults", function()
        local node = dsl.dotFiller()
        assert(node, "dotFiller() should return a node")
        assert(node.config, "node should have config")
        assert(node.config.isDotFiller == true, "config.isDotFiller should be true")
    end)

    test("default dot character is '.'", function()
        local node = dsl.dotFiller()
        assert(node.config.dotChar == ".", "default dotChar should be '.', got: " .. tostring(node.config.dotChar))
    end)

    test("default spacing is 1", function()
        local node = dsl.dotFiller()
        assert(node.config.dotSpacing == 1, "default dotSpacing should be 1, got: " .. tostring(node.config.dotSpacing))
    end)

    test("default minDots is 2", function()
        local node = dsl.dotFiller()
        assert(node.config.minDots == 2, "default minDots should be 2, got: " .. tostring(node.config.minDots))
    end)

    ----------------------------------------------------------------------------
    -- 2. Configuration Tests
    ----------------------------------------------------------------------------
    print("\n2. Configuration Tests")
    print(string.rep("-", 50))

    test("custom dot character", function()
        local node = dsl.dotFiller({ dot = "-" })
        assert(node.config.dotChar == "-", "dotChar should be '-', got: " .. tostring(node.config.dotChar))
    end)

    test("custom spacing", function()
        local node = dsl.dotFiller({ spacing = 3 })
        assert(node.config.dotSpacing == 3, "dotSpacing should be 3, got: " .. tostring(node.config.dotSpacing))
    end)

    test("custom minDots", function()
        local node = dsl.dotFiller({ minDots = 5 })
        assert(node.config.minDots == 5, "minDots should be 5, got: " .. tostring(node.config.minDots))
    end)

    test("fontSize option", function()
        local node = dsl.dotFiller({ fontSize = 14 })
        assert(node.config.fontSize == 14, "fontSize should be 14, got: " .. tostring(node.config.fontSize))
    end)

    test("color option", function()
        local node = dsl.dotFiller({ color = "gray" })
        assert(node.config.color == "gray", "color should be 'gray', got: " .. tostring(node.config.color))
    end)

    test("multiple options combined", function()
        local node = dsl.dotFiller({
            dot = "*",
            spacing = 2,
            minDots = 3,
            fontSize = 12,
            color = "dim_gray"
        })
        assert(node.config.dotChar == "*", "dotChar should be '*'")
        assert(node.config.dotSpacing == 2, "dotSpacing should be 2")
        assert(node.config.minDots == 3, "minDots should be 3")
        assert(node.config.fontSize == 12, "fontSize should be 12")
        assert(node.config.color == "dim_gray", "color should be 'dim_gray'")
    end)

    ----------------------------------------------------------------------------
    -- 3. Container Integration Tests
    ----------------------------------------------------------------------------
    print("\n3. Container Integration Tests")
    print(string.rep("-", 50))

    test("dotFiller can be child of hbox", function()
        local layout = dsl.hbox {
            children = {
                dsl.text("Label"),
                dsl.dotFiller(),
                dsl.text("Value"),
            }
        }
        assert(layout, "hbox with dotFiller should be valid")
        assert(#layout.children == 3, "should have 3 children")
        assert(layout.children[2].config.isDotFiller == true, "second child should be dotFiller")
    end)

    test("stat row pattern: label + dotFiller + value", function()
        local row = dsl.hbox {
            config = { minWidth = 200 },
            children = {
                dsl.text("Attack Power"),
                dsl.dotFiller({ color = "dim_gray" }),
                dsl.text("125", { align = _G.AlignmentFlag.HORIZONTAL_RIGHT }),
            }
        }
        assert(row, "stat row should be valid")
        assert(#row.children == 3, "should have 3 children")
        -- Verify structure
        assert(row.children[1].config.text == "Attack Power", "first child should be label")
        assert(row.children[2].config.isDotFiller == true, "second child should be dotFiller")
        assert(row.children[3].config.text == "125", "third child should be value")
    end)

    ----------------------------------------------------------------------------
    -- 4. Filler vs DotFiller Distinction
    ----------------------------------------------------------------------------
    print("\n4. Filler vs DotFiller Distinction")
    print(string.rep("-", 50))

    test("dotFiller is distinct from regular filler", function()
        local filler = dsl.filler()
        local dotFiller = dsl.dotFiller()

        -- Both should exist but be different
        assert(filler.config.isFiller == true, "filler should have isFiller=true")
        assert(dotFiller.config.isDotFiller == true, "dotFiller should have isDotFiller=true")

        -- dotFiller should NOT have isFiller
        assert(dotFiller.config.isFiller ~= true, "dotFiller should not have isFiller=true")

        -- filler should NOT have isDotFiller
        assert(filler.config.isDotFiller ~= true, "filler should not have isDotFiller=true")
    end)

    test("dotFiller is NOT invisible (has visible content)", function()
        local dotFiller = dsl.dotFiller()
        -- dotFiller should have text/dynamic content to display dots
        -- It should either be a text type or have a text generation function
        local hasTextContent = dotFiller.type == "DYNAMIC_TEXT" or
                              dotFiller.type == "TEXT" or
                              dotFiller.config.getDotText ~= nil or
                              dotFiller.config.fetchText ~= nil
        assert(hasTextContent, "dotFiller should have visible text content mechanism")
    end)

    ----------------------------------------------------------------------------
    -- 5. Strict Mode Tests
    ----------------------------------------------------------------------------
    print("\n5. Strict Mode Tests")
    print(string.rep("-", 50))

    test("dsl.strict.dotFiller exists", function()
        assert(dsl.strict, "dsl.strict namespace should exist")
        assert(dsl.strict.dotFiller, "dsl.strict.dotFiller should exist")
        assert(type(dsl.strict.dotFiller) == "function", "dsl.strict.dotFiller should be a function")
    end)

    test("dsl.strict.dotFiller validates dot as string", function()
        -- Valid string
        local success1 = pcall(function()
            dsl.strict.dotFiller({ dot = "." })
        end)
        assert(success1, "valid dot string should pass")
    end)

    test("dsl.strict.dotFiller validates spacing as number", function()
        -- Valid number
        local success1 = pcall(function()
            dsl.strict.dotFiller({ spacing = 2 })
        end)
        assert(success1, "valid spacing number should pass")
    end)

    test("dsl.strict.dotFiller validates minDots as number", function()
        -- Valid number
        local success1 = pcall(function()
            dsl.strict.dotFiller({ minDots = 3 })
        end)
        assert(success1, "valid minDots number should pass")
    end)

    ----------------------------------------------------------------------------
    -- Summary
    ----------------------------------------------------------------------------
    print("\n" .. string.rep("=", 70))
    print(string.format("RESULTS: \27[32m%d passed\27[0m, \27[31m%d failed\27[0m",
        pass_count, fail_count))
    print(string.rep("=", 70))

    return fail_count == 0
end

-- Run tests
local success = test_dot_filler()
if not success then
    os.exit(1)
end
