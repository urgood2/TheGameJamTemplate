--------------------------------------------
-- Particle Helpers - Ergonomic Wrappers
--------------------------------------------
-- Provides options-table alternatives to verbose particle functions
-- while maintaining full backward compatibility with positional signatures.
--
-- Usage:
--   local particles = require("core.particle_helpers")
--   
--   -- Options table (new ergonomic API):
--   particles.burst({
--       x = 100, y = 200,
--       count = 10,
--       duration = 1.0,
--       startColor = Col(255, 0, 0),
--       endColor = Col(0, 0, 255),
--   })
--   
--   -- Positional (backward compat):
--   particles.burst(100, 200, 10, 1.0, RED, BLUE, "cubic", "world")
--------------------------------------------

if _G.__PARTICLE_HELPERS__ then
    return _G.__PARTICLE_HELPERS__
end

local particles = {}

--------------------------------------------------------
-- Type Annotations (LuaLS)
--------------------------------------------------------

---@class ParticleBurstOpts
---@field x number X position
---@field y number Y position
---@field count number? Number of particles (default: 10)
---@field duration number? Particle lifetime in seconds (default: 1.0)
---@field startColor table? Starting color (default: WHITE)
---@field endColor table? Ending color (default: WHITE)
---@field easing string? Easing function name (default: "cubic")
---@field space "screen"|"world"? Coordinate space (default: "screen")

---@class ParticleSwirlOpts
---@field x number X position (center)
---@field y number Y position (center)
---@field radius number? Swirl radius (default: 50)
---@field colors table[]? Array of colors to use
---@field emitDuration number? How long to emit particles (default: 1.0)
---@field totalLifetime number? Total effect duration (default: emitDuration + 1.0)

---@class ParticleSwirlWithRingOpts : ParticleSwirlOpts
-- Same as ParticleSwirlOpts, creates swirl with ring effect

--------------------------------------------------------
-- Default Values
--------------------------------------------------------

particles.DEFAULTS = {
    burst = {
        count = 10,
        duration = 1.0,
        easing = "cubic",
        space = "screen",
    },
    swirl = {
        radius = 50,
        emitDuration = 1.0,
    },
}

--------------------------------------------------------
-- Circular Burst Particles
--------------------------------------------------------

--- Spawn circular burst particles
--- @param x_or_opts number|ParticleBurstOpts X position or options table
--- @param y number? Y position (positional signature)
--- @param count number? Particle count (positional signature)
--- @param duration number? Lifetime in seconds (positional signature)
--- @param startColor table? Starting color (positional signature)
--- @param endColor table? Ending color (positional signature)
--- @param easing string? Easing name (positional signature)
--- @param space string? "screen" or "world" (positional signature)
function particles.burst(x_or_opts, y, count, duration, startColor, endColor, easing, space)
    -- DUAL SIGNATURE: detect if first arg is options table
    if type(x_or_opts) == "table" and x_or_opts.x ~= nil then
        return particles.burst_opts(x_or_opts)
    end
    
    -- Positional signature - call original function directly
    local x = x_or_opts
    if spawnCircularBurstParticles then
        spawnCircularBurstParticles(
            x, y,
            count or particles.DEFAULTS.burst.count,
            duration or particles.DEFAULTS.burst.duration,
            startColor,
            endColor,
            easing or particles.DEFAULTS.burst.easing,
            space or particles.DEFAULTS.burst.space
        )
    else
        log_warn("particle_helpers: spawnCircularBurstParticles not available")
    end
end

---@param opts ParticleBurstOpts
function particles.burst_opts(opts)
    assert(opts.x, "particles.burst_opts: x required")
    assert(opts.y, "particles.burst_opts: y required")
    
    particles.burst(
        opts.x,
        opts.y,
        opts.count or particles.DEFAULTS.burst.count,
        opts.duration or particles.DEFAULTS.burst.duration,
        opts.startColor,
        opts.endColor,
        opts.easing or particles.DEFAULTS.burst.easing,
        opts.space or particles.DEFAULTS.burst.space
    )
end

--------------------------------------------------------
-- Swirl Emitter
--------------------------------------------------------

--- Create a swirl particle emitter
--- @param x_or_opts number|ParticleSwirlOpts X position or options table
--- @param y number? Y position (positional signature)
--- @param radius number? Swirl radius (positional signature)
--- @param colorSet table[]? Array of colors (positional signature)
--- @param emitDuration number? Emit duration (positional signature)
--- @param totalLifetime number? Total lifetime (positional signature)
--- @return table? emitter The swirl emitter node
function particles.swirl(x_or_opts, y, radius, colorSet, emitDuration, totalLifetime)
    -- DUAL SIGNATURE: detect if first arg is options table
    if type(x_or_opts) == "table" and x_or_opts.x ~= nil then
        return particles.swirl_opts(x_or_opts)
    end
    
    -- Positional signature - call original function directly
    local x = x_or_opts
    if makeSwirlEmitter then
        return makeSwirlEmitter(
            x, y,
            radius or particles.DEFAULTS.swirl.radius,
            colorSet,
            emitDuration or particles.DEFAULTS.swirl.emitDuration,
            totalLifetime
        )
    else
        log_warn("particle_helpers: makeSwirlEmitter not available")
        return nil
    end
end

---@param opts ParticleSwirlOpts
---@return table? emitter The swirl emitter node
function particles.swirl_opts(opts)
    assert(opts.x, "particles.swirl_opts: x required")
    assert(opts.y, "particles.swirl_opts: y required")
    
    local emitDur = opts.emitDuration or particles.DEFAULTS.swirl.emitDuration
    local totalLife = opts.totalLifetime or (emitDur + 1.0)
    
    return particles.swirl(
        opts.x,
        opts.y,
        opts.radius or particles.DEFAULTS.swirl.radius,
        opts.colors,
        emitDur,
        totalLife
    )
end

--------------------------------------------------------
-- Swirl Emitter With Ring
--------------------------------------------------------

--- Create a swirl particle emitter with ring effect
--- @param x_or_opts number|ParticleSwirlWithRingOpts X position or options table
--- @param y number? Y position (positional signature)
--- @param radius number? Swirl radius (positional signature)
--- @param colorSet table[]? Array of colors (positional signature)
--- @param emitDuration number? Emit duration (positional signature)
--- @param totalLifetime number? Total lifetime (positional signature)
--- @return table? emitter The swirl emitter node
function particles.swirl_with_ring(x_or_opts, y, radius, colorSet, emitDuration, totalLifetime)
    -- DUAL SIGNATURE: detect if first arg is options table
    if type(x_or_opts) == "table" and x_or_opts.x ~= nil then
        return particles.swirl_with_ring_opts(x_or_opts)
    end
    
    -- Positional signature - call original function directly
    local x = x_or_opts
    if makeSwirlEmitterWithRing then
        return makeSwirlEmitterWithRing(
            x, y,
            radius or particles.DEFAULTS.swirl.radius,
            colorSet,
            emitDuration or particles.DEFAULTS.swirl.emitDuration,
            totalLifetime
        )
    else
        log_warn("particle_helpers: makeSwirlEmitterWithRing not available")
        return nil
    end
end

---@param opts ParticleSwirlWithRingOpts
---@return table? emitter The swirl emitter node
function particles.swirl_with_ring_opts(opts)
    assert(opts.x, "particles.swirl_with_ring_opts: x required")
    assert(opts.y, "particles.swirl_with_ring_opts: y required")
    
    local emitDur = opts.emitDuration or particles.DEFAULTS.swirl.emitDuration
    local totalLife = opts.totalLifetime or (emitDur + 1.0)
    
    return particles.swirl_with_ring(
        opts.x,
        opts.y,
        opts.radius or particles.DEFAULTS.swirl.radius,
        opts.colors,
        emitDur,
        totalLife
    )
end

--------------------------------------------------------
-- Module Export
--------------------------------------------------------

_G.__PARTICLE_HELPERS__ = particles
return particles
