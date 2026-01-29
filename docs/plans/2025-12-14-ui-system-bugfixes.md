# UI System Bugfixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix padding inconsistencies, zero-padding bugs, and alignment flag conflicts in the C++ UI system.

**Architecture:** Add `UIConfig::effectivePadding()` method to centralize padding calculation, unify two conflicting default values (10.0f → 4.0f), add alignment flag conflict detection with warnings, and replace ~40 duplicated calculations with the new method.

**Tech Stack:** C++20, GoogleTest, EnTT ECS, spdlog

---

## Task 1: Create Test File and Write effectivePadding Tests

**Files:**
- Create: `tests/unit/test_ui_layout.cpp`
- Modify: `tests/unit/CMakeLists.txt` (add new test file)

**Step 1: Create the test file with effectivePadding tests**

```cpp
// tests/unit/test_ui_layout.cpp
#include <gtest/gtest.h>
#include "systems/ui/ui_data.hpp"
#include "core/globals.hpp"

class UILayoutTest : public ::testing::Test {
protected:
    void SetUp() override {
        // Store original values
        originalSettingsPadding = globals::getSettings().uiPadding;
        originalGlobalScale = globals::getGlobalUIScaleFactor();

        // Set known test values
        globals::getSettings().uiPadding = 4.0f;
        globals::setGlobalUIScaleFactor(1.0f);
    }

    void TearDown() override {
        // Restore original values
        globals::getSettings().uiPadding = originalSettingsPadding;
        globals::setGlobalUIScaleFactor(originalGlobalScale);
    }

    float originalSettingsPadding;
    float originalGlobalScale;
};

// Test 1: Default values (no explicit padding, scale = 1.0)
TEST_F(UILayoutTest, EffectivePadding_DefaultValues) {
    ui::UIConfig config;
    // padding not set, scale defaults to 1.0f

    float result = config.effectivePadding();

    // Should be: 4.0f (default) * 1.0f (scale) * 1.0f (global) = 4.0f
    EXPECT_FLOAT_EQ(result, 4.0f);
}

// Test 2: Explicit padding value
TEST_F(UILayoutTest, EffectivePadding_ExplicitPadding) {
    ui::UIConfig config;
    config.padding = 8.0f;

    float result = config.effectivePadding();

    // Should be: 8.0f * 1.0f * 1.0f = 8.0f
    EXPECT_FLOAT_EQ(result, 8.0f);
}

// Test 3: With scale factor
TEST_F(UILayoutTest, EffectivePadding_WithScale) {
    ui::UIConfig config;
    config.padding = 4.0f;
    config.scale = 2.0f;

    float result = config.effectivePadding();

    // Should be: 4.0f * 2.0f * 1.0f = 8.0f
    EXPECT_FLOAT_EQ(result, 8.0f);
}

// Test 4: Zero padding (regression test)
TEST_F(UILayoutTest, EffectivePadding_ZeroPadding) {
    ui::UIConfig config;
    config.padding = 0.0f;
    config.scale = 1.0f;

    float result = config.effectivePadding();

    // Should be: 0.0f * 1.0f * 1.0f = 0.0f
    EXPECT_FLOAT_EQ(result, 0.0f);
}

// Test 5: With global UI scale factor
TEST_F(UILayoutTest, EffectivePadding_WithGlobalScale) {
    globals::setGlobalUIScaleFactor(1.5f);

    ui::UIConfig config;
    config.padding = 4.0f;
    config.scale = 1.0f;

    float result = config.effectivePadding();

    // Should be: 4.0f * 1.0f * 1.5f = 6.0f
    EXPECT_FLOAT_EQ(result, 6.0f);
}

// Test 6: Combined scale factors
TEST_F(UILayoutTest, EffectivePadding_CombinedScales) {
    globals::setGlobalUIScaleFactor(2.0f);

    ui::UIConfig config;
    config.padding = 5.0f;
    config.scale = 1.5f;

    float result = config.effectivePadding();

    // Should be: 5.0f * 1.5f * 2.0f = 15.0f
    EXPECT_FLOAT_EQ(result, 15.0f);
}
```

**Step 2: Add test file to CMakeLists.txt**

In `tests/unit/CMakeLists.txt`, add `test_ui_layout.cpp` to the test sources list.

**Step 3: Run tests to verify they fail**

Run: `just build-debug && ./build/tests/unit_tests --gtest_filter="UILayoutTest.*"`

Expected: FAIL - `effectivePadding` method does not exist yet

**Step 4: Commit test file**

```bash
git add tests/unit/test_ui_layout.cpp tests/unit/CMakeLists.txt
git commit -m "test: add UILayoutTest for effectivePadding method"
```

---

## Task 2: Implement UIConfig::effectivePadding() Method

**Files:**
- Modify: `src/systems/ui/ui_data.hpp:324` (inside UIConfig struct, before Builder)

**Step 1: Add effectivePadding() method to UIConfig**

Add this method inside the UIConfig struct, just before `struct Builder;`:

```cpp
    // Calculate effective padding with scale factors applied
    // Centralizes: padding.value_or(globals::getSettings().uiPadding) * scale.value_or(1.0f) * globals::getGlobalUIScaleFactor()
    float effectivePadding() const {
        return padding.value_or(globals::getSettings().uiPadding)
            * scale.value_or(1.0f)
            * globals::getGlobalUIScaleFactor();
    }

    struct Builder;
```

**Step 2: Run tests to verify they pass**

Run: `just build-debug && ./build/tests/unit_tests --gtest_filter="UILayoutTest.*"`

Expected: All 6 tests PASS

**Step 3: Commit implementation**

```bash
git add src/systems/ui/ui_data.hpp
git commit -m "feat(ui): add UIConfig::effectivePadding() method

Centralizes padding calculation: padding * scale * globalUIScale
Replaces ~40 duplicated calculations throughout the codebase"
```

---

## Task 3: Write Alignment Flag Conflict Detection Tests

**Files:**
- Modify: `tests/unit/test_ui_layout.cpp` (append tests)

**Step 1: Add alignment conflict detection tests**

Append to `tests/unit/test_ui_layout.cpp`:

```cpp
// ============================================================
// Alignment Flag Conflict Detection Tests
// ============================================================

#include "systems/transform/transform.hpp"

using Align = transform::InheritedProperties::Alignment;

// Test: No conflict with single flag
TEST_F(UILayoutTest, AlignmentFlags_SingleFlag_NoConflict) {
    std::string conflict;
    bool hasConflict = ui::hasConflictingAlignmentFlags(Align::VERTICAL_CENTER, &conflict);

    EXPECT_FALSE(hasConflict);
    EXPECT_TRUE(conflict.empty());
}

// Test: Valid combination (H_CENTER + V_CENTER)
TEST_F(UILayoutTest, AlignmentFlags_ValidCombination) {
    int flags = Align::HORIZONTAL_CENTER | Align::VERTICAL_CENTER;
    std::string conflict;
    bool hasConflict = ui::hasConflictingAlignmentFlags(flags, &conflict);

    EXPECT_FALSE(hasConflict);
}

// Test: Vertical conflict (CENTER + BOTTOM)
TEST_F(UILayoutTest, AlignmentFlags_VerticalConflict_CenterBottom) {
    int flags = Align::VERTICAL_CENTER | Align::VERTICAL_BOTTOM;
    std::string conflict;
    bool hasConflict = ui::hasConflictingAlignmentFlags(flags, &conflict);

    EXPECT_TRUE(hasConflict);
    EXPECT_FALSE(conflict.empty());
}

// Test: Vertical conflict (CENTER + TOP)
TEST_F(UILayoutTest, AlignmentFlags_VerticalConflict_CenterTop) {
    int flags = Align::VERTICAL_CENTER | Align::VERTICAL_TOP;
    std::string conflict;
    bool hasConflict = ui::hasConflictingAlignmentFlags(flags, &conflict);

    EXPECT_TRUE(hasConflict);
}

// Test: Vertical conflict (TOP + BOTTOM)
TEST_F(UILayoutTest, AlignmentFlags_VerticalConflict_TopBottom) {
    int flags = Align::VERTICAL_TOP | Align::VERTICAL_BOTTOM;
    std::string conflict;
    bool hasConflict = ui::hasConflictingAlignmentFlags(flags, &conflict);

    EXPECT_TRUE(hasConflict);
}

// Test: Horizontal conflict (CENTER + LEFT)
TEST_F(UILayoutTest, AlignmentFlags_HorizontalConflict_CenterLeft) {
    int flags = Align::HORIZONTAL_CENTER | Align::HORIZONTAL_LEFT;
    std::string conflict;
    bool hasConflict = ui::hasConflictingAlignmentFlags(flags, &conflict);

    EXPECT_TRUE(hasConflict);
}

// Test: Horizontal conflict (CENTER + RIGHT)
TEST_F(UILayoutTest, AlignmentFlags_HorizontalConflict_CenterRight) {
    int flags = Align::HORIZONTAL_CENTER | Align::HORIZONTAL_RIGHT;
    std::string conflict;
    bool hasConflict = ui::hasConflictingAlignmentFlags(flags, &conflict);

    EXPECT_TRUE(hasConflict);
}

// Test: Horizontal conflict (LEFT + RIGHT)
TEST_F(UILayoutTest, AlignmentFlags_HorizontalConflict_LeftRight) {
    int flags = Align::HORIZONTAL_LEFT | Align::HORIZONTAL_RIGHT;
    std::string conflict;
    bool hasConflict = ui::hasConflictingAlignmentFlags(flags, &conflict);

    EXPECT_TRUE(hasConflict);
}

// Test: Multiple conflicts detected
TEST_F(UILayoutTest, AlignmentFlags_MultipleConflicts) {
    int flags = Align::VERTICAL_CENTER | Align::VERTICAL_BOTTOM | Align::HORIZONTAL_LEFT | Align::HORIZONTAL_RIGHT;
    std::string conflict;
    bool hasConflict = ui::hasConflictingAlignmentFlags(flags, &conflict);

    EXPECT_TRUE(hasConflict);
    // Should report at least one conflict
    EXPECT_FALSE(conflict.empty());
}

// Test: nullptr for conflict description is safe
TEST_F(UILayoutTest, AlignmentFlags_NullptrDescription) {
    int flags = Align::VERTICAL_CENTER | Align::VERTICAL_BOTTOM;

    // Should not crash
    bool hasConflict = ui::hasConflictingAlignmentFlags(flags, nullptr);

    EXPECT_TRUE(hasConflict);
}
```

**Step 2: Run tests to verify they fail**

Run: `just build-debug && ./build/tests/unit_tests --gtest_filter="UILayoutTest.AlignmentFlags*"`

Expected: FAIL - `hasConflictingAlignmentFlags` function does not exist

**Step 3: Commit tests**

```bash
git add tests/unit/test_ui_layout.cpp
git commit -m "test: add alignment flag conflict detection tests"
```

---

## Task 4: Implement hasConflictingAlignmentFlags() Helper

**Files:**
- Modify: `src/systems/ui/ui_data.hpp` (add function declaration in namespace ui)
- Modify: `src/systems/ui/ui_data.cpp` (add function implementation)

**Step 1: Add function declaration to ui_data.hpp**

Add after the UIElementTemplateNode::Builder struct (around line 905), before closing the `ui` namespace:

```cpp
    // Detect conflicting alignment flags (e.g., VERTICAL_CENTER | VERTICAL_BOTTOM)
    // Returns true if conflicts exist, optionally fills conflictDescription with details
    bool hasConflictingAlignmentFlags(int flags, std::string* conflictDescription = nullptr);

} // namespace ui
```

**Step 2: Add function implementation to ui_data.cpp**

Add at the end of `src/systems/ui/ui_data.cpp`:

```cpp
bool ui::hasConflictingAlignmentFlags(int flags, std::string* conflictDescription) {
    using Align = transform::InheritedProperties::Alignment;

    bool vCenter = flags & Align::VERTICAL_CENTER;
    bool vTop    = flags & Align::VERTICAL_TOP;
    bool vBottom = flags & Align::VERTICAL_BOTTOM;
    bool hCenter = flags & Align::HORIZONTAL_CENTER;
    bool hLeft   = flags & Align::HORIZONTAL_LEFT;
    bool hRight  = flags & Align::HORIZONTAL_RIGHT;

    std::string conflict;

    // Check vertical conflicts
    if (vCenter && vTop) {
        conflict = "VERTICAL_CENTER conflicts with VERTICAL_TOP";
    } else if (vCenter && vBottom) {
        conflict = "VERTICAL_CENTER conflicts with VERTICAL_BOTTOM";
    } else if (vTop && vBottom) {
        conflict = "VERTICAL_TOP conflicts with VERTICAL_BOTTOM";
    }
    // Check horizontal conflicts
    else if (hCenter && hLeft) {
        conflict = "HORIZONTAL_CENTER conflicts with HORIZONTAL_LEFT";
    } else if (hCenter && hRight) {
        conflict = "HORIZONTAL_CENTER conflicts with HORIZONTAL_RIGHT";
    } else if (hLeft && hRight) {
        conflict = "HORIZONTAL_LEFT conflicts with HORIZONTAL_RIGHT";
    }

    if (!conflict.empty()) {
        if (conflictDescription) {
            *conflictDescription = conflict;
        }
        return true;
    }

    return false;
}
```

**Step 3: Add include for transform.hpp in ui_data.cpp if not present**

Ensure this include exists at the top of `ui_data.cpp`:
```cpp
#include "systems/transform/transform.hpp"
```

**Step 4: Run tests to verify they pass**

Run: `just build-debug && ./build/tests/unit_tests --gtest_filter="UILayoutTest.AlignmentFlags*"`

Expected: All 10 alignment tests PASS

**Step 5: Commit implementation**

```bash
git add src/systems/ui/ui_data.hpp src/systems/ui/ui_data.cpp
git commit -m "feat(ui): add hasConflictingAlignmentFlags() helper

Detects mutually exclusive alignment flag combinations:
- VERTICAL_CENTER vs TOP/BOTTOM
- HORIZONTAL_CENTER vs LEFT/RIGHT
- TOP vs BOTTOM, LEFT vs RIGHT"
```

---

## Task 5: Unify Padding Default Values

**Files:**
- Modify: `src/core/globals.hpp:447` (Settings struct)

**Step 1: Change Settings::uiPadding default from 10.0f to 4.0f**

In `src/core/globals.hpp`, find the Settings struct and change:

```cpp
struct Settings {
  bool shadowsOn = true;
  float uiPadding = 4.0f;  // Changed from 10.0f to match globals::uiPadding
};
```

**Step 2: Build and run tests**

Run: `just build-debug && ./build/tests/unit_tests --gtest_filter="UILayoutTest.*"`

Expected: All tests PASS (tests already expect 4.0f)

**Step 3: Commit**

```bash
git add src/core/globals.hpp
git commit -m "fix(ui): unify default padding to 4.0f

Settings::uiPadding and globals::uiPadding now both default to 4.0f
Previously: Settings had 10.0f, globals had 4.0f, causing inconsistent layouts"
```

---

## Task 6: Replace Padding Calculations in box.cpp (Part 1 - effectivePadding helper)

**Files:**
- Modify: `src/systems/ui/box.cpp:41-45`

**Step 1: Remove the unused inline effectivePadding function**

In `box.cpp`, find and delete:

```cpp
    inline float effectivePadding(const UIConfig& c) {
        return c.padding.value_or(globals::getSettings().uiPadding)
            * c.scale.value()
            * globals::getGlobalUIScaleFactor();
    }
```

**Step 2: Build to verify no breaking changes**

Run: `just build-debug`

Expected: Build succeeds (function was never called)

**Step 3: Commit**

```bash
git add src/systems/ui/box.cpp
git commit -m "refactor(ui): remove unused effectivePadding inline function

Replaced by UIConfig::effectivePadding() method"
```

---

## Task 7: Replace Padding Calculations in box.cpp (Part 2 - handleAlignment)

**Files:**
- Modify: `src/systems/ui/box.cpp` (handleAlignment function, lines ~617-760)

**Step 1: Replace padding calculations in handleAlignment**

In `box.cpp`, function `handleAlignment`, replace all instances of:
```cpp
uiConfig.padding.value_or(globals::getSettings().uiPadding) * uiConfig.scale.value() * globals::getGlobalUIScaleFactor()
```
with:
```cpp
uiConfig.effectivePadding()
```

Specific locations in handleAlignment (~lines 617-760):
- Line 618: `selfContentDimensions.x -= 2 * uiConfig.effectivePadding();`
- Line 619: `selfContentDimensions.y -= 2 * uiConfig.effectivePadding();`
- Line 621: `selfContentOffset.x += uiConfig.effectivePadding();`
- Line 622: `selfContentOffset.y += uiConfig.effectivePadding();`
- Line 693: Replace the long formula with `uiConfig.effectivePadding()`
- Line 695: Replace with `uiConfig.effectivePadding()`
- Line 709: Replace with `uiConfig.effectivePadding()`
- Line 711: Replace with `uiConfig.effectivePadding()`
- Line 729: Replace with `uiConfig.effectivePadding()`
- Line 731: Replace with `uiConfig.effectivePadding()`
- Line 757: Replace with `uiConfig.effectivePadding()`
- Line 759: Replace with `uiConfig.effectivePadding()`

**Step 2: Build and run tests**

Run: `just build-debug && ./build/tests/unit_tests --gtest_filter="UILayoutTest.*"`

Expected: Build succeeds, all tests pass

**Step 3: Commit**

```bash
git add src/systems/ui/box.cpp
git commit -m "refactor(ui): use effectivePadding() in handleAlignment

Replaced 12 duplicated padding calculations with UIConfig::effectivePadding()"
```

---

## Task 8: Replace Padding Calculations in box.cpp (Part 3 - CalcTreeSizes and placeUIElementsRecursively)

**Files:**
- Modify: `src/systems/ui/box.cpp` (multiple functions)

**Step 1: Replace in CalcTreeSizes area (~line 926)**

Replace:
```cpp
float padding = uiConfig.padding.value_or(globals::getSettings().uiPadding) * uiConfig.scale.value() * globals::getGlobalUIScaleFactor();
```
with:
```cpp
float padding = uiConfig.effectivePadding();
```

**Step 2: Replace in placeUIElementsRecursively (~lines 1258-1375)**

Replace all instances of the duplicated formula with `uiConfig.effectivePadding()`.

Key locations:
- Lines 1266-1267
- Lines 1290-1303 (multiple)
- Lines 1352-1376 (multiple)

**Step 3: Replace in TreeCalcSubContainer (~line 1411)**

Replace:
```cpp
float padding = uiConfig.padding.value_or(globals::getSettings().uiPadding) * uiConfig.scale.value();
```
with:
```cpp
float padding = uiConfig.effectivePadding();
```

Note: This one is missing `* globals::getGlobalUIScaleFactor()` - this is a BUG that effectivePadding() will fix.

**Step 4: Replace in scroll pane calculation (~line 1479)**

Replace the formula with `uiConfig.effectivePadding()`.

**Step 5: Build and run tests**

Run: `just build-debug && ./build/tests/unit_tests --gtest_filter="UILayoutTest.*"`

Expected: Build succeeds, all tests pass

**Step 6: Commit**

```bash
git add src/systems/ui/box.cpp
git commit -m "refactor(ui): use effectivePadding() in CalcTreeSizes and placement

Replaced ~18 more padding calculations in:
- CalcTreeSizes
- placeUIElementsRecursively
- TreeCalcSubContainer
- scroll pane calculations

Also fixed bug where globalUIScaleFactor was missing in TreeCalcSubContainer"
```

---

## Task 9: Replace Padding Calculations in element.cpp

**Files:**
- Modify: `src/systems/ui/element.cpp`

**Step 1: Replace in SetAlignments (~line 1093)**

Change:
```cpp
float padding = config->padding.value_or(globals::getUiPadding());
```
to:
```cpp
float padding = config->effectivePadding();
```

Note: This fixes the bug where `globals::getUiPadding()` was used instead of `globals::getSettings().uiPadding`, and scale factors were missing.

**Step 2: Search for any other padding calculations in element.cpp**

Search for `padding.value_or` and replace with `effectivePadding()` calls.

**Step 3: Build and run tests**

Run: `just build-debug && ./build/tests/unit_tests --gtest_filter="UILayoutTest.*"`

Expected: Build succeeds, all tests pass

**Step 4: Commit**

```bash
git add src/systems/ui/element.cpp
git commit -m "refactor(ui): use effectivePadding() in element.cpp

Fixed bug in SetAlignments where:
- globals::getUiPadding() was used instead of getSettings().uiPadding
- scale factors were not applied to padding"
```

---

## Task 10: Add Alignment Conflict Warnings to handleAlignment

**Files:**
- Modify: `src/systems/ui/box.cpp` (handleAlignment function)

**Step 1: Add conflict detection at start of alignment processing**

In `handleAlignment`, after getting alignmentFlags (~line 590), add:

```cpp
auto alignmentFlags = uiConfig.alignmentFlags.value();

// Warn about conflicting alignment flags
std::string conflictDesc;
if (ui::hasConflictingAlignmentFlags(alignmentFlags, &conflictDesc)) {
    SPDLOG_WARN("Entity {}: {} - using first applicable flag",
                static_cast<int>(entity), conflictDesc);
}
```

**Step 2: Change if statements to else-if for deterministic behavior**

In handleAlignment, change the alignment flag checks from:

```cpp
if (alignmentFlags & VERTICAL_CENTER) { ... }
if (alignmentFlags & HORIZONTAL_CENTER) { ... }
if (alignmentFlags & HORIZONTAL_RIGHT) { ... }
if (alignmentFlags & VERTICAL_BOTTOM) { ... }
```

To prioritized else-if chains:

```cpp
// Vertical alignment (CENTER takes priority)
if (alignmentFlags & transform::InheritedProperties::Alignment::VERTICAL_CENTER) {
    // ... existing code
}
else if (alignmentFlags & transform::InheritedProperties::Alignment::VERTICAL_TOP) {
    // TOP is default, no action needed
}
else if (alignmentFlags & transform::InheritedProperties::Alignment::VERTICAL_BOTTOM) {
    // ... existing code
}

// Horizontal alignment (CENTER takes priority)
if (alignmentFlags & transform::InheritedProperties::Alignment::HORIZONTAL_CENTER) {
    // ... existing code
}
else if (alignmentFlags & transform::InheritedProperties::Alignment::HORIZONTAL_LEFT) {
    // LEFT is default, no action needed
}
else if (alignmentFlags & transform::InheritedProperties::Alignment::HORIZONTAL_RIGHT) {
    // ... existing code
}
```

**Step 3: Build and run tests**

Run: `just build-debug && ./build/tests/unit_tests --gtest_filter="UILayoutTest.*"`

Expected: Build succeeds, all tests pass

**Step 4: Commit**

```bash
git add src/systems/ui/box.cpp
git commit -m "fix(ui): add alignment flag conflict detection and deterministic handling

- Warn when conflicting flags like VERTICAL_CENTER | VERTICAL_BOTTOM are set
- Changed if → else-if to ensure deterministic behavior
- CENTER flags take priority over edge flags"
```

---

## Task 11: Run Full Test Suite and Manual Verification

**Step 1: Run all unit tests**

Run: `just test`

Expected: All tests pass

**Step 2: Build and launch the game**

Run: `just build-debug && ./build/raylib-cpp-cmake-template`

**Step 3: Manual verification checklist**

- [ ] Main menu UI renders correctly
- [ ] In-game UI panels have correct spacing
- [ ] Buttons are properly aligned
- [ ] Scroll panes work correctly
- [ ] No visual regressions compared to master branch

**Step 4: Final commit if any fixes needed**

```bash
git status
# If any fixes were needed, commit them
```

---

## Task 12: Final Summary Commit

**Step 1: Review all changes**

Run: `git log --oneline bugfix/cpp-ui-system`

**Step 2: Push branch**

```bash
git push -u origin bugfix/cpp-ui-system
```

---

## Summary of Changes

| File | Changes |
|------|---------|
| `tests/unit/test_ui_layout.cpp` | NEW - 16 unit tests for padding and alignment |
| `src/systems/ui/ui_data.hpp` | Added `effectivePadding()` method, `hasConflictingAlignmentFlags()` declaration |
| `src/systems/ui/ui_data.cpp` | Added `hasConflictingAlignmentFlags()` implementation |
| `src/core/globals.hpp` | Changed `Settings::uiPadding` from 10.0f to 4.0f |
| `src/systems/ui/box.cpp` | Replaced ~30 padding calculations, added conflict warnings, fixed if→else-if |
| `src/systems/ui/element.cpp` | Replaced ~10 padding calculations, fixed missing scale factors |

## Verification Commands

```bash
# Run all UI tests
just test && ./build/tests/unit_tests --gtest_filter="UILayoutTest.*"

# Build and run game for visual verification
just build-debug && ./build/raylib-cpp-cmake-template
```

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
