-- assets/scripts/bargain/sim/events.lua

local events = {}

events.MAX_EVENTS = 20

local function ensure_list(world)
    if type(world) ~= "table" then
        return nil
    end
    if type(world._events) ~= "table" then
        world._events = {}
    end
    return world._events
end

function events.begin(world)
    if type(world) ~= "table" then
        return
    end
    world._events = {}
end

function events.emit(world, event)
    local list = ensure_list(world)
    if not list then
        return
    end
    if type(event) ~= "table" then
        return
    end
    if #list >= events.MAX_EVENTS then
        world._events_truncated = true
        return
    end
    list[#list + 1] = event
end

function events.snapshot(world)
    if type(world) ~= "table" or type(world._events) ~= "table" then
        return {}
    end
    local list = world._events
    local out = {}
    local cap = events.MAX_EVENTS
    local count = #list
    if count > cap then
        count = cap
    end
    for i = 1, count do
        out[i] = list[i]
    end
    return out
end

return events
