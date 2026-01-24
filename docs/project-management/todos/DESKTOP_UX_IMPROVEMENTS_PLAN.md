# Desktop Build UX Improvements - Implementation Plan

**Created**: 2026-01-21  
**Status**: Planning (Not Started)  
**Estimated Total Effort**: 24-40 hours

---

## Executive Summary

This plan addresses desktop build UX issues including:
- Black screen during 2-5 second initialization (PARTIALLY DONE - Phase 1 completed)
- Synchronous loading blocking the main thread
- No user-facing error notifications
- Window appearing before content is ready
- Limited startup configuration options

### Current State (After Phase 1)
- ✅ Console hidden by default
- ✅ Basic loading screen with text updates
- ✅ Splash image support (`assets/splash.png`)
- ❌ Loading is still synchronous (blocks main thread)
- ❌ No progress bar
- ❌ No error dialogs for users
- ❌ No threaded asset loading

---

## Architecture Overview

### Existing Infrastructure (Available to Leverage)

| Component | Location | Notes |
|-----------|----------|-------|
| **Taskflow Library** | `include/taskflow-master/` | Full tf::Executor, tf::Future support - currently underutilized |
| **std::thread Patterns** | `save_file_io.cpp`, `posthog_client.cpp` | Callback-queue pattern for main thread sync |
| **Startup Timer** | `src/util/startup_timer.hpp` | Phase timing with `ScopedPhase` |
| **Loading State Index** | `globals::loadingStateIndex` | Integer counter for progress tracking |
| **Modal System** | `assets/scripts/core/modal.lua` | Lua-based alert/confirm dialogs |
| **Crash Reporter** | `src/util/crash_reporter.hpp` | Captures errors, logs, system info |
| **Result<T,E>** | `src/util/error_handling.hpp` | Error handling without exceptions |

### Critical Constraints

1. **GPU Operations Must Stay on Main Thread**
   - Texture uploads (`LoadTexture`)
   - Shader compilation (`LoadShader`)
   - All OpenGL/Raylib draw calls

2. **ImGui Not Available During Early Init**
   - Use raw Raylib for loading screen
   - ImGui initialized in `imgui_init` phase

3. **Web Build Has Separate Loading**
   - `minshell.html` handles web loading
   - All desktop improvements wrapped in `#if !defined(__EMSCRIPTEN__)`

---

## Implementation Phases

### Phase 2: Progress Reporting System (4-6 hours)

**Goal**: Replace integer counter with callback-based progress system

#### 2.1 Create Progress Reporter API

**File**: `src/util/loading_progress.hpp` (NEW)

```cpp
namespace loading_progress {

struct ProgressInfo {
    std::string phase_name;
    std::string message;
    float progress;        // 0.0 - 1.0
    int current_step;
    int total_steps;
};

using ProgressCallback = std::function<void(const ProgressInfo&)>;

void setCallback(ProgressCallback cb);
void reportPhase(const std::string& phase, int current, int total, const std::string& msg = "");
void reportProgress(float progress, const std::string& msg = "");
float getProgress();
const ProgressInfo& getCurrentInfo();

} // namespace loading_progress
```

#### 2.2 Update Loading Screen to Use Progress

**File**: `src/core/init.cpp` - Modify `drawLoadingScreen()`

- Add progress bar rendering (Raylib `DrawRectangle`)
- Display percentage text
- Show current phase name
- Animate loading indicator

#### 2.3 Instrument Initialization Phases

Update `base_init()` and `startInit()` to report progress:
- `asset_scanning` (5%)
- `json_loading` (15%)
- `physics_init` (20%)
- `window_graphics_init` (25%)
- `imgui_init` (30%)
- `texture_loading` (50%)
- `animation_loading` (60%)
- `audio_init` (70%)
- `systems_init` (85%)
- `localization_init` (95%)
- Complete (100%)

**Deliverables**:
- [ ] `src/util/loading_progress.hpp`
- [ ] `src/util/loading_progress.cpp`
- [ ] Modified `drawLoadingScreen()` with progress bar
- [ ] All init phases reporting progress

---

### Phase 3: Startup Configuration (2-4 hours)

**Goal**: Make startup behavior configurable via `config.json`

#### 3.1 Extend config.json Schema

**File**: `assets/config.json`

```json
{
    "startup": {
        "show_splash": true,
        "splash_image": "splash.png",
        "splash_duration_ms": 0,
        "show_console_on_start": false,
        "show_loading_progress": true,
        "window_visible_on_start": false,
        "loading_tips": [
            "Tip: Press F3 for performance overlay",
            "Tip: Press ` for debug console",
            "Tip: Press F10 to capture debug report"
        ]
    }
}
```

#### 3.2 Apply Configuration in Init

**File**: `src/core/init.cpp`

- Read `startup` section after `loadConfigFileValues()`
- Apply `show_console_on_start` to `gui::showConsole`
- Load splash from configured path
- Optionally rotate loading tips

**Deliverables**:
- [ ] Extended `config.json` schema
- [ ] Configuration loading in `init.cpp`
- [ ] Loading tips rotation system

---

### Phase 4: Native Error Dialog System (4-6 hours)

**Goal**: Show user-facing errors without ImGui dependency

#### 4.1 Create Native Dialog API

**File**: `src/util/error_dialog.hpp` (NEW)

```cpp
namespace error_dialog {

enum class DialogType {
    Info,
    Warning,
    Error,
    Confirmation
};

struct DialogResult {
    bool confirmed;
    bool checkboxChecked;
};

// Non-blocking: queues dialog for main thread
void showAsync(DialogType type, 
               const std::string& title, 
               const std::string& message,
               std::function<void(DialogResult)> callback = nullptr);

// Blocking: shows immediately (use sparingly)
DialogResult showBlocking(DialogType type,
                         const std::string& title,
                         const std::string& message);

// Process queued dialogs (call from main loop)
void processQueue();

// Check if any dialog is currently shown
bool isDialogActive();

} // namespace error_dialog
```

#### 4.2 Implement Raylib-Based Dialog Renderer

**File**: `src/util/error_dialog.cpp` (NEW)

- Render modal overlay using Raylib primitives
- Support OK/Cancel buttons
- Keyboard navigation (Enter/Escape)
- Queue system for thread-safe dialog requests

#### 4.3 Integration Points

- Replace `SPDLOG_ERROR` in critical user-facing paths with dialog
- Show dialog on asset load failure
- Show dialog on Lua script errors (optional, configurable)
- Integrate with crash reporter for fatal errors

**Deliverables**:
- [ ] `src/util/error_dialog.hpp`
- [ ] `src/util/error_dialog.cpp`
- [ ] Integration with critical error paths
- [ ] Main loop `processQueue()` call

---

### Phase 5: Threaded Asset Loading (8-12 hours)

**Goal**: Load assets in background thread while showing responsive loading screen

#### 5.1 Identify Threadable vs Main-Thread Operations

| Operation | Thread-Safe? | Notes |
|-----------|--------------|-------|
| File I/O (read JSON, sounds) | ✅ Yes | Pure disk operations |
| JSON parsing | ✅ Yes | No GPU involvement |
| UUID generation | ✅ Yes | String operations |
| `LoadTexture()` | ❌ No | GPU upload required |
| `LoadShader()` | ❌ No | GPU compilation |
| `LoadSound()` | ⚠️ Partial | Decode yes, AudioDevice no |
| Font loading | ❌ No | Uses OpenGL |

#### 5.2 Create Threaded Loader Infrastructure

**File**: `src/util/threaded_loader.hpp` (NEW)

```cpp
namespace threaded_loader {

enum class TaskPriority { High, Normal, Low };

struct LoadTask {
    std::string id;
    std::function<void()> work;           // Background work
    std::function<void()> mainThreadWork; // GPU work (optional)
    std::function<void()> onComplete;     // Completion callback
    TaskPriority priority = TaskPriority::Normal;
};

class ThreadedLoader {
public:
    void start(int numThreads = 2);
    void stop();
    
    void enqueue(LoadTask task);
    void processMainThreadQueue();  // Call from main loop
    
    float getProgress() const;
    bool isComplete() const;
    
private:
    tf::Executor executor_;
    std::queue<std::function<void()>> mainThreadQueue_;
    std::mutex queueMutex_;
    std::atomic<int> completedTasks_{0};
    std::atomic<int> totalTasks_{0};
};

} // namespace threaded_loader
```

#### 5.3 Refactor Asset Loading Pipeline

**Phase 5.3.1**: Background JSON/UUID Loading
- Move `scanAssetsFolderAndAddAllPaths()` to background
- Move JSON parsing to background
- Queue texture/shader loading for main thread

**Phase 5.3.2**: Staged Texture Loading
- Background: Read file bytes into memory
- Main thread: Upload to GPU via `LoadTextureFromImage()`

**Phase 5.3.3**: Sound Preloading
- Background: Decode audio files
- Main thread: Register with AudioDevice

#### 5.4 Modified Init Flow

```
main() {
    // Minimal sync init
    InitWindow()
    LoadSplashImage()
    
    // Start background loading
    ThreadedLoader loader;
    loader.start();
    loader.enqueue(jsonTasks);
    loader.enqueue(assetTasks);
    
    // Loading loop (responsive)
    while (!loader.isComplete()) {
        loader.processMainThreadQueue();  // GPU uploads
        drawLoadingScreen(loader.getProgress());
        PollInputEvents();  // Keep window responsive
    }
    
    // Continue with ImGui init, game start...
}
```

**Deliverables**:
- [ ] `src/util/threaded_loader.hpp`
- [ ] `src/util/threaded_loader.cpp`
- [ ] Refactored `base_init()` with async loading
- [ ] Main thread queue processing in loading loop
- [ ] Progress integration with loading screen

---

### Phase 6: Window State Management (2-4 hours)

**Goal**: Better control over window visibility during startup

#### 6.1 Deferred Window Visibility

**Current Problem**: Window appears immediately with black screen

**Solution**: Use Raylib's `FLAG_WINDOW_HIDDEN` and show when ready

```cpp
// In base_init()
SetConfigFlags(FLAG_WINDOW_RESIZABLE | FLAG_WINDOW_HIDDEN);
InitWindow(...);

// Load splash, start background loading...

// When ready to show loading screen:
ClearWindowState(FLAG_WINDOW_HIDDEN);
```

#### 6.2 Startup Sequence Options

Add to `config.json`:
```json
{
    "startup": {
        "window_mode": "show_immediately" | "show_on_splash" | "show_when_ready"
    }
}
```

**Deliverables**:
- [ ] Window visibility control in init
- [ ] Config option for window mode
- [ ] Smooth transition from hidden to visible

---

### Phase 7: Loading Tips & Polish (2-4 hours)

**Goal**: Improve perceived loading time with engagement features

#### 7.1 Loading Tips System

- Read tips from `config.json`
- Rotate every 3-5 seconds during loading
- Fade transition between tips

#### 7.2 Animated Loading Indicator

Options:
- Spinning indicator (raylib shapes)
- Pulsing dots
- Progress bar with shimmer effect

#### 7.3 Minimum Display Time

- Configurable minimum splash duration
- Prevents jarring flash on fast loads

**Deliverables**:
- [ ] Loading tips rotation
- [ ] Animated loading indicator
- [ ] Configurable minimum display time

---

## Implementation Priority

| Phase | Priority | Effort | Impact | Dependencies |
|-------|----------|--------|--------|--------------|
| Phase 2: Progress Reporting | High | 4-6h | High | None |
| Phase 3: Startup Config | Medium | 2-4h | Medium | Phase 2 |
| Phase 4: Error Dialogs | High | 4-6h | High | None |
| Phase 5: Threaded Loading | High | 8-12h | Very High | Phase 2 |
| Phase 6: Window State | Medium | 2-4h | Medium | Phase 5 |
| Phase 7: Polish | Low | 2-4h | Medium | Phase 2, 5 |

**Recommended Order**: 2 → 4 → 5 → 3 → 6 → 7

---

## Testing Checklist

### Manual Testing
- [ ] Fast machine: Loading completes quickly, no jarring flash
- [ ] Slow machine: Progress updates smoothly, window responsive
- [ ] Missing splash.png: Graceful fallback to text-only
- [ ] Asset load failure: User sees error dialog, not crash
- [ ] Config changes: All startup options take effect
- [ ] Web build: No regressions (all changes wrapped in `#if !defined(__EMSCRIPTEN__)`)

### Automated Testing
- [ ] Unit tests for `loading_progress` module
- [ ] Unit tests for `error_dialog` queue system
- [ ] Unit tests for `threaded_loader` task management
- [ ] Integration test: Full init sequence completes

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| GPU calls from wrong thread | Medium | Crash | Strict separation, assertions |
| Deadlock in loader | Low | Hang | Timeout mechanisms, testing |
| Progress bar stuck | Medium | Bad UX | Fallback to text, timeout |
| Config breaking changes | Low | Crash | Schema validation, defaults |
| Web build regression | Low | High | Conditional compilation, CI |

---

## Files to Create/Modify

### New Files
- `src/util/loading_progress.hpp`
- `src/util/loading_progress.cpp`
- `src/util/error_dialog.hpp`
- `src/util/error_dialog.cpp`
- `src/util/threaded_loader.hpp`
- `src/util/threaded_loader.cpp`

### Modified Files
- `src/core/init.cpp` - Major refactor for async loading
- `src/core/init.hpp` - New function declarations
- `src/core/gui.cpp` - Console visibility from config
- `src/main.cpp` - Loading loop integration
- `assets/config.json` - Startup configuration section
- `CMakeLists.txt` - New source files

---

## Success Metrics

1. **Startup Time**: No increase in total time (ideally faster via parallelism)
2. **Responsiveness**: Window remains interactive during loading
3. **User Experience**: Clear progress indication, no black screen
4. **Error Handling**: Users see meaningful messages, not cryptic crashes
5. **Developer Experience**: Easy to add new loading phases

---

## Appendix: Code Snippets

### A. Taskflow Usage Pattern

```cpp
#include "taskflow/taskflow.hpp"

tf::Executor executor;
tf::Taskflow taskflow;

auto [A, B, C] = taskflow.emplace(
    []() { /* load JSON */ },
    []() { /* parse config */ },
    []() { /* scan assets */ }
);

A.precede(B);  // B depends on A

tf::Future<void> fu = executor.run(taskflow);
fu.wait();
```

### B. Thread-Safe Main Thread Queue

```cpp
std::queue<std::function<void()>> mainThreadQueue;
std::mutex queueMutex;

// From background thread:
{
    std::lock_guard<std::mutex> lock(queueMutex);
    mainThreadQueue.push([texture_data]() {
        LoadTextureFromImage(texture_data);
    });
}

// From main thread:
{
    std::lock_guard<std::mutex> lock(queueMutex);
    while (!mainThreadQueue.empty()) {
        mainThreadQueue.front()();
        mainThreadQueue.pop();
    }
}
```

### C. Progress Bar Rendering (Raylib)

```cpp
void drawProgressBar(float progress, int x, int y, int width, int height) {
    // Background
    DrawRectangle(x, y, width, height, DARKGRAY);
    
    // Fill
    int fillWidth = (int)(width * progress);
    DrawRectangle(x, y, fillWidth, height, GREEN);
    
    // Border
    DrawRectangleLines(x, y, width, height, WHITE);
    
    // Percentage text
    char text[8];
    snprintf(text, sizeof(text), "%d%%", (int)(progress * 100));
    int textWidth = MeasureText(text, 20);
    DrawText(text, x + (width - textWidth) / 2, y + (height - 20) / 2, 20, WHITE);
}
```
