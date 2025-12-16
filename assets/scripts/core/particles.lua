-- assets/scripts/core/particles.lua
--[[
================================================================================
PARTICLE BUILDER - Fluent API for Particle Effects
================================================================================
Reduces verbose particle.CreateParticle() calls to composable recipes.

Usage:
    local Particles = require("core.particles")

    local spark = Particles.define()
        :shape("circle")
        :size(4, 8)
        :color("orange", "red")
        :fade()
        :lifespan(0.3)

    spark:burst(10):at(x, y)

Design:
    - Recipe: Immutable particle definition (what it looks like, how it behaves)
    - Emission: Spawn configuration (where, when, how many)
    - Handle: Controller for streams (stop, pause, resume)
]]

-- Singleton guard
if _G.__PARTICLES_BUILDER__ then
    return _G.__PARTICLES_BUILDER__
end

local Particles = {}

--------------------------------------------------------------------------------
-- RECIPE
--------------------------------------------------------------------------------

local RecipeMethods = {}
RecipeMethods.__index = RecipeMethods

--- Set particle shape
--- @param shapeType string "circle"|"rect"|"line"|"sprite"
--- @param spriteId string? Sprite ID if shapeType is "sprite"
--- @return self
function RecipeMethods:shape(shapeType, spriteId)
    self._config.shape = shapeType
    if spriteId then
        self._config.spriteId = spriteId
    end
    return self
end

--- Set particle size (single value or random range)
--- @param minOrFixed number Min size, or fixed size if max not provided
--- @param max number? Max size for random range
--- @return self
function RecipeMethods:size(minOrFixed, max)
    self._config.sizeMin = minOrFixed
    self._config.sizeMax = max or minOrFixed
    return self
end

--- Set particle color (start/end for interpolation)
--- @param startColor string|table Color name or {r,g,b,a}
--- @param endColor string|table? End color (defaults to startColor)
--- @return self
function RecipeMethods:color(startColor, endColor)
    self._config.startColor = startColor
    self._config.endColor = endColor or startColor
    return self
end

--- Set particle lifespan (single value or random range)
--- @param minOrFixed number Min lifespan in seconds, or fixed if max not provided
--- @param max number? Max lifespan for random range
--- @return self
function RecipeMethods:lifespan(minOrFixed, max)
    self._config.lifespanMin = minOrFixed
    self._config.lifespanMax = max or minOrFixed
    return self
end

--- Set particle velocity (speed in pixels/second)
--- @param minOrFixed number Min velocity, or fixed if max not provided
--- @param max number? Max velocity for random range
--- @return self
function RecipeMethods:velocity(minOrFixed, max)
    self._config.velocityMin = minOrFixed
    self._config.velocityMax = max or minOrFixed
    return self
end

--- Set gravity strength (positive = down)
--- @param strength number Gravity in pixels/second^2
--- @return self
function RecipeMethods:gravity(strength)
    self._config.gravity = strength
    return self
end

--- Set drag factor (velocity multiplier per frame)
--- @param factor number Drag factor (0.95 = 5% slowdown per frame)
--- @return self
function RecipeMethods:drag(factor)
    self._config.drag = factor
    return self
end

--- Enable alpha fade (1 -> 0 over lifetime)
--- @return self
function RecipeMethods:fade()
    self._config.fade = true
    return self
end

--- Enable fade in then out (0 -> 1 -> 0)
--- @param fadeInPct number Percentage of lifetime for fade in (0-1)
--- @return self
function RecipeMethods:fadeIn(fadeInPct)
    self._config.fadeInPct = fadeInPct
    return self
end

--- Enable scale shrink (1 -> 0 over lifetime)
--- @return self
function RecipeMethods:shrink()
    self._config.shrink = true
    return self
end

--- Set scale interpolation
--- @param startScale number Starting scale
--- @param endScale number Ending scale
--- @return self
function RecipeMethods:grow(startScale, endScale)
    self._config.scaleStart = startScale
    self._config.scaleEnd = endScale
    return self
end

--- Set rotation speed (degrees/second)
--- @param minOrFixed number Min spin speed, or fixed
--- @param max number? Max spin for random range
--- @return self
function RecipeMethods:spin(minOrFixed, max)
    self._config.spinMin = minOrFixed
    self._config.spinMax = max or minOrFixed
    return self
end

--- Set lateral wiggle amount
--- @param amount number Wiggle in pixels
--- @return self
function RecipeMethods:wiggle(amount)
    self._config.wiggle = amount
    return self
end

--- Enable velocity-based stretching
--- @return self
function RecipeMethods:stretch()
    self._config.stretch = true
    return self
end

--- Enable bouncing with restitution
--- @param restitution number Bounce factor (0-1)
--- @return self
function RecipeMethods:bounce(restitution)
    self._config.bounceRestitution = restitution
    return self
end

--- Enable homing toward target
--- @param strength number Homing strength (0-1)
--- @return self
function RecipeMethods:homing(strength)
    self._config.homingStrength = strength
    return self
end

--- Spawn trail particles behind this particle
--- @param recipe Recipe Trail particle recipe
--- @param rate number Spawn rate in seconds
--- @return self
function RecipeMethods:trail(recipe, rate)
    self._config.trailRecipe = recipe
    self._config.trailRate = rate
    return self
end

--- Cycle through colors
--- @param ... string|table Colors to flash
--- @return self
function RecipeMethods:flash(...)
    self._config.flashColors = {...}
    return self
end

--- Set spawn callback
--- @param fn function(particle, entity)
--- @return self
function RecipeMethods:onSpawn(fn)
    self._config.onSpawn = fn
    return self
end

--- Set update callback (called every frame)
--- @param fn function(particle, dt, entity)
--- @return self
function RecipeMethods:onUpdate(fn)
    self._config.onUpdate = fn
    return self
end

--- Set death callback
--- @param fn function(particle, entity)
--- @return self
function RecipeMethods:onDeath(fn)
    self._config.onDeath = fn
    return self
end

--- Set particle draw order
--- @param order number Z-index for draw order
--- @return self
function RecipeMethods:z(order)
    self._config.z = order
    return self
end

--- Set render space
--- @param spaceName string "world" or "screen"
--- @return self
function RecipeMethods:space(spaceName)
    self._config.space = spaceName
    return self
end

--- Set shaders for particle (enables entity-based rendering)
--- @param shaderList table List of shader names
--- @return self
function RecipeMethods:shaders(shaderList)
    self._config.shaders = shaderList
    return self
end

--- Set shader uniforms
--- @param uniforms table Uniform name -> value mapping
--- @return self
function RecipeMethods:shaderUniforms(uniforms)
    self._config.shaderUniforms = uniforms
    return self
end

--------------------------------------------------------------------------------
-- EMISSION
--------------------------------------------------------------------------------

local EmissionMethods = {}
EmissionMethods.__index = EmissionMethods

--- Set spawn position and trigger burst
--- @param x number X position
--- @param y number Y position
--- @return self
function EmissionMethods:at(x, y)
    self._position = { x = x, y = y }
    self:_spawn()
    return self
end

--- Internal: Spawn particles
function EmissionMethods:_spawn()
    local particleModule = self._recipe._particleModule or _G.particle
    if not particleModule then
        log_warn("Particles: particle module not available")
        return
    end

    for i = 1, self._count do
        self:_spawnSingle(particleModule, i, self._count)
    end
end

--- Internal: Spawn a single particle
function EmissionMethods:_spawnSingle(particleModule, index, total)
    local config = self._recipe._config
    local pos = self._position

    -- Resolve random values
    local size = self:_randomRange(config.sizeMin or 6, config.sizeMax or 6)
    local lifespan = self:_randomRange(config.lifespanMin or 1, config.lifespanMax or 1)
    local velocity = self:_randomRange(config.velocityMin or 0, config.velocityMax or 0)

    -- Build angle (random direction by default)
    local angle = math.random() * math.pi * 2
    local vx = math.cos(angle) * velocity
    local vy = math.sin(angle) * velocity

    -- Map shape to C++ renderType
    local renderTypeMap = {
        circle = particleModule.ParticleRenderType and particleModule.ParticleRenderType.CIRCLE_FILLED or 4,
        rect = particleModule.ParticleRenderType and particleModule.ParticleRenderType.RECTANGLE_FILLED or 2,
        line = particleModule.ParticleRenderType and particleModule.ParticleRenderType.LINE_FACING or 8,
        sprite = particleModule.ParticleRenderType and particleModule.ParticleRenderType.TEXTURE or 0,
    }

    local opts = {
        renderType = renderTypeMap[config.shape] or renderTypeMap.circle,
        velocity = { x = vx, y = vy },
        lifespan = lifespan,
        gravity = config.gravity,
        startColor = config.startColor,
        endColor = config.endColor,
        rotationSpeed = config.spinMin and self:_randomRange(config.spinMin, config.spinMax),
        autoAspect = config.stretch,
        z = config.z,
        space = config.space,
    }

    local location = { x = pos.x, y = pos.y }
    local sizeVec = { x = size, y = size }

    particleModule.CreateParticle(location, sizeVec, opts, nil, nil)
end

--- Internal: Get random value in range
function EmissionMethods:_randomRange(min, max)
    if min == max then return min end
    return min + math.random() * (max - min)
end

--- Create an emission for burst spawning
--- @param count number Number of particles to spawn
--- @return Emission
function RecipeMethods:burst(count)
    local emission = setmetatable({}, EmissionMethods)
    emission._recipe = self
    emission._count = count
    emission._mode = "burst"
    return emission
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Create a new particle recipe
--- @return Recipe
function Particles.define()
    local recipe = setmetatable({}, RecipeMethods)
    recipe._config = {
        shape = "circle",  -- default
    }
    return recipe
end

_G.__PARTICLES_BUILDER__ = Particles
return Particles
