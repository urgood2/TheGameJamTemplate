--[[
================================================================================
Q.lua - Quick convenience helpers for rapid game development
================================================================================
"Q" for "Quick" - single-letter import for minimal friction.

Usage:
    local Q = require("core.Q")

    Q.move(entity, 100, 200)           -- Set position
    local cx, cy = Q.center(entity)    -- Get center point
    Q.offset(entity, 10, 0)            -- Move relative
]]

-- Singleton guard
if _G.__Q__ then return _G.__Q__ end

local Q = {}

-- Dependencies
local component_cache = require("core.component_cache")

--------------------------------------------------------------------------------
-- Transform Helpers
--------------------------------------------------------------------------------

--- Move entity to absolute position
--- @param entity number Entity ID
--- @param x number Target X position
--- @param y number Target Y position
--- @return boolean success True if transform was found and updated
function Q.move(entity, x, y)
    local transform = component_cache.get(entity, Transform)
    if not transform then return false end
    transform.actualX = x
    transform.actualY = y
    return true
end

--- Get center point of entity
--- @param entity number Entity ID
--- @return number|nil x Center X, or nil if no transform
--- @return number|nil y Center Y, or nil if no transform
function Q.center(entity)
    local transform = component_cache.get(entity, Transform)
    if not transform then return nil, nil end
    return transform.actualX + transform.actualW / 2,
           transform.actualY + transform.actualH / 2
end

--- Move entity relative to current position
--- @param entity number Entity ID
--- @param dx number Delta X
--- @param dy number Delta Y
--- @return boolean success True if transform was found and updated
function Q.offset(entity, dx, dy)
    local transform = component_cache.get(entity, Transform)
    if not transform then return false end
    transform.actualX = transform.actualX + dx
    transform.actualY = transform.actualY + dy
    return true
end

_G.__Q__ = Q
return Q
