-- assets/scripts/serpent/ui/hud.lua
--[[
    HUD (Heads-Up Display) UI Module

    Provides view-model data and display helpers for real-time game information
    during combat mode including wave progress, health, gold, and game stats.
]]

local synergy_system = require("serpent.synergy_system")
local snake_logic = require("serpent.snake_logic")

local hud = {}

-- Track HUD visibility and state
hud.isVisible = false
hud.lastUpdateTime = 0

--- Initialize HUD UI
function hud.init()
    hud.isVisible = false
    hud.lastUpdateTime = love.timer and love.timer.getTime() or 0
end

--- Get view model data for combat HUD
--- @param game_state table Current game state with snake, wave, combat data
--- @param player_state table Player state with gold, stats
--- @return table HUD view model with display data
function hud.get_combat_view_model(game_state, player_state)
    local view_model = {
        -- Wave information
        wave_info = hud._get_wave_info(game_state),

        -- Snake/health information
        snake_info = hud._get_snake_info(game_state),

        -- Player resources
        player_info = hud._get_player_info(player_state),

        -- Combat status
        combat_info = hud._get_combat_info(game_state),

        -- Synergy display
        synergy_info = hud._get_synergy_info(game_state),

        -- Performance metrics
        performance = hud._get_performance_info()
    }

    return view_model
end

--- Get simplified view model for shop mode
--- @param player_state table Player state with gold, stats
--- @param snake_state table Current snake state
--- @return table Shop HUD view model
function hud.get_shop_view_model(player_state, snake_state)
    local view_model = {
        player_info = hud._get_player_info(player_state),
        snake_info = hud._get_snake_info({ snake_state = snake_state }),
        mode = "SHOP"
    }

    return view_model
end

--- Get wave progress and status information
--- @param game_state table Current game state
--- @return table Wave information
function hud._get_wave_info(game_state)
    local wave_info = {
        current_wave = 1,
        max_waves = 20,
        progress_percent = 0,
        enemies_remaining = 0,
        wave_complete = false,
        run_complete = false
    }

    -- Extract from wave director if available
    if game_state and game_state.wave_director then
        local director = game_state.wave_director
        wave_info.current_wave = director.current_wave or 1
        wave_info.max_waves = director.max_waves or 20
        wave_info.progress_percent = math.floor(((wave_info.current_wave - 1) / wave_info.max_waves) * 100)
        wave_info.wave_complete = director.wave_complete or false
        wave_info.run_complete = director.run_complete or false

        -- Calculate enemies remaining
        local spawned = director.enemies_spawned or 0
        local killed = director.enemies_killed or 0
        wave_info.enemies_remaining = math.max(0, spawned - killed)
    end

    return wave_info
end

--- Get snake health and status information
--- @param game_state table Current game state
--- @return table Snake information
function hud._get_snake_info(game_state)
    local snake_info = {
        current_length = 0,
        min_length = 3,
        max_length = 8,
        alive_segments = 0,
        health_percent = 100,
        is_alive = true
    }

    if game_state and game_state.snake_state then
        local snake_state = game_state.snake_state
        local segments = snake_state.segments or {}

        snake_info.current_length = #segments
        snake_info.min_length = snake_state.min_len or 3
        snake_info.max_length = snake_state.max_len or 8

        -- Count alive segments and calculate health
        local alive_count = 0
        local total_hp = 0
        local max_hp = 0

        for _, segment in ipairs(segments) do
            if segment and segment.hp and segment.hp > 0 then
                alive_count = alive_count + 1
                total_hp = total_hp + segment.hp
                max_hp = max_hp + (segment.hp_max_base or 100)
            end
        end

        snake_info.alive_segments = alive_count
        snake_info.is_alive = not snake_logic.is_dead(snake_state)

        if max_hp > 0 then
            snake_info.health_percent = math.floor((total_hp / max_hp) * 100)
        end
    end

    return snake_info
end

--- Get player resources and statistics
--- @param player_state table Player state
--- @return table Player information
function hud._get_player_info(player_state)
    local player_info = {
        gold = 0,
        total_gold_earned = 0,
        time_played = 0,
        kills = 0,
        waves_completed = 0,
        seed = 0
    }

    if player_state then
        player_info.gold = player_state.gold or 0
        player_info.total_gold_earned = player_state.total_gold_earned or 0
        player_info.time_played = player_state.time_played or 0
        player_info.kills = player_state.kills or 0
        player_info.waves_completed = player_state.waves_completed or 0
        player_info.seed = player_state.seed or player_state.run_seed or 0
    end

    return player_info
end

--- Get current combat status information
--- @param game_state table Current game state
--- @return table Combat information
function hud._get_combat_info(game_state)
    local combat_info = {
        enemies_active = 0,
        recent_damage = false,
        combat_active = false,
        victory = false,
        defeat = false
    }

    if game_state then
        -- Count active enemies
        if game_state.enemy_entities then
            combat_info.enemies_active = #game_state.enemy_entities
        end

        combat_info.combat_active = combat_info.enemies_active > 0

        -- Victory/defeat status
        if game_state.wave_director then
            combat_info.victory = game_state.wave_director.run_complete or false
        end

        if game_state.snake_state then
            combat_info.defeat = snake_logic.is_dead(game_state.snake_state)
        end
    end

    return combat_info
end

--- Get synergy status for display
--- @param game_state table Current game state
--- @return table Synergy information
function hud._get_synergy_info(game_state)
    local synergy_info = {
        class_counts = {},
        active_bonuses = {},
        total_bonuses = 0
    }

    if game_state and game_state.snake_state and game_state.unit_defs then
        local segments = game_state.snake_state.segments or {}
        local unit_defs = game_state.unit_defs

        -- Calculate synergy state
        local synergy_state = synergy_system.calculate(segments, unit_defs)
        local summary = synergy_system.get_synergy_summary(synergy_state)

        synergy_info.class_counts = summary.class_counts or {}
        synergy_info.active_bonuses = summary.active_synergies or {}
        synergy_info.total_bonuses = #synergy_info.active_bonuses
    end

    return synergy_info
end

--- Get performance metrics for debugging
--- @return table Performance information
function hud._get_performance_info()
    local current_time = love.timer and love.timer.getTime() or 0
    local dt = current_time - hud.lastUpdateTime
    hud.lastUpdateTime = current_time

    return {
        fps = math.floor(1 / (dt > 0 and dt or 0.016)),
        frame_time_ms = dt * 1000,
        memory_kb = math.floor(collectgarbage("count"))
    }
end

--- Show HUD
function hud.show()
    hud.isVisible = true
end

--- Hide HUD
function hud.hide()
    hud.isVisible = false
end

--- Toggle HUD visibility
function hud.toggle()
    hud.isVisible = not hud.isVisible
end

--- Check if HUD is visible
--- @return boolean True if HUD is visible
function hud.is_visible()
    return hud.isVisible
end

--- Format time in MM:SS format
--- @param seconds number Time in seconds
--- @return string Formatted time string
function hud.format_time(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d:%02d", minutes, secs)
end

--- Format number with commas
--- @param num number Number to format
--- @return string Formatted number string
function hud.format_number(num)
    local formatted = tostring(math.floor(num))
    -- Insert commas from right to left
    local result = ""
    local count = 0
    for i = #formatted, 1, -1 do
        if count > 0 and count % 3 == 0 then
            result = "," .. result
        end
        result = formatted:sub(i, i) .. result
        count = count + 1
    end
    return result
end

--- Get health color based on percentage
--- @param health_percent number Health percentage (0-100)
--- @return table Color RGB values
function hud.get_health_color(health_percent)
    if health_percent > 60 then
        return { r = 0, g = 255, b = 0 } -- Green
    elseif health_percent > 30 then
        return { r = 255, g = 255, b = 0 } -- Yellow
    else
        return { r = 255, g = 0, b = 0 } -- Red
    end
end

--- Get wave progress color
--- @param wave_num number Current wave number
--- @param max_waves number Maximum waves
--- @return table Color RGB values
function hud.get_wave_color(wave_num, max_waves)
    local progress = wave_num / max_waves
    if progress < 0.5 then
        return { r = 100, g = 150, b = 255 } -- Blue (early)
    elseif progress < 0.8 then
        return { r = 255, g = 200, b = 0 } -- Orange (mid)
    else
        return { r = 255, g = 100, b = 100 } -- Red (late)
    end
end

--- Cleanup HUD resources
function hud.cleanup()
    hud.isVisible = false
    hud.lastUpdateTime = 0
end

return hud