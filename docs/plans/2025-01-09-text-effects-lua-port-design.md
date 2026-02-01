# Text Effects Lua Port Design

## Overview

Port the C++ text effects system (`src/systems/text/text_effects.cpp`) to Lua, improving the API and adding 20 new visually-distinct effects focused on juicy/playful and magical/fantasy styles.

## Goals

1. **Full parity** with C++ character properties (rotation, scale, alpha, etc.)
2. **Smart defaults** with easy overrides (e.g., `[text](shake)` or `[text](shake=2,0.5)`)
3. **38 total effects**: 18 ported + 20 new
4. **Visually distinct** effects with color integration, not just positioning

## Character Model Extension

Current Lua character properties:
```lua
ch.x, ch.y      -- base position (from layout)
ch.ox, ch.oy    -- offset (from effects)
ch.color        -- RGBA color
ch.c            -- the character string
ch.i            -- character index
```

New properties to add:
```lua
ch.rotation     -- degrees (default 0)
ch.scale        -- uniform scale (default 1)
ch.scaleX       -- horizontal scale (default 1)
ch.scaleY       -- vertical scale (default 1)
ch.alpha        -- 0-255, separate from color.a for layering
ch.codepoint    -- override character display (for scramble)
ch.created_at   -- timestamp for one-shot effects
ch.effect_data  -- per-effect persistent state
```

## Effect Function Signature

```lua
function(ctx, dt, char, ...)
--       │    │    │    └─ variadic args (parsed from effect string)
--       │    │    └────── character table (with all properties)
--       │    └─────────── delta time
--       └──────────────── context: { time, char_count, text_w, text_h, first_frame }
```

## File Structure

```
assets/scripts/ui/
├── command_buffer_text.lua      -- Main text renderer (modify)
└── text_effects/
    ├── init.lua                 -- Effect registry + color helpers
    ├── continuous.lua           -- Looping effects
    ├── oneshot.lua              -- One-shot effects
    ├── static.lua               -- Non-animated effects
    └── magical.lua              -- New fantasy effects
```

Uses existing `util/easing.lua` for easing functions.

## Effects List

### Ported Effects (18)

#### Continuous (loop forever)
| Effect | Params | Defaults | Description |
|--------|--------|----------|-------------|
| `shake` | intensity, speed | 2, 10 | Random jitter |
| `float` | amp, speed, stagger | 5, 2.5, 0.4 | Vertical sine bob |
| `pulse` | min, max, speed, stagger | 0.8, 1.2, 2, 0 | Scale oscillation |
| `bump` | amp, speed, threshold, stagger | 3, 6, 0.8, 1.2 | Snap-jump vertical |
| `wiggle` | angle, speed, stagger | 10, 10, 1 | Rotation oscillation |
| `rotate` | speed, angle | 2, 25 | Gentle rotation wave |
| `spin` | speed, stagger | 1, 0.5 | Continuous 360 spin |
| `fade` | min, max, speed, stagger | 0.4, 1, 3, 0.5 | Alpha oscillation |
| `rainbow` | speed, stagger, step | 60, 10, 0 | HSV color cycling |
| `highlight` | speed, color, stagger | 4, "white", 0.5 | Color sweep wave |
| `expand` | min, max, speed, axis | 0.8, 1.2, 2, "y" | Axis-specific scale |

#### One-Shot (play once)
| Effect | Params | Defaults | Description |
|--------|--------|----------|-------------|
| `pop` | duration, stagger, mode | 0.3, 0.1, "in" | Scale in/out |
| `slide` | duration, stagger, dir, fade | 0.3, 0.1, "l", "in" | Slide from direction |
| `bounce` | height, gravity, stagger | 20, 700, 0.1 | Drop with physics |
| `scramble` | duration, stagger, rate | 0.4, 0.1, 15 | Random char cycling |

#### Static (no animation)
| Effect | Params | Description |
|--------|--------|-------------|
| `color` | color | Set character color |
| `fan` | angle | Spread rotation from center |

### New Effects (20)

#### Juicy/Playful (10)
| Effect | Params | Defaults | Visual Description |
|--------|--------|----------|-------------------|
| `jelly` | squash, speed, stagger | 0.3, 8, 0.2 | Squash/stretch + hue shift |
| `hop` | height, speed, stagger, color | 6, 5, 0.3, nil | Quick hops + shadow color |
| `rubberband` | intensity, speed, overshoot_tint | 1.5, 6, "yellow" | Overshoot scale + flash |
| `swing` | angle, speed, stagger | 20, 3, 0.2 | Pendulum + light/dark shift |
| `tremble` | intensity, speed, tint | 1, 30, "red" | Micro-shake + fear tint |
| `pop_rotate` | duration, stagger, spins, flash | 0.4, 0.08, 1, "white" | Spin-in + landing flash |
| `slam` | duration, stagger, scale, impact_color | 0.25, 0.05, 2, "orange" | Slam down + impact burst |
| `wave` | amp, speed, wavelength, gradient | 8, 4, 0.5, nil | Sine wave + color gradient |
| `heartbeat` | scale, speed, color | 1.3, 2, "pink" | Lub-dub + warm throb |
| `squish` | amount, speed, tint | 0.2, 8, nil | Horizontal squish + saturation |

#### Magical/Fantasy (10)
| Effect | Params | Defaults | Visual Description |
|--------|--------|----------|-------------------|
| `glow_pulse` | min, max, speed, color | 0.5, 1, 2, "gold" | Alpha pulse + glow color |
| `shimmer` | speed, stagger, colors | 12, 0.1, "silver,white" | Rapid flicker between colors |
| `float_drift` | amp_x, amp_y, speed, tint | 3, 5, 1.5, "cyan" | 2D float + ethereal tint |
| `sparkle` | chance, colors | 0.03, "white,gold,cyan" | Random flash from palette |
| `enchant` | speed, stagger, color | 3, 0.3, "purple" | Float + shimmer + rotation + magic color |
| `rise` | speed, fade, stagger, color | 30, true, 0.1, "white" | Drift up + fade to color |
| `waver` | amp, speed, stagger, heat_color | 3, 2, 0.15, "orange" | Heat shimmer + warm tint |
| `phase` | min, max, speed, ghost_color | 0.3, 1, 1.5, "lightblue" | Ghostly fade + spectral tint |
| `orbit` | radius, speed, stagger, trail_color | 3, 2, 0.5, nil | Orbit + trailing echo |
| `cascade` | delay, duration, start_color | 0.08, 0.3, "white" | Waterfall reveal bright→base |

#### Elemental Bonus (8)
| Effect | Params | Defaults | Visual Description |
|--------|--------|----------|-------------------|
| `burn` | speed, stagger | 2, 0.15 | Orange→red→black + shrivel |
| `freeze` | duration, stagger | 0.5, 0.1 | Blue tint spread + vibrate→stop |
| `poison` | speed, intensity | 3, 0.5 | Green/purple pulse + drip |
| `electric` | speed, jitter, color | 20, 2, "cyan" | Fast jitter + cyan flashes |
| `holy` | speed, stagger | 2, 0.2 | Gold glow + rise + scale pulse |
| `void` | speed, stagger | 1.5, 0.3 | Purple/black desaturate + inward pull |
| `fire` | speed, flicker | 8, 3 | Orange/yellow/red cycle + upward jitter |
| `ice` | speed | 1 | Cyan/white shimmer + horizontal crackle |

## Color Utilities

Named colors:
```lua
white, black, red, orange, yellow, gold, green, cyan, blue, purple, pink, silver
fire, ice, poison, holy, void, electric
```

Helper functions:
- `hsv_to_rgb(h, s, v)` — for rainbow, hue shifts
- `rgb_to_hsv(r, g, b)` — for modifications
- `shift_hue(color, degrees)` — hue rotation
- `lerp_color(c1, c2, t)` — color interpolation
- `get_color(name_or_color)` — resolve named colors

## Rendering Changes

In `command_buffer_text.lua` update method:
```lua
c.text = ch.codepoint or ch.c
c.rotation = ch.rotation
c.scaleX = ch.scale * ch.scaleX
c.scaleY = ch.scale * ch.scaleY
-- Alpha handled via color.a
```

## Dependencies

- `util/easing.lua` — existing easing library (outElastic, outBounce, outBack, etc.)
- `command_buffer.queueDrawText` — must support rotation, scaleX, scaleY

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
