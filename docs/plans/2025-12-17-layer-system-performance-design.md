# Layer System Performance Optimization

**Date:** 2025-12-17
**Status:** Approved for implementation
**Target:** Reduce layer system CPU time from 28% (~7ms) to ~15% (~4ms)

## Background

Tracy profiling revealed:
- **EndDrawing/GPU sync:** 71.1% (17.6ms avg) — GPU-bound, needs separate investigation
- **Layer System + Sprites:** 28.3% (~7ms) — CPU work we can optimize
- **Average frame:** 24ms (41.5 FPS) → Target: 16.67ms (60 FPS)

This plan focuses on safe, incremental CPU-side optimizations to the layer rendering system.

---

## Optimization 1: Verify Sort Dirty Flag

**File:** `src/systems/layer/layer_command_buffer.cpp`

**Current state:** `isSorted` flag exists but may be reset unnecessarily.

**Changes:**
1. Audit all places that set `isSorted = false`
2. Ensure flag only resets when commands are actually added
3. Add Tracy zone to measure actual sort frequency

**Verification:**
```cpp
if (!layer->isSorted) {
    ZONE_SCOPED("CommandBuffer Sort");
    std::stable_sort(...);
    layer->isSorted = true;
}
```

**Risk:** Very low
**Expected gain:** ~0.3ms if redundant sorting is occurring

---

## Optimization 2: State-Aware Batching (Feature Flagged)

**Files:**
- `src/systems/layer/layer_command_buffer.hpp` — Add flag
- `src/systems/layer/layer_command_buffer.cpp` — Modify sort

**Design:**

Add global feature flag:
```cpp
// layer_command_buffer.hpp
namespace layer::layer_command_buffer {
    inline bool g_enableStateBatching = false;  // Off by default
}
```

Modify sort to group by render state within same z-level:
```cpp
const std::vector<DrawCommandV2>& GetCommandsSorted(const std::shared_ptr<Layer>& layer) {
    if (!layer->isSorted) {
        if (g_enableStateBatching) {
            std::stable_sort(layer->commands.begin(), layer->commands.end(),
                [](const DrawCommandV2& a, const DrawCommandV2& b) {
                    if (a.z != b.z) return a.z < b.z;
                    if (a.space != b.space) return a.space < b.space;
                    // Future: add shaderId, textureId comparisons
                    return false;
                });
        } else {
            std::stable_sort(layer->commands.begin(), layer->commands.end(),
                [](const DrawCommandV2& a, const DrawCommandV2& b) {
                    if (a.z != b.z) return a.z < b.z;
                    return false;
                });
        }
        layer->isSorted = true;
    }
    return layer->commands;
}
```

**Testing approach:**
1. Run with flag OFF — verify no visual changes
2. Run with flag ON — profile with Tracy
3. Visual comparison screenshots
4. If validated, enable by default

**Risk:** Low (feature flagged, off by default)
**Expected gain:** ~1.5ms from reduced camera toggles and future shader batching

---

## Optimization 3: Shader Hot-Reload Throttling

**File:** `src/systems/shaders/shader_system.cpp:716-728`

**Current state:** Checks for shader changes every frame in debug builds (1.9% overhead).

**Change:**
```cpp
auto update(float dt) -> void
{
    ZONE_SCOPED("Shaders update");

    updateAllShaderUniforms();

#ifndef __EMSCRIPTEN__
    if (!kIsReleaseBuild)
    {
        static float s_hotReloadTimer = 0.0f;
        s_hotReloadTimer += dt;

        // Throttle to every 500ms or on F5 keypress
        if (s_hotReloadTimer > 0.5f || IsKeyPressed(KEY_F5)) {
            hotReloadShaders();
            s_hotReloadTimer = 0.0f;
        }
    }
#endif
}
```

**Risk:** None (debug-only, improves dev experience)
**Expected gain:** ~0.5ms per frame in debug builds

---

## Optimization 4: Draw Call Counter (Instrumentation)

**Files:**
- `src/systems/layer/layer_optimized.hpp` — Add counter
- `src/systems/layer/layer_optimized.cpp` — Increment in dispatcher
- `src/core/game.cpp` — Log and reset

**Design:**
```cpp
// layer_optimized.hpp
namespace layer {
    inline int g_drawCallsThisFrame = 0;
}

// In dispatcher execution (layer_optimized.cpp or layer.cpp)
g_drawCallsThisFrame++;

// In game::draw() at end
#ifndef NDEBUG
if (ImGui::Begin("Performance")) {
    ImGui::Text("Draw calls: %d", layer::g_drawCallsThisFrame);
}
layer::g_drawCallsThisFrame = 0;
#endif
```

**Risk:** None (debug instrumentation only)
**Purpose:** Measure effectiveness of batching optimizations

---

## Implementation Order

| Phase | Optimization | Risk | Effort |
|-------|-------------|------|--------|
| 1 | Draw call counter | None | 30 min |
| 2 | Sort dirty flag audit | Very low | 1 hour |
| 3 | Hot-reload throttling | None | 30 min |
| 4 | State batching (flagged) | Low | 2-3 hours |

**Total estimated effort:** 4-5 hours

---

## Success Criteria

1. **Draw call count visible** in debug UI
2. **No visual regressions** with batching flag OFF
3. **Measurable improvement** with batching flag ON:
   - Tracy shows reduced time in `sprites layer` zone
   - Draw call count reduced (if shader/texture batching added later)
4. **Hot-reload still works** but doesn't impact frame time

---

## Future Optimizations (Out of Scope)

These require more invasive changes and are deferred:

1. **Shader/texture ID in DrawCommandV2** — Requires modifying command creation
2. **Instanced rendering** — Requires GPU-side changes
3. **Frustum culling** — Requires spatial awareness in command buffer
4. **GPU profiling** — Separate investigation for the 71% GPU time

---

## Rollback Plan

All changes are:
- Feature-flagged (batching)
- Debug-only (hot-reload, draw counter)
- Or audit-only (sort flag verification)

If issues arise, disable `g_enableStateBatching` flag.

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
