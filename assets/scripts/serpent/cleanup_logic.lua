-- assets/scripts/serpent/cleanup_logic.lua
--[[
    Cleanup Logic Module

    Removes dead segments from snake_state and prunes stale contact cooldowns
    for missing enemy/unit ids. Implements step 11 in the combat tick.
]]

local cleanup_logic = {}

local function copy_state(state)
    local copy = {}
    for k, v in pairs(state or {}) do
        copy[k] = v
    end
    return copy
end

local function copy_segment(segment)
    local copy = {}
    for k, v in pairs(segment or {}) do
        copy[k] = v
    end
    return copy
end

local function parse_contact_key(key)
    if type(key) ~= "string" then
        return nil, nil
    end

    local enemy_str, unit_str = key:match("^(%d+):(%d+)$")
    if not enemy_str then
        enemy_str, unit_str = key:match("^(%d+)_(%d+)$")
    end

    if not enemy_str or not unit_str then
        return nil, nil
    end

    return tonumber(enemy_str), tonumber(unit_str)
end

--- Remove dead segments (hp <= 0) from snake state.
--- @param snake_state table Snake state
--- @return table Updated snake state with only living segments
function cleanup_logic.remove_dead_segments(snake_state)
    local safe_state = snake_state or { segments = {}, min_len = 3, max_len = 8 }
    local updated_state = {
        segments = {},
        min_len = safe_state.min_len or 3,
        max_len = safe_state.max_len or 8
    }

    for _, segment in ipairs(safe_state.segments or {}) do
        if segment and (segment.hp or 0) > 0 then
            table.insert(updated_state.segments, copy_segment(segment))
        end
    end

    return updated_state
end

--- Prune stale contact cooldowns where enemy/unit ids are no longer present.
--- @param contact_cooldowns table Map of cooldowns by "enemy_id:instance_id"
--- @param enemy_snaps table Array of enemy snapshots
--- @param snake_state table Snake state (living segments)
--- @return table Pruned contact cooldown map
function cleanup_logic.prune_contact_cooldowns(contact_cooldowns, enemy_snaps, snake_state)
    local cleaned = {}
    if not contact_cooldowns then
        return cleaned
    end

    local alive_enemy_ids = {}
    for _, enemy in ipairs(enemy_snaps or {}) do
        if enemy and enemy.enemy_id then
            alive_enemy_ids[enemy.enemy_id] = true
        end
    end

    local alive_unit_ids = {}
    for _, segment in ipairs((snake_state and snake_state.segments) or {}) do
        if segment and segment.instance_id then
            alive_unit_ids[segment.instance_id] = true
        end
    end

    for key, value in pairs(contact_cooldowns) do
        local enemy_id, instance_id = parse_contact_key(key)
        if enemy_id and instance_id and alive_enemy_ids[enemy_id] and alive_unit_ids[instance_id] then
            cleaned[key] = value
        end
    end

    return cleaned
end

--- Apply cleanup phase to snake_state and combat_state.
--- @param snake_state table Snake state
--- @param enemy_snaps table Enemy snapshots
--- @param combat_state table Combat state with contact_cooldowns
--- @return table, table Updated snake_state, updated combat_state
function cleanup_logic.apply(snake_state, enemy_snaps, combat_state)
    local updated_snake_state = cleanup_logic.remove_dead_segments(snake_state)
    local updated_combat_state = copy_state(combat_state or {})

    updated_combat_state.contact_cooldowns = cleanup_logic.prune_contact_cooldowns(
        updated_combat_state.contact_cooldowns or {}, enemy_snaps, updated_snake_state
    )

    return updated_snake_state, updated_combat_state
end

return cleanup_logic
