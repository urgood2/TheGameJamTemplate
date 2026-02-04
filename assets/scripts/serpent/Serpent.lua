--[[
    Serpent Module - Interface for Serpent Game Integration

    This module provides the interface between the main game state system
    and the Serpent game implementation.
]]

local serpent_main = require("serpent.serpent_main")

local Serpent = {}

--[[
    Initialize the Serpent game
    Called when changing to GAMESTATE.SERPENT
]]
function Serpent.init()
    log_debug("[Serpent] Initializing Serpent game mode")
    serpent_main.init()
end

--[[
    Update the Serpent game
    Called during main game loop when in SERPENT state

    @param dt number - Delta time in seconds
]]
function Serpent.update(dt)
    if serpent_main.update then
        serpent_main.update(dt)
    end
end

--[[
    Clean up the Serpent game
    Called when leaving GAMESTATE.SERPENT
]]
function Serpent.cleanup()
    log_debug("[Serpent] Cleaning up Serpent game mode")
    serpent_main.cleanup()
end

--[[
    Get current Serpent mode state

    @return string - Current MODE_STATE
]]
function Serpent.get_current_state()
    if serpent_main.get_current_state then
        return serpent_main.get_current_state()
    end
    return nil
end

--[[
    Change Serpent mode state

    @param new_state string - New MODE_STATE value
    @return boolean - Success
]]
function Serpent.change_state(new_state)
    if serpent_main.change_state then
        return serpent_main.change_state(new_state)
    end
    return false
end

return Serpent