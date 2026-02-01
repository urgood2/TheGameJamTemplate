# Custom UI Sprite System Implementation Plan

## Overview
A robust, hassle-free sprite-based UI system with custom decorations, flexible sizing modes, and Lua command buffer rendering. Uses **TDD (Test-Driven Development)** throughout.

## Key Features
- **Nine-patch panels** with mixed stretch/tile/fixed modes per region
- **Custom decorations** - sprite overlays for corners, edges, centers
- **Two sizing modes** - sprite-to-size OR size-to-sprite
- **Lua command buffer** - custom rendering hooks
- **Minimal config friction** - inline Lua definitions, no JSON required

## Worktree Setup
```bash
git worktree add .worktrees/inventory-ui-custom-decorations feature/inventory-grid-ui-part-2
cd .worktrees/inventory-ui-custom-decorations
# Create new branch for this feature
git checkout -b feature/inventory-ui-custom-decorations
```

---

## Phase 1: TDD Foundation - Write Tests First

### 1.1 C++ Unit Tests (Write First)
**File:** `tests/unit/test_ui_sprite_system.cpp`

```cpp
// RED: These tests should FAIL initially
TEST(NinePatchTest, MixedModes_StaticCornerWithTiledEdge) {
    // Corner uses Fixed mode, edge uses Tile mode
}

TEST(NinePatchTest, SizeToSprite_ContainerResizesToFitSprite) {
    // Container should adopt sprite dimensions
}

TEST(NinePatchTest, SpriteToSize_SpriteStretchesToFitContainer) {
    // Sprite should scale to container dimensions
}

TEST(DecorationTest, OverlayRendersAbovePanel) {
    // Decoration sprite renders on top of base panel
}
```

### 1.2 Lua Integration Tests (Write First)
**File:** `assets/scripts/tests/test_sprite_ui.lua`

```lua
-- RED: These tests should FAIL initially
function test_inline_panel_definition()
    -- No JSON file needed
    local panel = dsl.spritePanel {
        sprite = "panel_bg.png",
        borders = { 8, 8, 8, 8 },
        children = { dsl.text("Hello") }
    }
    assert(panel ~= nil)
end

function test_size_to_sprite_mode()
    -- Container resizes to fit the sprite
    local panel = dsl.spritePanel {
        sprite = "fixed_size_frame.png",
        sizing = "fit_sprite"  -- vs "fit_content" (default)
    }
end

function test_decoration_overlay()
    local panel = dsl.spritePanel {
        sprite = "base_panel.png",
        decorations = {
            { sprite = "corner_flourish.png", position = "top_left" },
            { sprite = "corner_flourish.png", position = "top_right", flip = "horizontal" }
        }
    }
end
```

---

## Phase 2: Hassle-Free Lua API (No JSON Required)

### 2.1 Inline Sprite Panel Definition
**File:** `assets/scripts/ui/ui_syntax_sugar.lua`

```lua
-- SIMPLE: Just sprite + borders
dsl.spritePanel {
    sprite = "panel_wood.png",
    borders = { 12, 12, 12, 12 },  -- left, top, right, bottom
    children = { ... }
}

-- ADVANCED: Mixed modes per region
dsl.spritePanel {
    sprite = "ornate_frame.png",
    regions = {
        corners = { mode = "fixed" },      -- Static, never stretched
        edges = { mode = "tile" },          -- Tile to fill
        center = { mode = "stretch" }       -- Stretch to fill (default)
    },
    children = { ... }
}

-- TWO SIZING MODES
dsl.spritePanel {
    sprite = "card_frame.png",
    sizing = "fit_sprite",  -- Container adopts sprite dimensions
    -- OR
    sizing = "fit_content", -- Sprite stretches to fit content (default)
}
```

### 2.2 Custom Decorations System
```lua
dsl.spritePanel {
    sprite = "base_panel.png",
    borders = { 8, 8, 8, 8 },
    decorations = {
        -- Corner flourishes
        { sprite = "flourish_tl.png", anchor = "top_left", offset = {-4, -4} },
        { sprite = "flourish_tr.png", anchor = "top_right", offset = {4, -4} },

        -- Edge decorations (centered on edge)
        { sprite = "title_bar.png", anchor = "top_center", offset = {0, -8} },

        -- Center overlay
        { sprite = "watermark.png", anchor = "center", opacity = 0.3 },
    },
    children = { ... }
}
```

### 2.3 Sprite Button with States
```lua
dsl.spriteButton {
    states = {
        normal = "btn_normal.png",
        hover = "btn_hover.png",
        pressed = "btn_pressed.png",
        disabled = "btn_disabled.png",
    },
    borders = { 4, 4, 4, 4 },
    onClick = function() ... end,
    children = { dsl.text("Click Me") }
}

-- Or shorthand with auto-suffixes
dsl.spriteButton {
    sprite = "btn_blue",  -- Auto-finds btn_blue_normal.png, btn_blue_hover.png, etc.
    onClick = fn
}
```

---

## Phase 3: Lua Command Buffer Rendering

### 3.1 Custom Render Hook
**File:** `assets/scripts/ui/ui_syntax_sugar.lua`

Allow custom rendering via Lua command buffer:

```lua
dsl.customPanel {
    minWidth = 200,
    minHeight = 100,

    -- Called every frame with bounds
    onDraw = function(bounds, layer, z)
        -- Use command_buffer API
        command_buffer.queueDrawTexture(layer, function(cmd)
            cmd.texture = getTexture("my_panel.png")
            cmd.x = bounds.x
            cmd.y = bounds.y
            cmd.width = bounds.width
            cmd.height = bounds.height
        end, z)

        -- Draw additional decorations
        command_buffer.queueDrawTexture(layer, function(cmd)
            cmd.texture = getTexture("corner.png")
            cmd.x = bounds.x - 8
            cmd.y = bounds.y - 8
        end, z + 1)
    end,

    children = { ... }
}
```

### 3.2 C++ Hook Integration
**File:** `src/systems/ui/element.cpp`

Add callback point in DrawSelf() for custom Lua rendering:

```cpp
// After standard rendering, check for custom draw callback
if (config.hasCustomDrawCallback) {
    // Call Lua function with bounds
    sol::protected_function callback = config.customDrawCallback;
    callback(elementBounds, layerName, zIndex);
}
```

---

## Phase 4: Mixed Nine-Patch Modes

### 4.1 Per-Region Scale Mode
**File:** `src/systems/nine_patch/nine_patch_baker.hpp`

Extend NPatchTiling to support per-region modes:

```cpp
struct NPatchRegionModes {
    SpriteScaleMode topLeft = SpriteScaleMode::Fixed;
    SpriteScaleMode topRight = SpriteScaleMode::Fixed;
    SpriteScaleMode bottomLeft = SpriteScaleMode::Fixed;
    SpriteScaleMode bottomRight = SpriteScaleMode::Fixed;
    SpriteScaleMode top = SpriteScaleMode::Tile;
    SpriteScaleMode bottom = SpriteScaleMode::Tile;
    SpriteScaleMode left = SpriteScaleMode::Tile;
    SpriteScaleMode right = SpriteScaleMode::Tile;
    SpriteScaleMode center = SpriteScaleMode::Stretch;
};
```

### 4.2 Decoration Overlay System
**File:** `src/systems/ui/ui_decoration.hpp` (NEW)

```cpp
struct UIDecoration {
    std::string spriteName;
    enum class Anchor {
        TopLeft, TopCenter, TopRight,
        MiddleLeft, Center, MiddleRight,
        BottomLeft, BottomCenter, BottomRight
    } anchor;
    Vector2 offset{0, 0};
    float opacity = 1.0f;
    bool flipX = false;
    bool flipY = false;
    float rotation = 0.0f;          // Degrees
    Vector2 scale = {1.0f, 1.0f};   // Independent X/Y scale
    int zOffset = 0;                // Relative z-order (+1 = above, -1 = below)
    Color tint = WHITE;             // Tint color
    bool visible = true;            // Toggle visibility
    std::string id;                 // For runtime lookup/modification
};

struct UIDecorations {
    std::vector<UIDecoration> decorations;
};
```

### 4.3 Additional Flexibility Ideas

#### A. Animated Decorations
```lua
decorations = {
    {
        sprite = "sparkle.png",
        anchor = "top_right",
        animation = {
            type = "pulse",       -- pulse, rotate, bob, shimmer
            speed = 1.0,
            intensity = 0.2
        }
    }
}
```

#### B. Conditional Decorations (State-Based)
```lua
decorations = {
    {
        sprite = "glow_active.png",
        anchor = "center",
        showWhen = "hover"  -- only show on hover state
    },
    {
        sprite = "badge_new.png",
        anchor = "top_right",
        showWhen = function(panel) return panel.data.isNew end
    }
}
```

#### C. Edge-Repeating Decorations
```lua
decorations = {
    {
        sprite = "chain_link.png",
        edge = "top",           -- repeat along entire top edge
        spacing = 16,           -- pixels between each
        offset = { 0, -4 }
    },
    {
        sprite = "rivet.png",
        corners = true,         -- place at all 4 corners
        offset = { 4, 4 }
    }
}
```

#### D. Decoration Templates (Reusable)
```lua
-- Define once
local fancyBorder = dsl.decorationTemplate {
    { sprite = "corner_gold.png", corners = true },
    { sprite = "edge_gold.png", edges = true, tile = true }
}

-- Use many times
dsl.spritePanel {
    sprite = "base.png",
    decorations = fancyBorder,
    children = { ... }
}

dsl.spritePanel {
    sprite = "another_base.png",
    decorations = fancyBorder,  -- Same decoration set
    children = { ... }
}
```

#### E. Decoration Inheritance
```lua
-- Parent panel decorations can cascade to children
dsl.spritePanel {
    sprite = "container.png",
    decorations = { ... },
    decorationInherit = true,  -- Children inherit parent decorations
    children = {
        dsl.spritePanel {
            sprite = "child.png",
            decorationOverride = { ... }  -- Override specific decorations
        }
    }
}
```

#### F. 9-Slice Decorations (Separate from Panel)
```lua
-- Decoration that is itself a 9-patch
decorations = {
    {
        sprite = "ornate_frame.png",
        borders = { 16, 16, 16, 16 },
        mode = "9patch",
        inset = -8,  -- Extend beyond panel bounds
    }
}
```

#### G. Runtime Decoration Control
```lua
-- Get decoration by ID and modify at runtime
local panel = dsl.spritePanel {
    decorations = {
        { id = "badge", sprite = "badge.png", anchor = "top_right", visible = false }
    }
}

-- Later, show the badge
panel:setDecorationVisible("badge", true)
panel:setDecorationSprite("badge", "badge_urgent.png")
panel:setDecorationTint("badge", util.getColor("red"))
```

#### H. Layered Backgrounds (Multiple Sprites)
```lua
-- Stack multiple background sprites with different blend modes
dsl.spritePanel {
    backgrounds = {
        { sprite = "noise_texture.png", mode = "tile", opacity = 0.1 },
        { sprite = "gradient_overlay.png", mode = "stretch", blend = "multiply" },
        { sprite = "main_panel.png", borders = { 8, 8, 8, 8 } }  -- Top layer
    },
    children = { ... }
}
```

---

## Phase 5: Main Menu Showcase Tab

### 5.1 Add to Existing Demo
**File:** `assets/scripts/core/main.lua` (line 501-570)

```lua
{
    id = "sprites",
    label = "Sprites",
    content = function()
        return require("ui.sprite_ui_showcase").createShowcase()
    end
}
```

### 5.2 Showcase Contents
**New File:** `assets/scripts/ui/sprite_ui_showcase.lua`

- Nine-patch panel grid (different border sizes)
- Mixed mode demo (static corners + tiled edges)
- Sizing mode comparison (fit_sprite vs fit_content)
- Decoration overlays demo
- Button state transitions
- Custom render hook example
- Interactive controls to toggle options

---

## Phase 6: C++ State System Integration

### 6.1 State Backgrounds Component
**File:** `src/systems/ui/ui_data.hpp`

```cpp
struct UIStyleConfig {
    UIStylingType stylingType;
    std::optional<NPatchInfo> nPatchInfo;
    std::optional<Texture2D*> nPatchSourceTexture;
    std::optional<Texture2D*> spriteSourceTexture;
    std::optional<Rectangle> spriteSourceRect;
    SpriteScaleMode spriteScaleMode;
    std::optional<Color> color;
};

struct UIStateBackgrounds {
    std::optional<UIStyleConfig> normal, hover, pressed, disabled;
    State currentState = State::NORMAL;
    const UIStyleConfig* getCurrentStyle() const;
};
```

### 6.2 State Update in Render Loop
**File:** `src/systems/ui/element.cpp`

In `UpdateUIElementState()` (call from draw or update):
1. Check `node->state.isBeingHovered`, `cursor_down`, `disable_button`
2. If state changed, copy style from `UIStateBackgrounds` to `UIConfig`

---

## Phase 7: Testing (TDD - GREEN Phase)

Make the tests from Phase 1 pass:

### 7.1 C++ Tests Pass
- Mixed modes (static corners + tiled edges)
- Size-to-sprite mode
- Sprite-to-size mode
- Decoration overlay rendering

### 7.2 Lua Tests Pass
- Inline panel definition (no JSON)
- Decoration overlays
- Button state sprites
- Custom render hook

### 7.3 Visual Verification
The showcase tab serves as manual verification:
- All sizing modes render correctly
- Mixed nine-patch modes work
- Decorations positioned correctly
- State transitions visible on hover/click
- Custom render hook executes

---

## Critical Files Summary

| File | Action |
|------|--------|
| `tests/unit/test_ui_sprite_system.cpp` | TDD: Write tests FIRST |
| `assets/scripts/tests/test_sprite_ui.lua` | TDD: Write tests FIRST |
| `assets/scripts/ui/ui_syntax_sugar.lua` | Add spritePanel, spriteButton, customPanel |
| `src/systems/ui/ui_data.hpp` | Add UIStateBackgrounds, UIDecorations |
| `src/systems/ui/ui_decoration.hpp` | NEW - decoration overlay system |
| `src/systems/nine_patch/nine_patch_baker.hpp` | Add NPatchRegionModes |
| `src/systems/ui/element.cpp` | Add state update + custom draw callback |
| `assets/scripts/core/main.lua` | Add "Sprites" tab to demo |
| `assets/scripts/ui/sprite_ui_showcase.lua` | NEW - main menu showcase |

---

## TDD Implementation Order

### Core Features (Must Have)
1. **Create worktree** `inventory-ui-custom-decorations`
2. **RED: Write tests** for core features (inline panels, sizing modes, basic decorations)
3. **GREEN: Implement `dsl.spritePanel`** with inline definition (no JSON)
4. **GREEN: Implement sizing modes** (fit_sprite vs fit_content)
5. **GREEN: Implement basic decorations** (anchor positions, offset, flip)
6. **GREEN: Implement state system** (hover/press sprite swapping)
7. **SHOWCASE: Visual demo tab** in main menu

### Extended Features (Nice to Have)
8. **GREEN: Mixed nine-patch modes** (fixed corners + tiled edges)
9. **GREEN: Command buffer hook** (custom Lua rendering)
10. **GREEN: Decoration templates** (reusable decoration sets)
11. **GREEN: Runtime decoration control** (show/hide/modify by ID)
12. **GREEN: Conditional decorations** (showWhen state/function)

### Future Features (If Time Permits)
13. Animated decorations (pulse, rotate, bob)
14. Edge-repeating decorations
15. 9-slice decorations
16. Layered backgrounds
17. Decoration inheritance

### Final
18. **REFACTOR: Clean up and optimize**
19. **REVIEW: Final code review** via annotation system

---

## Success Criteria

### Core (Required)
- [ ] All C++ unit tests pass (TDD green)
- [ ] All Lua integration tests pass (TDD green)
- [ ] `dsl.spritePanel { sprite = "x.png", borders = {...} }` works inline (no JSON)
- [ ] Two sizing modes work (fit_sprite vs fit_content)
- [ ] Basic decorations render at correct anchors
- [ ] Button states visually transition on hover/press/disable
- [ ] Visual showcase demonstrates core features

### Extended (Goal)
- [ ] Mixed nine-patch modes work (fixed corners + tiled edges)
- [ ] Custom render hook executes every frame
- [ ] Decoration templates are reusable
- [ ] Runtime decoration modification works
- [ ] Conditional decorations show/hide based on state

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
