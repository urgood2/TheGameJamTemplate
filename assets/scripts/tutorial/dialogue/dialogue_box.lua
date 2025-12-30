local DialogueBox = {}
DialogueBox.__index = DialogueBox

local timer = require("core.timer")
local entity_cache = require("core.entity_cache")
local component_cache = require("core.component_cache")

local POSITION_PRESETS = {
    bottom = function(screenW, screenH, boxW, boxH, padding)
        return { 
            x = (screenW - boxW) * 0.5, 
            y = screenH - boxH - padding - 40 
        }
    end,
    top = function(screenW, screenH, boxW, boxH, padding)
        return { 
            x = (screenW - boxW) * 0.5, 
            y = padding + 40 
        }
    end,
    center = function(screenW, screenH, boxW, boxH, padding)
        return { 
            x = (screenW - boxW) * 0.5, 
            y = (screenH - boxH) * 0.5 
        }
    end,
}

local DEFAULT_COLORS = {
    background = { 20, 25, 35, 230 },
    border = { 80, 100, 140, 255 },
    nameplateBg = { 50, 60, 80, 255 },
}

function DialogueBox.new(boxConfig, textConfig, timerGroup)
    local self = setmetatable({}, DialogueBox)
    
    self._group = timerGroup or "dialogue_box_" .. math.random(1, 9999)
    self._boxConfig = boxConfig or {}
    self._textConfig = textConfig or {}
    self._visible = false
    self._typing = false
    self._alpha = 0
    self._text = ""
    self._displayedChars = 0
    self._speakerName = nil
    self._onTypingComplete = nil
    self._textRenderer = nil
    self._boxEntity = nil
    self._pos = { x = 0, y = 0 }
    self._size = { w = 500, h = 120 }
    
    return self
end

function DialogueBox:_resolvePosition()
    local screenW = (globals and globals.screenWidth and globals.screenWidth()) or 1920
    local screenH = (globals and globals.screenHeight and globals.screenHeight()) or 1080
    local padding = self._boxConfig.padding or 16
    local boxW = self._boxConfig.width or 500
    local boxH = self._size.h
    
    local pos = self._boxConfig.position
    if type(pos) == "string" then
        local preset = POSITION_PRESETS[pos] or POSITION_PRESETS.bottom
        return preset(screenW, screenH, boxW, boxH, padding)
    elseif type(pos) == "table" then
        return { x = pos.x or pos[1] or 0, y = pos.y or pos[2] or 0 }
    end
    
    return POSITION_PRESETS.bottom(screenW, screenH, boxW, boxH, padding)
end

function DialogueBox:_getColors()
    return self._boxConfig.colors or DEFAULT_COLORS
end

function DialogueBox:show(duration)
    duration = duration or 0.25
    self._visible = true
    self._alpha = 0
    
    self._size.w = self._boxConfig.width or 500
    self._size.h = 120
    self._pos = self:_resolvePosition()
    
    timer.tween_scalar(duration,
        function() return self._alpha end,
        function(v) self._alpha = v end,
        1,
        function(t) return t < 0.5 and 2*t*t or 1 - (-2*t + 2)^2 / 2 end,
        nil, nil, self._group
    )
end

function DialogueBox:hide(duration)
    duration = duration or 0.2
    self._visible = false
    self._typing = false
    
    timer.kill_group(self._group .. "_typing")
    
    timer.tween_scalar(duration,
        function() return self._alpha end,
        function(v) self._alpha = v end,
        0,
        nil, nil, nil, self._group
    )
end

function DialogueBox:destroy()
    timer.kill_group(self._group)
    timer.kill_group(self._group .. "_typing")
    
    if self._textRenderer then
        self._textRenderer = nil
    end
    
    if self._boxEntity and entity_cache.valid(self._boxEntity) then
        registry:destroy(self._boxEntity)
        self._boxEntity = nil
    end
end

function DialogueBox:setName(name)
    self._speakerName = name
end

function DialogueBox:setText(text, opts)
    opts = opts or {}
    self._text = text or ""
    self._displayedChars = 0
    self._onTypingComplete = opts.onComplete
    
    local typingSpeed = opts.typingSpeed or self._textConfig.typingSpeed or 0.03
    
    if typingSpeed <= 0 then
        self._displayedChars = #self._text
        self._typing = false
        if self._onTypingComplete then
            self._onTypingComplete()
        end
        return
    end
    
    self._typing = true
    local charCount = #self._text
    
    timer.every(typingSpeed, function()
        if not self._typing then return end
        
        self._displayedChars = self._displayedChars + 1
        
        if self._displayedChars >= charCount then
            self._typing = false
            timer.cancel(self._group .. "_typing_timer")
            if self._onTypingComplete then
                self._onTypingComplete()
            end
        end
    end, charCount, false, nil, self._group .. "_typing_timer", self._group .. "_typing")
end

function DialogueBox:skipTyping()
    if not self._typing then return end
    
    self._typing = false
    self._displayedChars = #self._text
    timer.kill_group(self._group .. "_typing")
    
    if self._onTypingComplete then
        self._onTypingComplete()
    end
end

function DialogueBox:isTyping()
    return self._typing
end

function DialogueBox:getDisplayedText()
    if self._displayedChars >= #self._text then
        return self._text
    end
    return self._text:sub(1, self._displayedChars)
end

function DialogueBox:getPromptPosition()
    return {
        x = self._pos.x + self._size.w - 20,
        y = self._pos.y + self._size.h - 10,
    }
end

function DialogueBox:draw()
    if self._alpha <= 0.01 then return end
    
    local colors = self:_getColors()
    local padding = self._boxConfig.padding or 16
    local cornerRadius = 8
    
    local bgColor = colors.background
    local borderColor = colors.border
    local npBgColor = colors.nameplateBg
    
    local alphaScale = self._alpha
    
    local screenSpace = layer and layer.DrawCommandSpace and layer.DrawCommandSpace.Screen
    local uiLayer = layers and layers.ui
    local baseZ = 900
    
    if not uiLayer or not command_buffer then return end
    
    command_buffer.queueDrawCenteredFilledRoundedRect(uiLayer, function(c)
        c.x = self._pos.x + self._size.w * 0.5
        c.y = self._pos.y + self._size.h * 0.5
        c.w = self._size.w
        c.h = self._size.h
        c.rx = cornerRadius
        c.ry = cornerRadius
        c.color = Col(bgColor[1], bgColor[2], bgColor[3], math.floor(bgColor[4] * alphaScale))
    end, baseZ, screenSpace)
    
    command_buffer.queueDrawCenteredRoundedRect(uiLayer, function(c)
        c.x = self._pos.x + self._size.w * 0.5
        c.y = self._pos.y + self._size.h * 0.5
        c.w = self._size.w
        c.h = self._size.h
        c.rx = cornerRadius
        c.ry = cornerRadius
        c.thickness = 2
        c.color = Col(borderColor[1], borderColor[2], borderColor[3], math.floor(borderColor[4] * alphaScale))
    end, baseZ + 1, screenSpace)
    
    if self._speakerName and self._boxConfig.nameplate ~= false then
        local npHeight = 28
        local npWidth = 120
        local npX = self._pos.x + 16
        local npY = self._pos.y - npHeight * 0.5
        
        command_buffer.queueDrawCenteredFilledRoundedRect(uiLayer, function(c)
            c.x = npX + npWidth * 0.5
            c.y = npY + npHeight * 0.5
            c.w = npWidth
            c.h = npHeight
            c.rx = 4
            c.ry = 4
            c.color = Col(npBgColor[1], npBgColor[2], npBgColor[3], math.floor(npBgColor[4] * alphaScale))
        end, baseZ + 2, screenSpace)
        
        local font = localization and localization.getFont and localization.getFont()
        command_buffer.queueDrawText(uiLayer, function(c)
            c.text = self._speakerName
            c.font = font
            c.x = npX + 8
            c.y = npY + 6
            c.color = Col(255, 255, 255, math.floor(255 * alphaScale))
            c.fontSize = 14
        end, baseZ + 3, screenSpace)
    end
    
    local displayedText = self:getDisplayedText()
    if displayedText and #displayedText > 0 then
        local textX = self._pos.x + padding
        local textY = self._pos.y + padding + 10
        local font = localization and localization.getFont and localization.getFont()
        local fontSize = self._textConfig.fontSize or 18
        
        command_buffer.queueDrawText(uiLayer, function(c)
            c.text = displayedText
            c.font = font
            c.x = textX
            c.y = textY
            c.color = Col(255, 255, 255, math.floor(255 * alphaScale))
            c.fontSize = fontSize
        end, baseZ + 4, screenSpace)
    end
end

function DialogueBox:update(dt)
    self:draw()
end

return DialogueBox
