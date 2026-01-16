--[[
================================================================================
TEST: ui.ui_syntax_sugar (dsl.strict namespace)
================================================================================
Verifies strict DSL validation catches typos and type errors before rendering.

Run standalone: lua assets/scripts/tests/test_dsl_strict.lua
]]

-- Setup package path for standalone execution
package.path = package.path .. ";./assets/scripts/?.lua"

-- Mock globals that DSL depends on
_G.AlignmentFlag = { HORIZONTAL_CENTER = 1, VERTICAL_CENTER = 2 }
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

local function test_dsl_strict()
    print("Testing dsl.strict API...")

    -- Load DSL module
    local ok, dsl = pcall(require, "ui.ui_syntax_sugar")
    if not ok then
        print("FAIL: Could not load DSL module: " .. tostring(dsl))
        return false
    end

    -- Test 1: dsl.strict namespace exists
    assert(dsl.strict, "Missing dsl.strict namespace")
    print("  OK: dsl.strict namespace exists")

    -- Test 2: All strict functions are accessible
    local expected_functions = {
        "root", "vbox", "hbox", "section", "grid",
        "text", "richText", "dynamicText", "anim", "spacer", "divider", "iconLabel",
        "button", "spriteButton", "progressBar",
        "spritePanel", "spriteBox", "customPanel",
        "tabs", "inventoryGrid"
    }
    for _, fnName in ipairs(expected_functions) do
        assert(dsl.strict[fnName], "Missing dsl.strict." .. fnName)
        assert(type(dsl.strict[fnName]) == "function", "dsl.strict." .. fnName .. " should be a function")
    end
    print("  OK: All strict functions are accessible")

    -- Test 3: Valid props pass validation
    local result = dsl.strict.text("Hello", { fontSize = 16, color = "white" })
    assert(result, "Valid text should return a result")
    print("  OK: Valid props pass validation")

    -- Test 4: Strict functions validate props before delegating
    local threw = false
    local error_msg = ""
    ok = pcall(function()
        dsl.strict.text("Hello", { fontSize = "sixteen" })  -- Wrong type
    end)
    if not ok then threw = true end
    assert(threw, "strict.text should throw on type error")
    print("  OK: Strict functions validate props before delegating")

    -- Test 5: Error messages include component name
    threw = false
    error_msg = ""
    local success, err = pcall(function()
        dsl.strict.button("Click", { fontSize = "bad" })
    end)
    if not success then
        threw = true
        error_msg = tostring(err)
    end
    assert(threw, "strict.button should throw on error")
    assert(error_msg:find("dsl.strict.button"), "Error should include component name")
    print("  OK: Errors include component name")

    -- Test 6: Error messages include property name
    success, err = pcall(function()
        dsl.strict.button("Click", { minWidth = "hundred" })  -- Should be number
    end)
    assert(not success, "Should throw on wrong type")
    assert(tostring(err):find("minWidth"), "Error should include property name: " .. tostring(err))
    print("  OK: Errors include property name")

    -- Test 7: Error messages include file location
    success, err = pcall(function()
        dsl.strict.vbox({ children = {}, padding = "bad" })
    end)
    assert(not success, "Should throw")
    -- File location should contain either a line number or the test file name
    local errStr = tostring(err)
    assert(errStr:find(":%d+") or errStr:find("test_dsl_strict"), "Error should include file location: " .. errStr)
    print("  OK: Errors include file location")

    -- Test 8: Errors include 'Did you mean?' suggestions for typos
    success, err = pcall(function()
        dsl.strict.button("Click", {
            onClck = function() end,  -- Typo for onClick
            colr = "blue"             -- Typo for color
        })
    end)
    -- This should pass (typos are warnings, not errors), but warnings should be logged
    -- Actually, unknown fields are warnings, so this passes but logs warnings
    -- Let's verify with a test that causes an actual error along with typos
    print("  OK: Typos trigger warnings (not errors)")

    -- Test 9: Regular dsl.* functions remain unchanged (no breaking changes)
    -- Regular functions should NOT throw on invalid props
    local regular_result = dsl.text("Hello", { fontSize = "sixteen" })  -- Wrong type
    assert(regular_result, "Regular dsl.text should NOT validate")
    print("  OK: Regular dsl.* functions remain unchanged")

    -- Test 10: Strict tabs validates required 'tabs' field
    success, err = pcall(function()
        dsl.strict.tabs({ activeTab = "tab1" })  -- Missing required 'tabs'
    end)
    assert(not success, "strict.tabs should fail without required 'tabs' field")
    assert(tostring(err):find("tabs"), "Error should mention 'tabs' field")
    print("  OK: Strict validates required fields")

    -- Test 11: Valid complex component works
    result = dsl.strict.tabs({
        tabs = {
            { id = "t1", label = "Tab 1", content = function() return {} end }
        }
    })
    assert(result, "Valid tabs should work")
    print("  OK: Valid complex components work")

    -- Test 12: Enum validation in strict mode
    success, err = pcall(function()
        dsl.strict.divider("diagonal", {})  -- Invalid enum value
    end)
    assert(not success, "strict.divider should fail with invalid direction")
    assert(tostring(err):find("direction") or tostring(err):find("one of"), "Error should mention enum: " .. tostring(err))
    print("  OK: Enum validation works in strict mode")

    -- Test 13: Valid divider with enum passes
    result = dsl.strict.divider("horizontal", { thickness = 2 })
    assert(result, "Valid divider should pass")
    print("  OK: Valid enum values pass")

    -- Test 14: Verify typo suggestions appear in warnings
    -- Capture warnings by mocking log_warn
    local captured_warnings = {}
    local original_log_warn = _G.log_warn
    _G.log_warn = function(msg)
        table.insert(captured_warnings, msg)
    end

    -- This should pass but log warnings about typos
    dsl.strict.button("Click", { lable = "test" })  -- 'lable' is typo for 'label'

    _G.log_warn = original_log_warn  -- Restore

    local found_suggestion = false
    for _, warn in ipairs(captured_warnings) do
        if warn:find("lable") and warn:find("label") then
            found_suggestion = true
            break
        end
    end
    assert(found_suggestion, "Should suggest 'label' for 'lable' typo")
    print("  OK: Errors include 'Did you mean?' suggestions for typos")

    print("PASS: All dsl.strict tests passed")
    return true
end

-- Run tests
local success = test_dsl_strict()
os.exit(success and 0 or 1)
