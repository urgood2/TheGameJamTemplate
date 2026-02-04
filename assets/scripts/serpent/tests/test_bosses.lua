--[[
================================================================================
TEST: Boss Mechanics Module
================================================================================
Tests boss behavior including swarm queen cadence, lich king raise scheduling,
and boss death filtering for the Serpent minigame.

Run with: lua assets/scripts/serpent/tests/test_bosses.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

-- Test framework
local test = {}
test.passed = 0
test.failed = 0
test.assertions = 0

function test.assert_eq(actual, expected, message)
    test.assertions = test.assertions + 1
    if actual == expected then
        test.passed = test.passed + 1
        return true
    else
        test.failed = test.failed + 1
        print(string.format("❌ FAIL: %s", message or "assertion"))
        print(string.format("   Expected: %s", tostring(expected)))
        print(string.format("   Actual:   %s", tostring(actual)))
        return false
    end
end

function test.assert_near(actual, expected, tolerance, message)
    test.assertions = test.assertions + 1
    local diff = math.abs(actual - expected)
    if diff <= tolerance then
        test.passed = test.passed + 1
        return true
    else
        test.failed = test.failed + 1
        print(string.format("❌ FAIL: %s", message or "near assertion"))
        print(string.format("   Expected: %s ± %s", tostring(expected), tostring(tolerance)))
        print(string.format("   Actual:   %s (diff: %s)", tostring(actual), tostring(diff)))
        return false
    end
end

function test.assert_true(condition, message)
    return test.assert_eq(condition, true, message)
end

function test.assert_false(condition, message)
    return test.assert_eq(condition, false, message)
end

function test.assert_table_length(table_val, expected_length, message)
    local actual_length = #table_val
    return test.assert_eq(actual_length, expected_length, message)
end

-- Load boss modules
local lich_king = require("serpent.bosses.lich_king")
local swarm_queen = require("serpent.bosses.swarm_queen")
local boss_event_processor = require("serpent.boss_event_processor")

--- Test swarm queen spawn cadence behavior
function test.test_swarm_queen_cadence()
    print("\n=== Testing Swarm Queen Cadence ===")

    -- Initialize swarm queen state
    local boss_state = swarm_queen.init(2001)
    test.assert_eq(boss_state.enemy_id, 2001, "Swarm queen initialized with correct enemy_id")
    test.assert_eq(boss_state.spawn_accumulator, 0.0, "Swarm queen spawn accumulator starts at 0")

    -- Test partial time accumulation (no spawn yet)
    local new_state, spawns = swarm_queen.tick(5.0, boss_state, true)
    test.assert_near(new_state.spawn_accumulator, 5.0, 0.01, "Accumulator correctly tracks partial time")
    test.assert_table_length(spawns, 0, "No spawns before 10 second interval")

    -- Test reaching spawn interval
    new_state, spawns = swarm_queen.tick(5.1, new_state, true)
    test.assert_table_length(spawns, 5, "Spawns 5 slimes after 10 second interval")
    test.assert_near(new_state.spawn_accumulator, 0.1, 0.01, "Accumulator resets correctly after spawn")

    -- Verify spawn content
    for i, spawn_def_id in ipairs(spawns) do
        test.assert_eq(spawn_def_id, "slime", string.format("Spawn %d is a slime", i))
    end

    -- Test double interval (20+ seconds at once)
    new_state, spawns = swarm_queen.tick(20.5, new_state, true)
    test.assert_table_length(spawns, 10, "Spawns 10 slimes for two intervals at once")

    -- Test behavior when dead
    dead_state, dead_spawns = swarm_queen.tick(15.0, new_state, false)
    test.assert_table_length(dead_spawns, 0, "No spawns when swarm queen is dead")
    test.assert_eq(dead_state.spawn_accumulator, new_state.spawn_accumulator, "Dead swarm queen doesn't accumulate time")

    print("✓ Swarm queen cadence tests completed")
end

--- Test lich king raise scheduling behavior
function test.test_lich_king_raise_scheduling()
    print("\n=== Testing Lich King Raise Scheduling ===")

    -- Initialize lich king state
    local boss_state = lich_king.init(3001)
    test.assert_eq(boss_state.enemy_id, 3001, "Lich king initialized with correct enemy_id")
    test.assert_eq(boss_state.queued_raises, 0, "Lich king starts with no queued raises")

    -- Test queuing raises from enemy deaths
    local updated_state = lich_king.on_enemy_dead(boss_state, "goblin", {})
    test.assert_eq(updated_state.queued_raises, 1, "Queues raise for non-boss enemy death")

    -- Queue multiple raises
    updated_state = lich_king.on_enemy_dead(updated_state, "orc", {})
    updated_state = lich_king.on_enemy_dead(updated_state, "troll", {})
    test.assert_eq(updated_state.queued_raises, 3, "Queues multiple raises from multiple deaths")

    -- Test raise processing when alive
    local final_state, delayed_spawns = lich_king.tick(0.1, updated_state, true)
    test.assert_eq(final_state.queued_raises, 0, "Clears queue after processing raises")
    test.assert_table_length(delayed_spawns, 3, "Generates 3 delayed spawns for queued raises")

    -- Verify delayed spawn content
    for i, delayed_spawn in ipairs(delayed_spawns) do
        test.assert_eq(delayed_spawn.def_id, "skeleton", string.format("Delayed spawn %d is skeleton", i))
        test.assert_near(delayed_spawn.t_left_sec, 2.0, 0.01, string.format("Delayed spawn %d has 2 second delay", i))
    end

    -- Test no processing when dead
    local dead_state = lich_king.on_enemy_dead(boss_state, "goblin", {})
    local final_dead_state, dead_spawns = lich_king.tick(0.1, dead_state, false)
    test.assert_eq(final_dead_state.queued_raises, 1, "Dead lich king keeps queued raises")
    test.assert_table_length(dead_spawns, 0, "Dead lich king doesn't generate spawns")

    print("✓ Lich king raise scheduling tests completed")
end

--- Test boss death filtering (lich king doesn't raise bosses)
function test.test_boss_death_filtering()
    print("\n=== Testing Boss Death Filtering ===")

    -- Initialize lich king state
    local boss_state = lich_king.init(4001)

    -- Test regular enemy death (should queue raise)
    local after_minion = lich_king.on_enemy_dead(boss_state, "goblin", {})
    test.assert_eq(after_minion.queued_raises, 1, "Regular enemy death queues raise")

    -- Test boss enemy death (should not queue raise)
    local after_boss = lich_king.on_enemy_dead(after_minion, "dragon", {"boss", "fire"})
    test.assert_eq(after_boss.queued_raises, 1, "Boss enemy death does not queue additional raise")

    -- Test enemy with boss tag explicitly
    local after_explicit_boss = lich_king.on_enemy_dead(after_boss, "lich_king", {"boss"})
    test.assert_eq(after_explicit_boss.queued_raises, 1, "Enemy with boss tag does not queue raise")

    -- Test enemy without tags (should queue raise)
    local after_no_tags = lich_king.on_enemy_dead(after_explicit_boss, "skeleton", nil)
    test.assert_eq(after_no_tags.queued_raises, 2, "Enemy with no tags queues raise")

    -- Test mixed tag enemy (non-boss)
    local after_mixed = lich_king.on_enemy_dead(after_no_tags, "elite_goblin", {"elite", "melee"})
    test.assert_eq(after_mixed.queued_raises, 3, "Enemy with non-boss tags queues raise")

    print("✓ Boss death filtering tests completed")
end

--- Test boss event processor integration
function test.test_boss_event_processor_integration()
    print("\n=== Testing Boss Event Processor Integration ===")

    -- Create boss processor state with both bosses
    local active_bosses = {
        {enemy_id = 5001, def_id = "lich_king"},
        {enemy_id = 5002, def_id = "swarm_queen"}
    }
    local processor_state = boss_event_processor.create_state(active_bosses)

    -- Verify both bosses were initialized
    test.assert_eq(processor_state.active_boss_ids[5001], "lich_king", "Lich king added to processor")
    test.assert_eq(processor_state.active_boss_ids[5002], "swarm_queen", "Swarm queen added to processor")
    test.assert_true(processor_state.boss_states[5001] ~= nil, "Lich king state initialized")
    test.assert_true(processor_state.boss_states[5002] ~= nil, "Swarm queen state initialized")

    -- Create enemy death events
    local death_events = {
        {type = "enemy_dead", enemy_id = 1001, def_id = "goblin"},
        {type = "enemy_dead", enemy_id = 1002, def_id = "orc"},
    }

    local enemy_definitions = {
        goblin = {id = "goblin", tags = {}},
        orc = {id = "orc", tags = {}}
    }

    local alive_bosses = {[5001] = true, [5002] = true}

    -- Process death events
    local updated_state = boss_event_processor.process_enemy_dead_events(
        death_events, processor_state, enemy_definitions, alive_bosses)

    -- Check lich king queued raises
    local lich_state = updated_state.boss_states[5001]
    test.assert_eq(lich_state.queued_raises, 2, "Lich king queued 2 raises from enemy deaths")

    -- Tick processor to generate events
    local final_state, spawn_events = boss_event_processor.tick(0.1, updated_state, alive_bosses)

    -- Should generate delayed spawn events from lich king
    local delayed_events = {}
    local immediate_events = {}
    for _, event in ipairs(spawn_events) do
        if event.type == "DelayedSpawnEvent" then
            table.insert(delayed_events, event)
        elseif event.type == "SpawnEnemyEvent" then
            table.insert(immediate_events, event)
        end
    end

    test.assert_table_length(delayed_events, 2, "Generated 2 delayed spawn events from lich king")
    for _, event in ipairs(delayed_events) do
        test.assert_eq(event.enemy_def_id, "skeleton", "Delayed spawn is skeleton")
        test.assert_eq(event.source_boss_id, 5001, "Delayed spawn from lich king")
    end

    print("✓ Boss event processor integration tests completed")
end

--- Test boss lifecycle in processor
function test.test_boss_lifecycle()
    print("\n=== Testing Boss Lifecycle ===")

    -- Start with empty processor
    local processor_state = boss_event_processor.create_state({})
    local summary = boss_event_processor.get_summary(processor_state)
    test.assert_eq(summary.active_boss_count, 0, "Empty processor has no active bosses")

    -- Add lich king
    local lich_boss = {enemy_id = 6001, def_id = "lich_king"}
    processor_state = boss_event_processor.add_boss(processor_state, lich_boss)
    summary = boss_event_processor.get_summary(processor_state)
    test.assert_eq(summary.active_boss_count, 1, "Added lich king increases boss count")
    test.assert_eq(summary.boss_types["lich_king"], 1, "Summary shows 1 lich king")

    -- Add swarm queen
    local swarm_boss = {enemy_id = 6002, def_id = "swarm_queen"}
    processor_state = boss_event_processor.add_boss(processor_state, swarm_boss)
    summary = boss_event_processor.get_summary(processor_state)
    test.assert_eq(summary.active_boss_count, 2, "Added swarm queen increases boss count")
    test.assert_eq(summary.boss_types["swarm_queen"], 1, "Summary shows 1 swarm queen")

    -- Remove lich king
    processor_state = boss_event_processor.remove_boss(processor_state, 6001)
    summary = boss_event_processor.get_summary(processor_state)
    test.assert_eq(summary.active_boss_count, 1, "Removed lich king decreases boss count")
    test.assert_eq(summary.boss_types["lich_king"], nil, "Summary shows no lich kings")
    test.assert_eq(summary.boss_types["swarm_queen"], 1, "Summary still shows swarm queen")

    -- Remove swarm queen
    processor_state = boss_event_processor.remove_boss(processor_state, 6002)
    summary = boss_event_processor.get_summary(processor_state)
    test.assert_eq(summary.active_boss_count, 0, "Removed all bosses")

    print("✓ Boss lifecycle tests completed")
end

--- Test edge cases and error handling
function test.test_boss_edge_cases()
    print("\n=== Testing Boss Edge Cases ===")

    -- Test lich king with invalid inputs
    local lich_state = lich_king.init(7001)

    -- Test with nil tags
    local after_nil_tags = lich_king.on_enemy_dead(lich_state, "goblin", nil)
    test.assert_eq(after_nil_tags.queued_raises, 1, "Handles nil tags gracefully")

    -- Test with empty tags array
    local after_empty_tags = lich_king.on_enemy_dead(lich_state, "goblin", {})
    test.assert_eq(after_empty_tags.queued_raises, 1, "Handles empty tags array")

    -- Test swarm queen with zero delta time
    local swarm_state = swarm_queen.init(7002)
    local new_state, spawns = swarm_queen.tick(0.0, swarm_state, true)
    test.assert_eq(new_state.spawn_accumulator, 0.0, "Zero delta time doesn't change accumulator")
    test.assert_table_length(spawns, 0, "Zero delta time doesn't trigger spawns")

    -- Test boss event processor with invalid events
    local processor_state = boss_event_processor.create_state({})
    local invalid_events = {
        {type = "wrong_type", enemy_id = 1, def_id = "goblin"},
        {type = "enemy_dead", def_id = "goblin"}, -- missing enemy_id
        {type = "enemy_dead", enemy_id = 1}, -- missing def_id
        nil,
        {}
    }

    -- Should handle invalid events without crashing
    local updated_state = boss_event_processor.process_enemy_dead_events(
        invalid_events, processor_state, {}, {})
    test.assert_true(updated_state ~= nil, "Handles invalid events without crashing")

    print("✓ Boss edge cases tests completed")
end

--- Main test runner
function test.run_all()
    print("================================================================================")
    print("TESTING: Boss Mechanics (Swarm Queen Cadence, Lich King Raise Scheduling)")
    print("================================================================================")
    print("Verifying boss behavior, death filtering, and event processing integration")

    -- Run all test suites
    test.test_swarm_queen_cadence()
    test.test_lich_king_raise_scheduling()
    test.test_boss_death_filtering()
    test.test_boss_event_processor_integration()
    test.test_boss_lifecycle()
    test.test_boss_edge_cases()

    -- Print summary
    print("\n================================================================================")
    print("TEST SUMMARY")
    print("================================================================================")

    local total = test.passed + test.failed
    local pass_rate = total > 0 and (test.passed / total * 100) or 0

    print(string.format("Total Tests: %d", total))
    print(string.format("Passed: %d (%.1f%%)", test.passed, pass_rate))
    print(string.format("Failed: %d", test.failed))
    print(string.format("Assertions: %d", test.assertions))

    if test.failed == 0 then
        print("\n🎉 ALL TESTS PASSED!")
        print("✓ Swarm queen spawn cadence works correctly (5 slimes every 10s)")
        print("✓ Lich king raise scheduling works correctly (2s delayed skeletons)")
        print("✓ Boss death filtering prevents raising bosses")
        print("✓ Boss event processor integration handles multiple bosses")
        print("✓ Boss lifecycle management works correctly")
        print("✓ Edge cases handled gracefully")
        return true
    else
        print(string.format("\n❌ %d TESTS FAILED", test.failed))
        return false
    end
end

-- Run the tests
local success = test.run_all()
os.exit(success and 0 or 1)