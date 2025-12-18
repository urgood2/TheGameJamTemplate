# Lua Codebase Cleanup Plan

## Overview
Refactoring tasks identified from codebase audit:
- Timer leak fixes (memory safety)
- registry:get → component_cache.get migrations (performance + safety)
- _G export consolidation (maintainability)

## Task 1: Fix Timer Leaks in entity_factory.lua

**Goal:** Add cleanup for infinite timers that reference entities

**Problem:** 4 infinite timers (times=0) at lines 134, 303, 433, 599 run forever even after entities are destroyed.

**Solution:** Store timer tags in the colonist_ui table and add a cleanup function.

**Files to modify:**
- `assets/scripts/core/entity_factory.lua`

**Implementation:**
1. Add `timer_tag` field to `globals.ui.colonist_ui[colonist]` object when creating timer
2. Create `cleanupColonistUI(colonist)` function that:
   - Checks if `globals.ui.colonist_ui[colonist]` exists
   - Cancels timer using stored tag: `timer.cancel(tag)`
   - Cleans up UI elements
3. The timer tag is already being created (e.g., `"colonist_hp_text_update_" .. colonist`), just need to store it

**Test approach:**
- Write a test that verifies timer tags are stored
- Write a test that verifies cleanupColonistUI cancels timers
- Verify no runtime errors when calling cleanup

**Verification:**
- Run `just test` to ensure no regressions
- Manually verify timers are cancelled (check timer module if it has debug output)

---

## Task 2: Migrate registry:get in entity_factory.lua

**Goal:** Replace 56 `registry:get()` calls with `component_cache.get()`

**Files to modify:**
- `assets/scripts/core/entity_factory.lua`

**Implementation:**
1. Add `local component_cache = require("core.component_cache")` at top of file
2. Replace all `registry:get(entity, ComponentType)` with `component_cache.get(entity, ComponentType)`
3. Keep `registry:emplace()` calls unchanged (those are correct)
4. Keep `registry:valid()` calls unchanged (those are correct)

**Pattern:**
```lua
-- BEFORE:
local transformComp = registry:get(e, Transform)

-- AFTER:
local transformComp = component_cache.get(e, Transform)
```

**Test approach:**
- Run existing tests to verify no regressions
- The component_cache.get has the same return type, so it should be drop-in

**Verification:**
- `just build-debug` compiles successfully
- `just test` passes
- Game runs without errors

---

## Task 3: Migrate registry:get in ui_defs.lua

**Goal:** Replace 37 `registry:get()` calls with `component_cache.get()`

**Files to modify:**
- `assets/scripts/ui/ui_defs.lua`

**Implementation:**
1. Check if `component_cache` is already required, add if not
2. Replace all `registry:get(entity, ComponentType)` with `component_cache.get(entity, ComponentType)`

**Test approach:**
- Run existing tests
- UI should function identically

**Verification:**
- `just build-debug` compiles
- `just test` passes

---

## Task 4: Consolidate _G Exports in gameplay.lua

**Goal:** Move scattered `_G.` assignments to a single location at end of file

**Files to modify:**
- `assets/scripts/core/gameplay.lua`

**Current scattered exports (lines 495-499, 531, 604, 762, etc.):**
```lua
_G.makeSimpleTooltip = makeSimpleTooltip
_G.ensureSimpleTooltip = ensureSimpleTooltip
_G.showSimpleTooltipAbove = showSimpleTooltipAbove
_G.hideSimpleTooltip = hideSimpleTooltip
_G.destroyAllSimpleTooltips = destroyAllSimpleTooltips
_G.centerTooltipAboveEntity = centerTooltipAboveEntity
_G.isEnemyEntity = isEnemyEntity
```

**Implementation:**
1. Find all `_G.` assignments in gameplay.lua
2. Remove them from their current scattered locations
3. Add a consolidated block at the END of the file (before the particle test code):
```lua
-- ============================================================================
-- GLOBAL EXPORTS
-- ============================================================================
_G.makeSimpleTooltip = makeSimpleTooltip
_G.ensureSimpleTooltip = ensureSimpleTooltip
-- ... etc
```

**Test approach:**
- Run existing tests
- Functions should still be accessible globally

**Verification:**
- `just test` passes
- Game runs, tooltips work

---

## Task 5: Migrate registry:get in Remaining Files

**Goal:** Migrate remaining ~39 occurrences across other files

**Files to modify:**
- `assets/scripts/ai/actions/dig_for_gold.lua` (6)
- `assets/scripts/ai/actions/heal_other.lua` (3)
- `assets/scripts/ai/actions/use_duplicator.lua` (1)
- `assets/scripts/combat/combat_loop_integration.lua` (1)
- `assets/scripts/combat/enemy_spawner.lua` (2)
- `assets/scripts/combat/entity_cleanup.lua` (1)
- `assets/scripts/combat/loot_system.lua` (3)
- `assets/scripts/core/entity_builder.lua` (2)
- `assets/scripts/core/globals.lua` (2)
- `assets/scripts/core/shader_builder.lua` (2)
- `assets/scripts/core/gameplay.lua` (1)
- `assets/scripts/ui/cast_execution_graph_ui.lua` (2)
- `assets/scripts/ui/entity_inspector.lua` (1)
- `assets/scripts/ui/level_up_screen.lua` (1)
- `assets/scripts/ui/ui_syntax_sugar.lua` (4)

**Implementation:**
For each file:
1. Add `local component_cache = require("core.component_cache")` if not present
2. Replace `registry:get()` calls with `component_cache.get()`

**Skip these files (test mocks or special cases):**
- `chugget_code_definitions.lua` (type definitions, not real code)
- `tests/*.lua` (test mocks are fine)
- `examples/*.lua` (examples can stay as-is)

**Verification:**
- `just test` passes
- `just build-debug` compiles

---

## Success Criteria

1. ✅ No timer leaks in entity_factory.lua (cleanup function exists)
2. ✅ All registry:get calls migrated (except tests/examples/definitions)
3. ✅ _G exports consolidated in gameplay.lua
4. ✅ All tests pass
5. ✅ Game compiles and runs
