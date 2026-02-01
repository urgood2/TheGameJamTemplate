-- assets/scripts/descent/enemies/goblin.lua
--[[
================================================================================
DESCENT ENEMY: GOBLIN
================================================================================
Basic melee enemy for Descent roguelike mode.

Goblins are weak but fast enemies found on early floors.
They use simple melee AI (approach and attack).

Stats from spec/enemy module:
- HP: 8
- STR: 4, DEX: 12
- Evasion: 10
- Weapon Base: 3
- Speed: normal
- AI: melee

Usage:
    local goblin = require("descent.enemies.goblin")
    local enemy = goblin.create(5, 5)  -- Spawn at position
================================================================================
]]

local M = {}

-- Dependencies
local enemy_module = require("descent.enemy")

-- Goblin-specific configuration
local GOBLIN_CONFIG = {
    template_id = "goblin",
    
    -- Floor spawn weights
    spawn_floors = { 1, 2, 3 },
    spawn_weight = {
        [1] = 10,  -- Common on floor 1
        [2] = 5,   -- Less common on floor 2
        [3] = 2,   -- Rare on floor 3
    },
    
    -- Group spawning
    pack_size_min = 1,
    pack_size_max = 3,
    
    -- Behavior modifiers
    aggro_range = 6,
    flee_hp_threshold = 0,  -- Goblins don't flee
    
    -- Loot
    gold_min = 3,
    gold_max = 8,
    drop_chance = 0.1,  -- 10% chance to drop item
    drop_pool = {
        { id = "dagger", weight = 5 },
        { id = "health_potion", weight = 10 },
    },
}

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Get goblin template ID
--- @return string
function M.get_template_id()
    return GOBLIN_CONFIG.template_id
end

--- Create a goblin enemy
--- @param x number Spawn X position
--- @param y number Spawn Y position
--- @param overrides table|nil Optional stat overrides
--- @return table Enemy entity
function M.create(x, y, overrides)
    return enemy_module.create(GOBLIN_CONFIG.template_id, x, y, overrides)
end

--- Check if goblin can spawn on floor
--- @param floor number Floor number
--- @return boolean
function M.can_spawn_on_floor(floor)
    for _, f in ipairs(GOBLIN_CONFIG.spawn_floors) do
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
    return GOBLIN_CONFIG.spawn_weight[floor] or 0
end

--- Get pack size range
--- @return number, number Min and max pack size
function M.get_pack_size()
    return GOBLIN_CONFIG.pack_size_min, GOBLIN_CONFIG.pack_size_max
end

--- Get aggro range
--- @return number
function M.get_aggro_range()
    return GOBLIN_CONFIG.aggro_range
end

--- Generate gold drop
--- @param rng table RNG module
--- @return number Gold amount
function M.generate_gold(rng)
    return rng.random_int(GOBLIN_CONFIG.gold_min, GOBLIN_CONFIG.gold_max)
end

--- Roll for item drop
--- @param rng table RNG module
--- @return string|nil Item template ID or nil
function M.roll_drop(rng)
    if rng.random() > GOBLIN_CONFIG.drop_chance then
        return nil  -- No drop
    end
    
    -- Weighted selection
    local total_weight = 0
    for _, entry in ipairs(GOBLIN_CONFIG.drop_pool) do
        total_weight = total_weight + entry.weight
    end
    
    local roll = rng.random_int(1, total_weight)
    local cumulative = 0
    for _, entry in ipairs(GOBLIN_CONFIG.drop_pool) do
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
    return GOBLIN_CONFIG
end

return M
