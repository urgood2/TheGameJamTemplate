--[[
================================================================================
Tooltip Registry - Name-based tooltip management with parameterized templates
================================================================================

USAGE:
    local tooltips = require("core.tooltip_registry")

    -- Register a tooltip template
    tooltips.register("fire_damage", {
        title = "Fire Damage",
        body = "Deals {damage} fire damage",
        info = { tags = { "Fire" } }  -- Optional: stats/tags for V2
    })

    -- Attach to entity (shows on hover)
    tooltips.attachToEntity(entity, "fire_damage", { damage = 25 })

    -- Manual show/hide
    tooltips.showFor(entity)
    tooltips.hide()

TEMPLATE SYNTAX:
    {param}         -- Simple substitution
    {param|color}   -- Substitution with color (uses styled markup)

TOOLTIP V2 INTEGRATION:
    When USE_TOOLTIP_V2 is true (set in gameplay.lua), this registry
    automatically uses the new 3-box TooltipV2 system instead of the
    legacy makeSimpleTooltip approach.
]]

local tooltips = {}

-- Dependencies (will be set during init)
local component_cache = require("core.component_cache")
local entity_cache = _G.entity_cache

-- Lazy-load TooltipV2 to avoid circular dependency
local TooltipV2 = nil
local function getTooltipV2()
    if TooltipV2 == nil then
        local ok, module = pcall(require, "ui.tooltip_v2")
        TooltipV2 = ok and module or false
    end
    return TooltipV2 or nil
end

--------------------------------------------------------------------------------
-- Internal State
--------------------------------------------------------------------------------

local tooltip_definitions = {}      -- name → { title, body, opts }
local entity_attachments = {}       -- entity → { name, params, originalOnHover, originalOnStopHover }
local active_tooltip = nil          -- Currently visible tooltip entity
local active_target = nil           -- Entity the tooltip is shown for
local active_cache_key = nil        -- cache key used for active tooltip

--------------------------------------------------------------------------------
-- Template Interpolation
--------------------------------------------------------------------------------

-- Interpolate {param} and {param|color} in template string
local function interpolateTemplate(template, params)
    if not template or not params then return template or "" end

    return template:gsub("{([^}]+)}", function(match)
        -- Check for color syntax: {param|color}
        local param, color = match:match("^(%w+)|(%w+)$")
        if param and color then
            local value = params[param]
            if value ~= nil then
                return string.format("[%s](color=%s)", tostring(value), color)
            end
        else
            -- Simple substitution: {param}
            local value = params[match]
            if value ~= nil then
                return tostring(value)
            end
        end
        return "{" .. match .. "}"  -- Return unchanged if not found
    end)
end

-- Generate cache key from name + params
local function getCacheKey(name, params)
    if not params or next(params) == nil then
        return name
    end
    -- Simple serialization for cache key
    local parts = { name }
    local keys = {}
    for k in pairs(params) do table.insert(keys, k) end
    table.sort(keys)
    for _, k in ipairs(keys) do
        table.insert(parts, k .. "=" .. tostring(params[k]))
    end
    return table.concat(parts, ":")
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Register a tooltip template by name
--- @param name string Unique identifier for the tooltip
--- @param def table { title = string, body = string, info = { stats, tags }?, opts = table? }
function tooltips.register(name, def)
    tooltip_definitions[name] = {
        title = def.title or "",
        body = def.body or "",
        info = def.info,  -- V2: { stats = {...}, tags = {...} }
        opts = def.opts or {}
    }
end

--- Check if a tooltip is registered
--- @param name string Tooltip name
--- @return boolean
function tooltips.isRegistered(name)
    return tooltip_definitions[name] ~= nil
end

--- Attach a tooltip to an entity (will show on hover)
--- @param entity number Entity ID
--- @param tooltipName string Registered tooltip name
--- @param params table? Parameters for template interpolation
function tooltips.attachToEntity(entity, tooltipName, params)
    if not entity or not entity_cache.valid(entity) then return end
    if not tooltip_definitions[tooltipName] then
        log_error("Tooltip not registered:", tooltipName)
        return
    end

    local go = component_cache.get(entity, GameObject)
    if not go then return end

    local existing = entity_attachments[entity]
    if existing then
        if existing.name == tooltipName then
            return
        end
        tooltips.detachFromEntity(entity)
    end

    -- Store attachment info
    entity_attachments[entity] = {
        name = tooltipName,
        params = params or {},
        originalOnHover = go.methods.onHover,
        originalOnStopHover = go.methods.onStopHover
    }

    -- Enable hover if not already
    go.state.hoverEnabled = true
    go.state.collisionEnabled = true

    -- Wrap hover handlers
    go.methods.onHover = function(reg, eid, releasedOn)
        local attachment = entity_attachments[entity]
        if attachment and attachment.originalOnHover then
            attachment.originalOnHover(reg, eid, releasedOn)
        end
        tooltips.showFor(entity)
    end

    go.methods.onStopHover = function(reg, eid)
        local attachment = entity_attachments[entity]
        if attachment and attachment.originalOnStopHover then
            attachment.originalOnStopHover(reg, eid)
        end
        tooltips.hide()
    end
end

--- Detach tooltip from an entity
--- @param entity number Entity ID
function tooltips.detachFromEntity(entity)
    local attachment = entity_attachments[entity]
    if not attachment then return end

    -- Restore original handlers
    local go = component_cache.get(entity, GameObject)
    if go then
        go.methods.onHover = attachment.originalOnHover
        go.methods.onStopHover = attachment.originalOnStopHover
    end

    entity_attachments[entity] = nil

    -- If this entity's tooltip is showing, hide it
    if active_target == entity then
        tooltips.hide()
    end
end

--- Show tooltip for an entity
--- @param entity number Entity ID with attached tooltip
function tooltips.showFor(entity)
    local attachment = entity_attachments[entity]
    if not attachment then return end

    local def = tooltip_definitions[attachment.name]
    if not def then return end

    -- Use TooltipV2 if available and enabled
    local v2 = USE_TOOLTIP_V2 and getTooltipV2()
    if v2 then
        -- Same target? V2 handles repositioning internally
        if active_target == entity then
            return
        end

        -- Hide previous tooltip
        if active_target then
            v2.hide(active_target)
        end

        -- Interpolate template
        local title = interpolateTemplate(def.title, attachment.params)
        local body = interpolateTemplate(def.body, attachment.params)

        -- Show V2 tooltip
        v2.show(entity, {
            name = title,
            description = body,
            info = def.info,
            nameEffects = def.opts and def.opts.nameEffects,
        })
        active_target = entity
        active_tooltip = true  -- V2 manages actual entities
        return
    end

    -- Fallback: Legacy tooltip system
    -- Same target? Just reposition
    if active_target == entity and active_tooltip then
        if centerTooltipAboveEntity then
            centerTooltipAboveEntity(active_tooltip, entity, 12)
        end
        return
    end

    -- Hide previous
    tooltips.hide()

    -- Interpolate template
    local title = interpolateTemplate(def.title, attachment.params)
    local body = interpolateTemplate(def.body, attachment.params)

    -- Create tooltip using existing system
    local cacheKey = "tooltip_registry:" .. getCacheKey(attachment.name, attachment.params)
    active_cache_key = cacheKey  -- Store for hide()

    if showSimpleTooltipAbove then
        active_tooltip = showSimpleTooltipAbove(cacheKey, title, body, entity, def.opts)
        active_target = entity
    end
end

--- Hide the currently visible tooltip
function tooltips.hide()
    -- Use TooltipV2 if available and enabled
    local v2 = USE_TOOLTIP_V2 and getTooltipV2()
    if v2 and active_target then
        v2.hide(active_target)
        active_tooltip = nil
        active_target = nil
        return
    end

    -- Fallback: Legacy tooltip system
    if active_tooltip and hideSimpleTooltip and active_cache_key then
        hideSimpleTooltip(active_cache_key)
    end
    active_tooltip = nil
    active_target = nil
    active_cache_key = nil
end

--- Get the currently active tooltip entity (if any)
--- @return number? tooltipEntity
function tooltips.getActiveTooltip()
    return active_tooltip
end

--- Clear all attachments (for cleanup/reset)
function tooltips.clearAll()
    for entity in pairs(entity_attachments) do
        tooltips.detachFromEntity(entity)
    end
    tooltips.hide()

    -- Also clear V2 cache if available
    local v2 = getTooltipV2()
    if v2 and v2.clearCache then
        v2.clearCache()
    end
end

--- Check if using TooltipV2 system
--- @return boolean
function tooltips.isUsingV2()
    return USE_TOOLTIP_V2 and getTooltipV2() ~= nil
end

return tooltips
