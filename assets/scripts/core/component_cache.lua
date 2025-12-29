--[[
================================================================================
component_cache.lua - Per-Frame Component Access Caching
================================================================================
Caches ECS component lookups within a single frame, dramatically reducing
repeated registry:get() calls for the same entity/component pairs.

The cache automatically invalidates at the start of each frame, ensuring
you always get fresh data while still benefiting from within-frame caching.

Usage:
    local component_cache = require("core.component_cache")

    -- Basic usage (most common)
    local transform = component_cache.get(entity, Transform)
    if transform then
        transform.actualX = 100
    end

    -- Safe access with validation
    local sprite, is_valid = component_cache.safe_get(entity, Sprite)
    if is_valid then
        sprite.visible = true
    end

    -- Check entity validity before accessing
    if component_cache.ensure(entity) then
        local transform = component_cache.get(entity, Transform)
    end

    -- Manual invalidation (rarely needed)
    component_cache.invalidate(entity, Transform)  -- Invalidate specific
    component_cache.invalidate(entity)             -- Invalidate all for entity

Performance:
    - First access: ~same as registry:get()
    - Subsequent accesses (same frame): ~10x faster (table lookup vs C++ call)
    - Automatically clears at frame start

Dependencies:
    - registry (global ECS registry)
    - GetFrameCount() (engine frame counter)
]]

---@class ComponentCache
---@field get fun(eid: number, comp: any): table|nil Fetch component with caching
---@field safe_get fun(eid: number, comp: any): table|nil, boolean Safe fetch with validation
---@field ensure fun(eid: number): boolean Check entity validity
---@field invalidate fun(eid: number, comp?: any) Clear cache for entity
---@field clear fun() Clear entire cache
---@field register_hook fun(comp: any, hook_table: table) Register component hooks
---@field begin_frame fun() Start batched mode
---@field end_frame fun() End batched mode
---@field update_frame fun() Force frame advance check

------------------------------------------------------------

-- ensure single global instance
if _G.component_cache then
    return _G.component_cache
end

local component_cache = {}
_G.component_cache = component_cache  -- persist globally

------------------------------------------------------------
-- Dependencies / upvalues
------------------------------------------------------------
local registry = _G.registry
local valid = registry and registry.valid
local get_component = registry and registry.get

-- use engine-provided frame counter if available
local GetFrameCount = _G.GetFrameCount or function()
    component_cache.__frame_counter = (component_cache.__frame_counter or 0) + 1
    return component_cache.__frame_counter
end

------------------------------------------------------------
-- Internal State
------------------------------------------------------------
component_cache._frame = -1
component_cache._data = {}   -- per-component cache tables
component_cache._hooks = {}  -- optional per-component hooks

------------------------------------------------------------
-- Internal helpers
------------------------------------------------------------
local function ensure_component_table(comp)
    local t = component_cache._data[comp]
    if not t then
        t = {}
        component_cache._data[comp] = t
    end
    return t
end

local function check_frame_advance()
    local frame = GetFrameCount()
    if frame ~= component_cache._frame then
        component_cache._frame = frame
        component_cache._data = {}
    end
end

------------------------------------------------------------
-- Optional Frame-Batched Mode
-- When active, GetFrameCount() is only called once per frame.
------------------------------------------------------------
function component_cache.begin_frame()
    local cache = component_cache
    cache._frame = GetFrameCount()
    cache._data = {}
    cache._frame_batched = true
end

function component_cache.end_frame()
    -- Note: We intentionally keep _frame_batched = true until the next begin_frame().
    -- This avoids redundant GetFrameCount() calls during draw phase or other code
    -- that runs after update() but still in the same frame.
    -- The cache will be properly cleared by begin_frame() at the start of the next frame.
end

------------------------------------------------------------
-- Public API
------------------------------------------------------------

--- Called once per frame to force flush timing.
function component_cache.update_frame()
    check_frame_advance()
end

--- Fetch a component with per-frame caching.
---@param eid entt.entity
---@param comp any
---@return table|nil
function component_cache.get(eid, comp)
    if not eid then return nil end

    local cache = component_cache

    -- Only call GetFrameCount once per frame unless in batch mode
    if not cache._frame_batched then
        local frame = GetFrameCount()
        if frame ~= cache._frame then
            cache._frame = frame
            cache._data = {}
        end
    end

    local data = cache._data
    local tbl = data[comp]
    if not tbl then
        tbl = {}
        data[comp] = tbl
    end

    -- direct access
    local c = tbl[eid]
    if c then return c end

    -- lazy validate only if needed
    local vfn = valid
    if vfn and not vfn(registry, eid) then
        return nil
    end

    local gfn = get_component
    if not gfn then return nil end
    c = gfn(registry, eid, comp)
    if not c then return nil end

    tbl[eid] = c

    local hook = cache._hooks[comp]
    if hook then
        local f = hook.on_get
        if f then f(eid, c) end
    end

    return c
end

--- Validate that an entity exists and is valid.
--- Use this before accessing cached components when entity lifetime is uncertain.
---@param eid entt.entity
---@return boolean valid True if entity exists and is valid
function component_cache.ensure(eid)
    if not eid then return false end
    local vfn = valid
    if not vfn then return false end
    return vfn(registry, eid) == true
end

--- Safe component access with automatic validation.
--- Returns nil if entity is invalid, otherwise returns component.
---@param eid entt.entity
---@param comp any
---@return table|nil component, boolean valid
function component_cache.safe_get(eid, comp)
    if not component_cache.ensure(eid) then
        return nil, false
    end
    return component_cache.get(eid, comp), true
end

--- Invalidate cached value(s).
---@param eid entt.entity
---@param comp any|nil  If nil, invalidates all components for entity.
function component_cache.invalidate(eid, comp)
    if comp then
        local tbl = component_cache._data[comp]
        if tbl then
            tbl[eid] = nil
            local hook = component_cache._hooks[comp]
            if hook and hook.on_invalidate then
                hook.on_invalidate(eid)
            end
        end
    else
        for _, tbl in pairs(component_cache._data) do
            tbl[eid] = nil
        end
    end
end

--- Full cache clear (used on reload or reset).
function component_cache.clear()
    component_cache._data = {}
    component_cache._frame = -1
end

--- Register hooks for specific component types.
--- Hooks can define: on_get(eid, comp), on_invalidate(eid)
---@param comp any
---@param hook_table table
function component_cache.register_hook(comp, hook_table)
    component_cache._hooks[comp] = hook_table
end

------------------------------------------------------------
-- Compatibility alias for transforms
-- Usage: component_cache.Transform.get(eid)
------------------------------------------------------------
component_cache.Transform = {
    get = function(eid)
        return component_cache.get(eid, _G.Transform)
    end,
    invalidate = function(eid)
        return component_cache.invalidate(eid, _G.Transform)
    end,
    update_frame = function()
        component_cache.update_frame()
    end
}

------------------------------------------------------------
-- Initialization log (optional)
------------------------------------------------------------
-- log_debug and log_info optional; comment out if unused
if _G.log_debug then
    log_debug("[component_cache] Initialized global cache")
end

return component_cache
