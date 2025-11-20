# Lua API Reference

This document provides comprehensive API documentation for various features available in the game engine.

## Table of Contents

- [UI and Rendering](#ui-and-rendering)
- [Animation and Sprites](#animation-and-sprites)
- [Camera System](#camera-system)
- [Input System](#input-system)
- [Collision System](#collision-system)
- [Particle System](#particle-system)
- [Layer and Rendering](#layer-and-rendering)
- [Entity Management](#entity-management)
- [Text System](#text-system)
- [Performance Considerations](#performance-considerations)

---

## UI and Rendering

### UI Padding and Clipping

**Warning:** Using 0 padding with UI will cause clipping issues.

Always provide adequate padding values to prevent rendering artifacts.

### Scoped Transform Render Queuing

Queue rendering operations in an entity's local transform space:

```lua
command_buffer.queueScopedTransformCompositeRender(layers.sprites, entityA, function()
    -- This text will render in A's local space
    command_buffer.queueDrawText(layers.sprites, function(c)
        c.text = "Entity A"
        c.x = 0
        c.y = 0
        c.fontSize = 24
        c.color = palette.snapToColorName("black")
    end, z_orders.text, layer.DrawCommandSpace.World)

    -- Nested transform under child entityB
    command_buffer.queueScopedTransformCompositeRender(layers.sprites, entityB, function()
        command_buffer.queueDrawRectangle(layers.sprites, function(c)
            c.x = -10
            c.y = -10
            c.width = 20
            c.height = 20
            c.color = palette.snapToColorName("red")
        end, z_orders.overlay, layer.DrawCommandSpace.World)
    end, z_orders.overlay)
end, z_orders.text)
```

### UIBoxComponent Resize Callbacks

Use `onBoxResize` callback to make UI elements responsive to box size changes and update alignment respective to the screen:

```lua
uiBox.onBoxResize = function(newWidth, newHeight)
    -- Update UI element positions based on new dimensions
end
```

### UI with Shaders

To use shaders with UI elements, simply use the pipeline component:

```lua
-- Add PipelineComponent to UI entity for shader effects
```

### Layer Z-Index Management

Assign z-index to entities and UI boxes:

```lua
layer_order_system.assignZIndexToEntity(
    dragDropboxUIBOX, -- entity to assign z-index to
    0 -- z-index value
)

ui.box.AssignLayerOrderComponents(
    registry, -- registry to use
    dragDropboxUIBOX -- ui box to assign layer order components to
)
```

### Draw Command Space

Use `layer.DrawCommandSpace` with queue command methods to control whether primitives respect the camera:

```lua
-- DrawCommandSpace.World - respects camera
-- DrawCommandSpace.Screen - screen space, ignores camera
```

### Background and Final Output Layers

**Important:** Background and final output layers don't work with layer post-processing since they are overwritten. Use fullscreen shaders instead.

---

## Animation and Sprites

### Blinking Sprites

Control sprite visibility for blinking effects:

```lua
local rainComp = registry:get(globals.rainEntity, AnimationQueueComponent)
rainComp.noDraw = not rainComp.noDraw
```

### Entity Render Override

Replace sprite rendering with custom draw functions while retaining shader functionality:

```lua
entity.set_draw_override(survivorEntity, function(w, h)
    -- immediate render version of the same thing.
    command_buffer.executeDrawGradientRectRoundedCentered(layers.sprites, function(c)
        local survivorT = registry:get(survivorEntity, Transform)

        c.cx = 0 -- self centered
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
end, true) -- true disables sprite rendering
```

---

## Camera System

### Camera Creation and Configuration

Create a camera with smooth damping:

```lua
local testCamera = camera.new(0, 0, 1, 0, camera.smooth.damped(0.1))
testCamera:move(400, 400)
```

**Note:** `camera.new()` doesn't actually create a new camera instance; it binds to `global::camera`.

For detailed camera documentation, see [lua_camera_docs.md](../systems/lua_camera_docs.md).

---

## Input System

### Gamepad Detection

Check if gamepad input is enabled:

```lua
if input.isGamepadEnabled() then
    -- Handle gamepad input
end
```

---

## Collision System

### Collision Categories and Masks

Define which entities collide with each other:

```lua
-- Make this entity "player" and only collide with "enemy" or "powerup"
setCollisionCategory(me, "player")
setCollisionMask(me, "enemy", "powerup")
```

### Custom Colliders with Callbacks

Create custom collider entities with collision callbacks:

```lua
-- Create custom collider entity
local collider = create_collider_for_entity(
    e,
    Colliders.TRANSFORM,
    {offsetX = 0, offsetY = 50, width = 50, height = 50}
)

-- Define collider logic with callback
local ColliderLogic = {
    -- Custom data
    speed = 150, -- pixels / second
    hp = 10,

    -- Called once, right after the component is attached
    init = function(self)
    end,

    -- Called every frame by script_system_update()
    update = function(self, dt)
    end,

    -- Called on collision
    on_collision = function(self, other)
    end,

    -- Called just before the entity is destroyed
    destroy = function(self)
    end
}

registry:add_script(collider, ColliderLogic)
```

**Note:** Transform components which aren't collision-enabled are ignored efficiently by the collision system.

---

## Particle System

### Textured Particles

Create particles with texture/animation:

```lua
particle.CreateParticle(
    Vec2(x, y),                 -- start at the center
    Vec2(initialSize, initialSize),
    {
        renderType     = particle.ParticleRenderType.RECTANGLE_FILLED,
        velocity       = Vec2(vx, vy),
        acceleration   = 0,      -- no gravity
        lifespan       = seconds,
        startColor     = util.getColor("WHITE"),
        endColor       = util.getColor("WHITE"),
        rotationSpeed  = rotationSpeed,
        onUpdateCallback = function(comp, dt)
        end,
    },
    { loop = true, animationName = "idle_animation"} -- animation config
)
```

---

## Layer and Rendering

### Color Creation

Create new colors using the `Col()` method:

```lua
local myColor = Col(255, 128, 64, 255) -- R, G, B, A
```

---

## Entity Management

### State Tags

Use state tags to exclude transforms from render, collision, and updates:

```lua
-- Documentation needed for state tag system
```

### Script Component Self Table

Use the script component's script table (`self`) for easier and more performant blackboard access:

```lua
local comp = get_script_component(myEntity)
print(comp.self.someField)
```

### entt_null Binding

The `entt_null` constant is available in Lua for entity comparisons:

```lua
if entity == entt_null then
    -- Entity is null/invalid
end
```

---

## Text System

### Dynamic Text with Wait Commands

**Important:** Current text implementation requires arguments in the specific number and order shown in the docs.

```lua
<typing,speed=0.05>
Hello, brave hero! <wait=key,id=KEY_ENTER>
Hello, brave hero! <wait=mouse,id=MOUSE_BUTTON_LEFT>
Press ENTER to continue…<wait=lua,id=myCustomCallback>
And now the rest…
```

### Text Documentation References

For comprehensive text system documentation, see:
- [effects_documentation.md](../systems/text/effects_documentation.md)
- [dynamic_text_documentation.md](../systems/text/dynamic_text_documentation.md)
- [static_ui_text_documentation.md](../systems/text/static_ui_text_documentation.md)

---

## Performance Considerations

### Node Update Performance

**Warning:** Adding `update()` methods to nodes in multiple entities will greatly slow down performance.

**Best Practice:** Use a timer or a system that processes multiple entities at once instead of per-entity node updates.

---

## Additional Documentation

### Physics System

See [physics_docs.md](../systems/physics_docs.md) for:
- Global `PhysicsManagerInstance` usage
- Physics system integration

### GOAP AI System

For AI action implementation, see:
- [AI_README.md](../systems/ai/AI_README.md)
- Example: [dig_for_gold.lua](../../assets/scripts/ai/actions/dig_for_gold.lua) for optional watch field and abort hooks

### Lua Bindings

See [working_with_sol.md](../systems/working_with_sol.md) for:
- `exposeGlobalsToLua` with Lua doc bindings
- C++ to Lua binding patterns

---

## See Also

- [Lua Scripting Cheatsheet](../../assets/scripts/cheatsheet.md)
- [Controller Navigation](../../assets/scripts/controller_navigation.md)
- [Entity State Management](../../assets/scripts/entity_state_management_doc.md)
- [Timer Documentation](../../assets/scripts/timer_docs.md)
- [Particle System](../../assets/scripts/particles_doc.md)
