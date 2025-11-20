# Godot to Raylib Shader Conversion

This directory contains tools and resources for converting Godot shaders to Raylib format.

## Overview

The project needs to convert **45+ Godot shaders** from the `shader_todo.md` file to work with Raylib. This involves:

1. **Downloading** shader source code from godotshaders.com
2. **Converting** Godot GLSL syntax to Raylib GLSL syntax
3. **Creating** both desktop (OpenGL 3.3) and web (OpenGL ES 3.0) versions
4. **Testing** the converted shaders in the game

## Quick Start

### Step 1: Download Godot Shaders

Run the download script to fetch all shader source code:

```bash
cd shaders_to_build
python3 download_godot_shaders.py
```

This will:
- Read all godotshaders.com URLs from `shader_todo.md`
- Download shader source code to `godot_sources/` directory
- Create `.txt` files for any shaders that fail to download automatically

**Expected output:** ~45 `.godot` files in `godot_sources/`

### Step 2: Convert Shaders

Once downloaded, tag Claude to convert the shaders:

```
@claude please convert all the downloaded Godot shaders in shaders_to_build/godot_sources/ to Raylib format
```

Claude will convert each shader following the patterns established in `assets/shaders/`.

## Shader Conversion Rules

### Godot → Raylib Mappings

| Godot Syntax | Raylib Syntax | Notes |
|--------------|---------------|-------|
| `shader_type canvas_item` | *(removed)* | Raylib uses separate .vs/.fs files |
| `uniform sampler2D TEXTURE` | `uniform sampler2D texture0` | Raylib's default texture |
| `TEXTURE(TEXTURE, UV)` | `texture(texture0, fragTexCoord)` | Updated function name |
| `COLOR` | `fragColor` (vertex) / `finalColor` (fragment) | Context-dependent |
| `UV` | `fragTexCoord` | Interpolated texture coordinates |
| `TIME` | `uniform float time` | Must be passed as uniform |
| `SCREEN_TEXTURE` | *(requires special handling)* | Needs render-to-texture setup |
| `vec2 SCREEN_PIXEL_SIZE` | *(calculate from resolution)* | Pass as uniform if needed |

### File Structure

Each shader needs **4 files**:

```
assets/shaders/
├── shader_name_vertex.vs          # Desktop vertex shader (#version 330)
├── shader_name_fragment.fs        # Desktop fragment shader (#version 330)
└── web/
    ├── shader_name_vertex.vs      # Web vertex shader (#version 300 es)
    └── shader_name_fragment.fs    # Web fragment shader (#version 300 es)
```

### Desktop Shaders (OpenGL 3.3)

**Vertex Shader Template** (`shader_name_vertex.vs`):
```glsl
#version 330

// Input vertex attributes
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

// Input uniform values
uniform mat4 mvp;
uniform float time;  // Add any custom uniforms

// Output vertex attributes (to fragment shader)
out vec2 fragTexCoord;
out vec4 fragColor;

void main()
{
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;

    // Add custom vertex logic here

    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
```

**Fragment Shader Template** (`shader_name_fragment.fs`):
```glsl
#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float time;  // Add any custom uniforms

// Output fragment color
out vec4 finalColor;

void main()
{
    vec4 texelColor = texture(texture0, fragTexCoord);

    // Add custom fragment logic here

    finalColor = texelColor * colDiffuse * fragColor;
}
```

### Web Shaders (OpenGL ES 3.0)

Nearly identical to desktop, but use:
```glsl
#version 300 es
precision mediump float;  // Add this line after version
```

### Atlas-Aware Shaders (For Sprites)

Some shaders need to work with texture atlases (sprite sheets). These use additional uniforms:

```glsl
uniform vec4 texture_details;  // Atlas rectangle (x, y, width, height)
uniform vec2 image_details;    // Image dimensions
```

**Example:** See `assets/shaders/holo_fragment.fs` for atlas-aware shader pattern.

## Common Conversion Challenges

### 1. Time-Based Animations

**Godot:**
```glsl
shader_type canvas_item;

void fragment() {
    float wave = sin(TIME * 2.0);
    COLOR.rgb *= wave;
}
```

**Raylib:**
```glsl
#version 330
in vec2 fragTexCoord;
in vec4 fragColor;
out vec4 finalColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float time;  // Must be passed from C code

void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);
    float wave = sin(time * 2.0);
    finalColor = vec4(texelColor.rgb * wave, texelColor.a) * colDiffuse * fragColor;
}
```

### 2. Screen-Space Effects

Godot's `SCREEN_TEXTURE` requires special handling in Raylib:
- Use render-to-texture
- Pass previous frame as a texture uniform
- May need to restructure shader logic

### 3. Vertex Modifications

**Godot:**
```glsl
void vertex() {
    VERTEX += vec2(sin(TIME), 0.0);
}
```

**Raylib:** Modify in vertex shader:
```glsl
void main() {
    vec3 pos = vertexPosition;
    pos.x += sin(time);
    gl_Position = mvp * vec4(pos, 1.0);
}
```

## Shader Categories in Todo List

### High Priority (Common Effects)
- Outlines (pixel-perfect, atlas-aware)
- Dissolve effects
- Lighting (spotlight, radial shine)
- Displacement/distortion

### Visual Effects
- Fireworks, fire, particles
- Water, liquid effects
- Holographic, foil effects
- Trails, shadows

### Post-Processing
- Blur, chromatic aberration
- Color palette, color replacement
- CRT effects, glitch effects

### Background Effects
- Clouds, parallax scrolling
- Bouncing backgrounds
- Animated patterns

## Testing Converted Shaders

After conversion, test each shader:

1. **Compile check:** Ensure no GLSL syntax errors
2. **Visual test:** Load in game and verify appearance
3. **Performance:** Check frame rate impact
4. **Atlas test:** For sprite shaders, verify atlas coordinates work correctly
5. **Web test:** Verify web version works in browser build

## Directory Structure

```
shaders_to_build/
├── README.md                    # This file
├── shader_todo.md               # List of shaders to convert
├── shaders_for_sprite_effects.md  # Additional shader ideas
├── download_godot_shaders.py    # Download script
└── godot_sources/               # Downloaded Godot shaders (created by script)
    ├── efficient-2d-pixel-outlines.godot
    ├── spotlight-effect.godot
    └── ...

assets/shaders/                  # Converted Raylib shaders
├── shader_name_vertex.vs
├── shader_name_fragment.fs
└── web/
    ├── shader_name_vertex.vs
    └── shader_name_fragment.fs
```

## Notes

- **Rate limiting:** The download script includes delays to be respectful to godotshaders.com
- **Manual downloads:** Some shaders may fail to auto-download. Check `.txt` files in `godot_sources/` for manual download instructions
- **Incremental conversion:** Convert shaders in batches to make progress manageable
- **Reusable code:** Many shaders share common functions (noise, color conversion, etc.) - consider creating shared utility files

## Resources

- [Raylib Shaders Documentation](https://www.raylib.com/examples/shaders/loader.html)
- [GodotShaders.com](https://godotshaders.com/)
- [Existing shader examples](../assets/shaders/) in this project

## Questions?

Tag `@claude` in the GitHub issue with questions about:
- Specific shader conversion challenges
- Raylib shader patterns
- Atlas coordinate handling
- Performance optimization
