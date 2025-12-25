--[[
    Test for event system unification

    This test verifies that:
    1. signal.emit() and signal.register() work correctly
    2. Events flow through the signal system
    3. Multiple handlers can listen to the same event
    4. Handler removal works properly
    5. Event data is passed correctly

    This validates the primary event system (hump.signal) used by the codebase.
]]

local test_event_unification = {}

-- Mock the signal library if not available
local signal
if not pcall(function() signal = require("external.hump.signal") end) then
    -- Create a minimal mock for standalone testing
    local Registry = {}
    Registry.__index = function(self, key)
        return Registry[key] or (function()
            local t = {}
            rawset(self, key, t)
            return t
        end)()
    end

    function Registry:register(s, f)
        self[s][f] = f
        return f
    end

    function Registry:emit(s, ...)
        for f in pairs(self[s]) do
            f(...)
        end
    end

    function Registry:remove(s, ...)
        local f = {...}
        for i = 1, select('#', ...) do
            self[s][f[i]] = nil
        end
    end

    function Registry:clear(...)
        local s = {...}
        for i = 1, select('#', ...) do
            self[s[i]] = {}
        end
    end

    function Registry.new()
        return setmetatable({}, Registry)
    end

    local default = Registry.new()
    signal = {}
    for k in pairs(Registry) do
        if k ~= "__index" then
            signal[k] = function(...) return default[k](default, ...) end
        end
    end
end

-- Test that basic emit/register works
function test_event_unification.test_basic_emit_register()
    local received = false
    local received_data = nil

    local handler = function(data)
        received = true
        received_data = data
    end

    signal.register("test_event", handler)
    signal.emit("test_event", { value = 42 })

    assert(received, "Handler should have been called")
    assert(received_data ~= nil, "Handler should have received data")
    assert(received_data.value == 42, "Data should be passed correctly")

    -- Cleanup
    signal.remove("test_event", handler)

    print("✓ Basic emit/register test passed")
    return true
end

-- Test multiple handlers on same event
function test_event_unification.test_multiple_handlers()
    local handler1_called = false
    local handler2_called = false

    local handler1 = function()
        handler1_called = true
    end

    local handler2 = function()
        handler2_called = true
    end

    signal.register("multi_event", handler1)
    signal.register("multi_event", handler2)
    signal.emit("multi_event")

    assert(handler1_called, "First handler should have been called")
    assert(handler2_called, "Second handler should have been called")

    -- Cleanup
    signal.remove("multi_event", handler1, handler2)

    print("✓ Multiple handlers test passed")
    return true
end

-- Test handler removal
function test_event_unification.test_handler_removal()
    local call_count = 0

    local handler = function()
        call_count = call_count + 1
    end

    signal.register("removal_event", handler)
    signal.emit("removal_event")

    assert(call_count == 1, "Handler should be called once")

    signal.remove("removal_event", handler)
    signal.emit("removal_event")

    assert(call_count == 1, "Handler should not be called after removal")

    print("✓ Handler removal test passed")
    return true
end

-- Test multiple parameters
function test_event_unification.test_multiple_parameters()
    local received_entity = nil
    local received_data = nil

    local handler = function(entity, data)
        received_entity = entity
        received_data = data
    end

    signal.register("multi_param_event", handler)
    signal.emit("multi_param_event", 123, { damage = 50 })

    assert(received_entity == 123, "First parameter should be passed")
    assert(received_data.damage == 50, "Second parameter should be passed")

    -- Cleanup
    signal.remove("multi_param_event", handler)

    print("✓ Multiple parameters test passed")
    return true
end

-- Test event isolation (handlers don't cross-contaminate)
function test_event_unification.test_event_isolation()
    local event1_called = false
    local event2_called = false

    local handler1 = function()
        event1_called = true
    end

    local handler2 = function()
        event2_called = true
    end

    signal.register("isolated_event_1", handler1)
    signal.register("isolated_event_2", handler2)

    signal.emit("isolated_event_1")

    assert(event1_called, "Handler for event 1 should be called")
    assert(not event2_called, "Handler for event 2 should NOT be called")

    -- Cleanup
    signal.remove("isolated_event_1", handler1)
    signal.remove("isolated_event_2", handler2)

    print("✓ Event isolation test passed")
    return true
end

-- Test common game events (mimics actual usage)
function test_event_unification.test_common_game_events()
    local enemy_killed_count = 0
    local player_damaged = false
    local wave_complete = false

    local enemy_handler = function(entity)
        enemy_killed_count = enemy_killed_count + 1
    end

    local damage_handler = function(entity, data)
        player_damaged = true
    end

    local wave_handler = function()
        wave_complete = true
    end

    signal.register("enemy_killed", enemy_handler)
    signal.register("player_damaged", damage_handler)
    signal.register("wave_complete", wave_handler)

    -- Simulate game events
    signal.emit("enemy_killed", 101)
    signal.emit("enemy_killed", 102)
    signal.emit("player_damaged", 999, { damage = 10 })
    signal.emit("wave_complete")

    assert(enemy_killed_count == 2, "Should count two enemy kills")
    assert(player_damaged, "Player damage event should be received")
    assert(wave_complete, "Wave complete event should be received")

    -- Cleanup
    signal.remove("enemy_killed", enemy_handler)
    signal.remove("player_damaged", damage_handler)
    signal.remove("wave_complete", wave_handler)

    print("✓ Common game events test passed")
    return true
end

-- Test clear event handlers
function test_event_unification.test_clear_handlers()
    local called = false

    local handler = function()
        called = true
    end

    signal.register("clearable_event", handler)
    signal.clear("clearable_event")
    signal.emit("clearable_event")

    assert(not called, "Handler should not be called after clear")

    print("✓ Clear handlers test passed")
    return true
end

-- Run all tests
function test_event_unification.run_all()
    print("\n=== Running Event Unification Tests ===\n")

    local tests = {
        test_event_unification.test_basic_emit_register,
        test_event_unification.test_multiple_handlers,
        test_event_unification.test_handler_removal,
        test_event_unification.test_multiple_parameters,
        test_event_unification.test_event_isolation,
        test_event_unification.test_common_game_events,
        test_event_unification.test_clear_handlers,
    }

    local passed = 0
    local failed = 0

    for i, test_func in ipairs(tests) do
        local success, err = pcall(test_func)
        if success then
            passed = passed + 1
        else
            failed = failed + 1
            print("✗ Test failed: " .. tostring(err))
        end
    end

    print("\n=== Test Results ===")
    print(string.format("Passed: %d", passed))
    print(string.format("Failed: %d", failed))
    print(string.format("Total:  %d\n", passed + failed))

    return failed == 0
end

-- Auto-run if executed directly
if not pcall(debug.getlocal, 4, 1) then
    test_event_unification.run_all()
end

return test_event_unification
