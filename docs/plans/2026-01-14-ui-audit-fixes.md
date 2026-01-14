# UI Audit Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Address all critical and high-priority issues identified in the comprehensive UI audit, eliminating memory leaks, enabling the handler system, fixing collision bugs, and adding safety utilities.

**Architecture:** Five independent fixes that can be implemented in parallel or sequentially. Each fix targets a specific subsystem (C++ handlers, Lua registries, collision buffers, component migration, Sol2 safety). Changes are isolated to minimize risk.

**Tech Stack:** C++20, Lua 5.4, Sol2, EnTT, Raylib

---

## Overview of Fixes

| Priority | Fix | Type | Risk | Files |
|----------|-----|------|------|-------|
| P1 | Enable Handler System | C++ | Low | 2 files |
| P1 | Add Entity Cleanup Hook | Lua | Medium | 5 files |
| P1 | Add Nil Guard Utility | Lua | Low | 2 files |
| P2 | Fix Hover/Drag Buffer | C++ | Low | 1 file |
| P2 | Complete Component Migration | C++/Lua | High | 10+ files |

---

## Task 1: Enable Handler System

**Goal:** Enable the built-but-disabled UI handler system to use the modern Strategy pattern for rendering.

**Files:**
- Modify: `src/systems/ui/element.cpp:27-29`
- Modify: `src/core/game.cpp` (or equivalent initialization file)

### Step 1.1: Read current handler registration code

Read `src/systems/ui/handlers/handler_registry.cpp` to verify `registerAllHandlers()` implementation exists.

### Step 1.2: Enable feature flag

**File:** `src/systems/ui/element.cpp`

Change line 28 from:
```cpp
#define UI_USE_HANDLERS 0
```

To:
```cpp
#define UI_USE_HANDLERS 1
```

### Step 1.3: Verify handler registration is called at startup

**File:** Search for where `registerAllHandlers()` should be called.

If not found, add to initialization (after Lua but before UI):

```cpp
#include "systems/ui/handlers/handler_registry.hpp"

// In initialization function:
ui::registerAllHandlers();
```

### Step 1.4: Build and test

Run:
```bash
just build-debug
```

Expected: Build succeeds without errors.

### Step 1.5: Run visual test

Run:
```bash
(./build/raylib-cpp-cmake-template 2>&1 & sleep 10; kill $!) | tail -50
```

Expected: UI renders correctly. Look for any rendering artifacts or errors.

### Step 1.6: Commit

```bash
git add src/systems/ui/element.cpp
git commit -m "feat(ui): enable handler-based rendering

Enable UI_USE_HANDLERS feature flag to use the Strategy pattern
for type-specific UI element rendering. Handlers were built and
tested but never enabled in production.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Add Entity Cleanup Hook

**Goal:** Create a centralized cleanup function that removes entity metadata from all Lua registries, preventing memory leaks.

**Files:**
- Create: `assets/scripts/ui/ui_cleanup.lua`
- Modify: `assets/scripts/ui/ui_syntax_sugar.lua` (add export of cleanup functions)
- Modify: `assets/scripts/ui/ui_decorations.lua` (verify cleanup exists)
- Modify: `assets/scripts/ui/ui_background.lua` (verify cleanup exists)
- Modify: Entity destruction paths (gameplay.lua or equivalent)

### Step 2.1: Create centralized cleanup module

**File:** `assets/scripts/ui/ui_cleanup.lua`

```lua
---@module ui.ui_cleanup
--- Centralized cleanup for all UI registries to prevent memory leaks.
--- Call cleanupEntity() when destroying any UI entity.

local UICleanup = {}

-- Import cleanup functions from each module
local dsl = require("ui.ui_syntax_sugar")
local UIDecorations = require("ui.ui_decorations")
local UIBackground = require("ui.ui_background")

-- Optional: tooltip_v2 if it has cleanup
local ok, TooltipV2 = pcall(require, "ui.tooltip_v2")
if not ok then TooltipV2 = nil end

--- Clean up all registry entries for an entity.
--- Call this before destroying any UI entity to prevent memory leaks.
---@param entity number The entity ID to clean up
function UICleanup.cleanupEntity(entity)
    if not entity then return end

    local key = tostring(entity)

    -- Tab registry cleanup
    if dsl.cleanupTabs then
        pcall(dsl.cleanupTabs, key)
    end

    -- Grid registry cleanup
    if dsl.cleanupGrid then
        pcall(dsl.cleanupGrid, key)
    end

    -- Decoration registry cleanup
    if UIDecorations and UIDecorations.cleanup then
        pcall(UIDecorations.cleanup, entity)
    end

    -- Background registry cleanup
    if UIBackground and UIBackground.remove then
        pcall(UIBackground.remove, entity)
    end

    -- Tooltip cache cleanup (if available)
    if TooltipV2 and TooltipV2.hideForAnchor then
        pcall(TooltipV2.hideForAnchor, entity)
    end
end

--- Clean up all registries for a UI box and its children.
--- Recursively cleans all child entities.
---@param boxEntity number The UI box entity to clean up
function UICleanup.cleanupUIBox(boxEntity)
    if not boxEntity or not registry:valid(boxEntity) then return end

    -- Get GameObject for children
    local go = component_cache.get(boxEntity, GameObject)
    if go and go.orderedChildren then
        for _, child in ipairs(go.orderedChildren) do
            UICleanup.cleanupUIBox(child)
        end
    end

    -- Clean up this entity
    UICleanup.cleanupEntity(boxEntity)
end

return UICleanup
```

### Step 2.2: Export cleanupGrid from ui_syntax_sugar.lua

**File:** `assets/scripts/ui/ui_syntax_sugar.lua`

Find `dsl.cleanupTabs` (around line 826) and verify `dsl.cleanupGrid` exists nearby. If not, add after line 946:

```lua
--- Clean up grid registry entry (call when destroying inventory grid)
--- @param gridId string The grid's ID
function dsl.cleanupGrid(gridId)
    _gridRegistry[gridId] = nil
end
```

### Step 2.3: Integrate with entity destruction

**File:** Find main entity destruction path (likely `assets/scripts/core/entity_lifecycle.lua` or in gameplay.lua)

Add import at top:
```lua
local UICleanup = require("ui.ui_cleanup")
```

Add cleanup call before entity destruction:
```lua
-- Before registry:destroy(entity)
UICleanup.cleanupEntity(entity)
```

### Step 2.4: Test cleanup

Create test in Lua console or test file:

```lua
-- Test: Create UI, destroy it, verify no registry leak
local dsl = require("ui.ui_syntax_sugar")
local UICleanup = require("ui.ui_cleanup")

local box = dsl.spawn({ x = 100, y = 100 }, dsl.root {
    children = { dsl.text("Test") }
})

-- Before cleanup
print("Box created:", box)

-- Cleanup
UICleanup.cleanupUIBox(box)
registry:destroy(box)

print("Cleanup complete")
```

### Step 2.5: Commit

```bash
git add assets/scripts/ui/ui_cleanup.lua assets/scripts/ui/ui_syntax_sugar.lua
git commit -m "feat(ui): add centralized entity cleanup hook

Create ui_cleanup.lua module that cleans all registry entries
(tabs, grids, decorations, backgrounds, tooltips) when UI entities
are destroyed. Prevents memory leaks from orphaned registry entries.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Add Nil Guard Utility

**Goal:** Create a safe wrapper for Sol2 builder calls that prevents nil-to-C++ crashes.

**Files:**
- Create: `assets/scripts/core/sol2_safety.lua`
- Modify: `assets/scripts/ui/ui_definition_helper.lua` (use utility)

### Step 3.1: Create safety utility module

**File:** `assets/scripts/core/sol2_safety.lua`

```lua
---@module core.sol2_safety
--- Safety utilities for Sol2 C++ interop.
--- Prevents SIGSEGV crashes from passing nil to C++ methods.

local Sol2Safety = {}

--- Safely call a builder method, skipping if value is nil.
--- @param builder userdata The Sol2 builder object
--- @param method string The method name (e.g., "addColor")
--- @param value any The value to pass (skipped if nil)
--- @return userdata The builder (for chaining)
function Sol2Safety.safeBuilderCall(builder, method, value)
    if value == nil then
        return builder
    end

    local fn = builder[method]
    if not fn then
        log_debug("[sol2_safety] Unknown method: " .. tostring(method))
        return builder
    end

    local ok, err = pcall(fn, builder, value)
    if not ok then
        log_warn("[sol2_safety] Builder call failed: " .. method .. " - " .. tostring(err))
    end

    return builder
end

--- Safely apply multiple values to a builder.
--- @param builder userdata The Sol2 builder object
--- @param values table Key-value pairs where keys are method suffixes (e.g., "Color" for "addColor")
--- @return userdata The builder (for chaining)
function Sol2Safety.safeApplyAll(builder, values)
    for key, value in pairs(values) do
        if value ~= nil then
            local method = "add" .. key:sub(1,1):upper() .. key:sub(2)
            Sol2Safety.safeBuilderCall(builder, method, value)
        end
    end
    return builder
end

--- Check if a value is safe to pass to C++ (not nil, not invalid userdata).
--- @param value any The value to check
--- @return boolean True if safe to pass
function Sol2Safety.isSafe(value)
    if value == nil then
        return false
    end

    -- Check for invalid userdata (destroyed Sol2 objects)
    if type(value) == "userdata" then
        local ok, _ = pcall(tostring, value)
        return ok
    end

    return true
end

--- Wrap a function to skip execution if any argument is nil.
--- @param fn function The function to wrap
--- @return function The wrapped function
function Sol2Safety.nilGuard(fn)
    return function(...)
        local args = {...}
        for i, arg in ipairs(args) do
            if arg == nil then
                log_debug("[sol2_safety] nilGuard: skipping call, arg " .. i .. " is nil")
                return nil
            end
        end
        return fn(...)
    end
end

return Sol2Safety
```

### Step 3.2: Update ui_definition_helper.lua to use utility

**File:** `assets/scripts/ui/ui_definition_helper.lua`

Add import at top (after other requires):
```lua
local Sol2Safety = require("core.sol2_safety")
```

Replace direct nil checks with utility where appropriate. Find the `makeConfigFromTable` function and update the pattern:

```lua
-- Instead of:
if v == nil then
    log_debug("[ui.def] Skipping nil value for key: " .. tostring(k))
    goto continue
end

-- Use:
if not Sol2Safety.isSafe(v) then
    goto continue
end
```

### Step 3.3: Test safety utility

```lua
local Sol2Safety = require("core.sol2_safety")

-- Test nil guard
local builder = UIConfigBuilder.create()
Sol2Safety.safeBuilderCall(builder, "addColor", nil)  -- Should not crash
Sol2Safety.safeBuilderCall(builder, "addWidth", 100)  -- Should work
print("Safety test passed")
```

### Step 3.4: Commit

```bash
git add assets/scripts/core/sol2_safety.lua assets/scripts/ui/ui_definition_helper.lua
git commit -m "feat(core): add Sol2 safety utilities

Create sol2_safety.lua module with:
- safeBuilderCall: skip nil values without crashing
- safeApplyAll: bulk apply with nil filtering
- isSafe: check if value can be passed to C++
- nilGuard: wrap functions to skip on nil args

Prevents SIGSEGV crashes from nil-to-C++ calls via Sol2.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Fix Hover/Drag Buffer Logic

**Goal:** Fix the bug where hover and drag buffers stack additively instead of using max().

**Files:**
- Modify: `src/systems/collision/broad_phase.hpp:164-173`

### Step 4.1: Read current implementation

**File:** `src/systems/collision/broad_phase.hpp`

Current code (lines 164-173):
```cpp
// apply hover/drag "forgiveness"
float bufX = 0, bufY = 0;
if (go.state.isBeingHovered) {
    bufX += T->getHoverCollisionBufferX();
    bufY += T->getHoverCollisionBufferY();
}
if (go.state.isBeingDragged) {
    bufX += T->getHoverCollisionBufferX();
    bufY += T->getHoverCollisionBufferY();
}
```

**Problem:** When both hovering AND dragging, buffer is doubled (additive).

### Step 4.2: Fix buffer logic to use max

**File:** `src/systems/collision/broad_phase.hpp`

Replace lines 164-173 with:
```cpp
// apply hover/drag "forgiveness" - use max, not sum
float bufX = 0, bufY = 0;
if (go.state.isBeingHovered || go.state.isBeingDragged) {
    // Both states use the same buffer, so just apply once
    // Using hover buffer since it's the "forgiveness" buffer
    bufX = T->getHoverCollisionBufferX();
    bufY = T->getHoverCollisionBufferY();
}
```

Or if hover and drag should have different buffers in the future:
```cpp
// apply hover/drag "forgiveness" - use max of either state's buffer
float bufX = 0, bufY = 0;
float hoverBufX = go.state.isBeingHovered ? T->getHoverCollisionBufferX() : 0;
float hoverBufY = go.state.isBeingHovered ? T->getHoverCollisionBufferY() : 0;
float dragBufX = go.state.isBeingDragged ? T->getHoverCollisionBufferX() : 0;
float dragBufY = go.state.isBeingDragged ? T->getHoverCollisionBufferY() : 0;
bufX = std::max(hoverBufX, dragBufX);
bufY = std::max(hoverBufY, dragBufY);
```

### Step 4.3: Build and test

Run:
```bash
just build-debug
```

Expected: Build succeeds.

### Step 4.4: Visual test drag behavior

Run:
```bash
./build/raylib-cpp-cmake-template
```

Test: Drag a card or UI element and verify collision detection is correct. The hitbox should not expand excessively when both hovering and dragging.

### Step 4.5: Commit

```bash
git add src/systems/collision/broad_phase.hpp
git commit -m "fix(collision): use max for hover/drag buffer, not sum

When both isBeingHovered and isBeingDragged are true, the collision
buffer was being doubled (additive). Now uses max() to prevent
collision box expansion beyond intended forgiveness radius.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 5: Complete Component Migration (Phase 2)

**Goal:** Finish migrating from monolithic UIConfig to split components, then deprecate legacy fields.

**Complexity:** HIGH - This is a multi-session task. Break into sub-phases.

**Files:**
- Modify: `src/systems/ui/element.cpp` (multiple locations)
- Modify: `src/systems/ui/box.cpp` (multiple locations)
- Modify: `src/systems/ui/ui.cpp` (bindings)
- Modify: `src/systems/ui/core/ui_components.hpp` (add missing extractions)
- Create: `tests/unit/test_ui_migration.cpp`

### Phase 2a: Audit Current Split Component Usage

**Step 5a.1:** Search for all UIConfig field accesses in rendering paths

Run:
```bash
grep -n "config->" src/systems/ui/element.cpp | head -100
```

Document which fields are accessed and map to split components:
- Style fields → UIStyleConfig
- Layout fields → UILayoutConfig
- Interaction fields → UIInteractionConfig
- Content fields → UIContentConfig

**Step 5a.2:** Verify extraction functions cover all fields

**File:** `src/systems/ui/core/ui_components.cpp`

Check that these functions exist and are complete:
- `extractStyle(const UIConfig&) -> UIStyleConfig`
- `extractLayout(const UIConfig&) -> UILayoutConfig`
- `extractInteraction(const UIConfig&) -> UIInteractionConfig`
- `extractContent(const UIConfig&) -> UIContentConfig`

### Phase 2b: Update Rendering to Use Split Components

**Step 5b.1:** Update DrawSelf to read from split components

In `element.cpp:DrawSelf()`, replace:
```cpp
const auto* config = registry.try_get<UIConfig>(entity);
if (!config) return;

// Access via config->field
auto color = config->color;
```

With:
```cpp
const auto* style = registry.try_get<UIStyleConfig>(entity);
const auto* layout = registry.try_get<UILayoutConfig>(entity);
// ... etc

// Access via split component
auto color = style ? style->color : std::nullopt;
```

**Step 5b.2:** Create compatibility shim (temporary)

Add helper to read from split component OR fall back to UIConfig:
```cpp
template<typename T>
T getStyleField(entt::registry& reg, entt::entity e,
                T UIStyleConfig::*field, T UIConfig::*fallback, T defaultVal) {
    if (auto* style = reg.try_get<UIStyleConfig>(e)) {
        return style->*field;
    }
    if (auto* config = reg.try_get<UIConfig>(e)) {
        auto val = config->*fallback;
        return val.value_or(defaultVal);
    }
    return defaultVal;
}
```

### Phase 2c: Update Handler System

**Step 5c.1:** Ensure handlers read from split components

**Files:** `src/systems/ui/handlers/rect_handler.cpp`, `text_handler.cpp`

Verify handlers use UIStyleConfig, not UIConfig:
```cpp
void RectHandler::draw(entt::registry& registry, entt::entity entity,
                       const UIStyleConfig& style,  // ← Use split component
                       const transform::Transform& transform,
                       const UIDrawContext& ctx) {
    // Use style.color, style.outlineColor, etc.
}
```

### Phase 2d: Deprecate Legacy UIConfig Access

**Step 5d.1:** Add deprecation warnings

In `ui_data.hpp`, add:
```cpp
struct [[deprecated("Use split components (UIStyleConfig, etc.) instead")]]
UIConfigLegacy { /* ... */ };

// Temporary alias during migration
using UIConfig = UIConfigLegacy;
```

**Step 5d.2:** Enable compiler warnings

```cpp
#pragma GCC diagnostic push
#pragma GCC diagnostic warning "-Wdeprecated-declarations"
// ... code using UIConfig
#pragma GCC diagnostic pop
```

### Phase 2e: Final Cleanup

**Step 5e.1:** Remove UIConfig from entity initialization (after all paths migrated)

**Step 5e.2:** Remove extraction functions (no longer needed)

**Step 5e.3:** Remove legacy DrawSelf overloads

**Step 5e.4:** Update all Sol2 bindings to expose split components

### Commit Strategy for Phase 2

Each sub-phase should be a separate commit:
```bash
git commit -m "refactor(ui): phase 2a - audit split component usage"
git commit -m "refactor(ui): phase 2b - update rendering to use split components"
git commit -m "refactor(ui): phase 2c - update handler system for split components"
git commit -m "refactor(ui): phase 2d - add deprecation warnings for UIConfig"
git commit -m "refactor(ui): phase 2e - remove legacy UIConfig (breaking)"
```

---

## Verification Checklist

After implementing all fixes, verify:

- [ ] Game builds without warnings: `just build-debug 2>&1 | grep -i warning`
- [ ] Game runs without crashes: `./build/raylib-cpp-cmake-template`
- [ ] UI renders correctly (no visual regressions)
- [ ] Drag-and-drop works with correct hitboxes
- [ ] No memory growth over time (create/destroy UI in loop)
- [ ] Unit tests pass: `just test`

---

## Risk Assessment

| Task | Risk | Mitigation |
|------|------|------------|
| Task 1 (Handlers) | Low | Handlers are tested; can revert flag |
| Task 2 (Cleanup) | Medium | Uses pcall; won't crash on errors |
| Task 3 (Nil Guard) | Low | Additive; doesn't change existing code |
| Task 4 (Buffer) | Low | Behavior change is more correct |
| Task 5 (Migration) | High | Multi-phase; extensive testing required |

---

## Dependencies

```
Task 1 (Handlers) ─────────────────────────────→ Task 5 (Migration)
                                                      ↑
Task 2 (Cleanup) ──────────────────────────────────────┘ (independent)

Task 3 (Nil Guard) ────────────────────────────────────→ (independent)

Task 4 (Buffer) ───────────────────────────────────────→ (independent)
```

Tasks 1-4 can be done in parallel. Task 5 depends on Task 1 (handlers must work before removing legacy paths).

---

## Estimated Effort

| Task | Effort | Sessions |
|------|--------|----------|
| Task 1 | 15 min | 1 |
| Task 2 | 30 min | 1 |
| Task 3 | 20 min | 1 |
| Task 4 | 10 min | 1 |
| Task 5 | 4-8 hours | 2-4 |

**Total:** ~5-10 hours depending on Task 5 complexity.
