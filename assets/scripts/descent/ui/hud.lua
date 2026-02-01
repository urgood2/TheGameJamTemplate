-- assets/scripts/descent/ui/hud.lua
--[[
================================================================================
DESCENT HUD
================================================================================
Displays essential game state information:
- Seed (for reproducibility/bug reports)
- Floor number
- Turn count
- Player position (x, y)

Per PLAN.md §2.2: HUD must always show seed/floor/turn/pos.
On death/victory/error: seed, final_floor, turns, kills, cause must be shown.

Usage:
    local hud = require("descent.ui.hud")
    hud.init()
    hud.update({ seed = 12345, floor = 1, turn = 0, pos = {x = 5, y = 5} })
    hud.render()  -- Called each frame
================================================================================
]]

local HUD = {}

-- State
local _state = {
    seed = nil,
    floor = 1,
    turn = 0,
    pos = { x = 0, y = 0 },
    hp = nil,
    hp_max = nil,
    mp = nil,
    mp_max = nil,
    gold = nil,
    xp = nil,
    level = nil,
}

local _visible = true
local _initialized = false

-- UI configuration
local CONFIG = {
    position = { x = 10, y = 10 },
    font_size = 16,
    line_height = 20,
    padding = 5,
    background_alpha = 0.7,
    text_color = { r = 255, g = 255, b = 255, a = 255 },
    label_color = { r = 180, g = 180, b = 180, a = 255 },
    value_color = { r = 255, g = 220, b = 100, a = 255 },
}

--------------------------------------------------------------------------------
-- Internal Helpers
--------------------------------------------------------------------------------

--- Format position as string
--- @param pos table Position with x, y fields
--- @return string Formatted position
local function format_pos(pos)
    if not pos then return "?,?" end
    return string.format("%d,%d", pos.x or 0, pos.y or 0)
end

--- Get current seed from RNG module if available
--- @return number|nil Current seed
local function get_rng_seed()
    local ok, rng = pcall(require, "descent.rng")
    if ok and rng and rng.get_seed then
        return rng.get_seed()
    end
    return nil
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Initialize the HUD
--- @param config table|nil Optional configuration overrides
function HUD.init(config)
    if config then
        for k, v in pairs(config) do
            if CONFIG[k] ~= nil then
                CONFIG[k] = v
            end
        end
    end
    
    _initialized = true
    _visible = true
    
    -- Try to get seed from RNG if not set
    if not _state.seed then
        _state.seed = get_rng_seed()
    end
end

--- Update HUD state
--- @param state table State update with any of: seed, floor, turn, pos, hp, mp, gold, xp, level
function HUD.update(state)
    if not state then return end
    
    for k, v in pairs(state) do
        if _state[k] ~= nil or k == "pos" then
            _state[k] = v
        end
    end
    
    -- Auto-fetch seed if not provided
    if not _state.seed then
        _state.seed = get_rng_seed()
    end
end

--- Set a single state value
--- @param key string State key
--- @param value any State value
function HUD.set(key, value)
    _state[key] = value
end

--- Get current HUD state
--- @return table Current state
function HUD.get_state()
    return {
        seed = _state.seed,
        floor = _state.floor,
        turn = _state.turn,
        pos = _state.pos and { x = _state.pos.x, y = _state.pos.y } or nil,
        hp = _state.hp,
        hp_max = _state.hp_max,
        mp = _state.mp,
        mp_max = _state.mp_max,
        gold = _state.gold,
        xp = _state.xp,
        level = _state.level,
    }
end

--- Show the HUD
function HUD.show()
    _visible = true
end

--- Hide the HUD
function HUD.hide()
    _visible = false
end

--- Toggle HUD visibility
--- @return boolean New visibility state
function HUD.toggle()
    _visible = not _visible
    return _visible
end

--- Check if HUD is visible
--- @return boolean Visibility state
function HUD.is_visible()
    return _visible
end

--- Reset HUD state to defaults
function HUD.reset()
    _state = {
        seed = nil,
        floor = 1,
        turn = 0,
        pos = { x = 0, y = 0 },
        hp = nil,
        hp_max = nil,
        mp = nil,
        mp_max = nil,
        gold = nil,
        xp = nil,
        level = nil,
    }
end

--- Build text lines for HUD display
--- @return table Array of {label, value} pairs
function HUD.build_lines()
    local lines = {}
    
    -- Required fields per PLAN.md
    table.insert(lines, { "Seed", tostring(_state.seed or "?") })
    table.insert(lines, { "Floor", tostring(_state.floor or 1) })
    table.insert(lines, { "Turn", tostring(_state.turn or 0) })
    table.insert(lines, { "Pos", format_pos(_state.pos) })
    
    -- Optional fields
    if _state.hp and _state.hp_max then
        table.insert(lines, { "HP", string.format("%d/%d", _state.hp, _state.hp_max) })
    end
    if _state.mp and _state.mp_max then
        table.insert(lines, { "MP", string.format("%d/%d", _state.mp, _state.mp_max) })
    end
    if _state.gold then
        table.insert(lines, { "Gold", tostring(_state.gold) })
    end
    if _state.level and _state.xp then
        table.insert(lines, { "Level", string.format("%d (%d XP)", _state.level, _state.xp) })
    elseif _state.level then
        table.insert(lines, { "Level", tostring(_state.level) })
    end
    
    return lines
end

--- Render the HUD (placeholder - actual rendering depends on engine)
--- In-engine, this would use the DSL or ImGui
--- For testing, returns the formatted text
--- @return string Formatted HUD text
function HUD.render()
    if not _visible then
        return ""
    end
    
    local lines = HUD.build_lines()
    local output = {}
    
    for _, line in ipairs(lines) do
        table.insert(output, string.format("%s: %s", line[1], line[2]))
    end
    
    return table.concat(output, "\n")
end

--- Format state for death/victory/error screens
--- Per PLAN.md: seed, final_floor, turns, kills, cause must be shown
--- @param cause string|nil Cause of death/victory/error
--- @param kills number|nil Kill count
--- @return table Formatted ending state
function HUD.format_ending(cause, kills)
    return {
        seed = _state.seed,
        final_floor = _state.floor,
        turns = _state.turn,
        kills = kills or 0,
        cause = cause or "unknown",
    }
end

--- Get formatted string for ending screens
--- @param cause string|nil Cause
--- @param kills number|nil Kill count
--- @return string Formatted ending text
function HUD.render_ending(cause, kills)
    local ending = HUD.format_ending(cause, kills)
    local lines = {
        "Seed: " .. tostring(ending.seed),
        "Floor: " .. tostring(ending.final_floor),
        "Turns: " .. tostring(ending.turns),
        "Kills: " .. tostring(ending.kills),
        "Cause: " .. tostring(ending.cause),
    }
    return table.concat(lines, "\n")
end

return HUD
