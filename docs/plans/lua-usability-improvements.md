# Lua Usability Improvement Plan

> Generated: 2026-01-17
> Status: Draft - Pending Review

## Executive Summary

Based on comprehensive codebase analysis, I've identified **10 high-impact improvements** that will significantly speed up development while maintaining stability. The plan focuses on extending existing patterns (Q.lua, EntityBuilder, timer.sequence) rather than introducing new paradigms.

**Key Metrics**:
- 617 `component_cache.get()` calls reducible
- 200+ timer calls with confusing 7-param API
- 51 animation setup sequences (10-15 lines each)
- 54 signal handlers without cleanup

**Estimated Total**: ~2000+ lines of boilerplate reducible

---

## Phase 1: Quick Wins (2-3 days, HIGH impact)

### 1. Extend Q.lua with Component Shortcuts

**Problem**: 617 `component_cache.get()` calls across 75 files. Q.lua exists but only covers Transform.

**Current friction**:
```lua
local transform = component_cache.get(entity, Transform)
local go = component_cache.get(entity, GameObject)
local anim = component_cache.get(entity, AnimationQueueComponent)
```

**Solution**:
```lua
-- New shortcuts (follow existing Q.getTransform pattern)
Q.getGameObject(entity)      -- returns GameObject or nil
Q.getAnimation(entity)       -- returns AnimationQueueComponent or nil
Q.getUIConfig(entity)        -- returns UIConfig or nil
Q.getCollision(entity)       -- returns CollisionShape2D or nil

-- Callback pattern (existing Q.withTransform style)
Q.withGameObject(entity, function(go)
    go.state.visible = true
end)

-- Bulk getter for multiple components
Q.components(entity, "transform", "gameObject", "animation")
-- Returns: { transform = ..., gameObject = ..., animation = ... }
```

**Implementation Notes**:
- Key file: `assets/scripts/core/Q.lua`
- Add 8-10 functions following existing `getTransform`/`withTransform` pattern
- Backward compatible: additive only
- Estimated complexity: **S** (small)

**Success Criteria**:
- All new functions return nil safely for invalid entities
- Existing Q.lua tests pass
- Can replace 50+ common `component_cache.get()` patterns

---

### 2. Timer Opts Promotion

**Problem**: 130+ `timer.after()` and 71 `timer.every()` calls use confusing positional parameters:
- `timer.every(delay, action, times, immediate, after, tag, group)` - 7 params!
- Easy to mix up `tag` and `group`

**Current friction**:
```lua
-- What does 10, true, nil, "update" mean?
timer.every(0.5, function() update() end, 10, true, nil, "update", "gameplay")
```

**Solution**:
```lua
-- Already available but underused - PROMOTE THESE:
timer.after_opts({ delay = 2.0, action = fn, tag = "my_timer" })
timer.every_opts({ delay = 0.5, action = fn, times = 10, immediate = true })

-- NEW: Add missing opts variants
timer.tween_opts({ ... })           -- opts wrapper for tweens
timer.physics_every_opts({ ... })   -- opts wrapper for physics timers

-- NEW: Convenience alias
timer.delay(0.5, fn)                -- simple 2-arg version
timer.delay(0.5, fn, { tag = "x" }) -- with options
```

**Implementation Notes**:
- Key file: `assets/scripts/core/timer.lua`
- Add missing `_opts` variants (tween, physics)
- Add `timer.delay()` convenience function
- Update CLAUDE.md examples to prefer opts
- Estimated complexity: **S** (small)

**Success Criteria**:
- All timer functions have opts variants
- New code uses opts by default
- CLAUDE.md updated with recommended patterns

---

## Phase 2: New Builders (3-4 days, HIGH impact)

### 3. AnimationBuilder - Fluent Animation Setup

**Problem**: 51 uses of `animation_system.createAnimatedObjectWithTransform()` followed by 3-15 lines of boilerplate.

**Current friction (10-15 lines)**:
```lua
local entity = animation_system.createAnimatedObjectWithTransform(spriteId, true, x, y, nil, false)
animation_system.resizeAnimationObjectsInEntityToFit(entity, w, h)
local animComp = component_cache.get(entity, AnimationQueueComponent)
if animComp then
    animComp.drawWithLegacyPipeline = true
end
transform.set_space(entity, "screen")
setFGColorForAllAnimationObjects(entity, color)
registry:emplace(entity, ScreenSpaceCollisionMarker)
remove_default_state_tag(entity)
add_state_tag(entity, PLANNING_STATE)
```

**Solution**:
```lua
local AnimationBuilder = require("core.animation_builder")

-- Fluent API
local entity = AnimationBuilder.new("sprite.png")
    :at(100, 200)
    :size(64, 64)
    :screenSpace()              -- sets transform space + collision marker
    :shaderPipeline(true)       -- drawWithLegacyPipeline = true
    :tint(1, 0.8, 0.8, 1)
    :state(PLANNING_STATE)
    :build()

-- Quick static method for common case
local entity = AnimationBuilder.quick("sprite.png", x, y, w, h, {
    screenSpace = true,
    state = PLANNING_STATE
})
```

**Implementation Notes**:
- New file: `assets/scripts/core/animation_builder.lua`
- Wraps `animation_system.createAnimatedObjectWithTransform()`
- Follow EntityBuilder's dual API pattern (fluent + static)
- Estimated complexity: **M** (medium)

**Success Criteria**:
- Reduces 10-15 line patterns to 3-5 lines
- All existing animation tests pass
- Integrates with ShaderBuilder for compound operations

---

### 4. Signal Auto-Cleanup

**Problem**: 54 `signal.register()` calls found, but only 1-2 use `signal_group` for cleanup. Handler leaks are likely.

**Current friction**:
```lua
-- Registered but never cleaned up
signal.register("enemy_killed", function(entity) ... end)
```

**Solution**:
```lua
local signal_group = require("core.signal_group")

-- Existing (promote this):
local handlers = signal_group.new("my_module")
handlers:on("enemy_killed", fn)
handlers:cleanup()  -- clears all

-- NEW: Entity-scoped signals (auto-cleanup on destroy)
local entity_signals = require("core.entity_signals")

-- Auto-removes handler when entity is destroyed
entity_signals.on(entity, "enemy_killed", function(e) ... end)

-- Or attach to script lifecycle
function Script:on_create()
    self:on("enemy_killed", function(e) ... end)  -- auto-cleanup on destroy
end
```

**Implementation Notes**:
- Enhance existing `assets/scripts/core/signal_group.lua`
- New file: `assets/scripts/core/entity_signals.lua`
- Hook into entity destruction system
- Estimated complexity: **M** (medium)

**Success Criteria**:
- Entity destruction cleans up attached signal handlers
- No memory leaks from orphaned handlers
- signal_group usage increases

---

## Phase 3: Unification (2-3 days, MEDIUM impact)

### 5. Unified Spawn Module

**Problem**: Creating game entities requires combining 3-4 systems: EntityBuilder + PhysicsBuilder + ShaderBuilder + animation.

**Current friction**:
```lua
local entity = animation_system.createAnimatedObjectWithTransform(...)
PhysicsBuilder.for_entity(entity):circle():tag("projectile"):apply()
ShaderBuilder.for_entity(entity):add("glow"):apply()
add_state_tag(entity, ACTION_STATE)
```

**Solution**:
```lua
local spawn = require("core.spawn")

-- Unified creation with domain-specific defaults
local entity = spawn.enemy("goblin", x, y, {
    size = { 64, 64 },
    physics = { shape = "circle", tag = "enemy" },
    shaders = { "damage_flash" },
    state = ACTION_STATE,
    data = { health = 100 }
})

-- Specific helpers with smart defaults
spawn.projectile("fireball", x, y, { angle = 0, speed = 300 })
spawn.pickup("gold_coin", x, y, { value = 10 })
spawn.effect("explosion", x, y, { duration = 0.5 })
spawn.ui_sprite("icon.png", x, y, { screenSpace = true })
```

**Implementation Notes**:
- Enhance existing `assets/scripts/core/spawn.lua`
- Internally uses EntityBuilder, PhysicsBuilder, AnimationBuilder
- Domain-specific defaults (enemy = has health, projectile = has velocity)
- Estimated complexity: **M** (medium)

**Success Criteria**:
- One-liner entity creation for common cases
- Reduces 5-10 line patterns to 1-2 lines
- Type-specific defaults reduce configuration

---

### 6. Naming Convention Documentation

**Problem**: API inconsistency across modules:
- `Q.visualCenter` (camelCase) vs `entity_cache.valid` (snake_case)
- `EntityBuilder.for_entity()` vs `EntityBuilder.new()` vs `EntityBuilder.create()`
- Some functions return bool, some return nil, some throw

**Solution**: Establish and document conventions in CLAUDE.md:

```lua
-- CONVENTION: Use camelCase for quick helpers (Q.lua style)
Q.getTransform, Q.isValid, Q.visualCenter

-- CONVENTION: Use snake_case for system modules
entity_cache.valid, component_cache.get, timer.after_opts

-- CONVENTION: Builder instantiation
Builder.for_entity(entity)  -- fluent, modifying existing
Builder.new(...)            -- fluent, creating new
Builder.quick(...)          -- static, one-liner

-- CONVENTION: Returns
-- nil on failure (safe to chain)
-- print warning, don't throw
```

**Implementation Notes**:
- Document in CLAUDE.md under "API Conventions"
- Add aliases for inconsistent functions (don't break existing)
- Phase out over time
- Estimated complexity: **S** (small for docs, M for aliases)

**Success Criteria**:
- Clear documentation of conventions
- New code follows conventions
- Aliases available for legacy code

---

## Phase 4: Developer Experience (2-3 days, MEDIUM impact)

### 7. EntityBuilder Result Enhancement

**Problem**: EntityBuilder creates entities but requires component_cache.get() for follow-up access.

**Current friction**:
```lua
local entity, script = EntityBuilder.create({ ... })
local transform = component_cache.get(entity, Transform)
local go = component_cache.get(entity, GameObject)
```

**Solution**:
```lua
local result = EntityBuilder.create({ ... })

-- Access via result object
result.entity       -- raw entity ID
result.script       -- script table
result.transform    -- Transform component (lazy-loaded)
result.gameObject   -- GameObject component (lazy-loaded)

-- Backward compatible destructuring still works
local entity, script = EntityBuilder.create({ ... })

-- New fluent access
EntityBuilder.new("sprite"):at(100, 200):build()
    :getTransform()  -- returns Transform component
```

**Implementation Notes**:
- Modify return value to be a table with `__call` metamethod for backward compat
- Add lazy getters for common components
- Estimated complexity: **M** (medium)

**Success Criteria**:
- Backward compatible with existing `entity, script = ...` destructuring
- Reduces follow-up component_cache.get() calls
- Clear component access in fluent chains

---

### 8. Debug Helpers Enhancement

**Problem**: Debugging entity issues requires manually checking components, bounds, z-order.

**Current friction**:
```lua
print("Transform:", component_cache.get(entity, Transform))
print("Z-order:", layer_order_system.getZIndex(entity))
print("Collision:", component_cache.get(entity, CollisionShape2D))
```

**Solution**:
```lua
local debug = require("core.debug")

-- Console dump
debug.entity(entity)  -- prints all components, position, z-order, state
debug.entities(entityList)  -- summary table

-- Visual debugging (render overlays)
debug.bounds(entity, "red")       -- draw collision bounds
debug.origin(entity)              -- draw position marker
debug.zOrder(entity)              -- show z-order number
debug.velocity(entity)            -- draw velocity vector
debug.enableAll()                 -- show all debug overlays

-- Conditional (only in debug builds)
debug.assert(condition, "message", entity)
debug.watch("player_health", player.health)  -- on-screen watch
```

**Implementation Notes**:
- Enhance existing `assets/scripts/core/debug.lua`
- Hook into render system for overlays
- Conditional compilation for release builds
- Estimated complexity: **M** (medium)

**Success Criteria**:
- One-liner entity inspection
- Visual debugging reduces print-debugging
- Easy to enable/disable

---

## Phase 5: Nice-to-Have (3-4 days, LOW impact)

### 9. Tween Builder

**Problem**: Tweening properties requires knowing the timer.tween API and easing functions.

**Current friction**:
```lua
timer.tween(0.5, transform, { actualX = 100 }, "linear", function() end)
```

**Solution**:
```lua
local tween = require("core.tween")

tween.to(entity)
    :prop("x", 100)
    :prop("y", 200)
    :duration(0.5)
    :ease("outQuad")
    :onComplete(fn)
    :start()

-- Quick version
tween.move(entity, targetX, targetY, 0.5)
tween.fade(entity, 0, 0.3)
tween.scale(entity, 2, 2, 0.5)
```

**Implementation Notes**:
- New file: `assets/scripts/core/tween_builder.lua` (or enhance existing `tween.lua`)
- Wraps timer.tween internally
- Entity-aware (auto-gets transform)
- Estimated complexity: **M** (medium)

**Success Criteria**:
- Replaces manual timer.tween calls
- Entity-aware (no manual component access)
- Common operations (move, fade, scale) are one-liners

---

### 10. FSM Builder for Entity States

**Problem**: Entity state machines are implemented ad-hoc with if/else chains.

**Solution**:
```lua
local fsm = require("core.fsm")

local enemyFSM = fsm.define({
    initial = "idle",
    states = {
        idle = {
            enter = function(e) stopMoving(e) end,
            update = function(e, dt) if playerNear(e) then return "chase" end end
        },
        chase = {
            enter = function(e) startChasing(e) end,
            update = function(e, dt) if playerFar(e) then return "idle" end end
        }
    }
})

-- Attach to entity
enemyFSM:attach(entity)
```

**Implementation Notes**:
- New file: `assets/scripts/core/fsm.lua`
- Similar to existing `behaviors.lua` pattern
- Estimated complexity: **M** (medium)

**Success Criteria**:
- Replaces ad-hoc state management
- Clear state transitions
- Debug-friendly (can inspect current state)

---

## Implementation Order

| Phase | Improvements | Effort | Impact |
|-------|--------------|--------|--------|
| **1** | Q.lua extensions (#1), Timer opts (#2) | 2-3 days | HIGH |
| **2** | AnimationBuilder (#3), Signal cleanup (#4) | 3-4 days | HIGH |
| **3** | Spawn module (#5), Naming docs (#6) | 2-3 days | MEDIUM |
| **4** | EntityBuilder result (#7), Debug helpers (#8) | 2-3 days | MEDIUM |
| **5** | Tween builder (#9), FSM builder (#10) | 3-4 days | LOW |

**Total Estimated Effort**: 12-17 days

---

## Impact Summary

| Improvement | Lines Saved | Frequency | Risk |
|-------------|-------------|-----------|------|
| Q.lua extensions | 2-3/use | 617 uses | Low |
| Timer opts | 1-2/use | 200+ uses | Low |
| AnimationBuilder | 8-12/use | 51 uses | Low |
| Signal cleanup | N/A (prevents bugs) | 54 uses | Low |
| Spawn module | 5-8/use | 100+ uses | Low |
| Debug helpers | N/A (DX) | Daily use | Low |

---

## Open Questions

1. **Backward Compatibility**: Should deprecated APIs (positional timer params) emit warnings, or remain silent?

2. **Module Organization**: Should AnimationBuilder be standalone or merged into EntityBuilder?

3. **Debug Module**: Should debug overlays be always available or conditionally compiled out for release?

4. **Priority Adjustment**: Are there specific pain points to elevate in priority?
