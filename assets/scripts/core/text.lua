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
