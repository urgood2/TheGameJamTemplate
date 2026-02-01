# UI System Bugfixes Design

**Date:** 2025-12-14
**Branch:** `bugfix/cpp-ui-system`
**Status:** Approved

## Problem Statement

The C++ UI system has several bugs and inconsistencies that cause layout issues:

1. **Two conflicting default padding values** - `Settings::uiPadding` (10.0f) vs `globals::uiPadding` (4.0f)
2. **Zero padding produces incorrect sizes** - Container size calculation breaks when padding=0
3. **~40 duplicated padding calculations** - Same formula copy-pasted instead of using helper
4. **Conflicting alignment flags** - Setting `VERTICAL_CENTER | VERTICAL_BOTTOM` has unpredictable results
5. **SetAlignments vs handleAlignment inconsistency** - Different functions use different padding sources
6. **No unit tests** - Regressions not caught

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Canonical default padding | **4.0f** | Tighter spacing, matches element.cpp usage |
| Padding helper location | **`UIConfig::effectivePadding()` method** | Clean call sites, encapsulates scale logic |
| Conflicting flags behavior | **Warn + use first flag** | Helps users catch mistakes early |
| Test scope | **Core calculations only** | Fast, focused, maintainable |
| UIConfig struct | **Don't decompose** | Out of scope, separate effort |

## Implementation Architecture

### File Changes

```
src/core/globals.hpp          # Unify padding defaults
src/core/globals.cpp          # Remove duplicate default
src/systems/ui/ui_data.hpp    # Add effectivePadding() method
src/systems/ui/box.cpp        # Replace 30+ calculations, fix zero-padding bug
src/systems/ui/element.cpp    # Replace 10+ calculations, unify with box.cpp
tests/unit/test_ui_layout.cpp # NEW: Unit tests for calculations
```

### New Method: `UIConfig::effectivePadding()`

```cpp
// In ui_data.hpp, inside UIConfig struct:
float effectivePadding() const {
    return padding.value_or(globals::getSettings().uiPadding)
        * scale.value_or(1.0f)
        * globals::getGlobalUIScaleFactor();
}
```

### New Helper: `hasConflictingAlignmentFlags()`

```cpp
bool hasConflictingAlignmentFlags(int flags, std::string* conflictDescription = nullptr);
```

Detects when mutually exclusive flags are combined (e.g., `VERTICAL_CENTER | VERTICAL_BOTTOM`).

## Bug Fixes

### A. Zero Padding Fix

Standardize container size formula:
```
Total size = sum(child_sizes) + (num_children - 1) * padding + 2 * padding
           = sum(child_sizes) + (num_children + 1) * padding
```

This gives: padding on edges + padding between each child.

### B. Alignment Flag Conflicts

1. Add `hasConflictingAlignmentFlags()` detection
2. Log `SPDLOG_WARN` when conflicts detected
3. Change `if` chains to `else if` for deterministic behavior

## Testing Strategy

New test file: `tests/unit/test_ui_layout.cpp`

### Test Categories

```cpp
// 1. effectivePadding() tests
TEST(UILayoutTest, EffectivePadding_DefaultValues)
TEST(UILayoutTest, EffectivePadding_ExplicitPadding)
TEST(UILayoutTest, EffectivePadding_WithScale)
TEST(UILayoutTest, EffectivePadding_ZeroPadding)
TEST(UILayoutTest, EffectivePadding_ZeroScale)

// 2. Size calculation tests
TEST(UILayoutTest, ContainerSize_SingleChild)
TEST(UILayoutTest, ContainerSize_MultipleChildren_Vertical)
TEST(UILayoutTest, ContainerSize_MultipleChildren_Horizontal)
TEST(UILayoutTest, ContainerSize_ZeroPadding)
TEST(UILayoutTest, ContainerSize_NestedContainers)

// 3. Alignment flag tests
TEST(UILayoutTest, AlignmentFlags_SingleFlag)
TEST(UILayoutTest, AlignmentFlags_CombinedValid)
TEST(UILayoutTest, AlignmentFlags_ConflictDetection)
```

## Implementation Order

| Phase | Task | Risk |
|-------|------|------|
| 1 | Write tests for `effectivePadding()` | Low |
| 2 | Add `UIConfig::effectivePadding()` method | Low |
| 3 | Write tests for alignment conflict detection | Low |
| 4 | Add `hasConflictingAlignmentFlags()` helper | Low |
| 5 | Unify padding defaults (10→4 in Settings) | Medium |
| 6 | Replace calculations in `box.cpp` (~30 sites) | Medium |
| 7 | Replace calculations in `element.cpp` (~10 sites) | Medium |
| 8 | Write tests for zero-padding case | Low |
| 9 | Fix zero-padding bug in `SubCalculateContainerSize` | Medium |
| 10 | Add conflict warnings to `handleAlignment()` | Low |
| 11 | Change `if` → `else if` for alignment flags | Low |

## Verification Checkpoints

- After Phase 5: Launch game, verify existing UIs look correct
- After Phase 7: Run all tests, verify compilation clean
- After Phase 9: Run zero-padding test, verify it passes
- Final: Full game playthrough of UI-heavy screens

## Success Criteria

1. Single padding default (4.0f) used everywhere
2. All 40+ padding calculations call `effectivePadding()`
3. Zero padding produces correct layouts
4. Conflicting alignment flags emit warnings
5. Unit tests cover all calculation functions
6. Existing UI behavior unchanged (no visual regressions)

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
