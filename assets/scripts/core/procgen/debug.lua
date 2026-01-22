-- assets/scripts/core/procgen/debug.lua
-- Visualization utilities for procedural generation data structures
--
-- Usage:
--   local procgenDebug = require("core.procgen.debug")
--   procgenDebug.enabled = true
--
--   -- Draw a grid with default wall/floor colors
--   procgenDebug.drawGrid(grid, screenX, screenY, cellSize)
--
--   -- Draw with custom color function
--   procgenDebug.drawGrid(grid, x, y, 16, function(value)
--       return value == 0 and debug.colors.floor or debug.colors.wall
--   end)
--
--   -- Draw a pattern
--   procgenDebug.drawPattern(pattern, screenX, screenY, cellSize)
--
--   -- Draw a graph (nodes and edges)
--   procgenDebug.drawGraph(graphBuilder)
--
--   -- Draw influence map with gradient
--   procgenDebug.drawInfluence(grid, screenX, screenY, cellSize, minVal, maxVal)

-- Singleton pattern to avoid reloading
if _G.__PROCGEN_DEBUG__ then return _G.__PROCGEN_DEBUG__ end

local debug = {}

debug.enabled = false

-- Default colors for visualization
debug.colors = {
    floor = {r = 80, g = 80, b = 100, a = 200},
    wall = {r = 40, g = 40, b = 50, a = 255},
    node = {r = 100, g = 200, b = 100, a = 255},
    edge = {r = 150, g = 150, b = 200, a = 180},
    pattern = {r = 100, g = 180, b = 220, a = 200},
    influenceLow = {r = 0, g = 0, b = 100, a = 50},
    influenceHigh = {r = 255, g = 50, b = 50, a = 200},
    room = {r = 255, g = 255, b = 0, a = 150},
    enemy = {r = 255, g = 0, b = 0, a = 200},
    treasure = {r = 255, g = 215, b = 0, a = 200},
}

--- Get the debug layer for rendering
local function getLayer()
    local layers = _G.layers
    if layers then
        return layers.debug or layers.ui or layers.sprites
    end
    return nil
end

--- Interpolate between two colors
-- @param c1 table Color {r, g, b, a}
-- @param c2 table Color {r, g, b, a}
-- @param t number Interpolation factor 0-1
-- @return table Interpolated color
function debug.lerp(c1, c2, t)
    t = math.max(0, math.min(1, t))
    return {
        r = math.floor(c1.r + (c2.r - c1.r) * t),
        g = math.floor(c1.g + (c2.g - c1.g) * t),
        b = math.floor(c1.b + (c2.b - c1.b) * t),
        a = math.floor((c1.a or 255) + ((c2.a or 255) - (c1.a or 255)) * t),
    }
end

--- Draw a filled rectangle
local function drawRect(x, y, w, h, color)
    local command_buffer = _G.command_buffer
    local layer = getLayer()
    if not command_buffer or not layer then return end

    command_buffer.queueDrawRectangle(layer, function(cmd)
        cmd.x = x
        cmd.y = y
        cmd.width = w
        cmd.height = h
        cmd.color = color
    end, 9000)
end

--- Draw a circle outline
local function drawCircle(x, y, radius, color)
    local command_buffer = _G.command_buffer
    local layer = getLayer()
    if not command_buffer or not layer then return end

    command_buffer.queueDrawCircleLines(layer, function(cmd)
        cmd.centerX = x
        cmd.centerY = y
        cmd.radius = radius
        cmd.color = color
    end, 9001)
end

--- Draw a line
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
        cmd.color = color
    end, 9000)
end

-- Note: drawText helper removed - currently unused. If text labels are needed
-- for visualization (e.g., node IDs, influence values), add drawText back.

--- Draw a Grid with color-coded cells
-- @param grid Grid The Grid to visualize
-- @param screenX number Screen X position
-- @param screenY number Screen Y position
-- @param cellSize number Size of each cell in pixels
-- @param colorFn function? Optional function(value) returning color table
function debug.drawGrid(grid, screenX, screenY, cellSize, colorFn)
    if not debug.enabled then return end

    -- Default color function: 0 = floor, 1 = wall
    colorFn = colorFn or function(value)
        if value == 0 then
            return debug.colors.floor
        elseif value == 1 then
            return debug.colors.wall
        else
            -- Gradient for other values
            local t = math.abs(value) / 10
            return debug.lerp(debug.colors.floor, debug.colors.wall, t)
        end
    end

    -- Grid is 1-indexed
    for x = 1, grid.w do
        for y = 1, grid.h do
            local value = grid:get(x, y)
            local color = colorFn(value)
            local px = screenX + (x - 1) * cellSize
            local py = screenY + (y - 1) * cellSize
            drawRect(px, py, cellSize, cellSize, color)
        end
    end
end

--- Draw a Pattern with filled cells
-- @param pattern pattern The Forma pattern to visualize
-- @param screenX number Screen X position
-- @param screenY number Screen Y position
-- @param cellSize number Size of each cell in pixels
-- @param color table? Optional color (default: debug.colors.pattern)
function debug.drawPattern(pattern, screenX, screenY, cellSize, color)
    if not debug.enabled then return end

    color = color or debug.colors.pattern

    -- Pattern is 0-indexed
    for cell in pattern:cells() do
        local px = screenX + cell.x * cellSize
        local py = screenY + cell.y * cellSize
        drawRect(px, py, cellSize, cellSize, color)
    end
end

--- Draw a GraphBuilder's nodes and edges
-- @param builder GraphBuilder The builder to visualize (must have nodes with x,y)
function debug.drawGraph(builder)
    if not debug.enabled then return end

    local nodeRadius = 8
    local drawnEdges = {}  -- Track drawn edges to avoid duplicates

    -- Draw edges first (so nodes appear on top)
    -- Traverse the graph using neighbors() to find edges
    for id, node in pairs(builder._nodes or {}) do
        local neighbors = builder:neighbors(id) or {}
        for _, neighbor in ipairs(neighbors) do
            -- Create a sorted edge key to avoid drawing twice
            local edgeKey = id < (neighbor._id or "") and (id .. "-" .. (neighbor._id or "")) or ((neighbor._id or "") .. "-" .. id)
            if not drawnEdges[edgeKey] then
                drawnEdges[edgeKey] = true
                local x1 = node.x or 0
                local y1 = node.y or 0
                local x2 = neighbor.x or 0
                local y2 = neighbor.y or 0
                drawLine(x1, y1, x2, y2, debug.colors.edge)
            end
        end
    end

    -- Draw nodes
    -- Node object IS the data (x, y are directly on the node)
    for id, node in pairs(builder._nodes or {}) do
        local x = node.x or 0
        local y = node.y or 0
        drawCircle(x, y, nodeRadius, debug.colors.node)
    end
end

--- Draw an influence map as a heat gradient
-- @param grid Grid The influence grid (values typically 0-1)
-- @param screenX number Screen X position
-- @param screenY number Screen Y position
-- @param cellSize number Size of each cell in pixels
-- @param minValue number? Minimum value for normalization (default: 0)
-- @param maxValue number? Maximum value for normalization (default: 1)
function debug.drawInfluence(grid, screenX, screenY, cellSize, minValue, maxValue)
    if not debug.enabled then return end

    minValue = minValue or 0
    maxValue = maxValue or 1
    local range = maxValue - minValue
    if range == 0 then range = 1 end

    for x = 1, grid.w do
        for y = 1, grid.h do
            local value = grid:get(x, y)
            local t = (value - minValue) / range
            t = math.max(0, math.min(1, t))

            local color = debug.lerp(debug.colors.influenceLow, debug.colors.influenceHigh, t)
            local px = screenX + (x - 1) * cellSize
            local py = screenY + (y - 1) * cellSize
            drawRect(px, py, cellSize, cellSize, color)
        end
    end
end

--- Draw a complete dungeon result (grid + room outlines + spawn points)
-- @param dungeon table Result from DungeonBuilder:build()
-- @param screenX number Screen X position
-- @param screenY number Screen Y position
-- @param cellSize number Size of each cell in pixels
function debug.drawDungeon(dungeon, screenX, screenY, cellSize)
    if not debug.enabled then return end

    -- Draw the grid first
    debug.drawGrid(dungeon.grid, screenX, screenY, cellSize)

    -- Draw room outlines
    for _, room in ipairs(dungeon.rooms or {}) do
        local rx = screenX + (room.x - 1) * cellSize
        local ry = screenY + (room.y - 1) * cellSize
        local rw = room.w * cellSize
        local rh = room.h * cellSize

        -- Draw room outline as 4 lines
        drawLine(rx, ry, rx + rw, ry, debug.colors.room)
        drawLine(rx + rw, ry, rx + rw, ry + rh, debug.colors.room)
        drawLine(rx + rw, ry + rh, rx, ry + rh, debug.colors.room)
        drawLine(rx, ry + rh, rx, ry, debug.colors.room)
    end

    -- Draw spawn points
    local spawnPoints = dungeon.spawnPoints or {}
    for _, spawn in ipairs(spawnPoints.enemies or {}) do
        local sx = screenX + (spawn.gx - 1) * cellSize + cellSize / 2
        local sy = screenY + (spawn.gy - 1) * cellSize + cellSize / 2
        drawCircle(sx, sy, cellSize / 3, debug.colors.enemy)
    end
    for _, spawn in ipairs(spawnPoints.treasures or {}) do
        local sx = screenX + (spawn.gx - 1) * cellSize + cellSize / 2
        local sy = screenY + (spawn.gy - 1) * cellSize + cellSize / 2
        drawCircle(sx, sy, cellSize / 3, debug.colors.treasure)
    end
end

--- Toggle debug visualization on/off
function debug.toggle()
    debug.enabled = not debug.enabled
    print(string.format("[procgen.debug] Visualization %s", debug.enabled and "ENABLED" or "DISABLED"))
end

_G.__PROCGEN_DEBUG__ = debug
return debug
