local Speaker = {}
Speaker.__index = Speaker

local timer = require("core.timer")
local entity_cache = require("core.entity_cache")
local component_cache = require("core.component_cache")

local EntityBuilder, ShaderBuilder
local function lazyLoadBuilders()
    if not EntityBuilder then
        EntityBuilder = require("core.entity_builder")
        ShaderBuilder = require("core.shader_builder")
    end
end

local POSITION_PRESETS = {
    left = function(screenW, screenH, size)
        return { x = screenW * 0.15, y = screenH * 0.5 - size[2] * 0.3 }
    end,
    right = function(screenW, screenH, size)
        return { x = screenW * 0.85 - size[1], y = screenH * 0.5 - size[2] * 0.3 }
    end,
    center = function(screenW, screenH, size)
        return { x = screenW * 0.5 - size[1] * 0.5, y = screenH * 0.5 - size[2] * 0.5 }
    end,
    bottom_left = function(screenW, screenH, size)
        return { x = screenW * 0.1, y = screenH * 0.7 }
    end,
    bottom_right = function(screenW, screenH, size)
        return { x = screenW * 0.9 - size[1], y = screenH * 0.7 }
    end,
}

function Speaker.new(config, timerGroup)
    lazyLoadBuilders()
    
    local self = setmetatable({}, Speaker)
    
    self._group = timerGroup or "speaker_" .. math.random(1, 9999)
    self._config = config or {}
    self._entity = nil
    self._visible = false
    self._talking = false
    self._alpha = 0
    self._basePos = { x = 0, y = 0 }
    self._currentOffset = { x = 0, y = 0 }
    self._elapsed = 0
    self._jigglePhase = 0
    
    return self
end

function Speaker:_resolvePosition()
    local screenW = (globals and globals.screenWidth and globals.screenWidth()) or 1920
    local screenH = (globals and globals.screenHeight and globals.screenHeight()) or 1080
    local size = self._config.size or { 96, 96 }
    
    local pos = self._config.position
    if type(pos) == "string" then
        local preset = POSITION_PRESETS[pos] or POSITION_PRESETS.left
        return preset(screenW, screenH, size)
    elseif type(pos) == "table" then
        return { x = pos.x or pos[1] or 0, y = pos.y or pos[2] or 0 }
    end
    
    return POSITION_PRESETS.left(screenW, screenH, size)
end

function Speaker:_createEntity()
    if self._entity and entity_cache.valid(self._entity) then
        return
    end
    
    local size = self._config.size or { 96, 96 }
    self._basePos = self:_resolvePosition()
    
    local opts = {
        sprite = self._config.sprite,
        x = self._basePos.x,
        y = self._basePos.y,
        size = size,
        shadow = self._config.shadow ~= false,
    }
    
    self._entity = EntityBuilder.create(opts)
    
    if self._config.shaders and #self._config.shaders > 0 then
        local builder = ShaderBuilder.for_entity(self._entity)
        for _, shader in ipairs(self._config.shaders) do
            if type(shader) == "string" then
                builder:add(shader)
            elseif type(shader) == "table" then
                builder:add(shader[1], shader[2])
            end
        end
        builder:apply()
    end
    
    local t = component_cache.get(self._entity, Transform)
    if t then
        t.visualAlpha = 0
    end
end

function Speaker:show(duration)
    duration = duration or 0.3
    
    self:_createEntity()
    self._visible = true
    self._elapsed = 0
    
    local t = component_cache.get(self._entity, Transform)
    if not t then return end
    
    local startY = self._basePos.y + 30
    t.actualY = startY
    t.visualY = startY
    t.visualAlpha = 0
    
    timer.tween_tracks(duration, {
        { get = function() return t.visualAlpha or 0 end, set = function(v) t.visualAlpha = v end, to = 255 },
        { get = function() return t.actualY end, set = function(v) t.actualY = v; t.visualY = v end, to = self._basePos.y },
    }, function(x) return x < 0.5 and 2*x*x or 1 - (-2*x + 2)^2 / 2 end, nil, nil, self._group)
    
    self:_startIdleAnimation()
end

function Speaker:hide(duration)
    duration = duration or 0.25
    self._visible = false
    self._talking = false
    
    timer.kill_group(self._group .. "_idle")
    timer.kill_group(self._group .. "_jiggle")
    
    local t = component_cache.get(self._entity, Transform)
    if not t then return end
    
    timer.tween_tracks(duration, {
        { get = function() return t.visualAlpha or 255 end, set = function(v) t.visualAlpha = v end, to = 0 },
    }, nil, nil, nil, self._group)
end

function Speaker:destroy()
    timer.kill_group(self._group)
    timer.kill_group(self._group .. "_idle")
    timer.kill_group(self._group .. "_jiggle")
    
    if self._entity and entity_cache.valid(self._entity) then
        registry:destroy(self._entity)
    end
    self._entity = nil
end

function Speaker:_startIdleAnimation()
    if not self._config.idleFloat or not self._config.idleFloat.enabled then
        return
    end
    
    local amp = self._config.idleFloat.amplitude or 4
    local speed = self._config.idleFloat.speed or 1.5
    local phase = math.random() * math.pi * 2
    
    timer.every(0.016, function()
        if not self._visible or not self._entity or not entity_cache.valid(self._entity) then
            return
        end
        
        self._elapsed = self._elapsed + 0.016
        
        local floatY = math.sin(self._elapsed * speed + phase) * amp
        local floatX = math.sin(self._elapsed * speed * 0.7 + phase * 0.5) * (amp * 0.5)
        
        local t = component_cache.get(self._entity, Transform)
        if t then
            t.actualX = self._basePos.x + floatX + self._currentOffset.x
            t.actualY = self._basePos.y + floatY + self._currentOffset.y
            t.visualX = t.actualX
            t.visualY = t.actualY
        end
    end, 0, false, nil, nil, self._group .. "_idle")
end

function Speaker:startTalking()
    if self._talking then return end
    self._talking = true
    
    local jiggle = self._config.jiggle or {}
    if jiggle.enabled == false then return end
    
    local intensity = jiggle.intensity or 0.08
    local speed = jiggle.speed or 8
    
    timer.every(0.016, function()
        if not self._talking or not self._entity or not entity_cache.valid(self._entity) then
            self._currentOffset = { x = 0, y = 0 }
            return
        end
        
        self._jigglePhase = self._jigglePhase + 0.016 * speed
        
        local t = component_cache.get(self._entity, Transform)
        if t then
            local baseW = self._config.size and self._config.size[1] or 96
            local baseH = self._config.size and self._config.size[2] or 96
            
            local scaleJiggle = math.sin(self._jigglePhase * 6) * intensity
            t.actualW = baseW * (1 + scaleJiggle)
            t.actualH = baseH * (1 - scaleJiggle * 0.5)
            t.visualW = t.actualW
            t.visualH = t.actualH
            
            self._currentOffset.y = math.sin(self._jigglePhase * 4) * 2
        end
    end, 0, false, nil, nil, self._group .. "_jiggle")
end

function Speaker:stopTalking()
    self._talking = false
    timer.kill_group(self._group .. "_jiggle")
    
    if self._entity and entity_cache.valid(self._entity) then
        local t = component_cache.get(self._entity, Transform)
        if t then
            local baseW = self._config.size and self._config.size[1] or 96
            local baseH = self._config.size and self._config.size[2] or 96
            
            timer.tween_tracks(0.15, {
                { get = function() return t.actualW end, set = function(v) t.actualW = v; t.visualW = v end, to = baseW },
                { get = function() return t.actualH end, set = function(v) t.actualH = v; t.visualH = v end, to = baseH },
            }, nil, nil, nil, self._group)
        end
    end
    
    self._currentOffset = { x = 0, y = 0 }
end

function Speaker:getEntity()
    return self._entity
end

function Speaker:getPosition()
    return { x = self._basePos.x, y = self._basePos.y }
end

return Speaker
