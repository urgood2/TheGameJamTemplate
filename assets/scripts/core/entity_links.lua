--[[
================================================================================
entity_links.lua - Horizontal Entity Links (Die-When-Target-Dies)
================================================================================
Creates dependency relationships between entities where the dependent entity
is automatically destroyed when the target entity is destroyed.

Usage:
    local EntityLinks = require("core.entity_links")
    
    -- Projectile dies when owner dies
    EntityLinks.link(projectile, owner)
    
    -- Remove a specific link
    EntityLinks.unlink(projectile, owner)
    
    -- Remove all links for an entity
    EntityLinks.unlinkAll(projectile)
    
    -- Check if entity is linked to target
    if EntityLinks.isLinkedTo(projectile, owner) then ... end

Dependencies:
    - external.hump.signal
    - core.signal_group
]]

if _G.__ENTITY_LINKS__ then return _G.__ENTITY_LINKS__ end

local EntityLinks = {}

local signal = require("external.hump.signal")
local signal_group = require("core.signal_group")

local activeLinks = {}
local linkCounter = 0

--- Link dependent to target: dependent dies when target dies.
--- @param dependent number Entity that will be destroyed
--- @param target number Entity being watched
--- @return boolean Success
function EntityLinks.link(dependent, target)
    if not registry:valid(dependent) or not registry:valid(target) then
        return false
    end
    
    activeLinks[dependent] = activeLinks[dependent] or {}
    
    if activeLinks[dependent][target] then
        return true
    end
    
    linkCounter = linkCounter + 1
    local groupName = "entity_link_" .. linkCounter
    local handlers = signal_group.new(groupName)
    
    handlers:on("entity_destroyed", function(destroyedEntity)
        if destroyedEntity == target then
            if registry:valid(dependent) then
                local script = getScriptTableFromEntityID(dependent)
                if script and script.destroy then
                    script:destroy()
                else
                    registry:destroy(dependent)
                end
            end
            handlers:cleanup()
            if activeLinks[dependent] then
                activeLinks[dependent][target] = nil
            end
        end
    end)
    
    handlers:on("entity_destroyed", function(destroyedEntity)
        if destroyedEntity == dependent then
            handlers:cleanup()
            if activeLinks[dependent] then
                activeLinks[dependent][target] = nil
            end
        end
    end)
    
    activeLinks[dependent][target] = handlers
    return true
end

--- Remove link between dependent and target.
--- @param dependent number
--- @param target number
--- @return boolean Success
function EntityLinks.unlink(dependent, target)
    if not activeLinks[dependent] or not activeLinks[dependent][target] then
        return false
    end
    
    activeLinks[dependent][target]:cleanup()
    activeLinks[dependent][target] = nil
    return true
end

--- Remove all links for a dependent entity.
--- @param dependent number
--- @return number Count of links removed
function EntityLinks.unlinkAll(dependent)
    if not activeLinks[dependent] then
        return 0
    end
    
    local count = 0
    for _, handlers in pairs(activeLinks[dependent]) do
        handlers:cleanup()
        count = count + 1
    end
    
    activeLinks[dependent] = nil
    return count
end

--- Check if dependent is linked to target.
--- @param dependent number
--- @param target number
--- @return boolean
function EntityLinks.isLinkedTo(dependent, target)
    return activeLinks[dependent] ~= nil and activeLinks[dependent][target] ~= nil
end

--- Get all targets that dependent is linked to.
--- @param dependent number
--- @return table Array of target entity IDs
function EntityLinks.getTargets(dependent)
    if not activeLinks[dependent] then
        return {}
    end
    
    local targets = {}
    for target, _ in pairs(activeLinks[dependent]) do
        table.insert(targets, target)
    end
    return targets
end

--- Get count of active links for debugging.
--- @return number Total active link count
function EntityLinks.getActiveLinkCount()
    local count = 0
    for _, targets in pairs(activeLinks) do
        for _, _ in pairs(targets) do
            count = count + 1
        end
    end
    return count
end

_G.__ENTITY_LINKS__ = EntityLinks
return EntityLinks
