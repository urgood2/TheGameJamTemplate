--[[
================================================================================
Q.lua - Quick convenience helpers for rapid game development
================================================================================
"Q" for "Quick" - single-letter import for minimal friction.

Usage:
    local Q = require("core.Q")

    -- Position helpers
    Q.move(entity, 100, 200)           -- Set position
    local cx, cy = Q.center(entity)    -- Get center (actual position)
    local vx, vy = Q.visualCenter(entity) -- Get center (visual/rendered position)
    Q.offset(entity, 10, 0)            -- Move relative

    -- Size & bounds
    local w, h = Q.size(entity)        -- Get dimensions
    local x, y, w, h = Q.bounds(entity) -- Get bounding box

    -- Rotation
    local rad = Q.rotation(entity)     -- Get rotation in radians
    Q.setRotation(entity, math.pi/4)   -- Set rotation

    -- Validation
    if Q.isValid(entity) then ... end  -- Check entity validity

    -- Spatial queries
    local dist = Q.distance(e1, e2)    -- Distance between entities
    local dx, dy = Q.direction(e1, e2) -- Normalized direction vector
]]

-- Singleton guard
if _G.__Q__ then return _G.__Q__ end

local Q = {}

-- Dependencies
local component_cache = require("core.component_cache")
local lume = require("external.lume")

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

--- Get visual center point of entity (where it's rendered, with interpolation)
--- Use this for spawning effects, popups, particles at visible position
--- @param entity number Entity ID
--- @return number|nil x Visual center X, or nil if no transform
--- @return number|nil y Visual center Y, or nil if no transform
function Q.visualCenter(entity)
    local transform = component_cache.get(entity, Transform)
    if not transform then return nil, nil end
    return transform.visualX + transform.visualW / 2,
           transform.visualY + transform.visualH / 2
end

--- Get entity dimensions
--- @param entity number Entity ID
--- @return number|nil width Width, or nil if no transform
--- @return number|nil height Height, or nil if no transform
function Q.size(entity)
    local transform = component_cache.get(entity, Transform)
    if not transform then return nil, nil end
    return transform.actualW, transform.actualH
end

--- Get entity bounding box (actual position)
--- @param entity number Entity ID
--- @return number|nil x Top-left X
--- @return number|nil y Top-left Y
--- @return number|nil w Width
--- @return number|nil h Height
function Q.bounds(entity)
    local transform = component_cache.get(entity, Transform)
    if not transform then return nil, nil, nil, nil end
    return transform.actualX, transform.actualY, transform.actualW, transform.actualH
end

--- Get entity bounding box (visual/rendered position)
--- @param entity number Entity ID
--- @return number|nil x Top-left X
--- @return number|nil y Top-left Y
--- @return number|nil w Width
--- @return number|nil h Height
function Q.visualBounds(entity)
    local transform = component_cache.get(entity, Transform)
    if not transform then return nil, nil, nil, nil end
    return transform.visualX, transform.visualY, transform.visualW, transform.visualH
end

--------------------------------------------------------------------------------
-- Rotation Helpers
--------------------------------------------------------------------------------

--- Get entity rotation in radians
--- @param entity number Entity ID
--- @return number|nil rotation Rotation in radians, or nil if no transform
function Q.rotation(entity)
    local transform = component_cache.get(entity, Transform)
    if not transform then return nil end
    return transform.actualR or 0
end

--- Set entity rotation in radians
--- @param entity number Entity ID
--- @param radians number Rotation in radians
--- @return boolean success True if transform was found and updated
function Q.setRotation(entity, radians)
    local transform = component_cache.get(entity, Transform)
    if not transform then return false end
    transform.actualR = radians
    return true
end

--- Rotate entity by delta radians
--- @param entity number Entity ID
--- @param deltaRadians number Amount to rotate (positive = clockwise)
--- @return boolean success True if transform was found and updated
function Q.rotate(entity, deltaRadians)
    local transform = component_cache.get(entity, Transform)
    if not transform then return false end
    transform.actualR = (transform.actualR or 0) + deltaRadians
    return true
end

--------------------------------------------------------------------------------
-- Validation Helpers
--------------------------------------------------------------------------------

--- Check if entity is valid (exists and not destroyed)
--- @param entity any Entity ID to check
--- @return boolean valid True if entity exists and is valid
function Q.isValid(entity)
    if not entity then return false end
    if entity == entt_null then return false end
    if entity_cache and entity_cache.valid then
        return entity_cache.valid(entity)
    end
    if registry and registry.valid then
        return registry:valid(entity)
    end
    return false
end

--- Ensure entity is valid, returns entity or nil with optional warning
--- @param entity any Entity ID to check
--- @param context string|nil Optional context for warning message
--- @return number|nil entity The entity if valid, nil otherwise
function Q.ensure(entity, context)
    if Q.isValid(entity) then
        return entity
    end
    if context then
        print(string.format("[Q.ensure] Invalid entity in %s: %s", context, tostring(entity)))
    end
    return nil
end

--------------------------------------------------------------------------------
-- Spatial Query Helpers
--------------------------------------------------------------------------------

--- Get distance between two entities (center to center)
--- @param entity1 number First entity ID
--- @param entity2 number Second entity ID
--- @return number|nil distance Distance in pixels, or nil if either entity invalid
function Q.distance(entity1, entity2)
    local x1, y1 = Q.center(entity1)
    local x2, y2 = Q.center(entity2)
    if not x1 or not x2 then return nil end
    return lume.distance(x1, y1, x2, y2)
end

--- Get normalized direction vector from entity1 to entity2
--- @param entity1 number Source entity ID
--- @param entity2 number Target entity ID
--- @return number|nil dx Normalized X direction (-1 to 1), or nil if invalid
--- @return number|nil dy Normalized Y direction (-1 to 1), or nil if invalid
function Q.direction(entity1, entity2)
    local x1, y1 = Q.center(entity1)
    local x2, y2 = Q.center(entity2)
    if not x1 or not x2 then return nil, nil end

    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.0001 then return 0, 0 end
    return dx / len, dy / len
end

--- Get distance from entity to a point
--- @param entity number Entity ID
--- @param x number Target X position
--- @param y number Target Y position
--- @return number|nil distance Distance in pixels, or nil if entity invalid
function Q.distanceToPoint(entity, x, y)
    local ex, ey = Q.center(entity)
    if not ex then return nil end
    return lume.distance(ex, ey, x, y)
end

--- Check if entity is within range of another entity
--- @param entity1 number First entity ID
--- @param entity2 number Second entity ID
--- @param range number Maximum distance
--- @return boolean inRange True if within range, false otherwise
function Q.isInRange(entity1, entity2, range)
    local dist = Q.distance(entity1, entity2)
    return dist ~= nil and dist <= range
end

--------------------------------------------------------------------------------
-- Component Access Helpers
--------------------------------------------------------------------------------

--- Get transform component with single call (for when you need multiple fields)
--- @param entity number Entity ID
--- @return table|nil transform The Transform component, or nil
function Q.getTransform(entity)
    return component_cache.get(entity, Transform)
end

--- Execute callback with transform if entity is valid
--- Reduces boilerplate: if transform then ... end pattern
--- @param entity number Entity ID
--- @param fn function Callback receiving transform
--- @return boolean success True if callback was executed
function Q.withTransform(entity, fn)
    local transform = component_cache.get(entity, Transform)
    if not transform then return false end
    fn(transform)
    return true
end

--------------------------------------------------------------------------------
-- Physics Helpers (Chipmunk integration)
--------------------------------------------------------------------------------

local _physics = nil
local _PhysicsManager = nil

local function get_physics()
    if not _physics then _physics = _G.physics end
    return _physics
end

local function get_world()
    if not _PhysicsManager then _PhysicsManager = _G.PhysicsManager end
    if _PhysicsManager and _PhysicsManager.get_world then
        return _PhysicsManager.get_world("world")
    end
    return nil
end

--- Get velocity of physics-enabled entity
--- @param entity number Entity ID
--- @return number|nil vx Velocity X, or nil if no physics body
--- @return number|nil vy Velocity Y, or nil if no physics body
function Q.velocity(entity)
    local physics = get_physics()
    local world = get_world()
    if not physics or not world then return nil, nil end
    if not Q.isValid(entity) then return nil, nil end
    
    local vel = physics.GetVelocity and physics.GetVelocity(world, entity)
    if vel then
        return vel.x, vel.y
    end
    return nil, nil
end

--- Set velocity of physics-enabled entity
--- @param entity number Entity ID
--- @param vx number Velocity X
--- @param vy number Velocity Y
--- @return boolean success True if velocity was set
function Q.setVelocity(entity, vx, vy)
    local physics = get_physics()
    local world = get_world()
    if not physics or not world then return false end
    if not Q.isValid(entity) then return false end
    
    if physics.SetVelocity then
        physics.SetVelocity(world, entity, { x = vx, y = vy })
        return true
    end
    return false
end

--- Get speed (magnitude of velocity)
--- @param entity number Entity ID
--- @return number|nil speed Speed in pixels/second, or nil if no physics
function Q.speed(entity)
    local vx, vy = Q.velocity(entity)
    if not vx then return nil end
    return math.sqrt(vx * vx + vy * vy)
end

--- Apply impulse to entity
--- @param entity number Entity ID
--- @param ix number Impulse X
--- @param iy number Impulse Y
--- @return boolean success True if impulse was applied
function Q.impulse(entity, ix, iy)
    local physics = get_physics()
    local world = get_world()
    if not physics or not world then return false end
    if not Q.isValid(entity) then return false end
    
    if physics.ApplyImpulse then
        physics.ApplyImpulse(world, entity, ix, iy)
        return true
    end
    return false
end

--- Apply force to entity (for continuous pushing)
--- @param entity number Entity ID
--- @param fx number Force X
--- @param fy number Force Y
--- @return boolean success True if force was applied
function Q.force(entity, fx, fy)
    local physics = get_physics()
    local world = get_world()
    if not physics or not world then return false end
    if not Q.isValid(entity) then return false end
    
    if physics.ApplyForce then
        physics.ApplyForce(world, entity, fx, fy)
        return true
    end
    return false
end

--- Set angular velocity (spin)
--- @param entity number Entity ID
--- @param angularVel number Angular velocity in radians/second
--- @return boolean success
function Q.setSpin(entity, angularVel)
    local physics = get_physics()
    local world = get_world()
    if not physics or not world then return false end
    if not Q.isValid(entity) then return false end
    
    if physics.SetAngularVelocity then
        physics.SetAngularVelocity(world, entity, angularVel)
        return true
    end
    return false
end

--- Get angular velocity (spin)
--- @param entity number Entity ID
--- @return number|nil angularVel Angular velocity in radians/second
function Q.spin(entity)
    local physics = get_physics()
    local world = get_world()
    if not physics or not world then return nil end
    if not Q.isValid(entity) then return nil end
    
    if physics.GetAngularVelocity then
        return physics.GetAngularVelocity(world, entity)
    end
    return nil
end

--- Move toward a target point (sets velocity directly)
--- @param entity number Entity ID
--- @param targetX number Target X position
--- @param targetY number Target Y position
--- @param speed number Speed in pixels/second
--- @return boolean success
function Q.moveToward(entity, targetX, targetY, speed)
    local cx, cy = Q.center(entity)
    if not cx then return false end
    
    local dx, dy = targetX - cx, targetY - cy
    local len = math.sqrt(dx * dx + dy * dy)
    
    if len < 1 then
        return Q.setVelocity(entity, 0, 0)
    end
    
    local vx = (dx / len) * speed
    local vy = (dy / len) * speed
    return Q.setVelocity(entity, vx, vy)
end

--- Move toward another entity
--- @param entity number Entity to move
--- @param target number Target entity to move toward
--- @param speed number Speed in pixels/second
--- @return boolean success
function Q.chase(entity, target, speed)
    local tx, ty = Q.center(target)
    if not tx then return false end
    return Q.moveToward(entity, tx, ty, speed)
end

--- Move away from another entity
--- @param entity number Entity to move
--- @param threat number Entity to flee from
--- @param speed number Speed in pixels/second
--- @return boolean success
function Q.flee(entity, threat, speed)
    local cx, cy = Q.center(entity)
    local tx, ty = Q.center(threat)
    if not cx or not tx then return false end
    
    local dx, dy = cx - tx, cy - ty
    local len = math.sqrt(dx * dx + dy * dy)
    
    if len < 0.0001 then
        dx, dy = 1, 0
        len = 1
    end
    
    local vx = (dx / len) * speed
    local vy = (dy / len) * speed
    return Q.setVelocity(entity, vx, vy)
end

_G.__Q__ = Q
return Q
