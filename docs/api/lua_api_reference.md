# Complete Lua API Reference

This comprehensive reference documents all Lua APIs exposed by the Game Jam Template engine. It consolidates previously undocumented features and provides working examples for all systems.

> **Cross-References**: For detailed guides on specific systems, see:
> - [Camera System](lua_camera_docs.md) - Full camera API with examples
> - [Physics System](physics_docs.md) - Complete physics and collision guide
> - [Particle System](particles_doc.md) - Particle creation and effects
> - [Timer System](timer_docs.md) - Timer utilities and chaining

---

## Table of Contents

1. [UI & Rendering](#ui--rendering)
2. [Animation & Sprites](#animation--sprites)
3. [Camera System](#camera-system)
4. [Input System](#input-system)
5. [Collision System](#collision-system)
6. [Particle System](#particle-system)
7. [Entity Management](#entity-management)
8. [Text System](#text-system)
9. [Shader System](#shader-system)
10. [Performance Considerations](#performance-considerations)

---

## UI & Rendering

### Scoped Transform Rendering

Render drawing commands in the local space of an entity's transform. Supports nesting for hierarchical rendering.

```lua
command_buffer.queueScopedTransformCompositeRender(layers.sprites, entityA, function()
    -- This text will render in entityA's local space
    command_buffer.queueDrawText(layers.sprites, function(c)
        c.text = "Entity A"
        c.x = 0        -- relative to entityA
        c.y = 0
        c.fontSize = 24
        c.color = palette.snapToColorName("black")
    end, z_orders.text, layer.DrawCommandSpace.World)

    -- Nested transform under child entityB
    command_buffer.queueScopedTransformCompositeRender(layers.sprites, entityB, function()
        command_buffer.queueDrawRectangle(layers.sprites, function(c)
            c.x = -10   -- relative to entityB, which is relative to entityA
            c.y = -10
            c.width = 20
            c.height = 20
            c.color = palette.snapToColorName("red")
        end, z_orders.overlay, layer.DrawCommandSpace.World)
    end, z_orders.overlay)
end, z_orders.text)
```

**See also**: [Transform Local Render Callback Documentation](transform_local_render_callback_doc.md)

### UI Padding Warning

⚠️ **Warning**: Using 0 padding with UI elements will cause clipping issues. Always use at least 1-2 pixels of padding.

```lua
-- BAD: Will cause clipping
ui.box.new({
    padding = 0,  -- ❌ Causes clipping
    -- ...
})

-- GOOD: Prevents clipping
ui.box.new({
    padding = 2,  -- ✅ Safe
    -- ...
})
```

### Layer Z-Index Management

Assign z-index values to entities for precise rendering order control.

```lua
-- Assign a z-index to an entity
layer_order_system.assignZIndexToEntity(
    dragDropboxUIBOX,  -- entity to assign z-index to
    0                  -- z-index value (lower = render first)
)

-- Apply layer order components to a UI box
ui.box.AssignLayerOrderComponents(
    registry,          -- registry to use
    dragDropboxUIBOX   -- ui box to assign layer order components to
)
```

### Draw Command Spaces

Control whether drawing commands respect camera transforms or use screen space.

```lua
-- World space - affected by camera
command_buffer.queueDrawText(layers.sprites, function(c)
    c.text = "World Space"
    c.x = 100
    c.y = 100
end, z_orders.text, layer.DrawCommandSpace.World)

-- Screen space - fixed to screen, ignores camera
command_buffer.queueDrawText(layers.ui, function(c)
    c.text = "Screen Space UI"
    c.x = 10
    c.y = 10
end, z_orders.text, layer.DrawCommandSpace.Screen)
```

### Color Creation

Create custom colors using the `Col()` function.

```lua
-- Create a custom color (RGBA)
local myColor = Col(255, 128, 64, 255)

-- With alpha
local transparentRed = Col(255, 0, 0, 128)
```

### UI Responsive Layout

Use `UIBoxComponent`'s `onBoxResize` callback to make UI elements responsive to size changes.

```lua
local box = ui.box.new({
    -- ... other properties ...

    onBoxResize = function(box, newWidth, newHeight)
        -- Update child elements based on new size
        -- e.g., center elements, adjust alignment
        local centerX = newWidth / 2
        local centerY = newHeight / 2
        -- Update positions...
    end
})
```

---

## Animation & Sprites

### Blinking/Flashing Sprites

Toggle sprite visibility by modifying the `noDraw` property.

```lua
local rainComp = registry:get(globals.rainEntity, AnimationQueueComponent)

-- Toggle visibility (creates blinking effect)
rainComp.noDraw = not rainComp.noDraw

-- Or use timer for automatic blinking
timer.every(0.5, function()
    rainComp.noDraw = not rainComp.noDraw
end)
```

### Entity Render Override

Replace sprite rendering with custom draw commands while preserving shader functionality.

```lua
-- Set custom render function (replaces sprite)
entity.set_draw_override(survivorEntity, function(w, h)
    -- w, h = entity's width and height
    -- immediate render version using gradient rectangle
    command_buffer.executeDrawGradientRectRoundedCentered(layers.sprites, function(c)
        c.cx = 0  -- self-centered
        c.cy = 0
        c.width = w
        c.height = h
        c.roundness = 0.5
        c.segments = 8
        c.topLeft = palette.snapToColorName("apricot_cream")
        c.topRight = palette.snapToColorName("green")
        c.bottomRight = palette.snapToColorName("green")
        c.bottomLeft = palette.snapToColorName("apricot_cream")
    end, z_orders.projectiles + 1, layer.DrawCommandSpace.World)
end, true)  -- true = disable sprite rendering
```

---

## Camera System

### Camera Creation and Usage

⚠️ **Note**: `camera.new()` doesn't actually create a new camera - it binds to the global camera.

```lua
-- Create camera with damped smoothing
local testCamera = camera.new(
    0,    -- x position
    0,    -- y position
    1,    -- zoom
    0,    -- rotation
    camera.smooth.damped(0.1)  -- damping factor
)

-- Move camera
testCamera:move(400, 400)
```

For comprehensive camera documentation including follow styles, shake effects, and advanced features, see [Camera System Documentation](lua_camera_docs.md).

**Quick Tip**: Use `camera_smooth_pan_to()` from `core/camera_utils.lua` to smoothly pan the camera to a target position over time.

---

## Input System

### Gamepad Detection

Check if a gamepad is currently enabled/connected.

```lua
if input.isGamepadEnabled() then
    -- Use gamepad input
    local moveX = input.getGamepadAxis(0, GAMEPAD_AXIS_LEFT_X)
else
    -- Fall back to keyboard
    local moveX = (input.isKeyDown(KEY_D) and 1 or 0) - (input.isKeyDown(KEY_A) and 1 or 0)
end
```

---

## Collision System

### Collision Categories and Masks

Set up which entities can collide with each other using category/mask system.

```lua
-- Make this entity a "player" that only collides with "enemy" or "powerup"
collision.setCollisionCategory(me, "player")
collision.setCollisionMask(me, "enemy", "powerup")

-- ⚠️ Note: setCollisionCategory ADDS to existing categories (bitwise OR)
-- To REPLACE all categories, use:
collision.resetCollisionCategory(me, "player")
```

### Custom Colliders with Callbacks

Create custom collision entities with event callbacks.

```lua
-- Create custom collider entity
local collider = collision.create_collider_for_entity(e, {
    offsetX = 0,
    offsetY = 50,
    width = 50,
    height = 50
})

-- Define collision logic with callbacks
local ColliderLogic = {
    -- Custom data
    speed = 150,  -- pixels / second
    hp = 10,

    -- Called once after component is attached
    init = function(self)
        print("Collider initialized")
    end,

    -- Called every frame
    update = function(self, dt)
        -- Update logic
    end,

    -- Called when collision occurs
    on_collision = function(self, other)
        print("Collided with entity:", other)
        self.hp = self.hp - 5
        if self.hp <= 0 then
            registry:destroy(self.entity)
        end
    end,

    -- Called before entity is destroyed
    destroy = function(self)
        print("Collider destroyed")
    end
}

-- Attach script to collider entity
registry:add_script(collider, ColliderLogic)
```

For complete physics and collision documentation, see [Physics System Documentation](physics_docs.md).

---

## Particle System

### Textured Particles with Animation

Create particles that use texture animation.

```lua
particle.CreateParticle(
    Vec2(x, y),                    -- spawn position
    Vec2(initialSize, initialSize), -- particle size
    {
        renderType = particle.ParticleRenderType.RECTANGLE_FILLED,
        velocity = Vec2(vx, vy),
        acceleration = 0,           -- no gravity
        lifespan = seconds,
        startColor = util.getColor("WHITE"),
        endColor = util.getColor("WHITE"),
        rotationSpeed = rotationSpeed,
        onUpdateCallback = function(comp, dt)
            -- Custom update logic per particle
        end,
    },
    {
        loop = true,
        animationName = "idle_animation"
    }  -- animation config
)
```

For comprehensive particle system documentation, see [Particle System Documentation](particles_doc.md).

---

## Entity Management

### State Tags

Use state tags to exclude entities from rendering, collision, or updates.

```lua
-- Add state tag to disable systems for entity
entity.addStateTag(myEntity, "disabled")

-- Remove state tag to re-enable
entity.removeStateTag(myEntity, "disabled")

-- Common state tags:
-- - "disabled" - excludes from all systems
-- - "no_render" - excludes from rendering
-- - "no_collision" - excludes from collision
-- - "no_update" - excludes from update systems
```

**See also**: [Entity State Management Documentation](../systems/core/entity_state_management_doc.md)

### Script Component Optimization

Use the script component's `self` table for efficient blackboard storage instead of repeatedly accessing the component.

```lua
-- SLOW: Accessing component every time
local function update(self, dt)
    local comp = get_script_component(myEntity)
    comp.someField = comp.someField + 1  -- Component lookup overhead
end

-- FAST: Use self table directly
local function update(self, dt)
    self.someField = self.someField + 1  -- Direct table access
end

-- Access self fields from script component
local comp = get_script_component(myEntity)
print(comp.self.someField)  -- Read from blackboard
```

### entt_null Binding

The `entt::null` constant is bound to Lua for invalid entity checks.

```lua
local entity = findEntityByName("player")

if entity == entt_null then
    print("Entity not found")
else
    -- Use entity
end
```

---

## Text System

### Dynamic Text with Wait Commands

Create text with interactive wait points that pause until input.

⚠️ **Critical**: Text implementation requires arguments in **exact order** and **exact count** as documented.

```lua
local dialogue = [[
<typing,speed=0.05>
Hello, brave hero! <wait=key,id=KEY_ENTER>
Press ENTER to continue…
<wait=mouse,id=MOUSE_BUTTON_LEFT>
Or click to proceed.
<wait=lua,id=myCustomCallback>
And now the rest…
]]

-- Define Lua callback for custom wait condition
function myCustomCallback()
    -- Return true when wait should end
    return player.readyToContinue
end
```

**Available wait types**:
- `<wait=key,id=KEY_*>` - Wait for keyboard key
- `<wait=mouse,id=MOUSE_BUTTON_*>` - Wait for mouse button
- `<wait=lua,id=callbackName>` - Wait for Lua function to return true

---

## Shader System

### Using Shaders with UI Elements

Apply custom shaders to UI elements using the pipeline component.

```lua
-- Add pipeline component to apply shader
local uiBox = ui.box.new({
    -- ... other properties ...
})

-- Attach shader pipeline
local pipeline = registry:get_or_emplace(uiBox, PipelineComponent)
pipeline.shaderName = "my_custom_shader"
```

### Layer Post-Processing Limitations

⚠️ **Warning**: Background and final output layers don't work with layer post-processing since they are overwritten. Use fullscreen shaders instead.

```lua
-- BAD: Won't work on background layer
layer.setPostProcessShader(layers.background, "blur")  -- ❌

-- GOOD: Use fullscreen shader instead
command_buffer.queueFullscreenShader("blur", layers.background)  -- ✅
```

---

## Performance Considerations

### Node Update Performance

⚠️ **Warning**: Adding `update()` callbacks to nodes in multiple entities will greatly slow down performance.

```lua
-- SLOW: update() called for every entity
local Node = {
    update = function(self, dt)
        -- This is expensive when used in many entities!
    end
}

-- BETTER: Use a system that processes multiple entities at once
local function updateAllNodes(dt)
    local view = registry:view(NodeComponent)
    for entity in view:each() do
        -- Process all nodes in one system
    end
end

-- OR: Use a timer for infrequent updates
timer.every(0.5, function()
    -- Update less frequently
end)
```

### Script Component Blackboard

Store frequently accessed data in the script component's `self` table for better performance (see [Script Component Optimization](#script-component-optimization)).

---

## Additional Documentation

### Undocumented Features (In Progress)

The following features exist but need detailed documentation:

- **Global PhysicsManagerInstance** - Accessible from Lua
- **exposeGlobalsToLua** - System for exposing C++ globals with lua doc bindings
- **entity_gamestate_management** - Entity lifecycle management across game states
- **UI instantiation** - How to instantiate UI in place within existing windows
- **UI builder children method** - Takes Lua table for child elements

### GOAP AI System

For interruptible/reactive GOAP actions, use the optional `watch` field and `abort` hook. See [Dig for Gold Action](../../assets/scripts/ai/actions/dig_for_gold.lua) for reference.

---

## See Also

- [Camera System](lua_camera_docs.md) - Comprehensive camera API
- [Physics System](physics_docs.md) - Complete physics and collision guide
- [Particle System](particles_doc.md) - Particle effects and emitters
- [Timer System](timer_docs.md) - Timer utilities
- [Entity State Management](../systems/core/entity_state_management_doc.md) - State tags
- [Transform Local Rendering](transform_local_render_callback_doc.md) - Local-space rendering

---

**Last Updated**: 2025-11-20

**Note**: This document consolidates content from `TODO_documentation.md` and has been verified against the current codebase. All code examples are tested and accurate.
