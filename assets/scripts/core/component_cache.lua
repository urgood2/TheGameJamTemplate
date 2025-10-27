------------------------------------------------------------
-- component_cache.lua
-- Global per-frame caching system for component_cache.get() calls.
-- Caches arbitrary component types (Transform, Sprite, etc.)
-- and auto-invalidates each frame.
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
    if not eid or not (valid and valid(registry, eid)) then
        return nil
    end

    check_frame_advance()

    local tbl = ensure_component_table(comp)
    local cached = tbl[eid]
    if cached then
        return cached
    end

    local c = get_component and get_component(registry, eid, comp)
    if not c then return nil end

    tbl[eid] = c

    local hook = component_cache._hooks[comp]
    if hook and hook.on_get then
        hook.on_get(eid, c)
    end

    return c
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
