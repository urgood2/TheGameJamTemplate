-- assets/scripts/serpent/tests/test_hud.lua
--[[
    Test Suite: HUD UI Module

    Verifies HUD display helpers and aggregation functions:
    - HP formatting (format_time, format_number)
    - Health aggregation from snake segments
    - Color helpers (get_health_color, get_wave_color)
    - View model generation

    Run with: lua assets/scripts/serpent/tests/test_hud.lua
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

-- Mock love.timer before requiring hud
_G.love = {
    timer = {
        getTime = function() return 0 end
    }
}

-- Mock snake_logic for is_dead function
package.loaded["serpent.snake_logic"] = {
    is_dead = function(snake_state)
        if not snake_state or not snake_state.segments then
            return true
        end
        local min_len = snake_state.min_len or 3
        return #snake_state.segments < min_len
    end
}

-- Mock synergy_system
package.loaded["serpent.synergy_system"] = {
    calculate = function(segments, unit_defs)
        return { class_counts = {}, bonuses = {} }
    end,
    get_synergy_summary = function(synergy_state)
        return { class_counts = {}, active_synergies = {} }
    end
}

local hud = require("serpent.ui.hud")

--===========================================================================
-- TEST: Time Formatting
--===========================================================================

function test.test_format_time_zero()
    print("\n=== Test: format_time Zero ===")

    test.assert_eq(hud.format_time(0), "00:00", "0 seconds = 00:00")

    print("\226\156\147 Zero time formatted correctly")
end

function test.test_format_time_seconds_only()
    print("\n=== Test: format_time Seconds Only ===")

    test.assert_eq(hud.format_time(5), "00:05", "5 seconds")
    test.assert_eq(hud.format_time(30), "00:30", "30 seconds")
    test.assert_eq(hud.format_time(59), "00:59", "59 seconds")

    print("\226\156\147 Seconds-only times formatted correctly")
end

function test.test_format_time_minutes_and_seconds()
    print("\n=== Test: format_time Minutes and Seconds ===")

    test.assert_eq(hud.format_time(60), "01:00", "1 minute")
    test.assert_eq(hud.format_time(90), "01:30", "1.5 minutes")
    test.assert_eq(hud.format_time(125), "02:05", "2 minutes 5 seconds")
    test.assert_eq(hud.format_time(3599), "59:59", "59 minutes 59 seconds")
    test.assert_eq(hud.format_time(3600), "60:00", "60 minutes (1 hour)")

    print("\226\156\147 Minutes and seconds formatted correctly")
end

function test.test_format_time_fractional()
    print("\n=== Test: format_time Fractional Seconds ===")

    -- Fractional seconds should be floored
    test.assert_eq(hud.format_time(30.5), "00:30", "30.5 seconds floors to 30")
    test.assert_eq(hud.format_time(59.9), "00:59", "59.9 seconds floors to 59")

    print("\226\156\147 Fractional seconds handled correctly")
end

--===========================================================================
-- TEST: Number Formatting
--===========================================================================

function test.test_format_number_small()
    print("\n=== Test: format_number Small Numbers ===")

    test.assert_eq(hud.format_number(0), "0", "0")
    test.assert_eq(hud.format_number(1), "1", "1")
    test.assert_eq(hud.format_number(99), "99", "99")
    test.assert_eq(hud.format_number(999), "999", "999 (no comma)")

    print("\226\156\147 Small numbers formatted correctly")
end

function test.test_format_number_with_commas()
    print("\n=== Test: format_number With Commas ===")

    test.assert_eq(hud.format_number(1000), "1,000", "1,000")
    test.assert_eq(hud.format_number(12345), "12,345", "12,345")
    test.assert_eq(hud.format_number(999999), "999,999", "999,999")
    test.assert_eq(hud.format_number(1000000), "1,000,000", "1,000,000")

    print("\226\156\147 Numbers with commas formatted correctly")
end

function test.test_format_number_fractional()
    print("\n=== Test: format_number Fractional ===")

    -- Fractional numbers should be floored
    test.assert_eq(hud.format_number(1234.56), "1,234", "1234.56 floors to 1234")
    test.assert_eq(hud.format_number(999.99), "999", "999.99 floors to 999")

    print("\226\156\147 Fractional numbers handled correctly")
end

--===========================================================================
-- TEST: Health Color Helper
--===========================================================================

function test.test_health_color_high()
    print("\n=== Test: Health Color High (>60%) ===")

    local color = hud.get_health_color(100)
    test.assert_eq(color.r, 0, "100% health is green (r=0)")
    test.assert_eq(color.g, 255, "100% health is green (g=255)")
    test.assert_eq(color.b, 0, "100% health is green (b=0)")

    color = hud.get_health_color(61)
    test.assert_eq(color.g, 255, "61% health is still green")

    print("\226\156\147 High health color is green")
end

function test.test_health_color_medium()
    print("\n=== Test: Health Color Medium (31-60%) ===")

    local color = hud.get_health_color(60)
    test.assert_eq(color.r, 255, "60% health is yellow (r=255)")
    test.assert_eq(color.g, 255, "60% health is yellow (g=255)")
    test.assert_eq(color.b, 0, "60% health is yellow (b=0)")

    color = hud.get_health_color(31)
    test.assert_eq(color.r, 255, "31% health is still yellow")
    test.assert_eq(color.g, 255, "31% health is still yellow")

    print("\226\156\147 Medium health color is yellow")
end

function test.test_health_color_low()
    print("\n=== Test: Health Color Low (<=30%) ===")

    local color = hud.get_health_color(30)
    test.assert_eq(color.r, 255, "30% health is red (r=255)")
    test.assert_eq(color.g, 0, "30% health is red (g=0)")
    test.assert_eq(color.b, 0, "30% health is red (b=0)")

    color = hud.get_health_color(1)
    test.assert_eq(color.g, 0, "1% health is red")

    color = hud.get_health_color(0)
    test.assert_eq(color.g, 0, "0% health is red")

    print("\226\156\147 Low health color is red")
end

--===========================================================================
-- TEST: Wave Color Helper
--===========================================================================

function test.test_wave_color_early()
    print("\n=== Test: Wave Color Early (<50%) ===")

    local color = hud.get_wave_color(1, 20)
    test.assert_eq(color.r, 100, "Wave 1/20 is blue (r=100)")
    test.assert_eq(color.g, 150, "Wave 1/20 is blue (g=150)")
    test.assert_eq(color.b, 255, "Wave 1/20 is blue (b=255)")

    color = hud.get_wave_color(9, 20)
    test.assert_eq(color.b, 255, "Wave 9/20 is still blue")

    print("\226\156\147 Early wave color is blue")
end

function test.test_wave_color_mid()
    print("\n=== Test: Wave Color Mid (50-79%) ===")

    local color = hud.get_wave_color(10, 20)
    test.assert_eq(color.r, 255, "Wave 10/20 is orange (r=255)")
    test.assert_eq(color.g, 200, "Wave 10/20 is orange (g=200)")
    test.assert_eq(color.b, 0, "Wave 10/20 is orange (b=0)")

    color = hud.get_wave_color(15, 20)
    test.assert_eq(color.g, 200, "Wave 15/20 is still orange")

    print("\226\156\147 Mid wave color is orange")
end

function test.test_wave_color_late()
    print("\n=== Test: Wave Color Late (>=80%) ===")

    local color = hud.get_wave_color(16, 20)
    test.assert_eq(color.r, 255, "Wave 16/20 is red (r=255)")
    test.assert_eq(color.g, 100, "Wave 16/20 is red (g=100)")
    test.assert_eq(color.b, 100, "Wave 16/20 is red (b=100)")

    color = hud.get_wave_color(20, 20)
    test.assert_eq(color.r, 255, "Wave 20/20 is red")

    print("\226\156\147 Late wave color is red")
end

--===========================================================================
-- TEST: HP Aggregation (_get_snake_info)
--===========================================================================

function test.test_snake_info_empty()
    print("\n=== Test: Snake Info Empty State ===")

    local info = hud._get_snake_info(nil)
    test.assert_eq(info.current_length, 0, "Nil state has 0 length")
    test.assert_eq(info.alive_segments, 0, "Nil state has 0 alive")
    test.assert_eq(info.health_percent, 100, "Nil state has 100% health (default)")

    info = hud._get_snake_info({})
    test.assert_eq(info.current_length, 0, "Empty state has 0 length")

    print("\226\156\147 Empty snake info handled correctly")
end

function test.test_snake_info_full_health()
    print("\n=== Test: Snake Info Full Health ===")

    local game_state = {
        snake_state = {
            segments = {
                { hp = 100, hp_max_base = 100 },
                { hp = 100, hp_max_base = 100 },
                { hp = 100, hp_max_base = 100 }
            },
            min_len = 3,
            max_len = 8
        }
    }

    local info = hud._get_snake_info(game_state)
    test.assert_eq(info.current_length, 3, "3 segments")
    test.assert_eq(info.alive_segments, 3, "3 alive")
    test.assert_eq(info.health_percent, 100, "100% health")
    test.assert_true(info.is_alive, "Snake is alive")

    print("\226\156\147 Full health aggregation correct")
end

function test.test_snake_info_partial_health()
    print("\n=== Test: Snake Info Partial Health ===")

    local game_state = {
        snake_state = {
            segments = {
                { hp = 80, hp_max_base = 100 },
                { hp = 50, hp_max_base = 100 },
                { hp = 30, hp_max_base = 100 }
            },
            min_len = 3,
            max_len = 8
        }
    }

    local info = hud._get_snake_info(game_state)
    test.assert_eq(info.current_length, 3, "3 segments")
    test.assert_eq(info.alive_segments, 3, "3 alive (all have hp > 0)")
    -- Total HP: 80+50+30 = 160, Max HP: 300, Percent: 53%
    test.assert_eq(info.health_percent, 53, "160/300 = 53% health")
    test.assert_true(info.is_alive, "Snake is alive (length >= min_len)")

    print("\226\156\147 Partial health aggregation correct")
end

function test.test_snake_info_dead_snake()
    print("\n=== Test: Snake Info Dead Snake ===")

    local game_state = {
        snake_state = {
            segments = {
                { hp = 50, hp_max_base = 100 }
            },
            min_len = 3,
            max_len = 8
        }
    }

    local info = hud._get_snake_info(game_state)
    test.assert_eq(info.current_length, 1, "1 segment")
    test.assert_eq(info.alive_segments, 1, "1 alive")
    test.assert_false(info.is_alive, "Snake is dead (length < min_len)")

    print("\226\156\147 Dead snake detection correct")
end

--===========================================================================
-- TEST: Player Info Aggregation
--===========================================================================

function test.test_player_info_nil()
    print("\n=== Test: Player Info Nil ===")

    local info = hud._get_player_info(nil)
    test.assert_eq(info.gold, 0, "Nil state has 0 gold")
    test.assert_eq(info.total_gold_earned, 0, "Nil state has 0 total gold")
    test.assert_eq(info.kills, 0, "Nil state has 0 kills")

    print("\226\156\147 Nil player info handled correctly")
end

function test.test_player_info_basic()
    print("\n=== Test: Player Info Basic ===")

    local player_state = {
        gold = 150,
        total_gold_earned = 500,
        time_played = 180,
        kills = 25,
        waves_completed = 4
    }

    local info = hud._get_player_info(player_state)
    test.assert_eq(info.gold, 150, "Gold is 150")
    test.assert_eq(info.total_gold_earned, 500, "Total gold is 500")
    test.assert_eq(info.time_played, 180, "Time is 180 seconds")
    test.assert_eq(info.kills, 25, "Kills is 25")
    test.assert_eq(info.waves_completed, 4, "Waves completed is 4")

    print("\226\156\147 Player info extraction correct")
end

--===========================================================================
-- TEST: View Model Generation
--===========================================================================

function test.test_combat_view_model_structure()
    print("\n=== Test: Combat View Model Structure ===")

    local game_state = {
        snake_state = {
            segments = {{ hp = 100, hp_max_base = 100 }},
            min_len = 1,
            max_len = 8
        }
    }
    local player_state = { gold = 100 }

    local view_model = hud.get_combat_view_model(game_state, player_state)

    test.assert_true(view_model.wave_info ~= nil, "Has wave_info")
    test.assert_true(view_model.snake_info ~= nil, "Has snake_info")
    test.assert_true(view_model.player_info ~= nil, "Has player_info")
    test.assert_true(view_model.combat_info ~= nil, "Has combat_info")
    test.assert_true(view_model.synergy_info ~= nil, "Has synergy_info")
    test.assert_true(view_model.performance ~= nil, "Has performance")

    print("\226\156\147 Combat view model has all sections")
end

function test.test_shop_view_model_structure()
    print("\n=== Test: Shop View Model Structure ===")

    local player_state = { gold = 50 }
    local snake_state = {
        segments = {{ hp = 100, hp_max_base = 100 }},
        min_len = 1,
        max_len = 8
    }

    local view_model = hud.get_shop_view_model(player_state, snake_state)

    test.assert_true(view_model.player_info ~= nil, "Has player_info")
    test.assert_true(view_model.snake_info ~= nil, "Has snake_info")
    test.assert_eq(view_model.mode, "SHOP", "Mode is SHOP")

    print("\226\156\147 Shop view model has correct structure")
end

--===========================================================================
-- TEST: Visibility State
--===========================================================================

function test.test_visibility_toggle()
    print("\n=== Test: HUD Visibility Toggle ===")

    hud.init()
    test.assert_false(hud.isVisible, "Initially not visible")
    test.assert_false(hud.is_visible(), "is_visible() returns false")

    hud.show()
    test.assert_true(hud.isVisible, "Visible after show()")
    test.assert_true(hud.is_visible(), "is_visible() returns true")

    hud.hide()
    test.assert_false(hud.isVisible, "Hidden after hide()")

    hud.toggle()
    test.assert_true(hud.isVisible, "Visible after toggle()")

    hud.toggle()
    test.assert_false(hud.isVisible, "Hidden after second toggle()")

    print("\226\156\147 Visibility state management correct")
end

--===========================================================================
-- RUN ALL TESTS
--===========================================================================

function test.run_all()
    print("================================================================================")
    print("TEST SUITE: HUD UI Module (bd-1wlp)")
    print("================================================================================")

    -- Time formatting tests
    test.test_format_time_zero()
    test.test_format_time_seconds_only()
    test.test_format_time_minutes_and_seconds()
    test.test_format_time_fractional()

    -- Number formatting tests
    test.test_format_number_small()
    test.test_format_number_with_commas()
    test.test_format_number_fractional()

    -- Health color tests
    test.test_health_color_high()
    test.test_health_color_medium()
    test.test_health_color_low()

    -- Wave color tests
    test.test_wave_color_early()
    test.test_wave_color_mid()
    test.test_wave_color_late()

    -- HP aggregation tests
    test.test_snake_info_empty()
    test.test_snake_info_full_health()
    test.test_snake_info_partial_health()
    test.test_snake_info_dead_snake()

    -- Player info tests
    test.test_player_info_nil()
    test.test_player_info_basic()

    -- View model tests
    test.test_combat_view_model_structure()
    test.test_shop_view_model_structure()

    -- Visibility tests
    test.test_visibility_toggle()

    print("\n================================================================================")
    print(string.format("RESULTS: %d passed, %d failed", test.passed, test.failed))
    print("================================================================================")

    return test.failed == 0
end

-- Execute tests if run directly
if arg and arg[0] and arg[0]:match("test_hud") then
    local success = test.run_all()
    os.exit(success and 0 or 1)
end

return test
