--[[
================================================================================
ENTITY BUILDER - Fluent API for Entity Creation
================================================================================
Reduces 15-30 line entity creation patterns to 3-5 lines.

DESIGN PRINCIPLE: Non-rigid API
- All methods return raw objects (entity IDs, components), not opaque wrappers
- Escape hatches available at every step (getEntity, getTransform, getScript)
- Mix builder + manual operations freely
- Builder never prevents access to underlying APIs

Usage (static):
    local entity, script = EntityBuilder.create({
        sprite = "kobold",
        position = { x = 100, y = 200 },
        size = { 64, 64 },
        data = { health = 100 }
    })
    -- entity is raw EnTT ID, script is raw table
    -- Continue with manual operations:
    local transform = component_cache.get(entity, Transform)
    transform.actualR = math.rad(45)

Usage (fluent):
    local builder = EntityBuilder.new("kobold")
        :at(100, 200)
        :size(64, 64)
        :withData({ health = 100 })

    -- Escape hatch: get entity before finishing
    local eid = builder:getEntity()

    -- Continue building
    builder:withHover("Title", "Body")
        :build()

Dependencies:
    - animation_system (C++ binding)
    - registry (global ECS registry)
    - entity_cache, component_cache
    - monobehavior.behavior_script_v2 (Node)
]]

-- Singleton guard
if _G.__ENTITY_BUILDER__ then
    return _G.__ENTITY_BUILDER__
end

local EntityBuilder = {}

-- Dependencies
local animation_system = _G.animation_system
local registry = _G.registry
local entity_cache = require("core.entity_cache")
local component_cache = require("core.component_cache")
local Node = require("monobehavior.behavior_script_v2")

---@class EntityBuilderOpts
---@field sprite string? Animation/sprite ID
---@field fromSprite boolean? True=animation, false=sprite identifier (default: true)
---@field x number? X position (alternative to position)
---@field y number? Y position (alternative to position)
---@field position {x: number, y: number}|{[1]: number, [2]: number}? Position table
---@field size {[1]: number, [2]: number}|{w: number, h: number}? Size (default: 32x32)
---@field shadow boolean? Enable shadow (default: false)
---@field data table? Script table data (assigned before attach_ecs)
---@field interactive EntityBuilderInteractive? Interaction configuration
---@field state string? State tag to add (e.g., PLANNING_STATE)
---@field shaders (string|{[1]: string, [2]: table})[]? Shader names or {name, uniforms} pairs

---@class EntityBuilderInteractive
---@field hover {title: string, body: string, id: string?}? Tooltip configuration
---@field click fun(registry: any, entity: number)? Click callback
---@field drag boolean|fun()? Enable drag (true) or custom drag handler
---@field stopDrag fun()? Stop drag callback
---@field collision boolean? Enable collision detection

-- Optional dependencies (may not exist in all contexts)
local showSimpleTooltipAbove = _G.showSimpleTooltipAbove
local hideSimpleTooltip = _G.hideSimpleTooltip
local add_state_tag = _G.add_state_tag

--------------------------------------------------------------------------------
-- DEFAULTS
--------------------------------------------------------------------------------

EntityBuilder.DEFAULTS = {
    size = { 32, 32 },
    shadow = false,
    fromSprite = true,  -- true = animation, false = sprite identifier
}

--------------------------------------------------------------------------------
-- PRIVATE HELPERS
--------------------------------------------------------------------------------

local function setup_tooltip(entity, nodeComp, hover)
    if not hover then return end
    if not showSimpleTooltipAbove or not hideSimpleTooltip then
        log_warn("EntityBuilder: tooltip functions not available")
        return
    end

    local tooltipId = hover.id or ("tooltip_" .. tostring(entity))
    local title = hover.title or ""
    local body = hover.body or ""

    nodeComp.methods.onHover = function()
        showSimpleTooltipAbove(tooltipId, title, body, entity)
    end
    nodeComp.methods.onStopHover = function()
        hideSimpleTooltip(tooltipId)
    end
end

local function setup_interactions(entity, nodeComp, interactive)
    if not interactive then return end

    local state = nodeComp.state

    -- Enable interaction modes based on provided callbacks
    if interactive.hover then
        state.hoverEnabled = true
        setup_tooltip(entity, nodeComp, interactive.hover)
    end

    if interactive.click then
        state.clickEnabled = true
        nodeComp.methods.onClick = interactive.click
    end

    if interactive.drag then
        state.dragEnabled = true
        if type(interactive.drag) == "function" then
            nodeComp.methods.onDrag = interactive.drag
        end
    end

    if interactive.stopDrag then
        nodeComp.methods.onStopDrag = interactive.stopDrag
    end

    if interactive.collision ~= nil then
        state.collisionEnabled = interactive.collision
    end
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Create an entity with all common setup in one call.
--- @param opts EntityBuilderOpts Configuration options
--- @return number entity The created entity ID
--- @return table|nil script The script table (if data provided)
function EntityBuilder.create(opts)
    opts = opts or {}

    -- Extract options with defaults
    local sprite = opts.sprite
    local fromSprite = opts.fromSprite ~= false  -- default true
    local x = opts.x or (opts.position and opts.position.x) or (opts.position and opts.position[1]) or 0
    local y = opts.y or (opts.position and opts.position.y) or (opts.position and opts.position[2]) or 0
    local w = (opts.size and opts.size[1]) or (opts.size and opts.size.w) or EntityBuilder.DEFAULTS.size[1]
    local h = (opts.size and opts.size[2]) or (opts.size and opts.size.h) or EntityBuilder.DEFAULTS.size[2]
    local shadow = (opts.shadow ~= nil) and opts.shadow or EntityBuilder.DEFAULTS.shadow
    local data = opts.data
    local interactive = opts.interactive
    local state = opts.state
    local shaders = opts.shaders

    -- Create entity
    local entity
    if sprite and animation_system then
        entity = animation_system.createAnimatedObjectWithTransform(
            sprite,
            fromSprite,
            x,
            y,
            nil,  -- shader pass
            shadow
        )

        -- Resize if size provided
        if opts.size then
            animation_system.resizeAnimationObjectsInEntityToFit(entity, w, h)
        end
    else
        -- Fallback: create raw entity
        entity = registry:create()
        local transform = registry:emplace(entity, Transform)
        transform.actualX = x
        transform.actualY = y
        transform.actualW = w
        transform.actualH = h
    end

    -- Initialize script table if data provided
    local script = nil
    if data then
        local EntityType = Node:extend()
        script = EntityType {}

        -- CRITICAL: Assign data BEFORE attach_ecs per CLAUDE.md
        for k, v in pairs(data) do
            script[k] = v
        end

        script:attach_ecs { create_new = false, existing_entity = entity }
    end

    -- Set up interactions
    if interactive then
        local nodeComp = registry:get(entity, GameObject)
        if nodeComp then
            setup_interactions(entity, nodeComp, interactive)
        else
            log_warn("EntityBuilder: GameObject component not found on entity, cannot set up interactions")
        end
    end

    -- Add state tag (must also remove default per gameplay.lua pattern)
    if state and add_state_tag then
        add_state_tag(entity, state)
        if remove_default_state_tag then
            remove_default_state_tag(entity)
        end
    end

    -- Apply shaders
    if shaders then
        local ok, ShaderBuilder = pcall(require, "core.shader_builder")
        if ok then
            local builder = ShaderBuilder.for_entity(entity)
            for _, shader in ipairs(shaders) do
                if type(shader) == "string" then
                    builder:add(shader)
                elseif type(shader) == "table" then
                    builder:add(shader[1], shader[2])
                end
            end
            builder:apply()
        else
            log_warn("EntityBuilder: ShaderBuilder not available")
        end
    end

    return entity, script
end

--- Create an entity with only position and size (minimal version)
--- @param sprite string Sprite/animation ID
--- @param x number X position
--- @param y number Y position
--- @param w number? Width (default 32)
--- @param h number? Height (default 32)
--- @return number entity The created entity ID
function EntityBuilder.simple(sprite, x, y, w, h)
    return EntityBuilder.create({
        sprite = sprite,
        x = x,
        y = y,
        size = { w or 32, h or 32 }
    })
end

--- Create an interactive entity with hover tooltip
--- @param opts table Options including sprite, position, size, hover
--- @return number entity
--- @return table script
function EntityBuilder.interactive(opts)
    -- Ensure interactive is set
    opts.interactive = opts.interactive or {}
    if opts.hover then
        opts.interactive.hover = opts.hover
        opts.hover = nil
    end
    if opts.click then
        opts.interactive.click = opts.click
        opts.click = nil
    end
    return EntityBuilder.create(opts)
end

--------------------------------------------------------------------------------
-- FLUENT BUILDER INSTANCE (Alternative API)
--------------------------------------------------------------------------------
-- For users who prefer method chaining over options tables.
-- Provides escape hatches at every step.

local BuilderInstance = {}
BuilderInstance.__index = BuilderInstance

--- Create a new fluent builder
--- @param sprite string? Sprite/animation ID (optional, can set later)
--- @return table Builder instance
function EntityBuilder.new(sprite)
    local self = setmetatable({}, BuilderInstance)
    self._opts = {
        sprite = sprite,
        size = { 32, 32 },
        position = { 0, 0 },
    }
    self._entity = nil  -- created lazily or on build()
    self._script = nil
    return self
end

-- Chainable setters
function BuilderInstance:sprite(s) self._opts.sprite = s; return self end
function BuilderInstance:at(x, y) self._opts.position = { x, y }; return self end
function BuilderInstance:size(w, h) self._opts.size = { w, h }; return self end
function BuilderInstance:shadow(v) self._opts.shadow = v ~= false; return self end
function BuilderInstance:withData(data) self._opts.data = data; return self end
function BuilderInstance:withState(state) self._opts.state = state; return self end
function BuilderInstance:withShaders(shaders) self._opts.shaders = shaders; return self end

function BuilderInstance:withHover(title, body, id)
    self._opts.interactive = self._opts.interactive or {}
    self._opts.interactive.hover = { title = title, body = body, id = id }
    return self
end

function BuilderInstance:onClick(fn)
    self._opts.interactive = self._opts.interactive or {}
    self._opts.interactive.click = fn
    return self
end

function BuilderInstance:onDrag(fn)
    self._opts.interactive = self._opts.interactive or {}
    self._opts.interactive.drag = fn or true
    return self
end

function BuilderInstance:withCollision(enabled)
    self._opts.interactive = self._opts.interactive or {}
    self._opts.interactive.collision = enabled ~= false
    return self
end

--------------------------------------------------------------------------------
-- ESCAPE HATCHES - Access raw objects at any point
--------------------------------------------------------------------------------

--- Get the entity ID (creates entity if not yet created)
--- ESCAPE HATCH: Use this to access the raw entity for manual operations
--- @return number entity Raw EnTT entity ID
function BuilderInstance:getEntity()
    if not self._entity then
        self._entity, self._script = EntityBuilder.create(self._opts)
    end
    return self._entity
end

--- Get the Transform component
--- ESCAPE HATCH: Direct access to transform for manual modifications
--- @return userdata|nil Transform component
function BuilderInstance:getTransform()
    local eid = self:getEntity()
    return component_cache.get(eid, Transform)
end

--- Get the GameObject component
--- ESCAPE HATCH: Direct access to GameObject for custom callbacks
--- @return userdata|nil GameObject component
function BuilderInstance:getGameObject()
    local eid = self:getEntity()
    return registry:get(eid, GameObject)
end

--- Get the script table
--- ESCAPE HATCH: Direct access to script for custom data
--- @return table|nil Script table
function BuilderInstance:getScript()
    self:getEntity()  -- ensure created
    return self._script
end

--------------------------------------------------------------------------------
-- BUILD - Finalize and return raw objects
--------------------------------------------------------------------------------

--- Build the entity and return raw objects
--- @return number entity Raw EnTT entity ID
--- @return table|nil script Raw script table
function BuilderInstance:build()
    local eid = self:getEntity()
    return eid, self._script
end

_G.__ENTITY_BUILDER__ = EntityBuilder
return EntityBuilder
