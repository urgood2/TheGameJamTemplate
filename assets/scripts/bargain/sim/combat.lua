-- assets/scripts/bargain/sim/combat.lua

local events = require("bargain.sim.events")

local combat = {}

local function ensure_stats(world)
    world.stats = world.stats or {}
    if type(world.stats.damage_dealt_total) ~= "number" then world.stats.damage_dealt_total = 0 end
    if type(world.stats.damage_taken_total) ~= "number" then world.stats.damage_taken_total = 0 end
    if type(world.stats.hp_lost_total) ~= "number" then world.stats.hp_lost_total = 0 end
end

local function get_damage(attacker)
    if attacker and type(attacker.damage) == "number" then
        return attacker.damage
    end
    if attacker and type(attacker.atk) == "number" then
        return attacker.atk
    end
    return 1
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

    local damage = get_damage(attacker)
    local before_hp = target.hp or 0
    target.hp = before_hp - damage

    ensure_stats(world)
    if attacker.kind == "enemy" and target.kind == "player" then
        world.stats.damage_taken_total = world.stats.damage_taken_total + damage
        world.stats.hp_lost_total = world.stats.hp_lost_total + damage
    elseif attacker.kind == "player" and target.kind == "enemy" then
        world.stats.damage_dealt_total = world.stats.damage_dealt_total + damage
    end

    events.emit(world, {
        type = "damage",
        source_id = attacker_id,
        target_id = target_id,
        amount = damage,
    })

    local dead = (target.hp or 0) <= 0
    if dead then
        events.emit(world, { type = "death", target_id = target_id })
    end

    return true, dead
end

return combat
