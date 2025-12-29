--[[
================================================================================
tween.lua - Simplified Property Tweening
================================================================================
Fluent API wrapper over timer.tween_* with common easing presets.

Usage:
    local Tween = require("core.tween")

    Tween.to(entity, 0.5, { x = 100, y = 200 })
        :ease("outQuad")
        :onComplete(function() print("done!") end)

    Tween.value(0, 100, 1.0, function(v) bar.width = v end)
        :ease("outBounce")

    Tween.fadeOut(entity, 0.3)
    Tween.fadeIn(entity, 0.3)
    Tween.popIn(entity, 0.2)

Dependencies:
    - core.timer
    - core.Q (optional, for transform tweens)
]]

if _G.__TWEEN__ then return _G.__TWEEN__ end

local Tween = {}

local timer = require("core.timer")
local Q = require("core.Q")
local component_cache = require("core.component_cache")

local Easing = {
    linear = function(t) return t end,
    inQuad = function(t) return t * t end,
    outQuad = function(t) return t * (2 - t) end,
    inOutQuad = function(t)
        if t < 0.5 then return 2 * t * t end
        return -1 + (4 - 2 * t) * t
    end,
    inCubic = function(t) return t * t * t end,
    outCubic = function(t) return (t - 1) ^ 3 + 1 end,
    inOutCubic = function(t)
        if t < 0.5 then return 4 * t * t * t end
        return (t - 1) * (2 * t - 2) * (2 * t - 2) + 1
    end,
    outBack = function(t)
        local c1, c3 = 1.70158, 2.70158
        return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
    end,
    outElastic = function(t)
        if t == 0 then return 0 end
        if t == 1 then return 1 end
        local c4 = (2 * math.pi) / 3
        return 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * c4) + 1
    end,
    outBounce = function(t)
        local n1, d1 = 7.5625, 2.75
        if t < 1 / d1 then
            return n1 * t * t
        elseif t < 2 / d1 then
            t = t - 1.5 / d1
            return n1 * t * t + 0.75
        elseif t < 2.5 / d1 then
            t = t - 2.25 / d1
            return n1 * t * t + 0.9375
        else
            t = t - 2.625 / d1
            return n1 * t * t + 0.984375
        end
    end,
}

Tween.Easing = Easing

local TweenChain = {}
TweenChain.__index = TweenChain

function TweenChain:ease(name)
    self._easing = Easing[name] or Easing.linear
    return self
end

function TweenChain:onComplete(fn)
    self._onComplete = fn
    return self
end

function TweenChain:tag(name)
    self._tag = name
    return self
end

function TweenChain:start()
    if self._started then return self end
    self._started = true
    
    if self._type == "transform" then
        self:_startTransformTween()
    elseif self._type == "value" then
        self:_startValueTween()
    elseif self._type == "fields" then
        self:_startFieldsTween()
    end
    
    return self
end

function TweenChain:_startTransformTween()
    local entity = self._entity
    local targets = self._targets
    local duration = self._duration
    local easing = self._easing or Easing.linear
    local onComplete = self._onComplete
    
    local transform = Q.getTransform(entity)
    if not transform then return end
    
    local source = {}
    if targets.x then source.actualX = targets.x end
    if targets.y then source.actualY = targets.y end
    if targets.w then source.actualW = targets.w end
    if targets.h then source.actualH = targets.h end
    if targets.r then source.actualR = targets.r end
    if targets.scale then
        source.scaleX = targets.scale
        source.scaleY = targets.scale
    end
    if targets.scaleX then source.scaleX = targets.scaleX end
    if targets.scaleY then source.scaleY = targets.scaleY end
    if targets.alpha then source.alpha = targets.alpha end
    
    timer.tween_fields(duration, transform, source, easing, onComplete, self._tag)
end

function TweenChain:_startValueTween()
    local from = self._from
    local to = self._to
    local duration = self._duration
    local callback = self._callback
    local easing = self._easing or Easing.linear
    local onComplete = self._onComplete
    
    timer.tween_scalar(
        duration,
        function() return from end,
        function(v) callback(v) end,
        to,
        easing,
        onComplete,
        self._tag
    )
end

function TweenChain:_startFieldsTween()
    local target = self._target
    local source = self._source
    local duration = self._duration
    local easing = self._easing or Easing.linear
    local onComplete = self._onComplete
    
    timer.tween_fields(duration, target, source, easing, onComplete, self._tag)
end

function TweenChain:cancel()
    if self._tag then
        timer.cancel(self._tag)
    end
end

function Tween.to(entity, duration, targets)
    local chain = setmetatable({}, TweenChain)
    chain._type = "transform"
    chain._entity = entity
    chain._duration = duration
    chain._targets = targets
    chain._tag = "tween_" .. tostring(entity) .. "_" .. tostring(os.clock())
    timer.after(0, function() chain:start() end)
    return chain
end

function Tween.value(from, to, duration, callback)
    local chain = setmetatable({}, TweenChain)
    chain._type = "value"
    chain._from = from
    chain._to = to
    chain._duration = duration
    chain._callback = callback
    chain._tag = "tween_value_" .. tostring(os.clock())
    timer.after(0, function() chain:start() end)
    return chain
end

function Tween.fields(target, source, duration)
    local chain = setmetatable({}, TweenChain)
    chain._type = "fields"
    chain._target = target
    chain._source = source
    chain._duration = duration
    chain._tag = "tween_fields_" .. tostring(os.clock())
    timer.after(0, function() chain:start() end)
    return chain
end

function Tween.fadeOut(entity, duration, opts)
    opts = opts or {}
    local transform = Q.getTransform(entity)
    if not transform then return end
    
    return Tween.to(entity, duration or 0.3, { alpha = 0 })
        :ease(opts.ease or "outQuad")
        :onComplete(opts.onComplete)
end

function Tween.fadeIn(entity, duration, opts)
    opts = opts or {}
    local transform = Q.getTransform(entity)
    if not transform then return end
    
    transform.alpha = 0
    return Tween.to(entity, duration or 0.3, { alpha = 255 })
        :ease(opts.ease or "outQuad")
        :onComplete(opts.onComplete)
end

function Tween.popIn(entity, duration, opts)
    opts = opts or {}
    local transform = Q.getTransform(entity)
    if not transform then return end
    
    transform.scaleX = 0
    transform.scaleY = 0
    
    return Tween.to(entity, duration or 0.2, { scaleX = 1, scaleY = 1 })
        :ease(opts.ease or "outBack")
        :onComplete(opts.onComplete)
end

function Tween.popOut(entity, duration, opts)
    opts = opts or {}
    return Tween.to(entity, duration or 0.2, { scaleX = 0, scaleY = 0 })
        :ease(opts.ease or "inBack")
        :onComplete(opts.onComplete)
end

function Tween.shake(entity, duration, intensity, opts)
    opts = opts or {}
    intensity = intensity or 5
    duration = duration or 0.3
    
    local transform = Q.getTransform(entity)
    if not transform then return end
    
    local originalX = transform.actualX
    local originalY = transform.actualY
    local elapsed = 0
    
    local tag = "shake_" .. tostring(entity) .. "_" .. tostring(os.clock())
    
    timer.for_time(duration, function(dt)
        elapsed = elapsed + dt
        local decay = 1 - (elapsed / duration)
        local offsetX = (math.random() * 2 - 1) * intensity * decay
        local offsetY = (math.random() * 2 - 1) * intensity * decay
        transform.actualX = originalX + offsetX
        transform.actualY = originalY + offsetY
    end, function()
        transform.actualX = originalX
        transform.actualY = originalY
        if opts.onComplete then opts.onComplete() end
    end, tag)
end

_G.__TWEEN__ = Tween
return Tween
