# Render Local Callback — Lua API Guide

Attach a **Lua drawing callback** to an entity that renders in local space. This is useful for drawing custom shapes, outlines, meters, HUD overlays, or anything that should render inside the entity’s transform.

Local space origin `(0,0)` is the **top-left of the content rectangle**.

---

## Overview

* Callbacks are stored in `transform.RenderLocalCallback`.
* They receive `(width, height, isShadow)` each frame:

  * `width, height`: The content size (sprite-derived if present, or set manually).
  * `isShadow`: True if the engine is currently rendering the shadow pass.

Callbacks can run **before** the shader pipeline (to be processed with the entity’s sprite), or **after** the pipeline (to bypass shaders and render as overlays).

---

## API Reference

### `transform.install_local_callback`

Install or replace a local render callback.

#### Positional overload

```lua
transform.install_local_callback(entity, fn, after, width, height)
```

* `entity`: The target entity.
* `fn`: A Lua function `(w:number, h:number, isShadow:boolean)`.
* `after`: Boolean — run after pipeline if true.
* `width`, `height`: Fallback content size (if no sprite).

#### Table overload (recommended)

```lua
transform.install_local_callback(entity, fn, {
  after = false,    -- default false
  width = 64.0,     -- default 64
  height = 64.0     -- default 64
})
```

### `transform.remove_local_callback`

```lua
transform.remove_local_callback(entity)
```

Removes the local callback if present.

### `transform.has_local_callback`

```lua
local ok = transform.has_local_callback(entity)
```

Returns `true` if the entity has a callback.

### `transform.get_local_callback_info`

```lua
local info = transform.get_local_callback_info(entity)
-- { width:number, height:number, after:boolean } or nil
```

### `transform.set_local_callback_size`

```lua
transform.set_local_callback_size(entity, width, height)
```

Updates the stored `width`/`height` for the callback (used when no sprite defines size).

### `transform.set_local_callback_after_pipeline`

```lua
transform.set_local_callback_after_pipeline(entity, true_or_false)
```

Toggles whether the callback runs after the shader pipeline.

---

## Examples

### 1. Health bar drawn **before pipeline**

```lua
local function draw_healthbar(w, h, isShadow)
  if isShadow then return end
  local pad = 2
  local maxw = w - pad * 2
  local hp = math.max(0, math.min(1, self.hp / self.hp_max))

  -- background
  layer.RectanglePro(pad, h - 8, {maxw, 6}, {0,0}, 0, {0,0,0,128})
  -- fill
  layer.RectanglePro(pad+1, h - 7, {(maxw-2) * hp, 4}, {0,0}, 0, {255,64,64,220})
end

transform.install_local_callback(self.ent, draw_healthbar, {
  after = false,
  width = 64, height = 64
})
```

### 2. Selection outline drawn **after pipeline**

```lua
local function draw_outline(w, h, isShadow)
  if isShadow then return end
  layer.RectangleLinesPro(0, 0, w, h, {0,0}, 0, {255,255,0,255})
end

transform.install_local_callback(self.ent, draw_outline, {
  after = true,
  width = 96,
  height = 64
})
```

### 3. Shadow-aware silhouette

```lua
local function draw_silhouette(w, h, isShadow)
  local col = isShadow and {0,0,0,140} or {255,255,255,32}
  layer.RectanglePro(0, 0, {w, h}, {0,0}, 0, col)
end

transform.install_local_callback(self.ent, draw_silhouette, { after = true })
```

### 4. Modify settings at runtime

```lua
if boss_phase_2 then
  transform.set_local_callback_after_pipeline(self.ent, true)
else
  transform.set_local_callback_after_pipeline(self.ent, false)
end
```

### 5. Remove callback

```lua
transform.remove_local_callback(self.ent)
```

---

## Best Practices

* **Respect bounds:** Draw inside `[0..width] x [0..height]`. Engine translates origin for you.
* **Cheap callbacks:** They run every frame. Avoid allocations in hot paths.
* **Handle shadows:** If you don’t need them, just early-return when `isShadow` is true.
* **Sprite vs. fixed size:** If a sprite exists, `width/height` comes from the sprite. Otherwise, use `set_local_callback_size`.

---
