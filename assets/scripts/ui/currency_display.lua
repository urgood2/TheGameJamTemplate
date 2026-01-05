--[[
Lightweight currency display for planning/shop screens.
Tracks a target amount and animates toward it with a small pulse on change.
Simplified design: icon + number only (no background/borders).
]]

local CurrencyDisplay = {}

local z_orders = require("core.z_orders")

CurrencyDisplay.amount = 0
CurrencyDisplay.displayAmount = 0
CurrencyDisplay.pulse = 0
CurrencyDisplay.wobbleTime = 0
CurrencyDisplay.isActive = false
CurrencyDisplay.position = { x = 20, y = 16 }
CurrencyDisplay.margins = { x = 16, y = 16 }

local colors = {
    accent = util.getColor("gold"),
    text = util.getColor("white"),
}

function CurrencyDisplay.init(opts)
    CurrencyDisplay.amount = math.floor((opts and opts.amount) or 0)
    CurrencyDisplay.displayAmount = CurrencyDisplay.amount
    CurrencyDisplay.pulse = 0
    CurrencyDisplay.position = {
        x = (opts and opts.x) or (opts and opts.position and opts.position.x) or 20,
        y = (opts and opts.y) or (opts and opts.position and opts.position.y) or 16
    }
    CurrencyDisplay.margins = {
        x = (opts and opts.marginX) or (opts and opts.margins and opts.margins.x) or 16,
        y = (opts and opts.marginY) or (opts and opts.margins and opts.margins.y) or 16
    }
    CurrencyDisplay.isActive = true
end

function CurrencyDisplay.setAmount(amount)
    amount = math.floor(amount or 0)
    if amount ~= CurrencyDisplay.amount then
        CurrencyDisplay.amount = amount
        CurrencyDisplay.pulse = 1.0
    end
end

function CurrencyDisplay.update(dt)
    if not CurrencyDisplay.isActive then return end
    if not dt then dt = GetFrameTime() end

    local lerpRate = math.min(1, dt * 8)
    CurrencyDisplay.displayAmount = CurrencyDisplay.displayAmount +
        (CurrencyDisplay.amount - CurrencyDisplay.displayAmount) * lerpRate

    CurrencyDisplay.pulse = math.max(0, CurrencyDisplay.pulse - dt * 3.2)
    CurrencyDisplay.wobbleTime = CurrencyDisplay.wobbleTime + dt
end

local function drawCoinIcon(centerX, centerY, radius, z, space)
    command_buffer.queueDrawCenteredEllipse(layers.ui, function(c)
        c.x = centerX
        c.y = centerY
        c.rx = radius
        c.ry = radius
        c.color = colors.accent
    end, z, space)

    command_buffer.queueDrawCenteredEllipse(layers.ui, function(c)
        c.x = centerX
        c.y = centerY
        c.rx = radius * 0.55
        c.ry = radius * 0.55
        c.color = Col(255, 255, 255, 140)
    end, z + 1, space)
end

function CurrencyDisplay.draw()
    if not CurrencyDisplay.isActive then return end
    if not command_buffer or not layers then return end

    local amount = math.floor(CurrencyDisplay.displayAmount + 0.5)
    local amountSize = 24 + CurrencyDisplay.pulse * 4
    local pos = CurrencyDisplay.position

    local screenW = (globals and ((globals.screenWidth and globals.screenWidth()) or (globals.getScreenWidth and globals.getScreenWidth()))) or 1920
    local screenH = (globals and ((globals.screenHeight and globals.screenHeight()) or (globals.getScreenHeight and globals.getScreenHeight()))) or 1080
    local marginX = CurrencyDisplay.margins.x or 0
    local marginY = CurrencyDisplay.margins.y or 0

    local iconRadius = 14 + CurrencyDisplay.pulse * 4
    local iconDiameter = iconRadius * 2
    local textGap = 8
    local amountWidth = localization.getTextWidthWithCurrentFont(tostring(amount), amountSize, 1)
    local totalWidth = iconDiameter + textGap + amountWidth
    
    local clampedX = math.max(marginX, math.min(pos.x, screenW - totalWidth - marginX))
    local clampedY = math.max(marginY, math.min(pos.y, screenH - iconDiameter - marginY))

    local iconCenterX = clampedX + iconRadius
    local iconCenterY = clampedY + iconRadius
    local space = layer.DrawCommandSpace.Screen
    local baseZ = (z_orders.ui_tooltips or 0) - 4
    local font = localization.getFont()

    drawCoinIcon(iconCenterX, iconCenterY, iconRadius, baseZ, space)

    local wobbleOffset = math.sin(CurrencyDisplay.wobbleTime * 3.5) * 2 * (0.3 + CurrencyDisplay.pulse * 0.7)
    local textX = iconCenterX + iconRadius + textGap
    local textY = iconCenterY - amountSize * 0.35 + wobbleOffset

    command_buffer.queueDrawText(layers.ui, function(c)
        c.text = tostring(amount)
        c.font = font
        c.x = textX
        c.y = textY
        c.color = colors.text
        c.fontSize = amountSize
    end, baseZ + 2, space)
end

return CurrencyDisplay
