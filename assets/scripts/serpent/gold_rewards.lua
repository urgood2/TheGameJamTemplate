-- assets/scripts/serpent/gold_rewards.lua
--[[
    Gold Rewards Module

    Implements the gold reward formula for wave completion in the Serpent minigame.
    Formula: gold_reward(wave) = 10 + wave * 2

    As specified in task bd-2lu.
]]

-- Mock log functions for environments that don't have them
local log_debug = log_debug or function(msg) end
local log_warning = log_warning or function(msg) end

local gold_rewards = {}

--- Calculate gold reward for completing a wave
--- Formula: gold_reward(wave) = 10 + wave * 2
--- @param wave number Wave number (1-20)
--- @return number Gold reward amount
function gold_rewards.calculate_gold_reward(wave)
    if not wave then
        log_warning("[GoldRewards] Wave number is nil, defaulting to wave 1")
        wave = 1
    end

    if type(wave) ~= "number" then
        log_warning("[GoldRewards] Wave number is not a number, defaulting to wave 1")
        wave = 1
    end

    if wave < 1 then
        log_warning("[GoldRewards] Wave number is less than 1, clamping to 1")
        wave = 1
    end

    -- Apply the formula: 10 + wave * 2
    return 10 + wave * 2
end

--- Calculate cumulative gold earned from waves 1 through target wave
--- @param target_wave number Final wave number
--- @return number Total gold earned from all waves up to target_wave
function gold_rewards.calculate_cumulative_gold(target_wave)
    if not target_wave or target_wave < 1 then
        return 0
    end

    local total_gold = 0
    for wave = 1, target_wave do
        total_gold = total_gold + gold_rewards.calculate_gold_reward(wave)
    end

    return total_gold
end

--- Get gold reward breakdown for multiple waves
--- @param start_wave number Starting wave number
--- @param end_wave number Ending wave number
--- @return table Array of {wave, gold_reward} pairs
function gold_rewards.get_gold_breakdown(start_wave, end_wave)
    start_wave = start_wave or 1
    end_wave = end_wave or 20

    local breakdown = {}
    for wave = start_wave, end_wave do
        table.insert(breakdown, {
            wave = wave,
            gold_reward = gold_rewards.calculate_gold_reward(wave)
        })
    end

    return breakdown
end

--- Validate that a wave number is in the expected range
--- @param wave number Wave number to validate
--- @return boolean, string True if valid, false with error message if invalid
function gold_rewards.validate_wave_number(wave)
    if not wave then
        return false, "Wave number is required"
    end

    if type(wave) ~= "number" then
        return false, "Wave number must be a number"
    end

    if wave < 1 then
        return false, "Wave number must be at least 1"
    end

    if wave > 20 then
        return false, "Wave number must not exceed 20"
    end

    return true, "Valid wave number"
end

--- Calculate expected gold at specific wave milestones
--- @return table Gold rewards at key wave numbers
function gold_rewards.get_milestone_rewards()
    return {
        wave_1 = gold_rewards.calculate_gold_reward(1),     -- 12
        wave_5 = gold_rewards.calculate_gold_reward(5),     -- 20
        wave_10 = gold_rewards.calculate_gold_reward(10),   -- 30
        wave_15 = gold_rewards.calculate_gold_reward(15),   -- 40
        wave_20 = gold_rewards.calculate_gold_reward(20)    -- 50
    }
end

--- Get statistics about gold rewards across all waves
--- @return table Statistics including min, max, total, average
function gold_rewards.get_reward_statistics()
    local min_gold = gold_rewards.calculate_gold_reward(1)
    local max_gold = gold_rewards.calculate_gold_reward(20)
    local total_gold = gold_rewards.calculate_cumulative_gold(20)
    local average_gold = total_gold / 20

    return {
        min_reward = min_gold,
        max_reward = max_gold,
        total_gold_all_waves = total_gold,
        average_reward = average_gold,
        wave_count = 20
    }
end

--- Test the gold reward formula implementation
--- @return boolean True if all tests pass
function gold_rewards.test_gold_reward_formula()
    local test_cases = {
        {wave = 1, expected = 12},   -- 10 + 1*2 = 12
        {wave = 5, expected = 20},   -- 10 + 5*2 = 20
        {wave = 10, expected = 30},  -- 10 + 10*2 = 30
        {wave = 15, expected = 40},  -- 10 + 15*2 = 40
        {wave = 20, expected = 50}   -- 10 + 20*2 = 50
    }

    for _, test_case in ipairs(test_cases) do
        local actual = gold_rewards.calculate_gold_reward(test_case.wave)
        if actual ~= test_case.expected then
            log_warning(string.format("[GoldRewards] Test failed: wave %d expected %d, got %d",
                        test_case.wave, test_case.expected, actual))
            return false
        end
    end

    log_debug("[GoldRewards] All formula tests passed")
    return true
end

--- Test edge cases and validation
--- @return boolean True if all edge case tests pass
function gold_rewards.test_edge_cases()
    -- Test nil input
    local result = gold_rewards.calculate_gold_reward(nil)
    if result ~= 12 then  -- Should default to wave 1
        log_warning("[GoldRewards] Nil input test failed")
        return false
    end

    -- Test negative input
    result = gold_rewards.calculate_gold_reward(-5)
    if result ~= 12 then  -- Should clamp to wave 1
        log_warning("[GoldRewards] Negative input test failed")
        return false
    end

    -- Test non-number input
    result = gold_rewards.calculate_gold_reward("invalid")
    if result ~= 12 then  -- Should default to wave 1
        log_warning("[GoldRewards] Non-number input test failed")
        return false
    end

    -- Test validation function
    local valid, msg = gold_rewards.validate_wave_number(10)
    if not valid then
        log_warning("[GoldRewards] Valid wave validation test failed")
        return false
    end

    valid, msg = gold_rewards.validate_wave_number(-1)
    if valid then
        log_warning("[GoldRewards] Invalid wave validation test failed")
        return false
    end

    log_debug("[GoldRewards] All edge case tests passed")
    return true
end

--- Test cumulative gold calculation
--- @return boolean True if cumulative calculation is correct
function gold_rewards.test_cumulative_calculation()
    -- Test cumulative for first 3 waves
    -- Wave 1: 12, Wave 2: 14, Wave 3: 16 -> Total: 42
    local expected = 12 + 14 + 16
    local actual = gold_rewards.calculate_cumulative_gold(3)

    if actual ~= expected then
        log_warning(string.format("[GoldRewards] Cumulative test failed: expected %d, got %d",
                    expected, actual))
        return false
    end

    log_debug("[GoldRewards] Cumulative calculation test passed")
    return true
end

--- Run all gold reward tests
--- @return boolean True if all tests pass
function gold_rewards.run_all_tests()
    local tests = {
        {"gold_reward_formula", gold_rewards.test_gold_reward_formula},
        {"edge_cases", gold_rewards.test_edge_cases},
        {"cumulative_calculation", gold_rewards.test_cumulative_calculation},
    }

    local passed = 0
    local total = #tests

    log_debug("[GoldRewards] Running " .. total .. " tests...")

    for _, test in ipairs(tests) do
        local test_name, test_func = test[1], test[2]
        local success = test_func()

        if success then
            log_debug("[GoldRewards] ✓ " .. test_name)
            passed = passed + 1
        else
            log_warning("[GoldRewards] ✗ " .. test_name)
        end
    end

    log_debug(string.format("[GoldRewards] Results: %d/%d tests passed", passed, total))
    return passed == total
end

return gold_rewards