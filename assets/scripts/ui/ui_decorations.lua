--[[
================================================================================
UI Decorations System
================================================================================
Corner badges, overlays, and decorative elements for UI components.

Usage:
    local decor = require("ui.ui_decorations")
    
    -- Add corner badge
    decor.addBadge(element, {
        icon = "star_icon",
        position = "top_right",
        offset = { x = -4, y = 4 },
        size = { w = 16, h = 16 },
    })
    
    -- Add overlay
    decor.addOverlay(element, {
        id = "glow",
        sprite = "glow_effect",
        position = "center",
        opacity = 0.5,
        z = -1,  -- Behind content
    })
    
    -- Add custom draw overlay
    decor.addCustomOverlay(element, {
        id = "selection",
        visible = function(self) return isSelected(self) end,
        onDraw = function(self, x, y, w, h, z)
            -- Custom rendering
        end,
    })

Dependencies: component_cache, animation_system, command_buffer
================================================================================
]]

local UIDecorations = {}

local component_cache = require("core.component_cache")

--------------------------------------------------------------------------------
-- Position Constants
--------------------------------------------------------------------------------

UIDecorations.Position = {
    TOP_LEFT = "top_left",
    TOP_CENTER = "top_center",
    TOP_RIGHT = "top_right",
    CENTER_LEFT = "center_left",
    CENTER = "center",
    CENTER_RIGHT = "center_right",
    BOTTOM_LEFT = "bottom_left",
    BOTTOM_CENTER = "bottom_center",
    BOTTOM_RIGHT = "bottom_right",
}

--------------------------------------------------------------------------------
-- Internal: Calculate position offset
--------------------------------------------------------------------------------

local function calculatePosition(position, elementW, elementH, decorW, decorH, offset)
    offset = offset or { x = 0, y = 0 }
    local x, y = 0, 0
    
    -- Horizontal
    if position:find("left") then
        x = offset.x
    elseif position:find("right") then
        x = elementW - decorW + offset.x
    else
        x = (elementW - decorW) / 2 + offset.x
    end
    
    -- Vertical
    if position:find("top") then
        y = offset.y
    elseif position:find("bottom") then
        y = elementH - decorH + offset.y
    else
        y = (elementH - decorH) / 2 + offset.y
    end
    
    return x, y
end

--------------------------------------------------------------------------------
-- Internal: Get decoration storage
--------------------------------------------------------------------------------

local function getDecorations(entity)
    local go = component_cache.get(entity, GameObject)
    if not go then return nil end
    go.config = go.config or {}
    go.config._decorations = go.config._decorations or {
        badges = {},
        overlays = {},
        customOverlays = {},
    }
    return go.config._decorations
end

--------------------------------------------------------------------------------
-- Add corner badge (sprite-based)
--------------------------------------------------------------------------------

function UIDecorations.addBadge(entity, config)
    local decor = getDecorations(entity)
    if not decor then return nil end
    
    local badge = {
        id = config.id or ("badge_" .. tostring(#decor.badges + 1)),
        icon = config.icon,
        position = config.position or UIDecorations.Position.TOP_RIGHT,
        offset = config.offset or { x = 0, y = 0 },
        size = config.size or { w = 16, h = 16 },
        visible = config.visible,  -- Optional visibility function
        text = config.text,  -- Optional text instead of icon
        textColor = config.textColor or "white",
        backgroundColor = config.backgroundColor,
        entity = nil,  -- Will be created when drawn
    }
    
    table.insert(decor.badges, badge)
    
    -- Create badge entity if we have animation_system
    if animation_system and badge.icon then
        badge.entity = animation_system.createAnimatedObjectWithTransform(
            badge.icon, true, 0, 0, nil, false
        )
        animation_system.resizeAnimationObjectsInEntityToFit(
            badge.entity, badge.size.w, badge.size.h
        )
    end
    
    return badge.id
end

--------------------------------------------------------------------------------
-- Add sprite overlay
--------------------------------------------------------------------------------

function UIDecorations.addOverlay(entity, config)
    local decor = getDecorations(entity)
    if not decor then return nil end
    
    local overlay = {
        id = config.id or ("overlay_" .. tostring(#decor.overlays + 1)),
        sprite = config.sprite,
        position = config.position or UIDecorations.Position.CENTER,
        offset = config.offset or { x = 0, y = 0 },
        size = config.size,  -- nil = fill element
        opacity = config.opacity or 1.0,
        z = config.z or 0,  -- Relative z-offset (negative = behind)
        visible = config.visible,
        blendMode = config.blendMode,  -- Future: additive, multiply
        entity = nil,
    }
    
    table.insert(decor.overlays, overlay)
    
    return overlay.id
end

--------------------------------------------------------------------------------
-- Add custom draw overlay
--------------------------------------------------------------------------------

function UIDecorations.addCustomOverlay(entity, config)
    local decor = getDecorations(entity)
    if not decor then return nil end
    
    local overlay = {
        id = config.id or ("custom_" .. tostring(#decor.customOverlays + 1)),
        visible = config.visible,  -- function(self) -> bool
        onDraw = config.onDraw,    -- function(self, x, y, w, h, z)
        z = config.z or 0,
    }
    
    table.insert(decor.customOverlays, overlay)
    
    return overlay.id
end

--------------------------------------------------------------------------------
-- Remove decoration by ID
--------------------------------------------------------------------------------

function UIDecorations.remove(entity, decorId)
    local decor = getDecorations(entity)
    if not decor then return false end
    
    -- Check badges
    for i, badge in ipairs(decor.badges) do
        if badge.id == decorId then
            if badge.entity and registry:valid(badge.entity) then
                registry:destroy(badge.entity)
            end
            table.remove(decor.badges, i)
            return true
        end
    end
    
    -- Check overlays
    for i, overlay in ipairs(decor.overlays) do
        if overlay.id == decorId then
            if overlay.entity and registry:valid(overlay.entity) then
                registry:destroy(overlay.entity)
            end
            table.remove(decor.overlays, i)
            return true
        end
    end
    
    -- Check custom overlays
    for i, overlay in ipairs(decor.customOverlays) do
        if overlay.id == decorId then
            table.remove(decor.customOverlays, i)
            return true
        end
    end
    
    return false
end

--------------------------------------------------------------------------------
-- Update decoration positions (call after element resize)
--------------------------------------------------------------------------------

function UIDecorations.updatePositions(entity)
    local decor = getDecorations(entity)
    if not decor then return end
    
    local transform = component_cache.get(entity, Transform)
    if not transform then return end
    
    local elementW = transform.actualW or transform.w or 0
    local elementH = transform.actualH or transform.h or 0
    local elementX = transform.actualX or transform.visualX or 0
    local elementY = transform.actualY or transform.visualY or 0
    
    -- Update badge positions
    for _, badge in ipairs(decor.badges) do
        if badge.entity and registry:valid(badge.entity) then
            local badgeT = component_cache.get(badge.entity, Transform)
            if badgeT then
                local ox, oy = calculatePosition(
                    badge.position, elementW, elementH,
                    badge.size.w, badge.size.h, badge.offset
                )
                badgeT.actualX = elementX + ox
                badgeT.actualY = elementY + oy
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Draw decorations (call during element draw)
--------------------------------------------------------------------------------

function UIDecorations.draw(entity, baseZ)
    local decor = getDecorations(entity)
    if not decor then return end
    
    local transform = component_cache.get(entity, Transform)
    if not transform then return end
    
    local elementW = transform.actualW or transform.w or 0
    local elementH = transform.actualH or transform.h or 0
    local elementX = transform.actualX or transform.visualX or 0
    local elementY = transform.actualY or transform.visualY or 0
    
    baseZ = baseZ or 0
    
    -- Draw custom overlays
    for _, overlay in ipairs(decor.customOverlays) do
        local visible = true
        if overlay.visible then
            visible = overlay.visible(entity)
        end
        
        if visible and overlay.onDraw then
            overlay.onDraw(entity, elementX, elementY, elementW, elementH, baseZ + overlay.z)
        end
    end
end

--------------------------------------------------------------------------------
-- Check if entity has decorations
--------------------------------------------------------------------------------

function UIDecorations.hasDecorations(entity)
    local go = component_cache.get(entity, GameObject)
    return go and go.config and go.config._decorations ~= nil
end

--------------------------------------------------------------------------------
-- Get all decoration IDs
--------------------------------------------------------------------------------

function UIDecorations.getDecorationIds(entity)
    local decor = getDecorations(entity)
    if not decor then return {} end
    
    local ids = {}
    for _, badge in ipairs(decor.badges) do
        table.insert(ids, badge.id)
    end
    for _, overlay in ipairs(decor.overlays) do
        table.insert(ids, overlay.id)
    end
    for _, overlay in ipairs(decor.customOverlays) do
        table.insert(ids, overlay.id)
    end
    return ids
end

--------------------------------------------------------------------------------
-- Set badge text (for dynamic badges like stack counts)
--------------------------------------------------------------------------------

function UIDecorations.setBadgeText(entity, badgeId, text)
    local decor = getDecorations(entity)
    if not decor then return false end
    
    for _, badge in ipairs(decor.badges) do
        if badge.id == badgeId then
            badge.text = text
            return true
        end
    end
    return false
end

--------------------------------------------------------------------------------
-- Set decoration visibility
--------------------------------------------------------------------------------

function UIDecorations.setVisible(entity, decorId, visible)
    local decor = getDecorations(entity)
    if not decor then return false end
    
    -- Check all decoration types
    for _, badge in ipairs(decor.badges) do
        if badge.id == decorId then
            badge.visible = function() return visible end
            return true
        end
    end
    
    for _, overlay in ipairs(decor.overlays) do
        if overlay.id == decorId then
            overlay.visible = function() return visible end
            return true
        end
    end
    
    for _, overlay in ipairs(decor.customOverlays) do
        if overlay.id == decorId then
            overlay.visible = function() return visible end
            return true
        end
    end
    
    return false
end

return UIDecorations
