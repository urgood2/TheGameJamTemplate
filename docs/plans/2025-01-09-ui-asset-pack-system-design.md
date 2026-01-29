# UI Asset Pack System Design

Support arbitrary UI asset packs from itch.io with minimum disruption to existing UI system.

## Goals

- Load UI asset packs (9-patch panels, buttons, scrollbars, etc.) from itch.io
- Explicit opt-in per UI element (no global theme override)
- Visual ImGui tool to author pack manifests from atlas textures
- No changes to existing UI rendering or element creation

## Manifest Schema (pack.json)

Each pack has a JSON manifest describing its assets:

```json
{
  "name": "kenney_rpg",
  "version": "1.0",
  "atlas": "spritesheet.png",

  "panels": {
    "wooden": { "region": [0, 0, 64, 64], "9patch": [8, 8, 8, 8] },
    "metal": { "region": [64, 0, 64, 64], "9patch": [6, 6, 6, 6] }
  },

  "buttons": {
    "green": {
      "normal": { "region": [0, 64, 48, 16] },
      "hover": { "region": [0, 80, 48, 16] },
      "pressed": { "region": [0, 96, 48, 16] },
      "disabled": { "region": [0, 112, 48, 16] }
    }
  },

  "progress_bars": {
    "health": {
      "background": { "region": [128, 0, 100, 20], "9patch": [4, 4, 4, 4] },
      "fill": { "region": [128, 20, 100, 20], "9patch": [2, 2, 2, 2] }
    }
  },

  "scrollbars": {
    "default": {
      "track": { "region": [228, 0, 16, 64], "9patch": [2, 2, 2, 2] },
      "thumb": { "region": [244, 0, 16, 32], "9patch": [3, 3, 3, 3] }
    }
  },

  "sliders": {
    "volume": {
      "track": { "region": [260, 0, 100, 8], "9patch": [4, 0, 4, 0] },
      "thumb": { "region": [260, 8, 16, 16] }
    }
  },

  "inputs": {
    "default": {
      "normal": { "region": [0, 128, 120, 24], "9patch": [4, 4, 4, 4] },
      "focus": { "region": [0, 152, 120, 24], "9patch": [4, 4, 4, 4] }
    }
  },

  "icons": {
    "coin": { "region": [300, 0, 16, 16], "scale_mode": "fixed" },
    "heart": { "region": [316, 0, 16, 16], "scale_mode": "fixed" }
  }
}
```

### Region Definition Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `region` | `[x, y, w, h]` | Yes | Rectangle in atlas coordinates |
| `9patch` | `[left, top, right, bottom]` | No | Border sizes for 9-patch rendering |
| `scale_mode` | `"stretch" \| "tile" \| "fixed"` | No | How non-9-patch sprites fill space (default: `"stretch"`) |

### Scale Modes

- **stretch** - Scale sprite to fit container (default)
- **tile** - Repeat sprite to fill area
- **fixed** - Draw at original size, centered in container

## Lua API

### Registration

```lua
-- Register a pack from manifest file
ui.register_pack("kenney_rpg", "assets/ui_packs/kenney_rpg/pack.json")

-- Get a pack handle for use
local pack = ui.use_pack("kenney_rpg")
```

### Element Access

```lua
local pack = ui.use_pack("kenney_rpg")

-- Panels - returns configured UIConfig with 9-patch set up
local panel_config = pack.panel("wooden")
local panel_config = pack.panel("wooden", { padding = 10 })

-- Buttons - returns UIConfig with sprite states
local button_config = pack.button("green", { onClick = handleClick })

-- Progress bars - returns table with background + fill configs
local bar = pack.progress_bar("health")
-- bar.background = UIConfig for background
-- bar.fill = UIConfig for fill

-- Scrollbars
local scrollbar = pack.scrollbar("default")
-- scrollbar.track, scrollbar.thumb

-- Sliders
local slider = pack.slider("volume")
-- slider.track, slider.thumb

-- Input fields
local input_config = pack.input("default")

-- Icons
local icon_config = pack.icon("coin")
```

### Integration with Existing DSL

```lua
local dsl = require("ui.ui_syntax_sugar")
local pack = ui.use_pack("kenney_rpg")

dsl.vbox({
    pack.panel("wooden", { padding = 12 }),
    children = {
        dsl.text("Inventory", { fontSize = 24 }),
        dsl.hbox({
            pack.button("green", { onClick = onAccept }),
            children = { dsl.text("Accept") }
        }),
    }
})
```

Pack functions return standard `UIConfig` tables that compose naturally with existing UI code.

## Runtime Architecture

### Data Structures (C++)

```cpp
// Scale mode for non-9-patch sprites
enum class ScaleMode { Stretch, Tile, Fixed };

// Region definition (maps to JSON)
struct RegionDef {
    Rectangle region;                    // x, y, width, height in atlas
    std::optional<NPatchInfo> nine_patch; // If 9-patch, border info
    ScaleMode scale_mode = ScaleMode::Stretch;
};

// Element definitions
struct ButtonDef {
    RegionDef normal;
    std::optional<RegionDef> hover;
    std::optional<RegionDef> pressed;
    std::optional<RegionDef> disabled;
};

struct ProgressBarDef {
    RegionDef background;
    RegionDef fill;
};

struct ScrollbarDef {
    RegionDef track;
    RegionDef thumb;
};

struct SliderDef {
    RegionDef track;
    RegionDef thumb;
};

struct InputDef {
    RegionDef normal;
    std::optional<RegionDef> focus;
};

// Complete pack
struct UIAssetPack {
    std::string name;
    Texture2D* atlas;

    std::unordered_map<std::string, RegionDef> panels;
    std::unordered_map<std::string, ButtonDef> buttons;
    std::unordered_map<std::string, ProgressBarDef> progress_bars;
    std::unordered_map<std::string, ScrollbarDef> scrollbars;
    std::unordered_map<std::string, SliderDef> sliders;
    std::unordered_map<std::string, InputDef> inputs;
    std::unordered_map<std::string, RegionDef> icons;
};
```

### Registry

```cpp
// In EngineContext (following existing DI pattern)
struct EngineContext {
    // ... existing fields ...
    std::unordered_map<std::string, UIAssetPack> uiPacks;
};

// API
void ui::registerPack(const std::string& name, const std::string& manifestPath);
UIAssetPack* ui::getPack(const std::string& name);
```

### Lua Bindings

```cpp
// Exposed via ui::exposeToLua()
// ui.register_pack(name, manifest_path)
// ui.use_pack(name) --> returns PackHandle userdata

// PackHandle usertype with methods:
// :panel(variant, opts?)
// :button(variant, opts?)
// :progress_bar(variant)
// :scrollbar(variant)
// :slider(variant)
// :input(variant, opts?)
// :icon(variant, opts?)
```

### Rendering Integration

Pack element functions return `UIConfig` with these fields populated:

- `stylingType = NINEPATCH_BORDERS` (for 9-patch elements)
- `nPatchInfo` - slice borders
- `nPatchSourceTexture` - atlas texture reference
- `nPatchSourceRect` - region in atlas

For non-9-patch elements:
- `stylingType = SPRITE` (new enum value)
- `spriteSourceTexture` - atlas texture reference
- `spriteSourceRect` - region in atlas
- `spriteScaleMode` - stretch/tile/fixed

Rendering in `DrawSelf()`:

```cpp
if (config.stylingType == NINEPATCH_BORDERS) {
    DrawNPatchUIElement(...);  // Existing path
}
else if (config.stylingType == SPRITE) {
    switch (config.spriteScaleMode) {
        case ScaleMode::Fixed:
            // Draw at original size, centered
            DrawTextureRec(atlas, sourceRect, centeredPos, WHITE);
            break;
        case ScaleMode::Tile:
            // Tile to fill container
            for (float y = 0; y < containerH; y += sourceRect.height) {
                for (float x = 0; x < containerW; x += sourceRect.width) {
                    DrawTextureRec(atlas, sourceRect, {x, y}, WHITE);
                }
            }
            break;
        case ScaleMode::Stretch:
        default:
            // Scale to fit
            DrawTexturePro(atlas, sourceRect, destRect, {0,0}, 0, WHITE);
            break;
    }
}
else {
    DrawSteppedRoundedRectangle(...);  // Existing default path
}
```

## ImGui Manifest Editor

Visual tool for creating pack.json manifests from atlas textures.

### Layout

```
+------------------------------------------------------------------+
| Pack Editor: kenney_rpg                             [Save] [Load] |
+------------------------------------------------------------------+
| [+] [-] [Fit] [1:1]  Zoom: 200%        | Element Type:           |
+----------------------------------------|  ( ) Panel              |
|                                        |  ( ) Button             |
|                                        |  ( ) Progress Bar       |
|      Atlas Preview                     |  ( ) Scrollbar          |
|      - Scroll wheel to zoom            |  ( ) Slider             |
|      - Middle-click drag to pan        |  ( ) Input              |
|      - Left-click drag to select       |  ( ) Icon               |
|                                        |-------------------------|
|      [9-patch guides overlay]          | Variant: [wooden      ] |
|                                        | State: [normal v]       |
+----------------------------------------|                         |
| Selection: (32,64) 48x16               | Scale Mode: [stretch v] |
| 9-patch: [8] [8] [8] [8]               | [Add to Pack]           |
+----------------------------------------+-------------------------+
| Pack Contents:                                                    |
|  panels: wooden, metal                                            |
|  buttons: green (4 states), red (4 states)                        |
|  icons: coin, heart                                               |
+------------------------------------------------------------------+
```

### Viewport Controls

- **Scroll wheel** - Zoom in/out centered on cursor
- **Middle-click + drag** - Pan the view
- **Left-click + drag** - Select region (in atlas coordinates)
- **[+] [-]** - Zoom buttons for trackpad users
- **[Fit]** - Fit entire atlas in viewport
- **[1:1]** - Actual pixel view

### Features

- **9-patch guide overlay** - Draggable lines to set border slices visually
- **State grouping** - For buttons, prompts to add all 4 states
- **Preview pane** - Shows 9-patch stretched at different sizes
- **Validation** - Warns if button missing states
- **Pixel-perfect selection** - Snaps to atlas pixels regardless of zoom

### Workflow

1. Load atlas texture (already imported via existing pipeline)
2. Click-drag to select rectangular region
3. Select element type (panel/button/etc.)
4. Set variant name, state (for stateful elements)
5. Adjust 9-patch borders if applicable
6. Add to pack
7. Repeat for all elements
8. Save pack.json

## File Structure

```
src/systems/ui/
├── ui_pack.hpp          # UIAssetPack, RegionDef, ButtonDef, etc.
├── ui_pack.cpp          # registerPack(), getPack(), JSON parsing
├── ui_pack_lua.cpp      # Lua bindings, PackHandle userdata

src/systems/ui/editor/
├── pack_editor.hpp      # ImGui manifest editor
├── pack_editor.cpp      # Viewport, selection, 9-patch guides

assets/ui_packs/
├── kenney_rpg/
│   ├── pack.json        # Manifest (generated by editor)
│   └── spritesheet.png  # Atlas texture
```

## What Stays Unchanged

- Existing UI element creation (`ui.box.Initialize`, DSL functions)
- Existing rendering paths (`DrawNPatchUIElement`, `DrawSteppedRoundedRectangle`)
- Existing asset pipeline (textures imported as normal)
- Existing Lua UI code (just gains new pack functions)
- OBJECT type behavior (for dynamic text/animated sprites)

## Implementation Tasks

1. **Define data structures** - `ui_pack.hpp` with `UIAssetPack`, `RegionDef`, element defs
2. **JSON parsing** - Load pack.json, populate `UIAssetPack`
3. **Registry in EngineContext** - Store loaded packs
4. **Lua bindings** - `register_pack`, `use_pack`, `PackHandle` userdata
5. **Rendering support** - Add `SPRITE` styling type, scale mode rendering
6. **ImGui editor** - Atlas viewport, region selection, 9-patch guides, export

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
