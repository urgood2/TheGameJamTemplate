local S = {}

function S.check(e, dt, opts)
    opts = opts or {}
    local eps = opts.eps or 2
    local window = opts.window or 0.8
    local key = opts.key or "nav"

    local pos = ai.sense.position(e)
    if not pos then return false end

    local last_pos = ai.bb.get(e, key .. ".last_pos", pos)
    local stuck_time = ai.bb.get(e, key .. ".stuck_time", 0)

    local dist = ai.sense.distance(pos, last_pos)

    if dist < eps then
        stuck_time = stuck_time + dt
    else
        stuck_time = 0
    end

    ai.bb.set(e, key .. ".last_pos", pos)
    ai.bb.set(e, key .. ".stuck_time", stuck_time)

    return stuck_time >= window
end

function S.reset(e, key)
    key = key or "nav"
    ai.bb.set(e, key .. ".stuck_time", 0)
end

return S
