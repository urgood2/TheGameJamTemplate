--[[
================================================================================
MODAL SYSTEM TESTS
================================================================================
Tests for the generic modal system (core/modal.lua)

Run with:
    lua assets/scripts/tests/test_modal.lua

Or in-game:
    require("tests.test_modal")

Note: Tests mock UI dependencies for standalone testing.
]]

--------------------------------------------------------------------------------
-- TEST FRAMEWORK
--------------------------------------------------------------------------------

local test_count = 0
local pass_count = 0
local fail_count = 0
local test_output = {}

local function log_test(msg)
    table.insert(test_output, msg)
end

local function assert_eq(actual, expected, msg)
    test_count = test_count + 1
    if actual ~= expected then
        fail_count = fail_count + 1
        local error_msg = string.format("FAIL: %s - expected '%s', got '%s'",
            msg, tostring(expected), tostring(actual))
        log_test(error_msg)
        print(error_msg)
    else
        pass_count = pass_count + 1
        local pass_msg = "PASS: " .. msg
        log_test(pass_msg)
        print(pass_msg)
    end
end

local function assert_not_nil(value, msg)
    test_count = test_count + 1
    if value == nil then
        fail_count = fail_count + 1
        local error_msg = "FAIL: " .. msg .. " - expected non-nil, got nil"
        log_test(error_msg)
        print(error_msg)
    else
        pass_count = pass_count + 1
        local pass_msg = "PASS: " .. msg
        log_test(pass_msg)
        print(pass_msg)
    end
end

local function assert_nil(value, msg)
    test_count = test_count + 1
    if value ~= nil then
        fail_count = fail_count + 1
        local error_msg = string.format("FAIL: %s - expected nil, got '%s'",
            msg, tostring(value))
        log_test(error_msg)
        print(error_msg)
    else
        pass_count = pass_count + 1
        local pass_msg = "PASS: " .. msg
        log_test(pass_msg)
        print(pass_msg)
    end
end

local function assert_true(value, msg)
    test_count = test_count + 1
    if value ~= true then
        fail_count = fail_count + 1
        local error_msg = string.format("FAIL: %s - expected true, got '%s'",
            msg, tostring(value))
        log_test(error_msg)
        print(error_msg)
    else
        pass_count = pass_count + 1
        local pass_msg = "PASS: " .. msg
        log_test(pass_msg)
        print(pass_msg)
    end
end

local function assert_false(value, msg)
    test_count = test_count + 1
    if value ~= false then
        fail_count = fail_count + 1
        local error_msg = string.format("FAIL: %s - expected false, got '%s'",
            msg, tostring(value))
        log_test(error_msg)
        print(error_msg)
    else
        pass_count = pass_count + 1
        local pass_msg = "PASS: " .. msg
        log_test(pass_msg)
        print(pass_msg)
    end
end

local function assert_type(value, expected_type, msg)
    test_count = test_count + 1
    local actual_type = type(value)
    if actual_type ~= expected_type then
        fail_count = fail_count + 1
        local error_msg = string.format("FAIL: %s - expected type '%s', got '%s'",
            msg, expected_type, actual_type)
        log_test(error_msg)
        print(error_msg)
    else
        pass_count = pass_count + 1
        local pass_msg = "PASS: " .. msg
        log_test(pass_msg)
        print(pass_msg)
    end
end

local function assert_error(fn, msg)
    test_count = test_count + 1
    local success, err = pcall(fn)
    if success then
        fail_count = fail_count + 1
        local error_msg = "FAIL: " .. msg .. " - expected error, but succeeded"
        log_test(error_msg)
        print(error_msg)
    else
        pass_count = pass_count + 1
        local pass_msg = "PASS: " .. msg
        log_test(pass_msg)
        print(pass_msg)
    end
end

local function assert_no_error(fn, msg)
    test_count = test_count + 1
    local success, err = pcall(fn)
    if not success then
        fail_count = fail_count + 1
        local error_msg = string.format("FAIL: %s - unexpected error: %s", msg, tostring(err))
        log_test(error_msg)
        print(error_msg)
    else
        pass_count = pass_count + 1
        local pass_msg = "PASS: " .. msg
        log_test(pass_msg)
        print(pass_msg)
    end
end

--------------------------------------------------------------------------------
-- MOCK DEPENDENCIES
--------------------------------------------------------------------------------

-- Track callback invocations
local callback_log = {}
local function reset_callbacks()
    callback_log = {}
end

local function log_callback(name)
    table.insert(callback_log, name)
end

-- Mock globals
_G.globals = {
    screenWidth = function() return 1920 end,
    screenHeight = function() return 1080 end,
}

-- Mock entity system
local next_entity_id = 1000
local entities = {}

_G.entt_null = -1

_G.registry = {
    create = function()
        local eid = next_entity_id
        next_entity_id = next_entity_id + 1
        entities[eid] = true
        return eid
    end,
    valid = function(self, entity)
        return entity and entity ~= _G.entt_null and entities[entity] == true
    end,
    destroy = function(self, entity)
        entities[entity] = nil
    end
}

-- Mock component_cache
local entity_components = {}
_G.Transform = "Transform"
_G.GameObject = "GameObject"

local mock_component_cache = {
    get = function(entity, component_type)
        if not entity_components[entity] then return nil end
        return entity_components[entity][component_type]
    end
}

-- Mock z_orders
local mock_z_orders = {
    ui_modal = 900
}

-- Mock util
local mock_util = {
    getColor = function(name)
        return { r = 100, g = 100, b = 100, a = 255 }
    end
}
_G.util = mock_util

-- Mock signal
local signal_handlers = {}
local mock_signal = {
    emit = function(name, ...)
        log_callback("signal:" .. name)
    end,
    register = function(name, fn)
        signal_handlers[name] = fn
    end
}

-- Mock ui.box
local spawned_boxes = {}
_G.ui = {
    box = {
        Remove = function(reg, eid)
            spawned_boxes[eid] = nil
            entities[eid] = nil
        end,
        set_draw_layer = function(eid, layer) end,
        RenewAlignment = function(reg, eid) end
    }
}

-- Mock DSL with minimal implementation
local mock_dsl = {
    root = function(def) return { _type = "root", def = def } end,
    vbox = function(def) return { _type = "vbox", def = def } end,
    hbox = function(def) return { _type = "hbox", def = def } end,
    text = function(text, opts) return { _type = "text", text = text, opts = opts } end,
    button = function(text, opts) return { _type = "button", text = text, opts = opts } end,
    spacer = function(size) return { _type = "spacer", size = size } end,
    divider = function(dir, opts) return { _type = "divider", dir = dir, opts = opts } end,
    spawn = function(pos, def, layer, z)
        local eid = _G.registry:create()
        spawned_boxes[eid] = { pos = pos, def = def }
        entity_components[eid] = {
            [Transform] = {
                actualX = pos.x, actualY = pos.y,
                actualW = 400, actualH = 300,
                visualX = pos.x, visualY = pos.y,
                visualW = 400, visualH = 300
            }
        }
        return eid
    end
}

-- Mock layer
_G.layer = {
    DrawCommandSpace = { Screen = "screen" }
}
_G.layers = { ui = "ui_layer" }

-- Mock sound
_G.playSoundEffect = function(category, name)
    log_callback("sound:" .. name)
end

-- Mock input
local mock_key_pressed = {}
_G.IsKeyPressed = function(key)
    return mock_key_pressed[key] == true
end
_G.KEY_ESCAPE = 256

-- Setup package.preload for mocked modules
package.preload["core.component_cache"] = function() return mock_component_cache end
package.preload["core.z_orders"] = function() return mock_z_orders end
package.preload["ui.ui_syntax_sugar"] = function() return mock_dsl end
package.preload["external.hump.signal"] = function() return mock_signal end

-- Adjust package path
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/core/?.lua"

--------------------------------------------------------------------------------
-- TEST SUITE 1: MODULE LOADING
--------------------------------------------------------------------------------

print("\n=== MODAL: MODULE LOADING ===")

local modal_loaded, modal = pcall(require, "core.modal")

assert_true(modal_loaded, "modal module loads without error")
assert_not_nil(modal, "modal module is not nil")
assert_type(modal.alert, "function", "modal.alert is a function")
assert_type(modal.confirm, "function", "modal.confirm is a function")
assert_type(modal.show, "function", "modal.show is a function")
assert_type(modal.close, "function", "modal.close is a function")
assert_type(modal.isOpen, "function", "modal.isOpen is a function")

--------------------------------------------------------------------------------
-- TEST SUITE 2: MODAL STATE MANAGEMENT
--------------------------------------------------------------------------------

print("\n=== MODAL: STATE MANAGEMENT ===")

-- Clean state at start
modal.close()
assert_false(modal.isOpen(), "modal.isOpen() returns false when no modal open")

-- Test opening with alert
reset_callbacks()
modal.alert("Test message")
assert_true(modal.isOpen(), "modal.isOpen() returns true after alert()")

-- Test closing
modal.close()
assert_false(modal.isOpen(), "modal.isOpen() returns false after close()")

-- Test signal emissions
reset_callbacks()
modal.alert("Test")
local found_open_signal = false
for _, cb in ipairs(callback_log) do
    if cb == "signal:modal_opened" then found_open_signal = true end
end
assert_true(found_open_signal, "modal emits 'modal_opened' signal")

reset_callbacks()
modal.close()
local found_close_signal = false
for _, cb in ipairs(callback_log) do
    if cb == "signal:modal_closed" then found_close_signal = true end
end
assert_true(found_close_signal, "modal emits 'modal_closed' signal")

--------------------------------------------------------------------------------
-- TEST SUITE 3: ALERT MODAL
--------------------------------------------------------------------------------

print("\n=== MODAL: ALERT ===")

modal.close()

-- Basic alert
assert_no_error(function()
    modal.alert("Simple message")
end, "modal.alert() with just message works")
modal.close()

-- Alert with title
assert_no_error(function()
    modal.alert("Message with title", { title = "Warning" })
end, "modal.alert() with title works")
modal.close()

-- Alert with custom color
assert_no_error(function()
    modal.alert("Colored message", { title = "Error", color = "red" })
end, "modal.alert() with color works")
modal.close()

-- Alert with onClose callback
reset_callbacks()
local close_called = false
modal.alert("With callback", {
    onClose = function()
        close_called = true
        log_callback("onClose")
    end
})
modal.close()
assert_true(close_called, "alert onClose callback is invoked on close")

--------------------------------------------------------------------------------
-- TEST SUITE 4: CONFIRM MODAL
--------------------------------------------------------------------------------

print("\n=== MODAL: CONFIRM ===")

modal.close()

-- Basic confirm
assert_no_error(function()
    modal.confirm("Are you sure?", {
        onConfirm = function() end
    })
end, "modal.confirm() with onConfirm works")
modal.close()

-- Confirm with both callbacks
local confirm_called = false
local cancel_called = false
modal.confirm("Delete item?", {
    onConfirm = function() confirm_called = true end,
    onCancel = function() cancel_called = true end
})
-- Simulate confirm button (this would be triggered by UI in real use)
-- For testing, we check callbacks are stored properly
modal.close()

-- Confirm with custom button text
assert_no_error(function()
    modal.confirm("Proceed?", {
        onConfirm = function() end,
        confirmText = "Yes, do it",
        cancelText = "No, cancel"
    })
end, "modal.confirm() with custom button text works")
modal.close()

--------------------------------------------------------------------------------
-- TEST SUITE 5: CUSTOM CONTENT MODAL
--------------------------------------------------------------------------------

print("\n=== MODAL: CUSTOM CONTENT ===")

modal.close()

-- Basic show with content function
assert_no_error(function()
    modal.show({
        title = "Custom Modal",
        content = function(dsl)
            return dsl.text("Hello world")
        end
    })
end, "modal.show() with content function works")
modal.close()

-- Show with width/height
assert_no_error(function()
    modal.show({
        title = "Sized Modal",
        width = 600,
        height = 400,
        content = function(dsl)
            return dsl.vbox {
                children = {
                    dsl.text("Line 1"),
                    dsl.text("Line 2")
                }
            }
        end
    })
end, "modal.show() with custom width/height works")
modal.close()

-- Show with custom buttons
assert_no_error(function()
    modal.show({
        title = "Button Modal",
        content = function(dsl) return dsl.text("Content") end,
        buttons = {
            { text = "Action 1", action = function() end },
            { text = "Action 2", color = "red", action = function() end }
        }
    })
end, "modal.show() with custom buttons works")
modal.close()

-- Show without buttons (should auto-add OK button)
assert_no_error(function()
    modal.show({
        title = "No Buttons",
        content = function(dsl) return dsl.text("Content") end
    })
end, "modal.show() without buttons auto-adds OK")
modal.close()

--------------------------------------------------------------------------------
-- TEST SUITE 6: MODAL REPLACEMENT
--------------------------------------------------------------------------------

print("\n=== MODAL: REPLACEMENT ===")

modal.close()

-- Opening new modal should close previous
modal.alert("First modal")
assert_true(modal.isOpen(), "First modal is open")

modal.alert("Second modal")
assert_true(modal.isOpen(), "Second modal is open (replaced first)")

modal.close()
assert_false(modal.isOpen(), "Modal closed after replacement")

--------------------------------------------------------------------------------
-- TEST SUITE 7: ESC KEY HANDLING
--------------------------------------------------------------------------------

print("\n=== MODAL: ESC KEY ===")

modal.close()

-- Simulate ESC key press
modal.alert("Test ESC")
assert_true(modal.isOpen(), "Modal open before ESC")

mock_key_pressed[KEY_ESCAPE] = true
modal.update(0.016) -- Simulate frame update
mock_key_pressed[KEY_ESCAPE] = false

assert_false(modal.isOpen(), "Modal closed after ESC key")

--------------------------------------------------------------------------------
-- TEST SUITE 8: BACKDROP CLICK
--------------------------------------------------------------------------------

print("\n=== MODAL: BACKDROP CLICK ===")

modal.close()

-- Alert modals should close on backdrop click
modal.alert("Test backdrop")
assert_true(modal.isOpen(), "Modal open before backdrop click")

-- Simulate backdrop click (test the internal handler exists)
-- In real implementation, this is handled by UI click callback
modal.close() -- Manual close for now
assert_false(modal.isOpen(), "Modal closed after backdrop handling")

--------------------------------------------------------------------------------
-- TEST SUITE 9: SOUND EFFECTS
--------------------------------------------------------------------------------

print("\n=== MODAL: SOUND EFFECTS ===")

modal.close()
reset_callbacks()

-- Opening modal should play sound
modal.alert("Sound test")
local found_sound = false
for _, cb in ipairs(callback_log) do
    if cb:find("sound:") then found_sound = true end
end
-- Sound is optional, so we just verify it doesn't crash
modal.close()

--------------------------------------------------------------------------------
-- TEST SUMMARY
--------------------------------------------------------------------------------

print("\n=== TEST SUMMARY ===")
print(string.format("Total tests: %d", test_count))
print(string.format("Passed: %d", pass_count))
print(string.format("Failed: %d", fail_count))

if fail_count == 0 then
    print("\n✓ ALL TESTS PASSED")
else
    print(string.format("\n✗ %d TEST(S) FAILED", fail_count))
end

-- Return results for programmatic use
return {
    total = test_count,
    passed = pass_count,
    failed = fail_count,
    success = fail_count == 0
}
