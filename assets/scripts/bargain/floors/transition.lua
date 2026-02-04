-- assets/scripts/bargain/floors/transition.lua

local generator = require("bargain.floors.generator")
local placement = require("bargain.floors.placement")

local transition = {}

local function clamp_floor(value)
    if value < 1 then
        return 1
    end
    if value > 7 then
        return 7
    end
    return value
end

function transition.is_boss_floor(world)
    if not world or type(world.floor_num) ~= "number" then
        return false
    end
    return world.floor_num >= 7
end

function transition.descend(world, opts)
    if type(world) ~= "table" then
        return false, "world_not_table"
    end

    local current = tonumber(world.floor_num) or 1
    current = clamp_floor(current)

    if current >= 7 then
        world.floor_num = 7
        world.is_boss_floor = true
        return false, "already_at_boss_floor"
    end

    local next_floor = clamp_floor(current + 1)
    world.floor_num = next_floor
    world.is_boss_floor = next_floor == 7

    local options = opts or {}
    local grid = generator.generate(world, next_floor, options.generator)
    if grid then
        placement.apply(world, grid, options.placement)
    end

    return true, next_floor
end

return transition
