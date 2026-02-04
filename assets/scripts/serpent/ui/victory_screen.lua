-- assets/scripts/serpent/ui/victory_screen.lua
--[[
    Victory Screen UI

    Shows "VICTORY" text and "Continue" button using Text Builder.
    Emits "continue_game" signal when button is clicked.
]]

local Text = require("core.text")
local signal = require("external.hump.signal")

local VictoryScreen = {}

-- Active text handles for cleanup
local activeHandles = {}

-- Track if victory screen is visible
VictoryScreen.isVisible = false

-- Dark overlay entity (optional, for dimming background)
local overlayEntity = nil

--- Show the victory screen
function VictoryScreen.show()
    if VictoryScreen.isVisible then return end
    VictoryScreen.isVisible = true

    local screenW = globals.screenWidth()
    local screenH = globals.screenHeight()
    local centerX = screenW / 2
    local centerY = screenH / 2

    -- "VICTORY" title - large, gold, no lifespan (persistent)
    local titleRecipe = Text.define()
        :content("[VICTORY](color=gold)")
        :size(64)
        :anchor("center")
        :space("screen")
        :z(1000)
        :pop(0.5)

    local titleHandle = titleRecipe:spawn():at(centerX, centerY - 60)
    table.insert(activeHandles, titleHandle)

    -- "Continue" button - clickable
    local buttonRecipe = Text.define()
        :content("[Click to Continue](color=white)")
        :size(28)
        :anchor("center")
        :space("screen")
        :z(1000)

    local buttonHandle = buttonRecipe:spawn():at(centerX, centerY + 40)
    table.insert(activeHandles, buttonHandle)

    -- Store button bounds for click detection
    VictoryScreen._buttonBounds = {
        x = centerX - 120,
        y = centerY + 20,
        w = 240,
        h = 50
    }

    log_debug("[VictoryScreen] Shown")
end

--- Hide the victory screen
function VictoryScreen.hide()
    if not VictoryScreen.isVisible then return end
    VictoryScreen.isVisible = false

    -- Stop all active text handles
    for _, handle in ipairs(activeHandles) do
        if handle and handle.stop then
            handle:stop()
        end
    end
    activeHandles = {}

    VictoryScreen._buttonBounds = nil

    log_debug("[VictoryScreen] Hidden")
end

--- Check for click on "Continue" button
--- Call this from the main update loop when victory screen is visible
--- @param mouseX number Mouse X position
--- @param mouseY number Mouse Y position
--- @param clicked boolean Whether mouse was clicked this frame
function VictoryScreen.checkClick(mouseX, mouseY, clicked)
    if not VictoryScreen.isVisible then return end
    if not VictoryScreen._buttonBounds then return end
    if not clicked then return end

    local b = VictoryScreen._buttonBounds
    if mouseX >= b.x and mouseX <= b.x + b.w and
       mouseY >= b.y and mouseY <= b.y + b.h then
        log_debug("[VictoryScreen] Continue clicked!")
        VictoryScreen.hide()
        signal.emit("continue_game")
    end
end

--- Alternative: trigger continue from any click while victory screen is visible
--- Simpler UX - just click anywhere
function VictoryScreen.handleAnyClick()
    if not VictoryScreen.isVisible then return end
    log_debug("[VictoryScreen] Clicked - continuing game")
    VictoryScreen.hide()
    signal.emit("continue_game")
end

return VictoryScreen