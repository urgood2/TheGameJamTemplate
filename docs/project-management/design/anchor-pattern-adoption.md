# Anchor Pattern Adoption Plan

**Status**: Planning  
**Created**: 2026-01-05  
**Goal**: Adopt beneficial patterns from Anchor-main (SNKRX engine) to simplify entity construction and parent-child relationships.

---

## 1. Current State Analysis

### Transform System Architecture (C++)

From `src/systems/transform/transform.hpp`:

```cpp
// GameObject manages parent-child tree structure
struct GameObject {
    std::optional<entt::entity> parent;
    std::map<std::string, entt::entity> children;      // Lookup by ID
    std::vector<entt::entity> orderedChildren;         // Ordered traversal
    entt::entity container = entt::null;               // UI container reference
    // ... interaction state, methods ...
};

// InheritedProperties handles positioning relative to parent
struct InheritedProperties {
    enum class Type { 
        RoleRoot,           // No parent
        RoleInheritor,      // Inherits with offset
        RoleCarbonCopy,     // Exact copy
        PermanentAttachment // Persists after parent death
    };
    
    Type role_type = Type::RoleRoot;
    entt::entity master = entt::null;
    std::optional<Vector2> offset;
    
    // Bonds: Strong (instant sync) vs Weak (eased sync)
    std::optional<Sync> location_bond, size_bond, rotation_bond, scale_bond;
    
    // Alignment flags for positioning
    std::optional<Alignment> flags;
};
```

### Entity Builder API (Lua)

From `assets/scripts/core/entity_builder.lua`:

```lua
-- Current API (verbose but flexible)
local entity, script = EntityBuilder.create({
    sprite = "kobold",
    position = { x = 100, y = 200 },
    size = { 64, 64 },
    data = { health = 100 },
    interactive = { hover = {...}, click = fn },
    state = PLANNING_STATE,
    shaders = { "3d_skew_holo" }
})

-- Simple version
local entity = EntityBuilder.simple("kobold", 100, 200, 64, 64)
```

### Node/Script System (Lua)

From `assets/scripts/monobehavior/behavior_script_v2.lua`:

```lua
-- Factory methods
local script = Node.quick(entity, { health = 100 })
local script = Node.create({ health = 100 })

-- Destruction
script:destroy()                           -- Immediate destruction
script:destroy_when(entity, "destroyed")   -- Conditional destruction (link)
```

---

## 2. Anchor Patterns Worth Adopting

### 2.1 Operator-Based Construction (DEFERRED)

Anchor uses Lua metatables for fluent construction:

```lua
-- Anchor style
E 'ball' ^ {x=100} / update >> arena

-- Translates to:
-- E('ball'):set({x=100}):add_updater(update):add_to(arena)
```

**Decision**: DEFER. Current EntityBuilder API is adequate. Operators would require significant refactoring and training.

### 2.2 Simplified Child Addition API (HIGH PRIORITY)

**Current**: Complex InheritedProperties::Builder pattern in C++

**Goal**: Simple Lua API for common cases:

```lua
-- Proposed API
parent:addChild(child, {
    offset = {10, 0},        -- Relative position
    rotateWith = true,       -- Inherit rotation
    align = "above",         -- Alignment preset
    name = "weapon"          -- Optional: lookup key
})

-- OR fluent style via ChildBuilder
ChildBuilder.for_entity(child)
    :attachTo(parent)
    :offset(10, 0)
    :rotateWith()
    :named("weapon")
    :apply()
```

### 2.3 Horizontal Links (MEDIUM PRIORITY)

"Die when target dies" pattern.

**Current**: `script:destroy_when(entity, "destroyed")` exists but may not be robust.

**Goal**: Explicit link API:

```lua
-- Projectile dies when firing unit dies
projectile:linkTo(firingUnit)

-- OR: Many-to-one link
linkGroup:add(projectile)
linkGroup:add(effect)
linkGroup:bindTo(firingUnit)  -- All members die when unit dies
```

### 2.4 Tree-Based Ownership (LOW PRIORITY - ALREADY EXISTS)

From `transform_functions.cpp`:

```cpp
void RemoveEntity(...) {
    // Already recursively destroys GameObject children
    for (auto child : gameObject->orderedChildren) {
        RemoveEntity(registry, child);
    }
}
```

**Status**: Already implemented. Just need Lua bindings to be verified.

---

## 3. Implementation Plan

### Phase 1: Simplified Child API (2-3 hours)

**File**: `assets/scripts/core/child_builder.lua` (NEW)

```lua
local ChildBuilder = {}
ChildBuilder.__index = ChildBuilder

function ChildBuilder.for_entity(entity)
    return setmetatable({
        _entity = entity,
        _parent = nil,
        _offset = {0, 0},
        _rotateWith = false,
        _scaleWith = false,
        _name = nil,
        _syncMode = "strong"  -- or "weak" for eased following
    }, ChildBuilder)
end

function ChildBuilder:attachTo(parent)
    self._parent = parent
    return self
end

function ChildBuilder:offset(x, y)
    self._offset = {x, y}
    return self
end

function ChildBuilder:rotateWith(enabled)
    self._rotateWith = enabled ~= false
    return self
end

function ChildBuilder:scaleWith(enabled)
    self._scaleWith = enabled ~= false
    return self
end

function ChildBuilder:named(name)
    self._name = name
    return self
end

function ChildBuilder:eased()
    self._syncMode = "weak"
    return self
end

function ChildBuilder:apply()
    -- Call C++ binding: attach_child(registry, parent, child, config)
    attach_child(registry, self._parent, self._entity, {
        offset = self._offset,
        rotate = self._rotateWith,
        scale = self._scaleWith,
        name = self._name,
        sync = self._syncMode
    })
    return self._entity
end

return ChildBuilder
```

**C++ Binding Needed** (`transform_functions.cpp`):

```cpp
void attach_child(entt::registry& reg, entt::entity parent, entt::entity child, sol::table config) {
    auto& parentGO = reg.get_or_emplace<GameObject>(parent);
    auto& childIP = reg.get_or_emplace<InheritedProperties>(child);
    
    // Set master
    childIP.master = parent;
    childIP.role_type = InheritedProperties::Type::RoleInheritor;
    
    // Offset
    if (config["offset"].valid()) {
        sol::table offset = config["offset"];
        childIP.offset = Vector2{offset[1], offset[2]};
    }
    
    // Rotation sync
    if (config.get_or("rotate", false)) {
        childIP.rotation_bond = Sync::Strong;
    }
    
    // Scale sync
    if (config.get_or("scale", false)) {
        childIP.scale_bond = Sync::Strong;
    }
    
    // Add to parent's children
    std::string name = config.get_or<std::string>("name", "");
    if (!name.empty()) {
        parentGO.children[name] = child;
    }
    parentGO.orderedChildren.push_back(child);
}
```

### Phase 2: Horizontal Links System (1-2 hours)

**File**: `assets/scripts/core/entity_links.lua` (NEW)

```lua
local signal = require("external.hump.signal")
local signal_group = require("core.signal_group")

local EntityLinks = {}

-- Store active links: entity -> {targets}
local links = {}

function EntityLinks.link(dependent, target)
    -- dependent dies when target dies
    local handler = signal_group.new("link_" .. tostring(dependent))
    
    handler:on("entity_destroyed", function(destroyedEntity)
        if destroyedEntity == target then
            -- Target died, destroy dependent
            if ensure_entity(dependent) then
                local script = safe_script_get(dependent)
                if script and script.destroy then
                    script:destroy()
                else
                    destroy_entity(registry, dependent)
                end
            end
            handler:cleanup()
        end
    end)
    
    -- Track for cleanup if dependent dies first
    links[dependent] = links[dependent] or {}
    links[dependent][target] = handler
end

function EntityLinks.unlink(dependent, target)
    if links[dependent] and links[dependent][target] then
        links[dependent][target]:cleanup()
        links[dependent][target] = nil
    end
end

function EntityLinks.unlinkAll(dependent)
    if links[dependent] then
        for _, handler in pairs(links[dependent]) do
            handler:cleanup()
        end
        links[dependent] = nil
    end
end

return EntityLinks
```

**Integration with Node**:

```lua
-- In behavior_script_v2.lua
function Node:linkTo(target)
    local EntityLinks = require("core.entity_links")
    EntityLinks.link(self:handle(), target)
    return self
end
```

### Phase 3: Verification & Lua Bindings (1 hour)

1. Verify `RemoveEntity` properly destroys children (add unit test)
2. Add Lua binding for `destroy_entity` if not exists
3. Emit `entity_destroyed` signal from C++ destruction callback
4. Add convenience methods to EntityBuilder

---

---

## Concrete Example: Weapon Swing Animation

```lua
local ChildBuilder = require("core.child_builder")
local Tween = require("core.tween")
local timer = require("core.timer")

-- 1. Create weapon attached to player
local weapon = EntityBuilder.simple("sword", 0, 0, 32, 32)

ChildBuilder.for_entity(weapon)
    :attachTo(player)
    :offset(20, 0)        -- Resting position (right of player center)
    :rotateWith()         -- Rotate with player facing direction
    :apply()

-- 2. Define swing animation function
local function swingWeapon()
    local ip = component_cache.get(weapon, InheritedProperties)
    
    -- Swing arc: start right, swing through top to left
    timer.sequence("weapon_swing")
        :do_now(function()
            -- Wind up (pull back slightly)
            ChildBuilder.animateOffset(weapon, {
                to = { x = 25, y = 5 },
                duration = 0.1,
                ease = "inQuad"
            })
        end)
        :wait(0.1)
        :do_now(function()
            -- Main swing (arc from right to left)
            ChildBuilder.orbit(weapon, {
                radius = 25,
                startAngle = 0,              -- Right
                endAngle = math.pi * 0.8,    -- Almost left
                duration = 0.15,
                ease = "outQuad"
            })
        end)
        :wait(0.15)
        :do_now(function()
            -- Return to rest
            ChildBuilder.animateOffset(weapon, {
                to = { x = 20, y = 0 },
                duration = 0.2,
                ease = "outBack"
            })
        end)
        :start()
end

-- 3. Trigger on attack
signal.register("player_attack", swingWeapon)
```

### Visual Diagram

```
Player facing right:

    Rest Position:     Wind Up:         Swing Arc:        Return:
    
    [P]--[W]           [P]---[W]        [P]               [P]--[W]
                                          \
                                           [W]
                                          /
                                        [W]
```

---

## 4. Testing Checklist

### Child Addition
- [ ] `ChildBuilder.for_entity(e):attachTo(parent):offset(10,0):apply()` creates valid child
- [ ] Child moves when parent moves
- [ ] Child rotates when parent rotates (if `rotateWith()`)
- [ ] Named child is retrievable: `parent:getChild("weapon")`
- [ ] Parent destruction destroys child

### Horizontal Links
- [ ] `projectile:linkTo(player)` creates valid link
- [ ] Player death destroys linked projectile
- [ ] Projectile death does NOT destroy player
- [ ] `unlink()` properly removes connection
- [ ] No memory leaks (handlers cleaned up)

### Integration
- [ ] EntityBuilder can spawn with initial children
- [ ] Combat projectiles use linkTo for owner tracking
- [ ] UI elements use parent-child for hierarchies

---

## 5. Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `assets/scripts/core/child_builder.lua` | CREATE | Fluent child attachment API |
| `assets/scripts/core/entity_links.lua` | CREATE | Horizontal link system |
| `assets/scripts/monobehavior/behavior_script_v2.lua` | MODIFY | Add `linkTo()` method |
| `src/systems/scripting/script_lua_binding.cpp` | MODIFY | Add `attach_child` C++ binding |
| `CLAUDE.md` | MODIFY | Document new APIs |

---

## 6. Open Questions

1. **Alignment presets**: Should we have named presets like `"above"`, `"below"`, `"orbit"` for common patterns?
2. **Animation support**: How to handle animated attachments (e.g., weapon swing)?
3. **Collision inheritance**: Should child entities inherit parent's collision group?
4. **Z-ordering**: How to handle depth sorting for children vs parent?

---

## 7. Agent Research Findings (2026-01-05)

### Entity Destruction System (bg_e75877f3)

**Key Files:**
- `src/systems/transform/transform.hpp:858-887` - C++ destruction callback
- `src/systems/transform/transform_functions.cpp:2421-2444` - `RemoveEntity()` recursive child destruction
- `src/systems/ui/box.hpp:143-156` - UI post-order traversal destruction
- `assets/scripts/combat/entity_cleanup.lua:88-93` - Deferred destruction via `timer.after(0.1s)`
- `assets/scripts/combat/projectile_system.lua:1931-1949` - Projectile destruction + signal emit

**Existing Patterns:**
```lua
-- Deferred destruction (entity_cleanup.lua)
timer.after(0.1, function()
    if registry:valid(entity_id) then
        registry:destroy(entity_id)
    end
end, "entity_cleanup_" .. entity_id)

-- attachTo() auto-cleanup (lighting.lua, particles.lua)
local light = Lighting.point():attachTo(playerEntity):create()
-- Light auto-removes when playerEntity is destroyed

-- Timer group cleanup
timer.kill_group("entity_" .. entity_id)
```

**Signal Events Already In Use:**
- `"entity_destroyed"` - Used by mark_system.lua, status_indicator_system.lua
- `"projectile_destroyed"` - From projectile_system.lua
- `"enemy_killed"` - Bridged from ctx.bus OnDeath

### Entity Construction Patterns (bg_d5850429)

**Complete Pattern Catalog:**

| Pattern | File | Use Case |
|---------|------|----------|
| `EntityBuilder.create({...})` | entity_builder.lua:178 | Full options table |
| `EntityBuilder.simple(sprite, x, y, w, h)` | entity_builder.lua:267 | Minimal entity |
| `EntityBuilder.validated(Script, entity, data)` | entity_builder.lua:282 | Prevent data-loss bug |
| `EntityBuilder.spawn(sprite, x, y, opts)` | entity_builder.lua:441 | One-liner with physics |
| `Node.quick(entity, data)` | behavior_script_v2.lua:289 | Safe script attach |
| `Node.create(data)` | behavior_script_v2.lua:320 | New entity + script |
| `PhysicsBuilder.for_entity(e):circle():apply()` | physics_builder.lua | Fluent physics |
| `ShaderBuilder.for_entity(e):add("shader"):apply()` | shader_builder.lua | Fluent shaders |
| `Lighting.point():attachTo(e):create()` | lighting.lua | Fluent lights |
| `spawn.enemy("type", x, y)` | spawn.lua:239 | Preset-based |
| `EnemyFactory.spawn("type", pos)` | enemy_factory.lua:93 | Combat-integrated |
| `SpecialItem.create({...})` | special_item.lua:249 | Visual items |
| `Particles.define():spawn():at(x,y)` | particles.lua | Fluent particles |
| `Text.define():spawn(val):above(e)` | text.lua | Fluent text |

**Key Finding**: No native entity parent-child transform propagation exists. Current system tracks:
- `GameObject.children` - For UI/node hierarchy (used by RemoveEntity)
- `InheritedProperties` - For transform property inheritance
- These are SEPARATE hierarchies

### Existing attachTo() Pattern

Multiple systems already use `attachTo(entity)` for lifecycle binding:

```lua
-- Particles (particles.lua:1012-1060)
particles.spawnStream("fx"):attachTo(entity)
-- Checks entity_cache.valid() in update, stops when invalid

-- Lighting (lighting.lua:841-860)
Lighting.point():attachTo(entity):create()
-- Marks for removal when attached entity destroyed

-- Text (implied by Text.define():spawn():above(entity))
```

**This IS the horizontal link pattern we want!** Just needs:
1. Generalization to entity-to-entity links
2. Integration with Node class

---

## 8. Revised Implementation Priority

Based on agent findings:

### Priority 1: EntityLinks Module (Uses Existing Patterns)
- Leverage existing `attachTo()` pattern
- Add `signal.register("entity_destroyed")` handler
- Integrate with Node class as `linkTo()` method
- **Estimated: 1 hour** (simpler than originally planned)

### Priority 2: ChildBuilder (Wrapper Only - No C++ Needed!)
**DISCOVERY**: `transform.AssignRole()` already exists as Lua binding!

```lua
-- EXISTING API (chugget_code_definitions.lua:3601-3791)
transform.AssignRole(registry, entity, 
    InheritedPropertiesType.RoleInheritor,  -- Role type
    parentEntity,                          -- Parent/master
    InheritedPropertiesSync.Strong,           -- Location bond
    InheritedPropertiesSync.Weak,            -- Size bond
    InheritedPropertiesSync.Strong,           -- Rotation bond
    InheritedPropertiesSync.Weak,            -- Scale bond
    {x=10, y=20}                          -- Offset
)
```

ChildBuilder just needs to wrap this in fluent API:
```lua
ChildBuilder.for_entity(child)
    :attachTo(parent)
    :offset(10, 20)
    :rotateWith()  -- Sets rotation bond to Strong
    :eased()       -- Sets all bonds to Weak
    :apply()       -- Calls transform.AssignRole internally
```

- **Estimated: 30 minutes** (pure Lua wrapper)

### Priority 3: Child Offset Animation (No C++ Needed!)

**DISCOVERY**: `InheritedProperties.offset` is directly exposed to Lua as `Vector2`!

```lua
-- EXISTING: Direct offset access
local ip = component_cache.get(childEntity, InheritedProperties)
ip.offset.x = 10
ip.offset.y = 20
```

**Proposed API for ChildBuilder:**

```lua
-- Animate offset (weapon swing)
ChildBuilder.for_entity(weapon)
    :attachTo(player)
    :offset(20, 0)              -- Base offset (weapon hand position)
    :rotateWith()
    :apply()

-- Later, animate the offset for weapon swing:
local ip = component_cache.get(weapon, InheritedProperties)

-- Option A: Direct tween
Tween.value(0, math.pi/2, 0.2, function(angle)
    local radius = 30
    ip.offset.x = math.cos(angle) * radius
    ip.offset.y = math.sin(angle) * radius
end):ease("outQuad")

-- Option B: Fluent helper (new)
ChildBuilder.animateOffset(weapon, {
    from = {x=20, y=0},
    to = {x=-20, y=30},
    duration = 0.2,
    ease = "outQuad",
    onComplete = function() end
})

-- Option C: Orbit animation (new)
ChildBuilder.orbit(weapon, {
    radius = 30,
    startAngle = 0,
    endAngle = math.pi/2,
    duration = 0.2,
    ease = "outQuad"
})
```

**Implementation** (pure Lua helper):

```lua
-- In child_builder.lua
function ChildBuilder.animateOffset(entity, opts)
    local ip = component_cache.get(entity, InheritedProperties)
    if not ip then return end
    
    local from = opts.from or { x = ip.offset.x, y = ip.offset.y }
    local to = opts.to
    local duration = opts.duration or 0.2
    
    Tween.value(0, 1, duration, function(t)
        ip.offset.x = from.x + (to.x - from.x) * t
        ip.offset.y = from.y + (to.y - from.y) * t
    end)
        :ease(opts.ease or "linear")
        :onComplete(opts.onComplete)
    
    return entity
end

function ChildBuilder.orbit(entity, opts)
    local ip = component_cache.get(entity, InheritedProperties)
    if not ip then return end
    
    local radius = opts.radius or 30
    local startAngle = opts.startAngle or 0
    local endAngle = opts.endAngle or math.pi * 2
    local duration = opts.duration or 0.5
    local baseOffset = opts.baseOffset or { x = 0, y = 0 }
    
    Tween.value(startAngle, endAngle, duration, function(angle)
        ip.offset.x = baseOffset.x + math.cos(angle) * radius
        ip.offset.y = baseOffset.y + math.sin(angle) * radius
    end)
        :ease(opts.ease or "linear")
        :onComplete(opts.onComplete)
    
    return entity
end
```

**Estimated: 20 minutes** (pure Lua)

### Priority 4: Documentation
- Update CLAUDE.md with new patterns
- Add examples to docs/api/

---

## 9. References

- Anchor-main `ANCHOR.md`: Tree-based ownership, operator construction
- Current transform system: `src/systems/transform/transform.hpp`
- InheritedProperties: Lines 520-620
- RemoveEntity: `transform_functions.cpp:2421-2444`
- Entity destruction callback: `transform.hpp:858-887`
- Existing attachTo patterns: `lighting.lua:841`, `particles.lua:1012`
