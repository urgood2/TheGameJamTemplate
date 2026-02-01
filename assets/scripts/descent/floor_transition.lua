-- assets/scripts/descent/floor_transition.lua
--[[
================================================================================
DESCENT FLOOR TRANSITION MODULE
================================================================================
Handles floor transitions (stairs) for Descent roguelike mode.

Features:
- Stair transitions (up/down) advance floor once per turn
- Player state persists across floors
- Floor-local state resets on transition
- Floor 5 triggers boss hook
- Backtracking support per spec

Per PLAN.md D3:
- Stepping on stairs advances floor once per turn
- Player state persists (HP/MP/XP/inventory/equipment/god/spells)
- Floor-local state resets
- Floor 5 triggers boss hook

Usage:
    local transition = require("descent.floor_transition")
    local result = transition.use_stairs(game_state, "down")
================================================================================
]]

local Transition = {}

-- Dependencies
local spec = require("descent.spec")
local procgen = require("descent.procgen")
local fov = require("descent.fov")

-- Event callbacks
local callbacks = {
    on_floor_change = nil,
    on_boss_floor = nil,
}

-- Floor data cache (for backtracking)
local floor_cache = {}

--------------------------------------------------------------------------------
-- Player State Persistence
--------------------------------------------------------------------------------

-- Fields that persist across floors
local PERSISTENT_FIELDS = {
    "hp", "hp_max",
    "mp", "mp_max",
    "xp", "level",
    "str", "dex", "int",
    "armor", "evasion", "damage_bonus",
    "inventory", "equipment",
    "god", "piety",
    "spells",
    "species", "background",
    "kills", "name",
    "species_hp_mod", "species_mp_mod", "species_xp_mod",
    "species_bonus", "species_multiplier",
    "max_spells",
}

local function extract_persistent_state(player)
    local state = {}
    for _, field in ipairs(PERSISTENT_FIELDS) do
        state[field] = player[field]
    end
    return state
end

local function restore_persistent_state(player, state)
    for _, field in ipairs(PERSISTENT_FIELDS) do
        if state[field] ~= nil then
            player[field] = state[field]
        end
    end
end

--------------------------------------------------------------------------------
-- Floor Cache (Backtracking)
--------------------------------------------------------------------------------

local function save_floor_state(floor_num, map, enemies, items, explored)
    if not spec.backtracking.persist_floor_state then
        return
    end
    
    floor_cache[floor_num] = {
        map = map,
        enemies = enemies,
        items = items,
        explored = explored,
    }
end

local function load_floor_state(floor_num)
    return floor_cache[floor_num]
end

local function clear_floor_cache()
    floor_cache = {}
end

--------------------------------------------------------------------------------
-- Floor Transition Logic
--------------------------------------------------------------------------------

function Transition.can_use_stairs(game_state, direction)
    local player = game_state.player
    local map = game_state.map
    local floor_num = game_state.floor_num or 1
    
    -- Check player is on correct stairs
    local Map = require("descent.map")
    local tile = Map.get_tile(map, player.x, player.y)
    
    if direction == "down" then
        if tile ~= Map.TILE.STAIRS_DOWN then
            return false, "not_on_stairs_down"
        end
        if floor_num >= spec.floors.total then
            return false, "already_at_bottom"
        end
    else
        if tile ~= Map.TILE.STAIRS_UP then
            return false, "not_on_stairs_up"
        end
        if floor_num <= 1 then
            return false, "already_at_top"
        end
        if not spec.backtracking.allowed then
            return false, "backtracking_disabled"
        end
    end
    
    return true
end

function Transition.use_stairs(game_state, direction)
    local can, reason = Transition.can_use_stairs(game_state, direction)
    if not can then
        return {
            success = false,
            reason = reason,
            turns = 0,
        }
    end
    
    local player = game_state.player
    local current_floor = game_state.floor_num or 1
    local new_floor = direction == "down" and (current_floor + 1) or (current_floor - 1)
    
    -- Save current floor state for backtracking
    if spec.backtracking.allowed and spec.backtracking.persist_floor_state then
        local explored_state = nil
        if spec.backtracking.explored_persists and fov.save_explored then
            explored_state = fov.save_explored()
        end
        save_floor_state(current_floor, game_state.map, game_state.enemies, game_state.items, explored_state)
    end
    
    -- Save player persistent state
    local persistent = extract_persistent_state(player)
    
    -- Generate or load new floor
    local new_floor_data = nil
    local cached = load_floor_state(new_floor)
    
    if cached then
        -- Restore cached floor
        new_floor_data = {
            floor_num = new_floor,
            map = cached.map,
            placements = {},  -- Will be populated from cache
        }
        game_state.enemies = cached.enemies or {}
        game_state.items = cached.items or {}
        
        -- Restore explored state
        if cached.explored and fov.load_explored then
            fov.load_explored(cached.explored)
        end
    else
        -- Generate new floor
        local seed = game_state.seed and (game_state.seed + new_floor * 1000) or nil
        new_floor_data = procgen.generate(new_floor, seed)
        
        -- Reset floor-local state
        game_state.enemies = {}
        game_state.items = {}
        
        -- Clear explored state for new floor
        if fov.clear_explored then
            fov.clear_explored()
        end
    end
    
    -- Update game state
    game_state.map = new_floor_data.map
    game_state.floor_num = new_floor
    game_state.placements = new_floor_data.placements
    
    -- Position player at appropriate stairs
    local start_pos = nil
    if direction == "down" and new_floor_data.placements then
        -- Coming from above: place at stairs up
        start_pos = new_floor_data.placements.stairs_up or new_floor_data.placements.player_start
    else
        -- Coming from below: place at stairs down
        start_pos = new_floor_data.placements.stairs_down or new_floor_data.placements.player_start
    end
    
    if start_pos then
        player.x = start_pos.x
        player.y = start_pos.y
    end
    
    -- Restore player persistent state
    restore_persistent_state(player, persistent)
    player.alive = true  -- Ensure alive
    
    -- Update map occupancy
    local Map = require("descent.map")
    Map.place(game_state.map, "player", player.x, player.y, player.id)
    
    -- Trigger callbacks
    if callbacks.on_floor_change then
        callbacks.on_floor_change(new_floor, current_floor, direction)
    end
    
    -- Floor 5 boss hook
    if new_floor == spec.boss.floor and callbacks.on_boss_floor then
        callbacks.on_boss_floor(game_state)
    end
    
    return {
        success = true,
        from_floor = current_floor,
        to_floor = new_floor,
        direction = direction,
        from_cache = cached ~= nil,
        turns = spec.turn_cost.stairs,
    }
end

--------------------------------------------------------------------------------
-- Event Hooks
--------------------------------------------------------------------------------

function Transition.on_floor_change(callback)
    callbacks.on_floor_change = callback
end

function Transition.on_boss_floor(callback)
    callbacks.on_boss_floor = callback
end

--------------------------------------------------------------------------------
-- Utility
--------------------------------------------------------------------------------

function Transition.get_current_floor(game_state)
    return game_state.floor_num or 1
end

function Transition.is_boss_floor(floor_num)
    return floor_num == spec.boss.floor
end

function Transition.get_total_floors()
    return spec.floors.total
end

function Transition.can_go_up(floor_num)
    if floor_num <= 1 then
        return false
    end
    if not spec.backtracking.allowed then
        return false
    end
    
    local floors_with_stairs_up = spec.backtracking.stairs_up_on_floors or {}
    for _, f in ipairs(floors_with_stairs_up) do
        if f == floor_num then
            return true
        end
    end
    return false
end

function Transition.can_go_down(floor_num)
    if floor_num >= spec.floors.total then
        return false
    end
    
    local floors_with_stairs_down = spec.backtracking.stairs_down_on_floors or {}
    for _, f in ipairs(floors_with_stairs_down) do
        if f == floor_num then
            return true
        end
    end
    return false
end

function Transition.reset()
    clear_floor_cache()
    callbacks.on_floor_change = nil
    callbacks.on_boss_floor = nil
end

function Transition.get_cached_floor_count()
    local count = 0
    for _ in pairs(floor_cache) do
        count = count + 1
    end
    return count
end

return Transition
