-- assets/scripts/core/procgen/grid_builder.lua
-- Fluent builder pattern for Grid operations
--
-- Usage:
--   local GridBuilder = require("core.procgen.grid_builder")
--   local grid = GridBuilder.new(100, 100, 0)
--     :fill(1)
--     :rect(10, 10, 20, 20, 2)
--     :circle(50, 50, 15, 3)
--     :build()

local vendor = require("core.procgen.vendor")
local Grid = vendor.Grid

local GridBuilder = {}
GridBuilder.__index = GridBuilder

--- Create a new GridBuilder
-- @param w number Grid width
-- @param h number Grid height
-- @param default any Default fill value (default: 0)
-- @return GridBuilder
function GridBuilder.new(w, h, default)
    local self = setmetatable({}, GridBuilder)
    self._w = w
    self._h = h
    self._default = default or 0
    self._grid = Grid(w, h, self._default)
    return self
end

--- Fill entire grid with a value
-- @param value any Value to fill with
-- @return GridBuilder self for chaining
function GridBuilder:fill(value)
    self._grid:apply(function(g, x, y)
        g:set(x, y, value)
    end)
    return self
end

--- Draw a filled rectangle
-- @param x number Top-left X (1-indexed)
-- @param y number Top-left Y (1-indexed)
-- @param w number Width
-- @param h number Height
-- @param value any Value to fill rectangle with
-- @return GridBuilder self for chaining
function GridBuilder:rect(x, y, w, h, value)
    for gx = x, x + w - 1 do
        for gy = y, y + h - 1 do
            self._grid:set(gx, gy, value)
        end
    end
    return self
end

--- Draw a filled circle
-- @param cx number Center X (1-indexed)
-- @param cy number Center Y (1-indexed)
-- @param radius number Circle radius
-- @param value any Value to fill circle with
-- @return GridBuilder self for chaining
function GridBuilder:circle(cx, cy, radius, value)
    local r2 = radius * radius
    for gx = 1, self._w do
        for gy = 1, self._h do
            local dx = gx - cx
            local dy = gy - cy
            if dx * dx + dy * dy <= r2 then
                self._grid:set(gx, gy, value)
            end
        end
    end
    return self
end

--- Fill cells randomly based on density
-- @param density number Probability (0-1) of filling each cell
-- @param values table Array of possible values to fill with
-- @return GridBuilder self for chaining
function GridBuilder:noise(density, values)
    values = values or {1}
    for gx = 1, self._w do
        for gy = 1, self._h do
            if math.random() < density then
                local value = values[math.random(#values)]
                self._grid:set(gx, gy, value)
            end
        end
    end
    return self
end

--- Stamp another grid at a position
-- Note: Cells extending beyond grid bounds are silently clipped
-- @param stamp Grid Grid to paste
-- @param x number Position X (1-indexed)
-- @param y number Position Y (1-indexed)
-- @return GridBuilder self for chaining
function GridBuilder:stamp(stamp, x, y)
    for sx = 1, stamp.w do
        for sy = 1, stamp.h do
            local value = stamp:get(sx, sy)
            self._grid:set(x + sx - 1, y + sy - 1, value)
        end
    end
    return self
end

--- Apply a custom function to all cells
-- @param fn function Function(grid, x, y) to apply
-- @return GridBuilder self for chaining
function GridBuilder:apply(fn)
    self._grid:apply(fn)
    return self
end

--- Build and return the final Grid instance
-- @return Grid The constructed grid
function GridBuilder:build()
    return self._grid
end

--- Find connected components (islands) with a specific value
-- Uses the underlying Grid:flood_fill method
-- @param value any Value to find islands of
-- @return table Array of island info
function GridBuilder:findIslands(value)
    return self._grid:flood_fill(value)
end

--- Reset the builder for reuse
-- @return GridBuilder self for chaining
function GridBuilder:reset()
    self._grid = Grid(self._w, self._h, self._default)
    return self
end

return GridBuilder
