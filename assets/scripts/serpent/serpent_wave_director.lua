-- assets/scripts/serpent/serpent_wave_director.lua
--[[
    Serpent Wave Director Module

    Manages the 20-wave progression system for the Serpent minigame.
    Handles wave state, enemy spawning, boss injection, and victory/defeat conditions.
]]

local wave_config = require("serpent.wave_config")

local serpent_wave_director = {}

--- Initialize a new wave director state
--- @param starting_wave number Starting wave number (default 1)
--- @return table Wave director state
function serpent_wave_director.create_state(starting_wave)
    return {
        current_wave = starting_wave or 1,
        max_waves = 20,
        enemies_spawned = 0,
        enemies_killed = 0,
        spawning_complete = false,
        wave_complete = false,
        run_complete = false,
        total_gold_earned = 0,
        total_time_sec = 0.0
    }
end

--- Start a new wave
--- @param state table Wave director state
--- @param enemy_defs table Enemy definitions
--- @param rng table RNG instance for deterministic spawning
--- @return table Updated state, array of spawn events
function serpent_wave_director.start_wave(state, enemy_defs, rng)
    if not state or state.run_complete then
        return state, {}
    end

    local current_wave = state.current_wave
    local spawn_events = {}

    -- Validate wave number
    local valid, error_msg = wave_config.validate_wave(current_wave)
    if not valid then
        log_error("[SerpentWaveDirector] " .. error_msg)
        return state, {}
    end

    -- Calculate wave parameters
    local enemy_count = wave_config.enemy_count(current_wave)
    local hp_mult = wave_config.hp_mult(current_wave)
    local dmg_mult = wave_config.dmg_mult(current_wave)

    -- Get enemy pool for this wave (excludes bosses)
    local enemy_pool = wave_config.get_pool(current_wave, enemy_defs)

    if #enemy_pool == 0 then
        log_error("[SerpentWaveDirector] No enemies available for wave " .. current_wave)
        return state, {}
    end

    -- Generate regular enemy spawns
    for i = 1, enemy_count do
        local enemy_id = enemy_pool[(rng and rng:int(1, #enemy_pool)) or math.random(1, #enemy_pool)]
        table.insert(spawn_events, {
            type = "SpawnEnemyEvent",
            enemy_id = enemy_id,
            hp_mult = hp_mult,
            dmg_mult = dmg_mult,
            spawn_delay = (i - 1) * 0.1 -- Stagger spawning by 0.1 seconds
        })
    end

    -- Inject boss enemies at specific waves
    if current_wave == 10 then
        table.insert(spawn_events, {
            type = "SpawnEnemyEvent",
            enemy_id = "swarm_queen",
            hp_mult = hp_mult,
            dmg_mult = dmg_mult,
            is_boss = true,
            spawn_delay = enemy_count * 0.1 + 0.5 -- Spawn boss after regular enemies
        })
    elseif current_wave == 20 then
        table.insert(spawn_events, {
            type = "SpawnEnemyEvent",
            enemy_id = "lich_king",
            hp_mult = hp_mult,
            dmg_mult = dmg_mult,
            is_boss = true,
            spawn_delay = enemy_count * 0.1 + 0.5
        })
    end

    -- Update state
    local updated_state = {}
    for k, v in pairs(state) do
        updated_state[k] = v
    end
    updated_state.enemies_spawned = #spawn_events
    updated_state.spawning_complete = false
    updated_state.wave_complete = false

    return updated_state, spawn_events
end

--- Mark spawning as complete for the current wave
--- @param state table Wave director state
--- @return table Updated state
function serpent_wave_director.complete_spawning(state)
    local updated_state = {}
    for k, v in pairs(state) do
        updated_state[k] = v
    end
    updated_state.spawning_complete = true
    return updated_state
end

--- Handle enemy death and check wave completion
--- @param state table Wave director state
--- @param enemy_id string ID of killed enemy
--- @return table Updated state, boolean wave_cleared, table completion_data
function serpent_wave_director.on_enemy_killed(state, enemy_id)
    if not state then
        return state, false, {}
    end

    local updated_state = {}
    for k, v in pairs(state) do
        updated_state[k] = v
    end
    updated_state.enemies_killed = updated_state.enemies_killed + 1

    -- Check if wave is complete (all enemies spawned and killed)
    local wave_cleared = updated_state.spawning_complete and
                        updated_state.enemies_killed >= updated_state.enemies_spawned

    local completion_data = {}

    if wave_cleared then
        updated_state.wave_complete = true

        -- Calculate gold reward
        local gold_reward = wave_config.gold_reward(updated_state.current_wave)
        updated_state.total_gold_earned = updated_state.total_gold_earned + gold_reward

        completion_data = {
            wave_cleared = true,
            wave_num = updated_state.current_wave,
            gold_reward = gold_reward,
            enemies_killed = updated_state.enemies_killed
        }

        -- Check if run is complete
        if updated_state.current_wave >= updated_state.max_waves then
            updated_state.run_complete = true
            completion_data.run_complete = true
        end
    end

    return updated_state, wave_cleared, completion_data
end

--- Advance to the next wave
--- @param state table Wave director state
--- @return table Updated state
function serpent_wave_director.advance_wave(state)
    if not state or state.run_complete then
        return state
    end

    local updated_state = {}
    for k, v in pairs(state) do
        updated_state[k] = v
    end

    updated_state.current_wave = updated_state.current_wave + 1
    updated_state.enemies_spawned = 0
    updated_state.enemies_killed = 0
    updated_state.spawning_complete = false
    updated_state.wave_complete = false

    return updated_state
end

--- Check if the run should end in victory
--- @param state table Wave director state
--- @return boolean True if victory conditions met
function serpent_wave_director.is_victory(state)
    return state and state.run_complete and state.current_wave > state.max_waves
end

--- Get wave progress summary
--- @param state table Wave director state
--- @return table Progress summary
function serpent_wave_director.get_progress(state)
    if not state then
        return {
            current_wave = 1,
            max_waves = 20,
            progress_percent = 0,
            enemies_progress = "0/0"
        }
    end

    return {
        current_wave = state.current_wave,
        max_waves = state.max_waves,
        progress_percent = math.floor((state.current_wave - 1) / state.max_waves * 100),
        enemies_progress = string.format("%d/%d", state.enemies_killed, state.enemies_spawned),
        spawning_complete = state.spawning_complete,
        wave_complete = state.wave_complete,
        run_complete = state.run_complete,
        total_gold_earned = state.total_gold_earned
    }
end

--- Check if the director has finished spawning all pending enemies
--- @param state table Wave director state
--- @return boolean True when pending_count == 0
function serpent_wave_director.is_done_spawning(state)
    return state and state.pending_count == 0
end

--- Get wave scaling summary for current wave
--- @param state table Wave director state
--- @return table Wave scaling data
function serpent_wave_director.get_wave_scaling(state)
    local current_wave = state and state.current_wave or 1
    return wave_config.get_wave_summary(current_wave)
end

--- Reset wave director for a new run
--- @param starting_wave number Starting wave (default 1)
--- @return table Fresh wave director state
function serpent_wave_director.reset(starting_wave)
    return serpent_wave_director.create_state(starting_wave)
end

--- Tick function for continuous wave director updates
--- @param dt number Delta time in seconds
--- @param director_state table Wave director state
--- @param id_state table ID allocation state for unique entity IDs
--- @param rng table RNG instance for spawning
--- @param combat_events table Array of combat events to process
--- @param alive_set table Set of alive enemy IDs
--- @return table Array of spawn events to emit
function serpent_wave_director.tick(dt, director_state, id_state, rng, combat_events, alive_set)
    local spawn_events = {}

    if not director_state or director_state.run_complete then
        return spawn_events
    end

    -- Process combat events (enemy deaths, damage, etc.)
    local updated_director_state = director_state
    for _, event in ipairs(combat_events or {}) do
        if event.type == "EnemyDeathEvent" then
            local enemy_id = event.enemy_id
            updated_director_state = serpent_wave_director._process_enemy_death(
                updated_director_state, enemy_id, alive_set)
        end
    end

    -- Update internal timers
    updated_director_state.total_time_sec = updated_director_state.total_time_sec + dt

    -- Check if wave needs to be started
    if not updated_director_state.spawning_complete and
       not updated_director_state.wave_complete then

        -- Generate timed spawns if we have a spawn queue
        local timed_spawns = serpent_wave_director._generate_timed_spawns(
            dt, updated_director_state, id_state, rng)

        for _, spawn_event in ipairs(timed_spawns) do
            table.insert(spawn_events, spawn_event)
        end
    end

    return spawn_events
end

--- Process enemy death events within tick
--- @param director_state table Current director state
--- @param enemy_id number Enemy ID that died
--- @param alive_set table Set of alive enemies
--- @return table Updated director state
function serpent_wave_director._process_enemy_death(director_state, enemy_id, alive_set)
    -- Remove from alive set
    if alive_set then
        alive_set[enemy_id] = nil
    end

    -- Update kill count
    local updated_state, wave_cleared, completion_data = serpent_wave_director.on_enemy_killed(
        director_state, enemy_id)

    -- Handle wave completion
    if wave_cleared then
        log_debug("[SerpentWaveDirector] Wave " .. updated_state.current_wave .. " completed")

        -- If not the final wave, prepare for next wave
        if not updated_state.run_complete then
            updated_state = serpent_wave_director.advance_wave(updated_state)
            log_debug("[SerpentWaveDirector] Advanced to wave " .. updated_state.current_wave)
        end
    end

    return updated_state
end

--- Generate timed spawn events based on wave progression
--- @param dt number Delta time
--- @param director_state table Director state
--- @param id_state table ID allocation state
--- @param rng table RNG instance
--- @return table Array of spawn events
function serpent_wave_director._generate_timed_spawns(dt, director_state, id_state, rng)
    local spawn_events = {}

    -- Initialize spawn timing if not present
    if not director_state.spawn_timer then
        director_state.spawn_timer = 0.0
        director_state.enemies_spawned_count = 0
        director_state.spawn_queue = nil
    end

    -- Generate spawn queue if we don't have one
    if not director_state.spawn_queue then
        director_state.spawn_queue = serpent_wave_director._create_spawn_queue(
            director_state.current_wave, rng)
    end

    -- Update spawn timer
    director_state.spawn_timer = director_state.spawn_timer + dt

    -- Check if it's time to spawn the next enemy
    local spawn_interval = 0.5 -- Spawn every 0.5 seconds
    local enemies_to_spawn = math.floor(director_state.spawn_timer / spawn_interval)

    for i = 1, enemies_to_spawn do
        if director_state.enemies_spawned_count < #director_state.spawn_queue then
            director_state.enemies_spawned_count = director_state.enemies_spawned_count + 1
            local spawn_data = director_state.spawn_queue[director_state.enemies_spawned_count]

            -- Allocate unique ID if id_state is available
            local entity_id = nil
            if id_state and id_state.next_id then
                entity_id = id_state.next_id
                id_state.next_id = id_state.next_id + 1
            else
                entity_id = os.time() + director_state.enemies_spawned_count
            end

            table.insert(spawn_events, {
                type = "SpawnEnemyEvent",
                entity_id = entity_id,
                enemy_id = spawn_data.enemy_id,
                hp_mult = spawn_data.hp_mult,
                dmg_mult = spawn_data.dmg_mult,
                is_boss = spawn_data.is_boss or false
            })

            director_state.spawn_timer = director_state.spawn_timer - spawn_interval
        else
            -- All enemies spawned for this wave
            director_state.spawning_complete = true
            break
        end
    end

    return spawn_events
end

--- Create spawn queue for a wave
--- @param wave_num number Wave number
--- @param rng table RNG instance
--- @return table Array of spawn data entries
function serpent_wave_director._create_spawn_queue(wave_num, rng)
    local spawn_queue = {}

    -- Get wave parameters
    local enemy_count = wave_config.enemy_count(wave_num)
    local hp_mult = wave_config.hp_mult(wave_num)
    local dmg_mult = wave_config.dmg_mult(wave_num)

    -- For now, create a simple enemy selection
    -- This should eventually integrate with wave_logic.start_wave
    local basic_enemies = {"slime", "bat", "goblin", "orc", "skeleton"}

    for i = 1, enemy_count do
        local enemy_id = rng:choice(basic_enemies)
        table.insert(spawn_queue, {
            enemy_id = enemy_id,
            hp_mult = hp_mult,
            dmg_mult = dmg_mult,
            is_boss = false
        })
    end

    -- Add boss at specific waves
    if wave_num == 10 then
        table.insert(spawn_queue, {
            enemy_id = "swarm_queen",
            hp_mult = hp_mult,
            dmg_mult = dmg_mult,
            is_boss = true
        })
    elseif wave_num == 20 then
        table.insert(spawn_queue, {
            enemy_id = "lich_king",
            hp_mult = hp_mult,
            dmg_mult = dmg_mult,
            is_boss = true
        })
    end

    return spawn_queue
end

return serpent_wave_director
