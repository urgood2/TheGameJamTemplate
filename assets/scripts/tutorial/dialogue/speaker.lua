local Speaker = {}
Speaker.__index = Speaker

local timer = require("core.timer")

-- Position presets return TOP-LEFT corner positions
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
    local self = setmetatable({}, Speaker)

    self._group = timerGroup or "speaker_" .. math.random(1, 9999)
    self._config = config or {}
    self._visible = false
    self._talking = false
    self._alpha = 0
    self._basePos = { x = 0, y = 0 }
    self._currentOffset = { x = 0, y = 0 }
    self._currentScale = { w = 1, h = 1 }
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

--- Draw the speaker sprite to UI layer (avoids spotlight shader on sprites layer)
function Speaker:draw()
    if self._alpha <= 0 then return end
    if not command_buffer or not layers or not layers.ui then return end

    local size = self._config.size or { 96, 96 }
    local baseW, baseH = size[1], size[2]
    local scaledW = baseW * self._currentScale.w
    local scaledH = baseH * self._currentScale.h

    -- Calculate center position (base + offsets)
    local centerX = self._basePos.x + baseW * 0.5 + self._currentOffset.x
    local centerY = self._basePos.y + baseH * 0.5 + self._currentOffset.y

    local space = layer and layer.DrawCommandSpace and layer.DrawCommandSpace.Screen
    local baseZ = 850  -- Below dialogue box (900) but above world content

    local alphaInt = math.floor(self._alpha)

    -- Draw shadow if enabled
    if self._config.shadow ~= false then
        local shadowOffset = 4
        command_buffer.queueDrawSpriteCentered(layers.ui, function(c)
            c.spriteName = self._config.sprite
            c.x = centerX + shadowOffset
            c.y = centerY + shadowOffset
            c.dstW = scaledW
            c.dstH = scaledH
            c.tint = Col(0, 0, 0, math.floor(alphaInt * 0.5))
        end, baseZ - 1, space)
    end

    -- Draw main sprite
    command_buffer.queueDrawSpriteCentered(layers.ui, function(c)
        c.spriteName = self._config.sprite
        c.x = centerX
        c.y = centerY
        c.dstW = scaledW
        c.dstH = scaledH
        c.tint = Col(255, 255, 255, alphaInt)
    end, baseZ, space)
end

function Speaker:show(duration)
    duration = duration or 0.3

    self._basePos = self:_resolvePosition()
    self._visible = true
    self._elapsed = 0
    self._currentScale = { w = 1, h = 1 }

    -- Start with offset for slide-in animation
    local startOffsetY = 30
    self._currentOffset = { x = 0, y = startOffsetY }
    self._alpha = 0

    -- Tween alpha and Y offset
    timer.tween_tracks(duration, {
        { get = function() return self._alpha end, set = function(v) self._alpha = v end, to = 255 },
        { get = function() return self._currentOffset.y end, set = function(v) self._currentOffset.y = v end, to = 0 },
    }, function(x) return x < 0.5 and 2*x*x or 1 - (-2*x + 2)^2 / 2 end, nil, nil, self._group)

    self:_startIdleAnimation()
end

function Speaker:hide(duration)
    duration = duration or 0.25
    self._visible = false
    self._talking = false

    timer.kill_group(self._group .. "_idle")
    timer.kill_group(self._group .. "_jiggle")

    timer.tween_tracks(duration, {
        { get = function() return self._alpha end, set = function(v) self._alpha = v end, to = 0 },
    }, nil, nil, nil, self._group)
end

function Speaker:destroy()
    timer.kill_group(self._group)
    timer.kill_group(self._group .. "_idle")
    timer.kill_group(self._group .. "_jiggle")
    self._visible = false
    self._alpha = 0
end

function Speaker:_startIdleAnimation()
    if not self._config.idleFloat or not self._config.idleFloat.enabled then
        return
    end

    local amp = self._config.idleFloat.amplitude or 4
    local speed = self._config.idleFloat.speed or 1.5
    local phase = math.random() * math.pi * 2

    timer.every(0.016, function()
        if not self._visible then return end

        self._elapsed = self._elapsed + 0.016

        -- Idle float animation adds to current offset (jiggle is separate)
        local floatY = math.sin(self._elapsed * speed + phase) * amp
        local floatX = math.sin(self._elapsed * speed * 0.7 + phase * 0.5) * (amp * 0.5)

        -- Only update idle component of offset (jiggle adds its own)
        self._idleOffset = { x = floatX, y = floatY }
    end, 0, false, nil, nil, self._group .. "_idle")

    self._idleOffset = { x = 0, y = 0 }
end

function Speaker:startTalking()
    if self._talking then return end
    self._talking = true

    local jiggle = self._config.jiggle or {}
    if jiggle.enabled == false then return end

    local intensity = jiggle.intensity or 0.08
    local speed = jiggle.speed or 8

    timer.every(0.016, function()
        if not self._talking then
            return
        end

        self._jigglePhase = self._jigglePhase + 0.016 * speed

        -- Scale jiggle (squash & stretch)
        local scaleJiggle = math.sin(self._jigglePhase * 6) * intensity
        self._currentScale.w = 1 + scaleJiggle
        self._currentScale.h = 1 - scaleJiggle * 0.5

        -- Y jiggle offset
        self._jiggleOffset = { y = math.sin(self._jigglePhase * 4) * 2 }
    end, 0, false, nil, nil, self._group .. "_jiggle")

    self._jiggleOffset = { y = 0 }
end

function Speaker:stopTalking()
    self._talking = false
    timer.kill_group(self._group .. "_jiggle")

    -- Tween scale back to 1
    timer.tween_tracks(0.15, {
        { get = function() return self._currentScale.w end, set = function(v) self._currentScale.w = v end, to = 1 },
        { get = function() return self._currentScale.h end, set = function(v) self._currentScale.h = v end, to = 1 },
    }, nil, nil, nil, self._group)

    self._jiggleOffset = { y = 0 }
end

function Speaker:getPosition()
    return { x = self._basePos.x, y = self._basePos.y }
end

--- Per-frame update: combines offsets and calls draw
function Speaker:update(dt)
    if not self._visible and self._alpha <= 0 then return end

    -- Combine idle + jiggle offsets
    local idleX = self._idleOffset and self._idleOffset.x or 0
    local idleY = self._idleOffset and self._idleOffset.y or 0
    local jiggleY = self._jiggleOffset and self._jiggleOffset.y or 0

    self._currentOffset.x = idleX
    self._currentOffset.y = idleY + jiggleY

    self:draw()
end

return Speaker
