# UI Shader Pipeline Isolation Refactor

## Context

### Original Request
Fix brittleness when multiple shaders are applied to UI elements. Currently, having 2+ shader-enabled UI elements (e.g., cards with 3d_skew) causes elements to flip upside-down due to shared global state corruption.

### Interview Summary
**Key Discussions**:
- Use case: 1-5 UI elements, each with 1+ shader passes
- Symptom: Elements flip upside-down when multiple shader-UI elements render
- Solution: Per-element render textures for guaranteed isolation
- Extended scope: Also address ObjectAttachedToUITag + shader conflict
- Safety: Apply existing RAII guards to UI shader path

**Research Findings**:
- Root cause: Global `ping`/`pong`/`baseCache`/`postPassCache` in `shader_pipeline.hpp:112-124`
- UI slice path at `layer.cpp:2214-2427` (`renderSliceOffscreenFromDrawList`) uses global textures and calls `shader_pipeline::Swap()` at line 2351
- When multiple UI elements share globals, their `Swap()` calls corrupt each other's texture state
- RAII guards described in SAFETY_GUIDE but **NOT YET IMPLEMENTED in code** - must be created
- SAFETY_GUIDE Issue #7 documents this as "NOT FIXED YET"
- Note: SAFETY_GUIDE docs describe guards as if implemented, but they don't exist in code - treat docs as a specification, not current state

### Metis Review
**Identified Gaps** (addressed):
- Need concrete repro validation before implementing fix
- Memory budget calculation required (5 elements × 4 textures × ~1MB each = ~20MB)
- ObjectAttachedToUITag may be working as intended - needs investigation before code change
- Per-task guardrails added to prevent scope creep

---

## Work Objectives

### Core Objective
Isolate UI shader rendering so multiple shader-enabled UI elements can render correctly without visual corruption (upside-down flipping).

### Render Path Being Fixed
**Target**: `renderSliceOffscreenFromDrawList()` in `src/systems/layer/layer.cpp:2214-2427`

This is the UI slice rendering path that:
- Renders batches of UI elements with shaders
- Uses global `shader_pipeline::ping`/`pong` textures (problem: shared across elements)
- Calls `shader_pipeline::Swap()` at line 2351 (problem: corrupts state between elements)

**NOT being modified**: `DrawTransformEntityWithAnimationWithPipeline()` (world sprite path at ~line 1484)

### Concrete Deliverables
- `UIShaderRenderContext` component for per-element texture ownership
- Modified `renderSliceOffscreenFromDrawList()` to use per-element textures
- RAII guard integration in UI shader path
- C++ unit tests for multi-element scenarios
- Lua integration test for ShaderBuilder + multiple cards
- Documentation of ObjectAttachedToUITag behavior (code fix if needed)

### Definition of Done
- [ ] 5 UI elements with `ShaderPipelineComponent` + `3d_skew` render correctly (no flipping)
- [ ] `just test` passes with new tests included
- [ ] Memory usage documented (before/after)
- [ ] Single-entity shader rendering unchanged (regression verified)

### Must Have
- Per-element render texture isolation
- No visual corruption with 2-5 shader-enabled UI elements
- Existing single-entity pipeline behavior preserved
- RAII guards implemented and applied to UI shader path (new implementation required)

### Must NOT Have (Guardrails)
- DO NOT modify `DrawTransformEntityWithAnimationWithPipeline` behavior for world sprites
- DO NOT change global `inline` state in `shader_pipeline.hpp` (add new component, don't modify globals)
- DO NOT add render texture pooling (out of scope - only 1-5 elements)
- DO NOT optimize performance (fix corruption only)
- DO NOT resize pipeline textures mid-render
- PREFER references over copies for `RenderTexture2D` in new code (existing global accessor return types may remain as-is)

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (GoogleTest in `tests/`)
- **User wants tests**: TDD-style with both C++ and Lua tests
- **Framework**: GoogleTest for C++, Lua integration scripts

### If TDD Enabled

Each implementation TODO follows validation-first approach:

**Task Structure:**
1. **RED**: Write failing test that demonstrates the bug or expected behavior
2. **GREEN**: Implement minimum code to pass
3. **REFACTOR**: Clean up while keeping tests green

**Test Commands:**
- C++ tests: `just test` or `cd build && ctest --output-on-failure`
- Lua tests: Run game with test script loaded

---

## Task Flow

```
Task 0 (Validation) 
    ↓
Task 1 (Component) → Task 2 (UI Rendering) → Task 3 (RAII Guards)
                                                    ↓
                                              Task 4 (ObjectAttachedToUITag)
                                                    ↓
                                              Task 5 (Tests)
                                                    ↓
                                              Task 6 (Documentation)
```

## Parallelization

| Group | Tasks | Reason |
|-------|-------|--------|
| Sequential | 0 → 1 → 2 → 3 | Core implementation chain |
| After 3 | 4, 5 | Can start once rendering works |
| After 5 | 6 | Documentation after tests pass |

---

## TODOs

- [x] 0. Validate Bug Reproduction and Baseline

  **What to do**:
  - Create a minimal Lua test script that spawns 3 UI elements with `ShaderPipelineComponent` + `3d_skew` shader
  - Verify the upside-down flipping bug is reproducible
  - Document exact visual behavior (screenshot or description)
  - Run existing `test_shader_system.cpp` to establish baseline

  **Must NOT do**:
  - Make any code changes
  - Modify existing test files

  **Parallelizable**: NO (must complete first)

  **References**:
  - `assets/scripts/ui/player_inventory.lua` - Existing UI with shaders (pattern reference)
  - `src/systems/shaders/shader_pipeline.hpp:41-108` - ShaderPipelineComponent API
  - `tests/unit/test_shader_system.cpp` - Existing shader tests (baseline)
  - `docs/api/shader-builder.md` - ShaderBuilder Lua API

  **Acceptance Criteria**:
  - [ ] Bug reproduced and documented (description of visual artifact)
  - [ ] `just test` passes (baseline established)
  - [ ] Test script saved to `assets/scripts/tests/test_multi_shader_ui_repro.lua`

  **Commit**: YES
  - Message: `test(shader): add reproduction script for multi-shader UI bug`
  - Files: `assets/scripts/tests/test_multi_shader_ui_repro.lua`
  - Pre-commit: `just test`

---

- [x] 1. Create UIShaderRenderContext Component

  **What to do**:
  - Create new component `UIShaderRenderContext` in `src/systems/shaders/shader_pipeline.hpp`
  - Component owns: `RenderTexture2D ping`, `RenderTexture2D pong`, `RenderTexture2D baseCache`, `RenderTexture2D postPassCache`
  - Add lifecycle methods: `init(width, height)`, `resize(width, height)`, `unload()`
  - Add accessor methods: `front()`, `back()`, `swap()`
  - Track per-instance swap count for correct Y-flip logic
  - Register EnTT `on_destroy` hook to call `unload()` automatically when entity is destroyed
  - Expose to Lua via Sol2

  **swapCount Semantics** (CRITICAL):
  - `swapCount` is an `int` member, **reset to 0** at the start of each render pass for this element
  - Incremented by 1 each time `swap()` is called during that element's shader pass loop
  - Y-flip determination: `(swapCount % 2 == 0)` means no Y-flip needed; odd means Y-flip needed
  - This matches the current global logic but is isolated per-element
  - Note: disabled passes (where `pass.enabled == false`) do NOT call `swap()` and do NOT increment `swapCount`

  **Lifecycle/Ownership**:
  - `init(w, h)`: Called lazily when UI shader rendering first needs this context
  - `unload()`: Called automatically via EnTT `on_destroy<UIShaderRenderContext>` hook
  - Registration: In `game.cpp` or `init.cpp`, add: `registry.on_destroy<UIShaderRenderContext>().connect<&UIShaderRenderContext::unloadStatic>();`
  - `unloadStatic` is a static member that takes `(entt::registry&, entt::entity)` and calls `get<UIShaderRenderContext>(e).unload()`

  **Must NOT do**:
  - Modify existing global `ping`/`pong` variables
  - Change any rendering code yet
  - Add texture pooling

  **Parallelizable**: NO (depends on Task 0)

  **References**:
  - `src/systems/shaders/shader_pipeline.hpp:112-124` - Global state to replicate per-element
  - `src/systems/shaders/shader_pipeline.hpp:207-220` - `ShaderPipelineInit()` pattern to follow
  - `src/systems/shaders/shader_pipeline.hpp:259-261` - `Swap()` pattern
  - `src/systems/shaders/shader_pipeline.hpp:281-517` - Lua binding pattern to follow
  - `src/core/init.cpp` - Where EnTT on_destroy hooks are typically registered

  **Acceptance Criteria**:
  - [ ] `UIShaderRenderContext` struct defined with all 4 render textures
  - [ ] `init()`, `resize()`, `unload()` methods implemented
  - [ ] `front()`, `back()`, `swap()` accessors working
  - [ ] `swapCount` member (int) with `resetSwapCount()` method
  - [ ] EnTT `on_destroy` hook registered for automatic cleanup
  - [ ] Lua binding added: `shader_pipeline.UIShaderRenderContext`
  - [ ] Compiles without errors: `just build-debug`

  **Commit**: YES
  - Message: `feat(shader): add UIShaderRenderContext component for per-element isolation`
  - Files: `src/systems/shaders/shader_pipeline.hpp`, `src/core/init.cpp` (hook registration)
  - Pre-commit: `just build-debug`

---

- [x] 2. Modify UI Shader Rendering to Use Per-Element Textures

  **What to do**:
  - In `src/systems/layer/layer.cpp`, locate `renderSliceOffscreenFromDrawList()` (~line 2214)
  - For UI elements with `ShaderPipelineComponent`, check for `UIShaderRenderContext`
  - If `UIShaderRenderContext` exists, use its textures instead of globals
  - If not, lazily create and attach `UIShaderRenderContext` to the entity via `registry.emplace<UIShaderRenderContext>(entity)`
  - At start of element's shader pass loop, call `ctx.resetSwapCount()` to reset to 0
  - After each shader pass that calls `ctx.swap()`, the swapCount increments automatically
  - Use `(ctx.swapCount % 2 == 0)` for Y-flip determination instead of `pipelineComp.passes.size() % 2`
  - Ensure proper texture sizing based on element bounds (call `ctx.resize()` if needed)

  **Y-Flip Logic Change**:
  - BEFORE: `if (pipelineComp.passes.size() % 2 == 0)` - counts ALL passes including disabled
  - AFTER: `if (ctx.swapCount % 2 == 0)` - counts only ENABLED passes that actually swapped
  - This is more correct behavior and matches the actual texture state

  **Must NOT do**:
  - Change `DrawTransformEntityWithAnimationWithPipeline()` (world sprite path)
  - Remove or modify global `shader_pipeline::ping`/`pong` (still used elsewhere)
  - Add any optimization logic

  **Parallelizable**: NO (depends on Task 1)

  **References**:
  - `src/systems/layer/layer.cpp:2214-2427` - `renderSliceOffscreenFromDrawList()` to modify
  - `src/systems/layer/layer.cpp:1865-1870` - Y-flip logic pattern (to be changed from `passes.size()` to `swapCount`)
  - `src/systems/layer/layer.cpp:1773-1832` - Shader pass loop pattern to adapt
  - `src/systems/ui/box.cpp:2324-2368` - UI element shader detection

  **Acceptance Criteria**:
  - [ ] UI elements with shaders use per-element `UIShaderRenderContext`
  - [ ] `ctx.resetSwapCount()` called at start of each element's shader rendering
  - [ ] Y-flip logic uses `ctx.swapCount % 2` instead of `passes.size() % 2`
  - [ ] Global `shader_pipeline::front()`/`back()` NOT called for UI shader elements
  - [ ] Repro script from Task 0 shows correct rendering (no upside-down)
  - [ ] Single-element shader UI still works (regression check)

  **Commit**: YES
  - Message: `fix(layer): use per-element render textures for UI shader isolation`
  - Files: `src/systems/layer/layer.cpp`, `src/systems/ui/box.cpp` (if modified)
  - Pre-commit: `just build-debug && just test`

---

- [x] 3. Implement and Apply RAII Guards to UI Shader Path

  **What to do**:
  - **IMPLEMENT** the RAII guards described in SAFETY_GUIDE (they don't exist in code yet):
    - Create `RenderTargetGuard` class in `src/systems/shaders/shader_pipeline.hpp`
    - Create `MatrixStackGuard` class in `src/systems/shaders/shader_pipeline.hpp`
    - Create `SafeDrawTextureRec()` function with bounds validation
  - Apply these new guards to UI shader rendering path in `renderSliceOffscreenFromDrawList()`
  - Replace manual `render_stack_switch_internal::Push()`/`Pop()` with `RenderTargetGuard`
  - Replace manual `rlPushMatrix()`/`rlPopMatrix()` with `MatrixStackGuard`
  - Ensure guards scope correctly for early returns and exceptions

  **CRITICAL Design Decision: render_stack_switch_internal vs BeginTextureMode**:
  - The engine uses `layer::render_stack_switch_internal::Push()/Pop()` which wraps `BeginTextureMode`/`EndTextureMode` AND maintains a stack to restore the previous render target
  - The RAII guard MUST wrap `render_stack_switch_internal::Push()/Pop()`, NOT raw `BeginTextureMode`/`EndTextureMode`
  - This ensures proper restoration of render target state when guards go out of scope

  **RenderTargetGuard Implementation** (adapted for this engine):
  ```cpp
  class RenderTargetGuard {
      bool active = false;
  public:
      void push(RenderTexture2D& target) {
          if (active) return; // prevent double-push
          layer::render_stack_switch_internal::Push(target);
          active = true;
      }
      ~RenderTargetGuard() {
          if (active) layer::render_stack_switch_internal::Pop();
      }
  };
  ```

  **MatrixStackGuard Implementation**:
  ```cpp
  class MatrixStackGuard {
      bool pushed = false;
  public:
      bool push() {
          if (pushed) return false;
          rlPushMatrix();
          pushed = true;
          return true;
      }
      ~MatrixStackGuard() {
          if (pushed) rlPopMatrix();
      }
  };
  ```

  **Must NOT do**:
  - Apply guards to non-UI rendering paths (world sprite path unchanged)
  - Modify `render_stack_switch_internal` implementation itself
  - Use raw `BeginTextureMode`/`EndTextureMode` (use stack-aware version)

  **Parallelizable**: NO (depends on Task 2)

  **References**:
  - `docs/guides/implementation-summaries/SHADER_PIPELINE_SAFETY_GUIDE.md:14-72` - Guard design specification (treat as spec, not current impl)
  - `src/systems/layer/layer.cpp:2330` - Current `render_stack_switch_internal::Push()` in UI shader path
  - `src/systems/layer/layer.cpp:2350` - Current `render_stack_switch_internal::Pop()` in UI shader path
  - `src/systems/layer/layer.hpp` - `render_stack_switch_internal` namespace definition

  **Acceptance Criteria**:
  - [ ] `RenderTargetGuard` class implemented wrapping `render_stack_switch_internal::Push/Pop`
  - [ ] `MatrixStackGuard` class implemented wrapping `rlPushMatrix/rlPopMatrix`
  - [ ] `SafeDrawTextureRec()` function implemented with bounds validation
  - [ ] UI shader path (`renderSliceOffscreenFromDrawList`) uses these guards
  - [ ] No manual `render_stack_switch_internal::Push()/Pop()` in UI shader path
  - [ ] Tests still pass: `just test`

  **Commit**: YES
  - Message: `feat(shader): implement RAII guards and apply to UI shader path`
  - Files: `src/systems/shaders/shader_pipeline.hpp`, `src/systems/layer/layer.cpp`
  - Pre-commit: `just test`

---

- [x] 4. Investigate and Address ObjectAttachedToUITag Conflict

  **What to do**:
  - Research why `ObjectAttachedToUITag` breaks shader rendering
  - Test: Create UI element with BOTH `ObjectAttachedToUITag` AND `ShaderPipelineComponent`
  - Document findings:
    - If by design: Document in UI_PANEL_IMPLEMENTATION_GUIDE.md why they're mutually exclusive
    - If fixable: Implement fix to allow both
  - If code change needed, ensure it doesn't break existing draggable items

  **Investigation Starting Points**:
  - `ObjectAttachedToUITag` definition: `src/systems/ui/ui_data.hpp:29`
  - Tag is applied in: `src/systems/ui/box.cpp:168` - `emplace_or_replace<ui::ObjectAttachedToUITag>`
  - Tag affects master selection: `src/systems/transform/transform_functions.cpp` (search for ObjectAttachedToUITag)
  - UI shader detection: `src/systems/ui/box.cpp:2324-2368` - check if tag presence affects shader path selection

  **Must NOT do**:
  - Remove `ObjectAttachedToUITag` system
  - Change draggable item behavior
  - Make assumptions - investigate first

  **Parallelizable**: YES (after Task 3)

  **References**:
  - `docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md:526, 1000` - Current warning about conflict
  - `src/systems/ui/ui_data.hpp:29` - `ObjectAttachedToUITag` struct definition
  - `src/systems/ui/box.cpp:168` - Where tag is applied to entities
  - `src/systems/ui/box.cpp:2324-2368` - UI shader detection (may have tag check)
  - `src/systems/transform/transform_functions.cpp` - Tag affects transform master selection

  **Acceptance Criteria**:
  - [ ] Root cause of conflict documented (specific code location identified)
  - [ ] Either: Code fix applied OR documentation updated explaining mutual exclusivity
  - [ ] If fixed: Test showing element with both tag and shader working
  - [ ] If not fixed: Clear documentation of why and workaround

  **Commit**: YES
  - Message: `docs(ui): document ObjectAttachedToUITag + shader interaction` OR `fix(ui): allow ObjectAttachedToUITag with shader pipeline`
  - Files: Depends on finding
  - Pre-commit: `just test`

---

- [x] 5. Add Comprehensive Tests

  **What to do**:
  - **C++ Unit Test** (`tests/unit/test_ui_shader_isolation.cpp`):
    - Test `UIShaderRenderContext` **logic only** (no GPU context required):
      - Test `swapCount` initialization (should be 0)
      - Test `resetSwapCount()` sets count back to 0
      - Test `swap()` increments swapCount (test incrementing 0→1→2→3)
      - Test parity calculation: `(swapCount % 2 == 0)` for counts 0, 1, 2, 3, 4, 5
    - **Do NOT test RAII guards in C++ unit tests** - guards call `render_stack_switch_internal` which requires graphics context
    - **NOTE**: Tests do NOT call `LoadRenderTexture()` or `InitWindow()` - this codebase's unit tests run without a graphics context
    - Only test pure logic that doesn't touch raylib APIs
  - **Lua Integration Test** (`assets/scripts/tests/test_multi_shader_ui.lua`):
    - Spawn 5 cards with `ShaderBuilder:add("3d_skew")`
    - Log entity IDs and shader pass counts
    - Use `Timer.after(2, function() ... end)` to check state after rendering stabilizes
    - Print "PASS: All elements have distinct UIShaderRenderContext" or "FAIL: ..." for verification
    - This is a runtime visual+log test, not automated assertion
  - Update `tests/CMakeLists.txt` to include new test file

  **Test Constraints** (this repo's pattern):
  - C++ unit tests do NOT have a raylib window context (no `InitWindow()`)
  - Cannot test RAII guards that wrap raylib calls in C++ unit tests
  - RAII guard correctness verified via Lua integration test (guards work if multi-element renders correctly)
  - Lua tests run in-game and verify via logging + visual inspection

  **Must NOT do**:
  - Modify existing test files
  - Add performance benchmarks (out of scope)
  - Call `InitWindow()` or `LoadRenderTexture()` in C++ unit tests
  - Try to unit test RAII guard destruction (requires graphics context)

  **Parallelizable**: YES (after Task 3)

  **References**:
  - `tests/unit/test_shader_system.cpp` - Existing shader test patterns (logic-only, no GPU)
  - `tests/unit/test_render_stack_safety.cpp` - Render stack test patterns
  - `tests/CMakeLists.txt:1-50` - Test registration pattern
  - `assets/scripts/tests/shader_builder_visual_test.lua` - Lua test pattern

  **Acceptance Criteria**:
  - [ ] `test_ui_shader_isolation.cpp` created with 4+ test cases (logic-only, no GPU calls)
  - [ ] Tests cover: swapCount init, swapCount reset, swapCount increment, parity calculation
  - [ ] `test_multi_shader_ui.lua` created with multi-element scenario and log-based verification
  - [ ] `just test` passes with new tests
  - [ ] Lua test prints clear PASS/FAIL for manual verification
  - [ ] RAII guard correctness implicitly verified by Lua test (elements render correctly)

  **Commit**: YES
  - Message: `test(shader): add UI shader isolation tests (C++ and Lua)`
  - Files: `tests/unit/test_ui_shader_isolation.cpp`, `tests/CMakeLists.txt`, `assets/scripts/tests/test_multi_shader_ui.lua`
  - Pre-commit: `just test`

---

- [x] 6. Update Documentation

  **What to do**:
  - Update `SHADER_PIPELINE_SAFETY_GUIDE.md`:
    - Mark Issue #7 as FIXED
    - Add section on `UIShaderRenderContext` usage
    - Document when to use per-element vs global textures
  - Update `docs/api/shader-builder.md`:
    - Add example of multi-element shader UI
    - Note that isolation is automatic for UI elements
  - Update `docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md`:
    - Update shader guidance based on Task 4 findings
    - Remove or update "DO NOT" warning if fixed

  **Must NOT do**:
  - Create new documentation files
  - Document unimplemented features

  **Parallelizable**: NO (depends on Task 4 and 5)

  **References**:
  - `docs/guides/implementation-summaries/SHADER_PIPELINE_SAFETY_GUIDE.md:323-335` - Issue #7 section
  - `docs/api/shader-builder.md` - ShaderBuilder docs
  - `docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md:526, 1000` - Current warnings

  **Acceptance Criteria**:
  - [ ] SAFETY_GUIDE Issue #7 marked as FIXED with solution summary
  - [ ] `UIShaderRenderContext` documented with usage example
  - [ ] Multi-element shader UI example added
  - [ ] ObjectAttachedToUITag guidance updated based on findings

  **Commit**: YES
  - Message: `docs(shader): update documentation for UI shader isolation fix`
  - Files: `docs/guides/implementation-summaries/SHADER_PIPELINE_SAFETY_GUIDE.md`, `docs/api/shader-builder.md`, `docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md`
  - Pre-commit: N/A (docs only)

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 0 | `test(shader): add reproduction script for multi-shader UI bug` | `assets/scripts/tests/test_multi_shader_ui_repro.lua` | `just test` |
| 1 | `feat(shader): add UIShaderRenderContext component for per-element isolation` | `shader_pipeline.hpp` | `just build-debug` |
| 2 | `fix(layer): use per-element render textures for UI shader isolation` | `layer.cpp`, `box.cpp` | `just test` |
| 3 | `feat(shader): implement RAII guards and apply to UI shader path` | `shader_pipeline.hpp`, `layer.cpp` | `just test` |
| 4 | `docs/fix(ui): ObjectAttachedToUITag + shader interaction` | TBD | `just test` |
| 5 | `test(shader): add UI shader isolation tests (C++ and Lua)` | `test_*.cpp`, `test_*.lua`, `CMakeLists.txt` | `just test` |
| 6 | `docs(shader): update documentation for UI shader isolation fix` | `*.md` | N/A |

---

## Success Criteria

### Verification Commands
```bash
# Build and run tests
just build-debug && just test

# Run specific shader tests
cd build && ctest -R shader --output-on-failure

# Manual visual verification
./build/raylib-cpp-cmake-template
# Then in-game: spawn multiple shader-enabled UI elements
```

### Final Checklist
- [ ] 5 shader-enabled UI elements render correctly (no upside-down flipping)
- [ ] Single-element shader rendering unchanged (regression check)
- [ ] All tests pass (`just test`)
- [ ] Memory usage documented (~20MB for 5 elements acceptable)
- [ ] ObjectAttachedToUITag behavior documented or fixed
- [ ] SAFETY_GUIDE updated with fix
- [ ] No new global state added to `shader_pipeline.hpp`
