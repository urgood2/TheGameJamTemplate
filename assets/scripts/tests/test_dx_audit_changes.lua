--[[
================================================================================
DX AUDIT CHANGES - IN-GAME SMOKE TEST
================================================================================
Tests the new APIs added during the Lua Developer Experience audit.

Run in-game by calling:
    require("tests.test_dx_audit_changes").run()

Or from the debug console:
    dofile("assets/scripts/tests/test_dx_audit_changes.lua").run()
]]

local test = {}

local results = { passed = 0, failed = 0, errors = {} }

local function pass(name)
    results.passed = results.passed + 1
    print("[PASS] " .. name)
end

local function fail(name, err)
    results.failed = results.failed + 1
    table.insert(results.errors, { name = name, error = err })
    print("[FAIL] " .. name .. ": " .. tostring(err))
end

local function test_case(name, fn)
    local ok, err = pcall(fn)
    if ok then
        pass(name)
    else
        fail(name, err)
    end
end

--------------------------------------------------------------------------------
-- TEST: Q.lua Extensions
--------------------------------------------------------------------------------
local function test_Q_extensions()
    print("\n=== Q.lua Extensions ===")

    local Q = require("core.Q")

    -- Create a test entity
    local entity = registry:create()
    local transform = registry:emplace(entity, Transform)
    transform.actualX = 100
    transform.actualY = 200
    transform.actualW = 64
    transform.actualH = 48
    transform.actualR = 0
    transform.visualX = 100
    transform.visualY = 200
    transform.visualW = 64
    transform.visualH = 48

    -- Test Q.center
    test_case("Q.center returns correct values", function()
        local cx, cy = Q.center(entity)
        assert(cx == 132, "cx should be 132, got " .. tostring(cx))
        assert(cy == 224, "cy should be 224, got " .. tostring(cy))
    end)

    -- Test Q.visualCenter
    test_case("Q.visualCenter returns correct values", function()
        local vx, vy = Q.visualCenter(entity)
        assert(vx == 132, "vx should be 132, got " .. tostring(vx))
        assert(vy == 224, "vy should be 224, got " .. tostring(vy))
    end)

    -- Test Q.size
    test_case("Q.size returns correct values", function()
        local w, h = Q.size(entity)
        assert(w == 64, "w should be 64, got " .. tostring(w))
        assert(h == 48, "h should be 48, got " .. tostring(h))
    end)

    -- Test Q.bounds
    test_case("Q.bounds returns correct values", function()
        local x, y, w, h = Q.bounds(entity)
        assert(x == 100 and y == 200 and w == 64 and h == 48, "bounds mismatch")
    end)

    -- Test Q.rotation / Q.setRotation
    test_case("Q.rotation and Q.setRotation work", function()
        Q.setRotation(entity, 1.5)
        local r = Q.rotation(entity)
        assert(math.abs(r - 1.5) < 0.001, "rotation should be 1.5, got " .. tostring(r))
    end)

    -- Test Q.rotate
    test_case("Q.rotate adds to rotation", function()
        Q.setRotation(entity, 0)
        Q.rotate(entity, 0.5)
        Q.rotate(entity, 0.5)
        local r = Q.rotation(entity)
        assert(math.abs(r - 1.0) < 0.001, "rotation should be 1.0, got " .. tostring(r))
    end)

    -- Test Q.isValid
    test_case("Q.isValid returns true for valid entity", function()
        assert(Q.isValid(entity) == true, "should be valid")
    end)

    test_case("Q.isValid returns false for nil", function()
        assert(Q.isValid(nil) == false, "nil should be invalid")
    end)

    test_case("Q.isValid returns false for entt_null", function()
        assert(Q.isValid(entt_null) == false, "entt_null should be invalid")
    end)

    -- Test Q.ensure
    test_case("Q.ensure returns entity for valid", function()
        local e = Q.ensure(entity)
        assert(e == entity, "should return same entity")
    end)

    test_case("Q.ensure returns nil for invalid", function()
        local e = Q.ensure(nil)
        assert(e == nil, "should return nil")
    end)

    -- Test Q.move
    test_case("Q.move changes position", function()
        Q.move(entity, 500, 600)
        local cx, cy = Q.center(entity)
        assert(cx == 532, "cx should be 532 after move")
        assert(cy == 624, "cy should be 624 after move")
    end)

    -- Test Q.offset
    test_case("Q.offset adds to position", function()
        Q.move(entity, 100, 100)
        Q.offset(entity, 10, 20)
        local x, y = Q.bounds(entity)
        assert(x == 110, "x should be 110 after offset")
        assert(y == 120, "y should be 120 after offset")
    end)

    -- Test Q.distance (create second entity)
    local entity2 = registry:create()
    local transform2 = registry:emplace(entity2, Transform)
    transform2.actualX = 200
    transform2.actualY = 100
    transform2.actualW = 32
    transform2.actualH = 32

    test_case("Q.distance calculates correctly", function()
        Q.move(entity, 0, 0)
        local dist = Q.distance(entity, entity2)
        -- entity center: (32, 24), entity2 center: (216, 116)
        -- distance = sqrt((216-32)^2 + (116-24)^2) = sqrt(184^2 + 92^2) = sqrt(33856 + 8464) = sqrt(42320) ≈ 205.7
        assert(dist ~= nil, "distance should not be nil")
        assert(dist > 200 and dist < 210, "distance should be ~206, got " .. tostring(dist))
    end)

    -- Test Q.isInRange
    test_case("Q.isInRange works correctly", function()
        assert(Q.isInRange(entity, entity2, 300) == true, "should be in range 300")
        assert(Q.isInRange(entity, entity2, 100) == false, "should NOT be in range 100")
    end)

    -- Test Q.direction
    test_case("Q.direction returns normalized vector", function()
        local dx, dy = Q.direction(entity, entity2)
        assert(dx ~= nil and dy ~= nil, "direction should not be nil")
        local len = math.sqrt(dx*dx + dy*dy)
        assert(math.abs(len - 1.0) < 0.001, "direction should be normalized, got length " .. tostring(len))
    end)

    -- Test Q.getTransform
    test_case("Q.getTransform returns transform", function()
        local t = Q.getTransform(entity)
        assert(t ~= nil, "transform should not be nil")
        assert(t.actualW == 64, "actualW should be 64")
    end)

    -- Test Q.withTransform
    test_case("Q.withTransform calls callback", function()
        local called = false
        Q.withTransform(entity, function(t)
            called = true
            t.actualX = 999
        end)
        assert(called, "callback should have been called")
        assert(Q.bounds(entity) == 999, "X should be 999 after withTransform")
    end)

    -- Cleanup
    registry:destroy(entity)
    registry:destroy(entity2)
end

--------------------------------------------------------------------------------
-- TEST: popup.lua Helpers
--------------------------------------------------------------------------------
local function test_popup_helpers()
    print("\n=== popup.lua Helpers ===")

    local popup = require("core.popup")

    -- Create test entity
    local entity = registry:create()
    local transform = registry:emplace(entity, Transform)
    transform.actualX = 400
    transform.actualY = 300
    transform.actualW = 64
    transform.actualH = 64
    transform.visualX = 400
    transform.visualY = 300
    transform.visualW = 64
    transform.visualH = 64

    test_case("popup module loads", function()
        assert(popup ~= nil, "popup should not be nil")
    end)

    test_case("popup.defaults exists", function()
        assert(popup.defaults ~= nil, "defaults should exist")
        assert(popup.defaults.duration ~= nil, "duration default should exist")
    end)

    test_case("popup.at exists and is callable", function()
        assert(type(popup.at) == "function", "popup.at should be function")
        -- This will create a text popup (visual test)
        popup.at(100, 100, "Test popup.at", { color = "white", duration = 1.0 })
    end)

    test_case("popup.above works with entity", function()
        local result = popup.above(entity, "Above!", { color = "gold", duration = 1.0 })
        assert(result == true, "popup.above should return true for valid entity")
    end)

    test_case("popup.below works with entity", function()
        local result = popup.below(entity, "Below!", { color = "cyan", duration = 1.0 })
        assert(result == true, "popup.below should return true for valid entity")
    end)

    test_case("popup.heal shows healing number", function()
        local result = popup.heal(entity, 25)
        assert(result == true, "popup.heal should return true")
    end)

    test_case("popup.damage shows damage number", function()
        local result = popup.damage(entity, 50)
        assert(result == true, "popup.damage should return true")
    end)

    test_case("popup.critical shows critical hit", function()
        local result = popup.critical(entity, 100)
        assert(result == true, "popup.critical should return true")
    end)

    test_case("popup.gold shows gold change", function()
        local result = popup.gold(entity, 10)
        assert(result == true, "popup.gold should return true")
    end)

    test_case("popup.xp shows XP gain", function()
        local result = popup.xp(entity, 50)
        assert(result == true, "popup.xp should return true")
    end)

    test_case("popup.status shows status text", function()
        local result = popup.status(entity, "Stunned!")
        assert(result == true, "popup.status should return true")
    end)

    test_case("popup.miss shows miss text", function()
        local result = popup.miss(entity)
        assert(result == true, "popup.miss should return true")
    end)

    test_case("popup.above returns false for invalid entity", function()
        local result = popup.above(nil, "Test")
        assert(result == false, "should return false for nil entity")
    end)

    -- Cleanup
    registry:destroy(entity)
end

--------------------------------------------------------------------------------
-- TEST: signal_group.lua
--------------------------------------------------------------------------------
local function test_signal_group()
    print("\n=== signal_group.lua ===")

    local signal_group = require("core.signal_group")
    local signal = require("external.hump.signal")

    test_case("signal_group.new creates group", function()
        local group = signal_group.new("test_group")
        assert(group ~= nil, "group should not be nil")
        assert(group:getName() == "test_group", "name should be test_group")
    end)

    test_case("signal_group:on registers handler", function()
        local group = signal_group.new("handler_test")
        local called = false

        group:on("test_event", function()
            called = true
        end)

        signal.emit("test_event")
        assert(called, "handler should have been called")

        group:cleanup()
    end)

    test_case("signal_group:count tracks handlers", function()
        local group = signal_group.new("count_test")

        assert(group:count() == 0, "initial count should be 0")

        group:on("event1", function() end)
        assert(group:count() == 1, "count should be 1")

        group:on("event2", function() end)
        assert(group:count() == 2, "count should be 2")

        group:on("event1", function() end)  -- Same event, different handler
        assert(group:count() == 3, "count should be 3")

        group:cleanup()
    end)

    test_case("signal_group:cleanup removes all handlers", function()
        local group = signal_group.new("cleanup_test")
        local call_count = 0

        group:on("cleanup_event", function()
            call_count = call_count + 1
        end)

        signal.emit("cleanup_event")
        assert(call_count == 1, "should be called once before cleanup")

        group:cleanup()

        signal.emit("cleanup_event")
        assert(call_count == 1, "should NOT be called after cleanup")
    end)

    test_case("signal_group:isCleanedUp returns correct state", function()
        local group = signal_group.new("state_test")

        assert(group:isCleanedUp() == false, "should not be cleaned up initially")

        group:cleanup()

        assert(group:isCleanedUp() == true, "should be cleaned up after cleanup()")
    end)

    test_case("signal_group:off removes specific handler", function()
        local group = signal_group.new("off_test")
        local call_count = 0

        local handler = function()
            call_count = call_count + 1
        end

        group:on("off_event", handler)

        signal.emit("off_event")
        assert(call_count == 1, "should be called once")

        group:off("off_event", handler)

        signal.emit("off_event")
        assert(call_count == 1, "should NOT be called after off()")

        group:cleanup()
    end)
end

--------------------------------------------------------------------------------
-- TEST: Node.quick() and Node.create()
--------------------------------------------------------------------------------
local function test_node_factory()
    print("\n=== Node.quick() and Node.create() ===")

    local Node = require("monobehavior.behavior_script_v2")

    test_case("Node.quick creates script with data", function()
        local entity = registry:create()
        registry:emplace(entity, Transform)

        local script = Node.quick(entity, { health = 100, name = "test" })

        assert(script ~= nil, "script should not be nil")
        assert(script.health == 100, "health should be 100")
        assert(script.name == "test", "name should be test")
        assert(script:handle() == entity, "handle should match entity")

        registry:destroy(entity)
    end)

    test_case("Node.create creates new entity with script", function()
        local script = Node.create({ damage = 50, faction = "enemy" })

        assert(script ~= nil, "script should not be nil")
        assert(script.damage == 50, "damage should be 50")
        assert(script.faction == "enemy", "faction should be enemy")

        local entity = script:handle()
        assert(entity ~= nil, "entity should not be nil")

        registry:destroy(entity)
    end)

    test_case("Node.quick with custom class", function()
        local CustomType = Node:extend()
        function CustomType:getDoubleHealth()
            return (self.health or 0) * 2
        end

        local entity = registry:create()
        registry:emplace(entity, Transform)

        local script = Node.quick(entity, { health = 75 }, CustomType)

        assert(script:getDoubleHealth() == 150, "custom method should work")

        registry:destroy(entity)
    end)
end

--------------------------------------------------------------------------------
-- TEST: script:setState() and script:clearStateTags()
--------------------------------------------------------------------------------
local function test_state_management()
    print("\n=== script:setState() / clearStateTags() ===")

    local Node = require("monobehavior.behavior_script_v2")

    test_case("script:setState sets state tag", function()
        local entity = registry:create()
        registry:emplace(entity, Transform)

        local script = Node.quick(entity, {})

        -- This should not error
        local result = script:setState("IDLE")
        assert(result == script, "setState should return self for chaining")

        registry:destroy(entity)
    end)

    test_case("script:clearStateTags clears tags", function()
        local entity = registry:create()
        registry:emplace(entity, Transform)

        local script = Node.quick(entity, {})

        -- This should not error
        local result = script:clearStateTags()
        assert(result == script, "clearStateTags should return self for chaining")

        registry:destroy(entity)
    end)

    test_case("setState is chainable", function()
        local entity = registry:create()
        registry:emplace(entity, Transform)

        local script = Node.quick(entity, {})

        -- Chain multiple operations
        script:setState("STATE1"):clearStateTags():setState("STATE2")

        -- If we got here without error, it worked
        assert(true, "chaining works")

        registry:destroy(entity)
    end)
end

--------------------------------------------------------------------------------
-- RUN ALL TESTS
--------------------------------------------------------------------------------
function test.run()
    print("\n")
    print("================================================================================")
    print("DX AUDIT CHANGES - SMOKE TEST")
    print("================================================================================")

    results = { passed = 0, failed = 0, errors = {} }

    -- Run all test suites
    local ok, err

    ok, err = pcall(test_Q_extensions)
    if not ok then print("[ERROR] Q.lua tests crashed: " .. tostring(err)) end

    ok, err = pcall(test_popup_helpers)
    if not ok then print("[ERROR] popup tests crashed: " .. tostring(err)) end

    ok, err = pcall(test_signal_group)
    if not ok then print("[ERROR] signal_group tests crashed: " .. tostring(err)) end

    ok, err = pcall(test_node_factory)
    if not ok then print("[ERROR] Node factory tests crashed: " .. tostring(err)) end

    ok, err = pcall(test_state_management)
    if not ok then print("[ERROR] State management tests crashed: " .. tostring(err)) end

    -- Summary
    print("\n================================================================================")
    print("TEST SUMMARY")
    print("================================================================================")
    print(string.format("Passed: %d", results.passed))
    print(string.format("Failed: %d", results.failed))

    if results.failed > 0 then
        print("\nFailures:")
        for _, err in ipairs(results.errors) do
            print("  - " .. err.name .. ": " .. tostring(err.error))
        end
    end

    if results.failed == 0 then
        print("\n✓ ALL TESTS PASSED - DX Audit changes verified!")
    else
        print("\n✗ SOME TESTS FAILED - Check errors above")
    end

    print("================================================================================\n")

    return results
end

return test
