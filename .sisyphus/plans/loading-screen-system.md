# Desktop Loading Screen System with Multithreading

## TL;DR

> **Quick Summary**: Replace black screen gaps during game startup with a minimalist loading screen (progress bar + stage text). Use Taskflow for background loading of thread-safe operations (JSON parsing, file scanning, localization) while keeping OpenGL operations on the main thread.
> 
> **Deliverables**:
> - New `src/systems/loading_screen/` module with thread-safe progress state
> - Upgraded loading screen renderer with progress bar and stage text
> - Refactored startup flow for async-capable initialization
> - Config option `performance.loading_threads` for thread pool size
> - All wrapped in `#ifndef __EMSCRIPTEN__` guards (desktop only)
> 
> **Estimated Effort**: Medium (3-5 days)
> **Parallel Execution**: YES - 2 waves
> **Critical Path**: Task 1 → Task 2 → Task 3 → Task 4 → Task 5 → Task 6 → Task 7

---

## Context

### Original Request
Create a comprehensive loading screen to fully replace any black screen gaps while loading the game at startup. Use multithreading. Only show on desktop builds (incompatible with web).

### Interview Summary
**Key Discussions**:
- Visual style: Minimalist (progress bar + stage text + optional spinner)
- Progress granularity: Detailed stages ("Loading textures...", "Loading sounds...")
- Timing: No minimum display time - disappear immediately when ready
- Threading config: `performance.loading_threads` in config.json
- Parallelism scope: Safe subset only (JSON, file I/O, localization)
- OpenGL operations stay on main thread

**Research Findings**:
- `GameState::LOADING_SCREEN` already exists in enum
- Taskflow library available at `include/taskflow-master/`
- Existing `globals::loadingStages` and `loadingStateIndex` for tracking
- Event bus has `LoadingStageStarted`/`LoadingStageCompleted` events
- Basic loading screen exists but just draws "Loading..." text

### Metis Review
**Identified Gaps** (addressed):
- Error handling: Added fallback to synchronous loading on thread failure
- Cancellation: Added clean shutdown handling in destructor
- uuid::add() thread safety: Will use mutex wrapper or pre-populate UUIDs
- Two-phase texture loading: Added as explicit pattern requirement
- Thread count edge cases: Added clamping and fallback logic

---

## Work Objectives

### Core Objective
Eliminate black screen gaps during desktop game startup by implementing a visually informative loading screen that renders continuously while heavy initialization occurs in background threads.

### Concrete Deliverables
- `src/systems/loading_screen/loading_screen.hpp` - Public API and types
- `src/systems/loading_screen/loading_screen.cpp` - Implementation
- `src/systems/loading_screen/loading_progress.hpp` - Thread-safe progress state
- Updated `src/main.cpp` - New startup flow with loading screen loop
- Updated `src/core/init.cpp` - Async-capable initialization functions
- Updated `assets/config.json` - New `performance.loading_threads` setting

### Definition of Done
- [ ] `just build-debug && ./build/raylib-cpp-cmake-template` shows loading screen within 100ms of window creation
- [ ] Progress bar advances as stages complete (visually verify or check logs)
- [ ] `just build-web` compiles and runs without loading screen changes (guards working)
- [ ] Setting `performance.loading_threads` to different values changes worker count (log verification)

### Must Have
- Progress bar showing load completion percentage
- Stage text showing current operation ("Loading textures...")
- Thread-safe progress updates from background workers
- Configurable thread pool size via config.json
- Platform guards for desktop-only code
- Graceful fallback to synchronous loading if threading fails

### Must NOT Have (Guardrails)
- **NO Raylib/OpenGL calls from worker threads** - GPU operations main thread only
- **NO web build changes** - All code guarded by `#ifndef __EMSCRIPTEN__`
- **NO fancy visuals** - No particles, animations, or splash images for v1
- **NO loading screen configuration** - Fixed design, no colors/themes in config
- **NO asset caching or hot-reload** - Fresh load each startup
- **NO localized loading messages** - English-only stage names
- **NO loading statistics/telemetry** - Unless explicitly requested later
- **NO registry access from workers** - entt::registry is not thread-safe

---

## Verification Strategy

### Test Decision
- **Infrastructure exists**: YES (GoogleTest in tests/unit/)
- **User wants tests**: NO (manual verification - loading screen is visual/integration-heavy)
- **Framework**: N/A
- **QA approach**: Manual verification with log-based assertions

### Automated Verification (Command-Based)

Each task includes executable verification commands. The executor will:
1. Run the command
2. Check output/exit code
3. Mark acceptance criteria as PASS/FAIL

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately):
├── Task 1: Create loading_screen module structure and thread-safe progress state
└── Task 2: Add config.json loading_threads setting

Wave 2 (After Wave 1):
├── Task 3: Implement loading screen renderer (progress bar + text)
└── Task 4: Create Taskflow executor wrapper

Wave 3 (After Wave 2):
└── Task 5: Refactor init.cpp for async-capable initialization

Wave 4 (After Wave 3):
└── Task 6: Integrate loading screen into main.cpp startup flow

Wave 5 (After Wave 4):
└── Task 7: Add platform guards and verify web build unaffected

Critical Path: 1 → 3 → 5 → 6 → 7
Parallel Speedup: ~25% faster than sequential
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 3, 4, 5 | 2 |
| 2 | None | 5 | 1 |
| 3 | 1 | 6 | 4 |
| 4 | 1 | 5 | 3 |
| 5 | 2, 4 | 6 | None |
| 6 | 3, 5 | 7 | None |
| 7 | 6 | None | None |

---

## TODOs

- [ ] 1. Create loading_screen module with thread-safe progress state

  **What to do**:
  - Create directory `src/systems/loading_screen/`
  - Create `loading_progress.hpp` with thread-safe progress state struct:
    ```cpp
    struct LoadingProgress {
        std::atomic<float> percentage{0.0f};
        std::atomic<int> currentStage{0};
        std::atomic<int> totalStages{0};
        std::mutex stageMutex;
        std::string currentStageName; // guarded by stageMutex
        std::atomic<bool> isComplete{false};
        std::atomic<bool> hasError{false};
        std::string errorMessage; // guarded by stageMutex
    };
    ```
  - Create `loading_screen.hpp` with public API:
    ```cpp
    namespace loading_screen {
        void init();
        void shutdown();
        LoadingProgress& getProgress();
        void setStage(int index, int total, const std::string& name);
        void setComplete();
        void setError(const std::string& message);
    }
    ```
  - Create `loading_screen.cpp` with static `LoadingProgress` instance

  **Must NOT do**:
  - Do NOT include any Raylib headers in progress state
  - Do NOT add any rendering code yet (that's Task 3)
  - Do NOT add Taskflow code yet (that's Task 4)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Small, focused module creation with clear specifications
  - **Skills**: [`git-master`]
    - `git-master`: For atomic commit of new module

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 2)
  - **Blocks**: Tasks 3, 4, 5
  - **Blocked By**: None (can start immediately)

  **References**:
  - `src/util/startup_timer.cpp` - Example of mutex/atomic pattern in codebase
  - `src/core/ownership.cpp` - Another threading example with mutex
  - `src/systems/sound/sound_system.hpp` - Module structure pattern to follow

  **Acceptance Criteria**:
  ```bash
  # Verify files exist
  ls src/systems/loading_screen/loading_progress.hpp && \
  ls src/systems/loading_screen/loading_screen.hpp && \
  ls src/systems/loading_screen/loading_screen.cpp && \
  echo "PASS: All loading_screen module files created"
  
  # Verify thread-safe types used
  grep -q "std::atomic" src/systems/loading_screen/loading_progress.hpp && \
  grep -q "std::mutex" src/systems/loading_screen/loading_progress.hpp && \
  echo "PASS: Thread-safe types present"
  
  # Verify no Raylib includes in progress header
  ! grep -q "raylib.h" src/systems/loading_screen/loading_progress.hpp && \
  echo "PASS: No raylib dependency in progress state"
  ```

  **Commit**: YES
  - Message: `feat(loading): add loading_screen module with thread-safe progress state`
  - Files: `src/systems/loading_screen/*`

---

- [ ] 2. Add config.json loading_threads setting

  **What to do**:
  - Add to `assets/config.json` under `performance` section:
    ```json
    "performance": {
        "enable_lazy_shader_loading": false,
        "loading_threads": 0,
        "__loading_threads_comment": "0 = auto (hardware_concurrency - 1), negative = synchronous loading"
    }
    ```
  - Document the three modes:
    - `0` or positive > hardware_concurrency: Use `hardware_concurrency - 1` (auto)
    - Positive 1-N: Use exactly N threads
    - Negative: Disable threading, use synchronous loading

  **Must NOT do**:
  - Do NOT add loading screen visual configuration (colors, etc.)
  - Do NOT add any C++ code to read this yet (that's Task 5)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple JSON edit
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 1)
  - **Blocks**: Task 5
  - **Blocked By**: None (can start immediately)

  **References**:
  - `assets/config.json:24-27` - Existing `performance` section structure

  **Acceptance Criteria**:
  ```bash
  # Verify setting exists and is valid JSON
  jq '.performance.loading_threads' assets/config.json && \
  echo "PASS: loading_threads setting exists and config is valid JSON"
  ```

  **Commit**: YES
  - Message: `config: add performance.loading_threads setting for desktop loading`
  - Files: `assets/config.json`

---

- [ ] 3. Implement loading screen renderer with progress bar and stage text

  **What to do**:
  - Add rendering functions to `loading_screen.cpp`:
    ```cpp
    namespace loading_screen {
        void render(float dt);  // Call from main loop
    }
    ```
  - Implement minimalist UI using Raylib primitives:
    - Dark background (DARKGRAY or similar)
    - Centered progress bar (e.g., 400x20 pixels)
    - Progress fill based on `LoadingProgress::percentage`
    - Stage text below bar showing `currentStageName`
    - Optional: simple spinner (rotating line or dots)
  - Use `GetScreenWidth()`/`GetScreenHeight()` for centering
  - Wrap entire render function in `#ifndef __EMSCRIPTEN__`

  **Must NOT do**:
  - Do NOT use textures or custom fonts (use Raylib defaults)
  - Do NOT add animations beyond simple spinner
  - Do NOT add transitions or fades

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: UI rendering code with visual output
  - **Skills**: [`frontend-ui-ux`]
    - `frontend-ui-ux`: For clean, centered layout

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Task 4)
  - **Blocks**: Task 6
  - **Blocked By**: Task 1

  **References**:
  - `src/main.cpp:172-177` - Existing `loadingScreenStateGameLoopRender()` to replace
  - `include/raygui.h` - Could use GuiProgressBar if desired, but raw Raylib is simpler
  - `src/systems/ui/ui.cpp` - UI rendering patterns in codebase

  **Acceptance Criteria**:
  ```bash
  # Verify render function exists
  grep -q "void render" src/systems/loading_screen/loading_screen.cpp && \
  echo "PASS: render function defined"
  
  # Verify Raylib drawing calls present
  grep -q "DrawRectangle" src/systems/loading_screen/loading_screen.cpp && \
  grep -q "DrawText" src/systems/loading_screen/loading_screen.cpp && \
  echo "PASS: Raylib drawing primitives used"
  
  # Verify platform guard
  grep -q "#ifndef __EMSCRIPTEN__" src/systems/loading_screen/loading_screen.cpp && \
  echo "PASS: Platform guard present"
  ```

  **Commit**: YES
  - Message: `feat(loading): implement loading screen renderer with progress bar`
  - Files: `src/systems/loading_screen/loading_screen.cpp`, `src/systems/loading_screen/loading_screen.hpp`

---

- [ ] 4. Create Taskflow executor wrapper for background loading

  **What to do**:
  - Add to `loading_screen.hpp`:
    ```cpp
    namespace loading_screen {
        // Initialize executor with configured thread count
        void initExecutor(int configuredThreads);
        
        // Run a task in background, updating progress when done
        void runAsync(std::function<void()> task, const std::string& stageName);
        
        // Wait for all background tasks to complete
        void waitForCompletion();
        
        // Shutdown executor
        void shutdownExecutor();
    }
    ```
  - Implement in `loading_screen.cpp`:
    - Read thread count from config (passed in)
    - Clamp to 1..hardware_concurrency-1 range
    - If negative or 0 with fallback, use synchronous mode
    - Create `tf::Executor` with configured thread count
    - Track pending tasks for `waitForCompletion()`
  - Include Taskflow header only in .cpp, not .hpp
  - Wrap in `#ifndef __EMSCRIPTEN__` guards

  **Must NOT do**:
  - Do NOT expose Taskflow types in public API
  - Do NOT add task priorities or complex scheduling
  - Do NOT add task cancellation (out of scope)

  **Recommended Agent Profile**:
  - **Category**: `ultrabrain`
    - Reason: Threading/concurrency code requires careful design
  - **Skills**: []
    - No specific skills needed, but threading expertise important

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Task 3)
  - **Blocks**: Task 5
  - **Blocked By**: Task 1

  **References**:
  - `include/taskflow-master/taskflow/core/executor.hpp` - Executor API
  - `include/taskflow-master/taskflow/taskflow.hpp` - Main include
  - `src/systems/save/save_file_io.cpp:145` - Example of std::thread usage in codebase

  **Acceptance Criteria**:
  ```bash
  # Verify Taskflow included in implementation
  grep -q "#include.*taskflow" src/systems/loading_screen/loading_screen.cpp && \
  echo "PASS: Taskflow included"
  
  # Verify executor functions exist
  grep -q "initExecutor" src/systems/loading_screen/loading_screen.cpp && \
  grep -q "runAsync" src/systems/loading_screen/loading_screen.cpp && \
  grep -q "waitForCompletion" src/systems/loading_screen/loading_screen.cpp && \
  echo "PASS: Executor wrapper functions implemented"
  
  # Verify thread count clamping
  grep -q "hardware_concurrency" src/systems/loading_screen/loading_screen.cpp && \
  echo "PASS: Hardware concurrency used for clamping"
  ```

  **Commit**: YES
  - Message: `feat(loading): add Taskflow executor wrapper for async loading`
  - Files: `src/systems/loading_screen/loading_screen.cpp`, `src/systems/loading_screen/loading_screen.hpp`

---

- [ ] 5. Refactor init.cpp for async-capable initialization

  **What to do**:
  - Create new async-aware initialization functions in `init.cpp`:
    ```cpp
    namespace init {
        // Async-safe operations (can run in background)
        void loadJSONDataAsync();      // JSON parsing only
        void scanAssetPathsAsync();    // File I/O only
        void loadLocalizationAsync();  // File I/O only
        
        // Main-thread operations (OpenGL/audio)
        void loadTexturesMainThread();
        void loadShadersMainThread();
        void loadSoundsMainThread();
        void finalizeInit();
        
        // Orchestrator for desktop
        void startInitAsync(int loadingThreads);
        
        // Keep existing for web builds
        // void startInit(); // unchanged
    }
    ```
  - Read `performance.loading_threads` from config
  - If threading enabled:
    - Call async functions via `loading_screen::runAsync()`
    - Update progress after each stage completes
    - After async tasks done, run main-thread operations
  - If threading disabled (negative config or web):
    - Fall back to existing synchronous `startInit()`
  - Wrap all async code in `#ifndef __EMSCRIPTEN__`

  **Must NOT do**:
  - Do NOT change the existing `startInit()` function signature
  - Do NOT move texture/shader/sound loading to background threads
  - Do NOT modify what data is loaded, only HOW it's loaded
  - Do NOT touch web build code paths

  **Recommended Agent Profile**:
  - **Category**: `ultrabrain`
    - Reason: Complex refactoring with threading implications
  - **Skills**: []
    - No specific skills, but init.cpp knowledge important

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (Wave 3)
  - **Blocks**: Task 6
  - **Blocked By**: Tasks 2, 4

  **References**:
  - `src/core/init.cpp:942-1006` - Existing `startInit()` function
  - `src/core/init.cpp:122-253` - `loadJSONData()` function to wrap
  - `src/core/init.cpp:63-119` - `scanAssetsFolderAndAddAllPaths()` to wrap
  - `src/core/init.cpp:910-933` - `initSystems()` with shader loading (main thread)
  - `assets/config.json` - Where to read loading_threads from

  **Acceptance Criteria**:
  ```bash
  # Verify new async functions exist
  grep -q "loadJSONDataAsync" src/core/init.cpp && \
  grep -q "startInitAsync" src/core/init.cpp && \
  echo "PASS: Async initialization functions added"
  
  # Verify config reading
  grep -q "loading_threads" src/core/init.cpp && \
  echo "PASS: Config loading_threads read"
  
  # Verify platform guards
  grep -c "#ifndef __EMSCRIPTEN__" src/core/init.cpp | grep -q "[2-9]" && \
  echo "PASS: Multiple platform guards added"
  
  # Build test
  cmake --build build --target raylib-cpp-cmake-template 2>&1 | tail -5
  echo "Build completed (check for errors above)"
  ```

  **Commit**: YES
  - Message: `feat(loading): refactor init.cpp for async-capable initialization`
  - Files: `src/core/init.cpp`, `src/core/init.hpp`

---

- [ ] 6. Integrate loading screen into main.cpp startup flow

  **What to do**:
  - Modify `main()` startup sequence:
    ```cpp
    // After base_init() and before game loop:
    #ifndef __EMSCRIPTEN__
    // Set loading screen state immediately
    globals::setCurrentGameState(GameState::LOADING_SCREEN);
    
    // Initialize loading screen system
    loading_screen::init();
    int loadingThreads = globals::configJSON["performance"]["loading_threads"];
    loading_screen::initExecutor(loadingThreads);
    
    // Start async initialization
    init::startInitAsync(loadingThreads);
    
    // Loading screen render loop (runs until init completes)
    while (!loading_screen::getProgress().isComplete && !WindowShouldClose()) {
        BeginDrawing();
        loading_screen::render(GetFrameTime());
        EndDrawing();
    }
    
    // Cleanup and transition
    loading_screen::shutdownExecutor();
    loading_screen::shutdown();
    #else
    // Web: use existing synchronous init
    init::startInit();
    #endif
    ```
  - Remove/update the existing `loadingScreenStateGameLoopRender()` or keep as fallback
  - Ensure ImGui is NOT initialized during loading (comes after)

  **Must NOT do**:
  - Do NOT initialize ImGui before loading completes
  - Do NOT change the game loop structure
  - Do NOT modify web build startup flow

  **Recommended Agent Profile**:
  - **Category**: `ultrabrain`
    - Reason: Critical integration point, main.cpp modifications
  - **Skills**: [`git-master`]
    - `git-master`: For careful commit of main.cpp changes

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (Wave 4)
  - **Blocks**: Task 7
  - **Blocked By**: Tasks 3, 5

  **References**:
  - `src/main.cpp:460-552` - Current `main()` function
  - `src/main.cpp:475-493` - Current initialization calls
  - `src/main.cpp:172-177` - Existing loading screen render (to replace/update)
  - `src/main.cpp:35-37` - Existing Emscripten guard pattern

  **Acceptance Criteria**:
  ```bash
  # Verify loading_screen includes added
  grep -q "#include.*loading_screen" src/main.cpp && \
  echo "PASS: loading_screen header included"
  
  # Verify loading screen render loop
  grep -q "loading_screen::render" src/main.cpp && \
  echo "PASS: Loading screen render call added"
  
  # Verify platform guard
  grep -B5 "loading_screen::init" src/main.cpp | grep -q "#ifndef __EMSCRIPTEN__" && \
  echo "PASS: Loading screen init guarded for desktop only"
  
  # Build and quick run test (timeout after 5 seconds)
  cmake --build build --target raylib-cpp-cmake-template && \
  timeout 5 ./build/raylib-cpp-cmake-template || true
  echo "Build and quick launch test completed"
  ```

  **Commit**: YES
  - Message: `feat(loading): integrate loading screen into main.cpp startup`
  - Files: `src/main.cpp`

---

- [ ] 7. Verify web build unaffected and finalize

  **What to do**:
  - Build web version: `just build-web`
  - Verify no Taskflow/loading_screen includes in web build
  - Verify web startup behavior unchanged
  - Run desktop build and verify:
    - Loading screen appears immediately (no black screen)
    - Progress bar advances
    - Game starts normally after loading
  - Update CMakeLists.txt if needed to add loading_screen source files
  - Add brief documentation comment to loading_screen.hpp

  **Must NOT do**:
  - Do NOT modify minshell.html or web-specific code
  - Do NOT add loading screen to web builds

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Verification and minor cleanup tasks
  - **Skills**: [`git-master`]
    - `git-master`: For final commit

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (Wave 5 - Final)
  - **Blocks**: None (final task)
  - **Blocked By**: Task 6

  **References**:
  - `CMakeLists.txt` - May need to add new source files
  - `Justfile` - Contains `build-web` recipe
  - `src/minshell.html` - Web loading screen (should NOT be modified)

  **Acceptance Criteria**:
  ```bash
  # Verify CMakeLists includes new files (if using glob, may auto-detect)
  grep -q "loading_screen" CMakeLists.txt || \
  (ls src/systems/loading_screen/*.cpp && echo "Source files exist, CMake may auto-glob")
  
  # Build desktop version
  cmake --build build --target raylib-cpp-cmake-template && \
  echo "PASS: Desktop build succeeds"
  
  # Build web version (if emsdk available)
  if command -v emcc &> /dev/null; then
    just build-web && echo "PASS: Web build succeeds"
  else
    echo "SKIP: emsdk not available, web build not tested"
  fi
  
  # Verify no taskflow in web build output (if built)
  if [ -f build-emc/index.js ]; then
    ! grep -q "taskflow" build-emc/index.js && echo "PASS: No taskflow in web build"
  fi
  ```

  **Commit**: YES
  - Message: `feat(loading): finalize desktop loading screen system`
  - Files: `CMakeLists.txt` (if modified), any final tweaks

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(loading): add loading_screen module with thread-safe progress state` | src/systems/loading_screen/* | File existence |
| 2 | `config: add performance.loading_threads setting` | assets/config.json | JSON validity |
| 3 | `feat(loading): implement loading screen renderer with progress bar` | src/systems/loading_screen/* | Build succeeds |
| 4 | `feat(loading): add Taskflow executor wrapper for async loading` | src/systems/loading_screen/* | Build succeeds |
| 5 | `feat(loading): refactor init.cpp for async-capable initialization` | src/core/init.* | Build succeeds |
| 6 | `feat(loading): integrate loading screen into main.cpp startup` | src/main.cpp | Build + launch |
| 7 | `feat(loading): finalize desktop loading screen system` | CMakeLists.txt, etc. | Full verification |

---

## Success Criteria

### Verification Commands
```bash
# 1. Build succeeds
cmake --build build --target raylib-cpp-cmake-template
# Expected: Build completes without errors

# 2. Desktop launch shows loading screen (visual check via log)
./build/raylib-cpp-cmake-template 2>&1 | head -20
# Expected: No "black screen" gap, loading stages logged

# 3. Web build unaffected (if emsdk available)
just build-web && echo "Web build OK"
# Expected: Compiles without taskflow errors

# 4. Config respected
jq '.performance.loading_threads = 2' assets/config.json > tmp && mv tmp assets/config.json
./build/raylib-cpp-cmake-template 2>&1 | grep -i "thread\|worker"
# Expected: Log shows 2 worker threads
```

### Final Checklist
- [ ] All "Must Have" present (progress bar, stage text, threading, config, guards)
- [ ] All "Must NOT Have" absent (no OpenGL from workers, no web changes, no fancy visuals)
- [ ] Desktop build: loading screen visible immediately on startup
- [ ] Web build: compiles and runs unchanged
- [ ] Config option `performance.loading_threads` functions correctly
