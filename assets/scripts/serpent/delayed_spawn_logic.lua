-- assets/scripts/serpent/delayed_spawn_logic.lua
--[[
    Delayed Spawn Logic Module

    Decrements delayed_queue timers and moves expired entries into forced_queue
    while preserving insertion order.
]]

local delayed_spawn_logic = {}

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

local function to_forced_entry(delayed_entry)
    local forced_entry = copy_table_shallow(delayed_entry)
    forced_entry.t_left_sec = nil

    if forced_entry.enemy_id == nil then
        forced_entry.enemy_id = forced_entry.def_id
    end
    if forced_entry.def_id == nil then
        forced_entry.def_id = forced_entry.enemy_id
    end

    return forced_entry
end

--- Process delayed_queue timers and move expired entries to forced_queue.
--- @param dt number Delta time in seconds
--- @param delayed_queue table Array of { t_left_sec, def_id, ... }
--- @param forced_queue table Array of forced spawn entries (FIFO)
--- @return table, table, table Updated delayed_queue, updated forced_queue, moved_entries
function delayed_spawn_logic.process(dt, delayed_queue, forced_queue)
    local updated_delayed = {}
    local updated_forced = forced_queue and {table.unpack(forced_queue)} or {}
    local moved_entries = {}

    local step = dt or 0

    for _, entry in ipairs(delayed_queue or {}) do
        local next_entry = copy_table_shallow(entry)
        next_entry.t_left_sec = (next_entry.t_left_sec or 0) - step

        if next_entry.t_left_sec <= 0 then
            local forced_entry = to_forced_entry(next_entry)
            table.insert(updated_forced, forced_entry)
            table.insert(moved_entries, forced_entry)
        else
            table.insert(updated_delayed, next_entry)
        end
    end

    return updated_delayed, updated_forced, moved_entries
end

return delayed_spawn_logic
