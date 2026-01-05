local InputPrompt = {}
InputPrompt.__index = InputPrompt

local timer = require("core.timer")

local KEY_DISPLAY_NAMES = {
    space = "SPACE",
    enter = "ENTER",
    escape = "ESC",
    mouse_click = "CLICK",
    mouse_left = "LMB",
    mouse_right = "RMB",
    e = "E",
    f = "F",
    q = "Q",
    r = "R",
    tab = "TAB",
    shift = "SHIFT",
    ctrl = "CTRL",
    alt = "ALT",
}

-- Sprite names for keys that have icons
local KEY_SPRITES = {
    space = "keyboard_space.png",
    enter = "keyboard_enter.png",
    escape = "keyboard_escape.png",
    e = "keyboard_e.png",
    f = "keyboard_f.png",
    q = "keyboard_q.png",
    r = "keyboard_r.png",
    tab = "key_tab.png",
    shift = "keyboard_shift.png",
    ctrl = "keyboard_ctrl.png",
    alt = "keyboard_alt.png",
}

local KEY_TO_RAYLIB = {
    space = "KEY_SPACE",
    enter = "KEY_ENTER",
    escape = "KEY_ESCAPE",
    e = "KEY_E",
    f = "KEY_F",
    q = "KEY_Q",
    r = "KEY_R",
    tab = "KEY_TAB",
    shift = "KEY_LEFT_SHIFT",
    ctrl = "KEY_LEFT_CONTROL",
    alt = "KEY_LEFT_ALT",
    a = "KEY_A",
    s = "KEY_S",
    d = "KEY_D",
    w = "KEY_W",
}

function InputPrompt.new(config, timerGroup)
    local self = setmetatable({}, InputPrompt)
    
    self._group = timerGroup or "input_prompt_" .. math.random(1, 9999)
    self._config = config or {}
    self._key = config.key or "space"
    self._text = config.text
    self._position = config.position or { x = 0, y = 0 }
    self._visible = false
    self._alpha = 0
    self._pulsePhase = 0
    self._onPress = nil
    
    return self
end

function InputPrompt:_getDisplayText()
    if self._text then
        local keyName = KEY_DISPLAY_NAMES[self._key] or self._key:upper()
        return self._text:gsub("%[%w+%]", "[" .. keyName .. "]")
    end
    
    local keyName = KEY_DISPLAY_NAMES[self._key] or self._key:upper()
    return "Press [" .. keyName .. "] to continue"
end

function InputPrompt:show(duration)
    duration = duration or 0.2
    self._visible = true
    self._pulsePhase = 0
    
    timer.tween_scalar(duration,
        function() return self._alpha end,
        function(v) self._alpha = v end,
        1,
        nil, nil, nil, self._group
    )
    
    timer.every(0.016, function()
        if not self._visible then return end
        self._pulsePhase = self._pulsePhase + 0.016
    end, 0, false, nil, nil, self._group .. "_pulse")
end

function InputPrompt:hide(duration)
    duration = duration or 0.15
    self._visible = false
    
    timer.kill_group(self._group .. "_pulse")
    timer.kill_group(self._group .. "_check")
    
    timer.tween_scalar(duration,
        function() return self._alpha end,
        function(v) self._alpha = v end,
        0,
        nil, nil, nil, self._group
    )
end

function InputPrompt:destroy()
    timer.kill_group(self._group)
    timer.kill_group(self._group .. "_pulse")
    timer.kill_group(self._group .. "_check")
end

function InputPrompt:waitForPress(callback)
    self._onPress = callback
    
    timer.every(0.016, function()
        if not self._visible then return end
        
        local pressed = false
        
        if self._key == "mouse_click" or self._key == "mouse_left" then
            if input and input.action_pressed then
                pressed = input.action_pressed("mouse_click")
            elseif IsMouseButtonPressed then
                pressed = IsMouseButtonPressed(0)
            end
        elseif self._key == "mouse_right" then
            if IsMouseButtonPressed then
                pressed = IsMouseButtonPressed(1)
            end
        else
            local raylibKey = KEY_TO_RAYLIB[self._key]
            if raylibKey and isKeyPressed then
                pressed = isKeyPressed(raylibKey)
            elseif input and input.action_pressed then
                pressed = input.action_pressed(self._key)
            end
        end
        
        if pressed then
            timer.kill_group(self._group .. "_check")
            if self._onPress then
                self._onPress()
            end
        end
    end, 0, false, nil, nil, self._group .. "_check")
end

function InputPrompt:draw()
    if self._alpha <= 0.01 then return end

    local screenSpace = layer and layer.DrawCommandSpace and layer.DrawCommandSpace.Screen
    local uiLayer = layers and layers.ui
    local baseZ = 950

    if not uiLayer or not command_buffer then return end

    local pulse = 0.7 + math.sin(self._pulsePhase * 3) * 0.3
    local finalAlpha = math.floor(255 * self._alpha * pulse)

    local keySprite = KEY_SPRITES[self._key]
    local spriteSize = 24  -- Icon size in pixels
    local spacing = 6      -- Space between icon and text

    -- Calculate total width for centering
    local displayText = "to continue"
    local font = localization and localization.getFont and localization.getFont()
    local fontSize = 14

    -- Position icon and text (icon on left, text on right)
    local iconX = self._position.x
    local iconY = self._position.y
    local textX = iconX + spriteSize + spacing
    local textY = iconY + (spriteSize - fontSize) / 2  -- Vertically center text with icon

    -- Draw key icon if available
    if keySprite then
        -- Shadow
        command_buffer.queueDrawSpriteTopLeft(uiLayer, function(c)
            c.spriteName = keySprite
            c.x = iconX + 2
            c.y = iconY + 2
            c.dstW = spriteSize
            c.dstH = spriteSize
            c.tint = Col(0, 0, 0, math.floor(finalAlpha * 0.5))
        end, baseZ, screenSpace)

        -- Main icon with pulse effect
        local iconScale = 1.0 + math.sin(self._pulsePhase * 3) * 0.05
        local scaledSize = spriteSize * iconScale
        local offset = (scaledSize - spriteSize) / 2

        command_buffer.queueDrawSpriteTopLeft(uiLayer, function(c)
            c.spriteName = keySprite
            c.x = iconX - offset
            c.y = iconY - offset
            c.dstW = scaledSize
            c.dstH = scaledSize
            c.tint = Col(255, 255, 255, finalAlpha)
        end, baseZ + 1, screenSpace)
    end

    -- Draw "to continue" text
    -- Shadow
    command_buffer.queueDrawText(uiLayer, function(c)
        c.text = displayText
        c.font = font
        c.x = textX + 1
        c.y = textY + 1
        c.color = Col(0, 0, 0, math.floor(finalAlpha * 0.5))
        c.fontSize = fontSize
    end, baseZ, screenSpace)

    -- Main text
    command_buffer.queueDrawText(uiLayer, function(c)
        c.text = displayText
        c.font = font
        c.x = textX
        c.y = textY
        c.color = Col(200, 210, 230, finalAlpha)
        c.fontSize = fontSize
    end, baseZ + 1, screenSpace)
end

function InputPrompt:update(dt)
    self:draw()
end

function InputPrompt:setPosition(x, y)
    self._position = { x = x, y = y }
end

return InputPrompt
