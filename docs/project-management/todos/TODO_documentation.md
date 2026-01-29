# Documentation
- [ ] using 0 padding with ui will cause clipping issues.
- [ ] blinking sprites
```lua
local rainComp = registry:get(globals.rainEntity, AnimationQueueComponent)
    --                             rainComp.noDraw = not rainComp.noDraw
```
- [ ] using scoped transfrom render queing
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
- [ ] input.isGamepadEnabled()
- [ ] note that adding update() to nodes in multiple entities will greatly slow down performance. better to use a timer or a system that processes multiple entities at once.
- [ ] entity render override (replaces sprites but gets the shader functionality too)
```cpp
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
- [ ] Col() method for creating new colors
- [ ] use uiboxcopmonent's onBoxResize callback to make ui elements responsive to box size changes and update alignment respective to the screen for instance
- [ ] use optional watch field and abort hook to make goap actions interruptible/reactive to specific worldstate changes, refer to [this file](assets/scripts/ai/actions/dig_for_gold.lua)
- [ ] document using shaders with ui elements (just use pipeline comp)
- [ ] document global PhysicsManagerInstance
- [ ] document exposeGlobalsToLua with lua doc bindings
- [ ] prob add docs for entity_gamestate_management
- [ ] using layer.DrawCommandSpace with queuecommand methods.
- [ ] document use script component's script table (self) to make blackboard accessing easier and more sustainable performance wise
```lua
local comp = get_script_component(myEntity)
print( comp.self.someField )
```
- [ ] how to get drawing pritimitives to optionall respect camera? -> use drawCommandSpace specifier in QueueCommand method
- entt_null binding in lua
- How to instantiate some ui in place in an existing ui window -- refer to existing lua code & document
- add children method (which takes lua table) for ui builder
- document this:
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
- [ ] document using state tags to exclude transforms from render or collision & updates
- [ ] camera documentation
    - also document that lua camera new doesn't actually create anew one, it binds to global::camera

```lua
local testCamera = camera.new(0, 0, 1, 0, camera.smooth.damped(0.1)) -- Create a new camera instance with damping
testCamera:move(400,400)
```
- [ ] Collision mask usage in lua
```lua
-- make this entity “player” and only collide with “enemy” or “powerup”
setCollisionCategory(me, "player")
setCollisionMask(me, "enemy", "powerup")
```
- [ ] document that background and finaloutput layers dont' work with layer post processing since they are overwritten. use fullscreen shaders instead.
- [ ] 
NOTE that current text implementation is brittle and requires the arguments to be specifically in the number in the docs, and in the specified order
```
<typing,speed=0.05>
Hello, brave hero! <wait=key,id=KEY_ENTER>
Hello, brave hero! <wait=mouse,id=MOUSE_BUTTON_LEFT>
Press ENTER to continue…<wait=lua,id=myCustomCallback>
And now the rest…
```

- [ ] ability ti add arbitrary colliders and link them to an event (on collision) need to ignore transform components which aren't collision enabled in an efficient manner -> https://chatgpt.com/share/6860eae3-67a8-800a-b105-849b6c82de32 -> done, expose to lua, document, and test

```lua

-- create custom collider entity which is always, underneath, a transform. But it should have custom types like (circle) which will decide how the collision system resolves the collision
local collider = create_collider_for_entity(e, Colliders.TRANSFORM, {offsetX = 0, offsetY = 50, width = 50, height = 50})

-- give it a ScriptComponent with an onCollision method
local ColliderLogic = {
    -- Custom data carried by this table
    speed        = 150, -- pixels / second
    hp           = 10,

    -- Called once, right after the component is attached.
    init         = function(self)
    end,

    -- Called every frame by script_system_update()
    update       = function(self, dt)
    end,

    on_collision = function(self, other)
    end,

    -- Called just before the entity is destroyed
    destroy      = function(self)
    end
}
registry:add_script(collider, ColliderLogic) -- Attach the script to the entity

-- now it will be checked in collision.

```
- [ ] using textuerd particles:

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

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
