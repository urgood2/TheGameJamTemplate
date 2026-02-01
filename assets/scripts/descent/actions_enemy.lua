-- assets/scripts/descent/actions_enemy.lua
--[[
================================================================================
DESCENT ENEMY ACTIONS
================================================================================
Executes enemy turn decisions and handles movement/attack resolution.

Key invariants (per bead):
- No moves into occupied tiles
- No overlaps after enemy phase
- Iteration order stable (via enemy.get_all spawn order)
- Pathfinding nil handled (enemy idles)

Usage:
    local actions_enemy = require("descent.actions_enemy")
    actions_enemy.init(player, enemy_module, combat_module, map_module)
    
    -- Process single enemy:
    local action = actions_enemy.decide_action(enemy)
    
    -- Process all enemies (deterministic order):
    local results = actions_enemy.process_all_enemies()
================================================================================
]]

local M = {}

-- Dependencies (set via init)
local player = nil
local enemy_module = nil
local combat_module = nil
local map_module = nil

-- Results
M.RESULT = {
    SUCCESS = "success",
    BLOCKED = "blocked",
    NO_TARGET = "no_target",
    IDLE = "idle",
}

-- Occupied tiles cache (rebuilt each turn)
local occupied_tiles = {}

--------------------------------------------------------------------------------
-- Internal Helpers
--------------------------------------------------------------------------------

--- Create a coordinate key
--- @param x number X coordinate
--- @param y number Y coordinate
--- @return string Key
local function coord_key(x, y)
    return x .. "," .. y
end

--- Rebuild occupied tiles cache
local function rebuild_occupied_cache()
    occupied_tiles = {}
    
    -- Mark player position
    if player and player.x and player.y then
        occupied_tiles[coord_key(player.x, player.y)] = { type = "player", entity = player }
    end
    
    -- Mark all enemy positions
    if enemy_module and enemy_module.get_all then
        for _, enemy in ipairs(enemy_module.get_all()) do
            if enemy.alive then
                occupied_tiles[coord_key(enemy.x, enemy.y)] = { type = "enemy", entity = enemy }
            end
        end
    end
end

--- Check if a tile is occupied
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param exclude_entity table|nil Entity to exclude from check
--- @return boolean, table|nil Occupied flag and occupant info
local function is_occupied(x, y, exclude_entity)
    local key = coord_key(x, y)
    local occupant = occupied_tiles[key]
    
    if occupant then
        if exclude_entity and occupant.entity == exclude_entity then
            return false, nil
        end
        return true, occupant
    end
    
    return false, nil
end

--- Check if a tile is walkable (not a wall)
--- @param x number X coordinate
--- @param y number Y coordinate
--- @return boolean Walkable status
local function is_walkable(x, y)
    if not map_module then
        return true  -- No map, assume walkable
    end
    
    if map_module.is_walkable then
        return map_module.is_walkable(x, y)
    end
    
    if map_module.get_tile then
        local tile = map_module.get_tile(x, y)
        return tile and tile.walkable
    end
    
    return true
end

--- Update occupied cache after a move
--- @param old_x number Old X position
--- @param old_y number Old Y position
--- @param new_x number New X position
--- @param new_y number New Y position
--- @param entity table Entity that moved
local function update_occupied_cache(old_x, old_y, new_x, new_y, entity)
    local old_key = coord_key(old_x, old_y)
    local new_key = coord_key(new_x, new_y)
    
    -- Remove from old position
    if occupied_tiles[old_key] and occupied_tiles[old_key].entity == entity then
        occupied_tiles[old_key] = nil
    end
    
    -- Add to new position
    occupied_tiles[new_key] = { type = "enemy", entity = entity }
end

--------------------------------------------------------------------------------
-- Action Execution
--------------------------------------------------------------------------------

--- Execute a move action for an enemy
--- @param enemy table Enemy entity
--- @param decision table Move decision with next_tile
--- @return table Result { result = string, ... }
local function execute_move(enemy, decision)
    local next_tile = decision.next_tile
    if not next_tile then
        return { result = M.RESULT.IDLE, reason = "no_next_tile" }
    end
    
    local target_x, target_y = next_tile.x, next_tile.y
    
    -- Check if target is walkable
    if not is_walkable(target_x, target_y) then
        return { result = M.RESULT.BLOCKED, reason = "unwalkable" }
    end
    
    -- Check if target is occupied
    local occupied, occupant = is_occupied(target_x, target_y, enemy)
    if occupied then
        -- If occupied by player, this should have been an attack decision
        if occupant.type == "player" then
            return { result = M.RESULT.BLOCKED, reason = "player_in_way" }
        end
        -- Occupied by another enemy - blocked
        return { result = M.RESULT.BLOCKED, reason = "enemy_in_way" }
    end
    
    -- Execute move
    local old_x, old_y = enemy.x, enemy.y
    enemy.x = target_x
    enemy.y = target_y
    
    -- Update cache
    update_occupied_cache(old_x, old_y, target_x, target_y, enemy)
    
    return {
        result = M.RESULT.SUCCESS,
        action = "move",
        from = { x = old_x, y = old_y },
        to = { x = target_x, y = target_y },
    }
end

--- Execute an attack action for an enemy
--- @param enemy table Enemy entity (attacker)
--- @param decision table Attack decision with target
--- @return table Result { result = string, ... }
local function execute_attack(enemy, decision)
    local target = decision.target
    if not target then
        return { result = M.RESULT.NO_TARGET, reason = "no_target" }
    end
    
    -- Use combat module if available
    if combat_module and combat_module.resolve_melee then
        local attack_type = decision.attack_type or "melee"
        local combat_result
        
        if attack_type == "magic" and combat_module.resolve_magic then
            combat_result = combat_module.resolve_magic(enemy, target)
        else
            combat_result = combat_module.resolve_melee(enemy, target)
        end
        
        -- Apply damage to target
        if combat_result.hit and combat_result.damage > 0 then
            if target.hp then
                target.hp = target.hp - combat_result.damage
            end
        end
        
        return {
            result = M.RESULT.SUCCESS,
            action = "attack",
            attack_type = attack_type,
            hit = combat_result.hit,
            damage = combat_result.damage,
            raw_damage = combat_result.raw_damage,
            roll = combat_result.roll,
            chance = combat_result.chance,
            target_hp = target.hp,
        }
    end
    
    -- Fallback: simple attack without combat module
    local damage = enemy.weapon_base or 5
    if target.hp then
        target.hp = target.hp - damage
    end
    
    return {
        result = M.RESULT.SUCCESS,
        action = "attack",
        attack_type = "melee",
        hit = true,
        damage = damage,
        target_hp = target.hp,
    }
end

--- Execute an idle action
--- @param enemy table Enemy entity
--- @param decision table Idle decision with reason
--- @return table Result
local function execute_idle(enemy, decision)
    return {
        result = M.RESULT.IDLE,
        reason = decision.reason or "no_action",
    }
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Initialize enemy actions module
--- @param player_ref table Player entity reference
--- @param enemy_ref table|nil Enemy module reference
--- @param combat_ref table|nil Combat module reference
--- @param map_ref table|nil Map module reference
function M.init(player_ref, enemy_ref, combat_ref, map_ref)
    player = player_ref
    enemy_module = enemy_ref
    combat_module = combat_ref
    map_module = map_ref
    
    -- Try to load modules if not provided
    if not enemy_module then
        pcall(function()
            enemy_module = require("descent.enemy")
        end)
    end
    
    if not combat_module then
        pcall(function()
            combat_module = require("descent.combat")
        end)
    end
end

--- Set player reference
--- @param player_ref table Player entity
function M.set_player(player_ref)
    player = player_ref
end

--- Set enemy module reference
--- @param enemy_ref table Enemy module
function M.set_enemy_module(enemy_ref)
    enemy_module = enemy_ref
end

--- Set combat module reference
--- @param combat_ref table Combat module
function M.set_combat_module(combat_ref)
    combat_module = combat_ref
end

--- Set map module reference
--- @param map_ref table Map module
function M.set_map_module(map_ref)
    map_module = map_ref
end

--- Decide and execute action for a single enemy
--- This is called by turn_manager.process_enemy()
--- @param enemy table Enemy entity
--- @return table Action result
function M.decide_action(enemy)
    if not enemy or not enemy.alive then
        return { result = M.RESULT.IDLE, reason = "dead_or_nil" }
    end
    
    if not player then
        return { result = M.RESULT.NO_TARGET, reason = "no_player" }
    end
    
    -- Get decision from enemy AI
    if not enemy_module or not enemy_module.decide then
        return { result = M.RESULT.IDLE, reason = "no_enemy_module" }
    end
    
    local decision = enemy_module.decide(enemy, player)
    
    if not decision then
        return { result = M.RESULT.IDLE, reason = "no_decision" }
    end
    
    -- Execute based on decision type
    if decision.action == "attack" then
        return execute_attack(enemy, decision)
    elseif decision.action == "move" then
        return execute_move(enemy, decision)
    else
        return execute_idle(enemy, decision)
    end
end

--- Process all enemies in deterministic order
--- @return table Array of { enemy = enemy, result = result }
function M.process_all_enemies()
    local results = {}
    
    -- Rebuild occupied cache at start of enemy phase
    rebuild_occupied_cache()
    
    if not enemy_module or not enemy_module.get_all then
        return results
    end
    
    -- Process in spawn order (deterministic)
    for _, enemy in ipairs(enemy_module.get_all()) do
        if enemy.alive then
            local result = M.decide_action(enemy)
            table.insert(results, {
                enemy = enemy,
                result = result,
            })
        end
    end
    
    return results
end

--- Start enemy turn phase (rebuild cache)
function M.begin_enemy_phase()
    rebuild_occupied_cache()
end

--- End enemy turn phase
function M.end_enemy_phase()
    -- Verify no overlaps
    local positions = {}
    local overlaps = {}
    
    if enemy_module and enemy_module.get_all then
        for _, enemy in ipairs(enemy_module.get_all()) do
            if enemy.alive then
                local key = coord_key(enemy.x, enemy.y)
                if positions[key] then
                    table.insert(overlaps, { key = key, enemies = { positions[key], enemy } })
                else
                    positions[key] = enemy
                end
            end
        end
    end
    
    if #overlaps > 0 then
        local log_fn = log_warn or print
        log_fn("[actions_enemy] WARNING: " .. #overlaps .. " enemy overlap(s) detected!")
        for _, overlap in ipairs(overlaps) do
            log_fn("  - Position " .. overlap.key .. ": " .. overlap.enemies[1].name .. " and " .. overlap.enemies[2].name)
        end
    end
    
    return #overlaps == 0
end

--- Get all sorted enemies (for turn_manager)
--- @return table Array of enemies in spawn order
function M.get_all_sorted()
    if enemy_module and enemy_module.get_all then
        return enemy_module.get_all()
    end
    return {}
end

--- Check if any enemy is adjacent to player
--- @return table|nil First adjacent enemy or nil
function M.get_adjacent_enemy()
    if not player or not enemy_module then
        return nil
    end
    
    local px, py = player.x, player.y
    
    for _, enemy in ipairs(enemy_module.get_all()) do
        if enemy.alive then
            local dx = math.abs(enemy.x - px)
            local dy = math.abs(enemy.y - py)
            if dx <= 1 and dy <= 1 and not (dx == 0 and dy == 0) then
                return enemy
            end
        end
    end
    
    return nil
end

return M
