-- assets/scripts/combat/wave_director.lua
-- Core orchestrator for wave-based gameplay

local signal = require("external.hump.signal")
local timer = require("core.timer")
local entity_cache = require("core.entity_cache")

local WaveHelpers = require("combat.wave_helpers")
local EnemyFactory = require("combat.enemy_factory")
local generators = require("combat.wave_generators")
local elite_modifiers = require("data.elite_modifiers")

-- Load visual handlers (registers signal listeners for show_floating_text, etc.)
require("combat.wave_visuals")

local WaveDirector = {}

--============================================
-- STATE
--============================================

local state = {
    current_stage = nil,
    current_wave_index = 0,
    waves = {},
    alive_enemies = {},
    spawning_complete = false,
    stage_complete = false,
    paused = false,
}

-- External reference to stage provider (set by game code)
WaveDirector.stage_provider = nil

--============================================
-- PUBLIC API
--============================================

function WaveDirector.start_stage(stage_config)
    if not stage_config then
        print("WaveDirector.start_stage called with nil config")
        return
    end

    state.current_stage = stage_config
    state.current_wave_index = 0
    state.alive_enemies = {}
    state.spawning_complete = false
    state.stage_complete = false
    state.paused = false

    -- Generate waves if using wave_generator
    if stage_config.wave_generator then
        state.waves = generators.from_budget(stage_config.wave_generator)
    elseif stage_config.waves then
        state.waves = {}
        for _, wave in ipairs(stage_config.waves) do
            table.insert(state.waves, generators.normalize_wave(wave))
        end
    else
        state.waves = {}
    end

    signal.emit("stage_started", stage_config)
    WaveDirector.start_next_wave()
end

function WaveDirector.start_next_wave()
    if state.paused then return end

    state.current_wave_index = state.current_wave_index + 1
    state.spawning_complete = false

    local wave = state.waves[state.current_wave_index]

    if not wave then
        -- All waves done, spawn elite if configured
        if state.current_stage.elite then
            WaveDirector.spawn_elite()
        else
            WaveDirector.complete_stage()
        end
        return
    end

    -- Announce wave
    local waveLabel = localization.get("ui.wave_label")
    WaveHelpers.show_floating_text(waveLabel .. " " .. state.current_wave_index, { style = "wave_announce" })
    signal.emit("wave_started", state.current_wave_index, wave)

    -- Get spawn positions
    local spawn_config = state.current_stage.spawn or "around_player"
    local enemies = wave.enemies or {}
    local positions = WaveHelpers.get_spawn_positions(spawn_config, #enemies)

    -- Telegraph then spawn each enemy
    local delay_between = wave.delay_between or 0.5
    local telegraph_duration = wave.telegraph_duration or 1.0
    local spawn_buffer = 0.1  -- Small buffer after telegraph completes

    for i, enemy_type in ipairs(enemies) do
        local pos = positions[i]
        local spawn_delay = (i - 1) * delay_between

        -- Show telegraph first
        timer.after(spawn_delay, function()
            if state.paused then return end
            WaveHelpers.spawn_telegraph(pos, enemy_type, telegraph_duration)
        end, "wave_telegraph_" .. i)

        -- Spawn AFTER telegraph completes (duration + buffer)
        timer.after(spawn_delay + telegraph_duration + spawn_buffer, function()
            if state.paused then return end
            WaveDirector.spawn_enemy(enemy_type, pos)
        end, "wave_spawn_" .. i)
    end

    -- Mark spawning complete after last enemy
    local total_spawn_time = (#enemies - 1) * delay_between + telegraph_duration + spawn_buffer
    timer.after(total_spawn_time + 0.1, function()
        state.spawning_complete = true
        WaveDirector.check_wave_complete()
    end, "wave_spawn_complete")
end

function WaveDirector.spawn_enemy(enemy_type, position, modifiers)
    modifiers = modifiers or {}
    local e, ctx = EnemyFactory.spawn(enemy_type, position, modifiers)
    if e and ctx then
        state.alive_enemies[e] = ctx
    end
    return e, ctx
end

function WaveDirector.spawn_elite()
    WaveHelpers.show_floating_text("Elite Incoming!", { style = "elite_announce" })

    local elite_config = state.current_stage.elite
    local pos = WaveHelpers.get_spawn_positions("around_player", 1)[1]

    -- Telegraph elite (longer warning)
    local elite_telegraph_duration = 1.5
    WaveHelpers.spawn_telegraph(pos, "elite", elite_telegraph_duration)

    -- Spawn after telegraph completes
    timer.after(elite_telegraph_duration + 0.1, function()
        if state.paused then return end

        local enemy_type, modifiers

        if type(elite_config) == "string" then
            -- Unique elite type
            enemy_type = elite_config
            modifiers = {}
        elseif elite_config.base then
            -- Modified regular enemy
            enemy_type = elite_config.base
            if elite_config.modifiers then
                modifiers = elite_config.modifiers
            elseif elite_config.modifier_count then
                modifiers = elite_modifiers.roll_random(elite_config.modifier_count)
            else
                modifiers = elite_modifiers.roll_random(2)
            end
        else
            print("Invalid elite config")
            WaveDirector.complete_stage()
            return
        end

        local e, ctx = WaveDirector.spawn_enemy(enemy_type, pos, modifiers)
        state.spawning_complete = true

        if e and ctx then
            signal.emit("elite_spawned", e, ctx)
        end
    end, "elite_spawn")
end

function WaveDirector.on_enemy_killed(e)
    if not state.alive_enemies[e] then return end

    state.alive_enemies[e] = nil
    WaveDirector.check_wave_complete()
end

function WaveDirector.check_wave_complete()
    if state.paused then return end
    if not state.spawning_complete then return end
    if next(state.alive_enemies) ~= nil then return end -- still enemies alive

    -- Check if we just finished the elite (last thing in stage)
    if state.current_wave_index >= #state.waves then
        -- All waves done
        if state.current_stage.elite then
            -- Elite was spawned and killed
            WaveDirector.complete_stage()
        else
            WaveDirector.complete_stage()
        end
    else
        -- More waves to go
        signal.emit("wave_cleared", state.current_wave_index)

        local wave_advance = state.current_stage.wave_advance or "on_clear"
        local delay = 1.0

        if type(wave_advance) == "number" then
            delay = wave_advance
        elseif wave_advance == "on_spawn_complete" then
            delay = 0.1
        end

        timer.after(delay, function()
            WaveDirector.start_next_wave()
        end, "wave_advance")
    end
end

function WaveDirector.complete_stage()
    if state.stage_complete then return end
    state.stage_complete = true

    WaveHelpers.show_floating_text("Stage Complete!", { style = "stage_complete" })

    local results = {
        stage = state.current_stage.id,
        waves_completed = state.current_wave_index,
    }

    signal.emit("stage_completed", results)

    -- Handle transition after delay
    timer.after(1.5, function()
        WaveDirector.handle_transition(results)
    end, "stage_transition")
end

function WaveDirector.handle_transition(results)
    local stage = state.current_stage

    if stage.on_complete then
        -- Custom callback
        stage.on_complete(results)
    elseif stage.show_reward then
        -- Show reward then continue
        signal.emit("show_rewards", results, function()
            if stage.next then
                WaveDirector.go_to(stage.next)
            elseif WaveDirector.stage_provider then
                local next_stage = WaveDirector.stage_provider.next()
                if next_stage then
                    WaveDirector.start_stage(next_stage)
                else
                    signal.emit("run_complete")
                end
            end
        end)
    elseif stage.next then
        WaveDirector.go_to(stage.next)
    elseif WaveDirector.stage_provider then
        local next_stage = WaveDirector.stage_provider.next()
        if next_stage then
            WaveDirector.start_stage(next_stage)
        else
            signal.emit("run_complete")
        end
    else
        signal.emit("run_complete")
    end
end

function WaveDirector.go_to(target)
    if target == "shop" then
        signal.emit("goto_shop")
    elseif target == "rewards" then
        signal.emit("goto_rewards")
    else
        -- Assume it's a stage ID
        if WaveDirector.stage_provider then
            local stage = WaveDirector.stage_provider.get(target)
            if stage then
                WaveDirector.start_stage(stage)
                return
            end
        end
        print("Unknown go_to target: " .. tostring(target))
    end
end

function WaveDirector.pause()
    state.paused = true
end

function WaveDirector.resume()
    state.paused = false
end

function WaveDirector.get_alive_count()
    local count = 0
    for _ in pairs(state.alive_enemies) do
        count = count + 1
    end
    return count
end

function WaveDirector.get_state()
    return {
        stage_id = state.current_stage and state.current_stage.id,
        wave_index = state.current_wave_index,
        total_waves = #state.waves,
        alive_enemies = WaveDirector.get_alive_count(),
        spawning_complete = state.spawning_complete,
        stage_complete = state.stage_complete,
        paused = state.paused,
    }
end

function WaveDirector.cleanup()
    -- Kill all remaining enemies
    for e, _ in pairs(state.alive_enemies) do
        if entity_cache.valid(e) then
            registry:destroy(e)
        end
    end
    state.alive_enemies = {}

    -- Cancel all wave timers
    for i = 1, 50 do
        timer.cancel("wave_telegraph_" .. i)
        timer.cancel("wave_spawn_" .. i)
    end
    timer.cancel("wave_spawn_complete")
    timer.cancel("wave_advance")
    timer.cancel("elite_spawn")
    timer.cancel("stage_transition")
end

--============================================
-- SIGNAL LISTENERS
--============================================

signal.register("enemy_killed", function(e, ctx)
    WaveDirector.on_enemy_killed(e)
end)

-- Handle summoned enemies (add to tracking)
signal.register("summon_enemy", function(data)
    local e, ctx = WaveDirector.spawn_enemy(data.type, { x = data.x, y = data.y })
    -- Summoned enemies are tracked just like regular enemies
end)

return WaveDirector
