-- assets/scripts/bargain/sim/entities.lua

local entities = {}

local PREFIX = {
    player = "p",
    enemy = "e",
    boss = "b",
}

local function ensure_registry(reg)
    reg.by_id = reg.by_id or {}
    reg.order = reg.order or {}
    reg._counters = reg._counters or { player = 0, enemy = 0, boss = 0 }
end

function entities.new_registry()
    local reg = { by_id = {}, order = {}, _counters = { player = 0, enemy = 0, boss = 0 } }
    return reg
end

local function next_id(reg, kind)
    ensure_registry(reg)
    local key = kind or "entity"
    local prefix = PREFIX[key] or "e"
    reg._counters[key] = (reg._counters[key] or 0) + 1
    return string.format("%s.%d", prefix, reg._counters[key])
end

local function insert_order(reg, id)
    reg.order[#reg.order + 1] = id
    table.sort(reg.order)
end

function entities.spawn(reg, kind, props)
    ensure_registry(reg)
    local id = next_id(reg, kind)
    local hp = props.hp or 1
    local max_hp = props.max_hp or hp
    local entity = {
        id = id,
        type = kind,
        kind = kind,
        x = props.x or 1,
        y = props.y or 1,
        hp = hp,
        max_hp = max_hp,
        speed = props.speed or 1,
        damage = props.damage or props.atk or 1,
    }

    reg.by_id[id] = entity
    insert_order(reg, id)

    return entity
end

function entities.remove(reg, id)
    if not reg or not reg.by_id then
        return
    end
    reg.by_id[id] = nil
    if reg.order then
        for i = 1, #reg.order do
            if reg.order[i] == id then
                table.remove(reg.order, i)
                break
            end
        end
    end
end

function entities.ordered_ids(reg)
    if not reg or not reg.order then
        return {}
    end
    local out = {}
    for i = 1, #reg.order do
        out[i] = reg.order[i]
    end
    return out
end

function entities.ordered_entities(reg)
    if not reg or not reg.order or not reg.by_id then
        return {}
    end
    local out = {}
    for i = 1, #reg.order do
        local id = reg.order[i]
        out[#out + 1] = reg.by_id[id]
    end
    return out
end

return entities
