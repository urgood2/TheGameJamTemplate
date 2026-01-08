--[[
================================================================================
UI Decorations System
================================================================================
Corner badges, overlays, and decorative elements for UI components.

Usage:
    local decor = require("ui.ui_decorations")
    
    -- Text badge
    decor.addBadge(element, {
        text = "5",
        backgroundColor = "red",
        position = decor.Position.BOTTOM_RIGHT,
        size = { w = 16, h = 16 },
    })
    
    -- Sprite icon badge
    decor.addBadge(element, {
        icon = "fire_icon",
        position = decor.Position.TOP_LEFT,
        size = { w = 16, h = 16 },
    })
    
    -- Sprite overlay with visibility function (for hover/selection)
    decor.addOverlay(element, {
        sprite = "glow_effect",
        opacity = 0.5,
        z = -1,
        visible = function(eid)
            local inputState = component_cache.get(eid, InputState)
            return inputState and inputState.cursor_hovering_target
        end,
    })
    
    -- Custom draw overlay (no sprite required)
    decor.addCustomOverlay(element, {
        visible = function(eid) return someCondition end,
        onDraw = function(eid, x, y, w, h, z)
            command_buffer.queueDrawRectangle(...)
        end,
    })

Dependencies: component_cache, animation_system, command_buffer
================================================================================
]]

local UIDecorations = {}

local component_cache = require("core.component_cache")

local _decorRegistry = {}

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
    if not registry:valid(entity) then return nil end
    local key = tostring(entity)
    if not _decorRegistry[key] then
        _decorRegistry[key] = {
            badges = {},
            overlays = {},
            customOverlays = {},
        }
    end
    return _decorRegistry[key]
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
        size = config.size,
        opacity = config.opacity or 1.0,
        z = config.z or 0,
        visible = config.visible,
        blendMode = config.blendMode,
        entity = nil,
        _entityCreated = false,
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

local function ensureOverlayEntity(overlay, elementW, elementH)
    if overlay._entityCreated or not overlay.sprite then return end
    if not animation_system then return end
    
    local w = overlay.size and overlay.size.w or elementW
    local h = overlay.size and overlay.size.h or elementH
    
    overlay.entity = animation_system.createAnimatedObjectWithTransform(
        overlay.sprite, true, 0, 0, nil, false
    )
    if overlay.entity and registry:valid(overlay.entity) then
        animation_system.resizeAnimationObjectsInEntityToFit(overlay.entity, w, h)
        overlay._entityCreated = true
        overlay._cachedSize = { w = w, h = h }
    end
end

local function ensureBadgeEntity(badge)
    if badge.entity or not badge.icon then return end
    if not animation_system then return end
    
    badge.entity = animation_system.createAnimatedObjectWithTransform(
        badge.icon, true, 0, 0, nil, false
    )
    if badge.entity and registry:valid(badge.entity) then
        animation_system.resizeAnimationObjectsInEntityToFit(
            badge.entity, badge.size.w, badge.size.h
        )
    end
end

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
    
    for _, overlay in ipairs(decor.overlays) do
        local visible = true
        if overlay.visible then
            visible = type(overlay.visible) == "function" and overlay.visible(entity) or overlay.visible
        end
        
        if visible and overlay.sprite then
            ensureOverlayEntity(overlay, elementW, elementH)
            
            if overlay.entity and registry:valid(overlay.entity) then
                local overlayW = overlay._cachedSize and overlay._cachedSize.w or elementW
                local overlayH = overlay._cachedSize and overlay._cachedSize.h or elementH
                
                local ox, oy = calculatePosition(
                    overlay.position, elementW, elementH,
                    overlayW, overlayH, overlay.offset
                )
                
                local overlayTransform = component_cache.get(overlay.entity, Transform)
                if overlayTransform then
                    overlayTransform.actualX = elementX + ox
                    overlayTransform.actualY = elementY + oy
                    overlayTransform.z = baseZ + overlay.z
                end
                
                local go = component_cache.get(overlay.entity, GameObject)
                if go then
                    go.state.isActive = true
                    go.state.alpha = overlay.opacity
                end
            end
        elseif overlay.entity and registry:valid(overlay.entity) then
            local go = component_cache.get(overlay.entity, GameObject)
            if go then
                go.state.isActive = false
            end
        end
    end
    
    for _, badge in ipairs(decor.badges) do
        local visible = true
        if badge.visible then
            visible = type(badge.visible) == "function" and badge.visible(entity) or badge.visible
        end
        
        if visible and badge.icon then
            ensureBadgeEntity(badge)
            
            if badge.entity and registry:valid(badge.entity) then
                local ox, oy = calculatePosition(
                    badge.position, elementW, elementH,
                    badge.size.w, badge.size.h, badge.offset
                )
                
                local badgeTransform = component_cache.get(badge.entity, Transform)
                if badgeTransform then
                    badgeTransform.actualX = elementX + ox
                    badgeTransform.actualY = elementY + oy
                    badgeTransform.z = baseZ + 2
                end
                
                local go = component_cache.get(badge.entity, GameObject)
                if go then
                    go.state.isActive = true
                end
            end
        elseif visible and badge.text and badge.text ~= "" then
            local ox, oy = calculatePosition(
                badge.position, elementW, elementH,
                badge.size.w, badge.size.h, badge.offset
            )
            local bx, by = elementX + ox, elementY + oy
            
            if command_buffer and command_buffer.queueDrawRectangle then
                local bgColor = badge.backgroundColor
                if type(bgColor) == "string" then
                    bgColor = util and util.getColor(bgColor)
                end
                if bgColor then
                    command_buffer.queueDrawRectangle(
                        layers.ui or "ui", function() end,
                        bx, by, badge.size.w, badge.size.h,
                        bgColor, baseZ + 1, layer.DrawCommandSpace.Screen
                    )
                end
            end
            
            if command_buffer and command_buffer.queueDrawTextPro then
                local textColor = badge.textColor
                if type(textColor) == "string" then
                    textColor = util and util.getColor(textColor)
                end
                command_buffer.queueDrawTextPro(
                    layers.ui or "ui", function() end,
                    badge.text,
                    bx + badge.size.w / 2, by + badge.size.h / 2,
                    10, textColor or Color.new(255,255,255,255),
                    baseZ + 2, layer.DrawCommandSpace.Screen
                )
            end
        elseif badge.entity and registry:valid(badge.entity) then
            local go = component_cache.get(badge.entity, GameObject)
            if go then
                go.state.isActive = false
            end
        end
    end
    
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
    local key = tostring(entity)
    return _decorRegistry[key] ~= nil
end

function UIDecorations.cleanup(entity)
    local key = tostring(entity)
    local decor = _decorRegistry[key]
    if decor then
        for _, badge in ipairs(decor.badges) do
            if badge.entity and registry:valid(badge.entity) then
                registry:destroy(badge.entity)
            end
        end
        for _, overlay in ipairs(decor.overlays) do
            if overlay.entity and registry:valid(overlay.entity) then
                registry:destroy(overlay.entity)
            end
        end
    end
    _decorRegistry[key] = nil
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
