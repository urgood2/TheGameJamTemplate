# Core Patterns

## pattern:core.entity_builder.create
**doc_id:** `pattern:core.entity_builder.create`
**Source:** assets/scripts/core/entity_builder.lua:14
**Frequency:** Found in 5 files

**Pattern:**
```lua
local entity, script = EntityBuilder.create({
    sprite = "kobold",
    position = { x = 100, y = 200 },
    size = { 64, 64 },
    data = { health = 100 },
})
```

**Preconditions:**
- `core.entity_builder` loaded
- `registry` available for entity creation
- `animation_system` available for sprite-backed spawn (falls back to raw entity)

**Verified:** Yes | Test: `test_core_patterns.lua::core.entity_builder.create`

---

## pattern:core.entity_builder.fluent_chain
**doc_id:** `pattern:core.entity_builder.fluent_chain`
**Source:** assets/scripts/core/procgen/spawner.lua:9
**Frequency:** Found in 3 files

**Pattern:**
```lua
return EntityBuilder.new("wall_tile")
    :at(wx, wy)
    :build()
```

**Preconditions:**
- `core.entity_builder` loaded
- Sprite ID is valid in the current scene

**Verified:** Yes | Test: `test_core_patterns.lua::core.entity_builder.fluent_chain`

---

## pattern:core.child_builder.attach_offset
**doc_id:** `pattern:core.child_builder.attach_offset`
**Source:** assets/scripts/core/child_builder.lua:12
**Frequency:** Found in 4 files

**Pattern:**
```lua
ChildBuilder.for_entity(weapon)
    :attachTo(player)
    :offset(20, 0)
    :rotateWith()
    :apply()
```

**Preconditions:**
- `transform.AssignRole` binding available
- `InheritedPropertiesType`, `InheritedPropertiesSync`, and `AlignmentFlag` enums available
- `core.component_cache` loaded

**Verified:** Yes | Test: `test_core_patterns.lua::core.child_builder.attach_offset`

---

## pattern:core.shader_builder.add_apply
**doc_id:** `pattern:core.shader_builder.add_apply`
**Source:** assets/scripts/core/shader_builder.lua:9
**Frequency:** Found in 10 files

**Pattern:**
```lua
ShaderBuilder.for_entity(entity)
    :add("3d_skew_holo")
    :apply()
```

**Preconditions:**
- `shader_pipeline` binding available
- `globalShaderUniforms` binding available
- `registry` available for `ShaderPipelineComponent`

**Verified:** Yes | Test: `test_core_patterns.lua::core.shader_builder.add_apply`

---

## pattern:core.physics_builder.basic_chain
**doc_id:** `pattern:core.physics_builder.basic_chain`
**Source:** assets/scripts/core/physics_builder.lua:13
**Frequency:** Found in 4 files

**Pattern:**
```lua
PhysicsBuilder.for_entity(entity)
    :circle()
    :tag("projectile")
    :bullet()
    :friction(0)
    :collideWith({ "enemy", "WORLD" })
    :apply()
```

**Preconditions:**
- `physics` module bound
- `PhysicsManager.get_world` available
- `registry` available for physics setup

**Verified:** Yes | Test: `test_core_patterns.lua::core.physics_builder.basic_chain`

---

## pattern:core.timer.after_basic
**doc_id:** `pattern:core.timer.after_basic`
**Source:** assets/scripts/core/main.lua:704
**Frequency:** Found in 11 files

**Pattern:**
```lua
local timer = require("core.timer")
local tag = timer.after(0.5, function()
    -- delayed work
end)
```

**Preconditions:**
- `core.timer` loaded

**Verified:** Yes | Test: `test_core_patterns.lua::core.timer.after_basic`

---

## pattern:core.timer.every_guarded_tick
**doc_id:** `pattern:core.timer.every_guarded_tick`
**Source:** assets/scripts/core/behaviors.lua:210
**Frequency:** Found in 7 files

**Pattern:**
```lua
timer.every(interval, function()
    if not entity_cache.valid(e) then
        return false
    end
    def.on_tick(e, ctx, helpers, config)
end, 0, immediate, nil, tag)
```

**Preconditions:**
- `core.timer` loaded
- `core.entity_cache` available for validity checks

**Verified:** Yes | Test: `test_core_patterns.lua::core.timer.every_guarded_tick`

---

## pattern:core.timer.tween_scalar
**doc_id:** `pattern:core.timer.tween_scalar`
**Source:** assets/scripts/core/main.lua:146
**Frequency:** Found in 6 files

**Pattern:**
```lua
timer.tween_scalar(
    duration,
    function() return getMainMenuEntityY(entity) end,
    function(v) setMainMenuEntityPosition(entity, x, v) end,
    y,
    nil,
    nil,
    tag
)
```

**Preconditions:**
- `core.timer` loaded
- Getter and setter functions are deterministic

**Verified:** Yes | Test: `test_core_patterns.lua::core.timer.tween_scalar`

---

## pattern:core.signal.emit
**doc_id:** `pattern:core.signal.emit`
**Source:** assets/scripts/core/grid_transfer.lua:123
**Frequency:** Found in 8 files

**Pattern:**
```lua
signal.emit("grid_transfer_failed", params.item, params.fromGrid, params.toGrid, reason)
```

**Preconditions:**
- `external.hump.signal` loaded into `signal`

**Verified:** Yes | Test: `test_core_patterns.lua::core.signal.emit`

---

## pattern:core.signal.register
**doc_id:** `pattern:core.signal.register`
**Source:** assets/scripts/core/main.lua:204
**Frequency:** Found in 4 files

**Pattern:**
```lua
signal.register("character_select_opened", function()
    setMainMenuVisible(false, { tween = true, duration = 0.25 })
end)
```

**Preconditions:**
- `external.hump.signal` loaded into `signal`

**Verified:** Yes | Test: `test_core_patterns.lua::core.signal.register`

---

## pattern:core.signal_group.cleanup
**doc_id:** `pattern:core.signal_group.cleanup`
**Source:** assets/scripts/core/signal_group.lua:73
**Frequency:** Found in 3 files

**Pattern:**
```lua
local group = SignalGroup.new("menu_signals")

group:on("game_state_changed", handler)

-- Later
group:cleanup()
```

**Preconditions:**
- `core.signal_group` loaded
- `signal` global bound to `external.hump.signal`

**Verified:** Yes | Test: `test_core_patterns.lua::core.signal_group.cleanup`

---

## pattern:core.event_bridge.attach
**doc_id:** `pattern:core.event_bridge.attach`
**Source:** assets/scripts/core/event_bridge.lua:271
**Frequency:** Found in 1 file

**Pattern:**
```lua
local EventBridge = require("core.event_bridge")
EventBridge.attach(ctx)
```

**Preconditions:**
- `ctx.bus` implements `:on(event, handler)`
- `signal` global bound to `external.hump.signal`

**Verified:** Yes | Test: `test_core_patterns.lua::core.event_bridge.attach`

<!-- AUTOGEN:BEGIN pattern_list -->
- `ChildBuilder attach with offset`
- `EntityBuilder fluent chain`
- `EntityBuilder.create config table`
- `Event bridge attach`
- `PhysicsBuilder fluent chain`
- `ShaderBuilder add and apply`
- `Signal emit`
- `Signal register`
- `SignalGroup cleanup`
- `Timer after basic`
- `Timer every guarded tick`
- `Timer tween scalar`
<!-- AUTOGEN:END pattern_list -->
