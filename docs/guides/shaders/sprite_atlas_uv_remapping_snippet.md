# GLSL Sprite Sheet UV Remapping Snippet

This is a reusable GLSL 330 Core snippet for working with **sprite sheets (texture atlases)**. It allows you to extract a specific sprite from a larger texture using UV manipulation in the **fragment shader**.

---

## 🔧 Uniforms Explained

```glsl
uniform vec2 uImageSize;
```
- Represents the full size of the sprite sheet (in pixels or texels).
- Example: If your sprite sheet is 1024x1024, pass in `vec2(1024.0, 1024.0)`.

```glsl
uniform vec4 uSpriteRect;
```
- Defines the location and size of the sprite in the atlas.
- Format: `vec4(offsetX, offsetY, width, height)` in texels.
- Example: A 64x64 sprite at (128, 256) would be `vec4(128.0, 256.0, 64.0, 64.0)`.

---

## 🧩 UV Remapping Function

```glsl
vec2 getSpriteUV(vec2 uv) {
    // Convert normalized [0,1] UVs to pixel space
    vec2 pixelUV = uv * uImageSize;

    // Rebase to sprite-local origin by subtracting the sprite's top-left offset
    vec2 spriteLocal = pixelUV - uSpriteRect.xy;

    // Normalize within the bounds of the sprite's size
    return spriteLocal / uSpriteRect.zw;
}
```

### ✅ What It Does
- Converts input UVs (from full image space) into UVs **relative to the target sprite**.
- Makes it possible to reuse the same texture and sample different sprites via uniforms.

---

## 🧪 Example Usage (Fragment Shader)

```glsl
in vec2 fragTexCoord;
uniform sampler2D texture0;

void main() {
    vec2 localUV = getSpriteUV(fragTexCoord);
    vec4 spriteColor = texture(texture0, localUV);

    // Use `spriteColor` however you like...
    gl_FragColor = spriteColor;
}
```

---

## 🎯 Summary
- This technique lets you render one sprite out of many on a texture atlas.
- CPU code should pass the proper `uImageSize` and `uSpriteRect` to control which sprite is used.
- Keep this in the **fragment shader**, where UV sampling happens.