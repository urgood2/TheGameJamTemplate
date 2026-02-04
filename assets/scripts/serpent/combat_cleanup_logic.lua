-- assets/scripts/serpent/combat_cleanup_logic.lua
--[[
    Combat Cleanup Logic Module

    Removes dead segments from snake_state and prunes stale contact_cooldowns
    entries for missing enemy/unit ids.
]]

local combat_cleanup_logic = {}

local function copy_table_shallow(t)
    if type(t) ~= "table" then
        return {}
    end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = v
    end
    return copy
end

local function copy_segment(segment)
    return {
        instance_id = segment.instance_id,
        def_id = segment.def_id,
        level = segment.level,
        hp = segment.hp,
        hp_max_base = segment.hp_max_base,
        attack_base = segment.attack_base,
        range_base = segment.range_base,
        atk_spd_base = segment.atk_spd_base,
        cooldown = segment.cooldown,
        acquired_seq = segment.acquired_seq,
        special_state = copy_table_shallow(segment.special_state),
        special_id = segment.special_id
    }
end

local function parse_cooldown_key(key)
    if type(key) ~= "string" then
        return nil, nil
    end
    local enemy_str, instance_str = string.match(key, "^(%-?%d+)_(%-?%d+)$")
    if not enemy_str or not instance_str then
        return nil, nil
    end
    return tonumber(enemy_str), tonumber(instance_str)
end

--- Remove dead segments from snake_state.
--- @param snake_state table
--- @return table Updated snake_state with dead segments removed
function combat_cleanup_logic.remove_dead_units(snake_state)
    local updated_state = {
        segments = {},
        min_len = (snake_state and snake_state.min_len) or 3,
        max_len = (snake_state and snake_state.max_len) or 8
    }

    for _, segment in ipairs((snake_state and snake_state.segments) or {}) do
        if segment and (segment.hp == nil or segment.hp > 0) then
            table.insert(updated_state.segments, copy_segment(segment))
        end
    end

    return updated_state
end

local function build_enemy_id_set(enemy_snaps)
    local enemy_ids = {}
    for _, enemy in ipairs(enemy_snaps or {}) do
        if enemy and enemy.enemy_id ~= nil then
            enemy_ids[enemy.enemy_id] = true
        end
    end
    return enemy_ids
end

local function build_instance_id_set(snake_state)
    local instance_ids = {}
    for _, segment in ipairs((snake_state and snake_state.segments) or {}) do
        if segment and segment.instance_id ~= nil then
            instance_ids[segment.instance_id] = true
        end
    end
    return instance_ids
end

--- Prune contact_cooldowns entries that reference missing enemy or unit ids.
--- @param contact_cooldowns table Map "enemy_id_instance_id" -> last_contact_time
--- @param snake_state table Current snake state
--- @param enemy_snaps table Enemy snapshots
--- @return table Cleaned contact_cooldowns map
function combat_cleanup_logic.prune_contact_cooldowns(contact_cooldowns, snake_state, enemy_snaps)
    local cleaned = {}
    if not contact_cooldowns then
        return cleaned
    end

    local enemy_ids = build_enemy_id_set(enemy_snaps)
    local instance_ids = build_instance_id_set(snake_state)

    for key, value in pairs(contact_cooldowns) do
        local enemy_id, instance_id = parse_cooldown_key(key)
        if enemy_id and instance_id and enemy_ids[enemy_id] and instance_ids[instance_id] then
            cleaned[key] = value
        end
    end

    return cleaned
end

--- Combined cleanup step for combat tick.
--- @param snake_state table
--- @param enemy_snaps table
--- @param contact_cooldowns table
--- @return table, table Updated snake_state, cleaned contact_cooldowns
function combat_cleanup_logic.cleanup(snake_state, enemy_snaps, contact_cooldowns)
    local updated_state = combat_cleanup_logic.remove_dead_units(snake_state or {})
    local cleaned_cooldowns = combat_cleanup_logic.prune_contact_cooldowns(
        contact_cooldowns or {}, updated_state, enemy_snaps or {}
    )

    return updated_state, cleaned_cooldowns
end

return combat_cleanup_logic
