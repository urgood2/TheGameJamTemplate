# Styled Localization for Tooltips

**Date:** 2025-12-21
**Status:** Approved

## Overview

Add color-coding support to localization strings for tooltips without impacting performance of existing per-frame `localization.get()` calls.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Scope | Dynamic values + manual markup | Flexibility for both automated and custom coloring |
| JSON syntax | `{param\|color}` | Default color at authoring time |
| Lua syntax | `{param = {value=X, color="Y"}}` | Runtime override capability |
| Priority | Lua override > JSON default | Context-dependent coloring when needed |
| API | Separate `localization.getStyled()` | Zero overhead for existing hot-path calls |
| Implementation | Lua wrapper | Hot-reloadable, tooltips cached anyway |

## API

### JSON Syntax

```json
{
  "tooltip": {
    "attack_desc": "Deal {damage|red} {element|fire} damage",
    "heal_desc": "Restore {amount|green} HP",
    "cost_desc": "Costs {mana|blue} mana"
  }
}
```

### Lua Usage

```lua
-- Uses JSON default colors
local text = localization.getStyled("tooltip.attack_desc", {
  damage = 25,
  element = "Fire"
})
-- Result: "Deal [25](color=red) [Fire](color=fire) damage"

-- Override color at runtime
local text = localization.getStyled("tooltip.attack_desc", {
  damage = { value = 25, color = "gold" },  -- override
  element = "Fire"                           -- uses default
})
-- Result: "Deal [25](color=gold) [Fire](color=fire) damage"
```

### Manual Markup (passthrough)

Authors can write full markup directly in JSON:

```json
{
  "tooltip": {
    "special": "Unleash a [devastating](color=red;shake=2) blow"
  }
}
```

## Implementation

### Core Function (`assets/scripts/core/localization_styled.lua`)

```lua
local function getStyled(key, params)
  local template = localization.getRaw(key)
  if not template then return "[MISSING: " .. key .. "]" end

  local result = template:gsub("{([^}]+)}", function(match)
    local name, defaultColor = match:match("^([^|]+)|?(.*)$")
    local param = params and params[name]

    if param == nil then return "{" .. match .. "}" end

    local value, color
    if type(param) == "table" then
      value = param.value
      color = param.color or (defaultColor ~= "" and defaultColor) or nil
    else
      value = param
      color = (defaultColor ~= "" and defaultColor) or nil
    end

    if color then
      return "[" .. tostring(value) .. "](color=" .. color .. ")"
    else
      return tostring(value)
    end
  end)

  return result
end

localization.getStyled = getStyled
```

### Tooltip Integration

```lua
local function makeLocalizedTooltip(key, params, opts)
  opts = opts or {}
  local text = localization.getStyled(key, params)
  return makeSimpleTooltip(
    opts.title or "",
    text,
    { bodyCoded = true, maxWidth = opts.maxWidth }
  )
end
```

## Error Handling

| Case | Behavior |
|------|----------|
| Missing param | Keep `{param\|color}` unchanged |
| Nil value | Keep `{param\|color}` unchanged |
| No color specified | Plain substitution (no markup) |
| Invalid color name | Pass through; effect system defaults to white |

## Implementation Steps

1. Create `assets/scripts/core/localization_styled.lua`
2. Load module at startup
3. Add test localization strings to `en_us.json`
4. Add `makeLocalizedTooltip()` helper to `gameplay.lua`
5. Test with a real tooltip
6. Document in CLAUDE.md

## Performance Notes

- `localization.get()` unchanged - zero overhead for existing code
- `localization.getStyled()` does one gsub pass per call
- Tooltips are cached by key - styled parsing happens once per tooltip creation
- Cache invalidates on font version change (language switch)

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
