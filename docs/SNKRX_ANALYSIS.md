# SNKRX Systems Analysis

**Date**: 2025-11-21
**Issue**: #22
**Analyzed by**: Claude Code

## Overview

This document contains the analysis of SNKRX systems found in `todo_from_snkrx/done/` and their applicability to TheGameJamTemplate codebase.

## SNKRX Architecture (Lua/LÖVE)

SNKRX uses a mixin-based architecture where game objects compose functionality through mixins:
- `GameObject` - Base mixin with timer, spring, transform
- `Physics` - Adds Box2D physics bodies
- `Unit` - Adds HP, damage, stat calculations

### Files Analyzed

1. **shared.lua** - Visual style, color ramps, canvas system
2. **table.lua** - Extended table utilities
3. **objects.lua** - Game objects (SpawnMarker, LightningLine, Unit)
4. **steering.lua** - Steering behaviors for AI movement
5. **physics.lua** - Box2D physics wrapper with mixin pattern
6. **graphics.lua** - Unified drawing API
7. **player.lua**, **enemies.lua** - Entity definitions

## Current Codebase (C++/Raylib)

- **ECS**: EnTT entity component system
- **Physics**: Chipmunk2D (not Box2D)
- **Scripting**: LuaJIT via Sol2
- **Systems**: 38 modular system directories
- **AI**: GOAP system with Lua-defined actions

### Already Implemented

✅ **Timer System** - Comprehensive (`src/systems/timer/`)
- `timer_after`, `timer_every`, `timer_tween`, etc.
- Groups, multipliers, pausing
- Event queue system

✅ **Spring System** - Physics-based animation (`src/systems/spring/`)
- Stiffness, damping, velocity
- Adaptive updates, sleeping
- Pool-based optimization

✅ **Palette System** - Color management (`src/systems/palette/`)

✅ **Nodemap** - Skill tree navigation (`assets/scripts/nodemap/nodemap_headless.lua`)

✅ **Behavior Scripts** - GameObject pattern (`assets/scripts/monobehavior/behavior_script_v2.lua`)

## Missing Systems Worth Implementing

### 1. Steering Behaviors ⭐ HIGH PRIORITY

**Status**: Mentioned in TODO.md line 124
**Location**: Create `src/systems/steering/`

**Key Behaviors to Port**:

```cpp
// From steering.lua
- seek_point(x, y, deceleration, weight)
- seek_object(object, deceleration, weight)
- wander(rs, distance, jitter, weight)
- steering_separate(rs, class_avoid_list, weight)
- pursuit(target)
- evade(target)
```

**Integration Points**:
- Works with Chipmunk2D bodies
- Calculates steering forces, applies to velocity
- Max velocity and max force constraints
- Turn rate limiting

**Benefits**:
- Rich AI movement patterns
- Flocking behaviors
- Smooth pursuit/evade
- Organic-feeling movement

### 2. HitFX System ⭐ HIGH PRIORITY

**Purpose**: Visual feedback for hits and actions

**SNKRX Pattern**:
```lua
self.hfx:add('hit', 1)
self.hfx:use('hit', 0.25)
if self.hfx.hit.f then -- flash
  graphics.push(self.x, self.y, 0, self.hfx.hit.x, self.hfx.hit.x) -- scale
end
```

**Proposed Component**:
```cpp
struct HitEffectComponent {
    struct Effect {
        Spring scaleSpring;
        float flashTimer = 0.0f;
        bool flashing = false;
    };
    std::map<std::string, Effect> effects;
};
```

**Benefits**:
- Professional game feel
- Reusable hit feedback
- Integrates with existing spring system

### 3. Visual Effect Game Objects 📊 MEDIUM PRIORITY

**Port to Lua** (using existing behavior_script_v2.lua):

**SpawnMarker** - Enemy spawn telegraph
- Blinking effect with timer
- Spring-based scale animation
- Color and rotation

**LightningLine** - Procedural lightning
- Recursive midpoint displacement
- Generations for detail level
- Hit particles at endpoints

**HitCircle/HitParticle** - Impact effects
- Spring-based expansion/contraction
- Color transitions
- Automatic cleanup

**Implementation**:
```lua
SpawnMarker = class('SpawnMarker')
function SpawnMarker:init(x, y, color)
    self.x, self.y = x, y
    self.color = color
    self.spring = spring.new(0, 200, 10)
    self.spring:pull(0.5)
    timer.timer_every({0.195, 0.24}, function()
        self.hidden = not self.hidden
    end)
end
```

### 4. Canvas Layering System 📊 MEDIUM PRIORITY

**SNKRX Approach**:
1. Background canvas (checkerboard pattern)
2. Main game canvas (all gameplay)
3. Shadow canvas (offset copy with shader)
4. Star/particle canvas (decorative layer)

**Raylib Implementation**:
```cpp
RenderTexture2D backgroundLayer;
RenderTexture2D mainLayer;
RenderTexture2D shadowLayer;
RenderTexture2D vfxLayer;

// Render order:
// 1. Background to texture
// 2. Main game to texture
// 3. Apply shadow shader to main -> shadow texture
// 4. VFX to texture
// 5. Composite all to screen
```

**Benefits**:
- Professional depth with shadows
- Easy full-screen effects
- Layer-specific shaders
- Performance (cache static layers)

### 5. Enhanced GameObject Pattern 🔧 LOW PRIORITY

**Goal**: Make Lua entity creation more ergonomic

**Current**: behavior_script_v2.lua exists but could be enhanced

**SNKRX Pattern**:
```lua
Unit = Object:extend()
Unit:implement(GameObject)
Unit:implement(Physics)

function Unit:init(args)
    self:init_game_object(args)
    self:set_as_rectangle(w, h, 'dynamic', 'enemy')
    self.t:after(1, function() self:do_something() end)
    self.spring:pull(0.5)
end
```

**Enhancement**: Create base classes that expose:
- `self.timer` - Direct timer access
- `self.spring` - Direct spring access
- `self.transform` - Position, rotation, scale
- Automatic cleanup on `self.dead = true`

### 6. Unit Stat System 🔧 LOW PRIORITY

**From objects.lua**:
- Level-based HP/damage scaling
- Defense calculations: `dmg * (100/(100+def))`
- Boss vs normal enemy stat curves
- New Game Plus scaling

**Use Case**: RPG/roguelike elements

## Implementation Priority

### Phase 1: Game Feel
1. **HitFX Component** - Immediate visual improvement
2. **VFX Lua Classes** - SpawnMarker, LightningLine, HitCircle

### Phase 2: AI Enhancement
3. **Steering Behaviors** - Rich movement patterns
4. **Integration with GOAP** - Steering as GOAP actions

### Phase 3: Visual Polish
5. **Canvas Layering** - Shadows and depth
6. **Enhanced GameObject** - Better Lua DX

## Code Examples

### Steering Behavior Usage

```cpp
// C++ system
struct SteeringComponent {
    Vector2 heading;
    Vector2 steeringForce;
    float maxVelocity = 100.0f;
    float maxForce = 2000.0f;
    float mass = 1.0f;
};

void steering_system_update(entt::registry& reg, float dt) {
    auto view = reg.view<SteeringComponent, PhysicsComponent>();
    for (auto entity : view) {
        auto& steering = view.get<SteeringComponent>(entity);
        auto& physics = view.get<PhysicsComponent>(entity);

        // Calculate and apply steering force
        Vector2 force = steering.steeringForce / steering.mass;
        apply_force_to_chipmunk_body(physics.body, force);
    }
}
```

```lua
-- Lua usage
local enemy = registry.create()
registry.emplace(enemy, "SteeringComponent", {
    maxVelocity = 50,
    maxForce = 1000
})

-- In update:
steering.seek_point(enemy, player.x, player.y)
steering.separate(enemy, 40, {"Enemy"})
```

### HitFX Usage

```lua
-- Setup
registry.emplace(entity, "HitEffectComponent")

-- On hit
hfx.add_effect(entity, "hit", 1.0)
hfx.use_effect(entity, "hit", 0.25) -- duration

-- In render:
local effect = hfx.get_effect(entity, "hit")
if effect.flashing then
    -- Flash white or scale
    DrawCircle(x, y, radius * effect.scale, WHITE)
end
```

## Notes

- SNKRX uses LÖVE2D/Box2D, we use Raylib/Chipmunk2D
- Most table utilities are covered by C++ STL + Sol2
- Timer system is already more comprehensive than SNKRX's
- Spring system is already implemented and optimized
- Focus on gameplay-facing systems (steering, VFX, hit feedback)

## References

- Original SNKRX: https://github.com/a327ex/SNKRX
- TODO.md line 124: "add steering stuff in from snkrx"
- TODO.md line 18: Nodemap already available
- TODO.md line 16: Springs for custom rendering
