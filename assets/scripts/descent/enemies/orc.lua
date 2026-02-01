-- assets/scripts/descent/enemies/orc.lua
--[[
================================================================================
DESCENT ENEMY: ORC
================================================================================
Tough melee enemy for Descent roguelike mode.

Orcs are powerful brutes found on later floors.
They are slow but hit hard. Use simple melee AI.

Stats:
- HP: 20
- STR: 10, DEX: 6
- Evasion: 3
- Weapon Base: 6
- Speed: slow
- AI: melee

Usage:
    local orc = require("descent.enemies.orc")
    local enemy = orc.create(5, 5)  -- Spawn at position
================================================================================
]]

local M = {}

-- Dependencies
local enemy_module = require("descent.enemy")

-- Orc-specific configuration
local ORC_CONFIG = {
    template_id = "orc",

    -- Floor spawn weights
    spawn_floors = { 3, 4, 5 },
    spawn_weight = {
        [3] = 5,   -- Rare on floor 3
        [4] = 10,  -- Common on floor 4
        [5] = 8,   -- Present on floor 5
    },

    -- Group spawning
    pack_size_min = 1,
    pack_size_max = 2,

    -- Behavior modifiers
    aggro_range = 6,
    flee_hp_threshold = 0,  -- Orcs don't flee

    -- Loot
    gold_min = 10,
    gold_max = 20,
    drop_chance = 0.20,  -- 20% chance to drop item
    drop_pool = {
        { id = "battle_axe", weight = 3 },
        { id = "leather_armor", weight = 4 },
        { id = "health_potion", weight = 8 },
    },
}

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Get orc template ID
--- @return string
function M.get_template_id()
    return ORC_CONFIG.template_id
end

--- Create an orc enemy
--- @param x number Spawn X position
--- @param y number Spawn Y position
--- @param overrides table|nil Optional stat overrides
--- @return table Enemy entity
function M.create(x, y, overrides)
    return enemy_module.create(ORC_CONFIG.template_id, x, y, overrides)
end

--- Check if orc can spawn on floor
--- @param floor number Floor number
--- @return boolean
function M.can_spawn_on_floor(floor)
    for _, f in ipairs(ORC_CONFIG.spawn_floors) do
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
    return ORC_CONFIG.spawn_weight[floor] or 0
end

--- Get pack size range
--- @return number, number Min and max pack size
function M.get_pack_size()
    return ORC_CONFIG.pack_size_min, ORC_CONFIG.pack_size_max
end

--- Get aggro range
--- @return number
function M.get_aggro_range()
    return ORC_CONFIG.aggro_range
end

--- Generate gold drop
--- @param rng table RNG module
--- @return number Gold amount
function M.generate_gold(rng)
    return rng.random_int(ORC_CONFIG.gold_min, ORC_CONFIG.gold_max)
end

--- Roll for item drop
--- @param rng table RNG module
--- @return string|nil Item template ID or nil
function M.roll_drop(rng)
    if rng.random() > ORC_CONFIG.drop_chance then
        return nil  -- No drop
    end

    -- Weighted selection
    local total_weight = 0
    for _, entry in ipairs(ORC_CONFIG.drop_pool) do
        total_weight = total_weight + entry.weight
    end

    local roll = rng.random_int(1, total_weight)
    local cumulative = 0
    for _, entry in ipairs(ORC_CONFIG.drop_pool) do
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
    return ORC_CONFIG
end

return M
