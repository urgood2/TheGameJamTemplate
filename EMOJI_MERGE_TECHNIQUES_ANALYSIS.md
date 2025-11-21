# Emoji-Merge Repository: Extractable Techniques & Systems

## Executive Summary

This document analyzes the **emoji-merge** repository (a Lua/LÖVE framework game) and compares it with the current C++/Raylib codebase to identify transferable architectural patterns, design philosophies, and implementation techniques.

**Repository URLs:**
- **emoji-merge**: https://github.com/urgood2/emoji-merge (Lua + LÖVE framework)
- **Current project**: C++/Raylib with CMake, EnTT, Sol2, Chipmunk2D physics

---

## Key Architectural Patterns from Emoji-Merge

### 1. Framework Abstraction Layer ⭐⭐⭐

**Concept**: Gameplay code never directly calls framework functions. All framework interaction goes through a middleware layer.

**Benefits**:
- Enables framework swapping with minimal gameplay code changes
- Reduces technological risk (licensing changes, framework abandonment)
- Clean separation between engine and gameplay code

**Current Status in Our Codebase**:
✅ **Already Implemented** - The current codebase achieves this through:
- Lua scripting layer (Sol2 bindings) abstracts C++ systems
- Systems-based architecture with clean interfaces
- Assets live in `assets/scripts/` and interact through exposed APIs

**Recommendation**: Continue current approach. Already following best practices.

---

### 2. Mixin-Based Composition System ⭐⭐

**Concept**: Instead of inheritance hierarchies, use composable "mixins" that add capabilities to any object.

**emoji-merge Pattern**:
```lua
-- All objects inherit from "anchor" base class
-- Mixins add functionality via anchor:class_add(mixin_module)
object:timer_after(...)  -- Timer mixin
object:collider_init()   -- Collider mixin
object:seek_point()      -- Steering mixin
```

**Current Status in Our Codebase**:
✅ **Already Implemented** via EnTT ECS:
- Components are composable capabilities
- Systems operate on component combinations
- Lua scripts can add/query components dynamically
- See: `src/systems/` directory structure

**Recommendation**: Our ECS approach is superior for C++. No changes needed.

---

### 3. Locality Principle (Code Organization) ⭐⭐⭐⭐

**Concept**: All related behavior for a feature should be defined in one code location, not scattered across callbacks.

**emoji-merge Implementation**:
- Timers with closures keep behavior local to definition site
- Observer patterns execute when state transitions occur
- All multi-frame logic lives in single function bodies

**Current Status in Our Codebase**:
⚠️ **Partially Implemented**:
- Timer system exists (see `assets/scripts/timer_docs.md`)
- Comprehensive timer API with `after`, `every`, `for_time`, `tween`
- Event system exists (EventQueueSystem)

**Areas for Improvement**:
1. **Pattern documentation**: Create examples showing "locality-first" patterns
2. **Best practices guide**: Document how to keep related behavior together
3. **Code review checklist**: Check for scattered callbacks that could be localized

**Recommendation**: Create a best practices document (see Section 7).

---

### 4. Fixed Timestep with Smart Input Handling ⭐⭐

**Concept**: Input handling occurs within fixed updates to prevent dropped inputs during frame rate fluctuations.

**Current Status in Our Codebase**:
✅ **Already Implemented**:
- Main loop system exists: `src/systems/main_loop_enhancement/main_loop.cpp`
- Physics uses Chipmunk2D with fixed timestep
- Input system: `src/systems/input/`

**Recommendation**: Document current main loop architecture if not already done.

---

### 5. Deferred Rendering via Layer Commands ⭐⭐⭐

**Concept**: Drawing occurs through layer objects that store draw commands for later execution, enabling arbitrary ordering.

**emoji-merge Pattern**:
```lua
-- Commands stored as tables with z-index
layer:add_command({type='circle', x=10, y=10, r=5, z=100})
-- Executed during dedicated draw phase
```

**Current Status in Our Codebase**:
✅ **Already Implemented**:
- Layer system exists: `src/systems/layer/`
- Command buffer: `layer_command_buffer.cpp`
- Optimized rendering: `layer_optimized.cpp`
- Z-ordering support

**Recommendation**: Our implementation is more sophisticated. No changes needed.

---

### 6. Timer-Driven State Machines ⭐⭐⭐⭐⭐

**Concept**: Use timer primitives to create lightweight state machines without explicit FSM code.

**emoji-merge Patterns**:
```lua
-- Push/knockback state
self:start_push(force, direction)
self:update_push_state(end_speed)  -- Auto-exits when velocity < threshold

-- Status effects with hooks
Status.apply(self, 'stunned', 3.0, on_start_fn, on_end_fn)

-- Boss attack patterns
self.t:every(6, function()
  self.t:during(2.0, telegraph_fn, release_fn)
end)
```

**Current Status in Our Codebase**:
✅ **System exists** but patterns underutilized:
- Timer API has all necessary primitives
- Examples in `assets/SNKRX_code_snippets_and_techniques.md` (20 patterns!)
- Combat system has some patterns: `assets/scripts/combat/`

**Opportunities**:
1. **Extract more patterns** from emoji-merge for AI behaviors
2. **Create pattern library** for common state machines (cooldowns, charges, etc.)
3. **Document timer-based FSM alternatives** to explicit state enums

**Recommendation**: Create new pattern documentation (see Section 8).

---

### 7. Proc/Chance System (Centralized RNG) ⭐⭐⭐

**Concept**: All probability-based triggers (crit, stun, proc effects) go through one consistent system.

**emoji-merge Pattern**:
```lua
Proc = {}
function Proc.roll(pct) return random:bool(pct) end
function Proc.critical(ctx)
  if Proc.roll(ctx.crit_chance) then return ctx.crit_mult end
  return 1
end
```

**Current Status in Our Codebase**:
⚠️ **Needs Consolidation**:
- Random library exists (effolkronium_random)
- Combat system exists but proc logic may be scattered
- Wand system has execution logic: `assets/scripts/wand/`

**Recommendation**:
1. Create centralized proc system in Lua
2. Document common proc patterns (crit, dodge, status application)
3. Add to combat system documentation

---

### 8. Telegraph + Payoff Pattern (Visual Feedback) ⭐⭐⭐⭐

**Concept**: Separate attack phases into "telegraph" (charging) and "payoff" (release) with visual hooks.

**emoji-merge Pattern**:
```lua
-- Color telegraph
self.t:tween(2.0, self.color, target_color, easing, function()
  self.t:tween(0.25, self.color, release_color)
  -- Execute attack
end)

-- Progress bar for charge
local t, c = self.t:get_timer_and_delay('boss_attack')
local progress = (c and c > 0) and (t/c) or 0
```

**Current Status in Our Codebase**:
✅ **Components exist** but pattern needs documentation:
- Tween support in timer system
- Color system: `assets/scripts/color/`
- Animation system: `src/systems/anim_system.cpp`
- Spring system: `src/systems/spring/`

**Recommendation**: Create telegraph pattern examples showing:
- Color charging with tweens
- Progress bar extraction from timers
- Screen shake + spring combinations
- Sound effect timing

---

### 9. Area Sensors as First-Class Objects ⭐⭐⭐

**Concept**: Reuse geometric shapes (circles, rectangles) for both queries and debug visualization.

**emoji-merge Pattern**:
```lua
self.area_sensor = Circle(self.x, self.y, 128)
-- Update position
self.area_sensor:move_to(self.x, self.y)
-- Query
local enemies = self:get_objects_in_shape(self.area_sensor, enemy_list)
```

**Current Status in Our Codebase**:
✅ **Already Implemented**:
- Quadtree system: `src/systems/collision/`
- Chipmunk2D shapes for physics queries
- Broad phase optimization: `broad_phase.cpp`

**Recommendation**: Document pattern for creating persistent query shapes that follow entities.

---

### 10. Pull/Push Force Fields ⭐⭐⭐

**Concept**: Apply forces proportional to distance for natural-feeling area effects.

**emoji-merge Pattern**:
```lua
for _, e in ipairs(enemies_in_radius) do
  local angle = e:angle_to_point(center_x, center_y)
  local force = remap(distance, 0, max_radius, 400, 200)  -- Stronger at center
  e:apply_steering_force(force, angle)
end
```

**Current Status in Our Codebase**:
✅ **Physics system supports this**:
- Chipmunk2D for force application
- Steering behaviors: `src/systems/physics/steering.cpp`
- Crane system for constraints: `crane_system.cpp`

**Recommendation**: Add Lua helper functions for common force field patterns.

---

## Systems Already Superior in Our Codebase

### 1. Physics Integration
- **Chipmunk2D** (robust, production-tested) vs emoji-merge's Box2D wrapper
- Transform-physics hook system: `transform_physics_hook.cpp`
- Advanced constraints and joints

### 2. Scripting Architecture
- **Sol2 + Lua 5.4** with comprehensive bindings
- Hot reload: `lua_hot_reload.cpp`
- Registry bond system: `registry_bond.cpp`
- Tracy integration for profiling Lua

### 3. Rendering Pipeline
- **Shader system**: `src/systems/shaders/`
- Multiple render passes and layers
- Text effects: `src/systems/text/`
- Particle system (archived but available)
- Nine-slice UI: `9slice_u9_configurable_snippet.md`

### 4. Asset Management
- **LDtk level loader** with rule import
- Localization system with Babel support
- Animation system with warnings/documentation
- Asset streaming for web builds

### 5. Development Tools
- **ImGui console** with logging
- Tutorial system v2
- Entity state management
- UUID system for persistent references
- Tracy profiling integration

---

## Philosophical Alignments

Both codebases share similar design philosophies:

### 1. Code Ownership over Framework Lock-in
- ✅ emoji-merge: Abstract framework calls
- ✅ Our codebase: Lua scripting layer + system abstraction

### 2. Composition over Inheritance
- ✅ emoji-merge: Mixin system
- ✅ Our codebase: ECS (EnTT) + component composition

### 3. Documentation as First-Class Citizen
- ✅ emoji-merge: Extensive README architecture docs
- ✅ Our codebase: 90+ markdown docs in assets/

### 4. Rapid Iteration via Scripting
- ✅ emoji-merge: Pure Lua gameplay code
- ✅ Our codebase: Lua scripts with C++ performance layer

---

## Extractable Patterns (Prioritized)

### High Priority (Implement Now)

#### 1. Timer-Based State Machine Pattern Library
Create `assets/scripts/state_machine_patterns.md` with examples:
- Cooldown with telegraph
- Charge-and-release attacks
- Status effect stacking
- Pushback/knockback states
- Boss phase transitions

#### 2. Centralized Proc System
Create `assets/scripts/combat/proc_system.lua`:
```lua
-- Centralized RNG for combat events
ProcSystem = {}
function ProcSystem.roll(chance) -- 0-100
function ProcSystem.critical(context)
function ProcSystem.dodge(context)
function ProcSystem.status_apply(effect_name, chance, context)
```

#### 3. Code Locality Best Practices Guide
Create `CODE_LOCALITY_PATTERNS.md`:
- When to use timers vs explicit states
- Closure patterns for context preservation
- Tag-based timer management
- Event system vs callback chains

### Medium Priority (Next Sprint)

#### 4. Force Field Helper Functions
Add to Lua physics API:
```lua
physics.apply_radial_force(center_x, center_y, radius, force, entity_list)
physics.apply_pull_force(center_x, center_y, radius, entities, falloff_curve)
physics.apply_explosion_force(center_x, center_y, radius, force, entities)
```

#### 5. Telegraph Pattern Examples
Create `assets/scripts/combat/telegraph_patterns.md`:
- Color charging with progress bars
- Screen shake + spring combos
- Multi-phase attack sequences
- Interrupt handling

#### 6. Area Query Optimization Patterns
Document best practices for:
- Persistent sensor shapes
- Query result caching
- Broad-phase optimization
- Debug visualization

### Low Priority (Future Consideration)

#### 7. Steering Behavior Cookbook
Expand `steering.cpp` with high-level patterns:
- Wander + seek combinations
- Separation from multiple groups
- Formation following
- Orbit behaviors

#### 8. Death Payload Pipeline
Create composable death effects:
- Loot drop timing
- Chain reactions
- VFX/SFX coordination
- Score/stat updates

---

## Techniques NOT Worth Extracting

### 1. God Objects
- **Why not**: ECS is superior for C++ performance and cache locality
- **emoji-merge uses this**: Due to Lua's dynamic nature and LÖVE simplicity
- **Keep current approach**: EnTT component composition

### 2. Global State via Main Object
- **Why not**: Leads to tight coupling and testing difficulties
- **emoji-merge uses this**: Acceptable in small Lua projects
- **Keep current approach**: Dependency injection and system isolation

### 3. Manual Memory Management with `.dead` Flags
- **Why not**: Modern C++ has RAII and smart pointers
- **emoji-merge uses this**: Lua GC requires explicit cleanup hints
- **Keep current approach**: RAII guards (see `RAII_GUARDS_IMPLEMENTATION_SUMMARY.md`)

### 4. Text-as-Objects Character System
- **Why not**: CPU-intensive for C++; better solutions exist
- **emoji-merge uses this**: Enables easy per-character effects in Lua
- **Keep current approach**: Shader-based text effects

---

## Action Items

### Immediate (This Sprint)
1. ✅ Create this analysis document
2. ⬜ Create `STATE_MACHINE_PATTERNS.md` with timer-based FSM examples
3. ⬜ Create `CODE_LOCALITY_PATTERNS.md` best practices guide
4. ⬜ Implement centralized `ProcSystem` in Lua

### Next Sprint
5. ⬜ Create `TELEGRAPH_PATTERNS.md` with visual feedback examples
6. ⬜ Add force field helper functions to Lua physics API
7. ⬜ Document area query optimization patterns

### Future
8. ⬜ Expand steering behavior documentation
9. ⬜ Create death payload pipeline system
10. ⬜ Review SNKRX patterns vs emoji-merge patterns for duplicates

---

## Conclusion

The emoji-merge repository demonstrates excellent **architectural thinking** around framework abstraction and code locality. However, our current C++/Raylib codebase already implements most of these patterns through:

- **ECS (EnTT)** for composition over inheritance
- **Lua scripting** for framework abstraction
- **Timer system** for temporal logic
- **Layer system** for deferred rendering
- **Comprehensive documentation** (90+ markdown files)

**The primary value** from this analysis is not new systems to build, but **pattern documentation** to extract. Specifically:

1. **Timer-based state machine patterns** (HIGH PRIORITY)
2. **Code locality best practices** (HIGH PRIORITY)
3. **Telegraph/payoff patterns** for game feel (MEDIUM PRIORITY)

These documentation improvements will help future development by providing clear patterns for common gameplay scenarios, reducing the cognitive load of "how should I structure this?" questions.

---

## References

- emoji-merge repository: https://github.com/urgood2/emoji-merge
- Current timer docs: `assets/scripts/timer_docs.md`
- SNKRX patterns: `assets/SNKRX_code_snippets_and_techniques.md`
- Combat architecture: `assets/scripts/combat/ARCHITECTURE.md`
- Wand system: `assets/scripts/wand/README.md`

---

*Document created: 2025-11-21*
*Analysis scope: Architecture, patterns, and systems comparison*
