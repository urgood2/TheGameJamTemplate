# 📋 Lua Bindings - Top 5 High-Priority Improvements
## Detailed Implementation Plan

**Generated:** January 18, 2026
**Status:** Planning Complete
**Priority:** HIGH

---

## Executive Summary

This plan addresses the top 5 high-priority feature gaps identified in the Lua bindings analysis:

1. **Combat Heal Binding** - Add `combat.heal()` API
2. **Expose UIScrollComponent** - Enable programmatic scroll control
3. **AI Get Current Action** - Debug GOAP plans from Lua
4. **Physics Spatial Query** - Add `get_entities_in_radius()` 
5. **Input Validation Wrapper** - Prevent crashes from invalid entities

---

## Overview Table

| # | Feature | File(s) to Modify | Effort | Risk |
|---|---------|-------------------|--------|------|
| 1 | `combat.heal()` binding | `effects.hpp`, `effects.cpp`, `loader_lua.cpp` | Medium | Low |
| 2 | Expose `UIScrollComponent` | `ui.cpp` | Low | Low |
| 3 | `ai:get_current_action()` | `ai_system.cpp` | Low | Low |
| 4 | `physics.get_entities_in_radius()` | `physics_world.hpp/cpp`, `physics_lua_bindings.cpp` | Medium | Low |
| 5 | Input validation wrapper | `binding_helpers.hpp` (NEW) + all binding files | Medium | Medium |

---

## 1️⃣ Combat Heal Binding

### Goal
Add `combat.heal(entity, amount)` and integrate with composable mechanics system.

### Files to Modify

| File | Changes |
|------|---------|
| `src/systems/composable_mechanics/stats.hpp` | Add `HealingReceivedPct` to `StatId` enum |
| `src/systems/composable_mechanics/effects.hpp` | Add `EffectOpCode::Heal` and `Op_DealHeal_Params` |
| `src/systems/composable_mechanics/effects.cpp` | Implement `Run_DealHeal` function |
| `src/systems/composable_mechanics/loader_lua.cpp` | Add Lua loading support for heal effects |

### Implementation Steps

#### Step 1: Add StatId (stats.hpp)
```cpp
// In StatId enum, add after existing stats:
enum class StatId {
    // ... existing stats ...
    HealingReceivedPct,  // NEW: Multiplier for incoming heals
};
```

#### Step 2: Add EffectOpCode and Params (effects.hpp)
```cpp
// In EffectOpCode enum:
enum class EffectOpCode {
    // ... existing opcodes ...
    Heal,  // NEW
};

// Add new param struct:
struct Op_DealHeal_Params {
    float flat = 0.0f;      // Flat heal amount
    float pctMax = 0.0f;    // Percentage of target's max HP
};

// In CompiledEffectGraph struct, add:
struct CompiledEffectGraph {
    // ... existing members ...
    std::vector<Op_DealHeal_Params> healParams;  // NEW
};
```

#### Step 3: Implement Run_DealHeal (effects.cpp)
```cpp
static void Run_DealHeal(const Op_DealHeal_Params& p, Context& cx,
                         const std::vector<entt::entity>& targets) {
    for (auto target : targets) {
        if (!cx.world.valid(target)) continue;
        if (!cx.world.any_of<Stats, LifeEnergy>(target)) continue;

        auto& tgtStats = cx.world.get<Stats>(target);
        auto& tgtPools = cx.world.get<LifeEnergy>(target);

        float maxHp = tgtStats[StatId::MaxHP];
        float healReceivedPct = tgtStats.get_or(StatId::HealingReceivedPct, 0.0f);

        float amt = p.flat + (p.pctMax / 100.0f) * maxHp;
        amt *= (1.0f + healReceivedPct / 100.0f);

        // Clamp to max HP
        tgtPools.hp = std::min(maxHp, tgtPools.hp + amt);

        SPDLOG_DEBUG("Healed {} for {:.1f} HP (now {:.1f}/{:.1f})",
                     (uint32_t)target, amt, tgtPools.hp, maxHp);
    }
}

// In ExecuteOp switch statement, add:
case EffectOpCode::Heal:
    Run_DealHeal(g.healParams[(size_t)op.paramIndex], cx, targets);
    break;
```

#### Step 4: Add Lua Loading (loader_lua.cpp)
```cpp
// In load_spells function, after damage loading:
if (sol::optional<sol::table> healTbl = effectTbl["heal"]) {
    Op_DealHeal_Params hp{};
    hp.flat = healTbl.value().get_or("flat", 0.0f);
    hp.pctMax = healTbl.value().get_or("pctMax", 0.0f);

    int healIndex = (int)g.healParams.size();
    g.healParams.push_back(hp);
    g.ops.push_back(EffectOp{EffectOpCode::Heal, 0, 0, healIndex});
}
```

### Test Plan
```lua
-- Test in Lua:
local player = getEntityByAlias("player")
local initialHp = get_hp(player)
combat.heal(player, 50)  -- Heal 50 HP
assert(get_hp(player) == math.min(initialHp + 50, get_max_hp(player)))
```

### Success Criteria
- [ ] `combat.heal(entity, amount)` works from Lua
- [ ] Healing respects `HealingReceivedPct` stat
- [ ] HP is clamped to max HP
- [ ] No crashes on invalid entities

---

## 2️⃣ Expose UIScrollComponent

### Goal
Allow Lua scripts to read/write scroll position programmatically.

### Files to Modify

| File | Changes |
|------|---------|
| `src/systems/ui/ui.cpp` | Add `UIScrollComponent` usertype binding |

### Implementation Steps

#### Step 1: Add Binding (ui.cpp)
Add after line ~195 (after `InventoryGridTileComponent`):

```cpp
// 13) UIScrollComponent
lua.new_usertype<UIScrollComponent>("UIScrollComponent",
    sol::constructors<>(),
    "offset",       &UIScrollComponent::offset,
    "prevOffset",   &UIScrollComponent::prevOffset,
    "minOffset",    &UIScrollComponent::minOffset,
    "maxOffset",    &UIScrollComponent::maxOffset,
    "contentSize",  &UIScrollComponent::contentSize,
    "viewportSize", &UIScrollComponent::viewportSize,
    "vertical",     &UIScrollComponent::vertical,
    "horizontal",   &UIScrollComponent::horizontal,
    "showSeconds",  &UIScrollComponent::showSeconds,
    "showUntilT",   &UIScrollComponent::showUntilT,
    "barThickness",  &UIScrollComponent::barThickness,
    "barMinLen",    &UIScrollComponent::barMinLen,
    "type_id", []() { return entt::type_hash<UIScrollComponent>::value(); }
);

// Documentation
auto& scrollDef = rec.add_type("UIScrollComponent", /*is_data_class=*/true);
scrollDef.doc = "Component for scroll pane state, including offset and content dimensions.";
rec.record_property("UIScrollComponent", {"offset", "number", "Current scroll offset (vertical by default)."});
rec.record_property("UIScrollComponent", {"minOffset", "number", "Minimum scroll offset (usually 0)."});
rec.record_property("UIScrollComponent", {"maxOffset", "number", "Maximum scroll offset based on content size."});
rec.record_property("UIScrollComponent", {"contentSize", "Vector2", "Size of the scrollable content."});
rec.record_property("UIScrollComponent", {"viewportSize", "Vector2", "Size of the visible viewport."});
rec.record_property("UIScrollComponent", {"vertical", "boolean", "Whether vertical scrolling is enabled."});
rec.record_property("UIScrollComponent", {"horizontal", "boolean", "Whether horizontal scrolling is enabled."});
rec.record_property("UIScrollComponent", {"showSeconds", "number", "How long scroll bars stay visible after input."});
rec.record_property("UIScrollComponent", {"showUntilT", "number", "Absolute time to hide scroll bars."});
rec.record_property("UIScrollComponent", {"barThickness", "number", "Thickness of scroll bars."});
rec.record_property("UIScrollComponent", {"barMinLen", "number", "Minimum visible length of scroll bars."});
```

#### Step 2: Add Helper Functions (ui.cpp)
```cpp
// Add scroll helper functions to ui table
sol::table uiTable = lua["ui"].get_or_create<sol::table>();

uiTable.set_function("scroll_to", [](entt::entity e, float offset) {
    auto& registry = globals::getRegistry();
    if (!registry.valid(e) || !registry.any_of<UIScrollComponent>(e)) {
        SPDLOG_WARN("scroll_to: entity {} has no UIScrollComponent", (uint32_t)e);
        return;
    }
    auto& scroll = registry.get<UIScrollComponent>(e);
    scroll.offset = std::clamp(offset, scroll.minOffset, scroll.maxOffset);
});

uiTable.set_function("get_scroll_offset", [](sol::this_state L, entt::entity e) -> sol::object {
    auto& registry = globals::getRegistry();
    if (!registry.valid(e) || !registry.any_of<UIScrollComponent>(e)) {
        return sol::make_object(L, sol::lua_nil);
    }
    return sol::make_object(L, registry.get<UIScrollComponent>(e).offset);
});

uiTable.set_function("scroll_to_bottom", [](entt::entity e) {
    auto& registry = globals::getRegistry();
    if (!registry.valid(e) || !registry.any_of<UIScrollComponent>(e)) return;
    auto& scroll = registry.get<UIScrollComponent>(e);
    scroll.offset = scroll.maxOffset;
});

uiTable.set_function("scroll_to_top", [](entt::entity e) {
    auto& registry = globals::getRegistry();
    if (!registry.valid(e) || !registry.any_of<UIScrollComponent>(e)) return;
    auto& scroll = registry.get<UIScrollComponent>(e);
    scroll.offset = scroll.minOffset;
});
```

### Test Plan
```lua
-- Test in Lua:
local scrollPane = find_scroll_pane()
local scroll = registry:get(scrollPane, UIScrollComponent)
print("Current offset:", scroll.offset)
print("Max offset:", scroll.maxOffset)

ui.scroll_to(scrollPane, 100)  -- Scroll to position 100
ui.scroll_to_bottom(scrollPane)  -- Scroll to end
```

### Success Criteria
- [ ] `UIScrollComponent` accessible via `registry:get(entity, UIScrollComponent)`
- [ ] `ui.scroll_to(entity, offset)` works
- [ ] `ui.scroll_to_bottom/top` helpers work
- [ ] No crashes on invalid entities

---

## 3️⃣ AI Get Current Action

### Goal
Expose `ai:get_current_action(entity)` to return name of currently running GOAP action.

### Files to Modify

| File | Changes |
|------|---------|
| `src/systems/ai/ai_system.cpp` | Add `get_current_action` binding |
| `assets/scripts/chugget_code_definitions.lua` | Add stub for IDE completion |

### Implementation Steps

#### Step 1: Add Binding (ai_system.cpp)
Add after line ~1126 (after `force_interrupt`):

```cpp
ai.set_function("get_current_action", [&](sol::this_state L, entt::entity e) -> sol::object {
    auto& registry = globals::getRegistry();

    // Validate entity
    if (!registry.valid(e)) {
        return sol::make_object(L, sol::lua_nil);
    }

    // Check for GOAP component
    if (!registry.any_of<GOAPComponent>(e)) {
        return sol::make_object(L, sol::lua_nil);
    }

    auto& goap = registry.get<GOAPComponent>(e);

    // Check if there's a running action
    if (goap.actionQueue.empty()) {
        return sol::make_object(L, sol::lua_nil);
    }

    const auto& currentAction = goap.actionQueue.front();
    if (!currentAction.is_running) {
        return sol::make_object(L, sol::lua_nil);
    }

    return sol::make_object(L, currentAction.name);
});

// Also add get_action_queue_size for debugging
ai.set_function("get_action_queue_size", [&](entt::entity e) -> int {
    auto& registry = globals::getRegistry();
    if (!registry.valid(e) || !registry.any_of<GOAPComponent>(e)) {
        return 0;
    }
    return (int)registry.get<GOAPComponent>(e).actionQueue.size();
});

// Add get_plan for full plan inspection
ai.set_function("get_plan", [&](sol::this_state L, entt::entity e) -> sol::object {
    auto& registry = globals::getRegistry();
    if (!registry.valid(e) || !registry.any_of<GOAPComponent>(e)) {
        return sol::make_object(L, sol::lua_nil);
    }

    auto& goap = registry.get<GOAPComponent>(e);
    sol::state_view lua(L);
    sol::table plan = lua.create_table();

    int idx = 1;
    std::queue<Action> tempQueue = goap.actionQueue;  // Copy to iterate
    while (!tempQueue.empty()) {
        plan[idx++] = tempQueue.front().name;
        tempQueue.pop();
    }

    return sol::make_object(L, plan);
});
```

#### Step 2: Add Documentation (ai_system.cpp)
```cpp
rec.record_method("ai", {
    "get_current_action",
    "---@param e Entity\n"
    "---@return string|nil",
    "Returns the name of the currently running GOAP action for the entity, or nil if no action is running."
});

rec.record_method("ai", {
    "get_action_queue_size",
    "---@param e Entity\n"
    "---@return integer",
    "Returns the number of actions in the entity's GOAP action queue."
});

rec.record_method("ai", {
    "get_plan",
    "---@param e Entity\n"
    "---@return string[]|nil",
    "Returns the full GOAP plan as an array of action names, or nil if no plan exists."
});
```

#### Step 3: Update Lua Definitions (chugget_code_definitions.lua)
```lua
---
--- Returns the name of the currently running GOAP action.
---
---@param e Entity
---@return string|nil
function ai:get_current_action(...) end

---
--- Returns the number of actions in the GOAP queue.
---
---@param e Entity
---@return integer
function ai:get_action_queue_size(...) end

---
--- Returns the full GOAP plan as an array of action names.
---
---@param e Entity
---@return string[]|nil
function ai:get_plan(...) end
```

### Test Plan
```lua
-- Test in Lua:
local enemy = getEntityByAlias("enemy")
local action = ai:get_current_action(enemy)
if action then
    print("Enemy is doing:", action)
else
    print("Enemy is idle")
end

local plan = ai:get_plan(enemy)
if plan then
    print("Full plan:", table.concat(plan, " -> "))
end
```

### Success Criteria
- [ ] `ai:get_current_action(entity)` returns action name or nil
- [ ] `ai:get_plan(entity)` returns full plan array
- [ ] Returns nil gracefully for invalid entities
- [ ] No crashes on entities without GOAPComponent

---

## 4️⃣ Physics Get Entities In Radius

### Goal
Add `physics.get_entities_in_radius(world, x, y, radius)` for spatial queries.

### Files to Modify

| File | Changes |
|------|---------|
| `src/systems/physics/physics_world.hpp` | Declare `GetEntitiesInRadius` |
| `src/systems/physics/physics_world.cpp` | Implement `GetEntitiesInRadius` |
| `src/systems/physics/physics_lua_bindings.cpp` | Add Lua binding |

### Implementation Steps

#### Step 1: Declare Method (physics_world.hpp)
Add after `GetObjectsInArea` declaration (~line 200):

```cpp
/**
 * @brief Query all entities within a radius of a point.
 * @param centerX Center X coordinate
 * @param centerY Center Y coordinate
 * @param radius Search radius
 * @return Vector of entity userData pointers within the radius
 */
std::vector<void*> GetEntitiesInRadius(float centerX, float centerY, float radius);
```

#### Step 2: Implement Method (physics_world.cpp)
Add after `GetObjectsInArea` implementation (~line 1029):

```cpp
std::vector<void*> PhysicsWorld::GetEntitiesInRadius(float centerX, float centerY, float radius) {
    std::vector<void*> entities;

    // Use bounding box for broad phase
    cpBB bb = cpBBNew(centerX - radius, centerY - radius,
                      centerX + radius, centerY + radius);

    // Query data struct
    struct RadiusQueryData {
        std::vector<void*>* entities;
        cpVect center;
        float radiusSq;
    };

    RadiusQueryData queryData{&entities, cpv(centerX, centerY), radius * radius};

    cpSpaceBBQuery(space, bb, CP_SHAPE_FILTER_ALL,
        [](cpShape* shape, void* data) {
            auto* qd = static_cast<RadiusQueryData*>(data);

            // Get closest point on shape to center
            cpPointQueryInfo info;
            cpShapePointQuery(shape, qd->center, &info);

            // Check if within radius (using squared distance for performance)
            float distSq = info.distance * info.distance;
            if (info.distance < 0) distSq = 0;  // Inside shape

            if (distSq <= qd->radiusSq) {
                void* userData = cpShapeGetUserData(shape);
                if (userData) {
                    // Avoid duplicates (entity might have multiple shapes)
                    auto& vec = *qd->entities;
                    if (std::find(vec.begin(), vec.end(), userData) == vec.end()) {
                        vec.push_back(userData);
                    }
                }
            }
        },
        &queryData);

    SPDLOG_TRACE("Radius query: center=({:.1f},{:.1f}) r={:.1f} found={}",
                 centerX, centerY, radius, (int)entities.size());

    return entities;
}
```

#### Step 3: Add Lua Binding (physics_lua_bindings.cpp)
Add after `GetObjectsInArea` binding (~line 393):

```cpp
rec.record_free_function(path, {
    "get_entities_in_radius",
    "---@param world physics.PhysicsWorld\n"
    "---@param centerX number @ center X coordinate\n"
    "---@param centerY number @ center Y coordinate\n"
    "---@param radius number @ search radius\n"
    "---@return entt.entity[] @ entities within the radius",
    "Returns all entities whose collision shapes are within the specified radius of a center point.",
    true, false
});
lua["physics"]["get_entities_in_radius"] = [](PhysicsWorld& W, float cx, float cy, float radius) {
    auto raw = W.GetEntitiesInRadius(cx, cy, radius);
    std::vector<entt::entity> out;
    out.reserve(raw.size());
    for (void* p : raw) {
        out.push_back(p ? to_entity(p) : entt::null);
    }
    return sol::as_table(out);
};
```

### Test Plan
```lua
-- Test in Lua:
local world = get_physics_world()
local playerPos = get_position(player)

-- Find all entities within 100 units of player
local nearby = physics.get_entities_in_radius(world, playerPos.x, playerPos.y, 100)
print("Found", #nearby, "entities nearby")

for _, entity in ipairs(nearby) do
    if entity ~= player then
        print("  -", get_name(entity))
    end
end
```

### Success Criteria
- [ ] `physics.get_entities_in_radius(world, x, y, r)` returns entity array
- [ ] Correctly filters by actual distance (not just AABB)
- [ ] No duplicate entities in results
- [ ] Returns empty table for no matches
- [ ] No crashes on edge cases (radius=0, no entities)

---

## 5️⃣ Input Validation Wrapper

### Goal
Create a consistent validation pattern for all entity-component bindings to prevent crashes.

### Files to Modify

| File | Changes |
|------|---------|
| `src/systems/scripting/binding_helpers.hpp` | NEW: Create validation helpers |
| All binding files | Use helpers consistently |

### Implementation Steps

#### Step 1: Create Helper Header (NEW FILE)
Create `src/systems/scripting/binding_helpers.hpp`:

```cpp
#pragma once

#include "entt/entt.hpp"
#include "sol/sol.hpp"
#include "spdlog/spdlog.h"

namespace scripting {

/**
 * @brief Safely get a component from an entity, returning nil if invalid.
 * @tparam T Component type
 * @param L Lua state
 * @param registry EnTT registry
 * @param entity Entity to query
 * @return Component reference or sol::lua_nil
 */
template<typename T>
sol::object safe_get_component(sol::this_state L, entt::registry& registry, entt::entity entity) {
    if (!registry.valid(entity)) {
        SPDLOG_WARN("safe_get_component<{}>: invalid entity {}",
                    typeid(T).name(), (uint32_t)entity);
        return sol::make_object(L, sol::lua_nil);
    }

    if (!registry.any_of<T>(entity)) {
        return sol::make_object(L, sol::lua_nil);
    }

    return sol::make_object(L, std::ref(registry.get<T>(entity)));
}

/**
 * @brief Safely check if entity has component.
 */
template<typename T>
bool safe_has_component(entt::registry& registry, entt::entity entity) {
    return registry.valid(entity) && registry.any_of<T>(entity);
}

/**
 * @brief Validate entity and log warning if invalid.
 * @return true if valid, false otherwise
 */
inline bool validate_entity(entt::registry& registry, entt::entity entity,
                           const char* context = "unknown") {
    if (!registry.valid(entity)) {
        SPDLOG_WARN("{}: invalid entity {}", context, (uint32_t)entity);
        return false;
    }
    return true;
}

/**
 * @brief Validate entity has required component.
 * @return true if valid and has component, false otherwise
 */
template<typename T>
bool validate_entity_component(entt::registry& registry, entt::entity entity,
                               const char* context = "unknown") {
    if (!validate_entity(registry, entity, context)) {
        return false;
    }
    if (!registry.any_of<T>(entity)) {
        SPDLOG_WARN("{}: entity {} missing component {}",
                    context, (uint32_t)entity, typeid(T).name());
        return false;
    }
    return true;
}

/**
 * @brief Macro for common validation pattern in bindings.
 */
#define VALIDATE_ENTITY_OR_RETURN(registry, entity, retval) \
    if (!registry.valid(entity)) { \
        SPDLOG_WARN("{}:{} invalid entity {}", __FILE__, __LINE__, (uint32_t)entity); \
        return retval; \
    }

#define VALIDATE_ENTITY_COMPONENT_OR_RETURN(registry, entity, CompType, retval) \
    VALIDATE_ENTITY_OR_RETURN(registry, entity, retval) \
    if (!registry.any_of<CompType>(entity)) { \
        return retval; \
    }

} // namespace scripting
```

#### Step 2: Example Usage in Bindings

**Before (crash-prone):**
```cpp
ai.set_function("get_blackboard", [&](entt::entity e) {
    auto& goap = registry.get<GOAPComponent>(e);  // CRASH if missing!
    return goap.blackboard;
});
```

**After (safe):**
```cpp
#include "systems/scripting/binding_helpers.hpp"

ai.set_function("get_blackboard", [&](sol::this_state L, entt::entity e) -> sol::object {
    auto& registry = globals::getRegistry();

    if (!scripting::validate_entity_component<GOAPComponent>(registry, e, "ai.get_blackboard")) {
        return sol::make_object(L, sol::lua_nil);
    }

    return sol::make_object(L, std::ref(registry.get<GOAPComponent>(e).blackboard));
});
```

#### Step 3: Audit and Update Existing Bindings

Priority files to update (most used, highest crash risk):

| File | Estimated Changes |
|------|-------------------|
| `ai_system.cpp` | ~15 functions |
| `transform_functions.cpp` | ~30 functions |
| `ui.cpp` | ~20 functions |
| `physics_lua_bindings.cpp` | ~10 functions |
| `anim_system.cpp` | ~5 functions |

### Test Plan
```lua
-- Test invalid entity handling:
local invalid = 999999  -- Invalid entity ID
local result = ai:get_blackboard(invalid)
assert(result == nil, "Should return nil for invalid entity")

-- Test missing component:
local entity = registry:create()  -- No components
local scroll = registry:get(entity, UIScrollComponent)
assert(scroll == nil, "Should return nil for missing component")
```

### Success Criteria
- [ ] All bindings return nil instead of crashing on invalid entities
- [ ] Warning logs help debug issues
- [ ] No performance regression (validation is O(1))
- [ ] Consistent pattern across all binding files

---

## 📅 Implementation Schedule

| Week | Tasks | Deliverables |
|------|-------|--------------|
| **Week 1** | Items 2, 3 (Low effort) | UIScrollComponent + ai:get_current_action |
| **Week 2** | Item 4 (Medium effort) | physics.get_entities_in_radius |
| **Week 3** | Item 1 (Medium effort) | combat.heal system |
| **Week 4** | Item 5 (Medium effort) | Input validation wrapper + audit |

## 🧪 Testing Strategy

1. **Unit Tests**: Add Lua test scripts in `tests/unit/` for each feature
2. **Integration Tests**: Test features in actual game scenarios
3. **Regression Tests**: Ensure existing functionality still works
4. **Edge Cases**: Test nil, invalid entities, missing components

## 📊 Success Metrics

After implementation:
- [ ] Zero crashes from Lua binding calls with invalid entities
- [ ] `pcall` usage in Lua scripts reduced by 30%+
- [ ] All 5 features have passing unit tests
- [ ] Documentation updated in `chugget_code_definitions.lua`

---

## Appendix: Related Issues Found

### Pain Points from Lua Scripts
1. **Combat System**
   - TODOs in `combat_system.lua`: Missing heal, buff, AoE APIs
   - Workaround: Direct HP manipulation with no validation

2. **UI System**
   - "missing initFunc" workarounds in `cast_execution_graph_ui.lua`
   - Nil guards for `UIScrollComponent` access in `stats_panel.lua`

3. **AI System**
   - No way to inspect current action for debugging
   - GOAP plans opaque from Lua

4. **Physics Queries**
   - Only rectangular area queries (`GetObjectsInArea`)
   - No radius-based entity search

5. **Error Handling**
   - Excessive `pcall` usage suggesting unreliable APIs
   - Inconsistent validation across bindings

### Components Without Lua Bindings
| Component | Impact | Priority |
|-----------|--------|----------|
| `GOAPComponent` | High - AI scripting | 🔴 High |
| `Blackboard` | High - AI state | 🔴 High |
| `ColliderComponent` | Medium - Physics queries | 🟡 Medium |
| `SteerableComponent` | Medium - Movement | 🟡 Medium |
| `TileComponent` | Low - Tile-based games | 🟢 Low |
| `LocationComponent` | Low - Legacy | 🟢 Low |
| `NinePatchComponent` | Medium - UI | 🟡 Medium |
| `ContainerComponent` | Medium - Inventory | 🟡 Medium |
| `InfoComponent` | Low - Metadata | 🟢 Low |
| `HasVisionComponent` | Medium - LOS | 🟡 Medium |
| `BlocksLightComponent` | Medium - LOS | 🟡 Medium |
| `ParticleComponent` | Medium - VFX | 🟡 Medium |
| `UIScrollComponent` | High - UI | 🔴 High |
| `TweenedLocationComponent` | Low - Animation | 🟢 Low |
| `SpriteComponentASCII` | Low - ASCII mode | 🟢 Low |

