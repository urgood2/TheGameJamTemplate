--[[
================================================================================
debug.lua - Visual Debugging Helpers
================================================================================
Draw bounds, vectors, paths, and collision shapes for debugging.

Usage:
    local Debug = require("core.debug")

    Debug.enabled = true

    function update(dt)
        Debug.bounds(entity)
        Debug.velocity(entity)
        Debug.circle(x, y, radius)
        Debug.text(entity, "HP: 100")
    end

Dependencies:
    - core.Q (position helpers)
    - core.draw (draw commands)
    - layers (render layers)
]]

if _G.__DEBUG_VIS__ then return _G.__DEBUG_VIS__ end

local Debug = {}

local Q = require("core.Q")

Debug.enabled = false

Debug.colors = {
    bounds = { r = 0, g = 255, b = 0, a = 128 },
    velocity = { r = 255, g = 255, b = 0, a = 200 },
    path = { r = 0, g = 128, b = 255, a = 180 },
    circle = { r = 255, g = 0, b = 255, a = 128 },
    text = { r = 255, g = 255, b = 255, a = 255 },
    collider = { r = 255, g = 0, b = 0, a = 100 },
    point = { r = 255, g = 128, b = 0, a = 255 },
}

local function getLayer()
    local layers = _G.layers
    if layers then
        return layers.debug or layers.ui or layers.sprites
    end
    return nil
end

local function drawLine(x1, y1, x2, y2, color)
    local command_buffer = _G.command_buffer
    local layer = getLayer()
    if not command_buffer or not layer then return end
    
    command_buffer.queueDrawLine(layer, function(cmd)
        cmd.startPosX = x1
        cmd.startPosY = y1
        cmd.endPosX = x2
        cmd.endPosY = y2
        cmd.thick = 2
        cmd.color = color or Debug.colors.bounds
    end, 9999)
end

local function drawRect(x, y, w, h, color)
    local command_buffer = _G.command_buffer
    local layer = getLayer()
    if not command_buffer or not layer then return end
    
    command_buffer.queueDrawRectangleLines(layer, function(cmd)
        cmd.x = x
        cmd.y = y
        cmd.width = w
        cmd.height = h
        cmd.lineThick = 2
        cmd.color = color or Debug.colors.bounds
    end, 9999)
end

local function drawCircleOutline(x, y, radius, color)
    local command_buffer = _G.command_buffer
    local layer = getLayer()
    if not command_buffer or not layer then return end
    
    command_buffer.queueDrawCircleLines(layer, function(cmd)
        cmd.centerX = x
        cmd.centerY = y
        cmd.radius = radius
        cmd.color = color or Debug.colors.circle
    end, 9999)
end

local function drawText(x, y, text, color)
    local command_buffer = _G.command_buffer
    local layer = getLayer()
    if not command_buffer or not layer then return end
    
    command_buffer.queueDrawText(layer, function(cmd)
        cmd.text = text
        cmd.posX = x
        cmd.posY = y
        cmd.fontSize = 12
        cmd.color = color or Debug.colors.text
    end, 9999)
end

function Debug.bounds(entity, color)
    if not Debug.enabled then return end
    
    local x, y, w, h = Q.bounds(entity)
    if not x then return end
    
    drawRect(x, y, w, h, color or Debug.colors.bounds)
end

function Debug.visualBounds(entity, color)
    if not Debug.enabled then return end
    
    local x, y, w, h = Q.visualBounds(entity)
    if not x then return end
    
    drawRect(x, y, w, h, color or Debug.colors.bounds)
end

function Debug.velocity(entity, scale, color)
    if not Debug.enabled then return end
    
    scale = scale or 0.1
    
    local cx, cy = Q.center(entity)
    if not cx then return end
    
    local vx, vy = Q.velocity(entity)
    if not vx then return end
    
    local endX = cx + vx * scale
    local endY = cy + vy * scale
    
    drawLine(cx, cy, endX, endY, color or Debug.colors.velocity)
    
    local arrowSize = 5
    local angle = math.atan2(vy, vx)
    local a1 = angle + math.pi * 0.8
    local a2 = angle - math.pi * 0.8
    drawLine(endX, endY, endX + math.cos(a1) * arrowSize, endY + math.sin(a1) * arrowSize, color or Debug.colors.velocity)
    drawLine(endX, endY, endX + math.cos(a2) * arrowSize, endY + math.sin(a2) * arrowSize, color or Debug.colors.velocity)
end

function Debug.direction(entity1, entity2, color)
    if not Debug.enabled then return end
    
    local x1, y1 = Q.center(entity1)
    local x2, y2 = Q.center(entity2)
    if not x1 or not x2 then return end
    
    drawLine(x1, y1, x2, y2, color or Debug.colors.path)
end

function Debug.circle(x, y, radius, color)
    if not Debug.enabled then return end
    drawCircleOutline(x, y, radius, color or Debug.colors.circle)
end

function Debug.point(x, y, size, color)
    if not Debug.enabled then return end
    size = size or 4
    drawCircleOutline(x, y, size, color or Debug.colors.point)
end

function Debug.line(x1, y1, x2, y2, color)
    if not Debug.enabled then return end
    drawLine(x1, y1, x2, y2, color or Debug.colors.path)
end

function Debug.path(points, color)
    if not Debug.enabled then return end
    if not points or #points < 2 then return end
    
    for i = 1, #points - 1 do
        local p1 = points[i]
        local p2 = points[i + 1]
        drawLine(p1.x or p1[1], p1.y or p1[2], p2.x or p2[1], p2.y or p2[2], color or Debug.colors.path)
    end
end

function Debug.text(entity, text, offsetY, color)
    if not Debug.enabled then return end
    
    local cx, cy = Q.visualCenter(entity)
    if not cx then return end
    
    offsetY = offsetY or -20
    drawText(cx, cy + offsetY, text, color or Debug.colors.text)
end

function Debug.textAt(x, y, text, color)
    if not Debug.enabled then return end
    drawText(x, y, text, color or Debug.colors.text)
end

function Debug.collider(entity, color)
    if not Debug.enabled then return end
    
    local x, y, w, h = Q.bounds(entity)
    if not x then return end
    
    local cx, cy = x + w/2, y + h/2
    local radius = math.min(w, h) / 2
    
    drawCircleOutline(cx, cy, radius, color or Debug.colors.collider)
end

function Debug.grid(cellSize, color)
    if not Debug.enabled then return end
    
    cellSize = cellSize or 32
    color = color or { r = 50, g = 50, b = 50, a = 100 }
    
    local screenW = _G.GetScreenWidth and _G.GetScreenWidth() or 800
    local screenH = _G.GetScreenHeight and _G.GetScreenHeight() or 600
    
    for x = 0, screenW, cellSize do
        drawLine(x, 0, x, screenH, color)
    end
    for y = 0, screenH, cellSize do
        drawLine(0, y, screenW, y, color)
    end
end

function Debug.log(entity, message)
    if not Debug.enabled then return end
    print(string.format("[DEBUG %s] %s", tostring(entity), message))
end

function Debug.toggle()
    Debug.enabled = not Debug.enabled
    print(string.format("[Debug] Visual debugging %s", Debug.enabled and "ENABLED" or "DISABLED"))
end

_G.__DEBUG_VIS__ = Debug
return Debug
