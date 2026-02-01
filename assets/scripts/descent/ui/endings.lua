-- assets/scripts/descent/ui/endings.lua
--[[
================================================================================
DESCENT ENDINGS UI FRAMEWORK
================================================================================
Framework for victory, death, and error screens.

Features:
- Victory screen (boss defeated)
- Death screen (player HP zero)
- Error screen (runtime errors)
- Shows: seed, turns, floor, kills, cause
- Return to menu with cleanup

Per PLAN.md H2:
- Framework for victory/death/error screens
- Shows seed, turns, floor, kills, cause
- Return to menu works with cleanup

Usage:
    local endings = require("descent.ui.endings")
    endings.show_victory(game_state)
    endings.show_death(game_state, "Killed by a goblin")
    endings.show_error(game_state, "Script error: ...")
================================================================================
]]

local Endings = {}

-- State
local _state = {
    active = false,
    type = nil,  -- "victory", "death", "error"
    data = nil,
    on_return = nil,
}

-- Screen types
Endings.TYPE = {
    VICTORY = "victory",
    DEATH = "death",
    ERROR = "error",
}

--------------------------------------------------------------------------------
-- Data Collection
--------------------------------------------------------------------------------

local function collect_stats(game_state)
    local stats = {
        seed = "unknown",
        turns = 0,
        floor = 1,
        kills = 0,
        time_played = 0,
    }
    
    if game_state then
        stats.seed = game_state.seed or stats.seed
        stats.floor = game_state.floor_num or stats.floor
        
        if game_state.player then
            stats.turns = game_state.player.turns_taken or stats.turns
            stats.kills = game_state.player.kills or stats.kills
            stats.level = game_state.player.level or 1
            stats.xp = game_state.player.xp or 0
        end
        
        if game_state.turn_count then
            stats.turns = game_state.turn_count
        end
    end
    
    return stats
end

--------------------------------------------------------------------------------
-- Screen Display Data
--------------------------------------------------------------------------------

local function create_victory_data(game_state)
    local stats = collect_stats(game_state)
    
    return {
        type = Endings.TYPE.VICTORY,
        title = "VICTORY!",
        subtitle = "You have defeated The Guardian!",
        stats = stats,
        message = string.format(
            "After %d turns and %d kills, you have conquered the dungeon!",
            stats.turns, stats.kills
        ),
        footer = "Press ENTER to return to menu",
    }
end

local function create_death_data(game_state, cause)
    local stats = collect_stats(game_state)
    
    return {
        type = Endings.TYPE.DEATH,
        title = "YOU DIED",
        subtitle = cause or "You have been slain.",
        stats = stats,
        message = string.format(
            "You reached floor %d after %d turns with %d kills.",
            stats.floor, stats.turns, stats.kills
        ),
        footer = "Press ENTER to return to menu",
    }
end

local function create_error_data(game_state, error_msg, stack_trace)
    local stats = collect_stats(game_state)

    if type(error_msg) == "table" then
        stack_trace = error_msg.stack or error_msg.trace or stack_trace
        error_msg = error_msg.message or error_msg.error or tostring(error_msg)
    end
    
    return {
        type = Endings.TYPE.ERROR,
        title = "ERROR",
        subtitle = "An error occurred during gameplay.",
        stats = stats,
        error = error_msg or "Unknown error",
        stack = stack_trace,
        message = string.format(
            "Game state: Floor %d, Turn %d. Your progress has been lost.",
            stats.floor, stats.turns
        ),
        footer = "Press ENTER to return to menu",
    }
end

--------------------------------------------------------------------------------
-- Seed Logging
--------------------------------------------------------------------------------

local function log_seed(ending_type, stats)
    local seed_str = tostring(stats.seed or "unknown")
    local floor_str = tostring(stats.floor or 1)
    local turns_str = tostring(stats.turns or 0)

    -- Log to terminal for reproduction
    local log_fn = (type(log_debug) == "function") and log_debug or print
    log_fn("================================================================================")
    log_fn("[Descent] " .. ending_type:upper() .. " - Run ended")
    log_fn("[Descent] Seed: " .. seed_str)
    log_fn("[Descent] Floor: " .. floor_str .. " | Turns: " .. turns_str)
    log_fn("[Descent] To replay: DESCENT_SEED=" .. seed_str .. " (or pass seed in options)")
    log_fn("================================================================================")
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function Endings.show_victory(game_state, on_return)
    local data = create_victory_data(game_state)
    log_seed("victory", data.stats)

    _state = {
        active = true,
        type = Endings.TYPE.VICTORY,
        data = data,
        on_return = on_return,
    }
end

function Endings.show_death(game_state, cause, on_return)
    local data = create_death_data(game_state, cause)
    log_seed("death", data.stats)

    _state = {
        active = true,
        type = Endings.TYPE.DEATH,
        data = data,
        on_return = on_return,
    }
end

function Endings.show_error(game_state, error_msg, on_return, stack_trace)
    local data = create_error_data(game_state, error_msg, stack_trace)
    log_seed("error", data.stats)

    _state = {
        active = true,
        type = Endings.TYPE.ERROR,
        data = data,
        on_return = on_return,
    }

    if os.getenv and os.getenv("RUN_DESCENT_TESTS") == "1" then
        os.exit(1)
    end
end

function Endings.is_active()
    return _state.active
end

function Endings.get_type()
    return _state.type
end

function Endings.get_data()
    return _state.data
end

function Endings.handle_input(key)
    if not _state.active then
        return false
    end
    
    if key == "return" or key == "enter" or key == "space" then
        Endings.return_to_menu()
        return true
    end
    
    return false
end

function Endings.return_to_menu()
    if _state.on_return then
        _state.on_return()
    end
    
    Endings.cleanup()
end

function Endings.cleanup()
    _state = {
        active = false,
        type = nil,
        data = nil,
        on_return = nil,
    }
end

--------------------------------------------------------------------------------
-- Rendering Data (for UI layer)
--------------------------------------------------------------------------------

function Endings.get_render_data()
    if not _state.active or not _state.data then
        return nil
    end
    
    local data = _state.data
    local lines = {}
    
    -- Title
    table.insert(lines, { text = data.title, style = "title" })
    table.insert(lines, { text = "", style = "spacer" })
    
    -- Subtitle
    table.insert(lines, { text = data.subtitle, style = "subtitle" })
    table.insert(lines, { text = "", style = "spacer" })
    
    -- Stats
    if data.stats then
        table.insert(lines, { text = "--- STATISTICS ---", style = "header" })
        table.insert(lines, { 
            text = string.format("Seed: %s", tostring(data.stats.seed)), 
            style = "stat" 
        })
        table.insert(lines, { 
            text = string.format("Floor: %d / 5", data.stats.floor), 
            style = "stat" 
        })
        table.insert(lines, { 
            text = string.format("Turns: %d", data.stats.turns), 
            style = "stat" 
        })
        table.insert(lines, { 
            text = string.format("Kills: %d", data.stats.kills), 
            style = "stat" 
        })
        if data.stats.level then
            table.insert(lines, { 
                text = string.format("Level: %d (XP: %d)", data.stats.level, data.stats.xp or 0), 
                style = "stat" 
            })
        end
        table.insert(lines, { text = "", style = "spacer" })
    end
    
    -- Error message (for error screens)
    if data.error then
        table.insert(lines, { text = "--- ERROR DETAILS ---", style = "header" })
        table.insert(lines, { text = data.error, style = "error" })
        if data.stack then
            table.insert(lines, { text = "", style = "spacer" })
            table.insert(lines, { text = "--- STACK TRACE ---", style = "header" })
            for line in tostring(data.stack):gmatch("([^\n]+)") do
                table.insert(lines, { text = line, style = "stack" })
            end
        end
        table.insert(lines, { text = "", style = "spacer" })
    end
    
    -- Message
    table.insert(lines, { text = data.message, style = "message" })
    table.insert(lines, { text = "", style = "spacer" })
    
    -- Footer
    table.insert(lines, { text = data.footer, style = "footer" })
    
    return {
        type = data.type,
        lines = lines,
        title = data.title,
        subtitle = data.subtitle,
        stats = data.stats,
    }
end

function Endings.format_for_log(data)
    if not data then
        data = _state.data
    end
    
    if not data then
        return ""
    end
    
    local parts = {
        "=== " .. data.title .. " ===",
        data.subtitle,
        "",
    }
    
    if data.stats then
        table.insert(parts, "Seed: " .. tostring(data.stats.seed))
        table.insert(parts, "Floor: " .. tostring(data.stats.floor))
        table.insert(parts, "Turns: " .. tostring(data.stats.turns))
        table.insert(parts, "Kills: " .. tostring(data.stats.kills))
    end
    
    if data.error then
        table.insert(parts, "")
        table.insert(parts, "Error: " .. data.error)
        if data.stack then
            table.insert(parts, "Stack:")
            for line in tostring(data.stack):gmatch("([^\n]+)") do
                table.insert(parts, line)
            end
        end
    end
    
    table.insert(parts, "")
    table.insert(parts, data.message)
    
    return table.concat(parts, "\n")
end

return Endings
