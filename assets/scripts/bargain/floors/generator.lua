-- assets/scripts/bargain/floors/generator.lua

local RNG = require("bargain.sim.rng")
local fallback = require("bargain.floors.fallback")

local generator = {}

local function ensure_rng(world)
    if type(world.rng) == "table" and world.rng.next then
        return world.rng
    end
    local seed = world.seed or 0
    world.rng = RNG.new(seed)
    return world.rng
end

local function build_grid(width, height)
    local tiles = {}
    for y = 1, height do
        tiles[y] = {}
        for x = 1, width do
            tiles[y][x] = "."
        end
    end

    for x = 1, width do
        tiles[1][x] = "#"
        tiles[height][x] = "#"
    end
    for y = 1, height do
        tiles[y][1] = "#"
        tiles[y][width] = "#"
    end

    return tiles
end

local function pick_floor_pos(rng, width, height)
    return {
        x = rng:int(2, width - 1),
        y = rng:int(2, height - 1),
    }
end

local function pick_with_cap(rng, width, height, exclude, max_attempts)
    for _ = 1, max_attempts do
        local pos = pick_floor_pos(rng, width, height)
        local key = pos.x .. "," .. pos.y
        if not exclude[key] then
            return pos
        end
    end
    return nil
end

function generator.generate(world, floor_num, opts)
    local rng = ensure_rng(world)
    local options = opts or {}
    local max_attempts = options.max_attempts or 10
    local w, h = 7, 7
    local tiles = build_grid(w, h)

    local spawn = { x = 2, y = 2 }

    if options.force_fallback then
        local grid = fallback.build()
        world.grid = grid
        world.floor_num = floor_num
        return grid
    end

    local exclude = {}
    exclude[spawn.x .. "," .. spawn.y] = true

    local stairs_up = nil
    if floor_num > 1 then
        stairs_up = pick_with_cap(rng, w, h, exclude, max_attempts)
        if not stairs_up then
            local grid = fallback.build()
            world.grid = grid
            world.floor_num = floor_num
            return grid
        end
        exclude[stairs_up.x .. "," .. stairs_up.y] = true
        tiles[stairs_up.y][stairs_up.x] = "<"
    end

    local stairs_down = nil
    if floor_num < 7 then
        stairs_down = pick_with_cap(rng, w, h, exclude, max_attempts)
        if not stairs_down then
            local grid = fallback.build()
            world.grid = grid
            world.floor_num = floor_num
            return grid
        end
        tiles[stairs_down.y][stairs_down.x] = ">"
    end

    local grid = {
        w = w,
        h = h,
        tiles = tiles,
        spawn = spawn,
        stairs_up = stairs_up,
        stairs_down = stairs_down,
    }

    world.grid = grid
    world.floor_num = floor_num

    return grid
end

function generator.generate_all(world, floor_count)
    local count = floor_count or 7
    local floors = {}
    for i = 1, count do
        floors[i] = generator.generate(world, i)
    end
    return floors
end

return generator
