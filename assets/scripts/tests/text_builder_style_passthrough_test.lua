-- assets/scripts/tests/text_builder_style_passthrough_test.lua
-- Verifies core.text forwards style config to ui.command_buffer_text.

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

-- Minimal layer mock for DrawCommandSpace mapping
_G.layers = {
  ui = {
    DrawCommandSpace = { Screen = "screen", World = "world" },
  },
}

local captured = nil
_G._MockCommandBufferText = function(args)
  captured = args
  return { _args = args }
end

local Text = require("core.text")

Text.define()
  :content("Wave 1")
  :size(32)
  :color("gold")
  :effects("wave")
  :align("center")
  :spawn()
  :at(100, 50)

assert(captured, "Expected CommandBufferText args to be captured")
assert(captured.color == "gold", "Expected core.text to pass through color")
assert(captured.effects == "wave", "Expected core.text to pass through effects")
assert(captured.alignment == "center", "Expected core.text to pass through alignment")

print("ok: core.text style passthrough")

