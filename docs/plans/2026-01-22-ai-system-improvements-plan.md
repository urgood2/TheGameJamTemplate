# AI System Improvements – Detailed Implementation Plan

> **Created:** 2026-01-22  
> **Status:** Planning  
> **Priority:** High - Game jam friendly AI ergonomics

## Executive Summary

Implement Tier 1 improvements by adding a small “AI ergonomics layer” on top of the existing GOAP + blackboard + physics/steering stack. Most of the work should live in Lua under `assets/scripts/ai/` (fast iteration), with *minimal* C++ additions in `src/systems/ai/ai_system.cpp` only where Lua would be awkward or too slow (e.g., safe blackboard type conversion and spatial queries). Reuse the existing inspector/debug plumbing already present (`ai.get_goap_state`, `ai.get_trace_events`, `ai.list_goap_entities`, `ai.report_goal_selection`) instead of inventing a second tracing system.

### Design Principles
- **DEAD SIMPLE API** - One-liner usage where possible
- **Lua-first** - Scriptable without touching C++
- **Composable** - Small pieces that combine well
- **Game jam friendly** - Quick iteration, minimal boilerplate

### Scope (Tier 1)
- A *consistent* blackboard API usable from actions/updaters (including `{x,y}` support)
- Simple sensing primitives (position/distance/nearest/LOS)
- Lightweight memory (TTL-based) and perception scheduling
- Navigation wrappers that match the engine’s “call steering every frame” behavior
- Debug overlay helpers that draw via existing rendering primitives and surface existing GOAP/trace info

### Non-goals
- Replace the GOAP planner / action system
- Add heavy new ECS infrastructure (unless escalation triggers are hit)
- Build a full-blown behavior tree framework
- Solve large-scale crowd simulation (RVO, detour crowd) in Tier 1

### Effort Estimate
| Tier | Items | Effort | Impact |
|------|-------|--------|--------|
| **Tier 1** | BB helpers, Sense, Memory, Perception, Nav, Debug | 1-2 days | Very High |
| **Tier 2** | Goal locks, Action helpers, Thresholds, Stuck | 0.5-1 day | Medium |
| **Tier 3** | Squad, Combat, Investigate, Spawn, Comms | 1-2 days | Nice-to-have |

---

## Current Architecture (As-Is)

### Key C++ Files
| File | Purpose |
|------|---------|
| `src/systems/ai/ai_system.cpp` | Binds `ai` Lua table, GOAP execution, replanning |
| `src/systems/ai/ai_system.hpp` | AI system interface |
| `src/components/components.hpp` | `GOAPComponent`, `Action` queue |

### Existing Lua AI Files
| File | Purpose |
|------|---------|
| `assets/scripts/ai/init.lua` | Loads actions, goal_selectors, blackboard_init, entity_types |
| `assets/scripts/ai/goal_selector_engine.lua` | Desire + hysteresis + band arbitration |
| `assets/scripts/ai/worldstate_updaters.lua` | Per-AI-tick sensors (runs on `ai_tick_rate_seconds`) |
| `assets/scripts/ai/actions/*.lua` | Coroutine-based GOAP actions |

### Existing Capabilities
- **GOAP planner** with goal arbitration + band priorities (COMBAT > SURVIVAL > WORK > IDLE)
- **Blackboard** per-entity key-value store (typed get/set)
- **Steering behaviors** (seek, flee, pursuit, wander, flocking)
- **TaskBoard** for multi-agent coordination
- **FSM helper** + MonoBehaviour system
- **World state updaters** (tick-based sensors)
- **Physics navmesh pathfinding** via `PhysicsManager.find_path`

### Repo Reality Check (Important)
- **Steering is physics-frame-based:** steering flags are reset each physics update. If GOAP ticks slower than the frame rate (`ai_tick_rate_seconds`), steering-based movement needs a per-frame “driver” (e.g., a Lua system that reads `ai.nav` intent and calls `steering.*` every frame), or you must lower `ai_tick_rate_seconds` so actions run frequently enough.
- **Position source of truth:** `create_ai_entity()` creates a `transform::Transform` entity; it does *not* create a `LocationComponent`. `ai.sense.position()` should therefore prefer physics body position (if present), else fall back to transform position.
- **Navmesh API shape:** `PhysicsManager.find_path(worldName, sx, sy, dx, dy)` takes a **world name string** and returns `{ {x=integer,y=integer}, ... }` points.
- **Debug already exists:** AI inspector/tracing bindings already exist (`ai.get_goap_state`, `ai.get_trace_events`, `ai.clear_trace`, `ai.list_goap_entities`, `ai.report_goal_selection`). Tier 1 “debug” should build on these, and only add drawing helpers.
- **Script compatibility risk:** existing Lua AI scripts reference legacy helpers like `getBlackboardFloat` / `setBlackboardFloat` / `blackboardContains`. Tier 1 should either (a) provide Lua shims for these, or (b) migrate scripts to `ai.bb`/`ai.get_blackboard` to avoid runtime errors.
- **Docs tooling:** C++ bindings use `BindingRecorder`; any new bound functions should be recorded so `assets/scripts/chugget_code_definitions.lua` stays accurate.

---

## Dependency Graph / Implementation Order

```
┌─────────────────────────────────────────────────────────────────┐
│                         TIER 1 (Must Have)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌──────────┐                                                   │
│   │ 1. ai.bb │──────────────────────────────────────────────┐   │
│   └────┬─────┘                                               │   │
│        │                                                     │   │
│        ├──────────────┬──────────────┬──────────────┐       │   │
│        ▼              ▼              ▼              ▼       │   │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │   │
│   │2. ai.sense│  │3. ai.mem │  │4. ai.perc│  │6. ai.dbg │   │   │
│   └────┬─────┘  └──────────┘  └──────────┘  └──────────┘   │   │
│        │                                                     │   │
│        ▼                                                     │   │
│   ┌──────────┐                                               │   │
│   │ 5. ai.nav│◄──────────────────────────────────────────────┘   │
│   └──────────┘                                                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                       TIER 2 (Should Have)                       │
├─────────────────────────────────────────────────────────────────┤
│   7. Goal Cooldowns/Locks    (depends on: goal_selector_engine)  │
│   8. Action Helpers          (depends on: ai.bb)                 │
│   9. Threshold Mapping       (depends on: ai.bb)                 │
│  10. Stuck Detection         (depends on: ai.nav, ai.sense)      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                       TIER 3 (Nice to Have)                      │
├─────────────────────────────────────────────────────────────────┤
│  11. Squad Memory            (depends on: ai.bb)                 │
│  12. Combat Helpers          (depends on: ai.nav, ai.sense)      │
│  13. Investigate Behavior    (depends on: ai.memory, ai.nav)     │
│  14. Spawn Helper            (depends on: ai.bb)                 │
│  15. Messaging               (depends on: signals/events)        │
└─────────────────────────────────────────────────────────────────┘
```

---

# TIER 1: Must Have

---

## 1. Blackboard QoL Helpers (`ai.bb`)

### Overview
Provide a single, “jam-friendly” blackboard API that (1) is safe with `std::any`, (2) supports `{x,y}` without boilerplate, and (3) can be used to shim legacy helpers currently referenced by scripts.

### File Locations
| Action | File |
|--------|------|
| **Modify** | `src/systems/ai/ai_system.cpp` (inside `bind_ai_utilities`) |
| **Add** | `assets/scripts/ai/bb_compat.lua` (optional legacy global shims) |
| **Optional** | `assets/scripts/ai/bb.lua` (Lua wrapper if desired) |

### Dependencies
- `GOAPComponent.blackboard` (exists)
- Existing `ai.get_blackboard(e)` binding
- Existing `Blackboard` usertype methods
- `BindingRecorder` (record new bindings)

### Lua API Specification

```lua
---@class ai.bb
ai.bb = {}

--- Set a value (auto-detects type: bool, int, float, string, Entity, {x,y})
---@param e Entity
---@param key string
---@param value any
function ai.bb.set(e, key, value) end

--- Get a value.
--- NOTE: the underlying Blackboard is `std::any`, so Tier 1 uses the type of `default`
--- to decide how to read the value. If you omit `default` (or pass nil), this does a
--- best-effort type probe for common types (bool/int/float/string/entity/vec2).
---@param e Entity
---@param key string
---@param default? any
---@return any|nil
function ai.bb.get(e, key, default) end

--- Check if key exists
---@param e Entity
---@param key string
---@return boolean
function ai.bb.has(e, key) end

--- Clear all blackboard entries
---@param e Entity
function ai.bb.clear(e) end

--- Convenience: store a position (accepts {x,y})
---@param e Entity
---@param key string
---@param pos {x:number,y:number}
function ai.bb.set_vec2(e, key, pos) end

--- Convenience: fetch a position as {x,y}
---@param e Entity
---@param key string
---@return {x:number,y:number}|nil
function ai.bb.get_vec2(e, key) end

--- Increment a numeric value
---@param e Entity
---@param key string
---@param delta number
---@param default? number  -- used if key doesn't exist
---@return number  -- new value
function ai.bb.inc(e, key, delta, default) end

--- Decay a value toward zero: value *= exp(-rate * dt)
---@param e Entity
---@param key string
---@param rate number
---@param dt number
---@param default? number
---@return number  -- new value
function ai.bb.decay(e, key, rate, dt, default) end
```

### C++ Implementation Notes

```cpp
// Inside bind_ai_utilities(sol::state& lua)
sol::table ai = lua["ai"];
sol::table bb = ai["bb"].get_or_create<sol::table>();

bb.set_function("set", [](entt::entity e, const std::string& key, sol::object v) {
    auto& R = globals::getRegistry();
    if (!R.valid(e) || !R.any_of<GOAPComponent>(e)) return;
    auto& B = R.get<GOAPComponent>(e).blackboard;

    if (v.is<bool>())        { B.set(key, v.as<bool>()); return; }
    if (v.is<int>())         { B.set(key, v.as<int>()); return; }  // rare; Lua numbers are usually doubles
    if (v.is<double>())      { B.set(key, static_cast<float>(v.as<double>())); return; } // store numeric as float
    if (v.is<std::string>()) { B.set(key, v.as<std::string>()); return; }
    if (v.is<entt::entity>()){ B.set(key, v.as<entt::entity>()); return; }

    // Handle {x, y} tables as Vector2
    if (v.is<sol::table>()) {
        auto t = v.as<sol::table>();
        if (t["x"].valid() && t["y"].valid()) {
            Vector2 p{ t.get_or("x", 0.0f), t.get_or("y", 0.0f) };
            B.set(key, p);
            return;
        }
    }
    SPDLOG_WARN("ai.bb.set: unsupported type for key '{}'", key);
});

bb.set_function("get", [](sol::this_state L, entt::entity e, 
                          const std::string& key, sol::object def) -> sol::object {
    auto& R = globals::getRegistry();
    if (!R.valid(e) || !R.any_of<GOAPComponent>(e)) 
        return sol::make_object(L, sol::lua_nil);
    auto& B = R.get<GOAPComponent>(e).blackboard;

    if (!B.contains(key)) {
        return def.valid() ? def : sol::make_object(L, sol::lua_nil);
    }

    // If no default provided, probe common types and return the first that matches.
    if (!def.valid()) {
        try { return sol::make_object(L, B.get<bool>(key)); } catch (...) {}
        try { return sol::make_object(L, B.get<int>(key)); } catch (...) {}
        try { return sol::make_object(L, static_cast<double>(B.get<float>(key))); } catch (...) {}
        try { return sol::make_object(L, B.get<double>(key)); } catch (...) {}
        try { return sol::make_object(L, B.get<std::string>(key)); } catch (...) {}
        try { return sol::make_object(L, B.get<entt::entity>(key)); } catch (...) {}
        try {
            auto p = B.get<Vector2>(key);
            sol::state_view sv(L);
            sol::table out = sv.create_table();
            out["x"] = p.x; out["y"] = p.y;
            return sol::make_object(L, out);
        } catch (...) {}
        return sol::make_object(L, sol::lua_nil);
    }

    try {
        if (def.is<bool>())        return sol::make_object(L, B.get<bool>(key));
        if (def.is<int>())         return sol::make_object(L, B.get<int>(key));
        if (def.is<double>()) {
            try { return sol::make_object(L, static_cast<double>(B.get<float>(key))); } catch (...) {}
            try { return sol::make_object(L, B.get<double>(key)); } catch (...) {}
            return def;
        }
        if (def.is<std::string>()) return sol::make_object(L, B.get<std::string>(key));
        if (def.is<entt::entity>())return sol::make_object(L, B.get<entt::entity>(key));
        if (def.is<sol::table>()) {
            auto p = B.get<Vector2>(key);
            sol::state_view sv(L);
            sol::table out = sv.create_table();
            out["x"] = p.x; out["y"] = p.y;
            return sol::make_object(L, out);
        }
    } catch (...) {
        return def;  // Type mismatch fallback
    }
    return def;
});

bb.set_function("has", [](entt::entity e, const std::string& key) -> bool {
    auto& R = globals::getRegistry();
    if (!R.valid(e) || !R.any_of<GOAPComponent>(e)) return false;
    return R.get<GOAPComponent>(e).blackboard.contains(key);
});

bb.set_function("clear", [](entt::entity e) {
    auto& R = globals::getRegistry();
    if (!R.valid(e) || !R.any_of<GOAPComponent>(e)) return;
    R.get<GOAPComponent>(e).blackboard.clear();
});

bb.set_function("set_vec2", [](entt::entity e, const std::string& key, sol::table pos) {
    auto& R = globals::getRegistry();
    if (!R.valid(e) || !R.any_of<GOAPComponent>(e)) return;
    Vector2 p{ pos.get_or("x", 0.0f), pos.get_or("y", 0.0f) };
    R.get<GOAPComponent>(e).blackboard.set(key, p);
});

bb.set_function("get_vec2", [](sol::this_state L, entt::entity e, const std::string& key) -> sol::object {
    auto& R = globals::getRegistry();
    if (!R.valid(e) || !R.any_of<GOAPComponent>(e)) return sol::make_object(L, sol::lua_nil);
    auto& B = R.get<GOAPComponent>(e).blackboard;
    if (!B.contains(key)) return sol::make_object(L, sol::lua_nil);
    try {
        auto p = B.get<Vector2>(key);
        sol::state_view sv(L);
        sol::table out = sv.create_table();
        out["x"] = p.x; out["y"] = p.y;
        return sol::make_object(L, out);
    } catch (...) {
        return sol::make_object(L, sol::lua_nil);
    }
});

bb.set_function("inc", [](entt::entity e, const std::string& key, 
                          float delta, sol::optional<float> def) -> float {
    auto& R = globals::getRegistry();
    if (!R.valid(e) || !R.any_of<GOAPComponent>(e)) return 0.f;
    auto& B = R.get<GOAPComponent>(e).blackboard;
    
    float current = def.value_or(0.f);
    if (B.contains(key)) {
        try { current = B.get<float>(key); } catch (...) { /* type mismatch -> use default */ }
    }
    float newVal = current + delta;
    B.set(key, newVal);
    return newVal;
});

bb.set_function("decay", [](entt::entity e, const std::string& key,
                            float rate, float dt, sol::optional<float> def) -> float {
    auto& R = globals::getRegistry();
    if (!R.valid(e) || !R.any_of<GOAPComponent>(e)) return 0.f;
    auto& B = R.get<GOAPComponent>(e).blackboard;
    
    float current = def.value_or(0.f);
    if (B.contains(key)) {
        try { current = B.get<float>(key); } catch (...) { /* type mismatch -> use default */ }
    }
    float newVal = current * std::exp(-rate * dt);
    B.set(key, newVal);
    return newVal;
});
```

### Test Cases
1. **Unit tests**:
   - Extend `tests/unit/test_blackboard.cpp` (already exists) to cover any new types you decide to store (e.g., `entt::entity`).
   - Add a small binding-level test (e.g., `tests/unit/test_ai_bb_bindings.cpp`) if you want to exercise the Lua conversion for `{x,y}`.

2. **Smoke test** (`assets/scripts/examples/ai_bb_smoke.lua`):
```lua
local e = create_ai_entity("demo_bot")
ai.bb.set(e, "hunger", 0.5)
assert(ai.bb.get(e, "hunger", 1.0) == 0.5)
ai.bb.inc(e, "anger", 1.0, 0.0)
assert(ai.bb.get(e, "anger", 0.0) == 1.0)
```

### Example Usage
```lua
local e = create_ai_entity("kobold")

-- Basic usage
ai.bb.set(e, "hunger", 0.5)
ai.bb.set_vec2(e, "target_pos", {x = 100, y = 200})
ai.bb.set(e, "is_alerted", true)

-- With defaults
local hunger = ai.bb.get(e, "hunger", 1.0)  -- returns 0.5
local missing = ai.bb.get(e, "foo", 42)     -- returns 42 (default)

-- Numeric operations
ai.bb.inc(e, "kill_count", 1, 0)
ai.bb.decay(e, "anger", 2.0, dt, 0.0)  -- anger decays over time
```

### Optional: Legacy Global Shims (`bb_compat.lua`)
If you want to avoid touching existing scripts immediately, add a tiny shim module that defines the legacy helpers in terms of `ai.bb` (or `ai.get_blackboard`), e.g. `blackboardContains`, `getBlackboardFloat`, `setBlackboardFloat`, etc., and `require()` it from `assets/scripts/ai/init.lua`.

```lua
-- assets/scripts/ai/bb_compat.lua
ai = ai or {}
ai.bb = ai.bb or {}

function blackboardContains(e, key)
    return ai.bb.has and ai.bb.has(e, key) or false
end

function getBlackboardFloat(e, key)
    if not blackboardContains(e, key) then return nil end
    return ai.bb.get(e, key, 0.0)
end

function setBlackboardFloat(e, key, v)
    if ai.bb.set then ai.bb.set(e, key, v) end
end

function getBlackboardInt(e, key)
    if not blackboardContains(e, key) then return nil end
    return ai.bb.get(e, key, 0)
end

function setBlackboardInt(e, key, v)
    if ai.bb.set then ai.bb.set(e, key, v) end
end

function getBlackboardString(e, key)
    if not blackboardContains(e, key) then return nil end
    return ai.bb.get(e, key, "")
end

function setBlackboardString(e, key, v)
    if ai.bb.set then ai.bb.set(e, key, v) end
end

function setBlackboardVector2(e, key, pos)
    if ai.bb.set_vec2 then ai.bb.set_vec2(e, key, pos) end
end

function getBlackboardVector2(e, key)
    if not blackboardContains(e, key) then return nil end
    return ai.bb.get_vec2 and ai.bb.get_vec2(e, key) or nil
end

return true
```

---

## 2. Sense Helpers (`ai.sense`)

### Overview
Simple entity queries without requiring ECS knowledge.

### File Locations
| Action | File |
|--------|------|
| **Modify** | `src/systems/ai/ai_system.cpp` |
| **Optional** | `src/systems/ai/ai_sense.hpp/cpp` (cleaner organization) |
| **Optional** | `assets/scripts/ai/sense.lua` (Lua augment: LOS helper) |
| **Optional** | `assets/scripts/ai/init.lua` (require the augment) |

### Dependencies
- `globals::getRegistry()`
- `transform::Transform` (preferred) and/or `LocationComponent` (fallback)
- Optional: `physics.segment_query_first()` for “wall-only” LOS checks

### Lua API Specification

```lua
---@class ai.sense
ai.sense = {}

--- Get entity position as {x, y}
---@param e Entity
---@return {x:number, y:number}|nil
function ai.sense.position(e) end

--- Calculate distance between two entities or positions
---@param a Entity|{x:number,y:number}
---@param b Entity|{x:number,y:number}
---@return number
function ai.sense.distance(a, b) end

--- Find nearest entity within radius
---@param e Entity  -- the searcher
---@param radius number
---@param opts? {filter:fun(Entity):boolean, scan_limit:integer}
---@return Entity|nil, number|nil  -- entity and distance
function ai.sense.nearest(e, radius, opts) end

--- Find all entities within radius
---@param e Entity
---@param radius number
---@param opts? {filter:fun(Entity):boolean, max:integer, scan_limit:integer}
---@return Entity[]
function ai.sense.all_in_range(e, radius, opts) end

--- Check line of sight between two points/entities
---@param from Entity|{x:number,y:number}
---@param to Entity|{x:number,y:number}
---@param opts? {world:string, alpha_ok:number} -- alpha_ok default ~0.98 (hit near the end counts as clear)
---@return boolean
function ai.sense.has_los(from, to, opts) end
```

### C++ Implementation Notes

```cpp
// Helper to extract a 2D position from:
// - entt::entity (prefer transform center, fallback to LocationComponent)
// - {x,y} table
static std::optional<Vector2> extract_position(entt::registry& R, sol::object obj) {
    if (obj.is<entt::entity>()) {
        auto e = obj.as<entt::entity>();
        if (!R.valid(e)) return std::nullopt;

        // Prefer transform center (CreateOrEmplace produces transform entities)
        if (R.any_of<transform::Transform>(e)) {
            auto& t = R.get<transform::Transform>(e);
            float x = t.getActualX() + 0.5f * t.getActualW();
            float y = t.getActualY() + 0.5f * t.getActualH();

            // Optional: add container offset if present
            if (auto* go = R.try_get<transform::GameObject>(e)) {
                if (R.valid(go->container) && R.any_of<transform::Transform>(go->container)) {
                    auto& ct = R.get<transform::Transform>(go->container);
                    x += ct.getActualX();
                    y += ct.getActualY();
                }
            }
            return Vector2{x, y};
        }

        // Fallback: LocationComponent
        if (R.any_of<LocationComponent>(e)) {
            auto& loc = R.get<LocationComponent>(e);
            return Vector2{loc.x, loc.y};
        }

        return std::nullopt;
    }

    if (obj.is<sol::table>()) {
        auto t = obj.as<sol::table>();
        if (t["x"].valid() && t["y"].valid()) {
            return Vector2{ t.get_or("x", 0.0f), t.get_or("y", 0.0f) };
        }
    }

    return std::nullopt;
}

// Inside bind_ai_utilities
sol::table sense = ai["sense"].get_or_create<sol::table>();

sense.set_function("position", [](sol::this_state L, entt::entity e) -> sol::object {
    auto& R = globals::getRegistry();
    auto pos = extract_position(R, sol::make_object(L, e));
    if (!pos) return sol::make_object(L, sol::lua_nil);
    
    sol::state_view sv(L);
    sol::table out = sv.create_table();
    out["x"] = pos->x;
    out["y"] = pos->y;
    return sol::make_object(L, out);
});

sense.set_function("distance", [](sol::this_state L, sol::object a, sol::object b) -> float {
    auto& R = globals::getRegistry();
    auto pa = extract_position(R, a);
    auto pb = extract_position(R, b);
    if (!pa || !pb) return std::numeric_limits<float>::infinity();
    
    float dx = pb->x - pa->x;
    float dy = pb->y - pa->y;
    return std::sqrt(dx*dx + dy*dy);
});

sense.set_function("nearest", [](sol::this_state L, entt::entity self, float radius, 
                                  sol::optional<sol::table> opts) -> sol::variadic_results {
    sol::variadic_results results;
    auto& R = globals::getRegistry();
    
    auto selfPos = extract_position(R, sol::make_object(L, self));
    if (!selfPos) {
        results.push_back(sol::make_object(L, sol::lua_nil));
        return results;
    }
    
    sol::optional<sol::function> filter = opts ? opts->get<sol::function>("filter") : sol::nullopt;
    int scanLimit = opts ? opts->get_or("scan_limit", std::numeric_limits<int>::max()) : std::numeric_limits<int>::max();
    
    float bestDist = radius * radius;  // Use squared distance
    entt::entity bestEntity = entt::null;
    
    int considered = 0;
    auto view = R.view<transform::Transform>();
    for (auto e : view) {
        if (e == self) continue;
        if (++considered > scanLimit) break;
        
        auto otherPos = extract_position(R, sol::make_object(L, e));
        if (!otherPos) continue;

        float dx = otherPos->x - selfPos->x;
        float dy = otherPos->y - selfPos->y;
        float distSq = dx*dx + dy*dy;
        
        if (distSq < bestDist) {
            // Custom filter (if provided)
            if (filter && filter->valid()) {
                auto res = filter->call(e);
                if (!res.valid() || !res.get<bool>()) continue;
            }
            bestDist = distSq;
            bestEntity = e;
        }
    }
    
    if (bestEntity != entt::null) {
        results.push_back(sol::make_object(L, bestEntity));
        results.push_back(sol::make_object(L, std::sqrt(bestDist)));
    } else {
        results.push_back(sol::make_object(L, sol::lua_nil));
    }
    return results;
});

sense.set_function("all_in_range", [](sol::this_state L, entt::entity self, float radius,
                                     sol::optional<sol::table> opts) -> sol::table {
    auto& R = globals::getRegistry();
    sol::state_view sv(L);
    sol::table out = sv.create_table();

    auto selfPos = extract_position(R, sol::make_object(L, self));
    if (!selfPos) return out;

    sol::optional<sol::function> filter = opts ? opts->get<sol::function>("filter") : sol::nullopt;
    int maxReturn = opts ? opts->get_or("max", 32) : 32;
    int scanLimit = opts ? opts->get_or("scan_limit", std::numeric_limits<int>::max()) : std::numeric_limits<int>::max();

    float r2 = radius * radius;
    int considered = 0;
    int added = 0;

    auto view = R.view<transform::Transform>();
    for (auto e : view) {
        if (e == self) continue;
        if (++considered > scanLimit) break;
        if (added >= maxReturn) break;

        auto otherPos = extract_position(R, sol::make_object(L, e));
        if (!otherPos) continue;

        float dx = otherPos->x - selfPos->x;
        float dy = otherPos->y - selfPos->y;
        float distSq = dx*dx + dy*dy;
        if (distSq > r2) continue;

        if (filter && filter->valid()) {
            auto res = filter->call(e);
            if (!res.valid() || !res.get<bool>()) continue;
        }

        out[++added] = e;
    }

    return out;
});
```

### LOS Implementation Notes (Lua)
`physics.segment_query_first()` provides a convenient “is there a wall in the way?” test without needing to map shapes back to entities. Use `alpha_ok` to treat a hit very close to the end of the segment as “clear”.

```lua
-- assets/scripts/ai/sense.lua (or ai.sense.has_los implementation)
function ai.sense.has_los(from, to, opts)
    opts = opts or {}
    local world_name = opts.world or "main"
    local alpha_ok = opts.alpha_ok or 0.98

    local world = PhysicsManager.get_world(world_name)
    if not world then return false end

    local a = ai.sense.position(from)
    local b = ai.sense.position(to)
    if not a or not b then return false end

    local res = physics.segment_query_first(world, a, b, nil)
    if not res.hit then return true end
    return (res.alpha or 0) >= alpha_ok
end
```

Update `assets/scripts/ai/init.lua` (optional; only needed if you implement `has_los` in Lua):
```lua
ai.sense = require("ai.sense") -- augments C++ ai.sense with has_los()
```

### Test Cases
1. Spawn entities at known positions
2. Verify `nearest` returns correct entity
3. Verify `distance` calculation
4. Test filter callback

### Example Usage
```lua
-- Find nearest player within 300 units
local target, dist = ai.sense.nearest(e, 300, {
    filter = function(other) 
        return registry:has(other, PlayerTag) 
    end
})

if target and ai.sense.has_los(e, target) then
    ai.bb.set(e, "target", target)
    ai.bb.set(e, "target_dist", dist)
    ai.set_worldstate(e, "enemyvisible", true)
end
```

---

## 3. Memory Helpers (`ai.memory`)

### Overview
Remember/recall values with automatic TTL expiration.

### File Locations
| Action | File |
|--------|------|
| **Add** | `assets/scripts/ai/memory.lua` |
| **Modify** | `assets/scripts/ai/init.lua` |

### Dependencies
- `ai.bb` (Tier 1 #1)
- `GetTime()` global

### Implementation

```lua
-- assets/scripts/ai/memory.lua
local M = {}

local function k_val(k) return "mem." .. k .. ".val" end
local function k_exp(k) return "mem." .. k .. ".exp" end

--- Remember a value with optional TTL
---@param e Entity
---@param key string
---@param value any
---@param ttl? number  -- seconds until expiry (nil = forever)
function M.remember(e, key, value, ttl)
    ai.bb.set(e, k_val(key), value)
    if ttl then
        ai.bb.set(e, k_exp(key), GetTime() + ttl)
    else
        ai.bb.set(e, k_exp(key), -1)  -- -1 means no expiry
    end
end

--- Recall a value (returns default if expired or not set)
---@param e Entity
---@param key string
---@param default? any
---@return any|nil
function M.recall(e, key, default)
    local exp = ai.bb.get(e, k_exp(key), -1)
    if exp ~= -1 and GetTime() > exp then
        -- Expired - soft delete
        ai.bb.set(e, k_exp(key), 0)
        return default
    end
    return ai.bb.get(e, k_val(key), default)
end

--- Check if memory exists and is not expired
---@param e Entity
---@param key string
---@return boolean
function M.has(e, key)
    local exp = ai.bb.get(e, k_exp(key), -1)
    if exp ~= -1 and GetTime() > exp then return false end
    return ai.bb.has(e, k_val(key))
end

--- Forget a memory
---@param e Entity
---@param key string
function M.forget(e, key)
    ai.bb.set(e, k_exp(key), 0)  -- Mark as expired
end

--- Remember a position
---@param e Entity
---@param key string
---@param pos {x:number, y:number}
---@param ttl? number
function M.remember_pos(e, key, pos, ttl)
    ai.bb.set_vec2(e, k_val(key), pos)
    if ttl then
        ai.bb.set(e, k_exp(key), GetTime() + ttl)
    else
        ai.bb.set(e, k_exp(key), -1)
    end
end

--- Recall a position
---@param e Entity
---@param key string
---@return {x:number, y:number}|nil
function M.recall_pos(e, key)
    local exp = ai.bb.get(e, k_exp(key), -1)
    if exp ~= -1 and GetTime() > exp then
        ai.bb.set(e, k_exp(key), 0)
        return nil
    end
    return ai.bb.get_vec2(e, k_val(key))
end

return M
```

Update `assets/scripts/ai/init.lua`:
```lua
ai.memory = require("ai.memory")
```

### Example Usage
```lua
-- When spotting an enemy
local enemy_pos = ai.sense.position(enemy)
ai.memory.remember(e, "last_seen_enemy", enemy, 5.0)
ai.memory.remember_pos(e, "last_seen_pos", enemy_pos, 10.0)

-- Later, when searching
local last_enemy = ai.memory.recall(e, "last_seen_enemy")
if last_enemy then
    ai.nav.chase(e, last_enemy)
elseif ai.memory.has(e, "last_seen_pos") then
    local pos = ai.memory.recall_pos(e, "last_seen_pos")
    ai.nav.move_to(e, pos)
end
```

---

## 4. Perception Module (`ai.perception`)

### Overview
Scheduled sensors that automatically write to blackboard.

### File Locations
| Action | File |
|--------|------|
| **Add** | `assets/scripts/ai/perception.lua` |
| **Modify** | `assets/scripts/ai/init.lua` |
| **Optional** | `assets/scripts/ai/worldstate_updaters.lua` (GOAP-tick integration) |
| **Optional** | `assets/scripts/systems/ai_runtime_system.lua` (per-frame integration for high-rate sensors) |

### Implementation

```lua
-- assets/scripts/ai/perception.lua
local P = {}

-- Storage: sensors[entity_id][sensor_name] = {period, next_time, fn}
P._sensors = {}

--- Add a sensor to an entity
---@param e Entity
---@param name string
---@param period number  -- seconds between runs
---@param fn fun(e:Entity, dt:number)
function P.add_sensor(e, name, period, fn)
    local eid = tostring(e)
    P._sensors[eid] = P._sensors[eid] or {}
    P._sensors[eid][name] = {
        period = period,
        next_run = GetTime(),
        fn = fn
    }
end

--- Remove a sensor
---@param e Entity
---@param name string
function P.remove_sensor(e, name)
    local eid = tostring(e)
    if P._sensors[eid] then
        P._sensors[eid][name] = nil
    end
end

--- Tick all sensors for an entity (call from AI update loop)
---@param e Entity
---@param dt number
function P.tick(e, dt)
    local eid = tostring(e)
    local sensors = P._sensors[eid]
    if not sensors then return end
    
    local now = GetTime()
    for name, s in pairs(sensors) do
        if now >= s.next_run then
            s.next_run = now + s.period
            local ok, err = pcall(s.fn, e, dt)
            if not ok then
                print("[ai.perception] Sensor '" .. name .. "' error: " .. tostring(err))
            end
        end
    end
end

--- Clear all sensors for an entity
---@param e Entity
function P.clear(e)
    P._sensors[tostring(e)] = nil
end

--- Preset: enemy scanner
---@param e Entity
---@param opts {range:number, update_hz:number}
function P.enemy_scanner(e, opts)
    local range = opts.range or 200
    local period = 1.0 / (opts.update_hz or 5)
    
    P.add_sensor(e, "enemy_scan", period, function(ent, dt)
        local nearest, dist = ai.sense.nearest(ent, range, {
            filter = function(o)
                return o ~= ent  -- Add tag check as needed
            end
        })
        
        if nearest then
            ai.memory.remember(ent, "target", nearest, 3.0)
            ai.memory.remember_pos(ent, "target_last_pos", ai.sense.position(nearest), 5.0)
            ai.bb.set(ent, "target_dist", dist)
            ai.set_worldstate(ent, "enemyvisible", true)
        else
            ai.set_worldstate(ent, "enemyvisible", false)
        end
    end)
end

return P
```

Update `assets/scripts/ai/init.lua`:
```lua
ai.perception = require("ai.perception")
```

### Tick Integration (Choose One)
Because GOAP currently runs on a fixed tick (`ai_tick_rate_seconds`), sensor periods faster than that need a per-frame driver.

**Option A (simplest, GOAP-tick):** call `ai.perception.tick(e, dt)` from a worldstate updater. Sensors effectively run at `max(period, ai_tick_rate_seconds)`.

```lua
-- assets/scripts/ai/worldstate_updaters.lua
perception_tick = function(e, dt)
    if ai.perception and ai.perception.tick then
        ai.perception.tick(e, dt)
    end
end
```

**Option B (recommended for steering + high-rate perception):** tick perception from a per-frame Lua system and keep GOAP for planning/decision-making.

```lua
-- assets/scripts/systems/ai_runtime_system.lua (shape only; wire into your per-frame update list)
local M = {}
function M.update(dt)
    for _, e in ipairs(ai.list_goap_entities()) do
        if ai.perception and ai.perception.tick then
            ai.perception.tick(e, dt)
        end
        if ai.nav and ai.nav.follow and ai.bb and ai.bb.get and ai.bb.get(e, "nav.active", false) then
            ai.nav.follow(e)
        end
    end
    if ai.debug and ai.debug.tick then
        ai.debug.tick(dt)
    end
end
return M
```

### Example Usage
```lua
-- Setup when entity spawns
ai.perception.enemy_scanner(e, {
    range = 300,
    update_hz = 4  -- 4 times per second
})

-- Custom sensor
ai.perception.add_sensor(e, "hunger_check", 1.0, function(ent, dt)
    local hunger = ai.bb.get(ent, "hunger", 0)
    ai.set_worldstate(ent, "hungry", hunger > 0.7)
end)
```

---

## 5. Navigation Wrappers (`ai.nav`)

### Overview
One-liner movement commands wrapping pathfinding + steering.

### File Locations
| Action | File |
|--------|------|
| **Add** | `assets/scripts/ai/nav.lua` |
| **Modify** | `assets/scripts/ai/init.lua` |

### Dependencies
- `PhysicsManager.find_path` (existing)
- `steering` module (existing)
- `ai.sense.position`

### Implementation

```lua
-- assets/scripts/ai/nav.lua
local N = {}

local DEFAULT_WORLD = "main"
local DEFAULT_ARRIVE = 16

--- Move to a destination point
---@param e Entity
---@param dest {x:number, y:number}
---@param opts? {world:string, arrive:number}
---@return boolean  -- true if path found
function N.move_to(e, dest, opts)
    opts = opts or {}
    local world_name = opts.world or DEFAULT_WORLD
    local arrive = opts.arrive or DEFAULT_ARRIVE
    
    local start = ai.sense.position(e)
    if not start then return false end
    
    -- Get path from navmesh (API takes world name string)
    if PhysicsManager.has_world and not PhysicsManager.has_world(world_name) then
        print("[ai.nav] World '" .. world_name .. "' not found")
        return false
    end

    local path = PhysicsManager.find_path(world_name, start.x, start.y, dest.x, dest.y)
    if not path or #path == 0 then
        -- Direct movement fallback (no obstacles)
        path = {{x = dest.x, y = dest.y}}
    end
    
    -- Set steering path
    steering.set_path(registry, e, path, arrive)
    
    -- Store nav state for debugging/stuck detection
    ai.bb.set_vec2(e, "nav.dest", dest)
    ai.bb.set(e, "nav.world", world_name)
    ai.bb.set(e, "nav.active", true)
    ai.bb.set(e, "nav.start_time", GetTime())
    
    return true
end

--- Follow the current path (call every frame while moving)
---@param e Entity
---@param opts? {decel:number, weight:number}
function N.follow(e, opts)
    opts = opts or {}
    steering.path_follow(registry, e, opts.decel or 1.0, opts.weight or 1.0)
end

--- Chase a target entity (call every frame while chasing)
---@param e Entity
---@param target Entity
---@param opts? {weight:number}
function N.chase(e, target, opts)
    opts = opts or {}
    local weight = opts.weight or 1.0
    steering.pursuit(registry, e, target, weight)
    ai.bb.set(e, "nav.chasing", target) -- debug only (may be absent depending on Lua<->entt conversion)
end

--- Flee from a threat (call every frame while fleeing)
---@param e Entity
---@param threat Entity
---@param opts? {weight:number}
function N.flee(e, threat, opts)
    opts = opts or {}
    local weight = opts.weight or 1.0
    steering.evade(registry, e, threat, weight)
    ai.bb.set(e, "nav.fleeing", threat) -- debug only
end

-- Patrol state lives in Lua (Blackboard cannot store arbitrary Lua tables)
N._patrol = {}

--- Patrol between waypoints
---@param e Entity
---@param points {{x:number, y:number}, ...}
---@param opts? {wait:number, loop:boolean, world:string, arrive:number}
function N.patrol(e, points, opts)
    opts = opts or {}
    local wait_time = opts.wait or 0.5
    local should_loop = opts.loop ~= false  -- default true

    local eid = tostring(e)
    N._patrol[eid] = {
        points = points,
        idx = 1,
        wait = wait_time,
        loop = should_loop,
        wait_until = 0,
        world = opts.world,
        arrive = opts.arrive,
    }

    ai.bb.set(e, "patrol.active", true)
    local first = points[1]
    if first then
        N.move_to(e, first, { world = opts.world, arrive = opts.arrive })
    end
end

--- Update patrol (call in action update)
---@param e Entity
---@param dt number
---@return string  -- "moving", "waiting", "done"
function N.patrol_update(e, dt)
    if not ai.bb.get(e, "patrol.active", false) then
        return "done"
    end

    local st = N._patrol[tostring(e)]
    if not st or not st.points or #st.points == 0 then
        ai.bb.set(e, "patrol.active", false)
        return "done"
    end

    local now = GetTime()
    if st.wait_until and now < st.wait_until then
        return "waiting"
    end

    -- Ensure we keep moving (per-frame driver should also call N.follow)
    if ai.bb.get(e, "nav.active", false) then
        N.follow(e)
    end

    if not N.arrived(e, DEFAULT_ARRIVE) then
        return "moving"
    end

    -- Arrived: advance
    st.idx = st.idx + 1
    if st.idx > #st.points then
        if st.loop then
            st.idx = 1
        else
            ai.bb.set(e, "patrol.active", false)
            N._patrol[tostring(e)] = nil
            return "done"
        end
    end

    st.wait_until = now + (st.wait or 0)
    local nextP = st.points[st.idx]
    if nextP then
        N.move_to(e, nextP, { world = st.world, arrive = st.arrive })
    end
    return "waiting"
end

--- Stop all navigation
---@param e Entity
function N.stop(e)
    -- Clear path; also zero velocity if this entity has a body in the target world.
    steering.set_path(registry, e, {}, DEFAULT_ARRIVE)
    local world_name = ai.bb.get(e, "nav.world", DEFAULT_WORLD)
    local world = PhysicsManager.get_world(world_name)
    if world then
        physics.SetVelocity(world, e, 0, 0)
    end
    ai.bb.set(e, "nav.active", false)
    ai.bb.set(e, "patrol.active", false)
    N._patrol[tostring(e)] = nil
end

--- Check if entity has reached destination
---@param e Entity
---@param threshold? number
---@return boolean
function N.arrived(e, threshold)
    threshold = threshold or DEFAULT_ARRIVE
    local dest = ai.bb.get_vec2(e, "nav.dest")
    if not dest then return true end
    return ai.sense.distance(e, dest) < threshold
end

return N
```

Update `assets/scripts/ai/init.lua`:
```lua
ai.nav = require("ai.nav")
```

### Tick Integration Note
If you want steering-based navigation to look smooth while GOAP ticks slowly, drive `ai.nav.follow()` from a per-frame system (similar to the `ai.perception` per-frame option).

```lua
-- assets/scripts/systems/ai_runtime_system.lua (add to your per-frame update list)
function M.update(dt)
    for _, e in ipairs(ai.list_goap_entities()) do
        if ai.bb.get(e, "nav.active", false) then
            ai.nav.follow(e)
        end
    end
end
```

### Example Usage (GOAP action)
```lua
-- ai/actions/go_to_food.lua
return {
    name = "go_to_food",
    cost = 1,
    pre = { food_visible = true },
    post = { near_food = true },
    
    start = function(e)
        local food_pos = ai.memory.recall_pos(e, "food_pos")
        if food_pos then
            ai.nav.move_to(e, food_pos, { arrive = 24 })
        end
    end,
    
    update = function(e, dt)
        -- If GOAP ticks slower than frame rate, consider calling ai.nav.follow from a per-frame driver.
        ai.nav.follow(e)
        
        if ai.nav.arrived(e, 24) then
            return ActionResult.SUCCESS
        end
        return ActionResult.RUNNING
    end,
    
    finish = function(e)
        ai.nav.stop(e)
    end
}
```

---

## 6. Debug Overlay (`ai.debug`)

### Overview
Visual debugging tools for AI state inspection.

### File Locations
| Action | File |
|--------|------|
| **Add** | `assets/scripts/ai/debug.lua` |
| **Modify** | `assets/scripts/ai/init.lua` |
| **Optional** | `assets/scripts/systems/ai_runtime_system.lua` (per-frame tick/draw) |

### Lua API Specification

```lua
---@class ai.debug
ai.debug = {}

--- Enable/disable debug drawing
---@param enabled boolean
function ai.debug.set_enabled(enabled) end

--- Tick + draw debug primitives (call from a per-frame system)
---@param dt number
function ai.debug.tick(dt) end

--- Draw a debug circle
---@param pos {x:number, y:number}
---@param radius number
---@param color? {r:number, g:number, b:number, a:number}
---@param ttl? number  -- seconds (nil = 1 frame)
function ai.debug.circle(pos, radius, color, ttl) end

--- Draw a debug line
---@param from {x:number, y:number}
---@param to {x:number, y:number}
---@param color? {r:number, g:number, b:number, a:number}
---@param ttl? number
function ai.debug.line(from, to, color, ttl) end

--- Draw text at position
---@param pos {x:number, y:number}
---@param text string
---@param color? {r:number, g:number, b:number, a:number}
function ai.debug.text(pos, text, color) end

--- Trace/log an event (prints to log; optionally also draws short-lived text if enabled)
---@param e Entity
---@param category string
---@param msg string
---@param data? table
function ai.debug.trace(e, category, msg, data) end

--- Get inspection data for an entity
---@param e Entity
---@param opts? {trace_count:integer}
---@return table  -- {goap=table|nil, trace=table[]|nil, blackboard_size=integer}
function ai.debug.inspect(e) end

--- Watch an entity (enable detailed tracing)
---@param e Entity
---@param enabled boolean
function ai.debug.watch(e, enabled) end
```

### Lua Implementation Notes
Implement `ai.debug` in Lua and draw via `command_buffer` (no new C++ rendering hooks). Store primitives in Lua, expire by `GetTime()`, and render them from a per-frame system (recommended).

```lua
-- assets/scripts/ai/debug.lua
local D = {}

D._enabled = false
D._watch = {}
D._items = {} -- { kind="circle"|"line"|"text", ... , expires=number }

local function now() return GetTime() end

local function push(item, ttl)
    item.expires = ttl and (now() + ttl) or (now() + 0.016) -- default ~1 frame
    table.insert(D._items, item)
end

function D.set_enabled(en) D._enabled = not not en end

function D.circle(pos, radius, color, ttl)
    if not D._enabled then return end
    push({ kind = "circle", pos = pos, radius = radius, color = color }, ttl)
end

function D.line(a, b, color, ttl)
    if not D._enabled then return end
    push({ kind = "line", a = a, b = b, color = color }, ttl)
end

function D.text(pos, text, color, ttl)
    if not D._enabled then return end
    push({ kind = "text", pos = pos, text = text, color = color }, ttl or 0.25)
end

function D.trace(e, category, msg, data)
    local prefix = "[ai." .. tostring(category) .. "] "
    if log_debug then
        log_debug(prefix .. tostring(msg), data)
    else
        print(prefix .. tostring(msg))
    end
    if D._enabled and ai and ai.sense and ai.sense.position then
        local pos = ai.sense.position(e)
        if pos then
            D.text({ x = pos.x, y = pos.y - 18 }, tostring(msg), nil, 0.35)
        end
    end
end

function D.watch(e, enabled)
    D._watch[tostring(e)] = not not enabled
end

function D.inspect(e, opts)
    opts = opts or {}
    local bb = ai.get_blackboard and ai.get_blackboard(e) or nil
    return {
        goap = ai.get_goap_state and ai.get_goap_state(e) or nil,
        trace = ai.get_trace_events and ai.get_trace_events(e, opts.trace_count or 20) or nil,
        blackboard_size = (bb and bb:size()) or 0,
    }
end

function D.tick(dt)
    if not (D._enabled and command_buffer and layers and layers.sprites and layer) then return end
    local t = now()

    -- expire + draw
    for i = #D._items, 1, -1 do
        local it = D._items[i]
        if t > (it.expires or 0) then
            table.remove(D._items, i)
        else
            if it.kind == "circle" then
                command_buffer.queueDrawCircleLine(layers.sprites, function(c)
                    c.x = it.pos.x; c.y = it.pos.y
                    c.innerRadius = it.radius - 1
                    c.outerRadius = it.radius
                    c.segments = 48
                    c.startAngle = 0
                    c.endAngle = 360
                    c.color = it.color or (util and util.getColor and util.getColor("WHITE")) or WHITE
                end, 9999, layer.DrawCommandSpace.World)
            elseif it.kind == "line" then
                command_buffer.queueDrawLine(layers.sprites, function(c)
                    c.x1 = it.a.x; c.y1 = it.a.y
                    c.x2 = it.b.x; c.y2 = it.b.y
                    c.color = it.color or (util and util.getColor and util.getColor("WHITE")) or WHITE
                    c.lineWidth = 2
                end, 9999, layer.DrawCommandSpace.World)
            elseif it.kind == "text" then
                command_buffer.queueDrawText(layers.sprites, function(c)
                    c.text = it.text
                    c.x = it.pos.x; c.y = it.pos.y
                    c.fontSize = 12
                    c.color = it.color or (util and util.getColor and util.getColor("WHITE")) or WHITE
                end, 9999, layer.DrawCommandSpace.World)
            end
        end
    end
end

return D
```

Update `assets/scripts/ai/init.lua`:
```lua
ai.debug = require("ai.debug")
```

### Example Usage
```lua
ai.debug.set_enabled(true)

-- In perception sensor (or any runtime system)
ai.perception.add_sensor(e, "debug_vision", 0.1, function(ent, dt)
    local pos = ai.sense.position(ent)
    
    -- Draw vision range
    ai.debug.circle(pos, 200, {r=0, g=255, b=0, a=50}, 0.1)
    
    -- Draw line to target
    local target = ai.memory.recall(ent, "target")
    if target then
        local tpos = ai.sense.position(target)
        ai.debug.line(pos, tpos, {r=255, g=0, b=0, a=180}, 0.1)
    end
end)
```

---

# TIER 2: Should Have

---

## 7. Goal Cooldowns / Locks

### File Location
**Modify:** `assets/scripts/ai/goal_selector_engine.lua`

### Extended Goal Schema
```lua
ai.goals.CHASE = {
    band = "COMBAT",
    persist = 0.10,
    lock = 0.75,      -- Minimum time to stay on this goal
    cooldown = 1.50,  -- Time before can select again after leaving
    desire = function(e) 
        return ai.get_worldstate(e, "enemy_visible") and 1 or 0 
    end,
    on_apply = function(e) 
        ai.set_goal(e, { enemy_dead = true }) 
    end
}
```

### Implementation Changes
```lua
-- In goal_selector_engine.lua
local function is_goal_locked(e, goal_id)
    local locked_until = ai.bb.get(e, "goal.locked_until", 0)
    return GetTime() < locked_until
end

local function is_goal_on_cooldown(e, goal_id)
    local cd_key = "goal.cooldown." .. goal_id
    local cd_until = ai.bb.get(e, cd_key, 0)
    return GetTime() < cd_until
end

local function apply_goal_lock(e, goal)
    if goal.lock then
        ai.bb.set(e, "goal.locked_until", GetTime() + goal.lock)
    end
end

local function apply_goal_cooldown(e, old_goal_id, goals)
    local goal = goals[old_goal_id]
    if goal and goal.cooldown then
        local cd_key = "goal.cooldown." .. old_goal_id
        ai.bb.set(e, cd_key, GetTime() + goal.cooldown)
    end
end
```

---

## 8. Action Helpers (`ai.action`)

### File Location
**Add:** `assets/scripts/ai/action.lua`

### Implementation
```lua
-- assets/scripts/ai/action.lua
local A = {}

--- Create an instant action (succeeds immediately after start)
function A.instant(opts)
    return {
        name = opts.name,
        cost = opts.cost or 1,
        pre = opts.pre or {},
        post = opts.post or {},
        start = opts.on_start or function() end,
        update = function(e, dt)
            return ActionResult.SUCCESS
        end,
        finish = opts.on_finish or function() end,
    }
end

--- Create a timed action (runs for duration then succeeds)
function A.timed(opts)
    local duration = opts.duration or 1.0
    local t0_key = "action." .. opts.name .. ".t0"
    
    return {
        name = opts.name,
        cost = opts.cost or 1,
        pre = opts.pre or {},
        post = opts.post or {},
        start = function(e)
            ai.bb.set(e, t0_key, GetTime())
            if opts.on_start then opts.on_start(e) end
        end,
        update = function(e, dt)
            if opts.on_tick then opts.on_tick(e, dt) end
            
            local elapsed = GetTime() - ai.bb.get(e, t0_key, GetTime())
            if elapsed >= duration then
                return ActionResult.SUCCESS
            end
            return ActionResult.RUNNING
        end,
        finish = opts.on_finish or function() end,
    }
end

--- Wrap an action with a timeout
function A.with_timeout(action, timeout)
    local t0_key = "action." .. action.name .. ".timeout_t0"
    local original_start = action.start
    local original_update = action.update
    
    action.start = function(e)
        ai.bb.set(e, t0_key, GetTime())
        if original_start then original_start(e) end
    end
    
    action.update = function(e, dt)
        local elapsed = GetTime() - ai.bb.get(e, t0_key, GetTime())
        if elapsed >= timeout then
            ai.debug.trace(e, "action", "Timeout: " .. action.name)
            return ActionResult.FAILURE
        end
        return original_update(e, dt)
    end
    
    return action
end

return A
```

### Example Usage
```lua
-- Quick windup action
ai.actions.windup = ai.action.timed{
    name = "windup",
    duration = 0.4,
    pre = { enemy_near = true },
    post = { windup_done = true },
    on_start = function(e) play_anim(e, "windup") end
}

-- Instant pickup
ai.actions.pickup = ai.action.instant{
    name = "pickup",
    pre = { near_item = true },
    post = { has_item = true },
    on_start = function(e) do_pickup(e) end
}

-- With timeout
ai.actions.move_to_food = ai.action.with_timeout(
    require("ai.actions.move_to_food_base"), 
    3.0
)
```

---

## 9. Threshold Mapping (`ai.thresholds`)

### File Location
**Add:** `assets/scripts/ai/thresholds.lua`

### Implementation
```lua
-- assets/scripts/ai/thresholds.lua
local T = {}

--- Map a numeric blackboard value to a boolean worldstate atom
---@param e Entity
---@param mappings {{bb:string, atom:string, gt:number?, lt:number?, eq:number?, default:number?}, ...}
function T.apply(e, mappings)
    for _, m in ipairs(mappings) do
        local val = ai.bb.get(e, m.bb, m.default or 0)
        local result = false
        
        if m.gt and val > m.gt then result = true end
        if m.lt and val < m.lt then result = true end
        if m.eq and val == m.eq then result = true end
        
        ai.set_worldstate(e, m.atom, result)
    end
end

return T
```

### Example Usage
```lua
-- In worldstate updater
ai.thresholds.apply(e, {
    { bb = "hunger", atom = "hungry", gt = 0.7 },
    { bb = "hp", atom = "low_hp", lt = 20 },
    { bb = "enemy_dist", atom = "enemy_near", lt = 80 },
    { bb = "ammo", atom = "out_of_ammo", eq = 0 },
})
```

---

## 10. Stuck Detection

### File Location
**Add:** `assets/scripts/ai/stuck.lua`

### Implementation
```lua
-- assets/scripts/ai/stuck.lua
local S = {}

--- Check if entity is stuck (not making progress)
---@param e Entity
---@param dt number
---@param opts? {eps:number, window:number, key:string}
---@return boolean
function S.check(e, dt, opts)
    opts = opts or {}
    local eps = opts.eps or 2  -- minimum distance to consider "moving"
    local window = opts.window or 0.8  -- seconds of no progress
    local key = opts.key or "nav"
    
    local pos = ai.sense.position(e)
    if not pos then return false end
    
    local last_pos = ai.bb.get(e, key .. ".last_pos", pos)
    local stuck_time = ai.bb.get(e, key .. ".stuck_time", 0)
    
    local dist = ai.sense.distance(pos, last_pos)
    
    if dist < eps then
        stuck_time = stuck_time + dt
    else
        stuck_time = 0
    end
    
    ai.bb.set(e, key .. ".last_pos", pos)
    ai.bb.set(e, key .. ".stuck_time", stuck_time)
    
    return stuck_time >= window
end

--- Reset stuck timer
---@param e Entity
---@param key? string
function S.reset(e, key)
    key = key or "nav"
    ai.bb.set(e, key .. ".stuck_time", 0)
end

return S
```

### Example Usage
```lua
-- In movement action update
function action:update(e, dt)
    if ai.stuck.check(e, dt) then
        ai.debug.trace(e, "nav", "Stuck detected, failing action")
        return ActionResult.FAILURE
    end
    
    ai.nav.follow(e)
    
    if ai.nav.arrived(e) then
        return ActionResult.SUCCESS
    end
    return ActionResult.RUNNING
end
```

---

# TIER 3: Nice to Have

Brief specifications for future implementation.

---

## 11. Squad Memory (`ai.squad`)
```lua
ai.squad.join(e, "goblins_1")
ai.squad.set("goblins_1", "target", player)
ai.squad.get("goblins_1", "target")
ai.squad.broadcast("goblins_1", "attack")
ai.squad.leave(e)
```

## 12. Combat Helpers (`ai.combat`)
```lua
ai.combat.keep_distance(e, target, { min = 120, max = 180 })
ai.combat.strafe(e, target, { direction = "left", speed = 100 })
ai.combat.face_target(e, target)
```

## 13. Investigate Behavior
```lua
ai.behaviors.investigate(e, {
    memory_key = "last_seen_pos",
    search_radius = 120,
    search_time = 3.0,
    on_found = function() end,
    on_timeout = function() end
})
```

## 14. Spawn Helper (`ai.spawn`)
```lua
local e = ai.spawn("kobold", {
    pos = {x = 200, y = 120},
    bb = { hp = 30, hunger = 0.2 },
    world = { candigforgold = true },
    sensors = { "enemy_scanner" },
    squad = "goblins_1"
})
```

## 15. Messaging (`ai.comms`)
```lua
ai.comms.emit("enemy_spotted", { by = e, target = player, pos = {x=100,y=200} })
ai.comms.on("enemy_spotted", function(msg)
    if ai.squad.same_squad(listener, msg.by) then
        ai.memory.remember_pos(listener, "investigate_pos", msg.pos, 5.0)
    end
end)
```

---

# Escalation Triggers

Only add heavier infrastructure if you hit these problems:

| Problem | Solution |
|---------|----------|
| Need to delete/iterate blackboard keys | Add `Blackboard::erase(key)` and `keys()` C++ bindings |
| Perception is a performance hotspot | Move sensor scheduling to C++ component |
| Sense queries too slow (hundreds of entities) | Add spatial index (quadtree) for AI queries |
| Need 50+ simultaneous AI agents | Add LOD scheduling + plan caching |
| Complex formations/crowding | Implement RVO or detour crowd |

---

# Checklist

## Tier 1 Implementation
- [ ] `ai.bb` - C++ bindings in `ai_system.cpp`
- [ ] `ai.sense` - C++ bindings in `ai_system.cpp`
- [ ] `ai.memory` - Lua module `assets/scripts/ai/memory.lua`
- [ ] `ai.perception` - Lua module + GOAP-tick or per-frame integration
- [ ] `ai.nav` - Lua module `assets/scripts/ai/nav.lua`
- [ ] `ai.debug` - Lua module + per-frame tick/draw

## Tier 2 Implementation
- [ ] Goal cooldowns/locks - Modify `goal_selector_engine.lua`
- [ ] Action helpers - Lua module `assets/scripts/ai/action.lua`
- [ ] Thresholds - Lua module `assets/scripts/ai/thresholds.lua`
- [ ] Stuck detection - Lua module `assets/scripts/ai/stuck.lua`

## Tier 3 Implementation
- [ ] Squad memory
- [ ] Combat helpers
- [ ] Investigate behavior
- [ ] Spawn helper
- [ ] Messaging

---

# Quick Start Template

Once implemented, creating a new AI entity becomes:

```lua
-- Create entity with AI (today's API)
local e = create_ai_entity("guard")
local component_cache = require("core.component_cache")
local t = component_cache.get(e, Transform)
if t then
    t.actualX = 100
    t.actualY = 200
end
-- If Tier 3 ai.spawn is added later, this can become:
-- local e = ai.spawn("guard", { pos = {x=100, y=200} })

-- Setup perception
ai.perception.enemy_scanner(e, { range = 250, update_hz = 4 })

-- Custom behavior sensor
ai.perception.add_sensor(e, "stamina_check", 0.5, function(ent, dt)
    ai.bb.decay(ent, "stamina", 0.1, dt, 100)
    local stamina = ai.bb.get(ent, "stamina", 100)
    ai.set_worldstate(ent, "tired", stamina < 20)
end)

-- That's it! GOAP handles the rest based on goals defined in init.lua
```

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
