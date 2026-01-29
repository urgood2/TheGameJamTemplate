# GOAP API Enhancements

## TL;DR

> **Quick Summary**: Enhance GOAP AI system with debugging visibility ("Why" reasoning), context helpers, and API ergonomics. Implements Phases 1.2, 1.3, 4.1-4.3 of existing GOAP_IMPROVEMENT_PLAN.md.
> 
> **Deliverables**:
> - "Why" tab in AI inspector showing action selection reasoning
> - Planning failure diagnostics with clear explanations
> - Graceful blackboard access (no crashes on missing keys)
> - Action Context object for cleaner action code
> - Behavior templates (instant, timed, moveTo)
> - Fluent Action Builder DSL
> 
> **Estimated Effort**: Large (3-5 days)
> **Parallel Execution**: YES - 3 waves
> **Critical Path**: Task 1 → Task 3 → Task 9 → Task 10

---

## Context

### Original Request
Comprehensive GOAP API enhancements for easier AI behavior design with debugging-first priority. All pain points addressed: API friction, debugging, expressiveness, Lua/C++ boundary. Backward compatible (additive only).

### Interview Summary
**Key Discussions**:
- Priority: Debugging-first (understand "why" AI makes decisions)
- Target users: Solo dev + designers/scripters
- Behavior types: Mixed (combat, NPCs, bosses, companions)
- Backward compatibility: Additive only, preserve existing APIs
- Blackboard: Must be error-free, graceful, frictionless
- Test strategy: TDD with existing Lua test suite

**Research Findings**:
- `core/goap_debug.lua` already exists with full API for competing actions, preconditions, costs
- `AITraceBuffer` exists in C++ (`goap_utils.hpp:59`)
- `ai_inspector.lua` has 4 tabs (State, Plan, Atoms, Trace) - add Tab 5 "Why"
- Blackboard throws `std::runtime_error` on missing key - needs `get_or` method
- Existing tests: `test_goap_api.lua` (663 lines), `test_goap_debug.lua` (494 lines)

### Metis Review
**Identified Gaps** (addressed):
- Plan relationship: Extending existing GOAP_IMPROVEMENT_PLAN.md (Phases 1.2, 1.3, 4.1-4.3)
- C++/Lua bridge for debug data: Wire planner to emit to goap_debug.lua
- Blackboard error handling: Add `get_or<T>()` without breaking existing API

---

## Work Objectives

### Core Objective
Enable AI developers to quickly understand "why" an AI made a decision and reduce boilerplate when writing actions.

### Concrete Deliverables
1. "Why" tab in `ai_inspector.lua` showing current action, preconditions, cost, alternatives
2. Planning failure diagnostics in inspector (not just "no plan")
3. `Blackboard::get_or<T>(key, default)` method in C++
4. `bb:get_or(key, default)` Lua binding
5. `ActionContext` object in `assets/scripts/ai/action_context.lua`
6. Behavior templates in `assets/scripts/ai/action_helpers.lua`
7. Fluent builder in `assets/scripts/ai/action_builder.lua`
8. Tests for all new functionality

### Definition of Done
- [ ] `just test` passes with new tests
- [ ] AI inspector shows "Why" tab with action reasoning
- [ ] Blackboard `get_or` returns default without throwing
- [ ] At least one existing action converted to use new helpers (demo)
- [ ] Documentation updated in GOAP_IMPROVEMENT_PLAN.md

### Must Have
- TDD: Tests written before implementation
- Backward compatibility: Existing `bb:get_int()` behavior unchanged
- Zero-cost debugging: No overhead when `goap_debug.is_enabled() == false`
- Inspector extension: Add to existing UI, don't replace

### Must NOT Have (Guardrails)
- **MUST NOT**: Modify goap_planner core A* algorithm
- **MUST NOT**: Change existing `Blackboard::get<T>()` throw behavior
- **MUST NOT**: Create more than 3 starter templates
- **MUST NOT**: Add goal-level debugging (action-level only for this work)
- **MUST NOT**: Rewrite ai_inspector.lua from scratch
- **MUST NOT**: Add performance optimizations (separate work)

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (Lua test suite + C++ GoogleTest)
- **User wants tests**: TDD
- **C++ test framework**: GoogleTest (`tests/unit/*.cpp`)
- **Lua test framework**: Custom runner (`assets/scripts/tests/test_runner.lua`)

### TDD Workflow
Each TODO follows RED-GREEN-REFACTOR:
1. **RED**: Write failing test first in appropriate test file
2. **GREEN**: Implement minimum code to pass
3. **REFACTOR**: Clean up while keeping tests green

### Verification Commands
```bash
# Run C++ unit tests (GoogleTest)
just test
# Equivalent: cmake -B build -DENABLE_UNIT_TESTS=ON && cmake --build build --target unit_tests && ./build/tests/unit_tests

# Run standalone Lua tests (no game required)
lua assets/scripts/tests/test_goap_debug.lua
lua assets/scripts/tests/test_goap_api.lua

# Build and run game (for in-game testing)
just build-debug && ./build/raylib-cpp-cmake-template
```

**Note**: Lua tests that require C++ bindings (like `test_goap_api.lua`) must run in-game, not standalone.

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately - Foundation):
├── Task 1: C++ planner emits debug data to goap_debug.lua
├── Task 2: Blackboard get_or method (C++)
└── Task 6: Action Context object (Lua-only)

Wave 2 (After Wave 1 - Inspector & Helpers):
├── Task 3: "Why" tab in ai_inspector.lua [depends: 1]
├── Task 4: Planning failure diagnostics [depends: 1]
├── Task 7: Behavior templates (Lua-only) [depends: 6]
└── Task 8: Fluent Action Builder (Lua-only) [depends: 6]

Wave 3 (After Wave 2 - Integration):
├── Task 5: Blackboard Lua bindings [depends: 2]
├── Task 9: Demo action conversion [depends: 7, 8]
└── Task 10: Documentation update [depends: all]

Critical Path: Task 1 → Task 3 → Task 9 → Task 10
Parallel Speedup: ~40% faster than sequential
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 3, 4 | 2, 6 |
| 2 | None | 5 | 1, 6 |
| 3 | 1 | 9 | 4, 7, 8 |
| 4 | 1 | 10 | 3, 7, 8 |
| 5 | 2 | 9 | 3, 4, 7, 8 |
| 6 | None | 7, 8 | 1, 2 |
| 7 | 6 | 9 | 3, 4, 5, 8 |
| 8 | 6 | 9 | 3, 4, 5, 7 |
| 9 | 3, 5, 7, 8 | 10 | None |
| 10 | All | None | None |

---

## TODOs

### Phase 1: Enhanced Debugging

- [ ] 1. Wire C++ planner to emit debug data to goap_debug.lua

  **What to do**:
  - Add C++ static bool `g_goap_debug_enabled` (default false) with Lua binding `ai.set_debug_enabled(bool)`
  - In `ai_system.cpp`, after planner selects action, call Lua `goap_debug.set_current_action(entity, action_name)`
  - Emit preconditions with met/unmet status via `goap_debug.set_action_preconditions()`
  - Emit cost breakdown via `goap_debug.set_action_cost()` - single component `{name="base_cost", value=action.cost}` since no breakdown exists
  - Emit **competing actions** = all actions whose preconditions are met in current worldstate but weren't chosen (higher cost or not in optimal path) via `goap_debug.add_competing_action()`
  - Guard all calls with `if (g_goap_debug_enabled)` check for zero-cost when disabled (cached bool, no Lua call)

  **Must NOT do**:
  - Modify goap_planner A* algorithm
  - Store debug data in C++ (only emit to Lua)

  **Recommended Agent Profile**:
  - **Category**: `ultrabrain`
    - Reason: C++/Lua boundary work requires careful understanding of Sol2 bindings
  - **Skills**: [`codebase-teacher`]
    - `codebase-teacher`: Understands existing Sol2 patterns in codebase

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 6)
  - **Blocks**: Tasks 3, 4
  - **Blocked By**: None

  **References**:
  - `src/systems/ai/ai_system.cpp:1570-1620` - Existing Sol2 bindings for AI, pattern for calling Lua
  - `src/systems/ai/goap_utils.hpp:173-290` - AITraceBuffer helper functions, similar emit pattern
  - `assets/scripts/core/goap_debug.lua:260-350` - Target Lua functions to call
  - `assets/scripts/tests/test_goap_debug.lua:357-486` - Test structure for action selection breakdown

  **Acceptance Criteria**:

  **TDD:**
  - [ ] Test file: `assets/scripts/tests/test_goap_debug.lua`
  - [ ] Add test: When entity executes action, `goap_debug.get_entity_debug_info(entity).current_action` equals action name
  - [ ] Add test: When entity executes action, `competing_actions` array has length > 0 (if alternatives exist)
  - [ ] `lua assets/scripts/tests/test_goap_debug.lua` → PASS

  **Automated Verification:**
  ```bash
  # Build and run game with test entity
  just build-debug && ./build/raylib-cpp-cmake-template
  
  # Verify goap_debug captures data (via in-game Lua console or test scene)
  # Test should: enable debug (ai.set_debug_enabled(true)), create entity, trigger planning, verify debug data populated
  ```

  **Commit**: YES
  - Message: `feat(ai): wire planner to emit debug data to goap_debug.lua`
  - Files: `src/systems/ai/ai_system.cpp`
  - Pre-commit: `just test`

---

- [ ] 2. Add Blackboard::get_or<T>() method in C++

  **What to do**:
  - Add `get_or<T>(const std::string& key, const T& default_value)` template method
  - Return `default_value` if key not found (no throw)
  - Keep existing `get<T>()` behavior unchanged (still throws)

  **Must NOT do**:
  - Change existing `get<T>()` behavior
  - Add runtime overhead to existing methods

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Small, focused C++ change with clear pattern
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 6)
  - **Blocks**: Task 5
  - **Blocked By**: None

  **References**:
  - `src/systems/ai/blackboard.hpp:18-24` - Existing `get<T>()` implementation to follow pattern
  - `assets/scripts/tests/test_goap_api.lua:454-526` - Blackboard test patterns

  **Acceptance Criteria**:

  **TDD:**
  - [ ] Test file: `tests/unit/test_blackboard.cpp` (extend existing)
  - [ ] Test: `bb.get_or<int>("missing", 42)` returns 42
  - [ ] Test: `bb.get_or<int>("existing", 42)` returns existing value
  - [ ] Test: `bb.get<int>("missing")` still throws (unchanged)
  - [ ] `just test` → PASS

  **Automated Verification:**
  ```bash
  just build-debug && just test
  # Verify tests/unit/test_blackboard.cpp passes
  ```

  **Commit**: YES
  - Message: `feat(ai): add Blackboard::get_or<T>() for graceful missing key handling`
  - Files: `src/systems/ai/blackboard.hpp`, `tests/unit/test_blackboard.cpp`
  - Pre-commit: `just test`

---

- [ ] 3. Add "Why" tab to ai_inspector.lua

  **What to do**:
  - Add Tab 5 "Why" to existing tab bar (after Trace)
  - Display: Current action name, cost breakdown, preconditions (met/unmet)
  - Display: Competing actions with why they lost (cost, failed preconditions)
  - Pull data from `goap_debug.get_entity_debug_info(entity)`
  - Color-code: Green for met preconditions, red for unmet

  **Must NOT do**:
  - Rewrite existing tabs
  - Add filtering/search (out of scope)
  - Add export functionality

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: ImGui UI work with visual feedback
  - **Skills**: [`codebase-teacher`]
    - `codebase-teacher`: Understands existing ai_inspector.lua patterns

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 7, 8)
  - **Blocks**: Task 9
  - **Blocked By**: Task 1

  **References**:
  - `assets/scripts/ui/ai_inspector.lua:276-343` - Existing Trace tab pattern to follow
  - `assets/scripts/ui/ai_inspector.lua:382-396` - Tab bar implementation
  - `assets/scripts/core/goap_debug.lua:64-99` - Data structures (GOAPEntityInfo, GOAPCompetingAction)
  - `assets/scripts/tests/test_goap_debug.lua:392-453` - Expected data format

  **Acceptance Criteria**:

  **TDD:**
  - [ ] Test: When "Why" tab selected, `AIInspector.current_tab == 5`
  - [ ] Test: "Why" tab renders without error when entity has debug data
  - [ ] Test: "Why" tab shows "No action selected" when no current action

  **Automated Verification:**
  ```bash
  # Build and run, open AI inspector
  just build-debug && ./build/raylib-cpp-cmake-template
  
  # Programmatic verification via Lua console:
  # local inspector = require("ui.ai_inspector")
  # inspector.open()
  # inspector.current_tab = 5
  # -- Should render "Why" tab without errors
  ```

  **Commit**: YES
  - Message: `feat(ai): add "Why" tab to AI inspector showing action selection reasoning`
  - Files: `assets/scripts/ui/ai_inspector.lua`
  - Pre-commit: `lua assets/scripts/tests/test_goap_debug.lua`

---

- [ ] 4. Add planning failure diagnostics to inspector

  **What to do**:
  - When `ai.has_plan(entity) == false`, show diagnostic panel
  - Display: "Planning failed" with reason (no valid actions, goal unreachable)
  - List actions that were considered but rejected
  - Pull from `goap_debug.get_entity_debug_info(entity).rejected_actions`

  **Must NOT do**:
  - Modify planner algorithm
  - Add auto-fix suggestions

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: ImGui UI work
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 3, 7, 8)
  - **Blocks**: Task 10
  - **Blocked By**: Task 1

  **References**:
  - `assets/scripts/ui/ai_inspector.lua:145-189` - Plan tab (enhance this)
  - `assets/scripts/core/goap_debug.lua:238-251` - `add_rejected_action` API

  **Acceptance Criteria**:

  **TDD:**
  - [ ] Test: When entity has no plan, inspector shows "Planning Failed" section
  - [ ] Test: Rejected actions list displays action name and reason

  **Automated Verification:**
  ```bash
  # Create entity with impossible goal, verify diagnostics appear
  just build-debug && ./build/raylib-cpp-cmake-template
  # Via Lua console: create entity, set impossible goal, check inspector
  ```

  **Commit**: YES
  - Message: `feat(ai): add planning failure diagnostics to AI inspector`
  - Files: `assets/scripts/ui/ai_inspector.lua`
  - Pre-commit: `lua assets/scripts/tests/test_goap_debug.lua`

---

### Phase 2: Context & Behavior Helpers

- [ ] 5. Add Blackboard Lua bindings for get_or

  **What to do**:
  - Add Sol2 binding for `get_or_bool`, `get_or_int`, `get_or_float`, `get_or_string`
  - Follow existing pattern from `get_bool`, `get_int`, etc.
  - Add tests to `test_goap_api.lua`

  **Must NOT do**:
  - Change existing binding signatures

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Small binding addition following existing pattern
  - **Skills**: [`codebase-teacher`]
    - `codebase-teacher`: Understands Sol2 binding patterns

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 3, 4, 7, 8)
  - **Blocks**: Task 9
  - **Blocked By**: Task 2

  **References**:
  - `src/systems/ai/ai_system.cpp:1579-1590` - Existing Blackboard bindings
  - `assets/scripts/tests/test_goap_api.lua:454-526` - Blackboard test patterns

  **Acceptance Criteria**:

  **TDD:**
  - [ ] Test file: `assets/scripts/tests/test_goap_api.lua`
  - [ ] Test: `bb:get_or_int("missing", 100)` returns 100
  - [ ] Test: `bb:get_or_bool("missing", true)` returns true
  - [ ] Test: `bb:get_or_string("missing", "default")` returns "default"
  - [ ] Test: `bb:get_or_int("existing", 100)` returns existing value
  - [ ] `just test` → PASS

  **Automated Verification:**
  ```bash
  just build-debug && just test
  # Lua tests requiring C++ bindings run in-game or via test scene
  ```

  **Commit**: YES
  - Message: `feat(ai): add Blackboard get_or Lua bindings for graceful access`
  - Files: `src/systems/ai/ai_system.cpp`, `assets/scripts/tests/test_goap_api.lua`
  - Pre-commit: `just test`

---

- [ ] 6. Create ActionContext object

  **What to do**:
  - Create `assets/scripts/ai/action_context.lua`
  - Provide `ActionContext.new(entity)` that pre-fetches:
    - `ctx.entity` - the entity
    - `ctx.blackboard` - `ai.get_blackboard(entity)`
    - `ctx.world_state` - helper to get/set worldstate
    - `ctx:get_target()` - method that returns `bb:get_int("target_entity")` if exists, else nil (uses `bb:contains()` check)
    - `ctx.dt` - delta time (set in update)
  - Actions can use `ctx` instead of manual fetching

  **Must NOT do**:
  - Force existing actions to use this (optional helper)
  - Cache stale data (refresh on access)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Pure Lua module, no C++ changes
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2)
  - **Blocks**: Tasks 7, 8
  - **Blocked By**: None

  **References**:
  - `assets/scripts/ai/actions/dig_for_gold.lua` - Example action using manual fetching
  - `assets/scripts/tests/test_goap_api.lua:173-183` - Blackboard access pattern

  **Acceptance Criteria**:

  **TDD:**
  - [ ] Test file: `assets/scripts/tests/test_action_context.lua` (new)
  - [ ] Test: `ActionContext.new(entity).entity == entity`
  - [ ] Test: `ActionContext.new(entity).blackboard` is truthy
  - [ ] Test: `ctx:get_target()` returns nil when no target set
  - [ ] Test: `ctx:get_target()` returns entity when target set
  - [ ] `lua assets/scripts/tests/test_action_context.lua` → PASS

  **Automated Verification:**
  ```bash
  lua assets/scripts/tests/test_action_context.lua
  ```

  **Commit**: YES
  - Message: `feat(ai): add ActionContext helper for cleaner action code`
  - Files: `assets/scripts/ai/action_context.lua`, `assets/scripts/tests/test_action_context.lua`
  - Pre-commit: `lua assets/scripts/tests/test_action_context.lua`

---

- [ ] 7. Create behavior templates in action_helpers.lua

  **What to do**:
  - Create `assets/scripts/ai/action_helpers.lua`
  - Implement 3 templates:
    - `helpers.instant(name, opts)` - Action that completes immediately
    - `helpers.timed(name, duration, opts)` - Action that runs for duration
    - `helpers.moveTo(name, target_key, opts)` - Action that moves toward target
  - Each returns a valid action table compatible with existing system
  - Document how to create custom templates

  **Must NOT do**:
  - Create more than 3 templates
  - Make templates required for actions

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Pure Lua module
  - **Skills**: [`codebase-teacher`]
    - `codebase-teacher`: Understands action definition patterns

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 3, 4, 5, 8)
  - **Blocks**: Task 9
  - **Blocked By**: Task 6

  **References**:
  - `assets/scripts/ai/actions/wander.lua` - Simple action example
  - `assets/scripts/ai/actions/dig_for_gold.lua` - Complex action with timers
  - `docs/systems/ai-behavior/GOAP_IMPROVEMENT_PLAN.md:185-188` - Planned helpers

  **Acceptance Criteria**:

  **TDD:**
  - [ ] Test file: `assets/scripts/tests/test_action_helpers.lua` (new)
  - [ ] Test: `helpers.instant("test", {pre={a=true}})` returns valid action table
  - [ ] Test: instant action `update()` returns `"success"` immediately
  - [ ] Test: `helpers.timed("test", 1.0, {})` action runs for ~1 second
  - [ ] Test: `helpers.moveTo("test", "target", {})` returns action with movement logic
  - [ ] `lua assets/scripts/tests/test_action_helpers.lua` → PASS

  **Automated Verification:**
  ```bash
  lua assets/scripts/tests/test_action_helpers.lua
  ```

  **Commit**: YES
  - Message: `feat(ai): add behavior templates (instant, timed, moveTo) in action_helpers.lua`
  - Files: `assets/scripts/ai/action_helpers.lua`, `assets/scripts/tests/test_action_helpers.lua`
  - Pre-commit: `lua assets/scripts/tests/test_action_helpers.lua`

---

### Phase 3: API Ergonomics

- [ ] 8. Create Fluent Action Builder DSL

  **What to do**:
  - Create `assets/scripts/ai/action_builder.lua`
  - Implement fluent API:
    ```lua
    local action = Action.new("attack_melee")
      :cost(1.5)
      :pre("has_weapon", true)
      :pre("target_in_range", true)
      :post("enemy_damaged", true)
      :watch("target_in_range")
      :on_start(function(ctx) ... end)
      :on_update(function(ctx, dt) ... end)
      :build()
    ```
  - `:build()` returns standard action table
  - Apply sensible defaults (cost=1, auto-watch preconditions if no explicit watch)

  **Must NOT do**:
  - Make builder required (existing table format still works)
  - Add validation beyond basic type checks

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Pure Lua DSL
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 3, 4, 5, 7)
  - **Blocks**: Task 9
  - **Blocked By**: Task 6

  **References**:
  - `assets/scripts/ai/actions/wander.lua` - Target output format
  - Research: CrashKonijn GOAP fluent builder pattern

  **Acceptance Criteria**:

  **TDD:**
  - [ ] Test file: `assets/scripts/tests/test_action_builder.lua` (new)
  - [ ] Test: `Action.new("test"):build()` returns table with `name="test"`
  - [ ] Test: `:cost(2.0)` sets `action.cost = 2.0`
  - [ ] Test: `:pre("a", true)` adds to `action.pre.a = true`
  - [ ] Test: Default cost is 1 when not specified
  - [ ] Test: Auto-watch preconditions when no explicit `:watch()`
  - [ ] `lua assets/scripts/tests/test_action_builder.lua` → PASS

  **Automated Verification:**
  ```bash
  lua assets/scripts/tests/test_action_builder.lua
  ```

  **Commit**: YES
  - Message: `feat(ai): add fluent Action Builder DSL for ergonomic action definition`
  - Files: `assets/scripts/ai/action_builder.lua`, `assets/scripts/tests/test_action_builder.lua`
  - Pre-commit: `lua assets/scripts/tests/test_action_builder.lua`

---

### Phase 4: Integration & Documentation

- [ ] 9. Convert one existing action to use new helpers (demo)

  **What to do**:
  - Choose `wander.lua` (simplest action)
  - Create `wander_v2.lua` using ActionContext and action_helpers
  - Keep original `wander.lua` unchanged (backward compat)
  - Add comment showing before/after comparison

  **Must NOT do**:
  - Modify original wander.lua
  - Convert all actions (just one demo)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Small Lua file creation
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (sequential)
  - **Blocks**: Task 10
  - **Blocked By**: Tasks 3, 5, 7, 8

  **References**:
  - `assets/scripts/ai/actions/wander.lua` - Original to convert
  - `assets/scripts/ai/action_helpers.lua` - Templates to use
  - `assets/scripts/ai/action_context.lua` - Context object to use

  **Acceptance Criteria**:

  **TDD:**
  - [ ] `wander_v2.lua` can be loaded without error
  - [ ] `wander_v2.lua` produces same behavior as original (manual verify)

  **Automated Verification:**
  ```bash
  # Verify wander_v2.lua loads
  lua -e "dofile('assets/scripts/ai/actions/wander_v2.lua')"
  ```

  **Commit**: YES
  - Message: `docs(ai): add wander_v2.lua demo showing new API helpers`
  - Files: `assets/scripts/ai/actions/wander_v2.lua`
  - Pre-commit: None

---

- [ ] 10. Update documentation

  **What to do**:
  - Update `GOAP_IMPROVEMENT_PLAN.md` to mark Phases 1.2, 1.3, 4.1-4.3 as implemented
  - Add usage examples for:
    - "Why" tab in inspector
    - ActionContext
    - action_helpers templates
    - Fluent builder
    - Graceful blackboard access
  - Update `docs/systems/ai-behavior/AI_README.md` with new APIs

  **Must NOT do**:
  - Create separate documentation files
  - Over-document (keep it concise)

  **Recommended Agent Profile**:
  - **Category**: `writing`
    - Reason: Documentation task
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (final)
  - **Blocks**: None
  - **Blocked By**: All other tasks

  **References**:
  - `docs/systems/ai-behavior/GOAP_IMPROVEMENT_PLAN.md` - Update this
  - `docs/systems/ai-behavior/AI_README.md` - Update this

  **Acceptance Criteria**:

  **Automated Verification:**
  ```bash
  # Verify markdown is valid
  cat docs/systems/ai-behavior/GOAP_IMPROVEMENT_PLAN.md | head -50
  ```

  **Commit**: YES
  - Message: `docs(ai): document GOAP API enhancements and mark plan phases complete`
  - Files: `docs/systems/ai-behavior/GOAP_IMPROVEMENT_PLAN.md`, `docs/systems/ai-behavior/AI_README.md`
  - Pre-commit: None

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(ai): wire planner to emit debug data` | ai_system.cpp | `just test` |
| 2 | `feat(ai): add Blackboard::get_or<T>()` | blackboard.hpp, test_blackboard.cpp | `just test` |
| 3 | `feat(ai): add "Why" tab to AI inspector` | ai_inspector.lua | lua test |
| 4 | `feat(ai): add planning failure diagnostics` | ai_inspector.lua | lua test |
| 5 | `feat(ai): add Blackboard get_or Lua bindings` | ai_system.cpp, test_goap_api.lua | `just test` |
| 6 | `feat(ai): add ActionContext helper` | action_context.lua, test | lua test |
| 7 | `feat(ai): add behavior templates` | action_helpers.lua, test | lua test |
| 8 | `feat(ai): add fluent Action Builder` | action_builder.lua, test | lua test |
| 9 | `docs(ai): add wander_v2.lua demo` | wander_v2.lua | manual |
| 10 | `docs(ai): document GOAP API enhancements` | *.md | none |

---

## Success Criteria

### Verification Commands
```bash
# All C++ tests pass
just test

# Standalone Lua tests (no C++ bindings required)
lua assets/scripts/tests/test_goap_debug.lua
lua assets/scripts/tests/test_action_context.lua
lua assets/scripts/tests/test_action_helpers.lua
lua assets/scripts/tests/test_action_builder.lua

# Lua tests requiring C++ bindings (run in-game)
just build-debug && ./build/raylib-cpp-cmake-template
# Then via Lua console: dofile("assets/scripts/tests/test_goap_api.lua")
```

### Final Checklist
- [ ] All "Must Have" features implemented
- [ ] All "Must NOT Have" guardrails respected
- [ ] All 10 tasks completed with commits
- [ ] TDD: All tests written before implementation, all passing
- [ ] Backward compatibility: Existing actions still work unchanged
- [ ] Documentation updated
