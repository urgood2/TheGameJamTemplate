-- assets/scripts/serpent/attack_production_logic.lua
--[[
    Attack Production Logic Module

    Uses auto_attack_logic to generate attack events and updates cooldowns
    on the snake_state segments (head->tail order).
]]

local auto_attack_logic = require("serpent.auto_attack_logic")

local attack_production_logic = {}

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

local function build_updated_state(snake_state, cooldowns_by_instance_id)
    local updated_state = {
        segments = {},
        min_len = snake_state.min_len or 3,
        max_len = snake_state.max_len or 8
    }

    for _, segment in ipairs(snake_state.segments or {}) do
        local updated_segment = {
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

        if cooldowns_by_instance_id and segment.instance_id ~= nil then
            local updated_cooldown = cooldowns_by_instance_id[segment.instance_id]
            if updated_cooldown ~= nil then
                updated_segment.cooldown = updated_cooldown
            end
        end

        table.insert(updated_state.segments, updated_segment)
    end

    return updated_state
end

--- Produce attacks and update cooldowns.
--- @param dt number Delta time in seconds
--- @param snake_state table Snake state with segments
--- @param segment_combat_snaps table Segment combat snapshots in head->tail order
--- @param enemy_snaps table Enemy snapshots in ascending enemy_id order
--- @return table, table, table Updated snake_state, attack_events, cooldowns_by_instance_id
function attack_production_logic.produce_attacks(dt, snake_state, segment_combat_snaps, enemy_snaps)
    local safe_state = snake_state or { segments = {}, min_len = 3, max_len = 8 }
    local safe_segment_snaps = segment_combat_snaps or {}
    local safe_enemy_snaps = enemy_snaps or {}

    local cooldowns_by_instance_id, attack_events = auto_attack_logic.tick(
        dt or 0, safe_segment_snaps, safe_enemy_snaps
    )

    local updated_state = build_updated_state(safe_state, cooldowns_by_instance_id)

    return updated_state, attack_events, cooldowns_by_instance_id
end

return attack_production_logic
