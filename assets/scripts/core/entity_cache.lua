------------------------------------------------------------
-- entity_cache.lua
-- Global per-frame cache for validity & active-state checks.
-- Optimizes registry:valid(eid) and is_entity_active(eid).
------------------------------------------------------------

if _G.entity_cache then
    return _G.entity_cache
end

local cache = {}
_G.entity_cache = cache

------------------------------------------------------------
-- Dependencies / globals
------------------------------------------------------------
local registry = _G.registry
local is_entity_active_fn = _G.is_entity_active or function() return true end

-- Engine frame counter
local GetFrameCount = _G.GetFrameCount or function()
    cache.__frame = (cache.__frame or 0) + 1
    return cache.__frame
end

------------------------------------------------------------
-- Internal state
------------------------------------------------------------
cache._frame = -1
cache._valid = {}
cache._active = {}

------------------------------------------------------------
-- Internal helpers
------------------------------------------------------------
local function check_frame_advance()
    local frame = GetFrameCount()
    if frame ~= cache._frame then
        cache._frame = frame
        cache._valid = {}
        cache._active = {}
    end
end

------------------------------------------------------------
-- Public API
------------------------------------------------------------

--- Check if entity is valid (cached per frame)
---@param eid entt.entity
---@return boolean
function cache.valid(eid)
    if not eid then return false end
    check_frame_advance()

    local val = cache._valid[eid]
    if val ~= nil then
        return val
    end

    local ok = registry and registry:valid(eid)
    cache._valid[eid] = ok or false
    return ok
end

--- Check if entity is active (cached per frame)
---@param eid entt.entity
---@return boolean
function cache.active(eid)
    if not eid then return false end
    check_frame_advance()

    local val = cache._active[eid]
    if val ~= nil then
        return val
    end

    local ok = is_entity_active_fn(eid)
    cache._active[eid] = ok or false
    return ok
end

--- Invalidate a single entity’s cache
function cache.invalidate(eid)
    cache._valid[eid] = nil
    cache._active[eid] = nil
end

--- Clear all caches (used on scene reload)
function cache.clear()
    cache._valid = {}
    cache._active = {}
    cache._frame = -1
end

--- Optional: bulk invalidate if multiple entities changed
function cache.invalidate_many(list)
    for i = 1, #list do
        local eid = list[i]
        cache._valid[eid] = nil
        cache._active[eid] = nil
    end
end

function cache.update_frame()
    local frame = GetFrameCount()
    if frame ~= cache._frame then
        cache._frame = frame
        cache._valid = {}
        cache._active = {}
    end
end

------------------------------------------------------------
-- Check if a particular state is active (non-entity-based)
------------------------------------------------------------

--- Check if a particular game state is active.
--- Cached per frame for efficiency.
---@param state_name string
---@return boolean
function cache.state_active(state_name)
    if not state_name then return false end
    check_frame_advance()

    -- Initialize a subcache for states
    cache._state_active = cache._state_active or {}

    local val = cache._state_active[state_name]
    if val ~= nil then
        return val
    end

    local fn = _G.is_state_active
    local ok = false
    if fn then
        ok = fn(state_name)
    end

    cache._state_active[state_name] = ok or false
    return ok
end


return cache
