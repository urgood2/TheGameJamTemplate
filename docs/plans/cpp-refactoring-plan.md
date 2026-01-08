# C++ Refactoring Plan

Based on architectural review feedback from 2026-01-08.

## Scope Summary

| Item | Status | Notes |
|------|--------|-------|
| EngineContext Migration | ✅ Approved | Needs test scaffolding first |
| game.cpp Self-Registering Systems | ✅ Approved | Include in plan |
| Layer System Extraction | ✅ Approved | As long as nothing breaks |
| Include Explosion Fix | ✅ Approved | Forward declarations |
| Blackboard std::any | ❌ Deferred | Not now |
| Raw Pointers → Safer Patterns | ✅ Approved | Do this |
| Static State in Headers | ✅ Approved | Safe to remove |
| [[nodiscard]] on Getters | ✅ Approved | Nodiscard only, no other C++20 features |
| UI System Decoupling | ❌ Frozen | Don't touch UI |

---

## Phase 0: Test Scaffolding (Pre-requisite)

**Goal:** Create safety net before any refactoring touches EngineContext.

### 0.1 Identify Critical Paths

Test coverage needed for:

```
src/core/engine_context.hpp
src/core/globals.hpp
src/core/init.cpp
src/core/game.cpp
```

### 0.2 Test Categories

| Category | What to Test | Example |
|----------|--------------|---------|
| Initialization | System startup order | Physics before scripting |
| Registry Access | Component add/get/remove | `registry.emplace<Transform>()` |
| Resource Loading | Atlas, animations, sprites | `getAtlasTexture("player")` |
| Physics | World creation, body creation | `physicsManager->getWorld("main")` |
| Lua Context | Script loading, function calls | `lua["someFunction"]()` |
| Input State | Input polling | `inputState->isKeyPressed()` |

### 0.3 Test Infrastructure

**File:** `src/tests/engine_context_tests.cpp`

```cpp
// Minimal test harness - no external dependencies
#include "core/engine_context.hpp"
#include <cassert>

namespace tests {

void test_registry_basic_operations() {
    EngineConfig cfg{};
    auto ctx = createEngineContext("");

    auto entity = ctx->registry.create();
    assert(ctx->registry.valid(entity));

    ctx->registry.destroy(entity);
    assert(!ctx->registry.valid(entity));
}

void test_physics_world_creation() {
    EngineConfig cfg{};
    auto ctx = createEngineContext("");

    // Verify physics manager exists
    assert(ctx->physicsManager != nullptr);

    // Verify world can be created
    auto* world = ctx->physicsManager->getOrCreateWorld("test");
    assert(world != nullptr);
}

void test_resource_caches_initialized() {
    EngineConfig cfg{};
    auto ctx = createEngineContext("");

    // Caches should be empty but accessible
    assert(ctx->textureAtlas.empty());
    assert(ctx->animations.empty());
}

void run_all_tests() {
    test_registry_basic_operations();
    test_physics_world_creation();
    test_resource_caches_initialized();
    // Add more as needed
}

} // namespace tests
```

### 0.4 Integration Test Script

**File:** `tools/test_refactoring.sh`

```bash
#!/bin/bash
set -e

echo "=== Refactoring Safety Tests ==="

# Build with tests
just build-debug

# Run unit tests
./build/raylib-cpp-cmake-template --run-tests

# Run game for 5 seconds to verify no crashes
timeout 5 ./build/raylib-cpp-cmake-template --headless || true

echo "=== All tests passed ==="
```

---

## Phase 1: Quick Wins (Low Risk)

**Estimated Time:** 1-2 days
**Risk Level:** Low

### 1.1 Add [[nodiscard]] to Getters

**Files to modify:**
- `src/core/globals.hpp` - 20+ getter functions
- `src/core/engine_context.hpp` - `getAtlasTexture()`
- `src/core/init.hpp` - `getAssetPath()`, `getAnimationObject()`, etc.

**Pattern:**
```cpp
// BEFORE
entt::entity getCursorEntity();
Vector2 getWorldMousePosition();
const Font& getBestFontForSize(float requestedSize) const;

// AFTER
[[nodiscard]] entt::entity getCursorEntity();
[[nodiscard]] Vector2 getWorldMousePosition();
[[nodiscard]] const Font& getBestFontForSize(float requestedSize) const;
```

**Specific locations:**
| File | Line | Function |
|------|------|----------|
| `globals.hpp` | 473 | `getBestFontForSize()` |
| `globals.hpp` | 491 | `getDefaultFont()` |
| `globals.hpp` | 549 | `getCursorEntity()` |
| `globals.hpp` | 553 | `getOverlayMenu()` |
| `globals.hpp` | 557 | `getGameWorldContainer()` |
| `globals.hpp` | 566 | `getRegistry()` |
| `globals.hpp` | 570 | `getWorldMousePosition()` |
| `globals.hpp` | 575-584 | All `getLastXxx()` functions |
| `globals.hpp` | 598 | `getCollisionLog()` |
| `engine_context.hpp` | 147 | `getAtlasTexture()` |
| `init.hpp` | 47 | `getAssetPath()` |
| `init.hpp` | 49 | `getAnimationObject()` |
| `init.hpp` | 52 | `getUIString()` |
| `init.hpp` | 55 | `getSpriteFrame()` |

### 1.2 Remove Static State from Headers

**File:** `src/core/misc_fuctions.hpp`

**Current problematic statics:**
```cpp
// Lines 48-51: Loading screen state
static int currentScaleIndex = 2;
static int previousScaleIndex = currentScaleIndex;
static int lastLoadingCountShown = 0;
static float fakeProgress = 0.0f;

// Line 196: UI state
static bool showContent = false;

// Line 262: Delete confirmation
static bool confirmDelete = false;

// Lines 321-322: Debug stats
static int runs = 0, wave = 0, kills = 0, gold = 0;
static bool initialized = false;
```

**Solution:** Move to a struct in the .cpp file or pass as parameters.

```cpp
// NEW: src/core/misc_functions_state.hpp
struct MiscFunctionsState {
    int currentScaleIndex = 2;
    int previousScaleIndex = 2;
    int lastLoadingCountShown = 0;
    float fakeProgress = 0.0f;
    bool showContent = false;
    bool confirmDelete = false;

    // Debug stats
    struct DebugStats {
        int runs = 0;
        int wave = 0;
        int kills = 0;
        int gold = 0;
        bool initialized = false;
    } debug;
};

// Access via function (lazy initialization)
MiscFunctionsState& getMiscState();
```

### 1.3 Fix Raw Pointers in EngineContext

**File:** `src/core/engine_context.hpp` lines 67-71

**Current:**
```cpp
::input::InputState* inputState{nullptr};        // non-owning
AudioContext* audio{nullptr};                    // non-owning placeholder
::shaders::ShaderUniformComponent* shaderUniformsPtr{nullptr}; // optional alias
```

**After:**
```cpp
// Option A: std::optional<std::reference_wrapper<T>> for nullable non-owning
std::optional<std::reference_wrapper<::input::InputState>> inputState;
std::optional<std::reference_wrapper<AudioContext>> audio;

// Option B: Raw pointer with clear documentation + helper
::input::InputState* inputState{nullptr};  // Non-owning. Valid only during game loop.

// Add safe accessor
[[nodiscard]] ::input::InputState* getInputState() const noexcept {
    return inputState;
}

[[nodiscard]] bool hasInputState() const noexcept {
    return inputState != nullptr;
}
```

**Recommended:** Option B with accessors (less invasive, clearer API).

---

## Phase 2: EngineContext Migration

**Estimated Time:** 3-5 days
**Risk Level:** Medium
**Pre-requisite:** Phase 0 tests passing

### 2.1 Audit Current Usage

Files still using `globals::` namespace directly:

```bash
# Run this to find all usages
grep -r "globals::" src/ --include="*.cpp" --include="*.hpp" | grep -v third_party | wc -l
```

**Expected:** ~25 files with direct globals usage.

### 2.2 Migration Order

Migrate in order of least dependencies to most:

| Order | System | Files | Dependencies |
|-------|--------|-------|--------------|
| 1 | Timer | `systems/timer/` | None |
| 2 | Random | `systems/random/` | None |
| 3 | Sound | `systems/sound/` | None |
| 4 | Camera | `systems/camera/` | Transform only |
| 5 | Particles | `systems/particles/` | Transform, Layer |
| 6 | AI | `systems/ai/` | Registry, Physics |
| 7 | Physics | `systems/physics/` | Registry |
| 8 | Scripting | `systems/scripting/` | Registry, Physics, Events |
| 9 | Input | `systems/input/` | Registry |
| 10 | Layer | `systems/layer/` | Everything (last) |

### 2.3 Migration Pattern per System

```cpp
// BEFORE: system uses globals
#include "core/globals.hpp"

void SomeSystem::update() {
    auto& reg = globals::registry;
    auto view = reg.view<Transform>();
    // ...
}

// AFTER: system receives EngineContext
#include "core/engine_context.hpp"

class SomeSystem {
    EngineContext& ctx;
public:
    explicit SomeSystem(EngineContext& ctx) : ctx(ctx) {}

    void update() {
        auto view = ctx.registry.view<Transform>();
        // ...
    }
};
```

### 2.4 Verification After Each Migration

After migrating each system:
1. Run `tools/test_refactoring.sh`
2. Run game for 30 seconds
3. Check no new compiler warnings
4. Commit with message: `refactor(context): migrate XxxSystem to EngineContext`

### 2.5 Migration Pattern (Implemented Example)

**Example: `entity_gamestate_management` system**

The migration pattern creates explicit-registry function signatures while maintaining backward compatibility:

**Header changes (`entity_gamestate_management.hpp`):**
```cpp
// New explicit-registry versions (preferred for dependency injection)
void emplaceOrReplaceStateTag(entt::registry &registry, entt::entity entity, const std::string &name);
void assignDefaultStateTag(entt::registry &registry, entt::entity entity);
bool isEntityActive(entt::registry &registry, entt::entity entity);

void activate_state(entt::registry &registry, std::string_view s);
void deactivate_state(entt::registry &registry, std::string_view s);
void clear_states(entt::registry &registry);

// Backward-compatible overloads (use globals internally)
void emplaceOrReplaceStateTag(entt::entity entity, const std::string &name);
void assignDefaultStateTag(entt::entity entity);
bool isEntityActive(entt::entity entity);

void activate_state(std::string_view s);
void deactivate_state(std::string_view s);
void clear_states();
```

**Implementation changes (`entity_gamestate_management.cpp`):**
```cpp
// Explicit registry version - contains actual logic
void emplaceOrReplaceStateTag(entt::registry &registry, entt::entity entity, const std::string &name) {
    registry.emplace_or_replace<StateTag>(entity, name);
    applyStateEffectsToEntity(registry, entity);
}

// Backward-compatible overload - delegates to explicit version
void emplaceOrReplaceStateTag(entt::entity entity, const std::string &name) {
    emplaceOrReplaceStateTag(globals::getRegistry(), entity, name);
}
```

**Lua bindings with overloaded functions:**
```cpp
// Use static_cast to disambiguate overloaded functions for Sol2
lua.set_function("activate_state",   static_cast<void(*)(std::string_view)>(&activate_state));
lua.set_function("deactivate_state", static_cast<void(*)(std::string_view)>(&deactivate_state));
lua.set_function("clear_states",     static_cast<void(*)()>(&clear_states));
lua.set_function("is_entity_active", static_cast<bool(*)(entt::entity)>(&isEntityActive));
```

**Benefits:**
1. New code can use explicit registry injection (testable, no global state)
2. Existing code continues to work unchanged (backward compatible)
3. Gradual migration - convert callers one at a time
4. Lua bindings remain unchanged (use backward-compatible overloads)

---

## Phase 3: Include Explosion Fix

**Estimated Time:** 2-3 days
**Risk Level:** Low-Medium

### 3.1 game.cpp Include Reduction

**Current state:** 95+ includes in game.cpp

**Target:** < 30 includes by using forward declarations and moving implementations.

**Strategy:**
```cpp
// BEFORE: game.cpp includes everything
#include "systems/physics/physics_world.hpp"      // 3,401 LOC of implementation
#include "systems/layer/layer.hpp"                // 6,871 LOC
#include "systems/ui/element.hpp"                 // 3,161 LOC

// AFTER: forward declarations + minimal headers
// In game.hpp:
namespace physics { class PhysicsWorld; }
namespace layer { class LayerSystem; }
namespace ui { class UIElement; }

// game.cpp only includes what it directly uses
#include "systems/physics/physics_fwd.hpp"  // forward declarations only
```

### 3.2 Create Forward Declaration Headers

For each major system, create `*_fwd.hpp`:

```cpp
// src/systems/physics/physics_fwd.hpp
#pragma once
namespace physics {
    class PhysicsWorld;
    class PhysicsManager;
    struct PhysicsBody;
}

// src/systems/layer/layer_fwd.hpp
#pragma once
namespace layer {
    class LayerSystem;
    struct RenderCommand;
    enum class LayerType;
}
```

### 3.3 Split components.hpp

**Current:** Single 279 LOC file with all components.

**After:** Split by domain:
```
src/components/
├── components.hpp        # Main include (aggregates all)
├── transform.hpp         # Transform, Velocity, etc.
├── rendering.hpp         # Sprite, Animation, Shader
├── physics.hpp           # PhysicsBody, Collision
├── ai.hpp                # GOAP components
└── scripting.hpp         # ScriptComponent
```

---

## Phase 4: game.cpp Self-Registering Systems

**Estimated Time:** 1 week
**Risk Level:** Medium
**Pre-requisite:** Phase 2 complete

### 4.1 System Registration Interface

```cpp
// src/core/system_registry.hpp
#pragma once
#include <functional>
#include <vector>
#include <string>

class SystemRegistry {
public:
    using UpdateFn = std::function<void(float dt)>;
    using InitFn = std::function<void()>;

    struct SystemEntry {
        std::string name;
        int priority;  // Lower = earlier
        UpdateFn update;
        InitFn init;
    };

    void registerSystem(std::string name, int priority, UpdateFn update, InitFn init = nullptr);
    void initAll();
    void updateAll(float dt);

private:
    std::vector<SystemEntry> systems;
    bool sorted = false;
};
```

### 4.2 System Self-Registration Pattern

```cpp
// src/systems/physics/physics_system.cpp
#include "core/system_registry.hpp"

namespace {
    // Self-registration on program startup
    struct PhysicsSystemRegistrar {
        PhysicsSystemRegistrar() {
            SystemRegistry::global().registerSystem(
                "physics",
                10,  // priority
                [](float dt) { PhysicsSystem::instance().update(dt); },
                []() { PhysicsSystem::instance().init(); }
            );
        }
    } registrar;
}
```

### 4.3 Simplified game.cpp

```cpp
// BEFORE: 2,421 LOC with explicit system calls
void Game::update(float dt) {
    physicsSystem.update(dt);
    aiSystem.update(dt);
    scriptingSystem.update(dt);
    // ... 38 more systems
}

// AFTER: ~100 LOC
void Game::update(float dt) {
    SystemRegistry::global().updateAll(dt);
}
```

---

## Phase 5: Layer System Extraction

**Estimated Time:** 2 weeks
**Risk Level:** High
**Pre-requisite:** Phase 0-4 complete, comprehensive visual tests

### 5.1 Extract Components

Split 6,871 LOC into:

| Component | Responsibility | Est. LOC |
|-----------|---------------|----------|
| `RenderBatcher` | Sprite/primitive batching | 1,500 |
| `DepthSorter` | Z-ordering algorithms | 800 |
| `RenderStack` | Push/pop render textures | 500 |
| `DrawCommandBuffer` | Deferred command queue | 1,200 |
| `LayerSystem` | Orchestration (facade) | 800 |

### 5.2 Interface Design

```cpp
// src/systems/layer/i_render_batcher.hpp
class IRenderBatcher {
public:
    virtual ~IRenderBatcher() = default;
    virtual void beginBatch() = 0;
    virtual void endBatch() = 0;
    virtual void addSprite(const SpriteCommand& cmd) = 0;
    virtual void addRect(const RectCommand& cmd) = 0;
    virtual void flush() = 0;
};

// src/systems/layer/i_depth_sorter.hpp
class IDepthSorter {
public:
    virtual ~IDepthSorter() = default;
    virtual void sort(std::vector<RenderCommand>& commands) = 0;
};
```

### 5.3 Visual Regression Test

**Critical:** Before ANY layer changes, capture reference screenshots.

```bash
# Capture reference frames
./build/raylib-cpp-cmake-template --capture-frames output/reference/

# After changes, compare
./tools/compare_frames.py output/reference/ output/current/
```

---

## Execution Checklist

### Before Starting Any Phase
- [ ] All existing tests pass
- [ ] Game runs without crashes for 5 minutes
- [ ] Commit current state as safety checkpoint

### After Each Change
- [ ] Incremental build succeeds
- [ ] No new compiler warnings
- [ ] Game still launches
- [ ] Relevant tests pass

### Before Merging Phase
- [ ] Full clean build succeeds
- [ ] All tests pass
- [ ] Game runs for 10+ minutes without issues
- [ ] Code review completed

---

## Timeline Estimate

| Phase | Duration | Cumulative |
|-------|----------|------------|
| Phase 0: Test Scaffolding | 2-3 days | Week 1 |
| Phase 1: Quick Wins | 1-2 days | Week 1 |
| Phase 2: EngineContext Migration | 3-5 days | Week 2 |
| Phase 3: Include Explosion | 2-3 days | Week 2-3 |
| Phase 4: Self-Registering Systems | 5-7 days | Week 3-4 |
| Phase 5: Layer Extraction | 10-14 days | Week 5-7 |

**Total: 5-7 weeks** (with buffer for unexpected issues)

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Breaking existing functionality | Phase 0 tests + incremental commits |
| Compile time regression | Measure before/after each phase |
| Merge conflicts with feature work | Do refactoring in dedicated branch, rebase frequently |
| Layer extraction visual bugs | Reference screenshot comparison |

---

## Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Full rebuild time | ? seconds | -30% |
| Incremental build (1 file) | ? seconds | -50% |
| game.cpp includes | 95 | < 30 |
| Files using globals:: | 25 | 0 |
| Layer system LOC | 6,871 | < 2,000 (facade) |
