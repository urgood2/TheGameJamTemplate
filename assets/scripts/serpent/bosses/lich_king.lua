-- assets/scripts/serpent/bosses/lich_king.lua
--[[
    Lich King Boss Module

    Implements skeleton raising behavior for the lich_king boss.
    Converts enemy deaths into delayed skeleton spawns.
]]

local lich_king = {}

-- Delay time for skeleton spawns after enemy death
local SKELETON_RAISE_DELAY_SEC = 2.0

--- Initialize boss state for a lich king
--- @param enemy_id number Boss enemy instance ID
--- @return table Boss state with raise queue
function lich_king.init(enemy_id)
    return {
        enemy_id = enemy_id,
        queued_raises = 0, -- Number of skeleton raises pending
    }
end

--- Handle enemy death events to queue skeleton raises
--- @param boss_state table Current boss state
--- @param dead_enemy_def_id string Definition ID of the dead enemy
--- @param dead_enemy_tags table Tags array from the dead enemy
--- @return table Updated boss state
function lich_king.on_enemy_dead(boss_state, dead_enemy_def_id, dead_enemy_tags)
    local next_state = {
        enemy_id = boss_state.enemy_id,
        queued_raises = boss_state.queued_raises,
    }

    -- Check if the dead enemy is eligible for raising
    if dead_enemy_tags then
        local is_boss = false
        for _, tag in ipairs(dead_enemy_tags) do
            if tag == "boss" then
                is_boss = true
                break
            end
        end

        -- Only raise non-boss enemies
        if not is_boss then
            next_state.queued_raises = next_state.queued_raises + 1
        end
    else
        -- If no tags provided, assume non-boss and queue a raise
        next_state.queued_raises = next_state.queued_raises + 1
    end

    return next_state
end

--- Process lich king tick and generate delayed spawns
--- @param dt number Delta time in seconds
--- @param boss_state table Current boss state
--- @param is_alive boolean Whether the boss is still alive
--- @return table, table Updated boss_state, array of delayed_spawns to add to delayed_queue
function lich_king.tick(dt, boss_state, is_alive)
    local next_state = {
        enemy_id = boss_state.enemy_id,
        queued_raises = boss_state.queued_raises,
    }
    local delayed_spawns = {}

    -- Only process raises if boss is alive and has queued raises
    if is_alive and next_state.queued_raises > 0 then
        -- Convert all queued raises into delayed spawns
        for i = 1, next_state.queued_raises do
            table.insert(delayed_spawns, {
                t_left_sec = SKELETON_RAISE_DELAY_SEC,
                def_id = "skeleton"
            })
        end

        -- Clear the queue after processing
        next_state.queued_raises = 0
    end

    return next_state, delayed_spawns
end

return lich_king