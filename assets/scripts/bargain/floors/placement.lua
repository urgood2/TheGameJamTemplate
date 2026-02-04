-- assets/scripts/bargain/floors/placement.lua

local spawn_enemy = require("bargain.enemies.spawn")

local placement = {}

local function in_bounds(grid, x, y)
    if not grid then
        return false
    end
    local w = grid.w or 0
    local h = grid.h or 0
    return x >= 1 and y >= 1 and x <= w and y <= h
end

local function is_floor(tile)
    return tile == "."
end

local function is_floor_or_stairs(tile)
    return tile == "." or tile == ">"
end

local function key_for(pos)
    return pos.x .. "," .. pos.y
end

local function find_floor_tile(grid, exclude)
    for y = 1, grid.h do
        local row = grid.tiles[y]
        for x = 1, grid.w do
            if row and is_floor(row[x]) then
                local key = x .. "," .. y
                if not exclude[key] then
                    return { x = x, y = y }
                end
            end
        end
    end
    return nil
end

local function ensure_player(world, spawn)
    world.entities = world.entities or { order = {}, by_id = {} }
    world.entities.order = world.entities.order or {}
    world.entities.by_id = world.entities.by_id or {}

    local player_id = world.player_id or "p.1"
    world.player_id = player_id

    local player = world.entities.by_id[player_id]
    if not player then
        player = {
            id = player_id,
            kind = "player",
            pos = { x = spawn.x, y = spawn.y },
            hp = 10,
        }
        world.entities.by_id[player_id] = player
        table.insert(world.entities.order, player_id)
    else
        player.pos = player.pos or {}
        player.pos.x = spawn.x
        player.pos.y = spawn.y
    end
end

function placement.apply(world, grid, opts)
    if type(world) ~= "table" then
        return false, "world_not_table"
    end
    if type(grid) ~= "table" or type(grid.tiles) ~= "table" then
        return false, "grid_missing"
    end

    local options = opts or {}
    local exclude = {}

    local spawn = grid.spawn or { x = 2, y = 2 }
    if not in_bounds(grid, spawn.x, spawn.y) or not is_floor(grid.tiles[spawn.y] and grid.tiles[spawn.y][spawn.x]) then
        local fallback_spawn = find_floor_tile(grid, exclude)
        if fallback_spawn then
            spawn = fallback_spawn
        end
    end
    grid.spawn = spawn
    exclude[key_for(spawn)] = true

    ensure_player(world, spawn)

    local stairs_down = grid.stairs_down
    if stairs_down and not in_bounds(grid, stairs_down.x, stairs_down.y) then
        stairs_down = nil
    end
    if stairs_down and exclude[key_for(stairs_down)] then
        stairs_down = nil
    end
    if stairs_down and not is_floor_or_stairs(grid.tiles[stairs_down.y] and grid.tiles[stairs_down.y][stairs_down.x]) then
        stairs_down = nil
    end
    if not stairs_down then
        stairs_down = find_floor_tile(grid, exclude)
    end
    if stairs_down then
        grid.stairs_down = stairs_down
        grid.tiles[stairs_down.y][stairs_down.x] = ">"
        exclude[key_for(stairs_down)] = true
    end

    local enemy_count = options.enemy_count or 1
    local template_id = options.enemy_template or "rat"
    for _ = 1, enemy_count do
        local pos = find_floor_tile(grid, exclude)
        if not pos then
            break
        end
        spawn_enemy.create_enemy(world, template_id, pos)
        exclude[key_for(pos)] = true
    end

    return true
end

return placement
