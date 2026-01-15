# Using the Showcase Gallery

This guide explains how to use the UI Showcase Gallery to browse, learn from, and test UI component examples.

## Table of Contents
1. [What is the Showcase Gallery?](#what-is-the-showcase-gallery)
2. [Opening the Gallery](#opening-the-gallery)
3. [Navigation](#navigation)
4. [Understanding Showcases](#understanding-showcases)
5. [Categories](#categories)
6. [Adding Your Own Showcases](#adding-your-own-showcases)
7. [API Reference](#api-reference)

---

## What is the Showcase Gallery?

The Showcase Gallery is an interactive browser for UI component examples. It provides:

- **Visual preview** of each component
- **Source code** showing how to create it
- **Prop documentation** explaining available options
- **Keyboard/mouse navigation** for quick browsing

Use it to:
- Learn the DSL API by example
- Find patterns to copy into your code
- Test components visually
- Document new components you create

---

## Opening the Gallery

### From Code

```lua
local GalleryViewer = require("ui.showcase.gallery_viewer")

-- Show at default position (50, 50)
GalleryViewer.showGlobal()

-- Show at custom position
GalleryViewer.showGlobal(100, 100)

-- Toggle visibility
GalleryViewer.toggleGlobal()

-- Hide when done
GalleryViewer.hideGlobal()
```

### From Debug Console

If your game has a debug console:

```lua
require("ui.showcase.gallery_viewer").showGlobal()
```

### As a Debug Key

Add to your debug key handler:

```lua
if isKeyPressed("KEY_F1") then
    local GalleryViewer = require("ui.showcase.gallery_viewer")
    GalleryViewer.toggleGlobal()
end
```

---

## Navigation

### Keyboard Controls

| Key | Action |
|-----|--------|
| `UP` / `W` | Select previous showcase |
| `DOWN` / `S` | Select next showcase |
| `ENTER` / `SPACE` | Refresh preview |
| `ESC` | Close gallery |

### Mouse Controls

- **Click** on any showcase in the list to select it
- The preview panel updates automatically

### Gallery Layout

```
┌─────────────────────────────────────────────────────────────┐
│  UI Showcase Gallery     primitives > Text (Basic)          │
│  Use UP/DOWN to navigate, ENTER to select, ESC to close     │
├──────────────┬──────────────────────────────────────────────┤
│ PRIMITIVES   │  Preview                                     │
│ ──────────── │  ┌────────────────────────────────────────┐  │
│ • Text Basic │  │                                        │  │
│ • Text Sizes │  │         [Live Preview Here]            │  │
│ • Text Colors│  │                                        │  │
│ • ...        │  └────────────────────────────────────────┘  │
│              │                                              │
│ LAYOUTS      │  Source Code                                 │
│ ──────────── │  ┌────────────────────────────────────────┐  │
│ • vbox_basic │  │ dsl.text("Hello World")                │  │
│ • hbox_basic │  │                                        │  │
│ • ...        │  └────────────────────────────────────────┘  │
└──────────────┴──────────────────────────────────────────────┘
```

---

## Understanding Showcases

Each showcase has four parts:

### 1. Name
A short, descriptive title like "Text (Basic)" or "Button with Hover".

### 2. Description
One-line explanation of what the showcase demonstrates:
```
"Simple text label with default styling"
```

### 3. Source Code
The exact code to recreate the component:
```lua
dsl.text("Hello World")
```

### 4. Create Function
A Lua function that returns the live component for the preview:
```lua
create = function()
    return dsl.text("Hello World")
end
```

### Example Showcase Definition

```lua
text_basic = {
    name = "Text (Basic)",
    description = "Simple text label with default styling",
    source = [[
dsl.text("Hello World")]],
    create = function()
        return dsl.text("Hello World")
    end,
}
```

---

## Categories

Showcases are organized into categories:

### Primitives
Basic building blocks that display content:

| Showcase | Description |
|----------|-------------|
| `text_basic` | Simple text label |
| `text_sizes` | Font sizes from 12px to 32px |
| `text_colors` | Named color options |
| `text_alignments` | Left, center, right alignment |
| `text_styled` | Combined styling options |
| `image_basic` | Static sprite display |
| `image_sizing` | Different image dimensions |
| `image_tinting` | Color tinting via animation_system |
| `anim_basic` | Animated sprite |
| `anim_speed` | Animation playback control |
| `spacer_horizontal` | Horizontal gaps |
| `spacer_vertical` | Vertical gaps |
| `spacer_combined` | Layout control patterns |
| `divider` | Horizontal/vertical separators |
| `icon_label` | Icon + text pattern |

### Layouts
Container patterns for organizing elements:

| Showcase | Description |
|----------|-------------|
| `vbox_basic` | Vertical stack |
| `vbox_spacing` | With gaps between items |
| `vbox_padding` | With inner padding |
| `hbox_basic` | Horizontal row |
| `hbox_spacing` | With gaps between items |
| `nested_mixed` | Nested vbox/hbox |
| `nested_deep` | 4+ levels of nesting |
| `root_basic` | Minimal root container |
| `root_padding` | Root with padding values |
| `root_alignment` | Various alignments |
| `root_full_config` | All configuration options |

### Patterns
Common UI patterns and compositions:

| Showcase | Description |
|----------|-------------|
| `button_basic` | Simple clickable button |
| `button_styled` | Colored button with emboss |
| `sprite_panel` | Nine-patch panel |
| `sprite_panel_decorations` | Panel with corner decorations |
| `progress_bar` | Animated progress indicator |
| `card_display` | Card-style layout |
| `stat_row` | Icon + label + value pattern |
| `tooltip_content` | Tooltip layout pattern |
| `form_layout` | Label + input rows |
| `action_bar` | Horizontal button row |

---

## Adding Your Own Showcases

### Step 1: Open the Registry

Edit `assets/scripts/ui/showcase/showcase_registry.lua`.

### Step 2: Add to a Category

Find the appropriate category and add your showcase:

```lua
ShowcaseRegistry._showcases.patterns.my_pattern = {
    name = "My Pattern",
    description = "Demonstrates my custom pattern",
    source = [[
dsl.vbox {
    config = { padding = 10, color = "darkgray" },
    children = {
        dsl.text("My Pattern", { fontSize = 16, color = "gold" }),
        dsl.button("Action", { onClick = function() end }),
    }
}]],
    create = function()
        return dsl.vbox {
            config = { padding = 10, color = "darkgray" },
            children = {
                dsl.text("My Pattern", { fontSize = 16, color = "gold" }),
                dsl.button("Action", { onClick = function() end }),
            }
        }
    end,
}
```

### Step 3: Add to Order List

Add the showcase ID to the category's order list:

```lua
ShowcaseRegistry._showcases.patterns.order = {
    "button_basic",
    "button_styled",
    "my_pattern",  -- Add here
    -- ...
}
```

### Step 4: Test Your Showcase

```lua
-- Test that it creates without error
local showcase = ShowcaseRegistry._showcases.patterns.my_pattern
local ok, result = pcall(showcase.create)
assert(ok, "Showcase creation failed: " .. tostring(result))
print("Showcase created successfully!")
```

---

## API Reference

### GalleryViewer Module

```lua
local GalleryViewer = require("ui.showcase.gallery_viewer")
```

#### Module Functions

| Function | Description |
|----------|-------------|
| `GalleryViewer.new(options)` | Create a new gallery instance |
| `GalleryViewer.showGlobal(x, y)` | Show the global gallery |
| `GalleryViewer.hideGlobal()` | Hide the global gallery |
| `GalleryViewer.toggleGlobal()` | Toggle global gallery visibility |
| `GalleryViewer.destroyGlobal()` | Clean up global gallery |

#### Instance Methods

```lua
local viewer = GalleryViewer.new({ width = 800, height = 500 })
```

| Method | Description |
|--------|-------------|
| `viewer:show(x, y)` | Show the gallery at position |
| `viewer:hide()` | Hide the gallery |
| `viewer:toggle()` | Toggle visibility |
| `viewer:update(dt)` | Update (call in game loop) |
| `viewer:destroy()` | Clean up resources |
| `viewer:getCurrentShowcase()` | Get selected showcase |

### ShowcaseRegistry Module

```lua
local ShowcaseRegistry = require("ui.showcase.showcase_registry")
```

| Function | Description |
|----------|-------------|
| `getCategories()` | Returns list of category IDs |
| `getCategoryName(id)` | Get display name for category |
| `getShowcases(categoryId)` | Get all showcases in category |
| `getShowcase(categoryId, showcaseId)` | Get specific showcase |
| `getFlatList()` | Get all showcases as flat list |

#### Example: Query Showcases

```lua
local ShowcaseRegistry = require("ui.showcase.showcase_registry")

-- List all categories
for _, catId in ipairs(ShowcaseRegistry.getCategories()) do
    print("Category:", ShowcaseRegistry.getCategoryName(catId))

    -- List showcases in category
    for _, showcase in ipairs(ShowcaseRegistry.getShowcases(catId)) do
        print("  -", showcase.name)
    end
end
```

---

## Tips and Tricks

### 1. Copy Source Directly

The source code in showcases is copy-paste ready. Select it from the gallery and use it as a starting point.

### 2. Modify and Re-test

After copying, use `dsl.strict` to catch any errors:

```lua
-- Original from showcase
dsl.text("Hello World")

-- Your modified version with strict validation
dsl.strict.text("Hello World", {
    fontSize = 24,
    color = "gold",
    shadow = true
})
```

### 3. Check Prop Documentation

Each primitive category includes prop documentation in comments. Look for sections like:

```lua
--[[
TEXT PROPS:
  text       - (string) The text content to display
  fontSize   - (number) Font size in pixels
  color      - (string|Color) Text color
  ...
]]
```

### 4. Use as Teaching Tool

The gallery is excellent for onboarding new team members or explaining UI patterns during code review.

---

## Related Documentation

- [Getting Started with dsl.strict](./getting-started-with-strict.md) - Validated DSL usage
- [Writing UI Tests](./writing-ui-tests.md) - Test your UI components
- [Adding Components to Strict](./adding-components-to-strict.md) - Extend the system
- [UI DSL Reference](../api/ui-dsl-reference.md) - Full API documentation
