# Raylib Shader Guide

This guide documents the requirements and best practices for creating shaders compatible with raylib for both desktop (OpenGL 3.3) and web (OpenGL ES 3.0) platforms.

## Table of Contents
1. [Required Uniforms](#required-uniforms)
2. [Desktop vs Web Differences](#desktop-vs-web-differences)
3. [Standard Vertex Shader Structure](#standard-vertex-shader-structure)
4. [Standard Fragment Shader Structure](#standard-fragment-shader-structure)
5. [Common Patterns](#common-patterns)
6. [Debugging Tips](#debugging-tips)

---

## Required Uniforms

### Vertex Shader Required Uniforms

All raylib vertex shaders **must** include:

```glsl
uniform mat4 mvp;  // Model-View-Projection matrix
```

This is the **minimum required uniform** for raylib to render geometry correctly. Without it, the shader will not display anything.

### Fragment Shader Required Uniforms

All raylib fragment shaders **must** include:

```glsl
uniform sampler2D texture0;  // Texture sampler
uniform vec4 colDiffuse;     // Tint color
```

- `texture0`: The texture being rendered (always present, even for non-textured geometry)
- `colDiffuse`: The global tint/diffuse color applied to the shader

### Optional Common Uniforms

These uniforms are commonly used but not strictly required:

```glsl
// Vertex shader
in vec3 vertexPosition;  // Vertex position
in vec2 vertexTexCoord;  // Texture coordinates
in vec3 vertexNormal;    // Vertex normal
in vec4 vertexColor;     // Vertex color

// Fragment shader
uniform vec2 resolution; // Screen/texture resolution
uniform float time;      // Time in seconds (if you set it from code)
```

---

## Desktop vs Web Differences

### Version Directive

**Desktop (OpenGL 3.3):**
```glsl
#version 330
```

**Web (OpenGL ES 3.0):**
```glsl
#version 300 es
```

### Precision Qualifiers (Web Only)

Web shaders **require** precision qualifiers for fragment shaders:

```glsl
#version 300 es
precision mediump float;  // Add this line for web fragment shaders

// Rest of shader...
```

Desktop shaders **do not** use precision qualifiers.

### Key Differences Summary

| Feature | Desktop (OpenGL 3.3) | Web (OpenGL ES 3.0) |
|---------|---------------------|---------------------|
| Version | `#version 330` | `#version 300 es` |
| Precision | Not used | Required (`precision mediump float;`) |
| Built-in functions | Full GL 3.3 support | ES 3.0 subset |
| texture() | Supported | Supported |
| texture2D() | Deprecated | Not supported (use `texture()`) |

---

## Standard Vertex Shader Structure

### Desktop Vertex Shader Template

```glsl
#version 330

// Input vertex attributes
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

// Input uniform values
uniform mat4 mvp;

// Output vertex attributes (to fragment shader)
out vec2 fragTexCoord;
out vec4 fragColor;

// NOTE: Add here your custom variables

void main()
{
    // Send vertex attributes to fragment shader
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;

    // Calculate final vertex position
    gl_Position = mvp*vec4(vertexPosition, 1.0);
}
```

### Web Vertex Shader Template

```glsl
#version 300 es

// Input vertex attributes
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

// Input uniform values
uniform mat4 mvp;

// Output vertex attributes (to fragment shader)
out vec2 fragTexCoord;
out vec4 fragColor;

// NOTE: Add here your custom variables

void main()
{
    // Send vertex attributes to fragment shader
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;

    // Calculate final vertex position
    gl_Position = mvp*vec4(vertexPosition, 1.0);
}
```

---

## Standard Fragment Shader Structure

### Desktop Fragment Shader Template

```glsl
#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Output fragment color
out vec4 finalColor;

// NOTE: Add here your custom variables

void main()
{
    // Texel color fetching from texture sampler
    vec4 texelColor = texture(texture0, fragTexCoord);

    // NOTE: Implement here your fragment shader code

    // Calculate final fragment color
    finalColor = texelColor*colDiffuse*fragColor;
}
```

### Web Fragment Shader Template

```glsl
#version 300 es
precision mediump float;  // Required for web!

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Output fragment color
out vec4 finalColor;

// NOTE: Add here your custom variables

void main()
{
    // Texel color fetching from texture sampler
    vec4 texelColor = texture(texture0, fragTexCoord);

    // NOTE: Implement here your fragment shader code

    // Calculate final fragment color
    finalColor = texelColor*colDiffuse*fragColor;
}
```

---

## Common Patterns

### 1. Time-Based Animation

Add a custom uniform for time:

```glsl
uniform float time;
```

Then set it from your code:
```c
float time = GetTime();
SetShaderValue(shader, GetShaderLocation(shader, "time"), &time, SHADER_UNIFORM_FLOAT);
```

### 2. Custom Parameters

Add uniforms for shader parameters:

```glsl
uniform float intensity;
uniform vec2 center;
uniform vec3 color;
```

### 3. Multi-Pass Effects

For complex effects, you may need multiple shader passes. See `sprite_atlas_uv_remapping_snippet.md` and `sprite_bound_expansion_snippet.md` for examples.

### 4. Alpha Blending

Always preserve alpha channel:

```glsl
finalColor = vec4(resultRGB, texelColor.a * fragColor.a);
```

---

## Debugging Tips

### Common Errors

1. **Shader doesn't display anything**
   - Check that `uniform mat4 mvp;` is present in vertex shader
   - Check that `gl_Position = mvp*vec4(vertexPosition, 1.0);` is in vertex shader

2. **Web shader fails but desktop works**
   - Add `precision mediump float;` after version directive in fragment shader
   - Check that you're using `texture()` not `texture2D()`
   - Verify version is `#version 300 es`

3. **Colors look wrong**
   - Ensure you're multiplying by `colDiffuse` and `fragColor`
   - Check alpha channel is preserved

4. **Web shader gives precision errors**
   - Add explicit precision qualifiers: `precision highp float;` or `precision mediump float;`

### Testing Shaders

1. Start with the base shader template
2. Test on desktop first
3. Create web version (change version + add precision)
4. Test on web platform
5. Add custom effects incrementally

---

## File Organization

### Directory Structure

```
assets/shaders/
├── shader_name_vertex.vs       (Desktop vertex shader)
├── shader_name_fragment.fs     (Desktop fragment shader)
└── web/
    ├── shader_name_vertex.vs   (Web vertex shader)
    └── shader_name_fragment.fs (Web fragment shader)
```

### Naming Conventions

- Vertex shaders: `*_vertex.vs` or `*.vs`
- Fragment shaders: `*_fragment.fs` or `*.fs`
- Web versions: Same name in `web/` subdirectory

### shaders.json Registry

All shaders should be registered in `shaders.json`:

```json
{
    "shader_name": {
        "vertex": "shader_name_vertex.vs",
        "fragment": "shader_name_fragment.fs",
        "web": {
            "vertex": "web/shader_name_vertex.vs",
            "fragment": "web/shader_name_fragment.fs"
        }
    }
}
```

---

## Additional Resources

- `SNIPPETS_FOR_LATER.md` - Code snippets for common effects
- `sprite_atlas_uv_remapping_snippet.md` - UV remapping techniques
- `sprite_bound_expansion_snippet.md` - Sprite boundary expansion
- `shader_web_error_msgs.md` - Common web shader error messages

---

## Quick Conversion Checklist (Desktop → Web)

- [ ] Change `#version 330` to `#version 300 es`
- [ ] Add `precision mediump float;` to fragment shader (after version)
- [ ] Test all custom uniforms work
- [ ] Verify texture sampling works
- [ ] Check alpha blending
- [ ] Test on actual web platform

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
