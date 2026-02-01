# C++ UI System Refactor Design

**Date**: 2025-12-16
**Goal**: Improve maintainability of the C++ UI system without changing Lua bindings
**Approach**: Split monolithic UIConfig, introduce type handlers via strategy pattern

---

## Problem Statement

The current UI system has **11,481 lines** with these pain points:

1. **UIConfig monolith** (170+ fields) - serves styling, layout, interaction, and scripting purposes in one struct
2. **Scattered type dispatch** - TEXT/OBJECT/SCROLL logic spread across `box.cpp`, `element.cpp`, `util.cpp`
3. **Hard to extend** - adding a new UI type requires changes in 3+ files

---

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Primary goal | Maintainability | Unlocks future performance/extensibility work |
| UIConfig approach | Split into separate ECS components | Clean boundaries, independent queries |
| Type-specific logic | Strategy pattern with handler classes | Self-contained, testable, extensible |
| Rendering duplication | Defer to follow-up | Keep scope focused |
| Lua API | No changes | Builder remains the entry point |

---

## Component Split

### Current State
One `UIConfig` struct with 170+ fields serving 5 different purposes.

### New Structure

```cpp
// Core identity (always present on UI elements)
struct UIElementCore {
    UITypeEnum type;
    entt::entity uiBox;      // Parent box
    std::string id;          // Unique identifier within box
    int treeOrder;           // Depth-first order
};

// Visual styling (~25 fields)
struct UIStyleConfig {
    UIStylingType stylingType;
    Color color, outlineColor, hoverColor;
    float outlineThickness, cornerRadius;
    std::optional<std::string> spriteRegionID;
    // ... other styling fields
};

// Layout & positioning (~30 fields)
struct UILayoutConfig {
    float w, h, padding, spacing;
    int alignmentFlags;
    bool fitW, fitH, centerX, centerY;
    std::optional<float> minW, maxW, minH, maxH;
    // ... other geometry fields
};

// Interaction & callbacks (~20 fields)
struct UIInteractionConfig {
    bool clickable, hoverable, draggable, focusable;
    std::optional<Tooltip> tooltip;
    std::optional<FocusArgs> focusArgs;
    // ... other input handling fields
};
```

### Benefits
- Query only what you need: `registry.view<UIElementCore, UIStyleConfig>()` for rendering
- Clear ownership: styling code only touches `UIStyleConfig`
- Smaller cache lines per system

---

## Lua Binding Compatibility

The Lua-facing API stays identical. `UIConfigBuilder` remains the single entry point.

```cpp
// Lua sees the same API:
// UIConfigBuilder.create():addColor(RED):addPadding(10):addClickable(true):build()

class UIConfigBuilder {
    UIStyleConfig style_;
    UILayoutConfig layout_;
    UIInteractionConfig interaction_;

public:
    // Style methods
    UIConfigBuilder& addColor(Color c) { style_.color = c; return *this; }
    UIConfigBuilder& addCornerRadius(float r) { style_.cornerRadius = r; return *this; }

    // Layout methods
    UIConfigBuilder& addPadding(float p) { layout_.padding = p; return *this; }
    UIConfigBuilder& addW(float w) { layout_.w = w; return *this; }

    // Interaction methods
    UIConfigBuilder& addClickable(bool c) { interaction_.clickable = c; return *this; }

    // Build returns a bundle that Initialize() unpacks
    UIConfigBundle build() { return {style_, layout_, interaction_}; }
};
```

At entity creation, `Initialize()` unpacks the bundle into separate components:

```cpp
void Initialize(entt::registry& reg, entt::entity e, UITypeEnum type,
                entt::entity box, const UIConfigBundle& bundle) {
    reg.emplace<UIElementCore>(e, type, box);
    reg.emplace<UIStyleConfig>(e, bundle.style);
    reg.emplace<UILayoutConfig>(e, bundle.layout);
    reg.emplace<UIInteractionConfig>(e, bundle.interaction);
}
```

New components are also exposed to Lua via Sol2 for direct access if needed.

---

## Type Handler Strategy Pattern

### Current State
Type-specific logic scattered across files with switch statements.

### New Structure

```cpp
// Base interface
struct IUIElementHandler {
    virtual ~IUIElementHandler() = default;

    // Layout phase
    virtual void calculateSize(entt::registry&, entt::entity,
                               UILayoutConfig&, float scaleFactor) = 0;

    // Render phase
    virtual void draw(entt::registry&, entt::entity,
                      const UIStyleConfig&, const Transform&) = 0;

    // Input phase (optional overrides)
    virtual bool handleClick(entt::registry&, entt::entity,
                             UIInteractionConfig&, Vector2 pos) { return false; }

    virtual void handleHover(entt::registry&, entt::entity,
                             UIInteractionConfig&) {}
};
```

### Concrete Handlers

| Handler | UI Types | Responsibilities |
|---------|----------|------------------|
| `TextHandler` | TEXT | Measure text bounds, render with styling |
| `ContainerHandler` | VERTICAL_CONTAINER, HORIZONTAL_CONTAINER | Sum children + padding, draw background |
| `ScrollPaneHandler` | SCROLL_PANE | Content vs viewport, clip region, scrollbars |
| `SliderHandler` | SLIDER_UI | Track + thumb rendering, drag interaction |
| `InputTextHandler` | INPUT_TEXT | Text input, cursor, selection |
| `ObjectHandler` | OBJECT | Wrapped entity (animation, sprite) |
| `RootHandler` | ROOT | Top-level container |
| `RectHandler` | RECT_SHAPE | Simple rectangle |

### Handler Registry

```cpp
class UIHandlerRegistry {
    std::unordered_map<UITypeEnum, std::unique_ptr<IUIElementHandler>> handlers_;
public:
    static UIHandlerRegistry& instance();

    void registerHandler(UITypeEnum type, std::unique_ptr<IUIElementHandler> h);
    IUIElementHandler* get(UITypeEnum type);
};

// Usage:
void ui::element::DrawSelf(entt::registry& reg, entt::entity e) {
    auto& core = reg.get<UIElementCore>(e);
    auto* handler = UIHandlerRegistry::instance().get(core.type);
    handler->draw(reg, e, reg.get<UIStyleConfig>(e), reg.get<Transform>(e));
}
```

### Benefits
- Add new UI type = add one handler file
- Each handler testable in isolation
- Clear where to look for type-specific bugs

---

## File Structure

```
src/systems/ui/
├── core/
│   ├── ui_components.hpp      # UIElementCore, UIStyleConfig, UILayoutConfig, UIInteractionConfig
│   ├── ui_components.cpp      # Component defaults, validation
│   ├── ui_builder.hpp         # UIConfigBuilder (Lua-facing)
│   ├── ui_builder.cpp
│   └── ui_state.hpp           # UIState, UIBoxComponent (mostly unchanged)
│
├── handlers/
│   ├── handler_interface.hpp  # IUIElementHandler base
│   ├── handler_registry.hpp   # UIHandlerRegistry singleton
│   ├── handler_registry.cpp
│   ├── text_handler.cpp
│   ├── container_handler.cpp  # Vertical + Horizontal
│   ├── scroll_handler.cpp
│   ├── slider_handler.cpp
│   ├── input_handler.cpp
│   ├── object_handler.cpp
│   └── root_handler.cpp
│
├── layout/
│   ├── layout_engine.hpp      # Layout calculation coordination
│   └── layout_engine.cpp
│
├── rendering/
│   ├── ui_draw.hpp            # Draw list building
│   ├── ui_draw.cpp
│   └── ui_util.cpp            # Rounded rect, ninepatch (existing util.cpp)
│
├── bindings/
│   ├── ui_lua.cpp             # Sol2 bindings (refactored from ui.cpp)
│   └── ui_pack_lua.cpp        # Asset pack bindings (unchanged)
│
├── box.cpp                    # Tree management (reduced scope)
├── element.cpp                # Thin dispatcher to handlers
└── ui.hpp                     # Public header
```

---

## Migration Strategy

Incremental migration with old and new systems coexisting. Never break the build.

### Phase 1: Add New Components Alongside Old

```cpp
void Initialize(..., const UIConfig& oldConfig) {
    // Existing behavior unchanged
    reg.emplace<UIConfig>(e, oldConfig);

    // NEW: Also populate split components
    reg.emplace<UIElementCore>(e, extractCore(oldConfig));
    reg.emplace<UIStyleConfig>(e, extractStyle(oldConfig));
    reg.emplace<UILayoutConfig>(e, extractLayout(oldConfig));
    reg.emplace<UIInteractionConfig>(e, extractInteraction(oldConfig));
}
```

### Phase 2: Migrate Readers One System at a Time
1. Rendering → reads `UIStyleConfig` instead of `UIConfig`
2. Layout → reads `UILayoutConfig`
3. Input handling → reads `UIInteractionConfig`
4. Each migration is a separate commit

### Phase 3: Migrate the Builder
- `UIConfigBuilder::build()` returns `UIConfigBundle` instead of `UIConfig`
- `Initialize()` stops creating old `UIConfig` component

### Phase 4: Introduce Handlers
- Start with simplest type (ROOT or RECT_SHAPE)
- One handler at a time, falling back to old code for unhandled types
- Delete old switch statements after all handlers exist

### Phase 5: Cleanup
- Remove old `UIConfig` component
- Remove extraction functions
- Remove fallback paths

**Testing gate**: Each phase must pass all existing tests before proceeding.

---

## Scope Boundaries

### In Scope
- Split `UIConfig` into 4 ECS components
- Create handler classes for each `UITypeEnum`
- Reorganize files into logical directories
- Keep Lua builder API identical

### Out of Scope (Deferred)
- Rendering duplication cleanup (buffered/immediate)
- Single-pass layout algorithm rewrite
- Global scale factor threading
- Asset pack integration changes
- Scroll pane deep refactor

---

## Risks and Mitigations

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Missed field in component split | Medium | Generate extraction functions from current UIConfig, verify all 170+ fields mapped |
| Performance regression from more components | Low | EnTT component access is fast; measure before/after |
| Handler interface too rigid | Medium | Start with minimal interface, extend as needed |
| Lua binding breakage | Low | No API change; run full test suite after each phase |
| Merge conflicts with main | Medium | Keep worktree synced, small frequent merges |

---

## Success Criteria

1. All existing tests pass
2. No Lua script changes required
3. Adding a new UI type requires only a new handler file
4. Each UI type's logic is in one place (its handler)

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
