# Tooltip Unification Design

## Overview

Unify all tooltips to use the existing DSL-based pattern from card/player stat tooltips in `gameplay.lua`. Fix spacing issues, ensure JetBrains font everywhere, and provide a clean API for simple title+description tooltips.

## Goals

1. Single code path for all tooltips (DSL-based)
2. JetBrains Mono font consistently applied
3. Fix spacing: more outer padding, tighter pills
4. Support per-element font overrides (future)
5. Support coded text parsing (colors, icons, effects)
6. Delete legacy `showTooltip()` system entirely

## Architecture

### Keep in `gameplay.lua`

No new files. The existing tooltip infrastructure stays in `gameplay.lua`:
- `tooltipStyle` configuration table
- `makeTooltipPill()`, `makeTooltipValueBox()`, `makeTooltipRow()` helpers
- `snapTooltipVisual()`, positioning functions
- Card and player stat tooltip implementations

### New Helper: `makeSimpleTooltip(title, body, opts)`

For title+description tooltips (jokers, avatars, creatures):

```lua
function makeSimpleTooltip(title, body, opts)
    opts = opts or {}
    local rows = {}

    -- Title pill (styled like card ID pill)
    table.insert(rows, makeTooltipPill(title, {
        background = opts.titleBg or tooltipStyle.labelBg,
        color = opts.titleColor or tooltipStyle.labelColor,
        font = opts.titleFont,  -- optional override
        coded = opts.titleCoded or false
    }))

    -- Body text (wrapped, no pill background)
    table.insert(rows, makeTooltipValueBox(body, {
        color = opts.bodyColor or tooltipStyle.valueColor,
        font = opts.bodyFont,  -- optional override
        coded = opts.bodyCoded or false,
        maxWidth = opts.maxWidth or 250
    }))

    -- Build with DSL (single column)
    -- ... standard root/vbox pattern with updated spacing

    return boxID
end
```

### Spacing Adjustments

```lua
tooltipStyle = {
    -- Unchanged
    fontSize = 18,
    innerPadding = 2,
    rowPadding = 0,
    textPadding = 1,

    -- Changed
    pillPadding = 2,  -- was 4, tighter pills
    outerPadding = 6, -- was 2, more breathing room at edges
}
```

### Font Configuration

Single font name `"tooltip"` (JetBrains Mono, size 44). Delete duplicate `"jetbrains"` loading from `util.lua`.

Per-element font overrides via `font` option for future flexibility.

### Coded Text Support

Option to parse text through `ui.definitions.getTextFromString()`:

```lua
makeSimpleTooltip("Fire Joker", "+10 damage to {color=red}Fire{/color} spells", {
    bodyCoded = true
})
```

Default `coded = false` preserves backward compatibility.

### Tooltip Lifecycle

Preserve lazy initialization with visual snap pattern:

```lua
local tooltipCache = {}  -- keyed by id

function ensureSimpleTooltip(key, title, body, opts)
    if tooltipCache[key] and tooltipCache[key].version == TOOLTIP_FONT_VERSION then
        return tooltipCache[key].boxID
    end
    if tooltipCache[key] then
        destroyTooltip(tooltipCache[key].boxID)
    end
    local boxID = makeSimpleTooltip(title, body, opts)
    tooltipCache[key] = { boxID = boxID, version = TOOLTIP_FONT_VERSION }
    return boxID
end

-- Visual snap prevents size tweening on init
function snapTooltipVisual(boxID)
    local t = component_cache.get(boxID, Transform)
    if t then
        t.visualX, t.visualY = t.actualX, t.actualY
        t.visualW, t.visualH = t.actualW, t.actualH
    end
end
```

### Positioning

Always relative to hovered entity using existing functions:
- `centerTooltipAboveEntity(boxID, entity)`
- `positionTooltipRightOfEntity(boxID, entity)`

## Migration Plan

### 1. `gameplay.lua` - Add new helpers, adjust spacing

- Update `tooltipStyle.pillPadding`: 4 → 2
- Add `outerPadding = 6` to tooltipStyle
- Update tooltip root configs to use `outerPadding`
- Add `coded` option to `makeTooltipPill()` and `makeTooltipValueBox()`
- Add `makeSimpleTooltip()` function

### 2. `avatar_joker_strip.lua` - Replace legacy tooltip calls

- Remove `showTooltip()` calls in `applyTooltip()`
- Remove fallback manual drawing code (lines 581-639)
- Add tooltip cache for joker/avatar tooltips
- Use `makeSimpleTooltip()` + `centerTooltipAboveEntity()`
- Add cleanup on strip destruction

### 3. `ui_defs.lua` - Replace creature button tooltips

- Remove creature button `showTooltip()` calls
- Use `makeSimpleTooltip()` instead
- Delete `generateTooltipUI()` function
- Remove `globals.ui.tooltipTitleText/BodyText/UIBox` setup

### 4. `util.lua` - Delete legacy code

- Delete `showTooltip()` function
- Delete `hideTooltip()` function
- Delete `ensureTooltipFont()` function

## Files Modified

| File | Changes |
|------|---------|
| `assets/scripts/core/gameplay.lua` | Add helpers, adjust spacing |
| `assets/scripts/ui/avatar_joker_strip.lua` | Migrate to DSL tooltips |
| `assets/scripts/ui/ui_defs.lua` | Migrate creature buttons, delete legacy setup |
| `assets/scripts/util/util.lua` | Delete legacy tooltip functions |

## Order of Operations

1. Add new helpers to `gameplay.lua` (non-breaking)
2. Migrate `avatar_joker_strip.lua`
3. Migrate `ui_defs.lua` creature buttons
4. Delete `generateTooltipUI()` from `ui_defs.lua`
5. Delete legacy functions from `util.lua`
6. Test all tooltip types work correctly

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
