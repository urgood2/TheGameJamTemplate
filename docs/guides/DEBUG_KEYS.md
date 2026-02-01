# Debug Key Reference

Generated: 2026-01-09
Branch: cpp-refactor (Phase 5)

## Current Key Mappings

| Key | Location | Action |
|-----|----------|--------|
| F1 | game.cpp | Toggle ImGui |
| F2 | game.cpp | Toggle release mode |
| F3 | main.cpp | Toggle performance overlay |
| F3 | game.cpp | Toggle debug draw ⚠️ CONFLICT |
| F4 | game.cpp | Toggle physics debug |
| F5 | shader_system.cpp | Hot reload shaders |
| F7 | main.cpp | Toggle hot path analyzer |
| F8 | main.cpp | Print ECS dashboard |
| F10 | main.cpp | Capture crash report |
| F10 | game.cpp | Generate debug report ⚠️ DUPLICATE |
| ` (backtick) | game.cpp | Toggle console |

## Known Issues

### F3 Conflict
Both `main.cpp` (line 270) and `game.cpp` (line 1079) handle F3:
- main.cpp: Toggles `perf_overlay` variable
- game.cpp: Toggles `globals::drawDebugInfo`

Pressing F3 activates BOTH handlers.

### F10 Duplicate
Both files handle F10 with crash_reporter, but the code is duplicated.

## Handler Locations

### main.cpp (main loop, direct IsKeyPressed)
```cpp
// Line 270: F3 - Performance overlay
if (IsKeyPressed(KEY_F3)) {
    perf_overlay = !perf_overlay;
}

// Line 276: F7 - Hot path analyzer
if (IsKeyPressed(KEY_F7)) { ... }

// Line 303: F8 - ECS dashboard
if (IsKeyPressed(KEY_F8)) { ... }

// Line 316: F10 - Crash report
if (crash_reporter::IsEnabled() && IsKeyPressed(KEY_F10)) { ... }
```

### game.cpp (event bus handler)
```cpp
// Lines 1073-1091: F1/F2/F3/F4/F10
else if (ev.keyCode == KEY_F1) { /* ImGui toggle */ }
else if (ev.keyCode == KEY_F2) { /* Release mode */ }
else if (ev.keyCode == KEY_F3) { /* Debug draw */ }
else if (ev.keyCode == KEY_F4) { /* Physics debug */ }
else if (ev.keyCode == KEY_F10) { /* Debug report */ }
```

### shader_system.cpp
```cpp
// Line 858: F5 - Shader hot reload
if (s_hotReloadTimer > 0.5f || IsKeyPressed(KEY_F5)) { ... }
```

## Recommendations

### Short-term (Low Risk)
1. Move F3 debug draw to F11 in game.cpp to resolve conflict
2. Remove duplicate F10 handler from game.cpp

### Long-term (Phase 5 - Deferred)
1. Create `src/core/debug_keys.hpp/cpp` module
2. Register all handlers in one place
3. Add runtime key listing (`debug_keys::listHandlers()`)

## Usage Notes

- F3 performance overlay only shows in debug builds
- F5 shader reload has a 0.5s cooldown
- F10 crash reports are saved to disk
- Backtick console requires ImGui to be enabled

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
