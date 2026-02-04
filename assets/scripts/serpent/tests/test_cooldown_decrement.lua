-- assets/scripts/serpent/tests/test_cooldown_decrement.lua
--[[
    Test Suite: Cooldown Decrement Phase

    Verifies that snake_logic.update_cooldowns correctly decrements
    unit cooldowns by dt for each segment in head→tail order.

    Run with: lua assets/scripts/serpent/tests/test_cooldown_decrement.lua
]]

-- Load dependencies
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local snake_logic = require("serpent.snake_logic")

-- Test framework
local test = {}
test.passed = 0
test.failed = 0

function test.assert_eq(actual, expected, message)
    if actual == expected then
        test.passed = test.passed + 1
        return true
    else
        test.failed = test.failed + 1
        print(string.format("✗ FAILED: %s\n  Expected: %s\n  Actual: %s",
            message or "assertion", tostring(expected), tostring(actual)))
        return false
    end
end

function test.assert_near(actual, expected, tolerance, message)
    if math.abs(actual - expected) <= tolerance then
        test.passed = test.passed + 1
        return true
    else
        test.failed = test.failed + 1
        print(string.format("✗ FAILED: %s\n  Expected: %s (±%s)\n  Actual: %s",
            message or "assertion", tostring(expected), tostring(tolerance), tostring(actual)))
        return false
    end
end

-- Helper: Create a test segment
local function make_segment(instance_id, cooldown)
    return {
        instance_id = instance_id,
        def_id = "test_unit",
        level = 1,
        hp = 100,
        hp_max_base = 100,
        attack_base = 10,
        range_base = 50,
        atk_spd_base = 1.0,
        cooldown = cooldown,
        acquired_seq = instance_id,
        special_state = {}
    }
end

-- Helper: Create a test snake state
local function make_snake_state(segments)
    return {
        segments = segments,
        min_len = 3,
        max_len = 8
    }
end

-- Test: Basic cooldown decrement
function test.test_basic_decrement()
    print("\n=== Test: Basic Cooldown Decrement ===")

    local snake = make_snake_state({
        make_segment(1, 1.0),  -- Head: 1.0s cooldown
        make_segment(2, 0.5),  -- Middle: 0.5s cooldown
        make_segment(3, 2.0),  -- Tail: 2.0s cooldown
    })

    local dt = 0.1
    local updated = snake_logic.update_cooldowns(snake, dt)

    test.assert_near(updated.segments[1].cooldown, 0.9, 0.001,
        "Segment 1 cooldown should be 0.9 after 0.1s")
    test.assert_near(updated.segments[2].cooldown, 0.4, 0.001,
        "Segment 2 cooldown should be 0.4 after 0.1s")
    test.assert_near(updated.segments[3].cooldown, 1.9, 0.001,
        "Segment 3 cooldown should be 1.9 after 0.1s")

    print("✓ Basic decrement works correctly")
end

-- Test: Cooldown clamping to zero
function test.test_clamp_to_zero()
    print("\n=== Test: Cooldown Clamping to Zero ===")

    local snake = make_snake_state({
        make_segment(1, 0.05), -- Will go below zero
        make_segment(2, 0.1),  -- Will hit exactly zero
        make_segment(3, 0.0),  -- Already at zero
    })

    local dt = 0.1
    local updated = snake_logic.update_cooldowns(snake, dt)

    test.assert_eq(updated.segments[1].cooldown, 0,
        "Cooldown should clamp to 0 (not go negative)")
    test.assert_eq(updated.segments[2].cooldown, 0,
        "Cooldown should be exactly 0")
    test.assert_eq(updated.segments[3].cooldown, 0,
        "Cooldown at 0 should stay at 0")

    print("✓ Cooldown clamping works correctly")
end

-- Test: Head to tail order is preserved
function test.test_head_to_tail_order()
    print("\n=== Test: Head→Tail Order Preserved ===")

    local snake = make_snake_state({
        make_segment(10, 3.0), -- Head
        make_segment(20, 2.0),
        make_segment(30, 1.0),
        make_segment(40, 0.5), -- Tail
    })

    local dt = 0.25
    local updated = snake_logic.update_cooldowns(snake, dt)

    -- Verify order is preserved (instance_ids should still be in order)
    test.assert_eq(updated.segments[1].instance_id, 10, "First segment should be instance 10 (head)")
    test.assert_eq(updated.segments[2].instance_id, 20, "Second segment should be instance 20")
    test.assert_eq(updated.segments[3].instance_id, 30, "Third segment should be instance 30")
    test.assert_eq(updated.segments[4].instance_id, 40, "Fourth segment should be instance 40 (tail)")

    -- Verify cooldowns are decremented correctly
    test.assert_near(updated.segments[1].cooldown, 2.75, 0.001, "Head cooldown: 3.0 - 0.25 = 2.75")
    test.assert_near(updated.segments[4].cooldown, 0.25, 0.001, "Tail cooldown: 0.5 - 0.25 = 0.25")

    print("✓ Head→tail order preserved")
end

-- Test: Large dt (multiple cooldowns expiring)
function test.test_large_dt()
    print("\n=== Test: Large Delta Time ===")

    local snake = make_snake_state({
        make_segment(1, 0.5),
        make_segment(2, 1.0),
        make_segment(3, 0.3),
    })

    local dt = 2.0 -- Large dt that expires all cooldowns
    local updated = snake_logic.update_cooldowns(snake, dt)

    test.assert_eq(updated.segments[1].cooldown, 0, "All cooldowns should clamp to 0 with large dt")
    test.assert_eq(updated.segments[2].cooldown, 0, "All cooldowns should clamp to 0 with large dt")
    test.assert_eq(updated.segments[3].cooldown, 0, "All cooldowns should clamp to 0 with large dt")

    print("✓ Large dt handling works correctly")
end

-- Test: Empty snake state
function test.test_empty_snake()
    print("\n=== Test: Empty Snake State ===")

    local snake = make_snake_state({})

    local dt = 0.1
    local updated = snake_logic.update_cooldowns(snake, dt)

    test.assert_eq(#updated.segments, 0, "Empty snake should remain empty")
    test.assert_eq(updated.min_len, 3, "min_len should be preserved")
    test.assert_eq(updated.max_len, 8, "max_len should be preserved")

    print("✓ Empty snake handled correctly")
end

-- Test: nil cooldown defaults to 0
function test.test_nil_cooldown()
    print("\n=== Test: Nil Cooldown Handling ===")

    local segment_with_nil = {
        instance_id = 1,
        def_id = "test",
        level = 1,
        hp = 100,
        hp_max_base = 100,
        attack_base = 10,
        range_base = 50,
        atk_spd_base = 1.0,
        cooldown = nil, -- Explicitly nil
        acquired_seq = 1,
        special_state = {}
    }

    local snake = make_snake_state({segment_with_nil})

    local dt = 0.1
    local updated = snake_logic.update_cooldowns(snake, dt)

    test.assert_eq(updated.segments[1].cooldown, 0,
        "Nil cooldown should be treated as 0 and clamp to 0")

    print("✓ Nil cooldown handled correctly")
end

-- Test: Immutability (original state unchanged)
function test.test_immutability()
    print("\n=== Test: State Immutability ===")

    local original_snake = make_snake_state({
        make_segment(1, 1.0),
        make_segment(2, 0.5),
    })

    local original_cooldown_1 = original_snake.segments[1].cooldown
    local original_cooldown_2 = original_snake.segments[2].cooldown

    local dt = 0.3
    local updated = snake_logic.update_cooldowns(original_snake, dt)

    -- Verify original is unchanged
    test.assert_eq(original_snake.segments[1].cooldown, original_cooldown_1,
        "Original segment 1 cooldown should be unchanged")
    test.assert_eq(original_snake.segments[2].cooldown, original_cooldown_2,
        "Original segment 2 cooldown should be unchanged")

    -- Verify updated is different
    test.assert_near(updated.segments[1].cooldown, 0.7, 0.001,
        "Updated segment 1 cooldown should be decremented")
    test.assert_near(updated.segments[2].cooldown, 0.2, 0.001,
        "Updated segment 2 cooldown should be decremented")

    print("✓ State immutability preserved")
end

-- Run all tests
function test.run_all()
    print("================================================================================")
    print("TEST SUITE: Cooldown Decrement Phase (bd-3eb)")
    print("================================================================================")

    test.test_basic_decrement()
    test.test_clamp_to_zero()
    test.test_head_to_tail_order()
    test.test_large_dt()
    test.test_empty_snake()
    test.test_nil_cooldown()
    test.test_immutability()

    print("\n================================================================================")
    print(string.format("RESULTS: %d passed, %d failed", test.passed, test.failed))
    print("================================================================================")

    return test.failed == 0
end

-- Execute tests if run directly
if arg and arg[0] and arg[0]:match("test_cooldown_decrement") then
    local success = test.run_all()
    os.exit(success and 0 or 1)
end

return test
