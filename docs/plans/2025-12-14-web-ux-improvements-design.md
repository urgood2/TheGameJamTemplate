# Web UX Improvements Design

**Date:** 2025-12-14
**Branch:** `feature/web-ux-improvements`
**Target:** itch.io web builds
**Constraints:** No breaking changes to build process, same Emscripten 3.1.67

## Overview

Improve the web build experience for both players and developers:
1. Extend crash reporting with game state and better UX
2. Redesign loading screen with Balatro aesthetic
3. Fix local development server
4. Add in-browser dev console overlay

---

## 1. Crash Reporting Extensions

### Current State

Existing `crash_reporter` in `src/util/crash_reporter.cpp` provides:
- Ring buffer capturing 200 log entries
- Stack traces via `emscripten_get_callstack`
- JSON serialization with build ID, platform, timestamp
- Browser download trigger + clipboard copy
- `ShowCaptureNotification()` with Copy/Dismiss buttons

### New Fields in `Report` Struct

```cpp
// Game state (populated by callback)
std::string current_scene;
std::string player_position;      // "x,y"
int entity_count{0};
std::string lua_script_context;   // "file.lua:function_name:line"

// Web-specific (Emscripten only)
std::string browser_info;         // User agent
std::string webgl_renderer;
size_t estimated_memory_mb{0};
double session_duration_sec{0};
```

### New Callback Mechanism

```cpp
// Register game-state provider (called at capture time)
using GameStateCallback = std::function<void(Report&)>;
void SetGameStateCallback(GameStateCallback cb);
```

Lua system registers a callback that populates `lua_script_context`, `player_position`, `entity_count`, and `current_scene`.

### Notification Enhancement

Add third button to `ShowCaptureNotification()`:
- **"Report Bug"** → opens `https://chugget.itch.io/testing/community` in new tab

---

## 2. Loading Screen Redesign

### Visual Style: Balatro Aesthetic

- Pixelated, rounded rectangle containers
- Slight bloom effect (CSS glow)
- Clean minimal pixelated font
- Subtle CRT-like background (CSS scanlines, not performance heavy)
- Subtle dark gradient background

### Two-Phase Loading

```
Phase 1: WASM/Assets Download (Emscripten handles)
├── Progress: 0% → 90%
├── Text: "Downloading..."
└── Controlled by Module.setStatus

Phase 2: Game Initialization (C++/Lua)
├── Progress: 90% → 100%
├── Text: "Starting..."
└── Ends when Lua init callback fires window.gameReady()
```

### Animation Sequence

| Time | Event |
|------|-------|
| 0.0s | Splash fades in (opacity 0→1, 400ms ease-out) |
| Loading | Progress bar pulses subtly (opacity 0.8↔1.0) |
| Download complete | Text changes to "Starting..." |
| `gameReady()` fires | Splash fades out (500ms), canvas fades in simultaneously |

### Game Ready Signal

Add to Lua init callback completion:
```cpp
#ifdef __EMSCRIPTEN__
EM_ASM({ if (window.gameReady) window.gameReady(); });
#endif
```

---

## 3. Dev Tooling Fixes

### Local Server (serve_web.py)

Move `scripts/serve_web.py` to main branch with enhancements:

```python
def end_headers(self):
    # COOP/COEP headers (required for SharedArrayBuffer)
    self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
    self.send_header("Cross-Origin-Opener-Policy", "same-origin")

    # Gzip content encoding for compressed files
    if self.path.endswith('.wasm.gz'):
        self.send_header('Content-Type', 'application/wasm')
        self.send_header('Content-Encoding', 'gzip')
    if self.path.endswith('.data.gz'):
        self.send_header('Content-Type', 'application/octet-stream')
        self.send_header('Content-Encoding', 'gzip')
```

### Justfile Update

```bash
serve-web port="8080":
    python3 scripts/serve_web.py {{port}}
```

### Build Process

**Unchanged.** Same CMake, same Emscripten version, same gzip pipeline.

Optional dev-only speedups (don't affect output):
- Ninja generator instead of Make
- ccache for Emscripten

---

## 4. Dev Console Overlay

### Behavior

- Hidden by default (no visual presence)
- Toggle with backtick (`) key, F12 as secondary
- Styled to match Balatro aesthetic

### Log Buffer Structure

```
STARTUP BUFFER (preserved forever)
├── First 5000 entries
├── Captured before gameReady() fires
└── Never evicted

RUNTIME BUFFER (rolling)
├── Next 500 entries (ring buffer)
├── Oldest entries evicted when full
└── Captures ongoing gameplay logs

TOTAL: Up to 5500 entries viewable
```

### Features

- Color-coded by level (info/warn/error)
- Auto-scroll to newest
- Copy all logs button
- Clear button
- Remembers open/closed state in session storage

### Implementation

Pure JS/CSS in `minshell.html`:
- Intercepts `console.log/warn/error`
- Z-index above game canvas, below crash notification

---

## File Changes Summary

| File | Change |
|------|--------|
| `src/minshell.html` | Complete rewrite - Balatro aesthetic, animations, dev console, two-phase loading |
| `cmake/inject_snippet.html` | No change |
| `scripts/serve_web.py` | Add to main branch, add gzip Content-Encoding headers |
| `justfile` | Update serve-web recipe |
| `src/util/crash_reporter.hpp` | Add new fields to Report, add SetGameStateCallback |
| `src/util/crash_reporter.cpp` | Implement callback, browser/WebGL info, "Report Bug" button |
| `src/systems/scripting/*.cpp` | Register game state callback, call window.gameReady() |

## Unchanged

- CMakeLists.txt
- GitHub workflow
- Emscripten version (3.1.67)
- inject_snippet.html (gzip/pako mechanism)

---

## Success Criteria

1. Local `just serve-web` works identically to itch.io deployment
2. Crash reports include Lua context, entity counts, browser info
3. Loading screen has smooth fade transitions, Balatro aesthetic
4. Dev console captures 5000 startup logs, toggles with backtick
5. No changes to CI/CD or build output

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
