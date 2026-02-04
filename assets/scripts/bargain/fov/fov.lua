-- assets/scripts/bargain/fov/fov.lua

local fov = {}

local function is_wall(grid, x, y)
    return grid.tiles[y][x] == "#"
end

local function in_bounds(grid, x, y)
    return x >= 1 and y >= 1 and x <= grid.w and y <= grid.h
end

local function line_of_sight(grid, start, target)
    local x0, y0 = start.x, start.y
    local x1, y1 = target.x, target.y

    local dx = math.abs(x1 - x0)
    local dy = math.abs(y1 - y0)
    local sx = (x0 < x1) and 1 or -1
    local sy = (y0 < y1) and 1 or -1
    local err = dx - dy

    local x, y = x0, y0
    while true do
        if x == x1 and y == y1 then
            return true
        end

        local e2 = 2 * err
        if e2 > -dy then
            err = err - dy
            x = x + sx
        end
        if e2 < dx then
            err = err + dx
            y = y + sy
        end

        if x == x1 and y == y1 then
            return true
        end

        if in_bounds(grid, x, y) and is_wall(grid, x, y) then
            return false
        end
    end
end

function fov.compute(grid, origin, radius)
    local r = radius or 4
    local visible = {}

    for y = 1, grid.h do
        for x = 1, grid.w do
            local dx = x - origin.x
            local dy = y - origin.y
            local dist2 = dx * dx + dy * dy
            if dist2 <= r * r then
                local can_see = line_of_sight(grid, origin, { x = x, y = y })
                if can_see then
                    visible[x .. "," .. y] = true
                end
            end
        end
    end

    return visible
end

return fov
