# 3D Skew Shader Outline Integration

**Date:** 2025-12-30
**Status:** Approved

## Overview

Add a configurable white outline directly into the `3d_skew` fragment shader, rendered on top of all other effects.

## Problem

Previous attempt used `efficient_pixel_outline` as a second shader pass, but this failed because:
- The 3d_skew vertex shader transforms geometry based on mouse position
- A second pass with its own vertex shader doesn't inherit this transformation
- Result: outline misalignment with the tilted card

## Solution

Integrate outline detection directly into the 3d_skew fragment shader so it shares the same geometry pass.

## Algorithm

**Edge detection via 8-way neighbor sampling:**
1. Sample 8 neighboring pixels (N, S, E, W, NE, NW, SE, SW)
2. If current pixel is transparent (alpha < 0.1) BUT any neighbor has alpha > 0 → outline pixel
3. Render `outline_color` instead of transparent

**Atlas-aware sampling:**
- Cards use texture atlases (multiple sprites in one texture)
- Sample coordinates are clamped within sprite's `uGridRect` bounds to prevent bleed

## New Uniforms

```glsl
uniform vec4 outline_color;      // Default: white (1,1,1,1)
uniform float outline_thickness; // Default: 1.0 (pixels)
uniform float outline_enabled;   // 0.0 = off, 1.0 = on
```

## Implementation

### Shader Flow

```
main() → compute finalUV → applyOverlay() → base color → APPLY OUTLINE → output
```

Outline applied as last step before output.

### Files Modified

1. `assets/shaders/3d_skew_fragment.fs` (desktop GLSL 330)
2. `assets/shaders/web/3d_skew_fragment.fs` (web GLSL ES 300)
3. `assets/scripts/core/shader_uniforms.lua` (default values)

## Usage

```lua
-- Enable outline on a card
setShaderUniform(registry, cardEntity, "3d_skew", "outline_enabled", 1.0)
setShaderUniform(registry, cardEntity, "3d_skew", "outline_thickness", 2.0)
setShaderUniform(registry, cardEntity, "3d_skew", "outline_color", {1, 0.84, 0, 1}) -- gold
```
