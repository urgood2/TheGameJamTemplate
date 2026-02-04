--[[
================================================================================
TEST: Shop Odds Module
================================================================================
Tests tier probability tables and wave bracket logic for the shop system.
Verifies that probabilities sum to 1.0 and wave brackets return correct odds.

Run with: lua assets/scripts/serpent/tests/test_shop_odds.lua
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

-- Load the shop odds module
local shop_odds = require("serpent.data.shop_odds")

--- Test that all tier probability tables sum to 1.0
function test.test_probability_sums()
    print("\n=== Testing Probability Sums ===")

    -- Test each defined wave bracket
    local brackets = {
        {wave = 1, name = "Waves 1-5"},
        {wave = 6, name = "Waves 6-10"},
        {wave = 11, name = "Waves 11-15"},
        {wave = 16, name = "Waves 16-20"}
    }

    for _, bracket in ipairs(brackets) do
        local odds = shop_odds.get_tier_odds(bracket.wave)
        local sum = 0.0

        for tier = 1, 4 do
            sum = sum + odds[tier]
        end

        test.assert_near(sum, 1.0, 0.001,
            string.format("%s probabilities sum to 1.0", bracket.name))

        print(string.format("✓ %s: %.3f (T1:%.2f T2:%.2f T3:%.2f T4:%.2f)",
                           bracket.name, sum, odds[1], odds[2], odds[3], odds[4]))
    end
end

--- Test that wave brackets return expected odds tables
function test.test_wave_bracket_mapping()
    print("\n=== Testing Wave Bracket Mapping ===")

    -- Test wave bracket boundaries
    local test_cases = {
        -- Early game (waves 1-5)
        {wave = 1, expected_t1 = 0.70, bracket = "1-5"},
        {wave = 3, expected_t1 = 0.70, bracket = "1-5"},
        {wave = 5, expected_t1 = 0.70, bracket = "1-5"},

        -- Mid-early (waves 6-10)
        {wave = 6, expected_t1 = 0.55, bracket = "6-10"},
        {wave = 8, expected_t1 = 0.55, bracket = "6-10"},
        {wave = 10, expected_t1 = 0.55, bracket = "6-10"},

        -- Mid-game (waves 11-15)
        {wave = 11, expected_t1 = 0.35, bracket = "11-15"},
        {wave = 13, expected_t1 = 0.35, bracket = "11-15"},
        {wave = 15, expected_t1 = 0.35, bracket = "11-15"},

        -- End game (waves 16-20)
        {wave = 16, expected_t1 = 0.20, bracket = "16-20"},
        {wave = 18, expected_t1 = 0.20, bracket = "16-20"},
        {wave = 20, expected_t1 = 0.20, bracket = "16-20"},
        {wave = 25, expected_t1 = 0.20, bracket = "16-20"} -- Beyond 20
    }

    for _, case in ipairs(test_cases) do
        local odds = shop_odds.get_tier_odds(case.wave)
        local bracket = shop_odds.get_wave_bracket(case.wave)

        test.assert_eq(bracket, case.bracket,
            string.format("Wave %d maps to bracket %s", case.wave, case.bracket))

        test.assert_near(odds[1], case.expected_t1, 0.001,
            string.format("Wave %d T1 probability is %.2f", case.wave, case.expected_t1))

        print(string.format("✓ Wave %d → %s (T1: %.2f)", case.wave, bracket, odds[1]))
    end
end

--- Test tier selection logic with known RNG values
function test.test_tier_selection()
    print("\n=== Testing Tier Selection Logic ===")

    -- Test with wave 1 odds: T1:70%, T2:25%, T3:5%, T4:0%
    local test_cases = {
        {rng = 0.00, expected = 1, desc = "RNG 0.0 → T1"},
        {rng = 0.35, expected = 1, desc = "RNG 0.35 → T1"},
        {rng = 0.69, expected = 1, desc = "RNG 0.69 → T1"},
        {rng = 0.70, expected = 2, desc = "RNG 0.70 → T2"},
        {rng = 0.85, expected = 2, desc = "RNG 0.85 → T2"},
        {rng = 0.94, expected = 2, desc = "RNG 0.94 → T2"},
        {rng = 0.95, expected = 3, desc = "RNG 0.95 → T3"},
        {rng = 0.99, expected = 3, desc = "RNG 0.99 → T3"},
    }

    for _, case in ipairs(test_cases) do
        local selected_tier = shop_odds.select_tier(1, case.rng)
        test.assert_eq(selected_tier, case.expected, case.desc)
        print(string.format("✓ %s", case.desc))
    end

    -- Test with wave 16 odds: T1:20%, T2:30%, T3:33%, T4:17%
    print("\n--- Testing End Game Tier Selection (Wave 16) ---")
    local endgame_cases = {
        {rng = 0.10, expected = 1, desc = "RNG 0.10 → T1"},
        {rng = 0.25, expected = 2, desc = "RNG 0.25 → T2"},
        {rng = 0.60, expected = 3, desc = "RNG 0.60 → T3"},
        {rng = 0.90, expected = 4, desc = "RNG 0.90 → T4"},
        {rng = 0.99, expected = 4, desc = "RNG 0.99 → T4"}
    }

    for _, case in ipairs(endgame_cases) do
        local selected_tier = shop_odds.select_tier(16, case.rng)
        test.assert_eq(selected_tier, case.expected, case.desc)
        print(string.format("✓ %s", case.desc))
    end
end

--- Test tier distribution over many samples
function test.test_tier_distribution()
    print("\n=== Testing Tier Distribution (Statistical) ===")

    -- Sample 10000 tier selections for wave 1
    local samples = 10000
    local wave = 1
    local counts = {0, 0, 0, 0}

    -- Use deterministic "random" sequence for reproducible test
    for i = 1, samples do
        local rng_roll = (i * 0.31415926) % 1.0  -- Pseudo-random sequence
        local tier = shop_odds.select_tier(wave, rng_roll)
        counts[tier] = counts[tier] + 1
    end

    -- Calculate actual percentages
    local expected_odds = shop_odds.get_tier_odds(wave)
    local tolerance = 0.02  -- 2% tolerance for statistical variance

    for tier = 1, 4 do
        local actual_percentage = counts[tier] / samples
        local expected_percentage = expected_odds[tier]

        test.assert_near(actual_percentage, expected_percentage, tolerance,
            string.format("T%d distribution (~%.1f%%) matches expected (%.1f%%)",
                         tier, actual_percentage * 100, expected_percentage * 100))

        print(string.format("✓ T%d: %.1f%% (expected %.1f%%, diff %.1f%%)",
                           tier, actual_percentage * 100, expected_percentage * 100,
                           math.abs(actual_percentage - expected_percentage) * 100))
    end
end

--- Test edge cases and error handling
function test.test_edge_cases()
    print("\n=== Testing Edge Cases ===")

    -- Test extreme wave numbers
    local edge_cases = {
        {wave = -1, desc = "Negative wave number"},
        {wave = 0, desc = "Zero wave number"},
        {wave = 1000, desc = "Very large wave number"}
    }

    for _, case in ipairs(edge_cases) do
        local bracket = shop_odds.get_wave_bracket(case.wave)
        local odds = shop_odds.get_tier_odds(case.wave)

        -- Should not crash, should return valid data
        test.assert_true(type(bracket) == "string",
            string.format("%s returns valid bracket string", case.desc))

        test.assert_true(type(odds) == "table" and #odds >= 4,
            string.format("%s returns valid odds table", case.desc))

        print(string.format("✓ %s → %s", case.desc, bracket))
    end

    -- Test extreme RNG values for tier selection
    local rng_edge_cases = {
        {rng = 0.0, desc = "RNG exactly 0.0"},
        {rng = 1.0, desc = "RNG exactly 1.0"},
        {rng = -0.1, desc = "Negative RNG"},
        {rng = 1.5, desc = "RNG > 1.0"}
    }

    for _, case in ipairs(rng_edge_cases) do
        local tier = shop_odds.select_tier(1, case.rng)
        test.assert_true(tier >= 1 and tier <= 4,
            string.format("%s returns valid tier (1-4)", case.desc))

        print(string.format("✓ %s → T%d", case.desc, tier))
    end
end

--- Main test runner
function test.run_all()
    print("================================================================================")
    print("TESTING: Shop Odds Module")
    print("================================================================================")
    print("Verifying tier probabilities, wave brackets, and selection logic")

    -- Run all test suites
    test.test_probability_sums()
    test.test_wave_bracket_mapping()
    test.test_tier_selection()
    test.test_tier_distribution()
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
        print("✓ All tier probabilities sum to 1.0")
        print("✓ Wave brackets map to correct odds")
        print("✓ Tier selection logic works correctly")
        print("✓ Statistical distribution matches expected values")
        return true
    else
        print(string.format("\n❌ %d TESTS FAILED", test.failed))
        return false
    end
end

-- Run the tests
local success = test.run_all()
os.exit(success and 0 or 1)