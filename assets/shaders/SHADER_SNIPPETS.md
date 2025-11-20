# Shader Snippets and Common Techniques

This file contains reusable shader code snippets and common techniques used across multiple shaders in this project.

## Table of Contents
1. [Color Space Conversions](#color-space-conversions)
2. [Noise Functions](#noise-functions)
3. [UV Manipulation](#uv-manipulation)
4. [Visual Effects](#visual-effects)
5. [Sprite Atlas Utilities](#sprite-atlas-utilities)
6. [Time-Based Animation](#time-based-animation)

---

## Color Space Conversions

### RGB to HSV
```glsl
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1e-10;
    return vec3(abs(q.z + (q.w - q.y)/(6.0*d+e)), d/(q.x+e), q.x);
}
```

### HSV to RGB
```glsl
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz)*6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
```

### RGB to HSL
```glsl
vec4 HSL(vec4 c) {
    float low = min(c.r, min(c.g, c.b));
    float high = max(c.r, max(c.g, c.b));
    float d = high - low;
    float sum = high + low;
    vec4 hsl = vec4(0.0, 0.0, 0.5 * sum, c.a);
    if (d == 0.0) return hsl;
    hsl.y = (hsl.z < 0.5) ? d / sum : d / (2.0 - sum);
    if      (high == c.r) hsl.x = (c.g - c.b) / d;
    else if (high == c.g) hsl.x = (c.b - c.r) / d + 2.0;
    else                  hsl.x = (c.r - c.g) / d + 4.0;
    hsl.x = mod(hsl.x / 6.0, 1.0);
    return hsl;
}
```

### HSL to RGB
```glsl
float hue(float s, float t, float h) {
    float hs = mod(h,1.0)*6.0;
    if (hs < 1.0) return (t - s)*hs + s;
    if (hs < 3.0) return t;
    if (hs < 4.0) return (t - s)*(4.0 - hs) + s;
    return s;
}

vec4 RGB(vec4 c) {
    if (c.y < 0.0001) return vec4(vec3(c.z), c.a);
    float tt = (c.z < 0.5) ? c.y*c.z + c.z : -c.y*c.z + (c.y + c.z);
    float ss = 2.0*c.z - tt;
    return vec4(
        hue(ss,tt,c.x + 1.0/3.0),
        hue(ss,tt,c.x),
        hue(ss,tt,c.x - 1.0/3.0),
        c.w
    );
}
```

---

## Noise Functions

### Simple Hash Function
```glsl
float hash(vec2 p) {
    p = fract(p*vec2(123.34, 456.21));
    p += dot(p, p+45.32);
    return fract(p.x*p.y);
}
```

### 2D Value Noise
```glsl
float noise2d(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    // four corners
    float a = hash(i);
    float b = hash(i+vec2(1,0));
    float c = hash(i+vec2(0,1));
    float d = hash(i+vec2(1,1));
    // smooth interpolation
    vec2 u = f*f*(3.0-2.0*f);
    return mix(a, b, u.x) + (c - a)*u.y*(1.0 - u.x) + (d - b)*u.x*u.y;
}
```

### Random Seed (for particle effects)
```glsl
float randomseed(float x) {
    return fract(cos(x * 12.9898) * 43758.5453123);
}
```

### Fractal Brownian Motion (FBM)
```glsl
float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < 4; i++) {
        value += amplitude * noise2d(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }

    return value;
}
```

---

## UV Manipulation

### Get Sprite UV from Atlas
```glsl
// Required uniforms:
// uniform vec2 uImageSize;  // Atlas dimensions (px)
// uniform vec4 uGridRect;   // x,y = top-left (px), z,w = size (px)

vec2 getSpriteUV(vec2 uv) {
    vec2 pixelUV   = uv * uImageSize;
    vec2 spriteLoc = pixelUV - uGridRect.xy;
    return spriteLoc / uGridRect.zw;
}
```

### Center UV Around Origin
```glsl
vec2 centerUV(vec2 uv) {
    return uv - 0.5;
}

// With aspect ratio correction
vec2 centerUVWithAspect(vec2 uv, vec2 resolution) {
    float aspect = resolution.x / resolution.y;
    return (uv - 0.5) * vec2(aspect, 1.0);
}
```

### Rotate UV
```glsl
vec2 rotateUV(vec2 uv, float angle) {
    vec2 centered = uv - 0.5;
    float s = sin(angle);
    float c = cos(angle);
    mat2 rotation = mat2(c, -s, s, c);
    return rotation * centered + 0.5;
}
```

### Polar Coordinates
```glsl
vec2 toPolar(vec2 uv) {
    vec2 centered = uv - 0.5;
    float r = length(centered);
    float theta = atan(centered.y, centered.x);
    return vec2(r, theta);
}

vec2 fromPolar(float r, float theta) {
    return vec2(cos(theta), sin(theta)) * r + 0.5;
}
```

---

## Visual Effects

### Swirling Highlight
```glsl
// Required uniforms: uniform float time;

vec4 swirlHighlight(vec2 spriteUV, vec4 origColor, vec4 gridRect) {
    // 1) center UV around (0,0) and account for aspect
    vec2 uvC = (spriteUV - 0.5) * vec2(gridRect.z/gridRect.w, 1.0);

    // 2) compute radius & base angle
    float r = length(uvC);
    float a = atan(uvC.y, uvC.x);

    // 3) add a time-varying swirl to the angle
    float swirlFreq = 6.0;    // number of lobes
    float swirlAmp  = 0.5;    // how tight the swirl
    float angle = a + swirlAmp * sin(swirlFreq * a + time * 1.5);

    // 4) rebuild a "swirled" UV and sample a simple radial gradient
    vec2 sw = vec2(cos(angle), sin(angle)) * r;
    float highlight = smoothstep(0.2, 0.0, r + 0.1 * sin(4.0 * angle + time));

    // 5) mask it so it only bleeds out around the perimeter
    float mask = smoothstep(0.3, 0.8, highlight);

    // 6) tint your sheen color however you like
    vec3 sheenColor = mix(vec3(1.0,0.9,0.6), vec3(0.6,0.8,1.0), 0.5 + 0.5*sin(time + r*10.0));

    // 7) composite over your sprite—soft blend so edges fade naturally
    vec3 outRgb = mix(origColor.rgb, sheenColor, mask * highlight);

    return vec4(outRgb, origColor.a);
}
```

### Edge Detection (Screen-Space Derivatives)
```glsl
float computeEdgeFactor(vec2 uv, sampler2D tex, float edgeWidth) {
    float a = texture(tex, uv).a;
    vec2 d = vec2(dFdx(a), dFdy(a));
    float grad = length(d);
    // invert so edges (high grad) -> 1, flat -> 0
    return 1.0 - clamp(grad * edgeWidth, 0.0, 1.0);
}
```

### Glow Effect
```glsl
vec4 addGlow(vec4 color, float intensity, vec3 glowColor) {
    float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    vec3 glow = glowColor * luminance * intensity;
    return vec4(color.rgb + glow, color.a);
}
```

### Chromatic Aberration
```glsl
vec4 chromaticAberration(sampler2D tex, vec2 uv, float strength) {
    vec2 offset = (uv - 0.5) * strength;
    float r = texture(tex, uv - offset).r;
    float g = texture(tex, uv).g;
    float b = texture(tex, uv + offset).b;
    float a = texture(tex, uv).a;
    return vec4(r, g, b, a);
}
```

### Vignette Effect
```glsl
float vignette(vec2 uv, float intensity, float smoothness) {
    vec2 centered = uv - 0.5;
    float dist = length(centered);
    return smoothstep(intensity, intensity - smoothness, dist);
}
```

### Pixelation
```glsl
vec2 pixelate(vec2 uv, float pixelSize) {
    return floor(uv / pixelSize) * pixelSize;
}
```

### Wave Distortion
```glsl
vec2 waveDistortion(vec2 uv, float time, float frequency, float amplitude) {
    float wave = sin(uv.y * frequency + time) * amplitude;
    return vec2(uv.x + wave, uv.y);
}
```

---

## Sprite Atlas Utilities

### UV Remapping for Sprite Atlases
See `sprite_atlas_uv_remapping_snippet.md` for detailed UV remapping techniques when working with sprite atlases.

### Sprite Bound Expansion
See `sprite_bound_expansion_snippet.md` for techniques to expand sprite boundaries for effects like outlines and glows.

---

## Time-Based Animation

### Oscillation (Sine Wave)
```glsl
float oscillate(float time, float speed, float min, float max) {
    float t = sin(time * speed) * 0.5 + 0.5;  // normalize to 0..1
    return mix(min, max, t);
}
```

### Pulse Effect
```glsl
float pulse(float time, float speed) {
    return abs(sin(time * speed));
}
```

### Smooth Step Loop
```glsl
float smoothLoop(float time, float duration) {
    float t = mod(time, duration) / duration;
    return smoothstep(0.0, 0.5, t) * smoothstep(1.0, 0.5, t) * 4.0;
}
```

### Easing Functions
```glsl
// Ease In Quad
float easeInQuad(float t) {
    return t * t;
}

// Ease Out Quad
float easeOutQuad(float t) {
    return t * (2.0 - t);
}

// Ease In Out Quad
float easeInOutQuad(float t) {
    return t < 0.5 ? 2.0 * t * t : -1.0 + (4.0 - 2.0 * t) * t;
}

// Ease In Cubic
float easeInCubic(float t) {
    return t * t * t;
}

// Ease Out Cubic
float easeOutCubic(float t) {
    return (--t) * t * t + 1.0;
}
```

---

## Color Filters and Blending

### Multiply Blend
```glsl
vec3 blendMultiply(vec3 base, vec3 blend) {
    return base * blend;
}
```

### Additive Blend
```glsl
vec3 blendAdd(vec3 base, vec3 blend) {
    return min(base + blend, vec3(1.0));
}
```

### Screen Blend
```glsl
vec3 blendScreen(vec3 base, vec3 blend) {
    return vec3(1.0) - (vec3(1.0) - base) * (vec3(1.0) - blend);
}
```

### Overlay Blend
```glsl
vec3 blendOverlay(vec3 base, vec3 blend) {
    return mix(
        2.0 * base * blend,
        vec3(1.0) - 2.0 * (vec3(1.0) - base) * (vec3(1.0) - blend),
        step(0.5, base)
    );
}
```

### Luminance Calculation
```glsl
float luminance(vec3 color) {
    return dot(color, vec3(0.299, 0.587, 0.114));
}
```

### Contrast Adjustment
```glsl
vec3 adjustContrast(vec3 color, float contrast) {
    return ((color - 0.5) * contrast + 0.5);
}
```

### Saturation Adjustment
```glsl
vec3 adjustSaturation(vec3 color, float saturation) {
    float lum = luminance(color);
    return mix(vec3(lum), color, saturation);
}
```

---

## Palette and Color Lookup

### Cosine-Based Palette
```glsl
// IQ's palette function
vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
    return a + b * cos(6.28318 * (c * t + d));
}

// Example usage for rainbow:
vec3 rainbow(float t) {
    return palette(t, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.0, 0.33, 0.67));
}
```

### Gradient Between Two Colors
```glsl
vec3 gradient(float t, vec3 colorA, vec3 colorB) {
    return mix(colorA, colorB, t);
}
```

---

## Geometric Shapes (SDF)

### Circle SDF
```glsl
float circleSDF(vec2 uv, vec2 center, float radius) {
    return length(uv - center) - radius;
}
```

### Rectangle SDF
```glsl
float rectangleSDF(vec2 uv, vec2 center, vec2 size) {
    vec2 d = abs(uv - center) - size;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}
```

### Ring SDF
```glsl
float ringSDF(vec2 uv, vec2 center, float radius, float thickness) {
    return abs(length(uv - center) - radius) - thickness;
}
```

---

## Performance Tips

1. **Avoid dynamic loops** - Use fixed loop counts when possible
2. **Minimize texture samples** - Cache texture lookups in variables
3. **Use built-in functions** - `mix()`, `smoothstep()`, `clamp()` are optimized
4. **Avoid branching** - Use `mix()` and `step()` instead of if/else when possible
5. **Use appropriate precision** - `mediump` for most cases, `highp` only when needed

---

## Debugging Techniques

### Visualize UV Coordinates
```glsl
finalColor = vec4(uv, 0.0, 1.0);  // Red = X, Green = Y
```

### Visualize Normal Maps
```glsl
finalColor = vec4(normal * 0.5 + 0.5, 1.0);
```

### Visualize Grayscale Values
```glsl
finalColor = vec4(vec3(value), 1.0);
```

### Color-Code Ranges
```glsl
vec3 debugRange(float value) {
    if (value < 0.0) return vec3(1.0, 0.0, 0.0);      // Red for negative
    if (value > 1.0) return vec3(0.0, 0.0, 1.0);      // Blue for > 1
    return vec3(0.0, 1.0, 0.0);                        // Green for valid range
}
```

---

## Additional Resources

- See `RAYLIB_SHADER_GUIDE.md` for raylib-specific shader requirements
- See `sprite_atlas_uv_remapping_snippet.md` for UV atlas techniques
- See `sprite_bound_expansion_snippet.md` for sprite boundary effects
