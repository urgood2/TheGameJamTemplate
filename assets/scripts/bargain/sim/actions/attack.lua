-- assets/scripts/bargain/sim/actions/attack.lua

local combat = require("bargain.sim.combat")

local attack = {}

local function find_target(world, x, y)
    if not world or not world.entities or not world.entities.order or not world.entities.by_id then
        return nil
    end

    for _, id in ipairs(world.entities.order) do
        local entity = world.entities.by_id[id]
        if entity and entity.kind == "enemy" and (entity.hp or 0) > 0 then
            if entity.pos then
                if entity.pos.x == x and entity.pos.y == y then
                    return entity
                end
            elseif entity.x ~= nil and entity.y ~= nil then
                if entity.x == x and entity.y == y then
                    return entity
                end
            end
        end
    end

    return nil
end

function attack.apply(world, dx, dy)
    if type(world) ~= "table" then
        return false, "world_not_table"
    end

    local player = world.entities and world.entities.by_id and world.entities.by_id[world.player_id]
    if not player or not player.pos then
        return false, "missing_player"
    end

    local target_x = player.pos.x + dx
    local target_y = player.pos.y + dy
    local target = find_target(world, target_x, target_y)
    if not target then
        return false, "no_target"
    end

    local ok, err = combat.apply_attack(world, player.id or world.player_id, target.id)
    if not ok then
        return false, err or "attack_failed"
    end

    return true, target.id
end

return attack
