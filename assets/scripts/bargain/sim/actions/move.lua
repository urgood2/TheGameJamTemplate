-- assets/scripts/bargain/sim/actions/move.lua

local events = require("bargain.sim.events")

local move = {}

local function in_bounds(grid, x, y)
    if not grid then return false end
    local w = grid.w or 0
    local h = grid.h or 0
    return x >= 1 and y >= 1 and x <= w and y <= h
end

local function is_wall(grid, x, y)
    if not grid or not grid.tiles then
        return false
    end
    local row = grid.tiles[y]
    if not row then
        return false
    end
    return row[x] == "#"
end

local function blocked_by_entity(world, x, y)
    if not world.entities or not world.entities.order or not world.entities.by_id then
        return false
    end
    for _, id in ipairs(world.entities.order) do
        if id ~= world.player_id then
            local entity = world.entities.by_id[id]
            if entity and entity.pos and entity.pos.x == x and entity.pos.y == y then
                return true
            end
        end
    end
    return false
end

function move.apply(world, dx, dy)
    if type(world) ~= "table" then
        return false, "world_not_table"
    end

    local player = world.entities and world.entities.by_id and world.entities.by_id[world.player_id]
    if not player or not player.pos then
        return false, "missing_player"
    end

    local from_x = player.pos.x
    local from_y = player.pos.y
    local target_x = from_x + dx
    local target_y = from_y + dy

    if not in_bounds(world.grid, target_x, target_y) then
        return false, "blocked_bounds"
    end

    if is_wall(world.grid, target_x, target_y) then
        return false, "blocked_wall"
    end

    if blocked_by_entity(world, target_x, target_y) then
        return false, "blocked_entity"
    end

    player.pos.x = target_x
    player.pos.y = target_y
    events.emit(world, {
        type = "move",
        entity_id = player.id or world.player_id,
        from = { x = from_x, y = from_y },
        to = { x = target_x, y = target_y },
    })
    return true
end

return move
