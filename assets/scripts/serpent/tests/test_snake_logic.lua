-- assets/scripts/serpent/tests/test_snake_logic.lua
--[[
    Test Suite: Snake Logic Module

    Verifies snake state management including:
    - Sell blocking (can_sell with min_len constraint)
    - Death removal (remove_instance)
    - Length 0 dead state
    - Instance ID monotonicity

    Run with: lua assets/scripts/serpent/tests/test_snake_logic.lua
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

function test.assert_true(condition, message)
    return test.assert_eq(condition, true, message)
end

function test.assert_false(condition, message)
    return test.assert_eq(condition, false, message)
end

-- Helper: Create a test segment
local function make_segment(instance_id, hp)
    return {
        instance_id = instance_id,
        def_id = "test_unit",
        level = 1,
        hp = hp or 100,
        hp_max_base = 100,
        attack_base = 10,
        range_base = 50,
        atk_spd_base = 1.0,
        cooldown = 0,
        acquired_seq = instance_id,
        special_state = {}
    }
end

-- Helper: Create a test snake state
local function make_snake_state(segments, min_len, max_len)
    return {
        segments = segments,
        min_len = min_len or 3,
        max_len = max_len or 8
    }
end

--===========================================================================
-- TEST: Sell Blocking (can_sell with min_len constraint)
--===========================================================================

function test.test_can_sell_at_min_length()
    print("\n=== Test: Can't Sell at Minimum Length ===")

    -- Snake at exactly min_len = 3
    local snake = make_snake_state({
        make_segment(1),
        make_segment(2),
        make_segment(3),
    }, 3, 8)

    test.assert_false(snake_logic.can_sell(snake, 1), "Can't sell segment 1 at min length")
    test.assert_false(snake_logic.can_sell(snake, 2), "Can't sell segment 2 at min length")
    test.assert_false(snake_logic.can_sell(snake, 3), "Can't sell segment 3 at min length")

    print("✓ Sell blocked at minimum length")
end

function test.test_can_sell_above_min_length()
    print("\n=== Test: Can Sell Above Minimum Length ===")

    -- Snake at length 4 (min_len = 3)
    local snake = make_snake_state({
        make_segment(1),
        make_segment(2),
        make_segment(3),
        make_segment(4),
    }, 3, 8)

    test.assert_true(snake_logic.can_sell(snake, 1), "Can sell segment 1 (length 4 > min 3)")
    test.assert_true(snake_logic.can_sell(snake, 2), "Can sell segment 2")
    test.assert_true(snake_logic.can_sell(snake, 3), "Can sell segment 3")
    test.assert_true(snake_logic.can_sell(snake, 4), "Can sell segment 4")

    print("✓ Sell allowed above minimum length")
end

function test.test_can_sell_nonexistent()
    print("\n=== Test: Can't Sell Non-Existent Segment ===")

    local snake = make_snake_state({
        make_segment(1),
        make_segment(2),
        make_segment(3),
        make_segment(4),
    })

    test.assert_false(snake_logic.can_sell(snake, 99), "Can't sell non-existent segment")
    test.assert_false(snake_logic.can_sell(snake, 0), "Can't sell segment with id 0")

    print("✓ Sell fails for non-existent segments")
end

function test.test_can_sell_nil_state()
    print("\n=== Test: Can't Sell With Nil State ===")

    test.assert_false(snake_logic.can_sell(nil, 1), "Can't sell from nil state")
    test.assert_false(snake_logic.can_sell({}, 1), "Can't sell from empty state")
    test.assert_false(snake_logic.can_sell({ segments = nil }, 1), "Can't sell with nil segments")

    print("✓ Sell handles nil/empty state correctly")
end

--===========================================================================
-- TEST: Death Removal (remove_instance)
--===========================================================================

function test.test_remove_instance_basic()
    print("\n=== Test: Remove Instance Basic ===")

    local snake = make_snake_state({
        make_segment(1),
        make_segment(2),
        make_segment(3),
        make_segment(4),
    })

    local updated, found = snake_logic.remove_instance(snake, 2)

    test.assert_true(found, "Should find segment to remove")
    test.assert_eq(#updated.segments, 3, "Should have 3 segments after removal")
    test.assert_eq(snake_logic.find_segment(updated, 2), nil, "Removed segment should be gone")
    test.assert_true(snake_logic.find_segment(updated, 1) ~= nil, "Other segments remain")
    test.assert_true(snake_logic.find_segment(updated, 3) ~= nil, "Other segments remain")
    test.assert_true(snake_logic.find_segment(updated, 4) ~= nil, "Other segments remain")

    print("✓ Remove instance works correctly")
end

function test.test_remove_instance_nonexistent()
    print("\n=== Test: Remove Non-Existent Instance ===")

    local snake = make_snake_state({
        make_segment(1),
        make_segment(2),
        make_segment(3),
    })

    local updated, found = snake_logic.remove_instance(snake, 99)

    test.assert_false(found, "Should not find non-existent segment")
    test.assert_eq(#updated.segments, 3, "Segments should remain unchanged")

    print("✓ Remove handles non-existent instance correctly")
end

function test.test_remove_preserves_order()
    print("\n=== Test: Remove Preserves Order ===")

    local snake = make_snake_state({
        make_segment(10),
        make_segment(20),
        make_segment(30),
        make_segment(40),
    })

    -- Remove middle element
    local updated, _ = snake_logic.remove_instance(snake, 20)

    -- Verify order is preserved
    test.assert_eq(updated.segments[1].instance_id, 10, "First should be 10")
    test.assert_eq(updated.segments[2].instance_id, 30, "Second should be 30")
    test.assert_eq(updated.segments[3].instance_id, 40, "Third should be 40")

    print("✓ Remove preserves segment order")
end

--===========================================================================
-- TEST: Length 0 Dead State
--===========================================================================

function test.test_is_dead_at_zero()
    print("\n=== Test: is_dead at Length 0 ===")

    local empty_snake = make_snake_state({}, 3, 8)

    test.assert_true(snake_logic.is_dead(empty_snake), "Snake with 0 segments is dead")

    print("✓ Length 0 is detected as dead")
end

function test.test_is_dead_below_min()
    print("\n=== Test: is_dead Below Minimum ===")

    local snake_1 = make_snake_state({ make_segment(1) }, 3, 8)
    local snake_2 = make_snake_state({ make_segment(1), make_segment(2) }, 3, 8)

    test.assert_true(snake_logic.is_dead(snake_1), "1 segment (min 3) is dead")
    test.assert_true(snake_logic.is_dead(snake_2), "2 segments (min 3) is dead")

    print("✓ Below min_len is detected as dead")
end

function test.test_is_dead_at_min()
    print("\n=== Test: is_dead at Minimum ===")

    local snake = make_snake_state({
        make_segment(1),
        make_segment(2),
        make_segment(3),
    }, 3, 8)

    test.assert_false(snake_logic.is_dead(snake), "3 segments (min 3) is NOT dead")

    print("✓ At min_len is NOT dead")
end

function test.test_is_dead_nil_state()
    print("\n=== Test: is_dead with Nil State ===")

    test.assert_true(snake_logic.is_dead(nil), "Nil state is dead")
    test.assert_true(snake_logic.is_dead({}), "Empty table is dead")
    test.assert_true(snake_logic.is_dead({ segments = nil }), "Nil segments is dead")

    print("✓ Nil/empty states are dead")
end

function test.test_remove_to_zero()
    print("\n=== Test: Remove Down to Zero ===")

    local snake = make_snake_state({
        make_segment(1),
        make_segment(2),
        make_segment(3),
    })

    -- Remove all segments
    local updated, _ = snake_logic.remove_instance(snake, 1)
    updated, _ = snake_logic.remove_instance(updated, 2)
    updated, _ = snake_logic.remove_instance(updated, 3)

    test.assert_eq(#updated.segments, 0, "Should have 0 segments")
    test.assert_true(snake_logic.is_dead(updated), "Snake should be dead")

    print("✓ Can remove to zero segments")
end

--===========================================================================
-- TEST: Instance ID Monotonicity
--===========================================================================

function test.test_instance_id_uniqueness()
    print("\n=== Test: Instance ID Uniqueness ===")

    -- Create snake with sequential IDs
    local snake = make_snake_state({
        make_segment(1),
        make_segment(2),
        make_segment(3),
        make_segment(4),
        make_segment(5),
    })

    -- Collect all IDs
    local ids = {}
    local has_duplicates = false
    for _, segment in ipairs(snake.segments) do
        if ids[segment.instance_id] then
            has_duplicates = true
        end
        ids[segment.instance_id] = true
    end

    test.assert_false(has_duplicates, "Instance IDs should be unique")

    print("✓ Instance IDs are unique")
end

function test.test_instance_id_monotonicity_after_removal()
    print("\n=== Test: IDs Remain Monotonic After Removal ===")

    local snake = make_snake_state({
        make_segment(1),
        make_segment(2),
        make_segment(3),
        make_segment(4),
        make_segment(5),
    })

    -- Remove segment 3
    local updated, _ = snake_logic.remove_instance(snake, 3)

    -- Check remaining IDs are still in original relative order
    local prev_id = 0
    local order_preserved = true
    for _, segment in ipairs(updated.segments) do
        if segment.instance_id < prev_id then
            order_preserved = false
        end
        prev_id = segment.instance_id
    end

    test.assert_true(order_preserved, "Remaining IDs should maintain relative order")

    print("✓ IDs remain monotonically ordered after removal")
end

--===========================================================================
-- TEST: Built-in Tests
--===========================================================================

function test.test_apply_damage_nonlethal()
    print("\n=== Test: Apply Damage (Non-Lethal) ===")

    local snake = make_snake_state({
        make_segment(1, 100),
        make_segment(2, 100),
        make_segment(3, 100),
    })

    local updated, events = snake_logic.apply_damage(snake, 2, 30)

    test.assert_eq(#updated.segments, 3, "Should still have 3 segments")
    test.assert_eq(#events, 0, "Should have no death events")

    local segment2 = snake_logic.find_segment(updated, 2)
    test.assert_eq(segment2.hp, 70, "Segment 2 should have 70 HP after 30 damage")

    print("✓ Non-lethal damage applied correctly")
end

function test.test_apply_damage_lethal()
    print("\n=== Test: Apply Damage (Lethal) ===")

    local snake = make_snake_state({
        make_segment(1, 100),
        make_segment(2, 50),
        make_segment(3, 100),
        make_segment(4, 100),
    })

    local updated, events = snake_logic.apply_damage(snake, 2, 60)

    test.assert_eq(#updated.segments, 3, "Should have 3 segments after death")
    test.assert_eq(#events, 1, "Should have 1 death event")
    test.assert_eq(events[1].instance_id, 2, "Death event should be for segment 2")
    test.assert_eq(snake_logic.find_segment(updated, 2), nil, "Segment 2 should be gone")

    print("✓ Lethal damage removes segment and generates death event")
end

function test.test_builtin_can_sell()
    print("\n=== Test: Built-in Can Sell ===")

    local result = snake_logic.test_can_sell()
    test.assert_true(result, "Built-in can_sell test should pass")

    print("✓ Built-in can_sell test passed")
end

function test.test_builtin_remove_instance()
    print("\n=== Test: Built-in Remove Instance ===")

    local result = snake_logic.test_remove_instance()
    test.assert_true(result, "Built-in remove_instance test should pass")

    print("✓ Built-in remove_instance test passed")
end

--===========================================================================
-- TEST: State Immutability
--===========================================================================

function test.test_remove_immutability()
    print("\n=== Test: Remove Instance Immutability ===")

    local original = make_snake_state({
        make_segment(1),
        make_segment(2),
        make_segment(3),
    })
    local original_count = #original.segments

    local _, _ = snake_logic.remove_instance(original, 2)

    test.assert_eq(#original.segments, original_count, "Original should be unchanged")
    test.assert_true(snake_logic.find_segment(original, 2) ~= nil,
        "Original should still have removed segment")

    print("✓ remove_instance preserves immutability")
end

--===========================================================================
-- RUN ALL TESTS
--===========================================================================

function test.run_all()
    print("================================================================================")
    print("TEST SUITE: Snake Logic (bd-3dd)")
    print("================================================================================")

    -- Sell blocking tests
    test.test_can_sell_at_min_length()
    test.test_can_sell_above_min_length()
    test.test_can_sell_nonexistent()
    test.test_can_sell_nil_state()

    -- Death removal tests
    test.test_remove_instance_basic()
    test.test_remove_instance_nonexistent()
    test.test_remove_preserves_order()

    -- Length 0 dead tests
    test.test_is_dead_at_zero()
    test.test_is_dead_below_min()
    test.test_is_dead_at_min()
    test.test_is_dead_nil_state()
    test.test_remove_to_zero()

    -- Instance ID tests
    test.test_instance_id_uniqueness()
    test.test_instance_id_monotonicity_after_removal()

    -- Damage tests
    test.test_apply_damage_nonlethal()
    test.test_apply_damage_lethal()

    -- Built-in tests (can_sell and remove_instance)
    test.test_builtin_can_sell()
    test.test_builtin_remove_instance()

    -- Immutability
    test.test_remove_immutability()

    print("\n================================================================================")
    print(string.format("RESULTS: %d passed, %d failed", test.passed, test.failed))
    print("================================================================================")

    return test.failed == 0
end

-- Execute tests if run directly
if arg and arg[0] and arg[0]:match("test_snake_logic") then
    local success = test.run_all()
    os.exit(success and 0 or 1)
end

return test
