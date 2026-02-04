-- assets/scripts/bargain/enemies/spawn.lua

local templates = require("bargain.enemies.templates")

local spawn = {}

local function next_enemy_index(world, prefix)
    world._enemy_counts = world._enemy_counts or {}
    local count = (world._enemy_counts[prefix] or 0) + 1
    world._enemy_counts[prefix] = count
    return count
end

function spawn.create_enemy(world, template_id, pos)
    local template = templates[template_id]
    if not template then
        return nil, "unknown_template"
    end

    world.entities = world.entities or { order = {}, by_id = {} }
    world.entities.order = world.entities.order or {}
    world.entities.by_id = world.entities.by_id or {}

    local index = next_enemy_index(world, template_id)
    local id = string.format("e.%s.%d", template_id, index)

    local enemy = {
        id = id,
        kind = "enemy",
        template_id = template_id,
        name = template.name,
        hp = template.hp,
        atk = template.atk,
        speed = template.speed,
        is_boss = template.is_boss or false,
        pos = { x = pos.x, y = pos.y },
    }

    world.entities.by_id[id] = enemy
    table.insert(world.entities.order, id)

    return enemy
end

return spawn
