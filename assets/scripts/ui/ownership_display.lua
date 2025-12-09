-- assets/scripts/ui/ownership_display.lua
-- Example usage of ownership bindings for title screen
--
-- This module demonstrates how to integrate ownership watermarking
-- into your title screen UI. The ownership system helps prevent
-- casual theft by detecting when build constants have been modified.

local M = {}

--- Draw ownership links on title screen
--- Call this from your title screen render function
--- @param x number X position for text
--- @param y number Y position for text
function M.draw(x, y)
    -- Get official links from C++ (read-only, cannot be modified by Lua)
    local discord = ownership.getDiscordLink()
    local itch = ownership.getItchLink()
    local buildId = ownership.getBuildId()

    -- Example: Draw the links using your game's UI system
    -- Replace these with actual calls to your rendering functions
    --
    -- Examples:
    --   DrawText("Join our Discord: " .. discord, x, y, 16, WHITE)
    --   DrawText("Get the game: " .. itch, x, y + 20, 16, WHITE)
    --   DrawText("Build: " .. buildId, x, y + 40, 12, GRAY)
    --
    -- Or using your custom UI framework:
    --   ui.text({ text = "Join our Discord: " .. discord, x = x, y = y, size = 16 })
    --   ui.text({ text = "Get the game: " .. itch, x = x, y = y + 20, size = 16 })
    --   ui.text({ text = "Build: " .. buildId, x = x, y = y + 40, size = 12 })

    -- IMPORTANT: Report what we displayed to C++ for validation
    -- This must be called after rendering the links to validate authenticity
    -- If discord/itch values don't match compile-time constants,
    -- a warning overlay will appear (rendered in C++, cannot be suppressed)
    ownership.validate(discord, itch)
end

--- Alternative: Get ownership data without rendering
--- Use this if you want to display links in your own custom UI
--- @return table { discord: string, itch: string, buildId: string, signature: string }
function M.getData()
    return {
        discord = ownership.getDiscordLink(),
        itch = ownership.getItchLink(),
        buildId = ownership.getBuildId(),
        signature = ownership.getBuildSignature()
    }
end

--- Validate displayed links
--- Call this after you've shown the links to the player
--- @param displayedDiscord string The Discord link you showed
--- @param displayedItch string The itch.io link you showed
function M.validate(displayedDiscord, displayedItch)
    ownership.validate(displayedDiscord, displayedItch)
end

return M
