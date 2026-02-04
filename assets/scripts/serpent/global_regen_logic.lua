-- assets/scripts/serpent/global_regen_logic.lua
--[[
    Global Regen Logic Module

    Implements Support synergy global regen accumulator and cursor-based
    round-robin healing for snake segments.
]]

local synergy_system = require("serpent.synergy_system")

local global_regen_logic = {}

local function copy_state(state)
    local copy = {}
    for k, v in pairs(state or {}) do
        copy[k] = v
    end
    return copy
end

local function normalize_cursor(cursor, count)
    if count <= 0 then
        return 1
    end
    local idx = tonumber(cursor) or 1
    if idx < 1 then
        idx = 1
    elseif idx > count then
        idx = ((idx - 1) % count) + 1
    end
    return idx
end

local function find_next_living_segment(segments, start_index)
    local count = #segments
    if count == 0 then
        return nil
    end

    local cursor = normalize_cursor(start_index, count)

    for offset = 0, count - 1 do
        local index = ((cursor - 1 + offset) % count) + 1
        local segment = segments[index]
        if segment and segment.hp and segment.hp > 0 then
            return segment, index
        end
    end

    return nil
end

--- Process global regen accumulation and emit heal events.
--- @param dt number Delta time in seconds
--- @param snake_state table Current snake state
--- @param synergy_state table Current synergy state
--- @param combat_state table Combat state with regen accum/cursor
--- @return table, table Updated combat_state, array of heal events
function global_regen_logic.tick(dt, snake_state, synergy_state, combat_state)
    local updated_state = copy_state(combat_state or {})
    local events = {}

    local segments = (snake_state and snake_state.segments) or {}
    local regen_per_sec = synergy_system.get_global_regen_rate(synergy_state)

    if not dt or dt <= 0 or regen_per_sec <= 0 or #segments == 0 then
        return updated_state, events
    end

    updated_state.global_regen_accum = (updated_state.global_regen_accum or 0.0) + (regen_per_sec * dt)
    updated_state.global_regen_cursor = normalize_cursor(updated_state.global_regen_cursor or 1, #segments)

    local cursor = updated_state.global_regen_cursor

    while updated_state.global_regen_accum >= 1.0 do
        local target_segment, target_index = find_next_living_segment(segments, cursor)
        if not target_segment or not target_segment.instance_id then
            break
        end

        table.insert(events, {
            kind = "heal_unit",
            target_instance_id = target_segment.instance_id,
            amount_int = 1,
            source_type = "global_regen"
        })

        updated_state.global_regen_accum = updated_state.global_regen_accum - 1.0
        cursor = target_index + 1
        if cursor > #segments then
            cursor = 1
        end
        updated_state.global_regen_cursor = cursor
    end

    return updated_state, events
end

return global_regen_logic
