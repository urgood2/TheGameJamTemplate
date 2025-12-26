-- assets/scripts/ui/death_screen.lua
--[[
    Death Screen UI

    Shows "YOU DIED" text and "Try Again" button using Text Builder.
    Emits "restart_game" signal when button is clicked.
]]

local Text = require("core.text")
local signal = require("external.hump.signal")

local DeathScreen = {}

-- Active text handles for cleanup
local activeHandles = {}

-- Track if death screen is visible
DeathScreen.isVisible = false

-- Dark overlay entity (optional, for dimming background)
local overlayEntity = nil

--- Show the death screen
function DeathScreen.show()
    if DeathScreen.isVisible then return end
    DeathScreen.isVisible = true

    local screenW = getScreenWidth()
    local screenH = getScreenHeight()
    local centerX = screenW / 2
    local centerY = screenH / 2

    -- "YOU DIED" title - large, red, no lifespan (persistent)
    local titleRecipe = Text.define()
        :content("[YOU DIED](color=red)")
        :size(64)
        :anchor("center")
        :space("screen")
        :z(1000)
        :pop(0.5)

    local titleHandle = titleRecipe:spawn():at(centerX, centerY - 60)
    table.insert(activeHandles, titleHandle)

    -- "Try Again" button - clickable
    -- Note: Text Builder may not support click handlers directly
    -- We'll use a simple approach: check for click in update or use a separate button
    local buttonRecipe = Text.define()
        :content("[Click to Try Again](color=white)")
        :size(28)
        :anchor("center")
        :space("screen")
        :z(1000)

    local buttonHandle = buttonRecipe:spawn():at(centerX, centerY + 40)
    table.insert(activeHandles, buttonHandle)

    -- Store button bounds for click detection
    DeathScreen._buttonBounds = {
        x = centerX - 120,
        y = centerY + 20,
        w = 240,
        h = 50
    }

    log_debug("[DeathScreen] Shown")
end

--- Hide the death screen
function DeathScreen.hide()
    if not DeathScreen.isVisible then return end
    DeathScreen.isVisible = false

    -- Stop all active text handles
    for _, handle in ipairs(activeHandles) do
        if handle and handle.stop then
            handle:stop()
        end
    end
    activeHandles = {}

    DeathScreen._buttonBounds = nil

    log_debug("[DeathScreen] Hidden")
end

--- Check for click on "Try Again" button
--- Call this from the main update loop when death screen is visible
--- @param mouseX number Mouse X position
--- @param mouseY number Mouse Y position
--- @param clicked boolean Whether mouse was clicked this frame
function DeathScreen.checkClick(mouseX, mouseY, clicked)
    if not DeathScreen.isVisible then return end
    if not DeathScreen._buttonBounds then return end
    if not clicked then return end

    local b = DeathScreen._buttonBounds
    if mouseX >= b.x and mouseX <= b.x + b.w and
       mouseY >= b.y and mouseY <= b.y + b.h then
        log_debug("[DeathScreen] Try Again clicked!")
        DeathScreen.hide()
        signal.emit("restart_game")
    end
end

--- Alternative: trigger restart from any click while death screen is visible
--- Simpler UX - just click anywhere
function DeathScreen.handleAnyClick()
    if not DeathScreen.isVisible then return end
    log_debug("[DeathScreen] Clicked - restarting game")
    DeathScreen.hide()
    signal.emit("restart_game")
end

return DeathScreen
