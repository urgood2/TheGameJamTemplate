-- assets/scripts/bargain/sim/grid.lua

local grid = {}

grid.TILES = {
    floor = ".",
    wall = "#",
    stairs_down = ">",
}

local function fill_tiles(width, height)
    local tiles = {}
    for y = 1, height do
        tiles[y] = {}
        for x = 1, width do
            tiles[y][x] = grid.TILES.floor
        end
    end

    for x = 1, width do
        tiles[1][x] = grid.TILES.wall
        tiles[height][x] = grid.TILES.wall
    end
    for y = 1, height do
        tiles[y][1] = grid.TILES.wall
        tiles[y][width] = grid.TILES.wall
    end

    return tiles
end

function grid.in_bounds(state, x, y)
    if not state then
        return false
    end
    local w = state.w or 0
    local h = state.h or 0
    return x >= 1 and y >= 1 and x <= w and y <= h
end

function grid.get_tile(state, x, y)
    if not state or not state.tiles then
        return nil
    end
    local row = state.tiles[y]
    if not row then
        return nil
    end
    return row[x]
end

function grid.build(width, height)
    local w = width or 7
    local h = height or 7
    local tiles = fill_tiles(w, h)

    local stairs_down = { x = w - 1, y = h - 1 }
    if grid.in_bounds({ w = w, h = h }, stairs_down.x, stairs_down.y) then
        tiles[stairs_down.y][stairs_down.x] = grid.TILES.stairs_down
    end

    return {
        w = w,
        h = h,
        tiles = tiles,
        stairs_down = stairs_down,
    }
end

grid.new = grid.build

return grid
