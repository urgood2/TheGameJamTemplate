---@module ui.ui_cleanup
--- Centralized cleanup for all UI registries to prevent memory leaks.
---
--- USAGE:
---   local UICleanup = require("ui.ui_cleanup")
---   UICleanup.remove(entity)  -- Recommended: cleans registries + destroys UI box
---
--- If you must use ui.box.Remove directly, call cleanupEntity() first:
---   UICleanup.cleanupEntity(entity)
---   ui.box.Remove(registry, entity)
---
--- NOTE: component_cache is a C++ global (see CLAUDE.md), not a Lua module.

local UICleanup = {}

-- Lazy-loaded references to avoid circular dependencies
-- (ui_syntax_sugar requires ui_cleanup for dsl.remove)
local _dsl = nil
local _UIDecorations = nil
local _UIBackground = nil
local _TooltipV2 = nil

local function getDsl()
    if not _dsl then _dsl = require("ui.ui_syntax_sugar") end
    return _dsl
end

local function getUIDecorations()
    if not _UIDecorations then _UIDecorations = require("ui.ui_decorations") end
    return _UIDecorations
end

local function getUIBackground()
    if not _UIBackground then _UIBackground = require("ui.ui_background") end
    return _UIBackground
end

local function getTooltipV2()
    if _TooltipV2 == nil then
        local ok, mod = pcall(require, "ui.tooltip_v2")
        _TooltipV2 = ok and mod or false  -- false means we tried and failed
    end
    return _TooltipV2 or nil
end

--- Clean up all registry entries for an entity.
--- Call this before destroying any UI entity to prevent memory leaks.
---@param entity number The entity ID to clean up
function UICleanup.cleanupEntity(entity)
    if not entity then return end

    local key = tostring(entity)

    -- Tab registry cleanup
    local dsl = getDsl()
    if dsl and dsl.cleanupTabs then
        pcall(dsl.cleanupTabs, key)
    end

    -- Grid registry cleanup
    if dsl and dsl.cleanupGrid then
        pcall(dsl.cleanupGrid, key)
    end

    -- Decoration registry cleanup
    local UIDecorations = getUIDecorations()
    if UIDecorations and UIDecorations.cleanup then
        pcall(UIDecorations.cleanup, entity)
    end

    -- Background registry cleanup
    local UIBackground = getUIBackground()
    if UIBackground and UIBackground.remove then
        pcall(UIBackground.remove, entity)
    end

    -- Tooltip cache cleanup (if available)
    -- TooltipV2 uses .hide() to cleanup by anchor entity
    local TooltipV2 = getTooltipV2()
    if TooltipV2 and TooltipV2.hide then
        pcall(TooltipV2.hide, entity)
    end
end

--- Clean up all registries for a UI box and its children.
--- Recursively cleans all child entities.
---@param boxEntity number The UI box entity to clean up
function UICleanup.cleanupUIBox(boxEntity)
    if not boxEntity or not registry:valid(boxEntity) then return end

    -- component_cache is a C++ global (not a Lua module)
    local go = component_cache.get(boxEntity, GameObject)
    if go and go.orderedChildren then
        for _, child in ipairs(go.orderedChildren) do
            UICleanup.cleanupUIBox(child)
        end
    end

    -- Clean up this entity
    UICleanup.cleanupEntity(boxEntity)
end

--- Remove a UI box with proper cleanup.
--- This is the recommended way to destroy UI entities.
--- Cleans all registries then calls ui.box.Remove (or registry:destroy as fallback).
---@param entity number The UI box entity to remove
---@return boolean success Whether removal succeeded
function UICleanup.remove(entity)
    if not entity then return false end
    if not registry or not registry:valid(entity) then return false end

    -- Clean up all registries first
    UICleanup.cleanupUIBox(entity)

    -- Use ui.box.Remove if available (proper cleanup of UI tree)
    if ui and ui.box and ui.box.Remove then
        local ok = pcall(function()
            ui.box.Remove(registry, entity)
        end)
        return ok
    end

    -- Fallback to raw destroy
    if registry:valid(entity) then
        registry:destroy(entity)
        return true
    end

    return false
end

return UICleanup
