--[[
================================================================================
TUTORIAL DIALOGUE SYSTEM
================================================================================
A configurable dialogue system for tutorials featuring:
- Animated speaker sprites with shaders and jiggle effects
- Styled dialogue boxes with typewriter text
- Spotlight/focus effects
- Input prompts

Usage:
    local TutorialDialogue = require("tutorial.dialogue")

    -- Create a dialogue session
    local dialogue = TutorialDialogue.new({
        speaker = {
            sprite = "tutorial_guide.png",
            position = "left",  -- "left", "right", "center"
            shaders = {},  -- e.g. { "3d_skew_holo" }
            size = { 128, 128 },
        },
        box = {
            position = "bottom",  -- "bottom", "top", "center"
            width = 600,
            style = "default",  -- see styles below
        },
        spotlight = {
            enabled = true,
            position = { x = 0.5, y = 0.5 },  -- UV coords
            size = 0.3,
        },
    })
    
    -- Show dialogue
    dialogue:say("Hello, adventurer!", {
        onComplete = function() print("done") end,
        typingSpeed = 0.05,  -- seconds per character
    })
    
    -- Chain dialogues
    dialogue:say("Welcome to the tutorial.")
           :say("Let me show you the basics.")
           :waitForInput("space")
           :say("Press WASD to move.")
           :start()

Dependencies:
    - core/timer (timer.sequence)
    - core/entity_builder
    - core/shader_builder
    - core/text (TextBuilder)
    - ui/ui_syntax_sugar (DSL)
    - ui/command_buffer_text
]]

local TutorialDialogue = {}
TutorialDialogue.__index = TutorialDialogue

-- Sub-modules
local Speaker = require("tutorial.dialogue.speaker")
local DialogueBox = require("tutorial.dialogue.dialogue_box")
local Spotlight = require("tutorial.dialogue.spotlight")
local InputPrompt = require("tutorial.dialogue.input_prompt")

-- Dependencies
local timer = require("core.timer")
local entity_cache = require("core.entity_cache")

--------------------------------------------------------------------------------
-- DEFAULT CONFIGURATION
--------------------------------------------------------------------------------

TutorialDialogue.DEFAULTS = {
    speaker = {
        sprite = nil,
        position = "left",        -- "left", "right", "center"
        shaders = {},
        size = { 96, 96 },
        jiggle = {
            enabled = true,
            intensity = 0.08,
            speed = 8,
        },
        idleFloat = {
            enabled = true,
            amplitude = 4,
            speed = 1.5,
        },
    },
    box = {
        position = "bottom",      -- "bottom", "top", "center"
        width = 500,
        padding = 16,
        style = "default",
        nameplate = true,
    },
    text = {
        fontSize = 18,
        typingSpeed = 0.03,       -- seconds per character
        color = "white",
        effects = {},
    },
    spotlight = {
        enabled = false,
        size = 0.4,
        feather = 0.1,
        position = nil,           -- auto-calculated if nil
        dimColor = { 0, 0, 0, 180 },
        delay = 0,                -- delay before spotlight activates (seconds)
    },
    input = {
        prompt = "Press [SPACE] to continue",
        key = "space",
        showDelay = 0.5,          -- delay after text finishes
    },
    timing = {
        fadeInDuration = 0.25,
        fadeOutDuration = 0.2,
        pauseBetweenLines = 0.1,
    },
}

-- Box styles (color presets)
TutorialDialogue.STYLES = {
    default = {
        background = { 20, 25, 35, 230 },
        border = { 80, 100, 140, 255 },
        nameplateBg = { 50, 60, 80, 255 },
    },
    dark = {
        background = { 10, 12, 18, 245 },
        border = { 40, 50, 70, 255 },
        nameplateBg = { 30, 35, 50, 255 },
    },
    light = {
        background = { 240, 235, 220, 240 },
        border = { 180, 160, 130, 255 },
        nameplateBg = { 200, 180, 150, 255 },
    },
    magical = {
        background = { 30, 20, 50, 235 },
        border = { 150, 100, 200, 255 },
        nameplateBg = { 80, 50, 120, 255 },
    },
}

--------------------------------------------------------------------------------
-- CONSTRUCTOR
--------------------------------------------------------------------------------

--- Create a new TutorialDialogue session.
--- @param config table Configuration options (merged with DEFAULTS)
--- @return TutorialDialogue
function TutorialDialogue.new(config)
    local self = setmetatable({}, TutorialDialogue)
    
    config = config or {}
    
    -- Deep merge configuration with defaults
    self.config = TutorialDialogue._mergeConfig(TutorialDialogue.DEFAULTS, config)
    
    -- Resolve style
    if type(self.config.box.style) == "string" then
        self.config.box.colors = TutorialDialogue.STYLES[self.config.box.style]
            or TutorialDialogue.STYLES.default
    end
    
    -- State
    self._active = false
    self._queue = {}              -- queued dialogue actions
    self._currentAction = nil
    self._group = "tutorial_dialogue_" .. tostring(os.time()) .. "_" .. math.random(1, 9999)
    
    -- Components (created on show)
    self._speaker = nil
    self._box = nil
    self._spotlight = nil
    self._prompt = nil
    
    return self
end

--- Deep merge two config tables
--- @param defaults table
--- @param overrides table
--- @return table
function TutorialDialogue._mergeConfig(defaults, overrides)
    local result = {}
    for k, v in pairs(defaults) do
        if type(v) == "table" and type(overrides[k]) == "table" then
            result[k] = TutorialDialogue._mergeConfig(v, overrides[k])
        elseif overrides[k] ~= nil then
            result[k] = overrides[k]
        else
            result[k] = v
        end
    end
    -- Include keys only in overrides
    for k, v in pairs(overrides) do
        if result[k] == nil then
            result[k] = v
        end
    end
    return result
end

--------------------------------------------------------------------------------
-- FLUENT API (CHAIN BUILDING)
--------------------------------------------------------------------------------

--- Queue a dialogue line.
--- @param text string The text to display
--- @param opts table? Optional overrides (typingSpeed, effects, speaker, etc.)
--- @return TutorialDialogue self for chaining
function TutorialDialogue:say(text, opts)
    table.insert(self._queue, {
        type = "say",
        text = text,
        opts = opts or {},
    })
    return self
end

--- Queue speaker change (for multi-character dialogues).
--- @param speakerConfig table Speaker configuration
--- @return TutorialDialogue self
function TutorialDialogue:setSpeaker(speakerConfig)
    table.insert(self._queue, {
        type = "set_speaker",
        config = speakerConfig,
    })
    return self
end

--- Queue a wait for specific input.
--- @param key string Key to wait for (e.g., "space", "enter", "mouse_click")
--- @param prompt string? Custom prompt text
--- @return TutorialDialogue self
function TutorialDialogue:waitForInput(key, prompt)
    table.insert(self._queue, {
        type = "wait_input",
        key = key or "space",
        prompt = prompt,
    })
    return self
end

--- Queue a timed pause.
--- @param duration number Seconds to wait
--- @return TutorialDialogue self
function TutorialDialogue:wait(duration)
    table.insert(self._queue, {
        type = "wait",
        duration = duration,
    })
    return self
end

--- Queue spotlight focus on a position or entity.
--- @param target table|userdata {x, y} position or entity ID
--- @param size number? Spotlight radius (UV space 0-1)
--- @return TutorialDialogue self
function TutorialDialogue:focusOn(target, size)
    table.insert(self._queue, {
        type = "focus",
        target = target,
        size = size,
    })
    return self
end

--- Queue spotlight disable.
--- @return TutorialDialogue self
function TutorialDialogue:unfocus()
    table.insert(self._queue, {
        type = "unfocus",
    })
    return self
end

--- Queue a custom callback.
--- @param fn function Callback to execute
--- @return TutorialDialogue self
function TutorialDialogue:call(fn)
    table.insert(self._queue, {
        type = "call",
        fn = fn,
    })
    return self
end

--- Set callback for when dialogue completes.
--- @param fn function Callback
--- @return TutorialDialogue self
function TutorialDialogue:onComplete(fn)
    self._onComplete = fn
    return self
end

--------------------------------------------------------------------------------
-- EXECUTION
--------------------------------------------------------------------------------

--- Start executing the dialogue queue.
--- @return TutorialDialogue self
function TutorialDialogue:start()
    if self._active then
        log_warn("[TutorialDialogue] Already active, ignoring start()")
        return self
    end

    self._active = true
    self:_createComponents()
    self:_showComponents()
    self:_startUpdateLoop()
    self:_processNext()

    return self
end

--- Start the per-frame update loop for rendering components
function TutorialDialogue:_startUpdateLoop()
    timer.every(0.016, function()
        if not self._active then return end
        self:_update(0.016)
    end, 0, false, nil, nil, self._group .. "_update")
end

--- Per-frame update - renders all visual components
--- (Spotlight uses layer shader, no draw needed)
function TutorialDialogue:_update(dt)
    if self._speaker then
        self._speaker:update(dt)
    end
    if self._box then
        self._box:update(dt)
    end
    if self._prompt then
        self._prompt:update(dt)
    end
end

--- Skip current dialogue line (if typing) or advance to next.
function TutorialDialogue:skip()
    if not self._active then return end
    
    if self._box and self._box:isTyping() then
        self._box:skipTyping()
    else
        self:_processNext()
    end
end

--- Stop and cleanup the dialogue.
function TutorialDialogue:stop()
    if not self._active then return end

    self._active = false
    timer.kill_group(self._group)
    timer.kill_group(self._group .. "_update")
    self:_hideComponents()
    self:_destroyComponents()

    self._queue = {}
    self._currentAction = nil
end

--------------------------------------------------------------------------------
-- INTERNAL: COMPONENT MANAGEMENT
--------------------------------------------------------------------------------

function TutorialDialogue:_createComponents()
    -- Speaker
    if self.config.speaker.sprite then
        self._speaker = Speaker.new(self.config.speaker, self._group)
    end
    
    -- Dialogue box
    self._box = DialogueBox.new(self.config.box, self.config.text, self._group)
    
    -- Spotlight
    if self.config.spotlight.enabled then
        self._spotlight = Spotlight.new(self.config.spotlight, self._group)
    end
    
    -- Input prompt (created per-use)
    self._prompt = nil
end

function TutorialDialogue:_showComponents()
    local fadeIn = self.config.timing.fadeInDuration
    local spotlightDelay = self.config.spotlight.delay or 0

    -- Show speaker and box FIRST, then spotlight after delay
    timer.sequence(self._group)
        :do_now(function()
            if self._speaker then self._speaker:show(fadeIn * 0.7) end
        end)
        :wait(fadeIn * 0.3)
        :do_now(function()
            if self._box then self._box:show(fadeIn * 0.5) end
        end)
        :wait(spotlightDelay)
        :do_now(function()
            if self._spotlight then self._spotlight:show(fadeIn) end
        end)
        :start()
end

function TutorialDialogue:_hideComponents()
    local fadeOut = self.config.timing.fadeOutDuration
    
    timer.sequence(self._group)
        :do_now(function()
            if self._prompt then self._prompt:hide() end
            if self._box then self._box:hide(fadeOut) end
        end)
        :wait(fadeOut * 0.5)
        :do_now(function()
            if self._speaker then self._speaker:hide(fadeOut * 0.5) end
        end)
        :wait(fadeOut * 0.3)
        :do_now(function()
            if self._spotlight then self._spotlight:hide(fadeOut * 0.5) end
        end)
        :start()
end

function TutorialDialogue:_destroyComponents()
    timer.after(self.config.timing.fadeOutDuration + 0.1, function()
        if self._speaker then
            self._speaker:destroy()
            self._speaker = nil
        end
        if self._box then
            self._box:destroy()
            self._box = nil
        end
        if self._spotlight then
            self._spotlight:destroy()
            self._spotlight = nil
        end
        if self._prompt then
            self._prompt:destroy()
            self._prompt = nil
        end
    end, nil, self._group)
end

--------------------------------------------------------------------------------
-- INTERNAL: QUEUE PROCESSING
--------------------------------------------------------------------------------

function TutorialDialogue:_processNext()
    if #self._queue == 0 then
        self:_finish()
        return
    end
    
    self._currentAction = table.remove(self._queue, 1)
    local action = self._currentAction
    
    if action.type == "say" then
        self:_executeSay(action)
    elseif action.type == "set_speaker" then
        self:_executeSetSpeaker(action)
    elseif action.type == "wait_input" then
        self:_executeWaitInput(action)
    elseif action.type == "wait" then
        self:_executeWait(action)
    elseif action.type == "focus" then
        self:_executeFocus(action)
    elseif action.type == "unfocus" then
        self:_executeUnfocus(action)
    elseif action.type == "call" then
        self:_executeCall(action)
    else
        log_warn("[TutorialDialogue] Unknown action type: " .. tostring(action.type))
        self:_processNext()
    end
end

function TutorialDialogue:_executeSay(action)
    local text = action.text
    local opts = action.opts

    -- Play a random tutorial talk sound
    local soundIndex = math.random(1, 6)
    playSoundEffect("effects", "tutorial-talk-" .. soundIndex, 1.0)

    -- Update speaker name if provided
    if opts.speaker and self._box then
        self._box:setName(opts.speaker)
    end

    -- Start jiggle on speaker
    if self._speaker then
        self._speaker:startTalking()
    end
    
    -- Start typing
    local typingSpeed = opts.typingSpeed or self.config.text.typingSpeed
    
    self._box:setText(text, {
        typingSpeed = typingSpeed,
        effects = opts.effects,
        onComplete = function()
            -- Stop jiggle
            if self._speaker then
                self._speaker:stopTalking()
            end
            
            -- Show input prompt after delay
            local showDelay = self.config.input.showDelay
            timer.after(showDelay, function()
                self:_showInputPrompt(action.opts.waitKey or self.config.input.key)
            end, nil, self._group)
        end,
    })
end

function TutorialDialogue:_showInputPrompt(key)
    if not self._active then return end
    
    local prompt = self.config.input.prompt
    self._prompt = InputPrompt.new({
        key = key,
        text = prompt,
        position = self._box:getPromptPosition(),
    }, self._group)
    
    self._prompt:show()
    self._prompt:waitForPress(function()
        self._prompt:hide()
        timer.after(0.1, function()
            self:_processNext()
        end, nil, self._group)
    end)
end

function TutorialDialogue:_executeSetSpeaker(action)
    -- Fade out current speaker
    if self._speaker then
        self._speaker:hide(0.2)
        timer.after(0.25, function()
            self._speaker:destroy()
            
            -- Create new speaker
            self._speaker = Speaker.new(action.config, self._group)
            self._speaker:show(0.2)
            
            timer.after(0.25, function()
                self:_processNext()
            end, nil, self._group)
        end, nil, self._group)
    else
        self._speaker = Speaker.new(action.config, self._group)
        self._speaker:show(0.2)
        timer.after(0.25, function()
            self:_processNext()
        end, nil, self._group)
    end
end

function TutorialDialogue:_executeWaitInput(action)
    self._prompt = InputPrompt.new({
        key = action.key,
        text = action.prompt or self.config.input.prompt,
        position = self._box:getPromptPosition(),
    }, self._group)
    
    self._prompt:show()
    self._prompt:waitForPress(function()
        self._prompt:hide()
        timer.after(0.1, function()
            self:_processNext()
        end, nil, self._group)
    end)
end

function TutorialDialogue:_executeWait(action)
    timer.after(action.duration, function()
        self:_processNext()
    end, nil, self._group)
end

function TutorialDialogue:_executeFocus(action)
    if not self._spotlight then
        self._spotlight = Spotlight.new(self.config.spotlight, self._group)
        self._spotlight:show(0.3)
    end
    
    self._spotlight:focusOn(action.target, action.size)
    
    timer.after(0.3, function()
        self:_processNext()
    end, nil, self._group)
end

function TutorialDialogue:_executeUnfocus(action)
    if self._spotlight then
        self._spotlight:hide(0.3)
    end
    
    timer.after(0.35, function()
        self:_processNext()
    end, nil, self._group)
end

function TutorialDialogue:_executeCall(action)
    if action.fn then
        action.fn()
    end
    self:_processNext()
end

function TutorialDialogue:_finish()
    self._active = false
    timer.kill_group(self._group .. "_update")

    self:_hideComponents()

    timer.after(self.config.timing.fadeOutDuration + 0.15, function()
        self:_destroyComponents()

        if self._onComplete then
            self._onComplete()
        end
    end, nil, self._group)
end

--------------------------------------------------------------------------------
-- STATIC HELPERS
--------------------------------------------------------------------------------

--- Quick single-line dialogue (fire-and-forget).
--- @param text string Text to display
--- @param opts table? Configuration
--- @return TutorialDialogue
function TutorialDialogue.quick(text, opts)
    opts = opts or {}
    return TutorialDialogue.new(opts)
        :say(text)
        :start()
end

return TutorialDialogue
