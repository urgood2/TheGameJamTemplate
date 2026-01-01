--[[
================================================================================
LIGHTING SYSTEM - Dynamic Multi-Light Layer Shader API
================================================================================
A Lua-accessible lighting system that applies dynamic lights to render layers 
via a fluent builder API. Supports up to 16 simultaneous lights with both 
additive and subtractive blend modes.

Usage:
    local Lighting = require("core.lighting")
    
    -- Enable lighting on a layer
    Lighting.enable("sprites", { mode = "subtractive" })
    Lighting.setAmbient("sprites", 0.1)
    
    -- Create a point light attached to player
    local light = Lighting.point()
        :attachTo(playerEntity)
        :radius(200)
        :intensity(1.0)
        :color("orange")
        :create()
    
    -- Create a spotlight
    local spot = Lighting.spot()
        :at(400, 300)
        :direction(90)
        :angle(45)
        :radius(300)
        :create()
    
    -- Animate with timer
    timer.every(0.1, function()
        light:setIntensity(0.8 + math.random() * 0.4)
    end)

Dependencies:
    - add_layer_shader / remove_layer_shader (C++ bindings)
    - globalShaderUniforms (C++ binding)
    - shaders.registerUniformUpdate (C++ binding)
    - component_cache, entity_cache (Lua modules)

Design:
    - Max 16 lights per layer (shader limit)
    - Lights stored in world pixel coordinates
    - Camera-aware UV conversion each frame
    - Auto-cleanup when attached entities are destroyed
]]

local Lighting = {}

-- Debug flag - set to true to see uniform sync output
local DEBUG_LIGHTING = true  -- TEMP: Enable for debugging

--------------------------------------------------------------------------------
-- VECTOR HELPERS
--------------------------------------------------------------------------------

local function Vector2(x, y)
    if _G.Vector2 then
        return _G.Vector2(x, y)
    end
    return { x = x or 0.0, y = y or 0.0 }
end

local function Vector3(x, y, z)
    if _G.Vector3 then
        return _G.Vector3(x, y, z)
    end
    return { x = x or 0.0, y = y or 0.0, z = z or 0.0 }
end

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------

local MAX_LIGHTS = 16
local LIGHT_TYPE_POINT = 0
local LIGHT_TYPE_SPOT = 1
local BLEND_MODE_SUBTRACTIVE = 0
local BLEND_MODE_ADDITIVE = 1

--------------------------------------------------------------------------------
-- NAMED COLORS
--------------------------------------------------------------------------------

local NAMED_COLORS = {
    white = { 1.0, 1.0, 1.0 },
    black = { 0.0, 0.0, 0.0 },
    red = { 1.0, 0.0, 0.0 },
    green = { 0.0, 1.0, 0.0 },
    blue = { 0.0, 0.0, 1.0 },
    yellow = { 1.0, 1.0, 0.0 },
    orange = { 1.0, 0.65, 0.0 },
    cyan = { 0.0, 1.0, 1.0 },
    magenta = { 1.0, 0.0, 1.0 },
    purple = { 0.5, 0.0, 0.5 },
    pink = { 1.0, 0.75, 0.8 },
    gold = { 1.0, 0.84, 0.0 },
    fire = { 1.0, 0.4, 0.1 },
    ice = { 0.5, 0.8, 1.0 },
    electric = { 0.8, 0.9, 1.0 },
}

--------------------------------------------------------------------------------
-- MODULE STATE
--------------------------------------------------------------------------------

-- Per-layer lighting state
-- _layers[layerName] = {
--     enabled = bool,
--     paused = bool,
--     ambient = float,
--     blendMode = int,
--     lights = { lightObj, ... }
-- }
Lighting._layers = {}

-- Default layer for new lights
Lighting._defaultLayer = nil

-- Light ID counter for unique handles
local _lightIdCounter = 0

--------------------------------------------------------------------------------
-- PRIVATE HELPERS
--------------------------------------------------------------------------------

local component_cache = nil
local entity_cache = nil
local Transform = nil

-- Lazy load dependencies to avoid circular requires
local function ensureDependencies()
    if not component_cache then
        component_cache = require("core.component_cache")
    end
    if not entity_cache then
        entity_cache = require("core.entity_cache")
    end
    if not Transform then
        Transform = _G.Transform
    end
end

-- Parse color from various formats
-- @param c string|table|number - Color name, RGB table, or individual RGB values
-- @param g number|nil - Green component (if c is red)
-- @param b number|nil - Blue component
-- @return table - { r, g, b } in 0-1 range
local function parseColor(c, g, b)
    if type(c) == "string" then
        local named = NAMED_COLORS[c:lower()]
        if named then
            return { named[1], named[2], named[3] }
        end
        -- Fallback to white if unknown
        return { 1.0, 1.0, 1.0 }
    elseif type(c) == "table" then
        -- Table can be { r, g, b } or { 1, 2, 3 }
        local r = c.r or c[1] or 1.0
        local gr = c.g or c[2] or 1.0
        local bl = c.b or c[3] or 1.0
        -- Normalize if values are 0-255
        if r > 1 or gr > 1 or bl > 1 then
            r, gr, bl = r / 255, gr / 255, bl / 255
        end
        return { r, gr, bl }
    elseif type(c) == "number" then
        -- Individual RGB values
        local r = c
        local gr = g or 1.0
        local bl = b or 1.0
        -- Normalize if values are 0-255
        if r > 1 or gr > 1 or bl > 1 then
            r, gr, bl = r / 255, gr / 255, bl / 255
        end
        return { r, gr, bl }
    end
    return { 1.0, 1.0, 1.0 }
end

-- Create a new unique light ID
local function newLightId()
    _lightIdCounter = _lightIdCounter + 1
    return _lightIdCounter
end

-- Get or create layer state
local function getLayerState(layerName)
    if not Lighting._layers[layerName] then
        Lighting._layers[layerName] = {
            enabled = false,
            paused = false,
            ambient = 0.2,
            blendMode = BLEND_MODE_SUBTRACTIVE,
            lights = {}
        }
    end
    return Lighting._layers[layerName]
end

-- Remove a light from its layer
local function removeLightFromLayer(light)
    if not light or not light._layerName then return end
    local state = Lighting._layers[light._layerName]
    if not state then return end
    
    for i, l in ipairs(state.lights) do
        if l._id == light._id then
            table.remove(state.lights, i)
            return
        end
    end
end

-- Convert world position to UV (0-1) coordinates
-- Uses camera offset for camera-aware conversion
local function worldToUV(worldX, worldY)
    local camX, camY = 0, 0
    
    -- Try to get camera offset from the camera system
    if _G.camera and _G.camera.getActiveOffset then
        local offset = _G.camera.getActiveOffset()
        if offset then
            camX, camY = offset.x or 0, offset.y or 0
        end
    elseif _G.camera and _G.camera.getActive then
        local cam = _G.camera.getActive()
        if cam then
            camX, camY = cam.x or cam.offsetX or 0, cam.y or cam.offsetY or 0
        end
    end
    
    -- Convert to screen space
    local screenX = worldX - camX
    local screenY = worldY - camY
    
    -- Convert to UV (0-1)
    local screenW = globals.screenWidth()
    local screenH = globals.screenHeight()
    
    local u = screenX / screenW
    local v = screenY / screenH
    
    return u, v
end

-- Convert radius in world pixels to UV space
local function radiusToUV(radiusPixels)
    local screenH = globals.screenHeight()
    return radiusPixels / screenH
end

--------------------------------------------------------------------------------
-- LAYER CONTROL API
--------------------------------------------------------------------------------

--- Enable lighting on a layer
-- @param layerName string - Name of the render layer
-- @param opts table|nil - Options: { mode = "subtractive"|"additive" }
function Lighting.enable(layerName, opts)
    opts = opts or {}
    local state = getLayerState(layerName)
    
    -- Set blend mode
    if opts.mode == "additive" then
        state.blendMode = BLEND_MODE_ADDITIVE
    else
        state.blendMode = BLEND_MODE_SUBTRACTIVE
    end
    
    -- Add shader to layer
    if not state.enabled then
        add_layer_shader(layerName, "lighting")
        state.enabled = true

        -- Pre-load shader to ensure uniform update callbacks run from first frame
        -- Without this, the shader isn't in loadedShaders and callbacks are skipped
        if shaders and shaders.getShader then
            local _ = shaders.getShader("lighting")
        end
    end

    state.paused = false
    
    -- Set as default layer if none set
    if not Lighting._defaultLayer then
        Lighting._defaultLayer = layerName
    end
end

--- Disable lighting on a layer (removes shader, destroys lights)
-- @param layerName string - Name of the render layer
function Lighting.disable(layerName)
    local state = Lighting._layers[layerName]
    if not state then return end
    
    -- Remove shader
    if state.enabled then
        remove_layer_shader(layerName, "lighting")
        state.enabled = false
    end
    
    -- Clear all lights
    state.lights = {}
    
    -- Clear default if this was it
    if Lighting._defaultLayer == layerName then
        Lighting._defaultLayer = nil
    end
end

--- Pause lighting (hides effect but keeps lights defined)
-- @param layerName string - Name of the render layer
function Lighting.pause(layerName)
    local state = Lighting._layers[layerName]
    if state then
        state.paused = true
    end
end

--- Resume lighting after pause
-- @param layerName string - Name of the render layer
function Lighting.resume(layerName)
    local state = Lighting._layers[layerName]
    if state then
        state.paused = false
    end
end

--- Set ambient light level for a layer
-- @param layerName string - Name of the render layer
-- @param level number - Ambient brightness (0 = pitch black, 1 = full bright)
function Lighting.setAmbient(layerName, level)
    local state = getLayerState(layerName)
    state.ambient = math.max(0, math.min(1, level or 0.2))
end

--- Check if lighting is enabled on a layer
-- @param layerName string - Name of the render layer
-- @return boolean
function Lighting.isEnabled(layerName)
    local state = Lighting._layers[layerName]
    return state and state.enabled or false
end

--- Remove all lights from a layer (but keep lighting enabled)
-- @param layerName string - Name of the render layer
function Lighting.removeAll(layerName)
    local state = Lighting._layers[layerName]
    if state then
        state.lights = {}
    end
end

--- Clear all lights from all layers
function Lighting.clear()
    for layerName, state in pairs(Lighting._layers) do
        state.lights = {}
    end
end

--------------------------------------------------------------------------------
-- LIGHT HANDLE
--------------------------------------------------------------------------------

local LightHandle = {}
LightHandle.__index = LightHandle

function LightHandle:isValid()
    if not self._light then return false end
    local state = Lighting._layers[self._light._layerName]
    if not state then return false end
    
    for _, l in ipairs(state.lights) do
        if l._id == self._light._id then
            return true
        end
    end
    return false
end

function LightHandle:destroy()
    if self._light then
        removeLightFromLayer(self._light)
        self._light._destroyed = true
        self._light = nil
    end
end

function LightHandle:setPosition(x, y)
    if self._light then
        self._light.worldX = x
        self._light.worldY = y
    end
    return self
end

function LightHandle:getPosition()
    if self._light then
        return self._light.worldX, self._light.worldY
    end
    return 0, 0
end

function LightHandle:setRadius(r)
    if self._light then
        self._light.radius = r
    end
    return self
end

function LightHandle:getRadius()
    if self._light then
        return self._light.radius
    end
    return 0
end

function LightHandle:setIntensity(i)
    if self._light then
        self._light.intensity = math.max(0, math.min(1, i))
    end
    return self
end

function LightHandle:getIntensity()
    if self._light then
        return self._light.intensity
    end
    return 0
end

function LightHandle:setColor(c, g, b)
    if self._light then
        self._light.color = parseColor(c, g, b)
    end
    return self
end

function LightHandle:attachTo(entity)
    if self._light then
        self._light.attachedEntity = entity
    end
    return self
end

function LightHandle:detach()
    if self._light then
        self._light.attachedEntity = nil
    end
    return self
end

--------------------------------------------------------------------------------
-- FLUENT BUILDER - POINT LIGHT
--------------------------------------------------------------------------------

local PointLightBuilder = {}
PointLightBuilder.__index = PointLightBuilder

function PointLightBuilder:at(x, y)
    self._x = x
    self._y = y
    return self
end

function PointLightBuilder:attachTo(entity)
    self._entity = entity
    return self
end

function PointLightBuilder:radius(r)
    self._radius = r
    return self
end

function PointLightBuilder:intensity(i)
    self._intensity = i
    return self
end

function PointLightBuilder:color(c, g, b)
    self._color = parseColor(c, g, b)
    return self
end

function PointLightBuilder:additive()
    self._blendMode = 1
    return self
end

function PointLightBuilder:layer(layerName)
    self._layerName = layerName
    return self
end

function PointLightBuilder:create()
    local layerName = self._layerName or Lighting._defaultLayer
    
    -- Validate layer exists and is enabled
    if not layerName then
        log_warn("Lighting.point():create() - No default layer set. Call Lighting.enable() first.")
        return setmetatable({ _light = nil }, LightHandle)
    end
    
    local state = Lighting._layers[layerName]
    if not state or not state.enabled then
        log_warn("Lighting.point():create() - Layer '" .. layerName .. "' not enabled.")
        return setmetatable({ _light = nil }, LightHandle)
    end
    
    -- Check light count
    if #state.lights >= MAX_LIGHTS then
        log_warn("Lighting: Max lights (" .. MAX_LIGHTS .. ") reached for layer '" .. layerName .. "'")
        return setmetatable({ _light = nil }, LightHandle)
    end
    
    -- Create light object
    local light = {
        _id = newLightId(),
        _layerName = layerName,
        _destroyed = false,
        type = LIGHT_TYPE_POINT,
        worldX = self._x or 0,
        worldY = self._y or 0,
        radius = self._radius or 100,
        intensity = self._intensity or 1.0,
        color = self._color or { 1.0, 1.0, 1.0 },
        blendMode = self._blendMode or 0,
        attachedEntity = self._entity,
        -- Spot-only fields (unused for point)
        directionDeg = 0,
        angleDeg = 360,
    }

    table.insert(state.lights, light)

    if DEBUG_LIGHTING then
        print(string.format("[Lighting] Created point light #%d at (%.0f, %.0f) r=%d on layer '%s'",
            light._id, light.worldX, light.worldY, light.radius, layerName))
    end

    return setmetatable({ _light = light }, LightHandle)
end

--- Create a point light builder
-- @return PointLightBuilder
function Lighting.point()
    return setmetatable({
        _x = 0,
        _y = 0,
        _radius = 100,
        _intensity = 1.0,
        _color = { 1.0, 1.0, 1.0 },
        _blendMode = 0,
        _entity = nil,
        _layerName = nil,
    }, PointLightBuilder)
end

--------------------------------------------------------------------------------
-- FLUENT BUILDER - SPOTLIGHT
--------------------------------------------------------------------------------

local SpotLightBuilder = {}
SpotLightBuilder.__index = SpotLightBuilder

function SpotLightBuilder:at(x, y)
    self._x = x
    self._y = y
    return self
end

function SpotLightBuilder:attachTo(entity)
    self._entity = entity
    return self
end

function SpotLightBuilder:direction(deg)
    self._direction = deg
    return self
end

function SpotLightBuilder:angle(deg)
    self._angle = deg
    return self
end

function SpotLightBuilder:radius(r)
    self._radius = r
    return self
end

function SpotLightBuilder:intensity(i)
    self._intensity = i
    return self
end

function SpotLightBuilder:color(c, g, b)
    self._color = parseColor(c, g, b)
    return self
end

function SpotLightBuilder:additive()
    self._blendMode = 1
    return self
end

function SpotLightBuilder:layer(layerName)
    self._layerName = layerName
    return self
end

function SpotLightBuilder:create()
    local layerName = self._layerName or Lighting._defaultLayer
    
    -- Validate layer exists and is enabled
    if not layerName then
        log_warn("Lighting.spot():create() - No default layer set. Call Lighting.enable() first.")
        return setmetatable({ _light = nil }, LightHandle)
    end
    
    local state = Lighting._layers[layerName]
    if not state or not state.enabled then
        log_warn("Lighting.spot():create() - Layer '" .. layerName .. "' not enabled.")
        return setmetatable({ _light = nil }, LightHandle)
    end
    
    -- Check light count
    if #state.lights >= MAX_LIGHTS then
        log_warn("Lighting: Max lights (" .. MAX_LIGHTS .. ") reached for layer '" .. layerName .. "'")
        return setmetatable({ _light = nil }, LightHandle)
    end
    
    -- Create light object
    local light = {
        _id = newLightId(),
        _layerName = layerName,
        _destroyed = false,
        type = LIGHT_TYPE_SPOT,
        worldX = self._x or 0,
        worldY = self._y or 0,
        radius = self._radius or 200,
        intensity = self._intensity or 1.0,
        color = self._color or { 1.0, 1.0, 1.0 },
        blendMode = self._blendMode or 0,
        attachedEntity = self._entity,
        directionDeg = self._direction or 0,
        angleDeg = self._angle or 45,
    }
    
    table.insert(state.lights, light)
    
    return setmetatable({ _light = light }, LightHandle)
end

--- Create a spotlight builder
-- @return SpotLightBuilder
function Lighting.spot()
    return setmetatable({
        _x = 0,
        _y = 0,
        _radius = 200,
        _intensity = 1.0,
        _color = { 1.0, 1.0, 1.0 },
        _blendMode = 0,
        _direction = 0,
        _angle = 45,
        _entity = nil,
        _layerName = nil,
    }, SpotLightBuilder)
end

--------------------------------------------------------------------------------
-- INTERNAL UPDATE (called each frame from shader_uniforms.lua)
--------------------------------------------------------------------------------

--- Update attached light positions and sync uniforms
-- Called internally each frame when lighting is enabled
function Lighting._update()
    ensureDependencies()
    
    for layerName, state in pairs(Lighting._layers) do
        if not state.enabled then goto continue end
        
        -- Update attached light positions
        local toRemove = {}
        for i, light in ipairs(state.lights) do
            if light.attachedEntity then
                if entity_cache.valid(light.attachedEntity) then
                    local t = component_cache.get(light.attachedEntity, Transform)
                    if t then
                        light.worldX = t.actualX + t.actualW * 0.5
                        light.worldY = t.actualY + t.actualH * 0.5
                    end
                else
                    -- Entity destroyed, mark for removal
                    table.insert(toRemove, i)
                end
            end
        end
        
        -- Remove destroyed entity lights (in reverse order)
        for i = #toRemove, 1, -1 do
            table.remove(state.lights, toRemove[i])
        end
        
        ::continue::
    end
end

--- Sync uniforms to shader for a specific layer
-- Called by shader_uniforms.lua in the uniform update callback
function Lighting._syncUniforms(layerName)
    local state = Lighting._layers[layerName]
    if not state then return end
    
    local screenW = globals.screenWidth()
    local screenH = globals.screenHeight()
    
    -- Set global uniforms
    globalShaderUniforms:set("lighting", "screen_width", screenW)
    globalShaderUniforms:set("lighting", "screen_height", screenH)
    globalShaderUniforms:set("lighting", "u_ambientLevel", state.ambient)
    globalShaderUniforms:set("lighting", "u_blendMode", state.blendMode)
    globalShaderUniforms:set("lighting", "u_feather", 0.2)  -- Default feather
    
    -- If paused, set light count to 0
    if state.paused then
        globalShaderUniforms:set("lighting", "u_lightCount", 0)
        return
    end
    
    -- Set light count
    local lightCount = math.min(#state.lights, MAX_LIGHTS)
    globalShaderUniforms:set("lighting", "u_lightCount", lightCount)

    if DEBUG_LIGHTING and lightCount > 0 then
        print(string.format("[Lighting] Syncing %d lights for layer '%s'", lightCount, layerName))
    end
    
    -- Sync each light's uniforms using indexed names
    for i = 1, MAX_LIGHTS do
        local idx = i - 1  -- 0-based for shader arrays
        local light = state.lights[i]
        
        if light and i <= lightCount then
            -- Convert world position to UV
            local u, v = worldToUV(light.worldX, light.worldY)
            local radiusUV = radiusToUV(light.radius)

            if DEBUG_LIGHTING then
                print(string.format("[Lighting] Light %d: world(%.0f,%.0f) -> UV(%.3f,%.3f) radius=%.3f",
                    idx, light.worldX, light.worldY, u, v, radiusUV))
            end

            -- Position as Vector2
            globalShaderUniforms:set("lighting", "u_lightPositions[" .. idx .. "]",
                Vector2(u, v))
            
            -- Radius
            globalShaderUniforms:set("lighting", "u_lightRadii[" .. idx .. "]", radiusUV)
            
            -- Intensity
            globalShaderUniforms:set("lighting", "u_lightIntensities[" .. idx .. "]", 
                light.intensity)
            
            -- Color as Vector3
            globalShaderUniforms:set("lighting", "u_lightColors[" .. idx .. "]",
                Vector3(light.color[1], light.color[2], light.color[3]))
            
            -- Type (0=point, 1=spot)
            globalShaderUniforms:set("lighting", "u_lightTypes[" .. idx .. "]", light.type)
            
            -- Blend mode
            globalShaderUniforms:set("lighting", "u_lightBlendModes[" .. idx .. "]", 
                light.blendMode)
            
            -- Spotlight-specific: direction (radians) and angle (cosine)
            local dirRad = math.rad(light.directionDeg or 0)
            local angleCos = math.cos(math.rad((light.angleDeg or 45) * 0.5))
            
            globalShaderUniforms:set("lighting", "u_lightDirections[" .. idx .. "]", dirRad)
            globalShaderUniforms:set("lighting", "u_lightAngles[" .. idx .. "]", angleCos)
        else
            -- Zero out unused slots to prevent stale data
            globalShaderUniforms:set("lighting", "u_lightPositions[" .. idx .. "]", 
                Vector2(0, 0))
            globalShaderUniforms:set("lighting", "u_lightRadii[" .. idx .. "]", 0)
            globalShaderUniforms:set("lighting", "u_lightIntensities[" .. idx .. "]", 0)
            globalShaderUniforms:set("lighting", "u_lightColors[" .. idx .. "]",
                Vector3(0, 0, 0))
            globalShaderUniforms:set("lighting", "u_lightTypes[" .. idx .. "]", 0)
            globalShaderUniforms:set("lighting", "u_lightBlendModes[" .. idx .. "]", 0)
            globalShaderUniforms:set("lighting", "u_lightDirections[" .. idx .. "]", 0)
            globalShaderUniforms:set("lighting", "u_lightAngles[" .. idx .. "]", 0)
        end
    end
end

--------------------------------------------------------------------------------
-- DEBUG HELPERS
--------------------------------------------------------------------------------

--- Get debug info about lighting state
-- @return table - Debug info
function Lighting.getDebugInfo()
    local info = {
        defaultLayer = Lighting._defaultLayer,
        layers = {}
    }
    
    for layerName, state in pairs(Lighting._layers) do
        info.layers[layerName] = {
            enabled = state.enabled,
            paused = state.paused,
            ambient = state.ambient,
            blendMode = state.blendMode == BLEND_MODE_ADDITIVE and "additive" or "subtractive",
            lightCount = #state.lights
        }
    end
    
    return info
end

return Lighting
