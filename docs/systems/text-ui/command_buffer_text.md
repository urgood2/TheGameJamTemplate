# Command Buffer Text Renderer

Command-buffer–friendly rich text renderer for Lua (`ui.command_buffer_text`).

## What it is
- Per-character markup parser: `[text](effect=arg1,arg2;other=...)`.
- Queues `command_buffer.queueDrawText` calls (no immediate drawing).
- Plays nicely with `behavior_script_v2` (can follow an attached entity transform).

## When to use it
- UI or world-space text that needs per-character effects (color, shake, custom).
- Anywhere you already use the layer command buffer and want text batching.

## Basics
```lua
local Text = require("ui.command_buffer_text")

local t = Text({
  text = "[Hello](color=Col(255,0,0)) world",
  w = 200,                -- wrap width (required)
  x = 320, y = 180,       -- anchor position
  z = 12,                 -- z-order in the layer
  layer = layers.ui,      -- target layer
  render_space = layer.DrawCommandSpace.Screen,
  font_size = 18,
  alignment = "left",     -- left|center|right|justify
  anchor = "center",      -- center or topleft
  text_effects = { ... }, -- optional custom effects
})

-- Call once per frame (update_all handles this for MonoBehaviors):
t:update(dt)

-- Update content/width on the fly:
t:set_text("new text")
t:set_width(260)
```

## Effect functions
- Signature: `fn(self, dt, char, ...)`.
- Defaults:
  - `color(dt, _, char, color)` → sets `char.color`.
  - `shake(dt, char, intensity, duration)` → random per-frame offset with optional decay.
- Add/override via `text_effects = { myeffect = function(...) ... end }`.

## Layout
- Required `w` sets wrap width.
- Alignment: `left|center|right|justify`.
- Line breaks: `|` or `\n`.
- Anchor: `center` (default) or `topleft`.

## Integration notes
- Follows attached entity transform (`follow_transform=true` by default). Set `false` to keep static screen coords.
- Uses `localization.getFont()` / `getTextWidthWithCurrentFont` if available; falls back to a simple width heuristic when mocked.
- Resets character offsets each frame before applying effects.

## Testing
- Harness: `assets/scripts/tests/rich_text_command_buffer_test.lua` (mocks command_buffer/layers/localization). Run with:
  ```
  lua assets/scripts/tests/rich_text_command_buffer_test.lua
  ```
