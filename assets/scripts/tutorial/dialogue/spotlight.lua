local Spotlight = {}
Spotlight.__index = Spotlight

local timer = require("core.timer")
local entity_cache = require("core.entity_cache")
local component_cache = require("core.component_cache")

function Spotlight.new(config, timerGroup)
    local self = setmetatable({}, Spotlight)

    self._group = timerGroup or "spotlight_" .. math.random(1, 9999)
    self._config = config or {}
    self._active = false
    self._size = config.size or 0.4
    self._feather = config.feather or 0.1
    self._position = config.position or { x = 0.5, y = 0.5 }
    self._targetSize = self._size
    self._targetPosition = { x = self._position.x, y = self._position.y }

    return self
end

function Spotlight:_setShaderUniforms()
    if not globalShaderUniforms then return end

    local screenW = (globals and globals.screenWidth and globals.screenWidth()) or 1920
    local screenH = (globals and globals.screenHeight and globals.screenHeight()) or 1080

    globalShaderUniforms:set("spotlight", "screen_width", screenW)
    globalShaderUniforms:set("spotlight", "screen_height", screenH)
    globalShaderUniforms:set("spotlight", "circle_size", self._size)
    globalShaderUniforms:set("spotlight", "feather", self._feather)
    globalShaderUniforms:set("spotlight", "circle_position", Vector2 {
        x = self._position.x,
        y = self._position.y
    })
end

function Spotlight:show(duration)
    duration = duration or 0.3

    log_debug("[Spotlight] show() called, duration=" .. tostring(duration))

    -- Apply spotlight shader to sprites layer only (UI stays bright)
    if add_layer_shader then
        add_layer_shader("sprites", "spotlight")
        log_debug("[Spotlight] Added spotlight shader to sprites layer")
    else
        log_warn("[Spotlight] add_layer_shader not available!")
    end

    self._active = true
    local startSize = 2.0
    self._size = startSize

    self:_setShaderUniforms()
    log_debug(string.format("[Spotlight] Initial uniforms: pos=(%.2f,%.2f), size=%.2f, feather=%.2f",
        self._position.x, self._position.y, self._size, self._feather))

    timer.tween_scalar(duration,
        function() return self._size end,
        function(v)
            self._size = v
            self:_setShaderUniforms()
        end,
        self._targetSize,
        function(t) return 1 - (1 - t) * (1 - t) end,
        nil, nil, self._group
    )
end

function Spotlight:hide(duration)
    duration = duration or 0.25

    timer.tween_scalar(duration,
        function() return self._size end,
        function(v)
            self._size = v
            self:_setShaderUniforms()
        end,
        2.0,
        nil,
        function()
            self._active = false
            if remove_layer_shader then
                remove_layer_shader("sprites", "spotlight")
            end
        end,
        nil, self._group
    )
end

function Spotlight:destroy()
    timer.kill_group(self._group)
    timer.kill_group(self._group .. "_update")

    if self._active and remove_layer_shader then
        remove_layer_shader("sprites", "spotlight")
    end
    self._active = false
end

function Spotlight:focusOn(target, size)
    if type(target) == "table" then
        self._targetPosition = {
            x = target.x or target[1] or 0.5,
            y = target.y or target[2] or 0.5
        }
    elseif entity_cache.valid(target) then
        local screenW = (globals and globals.screenWidth and globals.screenWidth()) or 1920
        local screenH = (globals and globals.screenHeight and globals.screenHeight()) or 1080

        local t = component_cache.get(target, Transform)
        if t then
            local centerX = (t.actualX or 0) + (t.actualW or 0) * 0.5
            local centerY = (t.actualY or 0) + (t.actualH or 0) * 0.5
            self._targetPosition = {
                x = centerX / screenW,
                y = centerY / screenH
            }
        end
    end

    if size then
        self._targetSize = size
    end

    local duration = 0.3

    timer.tween_tracks(duration, {
        {
            get = function() return self._position.x end,
            set = function(v) self._position.x = v end,
            to = self._targetPosition.x
        },
        {
            get = function() return self._position.y end,
            set = function(v) self._position.y = v end,
            to = self._targetPosition.y
        },
        {
            get = function() return self._size end,
            set = function(v) self._size = v end,
            to = self._targetSize
        },
    }, function(t) return t < 0.5 and 2*t*t or 1 - (-2*t + 2)^2 / 2 end,
    function() self:_setShaderUniforms() end,
    nil, self._group)

    timer.every(0.016, function()
        self:_setShaderUniforms()
    end, math.ceil(duration / 0.016), false, nil, nil, self._group .. "_update")
end

function Spotlight:setPosition(x, y)
    self._position = { x = x, y = y }
    self._targetPosition = { x = x, y = y }
    self:_setShaderUniforms()
end

function Spotlight:setSize(size)
    self._size = size
    self._targetSize = size
    self:_setShaderUniforms()
end

function Spotlight:isActive()
    return self._active
end

-- No draw() needed - shader handles rendering on sprites layer

return Spotlight
