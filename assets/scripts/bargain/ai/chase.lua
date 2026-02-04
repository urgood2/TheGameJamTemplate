-- assets/scripts/bargain/ai/chase.lua

local attack = require("bargain.ai.attack")
local ordering = require("bargain.ai.ordering")

local chase = {}

local DIRS = ordering.direction_order()

local function manhattan(a, b)
    return math.abs(a.x - b.x) + math.abs(a.y - b.y)
end

function chase.should_act(world, enemy)
    local speed = enemy.speed or 1
    if speed <= 1 then
        return (world.turn or 0) % 2 == 0
    end
    return true
end

function chase.choose_action(world, enemy, player)
    if not chase.should_act(world, enemy) then
        return { type = "wait" }
    end

    local attack_action = attack.choose_action(enemy, player)
    if attack_action then
        return attack_action
    end

    local dist = manhattan(enemy.pos, player.pos)

    local range = enemy.chase_range or 6
    if dist > range then
        return { type = "wait" }
    end

    local best = nil
    local best_dist = dist
    for _, dir in ipairs(DIRS) do
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

return chase
