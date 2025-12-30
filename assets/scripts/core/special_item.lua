--[[
================================================================================
SPECIAL ITEM - Modular VFX System for Special/Rare Items
================================================================================
Creates visually distinct items with configurable:
- Main shader effect (holographic, prismatic, foil, etc.)
- Bubbly colorful particles spawned within sprite bounds
- Outline effect (configurable color and thickness)

Usage:
    local SpecialItem = require("core.special_item")

    local item = SpecialItem.create({
        sprite = "rare_sword",
        position = { x = 400, y = 300 },
        size = { 64, 64 },
    })

    local item = SpecialItem.create({
        sprite = "legendary_item",
        position = { x = 400, y = 300 },
        size = { 64, 64 },
        shader = "3d_skew_prismatic",
        shaderUniforms = { sheen_strength = 1.5 },
        particles = {
            enabled = true,
            preset = "sparkle",
            colors = { "cyan", "magenta", "yellow" },
            density = 1.0,
        },
        outline = {
            enabled = true,
            color = { 255, 215, 0, 255 },
            thickness = 2,
            type = 8,
        },
    })

    local item = SpecialItem.new("rare_item")
        :at(400, 300)
        :size(64, 64)
        :shader("3d_skew_holo")
        :particles("sparkle", { colors = { "gold", "white" } })
        :outline("gold", 2)
        :build()

    SpecialItem.update(dt)
    item:destroy()

Dependencies:
    - animation_system, registry (C++ bindings)
    - core.shader_builder, core.particles
    - monobehavior.behavior_script_v2 (Node)
]]

-- Singleton guard
if _G.__SPECIAL_ITEM__ then
    return _G.__SPECIAL_ITEM__
end

local SpecialItem = {}

--------------------------------------------------------------------------------
-- DEPENDENCIES
--------------------------------------------------------------------------------

local registry = _G.registry
local animation_system = _G.animation_system
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")
local Node = require("monobehavior.behavior_script_v2")
local ShaderBuilder = require("core.shader_builder")
local Particles = require("core.particles")

--------------------------------------------------------------------------------
-- RENDER GROUP CONSTANTS
--------------------------------------------------------------------------------
-- Use render_groups system for reliable shader rendering (matches RenderGroupsTest pattern)

local RENDER_GROUP_NAME = "special_items"
local renderGroupInitialized = false

local unpack = table.unpack or unpack

--------------------------------------------------------------------------------
-- PARTICLE PRESETS
--------------------------------------------------------------------------------
-- Predefined particle recipes for common effects

local PARTICLE_PRESETS = {
    bubble = {
        shape = "circle",
        sizeMin = 3,
        sizeMax = 8,
        velocityMin = 20,
        velocityMax = 60,
        lifespanMin = 0.8,
        lifespanMax = 1.5,
        gravity = -30,  -- float up
        fade = true,
        pulse = { amount = 0.3, minSpeed = 2, maxSpeed = 5 },
        count = 3,
        interval = 0.15,
    },
    sparkle = {
        shape = "circle",
        sizeMin = 2,
        sizeMax = 5,
        velocityMin = 10,
        velocityMax = 40,
        lifespanMin = 0.3,
        lifespanMax = 0.6,
        fade = true,
        shrink = true,
        count = 2,
        interval = 0.1,
    },
    magical = {
        shape = "circle",
        sizeMin = 2,
        sizeMax = 6,
        velocityMin = 15,
        velocityMax = 50,
        lifespanMin = 0.5,
        lifespanMax = 1.0,
        gravity = -20,
        fade = true,
        wiggle = 3,
        wiggleFreq = 8,
        count = 4,
        interval = 0.12,
    },
    rainbow = {
        shape = "circle",
        sizeMin = 3,
        sizeMax = 7,
        velocityMin = 25,
        velocityMax = 55,
        lifespanMin = 0.6,
        lifespanMax = 1.2,
        gravity = -25,
        fade = true,
        pulse = { amount = 0.4, minSpeed = 3, maxSpeed = 6 },
        flash = true,  -- cycles through colors
        count = 5,
        interval = 0.1,
    },
    fire = {
        shape = "circle",
        sizeMin = 4,
        sizeMax = 10,
        velocityMin = 40,
        velocityMax = 80,
        lifespanMin = 0.4,
        lifespanMax = 0.8,
        gravity = -80,
        fade = true,
        shrink = true,
        count = 4,
        interval = 0.08,
        defaultColors = { "orange", "red", "yellow" },
    },
}

-- Default colors per preset (if user doesn't specify)
local DEFAULT_COLORS = {
    bubble = { "cyan", "magenta", "yellow", "lime" },
    sparkle = { "white", "gold", "cyan" },
    magical = { "purple", "blue", "pink", "cyan" },
    rainbow = { "red", "orange", "yellow", "green", "cyan", "blue", "purple" },
    fire = { "orange", "red", "yellow" },
}

--------------------------------------------------------------------------------
-- OUTLINE PRESETS
--------------------------------------------------------------------------------

local function toVec4Color(r, g, b, a)
    return Vector4 { x = r / 255, y = g / 255, z = b / 255, w = (a or 255) / 255 }
end

local OUTLINE_COLORS = {
    gold = toVec4Color(255, 215, 0, 255),
    silver = toVec4Color(192, 192, 192, 255),
    white = toVec4Color(255, 255, 255, 255),
    black = toVec4Color(0, 0, 0, 255),
    red = toVec4Color(255, 50, 50, 255),
    blue = toVec4Color(50, 100, 255, 255),
    green = toVec4Color(50, 255, 100, 255),
    purple = toVec4Color(180, 50, 255, 255),
    cyan = toVec4Color(50, 255, 255, 255),
}

--------------------------------------------------------------------------------
-- INTERNAL STATE
--------------------------------------------------------------------------------

-- Track all active special items for update loop
local activeItems = {}

--------------------------------------------------------------------------------
-- SPECIAL ITEM SCRIPT
--------------------------------------------------------------------------------

local SpecialItemScript = Node:extend()

function SpecialItemScript:init()
    self.particleStream = nil
    self.config = self.config or {}
end

function SpecialItemScript:update(dt)
    if not entity_cache.valid(self:handle()) then
        self:cleanup()
        return
    end
    
    if self.particleStream and self.particleStream:isActive() then
        local transform = component_cache.get(self:handle(), Transform)
        if transform then
            self.particleStream:setSpawnRect(
                transform.actualX,
                transform.actualY,
                transform.actualW,
                transform.actualH
            )
        end
        self.particleStream:update(dt)
    end
end

function SpecialItemScript:cleanup()
    if self.particleStream then
        self.particleStream:stop()
        self.particleStream = nil
    end
    if render_groups and self:handle() then
        render_groups.removeFromAll(self:handle())
    end
    activeItems[self:handle()] = nil
end

function SpecialItemScript:destroy()
    self:cleanup()
    if entity_cache.valid(self:handle()) then
        registry:destroy(self:handle())
    end
end

--------------------------------------------------------------------------------
-- PUBLIC API - STATIC CREATE
--------------------------------------------------------------------------------

--- Create a special item with all effects configured
--- @param opts table Configuration options
--- @return table SpecialItemScript instance
function SpecialItem.create(opts)
    opts = opts or {}
    
    -- Extract options
    local sprite = opts.sprite
    local x = opts.x or (opts.position and (opts.position.x or opts.position[1])) or 0
    local y = opts.y or (opts.position and (opts.position.y or opts.position[2])) or 0
    local w = (opts.size and (opts.size[1] or opts.size.w)) or 64
    local h = (opts.size and (opts.size[2] or opts.size.h)) or 64
    local shader = opts.shader or "3d_skew_holo"
    local shaderUniforms = opts.shaderUniforms or {}
    local particleConfig = opts.particles or { enabled = true, preset = "bubble" }
    local outlineConfig = opts.outline or { enabled = true, color = "gold", thickness = 2, type = 8 }
    local shadow = opts.shadow or false
    
    -- Create base entity
    local entity
    if sprite and animation_system then
        entity = animation_system.createAnimatedObjectWithTransform(
            sprite,
            true,  -- fromSprite
            x,
            y,
            nil,   -- shader pass (we'll apply via ShaderBuilder)
            shadow
        )
        if opts.size then
            animation_system.resizeAnimationObjectsInEntityToFit(entity, w, h)
        end
    else
        entity = registry:create()
        local transform = registry:emplace(entity, Transform)
        transform.actualX = x
        transform.actualY = y
        transform.actualW = w
        transform.actualH = h
    end
    
    -- Apply main shader
    local builder = ShaderBuilder.for_entity(entity):add(shader, shaderUniforms)
    
    if outlineConfig.enabled then
        local outlineColor = outlineConfig.color
        if type(outlineColor) == "string" then
            outlineColor = OUTLINE_COLORS[outlineColor] or OUTLINE_COLORS.gold
        elseif type(outlineColor) == "table" then
            if outlineColor.x ~= nil then
            elseif #outlineColor >= 3 then
                outlineColor = toVec4Color(outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4])
            elseif outlineColor.r then
                outlineColor = toVec4Color(outlineColor.r, outlineColor.g, outlineColor.b, outlineColor.a)
            else
                if _G.log_warn then
                    log_warn("SpecialItem: invalid outline color format, using gold")
                end
                outlineColor = OUTLINE_COLORS.gold
            end
        else
            outlineColor = OUTLINE_COLORS.gold
        end
        
        builder:add("efficient_pixel_outline", {
            outlineColor = outlineColor,
            outlineType = outlineConfig.type or 8,
            thickness = outlineConfig.thickness or 2,
        })
    end
    
    builder:apply()
    
    if not renderGroupInitialized and render_groups then
        render_groups.create(RENDER_GROUP_NAME, {})
        renderGroupInitialized = true
    end
    
    if render_groups then
        local shaderList = { shader }
        if outlineConfig.enabled then
            table.insert(shaderList, "efficient_pixel_outline")
        end
        render_groups.add(RENDER_GROUP_NAME, entity, shaderList)
    end
    
    local script = SpecialItemScript {
        config = {
            particles = particleConfig,
            outline = outlineConfig,
            shader = shader,
        }
    }
    script:attach_ecs { create_new = false, existing_entity = entity }
    activeItems[script:handle()] = script
    
    if particleConfig.enabled ~= false then
        local presetName = particleConfig.preset or "bubble"
        local preset = PARTICLE_PRESETS[presetName]
        if not preset then
            if _G.log_warn then
                log_warn("SpecialItem: unknown preset '" .. tostring(presetName) .. "', using 'bubble'")
            end
            preset = PARTICLE_PRESETS.bubble
            presetName = "bubble"
        end
        
        local colors = particleConfig.colors or DEFAULT_COLORS[presetName] or DEFAULT_COLORS.bubble
        local density = particleConfig.density or 1.0
        
        local recipe = Particles.define()
            :shape(preset.shape or "circle")
            :size(preset.sizeMin or 3, preset.sizeMax or 8)
            :velocity(preset.velocityMin or 20, preset.velocityMax or 60)
            :lifespan(preset.lifespanMin or 0.5, preset.lifespanMax or 1.0)
        
        if preset.gravity then recipe:gravity(preset.gravity) end
        if preset.fade then recipe:fade() end
        if preset.shrink then recipe:shrink() end
        if preset.wiggle then recipe:wiggle(preset.wiggle, preset.wiggleFreq) end
        if preset.pulse then recipe:pulse(preset.pulse.amount, preset.pulse.minSpeed, preset.pulse.maxSpeed) end
        
        if colors and #colors >= 2 then
            recipe:color(colors[1], colors[2])
            if preset.flash and #colors > 2 then
                recipe:flash(unpack(colors))
            end
        elseif colors and #colors == 1 then
            recipe:color(colors[1])
        end
        
        local count = math.floor((preset.count or 3) * density)
        
        script.particleStream = recipe
            :burst(count)
            :inRect(x, y, w, h)
            :stream()
            :every(preset.interval or 0.1)
    end
    
    return script
end

--------------------------------------------------------------------------------
-- PUBLIC API - FLUENT BUILDER
--------------------------------------------------------------------------------

local BuilderMethods = {}
BuilderMethods.__index = BuilderMethods

--- Create a new fluent builder
--- @param sprite string? Sprite/animation ID
--- @return table Builder instance
function SpecialItem.new(sprite)
    local self = setmetatable({}, BuilderMethods)
    self._opts = {
        sprite = sprite,
        position = { x = 0, y = 0 },
        size = { 64, 64 },
        shader = "3d_skew_holo",
        shaderUniforms = {},
        particles = { enabled = true, preset = "bubble" },
        outline = { enabled = true, color = "gold", thickness = 2, type = 8 },
    }
    return self
end

function BuilderMethods:sprite(s) self._opts.sprite = s; return self end
function BuilderMethods:at(x, y) self._opts.position = { x = x, y = y }; return self end
function BuilderMethods:size(w, h) self._opts.size = { w, h }; return self end
function BuilderMethods:shadow(v) self._opts.shadow = v ~= false; return self end

--- Set main shader effect
--- @param shaderName string Shader name (e.g., "3d_skew_holo", "3d_skew_prismatic")
--- @param uniforms table? Optional uniform overrides
--- @return self
function BuilderMethods:shader(shaderName, uniforms)
    self._opts.shader = shaderName
    if uniforms then
        self._opts.shaderUniforms = uniforms
    end
    return self
end

--- Configure particle effects
--- @param preset string|boolean Preset name or false to disable
--- @param config table? Additional config { colors, density }
--- @return self
function BuilderMethods:particles(preset, config)
    if preset == false then
        self._opts.particles = { enabled = false }
    else
        self._opts.particles = {
            enabled = true,
            preset = preset or "bubble",
            colors = config and config.colors,
            density = config and config.density,
        }
    end
    return self
end

--- Configure outline effect
--- @param color string|table|boolean Color name, RGBA table, or false to disable
--- @param thickness number? Outline thickness (default: 2)
--- @param outlineType number? 4 or 8 directions (default: 8)
--- @return self
function BuilderMethods:outline(color, thickness, outlineType)
    if color == false then
        self._opts.outline = { enabled = false }
    else
        self._opts.outline = {
            enabled = true,
            color = color or "gold",
            thickness = thickness or 2,
            type = outlineType or 8,
        }
    end
    return self
end

--- Disable all effects (just the base sprite)
--- @return self
function BuilderMethods:plain()
    self._opts.shader = nil
    self._opts.particles = { enabled = false }
    self._opts.outline = { enabled = false }
    return self
end

--- Build the special item
--- @return table SpecialItemScript instance
function BuilderMethods:build()
    return SpecialItem.create(self._opts)
end

--------------------------------------------------------------------------------
-- PUBLIC API - UPDATE & UTILITIES
--------------------------------------------------------------------------------

--- Update all active special items (call in game loop)
--- @param dt number Delta time
function SpecialItem.update(dt)
    for eid, item in pairs(activeItems) do
        if entity_cache.valid(eid) then
            item:update(dt)
        else
            activeItems[eid] = nil
        end
    end
end

--- Draw all special items via render_groups (call in game loop after update)
--- @param z number? Optional z-index for draw order (default: 1000)
function SpecialItem.draw(z)
    if not renderGroupInitialized then return end
    if not command_buffer or not layers or not layers.sprites then return end
    
    command_buffer.queueDrawRenderGroup(layers.sprites, function(cmd)
        cmd.registry = registry
        cmd.groupName = RENDER_GROUP_NAME
        cmd.autoOptimize = true
    end, z or 1000, layer.DrawCommandSpace.World)
end

--- Get particle preset names
--- @return table Array of preset names
function SpecialItem.getParticlePresets()
    local names = {}
    for name, _ in pairs(PARTICLE_PRESETS) do
        table.insert(names, name)
    end
    return names
end

--- Get outline color names
--- @return table Array of color names
function SpecialItem.getOutlineColors()
    local names = {}
    for name, _ in pairs(OUTLINE_COLORS) do
        table.insert(names, name)
    end
    return names
end

--- Register a custom particle preset
--- @param name string Preset name
--- @param config table Preset configuration
--- @param defaultColors table? Default colors for this preset
function SpecialItem.registerParticlePreset(name, config, defaultColors)
    PARTICLE_PRESETS[name] = config
    if defaultColors then
        DEFAULT_COLORS[name] = defaultColors
    end
end

--- @param name string Color name
--- @param r number Red (0-255)
--- @param g number Green (0-255)
--- @param b number Blue (0-255)
--- @param a number? Alpha (0-255, default 255)
function SpecialItem.registerOutlineColor(name, r, g, b, a)
    OUTLINE_COLORS[name] = toVec4Color(r, g, b, a)
end

--- Get count of active special items
--- @return number
function SpecialItem.getActiveCount()
    local count = 0
    for _ in pairs(activeItems) do
        count = count + 1
    end
    return count
end

_G.__SPECIAL_ITEM__ = SpecialItem
return SpecialItem
