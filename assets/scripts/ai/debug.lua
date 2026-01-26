local D = {}

D._enabled = false
D._watch = {}
D._items = {}

local function now() return GetTime() end

local function push(item, ttl)
    item.expires = ttl and (now() + ttl) or (now() + 0.016)
    table.insert(D._items, item)
end

function D.set_enabled(en)
    D._enabled = not not en
end

function D.circle(pos, radius, color, ttl)
    if not D._enabled then return end
    push({ kind = "circle", pos = pos, radius = radius, color = color }, ttl)
end

function D.line(a, b, color, ttl)
    if not D._enabled then return end
    push({ kind = "line", a = a, b = b, color = color }, ttl)
end

function D.text(pos, text, color, ttl)
    if not D._enabled then return end
    push({ kind = "text", pos = pos, text = text, color = color }, ttl or 0.25)
end

function D.trace(e, category, msg, data)
    local prefix = "[ai." .. tostring(category) .. "] "
    if log_debug then
        log_debug(prefix .. tostring(msg), data)
    else
        print(prefix .. tostring(msg))
    end

    if D._enabled and ai and ai.sense and ai.sense.position then
        local pos = ai.sense.position(e)
        if pos then
            D.text({ x = pos.x, y = pos.y - 18 }, tostring(msg), nil, 0.35)
        end
    end
end

function D.watch(e, enabled)
    D._watch[tostring(e)] = not not enabled
end

function D.inspect(e, opts)
    opts = opts or {}
    local bb = ai.get_blackboard and ai.get_blackboard(e) or nil
    return {
        goap = ai.get_goap_state and ai.get_goap_state(e) or nil,
        trace = ai.get_trace_events and ai.get_trace_events(e, opts.trace_count or 20) or nil,
        blackboard_size = (bb and bb:size()) or 0,
    }
end

function D.tick(dt)
    if not (D._enabled and command_buffer and layers and layers.sprites and layer) then return end
    local t = now()

    for i = #D._items, 1, -1 do
        local it = D._items[i]
        if t > (it.expires or 0) then
            table.remove(D._items, i)
        else
            if it.kind == "circle" then
                command_buffer.queueDrawCircleLine(layers.sprites, function(c)
                    c.x = it.pos.x; c.y = it.pos.y
                    c.innerRadius = it.radius - 1
                    c.outerRadius = it.radius
                    c.segments = 48
                    c.startAngle = 0
                    c.endAngle = 360
                    c.color = it.color or (util and util.getColor and util.getColor("WHITE")) or WHITE
                end, 9999, layer.DrawCommandSpace.World)
            elseif it.kind == "line" then
                command_buffer.queueDrawLine(layers.sprites, function(c)
                    c.x1 = it.a.x; c.y1 = it.a.y
                    c.x2 = it.b.x; c.y2 = it.b.y
                    c.color = it.color or (util and util.getColor and util.getColor("WHITE")) or WHITE
                    c.lineWidth = 2
                end, 9999, layer.DrawCommandSpace.World)
            elseif it.kind == "text" then
                command_buffer.queueDrawText(layers.sprites, function(c)
                    c.text = it.text
                    c.x = it.pos.x; c.y = it.pos.y
                    c.fontSize = 12
                    c.color = it.color or (util and util.getColor and util.getColor("WHITE")) or WHITE
                end, 9999, layer.DrawCommandSpace.World)
            end
        end
    end
end

return D
