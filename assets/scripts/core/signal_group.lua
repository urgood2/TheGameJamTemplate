--[[
================================================================================
signal_group.lua - Scoped event registration with automatic cleanup
================================================================================
Provides grouped signal handlers that can be cleaned up with a single call.
Prevents memory leaks from orphaned event handlers.

Usage:
    local signal_group = require("core.signal_group")

    -- Create a group for this module/entity
    local handlers = signal_group.new("combat_ui")

    -- Register handlers (same API as hump.signal)
    handlers:on("enemy_killed", function(entity)
        updateKillCount()
    end)

    handlers:on("player_damaged", function(entity, data)
        showDamageFlash()
    end)

    -- When done (e.g., scene unload, entity destroyed):
    handlers:cleanup()  -- Removes ALL handlers in this group
]]

-- Singleton guard
if _G.__signal_group__ then return _G.__signal_group__ end

local signal = require("external.hump.signal")

local SignalGroup = {}
SignalGroup.__index = SignalGroup

--------------------------------------------------------------------------------
-- Constructor
--------------------------------------------------------------------------------

--- Create a new signal group for scoped handler registration
--- @param name string? Optional name for debugging
--- @return SignalGroup
function SignalGroup.new(name)
    local self = setmetatable({}, SignalGroup)
    self._name = name or ("group_" .. tostring(os.time()) .. "_" .. math.random(1, 9999))
    self._handlers = {}  -- { [event_name] = { handler1, handler2, ... } }
    self._cleaned_up = false
    return self
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

--- Register a handler for an event
--- @param event_name string The event to listen for
--- @param handler function The callback function
--- @return function handler The registered handler (for manual removal if needed)
function SignalGroup:on(event_name, handler)
    if self._cleaned_up then
        print(string.format("[SignalGroup:%s] Warning: registering after cleanup!", self._name))
        return handler
    end

    assert(type(event_name) == "string", "SignalGroup:on() requires event_name string")
    assert(type(handler) == "function", "SignalGroup:on() requires handler function")

    -- Track it
    if not self._handlers[event_name] then
        self._handlers[event_name] = {}
    end
    table.insert(self._handlers[event_name], handler)

    -- Register with hump.signal
    signal.register(event_name, handler)

    return handler
end

--- Alias for on() to match hump.signal naming
--- @param event_name string
--- @param handler function
--- @return function
function SignalGroup:register(event_name, handler)
    return self:on(event_name, handler)
end

--- Remove a specific handler
--- @param event_name string
--- @param handler function
function SignalGroup:off(event_name, handler)
    signal.remove(event_name, handler)

    -- Also remove from our tracking
    local handlers = self._handlers[event_name]
    if handlers then
        for i, h in ipairs(handlers) do
            if h == handler then
                table.remove(handlers, i)
                break
            end
        end
    end
end

--- Alias for off() to match hump.signal naming
--- @param event_name string
--- @param handler function
function SignalGroup:remove(event_name, handler)
    self:off(event_name, handler)
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

--- Remove ALL handlers registered through this group
--- Call this when the owning module/entity is destroyed
function SignalGroup:cleanup()
    if self._cleaned_up then
        return  -- Already cleaned up
    end

    for event_name, handlers in pairs(self._handlers) do
        for _, handler in ipairs(handlers) do
            signal.remove(event_name, handler)
        end
    end

    self._handlers = {}
    self._cleaned_up = true
end

--- Check if group has been cleaned up
--- @return boolean
function SignalGroup:isCleanedUp()
    return self._cleaned_up
end

--- Get count of registered handlers (for debugging)
--- @return number
function SignalGroup:count()
    local total = 0
    for _, handlers in pairs(self._handlers) do
        total = total + #handlers
    end
    return total
end

--- Get the group name (for debugging)
--- @return string
function SignalGroup:getName()
    return self._name
end

--------------------------------------------------------------------------------
-- Module
--------------------------------------------------------------------------------

local signal_group = {
    new = SignalGroup.new,
}

_G.__signal_group__ = signal_group
return signal_group
