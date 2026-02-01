# Popup Helpers

Quick damage/heal numbers with automatic styling and positioning.

## Basic Usage

```lua
local popup = require("core.popup")

-- Damage numbers (red, descending)
popup.damage(entity, 25)

-- Heal numbers (green, ascending)
popup.heal(entity, 50)

-- Custom text above entity
popup.above(entity, "CRITICAL!", { color = "gold" })
popup.above(entity, "+10 XP", { color = "cyan", offset = 20 })
```

## Features

- Automatically uses visual position (not physics position)
- Built-in animations (pop, fade, drift)
- Color-coded by type (damage=red, heal=green)
- Offsets prevent overlap when spawning multiple popups

## Options

```lua
popup.above(entity, text, {
    color = "gold",   -- Named color or hex
    offset = 20,      -- Additional Y offset
    size = 24,        -- Font size
    duration = 0.8,   -- Lifespan
})
```

## Named Colors

`red`, `gold`, `green`, `blue`, `cyan`, `purple`, `fire`, `ice`, `poison`, `holy`, `void`, `electric`

## Equivalent Text Builder Code

`popup.damage(entity, 25)` is equivalent to:

```lua
local vx, vy = Q.visualCenter(entity)
Text.define()
    :content("[25](color=red;pop=0.2)")
    :size(20)
    :fade()
    :lifespan(0.8)
    :spawn()
    :at(vx, vy - 10)
```

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
