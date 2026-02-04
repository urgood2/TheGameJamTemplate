-- assets/scripts/serpent/data/enemies.lua
--[[
    Enemy Definitions for Serpent Game

    Exactly 11 enemies with specified base stats, wave ranges, and boss flags.
    Enemy HP and damage are scaled by wave multipliers in combat.
]]

local enemies = {}

-- Enemy definitions exactly matching PLAN.md and test specifications
local enemy_data = {
    {
        id = "slime",
        base_hp = 20,
        base_damage = 5,
        speed = 80,
        min_wave = 1,
        max_wave = 5,
        boss = false
    },
    {
        id = "bat",
        base_hp = 15,
        base_damage = 8,
        speed = 200,
        min_wave = 1,
        max_wave = 10,
        boss = false
    },
    {
        id = "goblin",
        base_hp = 30,
        base_damage = 10,
        speed = 120,
        min_wave = 3,
        max_wave = 10,
        boss = false
    },
    {
        id = "orc",
        base_hp = 50,
        base_damage = 15,
        speed = 120,
        min_wave = 5,
        max_wave = 15,
        boss = false
    },
    {
        id = "skeleton",
        base_hp = 40,
        base_damage = 12,
        speed = 120,
        min_wave = 5,
        max_wave = 15,
        boss = false
    },
    {
        id = "wizard",
        base_hp = 35,
        base_damage = 20,
        speed = 100,
        min_wave = 8,
        max_wave = 20,
        boss = false
    },
    {
        id = "troll",
        base_hp = 100,
        base_damage = 25,
        speed = 80,
        min_wave = 10,
        max_wave = 20,
        boss = false
    },
    {
        id = "demon",
        base_hp = 80,
        base_damage = 30,
        speed = 140,
        min_wave = 12,
        max_wave = 20,
        boss = false
    },
    {
        id = "dragon",
        base_hp = 200,
        base_damage = 40,
        speed = 60,
        min_wave = 15,
        max_wave = 20,
        boss = false
    },
    {
        id = "swarm_queen",
        base_hp = 500,
        base_damage = 50,
        speed = 50,
        min_wave = 10,
        max_wave = 10,
        boss = true,
        tags = {"boss"}
    },
    {
        id = "lich_king",
        base_hp = 800,
        base_damage = 75,
        speed = 100,
        min_wave = 20,
        max_wave = 20,
        boss = true,
        tags = {"boss"}
    }
}

-- Create enemy lookup table
local enemy_lookup = {}
for _, enemy in ipairs(enemy_data) do
    enemy_lookup[enemy.id] = enemy
end

--- Get enemy definition by ID
--- @param enemy_id string Enemy identifier
--- @return table|nil Enemy definition or nil if not found
function enemies.get_enemy(enemy_id)
    return enemy_lookup[enemy_id]
end

--- Get all enemy definitions
--- @return table Array of all enemy definitions
function enemies.get_all_enemies()
    return {table.unpack(enemy_data)}
end

--- Get enemies valid for a specific wave
--- @param wave_num number Wave number (1-20)
--- @return table Array of enemy definitions valid for this wave
function enemies.get_enemies_for_wave(wave_num)
    local valid_enemies = {}

    for _, enemy in ipairs(enemy_data) do
        if wave_num >= enemy.min_wave and wave_num <= enemy.max_wave then
            table.insert(valid_enemies, enemy)
        end
    end

    return valid_enemies
end

--- Get non-boss enemies for a specific wave
--- @param wave_num number Wave number (1-20)
--- @return table Array of non-boss enemy definitions valid for this wave
function enemies.get_regular_enemies_for_wave(wave_num)
    local regular_enemies = {}

    for _, enemy in ipairs(enemy_data) do
        if not enemy.boss and wave_num >= enemy.min_wave and wave_num <= enemy.max_wave then
            table.insert(regular_enemies, enemy)
        end
    end

    return regular_enemies
end

--- Get boss enemies for a specific wave
--- @param wave_num number Wave number (1-20)
--- @return table Array of boss enemy definitions for this wave
function enemies.get_boss_enemies_for_wave(wave_num)
    local boss_enemies = {}

    for _, enemy in ipairs(enemy_data) do
        if enemy.boss and wave_num >= enemy.min_wave and wave_num <= enemy.max_wave then
            table.insert(boss_enemies, enemy)
        end
    end

    return boss_enemies
end

--- Get enemy count summary
--- @return table Summary of enemy counts and wave ranges
function enemies.get_enemy_summary()
    local summary = {
        total = #enemy_data,
        bosses = 0,
        regular = 0,
        wave_ranges = {}
    }

    for _, enemy in ipairs(enemy_data) do
        if enemy.boss then
            summary.bosses = summary.bosses + 1
        else
            summary.regular = summary.regular + 1
        end

        summary.wave_ranges[enemy.id] = {
            min = enemy.min_wave,
            max = enemy.max_wave,
            span = enemy.max_wave - enemy.min_wave + 1
        }
    end

    return summary
end

--- Validate enemy definition structure
--- @param enemy table Enemy definition to validate
--- @return boolean, string True if valid, or false with error message
function enemies.validate_enemy(enemy)
    if not enemy then
        return false, "Enemy definition is nil"
    end

    -- Required fields
    local required_fields = {"id", "base_hp", "base_damage", "speed", "min_wave", "max_wave", "boss"}
    for _, field in ipairs(required_fields) do
        if enemy[field] == nil then
            return false, "Missing required field: " .. field
        end
    end

    -- Type validation
    if type(enemy.id) ~= "string" then
        return false, "id must be a string"
    end

    if type(enemy.base_hp) ~= "number" or enemy.base_hp <= 0 then
        return false, "base_hp must be a positive number"
    end

    if type(enemy.base_damage) ~= "number" or enemy.base_damage <= 0 then
        return false, "base_damage must be a positive number"
    end

    if type(enemy.speed) ~= "number" or enemy.speed <= 0 then
        return false, "speed must be a positive number"
    end

    if type(enemy.min_wave) ~= "number" or enemy.min_wave < 1 or enemy.min_wave > 20 then
        return false, "min_wave must be between 1 and 20"
    end

    if type(enemy.max_wave) ~= "number" or enemy.max_wave < 1 or enemy.max_wave > 20 then
        return false, "max_wave must be between 1 and 20"
    end

    if enemy.min_wave > enemy.max_wave then
        return false, "min_wave cannot be greater than max_wave"
    end

    if type(enemy.boss) ~= "boolean" then
        return false, "boss must be a boolean"
    end

    return true
end

--- Test that all 11 enemies are correctly defined
--- @return boolean True if all enemies pass validation
function enemies.test_all_enemies_valid()
    if #enemy_data ~= 11 then
        return false
    end

    -- Validate each enemy
    for _, enemy in ipairs(enemy_data) do
        local valid, error_msg = enemies.validate_enemy(enemy)
        if not valid then
            log_error("Enemy validation failed for " .. tostring(enemy.id) .. ": " .. error_msg)
            return false
        end
    end

    -- Check boss enemies are at exact waves
    local swarm_queen = enemies.get_enemy("swarm_queen")
    if not swarm_queen or swarm_queen.min_wave ~= 10 or swarm_queen.max_wave ~= 10 then
        return false
    end

    local lich_king = enemies.get_enemy("lich_king")
    if not lich_king or lich_king.min_wave ~= 20 or lich_king.max_wave ~= 20 then
        return false
    end

    return true
end

-- Export enemy lookup table for external access
enemies.enemy_lookup = enemy_lookup

return enemies