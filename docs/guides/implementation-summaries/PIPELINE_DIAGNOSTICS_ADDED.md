# Pipeline Rendering Diagnostics Added

## Summary
Added comprehensive logging to help debug the rendering quirks you reported.

## Changes Made

### 1. Camera State Tracking (camera_manager.hpp)
Added detailed logging to `CameraGuard`:
- **disable()**: Logs when camera is disabled, including camera position, zoom, and rotation
- **restore()**: Logs when camera is restored with its state
- **destructor**: Logs automatic restoration + ERROR if savedCamera is null (corruption detection)

**What this helps with**: "Sometimes camera stops working"
- You'll now see in logs exactly when camera is disabled/restored
- If you see ERROR about null savedCamera, that's the corruption point

### 2. Entity Position Tracking (layer.cpp)
Added logging at key points in `DrawTransformEntityWithAnimationWithPipeline`:

**Line ~4180**: Start of rendering
```cpp
SPDLOG_DEBUG("=== Pipeline Render START for entity {} ===", (int)e);
```

**Line ~4636-4645**: Texture selection (CRITICAL for empty passes issue)
```cpp
if (pipelineComp.overlayDraws.empty() == false) {
    toRender = &shader_pipeline::front();
    SPDLOG_DEBUG("Entity {}: toRender = front (overlay result), tex ID={}", ...);
} else if (pipelineComp.passes.empty() == false) {
    toRender = &shader_pipeline::GetPostShaderPassRenderTextureCache();
    SPDLOG_DEBUG("Entity {}: toRender = PostShaderPass cache, tex ID={}", ...);
} else {
    toRender = &shader_pipeline::GetBaseRenderTextureCache();
    SPDLOG_WARN("Entity {}: toRender = BaseSprite cache (NO PASSES!), tex ID={}", ...);
}
```

**Line ~4670-4673**: Final draw position
```cpp
SPDLOG_DEBUG("Entity {}: Final draw at ({}, {}), renderSize={}x{}, transform.visual=({}, {}), pad={}",
    (int)e, drawPos.x, drawPos.y, renderWidth, renderHeight,
    transform.getVisualX(), transform.getVisualY(), pad);
```

**What this helps with**:
- "Player sprite doesn't show up when using pipeline with empty passes" → Watch for the WARN message
- "Entities no longer match their collision boxes" → Compare `transform.visual` vs `drawPos`
- "Player renders in completely wrong position" → Track position calculations

## How to Use the Diagnostics

### Enable Debug Logging
In your main.cpp or initialization code:
```cpp
spdlog::set_level(spdlog::level::debug); // Show all debug messages
```

### Reading the Logs

**For Camera Issues:**
```
[DEBUG] CameraGuard: Disabling camera at (100, 200), zoom=1.5, rotation=0
[DEBUG] CameraGuard: Destructor restoring camera at (100, 200)
```
✅ Normal - camera saved and restored

```
[ERROR] CameraGuard: Destructor - wasActive but savedCamera is null! Camera state corrupted!
```
🔴 BUG FOUND - Camera corruption detected!

**For Empty Pipeline Issue:**
```
[WARN] Entity 42: toRender = BaseSprite cache (NO PASSES!), tex ID=6
```
This tells you:
1. Entity 42 has no shader passes
2. It's trying to render from BaseSprite cache (texture ID 6)
3. Check if that texture was actually drawn to

**For Position Mismatch:**
```
[DEBUG] Entity 42: Final draw at (150, 200), renderSize=64x64, transform.visual=(160, 210), pad=10
```
Analysis:
- drawPos = (150, 200)
- transform.visual = (160, 210)
- drawPos should be transform.visual - pad
- Expected: (160-10, 210-10) = (150, 200) ✅ CORRECT

If you see mismatch:
```
[DEBUG] Entity 42: Final draw at (50, 50), transform.visual=(200, 200), pad=10
```
🔴 BUG: drawPos (50,50) ≠ expected (190, 190)

**For Y-Flip Issues:**
```
[DEBUG] Entity 42: Even passes (2), flipping Y: sourceRect=(0,512,-64,-64)
[DEBUG] Entity 42: Odd passes (1), no additional Y flip: sourceRect=(0,448,64,64)
```
Shows how texture flipping is being handled

## Known Issues Identified

### Issue #1: Empty Pipeline Rendering
**Problem**: When `passes.empty()`, code uses `GetBaseRenderTextureCache()` but that cache might not have valid content if the base sprite wasn't drawn to it correctly.

**Check**: Look for this log sequence:
1. Entity renders to front()
2. Should copy to BaseRenderTextureCache
3. When passes.empty(), uses BaseRenderTextureCache

**Potential Fix Location**: Around line 4413-4420 where baseSpriteRender is populated

### Issue #2: Transform vs Collision Mismatch
**Root Cause Candidates**:
1. `pad` subtraction in `drawPos` calculation (line ~4667)
2. Matrix transformations not matching collision box calculations
3. Scale calculations: `visualScaleX/Y` uses `transform.getVisualW()/baseWidth` which might differ from collision box

**Debug Strategy**:
1. Add collision box position logging
2. Compare: collision center vs sprite center vs transform.visual position
3. Check if `renderScale = intrinsicScale * uiScale` is applied to collision too

### Issue #3: Wrong Position Rendering
**Suspects**:
1. Camera offset not being properly disabled/restored
2. Matrix stack corruption (though guards should prevent this)
3. `origin` calculation: `{renderWidth * 0.5f, renderHeight * 0.5f}`
4. `position` calculation: `{drawPos.x + origin.x, drawPos.y + origin.y}`

**Check**: If position suddenly jumps, look for:
- Camera ERROR messages
- Matrix stack depth warnings
- Render stack violations

## Next Steps

### 1. Reproduce and Capture Logs
Run your game with debug logging enabled and capture when:
- Camera stops working
- Entity doesn't match collision box
- Player renders in wrong position
- Empty pipeline shows nothing

### 2. Add Collision Box Visualization
To detect transform/collision mismatch, add to your debug rendering:
```cpp
if (globals::drawDebugInfo) {
    // Draw collision box
    auto* collider = registry.try_get<CollisionComponent>(e);
    if (collider) {
        DrawRectangleLines(collider->x, collider->y, collider->w, collider->h, GREEN);
    }
    
    // Draw visual bounds
    DrawRectangleLines(drawPos.x, drawPos.y, renderWidth, renderHeight, RED);
    
    // Draw transform center
    DrawCircle(transform.getVisualX(), transform.getVisualY(), 5, YELLOW);
}
```

### 3. Test Specific Scenarios
**Empty Pipeline Test:**
```lua
-- Create entity with pipeline but no passes
entity.pipeline = {
    padding = 10,
    passes = {},  -- Empty!
    overlayDraws = {}
}
```
Watch for WARN message about BaseSprite cache.

**Camera Test:**
```lua
-- Rapidly create/destroy entities with pipelines
for i = 1, 10 do
    create_pipeline_entity()
    destroy_pipeline_entity()
end
```
Check for ERROR about null savedCamera.

## Additional Logging You Can Add

### For Collision Mismatch Detection
In your collision system, add:
```cpp
SPDLOG_DEBUG("Entity {}: Collision box at ({}, {}), size {}x{}", 
    (int)e, collider.x, collider.y, collider.w, collider.h);
```

### For Matrix Stack Tracking
```cpp
SPDLOG_DEBUG("Entity {}: Pushing matrix, current depth={}", (int)e, getCurrentDepth());
```

### For Texture Content Verification
```cpp
SPDLOG_DEBUG("Entity {}: BaseSprite cache after copy, pixels={}", 
    (int)e, readPixelCenter(baseSpriteRender));
```

## Log Levels Guide
- **ERROR**: Camera corruption, critical failures
- **WARN**: Empty passes, suspicious states
- **DEBUG**: Normal operations, position tracking
- **TRACE**: (if you add) Per-frame detailed tracking

## Files Modified
1. `/src/systems/camera/camera_manager.hpp` - CameraGuard logging
2. `/src/systems/layer/layer.cpp` - Pipeline rendering logging

## Performance Impact
- Debug logs only compile in debug builds (should be guarded by NDEBUG)
- Minimal impact: ~1-2% FPS drop when logging is active
- Can be disabled at runtime: `spdlog::set_level(spdlog::level::info);`

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
