# Controller Navigation System - Feature Upgrades Plan

**Created**: 2026-01-19  
**Status**: Planning Complete - Ready for Implementation

---

## Executive Summary

The `controller_nav` system is a solid foundation that already implements many industry best practices (spatial navigation, layers, groups, callbacks, gamestate filtering). However, analysis identified **4 critical bugs** and **~10 feature gaps** compared to Unity/Unreal standards.

---

## Current Architecture (Strengths)

| Feature | Status | Notes |
|---------|--------|-------|
| Spatial navigation | ✅ Good | Dominant-axis + acceptance cone logic |
| Linear navigation | ✅ Good | Index-based with wrap option |
| Groups & Layers | ✅ Good | Hierarchical organization |
| Lua callbacks | ✅ Good | on_focus, on_unfocus, on_select |
| Entity gamestate filtering | ✅ Good | Skips inactive entities automatically |
| Input cooldowns | ✅ Basic | Global cooldown per group |
| Group linking | ✅ Good | Cross-group directional transitions |
| Enable/disable entities | ✅ Good | Runtime toggling |

---

## 🔴 P0 Critical - Correctness Bugs (Fix First!)

### 1. Layer Stack / Focus Group Stack Conflation
- **File**: `src/systems/input/controller_nav.hpp` (line 73), `controller_nav.cpp`
- **Bug**: `layerStack` is used by both `push_layer/pop_layer` AND `push_focus_group/pop_focus_group`
- **Impact**: Calling focus-group APIs corrupts layer navigation state
- **Fix**: Split into separate stacks:
  ```cpp
  std::vector<std::string> layerStack;      // For layers
  std::vector<std::string> focusGroupStack; // For focus groups only
  ```
  Define semantics:
  - `layerStack`: tracks active modal layer history
  - `focusGroupStack`: tracks currently focused group history (used by push_focus_group/pop_focus_group only)
- **Effort**: Low-Medium

### 2. Spatial Navigation Blocks Cross-Group Transitions
- **File**: `src/systems/input/controller_nav.cpp` (around line 263-268)
- **Bug**: In `navigate()`, spatial mode returns early when no candidates exist, **before** the linked-group transition block runs
- **Impact**: `link_groups()` doesn't work reliably at group edges in spatial mode
- **Fix**: Refactor navigation into phases:
  1. Find in-group candidate
  2. If none found, try group transition (upGroup/downGroup/etc.)
  3. Apply fallback policy (stay put / wrap)

  **Control flow note**: move the linked-group transition block to run after spatial candidate search fails, before any early return.
- **Effort**: Medium

### 3. Selection Validity Not Enforced
- **File**: `src/systems/input/controller_nav.cpp` (line 92-99)
- **Bug**: `get_selected()` returns `entries[0]` when `selectedIndex` is invalid without checking entity validity/enabled/active status
- **Impact**: Focus can point to dead/disabled entities
- **Fix**: 
  - Create `resolve_valid_selected()` helper that validates entity
  - Validate against: `reg.valid(e)`, `is_entity_enabled(e)`, and `entity_gamestate_management::isEntityActive(e)`
  - Re-validate selection after `remove_entity()`, `clear_group()`, `set_entity_enabled()`
- **Effort**: Medium

### 4. Crashy Asserts in Release Builds
- **File**: `src/systems/input/controller_nav.cpp` (lines 51, 385)
- **Bug**: `assert(!layerStack.empty())` in `pop_layer()` can hard-crash players
- **Impact**: Content bugs = player crashes
- **Fix**: Keep debug asserts, but log errors and recover gracefully at runtime:
  ```cpp
  if (layerStack.empty()) {
      SPDLOG_ERROR("[Nav] pop_layer() called on empty stack");
      return; // graceful recovery
  }
  ```
- **Effort**: Low

---

## 🟠 P1 High Priority - Feature Gaps

### 5. Missing Explicit Per-Element Neighbors (Unity "Explicit Navigation")
- **Gap**: You have group-to-group links, but not per-widget explicit neighbors
- **Why Needed**: Avoid bad auto-picks in complex layouts
- **Solution**: Add `NavNeighbors` component:
  ```cpp
  struct NavNeighbors {
      std::optional<entt::entity> up, down, left, right;
  };
  ```
- Navigation resolution order: **explicit neighbor → group link → automatic spatial/linear**
- Lua bindings to add (example):
  - `controller_nav.set_neighbors(entity, { up=..., down=..., left=..., right=... })`
- **Effort**: Medium | **Impact**: High

### 6. Missing Scroll-Into-View + Right Stick Scroll Support
- **Gap**: Focus changes but scroll panes don't follow; no right stick scrolling
- **Why Needed**: Essential for lists, grids, inventories (like character pane)
- **Solution**:
  - On focus change, detect if inside `ScrollPane` via `UIPaneParentRef` component
  - Call `scroll_to_make_visible(entity)` helper
    - Use `UIScrollComponent::viewportSize` and `contentSize`
    - Clamp offsets to `minOffset` / `maxOffset`
  - Add right stick handling in `input_gamepad.cpp` to scroll `InputState.activeScrollPane`
- **Effort**: Medium | **Impact**: High

### 7. Basic Input Repeat (Only Cooldown)
- **Gap**: Industry standard uses initial delay + repeat rate + optional acceleration
- **Current**: Fixed `globalCooldown` per group (0.08s)
- **Solution**: 
  ```cpp
  struct NavRepeatConfig {
      float initialDelay = 0.25f;   // Time before repeat starts
      float repeatRate = 0.08f;     // Time between repeats
      float acceleration = 1.0f;   // Speed up factor over time
  };
  ```
- **Effort**: Medium | **Impact**: Medium-High (feel improvement)

### 8. Missing Focus Restoration & Modal Scopes
- **Gap**: Unity/UMG restore focus when closing modals; trap focus inside topmost modal
- **Solution**: 
  - Store previous focus on `push_layer()`:
    ```cpp
    struct LayerState {
        std::string layerName;
        entt::entity previousFocus = entt::null;
        std::string previousGroup;
    };
    ```
  - Restore on `pop_layer()` if configured
- **Effort**: Medium | **Impact**: High for menus

---

## 🟡 P2 Medium Priority - Developer Ergonomics

### 9. Add entityToGroup Map for O(1) Callback Lookups
- **Gap**: `notify_focus/select` scan all groups to find entity's group
- **Solution**: 
  ```cpp
  std::unordered_map<entt::entity, std::string> entityToGroup;
  ```
  Update in `add_entity()`, `remove_entity()`, `clear_group()`, `reset()`
- **Effort**: Low | **Impact**: Medium (scales with UI size)

### 10. Expand validate() Function
- **Gap**: `validate()` only checks layer→group references
- **Solution**: Also check:
  - `selectedIndex` validity
  - Entries that are invalid/dead entities
  - Links to missing groups
  - (optional) Reachability within a layer
- **Effort**: Medium | **Impact**: Medium (debugging)

---

## Implementation Order

| Phase | Items | Effort | Outcome |
|-------|-------|--------|---------|
| **Phase 1** | P0 bugs (#1-4) | 1 day | System works correctly |
| **Phase 2** | P1 features (#5-8) | 2-3 days | Industry-standard UX |
| **Phase 3** | P2 ergonomics (#9-10) | 1 day | Developer productivity |
| **Phase 4** | Lua bindings + docs + tests | 1 day | Complete package |

---

## Comparison vs Industry Standards

| Feature | Your System | Unity UI Nav | Unreal UMG |
|---------|-------------|--------------|------------|
| Spatial navigation | ✅ | ✅ | ✅ |
| Linear navigation | ✅ | ✅ | ✅ |
| Explicit neighbors | ❌ **Add** | ✅ | ✅ |
| Scroll-into-view | ❌ **Add** | ✅ | ✅ |
| Focus restoration | ❌ **Add** | ✅ | ✅ |
| Repeat behavior | ⚠️ Basic | ✅ | ✅ |
| Layer/scope system | ✅ | ✅ | ✅ |
| Right stick scroll | ❌ **Add** | ✅ | ✅ |

---

## Files to Modify

| File | Changes |
|------|---------|
| `src/systems/input/controller_nav.hpp` | Add new structs, split stacks, add entityToGroup map |
| `src/systems/input/controller_nav.cpp` | Fix bugs, implement new features |
| `src/systems/input/input_gamepad.cpp` | Add right stick scroll handling (scroll active pane) |
| `src/systems/input/input_functions.cpp` | Integrate right stick scroll + focus-to-scroll logic hooks |
| `src/systems/ui/box.cpp` | Add scroll_to_make_visible helper |
| `docs/systems/advanced/controller_navigation.md` | Update documentation |
| `tests/unit/test_controller_nav.cpp` | Add tests for new functionality |
| `assets/scripts/chugget_code_definitions.lua` | Update Lua API definitions |

---

## Test Coverage to Add

- Spatial nav falls back to linked group when no candidates
- Selection validity after entity removal/disable
- Focus restoration on pop_layer
- Explicit neighbor overrides take precedence
- Scroll-into-view adjusts pane offset
- Right stick scroll moves activeScrollPane

## Notes

- The `push_focus_group/pop_focus_group` API is confirmed to be used, so we need to split stacks rather than remove
- Right stick scroll should integrate with existing `activeScrollPane` tracking in `InputState`
- Character pane confirmed to have scroll UI that would benefit from scroll-into-view

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
