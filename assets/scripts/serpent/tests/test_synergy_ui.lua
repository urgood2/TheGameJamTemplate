-- assets/scripts/serpent/tests/test_synergy_ui.lua
--[[
    Test Suite: Synergy UI Module

    Verifies synergy view-model formatting:
    - get_view_model: class counts, active multipliers, threshold info
    - get_compact_summary: active count, total bonuses, strongest class
    - should_show_synergy_ui: visibility logic

    Run with: lua assets/scripts/serpent/tests/test_synergy_ui.lua
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

function test.assert_near(actual, expected, tolerance, message)
    if math.abs(actual - expected) <= tolerance then
        test.passed = test.passed + 1
        return true
    else
        test.failed = test.failed + 1
        print(string.format("\226\156\151 FAILED: %s\n  Expected: %s (\194\177%s)\n  Actual: %s",
            message or "assertion", tostring(expected), tostring(tolerance), tostring(actual)))
        return false
    end
end

-- Mock Text system before requiring synergy_ui
local MockText = {
    define = function()
        return {
            content = function(self, content) return self end,
            size = function(self, size) return self end,
            anchor = function(self, anchor) return self end,
            space = function(self, space) return self end,
            z = function(self, z) return self end,
            spawn = function(self)
                return {
                    at = function(self, x, y) return { stop = function() end } end
                }
            end
        }
    end
}
package.loaded["core.text"] = MockText

-- Mock globals
_G.globals = {
    screenWidth = function() return 800 end,
    screenHeight = function() return 600 end
}

local synergy_ui = require("serpent.ui.synergy_ui")

--===========================================================================
-- TEST: get_view_model - Class Counts
--===========================================================================

function test.test_view_model_nil_state()
    print("\n=== Test: View Model Nil State ===")

    local view_model = synergy_ui.get_view_model(nil)

    test.assert_true(view_model ~= nil, "Returns view model for nil state")
    test.assert_eq(next(view_model.class_counts), nil, "Empty class counts for nil state")
    test.assert_eq(next(view_model.active_multipliers), nil, "Empty multipliers for nil state")

    print("\226\156\147 Nil state handled correctly")
end

function test.test_view_model_class_counts()
    print("\n=== Test: View Model Class Counts ===")

    local synergy_state = {
        class_counts = {
            warrior = 3,
            ranger = 2,
            mage = 0,  -- Should be filtered out
            support = 1
        }
    }

    local view_model = synergy_ui.get_view_model(synergy_state)

    test.assert_eq(view_model.class_counts.warrior, 3, "Warrior count is 3")
    test.assert_eq(view_model.class_counts.ranger, 2, "Ranger count is 2")
    test.assert_eq(view_model.class_counts.mage, nil, "Mage with 0 count not included")
    test.assert_eq(view_model.class_counts.support, 1, "Support count is 1")

    print("\226\156\147 Class counts extracted correctly")
end

function test.test_view_model_class_counts_empty()
    print("\n=== Test: View Model Empty Class Counts ===")

    local synergy_state = {
        class_counts = {}
    }

    local view_model = synergy_ui.get_view_model(synergy_state)
    test.assert_eq(next(view_model.class_counts), nil, "Empty class counts stays empty")

    print("\226\156\147 Empty class counts handled correctly")
end

--===========================================================================
-- TEST: get_view_model - Active Multipliers
--===========================================================================

function test.test_view_model_attack_bonus()
    print("\n=== Test: View Model Attack Bonus ===")

    local synergy_state = {
        class_multipliers = {
            warrior = {
                atk_multiplier = 1.2  -- 20% bonus
            }
        }
    }

    local view_model = synergy_ui.get_view_model(synergy_state)

    test.assert_true(view_model.active_multipliers.warrior ~= nil, "Warrior multipliers present")
    test.assert_near(view_model.active_multipliers.warrior.attack_bonus, 20, 0.1,
        "Attack bonus is 20%")

    print("\226\156\147 Attack bonus calculated correctly")
end

function test.test_view_model_hp_bonus()
    print("\n=== Test: View Model HP Bonus ===")

    local synergy_state = {
        class_multipliers = {
            tank = {
                hp_multiplier = 1.4  -- 40% bonus
            }
        }
    }

    local view_model = synergy_ui.get_view_model(synergy_state)

    test.assert_true(view_model.active_multipliers.tank ~= nil, "Tank multipliers present")
    test.assert_near(view_model.active_multipliers.tank.hp_bonus, 40, 0.1,
        "HP bonus is 40%")

    print("\226\156\147 HP bonus calculated correctly")
end

function test.test_view_model_speed_bonus()
    print("\n=== Test: View Model Speed Bonus ===")

    local synergy_state = {
        class_multipliers = {
            ranger = {
                atk_spd_multiplier = 1.15  -- 15% bonus
            }
        }
    }

    local view_model = synergy_ui.get_view_model(synergy_state)

    test.assert_true(view_model.active_multipliers.ranger ~= nil, "Ranger multipliers present")
    test.assert_near(view_model.active_multipliers.ranger.speed_bonus, 15, 0.1,
        "Speed bonus is 15%")

    print("\226\156\147 Speed bonus calculated correctly")
end

function test.test_view_model_range_bonus()
    print("\n=== Test: View Model Range Bonus ===")

    local synergy_state = {
        class_multipliers = {
            archer = {
                range_multiplier = 1.25  -- 25% bonus
            }
        }
    }

    local view_model = synergy_ui.get_view_model(synergy_state)

    test.assert_true(view_model.active_multipliers.archer ~= nil, "Archer multipliers present")
    test.assert_near(view_model.active_multipliers.archer.range_bonus, 25, 0.1,
        "Range bonus is 25%")

    print("\226\156\147 Range bonus calculated correctly")
end

function test.test_view_model_multiple_bonuses()
    print("\n=== Test: View Model Multiple Bonuses ===")

    local synergy_state = {
        class_multipliers = {
            paladin = {
                atk_multiplier = 1.1,     -- 10% attack
                hp_multiplier = 1.3,       -- 30% HP
                atk_spd_multiplier = 1.05  -- 5% speed
            }
        }
    }

    local view_model = synergy_ui.get_view_model(synergy_state)
    local paladin = view_model.active_multipliers.paladin

    test.assert_true(paladin ~= nil, "Paladin multipliers present")
    test.assert_near(paladin.attack_bonus, 10, 0.1, "Attack bonus is 10%")
    test.assert_near(paladin.hp_bonus, 30, 0.1, "HP bonus is 30%")
    test.assert_near(paladin.speed_bonus, 5, 0.1, "Speed bonus is 5%")

    print("\226\156\147 Multiple bonuses calculated correctly")
end

function test.test_view_model_no_bonus_filtered()
    print("\n=== Test: View Model No Bonus Filtered ===")

    local synergy_state = {
        class_multipliers = {
            inactive = {
                atk_multiplier = 1.0,  -- No bonus (1.0 = 0%)
                hp_multiplier = 1.0
            }
        }
    }

    local view_model = synergy_ui.get_view_model(synergy_state)

    test.assert_eq(view_model.active_multipliers.inactive, nil,
        "Class with 1.0 multipliers not included")

    print("\226\156\147 No-bonus classes filtered out")
end

--===========================================================================
-- TEST: get_compact_summary
--===========================================================================

function test.test_compact_summary_nil()
    print("\n=== Test: Compact Summary Nil State ===")

    local summary = synergy_ui.get_compact_summary(nil)

    test.assert_eq(summary.active_count, 0, "Active count is 0 for nil")
    test.assert_eq(summary.total_bonuses, 0, "Total bonuses is 0 for nil")
    test.assert_eq(summary.strongest_class, nil, "No strongest class for nil")
    test.assert_eq(summary.strongest_bonus, 0, "Strongest bonus is 0 for nil")

    print("\226\156\147 Nil state summary correct")
end

function test.test_compact_summary_single_class()
    print("\n=== Test: Compact Summary Single Class ===")

    local synergy_state = {
        class_multipliers = {
            warrior = {
                atk_multiplier = 1.2,  -- 20%
                hp_multiplier = 1.3    -- 30%
            }
        }
    }

    local summary = synergy_ui.get_compact_summary(synergy_state)

    test.assert_eq(summary.active_count, 1, "Active count is 1")
    test.assert_near(summary.total_bonuses, 50, 0.1, "Total bonuses is 50 (20+30)")
    test.assert_eq(summary.strongest_class, "warrior", "Strongest class is warrior")
    test.assert_near(summary.strongest_bonus, 50, 0.1, "Strongest bonus is 50")

    print("\226\156\147 Single class summary correct")
end

function test.test_compact_summary_multiple_classes()
    print("\n=== Test: Compact Summary Multiple Classes ===")

    local synergy_state = {
        class_multipliers = {
            warrior = {
                atk_multiplier = 1.1,  -- 10%
                hp_multiplier = 1.2    -- 20%
            },
            ranger = {
                atk_spd_multiplier = 1.15  -- 15%
            },
            mage = {
                atk_multiplier = 1.5  -- 50% (strongest)
            }
        }
    }

    local summary = synergy_ui.get_compact_summary(synergy_state)

    test.assert_eq(summary.active_count, 3, "Active count is 3")
    -- Total: warrior(10+20) + ranger(15) + mage(50) = 95
    test.assert_near(summary.total_bonuses, 95, 0.1, "Total bonuses is 95")
    test.assert_eq(summary.strongest_class, "mage", "Strongest class is mage")
    test.assert_near(summary.strongest_bonus, 50, 0.1, "Strongest bonus is 50")

    print("\226\156\147 Multiple classes summary correct")
end

function test.test_compact_summary_inactive_filtered()
    print("\n=== Test: Compact Summary Inactive Filtered ===")

    local synergy_state = {
        class_multipliers = {
            active = {
                atk_multiplier = 1.1  -- 10%
            },
            inactive = {
                atk_multiplier = 1.0,  -- No bonus
                hp_multiplier = 1.0
            }
        }
    }

    local summary = synergy_ui.get_compact_summary(synergy_state)

    test.assert_eq(summary.active_count, 1, "Only active class counted")
    test.assert_eq(summary.strongest_class, "active", "Strongest is active class")

    print("\226\156\147 Inactive classes filtered from summary")
end

--===========================================================================
-- TEST: should_show_synergy_ui
--===========================================================================

function test.test_should_show_nil()
    print("\n=== Test: Should Show - Nil State ===")

    test.assert_false(synergy_ui.should_show_synergy_ui(nil),
        "Should not show for nil state")

    print("\226\156\147 Nil state visibility correct")
end

function test.test_should_show_no_counts()
    print("\n=== Test: Should Show - No Class Counts ===")

    local synergy_state = {}

    test.assert_false(synergy_ui.should_show_synergy_ui(synergy_state),
        "Should not show without class_counts")

    print("\226\156\147 No counts visibility correct")
end

function test.test_should_show_empty_counts()
    print("\n=== Test: Should Show - Empty Class Counts ===")

    local synergy_state = {
        class_counts = {}
    }

    test.assert_false(synergy_ui.should_show_synergy_ui(synergy_state),
        "Should not show with empty class counts")

    print("\226\156\147 Empty counts visibility correct")
end

function test.test_should_show_zero_counts()
    print("\n=== Test: Should Show - All Zero Counts ===")

    local synergy_state = {
        class_counts = {
            warrior = 0,
            ranger = 0,
            mage = 0
        }
    }

    test.assert_false(synergy_ui.should_show_synergy_ui(synergy_state),
        "Should not show with all zero counts")

    print("\226\156\147 Zero counts visibility correct")
end

function test.test_should_show_has_units()
    print("\n=== Test: Should Show - Has Units ===")

    local synergy_state = {
        class_counts = {
            warrior = 1
        }
    }

    test.assert_true(synergy_ui.should_show_synergy_ui(synergy_state),
        "Should show when has units")

    print("\226\156\147 Has units visibility correct")
end

function test.test_should_show_mixed_counts()
    print("\n=== Test: Should Show - Mixed Counts ===")

    local synergy_state = {
        class_counts = {
            warrior = 0,
            ranger = 0,
            mage = 2  -- One class has units
        }
    }

    test.assert_true(synergy_ui.should_show_synergy_ui(synergy_state),
        "Should show when any class has units")

    print("\226\156\147 Mixed counts visibility correct")
end

--===========================================================================
-- TEST: Built-in Tests
--===========================================================================

function test.test_builtin_view_model_generation()
    print("\n=== Test: Built-in View Model Generation ===")

    local result = synergy_ui.test_view_model_generation()
    test.assert_true(result, "Built-in view model test should pass")

    print("\226\156\147 Built-in view model test passed")
end

function test.test_builtin_run_all()
    print("\n=== Test: Built-in Run All Tests ===")

    local result = synergy_ui.run_all_tests()
    test.assert_true(result, "Built-in run_all_tests should pass")

    print("\226\156\147 Built-in run_all_tests passed")
end

--===========================================================================
-- RUN ALL TESTS
--===========================================================================

function test.run_all()
    print("================================================================================")
    print("TEST SUITE: Synergy UI Module (bd-s65a)")
    print("================================================================================")

    -- View model class counts tests
    test.test_view_model_nil_state()
    test.test_view_model_class_counts()
    test.test_view_model_class_counts_empty()

    -- View model multiplier tests
    test.test_view_model_attack_bonus()
    test.test_view_model_hp_bonus()
    test.test_view_model_speed_bonus()
    test.test_view_model_range_bonus()
    test.test_view_model_multiple_bonuses()
    test.test_view_model_no_bonus_filtered()

    -- Compact summary tests
    test.test_compact_summary_nil()
    test.test_compact_summary_single_class()
    test.test_compact_summary_multiple_classes()
    test.test_compact_summary_inactive_filtered()

    -- Visibility tests
    test.test_should_show_nil()
    test.test_should_show_no_counts()
    test.test_should_show_empty_counts()
    test.test_should_show_zero_counts()
    test.test_should_show_has_units()
    test.test_should_show_mixed_counts()

    -- Built-in tests
    test.test_builtin_view_model_generation()
    test.test_builtin_run_all()

    print("\n================================================================================")
    print(string.format("RESULTS: %d passed, %d failed", test.passed, test.failed))
    print("================================================================================")

    return test.failed == 0
end

-- Execute tests if run directly
if arg and arg[0] and arg[0]:match("test_synergy_ui") then
    local success = test.run_all()
    os.exit(success and 0 or 1)
end

return test
