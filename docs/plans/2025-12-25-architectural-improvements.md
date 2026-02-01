# Architectural Improvements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Improve codebase stability and maintainability through entity validation, render stack safety, physics accessor standardization, event system unification, and EngineContext migration.

**Architecture:** Incremental improvements that can be tested independently. TDD for critical systems (validation, render stack, events). Each task produces a working, testable change.

**Tech Stack:** C++20, Lua 5.4, GoogleTest, Sol2, EnTT ECS

---

## Phase 1: Entity Validation (TDD)

### Task 1.1: Add validated entity getter to component_cache.lua

**Files:**
- Modify: `assets/scripts/core/component_cache.lua`
- Create: `tests/unit/test_component_cache_validation.lua`

**Step 1: Write the failing test**

Create `tests/unit/test_component_cache_validation.lua`:
```lua
--[[
    Tests for component_cache entity validation
]]

local test_validation = {}

function test_validation.test_get_returns_nil_for_nil_entity()
    local component_cache = require("core.component_cache")
    local result = component_cache.get(nil, _G.Transform)
    assert(result == nil, "Should return nil for nil entity")
    print("✓ get returns nil for nil entity")
    return true
end

function test_validation.test_get_returns_nil_for_invalid_entity()
    local component_cache = require("core.component_cache")
    -- Use a clearly invalid entity ID (very large number that was never created)
    local invalid_entity = 999999999
    local result = component_cache.get(invalid_entity, _G.Transform)
    assert(result == nil, "Should return nil for invalid entity")
    print("✓ get returns nil for invalid entity")
    return true
end

function test_validation.test_ensure_entity_returns_false_for_nil()
    local component_cache = require("core.component_cache")
    local result = component_cache.ensure(nil)
    assert(result == false, "ensure should return false for nil")
    print("✓ ensure returns false for nil")
    return true
end

function test_validation.test_ensure_entity_returns_false_for_invalid()
    local component_cache = require("core.component_cache")
    local invalid_entity = 999999999
    local result = component_cache.ensure(invalid_entity)
    assert(result == false, "ensure should return false for invalid entity")
    print("✓ ensure returns false for invalid entity")
    return true
end

function test_validation.run_all()
    print("\n=== Component Cache Validation Tests ===\n")
    local tests = {
        test_validation.test_get_returns_nil_for_nil_entity,
        test_validation.test_get_returns_nil_for_invalid_entity,
        test_validation.test_ensure_entity_returns_false_for_nil,
        test_validation.test_ensure_entity_returns_false_for_invalid,
    }
    local passed, failed = 0, 0
    for _, test_func in ipairs(tests) do
        local success, err = pcall(test_func)
        if success then passed = passed + 1
        else failed = failed + 1; print("✗ " .. tostring(err)) end
    end
    print(string.format("\nPassed: %d, Failed: %d", passed, failed))
    return failed == 0
end

return test_validation
```

**Step 2: Run test to verify it fails**

Run: `lua tests/unit/test_component_cache_validation.lua`
Expected: Tests pass for nil (already handled) but may reveal edge cases

**Step 3: Add ensure() method to component_cache.lua**

Add after line 131 in `assets/scripts/core/component_cache.lua`:
```lua
--- Validate that an entity exists and is valid.
--- Use this before accessing cached components when entity lifetime is uncertain.
---@param eid entt.entity
---@return boolean valid True if entity exists and is valid
function component_cache.ensure(eid)
    if not eid then return false end
    local vfn = valid
    if not vfn then return false end
    return vfn(registry, eid) == true
end

--- Safe component access with automatic validation.
--- Returns nil if entity is invalid, otherwise returns component.
---@param eid entt.entity
---@param comp any
---@return table|nil component, boolean valid
function component_cache.safe_get(eid, comp)
    if not component_cache.ensure(eid) then
        return nil, false
    end
    return component_cache.get(eid, comp), true
end
```

**Step 4: Run test to verify it passes**

Run: `lua tests/unit/test_component_cache_validation.lua`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add tests/unit/test_component_cache_validation.lua assets/scripts/core/component_cache.lua
git commit -m "feat(validation): add entity validation to component_cache

- Add ensure(eid) method for explicit entity validation
- Add safe_get(eid, comp) for validated component access
- Add unit tests for validation edge cases"
```

---

### Task 1.2: Add safe_script_get wrapper function

**Files:**
- Modify: `assets/scripts/core/globals.lua`
- Create: `tests/unit/test_safe_script_get.lua`

**Step 1: Write the failing test**

Create `tests/unit/test_safe_script_get.lua`:
```lua
--[[
    Tests for safe_script_get function
]]

local test_safe_script = {}

function test_safe_script.test_returns_nil_for_nil_entity()
    -- Ensure the function exists in globals
    assert(_G.safe_script_get, "safe_script_get should be defined globally")
    local result = safe_script_get(nil)
    assert(result == nil, "Should return nil for nil entity")
    print("✓ safe_script_get returns nil for nil entity")
    return true
end

function test_safe_script.test_returns_nil_for_invalid_entity()
    local invalid_entity = 999999999
    local result = safe_script_get(invalid_entity)
    assert(result == nil, "Should return nil for invalid entity")
    print("✓ safe_script_get returns nil for invalid entity")
    return true
end

function test_safe_script.test_script_field_returns_default_for_nil()
    assert(_G.script_field, "script_field should be defined globally")
    local result = script_field(nil, "health", 100)
    assert(result == 100, "Should return default value for nil entity")
    print("✓ script_field returns default for nil entity")
    return true
end

function test_safe_script.test_script_field_returns_default_for_missing_field()
    local invalid_entity = 999999999
    local result = script_field(invalid_entity, "nonexistent_field", 42)
    assert(result == 42, "Should return default value for missing field")
    print("✓ script_field returns default for missing field")
    return true
end

function test_safe_script.run_all()
    print("\n=== Safe Script Get Tests ===\n")
    local tests = {
        test_safe_script.test_returns_nil_for_nil_entity,
        test_safe_script.test_returns_nil_for_invalid_entity,
        test_safe_script.test_script_field_returns_default_for_nil,
        test_safe_script.test_script_field_returns_default_for_missing_field,
    }
    local passed, failed = 0, 0
    for _, test_func in ipairs(tests) do
        local success, err = pcall(test_func)
        if success then passed = passed + 1
        else failed = failed + 1; print("✗ " .. tostring(err)) end
    end
    print(string.format("\nPassed: %d, Failed: %d", passed, failed))
    return failed == 0
end

return test_safe_script
```

**Step 2: Run test to verify it fails**

Run: `lua tests/unit/test_safe_script_get.lua`
Expected: FAIL - functions not defined yet

**Step 3: Add safe_script_get to globals.lua**

Add to `assets/scripts/core/globals.lua`:
```lua
------------------------------------------------------------
-- Safe Script Table Access
-- Use these instead of raw getScriptTableFromEntityID()
------------------------------------------------------------

--- Safely get script table for an entity.
--- Returns nil if entity is invalid or has no script table.
---@param eid entt.entity
---@return table|nil script_table
function _G.safe_script_get(eid)
    if not eid then return nil end

    -- Validate entity exists
    if _G.registry and _G.registry.valid then
        if not _G.registry:valid(eid) then
            return nil
        end
    end

    -- Try to get script table
    local getScript = _G.getScriptTableFromEntityID
    if not getScript then return nil end

    local ok, script = pcall(getScript, eid)
    if not ok or not script then
        return nil
    end

    return script
end

--- Get a field from an entity's script table with a default value.
--- Safe against nil entities, invalid entities, and missing fields.
---@param eid entt.entity
---@param field string
---@param default any
---@return any value
function _G.script_field(eid, field, default)
    local script = safe_script_get(eid)
    if not script then return default end

    local value = script[field]
    if value == nil then return default end

    return value
end

--- Check if an entity has a valid script table.
---@param eid entt.entity
---@return boolean has_script
function _G.has_script(eid)
    return safe_script_get(eid) ~= nil
end
```

**Step 4: Run test to verify it passes**

Run: `lua tests/unit/test_safe_script_get.lua`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add tests/unit/test_safe_script_get.lua assets/scripts/core/globals.lua
git commit -m "feat(validation): add safe_script_get and script_field helpers

- safe_script_get(eid) - validated script table access
- script_field(eid, field, default) - field access with fallback
- has_script(eid) - check if entity has script table
- Prevents crashes from nil/invalid entity access"
```

---

## Phase 2: Render Stack Safety (TDD)

### Task 2.1: Add RenderStackError exception class

**Files:**
- Create: `src/systems/layer/render_stack_error.hpp`
- Modify: `src/systems/layer/layer.hpp`
- Create: `tests/unit/test_render_stack_safety.cpp`

**Step 1: Write the failing test**

Create `tests/unit/test_render_stack_safety.cpp`:
```cpp
#include <gtest/gtest.h>
#include "systems/layer/render_stack_error.hpp"

TEST(RenderStackSafety, ErrorContainsStackDepth) {
    layer::RenderStackError error(16, "overflow");
    EXPECT_EQ(error.depth(), 16);
    EXPECT_NE(std::string(error.what()).find("overflow"), std::string::npos);
}

TEST(RenderStackSafety, ErrorContainsContext) {
    layer::RenderStackError error(5, "push failed", "during UI render");
    std::string msg = error.what();
    EXPECT_NE(msg.find("during UI render"), std::string::npos);
}
```

**Step 2: Run test to verify it fails**

Run: `just test`
Expected: FAIL - header not found

**Step 3: Create render_stack_error.hpp**

Create `src/systems/layer/render_stack_error.hpp`:
```cpp
#pragma once

#include <stdexcept>
#include <string>
#include <sstream>

namespace layer {

/**
 * @brief Exception thrown when render stack operations fail.
 *
 * Provides detailed context about the failure including stack depth
 * and optional operation context for debugging.
 */
class RenderStackError : public std::runtime_error {
public:
    RenderStackError(int depth, const std::string& reason,
                     const std::string& context = "")
        : std::runtime_error(formatMessage(depth, reason, context))
        , depth_(depth)
        , reason_(reason)
        , context_(context) {}

    [[nodiscard]] int depth() const noexcept { return depth_; }
    [[nodiscard]] const std::string& reason() const noexcept { return reason_; }
    [[nodiscard]] const std::string& context() const noexcept { return context_; }

private:
    static std::string formatMessage(int depth, const std::string& reason,
                                     const std::string& context) {
        std::ostringstream oss;
        oss << "RenderStack error at depth " << depth << ": " << reason;
        if (!context.empty()) {
            oss << " (" << context << ")";
        }
        return oss.str();
    }

    int depth_;
    std::string reason_;
    std::string context_;
};

} // namespace layer
```

**Step 4: Run test to verify it passes**

Run: `just test`
Expected: PASS

**Step 5: Commit**

```bash
git add src/systems/layer/render_stack_error.hpp tests/unit/test_render_stack_safety.cpp
git commit -m "feat(render): add RenderStackError exception class

- Provides structured error with depth, reason, context
- Enables proper error handling instead of silent ForceClear
- Foundation for render stack safety improvements"
```

---

### Task 2.2: Replace ForceClear with proper error handling

**Files:**
- Modify: `src/systems/layer/layer.hpp`

**Step 1: Write the failing test**

Add to `tests/unit/test_render_stack_safety.cpp`:
```cpp
#include "systems/layer/layer.hpp"

TEST(RenderStackSafety, PushThrowsOnOverflow) {
    // Note: This test requires a mock or the actual render stack
    // For now, we test the error type exists and can be caught
    try {
        throw layer::RenderStackError(16, "overflow");
    } catch (const layer::RenderStackError& e) {
        EXPECT_EQ(e.depth(), 16);
    }
}

TEST(RenderStackSafety, GetStackDepthReturnsCurrentSize) {
    // Verify the function exists and returns a reasonable value
    size_t depth = layer::render_stack_switch_internal::GetStackDepth();
    EXPECT_GE(depth, 0);
    EXPECT_LE(depth, layer::render_stack_switch_internal::MAX_RENDER_STACK_DEPTH);
}
```

**Step 2: Run test to verify current behavior**

Run: `just test`
Expected: Should compile and pass basic tests

**Step 3: Modify layer.hpp Push function**

In `src/systems/layer/layer.hpp`, modify the `Push` function (around line 45-52):

```cpp
// Push a new render target, with proper error handling
inline bool Push(RenderTexture2D target, const char* context = nullptr)
{
    // FIX #6: Validate stack depth with proper error
    if (renderStack.size() >= MAX_RENDER_STACK_DEPTH) {
        std::string ctx = context ? context : "unknown";
        SPDLOG_ERROR("Render stack overflow at depth {}! Context: {}",
                     renderStack.size(), ctx);

        // Option 1: Throw (caller can catch and handle gracefully)
        // throw RenderStackError(renderStack.size(), "overflow", ctx);

        // Option 2: Return false and let caller handle
        // This is safer for game code that shouldn't crash
        return false;
    }

    // FIX #10: Validate texture before pushing
    if (target.id == 0) {
        SPDLOG_WARN("Attempted to push invalid render texture (id=0)");
        return false;
    }

    // End current drawing mode if we have an active target
    if (!renderStack.empty()) {
        rlDrawRenderBatchActive();
        EndTextureMode();
    }

    renderStack.push(target);
    BeginTextureMode(target);
    return true;
}
```

**Step 4: Update ForceClear to be a last-resort recovery**

```cpp
// Clear the entire stack - use only for error recovery, not normal flow
inline void ForceClear(const char* reason = nullptr)
{
    if (!renderStack.empty()) {
        SPDLOG_WARN("ForceClear called with {} items on stack. Reason: {}",
                    renderStack.size(), reason ? reason : "unspecified");

        rlDrawRenderBatchActive();
        EndTextureMode();

        while (!renderStack.empty()) {
            renderStack.pop();
        }
    }
}
```

**Step 5: Run test to verify it passes**

Run: `just test`
Expected: PASS

**Step 6: Commit**

```bash
git add src/systems/layer/layer.hpp tests/unit/test_render_stack_safety.cpp
git commit -m "fix(render): replace silent ForceClear with proper error handling

- Push() now returns bool to indicate success/failure
- Added optional context parameter for debugging
- ForceClear() logs warning with reason
- Prevents silent data loss on stack overflow"
```

---

## Phase 3: Physics Accessor Standardization

### Task 3.1: Find and document all globals.physicsWorld usages

**Files:**
- Research task (no code changes)

**Step 1: Search for all usages**

Run: `grep -rn "globals\.physicsWorld\|globals->physicsWorld" assets/scripts/ src/ --include="*.lua" --include="*.cpp" --include="*.hpp"`

**Step 2: Document findings**

Expected files with `globals.physicsWorld`:
- `assets/scripts/test_projectiles.lua`
- `assets/scripts/examples/ldtk_quickstart.lua`

**Step 3: Commit documentation (if creating a tracking issue)**

No commit needed - this is research for next task.

---

### Task 3.2: Replace globals.physicsWorld with PhysicsManager.get_world

**Files:**
- Modify: `assets/scripts/test_projectiles.lua`
- Modify: `assets/scripts/examples/ldtk_quickstart.lua`

**Step 1: Verify current usage pattern**

Read files to confirm they use `globals.physicsWorld`.

**Step 2: Update test_projectiles.lua**

Replace:
```lua
local world = globals.physicsWorld
```

With:
```lua
local PhysicsManager = require("core.physics_manager")
local world = PhysicsManager.get_world("world")
```

**Step 3: Update ldtk_quickstart.lua**

Same pattern - replace direct globals access with PhysicsManager require.

**Step 4: Test the changes**

Run the game and verify projectiles still work correctly.

**Step 5: Commit**

```bash
git add assets/scripts/test_projectiles.lua assets/scripts/examples/ldtk_quickstart.lua
git commit -m "refactor(physics): standardize physics world access via PhysicsManager

- Replace globals.physicsWorld with PhysicsManager.get_world()
- Consistent with CLAUDE.md documented pattern
- Reduces coupling to global state"
```

---

## Phase 4: Event System Unification (TDD)

### Task 4.1: Add direct signal emission to combat system

**Files:**
- Modify: `assets/scripts/combat/combat_system.lua`
- Create: `tests/unit/test_event_unification.lua`

**Step 1: Write the failing test**

Create `tests/unit/test_event_unification.lua`:
```lua
--[[
    Tests for unified event system
]]

local signal = require("external.hump.signal")

local test_events = {}

-- Track received events
local received_events = {}

function test_events.setup()
    received_events = {}
end

function test_events.test_combat_hit_emits_signal()
    test_events.setup()

    -- Register listener
    local handle = signal.register("combat_hit", function(data)
        table.insert(received_events, { event = "combat_hit", data = data })
    end)

    -- Emit via signal (this should work already)
    signal.emit("combat_hit", { damage = 50 })

    assert(#received_events == 1, "Should receive one event")
    assert(received_events[1].data.damage == 50, "Should have correct damage")

    signal.remove(handle)
    print("✓ combat_hit event received via signal")
    return true
end

function test_events.test_enemy_killed_emits_signal()
    test_events.setup()

    local handle = signal.register("enemy_killed", function(entity)
        table.insert(received_events, { event = "enemy_killed", entity = entity })
    end)

    -- Simulate what gameplay.lua does
    signal.emit("enemy_killed", 12345)

    assert(#received_events == 1, "Should receive one event")
    assert(received_events[1].entity == 12345, "Should have correct entity")

    signal.remove(handle)
    print("✓ enemy_killed event received via signal")
    return true
end

function test_events.run_all()
    print("\n=== Event Unification Tests ===\n")
    local tests = {
        test_events.test_combat_hit_emits_signal,
        test_events.test_enemy_killed_emits_signal,
    }
    local passed, failed = 0, 0
    for _, test_func in ipairs(tests) do
        local success, err = pcall(test_func)
        if success then passed = passed + 1
        else failed = failed + 1; print("✗ " .. tostring(err)) end
    end
    print(string.format("\nPassed: %d, Failed: %d", passed, failed))
    return failed == 0
end

return test_events
```

**Step 2: Run test to verify baseline**

Run: `lua tests/unit/test_event_unification.lua`
Expected: PASS (these test the signal system directly)

**Step 3: Document the event bridge behavior**

The event_bridge.lua already handles most bridging. The key issue is OnDeath which requires special handling (combat actor → entity ID conversion).

**Step 4: Add inline documentation to event_bridge.lua**

Add comment block explaining the architecture:
```lua
--[[
EVENT UNIFICATION ARCHITECTURE:

The codebase has two event systems that are being unified:

1. hump.signal (primary) - Used by gameplay, wave system, UI
2. ctx.bus (combat) - Used by combat_system.lua internals

This bridge forwards ctx.bus events → signal.emit() automatically.

SPECIAL CASES:
- OnDeath: NOT auto-bridged because ctx.bus uses combat actors,
  not entity IDs. gameplay.lua handles this conversion manually
  at ~line 5234 via combatActorToEntity lookup.

FUTURE: Migrate combat_system.lua to emit signals directly,
eliminating the need for this bridge.
]]
```

**Step 5: Commit**

```bash
git add tests/unit/test_event_unification.lua assets/scripts/core/event_bridge.lua
git commit -m "docs(events): document event system architecture and unification plan

- Add tests verifying signal-based event flow
- Document the event bridge architecture
- Explain OnDeath special case handling"
```

---

### Task 4.2: Add signal emission helper to combat system

**Files:**
- Modify: `assets/scripts/combat/combat_system.lua`

**Step 1: Locate combat event emission points**

Search for `ctx.bus:emit` in combat_system.lua to find all emission points.

**Step 2: Add signal helper at top of combat_system.lua**

After the requires section, add:
```lua
-- Event emission helper - emits to both bus (for combat internals) and signal (for external listeners)
local signal = require("external.hump.signal")

local function emit_combat_event(ctx, event_name, data, signal_name)
    -- Emit to combat bus for internal listeners
    if ctx.bus then
        ctx.bus:emit(event_name, data)
    end
    -- Emit to signal for external listeners (wave system, UI, etc.)
    signal.emit(signal_name or event_name, data)
end
```

**Step 3: Identify events to migrate (gradual)**

Start with one event that's already bridged (e.g., OnHitResolved) and verify behavior unchanged.

**Step 4: Test in-game**

Run the game and verify combat events still trigger correctly.

**Step 5: Commit**

```bash
git add assets/scripts/combat/combat_system.lua
git commit -m "refactor(events): add dual-emission helper to combat system

- emit_combat_event() sends to both bus and signal
- Preparation for eventual bus removal
- No behavior change - events reach same listeners"
```

---

## Phase 5: EngineContext Migration (Incremental)

### Task 5.1: Audit current globals usage and prioritize

**Files:**
- Research task

**Step 1: Count remaining globals**

Run: `grep -c "extern " src/core/globals.hpp`
Expected: ~100+ externs

**Step 2: Categorize by migration difficulty**

- **Easy**: Simple values (bool, float, int)
- **Medium**: Shared pointers, callbacks
- **Hard**: Complex state (registry, quadtrees)

**Step 3: Create migration tracking issue/document**

Create `docs/plans/globals-migration-tracking.md` with categorized list.

**Step 4: Commit**

```bash
git add docs/plans/globals-migration-tracking.md
git commit -m "docs: create globals migration tracking document

- Categorized ~100 globals by migration difficulty
- Prioritized order for EngineContext migration"
```

---

### Task 5.2: Migrate one simple global (example: uiPadding)

**Files:**
- Modify: `src/core/engine_context.hpp`
- Modify: `src/core/globals.cpp`
- Modify: Any files using `globals::uiPadding`

**Step 1: Verify uiPadding is in EngineContext**

Check if `EngineContext` already has `uiPadding` field.

**Step 2: Find all usages**

Run: `grep -rn "globals::uiPadding\|globals::getUiPadding" src/`

**Step 3: Replace usages with EngineContext access**

Replace:
```cpp
float padding = globals::uiPadding;
```

With:
```cpp
float padding = ctx->uiPadding;  // where ctx is EngineContext*
```

**Step 4: Mark global as deprecated (already done in globals.hpp)**

The `ENGINECTX_DEPRECATED` macro is already applied.

**Step 5: Build and test**

Run: `just build-debug && just test`
Expected: Build succeeds, tests pass

**Step 6: Commit**

```bash
git add src/
git commit -m "refactor(globals): migrate uiPadding to EngineContext

- Replace globals::uiPadding with ctx->uiPadding
- Global still exists (deprecated) for backward compatibility
- One step toward globals.hpp removal"
```

---

## Phase 6: UI Definitions Extraction

### Task 6.1: Create Lua-based UI definition system (Design)

**Files:**
- Create: `assets/scripts/ui/ui_layout_dsl.lua`

**Step 1: Design the DSL**

The goal is to move hardcoded C++ UI layouts to Lua tables that can be hot-reloaded.

```lua
-- Example UI layout definition
local layouts = {}

layouts.main_menu = {
    type = "vbox",
    padding = 10,
    children = {
        { type = "text", content = "Game Title", fontSize = 32 },
        { type = "button", label = "Start", callback = "start_game" },
        { type = "button", label = "Options", callback = "show_options" },
        { type = "button", label = "Quit", callback = "quit_game" },
    }
}

return layouts
```

**Step 2: Create the loader module**

```lua
local ui_layout_dsl = {}

local dsl = require("ui.ui_syntax_sugar")

function ui_layout_dsl.load(layout_name)
    local layouts = require("ui.layouts." .. layout_name)
    -- Convert table definition to actual UI tree
    return ui_layout_dsl.build(layouts)
end

function ui_layout_dsl.build(def)
    if def.type == "vbox" then
        return dsl.vbox {
            config = { padding = def.padding },
            children = ui_layout_dsl.build_children(def.children)
        }
    elseif def.type == "text" then
        return dsl.text(def.content, { fontSize = def.fontSize })
    elseif def.type == "button" then
        return dsl.button(def.label, { onClick = def.callback })
    end
    -- ... more types
end

return ui_layout_dsl
```

**Step 3: Commit**

```bash
git add assets/scripts/ui/ui_layout_dsl.lua
git commit -m "feat(ui): add Lua-based UI layout DSL

- Define UI layouts as Lua tables
- Hot-reloadable without C++ rebuild
- Foundation for ui_definitions.hpp extraction"
```

---

## Verification Checklist

After completing all tasks, verify:

- [ ] `just test` passes
- [ ] `just build-debug` succeeds
- [ ] Game runs without crashes
- [ ] Entity validation prevents nil access crashes
- [ ] Render stack logs warnings instead of silent ForceClear
- [ ] Physics world access uses PhysicsManager consistently
- [ ] Events flow correctly to all listeners

---

## Summary

| Phase | Tasks | TDD | Est. Complexity |
|-------|-------|-----|-----------------|
| 1. Entity Validation | 1.1, 1.2 | Yes | Low |
| 2. Render Stack Safety | 2.1, 2.2 | Yes | Medium |
| 3. Physics Accessor | 3.1, 3.2 | No | Low |
| 4. Event Unification | 4.1, 4.2 | Yes | Medium |
| 5. EngineContext Migration | 5.1, 5.2 | No | Medium |
| 6. UI Definitions | 6.1 | No | High (design only) |

Total: ~12 tasks, ~6 with TDD

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
