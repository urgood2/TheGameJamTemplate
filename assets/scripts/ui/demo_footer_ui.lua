local DemoFooterUI = {}

local z_orders = require("core.z_orders")

local CONFIG = {
    marginRight = 16,
    marginBottom = 16,
    textOpacity = 170,
    iconSize = 28,
    iconGap = 12,
    iconTextGap = 8,
    fontSize = 16,
    hoverScale = 1.15,
}

local URLS = {
    discord = "https://discord.gg/rp6yXxKu5z",
    forms = "https://forms.gle/YZFWQ41JnBNpzYSa7",
}

local state = {
    isActive = false,
    version = "0.1.0",
    isDemo = true,
    hoveredButton = nil,
}

local colors = {
    text = Col(255, 255, 255, CONFIG.textOpacity),
    discord = Col(88, 101, 242, 255),
    discordHover = Col(114, 127, 255, 255),
    forms = Col(103, 58, 183, 255),
    formsHover = Col(149, 117, 205, 255),
}

function DemoFooterUI.init()
    state.isActive = true
    
    if globals and globals.getConfigValue then
        local version = globals.getConfigValue("build.version")
        local isDemo = globals.getConfigValue("build.is_demo")
        if version then state.version = version end
        if isDemo ~= nil then state.isDemo = isDemo end
    end
end

function DemoFooterUI.show()
    state.isActive = true
end

function DemoFooterUI.hide()
    state.isActive = false
end

local function getMousePos()
    if input and input.getMousePos then
        local m = input.getMousePos()
        if m and m.x and m.y then return m.x, m.y end
    end
    if globals then
        return globals.mouseX or 0, globals.mouseY or 0
    end
    return 0, 0
end

local function isMouseInRect(x, y, w, h)
    local mx, my = getMousePos()
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

local function isMousePressed()
    if input and input.action_down then
        return input.action_down("mouse_click")
    end
    if IsMouseButtonPressed then
        return IsMouseButtonPressed(0)
    end
    return false
end

local function drawDiscordIcon(cx, cy, size, isHovered, z, space)
    local color = isHovered and colors.discordHover or colors.discord
    local s = isHovered and size * CONFIG.hoverScale or size
    local r = s * 0.5
    
    command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
        c.x = cx
        c.y = cy
        c.w = s
        c.h = s
        c.rx = 6
        c.ry = 6
        c.color = color
    end, z, space)
    
    command_buffer.queueDrawText(layers.ui, function(c)
        c.text = "D"
        c.font = localization and localization.getFont() or nil
        c.x = cx - 5
        c.y = cy - 8
        c.color = Col(255, 255, 255, 255)
        c.fontSize = 16
    end, z + 1, space)
end

local function drawFormsIcon(cx, cy, size, isHovered, z, space)
    local color = isHovered and colors.formsHover or colors.forms
    local s = isHovered and size * CONFIG.hoverScale or size
    
    command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
        c.x = cx
        c.y = cy
        c.w = s
        c.h = s
        c.rx = 6
        c.ry = 6
        c.color = color
    end, z, space)
    
    command_buffer.queueDrawText(layers.ui, function(c)
        c.text = "?"
        c.font = localization and localization.getFont() or nil
        c.x = cx - 4
        c.y = cy - 8
        c.color = Col(255, 255, 255, 255)
        c.fontSize = 16
    end, z + 1, space)
end

function DemoFooterUI.update(dt)
    if not state.isActive then return end
    
    local screenW = (globals and globals.screenWidth and globals.screenWidth()) or 1920
    local screenH = (globals and globals.screenHeight and globals.screenHeight()) or 1080
    
    local demoText = state.isDemo and ("DEMO v" .. state.version) or ("v" .. state.version)
    local textWidth = 0
    if localization and localization.getTextWidthWithCurrentFont then
        textWidth = localization.getTextWidthWithCurrentFont(demoText, CONFIG.fontSize, 1)
    else
        textWidth = #demoText * CONFIG.fontSize * 0.5
    end
    
    local textX = screenW - CONFIG.marginRight - textWidth
    local textY = screenH - CONFIG.marginBottom - CONFIG.fontSize
    
    local halfIcon = CONFIG.iconSize * 0.5
    local iconsY = textY - CONFIG.iconTextGap - halfIcon
    local formsX = screenW - CONFIG.marginRight - halfIcon
    local discordX = formsX - CONFIG.iconGap - CONFIG.iconSize
    
    state.hoveredButton = nil
    
    if isMouseInRect(discordX - halfIcon, iconsY - halfIcon, CONFIG.iconSize, CONFIG.iconSize) then
        state.hoveredButton = "discord"
    elseif isMouseInRect(formsX - halfIcon, iconsY - halfIcon, CONFIG.iconSize, CONFIG.iconSize) then
        state.hoveredButton = "forms"
    end
    
    if isMousePressed() and state.hoveredButton then
        local url = URLS[state.hoveredButton]
        if url and OpenURL then
            OpenURL(url)
        end
    end
end

function DemoFooterUI.draw()
    if not state.isActive then return end
    if not command_buffer or not layers then return end
    
    local screenW = (globals and globals.screenWidth and globals.screenWidth()) or 1920
    local screenH = (globals and globals.screenHeight and globals.screenHeight()) or 1080
    local space = layer.DrawCommandSpace.Screen
    local baseZ = (z_orders and z_orders.ui_tooltips or 0) - 2
    
    local demoText = state.isDemo and ("DEMO v" .. state.version) or ("v" .. state.version)
    local textWidth = 0
    if localization and localization.getTextWidthWithCurrentFont then
        textWidth = localization.getTextWidthWithCurrentFont(demoText, CONFIG.fontSize, 1)
    else
        textWidth = #demoText * CONFIG.fontSize * 0.5
    end
    
    local textX = screenW - CONFIG.marginRight - textWidth
    local textY = screenH - CONFIG.marginBottom - CONFIG.fontSize
    
    command_buffer.queueDrawText(layers.ui, function(c)
        c.text = demoText
        c.font = localization and localization.getFont() or nil
        c.x = textX
        c.y = textY
        c.color = colors.text
        c.fontSize = CONFIG.fontSize
    end, baseZ, space)
    
    local iconsY = textY - CONFIG.iconTextGap - CONFIG.iconSize * 0.5
    local formsX = screenW - CONFIG.marginRight - CONFIG.iconSize * 0.5
    local discordX = formsX - CONFIG.iconGap - CONFIG.iconSize
    
    drawDiscordIcon(discordX, iconsY, CONFIG.iconSize, state.hoveredButton == "discord", baseZ + 1, space)
    drawFormsIcon(formsX, iconsY, CONFIG.iconSize, state.hoveredButton == "forms", baseZ + 1, space)
end

function DemoFooterUI.cleanup()
    state.isActive = false
    state.hoveredButton = nil
end

return DemoFooterUI
