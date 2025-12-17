--[[
================================================================================
TEST: core/timer_scope.lua
================================================================================
Verifies scoped timer management for automatic cleanup.

Run standalone: lua assets/scripts/tests/test_timer_scope.lua
]]

-- Setup package path for standalone execution
package.path = package.path .. ";./assets/scripts/?.lua"

-- Mock the timer module for standalone testing
local mock_timers = {}
local mock_timer = {
    timers = mock_timers,
    after = function(delay, action, tag, group)
        tag = tag or ("mock_" .. tostring(math.random(1, 1e9)))
        mock_timers[tag] = { delay = delay, action = action, group = group }
        return tag
    end,
    every = function(delay, action, times, immediate, after, tag, group)
        tag = tag or ("mock_" .. tostring(math.random(1, 1e9)))
        mock_timers[tag] = { delay = delay, action = action, times = times, group = group }
        return tag
    end,
    cancel = function(tag)
        mock_timers[tag] = nil
    end,
    kill_group = function(group)
        for tag, t in pairs(mock_timers) do
            if t.group == group then mock_timers[tag] = nil end
        end
    end,
}

-- Inject mock timer before requiring TimerScope
package.loaded["core.timer"] = mock_timer

local function test_timer_scope()
    print("Testing core/timer_scope.lua...")

    -- Load module
    local ok, TimerScope = pcall(require, "core.timer_scope")
    if not ok then
        print("FAIL: Could not load timer_scope module: " .. tostring(TimerScope))
        return false
    end

    -- Test 1: Can create a scope
    local scope = TimerScope.new("test_scope")
    assert(scope, "Should create scope")
    assert(scope.name == "test_scope", "Scope should have name")
    print("  OK: Can create a scope")

    -- Test 2: Scoped timer.after creates timer with scope group
    mock_timers = {}  -- Reset
    mock_timer.timers = mock_timers
    local scope2 = TimerScope.new("scope2")
    local tag = scope2:after(1.0, function() end)
    assert(tag, "after() should return tag")
    assert(mock_timers[tag], "Timer should exist")
    assert(mock_timers[tag].group == scope2._group, "Timer should have scope group")
    print("  OK: Scoped after() creates timer with scope group")

    -- Test 3: Scoped timer.every creates timer with scope group
    local tag2 = scope2:every(0.5, function() end)
    assert(tag2, "every() should return tag")
    assert(mock_timers[tag2], "Timer should exist")
    assert(mock_timers[tag2].group == scope2._group, "Timer should have scope group")
    print("  OK: Scoped every() creates timer with scope group")

    -- Test 4: destroy() cancels all scoped timers
    mock_timers = {}
    mock_timer.timers = mock_timers
    local scope3 = TimerScope.new("scope3")
    scope3:after(1.0, function() end)
    scope3:after(2.0, function() end)
    scope3:every(0.5, function() end)
    assert(next(mock_timers) ~= nil, "Should have timers before destroy")

    scope3:destroy()
    assert(next(mock_timers) == nil, "All scoped timers should be cancelled after destroy")
    print("  OK: destroy() cancels all scoped timers")

    -- Test 5: Scopes are independent (destroying one doesn't affect another)
    mock_timers = {}
    mock_timer.timers = mock_timers
    local scopeA = TimerScope.new("scopeA")
    local scopeB = TimerScope.new("scopeB")

    scopeA:after(1.0, function() end)
    scopeB:after(1.0, function() end)

    local countBefore = 0
    for _ in pairs(mock_timers) do countBefore = countBefore + 1 end
    assert(countBefore == 2, "Should have 2 timers")

    scopeA:destroy()

    local countAfter = 0
    for _ in pairs(mock_timers) do countAfter = countAfter + 1 end
    assert(countAfter == 1, "Should have 1 timer after destroying scopeA")
    print("  OK: Scopes are independent")

    -- Test 6: cancel() cancels a specific scoped timer
    mock_timers = {}
    mock_timer.timers = mock_timers
    local scope4 = TimerScope.new("scope4")
    local tagA = scope4:after(1.0, function() end, "my_tag")
    local tagB = scope4:after(2.0, function() end)

    scope4:cancel("my_tag")
    assert(mock_timers["my_tag"] == nil, "Cancelled timer should be removed")
    assert(mock_timers[tagB] ~= nil, "Other timer should remain")
    print("  OK: cancel() cancels specific timer")

    -- Test 7: for_entity() creates entity-bound scope
    local scope5 = TimerScope.for_entity(12345)
    assert(scope5, "Should create entity scope")
    assert(scope5._entity == 12345, "Scope should track entity")
    print("  OK: for_entity() creates entity-bound scope")

    -- Test 8: Scope tracks timer count
    mock_timers = {}
    mock_timer.timers = mock_timers
    local scope6 = TimerScope.new("scope6")
    assert(scope6:count() == 0, "New scope should have 0 timers")
    scope6:after(1.0, function() end)
    scope6:after(2.0, function() end)
    assert(scope6:count() == 2, "Should track 2 timers")
    scope6:destroy()
    assert(scope6:count() == 0, "Should have 0 timers after destroy")
    print("  OK: Scope tracks timer count")

    -- Test 9: active() returns false after destroy
    mock_timers = {}
    mock_timer.timers = mock_timers
    local scope7 = TimerScope.new("scope7")
    assert(scope7:active() == true, "New scope should be active")
    scope7:destroy()
    assert(scope7:active() == false, "Destroyed scope should be inactive")
    print("  OK: active() reflects scope state")

    -- Test 10: Creating timer on destroyed scope does nothing
    mock_timers = {}
    mock_timer.timers = mock_timers
    local scope8 = TimerScope.new("scope8")
    scope8:destroy()
    local tag3 = scope8:after(1.0, function() end)
    assert(tag3 == nil, "after() on destroyed scope should return nil")
    assert(next(mock_timers) == nil, "No timer should be created")
    print("  OK: Destroyed scope rejects new timers")

    print("PASS: All timer_scope tests passed")
    return true
end

-- Run tests
local success = test_timer_scope()
os.exit(success and 0 or 1)
