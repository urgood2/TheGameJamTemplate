# Box.cpp Layout & Sizing Refactoring Plan

**Date:** 2026-01-16
**Status:** Draft
**Author:** Claude + Joshua
**Risk Level:** 🟠 Medium-High (Core UI system)

---

## Executive Summary

This plan systematically refactors the layout and sizing code in `box.cpp` to fix 16 identified issues while ensuring **zero regressions** through comprehensive measurement, testing, and code review at each step.

---

## Pre-Refactoring Infrastructure

### Phase 0: Baseline & Verification System Setup

Before any code changes, we establish measurement baselines and verification infrastructure.

#### 0.1 UI Snapshot System

Create a measurement system that captures the **exact bounds** of all UI elements.

```lua
-- assets/scripts/tests/_framework/ui_snapshot.lua
local UISnapshot = {}

--- Capture complete bounds of a UI tree
---@param uiBoxEntity Entity
---@return table snapshot { entities = { [entity] = { x, y, w, h, id } } }
function UISnapshot.capture(uiBoxEntity)
    local snapshot = {
        timestamp = os.time(),
        entities = {},
        tree = {},
    }

    -- Use existing DebugPrint to get structure, then measure each
    ui.box.TraverseUITreeBottomUp(registry, uiBoxEntity, function(entity)
        local transform = component_cache.get(entity, Transform)
        local config = component_cache.get(entity, UIConfig)
        if transform then
            snapshot.entities[entity] = {
                id = config and config.id or nil,
                x = transform:getActualX(),
                y = transform:getActualY(),
                w = transform:getActualW(),
                h = transform:getActualH(),
                -- Store visual position too (for spring-animated elements)
                vx = transform:getVisualX(),
                vy = transform:getVisualY(),
            }
        end
    end, false)

    return snapshot
end

--- Compare two snapshots, return differences
---@param before table
---@param after table
---@param tolerance number (default 0.5 for float precision)
---@return table { changed = {}, added = {}, removed = {} }
function UISnapshot.diff(before, after, tolerance)
    tolerance = tolerance or 0.5
    local changes = { changed = {}, added = {}, removed = {} }

    for entity, bounds in pairs(before.entities) do
        local afterBounds = after.entities[entity]
        if not afterBounds then
            table.insert(changes.removed, { entity = entity, bounds = bounds })
        elseif not UISnapshot.boundsEqual(bounds, afterBounds, tolerance) then
            table.insert(changes.changed, {
                entity = entity,
                id = bounds.id,
                before = bounds,
                after = afterBounds,
                delta = {
                    dx = afterBounds.x - bounds.x,
                    dy = afterBounds.y - bounds.y,
                    dw = afterBounds.w - bounds.w,
                    dh = afterBounds.h - bounds.h,
                }
            })
        end
    end

    for entity, bounds in pairs(after.entities) do
        if not before.entities[entity] then
            table.insert(changes.added, { entity = entity, bounds = bounds })
        end
    end

    return changes
end

--- Save snapshot to file for later comparison
function UISnapshot.save(snapshot, filename)
    local json = require("external.json")
    local file = io.open(filename, "w")
    file:write(json.encode(snapshot))
    file:close()
end

--- Load snapshot from file
function UISnapshot.load(filename)
    local json = require("external.json")
    local file = io.open(filename, "r")
    local content = file:read("*all")
    file:close()
    return json.decode(content)
end

return UISnapshot
```

#### 0.2 Baseline Capture Script

```lua
-- assets/scripts/tests/capture_ui_baselines.lua
local UISnapshot = require("tests._framework.ui_snapshot")

local BASELINE_DIR = "tests/baselines/ui/"

--- Capture baselines for all major UI screens
local function captureAllBaselines()
    local baselines = {}

    -- Main menu
    -- TODO: Load main menu state
    -- baselines.main_menu = UISnapshot.capture(globals.ui.main_menu)

    -- Inventory panel (if visible)
    if globals.ui and globals.ui.inventory then
        baselines.inventory = UISnapshot.capture(globals.ui.inventory)
        UISnapshot.save(baselines.inventory, BASELINE_DIR .. "inventory_baseline.json")
    end

    -- Stats panel
    if globals.ui and globals.ui.stats_panel then
        baselines.stats_panel = UISnapshot.capture(globals.ui.stats_panel)
        UISnapshot.save(baselines.stats_panel, BASELINE_DIR .. "stats_panel_baseline.json")
    end

    -- Combat UI
    if globals.ui and globals.ui.combat then
        baselines.combat = UISnapshot.capture(globals.ui.combat)
        UISnapshot.save(baselines.combat, BASELINE_DIR .. "combat_baseline.json")
    end

    print(string.format("[Baseline] Captured %d UI baselines", #baselines))
    return baselines
end

return {
    captureAll = captureAllBaselines,
}
```

#### 0.3 Regression Detection Runner

```lua
-- assets/scripts/tests/verify_ui_no_regressions.lua
local UISnapshot = require("tests._framework.ui_snapshot")

local function verifyNoRegressions(baselineFile, currentUIBox)
    local baseline = UISnapshot.load(baselineFile)
    local current = UISnapshot.capture(currentUIBox)
    local diff = UISnapshot.diff(baseline, current)

    local hasRegressions = #diff.changed > 0 or #diff.removed > 0

    if hasRegressions then
        print("[REGRESSION] UI layout changed!")
        for _, change in ipairs(diff.changed) do
            print(string.format("  %s: pos (%+.1f, %+.1f) size (%+.1f, %+.1f)",
                change.id or tostring(change.entity),
                change.delta.dx, change.delta.dy,
                change.delta.dw, change.delta.dh
            ))
        end
        for _, removed in ipairs(diff.removed) do
            print(string.format("  REMOVED: %s", removed.bounds.id or tostring(removed.entity)))
        end
        return false
    end

    print("[OK] No UI regressions detected")
    return true
end

return {
    verify = verifyNoRegressions,
}
```

#### 0.4 C++ Unit Test Expansion

```cpp
// tests/unit/test_ui_sizing.cpp - NEW FILE
#include <gtest/gtest.h>
#include "systems/ui/box.hpp"
#include "systems/ui/element.hpp"
#include "core/globals.hpp"
#include <entt/entt.hpp>

class UISizingTest : public ::testing::Test {
protected:
    entt::registry registry;

    void SetUp() override {
        globals::setGlobalUIScaleFactor(1.0f);
    }

    // Helper to create minimal UI config
    ui::UIConfig makeConfig(ui::UITypeEnum type) {
        ui::UIConfig cfg;
        cfg.uiType = type;
        return cfg;
    }
};

// Test: Vertical container accumulates heights
TEST_F(UISizingTest, VerticalContainer_AccumulatesChildHeights) {
    // Setup: Create container with 3 children of height 30 each
    // Expected: Container height = 3 * 30 + padding
    // This test will be filled in during implementation
}

// Test: Horizontal container accumulates widths
TEST_F(UISizingTest, HorizontalContainer_AccumulatesChildWidths) {
    // Setup: Create container with 3 children of width 50 each
    // Expected: Container width = 3 * 50 + padding
}

// Test: Global scale applied exactly once to text
TEST_F(UISizingTest, GlobalScale_AppliedOnceToText) {
    globals::setGlobalUIScaleFactor(2.0f);
    // Setup: Create text element
    // Expected: Final size = base_size * 2.0 (NOT 4.0)
}

// Test: Padding not doubled on vertical containers
TEST_F(UISizingTest, VerticalContainer_PaddingNotDoubled) {
    // Regression test for the double-padding bug
}

// Test: Scale not reset after sizing
TEST_F(UISizingTest, Scale_NotResetAfterSizing) {
    // Regression test for scale = 1.0f reset bug
}
```

#### 0.5 Justfile Additions

```makefile
# Add to Justfile

# Capture UI baselines (run before refactoring)
ui-baseline-capture:
    @mkdir -p tests/baselines/ui
    ./build/raylib-cpp-cmake-template --run-lua "require('tests.capture_ui_baselines').captureAll()"
    @echo "Baselines saved to tests/baselines/ui/"

# Verify no UI regressions
ui-verify:
    ./build/raylib-cpp-cmake-template --run-lua "require('tests.verify_ui_no_regressions').runAll()"

# Full UI test suite (existing + sizing)
ui-test-all: test
    ./build/raylib-cpp-cmake-template --run-lua "require('tests.run_all_ui_tests')()"
```

---

## Refactoring Phases

### Phase 1: Critical Bug Fixes (No Structural Changes)

**Goal:** Fix the most severe bugs without changing architecture.

| Task | Bug Fixed | Risk | Verification |
|------|-----------|------|--------------|
| 1.1 | Double global scale on text | 🔴 High | Unit test + visual |
| 1.2 | Double padding on vertical | 🔴 High | Unit test + baseline |
| 1.3 | Scale reset to 1.0f | 🔴 High | Unit test |
| 1.4 | Invalid entity access in RemoveGroup | 🔴 High | Crash test |
| 1.5 | Invalid entity access in GetGroup | 🔴 High | Crash test |

#### 1.1 Fix Double Global Scale (box.cpp:1139 vs 1766)

**Before:**
```cpp
// Line 1139: Applied to ALL content dimensions
uiState.contentDimensions->x *= globals::getGlobalUIScaleFactor();

// Line 1766: Already included in text measurement
float totalScale = scaleFactor * fontData.fontScale * globals::getGlobalUIScaleFactor();
```

**After:**
```cpp
// Line 1139: Only apply to non-text elements
if (uiConfig.uiType != UITypeEnum::TEXT && uiConfig.uiType != UITypeEnum::INPUT_TEXT) {
    uiState.contentDimensions->x *= globals::getGlobalUIScaleFactor();
    uiState.contentDimensions->y *= globals::getGlobalUIScaleFactor();
}
```

**Verification:**
```cpp
TEST_F(UISizingTest, Text_GlobalScaleAppliedOnce) {
    globals::setGlobalUIScaleFactor(2.0f);
    // Create text, measure, assert size is 2x not 4x
}
```

#### 1.2 Fix Double Padding (box.cpp:1648-1681)

**Problem Analysis:**
```cpp
// Condition 1 (line 1648): +padding to both w and h
if (selfUIConfig.uiType == UITypeEnum::HORIZONTAL_CONTAINER && !hasAtLeastOneContainerChild) {
    calcChildTransform.w += padding;
    calcChildTransform.h += padding;  // <-- Problem: h gets padding
}

// Condition 2 (line 1677): +padding to h AGAIN
if (hasAtLeastOneChild) {
    if (selfUIConfig.uiType == UITypeEnum::VERTICAL_CONTAINER && !hasAtLeastOneContainerChild) {
        calcChildTransform.h += padding;  // <-- Double padding!
    }
}
```

**Fix Strategy:** Consolidate padding logic into one location.

```cpp
// AFTER: Single location for final padding adjustment
if (!hasAtLeastOneContainerChild && hasAtLeastOneChild) {
    if (selfUIConfig.uiType == UITypeEnum::HORIZONTAL_CONTAINER) {
        calcChildTransform.w += padding;  // trailing padding
        calcChildTransform.h += padding;  // cross-axis padding
    } else if (selfUIConfig.uiType == UITypeEnum::VERTICAL_CONTAINER ||
               selfUIConfig.uiType == UITypeEnum::ROOT ||
               selfUIConfig.uiType == UITypeEnum::SCROLL_PANE) {
        calcChildTransform.w += padding;  // cross-axis padding
        calcChildTransform.h += padding;  // trailing padding
    }
}
```

**Verification:**
```lua
-- Test: vbox with 3 text children should have exact expected height
test("vbox_padding_not_doubled", function(t)
    local ui = dsl.vbox {
        config = { padding = 10 },
        children = {
            dsl.text("A", { h = 30 }),
            dsl.text("B", { h = 30 }),
            dsl.text("C", { h = 30 }),
        }
    }
    local entity = dsl.spawn({ x = 0, y = 0 }, ui)
    local bounds = t:getBounds(entity)

    -- Expected: 10 (top) + 30 + 10 + 30 + 10 + 30 + 10 (bottom) = 130
    -- NOT: 140 (double padding)
    t:assertEqual(bounds.h, 130, "height should not have double padding")
end)
```

#### 1.3 Fix Scale Reset (box.cpp:1829-1832)

**Before:**
```cpp
if (uiConfig.scale) {
    uiConfig.scale = 1.0f;  // DESTROYS user config!
}
```

**After:** Remove this code entirely. Scale should be preserved.

**Verification:**
```lua
test("scale_preserved_after_recalculate", function(t)
    local ui = dsl.root {
        config = { scale = 1.5 },
        children = { dsl.text("Scaled") }
    }
    local entity = dsl.spawn({ x = 0, y = 0 }, ui)

    -- Trigger recalculation
    ui.box.Recalculate(registry, entity)

    local config = component_cache.get(entity, UIConfig)
    t:assertEqual(config.scale, 1.5, "scale should be preserved")
end)
```

#### 1.4-1.5 Fix Invalid Entity Access

**Before (RemoveGroup, line 1840):**
```cpp
if (registry.valid(entity) == false) {
    auto *uiBox = registry.try_get<UIBoxComponent>(entity);  // UB!
    entity = uiBox->uiRoot.value();  // Crash if null
```

**After:**
```cpp
if (!registry.valid(entity)) {
    SPDLOG_WARN("RemoveGroup called with invalid entity");
    return false;  // Early return
}

auto *uiBox = registry.try_get<UIBoxComponent>(entity);
if (uiBox && uiBox->uiRoot) {
    entity = uiBox->uiRoot.value();
} else {
    SPDLOG_WARN("RemoveGroup: entity {} has no UIBoxComponent or uiRoot", static_cast<int>(entity));
    return false;
}
```

**Verification:**
```cpp
TEST_F(UISizingTest, RemoveGroup_InvalidEntityDoesNotCrash) {
    entt::entity invalid{9999};
    EXPECT_NO_THROW(ui::box::RemoveGroup(registry, invalid, "test"));
}
```

---

### 🔍 Code Review Checkpoint 1

After Phase 1, request code review focusing on:
- [ ] Each bug fix is isolated and minimal
- [ ] No behavioral changes beyond the fix
- [ ] Unit tests cover the exact bug
- [ ] Baseline comparison shows expected changes only

```
/superpowers:requesting-code-review
```

---

### Phase 2: Extract Reusable Utilities

**Goal:** Create foundational utilities that will be used in later phases.

| Task | Creates | Risk | Verification |
|------|---------|------|--------------|
| 2.1 | `traversal::forEachInTree()` | 🟢 Low | Existing behavior preserved |
| 2.2 | `TypeTraits` helper | 🟢 Low | Unit tests |
| 2.3 | `LayoutMetrics` struct | 🟢 Low | Unit tests |

#### 2.1 Extract DFS Traversal Utility

```cpp
// src/systems/ui/traversal.hpp - NEW FILE
#pragma once
#include <entt/entt.hpp>
#include <functional>
#include <vector>
#include <stack>
#include "systems/transform/transform.hpp"
#include "systems/ui/ui_data.hpp"

namespace ui::traversal {

enum class Order { TopDown, BottomUp };

/// Traverse UI tree, calling visitor on each entity
template<typename Visitor>
void forEachInTree(entt::registry& reg, entt::entity root,
                   Visitor&& visitor, Order order = Order::TopDown) {
    if (!reg.valid(root)) return;

    std::vector<entt::entity> nodes;
    std::stack<entt::entity> stack;
    stack.push(root);

    while (!stack.empty()) {
        auto e = stack.top();
        stack.pop();
        if (!reg.valid(e)) continue;

        nodes.push_back(e);

        if (auto* node = reg.try_get<transform::GameObject>(e)) {
            // Push in reverse for correct order
            for (auto it = node->orderedChildren.rbegin();
                 it != node->orderedChildren.rend(); ++it) {
                if (reg.valid(*it)) stack.push(*it);
            }
        }
    }

    if (order == Order::BottomUp) {
        std::reverse(nodes.begin(), nodes.end());
    }

    for (auto e : nodes) {
        visitor(e);
    }
}

/// Traverse UI tree including owned objects (UIConfig.object)
template<typename Visitor>
void forEachWithObjects(entt::registry& reg, entt::entity root,
                        Visitor&& visitor, Order order = Order::TopDown) {
    forEachInTree(reg, root, [&](entt::entity e) {
        visitor(e);
        if (auto* cfg = reg.try_get<UIConfig>(e)) {
            if (cfg->object && reg.valid(*cfg->object)) {
                visitor(*cfg->object);
            }
        }
    }, order);
}

} // namespace ui::traversal
```

**Verification:** Replace ONE usage site (e.g., `AssignStateTagsToUIBox`) and verify identical behavior.

```cpp
// Before: 80 lines
// After: ~15 lines using traversal::forEachWithObjects
auto box::AssignStateTagsToUIBox(entt::registry& reg, entt::entity uiBox,
                                  const std::string& stateName) -> void {
    using namespace entity_gamestate_management;
    if (!reg.valid(uiBox)) return;

    auto* boxComp = reg.try_get<UIBoxComponent>(uiBox);
    if (!boxComp || !boxComp->uiRoot) return;

    // Tag the box itself
    if (reg.any_of<StateTag>(uiBox)) {
        reg.get<StateTag>(uiBox).add_tag(stateName);
    } else {
        reg.emplace<StateTag>(uiBox, stateName);
    }

    // Tag all elements and their objects
    traversal::forEachWithObjects(reg, *boxComp->uiRoot, [&](entt::entity e) {
        if (reg.any_of<StateTag>(e)) {
            reg.get<StateTag>(e).add_tag(stateName);
        } else {
            reg.emplace<StateTag>(e, stateName);
        }
    });
}
```

**Test:** Before/after behavior is identical.

```lua
test("AssignStateTagsToUIBox_behaviorPreserved", function(t)
    local ui = dsl.vbox { children = { dsl.text("A"), dsl.text("B") } }
    local entity = dsl.spawn({ x = 0, y = 0 }, ui)

    ui.box.AssignStateTagsToUIBox(entity, "TEST_STATE")

    -- Verify all children got the tag
    ui.box.TraverseUITreeBottomUp(registry, entity, function(child)
        local tag = component_cache.get(child, StateTag)
        t:assert_not_nil(tag, "all children should have StateTag")
        t:assert_true(tag:has_tag("TEST_STATE"), "tag should contain TEST_STATE")
    end, false)
end)
```

#### 2.2 Type Classification Helpers

```cpp
// src/systems/ui/type_traits.hpp - NEW FILE
#pragma once
#include "systems/ui/ui_data.hpp"

namespace ui {

struct TypeTraits {
    static bool isVerticalFlow(UITypeEnum t) {
        return t == UITypeEnum::VERTICAL_CONTAINER ||
               t == UITypeEnum::ROOT ||
               t == UITypeEnum::SCROLL_PANE;
    }

    static bool isHorizontalFlow(UITypeEnum t) {
        return t == UITypeEnum::HORIZONTAL_CONTAINER;
    }

    static bool isContainer(UITypeEnum t) {
        return isVerticalFlow(t) || isHorizontalFlow(t);
    }

    static bool isLeaf(UITypeEnum t) {
        return t == UITypeEnum::RECT_SHAPE ||
               t == UITypeEnum::TEXT ||
               t == UITypeEnum::OBJECT ||
               t == UITypeEnum::INPUT_TEXT;
    }

    static bool needsIntrinsicSizing(UITypeEnum t) {
        return t == UITypeEnum::TEXT ||
               t == UITypeEnum::OBJECT ||
               t == UITypeEnum::ANIM;
    }
};

} // namespace ui
```

**Unit Tests:**
```cpp
TEST(TypeTraitsTest, VerticalFlowTypes) {
    EXPECT_TRUE(ui::TypeTraits::isVerticalFlow(ui::UITypeEnum::VERTICAL_CONTAINER));
    EXPECT_TRUE(ui::TypeTraits::isVerticalFlow(ui::UITypeEnum::ROOT));
    EXPECT_TRUE(ui::TypeTraits::isVerticalFlow(ui::UITypeEnum::SCROLL_PANE));
    EXPECT_FALSE(ui::TypeTraits::isVerticalFlow(ui::UITypeEnum::HORIZONTAL_CONTAINER));
}
```

#### 2.3 LayoutMetrics Helper

```cpp
// src/systems/ui/layout_metrics.hpp - NEW FILE
#pragma once
#include "systems/ui/ui_data.hpp"
#include "core/globals.hpp"

namespace ui {

struct LayoutMetrics {
    float padding;
    float emboss;
    float scale;
    float globalScale;

    static LayoutMetrics from(const UIConfig& cfg) {
        float s = cfg.scale.value_or(1.0f);
        float gs = globals::getGlobalUIScaleFactor();
        return {
            .padding = cfg.effectivePadding(),
            .emboss = cfg.emboss.value_or(0.f) * s * gs,
            .scale = s,
            .globalScale = gs
        };
    }

    /// Content area after removing padding from all sides
    Vector2 contentArea(float w, float h) const {
        return { w - 2 * padding, h - 2 * padding };
    }

    /// Offset to content origin (top-left of content area)
    Vector2 contentOffset() const {
        return { padding, padding };
    }

    /// Total size including emboss shadow
    float totalHeight(float baseHeight) const {
        return baseHeight + emboss;
    }

    /// Combined scale factor
    float combinedScale() const {
        return scale * globalScale;
    }
};

} // namespace ui
```

---

### 🔍 Code Review Checkpoint 2

After Phase 2, request code review focusing on:
- [ ] New utilities have comprehensive unit tests
- [ ] No changes to existing behavior (just additions)
- [ ] API is intuitive and well-documented
- [ ] Performance is equivalent or better

```
/superpowers:requesting-code-review
```

---

### Phase 3: Gradual Migration to Utilities

**Goal:** Replace duplicated patterns with utilities, one at a time.

| Task | Function Migrated | Risk | Verification |
|------|-------------------|------|--------------|
| 3.1 | `AssignStateTagsToUIBox` | 🟢 Low | Behavior test |
| 3.2 | `AddStateTagToUIBox` | 🟢 Low | Behavior test |
| 3.3 | `ClearStateTagsFromUIBox` | 🟢 Low | Behavior test |
| 3.4 | `SetTransformSpringsEnabledInUIBox` | 🟢 Low | Behavior test |
| 3.5 | `handleAlignment` traversal | 🟡 Medium | Layout baseline |
| 3.6 | `AssignTreeOrderComponents` | 🟢 Low | Order test |

**Strategy:** Migrate one function at a time. After each:
1. Run unit tests
2. Run baseline comparison
3. Manually verify one UI screen
4. Commit if green

---

### 🔍 Code Review Checkpoint 3

After Phase 3, request code review focusing on:
- [ ] Each migration is behavior-preserving
- [ ] Code is more readable
- [ ] No performance regressions
- [ ] All baselines pass

---

### Phase 4: Split CalcTreeSizes

**Goal:** Break the 230-line `CalcTreeSizes` into focused phases.

This is the highest-risk phase because it touches the core sizing algorithm.

| Task | Extracts | Risk | Verification |
|------|----------|------|--------------|
| 4.1 | `buildProcessingOrder()` | 🟡 Medium | Order matches |
| 4.2 | `calculateIntrinsicSizes()` | 🔴 High | Size baseline |
| 4.3 | `applyMaxConstraints()` | 🟡 Medium | Clamp tests |
| 4.4 | `applyGlobalScale()` | 🟡 Medium | Scale tests |
| 4.5 | `commitToTransforms()` | 🟡 Medium | Final baseline |

#### 4.1 Extract Processing Order Builder

```cpp
namespace ui::layout {

class SizingPass {
public:
    explicit SizingPass(entt::registry& r, entt::entity root)
        : reg_(r), root_(root) {
        buildProcessingOrder();
    }

    const std::vector<entt::entity>& processingOrder() const {
        return processingOrder_;
    }

private:
    void buildProcessingOrder() {
        // Exact code from CalcTreeSizes lines 952-993
        // Just moved, not modified
    }

    entt::registry& reg_;
    entt::entity root_;
    std::vector<entt::entity> processingOrder_;
};

} // namespace ui::layout
```

**Verification:**
```cpp
TEST_F(UISizingTest, ProcessingOrder_MatchesOriginal) {
    // Build a known tree
    // Compare order from SizingPass vs original CalcTreeSizes
}
```

#### Strategy: Parallel Implementation

To minimize risk, implement the new `SizingPass` class **alongside** the original `CalcTreeSizes`. Then:

1. Add logging to compare results between old and new
2. Run both paths in debug builds, assert they match
3. Once confident, switch to new path
4. Remove old code after verification period

```cpp
auto box::CalcTreeSizes(...) -> std::pair<float, float> {
    // NEW: Run new implementation
    layout::SizingPass pass(registry, uiElement);
    auto [newW, newH] = pass.run();

    // OLD: Run original implementation
    auto [oldW, oldH] = CalcTreeSizes_Original(...);

    // COMPARE
    if (std::abs(newW - oldW) > 0.1f || std::abs(newH - oldH) > 0.1f) {
        SPDLOG_ERROR("SizingPass mismatch! new=({},{}) old=({},{})",
                     newW, newH, oldW, oldH);
        // Return old result to maintain compatibility
        return {oldW, oldH};
    }

    return {newW, newH};
}
```

---

### 🔍 Code Review Checkpoint 4

After Phase 4, request code review focusing on:
- [ ] New SizingPass produces identical results
- [ ] All edge cases handled
- [ ] Performance is not degraded
- [ ] Code is significantly more readable

---

### Phase 5: Consolidate Draw Functions

**Goal:** Merge `drawAllBoxes` and `drawAllBoxesShaderEnabled`.

| Task | Change | Risk | Verification |
|------|--------|------|--------------|
| 5.1 | Extract common logic | 🟡 Medium | Visual test |
| 5.2 | Add DrawMode parameter | 🟢 Low | Same behavior |
| 5.3 | Remove duplicate function | 🟡 Medium | All UIs work |

---

### Phase 6: Cleanup & Documentation

| Task | Cleanup | Risk |
|------|---------|------|
| 6.1 | Remove dead code (`box::Draw` commented block) | 🟢 Low |
| 6.2 | Remove empty stubs (`Move`, `Drag`) | 🟢 Low |
| 6.3 | Remove unreachable return statement | 🟢 Low |
| 6.4 | Convert TODOs to GitHub issues | 🟢 Low |
| 6.5 | Add documentation comments | 🟢 Low |

---

### 🔍 Final Code Review

After all phases, comprehensive review:
- [ ] All bugs from original analysis are fixed
- [ ] All baselines pass
- [ ] Performance benchmarks show no regression
- [ ] Code is more maintainable
- [ ] Documentation is complete

---

## Verification Matrix

| UI Screen | Baseline File | Verify After Phase |
|-----------|---------------|-------------------|
| Main Menu | `main_menu_baseline.json` | 1, 3, 4 |
| Inventory | `inventory_baseline.json` | 1, 3, 4 |
| Stats Panel | `stats_panel_baseline.json` | 1, 3, 4 |
| Combat UI | `combat_baseline.json` | 1, 3, 4 |
| Shop | `shop_baseline.json` | 1, 3, 4 |
| Tooltips | `tooltips_baseline.json` | 1, 4 |
| Modals | `modals_baseline.json` | 1, 3, 4 |

---

## Rollback Strategy

Each phase creates a **git tag** before starting:

```bash
git tag pre-phase-1-box-refactor
git tag pre-phase-2-box-refactor
# etc.
```

If any phase introduces regressions that can't be fixed quickly:

```bash
git revert --no-commit HEAD~N..HEAD  # Revert all commits in phase
git commit -m "Rollback phase X: [reason]"
```

---

## Timeline Estimate

| Phase | Duration | Cumulative |
|-------|----------|------------|
| Phase 0: Setup | 1 day | 1 day |
| Phase 1: Critical Bugs | 2 days | 3 days |
| Phase 2: Utilities | 1 day | 4 days |
| Phase 3: Migration | 2 days | 6 days |
| Phase 4: CalcTreeSizes | 3 days | 9 days |
| Phase 5: Draw Consolidation | 1 day | 10 days |
| Phase 6: Cleanup | 1 day | 11 days |

**Total: ~11 working days**

---

## Success Criteria

1. ✅ All 16 identified bugs are fixed
2. ✅ All UI baseline comparisons pass (zero position/size changes)
3. ✅ All unit tests pass (new + existing)
4. ✅ Visual inspection of each major UI screen shows no regressions
5. ✅ Code is measurably more readable (fewer lines, clearer structure)
6. ✅ Performance benchmarks show no degradation

---

## Appendix: Files to Modify

| File | Changes |
|------|---------|
| `src/systems/ui/box.cpp` | Major refactoring |
| `src/systems/ui/box.hpp` | API updates |
| `src/systems/ui/element.cpp` | SetWH fix |
| `src/systems/ui/traversal.hpp` | NEW |
| `src/systems/ui/type_traits.hpp` | NEW |
| `src/systems/ui/layout_metrics.hpp` | NEW |
| `tests/unit/test_ui_sizing.cpp` | NEW |
| `tests/unit/test_ui_traversal.cpp` | NEW |
| `assets/scripts/tests/_framework/ui_snapshot.lua` | NEW |
| `assets/scripts/tests/capture_ui_baselines.lua` | NEW |
| `assets/scripts/tests/verify_ui_no_regressions.lua` | NEW |
