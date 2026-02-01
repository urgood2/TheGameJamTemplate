# UI Sprite Panel and Decoration System

Sprite panels allow you to use custom sprites (with nine-patch stretching) for UI backgrounds instead of the default rounded rectangles. Decorations are sprites that render on top of UI elements at specific anchor positions without affecting layout.

## Overview

This system provides three main features:

1. **Sprite Panels** - Nine-patch panels using custom sprites that stretch to fit content
2. **Sprite Buttons** - Four-state buttons (normal/hover/pressed/disabled) with custom sprites
3. **Decorations** - Overlaid sprites positioned at anchors (corners, centers, edges) that don't affect layout

**When to use:**
- Custom UI themes with ornate panels and borders
- Game-specific UI styling (medieval, sci-fi, fantasy)
- Decorative elements like corner ornaments, gems, badges
- Themed buttons with visual feedback

---

## Sprite Panels

### Basic Usage

```lua
local dsl = require("ui.ui_syntax_sugar")

dsl.spritePanel {
    sprite = "ui-panel-frame.png",
    borders = { 8, 8, 8, 8 },  -- left, top, right, bottom
    minWidth = 200,
    minHeight = 100,
    padding = 12,
    children = {
        dsl.text("Panel Content", { fontSize = 14, color = "white" })
    }
}
```

### Nine-Patch Stretching

The `borders` parameter defines which parts of the sprite are corners vs edges:

```
┌──────────┐
│  top     │  ← top border (8px)
├──┬────┬──┤
│L │    │R │  ← left (8px) / right (8px)
├──┴────┴──┤
│  bottom  │  ← bottom border (8px)
└──────────┘
```

- Corners stay fixed size
- Edges stretch in one direction
- Center stretches in both directions

### Sizing Modes

**`fit_content` (default)**: Panel stretches to fit children

```lua
dsl.spritePanel {
    sprite = "panel.png",
    borders = { 8, 8, 8, 8 },
    sizing = "fit_content",  -- stretches to content
    children = { ... }
}
```

**`fit_sprite`**: Panel uses original sprite dimensions (no stretching)

```lua
dsl.spritePanel {
    sprite = "fixed-frame.png",
    sizing = "fit_sprite",  -- 130x66 if sprite is that size
    children = { ... }
}
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `sprite` | string | *required* | Sprite name from atlas |
| `borders` | table | `{ 8, 8, 8, 8 }` | Nine-patch borders: `{ left, top, right, bottom }` |
| `sizing` | string | `"fit_content"` | `"fit_content"` or `"fit_sprite"` |
| `minWidth` | number | nil | Minimum width (ignored if `fit_sprite`) |
| `minHeight` | number | nil | Minimum height (ignored if `fit_sprite`) |
| `maxWidth` | number | nil | Maximum width |
| `maxHeight` | number | nil | Maximum height |
| `padding` | number | 0 | Inner padding |
| `tint` | Color/string | white | Color tint (supports named colors) |
| `decorations` | table | `{}` | Decoration sprites (see below) |
| `containerType` | string | `"VERTICAL_CONTAINER"` | `"VERTICAL_CONTAINER"` or `"HORIZONTAL_CONTAINER"` |
| `align` | AlignmentFlag | center/center | Content alignment |
| `hover` | boolean | false | Enable hover effects |
| `canCollide` | boolean | false | Enable collision detection |
| `children` | table | `{}` | Child UI elements |

### Examples

**Simple panel with content:**

```lua
dsl.spritePanel {
    sprite = "wooden-frame.png",
    borders = { 10, 10, 10, 10 },
    minWidth = 180,
    minHeight = 80,
    padding = 12,
    children = {
        dsl.text("Inventory", { fontSize = 16, color = "gold" }),
        dsl.spacer(8),
        dsl.text("12 / 20 items", { fontSize = 12, color = "white" })
    }
}
```

**Fixed-size ornate panel:**

```lua
dsl.spritePanel {
    sprite = "portrait-frame.png",
    sizing = "fit_sprite",  -- Uses original 100x120 dimensions
    padding = 8,
    children = {
        dsl.anim("player_portrait.png", { w = 64, h = 64 })
    }
}
```

**Tinted panel:**

```lua
dsl.spritePanel {
    sprite = "generic-panel.png",
    borders = { 6, 6, 6, 6 },
    tint = "cyan",  -- or Color.new(0, 255, 255, 200)
    children = { ... }
}
```

---

## Sprite Buttons

### Basic Usage

```lua
dsl.spriteButton {
    states = {
        normal = "btn-normal.png",
        hover = "btn-hover.png",
        pressed = "btn-pressed.png",
        disabled = "btn-disabled.png"
    },
    borders = { 6, 6, 6, 6 },
    label = "Confirm",
    onClick = function()
        print("Button clicked!")
    end
}
```

### Auto-State Discovery (Optional)

If your sprites follow the `*_normal.png`, `*_hover.png` naming convention:

```lua
dsl.spriteButton {
    sprite = "button",  -- Looks for button_normal.png, button_hover.png, etc.
    label = "Auto-detected states",
    onClick = function() ... end
}
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `states` | table | *required* | Sprite names for each state: `{ normal, hover, pressed, disabled }` |
| `sprite` | string | nil | Base sprite name for auto-discovery (appends `_normal`, `_hover`, etc.) |
| `borders` | table | `{ 4, 4, 4, 4 }` | Nine-patch borders |
| `label` | string | nil | Button text label |
| `text` | string | nil | Alias for `label` |
| `fontSize` | number | 16 | Label font size |
| `textColor` | string/Color | `"white"` | Label color |
| `shadow` | boolean | true | Enable text shadow |
| `onClick` | function | nil | Click callback |
| `disabled` | boolean | false | Disable button |
| `minWidth` | number | nil | Minimum width |
| `minHeight` | number | nil | Minimum height |
| `padding` | number | 4 | Inner padding |
| `align` | AlignmentFlag | center/center | Content alignment |
| `children` | table | `{}` | Custom children (overrides `label`) |

### Examples

**Basic button with all states:**

```lua
dsl.spriteButton {
    states = {
        normal = "blue-btn-normal.png",
        hover = "blue-btn-hover.png",
        pressed = "blue-btn-pressed.png",
        disabled = "blue-btn-disabled.png"
    },
    borders = { 8, 8, 8, 8 },
    label = "Start Game",
    fontSize = 18,
    onClick = function()
        startGame()
    end
}
```

**Disabled button:**

```lua
dsl.spriteButton {
    states = { ... },
    label = "Locked",
    disabled = true,  -- Shows disabled sprite
    onClick = function() 
        -- Won't trigger when disabled
    end
}
```

**Button with custom content:**

```lua
dsl.spriteButton {
    states = { ... },
    borders = { 6, 6, 6, 6 },
    onClick = function() ... end,
    children = {
        dsl.hbox {
            children = {
                dsl.anim("icon_gold.png", { w = 16, h = 16 }),
                dsl.spacer(4),
                dsl.text("Buy", { fontSize = 14 })
            }
        }
    }
}
```

---

## Decorations

Decorations are sprites rendered **after layout** at specific anchor positions. They don't affect the panel's size or content layout.

### Basic Usage

```lua
dsl.spritePanel {
    sprite = "panel.png",
    borders = { 8, 8, 8, 8 },
    decorations = {
        { sprite = "corner-ornament.png", position = "top_left", offset = { -4, -4 } },
        { sprite = "gem.png", position = "top_center", offset = { 0, -12 }, scale = 0.5 }
    },
    children = { ... }
}
```

### Anchor Positions

| Position | Description |
|----------|-------------|
| `top_left` | Top-left corner |
| `top_center` | Top edge center |
| `top_right` | Top-right corner |
| `middle_left` | Left edge center |
| `center` | Absolute center |
| `middle_right` | Right edge center |
| `bottom_left` | Bottom-left corner |
| `bottom_center` | Bottom edge center |
| `bottom_right` | Bottom-right corner |

### Decoration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `sprite` | string | *required* | Sprite name |
| `position` | string | `"top_left"` | Anchor position (see table above) |
| `offset` | table | `{ 0, 0 }` | Pixel offset from anchor: `{ x, y }` |
| `scale` | number/table | `1.0` | Uniform scale or `{ scaleX, scaleY }` |
| `rotation` | number | 0 | Rotation in radians |
| `flip` | string | nil | `"x"`, `"y"`, or `"both"` |
| `opacity` | number | 1.0 | Alpha transparency (0.0 - 1.0) |
| `tint` | Color/string | white | Color tint |
| `zOffset` | number | 0 | Render order offset |
| `visible` | boolean | true | Visibility toggle |
| `id` | string | "" | Optional identifier |

### Examples

**Corner ornaments (flipped for each corner):**

```lua
decorations = {
    { sprite = "ornament.png", position = "top_left", offset = { -8, -8 } },
    { sprite = "ornament.png", position = "top_right", offset = { 8, -8 }, flip = "x" },
    { sprite = "ornament.png", position = "bottom_left", offset = { -8, 8 }, flip = "y" },
    { sprite = "ornament.png", position = "bottom_right", offset = { 8, 8 }, flip = "both" }
}
```

**Centered gem badge (scaled down):**

```lua
decorations = {
    { 
        sprite = "gem-badge.png", 
        position = "top_center", 
        offset = { 0, -16 },
        scale = { 0.6, 0.6 }  -- 60% of original size
    }
}
```

**Edge dividers:**

```lua
decorations = {
    { sprite = "divider.png", position = "middle_left", offset = { -30, 0 } },
    { sprite = "divider.png", position = "bottom_center", offset = { 0, 16 } }
}
```

**Semi-transparent watermark:**

```lua
decorations = {
    { 
        sprite = "logo.png", 
        position = "center", 
        opacity = 0.3,
        scale = 0.5
    }
}
```

**Rotated decoration:**

```lua
decorations = {
    { 
        sprite = "banner.png", 
        position = "top_right", 
        offset = { 10, -10 },
        rotation = math.pi / 4  -- 45 degrees
    }
}
```

---

## Common Patterns

### Ornate Panel with Corner Decorations

```lua
local function createOrnatePanel(title, content)
    return dsl.spritePanel {
        sprite = "fantasy-panel.png",
        borders = { 12, 12, 12, 12 },
        minWidth = 250,
        minHeight = 150,
        padding = 20,
        decorations = {
            -- Corners
            { sprite = "corner-flourish.png", position = "top_left", offset = { -10, -10 } },
            { sprite = "corner-flourish.png", position = "top_right", offset = { 10, -10 }, flip = "x" },
            { sprite = "corner-flourish.png", position = "bottom_left", offset = { -10, 10 }, flip = "y" },
            { sprite = "corner-flourish.png", position = "bottom_right", offset = { 10, 10 }, flip = "both" },
            
            -- Title decoration
            { sprite = "title-gem.png", position = "top_center", offset = { 0, -18 }, scale = 0.7 }
        },
        children = {
            dsl.text(title, { fontSize = 18, color = "gold", shadow = true }),
            dsl.spacer(12),
            dsl.vbox {
                config = { padding = 4 },
                children = content
            }
        }
    }
end
```

### Button Row with Sprite Buttons

```lua
local function createButtonRow()
    return dsl.hbox {
        config = { spacing = 12, padding = 8 },
        children = {
            dsl.spriteButton {
                states = {
                    normal = "btn-green-normal.png",
                    hover = "btn-green-hover.png",
                    pressed = "btn-green-pressed.png",
                    disabled = "btn-green-disabled.png"
                },
                borders = { 6, 6, 6, 6 },
                label = "Accept",
                onClick = function() handleAccept() end
            },
            dsl.spriteButton {
                states = {
                    normal = "btn-red-normal.png",
                    hover = "btn-red-hover.png",
                    pressed = "btn-red-pressed.png",
                    disabled = "btn-red-disabled.png"
                },
                borders = { 6, 6, 6, 6 },
                label = "Cancel",
                onClick = function() handleCancel() end
            }
        }
    }
end
```

### Fixed-Size Portrait Frame

```lua
local function createPortraitFrame(characterSprite)
    return dsl.spritePanel {
        sprite = "portrait-frame.png",
        sizing = "fit_sprite",  -- Uses original sprite size (100x100)
        padding = 6,
        decorations = {
            -- Level badge
            { sprite = "level-badge.png", position = "bottom_right", offset = { 8, 8 } }
        },
        children = {
            dsl.anim(characterSprite, { w = 80, h = 80 })
        }
    }
end
```

### Nested Panels with Decorations

```lua
dsl.spritePanel {
    sprite = "outer-frame.png",
    borders = { 10, 10, 10, 10 },
    minWidth = 300,
    padding = 16,
    decorations = {
        { sprite = "title-banner.png", position = "top_center", offset = { 0, -20 } }
    },
    children = {
        dsl.text("Shop", { fontSize = 20, color = "gold" }),
        dsl.spacer(12),
        
        dsl.spritePanel {
            sprite = "inner-panel.png",
            borders = { 6, 6, 6, 6 },
            minWidth = 260,
            padding = 12,
            children = {
                dsl.text("Item 1", { fontSize = 14 }),
                dsl.text("Item 2", { fontSize = 14 }),
                dsl.text("Item 3", { fontSize = 14 })
            }
        }
    }
}
```

---

## Implementation Notes

### Sprite Requirements

- Sprites must exist in the texture atlas (loaded via animation system)
- For nine-patch panels, sprite should have consistent borders
- Button states can use different sprites or variations of the same base sprite

### Performance

- Decorations are rendered as additional draw calls
- Use `zOffset` to control render order of overlapping decorations
- Set `visible = false` to hide decorations without removing them

### Layout Behavior

- **Sprite panels**: Participate in normal layout flow
- **Decorations**: Rendered after layout, don't affect parent/sibling positioning
- **Sizing**: `fit_content` stretches panel to children; `fit_sprite` fixes size to original sprite dimensions

### Coordinate System

- `offset` is in pixels relative to the anchor position
- Positive x = right, positive y = down
- Rotation is in radians (use `math.pi / 4` for 45°)

---

## Quick Reference

### Sprite Panel

```lua
dsl.spritePanel {
    sprite = "panel.png",
    borders = { left, top, right, bottom },
    sizing = "fit_content",  -- or "fit_sprite"
    minWidth = 200,
    minHeight = 100,
    padding = 12,
    decorations = { ... },
    children = { ... }
}
```

### Sprite Button

```lua
dsl.spriteButton {
    states = { normal = "...", hover = "...", pressed = "...", disabled = "..." },
    borders = { 6, 6, 6, 6 },
    label = "Click Me",
    onClick = function() ... end
}
```

### Decoration

```lua
{ 
    sprite = "ornament.png", 
    position = "top_left",  -- 9 anchors available
    offset = { x, y },
    scale = 1.0,  -- or { scaleX, scaleY }
    rotation = 0,  -- radians
    flip = nil,  -- "x", "y", or "both"
    opacity = 1.0,
    tint = "white"
}
```

---

## See Also

- [UI Helper Reference](ui_helper_reference.md) - Full UI DSL documentation
- [Text Builder API](text-builder.md) - Animated text rendering
- Demo file: `assets/scripts/ui/sprite_ui_showcase.lua` - Working examples

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
