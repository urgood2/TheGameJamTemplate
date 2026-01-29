# Hover Registry Design

**Date:** 2025-12-18
**Status:** Approved
**Purpose:** Enable hover tooltips for immediate-mode Lua UI elements (like TagSynergyPanel) without requiring ECS entities.

## Problem

Pure-Lua immediate-mode UIs draw via `command_buffer.queueDraw*()` without backing entities. The existing hover system requires `GameObject` components with `collisionEnabled` + `hoverEnabled`, which these UIs don't have.

## Solution

A lightweight Lua module (`HoverRegistry`) where immediate-mode UIs register hover regions each frame. Single `update()` call resolves hover state.

## API

```lua
local HoverRegistry = require("ui.hover_registry")

-- Register regions during draw (call every frame)
HoverRegistry.region({
    id = "unique_id",
    x = 100, y = 200,
    w = 300, h = 50,
    z = 100,  -- higher = on top when overlapping
    onHover = function() showTooltip() end,
    onUnhover = function() hideTooltip() end,
    data = {},  -- optional payload
})

-- Called once per frame after all UIs register regions
HoverRegistry.update()

-- Force clear on state transitions
HoverRegistry.clear()
```

## Implementation

### Core Module (`ui/hover_registry.lua`)

- **Double-buffer pattern**: `pendingRegions` fills during draw, swapped to `regions` on `update()`
- **Z-ordering**: Regions sorted descending by z; first hit wins
- **State tracking**: `currentHover` tracks active region, fires callbacks on change
- **pcall wrapping**: Callbacks can't crash the system

### Integration Points

1. **TagSynergyPanel.draw()**: Register row and segment regions with appropriate z-indices
2. **TagSynergyPanel.update()**: Remove hover-clearing code (lines 807-809)
3. **gameplay.lua**: Call `HoverRegistry.update()` after all UI draw calls
4. **State transitions**: Call `HoverRegistry.clear()` when leaving PLANNING_STATE

### Performance

- O(n log n) sort + O(n) scan per frame
- For UI-scale counts (<50 regions), this is <0.01ms
- No C++ changes required

## Not Included (YAGNI)

- Drag support
- Click handling (use existing entity system)
- Nested/hierarchical regions
- Animation/transitions

## Files to Create/Modify

1. **CREATE**: `assets/scripts/ui/hover_registry.lua`
2. **MODIFY**: `assets/scripts/ui/tag_synergy_panel.lua` - integrate HoverRegistry
3. **MODIFY**: `assets/scripts/core/gameplay.lua` - add HoverRegistry.update() call

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
