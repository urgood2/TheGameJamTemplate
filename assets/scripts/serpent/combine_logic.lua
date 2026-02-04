-- assets/scripts/serpent/combine_logic.lua
--[[
    Combine Logic Module

    Handles unit combination when 3 copies of the same unit at the same level are collected.
    Implements deterministic ordering and chain-safe processing as per PLAN.md specifications.
]]

local combine_logic = {}

--- Apply combines repeatedly until no more combinations are possible
--- @param snake_state table Current snake state with segments
--- @param unit_defs table Unit definitions for stat lookup
--- @return table, table Updated snake_state, array of combine_events
function combine_logic.apply_combines_until_stable(snake_state, unit_defs)
    if not snake_state or not snake_state.segments then
        return snake_state, {}
    end

    local updated_snake = {
        segments = {table.unpack(snake_state.segments)}, -- Copy segments
        head_dir = snake_state.head_dir,
        length = snake_state.length or #snake_state.segments
    }
    local all_combine_events = {}

    -- Repeat combines until no more are possible
    local max_iterations = 100 -- Safety guard against infinite loops
    for iteration = 1, max_iterations do
        local snake_after_pass, combine_events = combine_logic.apply_single_combine_pass(updated_snake, unit_defs)

        -- Add events from this pass
        for _, event in ipairs(combine_events) do
            table.insert(all_combine_events, event)
        end

        -- If no combines happened this pass, we're done
        if #combine_events == 0 then
            break
        end

        updated_snake = snake_after_pass
    end

    -- Update length
    updated_snake.length = #updated_snake.segments

    return updated_snake, all_combine_events
end

--- Apply one pass of combine detection and processing
--- @param snake_state table Current snake state
--- @param unit_defs table Unit definitions
--- @return table, table Updated snake_state, combine_events from this pass
function combine_logic.apply_single_combine_pass(snake_state, unit_defs)
    local segments = {table.unpack(snake_state.segments)}
    local combine_events = {}

    -- Group segments by (def_id, level)
    local groups = combine_logic.build_combine_groups(segments)

    -- Process groups in deterministic order: def_id ascending, then level 1 before 2
    local sorted_keys = {}
    for key, _ in pairs(groups) do
        table.insert(sorted_keys, key)
    end
    table.sort(sorted_keys, function(a, b)
        local def_a, level_a = a:match("^(.+):(%d+)$")
        local def_b, level_b = b:match("^(.+):(%d+)$")

        if def_a ~= def_b then
            return def_a < def_b
        end
        return tonumber(level_a) < tonumber(level_b)
    end)

    -- Check each group for combines
    for _, group_key in ipairs(sorted_keys) do
        local group = groups[group_key]
        local def_id, level = group_key:match("^(.+):(%d+)$")
        level = tonumber(level)

        if #group >= 3 then
            -- Found a combinable triple - process it
            local combine_event = combine_logic.process_combine(segments, group, def_id, level, unit_defs)
            table.insert(combine_events, combine_event)

            -- Exit after first combine to restart pass (deterministic order)
            break
        end
    end

    local updated_snake = {
        segments = segments,
        head_dir = snake_state.head_dir,
        length = #segments
    }

    return updated_snake, combine_events
end

--- Build groups of segments by (def_id, level)
--- @param segments table Array of unit instances
--- @return table Groups keyed by "def_id:level"
function combine_logic.build_combine_groups(segments)
    local groups = {}

    for i, segment in ipairs(segments) do
        if segment and segment.def_id and segment.level then
            local key = segment.def_id .. ":" .. tostring(segment.level)
            if not groups[key] then
                groups[key] = {}
            end
            table.insert(groups[key], {index = i, segment = segment})
        end
    end

    return groups
end

--- Process a single combine operation
--- @param segments table Array of segments (modified in place)
--- @param group table Group of segments to combine from
--- @param def_id string Unit definition ID
--- @param level number Current level
--- @param unit_defs table Unit definitions for stat lookup
--- @return table Combine event
function combine_logic.process_combine(segments, group, def_id, level, unit_defs)
    -- Sort by acquired_seq to find the 3 lowest
    table.sort(group, function(a, b)
        return (a.segment.acquired_seq or 0) < (b.segment.acquired_seq or 0)
    end)

    -- Take the first 3 (lowest acquired_seq)
    local kept_index = group[1].index
    local kept_segment = group[1].segment
    local removed_indices = {group[2].index, group[3].index}
    local removed_ids = {group[2].segment.instance_id, group[3].segment.instance_id}

    -- Upgrade the kept segment
    local new_level = level + 1
    kept_segment.level = new_level

    -- Apply level scaling for stats
    local unit_def = unit_defs and unit_defs[def_id]
    if unit_def then
        local scaled_stats = combine_logic.apply_level_scaling(unit_def, new_level)
        kept_segment.hp = scaled_stats.hp_max_base_int -- Full heal on combine
        kept_segment.hp_max_base = scaled_stats.hp_max_base_int
        kept_segment.attack_base = scaled_stats.attack_base_int
    end

    -- Remove the other 2 segments (remove in reverse order to preserve indices)
    table.sort(removed_indices, function(a, b) return a > b end)
    for _, index in ipairs(removed_indices) do
        table.remove(segments, index)
    end

    return {
        kept_instance_id = kept_segment.instance_id,
        removed_instance_ids = removed_ids,
        new_level = new_level,
        def_id = def_id
    }
end

--- Apply level scaling to unit stats
--- @param unit_def table Unit definition
--- @param level number Target level (1-3)
--- @return table Scaled stats { hp_max_base_int, attack_base_int }
function combine_logic.apply_level_scaling(unit_def, level)
    if not unit_def then
        return {hp_max_base_int = 100, attack_base_int = 10}
    end

    level = math.min(level or 1, 3) -- Cap at level 3

    -- Scaling formula: base * 2^(level-1)
    local scale_multiplier = math.pow(2, level - 1)

    local scaled_hp = math.floor((unit_def.base_hp or 100) * scale_multiplier)
    local scaled_attack = math.floor((unit_def.base_attack or 10) * scale_multiplier)

    return {
        hp_max_base_int = scaled_hp,
        attack_base_int = scaled_attack
    }
end

--- Check if snake length would exceed maximum after potential combines
--- @param snake_state table Current snake state
--- @param new_segment table Segment to potentially add
--- @param max_length number Maximum allowed length
--- @param unit_defs table Unit definitions
--- @return boolean True if purchase would be valid
function combine_logic.can_purchase_at_max_length(snake_state, new_segment, max_length, unit_defs)
    if not snake_state or not snake_state.segments then
        return true
    end

    -- Simulate adding the new segment
    local simulated_snake = {
        segments = {table.unpack(snake_state.segments)},
        head_dir = snake_state.head_dir,
        length = snake_state.length
    }
    table.insert(simulated_snake.segments, new_segment)
    simulated_snake.length = #simulated_snake.segments

    -- Apply combines to see final length
    local final_snake, _ = combine_logic.apply_combines_until_stable(simulated_snake, unit_defs)

    return final_snake.length <= max_length
end

return combine_logic