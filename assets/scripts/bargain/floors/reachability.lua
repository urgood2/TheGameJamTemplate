-- assets/scripts/bargain/floors/reachability.lua

local reachability = {}

local DIRS = {
    { dx = 0, dy = -1 },
    { dx = 1, dy = 0 },
    { dx = 0, dy = 1 },
    { dx = -1, dy = 0 },
}

local function is_walkable(tile)
    return tile ~= "#"
end

local function in_bounds(grid, x, y)
    return x >= 1 and y >= 1 and x <= grid.w and y <= grid.h
end

local function bfs(grid, start)
    local visited = {}
    local queue = { start }
    visited[start.y * 1000 + start.x] = true

    local head = 1
    while head <= #queue do
        local node = queue[head]
        head = head + 1

        for _, dir in ipairs(DIRS) do
            local nx = node.x + dir.dx
            local ny = node.y + dir.dy
            if in_bounds(grid, nx, ny) then
                local key = ny * 1000 + nx
                if not visited[key] and is_walkable(grid.tiles[ny][nx]) then
                    visited[key] = true
                    queue[#queue + 1] = { x = nx, y = ny }
                end
            end
        end
    end

    return visited
end

function reachability.validate(grid)
    local errors = {}
    if not grid or not grid.tiles then
        return false, { "missing_grid" }
    end

    local spawn = grid.spawn or { x = 2, y = 2 }
    if not in_bounds(grid, spawn.x, spawn.y) then
        return false, { "spawn_out_of_bounds" }
    end

    local visited = bfs(grid, spawn)

    local function is_visited(pos)
        local key = pos.y * 1000 + pos.x
        return visited[key] == true
    end

    if grid.stairs_up and not is_visited(grid.stairs_up) then
        errors[#errors + 1] = "stairs_up_unreachable"
    end

    if grid.stairs_down and not is_visited(grid.stairs_down) then
        errors[#errors + 1] = "stairs_down_unreachable"
    end

    for y = 1, grid.h do
        for x = 1, grid.w do
            if is_walkable(grid.tiles[y][x]) then
                local key = y * 1000 + x
                if not visited[key] then
                    errors[#errors + 1] = "isolated_region"
                    y = grid.h
                    break
                end
            end
        end
    end

    return #errors == 0, errors
end

return reachability
