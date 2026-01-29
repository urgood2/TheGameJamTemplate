# Render Groups API

Render groups let you batch-render entities with arbitrary shaders without needing a `ShaderPipelineComponent` on each entity. Ideal for applying visual effects to many sprites efficiently.

## Quick Start

```lua
-- 1. Create a group with default shader(s)
render_groups.create("glowing_enemies", {"glow"})

-- 2. Add entities
render_groups.add("glowing_enemies", enemy1)
render_groups.add("glowing_enemies", enemy2)

-- 3. Draw in your render loop
command_buffer.queueDrawRenderGroup(layers.sprites, function(cmd)
    cmd.registry = registry
    cmd.groupName = "glowing_enemies"
    cmd.autoOptimize = true
end, z_order, layer.DrawCommandSpace.World)
```

---

## API Reference

### Group Management

#### `render_groups.create(groupName, shaders)`
Create a render group with default shaders applied to all entities.

```lua
-- Single shader
render_groups.create("holo_cards", {"3d_skew_holo"})

-- Multiple shaders (applied as sequential passes)
render_groups.create("fancy_fx", {"dissolve", "outline", "glow"})

-- No default shaders (entities must specify their own)
render_groups.create("custom_only", {})
```

#### `render_groups.clearGroup(groupName)`
Remove all entities from a group (group still exists).

#### `render_groups.clearAll()`
Remove all groups and entities.

---

### Entity Management

#### `render_groups.add(groupName, entity [, shaders])`
Add entity to group. Optionally override group's default shaders.

```lua
-- Use group's default shaders
render_groups.add("my_group", entity)

-- Override with specific shaders for this entity
render_groups.add("my_group", entity, {"3d_skew_foil", "dissolve"})
```

#### `render_groups.remove(groupName, entity)`
Remove entity from specific group.

#### `render_groups.removeFromAll(entity)`
Remove entity from all groups it belongs to.

---

### Per-Entity Shader Manipulation

#### `render_groups.addShader(groupName, entity, shaderName)`
Add a shader to entity's shader list.

```lua
render_groups.addShader("enemies", boss, "fire_aura")
```

#### `render_groups.removeShader(groupName, entity, shaderName)`
Remove a shader from entity's shader list.

#### `render_groups.setShaders(groupName, entity, shaders)`
Replace entity's entire shader list.

```lua
render_groups.setShaders("enemies", boss, {"ice_effect", "glow"})
```

#### `render_groups.resetToDefault(groupName, entity)`
Reset entity to use group's default shaders.

---

### Drawing

#### `command_buffer.queueDrawRenderGroup(layer, initFn, z, space)`

Queue all entities in a group for rendering.

```lua
command_buffer.queueDrawRenderGroup(layers.sprites, function(cmd)
    cmd.registry = registry      -- required
    cmd.groupName = "my_group"   -- required
    cmd.autoOptimize = true      -- optional: reduces shader state changes
end, 100, layer.DrawCommandSpace.World)
```

---

## Multiple Shaders Per Entity

When multiple shaders are specified, they're applied as **sequential passes**. Each shader draws the sprite independently.

```lua
-- Entity will be drawn 3 times:
-- Pass 1: dissolve shader
-- Pass 2: outline shader  
-- Pass 3: glow shader
render_groups.add("my_group", entity, {"dissolve", "outline", "glow"})
```

For **composited effects** (single draw with blended shaders), use `ShaderPipelineComponent` instead.

---

## Using Arbitrary Shaders

Any shader registered in the system works. The render groups system automatically:
- Injects atlas uniforms (`atlas_rect`, `atlas_size`, etc.)
- For `3d_skew_*` variants: sets up tilt, rotation, UV mapping

### Custom Shader Uniforms

Set uniforms via the global shader uniforms system:

```lua
-- Set uniform before draw
globalShaderUniforms:set("my_custom_shader", "intensity", 0.8)
globalShaderUniforms:set("dissolve", "dissolve", 0.5)
```

### Per-Entity Uniforms

For per-entity uniform overrides, attach a `ShaderUniformComponent`:

```lua
local uniformComp = registry:emplace(entity, shaders.ShaderUniformComponent)
uniformComp:setFloat("dissolve", "dissolve", 0.3)
uniformComp:setVec4("glow", "glow_color", 1.0, 0.5, 0.0, 1.0)
```

---

## Complete Example: Mixed Shader Effects

```lua
local effects_demo = {}
local GROUP = "demo_effects"

function effects_demo.init()
    -- Create group with base shader
    render_groups.create(GROUP, {"3d_skew_holo"})
    
    -- Create several entities with different shader configurations
    
    -- Entity 1: uses group default (3d_skew_holo)
    local e1 = create_sprite("card1.png", 100, 100)
    render_groups.add(GROUP, e1)
    
    -- Entity 2: override with different 3d_skew variant
    local e2 = create_sprite("card2.png", 250, 100)
    render_groups.add(GROUP, e2, {"3d_skew_polychrome"})
    
    -- Entity 3: multiple shaders
    local e3 = create_sprite("card3.png", 400, 100)
    render_groups.add(GROUP, e3, {"3d_skew_foil", "outline"})
    
    -- Entity 4: custom shader with uniforms
    local e4 = create_sprite("enemy.png", 550, 100)
    render_groups.add(GROUP, e4, {"dissolve"})
    globalShaderUniforms:set("dissolve", "dissolve", 0.4)
    
    -- Entity 5: no shaders (raw sprite)
    local e5 = create_sprite("plain.png", 700, 100)
    render_groups.add(GROUP, e5, {})
end

function effects_demo.draw()
    command_buffer.queueDrawRenderGroup(layers.sprites, function(cmd)
        cmd.registry = registry
        cmd.groupName = GROUP
        cmd.autoOptimize = true
    end, 100, layer.DrawCommandSpace.World)
end

function effects_demo.update(dt)
    -- Animate dissolve over time
    local t = (math.sin(globals.getTime()) + 1) / 2
    globalShaderUniforms:set("dissolve", "dissolve", t)
end

function effects_demo.cleanup()
    render_groups.clearGroup(GROUP)
end

-- Helper
local function create_sprite(name, x, y)
    local e = animation_system.createAnimatedObjectWithTransform(name, true)
    animation_system.resizeAnimationObjectsInEntityToFit(e, 128, 128)
    local t = component_cache.get(e, Transform)
    t.actualX, t.actualY = x, y
    
    -- Enable hover for 3d_skew tilt effect
    local node = component_cache.get(e, GameObject)
    node.state.hoverEnabled = true
    node.state.collisionEnabled = true
    
    return e
end

return effects_demo
```

---

## Available 3d_skew Shaders

These get automatic uniform setup for tilt, rotation, and UV mapping:

| Shader | Effect |
|--------|--------|
| `3d_skew` | Base pseudo-3D with sheen |
| `3d_skew_holo` | Holographic rainbow |
| `3d_skew_polychrome` | Color-shifting |
| `3d_skew_foil` | Metallic foil |
| `3d_skew_gold_seal` | Gold seal effect |
| `3d_skew_prismatic` | Prismatic light |
| `3d_skew_aurora` | Aurora borealis |
| `3d_skew_iridescent` | Iridescent sheen |
| `3d_skew_plasma` | Plasma effect |
| `3d_skew_nebula` | Nebula clouds |
| `3d_skew_thermal` | Thermal vision |
| `3d_skew_crystalline` | Crystal refraction |
| `3d_skew_negative` | Inverted colors |
| `3d_skew_negative_tint` | Tinted negative |
| `3d_skew_negative_shine` | Negative with shine |
| `3d_skew_glitch` | Glitch/distortion |
| `3d_skew_oil_slick` | Oil slick iridescence |
| `3d_skew_polka_dot` | Polka dot pattern |
| `3d_skew_voucher` | Voucher/ticket style |
| `3d_skew_hologram` | Hologram effect |

---

## Performance Tips

1. **Use `autoOptimize = true`** - reduces redundant shader state changes
2. **Group entities by shader** - entities with same shaders batch better
3. **Prefer group defaults** - per-entity overrides have slight overhead
4. **Clean up destroyed entities** - call `removeFromAll()` when destroying

---

## Render Groups vs ShaderPipelineComponent

| Feature | Render Groups | ShaderPipelineComponent |
|---------|---------------|-------------------------|
| Per-entity component needed | No | Yes |
| Batch rendering | Yes | No (per-entity) |
| Multi-pass composition | Sequential only | Full pipeline control |
| Dynamic shader changes | Easy | Requires component update |
| Local draw commands | No | Yes |
| Best for | Many entities, same effects | Complex per-entity pipelines |

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
