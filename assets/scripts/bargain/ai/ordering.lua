-- assets/scripts/bargain/ai/ordering.lua

local ordering = {}

local DIRS = {
    { dx = 0, dy = -1 }, -- N
    { dx = 1, dy = 0 },  -- E
    { dx = 0, dy = 1 },  -- S
    { dx = -1, dy = 0 }, -- W
}

function ordering.direction_order()
    local out = {}
    for i = 1, #DIRS do
        out[i] = DIRS[i]
    end
    return out
end

local function enemy_ids_from_order(world)
    local ids = {}
    if not world.entities or not world.entities.order or not world.entities.by_id then
        return ids
    end
    for _, id in ipairs(world.entities.order) do
        local entity = world.entities.by_id[id]
        if entity and entity.kind == "enemy" then
            ids[#ids + 1] = id
        end
    end
    return ids
end

function ordering.enemy_order(world)
    local ids = enemy_ids_from_order(world)
    table.sort(ids, function(a, b)
        local ea = world.entities.by_id[a]
        local eb = world.entities.by_id[b]
        local sa = ea and ea.speed or 0
        local sb = eb and eb.speed or 0
        if sa ~= sb then
            return sa > sb
        end
        return a < b
    end)
    return ids
end

return ordering
