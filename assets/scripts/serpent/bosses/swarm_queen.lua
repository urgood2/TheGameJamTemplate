-- assets/scripts/serpent/bosses/swarm_queen.lua
--[[
    Swarm Queen Boss Module

    Implements periodic slime spawning behavior for the swarm_queen boss.
    Spawns 5 slimes every 10.0 seconds while alive.
]]

local swarm_queen = {}

-- Spawn cadence for the swarm queen
local SPAWN_INTERVAL_SEC = 10.0
local SLIMES_PER_SPAWN = 5

--- Initialize boss state for a swarm queen
--- @param enemy_id number Boss enemy instance ID
--- @return table Boss state with timing accumulator
function swarm_queen.init(enemy_id)
    return {
        enemy_id = enemy_id,
        spawn_accumulator = 0.0,
    }
end

--- Process swarm queen tick and generate periodic spawns
--- @param dt number Delta time in seconds
--- @param boss_state table Current boss state
--- @param is_alive boolean Whether the boss is still alive
--- @return table, table Updated boss_state, array of forced_def_ids to spawn immediately
function swarm_queen.tick(dt, boss_state, is_alive)
    local next_state = {
        enemy_id = boss_state.enemy_id,
        spawn_accumulator = boss_state.spawn_accumulator,
    }
    local forced_def_ids = {}

    -- Only accumulate time and spawn if boss is alive
    if is_alive then
        next_state.spawn_accumulator = next_state.spawn_accumulator + dt

        -- Check if spawn interval has elapsed
        while next_state.spawn_accumulator >= SPAWN_INTERVAL_SEC do
            -- Queue 5 slimes for immediate spawning
            for i = 1, SLIMES_PER_SPAWN do
                table.insert(forced_def_ids, "slime")
            end

            -- Reset accumulator (subtract interval for precise timing)
            next_state.spawn_accumulator = next_state.spawn_accumulator - SPAWN_INTERVAL_SEC
        end
    end

    return next_state, forced_def_ids
end

return swarm_queen