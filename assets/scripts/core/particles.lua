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
