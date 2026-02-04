-- assets/scripts/serpent/boss_event_processor.lua
--[[
    Boss Event Processor Module

    Processes enemy_dead events and routes them to appropriate boss logic
    for special abilities like lich_king raise scheduling.
]]

local lich_king = require("serpent.bosses.lich_king")
local swarm_queen = require("serpent.bosses.swarm_queen")

local boss_event_processor = {}

--- Initialize boss event processing state
--- @param active_bosses table Array of active boss entities with their def_ids
--- @return table Boss processing state
function boss_event_processor.create_state(active_bosses)
    local state = {
        boss_states = {},
        active_boss_ids = {}
    }

    -- Initialize state for each active boss
    for _, boss_entity in ipairs(active_bosses or {}) do
        local boss_id = boss_entity.enemy_id
        local boss_def_id = boss_entity.def_id

        -- Initialize boss-specific state
        if boss_def_id == "lich_king" then
            state.boss_states[boss_id] = lich_king.init(boss_id)
            state.active_boss_ids[boss_id] = "lich_king"
        elseif boss_def_id == "swarm_queen" then
            state.boss_states[boss_id] = swarm_queen.init(boss_id)
            state.active_boss_ids[boss_id] = "swarm_queen"
        end
    end

    return state
end

--- Process enemy_dead events for boss special abilities
--- @param enemy_dead_events table Array of enemy_dead events to process
--- @param boss_processor_state table Boss processing state
--- @param enemy_definitions table Enemy definitions for tag lookup
--- @param alive_boss_set table Set of boss IDs that are still alive
--- @return table Updated boss processor state
function boss_event_processor.process_enemy_dead_events(enemy_dead_events, boss_processor_state, enemy_definitions, alive_boss_set)
    local updated_state = {
        boss_states = {},
        active_boss_ids = {}
    }

    -- Copy current state
    for boss_id, boss_state in pairs(boss_processor_state.boss_states) do
        updated_state.boss_states[boss_id] = boss_state
    end
    for boss_id, boss_type in pairs(boss_processor_state.active_boss_ids) do
        updated_state.active_boss_ids[boss_id] = boss_type
    end

    -- Process each enemy death event
    for _, death_event in ipairs(enemy_dead_events or {}) do
        if boss_event_processor._is_valid_enemy_dead_event(death_event) then
            -- Get enemy definition for tag lookup
            local dead_enemy_def = enemy_definitions[death_event.def_id]
            local dead_enemy_tags = dead_enemy_def and dead_enemy_def.tags or {}

            -- Route to appropriate boss handlers
            for boss_id, boss_type in pairs(updated_state.active_boss_ids) do
                local boss_alive = alive_boss_set and alive_boss_set[boss_id] or false

                if boss_alive then
                    if boss_type == "lich_king" then
                        updated_state.boss_states[boss_id] = lich_king.on_enemy_dead(
                            updated_state.boss_states[boss_id],
                            death_event.def_id,
                            dead_enemy_tags
                        )
                    elseif boss_type == "swarm_queen" then
                        -- Swarm queen doesn't process enemy deaths currently
                        -- But structure is ready for future implementation
                    end
                end
            end
        end
    end

    return updated_state
end

--- Tick boss processing and generate spawn events
--- @param dt number Delta time in seconds
--- @param boss_processor_state table Boss processing state
--- @param alive_boss_set table Set of boss IDs that are still alive
--- @return table, table Updated state, array of spawn events
function boss_event_processor.tick(dt, boss_processor_state, alive_boss_set)
    local updated_state = {
        boss_states = {},
        active_boss_ids = {}
    }
    local spawn_events = {}

    -- Copy active boss IDs
    for boss_id, boss_type in pairs(boss_processor_state.active_boss_ids) do
        updated_state.active_boss_ids[boss_id] = boss_type
    end

    -- Tick each boss and collect spawn events
    for boss_id, boss_type in pairs(boss_processor_state.active_boss_ids) do
        local boss_alive = alive_boss_set and alive_boss_set[boss_id] or false
        local boss_state = boss_processor_state.boss_states[boss_id]

        if boss_state then
            if boss_type == "lich_king" then
                local new_boss_state, delayed_spawns = lich_king.tick(dt, boss_state, boss_alive)
                updated_state.boss_states[boss_id] = new_boss_state

                -- Convert delayed spawns to spawn events
                for _, delayed_spawn in ipairs(delayed_spawns) do
                    table.insert(spawn_events, {
                        type = "DelayedSpawnEvent",
                        delay_sec = delayed_spawn.t_left_sec,
                        enemy_def_id = delayed_spawn.def_id,
                        source_boss_id = boss_id
                    })
                end

            elseif boss_type == "swarm_queen" then
                local new_boss_state, spawn_list = swarm_queen.tick(dt, boss_state, boss_alive)
                updated_state.boss_states[boss_id] = new_boss_state

                -- Convert spawn list to spawn events
                for _, spawn_data in ipairs(spawn_list) do
                    table.insert(spawn_events, {
                        type = "SpawnEnemyEvent",
                        enemy_def_id = spawn_data.def_id,
                        spawn_delay = 0,
                        source_boss_id = boss_id
                    })
                end
            else
                -- Unknown boss type, just copy state
                updated_state.boss_states[boss_id] = boss_state
            end
        end
    end

    return updated_state, spawn_events
end

--- Add a new boss to the processing state
--- @param boss_processor_state table Current processor state
--- @param boss_entity table Boss entity with enemy_id and def_id
--- @return table Updated processor state
function boss_event_processor.add_boss(boss_processor_state, boss_entity)
    local updated_state = {
        boss_states = {},
        active_boss_ids = {}
    }

    -- Copy existing state
    for boss_id, boss_state in pairs(boss_processor_state.boss_states) do
        updated_state.boss_states[boss_id] = boss_state
    end
    for boss_id, boss_type in pairs(boss_processor_state.active_boss_ids) do
        updated_state.active_boss_ids[boss_id] = boss_type
    end

    -- Add new boss
    local boss_id = boss_entity.enemy_id
    local boss_def_id = boss_entity.def_id

    if boss_def_id == "lich_king" then
        updated_state.boss_states[boss_id] = lich_king.init(boss_id)
        updated_state.active_boss_ids[boss_id] = "lich_king"
    elseif boss_def_id == "swarm_queen" then
        updated_state.boss_states[boss_id] = swarm_queen.init(boss_id)
        updated_state.active_boss_ids[boss_id] = "swarm_queen"
    end

    return updated_state
end

--- Remove a boss from the processing state (when boss dies)
--- @param boss_processor_state table Current processor state
--- @param boss_id number Boss ID to remove
--- @return table Updated processor state
function boss_event_processor.remove_boss(boss_processor_state, boss_id)
    local updated_state = {
        boss_states = {},
        active_boss_ids = {}
    }

    -- Copy state excluding the removed boss
    for id, boss_state in pairs(boss_processor_state.boss_states) do
        if id ~= boss_id then
            updated_state.boss_states[id] = boss_state
        end
    end
    for id, boss_type in pairs(boss_processor_state.active_boss_ids) do
        if id ~= boss_id then
            updated_state.active_boss_ids[id] = boss_type
        end
    end

    return updated_state
end

--- Get summary of boss processing state
--- @param boss_processor_state table Processor state
--- @return table Summary information
function boss_event_processor.get_summary(boss_processor_state)
    local summary = {
        active_boss_count = 0,
        boss_types = {},
        boss_details = {}
    }

    for boss_id, boss_type in pairs(boss_processor_state.active_boss_ids) do
        summary.active_boss_count = summary.active_boss_count + 1
        summary.boss_types[boss_type] = (summary.boss_types[boss_type] or 0) + 1

        local boss_state = boss_processor_state.boss_states[boss_id]
        summary.boss_details[boss_id] = {
            type = boss_type,
            state = boss_state
        }
    end

    return summary
end

--- Validate enemy_dead event structure
--- @param event table Event to validate
--- @return boolean True if event is valid
function boss_event_processor._is_valid_enemy_dead_event(event)
    return event and
           event.type == "enemy_dead" and
           event.def_id and
           event.enemy_id
end

--- Test lich king raise processing
--- @return boolean True if lich king raise logic works correctly
function boss_event_processor.test_lich_king_raises()
    -- Mock enemy definitions
    local enemy_defs = {
        goblin = { id = "goblin", tags = {} },
        lich_king = { id = "lich_king", tags = {"boss"} }
    }

    -- Create processor state with lich king
    local lich_boss = { enemy_id = 2001, def_id = "lich_king" }
    local processor_state = boss_event_processor.create_state({lich_boss})

    -- Create enemy death events
    local death_events = {
        { type = "enemy_dead", enemy_id = 1001, def_id = "goblin" },
        { type = "enemy_dead", enemy_id = 1002, def_id = "goblin" },
        { type = "enemy_dead", enemy_id = 2001, def_id = "lich_king" } -- Boss dies
    }

    local alive_bosses = { [2001] = true } -- Lich king is alive initially

    -- Process death events
    local updated_state = boss_event_processor.process_enemy_dead_events(
        death_events, processor_state, enemy_defs, alive_bosses)

    -- Check that lich king queued raises for goblins but not for itself
    local lich_state = updated_state.boss_states[2001]
    if not lich_state or lich_state.queued_raises ~= 2 then
        return false
    end

    -- Tick to generate spawn events
    local final_state, spawn_events = boss_event_processor.tick(0.1, updated_state, alive_bosses)

    -- Should generate 2 delayed spawn events for skeletons
    if #spawn_events ~= 2 then
        return false
    end

    for _, event in ipairs(spawn_events) do
        if event.type ~= "DelayedSpawnEvent" or
           event.enemy_def_id ~= "skeleton" or
           event.source_boss_id ~= 2001 then
            return false
        end
    end

    return true
end

--- Test boss lifecycle (add/remove)
--- @return boolean True if boss lifecycle works correctly
function boss_event_processor.test_boss_lifecycle()
    -- Start with empty state
    local processor_state = boss_event_processor.create_state({})

    -- Add lich king
    local lich_boss = { enemy_id = 3001, def_id = "lich_king" }
    processor_state = boss_event_processor.add_boss(processor_state, lich_boss)

    -- Check lich king was added
    if not processor_state.active_boss_ids[3001] or
       processor_state.active_boss_ids[3001] ~= "lich_king" then
        return false
    end

    -- Add swarm queen
    local swarm_boss = { enemy_id = 3002, def_id = "swarm_queen" }
    processor_state = boss_event_processor.add_boss(processor_state, swarm_boss)

    -- Check both bosses are active
    if not processor_state.active_boss_ids[3002] or
       processor_state.active_boss_ids[3002] ~= "swarm_queen" then
        return false
    end

    -- Remove lich king
    processor_state = boss_event_processor.remove_boss(processor_state, 3001)

    -- Check lich king is gone but swarm queen remains
    if processor_state.active_boss_ids[3001] or
       not processor_state.active_boss_ids[3002] then
        return false
    end

    return true
end

return boss_event_processor