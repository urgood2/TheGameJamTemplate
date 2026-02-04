-- assets/scripts/bargain/sim/stats.lua

local stats = {}

stats.KEYS = {
    "hp_lost_total",
    "turns_elapsed",
    "damage_dealt_total",
    "damage_taken_total",
    "forced_actions_count",
    "denied_actions_count",
    "visible_tiles_count",
    "resources_spent_total",
}

function stats.ensure(world)
    world.stats = world.stats or {}
    for i = 1, #stats.KEYS do
        local key = stats.KEYS[i]
        if type(world.stats[key]) ~= "number" then
            world.stats[key] = 0
        end
    end
end

function stats.on_turn(world)
    stats.ensure(world)
    world.stats.turns_elapsed = world.stats.turns_elapsed + 1
end

function stats.bump(world, key, delta)
    stats.ensure(world)
    if type(delta) ~= "number" then
        return
    end
    world.stats[key] = (world.stats[key] or 0) + delta
end

function stats.set(world, key, value)
    stats.ensure(world)
    if type(value) ~= "number" then
        return
    end
    world.stats[key] = value
end

return stats
