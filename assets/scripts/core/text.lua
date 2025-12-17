-- assets/scripts/core/text.lua
--[[
================================================================================
TEXT BUILDER - Fluent API for Game Text
================================================================================
Particle-style API for text rendering with three layers:
- Recipe: Immutable text definition
- Spawner: Position configuration
- Handle: Lifecycle control

Usage:
    local Text = require("core.text")

    local recipe = Text.define()
        :content("[%d](color=red)")
        :size(20)
        :fade()
        :lifespan(0.8)

    recipe:spawn(25):above(enemy, 10)

    -- In game loop:
    Text.update(dt)
]]

-- Singleton guard
if _G.__TEXT_BUILDER__ then
    return _G.__TEXT_BUILDER__
end

local Text = {}

-- Active handles list (managed by Text.update)
Text._activeHandles = {}

--------------------------------------------------------------------------------
-- RECIPE
--------------------------------------------------------------------------------

local RecipeMethods = {}
RecipeMethods.__index = RecipeMethods

--- Set text content (template string, literal, or callback)
--- @param contentOrFn string|function Content template or callback
--- @return self
function RecipeMethods:content(contentOrFn)
    self._config.content = contentOrFn
    return self
end

--- Set font size
--- @param fontSize number Font size in pixels
--- @return self
function RecipeMethods:size(fontSize)
    self._config.size = fontSize
    return self
end

--- Set base color
--- @param colorName string Color name or Color object
--- @return self
function RecipeMethods:color(colorName)
    self._config.color = colorName
    return self
end

--- Set default effects for all characters
--- @param effectStr string Effect string (e.g., "shake=2;float")
--- @return self
function RecipeMethods:effects(effectStr)
    self._config.effects = effectStr
    return self
end

--- Enable alpha fade over lifespan
--- @return self
function RecipeMethods:fade()
    self._config.fade = true
    return self
end

--- Set fade-in percentage
--- @param pct number Percentage of lifespan for fade-in (0-1)
--- @return self
function RecipeMethods:fadeIn(pct)
    self._config.fadeInPct = pct
    return self
end

--- Set auto-destroy lifespan
--- @param minOrFixed number Lifespan in seconds, or min if max provided
--- @param max number? Max lifespan for random range
--- @return self
function RecipeMethods:lifespan(minOrFixed, max)
    self._config.lifespanMin = minOrFixed
    self._config.lifespanMax = max or minOrFixed
    return self
end

--- Set wrap width for multi-line text
--- @param w number Width in pixels
--- @return self
function RecipeMethods:width(w)
    self._config.width = w
    return self
end

--- Set anchor mode
--- @param mode string "center" | "topleft"
--- @return self
function RecipeMethods:anchor(mode)
    self._config.anchor = mode
    return self
end

--- Set text alignment
--- @param align string "left" | "center" | "right" | "justify"
--- @return self
function RecipeMethods:align(align)
    self._config.align = align
    return self
end

--- Set render layer
--- @param layerObj any Layer object
--- @return self
function RecipeMethods:layer(layerObj)
    self._config.layer = layerObj
    return self
end

--- Set z-index
--- @param zIndex number Z-index for draw order
--- @return self
function RecipeMethods:z(zIndex)
    self._config.z = zIndex
    return self
end

--- Set render space
--- @param spaceName string "screen" | "world"
--- @return self
function RecipeMethods:space(spaceName)
    self._config.space = spaceName
    return self
end

--- Set custom font
--- @param fontObj any Font object
--- @return self
function RecipeMethods:font(fontObj)
    self._config.font = fontObj
    return self
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Create a new text recipe
--- @return Recipe
function Text.define()
    local recipe = setmetatable({}, RecipeMethods)
    recipe._config = {
        size = 16,
        color = "white",
        anchor = "center",
        space = "screen",
        z = 0,
    }
    return recipe
end

_G.__TEXT_BUILDER__ = Text
return Text
