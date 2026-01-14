---
name: debug-shader-coordinates
description: Use when shader effects appear flipped, mirrored, or mispositioned - covers RenderTexture Y-flip and coordinate system debugging
---

# Debug Shader Coordinates Skill

## When to Use

Trigger this skill when:
- Lighting/effects appear vertically flipped
- Shader positions don't match screen positions
- UV coordinates producing unexpected results
- RenderTexture-based effects have coordinate issues

## Coordinate System Reference

| System | Y Origin | Y Direction |
|--------|----------|-------------|
| Raylib Screen | Top | Down |
| OpenGL Texture | Bottom | Up |
| RenderTexture | Bottom | Up (INVERTED from screen) |

## RenderTexture Y-Flip Fix

**Problem:** RenderTextures have inverted Y compared to screen coordinates.

**Solution:** Fix in the fragment shader, NOT in Lua:

```glsl
// In fragment shader
void main() {
    // Flip Y coordinate for RenderTexture
    vec2 flippedTexCoord = vec2(fragTexCoord.x, 1.0 - fragTexCoord.y);

    // Use flipped coordinates for sampling
    vec4 color = texture(texture0, flippedTexCoord);

    // Continue with shader logic...
}
```

**Remember:** Update BOTH shader versions:
- `assets/shaders/[shader_name].fs` (desktop)
- `assets/shaders/web/[shader_name].fs` (web/emscripten)

## GLSL Function Order Fix

**Problem:** `Invalid call of undeclared identifier`

**Root Cause:** GLSL has no forward declarations. Functions must be defined BEFORE use.

```glsl
// WRONG ORDER
void main() {
    vec2 rotated = rotate2d(uv, angle);  // ERROR!
}
mat2 rotate2d(float angle) { ... }

// CORRECT ORDER
mat2 rotate2d(float angle) {
    return mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
}
void main() {
    vec2 rotated = rotate2d(uv, angle);  // Works
}
```

## Debugging Steps

### Step 1: Identify Coordinate System

```lua
-- Log positions to understand which system you're in
print("Screen mouse:", GetMouseX(), GetMouseY())  -- Raylib coords
print("World mouse:", camera_to_world(GetMouseX(), GetMouseY()))  -- After camera transform
```

### Step 2: Test Y-Flip Hypothesis

Temporarily add visual debug in shader:
```glsl
// Debug: color based on Y coordinate
gl_FragColor = vec4(fragTexCoord.y, 0.0, 0.0, 1.0);
// Red at top = normal screen coords
// Red at bottom = inverted (RenderTexture)
```

### Step 3: Check Both Shader Versions

```bash
# Ensure both desktop and web shaders are updated
diff assets/shaders/lighting_fragment.fs assets/shaders/web/lighting_fragment.fs
```

### Step 4: Verify Uniform Values

```lua
-- Check uniform values are in expected range
local uniforms = component_cache.get(entity, ShaderUniformComponent)
print("Light position uniform:", uniforms.vec2_values["lightPos"])
-- Verify: values should be in 0-1 range for normalized coords
--         or in screen pixel range for absolute coords
```

## Common Patterns

| Symptom | Likely Fix |
|---------|------------|
| Vertically flipped | Apply Y-flip in fragment shader |
| Horizontally mirrored | Check X transform signs |
| Position offset | Verify uniform coordinate space |
| Works desktop, broken web | Sync web shader file |
| "undeclared identifier" | Move function definition above usage |

## Verification

After fix, verify:
1. Effect appears at correct position
2. Orientation matches expected direction
3. Works on both desktop and web builds
