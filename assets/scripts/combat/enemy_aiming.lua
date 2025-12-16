--[[
================================================================================
ENEMY AIMING UTILITIES
================================================================================
Provides reusable aiming strategies for enemy projectiles.

Strategies:
- direct: Shoot at target's current position
- leadTarget: Predict where target will be
- spread: Multiple projectiles in a cone
- spiral: Circular pattern (for bosses)
================================================================================
]]

local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")

local EnemyAiming = {}

--- Get center position of an entity
--- @param entity number Entity ID
--- @return table|nil {x, y} or nil if invalid
function EnemyAiming.getEntityCenter(entity)
    if not entity or not entity_cache.valid(entity) then
        return nil
    end

    local transform = component_cache.get(entity, Transform)
    if not transform then
        return nil
    end

    return {
        x = transform.actualX + (transform.actualW or 0) * 0.5,
        y = transform.actualY + (transform.actualH or 0) * 0.5
    }
end

--- Direct shot at current position (basic enemies)
--- @param shooterPos table {x, y}
--- @param targetPos table {x, y}
--- @return table {x, y} normalized direction
function EnemyAiming.direct(shooterPos, targetPos)
    local dx = targetPos.x - shooterPos.x
    local dy = targetPos.y - shooterPos.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < 0.001 then
        return { x = 1, y = 0 }
    end

    return { x = dx / dist, y = dy / dist }
end

--- Lead the target based on velocity (elite enemies)
--- @param shooterPos table {x, y}
--- @param targetPos table {x, y}
--- @param targetVelocity table {x, y} target's current velocity
--- @param projectileSpeed number speed of projectile
--- @return table {x, y} normalized direction
function EnemyAiming.leadTarget(shooterPos, targetPos, targetVelocity, projectileSpeed)
    local dx = targetPos.x - shooterPos.x
    local dy = targetPos.y - shooterPos.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < 0.001 or projectileSpeed < 0.001 then
        return EnemyAiming.direct(shooterPos, targetPos)
    end

    -- Predict where target will be when projectile arrives
    local timeToHit = dist / projectileSpeed
    local predictedX = targetPos.x + (targetVelocity.x or 0) * timeToHit
    local predictedY = targetPos.y + (targetVelocity.y or 0) * timeToHit

    return EnemyAiming.direct(shooterPos, { x = predictedX, y = predictedY })
end

--- Spread shot - multiple directions in a cone (shotgun-style enemies)
--- @param shooterPos table {x, y}
--- @param targetPos table {x, y}
--- @param spreadAngleDegrees number total spread angle in degrees
--- @param count number number of projectiles
--- @return table array of {x, y} directions
function EnemyAiming.spread(shooterPos, targetPos, spreadAngleDegrees, count)
    local baseDir = EnemyAiming.direct(shooterPos, targetPos)
    local baseAngle = math.atan(baseDir.y, baseDir.x)

    local directions = {}

    if count == 1 then
        directions[1] = baseDir
        return directions
    end

    local halfSpread = math.rad(spreadAngleDegrees) / 2
    local step = math.rad(spreadAngleDegrees) / (count - 1)

    for i = 0, count - 1 do
        local angle = baseAngle - halfSpread + (step * i)
        directions[#directions + 1] = {
            x = math.cos(angle),
            y = math.sin(angle)
        }
    end

    return directions
end

--- Spiral pattern - radial burst (boss attacks)
--- @param baseAngle number starting angle in radians
--- @param count number number of projectiles
--- @param spacingDegrees number degrees between each projectile
--- @return table array of {x, y} directions
function EnemyAiming.spiral(baseAngle, count, spacingDegrees)
    local directions = {}

    for i = 0, count - 1 do
        local angle = baseAngle + math.rad(spacingDegrees * i)
        directions[#directions + 1] = {
            x = math.cos(angle),
            y = math.sin(angle)
        }
    end

    return directions
end

--- Ring pattern - evenly spaced around a circle
--- @param count number number of projectiles
--- @param offsetAngle number starting angle offset in radians (default 0)
--- @return table array of {x, y} directions
function EnemyAiming.ring(count, offsetAngle)
    offsetAngle = offsetAngle or 0
    local directions = {}
    local angleStep = (2 * math.pi) / count

    for i = 0, count - 1 do
        local angle = offsetAngle + (angleStep * i)
        directions[#directions + 1] = {
            x = math.cos(angle),
            y = math.sin(angle)
        }
    end

    return directions
end

--- Calculate distance between two positions
--- @param pos1 table {x, y}
--- @param pos2 table {x, y}
--- @return number distance
function EnemyAiming.distance(pos1, pos2)
    local dx = pos2.x - pos1.x
    local dy = pos2.y - pos1.y
    return math.sqrt(dx * dx + dy * dy)
end

return EnemyAiming
