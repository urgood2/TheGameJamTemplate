# UIEffect Shaders for Raylib

This directory contains modular GLSL shaders converted from the Unity UIEffect library. These shaders provide various visual effects for UI elements and sprites in Raylib.

## Conversion Notes

- **Original**: Unity UIEffect library (ShaderLab/HLSL/Cg)
- **Converted to**: Raylib GLSL 3.30 core
- **Approach**: Modularized into separate, reusable shader files instead of one massive monolithic shader

## Shader Categories

### 1. Tone Effects
Modify the overall tone/color balance of the image.

#### `uieffect_tone_grayscale.fs`
Converts the image to grayscale.
- **Uniforms**:
  - `float intensity`: Effect intensity (0.0 = no effect, 1.0 = full grayscale)

#### `uieffect_tone_sepia.fs`
Applies a sepia tone effect (vintage/old photo look).
- **Uniforms**:
  - `float intensity`: Effect intensity (0.0 = no effect, 1.0 = full sepia)

#### `uieffect_tone_negative.fs`
Inverts the colors to create a negative/inverse effect.
- **Uniforms**:
  - `float intensity`: Effect intensity (0.0 = no effect, 1.0 = full negative)

#### `uieffect_tone_posterize.fs`
Reduces the number of colors to create a poster-like effect.
- **Uniforms**:
  - `float intensity`: Effect intensity (0.0 = subtle/48 levels, 1.0 = extreme/4 levels)

#### `uieffect_tone_retro.fs`
Applies a Game Boy–style retro palette ramp based on luminance.
- **Uniforms**:
  - `float intensity`: Effect intensity (0.0 = no effect, 1.0 = full retro palette)

---

### 2. Color Filters
Apply color blending modes to modify the appearance.

#### `uieffect_color_filter.fs`
Multi-mode color filter with various blend modes.
- **Uniforms**:
  - `vec4 filterColor`: Color to blend with
  - `float intensity`: Effect intensity (0.0-1.0)
  - `int blendMode`: Blend mode
    - `0` = None
    - `1` = Multiply
    - `2` = Additive
    - `3` = Subtractive
    - `4` = Replace
    - `5` = Multiply Luminance
    - `6` = Multiply Additive
  - `float glow`: Glow effect that reduces alpha (0.0-1.0)

---

### 3. Sampling Effects
Blur, pixelation, and edge detection effects.

#### `uieffect_blur_fast.fs`
Fast Gaussian blur using a 5x5 kernel. Good for performance-sensitive applications.
- **Uniforms**:
  - `float intensity`: Blur intensity (0.0-1.0)
  - `vec2 texelSize`: Size of one texel (1.0/width, 1.0/height)
  - `float samplingScale`: Scale factor for blur (default 1.0)

#### `uieffect_blur_medium.fs`
Medium quality Gaussian blur using a 9x9 kernel. Better quality than fast.
- **Uniforms**:
  - `float intensity`: Blur intensity (0.0-1.0)
  - `vec2 texelSize`: Size of one texel
  - `float samplingScale`: Scale factor for blur

#### `uieffect_pixelation.fs`
Creates a pixelated/mosaic effect by snapping UVs to a grid.
- **Uniforms**:
  - `float intensity`: Pixelation intensity (0.0 = no effect, 1.0 = very pixelated)
  - `vec2 texelSize`: Size of one texel

#### `uieffect_rgb_shift.fs`
Offsets individual color channels to create a chromatic aberration effect.
- **Uniforms**:
  - `float intensity`: Shift strength (0.0 = none)
  - `vec2 texelSize`: Size of one texel
  - `vec2 shiftDir`: Direction of the shift (defaults to X axis)

#### `uieffect_edge_detection.fs`
Detects edges using the Sobel operator.
- **Uniforms**:
  - `float intensity`: Edge detection intensity (0.0-1.0)
  - `float width`: Edge detection kernel width
  - `vec2 texelSize`: Size of one texel
  - `int mode`: Detection mode (0 = luminance, 1 = alpha)

---

### 4. Transition Effects
Animated transition effects for scene/element transitions.

#### `uieffect_transition_fade.fs`
Simple fade in/out transition.
- **Uniforms**:
  - `float transitionRate`: Transition progress (0.0 = visible, 1.0 = invisible)

#### `uieffect_transition_dissolve.fs`
Dissolve transition with noise pattern and colored edge.
- **Uniforms**:
  - `sampler2D transitionTex`: Noise/pattern texture
  - `float transitionRate`: Transition progress (0.0-1.0)
  - `float transitionWidth`: Width of the dissolve edge
  - `float softness`: Softness of the edge (0.0-1.0)
  - `vec4 edgeColor`: Color of the dissolve edge
  - `float iTime`: Time for animation

#### `uieffect_transition_melt.fs`
Melt transition that drips downward.
- **Uniforms**:
  - `sampler2D transitionTex`: Pattern texture
  - `float transitionRate`: Transition progress (0.0-1.0)
  - `float transitionWidth`: Width of the melt effect
  - `float softness`: Softness of the edge
  - `vec4 edgeColor`: Color of the melt edge
  - `vec4 uvMask`: UV bounds (x, y, z, w)

#### `uieffect_transition_burn.fs`
Burn transition with ember-like edges that move upward.
- **Uniforms**:
  - `sampler2D transitionTex`: Pattern texture
  - `float transitionRate`: Transition progress (0.0-1.0)
  - `float transitionWidth`: Width of the burn effect
  - `float softness`: Softness of the edge
  - `vec4 edgeColor`: Color of the burn edge (typically orange/red)
  - `vec4 uvMask`: UV bounds

#### `uieffect_transition_shiny.fs`
Dissolve-style transition with a squared falloff for a shiny band.
- **Uniforms**:
  - `sampler2D transitionTex`: Pattern/gradient texture
  - `float transitionRate`: Transition progress (0.0-1.0)
  - `float transitionWidth`: Width of the shiny band
  - `float softness`: Edge softness (0.0-1.0)
  - `vec4 edgeColor`: Color used for the shiny band

#### `uieffect_transition_pattern.fs`
Pattern-based reveal that blends in a secondary color based on a range mask.
- **Uniforms**:
  - `sampler2D transitionTex`: Pattern mask texture
  - `float transitionRate`: Transition progress (0.0-1.0)
  - `vec2 transitionRange`: Range for the pattern ramp (min, max)
  - `int patternReverse`: If non-zero, invert the mask logic
  - `int patternArea`: 0 = full, 1 = edge bias, 2 = interior bias
  - `vec4 patternColor`: Color applied to the patterned region

#### `uieffect_transition_blaze.fs`
Fire-like transition driven by a gradient lookup.
- **Uniforms**:
  - `sampler2D transitionTex`: Source mask texture
  - `sampler2D transitionGradientTex`: Gradient ramp texture
  - `float transitionRate`: Transition progress (0.0-1.0)
  - `float transitionWidth`: Width of the blaze front

---

### 5. Edge Effects
Add colored edges/outlines to sprites.

#### `uieffect_edge_plain.fs`
Adds a simple colored edge to the sprite.
- **Uniforms**:
  - `float edgeWidth`: Width of the edge (0.0-1.0)
  - `vec4 edgeColor`: Color of the edge
  - `vec2 texelSize`: Size of one texel

#### `uieffect_edge_shiny.fs`
Adds an animated shiny edge that rotates around the sprite.
- **Uniforms**:
  - `float edgeWidth`: Width of the edge
  - `vec4 edgeColor`: Color of the edge
  - `float shinyRate`: Rotation position (0.0-1.0, animate this over time)
  - `float shinyWidth`: Width of the shiny portion (0.0-1.0)
  - `vec2 texelSize`: Size of one texel
  - `float iTime`: Time for auto-animation

---

### 6. Gradation Effects
Apply gradient overlays.

#### `uieffect_gradation_linear.fs`
Applies a linear gradient with rotation, scale, and offset.
- **Uniforms**:
  - `float intensity`: Gradient intensity (0.0-1.0)
  - `vec4 color1`: Start color
  - `vec4 color2`: End color
  - `float rotation`: Gradient rotation in degrees
  - `vec2 scale`: Gradient scale
  - `vec2 offset`: Gradient offset

#### `uieffect_gradation_radial.fs`
Applies a radial gradient from center to edges.
- **Uniforms**:
  - `float intensity`: Gradient intensity (0.0-1.0)
  - `vec4 color1`: Center color
  - `vec4 color2`: Edge color
  - `vec2 center`: Gradient center (0.0-1.0)
  - `float scale`: Gradient scale

---

### 7. Detail / Masking Effects
Overlay a secondary texture with multiple blend modes.

#### `uieffect_detail_filter.fs`
Flexible detail overlay supporting masking, multiply, additive, subtractive, replace, and multiply-additive modes.
- **Uniforms**:
  - `float detailIntensity`: 0 disables the effect
  - `vec4 detailColor`: Tint applied to the detail texture
  - `vec2 detailThreshold`: Used for masking mode
  - `int detailMode`: 0 masking, 1 multiply, 2 additive, 3 subtractive, 4 replace, 5 multiply-additive
  - `vec2 detailTexScale`: UV scale for the detail texture
  - `vec2 detailTexOffset`: UV offset
  - `vec2 detailTexSpeed`: UV scroll speed
  - `float iTime`: Time value for scrolling

---

### 8. Target Filters
Apply an overlay only where pixels match a hue or luminance range.

#### `uieffect_target_filter.fs`
Selective overlay based on hue or luminance proximity.
- **Uniforms**:
  - `int targetMode`: 0 none, 1 hue, 2 luminance
  - `vec4 targetColor`: Reference color
  - `float targetRange`: Acceptance range
  - `float targetSoftness`: Edge softness
  - `vec4 overlayColor`: Overlay color (alpha controls strength)
  - `float targetIntensity`: Blend strength

---

### 9. Shadow Effects
Create soft drop shadows using blurred alpha.

#### `uieffect_shadow_blur.fs`
Blurs the source alpha and tints it to create a soft shadow.
- **Uniforms**:
  - `float intensity`: Blur strength (0 = off)
  - `vec2 texelSize`: 1.0 / texture size
  - `vec2 shadowOffset`: UV offset for the shadow
  - `vec4 shadowColor`: Shadow tint
  - `float shadowAlpha`: Additional shadow alpha scale

---

### 10. Common Vertex Shader

#### `uieffect_common.vs`
A shared vertex shader that works with all the fragment shaders above. It passes through texture coordinates, colors, and vertex positions.

---

## Usage Example (C++)

```cpp
// Load shader
Shader shader = LoadShader("assets/shaders/uieffect_common.vs",
                          "assets/shaders/uieffect_tone_grayscale.fs");

// Get uniform locations
int intensityLoc = GetShaderLocation(shader, "intensity");

// Set uniform values
float intensity = 0.8f;
SetShaderValue(shader, intensityLoc, &intensity, SHADER_UNIFORM_FLOAT);

// Use shader
BeginShaderMode(shader);
DrawTexture(texture, x, y, WHITE);
EndShaderMode();

// Unload when done
UnloadShader(shader);
```

## Usage Example with texelSize

For shaders that need `texelSize` (blur, pixelation, edge effects):

```cpp
Shader shader = LoadShader("assets/shaders/uieffect_common.vs",
                          "assets/shaders/uieffect_blur_fast.fs");

int intensityLoc = GetShaderLocation(shader, "intensity");
int texelSizeLoc = GetShaderLocation(shader, "texelSize");
int samplingScaleLoc = GetShaderLocation(shader, "samplingScale");

float intensity = 0.5f;
Vector2 texelSize = { 1.0f / texture.width, 1.0f / texture.height };
float samplingScale = 1.0f;

SetShaderValue(shader, intensityLoc, &intensity, SHADER_UNIFORM_FLOAT);
SetShaderValue(shader, texelSizeLoc, &texelSize, SHADER_UNIFORM_VEC2);
SetShaderValue(shader, samplingScaleLoc, &samplingScale, SHADER_UNIFORM_FLOAT);

BeginShaderMode(shader);
DrawTexture(texture, x, y, WHITE);
EndShaderMode();
```

## Performance Notes

- **Fast blur** (5x5 kernel): Best for real-time effects
- **Medium blur** (9x9 kernel): Better quality, slightly slower
- **Edge detection**: Samples 9 neighbors, moderate cost
- **Edge effects**: Sample 12 neighbors, moderate to high cost
- **Transition effects**: Cost varies based on pattern texture complexity

## Differences from Unity Version

1. **Modular**: Each effect is a separate shader file instead of one massive shader with feature flags
2. **Simplified**: Removed Unity-specific features (stencil operations, soft masking, VR support)
3. **GLSL syntax**: Converted from HLSL/Cg to GLSL 3.30
4. **Uniforms**: Simplified uniform interface for easier C++ integration
5. **No preprocessing**: No conditional compilation - choose the shader you need directly

## Missing Features

All key Unity UIEffect features have been covered in the modular set above. If you need additional variants or tighter parity with specific Unity keywords, we can add them.

## Credits

- **Original Unity Library**: [UIEffect by mob-sakai](https://github.com/mob-sakai/UIEffect)
- **Conversion**: Adapted for Raylib/GLSL by Claude
- **License**: Original Unity library is MIT licensed

## Tips for Integration

1. **Combine effects**: Use multiple passes to combine effects (e.g., blur + gradation)
2. **Animate uniforms**: Animate `intensity`, `transitionRate`, `shinyRate`, etc. over time
3. **Custom patterns**: For transition effects, create noise textures for interesting patterns
4. **Performance**: Start with fast variants and upgrade if needed
5. **Testing**: Test with different texture sizes and alpha channels
