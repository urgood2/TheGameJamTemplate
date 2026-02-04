-- assets/scripts/bargain/enemies/boss.lua

local spawn = require("bargain.enemies.spawn")
local attack = require("bargain.ai.attack")
local ordering = require("bargain.ai.ordering")

local boss = {}

local function manhattan(a, b)
    return math.abs(a.x - b.x) + math.abs(a.y - b.y)
end

function boss.spawn(world, pos)
    if world and type(world.floor_num) == "number" and world.floor_num < 7 then
        return nil, "wrong_floor"
    end
    local position = pos or { x = 1, y = 1 }
    local enemy = spawn.create_enemy(world, "boss", position)
    if enemy then
        enemy.chase_range = 12
        enemy.behavior = "boss"
    end
    return enemy
end

function boss.choose_action(world, enemy, player)
    local attack_action = attack.choose_action(enemy, player)
    if attack_action then
        return attack_action
    end

    local dist = manhattan(enemy.pos, player.pos)
    if dist == 0 then
        return { type = "wait" }
    end

    local dirs = ordering.direction_order()
    local best = nil
    local best_dist = dist
    for _, dir in ipairs(dirs) do
        local next_pos = { x = enemy.pos.x + dir.dx, y = enemy.pos.y + dir.dy }
        local next_dist = manhattan(next_pos, player.pos)
        if next_dist < best_dist then
            best = dir
            best_dist = next_dist
            break
        end
    end

    if not best then
        return { type = "wait" }
    end

    return { type = "chase", dx = best.dx, dy = best.dy }
end

return boss
