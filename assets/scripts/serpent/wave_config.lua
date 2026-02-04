-- assets/scripts/serpent/wave_config.lua
--[[
    Wave Configuration Module

    Provides wave scaling formulas and enemy pool selection for the Serpent game.
    Implements the core wave progression mechanics.
]]

local wave_config = {}

--- Calculate number of enemies for a wave
--- Formula: Enemies_per_Wave = 5 + Wave * 2
--- @param wave number Wave number (1-20)
--- @return number Number of enemies to spawn
function wave_config.enemy_count(wave)
    if not wave or wave < 1 then
        wave = 1
    end
    return 5 + wave * 2
end

--- Calculate HP multiplier for enemies in a wave
--- Formula: Enemy_HP_Multiplier = 1 + Wave * 0.1
--- @param wave number Wave number (1-20)
--- @return number HP multiplier
function wave_config.hp_mult(wave)
    if not wave or wave < 1 then
        wave = 1
    end
    return 1 + wave * 0.1
end

--- Calculate damage multiplier for enemies in a wave
--- Formula: Enemy_Damage_Multiplier = 1 + Wave * 0.05
--- @param wave number Wave number (1-20)
--- @return number Damage multiplier
function wave_config.dmg_mult(wave)
    if not wave or wave < 1 then
        wave = 1
    end
    return 1 + wave * 0.05
end

--- Calculate gold reward for completing a wave
--- Formula: Gold_per_Wave = 10 + Wave * 2
--- @param wave number Wave number (1-20)
--- @return number Gold reward amount
function wave_config.gold_reward(wave)
    if not wave or wave < 1 then
        wave = 1
    end
    return 10 + wave * 2
end

--- Get pool of valid enemy definitions for a wave
--- Excludes boss enemies (they are injected by wave director)
--- @param wave_num number Current wave number
--- @param enemy_defs table All enemy definitions
--- @return table Array of enemy definition IDs valid for this wave
function wave_config.get_pool(wave_num, enemy_defs)
    local pool = {}

    if not wave_num or not enemy_defs then
        return pool
    end

    -- Iterate through all enemy definitions
    for enemy_id, enemy_def in pairs(enemy_defs) do
        if enemy_def and enemy_def.min_wave and enemy_def.max_wave then
            -- Check if enemy is valid for this wave
            local valid_wave = wave_num >= enemy_def.min_wave and wave_num <= enemy_def.max_wave

            -- Check if enemy is not a boss
            local is_boss = false
            if enemy_def.tags then
                for _, tag in ipairs(enemy_def.tags) do
                    if tag == "boss" then
                        is_boss = true
                        break
                    end
                end
            elseif enemy_def.boss then
                is_boss = enemy_def.boss
            end

            -- Include non-boss enemies that are valid for this wave
            if valid_wave and not is_boss then
                table.insert(pool, enemy_id)
            end
        end
    end

    -- Sort pool for deterministic ordering
    table.sort(pool)

    return pool
end

--- Get wave scaling summary for debugging/testing
--- @param wave number Wave number
--- @return table Summary of wave scaling values
function wave_config.get_wave_summary(wave)
    return {
        wave = wave,
        enemy_count = wave_config.enemy_count(wave),
        hp_mult = wave_config.hp_mult(wave),
        dmg_mult = wave_config.dmg_mult(wave),
        gold_reward = wave_config.gold_reward(wave)
    }
end

--- Validate wave number is in valid range
--- @param wave number Wave number to validate
--- @return boolean, string True if valid, or false with error message
function wave_config.validate_wave(wave)
    if not wave then
        return false, "Wave number is required"
    end

    if type(wave) ~= "number" then
        return false, "Wave number must be a number"
    end

    if wave < 1 or wave > 20 then
        return false, "Wave number must be between 1 and 20"
    end

    return true
end

--- Test the enemy_count formula specifically (focus of bd-1yt task)
--- @return boolean True if enemy_count formula is implemented correctly
function wave_config.test_enemy_count_formula()
    -- Test expected values according to the formula: 5 + wave * 2
    local test_cases = {
        {wave = 1, expected = 7},   -- 5 + 1*2 = 7
        {wave = 5, expected = 15},  -- 5 + 5*2 = 15
        {wave = 10, expected = 25}, -- 5 + 10*2 = 25
        {wave = 15, expected = 35}, -- 5 + 15*2 = 35
        {wave = 20, expected = 45}  -- 5 + 20*2 = 45
    }

    for _, test_case in ipairs(test_cases) do
        local actual = wave_config.enemy_count(test_case.wave)
        if actual ~= test_case.expected then
            log_error(string.format("Enemy count formula failed: wave %d expected %d, got %d",
                      test_case.wave, test_case.expected, actual))
            return false
        end
    end

    return true
end

--- Get the core wave scaling constants
--- @return table Constants used in wave scaling formulas
function wave_config.get_constants()
    return {
        enemy_count = {
            base = 5,
            per_wave = 2
        },
        hp_mult = {
            base = 1,
            per_wave = 0.1
        },
        dmg_mult = {
            base = 1,
            per_wave = 0.05
        },
        gold_reward = {
            base = 10,
            per_wave = 2
        }
    }
end

return wave_config