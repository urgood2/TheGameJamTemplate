--[[
================================================================================
PHYSICS BUILDER - Fluent API for Physics Body Setup
================================================================================
Reduces 10-15 line physics setup patterns to 3-5 lines.

DESIGN PRINCIPLE: Non-rigid API
- Escape hatches: getEntity(), getWorld(), getConfig()
- Returns raw objects, not opaque wrappers
- Mix builder + manual operations freely

Usage:
    PhysicsBuilder.for_entity(entity)
        :circle()
        :tag("projectile")
        :bullet()
        :friction(0)
        :collideWith({ "enemy", "WORLD" })
        :apply()

Escape Hatches:
    local builder = PhysicsBuilder.for_entity(entity):circle():tag("proj")

    -- Get raw world for manual operations
    local world = builder:getWorld()
    physics.SetLinearDamping(world, builder:getEntity(), 0.5)

    -- Then continue with builder
    builder:apply()

Dependencies:
    - physics (C++ binding)
    - PhysicsManager (Lua module)
    - registry (global ECS registry)
]]

-- Singleton guard
if _G.__PHYSICS_BUILDER__ then
    return _G.__PHYSICS_BUILDER__
end

local PhysicsBuilder = {}

-- Dependencies
local registry = _G.registry
local physics = _G.physics
local physics_manager_instance = _G.physics_manager_instance
local entity_cache = require("core.entity_cache")

-- Lazy-load PhysicsManager to avoid circular dependency
local PhysicsManager

--------------------------------------------------------------------------------
-- DEFAULTS
--------------------------------------------------------------------------------

PhysicsBuilder.DEFAULTS = {
    shape = "circle",
    tag = "default",
    sensor = false,
    density = 1.0,
    friction = 0.3,
    restitution = 0.0,
    bullet = false,
    fixedRotation = false,
    syncMode = "physics",  -- "physics" or "transform"
    worldName = "world",
}

--------------------------------------------------------------------------------
-- BUILDER INSTANCE
--------------------------------------------------------------------------------

local BuilderMethods = {}
BuilderMethods.__index = BuilderMethods

function BuilderMethods:shape(shape)
    self._shape = shape
    return self
end

function BuilderMethods:circle()
    self._shape = "circle"
    return self
end

function BuilderMethods:rectangle()
    self._shape = "rectangle"
    return self
end

function BuilderMethods:tag(t)
    self._tag = t
    return self
end

function BuilderMethods:sensor(v)
    if v == nil then v = true end  -- :sensor() with no arg means enable
    self._sensor = v
    return self
end

function BuilderMethods:density(v)
    self._density = v
    return self
end

function BuilderMethods:friction(v)
    self._friction = v
    return self
end

function BuilderMethods:restitution(v)
    self._restitution = v
    return self
end

function BuilderMethods:bullet(v)
    self._bullet = v ~= false
    return self
end

function BuilderMethods:fixedRotation(v)
    self._fixedRotation = v ~= false
    return self
end

function BuilderMethods:syncMode(mode)
    self._syncMode = mode
    return self
end

function BuilderMethods:world(name)
    self._worldName = name
    return self
end

function BuilderMethods:collideWith(tags)
    if type(tags) == "string" then
        tags = { tags }
    end
    self._collideWith = tags
    return self
end

--------------------------------------------------------------------------------
-- ESCAPE HATCHES - Access raw objects at any point
--------------------------------------------------------------------------------

--- Get the entity ID
--- ESCAPE HATCH: Use for manual physics operations not covered by builder
--- @return number entity Raw EnTT entity ID
function BuilderMethods:getEntity()
    return self._entity
end

--- Get the physics world (lazy-loaded)
--- ESCAPE HATCH: Use for advanced physics operations
--- @return userdata|nil world The physics world object
function BuilderMethods:getWorld()
    if not PhysicsManager then
        local ok, pm = pcall(require, "core.physics_manager")
        if ok then PhysicsManager = pm end
    end
    if PhysicsManager and PhysicsManager.get_world then
        return PhysicsManager.get_world(self._worldName)
    end
    return nil
end

--- Get the current configuration (before apply)
--- ESCAPE HATCH: Inspect or modify config before applying
--- @return table config Copy of current configuration
function BuilderMethods:getConfig()
    return {
        shape = self._shape,
        tag = self._tag,
        sensor = self._sensor,
        density = self._density,
        friction = self._friction,
        restitution = self._restitution,
        bullet = self._bullet,
        fixedRotation = self._fixedRotation,
        syncMode = self._syncMode,
        worldName = self._worldName,
        collideWith = self._collideWith,
    }
end

function BuilderMethods:apply()
    -- Lazy load PhysicsManager
    if not PhysicsManager then
        local ok, pm = pcall(require, "core.physics_manager")
        if ok then
            PhysicsManager = pm
        end
    end

    -- Get physics world
    local world
    if PhysicsManager and PhysicsManager.get_world then
        world = PhysicsManager.get_world(self._worldName)
    end

    if not world then
        log_warn("PhysicsBuilder: physics world '" .. self._worldName .. "' not available")
        return false
    end

    if not physics then
        log_warn("PhysicsBuilder: physics module not available")
        return false
    end

    -- Create physics body
    local config = {
        shape = self._shape,
        tag = self._tag,
        sensor = self._sensor,
        density = self._density,
    }

    physics.create_physics_for_transform(
        registry,
        physics_manager_instance,
        self._entity,
        self._worldName,
        config
    )

    -- Set physics properties
    if self._bullet then
        physics.SetBullet(world, self._entity, true)
    end

    -- Always apply friction and restitution (defaults are set in for_entity)
    physics.SetFriction(world, self._entity, self._friction)
    physics.SetRestitution(world, self._entity, self._restitution)

    if self._fixedRotation then
        physics.SetFixedRotation(world, self._entity, true)
    end

    -- Set sync mode
    if self._syncMode and physics.PhysicsSyncMode then
        local syncModes = {
            physics = physics.PhysicsSyncMode.AuthoritativePhysics,
            transform = physics.PhysicsSyncMode.AuthoritativeTransform,
        }
        local mode = syncModes[self._syncMode]
        if mode then
            physics.set_sync_mode(registry, self._entity, mode)
        end
    end

    -- Set up collision masks
    -- Note: enable_collision_between_many is symmetric - setting up A->B also enables B->A
    if self._collideWith and #self._collideWith > 0 then
        for _, targetTag in ipairs(self._collideWith) do
            physics.enable_collision_between_many(world, self._tag, { targetTag })
            physics.update_collision_masks_for(world, self._tag, { targetTag })
        end
    end

    return true
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Create a builder for the given entity
--- @param entity number Entity ID
--- @return table Builder instance with fluent API
function PhysicsBuilder.for_entity(entity)
    if not entity_cache.valid(entity) then
        error("PhysicsBuilder.for_entity: invalid entity")
    end

    local self = setmetatable({}, BuilderMethods)

    -- Set defaults
    self._entity = entity
    self._shape = PhysicsBuilder.DEFAULTS.shape
    self._tag = PhysicsBuilder.DEFAULTS.tag
    self._sensor = PhysicsBuilder.DEFAULTS.sensor
    self._density = PhysicsBuilder.DEFAULTS.density
    self._friction = PhysicsBuilder.DEFAULTS.friction
    self._restitution = PhysicsBuilder.DEFAULTS.restitution
    self._bullet = PhysicsBuilder.DEFAULTS.bullet
    self._fixedRotation = PhysicsBuilder.DEFAULTS.fixedRotation
    self._syncMode = PhysicsBuilder.DEFAULTS.syncMode
    self._worldName = PhysicsBuilder.DEFAULTS.worldName
    self._collideWith = {}

    return self
end

--- Quick physics setup with common options
--- @param entity number Entity ID
--- @param opts table Options { shape, tag, bullet, collideWith, ... }
--- @return boolean success
function PhysicsBuilder.quick(entity, opts)
    opts = opts or {}
    local builder = PhysicsBuilder.for_entity(entity)

    if opts.shape then builder:shape(opts.shape) end
    if opts.tag then builder:tag(opts.tag) end
    if opts.sensor ~= nil then builder:sensor(opts.sensor) end
    if opts.density then builder:density(opts.density) end
    if opts.friction then builder:friction(opts.friction) end
    if opts.restitution then builder:restitution(opts.restitution) end
    if opts.bullet then builder:bullet(opts.bullet) end
    if opts.fixedRotation then builder:fixedRotation(opts.fixedRotation) end
    if opts.syncMode then builder:syncMode(opts.syncMode) end
    if opts.collideWith then builder:collideWith(opts.collideWith) end

    return builder:apply()
end

_G.__PHYSICS_BUILDER__ = PhysicsBuilder
return PhysicsBuilder
