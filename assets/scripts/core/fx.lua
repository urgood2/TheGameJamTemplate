--[[
================================================================================
fx.lua - Unified Visual Effects Module
================================================================================
Combines particles, hitfx, screen shake, sound, and popups into a fluent API.

Usage:
    local Fx = require("core.fx")

    -- Fluent chaining (deferred execution)
    Fx.at(enemy)
      :flash(0.2)
      :shake(5, 0.3)
      :particles("spark", 10)
      :sound("hit_01")
      :go()

    -- Presets for common effects
    Fx.hit(enemy)           -- flash + shake + sparks
    Fx.death(enemy)         -- explosion particles + sound
    Fx.damage(enemy, 25)    -- flash + damage number
    Fx.heal(entity, 50)     -- green particles + heal number

Dependencies:
    - core.hitfx (flash effects)
    - core.popup (damage/heal numbers)
    - core.Q (position helpers)
    - core.timer (delayed effects)
    - particle (C++ binding, optional)
    - camera (C++ binding, optional)
]]

if _G.__FX__ then return _G.__FX__ end

local Fx = {}

local Q = require("core.Q")
local hitfx = require("core.hitfx")
local popup = require("core.popup")
local timer = require("core.timer")

local FxChain = {}
FxChain.__index = FxChain

function Fx.at(entity)
    local chain = setmetatable({}, FxChain)
    chain._entity = entity
    chain._actions = {}
    return chain
end

function Fx.point(x, y)
    local chain = setmetatable({}, FxChain)
    chain._x = x
    chain._y = y
    chain._actions = {}
    return chain
end

function FxChain:_getPosition()
    if self._entity then
        return Q.visualCenter(self._entity)
    end
    return self._x, self._y
end

function FxChain:flash(duration)
    table.insert(self._actions, function()
        if self._entity and Q.isValid(self._entity) then
            hitfx.flash(self._entity, duration or 0.2)
        end
    end)
    return self
end

function FxChain:shake(intensity, duration)
    table.insert(self._actions, function()
        local camera = _G.camera
        if camera and camera.shake then
            camera.shake(intensity or 5, duration or 0.2)
        elseif _G.globals and _G.globals.camera and _G.globals.camera.shake then
            _G.globals.camera:shake(intensity or 5, duration or 0.2)
        end
    end)
    return self
end

function FxChain:particles(name, count)
    table.insert(self._actions, function()
        local particle = _G.particle
        if not particle then return end
        
        local x, y = self:_getPosition()
        if not x then return end
        
        if particle.CreateParticleEmitter then
            local emitter = particle.CreateParticleEmitter(name, { x = x, y = y })
            if emitter and particle.EmitParticles then
                particle.EmitParticles(emitter, count or 10)
            end
        end
    end)
    return self
end

function FxChain:sound(name, category)
    table.insert(self._actions, function()
        local playSoundEffect = _G.playSoundEffect
        if playSoundEffect then
            playSoundEffect(category or "sfx", name)
        end
    end)
    return self
end

function FxChain:popup(text, opts)
    table.insert(self._actions, function()
        if self._entity then
            popup.above(self._entity, text, opts)
        else
            local x, y = self._x, self._y
            if x then
                popup.at(x, y, text, opts)
            end
        end
    end)
    return self
end

function FxChain:damage(amount, opts)
    table.insert(self._actions, function()
        if self._entity then
            popup.damage(self._entity, amount, opts)
        end
    end)
    return self
end

function FxChain:heal(amount, opts)
    table.insert(self._actions, function()
        if self._entity then
            popup.heal(self._entity, amount, opts)
        end
    end)
    return self
end

function FxChain:delay(seconds)
    table.insert(self._actions, { delay = seconds })
    return self
end

function FxChain:go()
    local delayAccum = 0
    for _, action in ipairs(self._actions) do
        if type(action) == "table" and action.delay then
            delayAccum = delayAccum + action.delay
        elseif type(action) == "function" then
            if delayAccum > 0 then
                local fn = action
                timer.after(delayAccum, fn)
            else
                action()
            end
        end
    end
    self._actions = {}
    return self
end

function Fx.hit(entity, opts)
    opts = opts or {}
    return Fx.at(entity)
        :flash(opts.flash_duration or 0.15)
        :shake(opts.shake_intensity or 3, opts.shake_duration or 0.1)
        :particles(opts.particle_name or "spark", opts.particle_count or 5)
        :go()
end

function Fx.death(entity, opts)
    opts = opts or {}
    return Fx.at(entity)
        :particles(opts.particle_name or "explosion", opts.particle_count or 20)
        :shake(opts.shake_intensity or 8, opts.shake_duration or 0.3)
        :sound(opts.sound or "enemy_death")
        :go()
end

function Fx.damage(entity, amount, opts)
    opts = opts or {}
    local chain = Fx.at(entity)
        :flash(opts.flash_duration or 0.1)
        :damage(amount, { color = opts.color or "red" })
    
    if opts.shake then
        chain:shake(opts.shake_intensity or 2, opts.shake_duration or 0.1)
    end
    
    return chain:go()
end

function Fx.heal(entity, amount, opts)
    opts = opts or {}
    return Fx.at(entity)
        :heal(amount, { color = opts.color or "green" })
        :particles(opts.particle_name or "heal_sparkle", opts.particle_count or 8)
        :go()
end

function Fx.levelUp(entity, opts)
    opts = opts or {}
    return Fx.at(entity)
        :particles(opts.particle_name or "gold_burst", opts.particle_count or 30)
        :popup("Level Up!", { color = "gold", duration = 2.0 })
        :sound(opts.sound or "level_up")
        :shake(5, 0.2)
        :go()
end

function Fx.pickup(entity, text, opts)
    opts = opts or {}
    return Fx.at(entity)
        :popup(text, { color = opts.color or "cyan", duration = 1.0 })
        :sound(opts.sound or "pickup")
        :go()
end

function Fx.screenFlash(color, duration)
    local camera = _G.camera or (_G.globals and _G.globals.camera)
    if camera and camera.flash then
        camera:flash(color or { r = 255, g = 255, b = 255, a = 200 }, duration or 0.1)
    end
end

function Fx.screenShake(intensity, duration)
    local camera = _G.camera or (_G.globals and _G.globals.camera)
    if camera and camera.shake then
        camera:shake(intensity or 5, duration or 0.2)
    end
end

_G.__FX__ = Fx
return Fx
