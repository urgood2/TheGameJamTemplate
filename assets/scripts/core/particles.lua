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
