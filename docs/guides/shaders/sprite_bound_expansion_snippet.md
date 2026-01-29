# GLSL Expanded Sprite Transform Snippet

This GLSL 330 Core snippet provides a modular way to apply **scaling transformations around the center of a sprite**, useful for effects like shadows, hover states, or visual emphasis. The transform respects the sprite’s actual center and can apply separate scaling for special effects like shadows.

---

## 🔧 Helper Function: Scale Around Center

```glsl
vec2 scale_around_center(vec2 pos, vec2 center, float scale) {
    return center + (pos - center) * scale;
}
```

### ✅ What It Does
- Takes a 2D position `pos`.
- Scales it around a pivot point `center`.
- Allows you to expand or shrink geometry relative to its center.

---

## 🧩 Main Function: Expanded Sprite Transform

```glsl
vec4 expanded_sprite_transform(
    vec3 vertexPos,        // Position of the vertex (usually from model space)
    vec2 topLeftCorner,    // Top-left corner of the sprite in world or screen space
    vec2 size,             // Size of the sprite (width, height)
    float scale,           // Normal scale factor
    float shadowScale,     // Additional scale factor for effects like shadow inflation
    mat4 mvp               // Model-View-Projection matrix
) {
    float finalScale = max(scale, scale * shadowScale); // Choose the larger scale
    vec2 center = topLeftCorner + size * 0.5;           // Compute center of the sprite
    vec2 pos2D = scale_around_center(vertexPos.xy, center, finalScale);
    return mvp * vec4(pos2D, vertexPos.z, 1.0);         // Transform to clip space
}
```

---

## 🧪 Example Usage (Vertex Shader)

```glsl
in vec3 vertexPosition;
uniform vec2 topLeftCorner;
uniform vec2 spriteSize;
uniform float scale;
uniform float shadow_scale;
uniform mat4 mvp;

void main() {
    gl_Position = expanded_sprite_transform(vertexPosition, topLeftCorner, spriteSize, scale, shadow_scale, mvp);
}
```

---

## 🎯 Summary
- This technique enables accurate center-based sprite scaling in the vertex shader.
- It supports both regular and inflated scaling (e.g., for drop shadows or highlights).
- Easy to plug into existing shader pipelines.

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
