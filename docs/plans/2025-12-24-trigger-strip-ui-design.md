# Trigger Strip UI Design

**Date:** 2025-12-24
**Status:** Approved

## Overview

A left-side UI element during action phase that displays all equipped trigger cards with interactive hover effects and cooldown visualization.

## Goals

- Provide constant visibility into equipped triggers during action phase
- Create a pleasing, polished interaction with wave-based hover effects
- Show cooldown state via radial pie overlay
- Highlight trigger activations with flash + pop feedback
- Support future interactivity (click actions, drag reordering, etc.)

## Design Decisions

| Aspect | Decision |
|--------|----------|
| Content | All equipped triggers (one per wand) |
| Layout | Evenly spaced vertically, centered on screen |
| Size | 75% scale (60×84 pixels) |
| Position | Half-peeking from left edge (~30px visible at rest) |
| Interaction | Wave ripple affecting both scale and slide-out |
| Jiggle | DynamicMotion triggered on focus change |
| Cooldown | Radial drain pie shader with dim overlay |
| Activation | Flash + scale pop when trigger fires |
| Tooltips | Delayed (0.3s) appearance on focus |
| Lifecycle | Persistent entities with state-based visibility |

## Architecture

### New File

`assets/scripts/ui/trigger_strip_ui.lua`

### Data Structure

```lua
local strip_entries = {}  -- Ordered list of trigger card entries

-- Each entry:
{
    entity = <entityId>,           -- The strip's visual entity
    sourceCardEntity = <entityId>, -- Original trigger card in wand board
    wandId = <wandId>,             -- Which wand this belongs to
    triggerId = "every_N_seconds", -- Trigger type ID
    centerY = 200,                 -- Computed vertical position
    influence = 0,                 -- Current wave influence (0-1)
}
```

### Lifecycle

Instead of create/destroy cycles, entities persist and use state-based visibility:

```lua
TriggerStripUI.ensureEntities()   -- Create/sync entities (called when wands change)
TriggerStripUI.show()             -- Show strip (entering action phase)
TriggerStripUI.hide()             -- Hide strip (leaving action phase)
TriggerStripUI.sync()             -- Ensure parity with wand trigger boards
```

**Sync Trigger Points:**
- `signal.register("deck_changed", TriggerStripUI.sync)`
- `signal.register("wand_created", TriggerStripUI.sync)`
- `signal.register("wand_destroyed", TriggerStripUI.sync)`

## Wave Interaction System

### Core Wave Math

Distance from mouse Y to each card's center Y, with Gaussian-like falloff:

```lua
local WAVE_RADIUS = 80        -- How far the wave extends (pixels)
local MAX_SCALE_BUMP = 0.25   -- Focused card: 1.0 -> 1.25
local MAX_SLIDE_OUT = 40      -- Focused card slides out 40px extra
local PEEK_X = -30            -- Resting position (half-hidden)

function calculateWaveInfluence(cardCenterY, mouseY)
    local distance = math.abs(cardCenterY - mouseY)
    if distance > WAVE_RADIUS then return 0 end

    local t = distance / WAVE_RADIUS
    return 0.5 * (1 + math.cos(t * math.pi))  -- 1.0 at center, 0 at edge
end
```

### Transform Updates

Uses Transform's built-in `actual` -> `visual` interpolation (no custom springs):

```lua
for _, entry in ipairs(strip_entries) do
    local influence = calculateWaveInfluence(entry.centerY, mouseY)
    local transform = component_cache.get(entry.entity, Transform)

    -- Slide: set actualX, visualX follows smoothly
    transform.actualX = PEEK_X + (MAX_SLIDE_OUT * influence)

    -- Scale: set actualScale, visualScale follows
    local scale = 1.0 + (MAX_SCALE_BUMP * influence)
    transform.actualScaleX = scale
    transform.actualScaleY = scale
end
```

### Jiggle on Focus Change

```lua
if focusedEntry ~= previousFocusedEntry then
    transform.InjectDynamicMotion(focusedEntry.entity, 0, 1)
    previousFocusedEntry = focusedEntry
end
```

## Cooldown Pie Shader

### Shader File

`assets/shaders/cooldown_pie.fs`

Atlas-aware UV handling (following `3d_skew` pattern):

```glsl
uniform float cooldown_progress;  // 0.0 = ready, 1.0 = full cooldown
uniform float dim_amount;         // e.g., 0.4
uniform float flash_intensity;    // 0.0 = normal, 1.0 = full flash
uniform vec4 sprite_bounds;       // Atlas bounds

vec2 toLocalUV(vec2 atlasUV) {
    return (atlasUV - sprite_bounds.xy) / sprite_bounds.zw;
}

void main() {
    vec2 localUV = toLocalUV(fragTexCoord);
    vec2 centered = localUV - 0.5;

    float angle = atan(centered.y, centered.x);
    float normalizedAngle = fract((angle / (2.0 * PI)) + 0.75);  // 0 at top, clockwise

    float inCooldown = step(normalizedAngle, cooldown_progress);

    vec4 texColor = texture(texture0, fragTexCoord);
    vec3 dimmed = texColor.rgb * (1.0 - dim_amount * inCooldown);
    vec3 finalRGB = mix(dimmed, vec3(1.0), flash_intensity * 0.6);

    finalColor = vec4(finalRGB, texColor.a);
}
```

### Pipeline Composition

Cooldown pie stacks on top of existing card shaders:

```lua
ShaderBuilder.for_entity(entry.entity)
    :add("3d_skew_holo", { skew_amount = 0.1 })
    :add("cooldown_pie", { cooldown_progress = 0, dim_amount = 0.4 })
    :apply()
```

## Activation Feedback

When a trigger fires:

```lua
signal.register("trigger_activated", function(wandId, triggerId)
    local entry = findEntryByWandId(wandId)
    if not entry then return end

    -- Pop: quick scale bump
    local transform = component_cache.get(entry.entity, Transform)
    transform.actualScaleX = 1.4
    transform.actualScaleY = 1.4

    -- Jiggle
    transform.InjectDynamicMotion(entry.entity, 0.3, 1.5)

    -- Flash via shader uniform
    shader_system.setUniform(entry.entity, "cooldown_pie", "flash_intensity", 1.0)

    timer.after_opts({
        delay = 0.15,
        action = function()
            shader_system.setUniform(entry.entity, "cooldown_pie", "flash_intensity", 0.0)
        end,
        tag = "trigger_flash_" .. entry.entity
    })
end)
```

## Tooltip System

Delayed tooltip on focus (0.3s delay to prevent flicker):

```lua
local TOOLTIP_DELAY = 0.3

function updateTooltipState(focusedEntry)
    if focusedEntry ~= activeTooltipEntry then
        -- Hide existing tooltip
        if activeTooltipEntry then
            hideSimpleTooltip("trigger_strip_" .. activeTooltipEntry.entity)
        end

        -- Cancel pending tooltip
        if tooltipTimer then
            timer.cancel(tooltipTimer)
        end

        activeTooltipEntry = focusedEntry

        if focusedEntry then
            tooltipTimer = timer.after_opts({
                delay = TOOLTIP_DELAY,
                action = function()
                    showTriggerTooltip(focusedEntry)
                end,
                tag = "trigger_strip_tooltip"
            })
        end
    end
end
```

## Integration Points

In `gameplay.lua`:

```lua
-- In initActionPhase():
TriggerStripUI.show()

-- In endActionPhase() / startPlanningPhase():
TriggerStripUI.hide()

-- In main update loop (when ACTION_STATE active):
TriggerStripUI.update(dt)

-- Signal registrations (once at init):
signal.register("deck_changed", TriggerStripUI.sync)
signal.register("trigger_activated", TriggerStripUI.onTriggerActivated)
```

## Constants

```lua
local CARD_WIDTH = 60           -- 75% of 80
local CARD_HEIGHT = 84          -- 75% of 112
local PEEK_X = -30              -- Resting X position
local WAVE_RADIUS = 80          -- Wave influence radius
local MAX_SCALE_BUMP = 0.25     -- Max scale increase (1.0 -> 1.25)
local MAX_SLIDE_OUT = 40        -- Max slide-out distance
local STRIP_HOVER_ZONE = 100    -- Mouse X threshold for interaction
local TOOLTIP_DELAY = 0.3       -- Seconds before tooltip appears
local VERTICAL_SPACING = 20     -- Gap between cards
```

## Future Extensibility

The design supports future additions:
- Click actions on focused card
- Drag to reorder triggers
- Right-click context menu
- Keyboard navigation through the strip

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
