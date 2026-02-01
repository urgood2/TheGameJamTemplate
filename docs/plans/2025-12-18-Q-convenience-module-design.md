# Q.lua - Quick Convenience Module

**Date:** 2025-12-18
**Status:** Approved for implementation

## Problem

Transform manipulation is the most common operation in the codebase, appearing 40+ times with verbose boilerplate:

```lua
-- Current: 4 lines to move an entity
local transform = component_cache.get(entity, Transform)
if transform then
    transform.actualX = x
    transform.actualY = y
end
```

Center-point calculations are similarly repeated:

```lua
local centerX = transform.visualX + transform.visualW / 2
local centerY = transform.visualY + transform.visualH / 2
```

## Solution

A minimal convenience module `core/Q.lua` with 3 focused functions:

| Function | Purpose | Returns |
|----------|---------|---------|
| `Q.move(entity, x, y)` | Set absolute position | `boolean` (success) |
| `Q.center(entity)` | Get center point | `x, y` or `nil, nil` |
| `Q.offset(entity, dx, dy)` | Move relative | `boolean` (success) |

## Design Decisions

1. **Single-letter module name "Q"** - Minimizes visual noise, suggests "quick" and "query"
2. **Transform-only scope** - Focused module, can expand later
3. **Nil-safe returns** - Functions handle invalid entities gracefully
4. **Boolean returns for mutations** - Allows chaining with `and`/`or`

## Usage

```lua
local Q = require("core.Q")

-- Move entity
Q.move(entity, 100, 200)

-- Get center for spawning effects
local cx, cy = Q.center(enemy)
if cx then spawn_explosion(cx, cy) end

-- Nudge entity
Q.offset(entity, 10, 0)  -- Move 10 pixels right
```

## Files Changed

- `assets/scripts/core/Q.lua` - New module
- `CLAUDE.md` - Add usage documentation

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
