# C++ Refactoring Implementation Plan

## Overview

| Item | Value |
|------|-------|
| **Total Estimated Time** | 3-4 weeks |
| **Worktree** | `.worktrees/cpp-refactor` |
| **Branch** | `cpp-refactor` |
| **Testing Framework** | GoogleTest |
| **Build Command** | `just build-debug` |
| **Test Command** | `just test` |

## Principles

1. **TDD**: Write tests FIRST, then implementation
2. **Incremental**: Small, atomic commits - all tests must pass after each
3. **Master untouched**: All work in `cpp-refactor` worktree/branch
4. **No regressions**: Existing 42+ unit tests must continue passing

---

## Pre-flight Checklist

- [ ] Verify all existing tests pass: `just test`
- [ ] Create baseline build: `just build-debug`
- [ ] Document current test count: `./build/tests/unit_tests --gtest_list_tests | wc -l`
- [ ] Tag baseline: `git tag pre-refactor-baseline`
- [ ] Verify worktree is on correct branch: `git branch --show-current` (should be `cpp-refactor`)

---

## Phase 1: Registry Consolidation (3-4 days)

**Goal**: Make `EngineContext::registry` authoritative, eliminate dual source of truth.

### Current State Analysis
- **417 calls** to `globals::getRegistry()` across 51 files
- **Bridge pattern** already exists in `globals.cpp:695-700`:
  ```cpp
  entt::registry& getRegistry() {
      if (g_ctx) return g_ctx->registry;
      return registry;  // Fallback to legacy global
  }
  ```
- **Existing tests**: `test_engine_context.cpp`, `test_globals_bridge.cpp`

### Step 1.1: Add Tests for Registry Access Patterns (Day 1)

- [ ] **Test file**: `tests/unit/test_registry_consolidation.cpp`
- [ ] **Test cases**:
  ```cpp
  TEST(RegistryConsolidation, GetRegistryReturnsContextRegistryWhenSet)
  TEST(RegistryConsolidation, GetRegistryReturnsLegacyRegistryWhenContextNull)
  TEST(RegistryConsolidation, ContextRegistryAndLegacyRegistryAreDistinct)
  TEST(RegistryConsolidation, EntityCreatedInContextIsValidInGetRegistry)
  TEST(RegistryConsolidation, ComponentsAccessibleViaEitherPath)
  TEST(RegistryConsolidation, SetEngineContextUpdatesBridgePointer)
  ```
- [ ] **Add to CMakeLists.txt**: `unit/test_registry_consolidation.cpp`
- [ ] **Verification**: `just test` passes, new tests fail (RED phase)

### Step 1.2: Implement Registry Consolidation (Day 1-2)

- [ ] **File changes**: `src/core/globals.cpp`
  - Ensure `getRegistry()` ALWAYS returns `g_ctx->registry` when `g_ctx` is set
  - Add assertion/warning when `g_ctx` is null in debug builds
  - Remove fallback path (or make it debug-only with loud warning)
  
- [ ] **File changes**: `src/core/globals.hpp`
  - Add `[[nodiscard]]` to `getRegistry()` if not present
  - Update deprecation message to be more specific
  
- [ ] **Verification**: `just test` passes, new tests pass (GREEN phase)
- [ ] **Commit**: `refactor(registry): make EngineContext::registry authoritative`

### Step 1.3: Add Runtime Validation (Day 2)

- [ ] **File changes**: `src/core/globals.cpp`
  ```cpp
  entt::registry& getRegistry() {
      if (!g_ctx) {
          SPDLOG_WARN("[registry] getRegistry() called before EngineContext set");
          #ifndef NDEBUG
          assert(g_ctx && "getRegistry() called before setEngineContext()");
          #endif
      }
      return g_ctx ? g_ctx->registry : registry;
  }
  ```
- [ ] **Verification**: Debug builds crash early on misuse, release builds log warning
- [ ] **Commit**: `feat(registry): add runtime validation for registry access`

### Step 1.4: Update High-Traffic Call Sites (Day 2-3)

Priority files (60+ usages each):
- [ ] `src/core/game.cpp` - Pass registry as parameter to subsystems
- [ ] `src/systems/text/textVer2.cpp` - Wrap internal functions

Medium priority (25-30 usages):
- [ ] `src/systems/ai/ai_system.cpp`
- [ ] `src/systems/transform/transform_functions.cpp`
- [ ] `src/systems/scripting/scripting_functions.cpp`

- [ ] **Pattern to follow** (from REGISTRY_MIGRATION_GUIDE.md):
  ```cpp
  // Before
  void processEntity(entt::entity e) {
      auto& reg = globals::getRegistry();
      // ...
  }
  
  // After
  void processEntity(entt::registry& reg, entt::entity e) {
      // ...
  }
  
  // Deprecated wrapper for Lua compatibility
  ENGINECTX_DEPRECATED("Use processEntity(registry, entity)")
  void processEntity(entt::entity e) {
      processEntity(globals::getRegistry(), e);
  }
  ```

- [ ] **Verification**: `just test` passes, full build succeeds
- [ ] **Commit per file**: `refactor(game): pass registry explicitly to subsystems`

### Step 1.5: Document Migration Status (Day 3-4)

- [ ] Update `docs/guides/REGISTRY_MIGRATION_GUIDE.md` with:
  - List of migrated files
  - Remaining Lua-bridge functions (acceptable non-migration)
  - Testing guidelines for new code

- [ ] **Commit**: `docs(registry): update migration status and guidelines`

### Phase 1 Success Criteria
- [ ] All 42+ existing tests pass
- [ ] New `test_registry_consolidation.cpp` tests pass (6+ tests)
- [ ] No new warnings in build output
- [ ] `globals::getRegistry()` logs warning when `g_ctx` is null

---

## Phase 2: Component Logic Extraction (4-5 days)

**Goal**: Extract `Blackboard` class and GOAP utilities from `components.hpp` to dedicated files.

### Current State Analysis
- **Blackboard class**: `src/components/components.hpp:48-87` (40 lines)
- **mask_from_names()**: `src/components/components.hpp:114-125` (12 lines)
- **build_watch_mask()**: `src/components/components.hpp:130-165` (36 lines)
- **GOAPComponent**: `src/components/components.hpp:169-204` (36 lines) - keep as data-only
- **No existing tests** for Blackboard/GOAP utilities

### Step 2.1: Add Tests for Blackboard (Day 1)

- [ ] **Test file**: `tests/unit/test_blackboard.cpp`
- [ ] **Test cases**:
  ```cpp
  TEST(Blackboard, SetAndGetFloat)
  TEST(Blackboard, SetAndGetString)
  TEST(Blackboard, SetAndGetVector2)
  TEST(Blackboard, GetThrowsOnKeyNotFound)
  TEST(Blackboard, GetThrowsOnTypeMismatch)
  TEST(Blackboard, ContainsReturnsTrueForExistingKey)
  TEST(Blackboard, ContainsReturnsFalseForMissingKey)
  TEST(Blackboard, ClearRemovesAllEntries)
  TEST(Blackboard, SizeReturnsCorrectCount)
  TEST(Blackboard, IsEmptyReturnsTrueWhenEmpty)
  ```
- [ ] **Add to CMakeLists.txt**: `unit/test_blackboard.cpp`
- [ ] **Verification**: Tests compile against current implementation

### Step 2.2: Add Tests for GOAP Utilities (Day 1-2)

- [ ] **Test file**: `tests/unit/test_goap_utils.cpp`
- [ ] **Test cases**:
  ```cpp
  TEST(GOAPUtils, MaskFromNamesEmptyList)
  TEST(GOAPUtils, MaskFromNamesSingleAtom)
  TEST(GOAPUtils, MaskFromNamesMultipleAtoms)
  TEST(GOAPUtils, MaskFromNamesUnknownAtomIgnored)
  TEST(GOAPUtils, BuildWatchMaskWildcardReturnsAllBits)
  TEST(GOAPUtils, BuildWatchMaskExplicitTableReturnsCorrectBits)
  TEST(GOAPUtils, BuildWatchMaskAutoWatchPreconditions)
  ```
- [ ] **Add to CMakeLists.txt**: `unit/test_goap_utils.cpp`
- [ ] **Verification**: Tests compile and pass

### Step 2.3: Extract Blackboard to Dedicated Header (Day 2)

- [ ] **Create file**: `src/systems/ai/blackboard.hpp`
  ```cpp
  #pragma once
  #include <any>
  #include <string>
  #include <unordered_map>
  #include <stdexcept>
  
  namespace ai {
  
  class Blackboard {
  public:
      template<typename T>
      void set(const std::string& key, const T& value);
      
      template<typename T>
      T get(const std::string& key) const;
      
      bool contains(const std::string& key) const;
      std::size_t size() const;
      bool isEmpty() const;
      void clear();
      
  private:
      std::unordered_map<std::string, std::any> data_;
  };
  
  } // namespace ai
  ```

- [ ] **Create file**: `src/systems/ai/blackboard.cpp` (template implementations in header)

- [ ] **Update**: `src/components/components.hpp`
  - Add `#include "systems/ai/blackboard.hpp"`
  - Replace inline `Blackboard` class with `using Blackboard = ai::Blackboard;`
  - Add deprecation comment for migration

- [ ] **Verification**: Full build succeeds, all tests pass
- [ ] **Commit**: `refactor(ai): extract Blackboard class to dedicated header`

### Step 2.4: Extract GOAP Utilities (Day 3)

- [ ] **Create file**: `src/systems/ai/goap_utils.hpp`
  ```cpp
  #pragma once
  #include "../../third_party/GPGOAP/goap.h"
  #include <sol/sol.hpp>
  #include <vector>
  #include <string>
  
  namespace ai {
  
  using bfield_t = decltype(worldstate_t::values);
  
  bfield_t mask_from_names(const actionplanner_t& ap, 
                           const std::vector<std::string>& names);
  
  bfield_t build_watch_mask(const actionplanner_t& ap, 
                            sol::table actionTbl);
  
  } // namespace ai
  ```

- [ ] **Create file**: `src/systems/ai/goap_utils.cpp`
  - Move implementations from `components.hpp`

- [ ] **Update**: `src/components/components.hpp`
  - Add `#include "systems/ai/goap_utils.hpp"`
  - Remove inline implementations
  - Keep `static inline` wrappers for backward compatibility (deprecated)

- [ ] **Verification**: Full build succeeds, all tests pass
- [ ] **Commit**: `refactor(ai): extract GOAP utilities to dedicated files`

### Step 2.5: Make GOAPComponent Data-Only (Day 4)

- [ ] **Update**: `src/components/components.hpp:169-204`
  - Remove any method implementations (if present)
  - Keep only data members
  - Add comment: `// Data-only struct - logic in ai_system.cpp`

- [ ] **Verification**: Full build succeeds, all tests pass
- [ ] **Commit**: `refactor(ai): make GOAPComponent data-only struct`

### Step 2.6: Update Include Paths (Day 4-5)

Files that include `components.hpp` for Blackboard/GOAP:
- [ ] `src/systems/ai/ai_system.cpp` - update includes
- [ ] `src/systems/scripting/scripting_functions.cpp` - update includes
- [ ] `assets/scripts/ai/` Lua files - no changes needed (use C++ bindings)

- [ ] **Verification**: Full build succeeds, all tests pass
- [ ] **Commit**: `refactor(ai): update include paths for extracted components`

### Phase 2 Success Criteria
- [ ] All existing tests pass
- [ ] New `test_blackboard.cpp` tests pass (10+ tests)
- [ ] New `test_goap_utils.cpp` tests pass (7+ tests)
- [ ] `components.hpp` no longer contains Blackboard/GOAP utility implementations
- [ ] Build succeeds with no new warnings

---

## Phase 3: Globals Migration to EngineContext (5-6 days)

**Goal**: Continue migrating globals to EngineContext, deprecate unused globals.

### Current State Analysis
- **~60 globals migrated** (marked with checkmark in inventory)
- **~40 globals not yet migrated**
- **~22 legacy JSON blobs** (mostly unused)
- **Dual-path accessor pattern** already established

### Step 3.1: Audit Unused Globals (Day 1)

- [ ] **Create file**: `docs/guides/GLOBALS_AUDIT.md`
- [ ] **Identify unused globals** via grep for usage:
  ```bash
  # Example: Check if activityJSON is used
  grep -r "activityJSON" src/ --include="*.cpp" --include="*.hpp"
  ```
- [ ] **Document each global**:
  - Last usage commit (if any)
  - Recommended action (migrate/deprecate/remove)

- [ ] **Commit**: `docs(globals): audit unused globals and legacy JSON blobs`

### Step 3.2: Add Tests for High-Priority Globals (Day 1-2)

- [ ] **Test file**: `tests/unit/test_globals_migration.cpp`
- [ ] **Test cases** for each global being migrated:
  ```cpp
  TEST(GlobalsMigration, SpritesJSONMirroredToContext)
  TEST(GlobalsMigration, EnemiesVectorMirroredToContext)
  TEST(GlobalsMigration, NinePatchDataMapMirroredToContext)
  // etc.
  ```

### Step 3.3: Migrate Active JSON Blobs (Day 2-3)

Priority order (actively used):
- [ ] `spritesJSON` -> `ctx->spritesJson`
- [ ] `cp437MappingsJSON` -> `ctx->cp437MappingsJson`
- [ ] `miniJamCardsJSON` -> `ctx->miniJamCardsJson`
- [ ] `miniJamEnemiesJSON` -> `ctx->miniJamEnemiesJson`
- [ ] `ninePatchDataMap` -> `ctx->ninePatchDataMap`

**Pattern for each**:
1. Add field to `EngineContext` struct
2. Add mirroring in `setEngineContext()`
3. Add getter with deprecation warning
4. Update all direct usages to use context

- [ ] **Verification**: All tests pass after each migration
- [ ] **Commit per blob**: `refactor(globals): migrate spritesJSON to EngineContext`

### Step 3.4: Deprecate Unused JSON Blobs (Day 4)

Legacy blobs to deprecate (verify unused first):
- [ ] `activityJSON`, `environmentJSON`, `floraJSON`, `humanJSON`
- [ ] `levelsJSON`, `levelCurvesJSON`, `materialsJSON`, `worldGenJSON`
- [ ] `muscleJSON`, `timeJSON`, `itemsJSON`, `behaviorTreeConfigJSON`
- [ ] `namegenJSON`, `professionJSON`, `particleEffectsJSON`
- [ ] `combatActionToStateJSON`, `combatAttackWoundsJSON`, `combatAvailableActionsByStateJSON`
- [ ] `objectsJSON`

**Deprecation pattern**:
```cpp
// In globals.hpp
ENGINECTX_DEPRECATED("This JSON blob is no longer used")
extern json activityJSON;
```

- [ ] **Commit**: `refactor(globals): deprecate unused legacy JSON blobs`

### Step 3.5: Migrate Entity Management Globals (Day 5)

- [ ] `enemies` vector -> `ctx->enemies`
- [ ] `clickedEntity` -> `ctx->clickedEntity`
- [ ] `G_ROOM` -> `ctx->currentRoom`

- [ ] **Verification**: All tests pass
- [ ] **Commit**: `refactor(globals): migrate entity management globals`

### Step 3.6: Enforce No New Globals Policy (Day 6)

- [ ] **Update**: `docs/guides/CODING_STANDARDS.md`
  - Add section: "No New Globals"
  - Document approved pattern for new state
  
- [ ] **Add CI check** (optional): Script to detect new globals

- [ ] **Commit**: `docs(standards): enforce no new globals policy`

### Phase 3 Success Criteria
- [ ] All existing tests pass
- [ ] New migration tests pass
- [ ] Actively used JSON blobs accessible via EngineContext
- [ ] Unused JSON blobs marked deprecated
- [ ] Documentation updated with migration status

---

## Phase 4: Error Handling Standardization (3-4 days)

**Goal**: Standardize on exceptions for fatal errors, `Result<T,E>` for recoverable errors.

### Current State Analysis
- **`Result<T,E>`** already exists in `src/util/error_handling.hpp`
- **`safeLuaCall()`** wraps all Lua callbacks
- **`tryWithLog()`** converts exceptions to Result
- **Existing tests**: `test_error_handling.cpp`
- **Policy documented**: `docs/guides/ERROR_HANDLING_POLICY.md`

### Step 4.1: Audit Current Error Handling (Day 1)

- [ ] **Identify inconsistencies**:
  - Functions that throw where they shouldn't
  - Functions returning bool that should return Result
  - Missing error logging
  
- [ ] **Create inventory** in `docs/guides/ERROR_HANDLING_AUDIT.md`

### Step 4.2: Add Missing Error Handling Tests (Day 1-2)

- [ ] **Test file**: Extend `tests/unit/test_error_handling.cpp`
- [ ] **New test cases**:
  ```cpp
  TEST(ErrorHandling, ResultValueOrThrowOnError)
  TEST(ErrorHandling, ResultValueOrDefaultOnError)
  TEST(ErrorHandling, LoadWithRetryRetriesOnFailure)
  TEST(ErrorHandling, LoadWithRetryReturnsErrorAfterMaxRetries)
  TEST(ErrorHandling, SafeLuaCallCatchesSyntaxErrors)
  TEST(ErrorHandling, SafeLuaCallCatchesRuntimeErrors)
  ```

### Step 4.3: Standardize Asset Loading Errors (Day 2)

Files to update:
- [ ] `src/core/init.cpp` - Ensure all asset loading uses `tryWithLog`
- [ ] `src/systems/sound/sound_system.cpp` - Consistent Result usage
- [ ] `src/systems/localization/localization.cpp` - Consistent Result usage

**Pattern**:
```cpp
auto result = util::tryWithLog(
    [&]() { return loadAsset(path); },
    std::string("asset:load:") + path
);

if (result.isErr()) {
    SPDLOG_ERROR("[asset] {}", result.error());
    return fallbackValue;  // Or propagate error
}
```

- [ ] **Commit**: `refactor(errors): standardize asset loading error handling`

### Step 4.4: Standardize Physics/Collision Errors (Day 3)

- [ ] `src/systems/physics/physics_world.cpp`
- [ ] `src/systems/collision/` files

**Pattern**: Use `Result<T>` for operations that can fail, log with `[physics]` prefix.

- [ ] **Commit**: `refactor(errors): standardize physics error handling`

### Step 4.5: Document Error Handling Decision Tree (Day 4)

- [ ] **Update**: `docs/guides/ERROR_HANDLING_POLICY.md`
  - Add decision tree diagram
  - Add examples for each error type
  - Add testing guidelines

- [ ] **Commit**: `docs(errors): update error handling decision tree`

### Phase 4 Success Criteria
- [ ] All existing tests pass
- [ ] New error handling tests pass
- [ ] Consistent use of `Result<T>` for recoverable errors
- [ ] All Lua callbacks wrapped with `safeLuaCall()`
- [ ] Error messages include system prefix (e.g., `[asset]`, `[physics]`)

---

## Phase 5: Debug Keys Extraction (2-3 days)

**Goal**: Extract debug key handlers from `main.cpp` to `src/core/debug_keys.cpp`.

### Current State Analysis
- **F3/F7/F8/F10** handlers in `main.cpp:269-332`
- **F1/F2/F3/F4/F10** handlers in `game.cpp` via event bus
- **F5** handler in `shader_system.cpp`
- **F3 conflict**: perf_overlay vs debug draw toggle
- **No existing tests** for debug keys

### Step 5.1: Add Tests for Debug Key Handlers (Day 1)

- [ ] **Test file**: `tests/unit/test_debug_keys.cpp`
- [ ] **Test cases**:
  ```cpp
  TEST(DebugKeys, F3TogglesPerformanceOverlay)
  TEST(DebugKeys, F7TogglesHotPathAnalyzer)
  TEST(DebugKeys, F8PrintsECSDashboard)
  TEST(DebugKeys, F10CapturesCrashReport)
  TEST(DebugKeys, RegisterHandlerAddsToRegistry)
  TEST(DebugKeys, UnregisterHandlerRemovesFromRegistry)
  TEST(DebugKeys, ProcessInputCallsRegisteredHandlers)
  ```

### Step 5.2: Create Debug Keys Module (Day 1-2)

- [ ] **Create file**: `src/core/debug_keys.hpp`
  ```cpp
  #pragma once
  #include <functional>
  #include <unordered_map>
  
  namespace debug_keys {
  
  using Handler = std::function<void()>;
  
  void registerHandler(int key, Handler handler, const std::string& description);
  void unregisterHandler(int key);
  void processInput();  // Call each frame
  void listHandlers();  // Print to console
  
  // Built-in handlers
  void initDefaultHandlers();
  
  } // namespace debug_keys
  ```

- [ ] **Create file**: `src/core/debug_keys.cpp`
  - Move F3/F7/F8/F10 handlers from `main.cpp`
  - Register them in `initDefaultHandlers()`

- [ ] **Verification**: All tests pass
- [ ] **Commit**: `refactor(debug): extract debug key handlers to dedicated module`

### Step 5.3: Resolve F3 Key Conflict (Day 2)

- [ ] **Decision**: F3 = perf_overlay (keep in main loop for immediate response)
- [ ] **Move**: Debug draw toggle to F11 or other key
- [ ] **Update**: `game.cpp` event handler
- [ ] **Document**: Key mappings in `docs/guides/DEBUG_KEYS.md`

- [ ] **Commit**: `fix(debug): resolve F3 key conflict between perf overlay and debug draw`

### Step 5.4: Create SystemRunner Class (Day 3)

- [ ] **Create file**: `src/core/system_runner.hpp`
  ```cpp
  #pragma once
  #include <functional>
  #include <vector>
  #include <string>
  
  namespace core {
  
  struct SystemEntry {
      std::string name;
      std::function<void(float)> update;
      bool enabled = true;
  };
  
  class SystemRunner {
  public:
      void addSystem(const std::string& name, std::function<void(float)> update);
      void removeSystem(const std::string& name);
      void enableSystem(const std::string& name, bool enabled);
      void update(float dt);
      void listSystems();  // Debug: print system order
      
  private:
      std::vector<SystemEntry> systems_;
  };
  
  } // namespace core
  ```

- [ ] **Note**: This is optional/stretch goal - may defer to future phase

- [ ] **Commit**: `feat(core): add SystemRunner for ordered system updates`

### Phase 5 Success Criteria
- [ ] All existing tests pass
- [ ] Debug key tests pass
- [ ] Debug keys extracted to `src/core/debug_keys.cpp`
- [ ] No F3 key conflict
- [ ] Debug key mappings documented

---

## Phase 6: Memory Management Audit (2-3 days)

**Goal**: Wrap remaining manual memory management in RAII.

### Current State Analysis
- **Excellent RAII pattern** in `chipmunk_raii.hpp`
- **15 `new`/`delete` pairs** in Chipmunk wrappers
- **1 `calloc`/`free`** pair in PointCloudSampler
- **No memory leaks detected** in current code

### Step 6.1: Add Memory Safety Tests (Day 1)

- [ ] **Test file**: Extend `tests/unit/test_memory_safety.cpp`
- [ ] **Test cases**:
  ```cpp
  TEST(MemorySafety, ChipmunkBodyUniquePtr)
  TEST(MemorySafety, ChipmunkSpaceUniquePtr)
  TEST(MemorySafety, ChipmunkShapeUniquePtr)
  TEST(MemorySafety, SpringClampDataRAII)
  TEST(MemorySafety, BlockContextRAII)
  ```

### Step 6.2: Wrap ChipmunkSpace Manual Allocations (Day 1-2)

- [ ] **File**: `src/systems/chipmunk_objectivec/ChipmunkSpace.cpp`
  
  **Before**:
  ```cpp
  _staticBody = new ChipmunkBody(0.0f, 0.0f);
  // ...
  delete _staticBody;
  ```
  
  **After**:
  ```cpp
  _staticBody = std::make_unique<ChipmunkBody>(0.0f, 0.0f);
  // destructor handles cleanup
  ```

- [ ] **Update**: `ChipmunkSpace.hpp` to use `std::unique_ptr<ChipmunkBody>`
- [ ] **Verification**: All tests pass
- [ ] **Commit**: `refactor(physics): wrap ChipmunkSpace allocations in RAII`

### Step 6.3: Wrap Factory Method Returns (Day 2)

- [ ] **File**: `src/systems/chipmunk_objectivec/ChipmunkBody.cpp`
  
  **Before**:
  ```cpp
  ChipmunkBody* ChipmunkBody::BodyWithMassAndMoment(cpFloat mass, cpFloat moment) {
      return new ChipmunkBody(mass, moment);
  }
  ```
  
  **After**:
  ```cpp
  std::unique_ptr<ChipmunkBody> ChipmunkBody::BodyWithMassAndMoment(cpFloat mass, cpFloat moment) {
      return std::make_unique<ChipmunkBody>(mass, moment);
  }
  ```

- [ ] **Update all call sites** to use unique_ptr
- [ ] **Verification**: All tests pass
- [ ] **Commit**: `refactor(physics): return unique_ptr from factory methods`

### Step 6.4: Wrap BlockContext Allocation (Day 3)

- [ ] **File**: `src/systems/chipmunk_objectivec/ChipmunkSpace.cpp:227-229`
  
  **Before**:
  ```cpp
  auto* ctx = new BlockContext{block};
  cpSpaceAddPostStepCallback(_space, ..., ctx);
  // callback deletes ctx
  ```
  
  **After**:
  ```cpp
  auto ctx = std::make_shared<BlockContext>(block);
  auto* rawPtr = ctx.get();
  _postStepContexts.push_back(ctx);  // Keep alive
  cpSpaceAddPostStepCallback(_space, ..., rawPtr);
  // Remove from _postStepContexts in callback
  ```

- [ ] **Verification**: All tests pass, no memory leaks
- [ ] **Commit**: `refactor(physics): wrap BlockContext in shared_ptr`

### Step 6.5: Document RAII Patterns (Day 3)

- [ ] **Create file**: `docs/guides/MEMORY_MANAGEMENT.md`
  - Document existing RAII patterns
  - Add examples for new allocations
  - Reference `chipmunk_raii.hpp` as template

- [ ] **Commit**: `docs(memory): document RAII patterns and guidelines`

### Phase 6 Success Criteria
- [ ] All existing tests pass
- [ ] Memory safety tests pass
- [ ] No raw `new`/`delete` in project code (except third-party)
- [ ] All allocations use smart pointers or RAII wrappers
- [ ] Memory management documented

---

## Rollback Plan

Each phase can be reverted independently using git tags:

| Phase | Tag | Rollback Command |
|-------|-----|------------------|
| Pre-refactor | `pre-refactor-baseline` | `git reset --hard pre-refactor-baseline` |
| Phase 1 | `post-phase-1-registry` | `git reset --hard post-phase-1-registry` |
| Phase 2 | `post-phase-2-components` | `git reset --hard post-phase-2-components` |
| Phase 3 | `post-phase-3-globals` | `git reset --hard post-phase-3-globals` |
| Phase 4 | `post-phase-4-errors` | `git reset --hard post-phase-4-errors` |
| Phase 5 | `post-phase-5-debug` | `git reset --hard post-phase-5-debug` |
| Phase 6 | `post-phase-6-memory` | `git reset --hard post-phase-6-memory` |

**Tag after each phase**:
```bash
git tag post-phase-X-<name>
git push origin post-phase-X-<name>
```

---

## Success Criteria Summary

### Quantitative
- [ ] All 42+ existing tests pass
- [ ] 30+ new tests added across all phases
- [ ] Build succeeds (debug + release)
- [ ] No new warnings introduced
- [ ] No memory leaks (AddressSanitizer clean)

### Qualitative
- [ ] `EngineContext::registry` is authoritative source
- [ ] Blackboard/GOAP utilities in dedicated files
- [ ] Unused globals deprecated
- [ ] Error handling consistent across codebase
- [ ] Debug keys consolidated
- [ ] All allocations use RAII

### Documentation
- [ ] `REGISTRY_MIGRATION_GUIDE.md` updated
- [ ] `GLOBALS_AUDIT.md` created
- [ ] `ERROR_HANDLING_POLICY.md` updated
- [ ] `DEBUG_KEYS.md` created
- [ ] `MEMORY_MANAGEMENT.md` created

---

## Appendix A: File Inventory

### Files to Create
| File | Phase | Purpose |
|------|-------|---------|
| `tests/unit/test_registry_consolidation.cpp` | 1 | Registry tests |
| `tests/unit/test_blackboard.cpp` | 2 | Blackboard tests |
| `tests/unit/test_goap_utils.cpp` | 2 | GOAP utility tests |
| `src/systems/ai/blackboard.hpp` | 2 | Blackboard class |
| `src/systems/ai/goap_utils.hpp` | 2 | GOAP utilities |
| `src/systems/ai/goap_utils.cpp` | 2 | GOAP implementations |
| `tests/unit/test_globals_migration.cpp` | 3 | Globals migration tests |
| `tests/unit/test_debug_keys.cpp` | 5 | Debug key tests |
| `src/core/debug_keys.hpp` | 5 | Debug key module |
| `src/core/debug_keys.cpp` | 5 | Debug key implementations |
| `src/core/system_runner.hpp` | 5 | System runner (optional) |
| `docs/guides/GLOBALS_AUDIT.md` | 3 | Globals inventory |
| `docs/guides/DEBUG_KEYS.md` | 5 | Debug key mappings |
| `docs/guides/MEMORY_MANAGEMENT.md` | 6 | RAII patterns |

### Files to Modify
| File | Phase | Changes |
|------|-------|---------|
| `src/core/globals.cpp` | 1, 3 | Registry consolidation, globals migration |
| `src/core/globals.hpp` | 1, 3 | Deprecation warnings |
| `src/core/engine_context.hpp` | 3 | Add migrated fields |
| `src/components/components.hpp` | 2 | Extract Blackboard/GOAP |
| `src/core/game.cpp` | 1, 5 | Registry params, debug keys |
| `src/main.cpp` | 5 | Extract debug keys |
| `src/systems/chipmunk_objectivec/ChipmunkSpace.cpp` | 6 | RAII wrappers |
| `src/systems/chipmunk_objectivec/ChipmunkBody.cpp` | 6 | Factory returns |
| `tests/CMakeLists.txt` | All | Add new test files |

---

## Appendix B: Test Count Tracking

| Phase | New Tests | Running Total |
|-------|-----------|---------------|
| Baseline | 0 | 42+ |
| Phase 1 | 6+ | 48+ |
| Phase 2 | 17+ | 65+ |
| Phase 3 | 10+ | 75+ |
| Phase 4 | 6+ | 81+ |
| Phase 5 | 7+ | 88+ |
| Phase 6 | 5+ | 93+ |

---

## Appendix C: Git Workflow

```bash
# Start of each phase
git checkout cpp-refactor
git pull origin cpp-refactor

# During development
git add -p  # Stage changes incrementally
git commit -m "type(scope): description"
just test   # Verify tests pass

# End of each phase
git tag post-phase-X-<name>
git push origin cpp-refactor
git push origin post-phase-X-<name>
```

### Commit Message Format
```
type(scope): description

- type: refactor, feat, fix, test, docs
- scope: registry, ai, globals, errors, debug, memory
- description: imperative mood, lowercase
```

### Examples
```
refactor(registry): make EngineContext::registry authoritative
test(blackboard): add type safety tests
docs(errors): update error handling decision tree
fix(debug): resolve F3 key conflict
```
