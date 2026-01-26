ai = ai or {}
ai.sense = ai.sense or {}

local S = ai.sense

local function as_pos(v)
    if type(v) == "table" and v.x and v.y then
        return v
    end
    if S.position then
        return S.position(v)
    end
    return nil
end

function S.has_los(from, to, opts)
    opts = opts or {}
    local world_name = opts.world or "main"
    local alpha_ok = opts.alpha_ok or 0.98

    if not PhysicsManager or not PhysicsManager.get_world then
        return false
    end
    if not physics or not physics.segment_query_first then
        return false
    end

    local world = PhysicsManager.get_world(world_name)
    if not world then return false end

    local a = as_pos(from)
    local b = as_pos(to)
    if not a or not b then return false end

    local res = physics.segment_query_first(world, a, b, nil)
    if not res or not res.hit then return true end
    return (res.alpha or 0) >= alpha_ok
end

return S
