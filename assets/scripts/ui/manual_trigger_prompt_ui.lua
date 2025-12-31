local ManualTriggerPromptUI = {}

local z_orders = require("core.z_orders")
local WandTriggers = nil

local CONFIG = {
    iconSize = 48,
    pulseSpeed = 4.0,
    pulseMinScale = 0.95,
    pulseMaxScale = 1.05,
    pulseMinAlpha = 180,
    pulseMaxAlpha = 255,
    flashDuration = 0.15,
    flashScale = 1.3,
    bottomMargin = 80,
}

local state = {
    isActive = false,
    pulsePhase = 0,
    flashUntil = 0,
}

local function getWandTriggers()
    if not WandTriggers then
        local ok, mod = pcall(require, "wand.wand_triggers")
        if ok then WandTriggers = mod end
    end
    return WandTriggers
end

function ManualTriggerPromptUI.init()
    state.isActive = true
    state.pulsePhase = 0
    state.flashUntil = 0
end

function ManualTriggerPromptUI.show()
    state.isActive = true
end

function ManualTriggerPromptUI.hide()
    state.isActive = false
end

function ManualTriggerPromptUI.flash()
    state.flashUntil = (GetTime and GetTime() or 0) + CONFIG.flashDuration
end

function ManualTriggerPromptUI.update(dt)
    if not state.isActive then return end
    
    state.pulsePhase = state.pulsePhase + dt * CONFIG.pulseSpeed
    
    if isKeyPressed and isKeyPressed("KEY_E") then
        local triggers = getWandTriggers()
        if triggers and triggers.fireManualAll then
            local fired = triggers.fireManualAll({ source = "e_key" })
            if fired > 0 then
                ManualTriggerPromptUI.flash()
            end
        end
    end
end

function ManualTriggerPromptUI.draw()
    if not state.isActive then return end
    if not command_buffer or not layers then return end
    
    local triggers = getWandTriggers()
    if not triggers or not triggers.hasManualTriggers or not triggers.hasManualTriggers() then
        return
    end
    
    local screenW = (globals and globals.screenWidth and globals.screenWidth()) or 1920
    local screenH = (globals and globals.screenHeight and globals.screenHeight()) or 1080
    local space = layer and layer.DrawCommandSpace and layer.DrawCommandSpace.Screen
    local baseZ = (z_orders and z_orders.ui_tooltips or 0) - 3
    
    local now = GetTime and GetTime() or 0
    local isFlashing = now < state.flashUntil
    
    local pulseT = (math.sin(state.pulsePhase) + 1) * 0.5
    local scale, alpha
    
    if isFlashing then
        scale = CONFIG.flashScale
        alpha = 255
    else
        scale = CONFIG.pulseMinScale + (CONFIG.pulseMaxScale - CONFIG.pulseMinScale) * pulseT
        alpha = CONFIG.pulseMinAlpha + (CONFIG.pulseMaxAlpha - CONFIG.pulseMinAlpha) * pulseT
    end
    
    local iconSize = CONFIG.iconSize * scale
    local cx = screenW * 0.5
    local cy = screenH - CONFIG.bottomMargin
    
    local bgColor = isFlashing and Col(255, 220, 100, 255) or Col(60, 65, 80, math.floor(alpha * 0.8))
    command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
        c.x = cx
        c.y = cy
        c.w = iconSize
        c.h = iconSize
        c.rx = 8 * scale
        c.ry = 8 * scale
        c.color = bgColor
    end, baseZ, space)
    
    local textColor = isFlashing and Col(40, 40, 40, 255) or Col(255, 255, 255, math.floor(alpha))
    local fontSize = 24 * scale
    local font = localization and localization.getFont and localization.getFont()
    
    command_buffer.queueDrawText(layers.ui, function(c)
        c.text = "E"
        c.font = font
        c.x = cx - fontSize * 0.3
        c.y = cy - fontSize * 0.45
        c.color = textColor
        c.fontSize = fontSize
    end, baseZ + 1, space)
end

function ManualTriggerPromptUI.cleanup()
    state.isActive = false
end

return ManualTriggerPromptUI
