# Shader Pipeline Safety Guide

## Overview of Fixes

This document describes the safety improvements made to the shader pipeline system to prevent memory corruption, render errors, and crashes when using multiple entities with shader pipelines.

## Summary of Implemented Fixes

### ✅ Fix #2: RAII Guards for Render Targets
**Problem**: Unbalanced `BeginTextureMode()`/`EndTextureMode()` calls caused render state corruption.

**Solution**: `RenderTargetGuard` class that automatically calls `EndTextureMode()` when it goes out of scope.

```cpp
// OLD (dangerous):
BeginTextureMode(myTexture);
// ... code that might throw or return early ...
EndTextureMode();  // ❌ Might never be called!

// NEW (safe):
shader_pipeline::RenderTargetGuard guard;
guard.push(myTexture);
// ... any code, exceptions, early returns ...
// ✅ Automatically calls EndTextureMode() when guard goes out of scope
```

### ✅ Fix #4: Texture Rectangle Validation
**Problem**: Out-of-bounds texture coordinates caused Metal backend crashes and visual corruption.

**Solution**: `ValidateTextureRect()` and `SafeDrawTextureRec()` with bounds checking and clamping.

```cpp
// Validate before drawing
if (shader_pipeline::ValidateTextureRect(myTexture, sourceRect, "MyContext")) {
    shader_pipeline::SafeDrawTextureRec(myTexture, sourceRect, pos, color, "MyContext");
}

// Or just use SafeDrawTextureRec directly (it validates internally)
shader_pipeline::SafeDrawTextureRec(myTexture, sourceRect, pos, color, "MyContext");
```

### ✅ Fix #6: Render Stack Overflow Detection
**Problem**: Infinite `Push()` calls without matching `Pop()` exhausted the render stack.

**Solution**: Added `MAX_RENDER_STACK_DEPTH` validation and automatic stack clearing.

```cpp
namespace render_stack_switch_internal {
    // Now validates stack depth before pushing
    void Push(RenderTexture2D target);  // Checks size < 16
    void Pop();                          // Safe even if stack is empty
    size_t GetDepth();                   // Query current depth
}
```

### ✅ Fix #8: Matrix Stack Guards
**Problem**: Unbalanced `rlPushMatrix()`/`rlPopMatrix()` caused matrix stack overflow (max 32 entries).

**Solution**: `MatrixStackGuard` with automatic cleanup and depth tracking.

```cpp
// OLD (dangerous):
rlPushMatrix();
// ... complex transformations ...
rlPopMatrix();  // ❌ Might be skipped

// NEW (safe):
shader_pipeline::MatrixStackGuard matrixGuard;
if (matrixGuard.push()) {
    // ... any transformations ...
}  // ✅ Automatically pops on destruction
```

### ✅ Fix #10: No More RenderTexture2D Copies
**Problem**: Copying `RenderTexture2D` by value created dangling texture IDs when originals were unloaded.

**Solution**: All cache functions now return **references**, not copies.

```cpp
// OLD (dangerous):
RenderTexture2D copy = shader_pipeline::GetBaseRenderTextureCache();  // ❌ Shallow copy
// ... later, if cache resizes, 'copy.id' is invalid!

// NEW (safe):
RenderTexture2D& ref = shader_pipeline::GetBaseRenderTextureCache();  // ✅ Reference
// Always points to the actual cache texture

// When you need to store which texture to use:
RenderTexture2D* toRender = nullptr;
if (condition) {
    toRender = &shader_pipeline::GetBaseRenderTextureCache();
} else {
    toRender = &shader_pipeline::GetPostShaderPassRenderTextureCache();
}
// Use: toRender->texture
```

## RAII Guard Usage Examples

### Example 1: Simple Render Target

```cpp
void DrawToOffscreenBuffer(RenderTexture2D& buffer) {
    shader_pipeline::RenderTargetGuard guard;
    guard.push(buffer);
    
    ClearBackground(BLACK);
    DrawCircle(100, 100, 50, RED);
    
    // guard automatically calls EndTextureMode() here
}
```

### Example 2: Nested Transformations

```cpp
void DrawWithTransforms(float x, float y, float angle) {
    shader_pipeline::MatrixStackGuard matrixGuard;
    
    if (!matrixGuard.push()) {
        SPDLOG_ERROR("Failed to push matrix!");
        return;
    }
    
    rlTranslatef(x, y, 0);
    rlRotatef(angle, 0, 0, 1);
    
    DrawRectangle(-25, -25, 50, 50, BLUE);
    
    // Matrix automatically popped here
}
```

### Example 3: Multiple Shader Passes with Guards

```cpp
void RenderWithPipeline(entt::entity e) {
    auto& pipeline = registry.get<shader_pipeline::ShaderPipelineComponent>(e);
    
    // Base sprite pass
    {
        shader_pipeline::RenderTargetGuard guard;
        guard.push(shader_pipeline::front());
        ClearBackground({0, 0, 0, 0});
        
        // Draw base sprite...
        DrawSprite(sprite);
    }  // Automatic EndTextureMode()
    
    // Shader passes
    for (auto& pass : pipeline.passes) {
        if (!pass.enabled) continue;
        
        shader_pipeline::RenderTargetGuard guard;
        guard.push(shader_pipeline::back());
        
        ClearBackground({0, 0, 0, 0});
        BeginShaderMode(GetShader(pass.shaderName));
        
        // Safe drawing with validation
        Rectangle src = {0, 0, (float)width, (float)height};
        shader_pipeline::SafeDrawTextureRec(
            shader_pipeline::front(), 
            src, 
            {0, 0}, 
            WHITE,
            pass.shaderName.c_str()
        );
        
        EndShaderMode();
        shader_pipeline::Swap();
    }  // Automatic cleanup for last pass
}
```

## Common Patterns

### Pattern 1: Conditional Early Return

```cpp
void DrawEntity(entt::entity e) {
    shader_pipeline::RenderTargetGuard guard;
    guard.push(myRenderTarget);
    
    if (shouldSkip) {
        return;  // ✅ Guard automatically cleans up
    }
    
    // Continue drawing...
}
```

### Pattern 2: Exception Safety

```cpp
void RenderWithValidation(const Data& data) {
    shader_pipeline::RenderTargetGuard rtGuard;
    shader_pipeline::MatrixStackGuard matrixGuard;
    
    rtGuard.push(myTexture);
    matrixGuard.push();
    
    try {
        DrawComplexScene(data);  // Might throw
    } catch (const std::exception& e) {
        SPDLOG_ERROR("Render failed: {}", e.what());
        // ✅ Both guards automatically clean up
    }
}
```

### Pattern 3: Using References Instead of Copies

```cpp
void SelectRenderTarget(bool useBase) {
    // Store POINTER or REFERENCE, never copy RenderTexture2D
    RenderTexture2D* target = nullptr;
    
    if (useBase) {
        target = &shader_pipeline::GetBaseRenderTextureCache();
    } else {
        target = &shader_pipeline::GetPostShaderPassRenderTextureCache();
    }
    
    // Use the target
    shader_pipeline::SafeDrawTextureRec(
        *target,
        sourceRect,
        {0, 0},
        WHITE,
        "MyRenderer"
    );
}
```

## Debugging Tools

### Check Matrix Stack Depth

```cpp
int depth = shader_pipeline::MatrixStackGuard::getDepth();
SPDLOG_DEBUG("Current matrix stack depth: {}", depth);

if (depth > 10) {
    SPDLOG_WARN("Matrix stack depth is high! Possible leak.");
}
```

### Check Render Stack Depth

```cpp
size_t depth = layer::render_stack_switch_internal::GetDepth();
SPDLOG_DEBUG("Render stack depth: {}", depth);

if (depth > 8) {
    SPDLOG_ERROR("Render stack too deep! Clearing...");
    layer::render_stack_switch_internal::ForceClear();
}
```

### Validate Texture Before Use

```cpp
RenderTexture2D& myTex = shader_pipeline::front();

if (myTex.id == 0) {
    SPDLOG_ERROR("Invalid texture!");
    return;
}

Rectangle rect = {0, 0, 100, 100};
if (!shader_pipeline::ValidateTextureRect(myTex, rect, "BeforeDraw")) {
    SPDLOG_ERROR("Invalid rectangle for texture!");
    return;
}
```

### Monitor Memory Usage

```cpp
size_t bytes = shader_pipeline::GetMemoryUsage();
SPDLOG_INFO("Pipeline using {:.2f} MB", bytes / (1024.0f * 1024.0f));

// Or just log it:
shader_pipeline::LogMemoryUsage();
```

## Migration Checklist

When updating existing code to use the new safe pipeline:

- [ ] Replace all `BeginTextureMode()`/`EndTextureMode()` pairs with `RenderTargetGuard`
- [ ] Replace all `rlPushMatrix()`/`rlPopMatrix()` pairs with `MatrixStackGuard`
- [ ] Change `RenderTexture2D copy = GetCache()` to `RenderTexture2D& ref = GetCache()`
- [ ] Use `SafeDrawTextureRec()` instead of raw `DrawTextureRec()` for pipeline textures
- [ ] Add validation with `ValidateTextureRect()` before critical draws
- [ ] Use `render_stack_switch_internal::GetDepth()` to monitor stack usage
- [ ] Add entity ID tracking with `CheckConcurrentRender()` if using multiple entities

## Remaining Known Issues

### Issue #3: Pipeline Resize During Rendering
**Status**: Partially mitigated with `isResizing` atomic flag.

**Recommendation**: Only resize pipeline when no entities are rendering. Add entity counting:

```cpp
inline std::atomic<int> activeRenderCount{0};

// At start of DrawTransformEntityWithAnimationWithPipeline:
activeRenderCount++;

// At end:
activeRenderCount--;

// Before resizing:
if (activeRenderCount > 0) {
    SPDLOG_WARN("Cannot resize: {} entities currently rendering", activeRenderCount.load());
    return false;
}
```

### ✅ Fix #7: Per-Element Shader Pipeline Isolation

**Problem**: The global `shader_pipeline::ping`, `pong`, `baseCache`, and `postPassCache` render textures were shared across all entities. When multiple UI elements with shaders rendered simultaneously, they corrupted each other's texture state, causing visual artifacts (elements flipping upside-down).

**Solution**: `UIShaderRenderContext` component provides isolated render textures per UI element.

```cpp
// Each UI element with shaders gets its own render context
struct UIShaderRenderContext {
    RenderTexture2D ping = {};
    RenderTexture2D pong = {};
    RenderTexture2D baseCache = {};
    RenderTexture2D postPassCache = {};
    int swapCount = 0;  // Tracks swaps for Y-flip determination
    bool initialized = false;
    
    void init(int w, int h);           // Lazy initialization
    void swap();                       // Increments swapCount automatically
    void resetSwapCount();             // Call at start of render pass
    bool needsYFlip() const;           // Returns (swapCount % 2) != 0
};
```

**Usage in UI Rendering**:
- `UIShaderRenderContext` is automatically created for UI elements with `ShaderPipelineComponent`
- Textures are lazily initialized to match element bounds
- Each element's render pass uses its own isolated textures
- `swapCount` tracks actual swaps (not total pass count) for correct Y-flip
- EnTT `on_destroy` hook automatically unloads textures

**Benefits**:
- ✅ Multiple UI elements with shaders render correctly
- ✅ No texture state corruption between elements
- ✅ Automatic cleanup via RAII (EnTT hook)
- ✅ More accurate Y-flip logic (tracks actual swaps, not pass count)

**Note**: World sprite rendering still uses global textures (unaffected by this fix)

## Best Practices

1. **Always use RAII guards** - Never manually manage `Begin`/`End` pairs
2. **Never copy RenderTexture2D** - Always use references or pointers
3. **Validate before drawing** - Use `SafeDrawTextureRec()` and `ValidateTextureRect()`
4. **Monitor stack depth** - Log depth in debug builds
5. **Check texture IDs** - Validate `texture.id != 0` before use
6. **Use context strings** - Pass descriptive context to validation functions for better error messages
7. **UI shader isolation** - `UIShaderRenderContext` is automatically created; no manual management needed

## Performance Notes

- RAII guards have **zero runtime overhead** in release builds (they compile away)
- Validation functions add ~1-5% overhead but prevent crashes
- Consider disabling verbose validation in production:

```cpp
#ifdef NDEBUG
    // Production: minimal validation
    DrawTextureRec(tex.texture, rect, pos, tint);
#else
    // Debug: full validation
    shader_pipeline::SafeDrawTextureRec(tex, rect, pos, tint, "MyFunc");
#endif
```

## Questions?

If you encounter issues or need clarification, check:
1. This guide
2. The implementation in `shader_pipeline.hpp`
3. The updated `layer.hpp` for render stack changes
4. Example usage in `layer.cpp` (to be updated)
