# C++ UI System Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Split the monolithic UIConfig (170+ fields) into separate ECS components and introduce type handlers via strategy pattern, without changing Lua bindings.

**Architecture:** Phase 1 adds new split components alongside existing UIConfig. Phase 2 migrates readers. Phase 3 migrates builders. Phase 4 introduces type handlers. Phase 5 cleans up.

**Tech Stack:** C++20, EnTT ECS, Sol2 Lua bindings, GoogleTest

---

## Phase 1: Add New Components (Parallel with Old)

### Task 1.1: Create Core Component Headers

**Files:**
- Create: `src/systems/ui/core/ui_components.hpp`

**Step 1: Create directory structure**

```bash
mkdir -p src/systems/ui/core
mkdir -p src/systems/ui/handlers
```

**Step 2: Create the new component definitions**

Create `src/systems/ui/core/ui_components.hpp`:

```cpp
#pragma once

#include "entt/entity/fwd.hpp"
#include "util/common_headers.hpp"
#include "systems/transform/transform_functions.hpp"
#include "systems/ui/ui_data.hpp"  // For UITypeEnum, UIStylingType, etc.

#include <string>
#include <optional>
#include <functional>

namespace ui {

// =============================================================================
// UIElementCore - Identity and hierarchy (always present)
// =============================================================================
struct UIElementCore {
    UITypeEnum type{UITypeEnum::NONE};
    entt::entity uiBox{entt::null};
    std::string id;
    int treeOrder{0};
};

// =============================================================================
// UIStyleConfig - Visual appearance only
// =============================================================================
struct UIStyleConfig {
    // Styling type
    UIStylingType stylingType{UIStylingType::ROUNDED_RECTANGLE};

    // Colors
    std::optional<Color> color;
    std::optional<Color> outlineColor;
    std::optional<Color> shadowColor;
    std::optional<Color> progressBarEmptyColor;
    std::optional<Color> progressBarFullColor;

    // Outline & effects
    std::optional<float> outlineThickness;
    std::optional<float> emboss;
    std::optional<float> resolution;
    bool shadow{false};
    bool outlineShadow{false};
    bool noFill{false};
    bool pixelatedRectangle{true};
    bool line_emboss{false};

    // 9-patch styling
    std::optional<NPatchInfo> nPatchInfo;
    std::optional<Texture2D> nPatchSourceTexture;
    std::optional<nine_patch::NPatchTiling> nPatchTiling;

    // Sprite styling
    std::optional<Texture2D*> spriteSourceTexture;
    std::optional<Rectangle> spriteSourceRect;
    SpriteScaleMode spriteScaleMode{SpriteScaleMode::Stretch};
};

// =============================================================================
// UILayoutConfig - Positioning and dimensions
// =============================================================================
struct UILayoutConfig {
    // Dimensions
    std::optional<int> width, height;
    std::optional<int> maxWidth, maxHeight;
    std::optional<int> minWidth, minHeight;
    std::optional<float> padding;
    std::optional<float> extend_up;

    // Alignment
    std::optional<int> alignmentFlags;

    // Transform bonds
    std::optional<transform::InheritedProperties::Sync> location_bond;
    std::optional<transform::InheritedProperties::Sync> rotation_bond;
    std::optional<transform::InheritedProperties::Sync> size_bond;
    std::optional<transform::InheritedProperties::Sync> scale_bond;

    // Position & scale
    std::optional<Vector2> offset;
    std::optional<float> scale;

    // Layout behavior
    std::optional<bool> no_recalc;
    std::optional<bool> non_recalc;
    bool mid{false};
    std::optional<bool> noRole;
    std::optional<transform::InheritedProperties> role;

    // Hierarchy
    std::optional<entt::entity> master;
    std::optional<entt::entity> parent;
    std::optional<int> drawLayer;
    bool draw_after{false};
};

// =============================================================================
// UIInteractionConfig - Input handling and callbacks
// =============================================================================
struct UIInteractionConfig {
    // Collision & interaction flags
    std::optional<bool> canCollide;
    std::optional<bool> collideable;
    std::optional<bool> forceCollision;
    bool hover{false};

    // Button behavior
    std::optional<entt::entity> button_UIE;
    bool disable_button{false};
    std::optional<float> buttonDelay;
    std::optional<float> buttonDelayStart;
    std::optional<float> buttonDelayEnd;
    std::optional<float> buttonDelayProgress;
    std::optional<float> buttonDistance;
    bool buttonClicked{false};

    // Focus
    bool force_focus{false};
    std::optional<bool> focusWithObject;
    std::optional<FocusArgs> focusArgs;

    // Tooltips
    std::optional<Tooltip> tooltip;
    std::optional<Tooltip> detailedTooltip;
    std::optional<Tooltip> onDemandTooltip;

    // Callbacks
    std::optional<std::function<void()>> buttonCallback;
    std::optional<std::function<void()>> buttonTemp;
    std::optional<std::function<void(entt::registry*, entt::entity, float)>> updateFunc;
    std::optional<std::function<void(entt::registry*, entt::entity)>> initFunc;
    std::optional<std::function<void(entt::registry*, entt::entity)>> onUIResizeFunc;
    std::optional<std::function<void(entt::registry*, entt::entity)>> onUIScalingResetToOne;
    std::optional<bool> instaFunc;

    // Choice/selection
    std::optional<bool> choice;
    std::optional<bool> chosen;
    std::optional<bool> one_press;
    std::optional<std::string> chosen_vert;
    std::optional<std::string> group;
    std::optional<entt::entity> groupParent;

    // Motion
    std::optional<bool> dynamicMotion;
    bool makeMovementDynamic{false};
    bool noMovementWhenDragged{false};
    std::optional<bool> refreshMovement;
};

// =============================================================================
// UIContentConfig - Text, objects, references (type-specific content)
// =============================================================================
struct UIContentConfig {
    // Text
    std::optional<std::string> text;
    std::optional<std::string> language;
    std::optional<bool> verticalText;
    std::optional<float> textSpacing;
    std::optional<float> fontSize;
    std::optional<std::string> fontName;
    std::optional<std::function<std::string()>> textGetter;

    // Object attachment
    std::optional<entt::entity> object;
    bool objectRecalculate{false};
    bool ui_object_updated{false};
    bool includeChildrenInShaderPass{true};

    // Progress bar
    bool progressBar{false};
    std::optional<float> progressBarMaxValue;
    std::optional<std::string> progressBarValueComponentName;
    std::optional<std::string> progressBarValueFieldName;
    std::optional<std::function<float(entt::entity)>> progressBarFetchValueLambda;

    // Reference system
    std::optional<entt::entity> ref_entity;
    std::optional<std::string> ref_component;
    std::optional<std::string> ref_value;
    std::optional<entt::meta_any> prev_ref_value;

    // Popups
    std::optional<entt::entity> hPopup;
    std::optional<entt::entity> dPopup;
    std::shared_ptr<UIConfig> hPopupConfig;
    std::shared_ptr<UIConfig> dPopupConfig;

    // Instance metadata
    std::optional<std::string> instanceType;
};

// =============================================================================
// UIConfigBundle - For passing all configs through builder
// =============================================================================
struct UIConfigBundle {
    UIStyleConfig style;
    UILayoutConfig layout;
    UIInteractionConfig interaction;
    UIContentConfig content;
};

// =============================================================================
// Extraction functions (Phase 1 compatibility layer)
// =============================================================================
UIStyleConfig extractStyle(const UIConfig& config);
UILayoutConfig extractLayout(const UIConfig& config);
UIInteractionConfig extractInteraction(const UIConfig& config);
UIContentConfig extractContent(const UIConfig& config);

} // namespace ui
```

**Step 3: Run build to verify header compiles**

```bash
just build-debug-ninja 2>&1 | head -50
```

Expected: Build succeeds (header not yet included anywhere)

**Step 4: Commit**

```bash
git add src/systems/ui/core/
git commit -m "feat(ui): add split component header definitions

Introduces UIStyleConfig, UILayoutConfig, UIInteractionConfig, UIContentConfig
as separate ECS components. These will coexist with UIConfig during migration."
```

---

### Task 1.2: Implement Extraction Functions

**Files:**
- Create: `src/systems/ui/core/ui_components.cpp`
- Modify: `src/systems/ui/CMakeLists.txt` (if exists) or main CMakeLists.txt

**Step 1: Create extraction implementation**

Create `src/systems/ui/core/ui_components.cpp`:

```cpp
#include "ui_components.hpp"

namespace ui {

UIStyleConfig extractStyle(const UIConfig& c) {
    UIStyleConfig s;
    s.stylingType = c.stylingType;
    s.color = c.color;
    s.outlineColor = c.outlineColor;
    s.shadowColor = c.shadowColor;
    s.progressBarEmptyColor = c.progressBarEmptyColor;
    s.progressBarFullColor = c.progressBarFullColor;
    s.outlineThickness = c.outlineThickness;
    s.emboss = c.emboss;
    s.resolution = c.resolution;
    s.shadow = c.shadow;
    s.outlineShadow = c.outlineShadow;
    s.noFill = c.noFill;
    s.pixelatedRectangle = c.pixelatedRectangle;
    s.line_emboss = c.line_emboss;
    s.nPatchInfo = c.nPatchInfo;
    s.nPatchSourceTexture = c.nPatchSourceTexture;
    s.nPatchTiling = c.nPatchTiling;
    s.spriteSourceTexture = c.spriteSourceTexture;
    s.spriteSourceRect = c.spriteSourceRect;
    s.spriteScaleMode = c.spriteScaleMode;
    return s;
}

UILayoutConfig extractLayout(const UIConfig& c) {
    UILayoutConfig l;
    l.width = c.width;
    l.height = c.height;
    l.maxWidth = c.maxWidth;
    l.maxHeight = c.maxHeight;
    l.minWidth = c.minWidth;
    l.minHeight = c.minHeight;
    l.padding = c.padding;
    l.extend_up = c.extend_up;
    l.alignmentFlags = c.alignmentFlags;
    l.location_bond = c.location_bond;
    l.rotation_bond = c.rotation_bond;
    l.size_bond = c.size_bond;
    l.scale_bond = c.scale_bond;
    l.offset = c.offset;
    l.scale = c.scale;
    l.no_recalc = c.no_recalc;
    l.non_recalc = c.non_recalc;
    l.mid = c.mid;
    l.noRole = c.noRole;
    l.role = c.role;
    l.master = c.master;
    l.parent = c.parent;
    l.drawLayer = c.drawLayer;
    l.draw_after = c.draw_after;
    return l;
}

UIInteractionConfig extractInteraction(const UIConfig& c) {
    UIInteractionConfig i;
    i.canCollide = c.canCollide;
    i.collideable = c.collideable;
    i.forceCollision = c.forceCollision;
    i.hover = c.hover;
    i.button_UIE = c.button_UIE;
    i.disable_button = c.disable_button;
    i.buttonDelay = c.buttonDelay;
    i.buttonDelayStart = c.buttonDelayStart;
    i.buttonDelayEnd = c.buttonDelayEnd;
    i.buttonDelayProgress = c.buttonDelayProgress;
    i.buttonDistance = c.buttonDistance;
    i.buttonClicked = c.buttonClicked;
    i.force_focus = c.force_focus;
    i.focusWithObject = c.focusWithObject;
    i.focusArgs = c.focusArgs;
    i.tooltip = c.tooltip;
    i.detailedTooltip = c.detailedTooltip;
    i.onDemandTooltip = c.onDemandTooltip;
    i.buttonCallback = c.buttonCallback;
    i.buttonTemp = c.buttonTemp;
    i.updateFunc = c.updateFunc;
    i.initFunc = c.initFunc;
    i.onUIResizeFunc = c.onUIResizeFunc;
    i.onUIScalingResetToOne = c.onUIScalingResetToOne;
    i.instaFunc = c.instaFunc;
    i.choice = c.choice;
    i.chosen = c.chosen;
    i.one_press = c.one_press;
    i.chosen_vert = c.chosen_vert;
    i.group = c.group;
    i.groupParent = c.groupParent;
    i.dynamicMotion = c.dynamicMotion;
    i.makeMovementDynamic = c.makeMovementDynamic;
    i.noMovementWhenDragged = c.noMovementWhenDragged;
    i.refreshMovement = c.refreshMovement;
    return i;
}

UIContentConfig extractContent(const UIConfig& c) {
    UIContentConfig t;
    t.text = c.text;
    t.language = c.language;
    t.verticalText = c.verticalText;
    t.textSpacing = c.textSpacing;
    t.fontSize = c.fontSize;
    t.fontName = c.fontName;
    t.textGetter = c.textGetter;
    t.object = c.object;
    t.objectRecalculate = c.objectRecalculate;
    t.ui_object_updated = c.ui_object_updated;
    t.includeChildrenInShaderPass = c.includeChildrenInShaderPass;
    t.progressBar = c.progressBar;
    t.progressBarMaxValue = c.progressBarMaxValue;
    t.progressBarValueComponentName = c.progressBarValueComponentName;
    t.progressBarValueFieldName = c.progressBarValueFieldName;
    t.progressBarFetchValueLambda = c.progressBarFetchValueLambda;
    t.ref_entity = c.ref_entity;
    t.ref_component = c.ref_component;
    t.ref_value = c.ref_value;
    t.prev_ref_value = c.prev_ref_value;
    t.hPopup = c.hPopup;
    t.dPopup = c.dPopup;
    t.hPopupConfig = c.hPopupConfig;
    t.dPopupConfig = c.dPopupConfig;
    t.instanceType = c.instanceType;
    return t;
}

} // namespace ui
```

**Step 2: Add to build system**

Find where UI sources are listed in CMakeLists.txt and add:
```cmake
src/systems/ui/core/ui_components.cpp
```

**Step 3: Build and verify**

```bash
just build-debug-ninja 2>&1 | tail -20
```

Expected: Build succeeds

**Step 4: Commit**

```bash
git add src/systems/ui/core/ui_components.cpp CMakeLists.txt
git commit -m "feat(ui): implement extraction functions for component migration"
```

---

### Task 1.3: Add New Components in Initialize

**Files:**
- Modify: `src/systems/ui/element.cpp:43-121`

**Step 1: Add include at top of element.cpp**

After existing includes, add:
```cpp
#include "core/ui_components.hpp"
```

**Step 2: Modify Initialize to emplace split components**

In `element::Initialize` function, after line 74 (`registry.emplace<UIState>(entity);`), add:

```cpp
        // NEW: Emplace split components for gradual migration
        if (config) {
            registry.emplace<UIElementCore>(entity, UIElementCore{
                .type = type,
                .uiBox = uiBox,
                .id = config->id.value_or(""),
                .treeOrder = 0
            });
            registry.emplace<UIStyleConfig>(entity, extractStyle(*config));
            registry.emplace<UILayoutConfig>(entity, extractLayout(*config));
            registry.emplace<UIInteractionConfig>(entity, extractInteraction(*config));
            registry.emplace<UIContentConfig>(entity, extractContent(*config));
        } else {
            registry.emplace<UIElementCore>(entity, UIElementCore{
                .type = type,
                .uiBox = uiBox,
                .id = "",
                .treeOrder = 0
            });
            registry.emplace<UIStyleConfig>(entity);
            registry.emplace<UILayoutConfig>(entity);
            registry.emplace<UIInteractionConfig>(entity);
            registry.emplace<UIContentConfig>(entity);
        }
```

**Step 3: Build and run tests**

```bash
just build-debug-ninja && just test
```

Expected: All tests pass

**Step 4: Commit**

```bash
git add src/systems/ui/element.cpp
git commit -m "feat(ui): emplace split components in Initialize

Both old UIConfig and new split components are now created.
This allows gradual migration of readers."
```

---

### Task 1.4: Expose New Components to Lua

**Files:**
- Modify: `src/systems/ui/ui.cpp`

**Step 1: Add include**

After existing includes in ui.cpp:
```cpp
#include "core/ui_components.hpp"
```

**Step 2: Add Sol2 bindings for new components**

After the UIConfig usertype binding (around line 450), add:

```cpp
        //=========================================================
        // Split Components (Phase 1 Migration)
        //=========================================================

        // UIElementCore
        lua.new_usertype<UIElementCore>("UIElementCore",
            sol::constructors<>(),
            "type", &UIElementCore::type,
            "uiBox", &UIElementCore::uiBox,
            "id", &UIElementCore::id,
            "treeOrder", &UIElementCore::treeOrder,
            "type_id", []() { return entt::type_hash<UIElementCore>::value(); }
        );
        rec.add_type("UIElementCore", true).doc = "Core identity component for UI elements.";

        // UIStyleConfig
        lua.new_usertype<UIStyleConfig>("UIStyleConfig",
            sol::constructors<>(),
            "stylingType", &UIStyleConfig::stylingType,
            "color", &UIStyleConfig::color,
            "outlineColor", &UIStyleConfig::outlineColor,
            "shadowColor", &UIStyleConfig::shadowColor,
            "outlineThickness", &UIStyleConfig::outlineThickness,
            "shadow", &UIStyleConfig::shadow,
            "noFill", &UIStyleConfig::noFill,
            "pixelatedRectangle", &UIStyleConfig::pixelatedRectangle,
            "emboss", &UIStyleConfig::emboss,
            "type_id", []() { return entt::type_hash<UIStyleConfig>::value(); }
        );
        rec.add_type("UIStyleConfig", true).doc = "Visual styling configuration for UI elements.";

        // UILayoutConfig
        lua.new_usertype<UILayoutConfig>("UILayoutConfig",
            sol::constructors<>(),
            "width", &UILayoutConfig::width,
            "height", &UILayoutConfig::height,
            "padding", &UILayoutConfig::padding,
            "alignmentFlags", &UILayoutConfig::alignmentFlags,
            "offset", &UILayoutConfig::offset,
            "scale", &UILayoutConfig::scale,
            "type_id", []() { return entt::type_hash<UILayoutConfig>::value(); }
        );
        rec.add_type("UILayoutConfig", true).doc = "Layout and positioning configuration for UI elements.";

        // UIInteractionConfig
        lua.new_usertype<UIInteractionConfig>("UIInteractionConfig",
            sol::constructors<>(),
            "hover", &UIInteractionConfig::hover,
            "canCollide", &UIInteractionConfig::canCollide,
            "buttonCallback", &UIInteractionConfig::buttonCallback,
            "tooltip", &UIInteractionConfig::tooltip,
            "focusArgs", &UIInteractionConfig::focusArgs,
            "type_id", []() { return entt::type_hash<UIInteractionConfig>::value(); }
        );
        rec.add_type("UIInteractionConfig", true).doc = "Interaction and input handling configuration.";

        // UIContentConfig
        lua.new_usertype<UIContentConfig>("UIContentConfig",
            sol::constructors<>(),
            "text", &UIContentConfig::text,
            "fontSize", &UIContentConfig::fontSize,
            "fontName", &UIContentConfig::fontName,
            "object", &UIContentConfig::object,
            "progressBar", &UIContentConfig::progressBar,
            "type_id", []() { return entt::type_hash<UIContentConfig>::value(); }
        );
        rec.add_type("UIContentConfig", true).doc = "Content configuration (text, objects, progress bars).";
```

**Step 3: Build and test**

```bash
just build-debug-ninja && just test
```

Expected: All tests pass

**Step 4: Commit**

```bash
git add src/systems/ui/ui.cpp
git commit -m "feat(ui): expose split components to Lua via Sol2

New components can now be accessed from Lua for debugging/inspection."
```

---

## Phase 2: Create Handler Infrastructure

### Task 2.1: Create Handler Interface

**Files:**
- Create: `src/systems/ui/handlers/handler_interface.hpp`

**Step 1: Create handler interface**

```cpp
#pragma once

#include "entt/entity/registry.hpp"
#include "../core/ui_components.hpp"
#include "systems/transform/transform_functions.hpp"

namespace ui {

struct IUIElementHandler {
    virtual ~IUIElementHandler() = default;

    // Layout phase - calculate element dimensions
    virtual void calculateSize(
        entt::registry& registry,
        entt::entity entity,
        UILayoutConfig& layout,
        float scaleFactor
    ) = 0;

    // Render phase - draw the element
    virtual void draw(
        entt::registry& registry,
        entt::entity entity,
        const UIStyleConfig& style,
        const transform::Transform& transform
    ) = 0;

    // Optional: input handling
    virtual bool handleClick(
        entt::registry& registry,
        entt::entity entity,
        UIInteractionConfig& interaction,
        Vector2 mousePos
    ) { return false; }

    virtual void handleHover(
        entt::registry& registry,
        entt::entity entity,
        UIInteractionConfig& interaction
    ) {}

    // Optional: update per frame
    virtual void update(
        entt::registry& registry,
        entt::entity entity,
        float dt
    ) {}
};

} // namespace ui
```

**Step 2: Commit**

```bash
git add src/systems/ui/handlers/
git commit -m "feat(ui): add IUIElementHandler interface

Base interface for type-specific UI element handlers."
```

---

### Task 2.2: Create Handler Registry

**Files:**
- Create: `src/systems/ui/handlers/handler_registry.hpp`
- Create: `src/systems/ui/handlers/handler_registry.cpp`

**Step 1: Create registry header**

```cpp
#pragma once

#include "handler_interface.hpp"
#include "../ui_data.hpp"
#include <memory>
#include <unordered_map>

namespace ui {

class UIHandlerRegistry {
public:
    static UIHandlerRegistry& instance();

    void registerHandler(UITypeEnum type, std::unique_ptr<IUIElementHandler> handler);
    IUIElementHandler* get(UITypeEnum type);
    bool hasHandler(UITypeEnum type) const;

private:
    UIHandlerRegistry() = default;
    std::unordered_map<UITypeEnum, std::unique_ptr<IUIElementHandler>> handlers_;
};

// Call this once at startup to register all handlers
void registerAllHandlers();

} // namespace ui
```

**Step 2: Create registry implementation**

```cpp
#include "handler_registry.hpp"
#include <spdlog/spdlog.h>

namespace ui {

UIHandlerRegistry& UIHandlerRegistry::instance() {
    static UIHandlerRegistry inst;
    return inst;
}

void UIHandlerRegistry::registerHandler(UITypeEnum type, std::unique_ptr<IUIElementHandler> handler) {
    handlers_[type] = std::move(handler);
    SPDLOG_DEBUG("Registered handler for UITypeEnum::{}", static_cast<int>(type));
}

IUIElementHandler* UIHandlerRegistry::get(UITypeEnum type) {
    auto it = handlers_.find(type);
    return (it != handlers_.end()) ? it->second.get() : nullptr;
}

bool UIHandlerRegistry::hasHandler(UITypeEnum type) const {
    return handlers_.find(type) != handlers_.end();
}

void registerAllHandlers() {
    // Will be populated as handlers are implemented
    SPDLOG_INFO("UI handler registration complete");
}

} // namespace ui
```

**Step 3: Add to build system**

Add to CMakeLists.txt:
```cmake
src/systems/ui/handlers/handler_registry.cpp
```

**Step 4: Build and test**

```bash
just build-debug-ninja && just test
```

**Step 5: Commit**

```bash
git add src/systems/ui/handlers/ CMakeLists.txt
git commit -m "feat(ui): add UIHandlerRegistry for type-specific handlers"
```

---

### Task 2.3: Implement RectHandler (Simplest Type)

**Files:**
- Create: `src/systems/ui/handlers/rect_handler.hpp`
- Create: `src/systems/ui/handlers/rect_handler.cpp`

**Step 1: Create rect handler header**

```cpp
#pragma once

#include "handler_interface.hpp"

namespace ui {

class RectHandler : public IUIElementHandler {
public:
    void calculateSize(
        entt::registry& registry,
        entt::entity entity,
        UILayoutConfig& layout,
        float scaleFactor
    ) override;

    void draw(
        entt::registry& registry,
        entt::entity entity,
        const UIStyleConfig& style,
        const transform::Transform& transform
    ) override;
};

} // namespace ui
```

**Step 2: Create rect handler implementation**

```cpp
#include "rect_handler.hpp"
#include "../util.hpp"
#include "core/globals.hpp"

namespace ui {

void RectHandler::calculateSize(
    entt::registry& registry,
    entt::entity entity,
    UILayoutConfig& layout,
    float scaleFactor
) {
    // RECT_SHAPE uses explicit dimensions from config
    // Size calculation is straightforward - just apply scale
    // The actual sizing is handled by the layout engine
}

void RectHandler::draw(
    entt::registry& registry,
    entt::entity entity,
    const UIStyleConfig& style,
    const transform::Transform& t
) {
    // Delegate to existing util functions for now
    // This will be refactored to self-contained logic later

    Rectangle rect = { t.actualX, t.actualY, t.actualW, t.actualH };

    if (style.stylingType == UIStylingType::ROUNDED_RECTANGLE) {
        // Use existing rounded rectangle drawing
        // util::DrawSteppedRoundedRectangle(...) - will integrate later
    }
    // For now, this is a placeholder - actual drawing remains in element.cpp
}

} // namespace ui
```

**Step 3: Register in handler_registry.cpp**

Add to `registerAllHandlers()`:

```cpp
#include "rect_handler.hpp"

void registerAllHandlers() {
    auto& reg = UIHandlerRegistry::instance();
    reg.registerHandler(UITypeEnum::RECT_SHAPE, std::make_unique<RectHandler>());
    SPDLOG_INFO("UI handler registration complete");
}
```

**Step 4: Add to build and test**

```bash
just build-debug-ninja && just test
```

**Step 5: Commit**

```bash
git add src/systems/ui/handlers/
git commit -m "feat(ui): implement RectHandler as first type handler"
```

---

## Phase 3: Write Unit Tests

### Task 3.1: Create UI Component Tests

**Files:**
- Create: `tests/unit/test_ui_components.cpp`

**Step 1: Write test file**

```cpp
#include <gtest/gtest.h>
#include "systems/ui/core/ui_components.hpp"
#include "systems/ui/ui_data.hpp"

using namespace ui;

class UIComponentsTest : public ::testing::Test {
protected:
    void SetUp() override {}
};

TEST_F(UIComponentsTest, ExtractStyle_CopiesAllFields) {
    UIConfig config;
    config.color = RED;
    config.outlineColor = BLUE;
    config.shadow = true;
    config.stylingType = UIStylingType::NINEPATCH_BORDERS;

    auto style = extractStyle(config);

    EXPECT_EQ(style.color, config.color);
    EXPECT_EQ(style.outlineColor, config.outlineColor);
    EXPECT_EQ(style.shadow, config.shadow);
    EXPECT_EQ(style.stylingType, config.stylingType);
}

TEST_F(UIComponentsTest, ExtractLayout_CopiesAllFields) {
    UIConfig config;
    config.width = 100;
    config.height = 200;
    config.padding = 10.0f;
    config.alignmentFlags = 5;

    auto layout = extractLayout(config);

    EXPECT_EQ(layout.width, config.width);
    EXPECT_EQ(layout.height, config.height);
    EXPECT_EQ(layout.padding, config.padding);
    EXPECT_EQ(layout.alignmentFlags, config.alignmentFlags);
}

TEST_F(UIComponentsTest, ExtractInteraction_CopiesAllFields) {
    UIConfig config;
    config.hover = true;
    config.canCollide = true;
    config.force_focus = true;

    auto interaction = extractInteraction(config);

    EXPECT_EQ(interaction.hover, config.hover);
    EXPECT_EQ(interaction.canCollide, config.canCollide);
    EXPECT_EQ(interaction.force_focus, config.force_focus);
}

TEST_F(UIComponentsTest, ExtractContent_CopiesAllFields) {
    UIConfig config;
    config.text = "Hello";
    config.fontSize = 24.0f;
    config.progressBar = true;

    auto content = extractContent(config);

    EXPECT_EQ(content.text, config.text);
    EXPECT_EQ(content.fontSize, config.fontSize);
    EXPECT_EQ(content.progressBar, config.progressBar);
}

TEST_F(UIComponentsTest, UIElementCore_DefaultValues) {
    UIElementCore core;

    EXPECT_EQ(core.type, UITypeEnum::NONE);
    EXPECT_EQ(core.uiBox, entt::null);
    EXPECT_EQ(core.id, "");
    EXPECT_EQ(core.treeOrder, 0);
}
```

**Step 2: Add to test CMakeLists.txt**

Add `test_ui_components.cpp` to test sources.

**Step 3: Run tests**

```bash
just test
```

Expected: All new tests pass

**Step 4: Commit**

```bash
git add tests/unit/test_ui_components.cpp
git commit -m "test(ui): add unit tests for split component extraction"
```

---

## Phase 4: Migrate First Reader (Styling in Draw)

### Task 4.1: Update DrawSelf to Use UIStyleConfig

**Files:**
- Modify: `src/systems/ui/element.cpp` (DrawSelf function)

**Step 1: Locate DrawSelf function**

Find `void element::DrawSelf` in element.cpp.

**Step 2: Add fallback pattern**

At the start of DrawSelf, add:

```cpp
    // Try new split components first, fall back to UIConfig
    auto* styleConfig = registry.try_get<UIStyleConfig>(entity);
    auto* oldConfig = registry.try_get<UIConfig>(entity);

    // Use styleConfig if available, otherwise oldConfig
    const auto& stylingType = styleConfig ? styleConfig->stylingType : oldConfig->stylingType;
    const auto& color = styleConfig ? styleConfig->color : oldConfig->color;
    const auto& shadow = styleConfig ? styleConfig->shadow : oldConfig->shadow;
    // ... etc for other style fields used in DrawSelf
```

**Step 3: Build and test**

```bash
just build-debug-ninja && just test
```

**Step 4: Commit**

```bash
git add src/systems/ui/element.cpp
git commit -m "refactor(ui): migrate DrawSelf to prefer UIStyleConfig

Falls back to UIConfig when split component not present."
```

---

## Remaining Tasks (Summary)

The remaining phases follow the same pattern:

### Phase 4 (continued):
- Task 4.2: Migrate layout calculation to use UILayoutConfig
- Task 4.3: Migrate input handling to use UIInteractionConfig
- Task 4.4: Migrate text/object handling to use UIContentConfig

### Phase 5: Implement Remaining Handlers
- Task 5.1: ContainerHandler (VERTICAL_CONTAINER, HORIZONTAL_CONTAINER)
- Task 5.2: TextHandler
- Task 5.3: ObjectHandler
- Task 5.4: ScrollPaneHandler
- Task 5.5: SliderHandler
- Task 5.6: InputTextHandler
- Task 5.7: RootHandler

### Phase 6: Migrate Builder
- Task 6.1: Modify UIConfig::Builder to populate UIConfigBundle
- Task 6.2: Update Initialize to accept UIConfigBundle
- Task 6.3: Stop emplacing old UIConfig

### Phase 7: Cleanup
- Task 7.1: Remove extraction functions
- Task 7.2: Remove old UIConfig component from entities
- Task 7.3: Update documentation

---

## Verification Checklist

After each phase:
- [ ] `just build-debug-ninja` succeeds
- [ ] `just test` all tests pass
- [ ] Game launches and UI renders correctly
- [ ] Lua scripts continue to work unchanged

---

## Files Modified (Summary)

| File | Change |
|------|--------|
| `src/systems/ui/core/ui_components.hpp` | NEW - Split component definitions |
| `src/systems/ui/core/ui_components.cpp` | NEW - Extraction functions |
| `src/systems/ui/handlers/handler_interface.hpp` | NEW - Handler base class |
| `src/systems/ui/handlers/handler_registry.hpp` | NEW - Handler registry |
| `src/systems/ui/handlers/handler_registry.cpp` | NEW - Registry implementation |
| `src/systems/ui/handlers/rect_handler.hpp` | NEW - First handler |
| `src/systems/ui/handlers/rect_handler.cpp` | NEW - Rect implementation |
| `src/systems/ui/element.cpp` | MODIFY - Emplace new components |
| `src/systems/ui/ui.cpp` | MODIFY - Expose new components to Lua |
| `tests/unit/test_ui_components.cpp` | NEW - Unit tests |
| `CMakeLists.txt` | MODIFY - Add new source files |

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
