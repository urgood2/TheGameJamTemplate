# UI Filler System Specification

> Flexible space distribution for hbox/vbox containers in the UI DSL

## Overview

The **Filler** system adds flexible space distribution to the existing UI DSL layout engine. Fillers are invisible layout elements that expand to claim remaining space in a container, enabling patterns like left-aligned + right-aligned elements, centered groups with edge-anchored items, and proportional space distribution.

## Core Concepts

### What is a Filler?

A filler is a **non-rendering layout primitive** that:
- Claims remaining space after fixed-size children are measured
- Respects flex weights for proportional distribution among multiple fillers
- Is non-interactive (clicks pass through)
- Works only as a direct child of hbox/vbox containers (single-level)

### Mental Model

```
┌─────────────────────────────────────────────────────┐
│  [Button]     ◄──── filler ────►     [Icon] [Menu] │
│   fixed            flexible              fixed      │
└─────────────────────────────────────────────────────┘
```

The filler absorbs all remaining space, pushing fixed elements to container edges.

---

## API Design

### Basic Usage

```lua
local dsl = require("ui.ui_syntax_sugar")

-- Simple filler (flex = 1 by default)
dsl.hbox {
    children = {
        dsl.text("Left"),
        dsl.filler(),           -- Claims all remaining space
        dsl.text("Right"),
    }
}

-- Filler with flex weight
dsl.hbox {
    children = {
        dsl.text("A"),
        dsl.filler { flex = 1 },    -- Gets 1/3 of remaining space
        dsl.text("B"),
        dsl.filler { flex = 2 },    -- Gets 2/3 of remaining space
        dsl.text("C"),
    }
}

-- Filler with max cap
dsl.hbox {
    config = { minWidth = 400 },
    children = {
        dsl.text("Left"),
        dsl.filler { maxFill = 100 },  -- Expand up to 100px max
        dsl.text("Right"),
    }
}
```

### API Signature

```lua
dsl.filler()                    -- flex = 1 (default)
dsl.filler { flex = N }         -- flex weight (integer, default 1)
dsl.filler { maxFill = N }      -- maximum expansion in pixels
dsl.filler { flex = N, maxFill = M }  -- both constraints
```

### Return Value

Returns a UI element node suitable for inclusion in `children` arrays, same as `dsl.spacer()`, `dsl.text()`, etc.

---

## Behavior Specification

### Space Calculation

```
Available Space = Parent Content Size
                - Sum(Fixed Children Sizes)
                - Sum(Spacing Between Children)
                - Padding (both sides)
```

Where:
- **Parent Content Size**: The container's actual size (from constraints or child accumulation)
- **Fixed Children**: All non-filler children
- **Spacing**: `config.spacing` × (child_count - 1)
- **Padding**: `config.padding` × 2 (or explicit left/right padding)

### Flex Weight Distribution

When multiple fillers exist:

```
Filler[i].size = (Filler[i].flex / Sum(all flex weights)) × Available Space
```

Fractional pixels are **rounded to nearest integer**. Small gaps (1-2px) are acceptable.

### maxFill Constraint

When `maxFill` is specified:
1. Calculate filler's proportional share as normal
2. Clamp to `min(calculated_share, maxFill)`
3. **Remaining space is NOT redistributed** to other fillers

### Cross-Axis Sizing

In an hbox, filler height = **max(sibling heights)**
In a vbox, filler width = **max(sibling widths)**

This ensures the filler doesn't collapse in the cross-axis and maintains consistent row/column height.

### Underflow Behavior

When `Available Space ≤ 0`:
- All fillers collapse to **zero size**
- Fixed children may overflow the container
- UIValidator warns about zero-size fillers

### Solo Filler

A filler as the **only child** in a container:
- Fills the entire container content area
- This is a valid use case (e.g., flexible spacer in a sized container)

---

## Layout Algorithm

### Two-Pass C++ Implementation

The layout engine requires modification to support fillers:

#### Pass 1: Bottom-Up Sizing (existing)
```cpp
// In SubCalculateContainerSize()
for each child:
    if (child is FILLER):
        mark as pending, size = 0
        accumulate flex weight
    else:
        accumulate fixed size as normal
```

#### Pass 2: Top-Down Filler Distribution (new)
```cpp
// After container size is known
void DistributeFillerSpace(container) {
    float availableSpace = container.contentSize
                         - sumFixedChildSizes
                         - totalSpacing
                         - padding * 2;

    float totalFlex = sumOf(filler.flex for each filler);

    for each filler in container:
        float share = (filler.flex / totalFlex) * availableSpace;
        if (filler.maxFill > 0):
            share = min(share, filler.maxFill);
        filler.computedSize = round(max(0, share));
}
```

#### Positioning Phase
Standard `handleAlignment()` proceeds as normal—fillers now have computed sizes.

---

## Interaction with Existing Features

### Container Alignment

When a container has fillers, **container-level alignment is superseded** for the primary axis:
- Fillers handle space distribution explicitly
- Alignment flags (CENTER, RIGHT) for the primary axis are ignored
- Cross-axis alignment still applies

```lua
-- align has no effect on horizontal positioning (filler handles it)
dsl.hbox {
    config = { align = CENTER },  -- Ignored for x-axis
    children = {
        dsl.text("Left"),
        dsl.filler(),
        dsl.text("Right"),
    }
}
```

### Padding and Borders

- **Padding**: Filler respects container padding—available space excludes padding
- **Sprite Panel Borders**: Nine-patch borders count as implicit padding—filler only claims content area

### Reactivity

Fillers **automatically re-layout** when parent size changes:
- Window resize
- Parent animation (timer.sequence size tweens)
- Sibling size changes

No manual invalidation required. The existing per-frame `Recalculate()` handles this.

### Delta Absorption

When sibling elements change size (e.g., text content updates):
- Filler **absorbs the delta**
- Elements at container edges maintain their edge-anchored positions
- This provides stable anchor points for left/right aligned items

---

## Nesting Behavior

Fillers operate at **single level only**:
- A filler claims space from its **direct parent** container
- Nested containers do not propagate flex constraints to grandchildren
- A filler inside a nested box only sees that box's content area

```lua
dsl.hbox {
    config = { minWidth = 400 },
    children = {
        dsl.vbox {
            children = {
                dsl.filler(),  -- Only fills this vbox, not outer hbox
                dsl.text("X"),
            }
        },
        dsl.filler(),  -- Fills remaining hbox space
    }
}
```

If more complex flex propagation is needed, add explicit size constraints to intermediate containers.

---

## UIValidator Integration

### New Validation Rules

| Rule | Severity | Condition |
|------|----------|-----------|
| `filler_zero_size` | warning | Filler computed size = 0 (likely layout misconfiguration) |
| `filler_multiple` | warning | Container has > 1 filler (not an error, but worth noting) |
| `filler_nested` | warning | Filler is not a direct child of hbox/vbox (undefined behavior) |
| `filler_in_unsized` | info | Filler in container with no size constraints (fills to 0) |

### Debug Visualization

`draw.debug_bounds(entity)` renders filler bounds like any element:
- Filler extents shown in standard debug overlay
- No special coloring needed—fillers are elements with computed sizes

---

## C++ Implementation Notes

### New UIConfig Fields

```cpp
// In ui_data.hpp UIConfig struct
bool isFiller = false;          // True if this is a filler element
float flexWeight = 1.0f;        // Flex proportion (default 1)
float maxFillSize = 0.0f;       // Maximum fill size in pixels (0 = unlimited)
float computedFillSize = 0.0f;  // Calculated size after distribution
```

### New UITypeEnum

```cpp
enum class UITypeEnum {
    // ... existing types ...
    FILLER,  // New filler type
};
```

### Modified Functions

| Function | Change |
|----------|--------|
| `SubCalculateContainerSize()` | Skip filler sizing, accumulate flex weights |
| `SetWH()` | After container size known, call `DistributeFillerSpace()` |
| `handleAlignment()` | Use `computedFillSize` for filler children |

### New Function

```cpp
void DistributeFillerSpace(entt::registry& reg, entt::entity container);
```

---

## Lua DSL Implementation

### In `ui_syntax_sugar.lua`

```lua
function dsl.filler(config)
    config = config or {}
    return {
        type = "FILLER",
        flex = config.flex or 1,
        maxFill = config.maxFill or 0,
        -- Cross-axis sizing handled by C++ (matches siblings)
    }
end
```

### Template Node Conversion

```lua
-- In convertToTemplateNode or similar
if def.type == "FILLER" then
    node.uiType = UITypeEnum.FILLER
    node.isFiller = true
    node.flexWeight = def.flex
    node.maxFillSize = def.maxFill
end
```

---

## Examples

### Toolbar with Spacer

```lua
local toolbar = dsl.hbox {
    config = { minWidth = screenWidth(), padding = 8, spacing = 4 },
    children = {
        dsl.button("File"),
        dsl.button("Edit"),
        dsl.button("View"),
        dsl.filler(),               -- Push remaining to right
        dsl.button("Settings"),
        dsl.button("Help"),
    }
}
```

### Centered Content with Edge Items

```lua
local header = dsl.hbox {
    config = { minWidth = 600 },
    children = {
        dsl.button("Back"),
        dsl.filler(),
        dsl.text("Page Title", { fontSize = 24 }),
        dsl.filler(),               -- Equal fillers center the title
        dsl.button("Menu"),
    }
}
```

### Proportional Columns

```lua
local layout = dsl.hbox {
    config = { minWidth = 800 },
    children = {
        dsl.box { config = { minWidth = 50 }, children = { dsl.text("Fixed") } },
        dsl.filler { flex = 1 },    -- 1/3 of remaining
        dsl.box { children = { dsl.text("A") } },
        dsl.filler { flex = 2 },    -- 2/3 of remaining
        dsl.box { children = { dsl.text("B") } },
    }
}
```

### Filler with Maximum

```lua
local balanced = dsl.hbox {
    config = { minWidth = 1000 },
    children = {
        dsl.text("Left"),
        dsl.filler { maxFill = 200 },   -- Won't exceed 200px
        dsl.text("Center"),
        dsl.filler { maxFill = 200 },
        dsl.text("Right"),
    }
}
```

---

## Future Considerations

### Grid Compatibility

The filler API is designed to be forward-compatible with future grid layouts:
- `flex` weight concept maps to grid track sizing (e.g., `1fr`, `2fr`)
- `maxFill` maps to `max-content` constraints
- Single-level operation avoids complex nested flex resolution

### Potential Extensions (Not in Scope)

- `minFill`: Minimum filler size before collapsing
- `shrink`: Whether filler can shrink below flex-calculated size
- Animated filler transitions (eased size changes)
- `align-self`: Per-child alignment override

---

## Summary

| Aspect | Decision |
|--------|----------|
| **API** | `dsl.filler()`, `dsl.filler { flex = N, maxFill = M }` |
| **Default flex** | 1 |
| **Scope** | Direct children of hbox/vbox only |
| **Alignment** | Fillers supersede container alignment for primary axis |
| **Reactivity** | Auto re-layout on parent resize |
| **Underflow** | Filler collapses to zero |
| **Cross-axis** | Matches tallest/widest sibling |
| **Interactivity** | Non-interactive (pass-through clicks) |
| **Padding** | Filler excludes container padding |
| **Algorithm** | Two-pass: sizing then distribution |
| **Fractional pixels** | Round to nearest, accept small gaps |
| **Validation** | Warns on zero-size, multiple fillers, nested attempts |

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
