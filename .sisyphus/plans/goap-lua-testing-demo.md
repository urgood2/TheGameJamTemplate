# GOAP Lua Testing & Interactive ImGui Demo

## TL;DR

> **Quick Summary**: Comprehensively test all Lua GOAP bindings, add usability helper functions, and build an interactive ImGui debug window for real-time AI inspection and tuning.
> 
> **Deliverables**:
> - **In-game test suite** via Lua (requires C++ bindings, runs in game context)
> - 5 new utility functions (`dump_worldstate`, `dump_plan`, `get_all_atoms`, `has_plan`, `dump_blackboard`)
> - ImGui debug window (F9) with tabs for entity inspection, worldstate viewing, plan visualization
> 
> **Estimated Effort**: Medium (3-4 focused sessions)
> **Parallel Execution**: YES - 2 waves
> **Critical Path**: Task 2 (utility bindings) → Task 3 (tests verify bindings) → Task 4 (ImGui uses them)

---

## Context

### Original Request
"Thoroughly test all Lua GOAP methods, add improvements especially usage improvements. Make a demo with easily interactible ImGui that shows all features and allows for fine tuning."

### Interview Summary
**Key Discussions**:
- Identified all Lua GOAP bindings in `ai_system.cpp:bind_ai_utilities()`:
  - **11 `ai.*` methods**: `set_worldstate`, `get_worldstate`, `set_goal`, `patch_worldstate`, `patch_goal`, `get_blackboard`, `get_entity_ai_def`, `pause_ai_system`, `resume_ai_system`, `force_interrupt`, `list_lua_files`
  - **2 global functions** (NOT in `ai.*` table): `create_ai_entity`, `create_ai_entity_with_overrides`
- Documented Blackboard usertype with 14 methods: 5 setters (`set_bool/int/double/float/string`) + 5 getters + 4 utilities (`contains/clear/size/isEmpty`) - no key iteration available
- Found existing C++ tests in `test_goap_utils.cpp` (multiple tests covering GOAP utilities)
- Discovered comprehensive Lua test framework (`test_runner.lua`) with extensive existing tests
- Analyzed ImGui patterns from `shader_system.cpp` for tabbed interactive editor

**Research Findings**:
- GPGOAP uses bitfield worldstate (`MAXATOMS 64` defined in `include/GPGOAP/goap.h`, `bfield_t` is `int64_t`)
- Test infrastructure is mature with CI pipeline (Lua standalone + GoogleTest)
- ImGui patterns: TabBar, DragFloat, TreeNode, BeginChild established

### Metis Review
**Identified Gaps** (addressed):
- Scope locks needed for plan visualization (text only, no graphs)
- Demo is read-only inspection, no live AI mutation
- Max 4-5 new utility bindings to prevent creep
- Entity selection needs null checks for destroyed entities
- Test isolation requires clean state per test

---

## Work Objectives

### Core Objective
Create a comprehensive test suite for all GOAP Lua APIs, add developer-friendly utility functions, and build an interactive ImGui window for real-time AI debugging and inspection.

### Concrete Deliverables
1. `assets/scripts/tests/test_goap_api.lua` - Comprehensive test suite
2. `src/systems/ai/goap_debug_window.cpp/hpp` - ImGui debug window
3. Extended `bind_ai_utilities()` with 3-4 new helper functions
4. Documentation of new APIs in binding recorder

### Definition of Done
- [ ] All 11 `ai.*` methods + 2 global functions have at least one test passing
- [ ] Edge cases tested: nil inputs, invalid entity IDs, empty worldstates
- [ ] F9 toggles ImGui window visibility
- [ ] Window renders without crash when 0 GOAP entities exist
- [ ] `just test` passes (no regressions)
- [ ] **In-game GOAP tests pass** (tests run via game runtime, NOT standalone Lua)
  - Note: `run_standalone.lua` CANNOT test GOAP bindings because they require C++ engine context

### Must Have
- Test coverage for all `ai.*` methods
- Test coverage for Blackboard usertype
- ImGui window with entity list and worldstate inspection
- F9 hotkey toggle
- `ai.dump_worldstate(e)` utility function
- `ai.dump_plan(e)` utility function

### Must NOT Have (Guardrails)
- NO plan visualization as node graphs (text only)
- NO live AI state mutation through demo (read-only inspection)
  - **EXCEPTION**: "Force Replan" button is allowed - it calls existing `ai.force_interrupt()` which only triggers a replan, does not directly mutate worldstate/goal
- NO GPGOAP C library modifications
- NO async/threaded operations in ImGui rendering
- NO more than 5 new Lua bindings (current plan: 5 - `dump_worldstate`, `dump_plan`, `get_all_atoms`, `has_plan`, `dump_blackboard`)
- NO entity comparison/diff views
- NO AI replay/recording features

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES - `test_runner.lua` framework
- **User wants tests**: YES (TDD for new bindings, tests for existing)
- **Framework**: Lua `test_runner.lua` with `describe/it/expect`
  - Use `TestRunner.run_all()` (alias of `TestRunner.run()`) to execute tests; returns boolean (no os.exit by default)

### Lua Test Structure
Each binding test follows:
```lua
local t = require("tests.test_runner")

t.describe("ai.function_name", function()
    t.it("should do expected behavior", function()
        -- Arrange: Use existing entity type "kobold" for deterministic testing
        -- See: assets/scripts/ai/entity_types/kobold.lua
        local entity = create_ai_entity("kobold")
        -- Act
        local result = ai.function_name(entity, args)
        -- Assert
        t.expect(result).to_be(expected)
    end)
end)
```

**Test Fixture Entity Types** (use existing types for tests):
- `"kobold"` - Simple AI entity with basic worldstate atoms (`assets/scripts/ai/entity_types/kobold.lua`)
- `"gold_digger"` - Entity focused on resource gathering (`assets/scripts/ai/entity_types/gold_digger.lua`)
- `"healer"` - Entity with healing-related atoms (`assets/scripts/ai/entity_types/healer.lua`)
- Recommendation: Use `"kobold"` as the primary test fixture for most tests

### Manual Verification
- ImGui window tested via game runtime
- F9 toggle verified interactively
- Entity selection and tab switching tested manually

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately):
├── Task 1: Validate assumptions (F9 free, entity iteration)
└── Task 2: Implement utility bindings (dump_worldstate, dump_plan, get_all_atoms)

Wave 2 (After Wave 1):
├── Task 3: Create comprehensive Lua test suite
└── Task 4: Build ImGui debug window structure

Wave 3 (After Wave 2):
├── Task 5: Implement ImGui tab content (WorldState, Plan, Blackboard)
└── Task 6: Integration testing and polish
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 2, 4 | 2 |
| 2 | None | 3, 5 | 1 |
| 3 | 2 | 6 | 4 |
| 4 | 1 | 5, 6 | 3 |
| 5 | 2, 4 | 6 | None |
| 6 | 3, 5 | None | None |

### Agent Dispatch Summary

| Wave | Tasks | Recommended Agents |
|------|-------|-------------------|
| 1 | 1, 2 | `category="quick"` for validation; `category="unspecified-low"` for bindings |
| 2 | 3, 4 | `category="unspecified-high"` for test suite; `category="visual-engineering"` for ImGui |
| 3 | 5, 6 | Sequential execution after Wave 2 |

---

## TODOs

- [x] 1. Validate Assumptions and Environment

  **What to do**:
  - Check if F9 key is available (not bound to other functions)
  - Verify entity iteration capability exists in Lua or expose one
  - Confirm `ImGui::BeginTabBar` is available in project's ImGui version
  - Check if atom name registry is accessible at runtime

  **Must NOT do**:
  - Do not add new hotkeys yet
  - Do not modify existing bindings

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple verification tasks, no code writing
  - **Skills**: `["codebase-teacher"]`
    - `codebase-teacher`: Navigate existing code to find bindings and patterns

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 2)
  - **Blocks**: Tasks 2, 4
  - **Blocked By**: None

  **References**:
  - `src/systems/input/input_keyboard.cpp` - Check existing keyboard key bindings
  - `src/main.cpp:269-333` - Existing F3, F7, F8, F10 handling pattern (F9 is NOT used here)
  - `src/third_party/rlImGui/imgui.h` - Verify TabBar availability
  - `src/systems/ai/ai_system.cpp:goap_worldstate_to_map()` - Atom name access pattern

  **Acceptance Criteria**:
  - [x] Documented whether F9 is free (grep for KEY_F9, IsKeyPressed.*9)
  - [x] Identified how to iterate GOAP entities (view pattern from registry)
  - [x] Confirmed TabBar is available in ImGui version
  - [x] Found how to access atom names from actionplanner_t

  **Commit**: NO (research only)

---

- [x] 2. Implement Utility Bindings

  **What to do**:
  - Add `ai.dump_worldstate(entity)` → returns table of `{atom_name = bool_value}`
    - **Output ordering**: Unordered (Lua table with string keys, iteration order undefined)
    - Only includes atoms where dontcare is NOT set
  - Add `ai.dump_plan(entity)` → returns array-table of action names
    - **Output ordering**: 1-based Lua array in execution order `{[1]="action1", [2]="action2", ...}`
    - Length = `planSize` (only valid plan steps, not full 64-element array)
  - Add `ai.get_all_atoms(entity)` → returns array-table of all registered atom names
    - **Output ordering**: 1-based Lua array in planner registration order (i=0..ap.numatoms-1 → Lua [1]..[n])
  - Add `ai.has_plan(entity)` → returns bool if entity has valid plan
    - **Definition of "has valid plan"**: `planSize > 0 && dirty == false`
    - Based on `GOAPComponent` fields at `src/components/components.hpp:88-93`
    - `planSize > 0` means there are actions in the plan array
    - `dirty == false` means the plan has been computed and is current
  - Add `ai.dump_blackboard(entity)` → returns table of all blackboard entries
    - **IMPORTANT**: Blackboard uses `std::unordered_map<std::string, std::any>` with NO iterator exposed
    - Must add `getKeys()` or similar method to `src/systems/ai/blackboard.hpp` first
    - Then iterate keys in binding to build Lua table with type-aware value extraction
    - **Supported types** (from `ai_system.cpp:1055-1064`): `bool`, `int`, `double`, `float`, `string`
    - **Type detection strategy**: For each key returned by `getKeys()`:
      - Try `std::any_cast<bool>` → if succeeds, type="bool"
      - Try `std::any_cast<int>` → if succeeds, type="int"
      - Try `std::any_cast<double>` → if succeeds, type="double"
      - Try `std::any_cast<float>` → if succeeds, type="float"
      - Try `std::any_cast<std::string>` → if succeeds, type="string"
      - If all fail (`std::bad_any_cast`), type="unknown", value="<unsupported>"
    - **Output format**: `{ key1 = {type="bool", value=true}, key2 = {type="int", value=42}, ... }`
  - Register all bindings in BindingRecorder for documentation

  **Must NOT do**:
  - Do not modify existing binding signatures
  - Do not add more than 5 new functions (now at limit: dump_worldstate, dump_plan, get_all_atoms, has_plan, dump_blackboard)
  - Do not add functions that mutate AI state

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: Straightforward C++ binding additions following existing patterns
  - **Skills**: `["codebase-teacher"]`
    - `codebase-teacher`: Reference existing ai.* bindings for pattern

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 1)
  - **Blocks**: Tasks 3, 5
  - **Blocked By**: None

  **References**:
  - `src/systems/ai/ai_system.cpp:956-1207` - Existing bind_ai_utilities() function
  - `src/systems/ai/ai_system.cpp:1375-1397` - goap_worldstate_to_map() implementation to reuse
  - `src/systems/scripting/binding_recorder.hpp` - BindingRecorder pattern
  - `src/components/components.hpp:GOAPComponent` - Component structure for plan access

  **Acceptance Criteria**:
  - [x] `ai.dump_worldstate(entity)` returns Lua table with atom names as keys
  - [x] `ai.dump_plan(entity)` returns array-like table `{[1]="action1", [2]="action2"}`
  - [x] `ai.get_all_atoms(entity)` returns all atom names registered in planner
  - [x] `ai.has_plan(entity)` returns boolean
  - [x] `ai.dump_blackboard(entity)` returns table `{key1={type="bool", value=true}, ...}`
    - Requires adding `getKeys()` to Blackboard class first
  - [x] All NEW functions handle **invalid (non-nil) entity** gracefully: validate entity and return `nil` (don't throw)
    - Note: **nil entity** will still cause Sol2 argument type error (since we take `entt::entity`, not `sol::optional<entt::entity>`)
    - This is consistent with existing bindings behavior
  - [x] All functions registered with BindingRecorder
  - [x] Project compiles without errors

  **Commit**: YES
  - Message: `feat(ai): add utility bindings for GOAP debugging`
  - Files: `src/systems/ai/ai_system.cpp`, `src/systems/ai/blackboard.hpp` (add getKeys())
  - Pre-commit: `cmake --build build -j`

---

- [x] 3. Create Comprehensive Lua Test Suite (IN-GAME)

  **What to do**:
  - Create `assets/scripts/tests/test_goap_api.lua` - test file using test_runner.lua framework
  - Test all 11 `ai.*` methods with happy path and edge cases
  - Test both global functions: `create_ai_entity(type)`, `create_ai_entity_with_overrides(type, overrides)`
  - Test all new utility bindings from Task 2
  - Test Blackboard usertype methods
  - Create **in-game test harness** that runs when game loads (NOT standalone):
    - Add to game's init or create a debug menu option to run GOAP tests
    - Tests require C++ bindings that are ONLY available in-game context
  - **DO NOT add to `run_standalone.lua`** - standalone Lua cannot access C++ bindings

  **Must NOT do**:
  - Do not attempt standalone test execution (C++ bindings unavailable)
  - Do not test internal C++ functions
  - Do not test GPGOAP C library directly

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Comprehensive test coverage requires careful design
  - **Skills**: `["codebase-teacher"]`
    - `codebase-teacher`: Reference existing test patterns in test_runner.lua

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Task 4)
  - **Blocks**: Task 6
  - **Blocked By**: Task 2 (needs utility bindings)

  **References**:
  - `assets/scripts/tests/test_runner.lua` - BDD test framework API
  - `assets/scripts/tests/test_expect_matchers.lua` - Fluent matcher examples
  - `assets/scripts/core/main.lua:1013` - Existing in-game test harness pattern (`RUN_UI_VALIDATOR_TESTS` env var check)
  - `assets/scripts/tests/run_ui_validator_tests.lua` - Reference in-game test runner module pattern
  - `tests/unit/test_goap_utils.cpp` - Reference for what edge cases C++ tests cover
  - **NOTE**: Do NOT reference `run_standalone.lua` - GOAP tests require C++ bindings unavailable in standalone mode

  **Acceptance Criteria**:
  - [ ] Test file created at `assets/scripts/tests/test_goap_api.lua`
  - [ ] All 11 `ai.*` methods tested with happy path assertions:
    - `set_worldstate(e, "atom", true)` → no error, subsequent `get_worldstate(e, "atom")` returns `true`
    - `get_worldstate(e, "atom")` → returns `true`, `false`, or `nil` (for unset)
    - `set_goal(e, {atom=true})` → no error (no getter exists for goal; test verifies no exception only)
    - `patch_worldstate(e, "atom", false)` → no error, verify via `get_worldstate(e, "atom")` returns `false`
    - `patch_goal(e, {atom=false})` → no error (no getter exists for goal; test verifies no exception only)
    - `get_blackboard(e)` → returns Blackboard userdata (not nil) for valid GOAP entity
    - `get_entity_ai_def(e)` → returns Lua table (the `def` field from GOAPComponent), assert `type(result) == "table"`
    - `pause_ai_system()` → no error (C++ `ai_system_paused=true`; no Lua getter exists, test verifies no exception only)
    - `resume_ai_system()` → no error (C++ `ai_system_paused=false`; no Lua getter exists, test verifies no exception only)
    - `force_interrupt(e)` → no error; call succeeds without throwing (NOTE: `on_interrupt()` calls `select_goal()` → `replan()`, so `has_plan(e)` may still be `true` after; verify only no-exception behavior)
    
    **Note on limited observability**: `set_goal`, `patch_goal`, `pause_ai_system`, `resume_ai_system` have no direct Lua getters to verify state change. Tests confirm no-exception behavior only. Adding observability would exceed the 5-binding limit.
    - `list_lua_files("ai.entity_types")` → returns array containing at least `"kobold"`, `"gold_digger"`, etc.
  - [ ] Both global functions tested: `create_ai_entity(type)`, `create_ai_entity_with_overrides(type, overrides)`
  - [ ] **Test isolation/cleanup strategy**:
    - Each test creates entities via `create_ai_entity("kobold")` and MUST destroy them after
    - Use `registry:destroy(entity)` to clean up
    - Access registry via `registry` global variable (bound in `src/systems/scripting/scripting_system.cpp` as `lua["registry"] = std::ref(registry);`)
    - Test structure: `local e = create_ai_entity("kobold"); -- test code --; registry:destroy(e)`
    - NOTE: This is only available in-engine context, not standalone Lua
  - [ ] New bindings tested: `dump_worldstate`, `dump_plan`, `get_all_atoms`, `has_plan`, `dump_blackboard`
  - [ ] Blackboard methods tested: `set_bool/get_bool`, `set_int/get_int`, `contains`, `clear`, `size`, `isEmpty`
  - [ ] Edge cases tested with expected behaviors:
    
    **nil entity handling** (Sol2 receives `entt::entity` directly - nil causes type error):
    - All existing `ai.*` functions and globals: `pcall()` returns `false` (Sol2 argument type error)
    - NEW utilities should follow same pattern for consistency: `pcall()` returns `false` on nil
    - Tests should use `pcall(ai.func, nil)` and assert `ok == false`
    
    **Invalid but non-nil entity ID** (entity doesn't exist or lacks GOAPComponent):
    - `ai.get_blackboard()`: Returns `nil` (already validates, see `ai_system.cpp:1075`)
    - Other existing `ai.*` funcs: `pcall()` returns `false` (entt throws on `.get<GOAPComponent>()`)
    - NEW utilities SHOULD validate and return `nil` on invalid entity (don't throw)
    
    **Other edge cases**:
    - **Invalid blackboard key**: `blackboard:get_*()` throws Lua error (C++ `std::runtime_error`)
    - **Empty worldstate**: `ai.dump_worldstate()` returns empty table `{}`
    - **Empty plan**: `ai.dump_plan()` returns empty table `{}`, `ai.has_plan()` returns `false`
  - [ ] **In-game test harness created** following existing pattern in `assets/scripts/core/main.lua:1013`:
    - Add `RUN_GOAP_TESTS` env var check inside `main.init()` (alongside existing `RUN_UI_VALIDATOR_TESTS`)
    - Trigger via: `RUN_GOAP_TESTS=1 ./build/raylib-cpp-cmake-template`
    - See `assets/scripts/tests/run_ui_validator_tests.lua` for reference runner pattern
    - **PRECONDITION**: GOAP tests depend on `ai_system::init()` having run first
      - C++ init order: `src/core/init.cpp:914` calls `ai_system::init()` which sets up `masterStateLua["ai"]`
      - Lua `main.init()` runs AFTER all C++ init completes (Lua scripts loaded after engine init)
      - Therefore: GOAP bindings ARE available when `main.init()` env-var check runs
    - **Pass/fail behavior** (differs from `run_ui_validator_tests.lua` which only returns boolean):
      - On SUCCESS: Log `[GOAP TESTS] ALL PASSED (N tests)` to console, then call `os.exit(0)` to signal CI success
      - On FAILURE: Log `[GOAP TESTS] FAILED: N/M tests passed` with failure details, then call `os.exit(1)` to signal CI failure
      - NOTE: Unlike `run_ui_validator_tests.lua`, GOAP tests WILL exit the process for CI automation
  - [ ] Tests pass when run in-game (verify via console output showing "ALL PASSED")

  **Commit**: YES
  - Message: `test(ai): add comprehensive in-game Lua tests for GOAP API`
  - Files: `assets/scripts/tests/test_goap_api.lua`, `assets/scripts/core/main.lua` (add test harness trigger following existing `RUN_UI_VALIDATOR_TESTS` pattern at line 1013)
  - Pre-commit: `cmake --build build -j` (tests run in-game, not standalone)

---

- [x] 4. Build ImGui Debug Window Structure

  **What to do**:
  - Create `src/systems/ai/goap_debug_window.hpp/cpp`
  - **CMake integration**: Project uses `file(GLOB_RECURSE ... CONFIGURE_DEPENDS)` at `CMakeLists.txt:844` which auto-discovers new `.cpp` files in `src/systems/ai/`. Files are auto-detected on `cmake --build build` thanks to `CONFIGURE_DEPENDS`. No manual CMakeLists.txt edits required.
  - Implement basic window with F9 toggle
  - Add TabBar with tabs: "Entities", "WorldState", "Plan", "Blackboard"
  - Implement entity list in Entities tab with selection
  - Wire window into main.cpp render loop (after rlImGuiBegin)

  **Must NOT do**:
  - Do not implement tab content beyond placeholders yet (Task 5)
  - Do not add live AI mutation controls
  - Do not add plan visualization graphs

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: ImGui UI development with layout and interaction patterns
  - **Skills**: `["frontend-ui-ux"]`
    - `frontend-ui-ux`: UI layout and interaction design

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Task 3)
  - **Blocks**: Tasks 5, 6
  - **Blocked By**: Task 1 (validates F9 availability)

  **References**:
  - `src/systems/shaders/shader_system.cpp:918-998` - TabBar and interactive editor pattern
  - `src/util/perf_overlay.cpp:76-169` - Window setup and toggle pattern
  - `src/main.cpp:263-300` - rlImGuiBegin/End lifecycle and F-key handling
  - `src/core/globals.hpp` - getRegistry() for GOAP entity view

  **Acceptance Criteria**:
  - [ ] Files created: `src/systems/ai/goap_debug_window.hpp`, `src/systems/ai/goap_debug_window.cpp`
  - [ ] F9 toggles window visibility
  - [ ] Window has TabBar with 4 tabs
  - [ ] Entities tab lists all entities with GOAPComponent
  - [ ] Selecting an entity updates selected_entity state
  - [ ] Window handles 0 entities gracefully (shows "No GOAP entities")
  - [ ] Window compiles and renders in game
  - [ ] No frame rate drop when window is hidden

  **Commit**: YES
  - Message: `feat(ai): add GOAP debug window structure with F9 toggle`
  - Files: `src/systems/ai/goap_debug_window.hpp`, `src/systems/ai/goap_debug_window.cpp`, `src/main.cpp`
  - Pre-commit: `cmake --build build -j`

---

- [x] 5. Implement ImGui Tab Content

  **What to do**:
  
  **DATA ACCESS STRATEGY: C++ DIRECT (NOT Lua)**
  - The ImGui window is C++ code and should access GOAP data directly via ECS registry, NOT via Lua bindings
  - This avoids per-frame Lua calls, error handling complexity, and sol::state access issues
  - Use `globals::getRegistry().view<GOAPComponent>()` to iterate entities
  - Use `registry.get<GOAPComponent>(e)` to access component fields directly
  - For worldstate atoms: iterate `ap.atm_names[i]` for i=0..ap.numatoms-1 (like `goap_worldstate_to_map()` does)
  - For blackboard: requires adding C++ `getKeys()` method to Blackboard class (Task 2)
  
  - WorldState tab: Display all atoms with tri-state indicators (read-only visual, not editable)
    - **C++ implementation**: Iterate `ap.atm_names[]` array, check `dontcare` and `values` bits directly
      - Bit set in `values` AND NOT in `dontcare` → true (green ✓)
      - Bit NOT set in `values` AND NOT in `dontcare` → false (red X)
      - Bit set in `dontcare` → unset (gray "?")
  - Plan tab: Show current plan as numbered list with action names (costs NOT available per-step; only total plan cost exists)
    - **C++ implementation**: Read `goap.plan[]` array for i=0..planSize-1, display current_action highlighted
  - Blackboard tab: Show all blackboard entries with types and values
    - **C++ implementation**: Use new `blackboard.getKeys()` method, then type-check with `std::any_cast<T>`
  - Add current goal display with atom states (same bit-checking as worldstate)
  - Add "Force Replan" button - **C++ implementation**: Call `ai_system::on_interrupt(entity)` directly (same as `ai.force_interrupt` binding)
    - **LINKAGE REQUIREMENT**: `on_interrupt()` is defined in `ai_system.cpp` but NOT declared in `ai_system.hpp`
    - Task 5 must add declaration to `src/systems/ai/ai_system.hpp`: `void on_interrupt(entt::entity e);`
    - Then `goap_debug_window.cpp` can `#include "ai_system.hpp"` and call it
    - **NOTE**: This is the ONE exception to "read-only"; it triggers replanning but doesn't directly mutate worldstate/goal

  **Must NOT do**:
  - Do not allow editing worldstate through checkboxes (display only)
  - Do not allow editing goal atoms
  - Do not allow editing plan or actions
  - Do not show A* search internals

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: ImGui content rendering with data binding
  - **Skills**: `["frontend-ui-ux"]`
    - `frontend-ui-ux`: Data presentation and layout

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (after Wave 2)
  - **Blocks**: Task 6
  - **Blocked By**: Tasks 2, 4

  **References**:
  - `src/systems/ai/ai_system.cpp:1375-1397` - goap_worldstate_to_map() for atom iteration
  - `src/systems/ai/ai_system.cpp:1349-1369` - debugPrintGOAPStruct() for plan display pattern
  - `src/systems/shaders/shader_system.cpp:960-998` - Variant visitor for different value types
  - `src/components/components.hpp:GOAPComponent` - Access plan[], planSize, current_action

  **Acceptance Criteria**:
  - [ ] WorldState tab shows all atoms with tri-state indicators (true=✓/green, false=X/red, unset=?/gray)
  - [ ] Plan tab shows numbered action list with current action highlighted (action names only, no per-step costs)
  - [ ] Blackboard tab shows key-value pairs with type indicators
  - [ ] Goal display shows target atoms
  - [ ] "Force Replan" button triggers ai.force_interrupt on selected entity
  - [ ] All tabs update when different entity is selected
  - [ ] No crashes when entity has empty plan or blackboard

  **Commit**: YES
  - Message: `feat(ai): implement GOAP debug window tab content`
  - Files: `src/systems/ai/goap_debug_window.cpp`
  - Pre-commit: `cmake --build build -j`

---

- [x] 6. Integration Testing and Polish

  **What to do**:
  - Run full test suite and fix any failures
  - Test ImGui window with various entity states (no plan, long plan, mid-action)
  - Verify window handles entity destruction gracefully
  - Add documentation comments to new functions
  - Update CHANGELOG.md with new features

  **Must NOT do**:
  - Do not add new features
  - Do not refactor unrelated code

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: Testing and documentation cleanup
  - **Skills**: `["codebase-teacher"]`
    - `codebase-teacher`: Verify integration with existing systems

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (final)
  - **Blocks**: None (final task)
  - **Blocked By**: Tasks 3, 5

  **References**:
  - `CHANGELOG.md` - Add entry for new features
  - `docs/systems/ai-behavior/AI_README.md` - Update with debug window usage
  - NOTE: `run_standalone.lua` does NOT include GOAP tests (requires C++ engine)

  **Acceptance Criteria**:
  - [ ] `just test` passes (C++ tests)
  - [ ] `RUN_GOAP_TESTS=1 ./build/raylib-cpp-cmake-template` passes (in-game GOAP tests)
  - [ ] ImGui window tested with: 0 entities, 1 entity, 10 entities
  - [ ] Entity destruction while selected doesn't crash
  - [ ] CHANGELOG.md updated with new features
  - [ ] All new functions have documentation comments

  **Commit**: YES
  - Message: `docs(ai): document GOAP debug features and update changelog`
  - Files: `CHANGELOG.md`, `docs/systems/ai-behavior/AI_README.md`
  - Pre-commit: `just test`

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 2 | `feat(ai): add utility bindings for GOAP debugging` | ai_system.cpp, blackboard.hpp | `cmake --build build -j` |
| 3 | `test(ai): add comprehensive in-game Lua tests for GOAP API` | test_goap_api.lua, core/main.lua | `cmake --build build -j` (tests verified in-game via `RUN_GOAP_TESTS=1`) |
| 4 | `feat(ai): add GOAP debug window structure with F9 toggle` | goap_debug_window.*, main.cpp | `cmake --build build -j` |
| 5 | `feat(ai): implement GOAP debug window tab content` | goap_debug_window.cpp | `cmake --build build -j` |
| 6 | `docs(ai): document GOAP debug features and update changelog` | CHANGELOG.md, AI_README.md | `just test` |

---

## Success Criteria

### Verification Commands
```bash
# C++ unit tests
just test

# Build verification
cmake --build build -j

# Run in-game GOAP tests (env var trigger - canonical method)
RUN_GOAP_TESTS=1 ./build/raylib-cpp-cmake-template

# Or run game and test F9 window manually
./build/raylib-cpp-cmake-template
```

**NOTE**: GOAP Lua tests CANNOT run standalone - they require the C++ game engine context.
The `run_standalone.lua` test suite does NOT include GOAP tests for this reason.

### Final Checklist
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] All **in-game** Lua GOAP tests pass (run via `RUN_GOAP_TESTS=1 ./build/raylib-cpp-cmake-template`)
- [ ] All C++ tests pass (`just test`)
- [ ] ImGui window renders and toggles with F9
- [ ] Documentation updated
