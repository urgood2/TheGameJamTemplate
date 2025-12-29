--[[
================================================================================
entity_cache.lua - Per-Frame Entity Validity Caching
================================================================================
Caches entity validity and active-state checks within a single frame,
reducing expensive C++ registry calls when the same entity is checked repeatedly.

Use Cases:
    - Checking `registry:valid(eid)` multiple times per frame (now cached)
    - Checking `is_entity_active(eid)` for state-filtered logic
    - Checking game state with `is_state_active()` (e.g., "COMBAT_STATE")

The cache automatically clears at frame start via GetFrameCount() detection.

Usage:
    local entity_cache = require("core.entity_cache")

    -- Check if entity exists (replaces registry:valid())
    if entity_cache.valid(entity) then
        -- Entity exists
    end

    -- Check if entity is active (has active state tag)
    if entity_cache.active(entity) then
        -- Entity is active and should be updated
    end

    -- Check global game state
    if entity_cache.state_active("COMBAT_STATE") then
        -- Currently in combat
    end

    -- Manual invalidation (after entity destruction)
    entity_cache.invalidate(entity)

    -- Clear all caches (on scene reload)
    entity_cache.clear()

Performance:
    - First check: ~same as registry:valid()
    - Subsequent checks (same frame): ~10x faster (table lookup)

See Also:
    - component_cache.lua - Caches component access
    - Q.isValid() - Convenience wrapper using this cache
]]

---@class EntityCache
---@field valid fun(eid: number): boolean Check entity validity (cached)
---@field active fun(eid: number): boolean Check entity active state (cached)
---@field state_active fun(state_name: string): boolean Check game state (cached)
---@field invalidate fun(eid: number) Clear cache for entity
---@field invalidate_many fun(list: number[]) Clear cache for multiple entities
---@field clear fun() Clear entire cache
---@field update_frame fun() Force frame advance

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

local frame_counter = 0
local last_real_time = os.clock()

local GetFrameCount = _G.GetFrameCount or function()
    local now = os.clock()
    if now - last_real_time > 1/120 then  -- assume max 120 fps
        frame_counter = frame_counter + 1
        last_real_time = now
    end
    return frame_counter
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
        cache._state_active = {}
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
    
    -- log_debug("entity_cache.active - eid #" .. tostring(eid) .. " active=" .. tostring(ok))
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
    cache._state_active = {}
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
    
    -- log_debug("entity_cache.state_active - state '" .. state_name .. "' active=" .. tostring(ok))

    cache._state_active[state_name] = ok or false
    return ok
end


return cache
