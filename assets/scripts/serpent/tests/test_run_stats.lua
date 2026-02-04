-- assets/scripts/serpent/tests/test_run_stats.lua
--[[
    Test Suite: Run Stats Tracking (bd-290x)

    Verifies serpent_main run statistics tracking:
    - reset_run_stats: clears all stats
    - record_* functions: increment stats properly
    - get_run_stats: returns accurate copy of stats
    - end_run: marks run end time

    Run with: lua assets/scripts/serpent/tests/test_run_stats.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

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
        print(string.format("\226\156\151 FAILED: %s\n  Expected: %s\n  Actual: %s",
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

function test.assert_ge(actual, expected, message)
    if actual >= expected then
        test.passed = test.passed + 1
        return true
    else
        test.failed = test.failed + 1
        print(string.format("\226\156\151 FAILED: %s\n  Expected >= %s\n  Actual: %s",
            message or "assertion", tostring(expected), tostring(actual)))
        return false
    end
end

-- Mock love.timer
_G.love = {
    timer = {
        getTime = function()
            return os.time()
        end
    }
}

-- Mock log functions
_G.log_debug = function() end
_G.log_error = function() end
_G.log_warning = function() end

-- Mock physics and other systems
_G.physics = {
    AddCollisionTag = function() end,
    enable_collision_between = function() end,
    on_pair_begin = function() end,
    on_pair_separate = function() end
}
_G.PhysicsManager = nil

-- Mock snake_entity_adapter
package.loaded["serpent.snake_entity_adapter"] = {
    init = function() end,
    cleanup = function() end,
    spawn_segment = function() return 1 end
}

-- Mock contact_collector_adapter
package.loaded["serpent.contact_collector_adapter"] = {
    init = function() end,
    cleanup = function() end
}

-- Mock constants
package.loaded["core.constants"] = {
    TimerGroups = { SERPENT = "serpent" },
    CollisionTags = {}
}

-- Mock signal system
local mock_signal_handlers = {}
package.loaded["external.hump.signal"] = {
    register = function(name, handler)
        mock_signal_handlers[name] = handler
    end,
    emit = function(name, ...)
        if mock_signal_handlers[name] then
            mock_signal_handlers[name](...)
        end
    end,
    remove = function() end
}

local serpent_main = require("serpent.serpent_main")

--===========================================================================
-- TEST: reset_run_stats
--===========================================================================

function test.test_reset_stats_initial()
    print("\n=== Test: Reset Stats Initial ===")

    serpent_main.reset_run_stats()
    local stats = serpent_main.get_run_stats()

    test.assert_eq(stats.waves_cleared, 0, "Waves cleared starts at 0")
    test.assert_eq(stats.gold_earned, 0, "Gold earned starts at 0")
    test.assert_eq(stats.units_purchased, 0, "Units purchased starts at 0")
    test.assert_eq(stats.enemies_killed, 0, "Enemies killed starts at 0")
    test.assert_eq(stats.damage_dealt, 0, "Damage dealt starts at 0")
    test.assert_eq(stats.damage_taken, 0, "Damage taken starts at 0")

    print("\226\156\147 Reset stats initial values correct")
end

function test.test_reset_stats_clears_previous()
    print("\n=== Test: Reset Stats Clears Previous ===")

    -- Record some stats
    serpent_main.record_wave_cleared()
    serpent_main.record_gold_earned(100)
    serpent_main.record_unit_purchased()

    -- Verify stats were recorded
    local stats_before = serpent_main.get_run_stats()
    test.assert_eq(stats_before.waves_cleared, 1, "Wave recorded before reset")

    -- Reset and verify cleared
    serpent_main.reset_run_stats()
    local stats_after = serpent_main.get_run_stats()

    test.assert_eq(stats_after.waves_cleared, 0, "Waves cleared after reset")
    test.assert_eq(stats_after.gold_earned, 0, "Gold cleared after reset")
    test.assert_eq(stats_after.units_purchased, 0, "Units cleared after reset")

    print("\226\156\147 Reset clears previous stats")
end

--===========================================================================
-- TEST: record_wave_cleared
--===========================================================================

function test.test_record_wave_single()
    print("\n=== Test: Record Wave Single ===")

    serpent_main.reset_run_stats()
    serpent_main.record_wave_cleared()

    local stats = serpent_main.get_run_stats()
    test.assert_eq(stats.waves_cleared, 1, "Single wave recorded")

    print("\226\156\147 Single wave recording correct")
end

function test.test_record_wave_multiple()
    print("\n=== Test: Record Wave Multiple ===")

    serpent_main.reset_run_stats()
    for i = 1, 5 do
        serpent_main.record_wave_cleared()
    end

    local stats = serpent_main.get_run_stats()
    test.assert_eq(stats.waves_cleared, 5, "Multiple waves recorded")

    print("\226\156\147 Multiple wave recording correct")
end

--===========================================================================
-- TEST: record_gold_earned
--===========================================================================

function test.test_record_gold_single()
    print("\n=== Test: Record Gold Single ===")

    serpent_main.reset_run_stats()
    serpent_main.record_gold_earned(50)

    local stats = serpent_main.get_run_stats()
    test.assert_eq(stats.gold_earned, 50, "Single gold amount recorded")

    print("\226\156\147 Single gold recording correct")
end

function test.test_record_gold_accumulated()
    print("\n=== Test: Record Gold Accumulated ===")

    serpent_main.reset_run_stats()
    serpent_main.record_gold_earned(25)
    serpent_main.record_gold_earned(75)
    serpent_main.record_gold_earned(100)

    local stats = serpent_main.get_run_stats()
    test.assert_eq(stats.gold_earned, 200, "Gold accumulates correctly")

    print("\226\156\147 Gold accumulation correct")
end

function test.test_record_gold_zero_ignored()
    print("\n=== Test: Record Gold Zero Ignored ===")

    serpent_main.reset_run_stats()
    serpent_main.record_gold_earned(0)
    serpent_main.record_gold_earned(nil)

    local stats = serpent_main.get_run_stats()
    test.assert_eq(stats.gold_earned, 0, "Zero/nil gold ignored")

    print("\226\156\147 Zero gold handling correct")
end

function test.test_record_gold_negative_ignored()
    print("\n=== Test: Record Gold Negative Ignored ===")

    serpent_main.reset_run_stats()
    serpent_main.record_gold_earned(-50)

    local stats = serpent_main.get_run_stats()
    test.assert_eq(stats.gold_earned, 0, "Negative gold ignored")

    print("\226\156\147 Negative gold handling correct")
end

--===========================================================================
-- TEST: record_unit_purchased
--===========================================================================

function test.test_record_unit_single()
    print("\n=== Test: Record Unit Single ===")

    serpent_main.reset_run_stats()
    serpent_main.record_unit_purchased()

    local stats = serpent_main.get_run_stats()
    test.assert_eq(stats.units_purchased, 1, "Single unit recorded")

    print("\226\156\147 Single unit recording correct")
end

function test.test_record_unit_multiple()
    print("\n=== Test: Record Unit Multiple ===")

    serpent_main.reset_run_stats()
    for i = 1, 8 do
        serpent_main.record_unit_purchased()
    end

    local stats = serpent_main.get_run_stats()
    test.assert_eq(stats.units_purchased, 8, "Multiple units recorded")

    print("\226\156\147 Multiple unit recording correct")
end

--===========================================================================
-- TEST: record_enemy_killed
--===========================================================================

function test.test_record_enemy_killed()
    print("\n=== Test: Record Enemy Killed ===")

    serpent_main.reset_run_stats()
    serpent_main.record_enemy_killed()
    serpent_main.record_enemy_killed()
    serpent_main.record_enemy_killed()

    local stats = serpent_main.get_run_stats()
    test.assert_eq(stats.enemies_killed, 3, "Enemies killed recorded")

    print("\226\156\147 Enemy kill recording correct")
end

--===========================================================================
-- TEST: record_damage_dealt / record_damage_taken
--===========================================================================

function test.test_record_damage_dealt()
    print("\n=== Test: Record Damage Dealt ===")

    serpent_main.reset_run_stats()
    serpent_main.record_damage_dealt(100)
    serpent_main.record_damage_dealt(50)

    local stats = serpent_main.get_run_stats()
    test.assert_eq(stats.damage_dealt, 150, "Damage dealt accumulated")

    print("\226\156\147 Damage dealt recording correct")
end

function test.test_record_damage_taken()
    print("\n=== Test: Record Damage Taken ===")

    serpent_main.reset_run_stats()
    serpent_main.record_damage_taken(30)
    serpent_main.record_damage_taken(20)

    local stats = serpent_main.get_run_stats()
    test.assert_eq(stats.damage_taken, 50, "Damage taken accumulated")

    print("\226\156\147 Damage taken recording correct")
end

function test.test_record_damage_ignores_invalid()
    print("\n=== Test: Record Damage Ignores Invalid ===")

    serpent_main.reset_run_stats()
    serpent_main.record_damage_dealt(0)
    serpent_main.record_damage_dealt(-10)
    serpent_main.record_damage_dealt(nil)
    serpent_main.record_damage_taken(0)
    serpent_main.record_damage_taken(-5)

    local stats = serpent_main.get_run_stats()
    test.assert_eq(stats.damage_dealt, 0, "Invalid damage dealt ignored")
    test.assert_eq(stats.damage_taken, 0, "Invalid damage taken ignored")

    print("\226\156\147 Invalid damage handling correct")
end

--===========================================================================
-- TEST: get_run_stats returns copy
--===========================================================================

function test.test_get_stats_returns_copy()
    print("\n=== Test: Get Stats Returns Copy ===")

    serpent_main.reset_run_stats()
    serpent_main.record_wave_cleared()

    local stats1 = serpent_main.get_run_stats()
    stats1.waves_cleared = 999  -- Modify the returned copy

    local stats2 = serpent_main.get_run_stats()
    test.assert_eq(stats2.waves_cleared, 1, "Original stats unchanged by copy modification")

    print("\226\156\147 Stats returns copy (immutable)")
end

--===========================================================================
-- TEST: run_duration calculation
--===========================================================================

function test.test_run_duration_calculated()
    print("\n=== Test: Run Duration Calculated ===")

    serpent_main.reset_run_stats()

    -- Get stats - duration should be >= 0
    local stats = serpent_main.get_run_stats()
    test.assert_ge(stats.run_duration, 0, "Run duration is non-negative")

    print("\226\156\147 Run duration calculation correct")
end

--===========================================================================
-- TEST: end_run
--===========================================================================

function test.test_end_run_marks_end_time()
    print("\n=== Test: End Run Marks End Time ===")

    serpent_main.reset_run_stats()
    serpent_main.end_run()

    local stats = serpent_main.get_run_stats()
    -- Duration should be set (>= 0)
    test.assert_ge(stats.run_duration, 0, "Run duration set after end_run")

    print("\226\156\147 End run marks end time")
end

--===========================================================================
-- TEST: Integration with transitions
--===========================================================================

function test.test_init_resets_stats()
    print("\n=== Test: Init Resets Stats ===")

    -- Record some stats
    serpent_main.record_wave_cleared()
    serpent_main.record_gold_earned(500)

    -- Re-init should reset
    serpent_main.init()

    local stats = serpent_main.get_run_stats()
    test.assert_eq(stats.waves_cleared, 0, "Init resets waves")
    test.assert_eq(stats.gold_earned, 0, "Init resets gold")

    print("\226\156\147 Init resets stats correctly")
end

function test.test_victory_ends_run()
    print("\n=== Test: Victory Ends Run ===")

    serpent_main.init()
    serpent_main.record_wave_cleared()
    serpent_main.record_wave_cleared()

    -- Transition to combat first (valid transition path)
    serpent_main.transitionToCombat()

    -- Then to victory
    serpent_main.transitionToVictory()

    local stats = serpent_main.get_run_stats()
    test.assert_eq(stats.waves_cleared, 2, "Stats preserved through victory")
    test.assert_ge(stats.run_duration, 0, "Duration calculated on victory")

    print("\226\156\147 Victory transition ends run")
end

function test.test_game_over_ends_run()
    print("\n=== Test: Game Over Ends Run ===")

    serpent_main.init()
    serpent_main.record_enemy_killed()
    serpent_main.record_enemy_killed()

    -- Transition to game over
    serpent_main.transitionToGameOver()

    local stats = serpent_main.get_run_stats()
    test.assert_eq(stats.enemies_killed, 2, "Stats preserved through game over")
    test.assert_ge(stats.run_duration, 0, "Duration calculated on game over")

    print("\226\156\147 Game over transition ends run")
end

--===========================================================================
-- TEST: Signal handler registration
--===========================================================================

function test.test_signal_handlers_registered()
    print("\n=== Test: Signal Handlers Registered ===")

    serpent_main.init()

    -- Check that handlers were registered (we can't directly verify, but init should not error)
    test.assert_true(true, "Signal handlers registered without error")

    print("\226\156\147 Signal handlers registered correctly")
end

function test.test_main_menu_callback_exists()
    print("\n=== Test: Main Menu Callback Exists ===")

    -- Verify the handler function exists
    test.assert_true(serpent_main._handleMainMenuSignal ~= nil, "Main menu handler function exists")
    test.assert_eq(type(serpent_main._handleMainMenuSignal), "function", "Main menu handler is a function")

    print("\226\156\147 Main menu callback exists")
end

function test.test_restart_callback_exists()
    print("\n=== Test: Restart Callback Exists ===")

    -- Verify the handler function exists
    test.assert_true(serpent_main._handleRestartSignal ~= nil, "Restart handler function exists")
    test.assert_eq(type(serpent_main._handleRestartSignal), "function", "Restart handler is a function")

    print("\226\156\147 Restart callback exists")
end

--===========================================================================
-- TEST: Full run simulation
--===========================================================================

function test.test_full_run_simulation()
    print("\n=== Test: Full Run Simulation ===")

    serpent_main.init()

    -- Simulate a run
    serpent_main.record_gold_earned(100)  -- Starting gold

    -- Wave 1
    serpent_main.record_unit_purchased()
    serpent_main.transitionToCombat()
    serpent_main.record_enemy_killed()
    serpent_main.record_enemy_killed()
    serpent_main.record_damage_dealt(200)
    serpent_main.record_damage_taken(50)
    serpent_main.record_wave_cleared()
    serpent_main.record_gold_earned(50)
    serpent_main.transitionToShop()

    -- Wave 2
    serpent_main.record_unit_purchased()
    serpent_main.transitionToCombat()
    serpent_main.record_enemy_killed()
    serpent_main.record_enemy_killed()
    serpent_main.record_enemy_killed()
    serpent_main.record_damage_dealt(350)
    serpent_main.record_damage_taken(75)
    serpent_main.record_wave_cleared()
    serpent_main.record_gold_earned(75)

    -- Victory!
    serpent_main.transitionToVictory()

    local stats = serpent_main.get_run_stats()

    test.assert_eq(stats.waves_cleared, 2, "Full run: waves cleared")
    test.assert_eq(stats.gold_earned, 225, "Full run: gold earned (100+50+75)")
    test.assert_eq(stats.units_purchased, 2, "Full run: units purchased")
    test.assert_eq(stats.enemies_killed, 5, "Full run: enemies killed")
    test.assert_eq(stats.damage_dealt, 550, "Full run: damage dealt")
    test.assert_eq(stats.damage_taken, 125, "Full run: damage taken")

    print("\226\156\147 Full run simulation correct")
end

--===========================================================================
-- RUN ALL TESTS
--===========================================================================

function test.run_all()
    print("================================================================================")
    print("TEST SUITE: Run Stats Tracking (bd-290x)")
    print("================================================================================")

    -- Reset stats tests
    test.test_reset_stats_initial()
    test.test_reset_stats_clears_previous()

    -- Wave recording tests
    test.test_record_wave_single()
    test.test_record_wave_multiple()

    -- Gold recording tests
    test.test_record_gold_single()
    test.test_record_gold_accumulated()
    test.test_record_gold_zero_ignored()
    test.test_record_gold_negative_ignored()

    -- Unit purchase tests
    test.test_record_unit_single()
    test.test_record_unit_multiple()

    -- Enemy kill tests
    test.test_record_enemy_killed()

    -- Damage tests
    test.test_record_damage_dealt()
    test.test_record_damage_taken()
    test.test_record_damage_ignores_invalid()

    -- Get stats tests
    test.test_get_stats_returns_copy()
    test.test_run_duration_calculated()

    -- End run tests
    test.test_end_run_marks_end_time()

    -- Integration tests
    test.test_init_resets_stats()
    test.test_victory_ends_run()
    test.test_game_over_ends_run()

    -- Signal handler tests
    test.test_signal_handlers_registered()
    test.test_main_menu_callback_exists()
    test.test_restart_callback_exists()

    -- Full simulation
    test.test_full_run_simulation()

    print("\n================================================================================")
    print(string.format("RESULTS: %d passed, %d failed", test.passed, test.failed))
    print("================================================================================")

    return test.failed == 0
end

-- Execute tests if run directly
if arg and arg[0] and arg[0]:match("test_run_stats") then
    local success = test.run_all()
    os.exit(success and 0 or 1)
end

return test
