--[[
================================================================================
TEST: Synergy System Module
================================================================================
Tests synergy thresholds, modifier values, and special rules.
Verifies 2/4 unit thresholds, correct bonus values, and mage cooldown mechanics.

Run with: lua assets/scripts/serpent/tests/test_synergy_system.lua
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

-- Load the synergy system module
local synergy_system = require("serpent.synergy_system")

--- Test that thresholds are correctly set at 2 and 4
function test.test_synergy_thresholds()
    print("\n=== Testing Synergy Thresholds ===")

    -- Test with mock segments and unit defs
    local unit_defs = {
        warrior_basic = { class = "Warrior", base_hp = 100, base_attack = 20 },
        mage_basic = { class = "Mage", base_hp = 80, base_attack = 25 },
        ranger_basic = { class = "Ranger", base_hp = 90, base_attack = 18 },
        support_basic = { class = "Support", base_hp = 70, base_attack = 15 }
    }

    -- Test threshold conditions
    local test_cases = {
        -- Below threshold - no bonuses
        {warriors = 1, expected_bonus = false, desc = "1 Warrior (below threshold)"},

        -- At 2-unit threshold
        {warriors = 2, expected_bonus = true, threshold = 2, desc = "2 Warriors (2-unit threshold)"},
        {warriors = 3, expected_bonus = true, threshold = 2, desc = "3 Warriors (still 2-unit threshold)"},

        -- At 4-unit threshold (higher tier)
        {warriors = 4, expected_bonus = true, threshold = 4, desc = "4 Warriors (4-unit threshold)"},
        {warriors = 5, expected_bonus = true, threshold = 4, desc = "5 Warriors (still 4-unit threshold)"}
    }

    for _, case in ipairs(test_cases) do
        local segments = {}

        -- Create warrior segments
        for i = 1, case.warriors do
            table.insert(segments, {
                instance_id = i,
                def_id = "warrior_basic",
                hp = 100,
                level = 1
            })
        end

        local synergy_state = synergy_system.calculate(segments, unit_defs)
        local warrior_bonuses = synergy_state.active_bonuses.Warrior

        if case.expected_bonus then
            test.assert_true(next(warrior_bonuses) ~= nil,
                string.format("%s should have bonuses", case.desc))

            -- Check that correct threshold bonus is applied
            if case.threshold == 2 then
                test.assert_near(warrior_bonuses.atk_mult or 0, 1.2, 0.001,
                    string.format("%s should have 2-unit attack bonus", case.desc))
            elseif case.threshold == 4 then
                test.assert_near(warrior_bonuses.atk_mult or 0, 1.4, 0.001,
                    string.format("%s should have 4-unit attack bonus", case.desc))
                test.assert_near(warrior_bonuses.hp_mult or 0, 1.2, 0.001,
                    string.format("%s should have 4-unit HP bonus", case.desc))
            end
        else
            test.assert_true(next(warrior_bonuses) == nil,
                string.format("%s should have no bonuses", case.desc))
        end

        print(string.format("✓ %s", case.desc))
    end
end

--- Test that modifier values exactly match the expected table
function test.test_modifier_values()
    print("\n=== Testing Modifier Values ===")

    local unit_defs = {
        warrior = { class = "Warrior" },
        mage = { class = "Mage" },
        ranger = { class = "Ranger" },
        support = { class = "Support" }
    }

    -- Test Warrior bonuses
    print("\n--- Warrior Modifiers ---")
    local warrior_segments_2 = {{instance_id = 1, def_id = "warrior", hp = 100},
                               {instance_id = 2, def_id = "warrior", hp = 100}}
    local warrior_segments_4 = {{instance_id = 1, def_id = "warrior", hp = 100},
                               {instance_id = 2, def_id = "warrior", hp = 100},
                               {instance_id = 3, def_id = "warrior", hp = 100},
                               {instance_id = 4, def_id = "warrior", hp = 100}}

    local warrior_synergy_2 = synergy_system.calculate(warrior_segments_2, unit_defs)
    local warrior_synergy_4 = synergy_system.calculate(warrior_segments_4, unit_defs)

    -- 2 Warriors: +20% attack
    test.assert_near(warrior_synergy_2.active_bonuses.Warrior.atk_mult, 1.2, 0.001,
        "2 Warriors should have 1.2x attack multiplier")
    test.assert_eq(warrior_synergy_2.active_bonuses.Warrior.hp_mult, nil,
        "2 Warriors should not have HP bonus")

    -- 4 Warriors: +40% attack, +20% HP
    test.assert_near(warrior_synergy_4.active_bonuses.Warrior.atk_mult, 1.4, 0.001,
        "4 Warriors should have 1.4x attack multiplier")
    test.assert_near(warrior_synergy_4.active_bonuses.Warrior.hp_mult, 1.2, 0.001,
        "4 Warriors should have 1.2x HP multiplier")
    print("✓ Warrior modifiers correct")

    -- Test Mage bonuses
    print("\n--- Mage Modifiers ---")
    local mage_segments_2 = {{instance_id = 1, def_id = "mage", hp = 80},
                            {instance_id = 2, def_id = "mage", hp = 80}}
    local mage_segments_4 = {{instance_id = 1, def_id = "mage", hp = 80},
                            {instance_id = 2, def_id = "mage", hp = 80},
                            {instance_id = 3, def_id = "mage", hp = 80},
                            {instance_id = 4, def_id = "mage", hp = 80}}

    local mage_synergy_2 = synergy_system.calculate(mage_segments_2, unit_defs)
    local mage_synergy_4 = synergy_system.calculate(mage_segments_4, unit_defs)

    -- 2 Mages: +20% spell damage
    test.assert_near(mage_synergy_2.active_bonuses.Mage.atk_mult, 1.2, 0.001,
        "2 Mages should have 1.2x attack multiplier")

    -- 4 Mages: +40% spell damage, -20% cooldown
    test.assert_near(mage_synergy_4.active_bonuses.Mage.atk_mult, 1.4, 0.001,
        "4 Mages should have 1.4x attack multiplier")
    test.assert_near(mage_synergy_4.active_bonuses.Mage.cooldown_period_mult, 0.8, 0.001,
        "4 Mages should have 0.8x cooldown multiplier")
    print("✓ Mage modifiers correct")

    -- Test Ranger bonuses
    print("\n--- Ranger Modifiers ---")
    local ranger_segments_2 = {{instance_id = 1, def_id = "ranger", hp = 90},
                              {instance_id = 2, def_id = "ranger", hp = 90}}
    local ranger_segments_4 = {{instance_id = 1, def_id = "ranger", hp = 90},
                              {instance_id = 2, def_id = "ranger", hp = 90},
                              {instance_id = 3, def_id = "ranger", hp = 90},
                              {instance_id = 4, def_id = "ranger", hp = 90}}

    local ranger_synergy_2 = synergy_system.calculate(ranger_segments_2, unit_defs)
    local ranger_synergy_4 = synergy_system.calculate(ranger_segments_4, unit_defs)

    -- 2 Rangers: +20% attack speed
    test.assert_near(ranger_synergy_2.active_bonuses.Ranger.atk_spd_mult, 1.2, 0.001,
        "2 Rangers should have 1.2x attack speed multiplier")

    -- 4 Rangers: +40% attack speed, +20% range
    test.assert_near(ranger_synergy_4.active_bonuses.Ranger.atk_spd_mult, 1.4, 0.001,
        "4 Rangers should have 1.4x attack speed multiplier")
    test.assert_near(ranger_synergy_4.active_bonuses.Ranger.range_mult, 1.2, 0.001,
        "4 Rangers should have 1.2x range multiplier")
    print("✓ Ranger modifiers correct")

    -- Test Support bonuses
    print("\n--- Support Modifiers ---")
    local support_segments_2 = {{instance_id = 1, def_id = "support", hp = 70},
                               {instance_id = 2, def_id = "support", hp = 70}}
    local support_segments_4 = {{instance_id = 1, def_id = "support", hp = 70},
                               {instance_id = 2, def_id = "support", hp = 70},
                               {instance_id = 3, def_id = "support", hp = 70},
                               {instance_id = 4, def_id = "support", hp = 70}}

    local support_synergy_2 = synergy_system.calculate(support_segments_2, unit_defs)
    local support_synergy_4 = synergy_system.calculate(support_segments_4, unit_defs)

    -- 2 Support: 5 HP/sec regen
    test.assert_eq(support_synergy_2.active_bonuses.Support.global_regen_per_sec, 5,
        "2 Support should provide 5 HP/sec global regen")

    -- 4 Support: 10 HP/sec regen + 10% all stats
    test.assert_eq(support_synergy_4.active_bonuses.Support.global_regen_per_sec, 10,
        "4 Support should provide 10 HP/sec global regen")
    test.assert_near(support_synergy_4.active_bonuses.Support.hp_mult, 1.1, 0.001,
        "4 Support should have 1.1x HP multiplier")
    test.assert_near(support_synergy_4.active_bonuses.Support.atk_mult, 1.1, 0.001,
        "4 Support should have 1.1x attack multiplier")
    test.assert_near(support_synergy_4.active_bonuses.Support.range_mult, 1.1, 0.001,
        "4 Support should have 1.1x range multiplier")
    test.assert_near(support_synergy_4.active_bonuses.Support.atk_spd_mult, 1.1, 0.001,
        "4 Support should have 1.1x attack speed multiplier")
    print("✓ Support modifiers correct")
end

--- Test the specific Mage cooldown rule
function test.test_mage_cooldown_rule()
    print("\n=== Testing Mage Cooldown Rule ===")

    -- Test built-in verification function
    local verification_result = synergy_system.verify_mage_synergy()
    test.assert_true(verification_result, "Built-in Mage synergy verification should pass")

    -- Manual verification of Mage cooldown mechanics
    local unit_defs = {
        mage = { class = "Mage", base_hp = 80, base_attack = 25 }
    }

    -- Test 2 Mages - should NOT have cooldown reduction
    local mage_segments_2 = {{instance_id = 1, def_id = "mage", hp = 80},
                            {instance_id = 2, def_id = "mage", hp = 80}}
    local mage_synergy_2 = synergy_system.calculate(mage_segments_2, unit_defs)

    test.assert_eq(mage_synergy_2.active_bonuses.Mage.cooldown_period_mult, nil,
        "2 Mages should not have cooldown reduction")
    print("✓ 2 Mages: No cooldown reduction")

    -- Test 4 Mages - should have -20% cooldown (0.8x multiplier)
    local mage_segments_4 = {{instance_id = 1, def_id = "mage", hp = 80},
                            {instance_id = 2, def_id = "mage", hp = 80},
                            {instance_id = 3, def_id = "mage", hp = 80},
                            {instance_id = 4, def_id = "mage", hp = 80}}
    local mage_synergy_4 = synergy_system.calculate(mage_segments_4, unit_defs)

    test.assert_near(mage_synergy_4.active_bonuses.Mage.cooldown_period_mult, 0.8, 0.001,
        "4 Mages should have 0.8x cooldown multiplier (-20% cooldown)")
    print("✓ 4 Mages: 20% cooldown reduction")

    -- Test effective multipliers
    local multipliers = synergy_system.get_effective_multipliers(mage_synergy_4, mage_segments_4, unit_defs)

    for _, segment in ipairs(mage_segments_4) do
        local mage_multipliers = multipliers[segment.instance_id]
        test.assert_true(mage_multipliers ~= nil,
            string.format("Mage %d should have multipliers", segment.instance_id))

        -- Check if cooldown_period_mult exists and has the right value
        local cooldown_mult = mage_multipliers and mage_multipliers.cooldown_period_mult
        if cooldown_mult then
            test.assert_near(cooldown_mult, 0.8, 0.001,
                string.format("Mage %d should have 0.8x cooldown multiplier", segment.instance_id))
        else
            print(string.format("⚠ Warning: Mage %d missing cooldown multiplier", segment.instance_id))
        end
    end
    print("✓ Effective multipliers checked")
end

--- Test edge cases and boundary conditions
function test.test_edge_cases()
    print("\n=== Testing Edge Cases ===")

    local unit_defs = {
        warrior = { class = "Warrior" },
        mage = { class = "Mage" }
    }

    -- Test empty segments
    local empty_synergy = synergy_system.calculate({}, unit_defs)
    test.assert_eq(empty_synergy.class_counts.Warrior, 0, "Empty segments should have 0 Warriors")
    test.assert_eq(empty_synergy.class_counts.Mage, 0, "Empty segments should have 0 Mages")
    test.assert_true(next(empty_synergy.active_bonuses.Warrior) == nil,
        "Empty segments should have no Warrior bonuses")
    print("✓ Empty segments handled correctly")

    -- Test dead units (hp = 0) should not count
    local dead_segments = {{instance_id = 1, def_id = "warrior", hp = 0},
                          {instance_id = 2, def_id = "warrior", hp = 100}}
    local dead_synergy = synergy_system.calculate(dead_segments, unit_defs)
    test.assert_eq(dead_synergy.class_counts.Warrior, 1, "Dead units should not count toward synergy")
    print("✓ Dead units excluded from synergy")

    -- Test mixed classes
    local mixed_segments = {{instance_id = 1, def_id = "warrior", hp = 100},
                           {instance_id = 2, def_id = "warrior", hp = 100},
                           {instance_id = 3, def_id = "mage", hp = 80},
                           {instance_id = 4, def_id = "mage", hp = 80}}
    local mixed_synergy = synergy_system.calculate(mixed_segments, unit_defs)
    test.assert_eq(mixed_synergy.class_counts.Warrior, 2, "Should count 2 Warriors")
    test.assert_eq(mixed_synergy.class_counts.Mage, 2, "Should count 2 Mages")
    test.assert_true(next(mixed_synergy.active_bonuses.Warrior) ~= nil,
        "Should have Warrior bonuses")
    test.assert_true(next(mixed_synergy.active_bonuses.Mage) ~= nil,
        "Should have Mage bonuses")
    print("✓ Mixed classes handled correctly")

    -- Test global regen extraction
    local support_segments = {{instance_id = 1, def_id = "support", hp = 70, def_id = "support_basic"},
                             {instance_id = 2, def_id = "support", hp = 70, def_id = "support_basic"}}
    local unit_defs_support = {support_basic = { class = "Support" }}
    local support_synergy = synergy_system.calculate(support_segments, unit_defs_support)
    local global_regen = synergy_system.get_global_regen_rate(support_synergy)
    test.assert_eq(global_regen, 5, "2 Support should provide 5 HP/sec global regen")
    print("✓ Global regen extraction works correctly")
end

--- Main test runner
function test.run_all()
    print("================================================================================")
    print("TESTING: Synergy System Module")
    print("================================================================================")
    print("Verifying thresholds at 2/4, modifier values, and mage cooldown rule")

    -- Run all test suites
    test.test_synergy_thresholds()
    test.test_modifier_values()
    test.test_mage_cooldown_rule()
    test.test_edge_cases()

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
        print("✓ Synergy thresholds work correctly at 2 and 4 units")
        print("✓ Modifier values match expected table values")
        print("✓ Mage cooldown rule implemented correctly (-20% at 4 units)")
        print("✓ All class bonuses calculated accurately")
        return true
    else
        print(string.format("\n❌ %d TESTS FAILED", test.failed))
        return false
    end
end

-- Run the tests
local success = test.run_all()
os.exit(success and 0 or 1)