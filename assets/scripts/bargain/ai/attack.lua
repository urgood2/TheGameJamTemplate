-- assets/scripts/bargain/ai/attack.lua

local attack = {}

local function manhattan(a, b)
    return math.abs(a.x - b.x) + math.abs(a.y - b.y)
end

function attack.should_attack(enemy, player)
    if not enemy or not player then
        return false
    end
    return manhattan(enemy.pos, player.pos) == 1
end

function attack.choose_action(enemy, player)
    if attack.should_attack(enemy, player) then
        return { type = "attack", target_id = player.id }
    end
    return nil
end

return attack
