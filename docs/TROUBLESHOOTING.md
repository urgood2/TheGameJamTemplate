# Troubleshooting

Common issues and solutions for Lua scripting in this engine.

## Entity Issues

### Entity Disappeared / Not Rendering

**Problem:** Entity was created but doesn't appear on screen.

**Common causes:**
1. Missing layer assignment
2. Wrong z-order (behind other entities)
3. Position outside camera view
4. Size too small (0 width/height)
5. Missing sprite/animation component

**Solution:**

```lua
local entity = animation_system.createAnimatedObjectWithTransform("kobold", true, 100, 200)

-- Verify entity is valid
if not entity_cache.valid(entity) then
    log_warn("Entity creation failed!")
    return
end

-- Check transform
local transform = component_cache.get(entity, Transform)
if not transform then
    log_warn("Entity missing Transform component!")
    return
end

-- Verify position and size
print("Position:", transform.actualX, transform.actualY)
print("Size:", transform.actualW, transform.actualH)

-- Check if entity has rendering components
local hasAnim = registry:has(entity, AnimationQueueComponent)
print("Has animation:", hasAnim)

-- Ensure reasonable size
if transform.actualW == 0 or transform.actualH == 0 then
    transform.actualW = 32
    transform.actualH = 32
end
```

### Entity Data Lost / getScriptTableFromEntityID Returns Nil

**Problem:** `getScriptTableFromEntityID(entity)` returns `nil`.

**Cause:** Script table was not properly initialized, or data was assigned AFTER `attach_ecs()`.

**Solution:**

```lua
-- WRONG: This will fail
local entity = animation_system.createAnimatedObjectWithTransform("kobold", true)
local script = getScriptTableFromEntityID(entity)  -- Returns nil!
script.health = 100  -- Error: attempt to index nil value

-- CORRECT: Initialize script table with Node pattern
local Node = require("monobehavior.behavior_script_v2")
local entity = animation_system.createAnimatedObjectWithTransform("kobold", true)

local EntityType = Node:extend()
local entityScript = EntityType {}

-- CRITICAL: Assign data BEFORE attach_ecs
entityScript.health = 100
entityScript.maxHealth = 100
entityScript.faction = "enemy"

-- Call attach_ecs LAST
entityScript:attach_ecs { create_new = false, existing_entity = entity }

-- Now getScriptTableFromEntityID works
local script = getScriptTableFromEntityID(entity)
print(script.health)  -- 100
```

**Prevention:** Use EntityBuilder to handle this automatically:

```lua
local entity, script = EntityBuilder.create({
    sprite = "kobold",
    position = { 100, 200 },
    data = { health = 100, maxHealth = 100, faction = "enemy" }
})

-- script is already initialized and ready to use
print(script.health)  -- 100
```

### Entity Validation Failures

**Problem:** Entity becomes invalid mid-execution.

**Solution:** Always validate before use:

```lua
-- Use global helpers (preferred)
if not ensure_entity(entity) then
    return
end

-- Or manual validation
local entity_cache = require("core.entity_cache")
if not entity or not entity_cache.valid(entity) then
    log_warn("Entity is invalid or destroyed")
    return
end

-- Check if entity has specific component
if not registry:has(entity, Transform) then
    log_warn("Entity missing Transform component")
    return
end
```

---

## Physics Issues

### Collisions Not Working

**Problem:** Physics bodies pass through each other without colliding.

**Common causes:**
1. Missing collision masks setup
2. Wrong collision tags
3. Both bodies are sensors
4. Bodies on wrong physics world
5. Collision layers not configured

**Solution:**

```lua
local PhysicsManager = require("core.physics_manager")
local PhysicsBuilder = require("core.physics_builder")

-- Get the physics world
local world = PhysicsManager.get_world("world")
if not world then
    log_warn("Physics world not available!")
    return
end

-- Set up collision properly
PhysicsBuilder.for_entity(entity)
    :circle()
    :tag("projectile")
    :sensor(false)  -- NOT a sensor - has physical response
    :collideWith({ "enemy", "WORLD" })
    :apply()

-- Verify collision masks are set
local config = component_cache.get(entity, PhysicsBodyConfig)
if config then
    print("Tag:", config.tag)
    print("Is sensor:", config.isSensor)
end

-- Enable bidirectional collisions
physics.enable_collision_between_many(world, "projectile", { "enemy" })
physics.enable_collision_between_many(world, "enemy", { "projectile" })
physics.update_collision_masks_for(world, "projectile", { "enemy" })
physics.update_collision_masks_for(world, "enemy", { "projectile" })
```

### Physics World Returns Nil

**Problem:** `PhysicsManager.get_world("world")` returns `nil`.

**Cause:** Physics system not initialized, or wrong world name.

**Solution:**

```lua
-- WRONG: Using old globals.physicsWorld pattern
if globals.physicsWorld then  -- May be nil or stale
    physics.create_physics_for_transform(globals.physicsWorld, entity, "dynamic")
end

-- CORRECT: Use PhysicsManager
local PhysicsManager = require("core.physics_manager")
local world = PhysicsManager.get_world("world")

if not world then
    log_warn("Physics world 'world' not available - check physics initialization")
    return
end

-- Use the world
local config = { shape = "circle", tag = "projectile", sensor = false, density = 1.0 }
physics.create_physics_for_transform(registry, physics_manager_instance, entity, "world", config)
```

### Physics Body Not Moving

**Problem:** Physics body created but entity doesn't move.

**Cause:** Sync mode set to AuthoritativeTransform instead of AuthoritativePhysics.

**Solution:**

```lua
-- Set correct sync mode for physics-driven movement
PhysicsBuilder.for_entity(entity)
    :circle()
    :tag("projectile")
    :syncMode("physics")  -- Transform follows physics
    :apply()

-- Apply velocity
local world = PhysicsManager.get_world("world")
physics.SetLinearVelocity(world, entity, velocityX, velocityY)

-- Verify sync mode
local syncConfig = component_cache.get(entity, PhysicsSyncConfig)
if syncConfig then
    print("Pull from physics:", syncConfig.pullPositionFromPhysics)
    print("Push to physics:", syncConfig.pushPositionToPhysics)
end
```

---

## Rendering Issues

### Entity Not Visible

**Problem:** Entity exists and has valid transform, but doesn't render.

**Common causes:**
1. Z-order behind other elements
2. Wrong rendering layer
3. Missing sprite/animation component
4. Entity outside camera bounds
5. Alpha/opacity set to 0

**Solution:**

```lua
local z_orders = require("core.z_orders")

-- Check z-order
local transform = component_cache.get(entity, Transform)
print("Current z-order:", transform.actualZ)

-- Move to foreground
transform.actualZ = z_orders.ui_foreground

-- Check layer assignment
local layerComp = registry:get(entity, EntityLayer)
if layerComp then
    print("Current layer:", layerComp.layer)
end

-- Verify animation component exists
if not registry:has(entity, AnimationQueueComponent) then
    log_warn("Entity missing AnimationQueueComponent - won't render!")
end

-- Check opacity
local sprite = component_cache.get(entity, Sprite)
if sprite then
    print("Sprite opacity:", sprite.opacity)
    sprite.opacity = 1.0  -- Ensure visible
end
```

### Wrong Layer / Z-Order

**Problem:** Entity renders but at wrong depth (behind/in front of other elements).

**Solution:**

```lua
local z_orders = require("core.z_orders")
local transform = component_cache.get(entity, Transform)

-- Common z-order values (from lowest to highest)
transform.actualZ = z_orders.background        -- Far background
transform.actualZ = z_orders.enemies           -- Enemy entities
transform.actualZ = z_orders.player            -- Player layer
transform.actualZ = z_orders.projectiles       -- Projectiles above player
transform.actualZ = z_orders.ui_background     -- UI bottom layer
transform.actualZ = z_orders.ui_foreground     -- UI top layer
transform.actualZ = z_orders.tooltip           -- Tooltips on top

-- For UI elements, also set layer
local EntityLayer = _G.EntityLayer
if EntityLayer then
    if not registry:has(entity, EntityLayer) then
        registry:emplace(entity, EntityLayer)
    end
    local layer = registry:get(entity, EntityLayer)
    layer.layer = "ui"  -- or "world", "background", etc.
end
```

### Shader Not Applying

**Problem:** Shader added but visual effect not visible.

**Solution:**

```lua
local ShaderBuilder = require("core.shader_builder")

-- Verify shader was added
local shaderComp = component_cache.get(entity, ShaderComponent)
if not shaderComp then
    log_warn("Entity missing ShaderComponent!")
end

-- Clear and rebuild shaders
ShaderBuilder.for_entity(entity)
    :clear()
    :add("3d_skew_holo", { sheen_strength = 1.5 })
    :apply()

-- Check if shader exists in system
local availableShaders = _G.shader_library or {}
if not availableShaders["3d_skew_holo"] then
    log_warn("Shader '3d_skew_holo' not found in shader library!")
end

-- Verify entity is in correct render pass
local localCmd = component_cache.get(entity, LocalDrawCommand)
if localCmd then
    print("Shader pass:", localCmd.shaderPass)
    print("UV passthrough:", localCmd.uvPassthrough)
end
```

---

## Common Lua Errors

### "attempt to index a nil value"

**Problem:** Trying to access field on nil object.

**Common cases:**

```lua
-- WRONG: Component doesn't exist
local transform = component_cache.get(entity, Transform)
transform.actualX = 100  -- Error if transform is nil

-- CORRECT: Check before use
local transform = component_cache.get(entity, Transform)
if transform then
    transform.actualX = 100
end

-- WRONG: Script table not initialized
local script = getScriptTableFromEntityID(entity)
script.health = 100  -- Error if script is nil

-- CORRECT: Use safe accessor
local script = safe_script_get(entity)
if script then
    script.health = 100
end

-- Or use script_field with default
local health = script_field(entity, "health", 100)

-- WRONG: Module not available
local result = some_module.doSomething()

-- CORRECT: Check module exists
if some_module and some_module.doSomething then
    local result = some_module.doSomething()
end
```

### "attempt to call a nil value"

**Problem:** Trying to call function that doesn't exist.

**Common cases:**

```lua
-- WRONG: Function doesn't exist on object
nodeComp.methods.onClick()  -- Error if onClick not set

-- CORRECT: Check before calling
if nodeComp.methods.onClick and type(nodeComp.methods.onClick) == "function" then
    nodeComp.methods.onClick(registry, entity)
end

-- WRONG: Global function not defined
myCustomFunction()  -- Error if not defined

-- CORRECT: Check existence
if _G.myCustomFunction then
    myCustomFunction()
end

-- WRONG: Module function doesn't exist
local timer = require("core.timer")
timer.nonexistent_function()

-- CORRECT: Verify before call
if timer.nonexistent_function then
    timer.nonexistent_function()
else
    log_warn("Function not available in timer module")
end
```

### Stack Overflow / Infinite Recursion

**Problem:** Script crashes with "stack overflow" error.

**Common causes:**
1. Circular requires between modules
2. Infinite timer loops
3. Signal handlers that emit the same signal
4. Entity creation during entity iteration

**Solution:**

```lua
-- WRONG: Infinite signal loop
signal.register("on_damage", function(entity)
    signal.emit("on_damage", entity)  -- Infinite recursion!
end)

-- CORRECT: Guard against recursion
local _processing_damage = false
signal.register("on_damage", function(entity)
    if _processing_damage then return end
    _processing_damage = true
    -- Handle damage
    _processing_damage = false
end)

-- WRONG: Creating entities during view iteration
for entity in registry:view(Transform):each() do
    local newEntity = registry:create()  -- Can invalidate iterator!
end

-- CORRECT: Collect entities first, then create
local entities_to_process = {}
for entity in registry:view(Transform):each() do
    table.insert(entities_to_process, entity)
end
for _, entity in ipairs(entities_to_process) do
    local newEntity = registry:create()
end
```

### Missing Component Errors

**Problem:** Accessing component that doesn't exist on entity.

**Solution:**

```lua
-- Always check component exists before accessing
local entity_cache = require("core.entity_cache")
local component_cache = require("core.component_cache")

-- Pattern 1: Early return if missing
local transform = component_cache.get(entity, Transform)
if not transform then
    log_warn("Entity missing Transform component:", entity)
    return
end

-- Pattern 2: Emplace if missing
if not registry:has(entity, GameObject) then
    registry:emplace(entity, GameObject)
end
local gameObj = registry:get(entity, GameObject)

-- Pattern 3: Try-get with default behavior
local script = safe_script_get(entity)
if not script then
    -- Create script table if needed
    local Node = require("monobehavior.behavior_script_v2")
    local EntityType = Node:extend()
    script = EntityType {}
    script:attach_ecs { create_new = false, existing_entity = entity }
end
```
