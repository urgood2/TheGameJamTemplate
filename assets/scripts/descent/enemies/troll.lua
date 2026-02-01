-- assets/scripts/descent/enemies/troll.lua
--[[
================================================================================
DESCENT ENEMY: TROLL
================================================================================
High HP regenerating enemy for Descent roguelike mode.

Trolls are massive brutes with regeneration found on late floors.
They are slow but extremely tough. Use simple melee AI.

Stats:
- HP: 30
- STR: 12, DEX: 5
- Evasion: 2
- Weapon Base: 8
- Speed: slow
- AI: melee
- Special: Regenerates 1 HP per turn

Usage:
    local troll = require("descent.enemies.troll")
    local enemy = troll.create(5, 5)  -- Spawn at position
================================================================================
]]

local M = {}

-- Dependencies
local enemy_module = require("descent.enemy")

-- Troll-specific configuration
local TROLL_CONFIG = {
    template_id = "troll",

    -- Floor spawn weights
    spawn_floors = { 4, 5 },
    spawn_weight = {
        [4] = 4,   -- Rare on floor 4
        [5] = 6,   -- Uncommon on floor 5
    },

    -- Group spawning
    pack_size_min = 1,
    pack_size_max = 1,  -- Trolls are solitary

    -- Behavior modifiers
    aggro_range = 5,
    flee_hp_threshold = 0,  -- Trolls never flee

    -- Special ability
    regen_per_turn = 1,

    -- Loot
    gold_min = 15,
    gold_max = 30,
    drop_chance = 0.30,  -- 30% chance to drop item
    drop_pool = {
        { id = "plate_armor", weight = 2 },
        { id = "battle_axe", weight = 3 },
        { id = "health_potion", weight = 6 },
        { id = "scroll_enchant_armor", weight = 4 },
    },
}

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Get troll template ID
--- @return string
function M.get_template_id()
    return TROLL_CONFIG.template_id
end

--- Create a troll enemy
--- @param x number Spawn X position
--- @param y number Spawn Y position
--- @param overrides table|nil Optional stat overrides
--- @return table Enemy entity
function M.create(x, y, overrides)
    return enemy_module.create(TROLL_CONFIG.template_id, x, y, overrides)
end

--- Check if troll can spawn on floor
--- @param floor number Floor number
--- @return boolean
function M.can_spawn_on_floor(floor)
    for _, f in ipairs(TROLL_CONFIG.spawn_floors) do
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
    return TROLL_CONFIG.spawn_weight[floor] or 0
end

--- Get pack size range
--- @return number, number Min and max pack size
function M.get_pack_size()
    return TROLL_CONFIG.pack_size_min, TROLL_CONFIG.pack_size_max
end

--- Get aggro range
--- @return number
function M.get_aggro_range()
    return TROLL_CONFIG.aggro_range
end

--- Get HP regeneration per turn
--- @return number
function M.get_regen_per_turn()
    return TROLL_CONFIG.regen_per_turn
end

--- Apply regeneration to a troll entity
--- @param enemy table Troll entity
--- @return number HP restored
function M.apply_regen(enemy)
    local regen = TROLL_CONFIG.regen_per_turn
    local hp_max = enemy.hp_max or 30
    local old_hp = enemy.hp or 0
    enemy.hp = math.min(hp_max, old_hp + regen)
    return enemy.hp - old_hp
end

--- Generate gold drop
--- @param rng table RNG module
--- @return number Gold amount
function M.generate_gold(rng)
    return rng.random_int(TROLL_CONFIG.gold_min, TROLL_CONFIG.gold_max)
end

--- Roll for item drop
--- @param rng table RNG module
--- @return string|nil Item template ID or nil
function M.roll_drop(rng)
    if rng.random() > TROLL_CONFIG.drop_chance then
        return nil  -- No drop
    end

    -- Weighted selection
    local total_weight = 0
    for _, entry in ipairs(TROLL_CONFIG.drop_pool) do
        total_weight = total_weight + entry.weight
    end

    local roll = rng.random_int(1, total_weight)
    local cumulative = 0
    for _, entry in ipairs(TROLL_CONFIG.drop_pool) do
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
    return TROLL_CONFIG
end

return M
