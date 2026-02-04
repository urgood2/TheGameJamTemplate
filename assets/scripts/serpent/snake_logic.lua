-- assets/scripts/serpent/snake_logic.lua
--[[
    Snake Logic Module

    Pure logic for snake state management including damage application,
    death handling, length validation, and segment operations.
    Part of the pure combat logic pipeline.
]]

local snake_logic = {}

--- Apply damage to a specific segment by instance_id
--- @param snake_state table Current snake state
--- @param instance_id number Target segment instance ID
--- @param damage_amount number Damage to apply (positive integer)
--- @return table, table Updated snake_state, array of death events
function snake_logic.apply_damage(snake_state, instance_id, damage_amount)
    local updated_state = {
        segments = {},
        min_len = snake_state.min_len or 3,
        max_len = snake_state.max_len or 8
    }
    local death_events = {}

    -- Copy segments and apply damage to the target
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
            special_state = segment.special_state and {table.unpack(segment.special_state)} or {}
        }

        -- Apply damage if this is the target segment
        if segment.instance_id == instance_id then
            updated_segment.hp = math.max(0, updated_segment.hp - damage_amount)

            -- Check for death
            if updated_segment.hp <= 0 then
                table.insert(death_events, {
                    kind = "unit_dead",
                    instance_id = instance_id
                })
                -- Don't add dead segment to updated segments (remove from snake)
            else
                table.insert(updated_state.segments, updated_segment)
            end
        else
            table.insert(updated_state.segments, updated_segment)
        end
    end

    return updated_state, death_events
end

--- Apply healing to a specific segment by instance_id
--- @param snake_state table Current snake state
--- @param instance_id number Target segment instance ID
--- @param heal_amount number Healing to apply (positive integer)
--- @param effective_hp_max number Effective max HP after synergy/special modifiers
--- @return table Updated snake_state
function snake_logic.apply_healing(snake_state, instance_id, heal_amount, effective_hp_max)
    local updated_state = {
        segments = {},
        min_len = snake_state.min_len or 3,
        max_len = snake_state.max_len or 8
    }

    -- Copy segments and apply healing to the target
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
            special_state = segment.special_state and {table.unpack(segment.special_state)} or {}
        }

        -- Apply healing if this is the target segment
        if segment.instance_id == instance_id then
            local max_hp = effective_hp_max or updated_segment.hp_max_base
            updated_segment.hp = math.min(max_hp, updated_segment.hp + heal_amount)
        end

        table.insert(updated_state.segments, updated_segment)
    end

    return updated_state
end

--- Validate snake length constraints
--- @param snake_state table Snake state to validate
--- @return boolean, string True if valid, or false with error message
function snake_logic.validate_length(snake_state)
    if not snake_state or not snake_state.segments then
        return false, "Snake state missing or invalid"
    end

    local length = #snake_state.segments
    local min_len = snake_state.min_len or 3
    local max_len = snake_state.max_len or 8

    if length < min_len then
        return false, string.format("Snake length %d below minimum %d", length, min_len)
    end

    if length > max_len then
        return false, string.format("Snake length %d exceeds maximum %d", length, max_len)
    end

    return true
end

--- Check if snake is dead (length below minimum)
--- @param snake_state table Snake state to check
--- @return boolean True if snake is dead
function snake_logic.is_dead(snake_state)
    if not snake_state or not snake_state.segments then
        return true
    end

    local length = #snake_state.segments
    local min_len = snake_state.min_len or 3

    return length < min_len
end

--- Get snake length summary
--- @param snake_state table Snake state
--- @return table Length summary with counts and constraints
function snake_logic.get_length_summary(snake_state)
    return {
        current = #(snake_state.segments or {}),
        min = snake_state.min_len or 3,
        max = snake_state.max_len or 8,
        alive_count = snake_logic._count_alive_segments(snake_state),
        can_add = snake_logic._can_add_segment(snake_state),
        can_remove = snake_logic._can_remove_segment(snake_state)
    }
end

--- Count alive segments (hp > 0)
--- @param snake_state table Snake state
--- @return number Number of alive segments
function snake_logic._count_alive_segments(snake_state)
    local count = 0
    for _, segment in ipairs(snake_state.segments or {}) do
        if segment.hp and segment.hp > 0 then
            count = count + 1
        end
    end
    return count
end

--- Check if a segment can be added to the snake
--- @param snake_state table Snake state
--- @return boolean True if segment can be added
function snake_logic._can_add_segment(snake_state)
    local length = #(snake_state.segments or {})
    local max_len = snake_state.max_len or 8
    return length < max_len
end

--- Check if a segment can be removed from the snake
--- @param snake_state table Snake state
--- @return boolean True if segment can be removed
function snake_logic._can_remove_segment(snake_state)
    local length = #(snake_state.segments or {})
    local min_len = snake_state.min_len or 3
    return length > min_len
end

--- Update segment cooldowns by delta time
--- @param snake_state table Current snake state
--- @param dt number Delta time in seconds
--- @return table Updated snake state with decremented cooldowns
function snake_logic.update_cooldowns(snake_state, dt)
    local updated_state = {
        segments = {},
        min_len = snake_state.min_len or 3,
        max_len = snake_state.max_len or 8
    }

    -- Update cooldowns for all segments
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
            cooldown = math.max(0, (segment.cooldown or 0) - dt), -- Clamp to 0 minimum
            acquired_seq = segment.acquired_seq,
            special_state = segment.special_state and {table.unpack(segment.special_state)} or {}
        }

        table.insert(updated_state.segments, updated_segment)
    end

    return updated_state
end

--- Find segment by instance_id
--- @param snake_state table Snake state
--- @param instance_id number Instance ID to find
--- @return table|nil Segment if found, nil otherwise
function snake_logic.find_segment(snake_state, instance_id)
    for _, segment in ipairs(snake_state.segments or {}) do
        if segment.instance_id == instance_id then
            return segment
        end
    end
    return nil
end

--- Get segments ordered head to tail
--- @param snake_state table Snake state
--- @return table Array of segments in head→tail order (same as segments array)
function snake_logic.get_ordered_segments(snake_state)
    -- Segments are already stored in head→tail order per PLAN.md
    return snake_state.segments and {table.unpack(snake_state.segments)} or {}
end

--- Check if a segment can be sold without violating minimum length
--- @param snake_state table Snake state to check
--- @param instance_id number Instance ID of segment to potentially sell
--- @return boolean True if segment can be sold, false if it would drop below min_len
function snake_logic.can_sell(snake_state, instance_id)
    if not snake_state or not snake_state.segments then
        return false
    end

    -- Check if the segment exists in the snake
    local segment_exists = false
    for _, segment in ipairs(snake_state.segments) do
        if segment.instance_id == instance_id then
            segment_exists = true
            break
        end
    end

    if not segment_exists then
        return false -- Can't sell something that doesn't exist
    end

    local current_length = #snake_state.segments
    local min_len = snake_state.min_len or 3

    -- Check if selling would drop below minimum length
    local length_after_sell = current_length - 1
    return length_after_sell >= min_len
end

--- Remove a segment instance from the snake by instance_id
--- @param snake_state table Current snake state
--- @param instance_id number Instance ID of segment to remove
--- @return table, boolean Updated snake_state, true if segment was found and removed
function snake_logic.remove_instance(snake_state, instance_id)
    local updated_state = {
        segments = {},
        min_len = snake_state.min_len or 3,
        max_len = snake_state.max_len or 8
    }
    local found = false

    -- Copy all segments except the one to remove
    for _, segment in ipairs(snake_state.segments or {}) do
        if segment.instance_id == instance_id then
            found = true
            -- Skip this segment (don't add to updated_state)
        else
            -- Copy segment to updated state
            local copied_segment = {
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
                special_state = segment.special_state and {table.unpack(segment.special_state)} or {}
            }
            table.insert(updated_state.segments, copied_segment)
        end
    end

    return updated_state, found
end

--- Test snake damage and death mechanics
--- @return boolean True if damage/death logic works correctly
function snake_logic.test_damage_and_death()
    -- Create mock snake state with 3 segments
    local snake_state = {
        segments = {
            { instance_id = 1, hp = 50, hp_max_base = 100 },
            { instance_id = 2, hp = 30, hp_max_base = 80 },
            { instance_id = 3, hp = 20, hp_max_base = 60 }
        },
        min_len = 3,
        max_len = 8
    }

    -- Apply non-lethal damage
    local updated_state, death_events = snake_logic.apply_damage(snake_state, 2, 10)

    -- Should have 3 segments still, second segment at 20 HP
    if #updated_state.segments ~= 3 then
        return false
    end

    local segment_2 = snake_logic.find_segment(updated_state, 2)
    if not segment_2 or segment_2.hp ~= 20 then
        return false
    end

    if #death_events ~= 0 then
        return false
    end

    -- Apply lethal damage
    updated_state, death_events = snake_logic.apply_damage(updated_state, 2, 25)

    -- Should have 2 segments now, segment 2 should be gone
    if #updated_state.segments ~= 2 then
        return false
    end

    if snake_logic.find_segment(updated_state, 2) ~= nil then
        return false
    end

    if #death_events ~= 1 or death_events[1].instance_id ~= 2 then
        return false
    end

    -- Check if snake is still alive
    if snake_logic.is_dead(updated_state) then
        return false
    end

    -- Kill one more segment to test death condition
    updated_state, death_events = snake_logic.apply_damage(updated_state, 1, 100)

    -- Should have 1 segment, snake should be dead
    if #updated_state.segments ~= 1 then
        return false
    end

    if not snake_logic.is_dead(updated_state) then
        return false
    end

    return true
end

--- Test can_sell function with minimum length constraints
--- @return boolean True if can_sell logic works correctly
function snake_logic.test_can_sell()
    -- Test with minimum length snake (3 segments)
    local min_snake = {
        segments = {
            { instance_id = 1 },
            { instance_id = 2 },
            { instance_id = 3 }
        },
        min_len = 3,
        max_len = 8
    }

    -- Cannot sell any segment from minimum length snake
    if snake_logic.can_sell(min_snake, 1) or
       snake_logic.can_sell(min_snake, 2) or
       snake_logic.can_sell(min_snake, 3) then
        return false
    end

    -- Test with longer snake (4 segments)
    local longer_snake = {
        segments = {
            { instance_id = 1 },
            { instance_id = 2 },
            { instance_id = 3 },
            { instance_id = 4 }
        },
        min_len = 3,
        max_len = 8
    }

    -- Can sell any segment from 4-segment snake (would leave 3)
    if not snake_logic.can_sell(longer_snake, 1) or
       not snake_logic.can_sell(longer_snake, 2) or
       not snake_logic.can_sell(longer_snake, 3) or
       not snake_logic.can_sell(longer_snake, 4) then
        return false
    end

    -- Test with non-existent segment
    if snake_logic.can_sell(longer_snake, 99) then
        return false
    end

    return true
end

--- Test remove_instance function
--- @return boolean True if remove_instance logic works correctly
function snake_logic.test_remove_instance()
    -- Test with 4-segment snake
    local snake_state = {
        segments = {
            { instance_id = 1, def_id = "soldier" },
            { instance_id = 2, def_id = "mage" },
            { instance_id = 3, def_id = "scout" },
            { instance_id = 4, def_id = "healer" }
        },
        min_len = 3,
        max_len = 8
    }

    -- Remove middle segment
    local updated_state, found = snake_logic.remove_instance(snake_state, 2)

    -- Should find and remove segment 2
    if not found or #updated_state.segments ~= 3 then
        return false
    end

    -- Verify segment 2 is gone but others remain
    local remaining_ids = {}
    for _, segment in ipairs(updated_state.segments) do
        table.insert(remaining_ids, segment.instance_id)
    end

    -- Should have 1, 3, 4 but not 2
    if snake_logic.find_segment(updated_state, 2) ~= nil then
        return false
    end

    if not snake_logic.find_segment(updated_state, 1) or
       not snake_logic.find_segment(updated_state, 3) or
       not snake_logic.find_segment(updated_state, 4) then
        return false
    end

    -- Test removing non-existent segment
    updated_state, found = snake_logic.remove_instance(updated_state, 99)
    if found or #updated_state.segments ~= 3 then
        return false
    end

    -- Test removing down to 0 segments (for death scenarios)
    updated_state, found = snake_logic.remove_instance(updated_state, 1)
    updated_state, found = snake_logic.remove_instance(updated_state, 3)
    updated_state, found = snake_logic.remove_instance(updated_state, 4)

    if #updated_state.segments ~= 0 then
        return false
    end

    return true
end

return snake_logic