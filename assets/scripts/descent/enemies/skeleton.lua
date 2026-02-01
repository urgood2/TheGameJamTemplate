-- assets/scripts/descent/enemies/skeleton.lua
--[[
================================================================================
DESCENT ENEMY: SKELETON
================================================================================
Undead melee enemy for Descent roguelike mode.

Skeletons are mid-tier undead enemies found on middle floors.
They are tougher but slower than goblins. Use simple melee AI.

Stats:
- HP: 12
- STR: 6, DEX: 8
- Evasion: 5
- Weapon Base: 4
- Speed: normal
- AI: melee

Usage:
    local skeleton = require("descent.enemies.skeleton")
    local enemy = skeleton.create(5, 5)  -- Spawn at position
================================================================================
]]

local M = {}

-- Dependencies
local enemy_module = require("descent.enemy")

-- Skeleton-specific configuration
local SKELETON_CONFIG = {
    template_id = "skeleton",

    -- Floor spawn weights
    spawn_floors = { 2, 3, 4 },
    spawn_weight = {
        [2] = 8,   -- Common on floor 2
        [3] = 10,  -- Most common on floor 3
        [4] = 5,   -- Less common on floor 4
    },

    -- Group spawning
    pack_size_min = 1,
    pack_size_max = 2,

    -- Behavior modifiers
    aggro_range = 8,
    flee_hp_threshold = 0,  -- Undead don't flee

    -- Loot
    gold_min = 5,
    gold_max = 12,
    drop_chance = 0.15,  -- 15% chance to drop item
    drop_pool = {
        { id = "short_sword", weight = 3 },
        { id = "health_potion", weight = 8 },
        { id = "scroll_identify", weight = 4 },
    },
}

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Get skeleton template ID
--- @return string
function M.get_template_id()
    return SKELETON_CONFIG.template_id
end

--- Create a skeleton enemy
--- @param x number Spawn X position
--- @param y number Spawn Y position
--- @param overrides table|nil Optional stat overrides
--- @return table Enemy entity
function M.create(x, y, overrides)
    return enemy_module.create(SKELETON_CONFIG.template_id, x, y, overrides)
end

--- Check if skeleton can spawn on floor
--- @param floor number Floor number
--- @return boolean
function M.can_spawn_on_floor(floor)
    for _, f in ipairs(SKELETON_CONFIG.spawn_floors) do
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
    return SKELETON_CONFIG.spawn_weight[floor] or 0
end

--- Get pack size range
--- @return number, number Min and max pack size
function M.get_pack_size()
    return SKELETON_CONFIG.pack_size_min, SKELETON_CONFIG.pack_size_max
end

--- Get aggro range
--- @return number
function M.get_aggro_range()
    return SKELETON_CONFIG.aggro_range
end

--- Generate gold drop
--- @param rng table RNG module
--- @return number Gold amount
function M.generate_gold(rng)
    return rng.random_int(SKELETON_CONFIG.gold_min, SKELETON_CONFIG.gold_max)
end

--- Roll for item drop
--- @param rng table RNG module
--- @return string|nil Item template ID or nil
function M.roll_drop(rng)
    if rng.random() > SKELETON_CONFIG.drop_chance then
        return nil  -- No drop
    end

    -- Weighted selection
    local total_weight = 0
    for _, entry in ipairs(SKELETON_CONFIG.drop_pool) do
        total_weight = total_weight + entry.weight
    end

    local roll = rng.random_int(1, total_weight)
    local cumulative = 0
    for _, entry in ipairs(SKELETON_CONFIG.drop_pool) do
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
    return SKELETON_CONFIG
end

return M
