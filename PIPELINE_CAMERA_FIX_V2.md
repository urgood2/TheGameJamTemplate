# Shader Pipeline Camera Fix V2 - Manual Screen Space Transform

## Problem

After the initial camera restoration fix, smaller sprites (player, enemies) rendered correctly, but **larger sprites (cards) and their child draw commands (text, shapes) were not showing up or showed up only erratically**.

### Root Cause

The issue was with **coordinate space consistency**:

1. The camera was being **restored** before the final draw in `DrawTransformEntityWithAnimationWithPipeline`
2. This made the sprite render correctly in world space (good for small sprites)
3. **BUT** it left the camera active for child draw commands that followed
4. Child commands from `queueScopedTransformCompositeRender` (e.g., text on cards) were designed to draw in **local entity space**
5. With camera active, these local-space coordinates were being transformed twice:
   - Once by the entity's transform matrix
   - Again by the camera transform
6. This caused child draws to appear in completely wrong positions or not visible at all

### Why Cards Were More Affected

- Small sprites (player, enemies): Less noticeable issue, might have worked by accident
- Large sprites (cards): Larger coordinate errors, more obvious when text/shapes were mispositioned
- Child commands: Text labels and UI elements on cards were completely misplaced

## Solution

**Keep camera DISABLED throughout the entire pipeline function**, but manually apply the camera transformation to world coordinates before drawing.

### Implementation

```cpp
// Get screen-space position by manually applying camera transform
Camera2D* camera = camera_manager::Current();
Vector2 worldPos = {transform.getVisualX() - pad, transform.getVisualY() - pad};

// Manual camera transformation: screen = (world - offset) * zoom + target
Vector2 screenPos = {
  (worldPos.x - camera->offset.x) * camera->zoom + camera->target.x,
  (worldPos.y - camera->offset.y) * camera->zoom + camera->target.y
};

// Use screenPos for all subsequent rendering
```

### Transform Logic

```cpp
// Calculate screen-space center
Vector2 screenCenter = {
  screenPos.x + renderWidth * 0.5f,
  screenPos.y + renderHeight * 0.5f
};

// Translate to center in screen space
Translate(screenCenter.x, screenCenter.y);

// Apply scale and rotation
float s = transform.getVisualScaleWithHoverAndDynamicMotionReflected();
Scale(s, s);
Rotate(transform.getVisualRWithDynamicMotionAndXLeaning());

// Translate back by half the render size
Translate(-renderWidth * 0.5f, -renderHeight * 0.5f);
```

## Why This Works

1. **Render textures** are created in screen space (camera disabled) ✓
2. **Final sprite draw** uses manually-transformed screen coordinates (camera disabled) ✓
3. **Child draw commands** execute in local entity space (camera disabled) ✓
4. **Consistent coordinate space** throughout - everything in screen space ✓

## Mathematical Correctness

Camera transformation formula:
```
screen.x = (world.x - camera.offset.x) * camera.zoom + camera.target.x
screen.y = (world.y - camera.offset.y) * camera.zoom + camera.target.y
```

Where:
- `world`: Entity position in world space
- `camera.offset`: Camera position in world space
- `camera.zoom`: Camera zoom factor (usually 1.0)
- `camera.target`: Screen-space target point (usually {0, 0})
- `screen`: Resulting screen-space coordinates

## Affected Code

**File**: `src/systems/layer/layer.cpp`  
**Function**: `DrawTransformEntityWithAnimationWithPipeline`

**Changes**:
1. Removed `cameraGuard.restore()` call (line ~4667 originally)
2. Added manual camera coordinate transformation (lines ~4672-4681)
3. Changed transform calculations to use `screenPos` instead of world coordinates (lines ~4703-4718)
4. Updated debug logging to show both world and screen coordinates

## Testing

✅ Small sprites (player, enemies): Should still render correctly  
✅ Large sprites (cards): Should now render correctly  
✅ Child draw commands (text on cards): Should now render in correct local positions  
✅ Camera movement: All sprites should move correctly with camera  
✅ Entity rotation/scale: Should work correctly in screen space  

## Related Fixes

- **Fix V1** (PIPELINE_QUIRKS_FIXED.md): Initial camera restoration attempt
- **Camera Guards** (RAII_GUARDS_IMPLEMENTATION_SUMMARY.md): Safe camera state management
- **Shader Pipeline** (SHADER_PIPELINE_REFACTOR_SUMMARY.md): Original pipeline architecture

## Key Insight

The critical realization was that **child draw commands need a consistent coordinate space**. When the camera was restored for the sprite but remained active for child commands, the coordinate spaces were mismatched. By keeping the camera disabled and manually transforming world→screen, everything stays in screen space and child commands work correctly in their local entity space.
