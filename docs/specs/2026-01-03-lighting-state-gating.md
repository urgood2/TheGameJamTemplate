# Lighting System State Gating

**Date:** 2026-01-03
**Status:** Draft
**Author:** Interview-driven spec

## Summary

Extend the lighting system to support game state awareness. Lights can be gated by entity state (PLANNING_STATE, ACTION_STATE, etc.), automatically hiding when their associated state is inactive and restoring when the state becomes active again.

## Motivation

Currently, lights attached to entities remain visible regardless of game state transitions. When switching from PLANNING to ACTION state, lights attached to planning-phase entities should disappear along with those entities. This creates a mismatch where visual effects outlive their logical context.

## Design Decisions

| Question | Decision | Rationale |
|----------|----------|-----------|
| Destroy vs hide on state exit | **Hide and restore** | Avoids recreation overhead; maintains light configuration |
| Fixed vs attached lights | **Both support state gating** | Consistent API; fixed lights may also be state-specific (e.g., shop ambiance) |
| Single vs multiple states | **Multiple states** | Flexible; light visible in PLANNING and ACTION but not SHOP |
| Default for attached lights | **Auto-inherit entity states** | Zero-config; mirrors entity visibility naturally |
| Default for no-tag entities | **Visible (treat as 'default')** | Prevents accidental light blackout on spawned entities |
| Evaluation timing | **Event-driven** | Efficient; responds to `game_state_changed` signal |
| Hidden entity destruction | **Immediate cleanup** | Prevents orphaned lights; clean memory semantics |
| Backwards compatibility | **Auto-inherit (may break)** | Cleaner long-term; existing attached lights gain state awareness |
| isValid() when hidden | **True (add isVisible())** | isValid = object exists; isVisible = currently rendering |
| Data structure | **State → lights index** | O(1) lookup per state; scales with many lights |
| Initialization | **Auto-register on require()** | Zero-config; lighting works when imported |
| Debug flag | **Lighting.setIgnoreStates(true)** | Bypass state gating for visual debugging |

## API Changes

### Builder Methods

```lua
-- Fluent builder addition for explicit state specification
local light = Lighting.point()
    :attachTo(entity)
    :activeStates({ PLANNING_STATE, ACTION_STATE })  -- NEW
    :radius(200)
    :create()

-- Fixed-position light with state gating
local shopLight = Lighting.point()
    :at(500, 300)
    :activeStates({ SHOP_STATE })
    :color("gold")
    :create()

-- Attached light with NO explicit states: auto-inherits from entity
local playerLight = Lighting.point()
    :attachTo(playerEntity)  -- Will mirror playerEntity's state tags
    :radius(150)
    :create()
```

### LightHandle Methods

```lua
-- Existing
light:isValid()        -- true if light object exists (even if hidden)
light:destroy()        -- Remove light completely
light:setPosition(x, y)
light:setRadius(r)
-- etc.

-- NEW
light:isVisible()           -- true if currently rendering (state active)
light:getActiveStates()     -- returns array of state strings, or nil if always-visible
light:setActiveStates({...}) -- dynamically change states
```

### Module-Level API

```lua
-- NEW: Global debug toggle
Lighting.setIgnoreStates(true)   -- All lights visible regardless of state
Lighting.setIgnoreStates(false)  -- Normal state-aware behavior

-- Existing (unchanged)
Lighting.enable(layerName, opts)
Lighting.disable(layerName)
Lighting.pause(layerName)
Lighting.resume(layerName)
Lighting.setAmbient(layerName, level)
Lighting.getDebugInfo()  -- Will now include state info per light
```

## Signal Integration

### New Signal: `game_state_changed`

The lighting system auto-registers a handler on `require()`:

```lua
-- Emitted by state transition code (e.g., gameplay.lua)
signal.emit("game_state_changed", {
    previous = "PLANNING",
    current = "SURVIVORS",  -- ACTION uses SURVIVORS internally
})
```

### Lighting Response

On `game_state_changed`:
1. Look up all lights in the **previous** state index → mark hidden
2. Look up all lights in the **current** state index → mark visible
3. For entity-attached lights, also check entity's current StateTag component

## Internal Data Structures

### Light Object (Extended)

```lua
local light = {
    _id = 42,
    _layerName = "sprites",
    _destroyed = false,
    _hidden = false,  -- NEW: state-based visibility

    -- State configuration
    _activeStates = nil,          -- nil = auto-inherit or always-visible
    _autoInheritStates = true,    -- NEW: for attached lights

    -- Existing fields
    type = LIGHT_TYPE_POINT,
    worldX = 100,
    worldY = 200,
    radius = 150,
    intensity = 1.0,
    color = { 1.0, 0.5, 0.0 },
    attachedEntity = entity,
}
```

### State Index

```lua
-- Lighting._stateIndex[stateName] = { light1, light2, ... }
Lighting._stateIndex = {
    ["PLANNING"] = { light1, light3 },
    ["SURVIVORS"] = { light2, light3 },
    ["SHOP"] = { light4 },
}
```

## Visibility Rules

### Attached Lights (No Explicit States)

```
IF light.attachedEntity exists AND entity is valid:
    IF entity has StateTag component:
        light is visible IF any entity state tag matches current active game state
    ELSE (entity has no state tags):
        light is visible (treat as "default" / always-on)
ELSE:
    Standard attached-entity cleanup (destroy light)
```

### Attached Lights (Explicit :activeStates())

```
light is visible IF:
    current active game state is in light._activeStates array
    AND attached entity is valid
```

### Fixed-Position Lights

```
IF light._activeStates is nil:
    light is always visible
ELSE:
    light is visible IF current game state is in light._activeStates
```

## Implementation Notes

### Shader Uniform Sync

In `Lighting._syncUniforms()`, hidden lights should be treated like destroyed lights:

```lua
for i, light in ipairs(state.lights) do
    if light._hidden then
        -- Skip, don't send to shader
        goto continue
    end
    -- ... existing uniform sync code
    ::continue::
end
```

### Entity Destruction While Hidden

The existing `Lighting._update()` already checks `entity_cache.valid(light.attachedEntity)`. This handles immediate cleanup even for hidden lights since validity check is independent of visibility.

### Signal Auto-Registration

```lua
-- At bottom of lighting.lua, before return
local signal = require("external.hump.signal")
signal.register("game_state_changed", function(data)
    Lighting._onStateChanged(data.previous, data.current)
end)
```

## Migration Impact

### Breaking Changes

Existing attached lights will now auto-inherit state behavior. If a light is attached to an entity with `PLANNING_STATE` tag, it will disappear during ACTION phase.

**Workaround for always-visible attached lights:**
```lua
-- Explicit empty array = visible in all states
local light = Lighting.point()
    :attachTo(entity)
    :activeStates({})  -- Empty = always visible
    :create()
```

### Files to Modify

1. `assets/scripts/core/lighting.lua` - Core implementation
2. `assets/scripts/core/shader_uniforms.lua` - May need hidden light filtering
3. `assets/scripts/core/gameplay.lua` - Emit `game_state_changed` signal on transitions

### Files to Create

None - all changes in existing files.

## Testing Checklist

- [ ] Point light follows entity, disappears on state change, reappears on return
- [ ] Spotlight with explicit :activeStates() only visible in specified states
- [ ] Fixed-position light with :activeStates() gated correctly
- [ ] Entity destroyed while hidden → light cleaned up immediately
- [ ] Entity with no state tags → attached light always visible
- [ ] Lighting.setIgnoreStates(true) makes all lights visible
- [ ] light:isVisible() returns correct value based on state
- [ ] light:getActiveStates() returns configured states
- [ ] light:isValid() returns true even when hidden
- [ ] Empty :activeStates({}) = always visible (opt-out of auto-inherit)
- [ ] Multiple lights in same state all toggle together
- [ ] Performance: no frame drops with 16 lights and frequent state changes

## Open Questions

None - all decisions made during interview.

## Appendix: Current State System Reference

```lua
-- From constants.lua
Constants.States = {
    PLANNING = "PLANNING",
    ACTION = "SURVIVORS",  -- Note: ACTION uses "SURVIVORS" internally
    MENU = "MENU",
    PAUSED = "PAUSED",
    GAME_OVER = "GAME_OVER",
    DEFAULT = "default",
}

-- C++ bindings (globals)
add_state_tag(entity, stateString)
clear_state_tags(entity)
remove_default_state_tag(entity)
is_state_active(stateString)  -- Checks global game state
```

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
