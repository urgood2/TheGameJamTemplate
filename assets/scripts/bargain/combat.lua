-- assets/scripts/bargain/combat.lua

local combat = {}

local function ensure_stats(world)
    world.stats = world.stats or {}
    if type(world.stats.damage_dealt_total) ~= "number" then world.stats.damage_dealt_total = 0 end
    if type(world.stats.damage_taken_total) ~= "number" then world.stats.damage_taken_total = 0 end
    if type(world.stats.hp_lost_total) ~= "number" then world.stats.hp_lost_total = 0 end
end

function combat.apply_attack(world, attacker_id, target_id)
    if not world or not world.entities or not world.entities.by_id then
        return false, "missing_entities"
    end

    local attacker = world.entities.by_id[attacker_id]
    local target = world.entities.by_id[target_id]
    if not attacker or not target then
        return false, "missing_entity"
    end

    local damage = attacker.atk or 1
    target.hp = (target.hp or 0) - damage

    ensure_stats(world)
    if attacker.kind == "enemy" and target.kind == "player" then
        world.stats.damage_taken_total = world.stats.damage_taken_total + damage
        world.stats.hp_lost_total = world.stats.hp_lost_total + damage
    elseif attacker.kind == "player" and target.kind == "enemy" then
        world.stats.damage_dealt_total = world.stats.damage_dealt_total + damage
    end

    return true
end

return combat
