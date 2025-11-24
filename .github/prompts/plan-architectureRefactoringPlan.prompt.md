# Architecture Refactoring Plan
**Game Engine Modernization & Technical Debt Reduction**

**Priority Order:** Critical → High → Medium  
**Approach:** Parallel/Incremental (maintain compatibility while refactoring)  
**Estimated Timeline:** 3-4 months part-time  

---

## 🔴 CRITICAL PRIORITY

### Step 1: Refactor Global State Architecture
**Impact:** Enables testing, reduces coupling, improves maintainability  
**Estimated Effort:** 2-3 weeks  
**Risk Level:** High (touches entire codebase)  

**Progress (ongoing incremental rollout):**
- EngineContext scaffolded with registry, lua, physics ptr, resource caches, mouse positions, audio placeholder; `createEngineContext` wired and `globals::g_ctx` bridge in place.
- Globals bridged: context caches mouse positions/scaled mouse, physics ptr, audio placeholder; nearly all data maps (configs/colors/UI strings/animations/AI JSON/nine-patch, atlas/spriteFrames/animations, colors) now use EngineContext-backed getters.
- Runtime state bridged: cursor/overlay/world container, global UI maps, camera params, world size, UI scale/padding, render/letterbox scale, timers, pause/useImGUI flags, shader uniforms, LOS visibility map.
- Callers updated to access via getters: input, transform, text, layers/shaders, misc utilities, LOS, main loop timers/game state/physics manager, shader systems, UI layout.
- Memory-safety tweak retained (Chipmunk static body ownership guard); cursor bug fixed (HID reapply each frame).
- Build remains green after each batch; warnings intentionally left for later cleanup.

#### Detailed Step 1 Task List
- **Design scope:** Map current globals; decide minimal EngineContext fields (registry, lua, physics, resource maps, current state, mouse position).
- **Create scaffolding:** Add `engine_context.hpp/cpp` with constructor, factory, move-only semantics, and lightweight defaults; avoid heavy init inside ctor.
- **Bridge globals:** Add `globals::g_ctx` and `setEngineContext` to support parallel use; keep all legacy globals intact.
- **Initialize in main/init:** Instantiate context early, assign `g_ctx`, and (optionally) mirror initial values back into globals without removing any.
- **Migration staging:** Pick low-risk utilities (color, texture atlas) to accept `EngineContext&` while still syncing legacy globals for compatibility.
- **Testing/validation:** Ensure builds succeed after wiring; add a smoke check (e.g., context creation) before migrating heavier systems.
- **Documentation:** Record migration expectations and temporary compatibility rules in comments or dev notes to avoid regressions during rollout.

#### Current Problem
- 200+ extern variables in `globals.hpp` create massive coupling
- Every system depends on every other system through globals
- Impossible to unit test in isolation
- No clear initialization/destruction order
- Thread-safety completely absent

#### Solution: Dependency Injection via Context Object

**Phase 1A: Create Engine Context (Week 1)**
1. Create `src/core/engine_context.hpp` and `engine_context.cpp`
2. Define core context structure:
   ```cpp
   struct EngineContext {
       // Core systems
       entt::registry registry;
       sol::state lua;
       std::shared_ptr<PhysicsManager> physicsManager;
       
       // Managers (owned)
       std::unique_ptr<AudioManager> audioManager;
       std::unique_ptr<CameraManager> cameraManager;
       std::unique_ptr<InputManager> inputManager;
       
       // Configuration (immutable after init)
       const Config config;
       
       // Resource caches (owned)
       std::map<std::string, Texture2D> textureAtlas;
       std::map<std::string, AnimationObject> animations;
       std::map<std::string, SpriteFrameData> spriteFrames;
       std::map<std::string, Color> colors;
       
       // State (mutable)
       GameState currentGameState;
       Vector2 worldMousePosition;
       
       EngineContext(Config cfg);
       ~EngineContext();
       
       // Disable copy, allow move
       EngineContext(const EngineContext&) = delete;
       EngineContext& operator=(const EngineContext&) = delete;
       EngineContext(EngineContext&&) = default;
   };
   ```

3. Create initialization function:
   ```cpp
   std::unique_ptr<EngineContext> createEngineContext(const std::string& configPath);
   ```

**Phase 1B: Parallel Globals Pattern (Week 1)**
1. Keep existing `globals` namespace temporarily
2. Add global `EngineContext* g_ctx = nullptr;`
3. Initialize both systems in `main.cpp`:
   ```cpp
   // Create new context
   auto ctx = createEngineContext("config.json");
   g_ctx = ctx.get();
   
   // Sync legacy globals from context
   globals::getRegistry() = &ctx->registry;
   globals::lua = &ctx->lua;
   // etc...
   ```
4. This allows incremental migration without breaking existing code

**Phase 1C: Migrate Systems One-by-One (Week 2-3)**

**Order of Migration (least coupled → most coupled):**

1. **Start with utilities** (no dependencies):
   - `src/util/color_utils.cpp` - Change `globals::colorsMap` → `ctx.colors`
   - `src/util/texture_utils.cpp` - Change `globals::textureAtlasMap` → `ctx.textureAtlas`

2. **Audio system** (minimal dependencies):
   - Refactor `src/systems/audio/audio_system.cpp`
   - Change all `globals::` references to accept `AudioManager&` parameter
   - Example:
     ```cpp
     // Before
     void audio_system::PlaySound(const std::string& name) {
         auto& sound = globals::soundsMap[name];
         // ...
     }
     
     // After
     void audio_system::PlaySound(AudioManager& audio, const std::string& name) {
         auto& sound = audio.getSoundsMap()[name];
         // ...
     }
     ```

3. **Input system**:
   - Refactor `src/systems/input/input_functions.cpp`
   - Change `globals::inputState` → `InputManager` class
   - Pass `InputManager&` to all input functions

4. **Rendering systems**:
   - Refactor `src/systems/rendering/draw_system.cpp`
   - Pass `EngineContext&` to render functions
   - Access `ctx.registry`, `ctx.textureAtlas`, `ctx.spriteFrames`

5. **Physics system**:
   - Already partially encapsulated in `PhysicsManager`
   - Move `globals::physicsManager` → `ctx.physicsManager`

6. **Main game loop**:
   - Refactor `src/core/game.cpp`
   - Pass `EngineContext&` to `game::init()` and `game::update()`
   - Update all function signatures progressively

**Phase 1D: Update Lua Bindings (Week 3)**
1. Add `EngineContext` to Sol2 bindings
2. Update Lua scripts to receive context:
   ```lua
   -- Before
   function update(dt)
       local pos = getMousePosition()
   end
   
   -- After
   function update(ctx, dt)
       local pos = ctx:getMousePosition()
   end
   ```
3. Provide compatibility layer:
   ```cpp
   // Allow both old and new API temporarily
   lua["getMousePosition"] = []() { return g_ctx->worldMousePosition; };
   lua["ctx"] = std::ref(*g_ctx);
   ```

**Phase 1E: Deprecate Legacy Globals (Week 3)**
1. Mark all `globals::` variables with `[[deprecated]]`
2. Add compiler warnings for remaining usage
3. Document migration path in comments
4. Set deadline for complete removal (e.g., 2 months)

#### Success Metrics
- [ ] `EngineContext` class created and compiles
- [ ] At least 3 systems migrated to use context
- [ ] Game runs with both old and new API active
- [ ] No regression in functionality
- [ ] Performance overhead < 1% (measured with Tracy)

#### Files to Modify
- Create: `src/core/engine_context.hpp`, `src/core/engine_context.cpp`
- Modify: `src/main.cpp`, `src/core/globals.hpp`, `src/core/globals.cpp`
- Modify: 50+ system files incrementally (see migration order)
- Modify: `src/core/sol_bindings.cpp` (Lua bindings)

---

### Step 2: Establish Unit Testing Infrastructure
**Impact:** Prevents regressions, enables confident refactoring  
**Estimated Effort:** 1 week setup + ongoing  
**Risk Level:** Low (additive only)  

#### Current Problem
- No unit tests exist
- Only integration test in Lua (`integration_test.lua`)
- Cannot verify correctness of refactorings
- Manual testing is slow and error-prone
- No CI/CD pipeline

#### Solution: Google Test Integration

**Phase 2A: Setup Test Framework (Day 1-2)**
1. Update `CMakeLists.txt` to enable testing by default:
   ```cmake
   option(ENABLE_UNIT_TESTS "Enable unit tests" ON)
   
   if(ENABLE_UNIT_TESTS)
       # Google Test already fetched via FetchContent
       enable_testing()
       include(GoogleTest)
   endif()
   ```

2. Create test directory structure:
   ```
   tests/
     unit/
       test_engine_context.cpp
       test_color_utils.cpp
       test_math_utils.cpp
       test_component_cache.cpp
     integration/
       test_rendering_pipeline.cpp
       test_physics_integration.cpp
     mocks/
       mock_engine_context.hpp
       mock_physics_manager.hpp
       mock_audio_manager.hpp
     helpers/
       test_fixtures.hpp
       test_utils.hpp
   ```

3. Create `tests/CMakeLists.txt`:
   ```cmake
   # Unit tests
   add_executable(unit_tests
       unit/test_engine_context.cpp
       unit/test_color_utils.cpp
       # ... more tests
       ${CMAKE_SOURCE_DIR}/src/core/engine_context.cpp
       ${CMAKE_SOURCE_DIR}/src/util/color_utils.cpp
   )
   
   target_link_libraries(unit_tests PRIVATE
       gtest_main
       CommonSettings
   )
   
   gtest_discover_tests(unit_tests)
   ```

**Phase 2B: Create Mock Objects (Day 3-4)**
1. **Mock EngineContext** (`tests/mocks/mock_engine_context.hpp`):
   ```cpp
   class MockEngineContext {
   public:
       entt::registry registry;
       sol::state lua;
       
       // Mock resource maps with test data
       std::map<std::string, Texture2D> textureAtlas;
       std::map<std::string, Color> colors;
       
       MockEngineContext() {
           // Pre-populate with test data
           colors["RED"] = RED;
           colors["BLUE"] = BLUE;
       }
       
       // Helper to verify state
       bool hasTexture(const std::string& name) const {
           return textureAtlas.count(name) > 0;
       }
   };
   ```

2. **Mock PhysicsManager**:
   ```cpp
   class MockPhysicsManager : public PhysicsManager {
   public:
       // Track calls for verification
       int updateCallCount = 0;
       std::vector<entt::entity> bodiesCreated;
       
       void update(float dt) override {
           updateCallCount++;
       }
       
       void createBody(entt::entity e) override {
           bodiesCreated.push_back(e);
       }
   };
   ```

**Phase 2C: Write Initial Tests (Day 4-5)**

1. **Test EngineContext Creation** (`tests/unit/test_engine_context.cpp`):
   ```cpp
   TEST(EngineContext, CreatesValidContext) {
       auto ctx = createEngineContext("test_config.json");
       ASSERT_NE(ctx, nullptr);
       EXPECT_GT(ctx->colors.size(), 0);
       EXPECT_TRUE(ctx->lua.valid());
   }
   
   TEST(EngineContext, RegistryIsValid) {
       auto ctx = createEngineContext("test_config.json");
       auto entity = ctx->registry.create();
       EXPECT_NE(entity, entt::null);
   }
   ```

2. **Test Utility Functions** (`tests/unit/test_color_utils.cpp`):
   ```cpp
   TEST(ColorUtils, GetColorByName) {
       MockEngineContext ctx;
       auto color = util::getColor(ctx, "RED");
       EXPECT_EQ(color.r, 255);
       EXPECT_EQ(color.g, 0);
       EXPECT_EQ(color.b, 0);
   }
   
   TEST(ColorUtils, GetColorInvalid) {
       MockEngineContext ctx;
       EXPECT_THROW(util::getColor(ctx, "INVALID"), std::out_of_range);
   }
   ```

3. **Test Component Cache** (`tests/unit/test_component_cache.cpp`):
   ```cpp
   TEST(ComponentCache, StoresAndRetrievesComponents) {
       entt::registry registry;
       auto entity = registry.create();
       
       struct TestComponent { int value; };
       registry.emplace<TestComponent>(entity, 42);
       
       auto& comp = registry.get<TestComponent>(entity);
       EXPECT_EQ(comp.value, 42);
   }
   ```

**Phase 2D: Integration with Build System (Day 5)**
1. Update `Justfile` to add test command:
   ```makefile
   # Run unit tests
   test:
       cmake --build build --target unit_tests
       ./build/unit_tests --gtest_color=yes
   
   # Run tests with coverage
   test-coverage:
       cmake -DCMAKE_BUILD_TYPE=Debug -DENABLE_COVERAGE=ON -B build
       cmake --build build --target unit_tests
       ./build/unit_tests
       gcovr -r . --html --html-details -o build/coverage.html
   ```

2. Add test runner script `scripts/run_tests.sh`:
   ```bash
   #!/bin/bash
   set -e
   
   echo "Building tests..."
   cmake --build build --target unit_tests
   
   echo "Running tests..."
   ./build/unit_tests --gtest_color=yes
   
   echo "✅ All tests passed!"
   ```

**Phase 2E: CI/CD Pipeline (Future - Optional)**
1. Create `.github/workflows/tests.yml`:
   ```yaml
   name: Unit Tests
   
   on: [push, pull_request]
   
   jobs:
     test:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v3
         - name: Install dependencies
           run: sudo apt-get install -y libraylib-dev
         - name: Build
           run: cmake -B build && cmake --build build
         - name: Run tests
           run: ./build/unit_tests
   ```

#### Test Coverage Goals
- **Phase 1 (Month 1):** 20% coverage (critical utils)
- **Phase 2 (Month 2):** 40% coverage (core systems)
- **Phase 3 (Month 3):** 60% coverage (all systems)

#### Success Metrics
- [ ] Google Test integrated and compiling
- [ ] At least 10 unit tests written
- [ ] All tests passing
- [ ] Mock objects created for core systems
- [ ] Test runner script functional
- [ ] Documentation for writing new tests

#### Files to Create
- `tests/CMakeLists.txt`
- `tests/unit/test_engine_context.cpp`
- `tests/unit/test_color_utils.cpp`
- `tests/unit/test_component_cache.cpp`
- `tests/mocks/mock_engine_context.hpp`
- `scripts/run_tests.sh`

#### Files to Modify
- `CMakeLists.txt` (enable testing by default)
- `Justfile` (add test commands)

---

### Step 3: Address Memory Safety Issues
**Impact:** Prevents crashes, memory leaks, undefined behavior  
**Estimated Effort:** 3-5 days  
**Risk Level:** Medium (requires careful ownership tracking)  

#### Current Problems
1. **Manual memory management in GOAP** (`src/systems/ai/ai_system.cpp`)
   - C-style `free()` calls for `atm_names` and `act_names`
   - No RAII, risk of leaks on exceptions

2. **Raw Chipmunk2D pointers** (various files)
   - `cpBody*`, `cpShape*`, `cpConstraint*` stored without ownership tracking
   - Unclear who owns and frees these
   - Found in: `src/systems/physics/`, `src/components/`

3. **Naked `delete` calls**
   - Found in `src/systems/physics/physics_world.cpp`
   - `src/systems/chipmunk_objectivec/ChipmunkSpace.cpp`

#### Solution: RAII and Smart Pointers

**Phase 3A: GOAP Memory Safety (Day 1)**

1. **Replace C strings with std::string** in `src/systems/ai/ai_system.cpp`:
   ```cpp
   // Before
   struct actionplanner_t {
       char* atm_names[MAXATOMS];
       char* act_names[MAXACTIONS];
   };
   
   void goap_actionplanner_clear_memory(actionplanner_t *ap) {
       for (int i = 0; i < ap->numatoms; ++i) {
           free(ap->atm_names[i]);
       }
   }
   
   // After
   struct actionplanner_t {
       std::string atm_names[MAXATOMS];
       std::string act_names[MAXACTIONS];
   };
   
   void goap_actionplanner_clear_memory(actionplanner_t *ap) {
       // Automatic cleanup, no manual free needed
       for (int i = 0; i < ap->numatoms; ++i) {
           ap->atm_names[i].clear();
       }
   }
   ```

2. **Update GOAP functions to use std::string**:
   ```cpp
   // Before
   int goap_actionplanner_add_atom(actionplanner_t *ap, const char *name) {
       ap->atm_names[ap->numatoms] = strdup(name);
       return ap->numatoms++;
   }
   
   // After
   int goap_actionplanner_add_atom(actionplanner_t *ap, const std::string& name) {
       ap->atm_names[ap->numatoms] = name;
       return ap->numatoms++;
   }
   ```

3. **Test changes**:
   ```cpp
   // Add unit test
   TEST(GOAP, AddAtomNoLeak) {
       actionplanner_t planner{};
       goap_actionplanner_add_atom(&planner, "test_atom");
       EXPECT_EQ(planner.atm_names[0], "test_atom");
       // No manual cleanup needed - RAII handles it
   }
   ```

**Phase 3B: Chipmunk2D Resource Management (Day 2-3)**

1. **Create RAII wrappers** (`src/systems/physics/chipmunk_raii.hpp`):
   ```cpp
   namespace physics {
   
   // RAII wrapper for cpBody
   class Body {
       cpBody* body_ = nullptr;
   public:
       explicit Body(cpBody* body) : body_(body) {}
       
       ~Body() {
           if (body_) cpBodyFree(body_);
       }
       
       // Disable copy
       Body(const Body&) = delete;
       Body& operator=(const Body&) = delete;
       
       // Enable move
       Body(Body&& other) noexcept : body_(other.body_) {
           other.body_ = nullptr;
       }
       
       cpBody* get() const { return body_; }
       cpBody* release() { 
           auto ptr = body_; 
           body_ = nullptr; 
           return ptr; 
       }
   };
   
   // Similar wrappers for Shape, Constraint, Space
   class Shape { /* ... */ };
   class Constraint { /* ... */ };
   class Space { /* ... */ };
   
   } // namespace physics
   ```

2. **Update PhysicsManager** to use RAII wrappers:
   ```cpp
   // Before
   struct PhysicsComponent {
       cpBody* body = nullptr;
       cpShape* shape = nullptr;
   };
   
   // After
   struct PhysicsComponent {
       std::unique_ptr<physics::Body> body;
       std::unique_ptr<physics::Shape> shape;
   };
   ```

3. **Update component destruction** in `src/core/init.cpp`:
   ```cpp
   // Before
   static void onColliderDestroyed(entt::registry& R, entt::entity e) {
       auto& cc = R.get<physics::ColliderComponent>(e);
       // Manual cleanup needed
   }
   
   // After
   static void onColliderDestroyed(entt::registry& R, entt::entity e) {
       // RAII wrappers automatically clean up
   }
   ```

**Phase 3C: Audit and Fix Naked Deletes (Day 4)**

1. **Search for all delete calls**:
   ```bash
   grep -r "delete " src/ --include="*.cpp"
   ```

2. **Replace with smart pointers**:
   ```cpp
   // Before (in ChipmunkSpace.cpp)
   ~ChipmunkSpace() { 
       delete _staticBody; 
       cpSpaceFree(_space); 
   }
   
   // After
   ~ChipmunkSpace() { 
       // _staticBody is now std::unique_ptr<ChipmunkBody>
       // Automatic cleanup
   }
   ```

3. **Document ownership** in comments:
   ```cpp
   // This class OWNS the cpSpace and is responsible for freeing it
   class PhysicsWorld {
       std::unique_ptr<physics::Space> space_;  // Owned
       cpBody* staticBody_;  // Not owned, managed by space
   };
   ```

**Phase 3D: Add Sanitizer Builds (Day 5)**

1. **Update CMakeLists.txt** to add sanitizer option:
   ```cmake
   option(ENABLE_ASAN "Enable Address Sanitizer" OFF)
   
   if(ENABLE_ASAN)
       add_compile_options(-fsanitize=address -fno-omit-frame-pointer)
       add_link_options(-fsanitize=address)
   endif()
   ```

2. **Create sanitizer build profile**:
   ```bash
   # Add to Justfile
   test-asan:
       cmake -DENABLE_ASAN=ON -B build-asan
       cmake --build build-asan
       ./build-asan/unit_tests
   ```

3. **Run and fix any detected leaks**:
   ```bash
   just test-asan 2>&1 | tee asan-report.txt
   ```

#### Success Metrics
- [ ] All `free()` calls replaced with RAII
- [ ] All raw Chipmunk pointers wrapped or documented
- [ ] No leaks detected by AddressSanitizer
- [ ] Unit tests passing with sanitizers enabled
- [ ] Documentation updated with ownership rules

#### Files to Create
- `src/systems/physics/chipmunk_raii.hpp`
- `tests/unit/test_memory_safety.cpp`

#### Files to Modify
- `src/systems/ai/ai_system.cpp` (GOAP memory)
- `src/systems/physics/physics_world.cpp` (RAII wrappers)
- `src/systems/chipmunk_objectivec/ChipmunkSpace.cpp` (smart pointers)
- `src/components/physics.hpp` (update pointer types)
- `CMakeLists.txt` (add sanitizer option)

---

## 🟡 HIGH PRIORITY

### Step 4: Implement Comprehensive Error Handling
**Impact:** More robust runtime, better debugging, graceful degradation  
**Estimated Effort:** 1-2 weeks  
**Risk Level:** Low (mostly additive)  

#### Current Problems
- Only 30 try-catch blocks in entire C++ codebase
- Most errors logged but not handled
- Silent failures common (e.g., texture loading)
- No exception specifications
- Lua/C++ boundary not properly protected

#### Solution: Error Handling Policy + Implementation

**Phase 4A: Define Error Handling Policy (Day 1)**

Create `docs/guides/ERROR_HANDLING_POLICY.md`:

```markdown
# Error Handling Policy

## Principles
1. **Fail fast in development, degrade gracefully in production**
2. **Log all errors with context**
3. **Never silently ignore errors**
4. **Protect Lua/C++ boundaries**

## Error Categories

### Critical Errors (Throw Exceptions)
- Memory allocation failures
- Asset corruption
- System initialization failures
- Invalid configuration

### Recoverable Errors (Return Error Codes)
- File not found (use default)
- Network timeout (retry)
- Invalid user input (validate)

### Warnings (Log Only)
- Performance degradation
- Deprecated API usage
- Missing optional assets

## Exception Types

```cpp
namespace game_engine {

// Base exception
class EngineException : public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};

// Specific exceptions
class AssetLoadException : public EngineException { /* ... */ };
class ConfigException : public EngineException { /* ... */ };
class PhysicsException : public EngineException { /* ... */ };

} // namespace game_engine
```
```

**Phase 4B: Create Error Handling Utilities (Day 2)**

Create `src/util/error_handling.hpp`:

```cpp
namespace util {

// Result type for recoverable errors
template<typename T, typename E = std::string>
class Result {
    std::variant<T, E> data_;
    bool success_;

public:
    Result(T value) : data_(std::move(value)), success_(true) {}
    Result(E error) : data_(std::move(error)), success_(false) {}
    
    bool isOk() const { return success_; }
    bool isErr() const { return !success_; }
    
    T& value() { return std::get<T>(data_); }
    const E& error() const { return std::get<E>(data_); }
    
    // Unwrap or throw
    T valueOrThrow() const {
        if (!success_) {
            throw std::runtime_error(std::get<E>(data_));
        }
        return std::get<T>(data_);
    }
    
    // Unwrap or default
    T valueOr(T defaultValue) const {
        return success_ ? std::get<T>(data_) : defaultValue;
    }
};

// Try-catch wrapper with logging
template<typename Fn>
auto tryWithLog(Fn&& fn, const std::string& context) 
    -> Result<decltype(fn()), std::string> 
{
    try {
        return Result<decltype(fn()), std::string>(fn());
    } catch (const std::exception& e) {
        SPDLOG_ERROR("[{}] Exception: {}", context, e.what());
        return Result<decltype(fn()), std::string>(e.what());
    }
}

} // namespace util
```

**Phase 4C: Asset Loading Error Handling (Day 3-4)**

1. **Update texture loading** (`src/util/texture_utils.cpp`):
   ```cpp
   // Before
   Texture2D loadTexture(const std::string& path) {
       auto texture = LoadTexture(path.c_str());
       if (texture.id == 0) {
           SPDLOG_ERROR("Failed to load texture: {}", path);
           return texture;  // Silent failure!
       }
       return texture;
   }
   
   // After
   util::Result<Texture2D, std::string> loadTexture(const std::string& path) {
       auto texture = LoadTexture(path.c_str());
       if (texture.id == 0) {
           return util::Result<Texture2D, std::string>(
               fmt::format("Failed to load texture: {}", path)
           );
       }
       return util::Result<Texture2D, std::string>(texture);
   }
   
   // Usage with fallback
   auto result = loadTexture("missing.png");
   Texture2D texture = result.valueOr(getDefaultTexture());
   ```

2. **Update JSON loading** (`src/core/init.cpp`):
   ```cpp
   // Before
   void loadJSONData() {
       colorsJSON = loadJSON("colors.json");
       // No error checking
   }
   
   // After
   void loadJSONData() {
       auto result = util::tryWithLog([&]() {
           return loadJSON("colors.json");
       }, "Load colors.json");
       
       if (result.isErr()) {
           throw ConfigException("Failed to load critical config: colors.json");
       }
       
       colorsJSON = result.value();
   }
   ```

3. **Add shader compilation error handling** (`src/systems/shaders/`):
   ```cpp
   util::Result<Shader, std::string> loadShader(const std::string& vs, const std::string& fs) {
       Shader shader = LoadShader(vs.c_str(), fs.c_str());
       
       if (shader.id == 0) {
           return util::Result<Shader, std::string>(
               fmt::format("Shader compilation failed: {} + {}", vs, fs)
           );
       }
       
       return util::Result<Shader, std::string>(shader);
   }
   ```

**Phase 4D: Lua/C++ Boundary Protection (Day 5)**

1. **Wrap all Lua bindings with error handlers** (`src/core/sol_bindings.cpp`):
   ```cpp
   void bindCoreFunctions(sol::state& lua, EngineContext& ctx) {
       // Set error handler
       lua.set_exception_handler([](lua_State* L, sol::optional<const std::exception&> e, sol::string_view desc) {
           SPDLOG_ERROR("Lua error: {}", desc);
           if (e) {
               SPDLOG_ERROR("C++ exception: {}", e->what());
           }
           return sol::stack::push(L, desc);
       });
       
       // Bind functions with error checking
       lua["loadTexture"] = [&ctx](const std::string& path) {
           auto result = loadTexture(ctx, path);
           if (result.isErr()) {
               SPDLOG_WARN("Texture load failed, using default: {}", result.error());
               return getDefaultTexture();
           }
           return result.value();
       };
   }
   ```

2. **Add Lua call wrapper**:
   ```cpp
   template<typename... Args>
   auto safeLuaCall(sol::state& lua, const std::string& funcName, Args&&... args) 
       -> util::Result<sol::object, std::string> 
   {
       try {
           sol::protected_function func = lua[funcName];
           auto result = func(std::forward<Args>(args)...);
           
           if (!result.valid()) {
               sol::error err = result;
               return util::Result<sol::object, std::string>(err.what());
           }
           
           return util::Result<sol::object, std::string>(result);
       } catch (const std::exception& e) {
           return util::Result<sol::object, std::string>(e.what());
       }
   }
   ```

**Phase 4E: Add Error Recovery Strategies (Day 6-7)**

1. **Asset loading retry logic**:
   ```cpp
   template<typename T>
   util::Result<T, std::string> loadWithRetry(
       std::function<util::Result<T, std::string>()> loader,
       int maxRetries = 3,
       std::chrono::milliseconds delay = std::chrono::milliseconds(100)
   ) {
       for (int i = 0; i < maxRetries; ++i) {
           auto result = loader();
           if (result.isOk()) {
               return result;
           }
           
           SPDLOG_WARN("Load attempt {} failed, retrying...", i + 1);
           std::this_thread::sleep_for(delay);
       }
       
       return loader(); // Final attempt
   }
   ```

2. **Graceful degradation for shaders**:
   ```cpp
   Shader getShaderOrDefault(const std::string& name, EngineContext& ctx) {
       auto result = loadShader(ctx.getShaderPath(name));
       
       if (result.isErr()) {
           SPDLOG_WARN("Shader '{}' failed, using passthrough shader", name);
           return ctx.getPassthroughShader();
       }
       
       return result.value();
   }
   ```

3. **Configuration validation**:
   ```cpp
   void validateConfig(const json& config) {
       std::vector<std::string> errors;
       
       if (!config.contains("screenWidth")) {
           errors.push_back("Missing required field: screenWidth");
       }
       
       if (!config.contains("fonts")) {
           errors.push_back("Missing required field: fonts");
       }
       
       if (!errors.empty()) {
           throw ConfigException(fmt::format(
               "Invalid configuration:\n{}",
               fmt::join(errors, "\n")
           ));
       }
   }
   ```

**Phase 4F: Add Error Reporting System (Future - Optional)**

Create `src/util/error_reporter.hpp`:

```cpp
class ErrorReporter {
    struct ErrorEvent {
        std::string message;
        std::string context;
        std::chrono::system_clock::time_point timestamp;
        std::string stackTrace;
    };
    
    std::vector<ErrorEvent> recentErrors_;
    
public:
    void report(const std::string& message, const std::string& context);
    void saveToFile(const std::string& path);
    std::string getErrorSummary() const;
};

// Global error reporter
inline ErrorReporter g_errorReporter;
```

#### Success Metrics
- [ ] Error handling policy document created
- [ ] Result<T, E> type implemented and tested
- [ ] All asset loading uses Result type
- [ ] Lua/C++ boundary protected with error handlers
- [ ] At least 5 critical code paths have error recovery
- [ ] Error handling tested with unit tests

#### Files to Create
- `docs/guides/ERROR_HANDLING_POLICY.md`
- `src/util/error_handling.hpp`
- `src/util/error_reporter.hpp`
- `tests/unit/test_error_handling.cpp`

#### Files to Modify
- `src/util/texture_utils.cpp`
- `src/core/init.cpp`
- `src/core/sol_bindings.cpp`
- `src/systems/shaders/shader_system.cpp`

---

### Step 5: Reduce System Coupling
**Impact:** Better modularity, easier testing, clearer dependencies  
**Estimated Effort:** 2-3 weeks  
**Risk Level:** Medium (architectural changes)  

**Progress (initial event-bus rollout):**
- `EventBus` implemented header-only (deferred queue, exception-safe dispatch); owned by `EngineContext` with `globals::getEventBus()` bridging to `g_ctx` or a fallback instance.
- Core events defined (UI focus/button/scale, loading stage start/complete, `EntityCreated/Destroyed`, `MouseClicked`, `KeyPressed`, `GameStateChanged`, `AssetLoaded/Failed`, `CollisionStarted/Ended`) covering UI, lifecycle, input, asset, and physics signals.
- Input polling now publishes `KeyPressed`/`MouseClicked` via the bus and resolves `InputState` through `EngineContext` when present for incremental migration.
- Physics collision callbacks publish bus events for collision start/end while still populating collider component vectors for compatibility.
- UI/loading events added plus consumers: UI focus/button activation tracked in globals, loading stage events feed loading status, UIScale change invokes UI reflow hook, and collision events still captured for debug; deferred-dispatch tests live for the bus. Next focus is richer physics/gameplay consumers and UI nav/gamepad events.

#### Current Problems
- Circular dependencies through globals
- Every system can access every other system
- No clear boundaries between systems
- Direct function calls create tight coupling
- Difficult to isolate systems for testing

#### Solution: Event Bus + Interfaces

**Phase 5A: Create Event Bus System (Day 1-2)**

Create `src/core/event_bus.hpp`:

```cpp
namespace event_bus {

// Event base class
struct Event {
    virtual ~Event() = default;
    std::chrono::system_clock::time_point timestamp;
};

// Listener interface
template<typename EventT>
using EventListener = std::function<void(const EventT&)>;

// Event bus implementation
class EventBus {
    template<typename EventT>
    using ListenerList = std::vector<EventListener<EventT>>;
    
    std::unordered_map<std::type_index, std::any> listeners_;
    
    // Deferred events (for safety during dispatch)
    std::vector<std::pair<std::type_index, std::any>> deferredEvents_;
    bool dispatching_ = false;

public:
    // Subscribe to event type
    template<typename EventT>
    void subscribe(EventListener<EventT> listener) {
        auto& list = getListeners<EventT>();
        list.push_back(std::move(listener));
    }
    
    // Publish event immediately
    template<typename EventT>
    void publish(const EventT& event) {
        if (dispatching_) {
            // Defer if already dispatching
            deferredEvents_.emplace_back(
                std::type_index(typeid(EventT)),
                std::any(event)
            );
            return;
        }
        
        dispatching_ = true;
        auto& list = getListeners<EventT>();
        for (auto& listener : list) {
            try {
                listener(event);
            } catch (const std::exception& e) {
                SPDLOG_ERROR("Event listener exception: {}", e.what());
            }
        }
        dispatching_ = false;
        
        // Process deferred
        processDeferred();
    }
    
private:
    template<typename EventT>
    ListenerList<EventT>& getListeners() {
        auto key = std::type_index(typeid(EventT));
        
        if (!listeners_.contains(key)) {
            listeners_[key] = ListenerList<EventT>();
        }
        
        return std::any_cast<ListenerList<EventT>&>(listeners_[key]);
    }
    
    void processDeferred() {
        while (!deferredEvents_.empty()) {
            auto [type, event] = deferredEvents_.back();
            deferredEvents_.pop_back();
            
            // Re-dispatch
            // (Implementation omitted for brevity)
        }
    }
};

} // namespace event_bus
```

**Phase 5B: Define Core Events (Day 3)**

Create `src/core/events.hpp`:

```cpp
namespace events {

// Entity lifecycle
struct EntityCreated : event_bus::Event {
    entt::entity entity;
    std::string type;
};

struct EntityDestroyed : event_bus::Event {
    entt::entity entity;
};

// Input events
struct MouseClicked : event_bus::Event {
    Vector2 position;
    int button;
};

struct KeyPressed : event_bus::Event {
    int keyCode;
    bool shift, ctrl, alt;
};

// Game state events
struct GameStateChanged : event_bus::Event {
    GameState oldState;
    GameState newState;
};

// Asset events
struct AssetLoaded : event_bus::Event {
    std::string assetId;
    std::string assetType;
};

struct AssetLoadFailed : event_bus::Event {
    std::string assetId;
    std::string error;
};

// UI events
struct UIElementFocused : event_bus::Event {
    entt::entity element{entt::null};
};

struct UIButtonActivated : event_bus::Event {
    entt::entity element{entt::null};
    int button{MOUSE_LEFT_BUTTON};
};

struct UIScaleChanged : event_bus::Event {
    float scale{1.0f};
};

// Loading/progress events
struct LoadingStageStarted : event_bus::Event {
    std::string stageId;
};

struct LoadingStageCompleted : event_bus::Event {
    std::string stageId;
    bool success{true};
    std::string error;
};

// Physics events
struct CollisionStarted : event_bus::Event {
    entt::entity entityA;
    entt::entity entityB;
    Vector2 point;
};

struct CollisionEnded : event_bus::Event {
    entt::entity entityA;
    entt::entity entityB;
};

} // namespace events
```

**Phase 5C: Migrate Input System to Events (Day 4-5)**

1. **Update input system** (`src/systems/input/input_functions.cpp`):
   ```cpp
   // Before (direct calls)
   void processInput(InputState& state) {
       if (IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) {
           auto pos = GetMousePosition();
           // Directly call game logic
           game::handleMouseClick(pos);
       }
   }
   
   // After (events)
   void processInput(InputState& state, event_bus::EventBus& bus) {
       if (IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) {
           auto pos = GetMousePosition();
           bus.publish(events::MouseClicked{pos, MOUSE_LEFT_BUTTON});
       }
   }
   ```

2. **Game logic subscribes to events**:
   ```cpp
   void game::init(EngineContext& ctx) {
       // Subscribe to mouse clicks
       ctx.eventBus.subscribe<events::MouseClicked>([&ctx](const auto& event) {
           handleMouseClick(ctx, event.position);
       });
       
       // Subscribe to key presses
       ctx.eventBus.subscribe<events::KeyPressed>([&ctx](const auto& event) {
           handleKeyPress(ctx, event.keyCode);
       });
   }
   ```

**Phase 5D: Migrate Physics System to Events (Day 6-7)**

1. **Update collision detection** (`src/systems/physics/physics_world.cpp`):
   ```cpp
   // Before (direct calls)
   void handleCollision(cpBody* bodyA, cpBody* bodyB) {
       auto entityA = getEntityFromBody(bodyA);
       auto entityB = getEntityFromBody(bodyB);
       
       // Direct call to game logic
       game::onCollision(entityA, entityB);
   }
   
   // After (events)
   void handleCollision(cpBody* bodyA, cpBody* bodyB, event_bus::EventBus& bus) {
       auto entityA = getEntityFromBody(bodyA);
       auto entityB = getEntityFromBody(bodyB);
       
       bus.publish(events::CollisionStarted{entityA, entityB, getCollisionPoint()});
   }
   ```

2. **Game logic subscribes**:
   ```cpp
   ctx.eventBus.subscribe<events::CollisionStarted>([&ctx](const auto& event) {
       // Handle collision logic
       handleEntityCollision(ctx, event.entityA, event.entityB);
   });
   ```

**Phase 5E: Create System Interfaces (Day 8-10)**

Create `src/systems/interfaces/`:

1. **IAudioSystem.hpp**:
   ```cpp
   class IAudioSystem {
   public:
       virtual ~IAudioSystem() = default;
       
       virtual void playSound(const std::string& name, float volume = 1.0f) = 0;
       virtual void playMusic(const std::string& name, bool loop = true) = 0;
       virtual void stopMusic() = 0;
       virtual void setMasterVolume(float volume) = 0;
   };
   ```

2. **IPhysicsSystem.hpp**:
   ```cpp
   class IPhysicsSystem {
   public:
       virtual ~IPhysicsSystem() = default;
       
       virtual void update(float dt) = 0;
       virtual void addBody(entt::entity entity, const BodyDef& def) = 0;
       virtual void removeBody(entt::entity entity) = 0;
       virtual void setGravity(Vector2 gravity) = 0;
   };
   ```

3. **Update EngineContext to use interfaces**:
   ```cpp
   struct EngineContext {
       // ... other members ...
       
       std::unique_ptr<IAudioSystem> audio;
       std::unique_ptr<IPhysicsSystem> physics;
       event_bus::EventBus eventBus;
       
       // Systems subscribe to events
       void initSystems() {
           // Audio subscribes to sound events
           eventBus.subscribe<events::PlaySoundRequested>([this](const auto& e) {
               audio->playSound(e.soundName, e.volume);
           });
           
           // Physics subscribes to entity creation
           eventBus.subscribe<events::EntityCreated>([this](const auto& e) {
               if (registry.any_of<PhysicsComponent>(e.entity)) {
                   physics->addBody(e.entity, getBodyDef(e.entity));
               }
           });
       }
   };
   ```

**Phase 5F: Document System Boundaries (Day 11)**

Create `docs/guides/SYSTEM_ARCHITECTURE.md`:

```markdown
# System Architecture

## System Boundaries

### Core Systems
- **Engine Context**: Owns all systems, provides dependency injection
- **Event Bus**: Communication backbone, all systems use events
- **Registry**: ECS entity storage, accessed through context

### Subsystems

#### Audio System
- **Responsibilities**: Sound/music playback, volume control
- **Dependencies**: None
- **Events Published**: None
- **Events Subscribed**: `PlaySoundRequested`, `PlayMusicRequested`
- **API**: `IAudioSystem` interface

#### Physics System  
- **Responsibilities**: Physics simulation, collision detection
- **Dependencies**: Event Bus
- **Events Published**: `CollisionStarted`, `CollisionEnded`
- **Events Subscribed**: `EntityCreated`, `EntityDestroyed`
- **API**: `IPhysicsSystem` interface

#### Input System
- **Responsibilities**: Input polling, event generation
- **Dependencies**: Event Bus
- **Events Published**: `MouseClicked`, `KeyPressed`, `GamepadButtonPressed`
- **Events Subscribed**: None
- **API**: Direct function calls (no interface needed)

#### Rendering System
- **Responsibilities**: Drawing entities, shaders, layers
- **Dependencies**: Registry, Texture Atlas
- **Events Published**: None
- **Events Subscribed**: `EntityCreated` (for render setup)
- **API**: Direct function calls

## Communication Patterns

### Synchronous (Direct Calls)
Use for:
- Rendering (performance critical)
- Utility functions
- Getters/setters within same system

### Asynchronous (Events)
Use for:
- Cross-system communication
- Decoupled notifications
- Game logic triggers

### Example Flow

```
User clicks mouse
  ↓
Input System detects click
  ↓
Publishes MouseClicked event
  ↓
Game Logic subscribes, handles click
  ↓
Publishes EntityCreated event
  ↓
Physics System subscribes, creates body
  ↓
Rendering System subscribes, creates sprite
```

## Testing Strategy

Each system can be tested in isolation:

```cpp
TEST(AudioSystem, PlaySound) {
    // Mock dependencies
    MockEventBus bus;
    AudioSystemImpl audio(bus);
    
    // Test
    audio.playSound("test.wav");
    
    // Verify (no other systems involved)
    EXPECT_TRUE(audio.isPlaying("test.wav"));
}
```
```

#### Success Metrics
- [x] Event bus implemented (tests in place)
- [x] Event bus tested (unit coverage incl. deferred dispatch)
- [x] At least 10 core events defined (now 13 incl. UI and loading)
- [ ] Input system migrated to events (keyboard/mouse + UI focus/button publishing; gamepad/UI navigation subscribers still pending)
- [ ] Physics system migrated to events (collision publishing done; consumers/subscribers pending)
- [ ] At least 2 system interfaces created
- [ ] Architecture documentation complete
- [ ] System coupling reduced measurably (use tool like `include-what-you-use`)

#### Files to Create
- `src/core/event_bus.hpp`, `src/core/event_bus.cpp`
- `src/core/events.hpp`
- `src/systems/interfaces/IAudioSystem.hpp`
- `src/systems/interfaces/IPhysicsSystem.hpp`
- `docs/guides/SYSTEM_ARCHITECTURE.md`
- `tests/unit/test_event_bus.cpp`

#### Files to Modify
- `src/core/engine_context.hpp` (add event bus)
- `src/systems/input/input_functions.cpp` (use events)
- `src/systems/physics/physics_world.cpp` (use events)
- `src/core/game.cpp` (subscribe to events)

---

### Step 6: Document C++ Codebase
**Impact:** Better maintainability, easier onboarding, clearer contracts  
**Estimated Effort:** 1 week  
**Risk Level:** Low (documentation only)  

#### Current Problems
- Minimal inline C++ comments
- No Doxygen or equivalent documentation
- Public vs private unclear (everything in headers)
- No documentation of ownership semantics
- Thread-safety requirements not documented
- Initialization order not documented

#### Solution: Doxygen + Documentation Standards

**Phase 6A: Setup Doxygen (Day 1)**

1. **Install Doxygen**:
   ```bash
   # macOS
   brew install doxygen graphviz
   
   # Ubuntu
   sudo apt-get install doxygen graphviz
   ```

2. **Create Doxyfile**:
   ```bash
   doxygen -g Doxyfile
   ```

3. **Configure Doxyfile**:
   ```
   PROJECT_NAME           = "Game Engine"
   OUTPUT_DIRECTORY       = docs/doxygen
   INPUT                  = src/ include/
   RECURSIVE              = YES
   EXTRACT_ALL            = NO
   EXTRACT_PRIVATE        = YES
   GENERATE_HTML          = YES
   GENERATE_LATEX         = NO
   HAVE_DOT               = YES
   CALL_GRAPH             = YES
   CALLER_GRAPH           = YES
   ```

4. **Add to build system**:
   ```makefile
   # Add to Justfile
   docs:
       doxygen Doxyfile
       open docs/doxygen/html/index.html
   ```

**Phase 6B: Create Documentation Standards (Day 2)**

Create `docs/guides/DOCUMENTATION_STANDARDS.md`:

```markdown
# C++ Documentation Standards

## Doxygen Comment Style

### Classes
\```cpp
/**
 * @brief Brief description of what this class does.
 * 
 * Detailed description explaining purpose, usage patterns,
 * and any important invariants.
 * 
 * @note Thread-safety: [Safe/Unsafe/Conditionally safe]
 * @note Ownership: [Does it own resources? What cleanup is needed?]
 * 
 * Example:
 * @code
 * EngineContext ctx;
 * ctx.initialize();
 * @endcode
 */
class EngineContext {
    // ...
};
\```

### Functions
\```cpp
/**
 * @brief Loads a texture from disk.
 * 
 * @param path Absolute or relative path to texture file
 * @param ctx Engine context for resource management
 * 
 * @return Result containing texture or error message
 * 
 * @throws AssetLoadException if file is corrupted
 * 
 * @note This function may take 100+ms for large textures
 * @note Thread-safe: Yes (uses internal mutex)
 */
Result<Texture2D, std::string> loadTexture(
    const std::string& path, 
    EngineContext& ctx
);
\```

### Member Variables
\```cpp
class PhysicsWorld {
private:
    /// Physics space owned by this object (RAII wrapper)
    std::unique_ptr<physics::Space> space_;
    
    /// Static body not owned (managed by space_)
    cpBody* staticBody_;
    
    /// Last update timestamp in seconds
    float lastUpdateTime_;
};
\```

## Required Documentation

### All Public APIs Must Document:
- [ ] Brief description
- [ ] All parameters
- [ ] Return value
- [ ] Exceptions thrown
- [ ] Thread-safety
- [ ] Performance characteristics (if non-trivial)

### All Classes Must Document:
- [ ] Purpose and responsibility
- [ ] Ownership semantics
- [ ] Thread-safety
- [ ] Usage example
- [ ] Related classes

### All Headers Must Have:
- [ ] File comment with purpose
- [ ] Include guard explanation (if complex)
- [ ] Author/maintainer (optional)
```

**Phase 6C: Document Core Classes (Day 3-4)**

1. **Document EngineContext**:
   ```cpp
   /**
    * @file engine_context.hpp
    * @brief Core engine state and dependency injection container.
    */
   
   /**
    * @class EngineContext
    * @brief Central context object containing all engine systems and state.
    * 
    * This class owns all major subsystems (physics, audio, rendering) and
    * provides dependency injection for game code. It replaces the old
    * `globals` namespace pattern.
    * 
    * @note Thread-safety: NOT thread-safe. Should only be accessed from
    *       main game thread unless specific methods are documented as safe.
    * 
    * @note Ownership: Owns all referenced systems via unique_ptr. Systems
    *       are destroyed in reverse order of construction.
    * 
    * @note Initialization: Must call initialize() before use. Will throw
    *       EngineException on initialization failure.
    * 
    * Typical usage:
    * @code
    * auto ctx = createEngineContext("config.json");
    * ctx->initialize();
    * 
    * // Access systems
    * ctx->audio->playSound("test.wav");
    * ctx->physics->update(dt);
    * @endcode
    * 
    * @see createEngineContext()
    * @see EngineException
    */
   class EngineContext {
   public:
       /**
        * @brief Constructs engine context with given configuration.
        * 
        * @param config Configuration object loaded from JSON
        * 
        * @note Does not initialize subsystems. Call initialize() separately.
        */
       explicit EngineContext(Config config);
       
       /**
        * @brief Destructor - cleans up all owned systems.
        * 
        * Systems are destroyed in reverse order of creation to handle
        * dependencies correctly.
        */
       ~EngineContext();
       
       /**
        * @brief Initializes all subsystems.
        * 
        * This must be called before using the context. Initializes systems
        * in dependency order: event bus, physics, audio, rendering.
        * 
        * @throws EngineException if any subsystem fails to initialize
        * 
        * @note This function may take several seconds for large asset sets.
        */
       void initialize();
       
       // ... rest of class ...
   };
   ```

2. **Document PhysicsManager**:
   ```cpp
   /**
    * @class PhysicsManager
    * @brief Manages Chipmunk2D physics simulation and bodies.
    * 
    * Responsibilities:
    * - Creating/destroying physics bodies and shapes
    * - Stepping physics simulation
    * - Collision detection and callbacks
    * 
    * @note Thread-safety: NOT thread-safe. Must be called from game thread.
    * 
    * @note Ownership: Owns the cpSpace and all bodies/shapes created through
    *       this manager. Uses RAII wrappers to ensure cleanup.
    * 
    * @note Performance: update() is O(n) where n = number of active bodies.
    *       Consider spatial partitioning for >1000 bodies.
    */
   class PhysicsManager {
       // ...
   };
   ```

**Phase 6D: Document Critical Functions (Day 5)**

Focus on:
- Init functions (`init.cpp`)
- Asset loading (`texture_utils.cpp`, `animation_system.cpp`)
- Core game loop (`game.cpp`)
- Lua bindings (`sol_bindings.cpp`)

Example:

```cpp
/**
 * @brief Initializes the game engine and all subsystems.
 * 
 * Call this once at program start before any game code runs.
 * Initialization order:
 * 1. Logging system
 * 2. JSON configuration loading
 * 3. Window creation
 * 4. ImGui setup
 * 5. ECS registry
 * 6. Physics manager
 * 7. Audio system
 * 8. Asset loading
 * 
 * @param configPath Path to config.json file
 * 
 * @return Initialized EngineContext
 * 
 * @throws ConfigException if config file is invalid
 * @throws EngineException if window creation fails
 * 
 * @note This function blocks for 1-3 seconds during asset loading.
 * @note Thread-safety: NOT thread-safe (calls OpenGL functions).
 * 
 * @see EngineContext
 * @see Config
 */
std::unique_ptr<EngineContext> init::base_init(const std::string& configPath);
```

**Phase 6E: Document Ownership and Lifetimes (Day 6)**

Add comments explaining pointer ownership:

```cpp
/**
 * @struct PhysicsComponent
 * @brief Component containing physics body and shape.
 * 
 * Ownership:
 * - body: OWNED by this component (unique_ptr, auto-cleanup)
 * - shape: OWNED by this component (unique_ptr, auto-cleanup)
 * - space: NOT owned (pointer to PhysicsManager's space)
 * 
 * Lifetime:
 * - Created when entity gets PhysicsComponent
 * - Destroyed when component is removed or entity destroyed
 * - Must call PhysicsManager::removeBody() before destruction
 */
struct PhysicsComponent {
    std::unique_ptr<physics::Body> body;   ///< Owned body (RAII)
    std::unique_ptr<physics::Shape> shape; ///< Owned shape (RAII)
    cpSpace* space;                        ///< Not owned (observer pointer)
};
```

**Phase 6F: Generate and Review Documentation (Day 7)**

1. **Generate docs**:
   ```bash
   just docs
   ```

2. **Review completeness**:
   ```bash
   # Find undocumented public functions
   grep -r "^    [a-zA-Z].*(" src/**/*.hpp | grep -v "///"
   ```

3. **Add missing documentation** where needed

4. **Add documentation to README**:
   ```markdown
   ## Documentation
   
   - **Markdown Guides**: `docs/guides/`
   - **System Documentation**: `docs/systems/`
   - **API Reference**: Generate with `just docs`, open `docs/doxygen/html/index.html`
   - **Lua API**: `docs/api/`
   ```

#### Success Metrics
- [ ] Doxygen configured and generating HTML
- [ ] All public classes documented
- [ ] All public functions documented
- [ ] Ownership semantics documented
- [ ] Thread-safety documented
- [ ] At least 3 usage examples in docs

#### Files to Create
- `Doxyfile`
- `docs/guides/DOCUMENTATION_STANDARDS.md`

#### Files to Modify
- Add Doxygen comments to:
  - `src/core/engine_context.hpp`
  - `src/core/init.cpp`
  - `src/systems/physics/physics_manager.hpp`
  - `src/systems/audio/audio_manager.hpp`
  - `src/util/texture_utils.hpp`
  - 20+ other critical headers

---

## 📊 PROGRESS TRACKING

### Week-by-Week Checklist

**Week 1: Foundation**
- [ ] Create EngineContext class
- [ ] Implement parallel globals pattern
- [ ] Migrate 3 utility systems
- [ ] Setup Google Test
- [ ] Write 10 initial unit tests

**Week 2: Core Refactoring**
- [ ] Migrate audio system to context
- [ ] Migrate input system to context
- [ ] Migrate rendering to context
- [ ] Write 20 more unit tests
- [ ] Fix GOAP memory safety

**Week 3: Critical Systems**
- [ ] Migrate physics to context
- [ ] Update main game loop
- [ ] Update Lua bindings
- [ ] Wrap Chipmunk2D pointers
- [ ] Add sanitizer builds

**Week 4: Error Handling**
- [ ] Create error handling policy
- [ ] Implement Result<T,E> type
- [ ] Update asset loading
- [ ] Protect Lua/C++ boundary
- [ ] Add recovery strategies

**Week 5: Decoupling**
- [ ] Implement event bus
- [ ] Define core events
- [ ] Migrate input to events
- [ ] Migrate physics to events
- [ ] Create system interfaces

**Week 6: Documentation**
- [ ] Setup Doxygen
- [ ] Document core classes
- [ ] Document critical functions
- [ ] Document ownership
- [ ] Generate and review docs

**Week 7-8: Polish & Testing**
- [ ] Deprecate legacy globals
- [ ] Write integration tests
- [ ] Performance validation
- [ ] Bug fixes
- [ ] Update all guides

**Week 9-12: Buffer & Iteration**
- [ ] Address feedback
- [ ] Fix edge cases
- [ ] Performance tuning
- [ ] Additional tests
- [ ] Final migration

### Metrics Dashboard

Track these weekly:

| Metric | Week 0 | Week 4 | Week 8 | Goal |
|--------|--------|--------|--------|------|
| Global variable count | 200+ | 150 | 50 | 0 |
| Unit tests | 0 | 30 | 80 | 100+ |
| Test coverage | 0% | 20% | 50% | 60% |
| Systems using context | 0 | 5 | 12 | 15 |
| Memory leaks (ASAN) | ? | 5 | 0 | 0 |
| Documentation coverage | 10% | 40% | 80% | 90% |

---

## ⚠️ RISK MITIGATION

### High-Risk Areas

1. **Lua Bindings Breakage**
   - Risk: Changing C++ APIs breaks 1000+ lines of Lua
   - Mitigation: Maintain compatibility layer, gradual migration
   - Rollback: Keep old bindings active until all Lua updated

2. **Performance Regression**
   - Risk: Context passing adds overhead
   - Mitigation: Profile with Tracy before/after
   - Rollback: Optimize hot paths, use references

3. **Physics System Instability**
   - Risk: RAII wrappers interfere with Chipmunk2D
   - Mitigation: Thorough testing, keep raw pointer escape hatches
   - Rollback: Document ownership instead of enforcing

### Contingency Plans

**If Week 4 Goals Not Met:**
- Reduce scope: Focus on context + testing only
- Extend timeline by 2 weeks
- Defer error handling to Phase 2

**If Critical Bugs Emerge:**
- Pause refactoring
- Fix bugs in current state
- Add regression tests before continuing

**If Performance Degrades >5%:**
- Profile to identify bottleneck
- Optimize specific hot path
- Consider reverting that subsystem

---

## 🎯 SUCCESS CRITERIA

This refactoring is successful when:

1. **Testability**: Can write unit tests for any system in isolation
2. **No Globals**: < 10 global variables remaining (down from 200+)
3. **Memory Safety**: Zero leaks detected by AddressSanitizer
4. **Error Handling**: All asset loading has recovery strategies
5. **Documentation**: 80%+ of public APIs documented
6. **No Regressions**: All existing features still work
7. **Performance**: <2% overhead from refactoring

---

## 📚 REFERENCES

### Related Documentation
- `docs/guides/SYSTEM_ARCHITECTURE.md` (created - architecture overview snapshot)
- `docs/guides/ERROR_HANDLING_POLICY.md` (created - error handling policy)
- `docs/guides/DOCUMENTATION_STANDARDS.md` (created - C++ doc comment standards)
- `IMPLEMENTATION_SUMMARY.md` (existing - draw command optimization)

### External Resources
- [Google Test Documentation](https://google.github.io/googletest/)
- [Doxygen Manual](https://www.doxygen.nl/manual/)
- [EnTT Wiki](https://github.com/skypjack/entt/wiki)
- [Sol2 Documentation](https://sol2.readthedocs.io/)

---

**Document Version**: 1.0  
**Last Updated**: 2025-11-22  
**Status**: Draft - Ready for Review
