--[[
================================================================================
UI Background System
================================================================================
Per-element background customization with ninepatch support and state handling.

Usage:
    local bg = require("ui.ui_background")
    
    -- Apply background to element
    bg.apply(element, {
        normal = { type = "ninepatch", sprite = "panel_dark" },
        hover = { type = "ninepatch", sprite = "panel_dark_hover" },
        pressed = { type = "color", color = "blue" },
    })
    
    -- Inline ninepatch definition
    bg.apply(element, {
        normal = {
            type = "ninepatch",
            corners = { tl = "panel_tl", t = "panel_t", ... },
            borders = { left = 8, right = 8, top = 8, bottom = 8 },
        }
    })

Dependencies: component_cache, nine_patch (C++)
================================================================================
]]

local UIBackground = {}

local component_cache = require("core.component_cache")

local _backgroundRegistry = {}

--------------------------------------------------------------------------------
-- State Constants
--------------------------------------------------------------------------------

UIBackground.State = {
    NORMAL = "normal",
    HOVER = "hover",
    PRESSED = "pressed",
    DISABLED = "disabled",
    FOCUSED = "focused",
}

--------------------------------------------------------------------------------
-- Background Type Constants
--------------------------------------------------------------------------------

UIBackground.Type = {
    COLOR = "color",
    NINEPATCH = "ninepatch",
    SPRITE = "sprite",
    GRADIENT = "gradient",  -- Future
}

--------------------------------------------------------------------------------
-- Internal: Parse background definition
--------------------------------------------------------------------------------

local function parseBackgroundDef(def)
    if not def then return nil end
    
    local result = {
        type = def.type or UIBackground.Type.COLOR,
    }
    
    if result.type == UIBackground.Type.COLOR then
        result.color = def.color
        
    elseif result.type == UIBackground.Type.NINEPATCH then
        -- Option A: Single sprite with borders
        if def.sprite then
            result.sprite = def.sprite
            result.borders = def.borders or { left = 8, right = 8, top = 8, bottom = 8 }
        end
        
        -- Option B: Nine separate corner sprites
        if def.corners then
            result.corners = def.corners
        end
        
        -- Tiling options
        result.tileEdges = def.tileEdges or false
        result.tileCenter = def.tileCenter or false
        result.pixelScale = def.pixelScale or 1.0
        
    elseif result.type == UIBackground.Type.SPRITE then
        result.sprite = def.sprite
        result.scaleMode = def.scaleMode or "stretch"  -- stretch, tile, fixed
        result.opacity = def.opacity or 1.0
    end
    
    return result
end

--------------------------------------------------------------------------------
-- Apply background configuration to element
--------------------------------------------------------------------------------

function UIBackground.apply(entity, config)
    if not registry:valid(entity) then
        return false
    end
    
    local key = tostring(entity)
    _backgroundRegistry[key] = {
        states = {},
        currentState = UIBackground.State.NORMAL,
    }
    
    for state, def in pairs(config) do
        if UIBackground.State[state:upper()] or state == "normal" or state == "hover" or state == "pressed" or state == "disabled" or state == "focused" then
            _backgroundRegistry[key].states[state] = parseBackgroundDef(def)
        end
    end
    
    UIBackground.setState(entity, UIBackground.State.NORMAL)
    UIBackground.setupStateHooks(entity)
    
    return true
end

--------------------------------------------------------------------------------
-- Set background state
--------------------------------------------------------------------------------

function UIBackground.setState(entity, state)
    local key = tostring(entity)
    local bgConfig = _backgroundRegistry[key]
    if not bgConfig then
        return false
    end
    bgConfig.currentState = state
    
    -- Get background def for state (fallback to normal)
    local def = bgConfig.states[state] or bgConfig.states[UIBackground.State.NORMAL]
    if not def then return false end
    
    -- Apply to UIConfig
    local uiConfig = component_cache.get(entity, UIConfig)
    if not uiConfig then return false end
    
    if def.type == UIBackground.Type.COLOR then
        if def.color then
            local c = type(def.color) == "string" and util.getColor(def.color) or def.color
            uiConfig.color = c
        end
        uiConfig.stylingType = UIStylingType.ROUNDED_RECTANGLE
        
    elseif def.type == UIBackground.Type.NINEPATCH then
        uiConfig.stylingType = UIStylingType.NINEPATCH_BORDERS
        
        -- If corners defined, need to bake ninepatch
        if def.corners then
            -- Use nine_patch.BakeNinePatchFromSprites if available
            if nine_patch and nine_patch.BakeNinePatchFromSprites then
                local baked = nine_patch.BakeNinePatchFromSprites({
                    tl = def.corners.tl, t = def.corners.t, tr = def.corners.tr,
                    l = def.corners.l, c = def.corners.c, r = def.corners.r,
                    bl = def.corners.bl, b = def.corners.b, br = def.corners.br,
                }, def.pixelScale or 1.0)
                
                if baked then
                    uiConfig.nPatchInfo = baked.info
                    uiConfig.nPatchSourceTexture = baked.texture
                end
            end
        elseif def.sprite then
            -- Use existing ninepatch from sprite
            local info, tex = animation_system.getNinepatchUIBorderInfo(def.sprite)
            if info and tex then
                uiConfig.nPatchInfo = info
                uiConfig.nPatchSourceTexture = tex
            end
        end
        
        -- Apply tiling options
        if def.tileEdges or def.tileCenter then
            uiConfig.nPatchTiling = {
                top = def.tileEdges,
                bottom = def.tileEdges,
                left = def.tileEdges,
                right = def.tileEdges,
                centerX = def.tileCenter,
                centerY = def.tileCenter,
                pixelScale = def.pixelScale or 1.0,
            }
        end
        
    elseif def.type == UIBackground.Type.SPRITE then
        uiConfig.stylingType = UIStylingType.SPRITE
        
        -- Get sprite texture
        if def.sprite then
            local frame = init.getSpriteFrame(def.sprite, globals.g_ctx)
            if frame then
                uiConfig.spriteSourceTexture = getAtlasTexture(frame.atlasUUID)
                uiConfig.spriteSourceRect = frame.frame
            end
        end
        
        -- Scale mode
        if def.scaleMode == "tile" then
            uiConfig.spriteScaleMode = SpriteScaleMode.Tile
        elseif def.scaleMode == "fixed" then
            uiConfig.spriteScaleMode = SpriteScaleMode.Fixed
        else
            uiConfig.spriteScaleMode = SpriteScaleMode.Stretch
        end
    end
    
    return true
end

--------------------------------------------------------------------------------
-- Setup automatic state change hooks
--------------------------------------------------------------------------------

function UIBackground.setupStateHooks(entity)
    local go = component_cache.get(entity, GameObject)
    if not go then return end
    
    -- Store original handlers
    local originalOnHover = go.methods.onHover
    local originalOnStopHover = go.methods.onStopHover
    local originalOnClick = go.methods.onClick
    
    -- Hover state
    go.methods.onHover = function(...)
        UIBackground.setState(entity, UIBackground.State.HOVER)
        if originalOnHover then originalOnHover(...) end
    end
    
    go.methods.onStopHover = function(...)
        UIBackground.setState(entity, UIBackground.State.NORMAL)
        if originalOnStopHover then originalOnStopHover(...) end
    end
    
    -- For pressed state, would need mouse down/up tracking
    -- This is simplified - full implementation would track mouse state
end

--------------------------------------------------------------------------------
-- Get current background state
--------------------------------------------------------------------------------

function UIBackground.getState(entity)
    local key = tostring(entity)
    local bgConfig = _backgroundRegistry[key]
    if not bgConfig then
        return UIBackground.State.NORMAL
    end
    return bgConfig.currentState
end

--------------------------------------------------------------------------------
-- Check if entity has background configuration
--------------------------------------------------------------------------------

function UIBackground.hasBackground(entity)
    local key = tostring(entity)
    return _backgroundRegistry[key] ~= nil
end

--------------------------------------------------------------------------------
-- Remove background configuration
--------------------------------------------------------------------------------

function UIBackground.remove(entity)
    local key = tostring(entity)
    _backgroundRegistry[key] = nil
end

return UIBackground
