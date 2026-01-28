# Draft: UI Shader Integration Refactor

## Requirements (confirmed)
- Fix brittleness when multiple shaders applied to UIBox/element
- **Symptom**: Elements flip upside-down with 2+ shader-enabled UI elements
- **Use case**: Multiple UI elements (1-5), each with 1+ shaders (e.g., 5 cards with 3d_skew)
- **Solution approach**: Per-element render textures (guaranteed isolation)
- **Scale**: 1-5 concurrent shader-UI elements (per-element textures acceptable)
- **Extended scope**: Also fix ObjectAttachedToUITag conflict with shader rendering
- **Safety integration**: Use existing RenderTargetGuard & MatrixStackGuard in UI path
- **Test strategy**: Both C++ unit tests AND Lua integration tests

## Root Cause Confirmed
The Y-flip logic at `layer.cpp:1865-1870` depends on **even/odd pass count**:
- Even passes → no Y-flip
- Odd passes → Y-flip via sourceRect adjustment

When multiple UI elements share global ping/pong, the Swap() count gets corrupted between elements, causing wrong flip direction.

## Technical Decisions
- **Framework**: Custom UI system on Raylib + ImGui (debug only)
- **Architecture**: ECS-based (EnTT), split component pattern
- **Shader System**: ShaderPipelineComponent with ping-pong buffers

## Research Findings

### Root Causes of Multi-Shader Bugs (identified)

1. **Global Pipeline State Corruption** (`layer.cpp:2323-2354`)
   - Ping-pong buffers (`shader_pipeline::ping/pong`) are GLOBAL
   - Multiple UI elements with shaders share and corrupt each other's state
   - FIXME in code: "TODO: this gets overwritten by the next overlay draw"

2. **Texture Rectangle State Corruption** (`layer.cpp:2339-2346`)
   - Source rect depends on `front().texture.height` 
   - After `Swap()`, texture IDs change but height may mismatch
   - Causes out-of-bounds access, crashes on Metal backend

3. **Render Target Stack Mismanagement**
   - Each pass does push/pop, but disabled passes cause imbalance
   - No validation of push/pop balance per-shader
   - Stack overflow at 16+ entries documented in SAFETY_GUIDE

4. **Child Inclusion State Bug** (`layer.cpp:2332`)
   - `includeChildrenInShaderPass` is per-element, not per-shader
   - Children rendered through BOTH shader passes = visual doubling

5. **Overlay Input Source Ambiguity** (`layer.cpp:2389-2426`)
   - `postPassRT` set AFTER all passes, but overlays read it during
   - TODO comment: "this gets overwritten by next overlay draw"

6. **Uniform State Leakage** (`layer.cpp:1808-1815`)
   - Global uniforms from pass 1 not cleared before pass 2
   - Leftover state causes visual corruption

7. **Matrix Stack Management**
   - Single matrix for entire slice, reused across shader passes
   - SAFETY_GUIDE: overflow at 32 entries

### Key Files
- `src/systems/layer/layer.cpp:2214-2427` - Multi-shader rendering
- `src/systems/ui/box.cpp:2324-2368` - UI shader detection/routing
- `src/systems/shaders/shader_pipeline.hpp` - Global ping-pong state
- `docs/guides/implementation-summaries/SHADER_PIPELINE_SAFETY_GUIDE.md`

### Known Workarounds (from SAFETY_GUIDE)
- Only render ONE entity with pipeline per frame (Issue #7)
- Only resize pipeline when no entities rendering (Issue #3)
- Use `RenderTargetGuard`, `MatrixStackGuard`, `SafeDrawTextureRec()`

### ObjectAttachedToUITag Conflict
- "DO NOT add ObjectAttachedToUITag to cards with shaders - breaks rendering!"
- Documented in UI_PANEL_IMPLEMENTATION_GUIDE.md lines 526, 1000

## Open Questions
- What specific multi-shader scenarios are failing?
- Should we fix the global state issue or redesign architecture?
- What's the acceptable performance tradeoff for isolation?
- How many concurrent shader-UI elements do you need?

## Scope Boundaries
- INCLUDE: *TBD*
- EXCLUDE: *TBD*

## Architecture Details

### Current Global State (shader_pipeline.hpp:112-124)
```cpp
inline RenderTexture2D ping = {};
inline RenderTexture2D pong = {};
inline int width = 0;
inline int height = 0;
inline RenderTexture2D* lastRenderTarget = nullptr;
inline Rectangle lastRenderRect = {0, 0, 0, 0};
inline RenderTexture2D baseCache = {};
inline bool baseCacheValid = false;
inline RenderTexture2D postPassCache = {};
inline bool postPassCacheValid = false;
```

### Safety Tools Available (but NOT used in UI path)
- `RenderTargetGuard` - RAII for Begin/EndTextureMode
- `MatrixStackGuard` - RAII for rlPush/PopMatrix
- `SafeDrawTextureRec()` - Bounds-checked drawing
- `ValidateTextureRect()` - Texture bounds validation

### Known Workaround (from SAFETY_GUIDE)
- "Only render ONE entity with pipeline per frame" - Not acceptable for UI

### SAFETY_GUIDE Issue #7 Status
"Global Pipeline State - NOT FIXED YET (requires major refactoring)"
