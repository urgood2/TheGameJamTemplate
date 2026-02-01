# Lighting System Design Spec

## Overview

A Lua-accessible lighting system that applies dynamic lights to render layers via a fluent builder API. Works like the existing spotlight shader but supports multiple simultaneous lights with both additive and subtractive blend modes.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Light count | 16 max (uniform array) | Single-shader approach for performance, practical limit for game scope |
| Blend modes | Both additive + subtractive | Subtractive for stealth/horror, additive for magic effects |
| GPU strategy | Single multi-light shader | Better performance than multi-pass, uniform arrays for light data |
| Animation | Static (external timer) | Keep shader simple, animate via `timer.sequence()` in Lua |
| Attachment | Auto-follow (parented) | Lights track entity position automatically each frame |
| Coordinates | World pixels | Same as entity transforms, camera-aware conversion in shader |
| Toggle behavior | Preserve (pause/resume) | Disabling hides effect but lights remain for re-enable |
| Overflow | Silent cap + log warning | Graceful degradation, debugging visibility |
| Falloff | Linear only | Simple to reason about, sufficient for 2D games |
| Cleanup | Auto-destroy on entity death | Prevents orphaned lights, matches entity lifecycle |
| Presets | None - always explicit | Maximum clarity, no magic |
| Platform | Web + Desktop | GLSL 330 + GLSL 100/300 ES shader variants |

## API Design

### Module Structure

```lua
local Lighting = require("core.lighting")
```

### Layer Control (The "Single Switch")

```lua
-- Enable lighting on a layer (adds lighting shader)
Lighting.enable("sprites")
Lighting.enable("sprites", { mode = "subtractive" })  -- or "additive"

-- Disable lighting (removes shader, preserves light definitions)
Lighting.disable("sprites")

-- Check if lighting is active on layer
if Lighting.isEnabled("sprites") then ... end

-- Pause/resume (hide effect but keep lights defined)
Lighting.pause("sprites")
Lighting.resume("sprites")

-- Set ambient light level for subtractive mode (0 = pitch black, 1 = full bright)
Lighting.setAmbient("sprites", 0.1)
```

### Creating Lights (Fluent Builder)

```lua
-- Basic point light
local light = Lighting.point()
    :at(100, 200)          -- World pixel position
    :radius(150)           -- Light radius in pixels
    :intensity(1.0)        -- 0-1 brightness
    :color("orange")       -- Named color or {r,g,b}
    :create()

-- Attach to entity (auto-follows)
local light = Lighting.point()
    :attachTo(playerEntity)
    :radius(200)
    :color(255, 200, 100)  -- RGB values
    :create()

-- Spotlight (cone-shaped)
local light = Lighting.spot()
    :at(400, 300)
    :direction(90)         -- Degrees (0=right, 90=down)
    :angle(45)             -- Cone angle in degrees
    :radius(300)
    :color("white")
    :create()
```

### Light Handle API

```lua
-- Returned from :create()
local light = Lighting.point():at(100, 200):radius(100):create()

-- Modify properties
light:setPosition(newX, newY)
light:setRadius(200)
light:setIntensity(0.5)
light:setColor("blue")

-- Get properties
local x, y = light:getPosition()
local r = light:getRadius()

-- Check validity
if light:isValid() then ... end

-- Manual destruction
light:destroy()

-- Re-attach to different entity
light:attachTo(newEntity)
light:detach()  -- Stops following, keeps current position
```

### Blend Mode Per-Light (Optional)

```lua
-- Override layer blend mode for specific light
local glow = Lighting.point()
    :at(x, y)
    :radius(50)
    :color("cyan")
    :additive()    -- This light adds brightness even in subtractive layer
    :create()
```

### Animation via Timer

```lua
local timer = require("core.timer")
local light = Lighting.point():attachTo(torch):radius(100):color("orange"):create()

-- Flicker effect
timer.every(0.1, function()
    light:setIntensity(0.8 + math.random() * 0.4)
    light:setRadius(95 + math.random() * 10)
end, nil, false, nil, "torch_flicker", "lighting")

-- Pulse effect
timer.sequence("light_pulse")
    :do_now(function()
        timer.tween_scalar(0.5,
            function() return light:getRadius() end,
            function(v) light:setRadius(v) end,
            150
        )
    end)
    :wait(0.5)
    :do_now(function()
        timer.tween_scalar(0.5,
            function() return light:getRadius() end,
            function(v) light:setRadius(v) end,
            100
        )
    end)
    :start()
```

### Cleanup Integration

```lua
-- Lights auto-destroy when attached entity is destroyed
-- Manual cleanup available:
Lighting.removeAll("sprites")  -- Remove all lights from layer
Lighting.clear()               -- Remove all lights from all layers
```

## Shader Implementation

### Uniform Structure (per layer)

```glsl
#define MAX_LIGHTS 16

uniform int u_lightCount;
uniform vec2 u_lightPositions[MAX_LIGHTS];   // Screen-space positions
uniform float u_lightRadii[MAX_LIGHTS];       // In pixels
uniform float u_lightIntensities[MAX_LIGHTS]; // 0-1
uniform vec3 u_lightColors[MAX_LIGHTS];       // RGB 0-1
uniform int u_lightTypes[MAX_LIGHTS];         // 0=point, 1=spot
uniform float u_lightAngles[MAX_LIGHTS];      // Spot cone angle
uniform float u_lightDirections[MAX_LIGHTS];  // Spot direction

uniform float u_ambientLevel;                 // 0-1 for subtractive mode
uniform int u_blendMode;                      // 0=subtractive, 1=additive
```

### Coordinate Conversion

Lua provides world-space pixel coordinates. The C++ layer (or shader) converts to screen-space each frame using the active camera transform.

```lua
-- Internal: Called by lighting system each frame
local function worldToScreen(worldX, worldY)
    -- Use camera offset to convert world -> screen
    local cam = camera.getActive()
    return worldX - cam.x, worldY - cam.y
end
```

### Web Compatibility

Shader variants:
- `lighting_fragment.fs` - GLSL 330 (Desktop)
- `web/lighting_fragment.fs` - GLSL 100/300 ES (Web)

Key differences handled:
- `precision mediump float;` for WebGL
- `#version 300 es` vs `#version 330 core`
- `out vec4 finalColor` vs `gl_FragColor`

## Integration Points

### With Existing Systems

| System | Integration |
|--------|-------------|
| `add_layer_shader` | Lighting.enable() calls this internally |
| `globalShaderUniforms` | Light data synced to uniforms each frame |
| `entity_cache` | Validate attached entities, cleanup on destroy |
| `timer` | External animation via timer system |
| `component_cache` | Get entity Transform for position updates |

### Update Loop

```lua
-- Called internally each frame when lighting is enabled
function Lighting._update(dt)
    for layerName, lights in pairs(activeLights) do
        -- Update positions for attached lights
        for _, light in ipairs(lights) do
            if light._attachedEntity then
                if entity_cache.valid(light._attachedEntity) then
                    local t = component_cache.get(light._attachedEntity, Transform)
                    if t then
                        light._x = t.actualX + t.actualW * 0.5
                        light._y = t.actualY + t.actualH * 0.5
                    end
                else
                    -- Entity destroyed, remove light
                    light:destroy()
                end
            end
        end

        -- Sync uniform arrays to shader
        Lighting._syncUniforms(layerName)
    end
end
```

## File Structure

```
assets/
  scripts/
    core/
      lighting.lua          # Main Lua module
  shaders/
    lighting_fragment.fs    # Desktop GLSL 330
    lighting_vertex.vs
    web/
      lighting_fragment.fs  # WebGL GLSL 100/300 ES
      lighting_vertex.vs
```

## Usage Examples

### Tutorial Spotlight Replacement

```lua
-- Before (spotlight.lua)
local Spotlight = require("tutorial.dialogue.spotlight")
local spot = Spotlight.new({ size = 0.4, feather = 0.1 })
spot:show()
spot:focusOn(entity)

-- After (lighting system)
local Lighting = require("core.lighting")
Lighting.enable("sprites", { mode = "subtractive" })
Lighting.setAmbient("sprites", 0.0)

local spot = Lighting.point()
    :attachTo(entity)
    :radius(200)
    :intensity(1.0)
    :color("white")
    :create()

-- To hide
Lighting.pause("sprites")
-- To show again
Lighting.resume("sprites")
```

### Combat Spell Effects

```lua
-- Fireball glow
local fireball = Lighting.point()
    :attachTo(projectileEntity)
    :radius(80)
    :color("orange")
    :additive()
    :create()

-- When projectile explodes, animate out
timer.tween_scalar(0.3,
    function() return fireball:getRadius() end,
    function(v) fireball:setRadius(v) end,
    200,  -- Expand
    nil,
    function() fireball:destroy() end
)
```

### Torch Array

```lua
local torches = {}
for _, torchEntity in ipairs(level.torches) do
    local light = Lighting.point()
        :attachTo(torchEntity)
        :radius(120)
        :color(255, 180, 80)
        :create()

    -- Add flicker
    timer.every(0.08, function()
        if light:isValid() then
            light:setIntensity(0.7 + math.random() * 0.3)
        end
    end, nil, false, nil, "torch_" .. torchEntity, "torches")

    table.insert(torches, light)
end
```

## Performance Considerations

1. **Uniform Upload**: Batch all light data into single uniform update per frame
2. **Position Caching**: Only recalculate screen positions when camera or light moves
3. **Early Exit**: Shader skips light calculations for lights with intensity=0
4. **Light Culling**: Future optimization - skip lights outside viewport

## Edge Cases

1. **Max lights exceeded**: Log warning, ignore new lights until slots free
2. **Entity destroyed**: Attached lights auto-cleanup
3. **Layer disabled**: Lights preserved, shader removed
4. **Hot reload**: Lighting state preserved across script reload
5. **Zero radius**: Light has no effect, treated as disabled

## Testing Checklist

- [ ] Point light at fixed position
- [ ] Point light attached to moving entity
- [ ] Spotlight with direction
- [ ] Subtractive mode with ambient
- [ ] Additive mode overlay
- [ ] 16 simultaneous lights
- [ ] 17th light (overflow warning)
- [ ] Entity destruction cleanup
- [ ] Layer enable/disable/pause/resume
- [ ] Web build compatibility
- [ ] Camera movement affects light positions
- [ ] Timer-based animation (flicker/pulse)

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
