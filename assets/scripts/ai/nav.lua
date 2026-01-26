local N = {}

local DEFAULT_WORLD = "main"
local DEFAULT_ARRIVE = 16

function N.move_to(e, dest, opts)
    opts = opts or {}
    local world_name = opts.world or DEFAULT_WORLD
    local arrive = opts.arrive or DEFAULT_ARRIVE

    local start = ai.sense.position(e)
    if not start then return false end

    if PhysicsManager and PhysicsManager.has_world and not PhysicsManager.has_world(world_name) then
        print("[ai.nav] World '" .. world_name .. "' not found")
        return false
    end

    local path = PhysicsManager and PhysicsManager.find_path and
        PhysicsManager.find_path(world_name, start.x, start.y, dest.x, dest.y) or nil
    if not path or #path == 0 then
        path = { { x = dest.x, y = dest.y } }
    end

    steering.set_path(registry, e, path, arrive)

    ai.bb.set_vec2(e, "nav.dest", dest)
    ai.bb.set(e, "nav.world", world_name)
    ai.bb.set(e, "nav.active", true)
    ai.bb.set(e, "nav.start_time", GetTime())

    return true
end

function N.follow(e, opts)
    opts = opts or {}
    steering.path_follow(registry, e, opts.decel or 1.0, opts.weight or 1.0)
end

function N.chase(e, target, opts)
    opts = opts or {}
    local weight = opts.weight or 1.0
    steering.pursuit(registry, e, target, weight)
    ai.bb.set(e, "nav.chasing", target)
end

function N.flee(e, threat, opts)
    opts = opts or {}
    local weight = opts.weight or 1.0
    steering.evade(registry, e, threat, weight)
    ai.bb.set(e, "nav.fleeing", threat)
end

N._patrol = {}

function N.patrol(e, points, opts)
    opts = opts or {}
    local wait_time = opts.wait or 0.5
    local should_loop = opts.loop ~= false

    local eid = tostring(e)
    N._patrol[eid] = {
        points = points,
        idx = 1,
        wait = wait_time,
        loop = should_loop,
        wait_until = 0,
        world = opts.world,
        arrive = opts.arrive,
    }

    ai.bb.set(e, "patrol.active", true)
    local first = points[1]
    if first then
        N.move_to(e, first, { world = opts.world, arrive = opts.arrive })
    end
end

function N.patrol_update(e, dt)
    if not ai.bb.get(e, "patrol.active", false) then
        return "done"
    end

    local st = N._patrol[tostring(e)]
    if not st or not st.points or #st.points == 0 then
        ai.bb.set(e, "patrol.active", false)
        return "done"
    end

    local now = GetTime()
    if st.wait_until and now < st.wait_until then
        return "waiting"
    end

    if ai.bb.get(e, "nav.active", false) then
        N.follow(e)
    end

    if not N.arrived(e, DEFAULT_ARRIVE) then
        return "moving"
    end

    st.idx = st.idx + 1
    if st.idx > #st.points then
        if st.loop then
            st.idx = 1
        else
            ai.bb.set(e, "patrol.active", false)
            N._patrol[tostring(e)] = nil
            return "done"
        end
    end

    st.wait_until = now + (st.wait or 0)
    local nextP = st.points[st.idx]
    if nextP then
        N.move_to(e, nextP, { world = st.world, arrive = st.arrive })
    end
    return "waiting"
end

function N.stop(e)
    steering.set_path(registry, e, {}, DEFAULT_ARRIVE)
    local world_name = ai.bb.get(e, "nav.world", DEFAULT_WORLD)
    if PhysicsManager and PhysicsManager.get_world and physics and physics.SetVelocity then
        local world = PhysicsManager.get_world(world_name)
        if world then
            physics.SetVelocity(world, e, 0, 0)
        end
    end
    ai.bb.set(e, "nav.active", false)
    ai.bb.set(e, "patrol.active", false)
    N._patrol[tostring(e)] = nil
end

function N.arrived(e, threshold)
    threshold = threshold or DEFAULT_ARRIVE
    local dest = ai.bb.get_vec2(e, "nav.dest")
    if not dest then return true end
    return ai.sense.distance(e, dest) < threshold
end

return N
