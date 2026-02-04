-- assets/scripts/bargain/floors/fallback.lua

local fallback = {}

function fallback.build()
    local w, h = 7, 7
    local tiles = {}
    for y = 1, h do
        tiles[y] = {}
        for x = 1, w do
            tiles[y][x] = "."
        end
    end

    for x = 1, w do
        tiles[1][x] = "#"
        tiles[h][x] = "#"
    end
    for y = 1, h do
        tiles[y][1] = "#"
        tiles[y][w] = "#"
    end

    local spawn = { x = 2, y = 2 }
    local stairs_down = { x = w - 1, y = h - 1 }
    tiles[stairs_down.y][stairs_down.x] = ">"

    return {
        w = w,
        h = h,
        tiles = tiles,
        spawn = spawn,
        stairs_up = nil,
        stairs_down = stairs_down,
        is_fallback = true,
    }
end

return fallback
