-- assets/scripts/serpent/spawn_emission.lua
--[[
    Spawn Emission Module

    Implements spawn emission logic that prioritizes forced_queue (FIFO) over
    base_spawn_list with spawn_budget management for timed enemy releases.
]]

local spawn_emission = {}

--- Initialize spawn emission state
--- @param forced_queue table Array of forced spawn entries (FIFO order)
--- @param base_spawn_list table Array of base spawn entries
--- @param spawn_budget number Initial spawn budget
--- @return table Emission state
function spawn_emission.create_state(forced_queue, base_spawn_list, spawn_budget)
    return {
        forced_queue = forced_queue and {table.unpack(forced_queue)} or {},
        base_spawn_list = base_spawn_list and {table.unpack(base_spawn_list)} or {},
        spawn_budget = spawn_budget or 0,
        base_spawn_index = 1, -- Current index in base_spawn_list
        total_emitted = 0
    }
end

--- Emit spawn events based on forced queue and spawn budget
--- @param emission_state table Current emission state
--- @param requested_count number Number of spawn events requested
--- @return table, table Updated emission_state, array of spawn events
function spawn_emission.emit(emission_state, requested_count)
    local updated_state = {
        forced_queue = {table.unpack(emission_state.forced_queue)},
        base_spawn_list = {table.unpack(emission_state.base_spawn_list)},
        spawn_budget = emission_state.spawn_budget,
        base_spawn_index = emission_state.base_spawn_index,
        total_emitted = emission_state.total_emitted
    }

    local spawn_events = {}
    local remaining_count = requested_count or 1

    -- First priority: emit from forced_queue (FIFO)
    while remaining_count > 0 and #updated_state.forced_queue > 0 do
        local forced_entry = table.remove(updated_state.forced_queue, 1) -- FIFO removal

        local spawn_event = spawn_emission._create_spawn_event(forced_entry, "forced")
        table.insert(spawn_events, spawn_event)

        updated_state.total_emitted = updated_state.total_emitted + 1
        remaining_count = remaining_count - 1
    end

    -- Second priority: emit from base_spawn_list via spawn_budget
    while remaining_count > 0 and
          updated_state.spawn_budget > 0 and
          updated_state.base_spawn_index <= #updated_state.base_spawn_list do

        local base_entry = updated_state.base_spawn_list[updated_state.base_spawn_index]

        local spawn_event = spawn_emission._create_spawn_event(base_entry, "budget")
        table.insert(spawn_events, spawn_event)

        updated_state.spawn_budget = updated_state.spawn_budget - 1
        updated_state.base_spawn_index = updated_state.base_spawn_index + 1
        updated_state.total_emitted = updated_state.total_emitted + 1
        remaining_count = remaining_count - 1
    end

    return updated_state, spawn_events
end

--- Add entries to the forced queue (highest priority)
--- @param emission_state table Current emission state
--- @param forced_entries table Array of spawn entries to add to forced queue
--- @return table Updated emission state
function spawn_emission.add_forced(emission_state, forced_entries)
    local updated_state = {
        forced_queue = {table.unpack(emission_state.forced_queue)},
        base_spawn_list = {table.unpack(emission_state.base_spawn_list)},
        spawn_budget = emission_state.spawn_budget,
        base_spawn_index = emission_state.base_spawn_index,
        total_emitted = emission_state.total_emitted
    }

    -- Add new entries to the end of forced queue (FIFO behavior)
    for _, entry in ipairs(forced_entries or {}) do
        table.insert(updated_state.forced_queue, entry)
    end

    return updated_state
end

--- Increase spawn budget (allows more base spawns)
--- @param emission_state table Current emission state
--- @param budget_increase number Amount to increase budget by
--- @return table Updated emission state
function spawn_emission.add_budget(emission_state, budget_increase)
    local updated_state = {
        forced_queue = {table.unpack(emission_state.forced_queue)},
        base_spawn_list = {table.unpack(emission_state.base_spawn_list)},
        spawn_budget = emission_state.spawn_budget + (budget_increase or 0),
        base_spawn_index = emission_state.base_spawn_index,
        total_emitted = emission_state.total_emitted
    }

    return updated_state
end

--- Replace the base spawn list
--- @param emission_state table Current emission state
--- @param new_base_list table New base spawn list
--- @return table Updated emission state
function spawn_emission.set_base_list(emission_state, new_base_list)
    local updated_state = {
        forced_queue = {table.unpack(emission_state.forced_queue)},
        base_spawn_list = new_base_list and {table.unpack(new_base_list)} or {},
        spawn_budget = emission_state.spawn_budget,
        base_spawn_index = 1, -- Reset index when list changes
        total_emitted = emission_state.total_emitted
    }

    return updated_state
end

--- Check if emission can produce more spawn events
--- @param emission_state table Emission state to check
--- @return boolean True if more spawns are available
function spawn_emission.can_emit(emission_state)
    -- Can emit if there are forced entries OR budget for base spawns
    local has_forced = #emission_state.forced_queue > 0
    local has_budget_spawns = emission_state.spawn_budget > 0 and
                             emission_state.base_spawn_index <= #emission_state.base_spawn_list

    return has_forced or has_budget_spawns
end

--- Get emission status summary
--- @param emission_state table Emission state
--- @return table Status summary
function spawn_emission.get_status(emission_state)
    local remaining_base = math.max(0, #emission_state.base_spawn_list - emission_state.base_spawn_index + 1)

    return {
        forced_queue_count = #emission_state.forced_queue,
        base_remaining = remaining_base,
        spawn_budget = emission_state.spawn_budget,
        total_emitted = emission_state.total_emitted,
        can_emit = spawn_emission.can_emit(emission_state),
        base_progress = {
            current = emission_state.base_spawn_index - 1,
            total = #emission_state.base_spawn_list
        }
    }
end

--- Create a spawn event from a spawn entry
--- @param spawn_entry table Entry with enemy_id or def_id
--- @param source string Source type ("forced" or "budget")
--- @return table SpawnEvent structure
function spawn_emission._create_spawn_event(spawn_entry, source)
    return {
        type = "SpawnEnemyEvent",
        enemy_id = spawn_entry.enemy_id,
        def_id = spawn_entry.def_id or spawn_entry.enemy_id,
        source = source,
        hp_mult = spawn_entry.hp_mult or 1.0,
        dmg_mult = spawn_entry.dmg_mult or 1.0,
        is_boss = spawn_entry.is_boss or false,
        spawn_rule = spawn_entry.spawn_rule or { mode = "edge_random", arena = { w = 800, h = 600, padding = 50 } }
    }
end

--- Test forced queue priority over base spawns
--- @return boolean True if forced queue has priority
function spawn_emission.test_forced_priority()
    local base_list = {
        { enemy_id = "slime" },
        { enemy_id = "bat" }
    }

    local forced_entries = {
        { enemy_id = "boss1", is_boss = true },
        { enemy_id = "boss2", is_boss = true }
    }

    -- Create emission state with budget and forced entries
    local state = spawn_emission.create_state({}, base_list, 10)
    state = spawn_emission.add_forced(state, forced_entries)

    -- Emit 3 spawns - should get 2 forced, then 1 from base
    local final_state, events = spawn_emission.emit(state, 3)

    -- Check order: boss1, boss2, slime
    if #events ~= 3 then
        return false
    end

    if events[1].enemy_id ~= "boss1" or events[1].source ~= "forced" then
        return false
    end

    if events[2].enemy_id ~= "boss2" or events[2].source ~= "forced" then
        return false
    end

    if events[3].enemy_id ~= "slime" or events[3].source ~= "budget" then
        return false
    end

    -- Check state - forced queue empty, budget reduced
    if #final_state.forced_queue ~= 0 or final_state.spawn_budget ~= 9 then
        return false
    end

    return true
end

--- Test spawn budget limits
--- @return boolean True if budget limiting works correctly
function spawn_emission.test_budget_limits()
    local base_list = {
        { enemy_id = "slime" },
        { enemy_id = "bat" },
        { enemy_id = "goblin" }
    }

    -- Create state with limited budget
    local state = spawn_emission.create_state({}, base_list, 2)

    -- Try to emit 5 spawns with budget of 2
    local final_state, events = spawn_emission.emit(state, 5)

    -- Should only emit 2 spawns due to budget
    if #events ~= 2 then
        return false
    end

    if events[1].enemy_id ~= "slime" or events[2].enemy_id ~= "bat" then
        return false
    end

    -- Budget should be exhausted
    if final_state.spawn_budget ~= 0 then
        return false
    end

    -- Index should be at 3 (next would be goblin)
    if final_state.base_spawn_index ~= 3 then
        return false
    end

    return true
end

--- Test FIFO behavior of forced queue
--- @return boolean True if FIFO works correctly
function spawn_emission.test_fifo_behavior()
    local forced_entries1 = {
        { enemy_id = "first" },
        { enemy_id = "second" }
    }

    local forced_entries2 = {
        { enemy_id = "third" },
        { enemy_id = "fourth" }
    }

    -- Create state and add forced entries in order
    local state = spawn_emission.create_state(forced_entries1, {}, 0)
    state = spawn_emission.add_forced(state, forced_entries2)

    -- Emit all forced spawns
    local final_state, events = spawn_emission.emit(state, 4)

    -- Check FIFO order
    if #events ~= 4 then
        return false
    end

    local expected_order = {"first", "second", "third", "fourth"}
    for i, expected in ipairs(expected_order) do
        if events[i].enemy_id ~= expected then
            return false
        end
    end

    return true
end

--- Test emission status and can_emit
--- @return boolean True if status reporting works correctly
function spawn_emission.test_emission_status()
    local base_list = {
        { enemy_id = "slime" },
        { enemy_id = "bat" }
    }

    local state = spawn_emission.create_state({}, base_list, 1)

    -- Initial status
    local status = spawn_emission.get_status(state)
    if not status.can_emit or status.spawn_budget ~= 1 or status.base_remaining ~= 2 then
        return false
    end

    -- Emit one
    state, _ = spawn_emission.emit(state, 1)

    -- Updated status
    status = spawn_emission.get_status(state)
    if status.can_emit or status.spawn_budget ~= 0 or status.base_remaining ~= 1 then
        return false
    end

    return true
end

return spawn_emission