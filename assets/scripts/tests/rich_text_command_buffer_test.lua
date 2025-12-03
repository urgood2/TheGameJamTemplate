-- Lightweight harness to sanity-check ui.command_buffer_text in isolation.
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

-- Mock registry early (task/task and behavior_script_v2 depend on it)
local mock_registry = {
  create = function() return 1 end,
  destroy = function() end,
  add_script = function() end,
  valid = function() return true end,
  get = function() return nil end
}
package.loaded["registry"] = mock_registry
_G.registry = mock_registry

-- Globals expected by behavior_script_v2 / component_cache
_G.Transform = {}
_G.entity_cache = require("core.entity_cache")

-- Mock command buffer + layer stack
local collected = {}
_G.command_buffer = {
  queueDrawText = function(layer, fn, z, space)
    local cmd = {}
    fn(cmd)
    cmd._layer = layer
    cmd._z = z
    cmd._space = space
    table.insert(collected, cmd)
  end
}
_G.layers = { ui = "ui" }
_G.layer = { DrawCommandSpace = { Screen = "screen" } }

-- Simple localization shim
_G.localization = {
  getTextWidthWithCurrentFont = function(text, size, spacing)
    return #text * size * 0.55 + ((spacing or 1) - 1)
  end,
  getFont = function() return "mock_font" end
}

_G.Col = function(r, g, b, a)
  return { r = r, g = g, b = b, a = a or 255 }
end

local Text = require("ui.command_buffer_text")

local t = Text({
  text = "[Hello](color=Col(255,0,0)) world",
  w = 200,
  x = 100,
  y = 60,
  z = 5,
  layer = layers.ui,
  render_space = layer.DrawCommandSpace.Screen,
  font_size = 18
})

t:update(0.016)

assert(#collected > 0, "No draw commands were queued")

print("queued commands:", #collected)
for i = 1, math.min(3, #collected) do
  local c = collected[i]
  print(i, c.text, c.color and c.color.r or "?", c.x, c.y)
end
