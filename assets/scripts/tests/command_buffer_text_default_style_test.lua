-- assets/scripts/tests/command_buffer_text_default_style_test.lua
-- Verifies ui.command_buffer_text supports base color names and default effects.

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

-- Mock globals used by command_buffer_text dependencies (behavior_script_v2, etc.)
local mock_registry = {
  create = function() return 1 end,
  destroy = function() end,
  add_script = function() end,
  valid = function() return true end,
  get = function() return nil end,
}
package.loaded["registry"] = mock_registry
_G.registry = mock_registry

_G.Transform = {}
_G.entity_cache = require("core.entity_cache")

_G.localization = {
  getTextWidthWithCurrentFont = function(text, size, spacing)
    return #text * size * 0.55 + ((spacing or 1) - 1)
  end,
  getFont = function() return "mock_font" end,
}

_G.layers = { ui = { DrawCommandSpace = { Screen = "screen" } } }
_G.layer = { DrawCommandSpace = { Screen = "screen" } }

_G.Col = function(r, g, b, a)
  return { r = r, g = g, b = b, a = a or 255 }
end

local CommandBufferText = require("ui.command_buffer_text")

local t = CommandBufferText({
  text = "Wave 1",
  w = 200,
  x = 0,
  y = 0,
  color = "gold",
  effects = "wave",
  layer = layers.ui,
})

assert(type(t.base_color) == "table", "Expected base_color to resolve to a Color-like table")
assert(t.base_color.r and t.base_color.g and t.base_color.b, "Expected base_color to have rgb fields")

assert(#t.characters > 0, "Expected characters to be parsed")
for _, ch in ipairs(t.characters) do
  assert(ch.effects and #ch.effects == 1, "Expected each character to have default effects")
  assert(ch.effects[1][1] == "wave", "Expected default effect 'wave' to be applied")
end

print("ok: command_buffer_text default style")

