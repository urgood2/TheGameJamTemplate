-- assets/scripts/serpent/data/units.lua
--[[
    Unit Definitions for Serpent Game

    Exactly 16 units, 4 per class (Warrior, Mage, Ranger, Support).
    Each unit has id, class, tier, cost, base_hp, base_attack, range, atk_spd, and special_id.

    Stats scale with level: base * 2^(level-1), capped at level 3.
]]

local units = {}

-- Unit definitions exactly matching PLAN.md specification
local unit_data = {
    -- Warrior class (4 units)
    {
        id = "soldier",
        class = "Warrior",
        tier = 1,
        cost = 3,
        base_hp = 100,
        base_attack = 15,
        range = 50,
        atk_spd = 1.0,
        special_id = nil
    },
    {
        id = "knight",
        class = "Warrior",
        tier = 2,
        cost = 6,
        base_hp = 150,
        base_attack = 20,
        range = 50,
        atk_spd = 0.9,
        special_id = "knight_block"
    },
    {
        id = "berserker",
        class = "Warrior",
        tier = 3,
        cost = 12,
        base_hp = 120,
        base_attack = 35,
        range = 60,
        atk_spd = 1.2,
        special_id = "berserker_frenzy"
    },
    {
        id = "champion",
        class = "Warrior",
        tier = 4,
        cost = 20,
        base_hp = 200,
        base_attack = 50,
        range = 80,
        atk_spd = 0.8,
        special_id = "champion_cleave"
    },

    -- Mage class (4 units)
    {
        id = "apprentice",
        class = "Mage",
        tier = 1,
        cost = 3,
        base_hp = 60,
        base_attack = 10,
        range = 200,
        atk_spd = 0.8,
        special_id = nil
    },
    {
        id = "pyromancer",
        class = "Mage",
        tier = 2,
        cost = 6,
        base_hp = 70,
        base_attack = 18,
        range = 180,
        atk_spd = 0.7,
        special_id = "pyromancer_burn"
    },
    {
        id = "archmage",
        class = "Mage",
        tier = 3,
        cost = 12,
        base_hp = 80,
        base_attack = 30,
        range = 250,
        atk_spd = 0.5,
        special_id = "archmage_multihit"
    },
    {
        id = "lich",
        class = "Mage",
        tier = 4,
        cost = 20,
        base_hp = 100,
        base_attack = 45,
        range = 300,
        atk_spd = 0.4,
        special_id = "lich_pierce"
    },

    -- Ranger class (4 units) - FOCUS OF THIS TASK
    {
        id = "scout",
        class = "Ranger",
        tier = 1,
        cost = 3,
        base_hp = 70,
        base_attack = 8,
        range = 300,
        atk_spd = 1.5,
        special_id = nil
    },
    {
        id = "sniper",
        class = "Ranger",
        tier = 2,
        cost = 6,
        base_hp = 60,
        base_attack = 25,
        range = 400,
        atk_spd = 0.6,
        special_id = "sniper_crit"
    },
    {
        id = "assassin",
        class = "Ranger",
        tier = 3,
        cost = 12,
        base_hp = 80,
        base_attack = 40,
        range = 70,
        atk_spd = 1.0,
        special_id = "assassin_backstab"
    },
    {
        id = "windrunner",
        class = "Ranger",
        tier = 4,
        cost = 20,
        base_hp = 100,
        base_attack = 35,
        range = 350,
        atk_spd = 1.1,
        special_id = "windrunner_multishot"
    },

    -- Support class (4 units)
    {
        id = "healer",
        class = "Support",
        tier = 1,
        cost = 3,
        base_hp = 80,
        base_attack = 5,
        range = 100,
        atk_spd = 0.5,
        special_id = "healer_adjacent_regen"
    },
    {
        id = "bard",
        class = "Support",
        tier = 2,
        cost = 6,
        base_hp = 90,
        base_attack = 8,
        range = 80,
        atk_spd = 0.8,
        special_id = "bard_adjacent_atkspd"
    },
    {
        id = "paladin",
        class = "Support",
        tier = 3,
        cost = 12,
        base_hp = 150,
        base_attack = 15,
        range = 60,
        atk_spd = 0.7,
        special_id = "paladin_divine_shield"
    },
    {
        id = "angel",
        class = "Support",
        tier = 4,
        cost = 20,
        base_hp = 120,
        base_attack = 20,
        range = 100,
        atk_spd = 0.6,
        special_id = "angel_resurrect"
    }
}

-- Create unit lookup table
local unit_lookup = {}
for _, unit in ipairs(unit_data) do
    unit_lookup[unit.id] = unit
end

--- Get unit definition by ID
--- @param unit_id string Unit identifier
--- @return table|nil Unit definition or nil if not found
function units.get_unit(unit_id)
    return unit_lookup[unit_id]
end

--- Get all unit definitions
--- @return table Array of all unit definitions
function units.get_all_units()
    return {table.unpack(unit_data)}
end

--- Get units by class
--- @param class_name string Class name ("Warrior", "Mage", "Ranger", "Support")
--- @return table Array of unit definitions for the specified class
function units.get_units_by_class(class_name)
    local class_units = {}
    for _, unit in ipairs(unit_data) do
        if unit.class == class_name then
            table.insert(class_units, unit)
        end
    end
    return class_units
end

--- Get units by tier
--- @param tier number Tier number (1-4)
--- @return table Array of unit definitions for the specified tier
function units.get_units_by_tier(tier)
    local tier_units = {}
    for _, unit in ipairs(unit_data) do
        if unit.tier == tier then
            table.insert(tier_units, unit)
        end
    end
    return tier_units
end

--- Get Ranger units specifically (focus of this task)
--- @return table Array of all Ranger unit definitions
function units.get_ranger_units()
    return units.get_units_by_class("Ranger")
end

--- Get unit count summary
--- @return table Summary of unit counts by class and tier
function units.get_unit_summary()
    local summary = {
        total = #unit_data,
        by_class = {
            Warrior = 0,
            Mage = 0,
            Ranger = 0,
            Support = 0
        },
        by_tier = {
            [1] = 0,
            [2] = 0,
            [3] = 0,
            [4] = 0
        }
    }

    for _, unit in ipairs(unit_data) do
        summary.by_class[unit.class] = summary.by_class[unit.class] + 1
        summary.by_tier[unit.tier] = summary.by_tier[unit.tier] + 1
    end

    return summary
end

-- Export unit lookup table for external access
units.unit_lookup = unit_lookup

return units