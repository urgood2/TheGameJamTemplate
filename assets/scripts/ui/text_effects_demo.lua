-- assets/scripts/ui/text_effects_demo.lua
-- Demo script for testing text effects
-- Usage: local demo = require("ui.text_effects_demo")
--        demo.show_all()

local Text = require("ui.command_buffer_text")
local text_effects = require("ui.text_effects")

local demo = {}
local active_demos = {}

function demo.create_sample(effect_name, y_offset)
  local sample_text = string.format("[%s](%s)", effect_name, effect_name)

  local t = Text({
    text = sample_text,
    w = 400,
    x = 320,
    y = 100 + (y_offset or 0),
    layer = layers and layers.ui,
    font_size = 24,
    alignment = "center",
    anchor = "center",
  })

  return t
end

function demo.show_all()
  -- Clear existing demos
  active_demos = {}

  local effects_list = text_effects.list()
  local y = 0
  local spacing = 35

  for _, name in ipairs(effects_list) do
    local t = demo.create_sample(name, y)
    table.insert(active_demos, t)
    y = y + spacing
  end

  return active_demos
end

function demo.show_category(category)
  active_demos = {}

  local categories = {
    static = { "color", "fan" },
    continuous = { "shake", "float", "pulse", "bump", "wiggle", "rotate", "spin", "fade", "rainbow", "highlight", "expand" },
    oneshot = { "pop", "slide", "bounce", "scramble" },
    juicy = { "jelly", "hop", "rubberband", "swing", "tremble", "pop_rotate", "slam", "wave", "heartbeat", "squish" },
    magical = { "glow_pulse", "shimmer", "float_drift", "sparkle", "enchant", "rise", "waver", "phase", "orbit", "cascade" },
    elemental = { "burn", "freeze", "poison", "electric", "holy", "void", "fire", "ice" },
  }

  local effects = categories[category]
  if not effects then return end

  local y = 0
  for _, name in ipairs(effects) do
    local t = demo.create_sample(name, y)
    table.insert(active_demos, t)
    y = y + 35
  end

  return active_demos
end

function demo.update_all(dt)
  for _, t in ipairs(active_demos) do
    t:update(dt)
  end
end

function demo.clear()
  active_demos = {}
end

return demo
