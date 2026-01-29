# ShaderBuilder API

Fluent API for attaching shaders to entities with uniform configuration.

## Basic Usage

```lua
local ShaderBuilder = require("core.shader_builder")

ShaderBuilder.for_entity(entity)
    :add("3d_skew_holo", { sheen_strength = 1.5 })
    :add("dissolve", { dissolve = 0.5 })
    :apply()
```

## Shader Families

| Family | Purpose | Examples |
|--------|---------|----------|
| `3d_skew_*` | Card shaders | `3d_skew_holo`, `3d_skew_foil` |
| `liquid_*` | Fluid effects | `liquid_ripple`, `liquid_wave` |
| `dissolve` | Dissolve/appear | `dissolve` |

## Common Uniforms

```lua
-- 3d_skew_holo
{ sheen_strength = 1.5, holo_intensity = 0.8 }

-- dissolve
{ dissolve = 0.5 }  -- 0.0 = fully visible, 1.0 = fully dissolved
```

## RenderTexture Y-Coordinate Handling

RenderTextures have inverted Y coordinates (Raylib Y=0 at top, OpenGL Y=0 at bottom).

**Fix in fragment shader, NOT in Lua:**

```glsl
// In fragment shader
vec2 flippedTexCoord = vec2(fragTexCoord.x, 1.0 - fragTexCoord.y);
vec4 color = texture(texture0, flippedTexCoord);
```

## GLSL Function Declaration Order

GLSL has no forward declarations. Define helper functions BEFORE use:

```glsl
// WRONG
void main() {
    vec2 rotated = rotate2d(uv, angle);  // ERROR!
}
mat2 rotate2d(float angle) { ... }

// RIGHT
mat2 rotate2d(float angle) {
    return mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
}
void main() {
    vec2 rotated = rotate2d(uv, angle);  // Works
}
```

## Dual Shader Versions

Always update BOTH desktop and web shader versions:
- `assets/shaders/` - Desktop GLSL
- `assets/shaders/web/` - WebGL GLSL

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
