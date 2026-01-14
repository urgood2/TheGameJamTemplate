---@module ui.ui_cleanup
--- Centralized cleanup for all UI registries to prevent memory leaks.
--- Call cleanupEntity() when destroying any UI entity.

local UICleanup = {}

-- Import cleanup functions from each module
local dsl = require("ui.ui_syntax_sugar")
local UIDecorations = require("ui.ui_decorations")
local UIBackground = require("ui.ui_background")

-- Optional: tooltip_v2 if it has cleanup
local ok, TooltipV2 = pcall(require, "ui.tooltip_v2")
if not ok then TooltipV2 = nil end

--- Clean up all registry entries for an entity.
--- Call this before destroying any UI entity to prevent memory leaks.
---@param entity number The entity ID to clean up
function UICleanup.cleanupEntity(entity)
    if not entity then return end

    local key = tostring(entity)

    -- Tab registry cleanup
    if dsl.cleanupTabs then
        pcall(dsl.cleanupTabs, key)
    end

    -- Grid registry cleanup
    if dsl.cleanupGrid then
        pcall(dsl.cleanupGrid, key)
    end

    -- Decoration registry cleanup
    if UIDecorations and UIDecorations.cleanup then
        pcall(UIDecorations.cleanup, entity)
    end

    -- Background registry cleanup
    if UIBackground and UIBackground.remove then
        pcall(UIBackground.remove, entity)
    end

    -- Tooltip cache cleanup (if available)
    -- TooltipV2 uses .hide() to cleanup by anchor entity
    if TooltipV2 and TooltipV2.hide then
        pcall(TooltipV2.hide, entity)
    end
end

--- Clean up all registries for a UI box and its children.
--- Recursively cleans all child entities.
---@param boxEntity number The UI box entity to clean up
function UICleanup.cleanupUIBox(boxEntity)
    if not boxEntity or not registry:valid(boxEntity) then return end

    -- Get GameObject for children
    local component_cache = require("core.component_cache")
    local go = component_cache.get(boxEntity, GameObject)
    if go and go.orderedChildren then
        for _, child in ipairs(go.orderedChildren) do
            UICleanup.cleanupUIBox(child)
        end
    end

    -- Clean up this entity
    UICleanup.cleanupEntity(boxEntity)
end

return UICleanup
