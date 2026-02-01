-- assets/scripts/descent/enemies/mage.lua
--[[
================================================================================
DESCENT ENEMY: MAGE
================================================================================
Ranged caster enemy for Descent roguelike mode.

Mages are frail but dangerous spell-casters found on later floors.
They keep distance and attack with magic. Use ranged AI (flee if close).

Stats:
- HP: 6
- STR: 3, INT: 14, DEX: 10
- Evasion: 8
- Spell Base: 5
- Speed: normal
- AI: ranged

Usage:
    local mage = require("descent.enemies.mage")
    local enemy = mage.create(5, 5)  -- Spawn at position
================================================================================
]]

local M = {}

-- Dependencies
local enemy_module = require("descent.enemy")

-- Mage-specific configuration
local MAGE_CONFIG = {
    template_id = "mage",

    -- Floor spawn weights
    spawn_floors = { 3, 4, 5 },
    spawn_weight = {
        [3] = 3,   -- Rare on floor 3
        [4] = 6,   -- Uncommon on floor 4
        [5] = 8,   -- More common on floor 5
    },

    -- Group spawning
    pack_size_min = 1,
    pack_size_max = 1,  -- Mages are solitary

    -- Behavior modifiers
    aggro_range = 10,        -- Long range detection
    preferred_range = 4,     -- Tries to stay at this distance
    flee_hp_threshold = 0.5, -- Flees when below 50% HP

    -- Loot
    gold_min = 8,
    gold_max = 15,
    drop_chance = 0.25,  -- 25% chance to drop item
    drop_pool = {
        { id = "scroll_magic_mapping", weight = 4 },
        { id = "scroll_enchant_weapon", weight = 3 },
        { id = "mana_potion", weight = 6 },
        { id = "health_potion", weight = 5 },
    },
}

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Get mage template ID
--- @return string
function M.get_template_id()
    return MAGE_CONFIG.template_id
end

--- Create a mage enemy
--- @param x number Spawn X position
--- @param y number Spawn Y position
--- @param overrides table|nil Optional stat overrides
--- @return table Enemy entity
function M.create(x, y, overrides)
    return enemy_module.create(MAGE_CONFIG.template_id, x, y, overrides)
end

--- Check if mage can spawn on floor
--- @param floor number Floor number
--- @return boolean
function M.can_spawn_on_floor(floor)
    for _, f in ipairs(MAGE_CONFIG.spawn_floors) do
        if f == floor then
            return true
        end
    end
    return false
end

--- Get spawn weight for floor
--- @param floor number Floor number
--- @return number Weight (0 if can't spawn)
function M.get_spawn_weight(floor)
    return MAGE_CONFIG.spawn_weight[floor] or 0
end

--- Get pack size range
--- @return number, number Min and max pack size
function M.get_pack_size()
    return MAGE_CONFIG.pack_size_min, MAGE_CONFIG.pack_size_max
end

--- Get aggro range
--- @return number
function M.get_aggro_range()
    return MAGE_CONFIG.aggro_range
end

--- Get preferred combat range
--- @return number
function M.get_preferred_range()
    return MAGE_CONFIG.preferred_range
end

--- Get flee threshold (HP percentage)
--- @return number
function M.get_flee_threshold()
    return MAGE_CONFIG.flee_hp_threshold
end

--- Generate gold drop
--- @param rng table RNG module
--- @return number Gold amount
function M.generate_gold(rng)
    return rng.random_int(MAGE_CONFIG.gold_min, MAGE_CONFIG.gold_max)
end

--- Roll for item drop
--- @param rng table RNG module
--- @return string|nil Item template ID or nil
function M.roll_drop(rng)
    if rng.random() > MAGE_CONFIG.drop_chance then
        return nil  -- No drop
    end

    -- Weighted selection
    local total_weight = 0
    for _, entry in ipairs(MAGE_CONFIG.drop_pool) do
        total_weight = total_weight + entry.weight
    end

    local roll = rng.random_int(1, total_weight)
    local cumulative = 0
    for _, entry in ipairs(MAGE_CONFIG.drop_pool) do
        cumulative = cumulative + entry.weight
        if roll <= cumulative then
            return entry.id
        end
    end

    return nil
end

--- Get configuration
--- @return table Configuration
function M.get_config()
    return MAGE_CONFIG
end

return M
