# 3-Box Tooltip System Specification

## Overview

A modular tooltip system with three distinct floating boxes: **Title**, **Description**, and **Stats**. Designed to replace the existing tooltip implementation with a generic, reusable system that works for cards, equipment, enemies, and other entities.

---

## Visual Structure

```
┌─────────────────────────────┐  ← Title Box (icon + name + rarity border)
│ 🔥  Pyroclastic Devastation │
└─────────────────────────────┘
         ↕ gap (4-8px)
┌─────────────────────────────┐  ← Description Box (rich text, variable height)
│ Unleash a wave of molten    │
│ fire dealing [25](red)      │
│ damage to all enemies.      │
└─────────────────────────────┘
         ↕ gap (4-8px)
┌─────────────────────────────┐  ← Stats Box (2-column grid)
│ Damage: 25    │ Mana: 12    │
│ Range: 150    │ Cooldown: 2 │
└─────────────────────────────┘
```

---

## Box Specifications

### 1. Title Box

| Property | Value |
|----------|-------|
| **Layout** | Icon (left) + Name (center/left) |
| **Icon Source** | Existing sprite sheets (element/type icons) |
| **Text Rendering** | C++ `TextSystem` with `resizeTextToFit()` |
| **Font Sizing** | Dynamic shrink-to-fit via C++ TextSystem |
| **Max Font Size** | 20px (or current default) |
| **Min Font Size** | 10px |
| **Rarity Styling** | Static border color based on rarity |
| **Border Style** | Flat, thin border |

**Rarity Border Colors:**
- Common: Gray (`#888888`)
- Uncommon: Green (`#4CAF50`)
- Rare: Blue (`#2196F3`)
- Epic: Purple (`#9C27B0`)
- Legendary: Orange/Gold (`#FF9800`)

### 2. Description Box

| Property | Value |
|----------|-------|
| **Layout** | Single text area, word-wrapped |
| **Height** | Expands to fit content (no max) |
| **Text Rendering** | C++ `TextSystem` dynamic text (NOT Lua Text Builder) |
| **Localization** | Uses existing `localization.get()` system |
| **Border Style** | Flat, thin border |

**Text System (C++ Dynamic Text):**

Uses the engine's native `TextSystem` from `src/systems/text/textVer2.hpp`. This provides:
- Inline colors: `[25](color=red)`
- Rich effects: `[text](pop=0.3,0.1,in)`, `[text](shake=2,2)`
- Keyword auto-styling via `localization.getStyled()`
- `resizeTextToFit()` for dynamic font sizing
- No embedded icons in description (text-only)

**Available Effects:**
| Effect | Example | Description |
|--------|---------|-------------|
| `color` | `[Fire](color=red)` | Text color |
| `pop` | `[!](pop=0.3,0.1,in)` | Scale in/out |
| `shake` | `[CRIT](shake=2,2)` | Random jitter |
| `pulse` | `[♥](pulse=0.9,1.1,2)` | Scale breathing |
| `float` | `[~](float=2.5,5,4)` | Vertical bob |

See `src/systems/text/effects_documentation.md` for full effect list.

### 3. Stats Box

| Property | Value |
|----------|-------|
| **Layout** | Fixed 2-column grid |
| **Row Format** | `Label: Value` (no icons) |
| **Empty State** | Shows "Passive Effect" label |
| **Growth** | Unbounded - rows added as needed |
| **Separators** | None - rely on spacing for readability |
| **Border Style** | Flat, thin border |

**Stats Whitelist (Global Config):**
```lua
-- In assets/scripts/config/tooltip_config.lua
return {
    stats_whitelist = {
        "damage",
        "mana_cost",
        "range",
        "cooldown",
        "duration",
        "area",
        "charges",
        -- Add more as needed
    }
}
```

---

## Positioning & Layout

### Anchor Position
- **Primary**: Right of hovered entity
- **Fallback**: Left of entity (when near right screen edge)
- **Gap from Entity**: 8-12px

### Multi-Tooltip Stacking
- **Direction**: Vertical (below previous tooltip)
- **Stack Gap**: 4-8px between tooltips
- **Size Limit**: None - each tooltip sizes independently
- **Max Count**: No limit (stack can grow tall)

### Box Gaps
- **Between boxes**: 4-8px
- **Style**: Independent floating boxes (each has own shadow/border)
- **No shared outer frame**

---

## Behavior

### Hover Timing
| Property | Value |
|----------|-------|
| **Appear Delay** | 0ms (instant) |
| **Disappear Delay** | 0ms (instant) |
| **Animation** | None (instant pop in/out) |

### Input Support
- Mouse hover only (no keyboard/gamepad for now)
- Hover on source entity shows tooltip
- Moving cursor away hides tooltip

---

## API Design

### Auto-Derive Mode (Primary)

```lua
local Tooltip = require("ui.tooltip_3box")

-- Show tooltip for a card (auto-extracts data)
Tooltip.showForCard(cardId, anchorEntity)

-- Show tooltip for any entity (auto-extracts based on components)
Tooltip.showForEntity(entity)

-- Hide current tooltip
Tooltip.hide()
```

### Manual Mode (Override)

```lua
-- Full manual control when auto-derive doesn't work
Tooltip.show({
    title = {
        name = "Custom Title",
        icon = "fire_icon",  -- sprite name
        rarity = "rare"
    },
    description = "This is a [custom](color=gold) description.",
    stats = {
        { label = "Power", value = 100 },
        { label = "Speed", value = 50 }
    }
}, anchorEntity)
```

### Hybrid Mode

```lua
-- Auto-derive but override specific fields
Tooltip.showForCard(cardId, anchorEntity, {
    description = "Override description only"
})
```

---

## Data Extraction

### From Card Definition

```lua
-- Card definition (assets/scripts/data/cards.lua)
Cards.FIREBALL = {
    id = "FIREBALL",
    name = "Fireball",           -- → Title.name
    type = "action",             -- → Title.icon (mapped to sprite)
    rarity = "rare",             -- → Title.rarity border
    description = "tooltip.fireball_desc",  -- → Description (localized)
    damage = 25,                 -- → Stats (if in whitelist)
    mana_cost = 12,              -- → Stats (if in whitelist)
    range = 150,                 -- → Stats (if in whitelist)
    damage_type = "fire",        -- Not in whitelist, ignored
}
```

### From Other Entity Types

For non-card entities, implement extractors:

```lua
-- In tooltip system
local extractors = {
    card = extractCardData,
    equipment = extractEquipmentData,
    enemy = extractEnemyData,
    -- Add more as needed
}

function Tooltip.showForEntity(entity)
    local entityType = detectEntityType(entity)
    local extractor = extractors[entityType]
    local data = extractor(entity)
    showTooltipWithData(data, entity)
end
```

---

## Localization Integration

### Stat Labels

```json
// en_us.json
{
    "stat": {
        "damage": "Damage",
        "mana_cost": "Mana",
        "range": "Range",
        "cooldown": "Cooldown",
        "duration": "Duration"
    }
}
```

### Descriptions

```json
{
    "tooltip": {
        "fireball_desc": "Hurl a ball of fire dealing {damage|red} damage."
    }
}
```

Usage with styled localization:
```lua
local desc = localization.getStyled("tooltip.fireball_desc", {
    damage = card.damage
})
```

---

## Migration Plan

**Full replacement** - the old tooltip system will be removed entirely.

### Migration Steps

1. Implement new 3-box tooltip module
2. Create data extractors for cards
3. Update all card hover handlers to use new system
4. Remove old tooltip code
5. Add extractors for equipment, enemies as needed

---

## File Structure

```
assets/scripts/
├── ui/
│   └── tooltip_3box.lua          # Main tooltip module
├── config/
│   └── tooltip_config.lua        # Stats whitelist, styling config
└── core/
    └── tooltip_extractors.lua    # Data extraction for entity types
```

---

## Visual Style Summary

| Property | Value |
|----------|-------|
| **Box Style** | Flat with thin border |
| **Shadow** | Each box has its own subtle shadow |
| **Corner Radius** | Small (4-6px) |
| **Background** | Semi-transparent dark |
| **Border Color** | Subtle gray (or rarity color for title) |
| **Text Color** | White/light for readability |
| **Spacing** | Generous padding inside boxes |

---

## Technical Note: Text Rendering

**IMPORTANT:** This tooltip system uses the **C++ TextSystem** (`src/systems/text/textVer2.hpp`), NOT the Lua-only Text Builder (`assets/scripts/core/text.lua`).

| System | Location | Use Case |
|--------|----------|----------|
| **C++ TextSystem** ✅ | `src/systems/text/` | Tooltip text rendering |
| Lua Text Builder ❌ | `assets/scripts/core/text.lua` | Fire-and-forget popups (NOT for tooltips) |

**Why C++ TextSystem:**
- Native rendering performance
- `resizeTextToFit()` for dynamic font sizing
- Proper integration with ECS entities
- Same effect syntax: `[text](color=red)`, `[text](pop=0.3)`

**Key Functions:**
```cpp
// Create text entity
TextSystem::Functions::createTextEntity(text, x, y);

// Resize to fit container
TextSystem::Functions::resizeTextToFit(entity, targetWidth, targetHeight);

// Update text content
TextSystem::Functions::setText(entity, "new text");
```

---

## Non-Goals (Out of Scope)

- Keyboard/gamepad navigation
- Animated rarity effects (shimmer, pulse)
- Tooltip scrolling
- Maximum height constraints
- Inline icons in description text
- Per-card stats configuration

---

## Open Questions (Resolved)

| Question | Decision |
|----------|----------|
| Title overflow | Shrink font to fit (min 10px) |
| Stats layout | Fixed 2-column grid |
| Box separation | Independent floating boxes |
| Description height | Expand to fit |
| Frame style | Independent floating (no shared frame) |
| Title extras | Icon + rarity border |
| Stat format | Label: Value (no icons) |
| Empty stats | Show "Passive Effect" |
| Multi-tooltip | Stack vertically |
| Rich text | C++ TextSystem dynamic text |
| Rarity animation | Static color only |
| Stats overflow | Grow unbounded |
| Positioning | Right of card, flip to left |
| Hover delay | Instant (0ms) |
| Data mapping | Auto-derive from card |
| Icon source | Existing sprites |
| Input support | Mouse-hover only |
| Stack limits | Independent sizing |
| Transitions | Instant pop |
| Box style | Flat with thin border |
| Row separators | None |
| Stats whitelist | Global config file |
| Localization | Use existing system |
| Scope | Generic from start |
| Min font size | 10px |
| Migration | Full replacement |

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
