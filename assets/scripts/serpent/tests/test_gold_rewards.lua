--[[
================================================================================
TEST: Gold Rewards Formula Implementation
================================================================================
Verifies that gold_rewards.lua correctly implements the gold reward formula:
gold_reward(wave) = 10 + wave * 2

as specified in task bd-2lu.

Run with: lua assets/scripts/serpent/tests/test_gold_rewards.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")

-- Mock dependencies
_G.log_debug = function(msg) end
_G.log_warning = function(msg) end

t.describe("gold_rewards.lua - Formula Implementation", function()
    t.it("implements correct formula for standard waves", function()
        local gold_rewards = require("serpent.gold_rewards")

        -- Test the exact formula: 10 + wave * 2
        local test_cases = {
            {wave = 1, expected = 12},   -- 10 + 1*2 = 12
            {wave = 2, expected = 14},   -- 10 + 2*2 = 14
            {wave = 5, expected = 20},   -- 10 + 5*2 = 20
            {wave = 10, expected = 30},  -- 10 + 10*2 = 30
            {wave = 15, expected = 40},  -- 10 + 15*2 = 40
            {wave = 20, expected = 50}   -- 10 + 20*2 = 50
        }

        for _, test_case in ipairs(test_cases) do
            local actual = gold_rewards.calculate_gold_reward(test_case.wave)
            t.expect(actual).to_be(test_case.expected)
        end
    end)

    t.it("handles edge cases gracefully", function()
        local gold_rewards = require("serpent.gold_rewards")

        -- Test nil input (should default to wave 1)
        local result = gold_rewards.calculate_gold_reward(nil)
        t.expect(result).to_be(12)

        -- Test negative input (should clamp to wave 1)
        result = gold_rewards.calculate_gold_reward(-5)
        t.expect(result).to_be(12)

        -- Test zero input (should clamp to wave 1)
        result = gold_rewards.calculate_gold_reward(0)
        t.expect(result).to_be(12)

        -- Test non-number input (should default to wave 1)
        result = gold_rewards.calculate_gold_reward("invalid")
        t.expect(result).to_be(12)
    end)

    t.it("validates wave numbers correctly", function()
        local gold_rewards = require("serpent.gold_rewards")

        -- Test valid wave numbers
        local valid, msg = gold_rewards.validate_wave_number(1)
        t.expect(valid).to_be(true)

        valid, msg = gold_rewards.validate_wave_number(10)
        t.expect(valid).to_be(true)

        valid, msg = gold_rewards.validate_wave_number(20)
        t.expect(valid).to_be(true)

        -- Test invalid wave numbers
        valid, msg = gold_rewards.validate_wave_number(nil)
        t.expect(valid).to_be(false)

        valid, msg = gold_rewards.validate_wave_number(-1)
        t.expect(valid).to_be(false)

        valid, msg = gold_rewards.validate_wave_number(21)
        t.expect(valid).to_be(false)

        valid, msg = gold_rewards.validate_wave_number("string")
        t.expect(valid).to_be(false)
    end)

    t.it("calculates cumulative gold correctly", function()
        local gold_rewards = require("serpent.gold_rewards")

        -- Test cumulative for first 3 waves
        -- Wave 1: 12, Wave 2: 14, Wave 3: 16 -> Total: 42
        local expected = 12 + 14 + 16
        local actual = gold_rewards.calculate_cumulative_gold(3)
        t.expect(actual).to_be(expected)

        -- Test cumulative for wave 0 or negative
        actual = gold_rewards.calculate_cumulative_gold(0)
        t.expect(actual).to_be(0)

        actual = gold_rewards.calculate_cumulative_gold(-1)
        t.expect(actual).to_be(0)

        -- Test single wave
        actual = gold_rewards.calculate_cumulative_gold(1)
        t.expect(actual).to_be(12)
    end)

    t.it("provides correct milestone rewards", function()
        local gold_rewards = require("serpent.gold_rewards")

        local milestones = gold_rewards.get_milestone_rewards()

        t.expect(milestones.wave_1).to_be(12)
        t.expect(milestones.wave_5).to_be(20)
        t.expect(milestones.wave_10).to_be(30)
        t.expect(milestones.wave_15).to_be(40)
        t.expect(milestones.wave_20).to_be(50)
    end)

    t.it("generates correct gold breakdown", function()
        local gold_rewards = require("serpent.gold_rewards")

        local breakdown = gold_rewards.get_gold_breakdown(1, 3)

        t.expect(#breakdown).to_be(3)
        t.expect(breakdown[1].wave).to_be(1)
        t.expect(breakdown[1].gold_reward).to_be(12)
        t.expect(breakdown[2].wave).to_be(2)
        t.expect(breakdown[2].gold_reward).to_be(14)
        t.expect(breakdown[3].wave).to_be(3)
        t.expect(breakdown[3].gold_reward).to_be(16)
    end)

    t.it("calculates reward statistics correctly", function()
        local gold_rewards = require("serpent.gold_rewards")

        local stats = gold_rewards.get_reward_statistics()

        t.expect(stats.min_reward).to_be(12)  -- Wave 1: 10 + 1*2
        t.expect(stats.max_reward).to_be(50)  -- Wave 20: 10 + 20*2
        t.expect(stats.wave_count).to_be(20)

        -- Verify total gold calculation
        -- Sum of arithmetic sequence: n/2 * (first + last)
        -- Rewards: 12, 14, 16, ..., 50 (20 terms)
        -- Sum = 20/2 * (12 + 50) = 10 * 62 = 620
        t.expect(stats.total_gold_all_waves).to_be(620)
        t.expect(stats.average_reward).to_be(31) -- 620 / 20 = 31
    end)

    t.it("passes built-in tests", function()
        local gold_rewards = require("serpent.gold_rewards")

        local formula_test = gold_rewards.test_gold_reward_formula()
        t.expect(formula_test).to_be(true)

        local edge_case_test = gold_rewards.test_edge_cases()
        t.expect(edge_case_test).to_be(true)

        local cumulative_test = gold_rewards.test_cumulative_calculation()
        t.expect(cumulative_test).to_be(true)

        local all_tests = gold_rewards.run_all_tests()
        t.expect(all_tests).to_be(true)
    end)
end)

t.describe("gold_rewards.lua - Formula Consistency", function()
    t.it("matches the exact specification", function()
        local gold_rewards = require("serpent.gold_rewards")

        -- Test that the formula exactly matches: gold_reward(wave) = 10 + wave * 2
        for wave = 1, 20 do
            local expected = 10 + wave * 2
            local actual = gold_rewards.calculate_gold_reward(wave)
            t.expect(actual).to_be(expected)
        end
    end)

    t.it("has consistent linear progression", function()
        local gold_rewards = require("serpent.gold_rewards")

        -- Test that the difference between consecutive waves is always 2
        for wave = 1, 19 do
            local current = gold_rewards.calculate_gold_reward(wave)
            local next = gold_rewards.calculate_gold_reward(wave + 1)
            local difference = next - current
            t.expect(difference).to_be(2)
        end
    end)

    t.it("starts at the correct base value", function()
        local gold_rewards = require("serpent.gold_rewards")

        -- Base formula: 10 + wave * 2
        -- For wave 1: 10 + 1*2 = 12
        local wave_1_reward = gold_rewards.calculate_gold_reward(1)
        t.expect(wave_1_reward).to_be(12)

        -- For wave 0 (if allowed): 10 + 0*2 = 10, but we clamp to wave 1
        local wave_0_reward = gold_rewards.calculate_gold_reward(0)
        t.expect(wave_0_reward).to_be(12) -- Clamped to wave 1
    end)
end)

local success = t.run()
os.exit(success and 0 or 1)