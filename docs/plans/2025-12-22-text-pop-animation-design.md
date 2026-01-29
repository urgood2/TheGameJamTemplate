# Text Builder Pop Animation Design

**Date:** 2025-12-22
**Status:** Ready for implementation

## Overview

Add a "pop in" entrance animation to the Text Builder system, allowing text to scale up from 0 with a bouncy oscillation effect. This mirrors the existing C++ DynamicMotion system but is implemented purely in Lua for lightweight, non-entity text.

## Design Decisions

1. **`:pop(intensity)` API** - Single method on Recipe with optional intensity (0-1) or config table
2. **Entrance animation only** - Pop handles entrance; existing `:fade()` handles exit
3. **Lua-based animation** - No C++ changes; leverages existing CBT matrix transform path
4. **Base transform approach** - Add `base_scale`/`base_rotation` to CBT that multiplies with per-character values

## API Design

### Recipe Configuration

```lua
-- Simple intensity (0-1)
Text.define()
    :content("[%d](color=red)")
    :pop(0.3)
    :fade()
    :lifespan(0.8)

-- Explicit config
Text.define()
    :content("WAVE 5")
    :pop({ scale = 0.4, rotation = 20, duration = 0.3 })
```

### Implementation

```lua
function RecipeMethods:pop(intensityOrConfig)
    if type(intensityOrConfig) == "table" then
        self._config.pop = {
            scale = intensityOrConfig.scale or 0.2,
            rotation = intensityOrConfig.rotation or 15,
            duration = intensityOrConfig.duration or 0.25,
        }
    else
        local intensity = intensityOrConfig or 0.3
        self._config.pop = {
            scale = intensity * 0.5,
            rotation = intensity * 30,
            duration = 0.25,
        }
    end
    return self
end
```

## Animation Logic

Mirrors C++ DynamicMotion formula:

```lua
local function updatePopAnimation(handle, dt)
    local anim = handle._anim
    if not anim.active then return end

    anim.elapsed = anim.elapsed + dt

    if anim.elapsed >= anim.duration then
        anim.active = false
        anim.currentScale = 1
        anim.currentRotation = 0
        return
    end

    local t = anim.elapsed / anim.duration
    local remaining = 1 - t
    local easing = remaining ^ 2.8

    local scaleOsc = math.sin(51.2 * anim.elapsed)
    local rotOsc = math.sin(46.3 * anim.elapsed)

    -- Scale ramps 0→1 quickly, then bounces
    local baseScale = math.min(1, t * 4)
    anim.currentScale = baseScale + (anim.scaleAmount * scaleOsc * easing)
    anim.currentRotation = anim.rotationAmount * rotOsc * easing
end
```

## CommandBufferText Changes

### New Fields

```lua
self.base_scale = args.base_scale or 1
self.base_rotation = args.base_rotation or 0
```

### Setter Methods

```lua
function CommandBufferText:set_base_scale(s)
    self.base_scale = s
end

function CommandBufferText:set_base_rotation(r)
    self.base_rotation = r
end
```

### Render Loop Modification

In `update()`, multiply base transform into per-character values:

```lua
local draw_scale = (ch.scale or 1) * (self.base_scale or 1)
local draw_scaleX = draw_scale * (ch.scaleX or 1)
local draw_scaleY = draw_scale * (ch.scaleY or 1)
local draw_rotation = (ch.rotation or 0) + (self.base_rotation or 0)
```

## Implementation Tasks

| # | Task | File(s) | Complexity |
|---|------|---------|------------|
| 1 | Add `base_scale` / `base_rotation` fields to CBT init | `command_buffer_text.lua` | Low |
| 2 | Add `set_base_scale()` / `set_base_rotation()` methods | `command_buffer_text.lua` | Low |
| 3 | Multiply/add base transform in CBT render loop | `command_buffer_text.lua` | Low |
| 4 | Add `:pop(intensity)` method to RecipeMethods | `text.lua` | Low |
| 5 | Add `_anim` state initialization in `_createHandle()` | `text.lua` | Low |
| 6 | Implement `updatePopAnimation()` function | `text.lua` | Medium |
| 7 | Call animation update + apply to CBT in `Text.update()` | `text.lua` | Low |
| 8 | Add unit tests for pop animation | `test_text_builder.lua` | Medium |
| 9 | Apply pop animation to wave announcements | `wave_visuals.lua` | Low |

## Testing Strategy

1. **Unit tests** - Mock CBT, verify animation state progression
2. **Visual test** - Demo scene with various pop intensities
3. **Integration test** - Wave announcements pop in smoothly

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  Text.define():pop(0.3):lifespan(0.8)                       │
│                    │                                         │
│                    ▼                                         │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  Handle._anim = { scaleAmount, rotationAmount, ... }    ││
│  └─────────────────────────────────────────────────────────┘│
│                    │                                         │
│         Text.update(dt) calls updatePopAnimation()          │
│                    │                                         │
│                    ▼                                         │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  handle._textRenderer:set_base_scale(currentScale)      ││
│  │  handle._textRenderer:set_base_rotation(currentRot)     ││
│  └─────────────────────────────────────────────────────────┘│
│                    │                                         │
│        Existing CBT matrix transform path renders            │
└─────────────────────────────────────────────────────────────┘
```

## References

- C++ DynamicMotion: `src/systems/transform/transform_functions.cpp:944-1025`
- Text Builder: `assets/scripts/core/text.lua`
- CommandBufferText: `assets/scripts/ui/command_buffer_text.lua`
- Wave visuals: `assets/scripts/combat/wave_visuals.lua`

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
