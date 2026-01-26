local P = {}

P._sensors = {}

function P.add_sensor(e, name, period, fn)
    local eid = tostring(e)
    P._sensors[eid] = P._sensors[eid] or {}
    P._sensors[eid][name] = {
        period = period,
        next_run = GetTime(),
        fn = fn,
    }
end

function P.remove_sensor(e, name)
    local eid = tostring(e)
    if P._sensors[eid] then
        P._sensors[eid][name] = nil
    end
end

function P.tick(e, dt)
    local eid = tostring(e)
    local sensors = P._sensors[eid]
    if not sensors then return end

    local now = GetTime()
    for name, s in pairs(sensors) do
        if now >= s.next_run then
            s.next_run = now + s.period
            local ok, err = pcall(s.fn, e, dt)
            if not ok then
                print("[ai.perception] Sensor '" .. name .. "' error: " .. tostring(err))
            end
        end
    end
end

function P.clear(e)
    P._sensors[tostring(e)] = nil
end

function P.enemy_scanner(e, opts)
    local range = opts.range or 200
    local period = 1.0 / (opts.update_hz or 5)

    P.add_sensor(e, "enemy_scan", period, function(ent, dt)
        local nearest, dist = ai.sense.nearest(ent, range, {
            filter = function(o)
                return o ~= ent
            end
        })

        if nearest then
            ai.memory.remember(ent, "target", nearest, 3.0)
            ai.memory.remember_pos(ent, "target_last_pos", ai.sense.position(nearest), 5.0)
            ai.bb.set(ent, "target_dist", dist)
            ai.set_worldstate(ent, "enemyvisible", true)
        else
            ai.set_worldstate(ent, "enemyvisible", false)
        end
    end)
end

return P
