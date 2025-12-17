--[[
================================================================================
core/timer_scope.lua - Scoped Timer Management
================================================================================
Provides automatic timer cleanup by grouping timers into scopes.
When a scope is destroyed, all its timers are automatically cancelled.

Usage:
    local TimerScope = require("core.timer_scope")

    -- Create a scope for a system/feature
    local scope = TimerScope.new("my_feature")
    scope:after(2.0, function() print("delayed") end)
    scope:every(0.5, function() print("repeating") end)

    -- Later, clean up all timers
    scope:destroy()

    -- Entity-bound scope (integrates with entity lifecycle)
    local entityScope = TimerScope.for_entity(entity)
    entityScope:after(1.0, doSomething)
    -- Automatically cleaned when entity is destroyed (if integrated)
]]

local timer = require("core.timer")

--------------------------------------------------------------------------------
-- TimerScope Class
--------------------------------------------------------------------------------

local TimerScope = {}
TimerScope.__index = TimerScope

-- Unique ID counter for scope groups
local _scope_counter = 0

--- Create a new timer scope
--- @param name string Human-readable name for debugging
--- @return table scope The new TimerScope instance
function TimerScope.new(name)
    _scope_counter = _scope_counter + 1
    local self = setmetatable({}, TimerScope)
    self.name = name or "unnamed"
    self._group = string.format("__scope_%s_%d__", self.name, _scope_counter)
    self._tags = {}  -- Track tags for counting
    self._active = true
    self._entity = nil
    return self
end

--- Create a scope bound to an entity
--- @param entity number Entity ID
--- @return table scope The entity-bound TimerScope
function TimerScope.for_entity(entity)
    local scope = TimerScope.new("entity_" .. tostring(entity))
    scope._entity = entity
    return scope
end

--------------------------------------------------------------------------------
-- Scoped Timer Methods
--------------------------------------------------------------------------------

--- Schedule a delayed action (scoped)
--- @param delay number Delay in seconds
--- @param action function Callback to execute
--- @param tag string? Optional tag for the timer
--- @return string|nil tag The timer tag, or nil if scope is destroyed
function TimerScope:after(delay, action, tag)
    if not self._active then return nil end

    local actualTag = timer.after(delay, action, tag, self._group)
    self._tags[actualTag] = true
    return actualTag
end

--- Schedule a repeating action (scoped)
--- @param delay number Delay between executions
--- @param action function Callback to execute
--- @param times number? Max repetitions (0 or nil = infinite)
--- @param immediate boolean? Run once immediately
--- @param after function? Callback when done
--- @param tag string? Optional tag
--- @return string|nil tag The timer tag, or nil if scope is destroyed
function TimerScope:every(delay, action, times, immediate, after, tag)
    if not self._active then return nil end

    local actualTag = timer.every(delay, action, times, immediate, after, tag, self._group)
    self._tags[actualTag] = true
    return actualTag
end

--- Cancel a specific timer within this scope
--- @param tag string The timer tag to cancel
function TimerScope:cancel(tag)
    if self._tags[tag] then
        timer.cancel(tag)
        self._tags[tag] = nil
    end
end

--- Destroy the scope and cancel all its timers
function TimerScope:destroy()
    if not self._active then return end

    timer.kill_group(self._group)
    self._tags = {}
    self._active = false
end

--- Count active timers in this scope
--- @return number count Number of active timers
function TimerScope:count()
    local count = 0
    for _ in pairs(self._tags) do
        count = count + 1
    end
    return count
end

--- Check if the scope is still active
--- @return boolean active True if scope can accept new timers
function TimerScope:active()
    return self._active
end

return TimerScope
