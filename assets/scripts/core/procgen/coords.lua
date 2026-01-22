-- assets/scripts/core/procgen/coords.lua
-- Coordinate conversion utilities for procgen
-- Handles World <-> Grid <-> Pattern coordinate systems
--
-- Coordinate Systems:
--   Grid coords (Grid.lua / IntGrid / LDtk): 1-indexed (gx, gy) where 1 <= gx <= w
--   Pattern coords (Forma): 0-indexed (px, py) where 0 <= px < w
--   World coords: pixels (float)

-- Ensure vendor is loaded first to set up forma path aliases
local vendor = require("core.procgen.vendor")
local formaPattern = vendor.forma.pattern

local coords = {}

-- Configuration (set once at game init)
coords.TILE_SIZE = 16
coords.ORIGIN_X = 0
coords.ORIGIN_Y = 0

--- Convert world coordinates to 1-indexed grid coordinates
-- @param worldX number World X position in pixels
-- @param worldY number World Y position in pixels
-- @param tileSize number? Optional tile size (defaults to coords.TILE_SIZE)
-- @return number, number Grid X and Y (1-indexed)
function coords.worldToGrid(worldX, worldY, tileSize)
    tileSize = tileSize or coords.TILE_SIZE
    local gx = math.floor((worldX - coords.ORIGIN_X) / tileSize) + 1
    local gy = math.floor((worldY - coords.ORIGIN_Y) / tileSize) + 1
    return gx, gy
end

--- Convert 1-indexed grid coordinates to world coordinates (cell center)
-- @param gridX number Grid X position (1-indexed)
-- @param gridY number Grid Y position (1-indexed)
-- @param tileSize number? Optional tile size (defaults to coords.TILE_SIZE)
-- @return number, number World X and Y (center of cell)
function coords.gridToWorld(gridX, gridY, tileSize)
    tileSize = tileSize or coords.TILE_SIZE
    local wx = (gridX - 1) * tileSize + coords.ORIGIN_X + tileSize / 2
    local wy = (gridY - 1) * tileSize + coords.ORIGIN_Y + tileSize / 2
    return wx, wy
end

--- Convert 1-indexed grid coordinates to world rectangle (top-left corner + size)
-- @param gridX number Grid X position (1-indexed)
-- @param gridY number Grid Y position (1-indexed)
-- @param tileSize number? Optional tile size (defaults to coords.TILE_SIZE)
-- @return table Rectangle {x, y, w, h}
function coords.gridToWorldRect(gridX, gridY, tileSize)
    tileSize = tileSize or coords.TILE_SIZE
    return {
        x = (gridX - 1) * tileSize + coords.ORIGIN_X,
        y = (gridY - 1) * tileSize + coords.ORIGIN_Y,
        w = tileSize,
        h = tileSize
    }
end

--- Convert Forma pattern (0-indexed) to Grid (1-indexed)
-- Iterates over all cells in the pattern and sets corresponding grid cells.
-- The offset parameters specify where pattern cell (0,0) lands in the grid.
-- With default offset (1,1), pattern (0,0) maps to grid (1,1).
-- With offset (5,5), pattern (0,0) maps to grid (5,5).
-- @param pattern table Forma pattern with :cells() iterator
-- @param grid table Grid instance with :set() method
-- @param value any Value to set in grid cells (default: 1)
-- @param offsetGX number? Grid position where pattern origin lands (default: 1)
-- @param offsetGY number? Grid position where pattern origin lands (default: 1)
-- @return table The modified grid
function coords.patternToGrid(pattern, grid, value, offsetGX, offsetGY)
    offsetGX = offsetGX or 1
    offsetGY = offsetGY or 1
    value = value or 1
    for cell in pattern:cells() do
        -- Pattern is 0-indexed, Grid is 1-indexed
        -- Pattern cell (px, py) -> Grid cell (px + offsetGX, py + offsetGY)
        grid:set(cell.x + offsetGX, cell.y + offsetGY, value)
    end
    return grid
end

--- Convert Grid (1-indexed) to Forma pattern (0-indexed)
-- Creates a new pattern containing all cells matching the specified value
-- @param grid table Grid instance with :apply() and :get() methods
-- @param matchValue any Value to match in grid cells
-- @return table New Forma pattern
function coords.gridToPattern(grid, matchValue)
    local p = formaPattern.new()
    grid:apply(function(g, x, y)
        if g:get(x, y) == matchValue then
            -- Grid is 1-indexed, Pattern is 0-indexed
            p:insert(x - 1, y - 1)
        end
    end)
    return p
end

return coords
