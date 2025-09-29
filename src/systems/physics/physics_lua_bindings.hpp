#pragma once

#include "physics_manager.hpp"
#include "physics_world.hpp"
#include "systems/physics/transform_physics_hook.hpp"
#include <sol.hpp>

#include "steering.hpp"

namespace physics {


// ---- Lua <-> cpVect helpers -------------------------------------------------
inline cpVect vec_from_lua(sol::table t) {
    return cpv(t.get_or("x", 0.0f), t.get_or("y", 0.0f));
}

inline std::vector<cpVect> vecarray_from_lua(sol::table arr) {
    std::vector<cpVect> out;
    for (auto& kv : arr) {
        sol::table t = kv.second.as<sol::table>();
        out.push_back(vec_from_lua(t));
    }
    return out;
}

inline sol::table vec_to_lua(sol::state_view L, const cpVect& v) {
    sol::table t = L.create_table();
    t["x"] = v.x;
    t["y"] = v.y;
    return t;
}

// ---- Expose physics to Lua --------------------------------------------------
inline void expose_physics_to_lua(sol::state& lua) {
    auto& rec = BindingRecorder::instance();
    const std::vector<std::string> path = {"physics"};

    // ---------- Types ----------
    rec.add_type("physics").doc =
        "Physics namespace (Chipmunk2D). Create worlds, set tags/masks, "
        "raycast, query areas, and attach colliders to entities.";

    struct LuaRaycastHit {
        void*  shape{};
        cpVect point{0, 0};
        cpVect normal{0, 0};
        float  fraction{0.f};
    };
    lua.new_usertype<LuaRaycastHit>(
        "RaycastHit",
        "shape",   &LuaRaycastHit::shape,
        "point",   sol::property([](sol::this_state s, LuaRaycastHit& h) {
            return vec_to_lua(sol::state_view(s), h.point);
        }),
        "normal",  sol::property([](sol::this_state s, LuaRaycastHit& h) {
            return vec_to_lua(sol::state_view(s), h.normal);
        }),
        "fraction",&LuaRaycastHit::fraction
    );
    rec.add_type("physics.RaycastHit").doc =
        "Result of a raycast. Fields:\n"
        "- shape: lightuserdata @ cpShape*\n"
        "- point: {x:number, y:number}\n"
        "- normal: {x:number, y:number}\n"
        "- fraction: number (0..1) distance fraction along the segment";

    struct LuaCollisionEvent {
        void* objectA{};
        void* objectB{};
        float x1{}, y1{}, x2{}, y2{}, nx{}, ny{};
    };
    lua.new_usertype<LuaCollisionEvent>(
        "CollisionEvent",
        "objectA", &LuaCollisionEvent::objectA,
        "objectB", &LuaCollisionEvent::objectB,
        "x1",      &LuaCollisionEvent::x1,
        "y1",      &LuaCollisionEvent::y1,
        "x2",      &LuaCollisionEvent::x2,
        "y2",      &LuaCollisionEvent::y2,
        "nx",      &LuaCollisionEvent::nx,
        "ny",      &LuaCollisionEvent::ny
    );
    rec.add_type("physics.CollisionEvent").doc =
        "Collision event with contact info. Fields:\n"
        "- objectA, objectB: lightuserdata (internally mapped to entt.entity)\n"
        "- x1, y1 (point on A), x2, y2 (point on B), nx, ny (contact normal)";

    // ColliderShapeType enum (table)
    sol::table physics_table = lua["physics"].get_or_create<sol::table>();
    physics_table["ColliderShapeType"] = lua.create_table_with(
        "Rectangle", static_cast<int>(physics::ColliderShapeType::Rectangle),
        "Circle",    static_cast<int>(physics::ColliderShapeType::Circle),
        "Polygon",   static_cast<int>(physics::ColliderShapeType::Polygon),
        "Chain",     static_cast<int>(physics::ColliderShapeType::Chain)
    );
    rec.add_type("physics.ColliderShapeType").doc =
        "Enum of supported collider shapes:\n"
        "- Rectangle, Circle, Polygon, Chain";

    // ---------- PhysicsWorld usertype ----------
    using physics::PhysicsWorld;
    lua.new_usertype<PhysicsWorld>(
        "PhysicsWorld",
        sol::constructors<PhysicsWorld(entt::registry*, float, float, float)>(),
        "Update",                 &PhysicsWorld::Update,
        "PostUpdate",             &PhysicsWorld::PostUpdate,
        "SetGravity",             &PhysicsWorld::SetGravity,
        "SetMeter",               &PhysicsWorld::SetMeter,
        "SetCollisionTags",       &PhysicsWorld::SetCollisionTags,
        "EnableCollisionBetween", &PhysicsWorld::EnableCollisionBetween,
        "DisableCollisionBetween",&PhysicsWorld::DisableCollisionBetween,
        "EnableTriggerBetween",   &PhysicsWorld::EnableTriggerBetween,
        "DisableTriggerBetween",  &PhysicsWorld::DisableTriggerBetween,
        "UpdateCollisionMasks",   &PhysicsWorld::UpdateCollisionMasks,
        "AddCollisionTag",        &PhysicsWorld::AddCollisionTag,
        "RemoveCollisionTag",     &PhysicsWorld::RemoveCollisionTag,
        "UpdateColliderTag",      &PhysicsWorld::UpdateColliderTag,
        "PrintCollisionTags",     &PhysicsWorld::PrintCollisionTags
    );
    {
        auto& pw = rec.add_type("physics.PhysicsWorld");
        pw.doc =
            "Owns a Chipmunk cpSpace, manages collision/trigger tags, and buffers of "
            "collision/trigger events.\n"
            "Construct with (registry*, meter:number, gravityX:number, gravityY:number). "
            "Call Update(dt) each frame and PostUpdate() after consuming event buffers.";
    }

    // ---------- Convenience mappers ----------
    static auto to_entity = [](void* p)->entt::entity {
        return static_cast<entt::entity>(reinterpret_cast<uintptr_t>(p));
    };

    rec.record_free_function(path, {
        "entity_from_ptr",
        "---@param p lightuserdata\n---@return entt.entity",
        "Converts a lightuserdata (internally an entity id) to entt.entity.",
        true, false
    });
    lua["physics"]["entity_from_ptr"] = [](void* p)->entt::entity {
        return static_cast<entt::entity>(reinterpret_cast<uintptr_t>(p));
    };

    rec.record_free_function(path, {
        "GetEntityFromBody",
        "---@param body lightuserdata @ cpBody*\n---@return entt.entity",
        "Returns entt.entity stored in body->userData or entt.null.",
        true, false
    });
    lua["physics"]["GetEntityFromBody"] = &physics::GetEntityFromBody;

    // ---------- Collision/Trigger buffered reads ----------
    rec.record_free_function(path, {
        "GetCollisionEnter",
        "---@param world physics.PhysicsWorld\n"
        "---@param type1 string\n"
        "---@param type2 string\n"
        "---@return {a:entt.entity, b:entt.entity, x1:number, y1:number, x2:number, y2:number, nx:number, ny:number}[]",
        "Buffered collision-begin events for the pair (type1, type2) since last PostUpdate().",
        true, false
    });
    lua["physics"]["GetCollisionEnter"] = [&lua](PhysicsWorld& W, const std::string& t1, const std::string& t2) {
        const auto& v = W.GetCollisionEnter(t1, t2);
        sol::table out = lua.create_table(static_cast<int>(v.size()), 0);
        int i = 1;
        for (const auto& e : v) {
            const entt::entity a = to_entity(e.objectA);
            const entt::entity b = to_entity(e.objectB);
            sol::table ev = lua.create_table();
            ev["a"]  = a;   ev["b"]  = b;
            ev["x1"] = e.x1; ev["y1"] = e.y1;
            ev["x2"] = e.x2; ev["y2"] = e.y2;
            ev["nx"] = e.nx; ev["ny"] = e.ny;
            out[i++] = ev;
        }
        return out;
    };

    rec.record_free_function(path, {
        "GetTriggerEnter",
        "---@param world physics.PhysicsWorld\n"
        "---@param type1 string\n"
        "---@param type2 string\n"
        "---@return entt.entity[]",
        "Buffered trigger-begin hits for (type1, type2) since last PostUpdate(). Returns entity handles.",
        true, false
    });
    lua["physics"]["GetTriggerEnter"] = [](PhysicsWorld& W, const std::string& t1, const std::string& t2) {
        const auto& v = W.GetTriggerEnter(t1, t2);
        std::vector<entt::entity> out;
        out.reserve(v.size());
        for (void* u : v) out.push_back(to_entity(u));
        return sol::as_table(out);
    };

    // ---------- Spatial queries ----------
    rec.record_free_function(path, {
        "Raycast",
        "---@param world physics.PhysicsWorld\n"
        "---@param x1 number @ ray start X (Chipmunk units)\n"
        "---@param y1 number @ ray start Y (Chipmunk units)\n"
        "---@param x2 number @ ray end X (Chipmunk units)\n"
        "---@param y2 number @ ray end Y (Chipmunk units)\n"
        "---@return physics.RaycastHit[]",
        "Segment raycast through the physics space (nearest-first).",
        true, false
    });
    lua["physics"]["Raycast"] = [](PhysicsWorld& W, float x1, float y1, float x2, float y2, sol::this_state) {
        auto hits = W.Raycast(x1, y1, x2, y2);
        std::vector<LuaRaycastHit> out;
        out.reserve(hits.size());
        for (auto& h : hits) {
            LuaRaycastHit r;
            r.shape    = h.shape;
            r.point    = h.point;
            r.normal   = h.normal;
            r.fraction = h.fraction;
            out.push_back(r);
        }
        return sol::as_table(out);
    };

    rec.record_free_function(path, {
        "GetObjectsInArea",
        "---@param world physics.PhysicsWorld\n"
        "---@param x1 number @ rect minX\n"
        "---@param y1 number @ rect minY\n"
        "---@param x2 number @ rect maxX\n"
        "---@param y2 number @ rect maxY\n"
        "---@return entt.entity[] @ entities whose shapes intersect the AABB",
        "Returns entities for all shapes intersecting the rectangle [x1,y1]-[x2,y2].",
        true, false
    });
    lua["physics"]["GetObjectsInArea"] = [](PhysicsWorld& W, float x1, float y1, float x2, float y2) {
        auto raw = W.GetObjectsInArea(x1, y1, x2, y2);
        std::vector<entt::entity> out;
        out.reserve(raw.size());
        for (void* p : raw) out.push_back(p ? to_entity(p) : entt::null);
        return sol::as_table(out);
    };

    // ---------- Attach body/shape to entity ----------
    rec.record_free_function(path, {
        "SetEntityToShape",
        "---@param shape lightuserdata @ cpShape*\n---@param e entt.entity",
        "Stores an entity ID in shape->userData.",
        true, false
    });
    lua["physics"]["SetEntityToShape"] = &physics::SetEntityToShape;

    rec.record_free_function(path, {
        "SetEntityToBody",
        "---@param body lightuserdata @ cpBody*\n---@param e entt.entity",
        "Stores an entity ID in body->userData.",
        true, false
    });
    lua["physics"]["SetEntityToBody"] = &physics::SetEntityToBody;

    // ---------- Create collider(s) ----------
    rec.record_free_function(path, {
        "AddCollider",
        "---@param world physics.PhysicsWorld\n"
        "---@param e entt.entity\n"
        "---@param tag string @ collision tag/category\n"
        "---@param shapeType 'rectangle'|'circle'|'polygon'|'chain'\n"
        "---@param a number @ rectangle: width | circle: radius\n"
        "---@param b number @ rectangle: height\n"
        "---@param c number @ unused (polygon/chain use points)\n"
        "---@param d number @ unused (polygon/chain use points)\n"
        "---@param isSensor boolean\n"
        "---@param points { {x:number,y:number} } | nil @ optional polygon/chain vertices (overrides a–d)\n"
        "---@return nil",
        "Creates cpBody + cpShape for entity, applies tag filter + collisionType, and adds to space.",
        true, false
    });
    lua["physics"]["AddCollider"] =
        [](PhysicsWorld& W, entt::entity e, const std::string& tag, const std::string& shapeType,
           sol::object a, sol::object b, sol::object c, sol::object d,
           bool isSensor, sol::object pointsOpt)
        {
            float A = a.is<double>() ? (float)a.as<double>() : 0.0f;
            float B = b.is<double>() ? (float)b.as<double>() : 0.0f;
            float C = c.is<double>() ? (float)c.as<double>() : 0.0f;
            float D = d.is<double>() ? (float)d.as<double>() : 0.0f;
            std::vector<cpVect> points;
            if (pointsOpt.is<sol::table>()) points = vecarray_from_lua(pointsOpt.as<sol::table>());
            // NOTE: 'segment' is not supported by PhysicsWorld::MakeShapeFor in this build.
            W.AddCollider(e, tag, shapeType, A, B, C, D, isSensor, points);
        };

    // Multi-shape helpers (backed by C++ multi-shape API)
    rec.record_free_function(path, {
        "add_shape_to_entity",
        "---@param world physics.PhysicsWorld\n"
        "---@param e entt.entity\n"
        "---@param tag string\n"
        "---@param shapeType 'rectangle'|'circle'|'polygon'|'chain'\n"
        "---@param a number\n"
        "---@param b number\n"
        "---@param c number\n"
        "---@param d number\n"
        "---@param isSensor boolean\n"
        "---@param points { {x:number,y:number} } | nil\n"
        "---@return nil",
        "Adds an extra shape to an existing entity body (or creates a body if missing).",
        true, false
    });
    lua["physics"]["add_shape_to_entity"] =
        [](PhysicsWorld& W, entt::entity e, const std::string& tag, const std::string& shapeType,
           double a, double b, double c, double d, bool isSensor, sol::object pointsOpt)
        {
            std::vector<cpVect> points;
            if (pointsOpt.is<sol::table>()) points = vecarray_from_lua(pointsOpt.as<sol::table>());
            W.AddShapeToEntity(e, tag, shapeType, (float)a, (float)b, (float)c, (float)d, isSensor, points);
        };

    rec.record_free_function(path, {
        "remove_shape_at",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param index integer @ 0=primary, >=1 extra\n---@return boolean",
        "Removes the shape at index (0 removes the primary). Returns true if removed.",
        true, false
    });
    lua["physics"]["remove_shape_at"] =
        [](PhysicsWorld& W, entt::entity e, uint64_t idx) { return W.RemoveShapeAt(e, (size_t)idx); };

    rec.record_free_function(path, {
        "clear_all_shapes",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@return nil",
        "Removes the primary and all extra shapes from the entity.",
        true, false
    });
    lua["physics"]["clear_all_shapes"] =
        [](PhysicsWorld& W, entt::entity e) { W.ClearAllShapes(e); };

    rec.record_free_function(path, {
        "get_shape_count",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@return integer",
        "Returns the total number of shapes on the entity (primary + extras).",
        true, false
    });
    lua["physics"]["get_shape_count"] =
        [](const PhysicsWorld& W, entt::entity e) { return (uint64_t)W.GetShapeCount(e); };

    rec.record_free_function(path, {
        "get_shape_bb",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param index integer\n"
        "---@return {l:number,b:number,r:number,t:number}",
        "Returns the AABB (cpBB) of the shape at index.",
        true, false
    });
    lua["physics"]["get_shape_bb"] =
        [](const PhysicsWorld& W, entt::entity e, uint64_t idx, sol::this_state s) {
            cpBB bb = W.GetShapeBB(e, (size_t)idx);
            sol::state_view L(s);
            sol::table t = L.create_table();
            t["l"] = (double)bb.l; t["b"] = (double)bb.b;
            t["r"] = (double)bb.r; t["t"] = (double)bb.t;
            return t;
        };

    // ---------- Body kinematics / forces ----------
    rec.record_free_function(path, {
        "SetVelocity",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param vx number\n---@param vy number",
        "Sets linear velocity on the entity's body.",
        true, false
    });
    lua["physics"]["SetVelocity"] = &PhysicsWorld::SetVelocity;

    rec.record_free_function(path, {
        "SetAngularVelocity",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param av number @ radians/sec",
        "Sets angular velocity on the entity's body.",
        true, false
    });
    lua["physics"]["SetAngularVelocity"] = &PhysicsWorld::SetAngularVelocity;

    rec.record_free_function(path, {
        "ApplyForce",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param fx number\n---@param fy number",
        "Applies a force at the body's current position.",
        true, false
    });
    lua["physics"]["ApplyForce"] = &PhysicsWorld::ApplyForce;

    rec.record_free_function(path, {
        "ApplyImpulse",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param ix number\n---@param iy number",
        "Applies an impulse at the body's current position.",
        true, false
    });
    lua["physics"]["ApplyImpulse"] = &PhysicsWorld::ApplyImpulse;

    rec.record_free_function(path, {
        "ApplyTorque",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param torque number",
        "Applies a simple 2-point torque pair to spin the body.",
        true, false
    });
    lua["physics"]["ApplyTorque"] = &PhysicsWorld::ApplyTorque;

    rec.record_free_function(path, {
        "SetDamping",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param linear number",
        "Scales current velocity by (1 - linear). Simple linear damping helper.",
        true, false
    });
    lua["physics"]["SetDamping"] = &PhysicsWorld::SetDamping;

    rec.record_free_function(path, {
        "SetGlobalDamping",
        "---@param world physics.PhysicsWorld\n---@param damping number",
        "Sets cpSpace global damping.",
        true, false
    });
    lua["physics"]["SetGlobalDamping"] = &PhysicsWorld::SetGlobalDamping;

    rec.record_free_function(path, {
        "GetPosition",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@return {x:number,y:number}",
        "Returns the body's position.",
        true, false
    });
    lua["physics"]["GetPosition"] = [](PhysicsWorld& W, entt::entity e, sol::this_state s) {
        auto p = W.GetPosition(e);
        return vec_to_lua(sol::state_view(s), p);
    };

    rec.record_free_function(path, {
        "SetPosition",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param x number\n---@param y number",
        "Sets the body's position directly.",
        true, false
    });
    lua["physics"]["SetPosition"] = &PhysicsWorld::SetPosition;

    rec.record_free_function(path, {
        "GetAngle",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@return number @ radians",
        "Returns the body's angle (radians).",
        true, false
    });
    lua["physics"]["GetAngle"] = &PhysicsWorld::GetAngle;

    rec.record_free_function(path, {
        "SetAngle",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param radians number",
        "Sets the body's angle (radians).",
        true, false
    });
    lua["physics"]["SetAngle"] = &PhysicsWorld::SetAngle;

    rec.record_free_function(path, {
        "SetRestitution",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param restitution number",
        "Sets elasticity on ALL shapes owned by this entity (primary + extras).",
        true, false
    });
    lua["physics"]["SetRestitution"] = &PhysicsWorld::SetRestitution;

    rec.record_free_function(path, {
        "SetFriction",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param friction number",
        "Sets friction on ALL shapes owned by this entity (primary + extras).",
        true, false
    });
    lua["physics"]["SetFriction"] = &PhysicsWorld::SetFriction;

    rec.record_free_function(path, {
        "SetAwake",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param awake boolean",
        "Wakes or sleeps the body.",
        true, false
    });
    lua["physics"]["SetAwake"] = &PhysicsWorld::SetAwake;

    rec.record_free_function(path, {
        "GetMass",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@return number",
        "Returns body mass.",
        true, false
    });
    lua["physics"]["GetMass"] = &PhysicsWorld::GetMass;

    rec.record_free_function(path, {
        "SetMass",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param mass number",
        "Sets body mass.",
        true, false
    });
    lua["physics"]["SetMass"] = &PhysicsWorld::SetMass;

    rec.record_free_function(path, {
        "SetBullet",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param isBullet boolean",
        "Enables high-iteration + slop tuning on the world and custom velocity update for the body.",
        true, false
    });
    lua["physics"]["SetBullet"] = &PhysicsWorld::SetBullet;

    rec.record_free_function(path, {
        "SetFixedRotation",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param fixed boolean",
        "If true, sets the moment to INFINITY (lock rotation).",
        true, false
    });
    lua["physics"]["SetFixedRotation"] = &PhysicsWorld::SetFixedRotation;

    rec.record_free_function(path, {
        "SetBodyType",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param bodyType 'static'|'kinematic'|'dynamic'",
        "Switch the Chipmunk body type for the entity.",
        true, false
    });
    lua["physics"]["SetBodyType"] = &PhysicsWorld::SetBodyType;

    // ---------- Arbiter key-value store helpers ----------
    auto t = lua["physics"].get_or_create<sol::table>();

    rec.record_free_function(path, {
        "arb_set_number",
        "---@param world physics.PhysicsWorld\n---@param arb lightuserdata @ cpArbiter*\n---@param key string\n---@param value number",
        "Attach a transient number to an arbiter for the duration of contact.",
        true, false
    });
    t.set_function("arb_set_number",
        [](PhysicsWorld& world, void* arbPtr, const std::string& key, double val) {
            auto* s = world.ensure_store(static_cast<cpArbiter*>(arbPtr));
            s->nums[key] = val;
        });

    rec.record_free_function(path, {
        "arb_get_number",
        "---@param world physics.PhysicsWorld\n---@param arb lightuserdata @ cpArbiter*\n---@param key string\n---@param default number|nil\n---@return number",
        "Get a number previously set on this arbiter (or default/0).",
        true, false
    });
    t.set_function("arb_get_number",
        [](PhysicsWorld& world, void* arbPtr, const std::string& key, sol::optional<double> def) {
            if (auto* s = static_cast<PhysicsWorld::ArbiterStore*>(
                    cpArbiterGetUserData(static_cast<cpArbiter*>(arbPtr)))) {
                if (auto it = s->nums.find(key); it != s->nums.end())
                    return it->second;
            }
            return def.value_or(0.0);
        });

    rec.record_free_function(path, {
        "arb_set_bool",
        "---@param world physics.PhysicsWorld\n---@param arb lightuserdata @ cpArbiter*\n---@param key string\n---@param value boolean",
        "Attach a transient boolean to an arbiter.",
        true, false
    });
    t.set_function("arb_set_bool",
        [](PhysicsWorld& world, void* arbPtr, const std::string& key, bool v) {
            auto* s = world.ensure_store(static_cast<cpArbiter*>(arbPtr));
            s->bools[key] = v;
        });

    rec.record_free_function(path, {
        "arb_get_bool",
        "---@param world physics.PhysicsWorld\n---@param arb lightuserdata @ cpArbiter*\n---@param key string\n---@param default boolean|nil\n---@return boolean",
        "Get a boolean previously set on this arbiter (or default/false).",
        true, false
    });
    t.set_function("arb_get_bool",
        [](PhysicsWorld& world, void* arbPtr, const std::string& key, sol::optional<bool> def) {
            if (auto* s = static_cast<PhysicsWorld::ArbiterStore*>(
                    cpArbiterGetUserData(static_cast<cpArbiter*>(arbPtr)))) {
                if (auto it = s->bools.find(key); it != s->bools.end())
                    return it->second;
            }
            return def.value_or(false);
        });

    rec.record_free_function(path, {
        "arb_set_ptr",
        "---@param world physics.PhysicsWorld\n---@param arb lightuserdata @ cpArbiter*\n---@param key string\n---@param value lightuserdata",
        "Attach a transient pointer (lightuserdata) to an arbiter.",
        true, false
    });
    t.set_function("arb_set_ptr",
        [](PhysicsWorld& world, void* arbPtr, const std::string& key, void* p) {
            auto* s = world.ensure_store(static_cast<cpArbiter*>(arbPtr));
            s->ptrs[key] = (uintptr_t)p;
        });

    rec.record_free_function(path, {
        "arb_get_ptr",
        "---@param world physics.PhysicsWorld\n---@param arb lightuserdata @ cpArbiter*\n---@param key string\n---@return lightuserdata|nil",
        "Get a pointer previously set on this arbiter (or nil).",
        true, false
    });
    t.set_function("arb_get_ptr",
        [](PhysicsWorld& world, void* arbPtr, const std::string& key) {
            void* out = nullptr;
            if (auto* s = static_cast<PhysicsWorld::ArbiterStore*>(
                    cpArbiterGetUserData(static_cast<cpArbiter*>(arbPtr)))) {
                if (auto it = s->ptrs.find(key); it != s->ptrs.end())
                    out = (void*)it->second;
            }
            return out;
        });

    // ---------- Lua collision handler registration ----------
    rec.record_free_function(path, {
        "on_pair_presolve",
        "---@param world physics.PhysicsWorld\n---@param tagA string\n---@param tagB string\n---@param fn fun(arb:lightuserdata):boolean|nil",
        "Registers a pre-solve callback for the pair (tagA, tagB). Return false to reject contact.",
        true, false
    });
    physics_table.set_function("on_pair_presolve",
        [](PhysicsWorld& W, const std::string& a, const std::string& b, sol::protected_function fn) {
            W.RegisterPairPreSolve(a, b, std::move(fn));
        });

    rec.record_free_function(path, {
        "on_pair_postsolve",
        "---@param world physics.PhysicsWorld\n---@param tagA string\n---@param tagB string\n---@param fn fun(arb:lightuserdata)",
        "Registers a post-solve callback for the pair (tagA, tagB).",
        true, false
    });
    physics_table.set_function("on_pair_postsolve",
        [](PhysicsWorld& W, const std::string& a, const std::string& b, sol::protected_function fn) {
            W.RegisterPairPostSolve(a, b, std::move(fn));
        });

    rec.record_free_function(path, {
        "on_wildcard_presolve",
        "---@param world physics.PhysicsWorld\n---@param tag string\n---@param fn fun(arb:lightuserdata):boolean|nil",
        "Registers a pre-solve wildcard callback for a single tag (fires for any counterpart).",
        true, false
    });
    physics_table.set_function("on_wildcard_presolve",
        [](PhysicsWorld& W, const std::string& tag, sol::protected_function fn) {
            W.RegisterWildcardPreSolve(tag, std::move(fn));
        });

    rec.record_free_function(path, {
        "on_wildcard_postsolve",
        "---@param world physics.PhysicsWorld\n---@param tag string\n---@param fn fun(arb:lightuserdata)",
        "Registers a post-solve wildcard callback for a single tag (fires for any counterpart).",
        true, false
    });
    physics_table.set_function("on_wildcard_postsolve",
        [](PhysicsWorld& W, const std::string& tag, sol::protected_function fn) {
            W.RegisterWildcardPostSolve(tag, std::move(fn));
        });

    rec.record_free_function(path, {
        "clear_pair_handlers",
        "---@param world physics.PhysicsWorld\n---@param tagA string\n---@param tagB string",
        "Clears registered Lua pre/postsolve for that pair.",
        true, false
    });
    physics_table.set_function("clear_pair_handlers",
        [](PhysicsWorld& W, const std::string& a, const std::string& b) { W.ClearPairHandlers(a, b); });

    rec.record_free_function(path, {
        "clear_wildcard_handlers",
        "---@param world physics.PhysicsWorld\n---@param tag string",
        "Clears registered Lua pre/postsolve for that tag wildcard.",
        true, false
    });
    physics_table.set_function("clear_wildcard_handlers",
        [](PhysicsWorld& W, const std::string& tag) { W.ClearWildcardHandlers(tag); });

    // NOTE: The following “transform” helpers reference PhysicsManager/CreatePhysicsForTransform
    // which are outside the provided snippet. Left intact but cosmetically fixed, assuming those exist.

    rec.record_free_function(path, {
        "create_physics_for_transform",
        "---@param R entt.registry&\n"
        "---@param PM PhysicsManager&\n"
        "---@param e entt.entity\n"
        "---@param cfg table @ {shape?:string, tag?:string, sensor?:boolean, density?:number}\n"
        "---@return nil",
        "Creates cpBody+cpShape from Transform ACTUAL size in the entity's referenced world.",
        true, false
    });
    lua["physics"]["create_physics_for_transform"] =
        [](entt::registry& R, PhysicsManager& PM, entt::entity e, sol::table cfg) {
            auto get_string = [&](const char* k, const char* def)->std::string {
                if (auto v = cfg[k]; v.valid() && v.get_type() == sol::type::string) return v.get<std::string>();
                return def;
            };
            auto get_bool = [&](const char* k, bool def)->bool {
                if (auto v = cfg[k]; v.valid() && v.get_type() == sol::type::boolean) return v.get<bool>();
                return def;
            };
            auto get_num = [&](const char* k, float def)->float {
                if (auto v = cfg[k]; v.valid() && v.get_type() == sol::type::number) return v.get<float>();
                return def;
            };
            std::string shapeStr = get_string("shape", "rectangle");
            physics::ColliderShapeType shape = physics::ColliderShapeType::Rectangle;
            if (shapeStr == "circle" || shapeStr == "Circle")      shape = physics::ColliderShapeType::Circle;
            else if (shapeStr == "polygon" || shapeStr == "Polygon") shape = physics::ColliderShapeType::Polygon;
            else if (shapeStr == "chain" || shapeStr == "Chain")     shape = physics::ColliderShapeType::Chain;

            physics::PhysicsCreateInfo ci;
            ci.shape   = shape;
            ci.tag     = get_string("tag", physics::DEFAULT_COLLISION_TAG.c_str());
            ci.sensor  = get_bool  ("sensor", false);
            ci.density = get_num   ("density", 1.0f);
            physics::CreatePhysicsForTransform(R, PM, e, ci);
        };
        
    // PhysicsSyncMode enum (table)
    physics_table["PhysicsSyncMode"] = lua.create_table_with(
        "AuthoritativePhysics",   static_cast<int>(physics::PhysicsSyncMode::AuthoritativePhysics),
        "AuthoritativeTransform", static_cast<int>(physics::PhysicsSyncMode::AuthoritativeTransform),
        "FollowVisual",           static_cast<int>(physics::PhysicsSyncMode::FollowVisual),
        "FrozenWhileDesynced",    static_cast<int>(physics::PhysicsSyncMode::FrozenWhileDesynced)
    );
    rec.add_type("physics.PhysicsSyncMode").doc =
        "Enum:\n- AuthoritativePhysics\n- AuthoritativeTransform\n- FollowVisual\n- FrozenWhileDesynced";

    // RotationSyncMode enum (table)
    physics_table["RotationSyncMode"] = lua.create_table_with(
        "TransformFixed_PhysicsFollows", static_cast<int>(physics::RotationSyncMode::TransformFixed_PhysicsFollows),
        "PhysicsFree_TransformFollows",  static_cast<int>(physics::RotationSyncMode::PhysicsFree_TransformFollows)
    );
    rec.add_type("physics.RotationSyncMode").doc =
        "Enum:\n- TransformFixed_PhysicsFollows (lock body rotation; Transform angle is authority)\n"
        "- PhysicsFree_TransformFollows (body rotates; Transform copies body angle)";
        
    rec.record_free_function(path, {
        "enforce_rotation_policy",
        "---@param R entt.registry\n---@param e entt.entity\n---@return nil",
        "Re-applies current RotationSyncMode immediately (locks/unlocks and snaps angle if needed).",
        true, false
    });
    physics_table.set_function("enforce_rotation_policy",
        [](entt::registry& R, entt::entity e){
            physics::EnforceRotationPolicy(R, e);
        }
    );
    
    rec.record_free_function(path, {
        "use_transform_fixed_rotation",
        "---@param R entt.registry\n---@param e entt.entity\n---@return nil",
        "Lock body rotation; Transform’s angle is authority.",
        true, false
    });
    physics_table.set_function("use_transform_fixed_rotation",
        [](entt::registry& R, entt::entity e){
            auto& cfg = R.get_or_emplace<physics::PhysicsSyncConfig>(e);
            cfg.rotMode = physics::RotationSyncMode::TransformFixed_PhysicsFollows;
            physics::EnforceRotationPolicy(R, e);
        }
    );

    rec.record_free_function(path, {
        "use_physics_free_rotation",
        "---@param R entt.registry\n---@param e entt.entity\n---@return nil",
        "Let physics rotate the body; Transform copies body angle.",
        true, false
    });
    physics_table.set_function("use_physics_free_rotation",
        [](entt::registry& R, entt::entity e){
            auto& cfg = R.get_or_emplace<physics::PhysicsSyncConfig>(e);
            cfg.rotMode = physics::RotationSyncMode::PhysicsFree_TransformFollows;
            physics::EnforceRotationPolicy(R, e);
        }
    );


    
    // physics.set_sync_mode(R, e, mode)
    // mode can be integer (enum) or string ("AuthoritativePhysics", etc.)
    rec.record_free_function(path, {
        "set_sync_mode",
        "---@param R entt.registry\n---@param e entt.entity\n---@param mode integer|string\n---@return nil",
        "Sets PhysicsSyncConfig.mode on the entity.",
        true, false
    });
    physics_table.set_function("set_sync_mode",
        [](entt::registry& R, entt::entity e, sol::object modeObj){
            auto& cfg = R.get_or_emplace<physics::PhysicsSyncConfig>(e);
            if (modeObj.is<int>()) {
                cfg.mode = static_cast<physics::PhysicsSyncMode>(modeObj.as<int>());
            } else if (modeObj.is<std::string>()) {
                const std::string s = modeObj.as<std::string>();
                if      (s == "AuthoritativePhysics")   cfg.mode = physics::PhysicsSyncMode::AuthoritativePhysics;
                else if (s == "AuthoritativeTransform") cfg.mode = physics::PhysicsSyncMode::AuthoritativeTransform;
                else if (s == "FollowVisual")           cfg.mode = physics::PhysicsSyncMode::FollowVisual;
                else if (s == "FrozenWhileDesynced")    cfg.mode = physics::PhysicsSyncMode::FrozenWhileDesynced;
            }
        }
    );

    rec.record_free_function(path, {
        "get_sync_mode",
        "---@param R entt.registry\n---@param e entt.entity\n---@return integer",
        "Returns PhysicsSyncConfig.mode (enum int).",
        true, false
    });
    physics_table.set_function("get_sync_mode",
        [](entt::registry& R, entt::entity e){
            auto& cfg = R.get_or_emplace<physics::PhysicsSyncConfig>(e);
            return static_cast<int>(cfg.mode);
        }
    );

    // physics.set_rotation_mode(R, e, rotMode)
    rec.record_free_function(path, {
        "set_rotation_mode",
        "---@param R entt.registry\n---@param e entt.entity\n---@param rot_mode integer|string\n---@return nil",
        "Sets PhysicsSyncConfig.rotMode on the entity.",
        true, false
    });
    physics_table.set_function("set_rotation_mode",
        [](entt::registry& R, entt::entity e, sol::object modeObj){
            auto& cfg = R.get_or_emplace<physics::PhysicsSyncConfig>(e);
            if (modeObj.is<int>()) {
                cfg.rotMode = static_cast<physics::RotationSyncMode>(modeObj.as<int>());
            } else if (modeObj.is<std::string>()) {
                const std::string s = modeObj.as<std::string>();
                if      (s == "TransformFixed_PhysicsFollows") cfg.rotMode = physics::RotationSyncMode::TransformFixed_PhysicsFollows;
                else if (s == "PhysicsFree_TransformFollows")  cfg.rotMode = physics::RotationSyncMode::PhysicsFree_TransformFollows;
            }
        }
    );

    rec.record_free_function(path, {
        "get_rotation_mode",
        "---@param R entt.registry\n---@param e entt.entity\n---@return integer",
        "Returns PhysicsSyncConfig.rotMode (enum int).",
        true, false
    });
    physics_table.set_function("get_rotation_mode",
        [](entt::registry& R, entt::entity e){
            auto& cfg = R.get_or_emplace<physics::PhysicsSyncConfig>(e);
            return static_cast<int>(cfg.rotMode);
        }
    );



    rec.record_free_function(path, {
        "create_physics_for_transform",
        "---@param R entt.registry\n"
        "---@param PM PhysicsManager\n"
        "---@param e entt.entity\n"
        "---@param world string @ name of physics world\n"
        "---@param cfg table @ {shape?:string, tag?:string, sensor?:boolean, density?:number, inflate_px?:number, set_world_ref?:boolean}\n"
        "---@return nil",
        "Creates physics for an entity in the given world; supports signed inflate in pixels and optional world-ref set.",
        true, false
    });
    lua["physics"]["create_physics_for_transform"] = sol::overload(
        lua["physics"]["create_physics_for_transform"].get<sol::protected_function>(),
        [](entt::registry& R, PhysicsManager& PM, entt::entity e, const std::string& world, sol::table cfg) {
            auto get_string = [&](const char* k, const char* def)->std::string {
                if (auto v = cfg[k]; v.valid() && v.get_type() == sol::type::string) return v.get<std::string>();
                return def;
            };
            auto get_bool = [&](const char* k, bool def)->bool {
                if (auto v = cfg[k]; v.valid() && v.get_type() == sol::type::boolean) return v.get<bool>();
                return def;
            };
            auto get_num = [&](const char* k, float def)->float {
                if (auto v = cfg[k]; v.valid() && v.get_type() == sol::type::number) return v.get<float>();
                return def;
            };
            std::string shapeStr = get_string("shape", "rectangle");
            physics::ColliderShapeType shape = physics::ColliderShapeType::Rectangle;
            if (shapeStr == "circle" || shapeStr == "Circle")        shape = physics::ColliderShapeType::Circle;
            else if (shapeStr == "polygon" || shapeStr == "Polygon") shape = physics::ColliderShapeType::Polygon;
            else if (shapeStr == "chain" || shapeStr == "Chain")     shape = physics::ColliderShapeType::Chain;

            physics::PhysicsCreateInfo ci;
            ci.shape   = shape;
            ci.tag     = get_string("tag", physics::DEFAULT_COLLISION_TAG.c_str());
            ci.sensor  = get_bool  ("sensor", false);
            ci.density = get_num   ("density", 1.0f);

            const float inflate_px = get_num("inflate_px", 0.0f);
            const bool  set_ref    = get_bool("set_world_ref", true);

            physics::CreatePhysicsForTransform(R, PM, e, ci, world, inflate_px, set_ref);
        }
    );

    // =========================
    // === Advanced Features ===
    // =========================

    // Small locals we already have:
    //   vec_from_lua, vecarray_from_lua, vec_to_lua
    //   physics_table = lua["physics"].get_or_create<sol::table>();
    //   to_entity(void*) -> entt::entity

    // ---------- Fluids ----------
    rec.record_free_function(path, {
        "register_fluid_volume",
        "---@param world physics.PhysicsWorld\n---@param tag string\n---@param density number\n---@param drag number\n---@return nil",
        "Registers a fluid config for a collision tag (density, drag).",
        true, false
    });
    physics_table.set_function("register_fluid_volume",
        [](physics::PhysicsWorld& W, const std::string& tag, double density, double drag){
            W.RegisterFluidVolume(tag, (float)density, (float)drag);
        });

    rec.record_free_function(path, {
        "add_fluid_sensor_aabb",
        "---@param world physics.PhysicsWorld\n---@param left number\n---@param bottom number\n---@param right number\n---@param top number\n---@param tag string\n---@return nil",
        "Adds an axis-aligned sensor box that uses the fluid config for 'tag'.",
        true, false
    });
    physics_table.set_function("add_fluid_sensor_aabb",
        [](physics::PhysicsWorld& W, double l, double b, double r, double t, const std::string& tag){
            W.AddFluidSensorAABB((float)l,(float)b,(float)r,(float)t, tag);
        });

    // ---------- One-way platforms ----------
    rec.record_free_function(path, {
        "add_one_way_platform",
        "---@param world physics.PhysicsWorld\n---@param x1 number\n---@param y1 number\n---@param x2 number\n---@param y2 number\n---@param thickness number\n---@param tag string|nil\n---@param n {x:number,y:number}|nil @ platform outward normal (default {0,1})\n---@return entt.entity",
        "Adds a static one-way platform segment. Entities pass from back side.",
        true, false
    });
    physics_table.set_function("add_one_way_platform",
        [&lua](physics::PhysicsWorld& W, double x1, double y1, double x2, double y2,
            double thickness, sol::object tagOpt, sol::object nOpt){
            std::string tag = tagOpt.is<std::string>() ? tagOpt.as<std::string>() : "one_way";
            cpVect n = {0,1};
            if (nOpt.is<sol::table>()) n = vec_from_lua(nOpt.as<sol::table>());
            auto e = W.AddOneWayPlatform((float)x1,(float)y1,(float)x2,(float)y2,(float)thickness, tag, n);
            return e;
        });

    // ---------- Sticky glue ----------
    rec.record_free_function(path, {
        "enable_sticky_between",
        "---@param world physics.PhysicsWorld\n---@param tagA string\n---@param tagB string\n---@param impulse_threshold number\n---@param max_force number\n---@return nil",
        "When collision impulse exceeds threshold, creates temporary pivot joints between shapes.",
        true, false
    });
    physics_table.set_function("enable_sticky_between",
        [](physics::PhysicsWorld& W, const std::string& A, const std::string& B,
        double impulseThreshold, double maxForce) {
            W.EnableStickyBetween(A, B, (float)impulseThreshold, (float)maxForce);
        });

    rec.record_free_function(path, {
        "disable_sticky_between",
        "---@param world physics.PhysicsWorld\n---@param tagA string\n---@param tagB string\n---@return nil",
        "Stops glue creation for the pair.",
        true, false
    });
    physics_table.set_function("disable_sticky_between",
        [](physics::PhysicsWorld& W, const std::string& A, const std::string& B) {
            W.DisableStickyBetween(A, B);
        });

    // ---------- Controllers (platformer, tank, top-down) ----------
    rec.record_free_function(path, {
        "create_platformer_player",
        "---@param world physics.PhysicsWorld\n---@param pos {x:number,y:number}\n---@param w number\n---@param h number\n---@param tag string\n---@return entt.entity",
        "Creates a kinematic-friendly box with custom velocity update for platforming.",
        true, false
    });
    physics_table.set_function("create_platformer_player",
        [](physics::PhysicsWorld& W, sol::table pos, double w, double h, const std::string& tag){
            cpVect p = vec_from_lua(pos);
            return W.CreatePlatformerPlayer(p, (float)w, (float)h, tag);
        });

    rec.record_free_function(path, {
        "set_platformer_input",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param move_x number @ [-1..1]\n---@param jump_held boolean\n---@return nil",
        "Feeds input each frame to the platformer controller.",
        true, false
    });
    physics_table.set_function("set_platformer_input",
        [](physics::PhysicsWorld& W, entt::entity e, double move_x, bool jump_held){
            W.SetPlatformerInput(e, (float)move_x, jump_held);
        });

    rec.record_free_function(path, {
        "create_topdown_controller",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param max_bias number\n---@param max_force number\n---@return nil",
        "Attaches a top-down controller (pivot constraint) to the entity's body.",
        true, false
    });
    physics_table.set_function("create_topdown_controller",
        [](physics::PhysicsWorld& W, entt::entity e, double max_bias, double max_force){
            W.CreateTopDownController(e, (float)max_bias, (float)max_force);
        });

    rec.record_free_function(path, {
        "enable_tank_controller",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param drive_speed number|nil\n---@param stop_radius number|nil\n---@param pivot_max_force number|nil\n---@param gear_max_force number|nil\n---@param gear_max_bias number|nil\n---@return nil",
        "Adds a kinematic control body + constraints; call command_tank_to() and update_tanks(dt).",
        true, false
    });
    physics_table.set_function("enable_tank_controller",
        [](physics::PhysicsWorld& W, entt::entity e,
        sol::optional<double> drive, sol::optional<double> stopR,
        sol::optional<double> pivotF, sol::optional<double> gearF, sol::optional<double> gearB){
            W.EnableTankController(e,
                (float)drive.value_or(30.0),
                (float)stopR.value_or(30.0),
                (float)pivotF.value_or(10000.0),
                (float)gearF.value_or(50000.0),
                (float)gearB.value_or(1.2));
        });

    rec.record_free_function(path, {
        "command_tank_to",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param target {x:number,y:number}\n---@return nil",
        "Sets the tank's target point.",
        true, false
    });
    physics_table.set_function("command_tank_to",
        [](physics::PhysicsWorld& W, entt::entity e, sol::table target){
            W.CommandTankTo(e, vec_from_lua(target));
        });

    rec.record_free_function(path, {
        "update_tanks",
        "---@param world physics.PhysicsWorld\n---@param dt number\n---@return nil",
        "Updates all tank controllers for dt.",
        true, false
    });
    physics_table.set_function("update_tanks",
        [](physics::PhysicsWorld& W, double dt){ W.UpdateTanks(dt); });

    // ---------- Custom Gravity Fields / Orbits ----------
    rec.record_free_function(path, {
        "enable_inverse_square_gravity_to_point",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param point {x:number,y:number}\n---@param GM number\n---@return nil",
        "Replaces velocity integration with inverse-square gravity toward a fixed point.",
        true, false
    });
    physics_table.set_function("enable_inverse_square_gravity_to_point",
        [](physics::PhysicsWorld& W, entt::entity e, sol::table point, double GM){
            W.EnableInverseSquareGravityToPoint(e, vec_from_lua(point), (float)GM);
        });

    rec.record_free_function(path, {
        "enable_inverse_square_gravity_to_body",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param center entt.entity\n---@param GM number\n---@return nil",
        "Inverse-square gravity toward another body's center.",
        true, false
    });
    physics_table.set_function("enable_inverse_square_gravity_to_body",
        [](physics::PhysicsWorld& W, entt::entity e, entt::entity center, double GM){
            W.EnableInverseSquareGravityToBody(e, center, (float)GM);
        });

    rec.record_free_function(path, {
        "disable_custom_gravity",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@return nil",
        "Restores default velocity integration for the body.",
        true, false
    });
    physics_table.set_function("disable_custom_gravity",
        [](physics::PhysicsWorld& W, entt::entity e){ W.DisableCustomGravity(e); });

    rec.record_free_function(path, {
        "create_planet",
        "---@param world physics.PhysicsWorld\n---@param radius number\n---@param spin number @ rad/s\n---@param tag string|nil\n---@param pos {x:number,y:number}|nil\n---@return entt.entity",
        "Creates a kinematic spinning circle body as a 'planet'.",
        true, false
    });
    physics_table.set_function("create_planet",
        [](physics::PhysicsWorld& W, double radius, double spin, sol::object tagOpt, sol::object posOpt){
            std::string tag = tagOpt.is<std::string>() ? tagOpt.as<std::string>() : "planet";
            cpVect pos = {0,0}; if (posOpt.is<sol::table>()) pos = vec_from_lua(posOpt.as<sol::table>());
            return W.CreatePlanet((float)radius, (float)spin, tag, pos);
        });

    rec.record_free_function(path, {
        "spawn_orbiting_box",
        "---@param world physics.PhysicsWorld\n---@param start_pos {x:number,y:number}\n---@param half_size number\n---@param mass number\n---@param GM number\n---@param gravity_center {x:number,y:number}\n---@return entt.entity",
        "Spawns a dynamic box with initial circular orbit and inverse-square gravity toward the center.",
        true, false
    });
    physics_table.set_function("spawn_orbiting_box",
        [](physics::PhysicsWorld& W, sol::table startPos, double halfSize,
        double mass, double GM, sol::table gravityCenter){
            return W.SpawnOrbitingBox(vec_from_lua(startPos), (float)halfSize, (float)mass,
                                    (float)GM, vec_from_lua(gravityCenter));
        });

    // ---------- Precise queries ----------
    rec.record_free_function(path, {
        "segment_query_first",
        "---@param world physics.PhysicsWorld\n---@param start {x:number,y:number}\n---@param finish {x:number,y:number}\n---@param radius number|nil\n---@return table @ {hit:boolean, shape:lightuserdata|nil, point={x,y}|nil, normal={x,y}|nil, alpha:number}",
        "Closest segment hit with optional fat radius.",
        true, false
    });
    physics_table.set_function("segment_query_first",
        [&lua](const physics::PhysicsWorld& W, sol::table A, sol::table B, sol::optional<double> r){
            physics::SegmentQueryHit h = W.SegmentQueryFirst(vec_from_lua(A), vec_from_lua(B), (float)r.value_or(0.0), CP_SHAPE_FILTER_ALL);
            sol::table t = lua.create_table();
            t["hit"]   = h.hit;
            t["alpha"] = h.alpha;
            if (h.hit) {
                t["shape"]  = h.shape;
                t["point"]  = vec_to_lua(sol::state_view(lua.lua_state()), h.point);
                t["normal"] = vec_to_lua(sol::state_view(lua.lua_state()), h.normal);
            }
            return t;
        });

    rec.record_free_function(path, {
        "point_query_nearest",
        "---@param world physics.PhysicsWorld\n---@param p {x:number,y:number}\n---@param max_distance number|nil\n---@return table @ {hit:boolean, shape:lightuserdata|nil, point={x,y}|nil, distance:number|nil}",
        "Nearest shape to a point (distance < 0 means inside).",
        true, false
    });
    physics_table.set_function("point_query_nearest",
        [&lua](const physics::PhysicsWorld& W, sol::table P, sol::optional<double> md){
            physics::NearestPointHit h = W.PointQueryNearest(vec_from_lua(P), (float)md.value_or(0.0), CP_SHAPE_FILTER_ALL);
            sol::table t = lua.create_table();
            t["hit"] = h.hit;
            if (h.hit) {
                t["shape"]    = h.shape;
                t["point"]    = vec_to_lua(sol::state_view(lua.lua_state()), h.point);
                t["distance"] = h.distance;
            }
            return t;
        });

    // ---------- Shatter / Slice ----------
    rec.record_free_function(path, {
        "shatter_nearest",
        "---@param world physics.PhysicsWorld\n---@param x number\n---@param y number\n---@param grid_div number|nil @ cells across AABB (>= 3 is sensible)\n---@return boolean",
        "Voronoi-shatters the nearest polygon shape around (x,y).",
        true, false
    });
    physics_table.set_function("shatter_nearest",
        [](physics::PhysicsWorld& W, double x, double y, sol::optional<double> gridDiv){
            return W.ShatterNearest((float)x, (float)y, (float)gridDiv.value_or(5.0));
        });

    rec.record_free_function(path, {
        "slice_first_hit",
        "---@param world physics.PhysicsWorld\n---@param A {x:number,y:number}\n---@param B {x:number,y:number}\n---@param density number\n---@param min_area number\n---@return boolean",
        "Slices the first polygon hit by segment AB into two bodies (returns true if sliced).",
        true, false
    });
    physics_table.set_function("slice_first_hit",
        [](physics::PhysicsWorld& W, sol::table A, sol::table B, double density, double minArea){
            return W.SliceFirstHit(vec_from_lua(A), vec_from_lua(B), (float)density, (float)minArea);
        });

    // ---------- Static chains / bars / bounds ----------
    rec.record_free_function(path, {
        "add_smooth_segment_chain",
        "---@param world physics.PhysicsWorld\n---@param pts { {x:number,y:number}, ... }\n---@param radius number\n---@param tag string\n---@return entt.entity",
        "Adds a static chain of segments with smoothed neighbor normals.",
        true, false
    });
    physics_table.set_function("add_smooth_segment_chain",
        [](physics::PhysicsWorld& W, sol::table pts, double radius, const std::string& tag){
            return W.AddSmoothSegmentChain(vecarray_from_lua(pts), (float)radius, tag);
        });

    rec.record_free_function(path, {
        "add_bar_segment",
        "---@param world physics.PhysicsWorld\n---@param a {x:number,y:number}\n---@param b {x:number,y:number}\n---@param thickness number\n---@param tag string\n---@param group integer|nil @ same non-zero group never collide with each other\n---@return entt.entity",
        "Creates a dynamic slender rod body with a segment collider.",
        true, false
    });
    physics_table.set_function("add_bar_segment",
        [](physics::PhysicsWorld& W, sol::table a, sol::table b, double thickness, const std::string& tag, sol::optional<int64_t> group){
            return W.AddBarSegment(vec_from_lua(a), vec_from_lua(b), (float)thickness, tag, (int32_t)group.value_or(0));
        });

    rec.record_free_function(path, {
        "add_screen_bounds",
        "---@param world physics.PhysicsWorld\n---@param xMin number\n---@param yMin number\n---@param xMax number\n---@param yMax number\n---@param thickness number\n---@param tag string\n---@return nil",
        "Adds four static walls (segment shapes) as a box boundary.",
        true, false
    });
    physics_table.set_function("add_screen_bounds",
        [](physics::PhysicsWorld& W, double xMin, double yMin, double xMax, double yMax,
        double thickness, const std::string& tag){
            W.AddScreenBounds((float)xMin,(float)yMin,(float)xMax,(float)yMax,(float)thickness, tag);
        });

    // Optional: tilemap colliders from bool grid (arr[x][y] = true)
    rec.record_free_function(path, {
        "create_tilemap_colliders",
        "---@param world physics.PhysicsWorld\n---@param grid boolean[][] @ grid[x][y]\n---@param tile_size number\n---@param segment_radius number\n---@return nil",
        "Generates static segments following the outline of solid cells.",
        true, false
    });
    physics_table.set_function("create_tilemap_colliders",
        [](physics::PhysicsWorld& W, sol::table grid, double tileSize, double segRadius){
            std::vector<std::vector<bool>> G;
            // Expect outer index = x, inner = y
            int xCount = 0;
            for (auto& kxv : grid) { (void)kxv; ++xCount; }
            G.reserve(xCount);
            for (auto& kxv : grid) {
                sol::table col = kxv.second.as<sol::table>();
                std::vector<bool> column;
                for (auto& kyv : col) {
                    bool b = false;
                    if (kyv.second.is<bool>()) b = kyv.second.as<bool>();
                    column.push_back(b);
                }
                G.push_back(std::move(column));
            }
            W.CreateTilemapColliders(G, (float)tileSize, (float)segRadius);
        });

    // ---------- Contact metrics & neighbors ----------
    rec.record_free_function(path, {
        "touching_entities",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@return entt.entity[]",
        "Returns entities currently touching e (via arbiters).",
        true, false
    });
    physics_table.set_function("touching_entities",
        [](physics::PhysicsWorld& W, entt::entity e){
            return sol::as_table(W.TouchingEntities(e));
        });

    rec.record_free_function(path, {
        "total_force_on",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param dt number\n---@return number",
        "Sum of contact impulses / dt on the body this step.",
        true, false
    });
    physics_table.set_function("total_force_on",
        [](physics::PhysicsWorld& W, entt::entity e, double dt){ return W.TotalForceOn(e, (float)dt); });

    rec.record_free_function(path, {
        "weight_on",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param dt number\n---@return number",
        "Projection of force along gravity / |g| (i.e., perceived weight).",
        true, false
    });
    physics_table.set_function("weight_on",
        [](physics::PhysicsWorld& W, entt::entity e, double dt){ return W.WeightOn(e, (float)dt); });

    rec.record_free_function(path, {
        "crush_on",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param dt number\n---@return table @ {touching_count:integer, crush:number}",
        "Crush metric ~ (sum|J| - |sum J|) * dt.",
        true, false
    });
    physics_table.set_function("crush_on",
        [&lua](physics::PhysicsWorld& W, entt::entity e, double dt){
            auto c = W.CrushOn(e, (float)dt);
            sol::table t = lua.create_table();
            t["touching_count"] = c.touchingCount;
            t["crush"] = c.crush;
            return t;
        });

    // ---------- Mouse drag helper ----------
    rec.record_free_function(path, {
        "start_mouse_drag",
        "---@param world physics.PhysicsWorld\n---@param x number\n---@param y number\n---@return nil",
        "Begins dragging nearest body at (x,y).",
        true, false
    });
    physics_table.set_function("start_mouse_drag",
        [](physics::PhysicsWorld& W, double x, double y){ W.StartMouseDrag((float)x,(float)y); });

    rec.record_free_function(path, {
        "update_mouse_drag",
        "---@param world physics.PhysicsWorld\n---@param x number\n---@param y number\n---@return nil",
        "Updates mouse drag anchor.",
        true, false
    });
    physics_table.set_function("update_mouse_drag",
        [](physics::PhysicsWorld& W, double x, double y){ W.UpdateMouseDrag((float)x,(float)y); });

    rec.record_free_function(path, {
        "end_mouse_drag",
        "---@param world physics.PhysicsWorld\n---@return nil",
        "Ends mouse dragging.",
        true, false
    });
    physics_table.set_function("end_mouse_drag",
        [](physics::PhysicsWorld& W){ W.EndMouseDrag(); });

    // ---------- Constraints (quick wrappers) ----------
    rec.record_free_function(path, {
        "add_pin_joint",
        "---@param world physics.PhysicsWorld\n---@param ea entt.entity\n---@param a_local {x:number,y:number}\n---@param eb entt.entity\n---@param b_local {x:number,y:number}\n---@return lightuserdata @ cpConstraint*",
        "Adds a pin joint between two bodies (local anchors).",
        true, false
    });
    physics_table.set_function("add_pin_joint",
        [](physics::PhysicsWorld& W, entt::entity ea, sol::table aLocal, entt::entity eb, sol::table bLocal){
            return (void*)W.AddPinJoint(ea, vec_from_lua(aLocal), eb, vec_from_lua(bLocal));
        });

    rec.record_free_function(path, {
        "add_slide_joint",
        "---@param world physics.PhysicsWorld\n---@param ea entt.entity\n---@param a_local {x:number,y:number}\n---@param eb entt.entity\n---@param b_local {x:number,y:number}\n---@param min_d number\n---@param max_d number\n---@return lightuserdata @ cpConstraint*",
        "Adds a slide joint.",
        true, false
    });
    physics_table.set_function("add_slide_joint",
        [](physics::PhysicsWorld& W, entt::entity ea, sol::table aL, entt::entity eb, sol::table bL, double minD, double maxD){
            return (void*)W.AddSlideJoint(ea, vec_from_lua(aL), eb, vec_from_lua(bL), (float)minD, (float)maxD);
        });

    rec.record_free_function(path, {
        "add_pivot_joint_world",
        "---@param world physics.PhysicsWorld\n---@param ea entt.entity\n---@param eb entt.entity\n---@param world_anchor {x:number,y:number}\n---@return lightuserdata @ cpConstraint*",
        "Adds a pivot joint defined in world space.",
        true, false
    });
    physics_table.set_function("add_pivot_joint_world",
        [](physics::PhysicsWorld& W, entt::entity ea, entt::entity eb, sol::table worldAnchor){
            return (void*)W.AddPivotJointWorld(ea, eb, vec_from_lua(worldAnchor));
        });

    rec.record_free_function(path, {
        "add_damped_spring",
        "---@param world physics.PhysicsWorld\n---@param ea entt.entity\n---@param a_local {x:number,y:number}\n---@param eb entt.entity\n---@param b_local {x:number,y:number}\n---@param rest number\n---@param k number\n---@param damping number\n---@return lightuserdata @ cpConstraint*",
        "Adds a linear damped spring.",
        true, false
    });
    physics_table.set_function("add_damped_spring",
        [](physics::PhysicsWorld& W, entt::entity ea, sol::table aL, entt::entity eb, sol::table bL,
        double rest, double k, double damping){
            return (void*)W.AddDampedSpring(ea, vec_from_lua(aL), eb, vec_from_lua(bL),
                                            (float)rest, (float)k, (float)damping);
        });

    rec.record_free_function(path, {
        "add_damped_rotary_spring",
        "---@param world physics.PhysicsWorld\n---@param ea entt.entity\n---@param eb entt.entity\n---@param rest_angle number\n---@param k number\n---@param damping number\n---@return lightuserdata @ cpConstraint*",
        "Adds a rotary damped spring.",
        true, false
    });
    physics_table.set_function("add_damped_rotary_spring",
        [](physics::PhysicsWorld& W, entt::entity ea, entt::entity eb, double restAngle, double k, double damping){
            return (void*)W.AddDampedRotarySpring(ea, eb, (float)restAngle, (float)k, (float)damping);
        });

    rec.record_free_function(path, {
        "set_constraint_limits",
        "---@param world physics.PhysicsWorld\n---@param c lightuserdata @ cpConstraint*\n---@param max_force number|nil\n---@param max_bias number|nil\n---@return nil",
        "Convenience to set cpConstraint maxForce/maxBias (pass nil to keep).",
        true, false
    });
    physics_table.set_function("set_constraint_limits",
        [](physics::PhysicsWorld& W, void* c, sol::optional<double> maxF, sol::optional<double> maxB){
            W.SetConstraintLimits(static_cast<cpConstraint*>(c),
                                maxF ? (float)maxF.value() : -1.0f,
                                maxB ? (float)maxB.value() : -1.0f);
        });

    rec.record_free_function(path, {
        "add_upright_spring",
        "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param stiffness number\n---@param damping number\n---@return nil",
        "Keeps a body upright (rotary spring to static body).",
        true, false
    });
    physics_table.set_function("add_upright_spring",
        [](physics::PhysicsWorld& W, entt::entity e, double k, double d){ W.AddUprightSpring(e, (float)k, (float)d); });

    // Breakable slide / convert-to-breakable
    rec.record_free_function(path, {
        "make_breakable_slide_joint",
        "---@param world physics.PhysicsWorld\n---@param ea entt.entity\n---@param eb entt.entity\n---@param a_local {x:number,y:number}\n---@param b_local {x:number,y:number}\n---@param min_d number\n---@param max_d number\n---@param breaking_force number\n---@param trigger_ratio number\n---@param collide_bodies boolean\n---@param use_fatigue boolean\n---@param fatigue_rate number\n---@return lightuserdata @ cpConstraint*",
        "Creates a slide joint that breaks under force/fatigue.",
        true, false
    });
    physics_table.set_function("make_breakable_slide_joint",
        [](physics::PhysicsWorld& W, entt::entity ea, entt::entity eb, sol::table aL, sol::table bL,
        double minD, double maxD, double breakingForce, double triggerRatio,
        bool collideBodies, bool useFatigue, double fatigueRate){
            return (void*)W.MakeBreakableSlideJoint(
                W.BodyOf(ea), W.BodyOf(eb),
                vec_from_lua(aL), vec_from_lua(bL),
                (float)minD, (float)maxD,
                (float)breakingForce, (float)triggerRatio, collideBodies,
                useFatigue, (float)fatigueRate);
        });

    rec.record_free_function(path, {
        "make_constraint_breakable",
        "---@param world physics.PhysicsWorld\n---@param c lightuserdata @ cpConstraint*\n---@param breaking_force number\n---@param trigger_ratio number\n---@param use_fatigue boolean\n---@param fatigue_rate number\n---@return nil",
        "Attaches breakable behavior to an existing constraint.",
        true, false
    });
    physics_table.set_function("make_constraint_breakable",
        [](physics::PhysicsWorld& W, void* c, double breakingForce, double triggerRatio,
        bool useFatigue, double fatigueRate){
            W.MakeConstraintBreakable(static_cast<cpConstraint*>(c),
                (float)breakingForce, (float)triggerRatio, useFatigue, (float)fatigueRate);
        });

    // ---------- Grouping (Union-Find) ----------
    rec.record_free_function(path, {
        "enable_collision_grouping",
        "---@param world physics.PhysicsWorld\n---@param min_type integer\n---@param max_type integer\n---@param threshold integer\n---@return nil",
        "Groups bodies that collide with same-type contacts; when a group's count >= threshold, callback in C++ runs.",
        true, false
    });
    physics_table.set_function("enable_collision_grouping",
        [](physics::PhysicsWorld& W, uint64_t minT, uint64_t maxT, int threshold){
            W.EnableCollisionGrouping((cpCollisionType)minT, (cpCollisionType)maxT, threshold, [](cpBody*){/* your C++ lambda already set */});
        });

    // rec.record_free_function(path, {
    //     "process_groups",
    //     "---@param world physics.PhysicsWorld\n---@return nil",
    //     "Runs group processing (invokes removal callbacks for groups over threshold).",
    //     true, false
    // });
    // physics_table.set_function("process_groups",
    //     [](physics::PhysicsWorld& W){ W.ProcessGroups(); });

}





inline void expose_steering_to_lua(sol::state& lua) {
    auto& rec = BindingRecorder::instance();
    const std::vector<std::string> path = {"steering"};

    rec.add_type("steering").doc =
        "Steering behaviors (seek/flee/wander/boids/path) that push forces into Chipmunk bodies.";

    rec.bind_function(lua, path, "make_steerable",
        &::Steering::MakeSteerable,
        "---@param r entt.registry& @Registry reference\n"
        "---@param e entt.entity\n"
        "---@param maxSpeed number\n"
        "---@param maxForce number\n"
        "---@param maxTurnRate number @radians/sec (default 2π)\n"
        "---@param turnMul number @turn responsiveness multiplier (default 2.0)",
        "Attach and initialize a SteerableComponent with speed/force/turn caps.");


    rec.bind_function(lua, path, "seek_point",
        sol::overload(
            [](entt::registry& r, entt::entity e, sol::table p, float decel, float weight) {
                ::Steering::SeekPoint(r, e, vec_from_lua(p), decel, weight);
            },
            [](entt::registry& r, entt::entity e, float x, float y, float decel, float weight) {
                ::Steering::SeekPoint(r, e, cpv(x,y), decel, weight);
            }
        ),
        "---@param r entt.registry&\n"
        "---@param e entt.entity\n"
        "---@param target {x:number,y:number}|(number,number)\n"
        "---@param decel number @arrival deceleration factor\n"
        "---@param weight number @blend weight",
        "Seek a world point (Chipmunk coords) with adjustable deceleration and blend weight.");

    rec.bind_function(lua, path, "flee_point",
        [](entt::registry& r, entt::entity e, sol::table threat, float panicDist, float weight){
            ::Steering::FleePoint(r, e, vec_from_lua(threat), panicDist, weight);
        },
        "---@param r entt.registry&\n"
        "---@param e entt.entity\n"
        "---@param threat {x:number,y:number}\n"
        "---@param panicDist number @only flee if within this distance\n"
        "---@param weight number @blend weight",
        "Flee from a point if within panicDist (Chipmunk coords).");

    rec.bind_function(lua, path, "wander",
        [](entt::registry& r, entt::entity e, float jitter, float radius, float distance, float weight){
            ::Steering::Wander(r, e, jitter, radius, distance, weight);
        },
        "---@param r entt.registry&\n"
        "---@param e entt.entity\n"
        "---@param jitter number @per-step target jitter\n"
        "---@param radius number @wander circle radius\n"
        "---@param distance number @circle forward distance\n"
        "---@param weight number @blend weight",
        "Classic wander on a projected circle (Chipmunk/world coordinates).");

    rec.bind_function(lua, path, "separate",
        [](entt::registry& r, entt::entity e, float separationRadius, sol::table neighbors, float weight){
            std::vector<entt::entity> ns;
            for (auto& kv : neighbors) ns.push_back(kv.second.as<entt::entity>());
            ::Steering::Separate(r, e, separationRadius, ns, weight);
        },
        "---@param r entt.registry&\n"
        "---@param e entt.entity\n"
        "---@param separationRadius number\n"
        "---@param neighbors entt.entity[] @Lua array/table of entities\n"
        "---@param weight number @blend weight",
        "Repulsive boids term; pushes away when too close.");

    rec.bind_function(lua, path, "align",
        [](entt::registry& r, entt::entity e, sol::table neighbors, float alignRadius, float weight){
            std::vector<entt::entity> ns;
            for (auto& kv : neighbors) ns.push_back(kv.second.as<entt::entity>());
            ::Steering::Align(r, e, ns, alignRadius, weight);
        },
        "---@param r entt.registry&\n"
        "---@param e entt.entity\n"
        "---@param neighbors entt.entity[] @Lua array/table of entities\n"
        "---@param alignRadius number\n"
        "---@param weight number @blend weight",
        "Boids alignment (match headings of nearby agents).");

    rec.bind_function(lua, path, "cohesion",
        [](entt::registry& r, entt::entity e, sol::table neighbors, float cohesionRadius, float weight){
            std::vector<entt::entity> ns;
            for (auto& kv : neighbors) ns.push_back(kv.second.as<entt::entity>());
            ::Steering::Cohesion(r, e, ns, cohesionRadius, weight);
        },
        "---@param r entt.registry&\n"
        "---@param e entt.entity\n"
        "---@param neighbors entt.entity[] @Lua array/table of entities\n"
        "---@param cohesionRadius number\n"
        "---@param weight number @blend weight",
        "Boids cohesion (seek the local group center).");

    rec.bind_function(lua, path, "pursuit",
        &::Steering::Pursuit,
        "---@param r entt.registry&\n"
        "---@param e entt.entity\n"
        "---@param target entt.entity @entity to predict and chase\n"
        "---@param weight number @blend weight",
        "Predict target future position and seek it (pursuit).");

    rec.bind_function(lua, path, "evade",
        &::Steering::Evade,
        "---@param r entt.registry&\n"
        "---@param e entt.entity\n"
        "---@param pursuer entt.entity @entity to predict and flee from\n"
        "---@param weight number @blend weight",
        "Predict pursuer future position and flee it (evade).");

    rec.bind_function(lua, path, "set_path",
        [](entt::registry& r, entt::entity e, sol::table points, float arriveRadius){
            ::Steering::SetPath(r, e, vecarray_from_lua(points), arriveRadius);
        },
        "---@param r entt.registry&\n"
        "---@param e entt.entity\n"
        "---@param points { {x:number,y:number}, ... } @Lua array of waypoints (Chipmunk coords)\n"
        "---@param arriveRadius number @advance when within this radius",
        "Define waypoints to follow and an arrival radius.");

    rec.bind_function(lua, path, "path_follow",
        &::Steering::PathFollow,
        "---@param r entt.registry&\n"
        "---@param e entt.entity\n"
        "---@param decel number @arrival deceleration factor\n"
        "---@param weight number @blend weight",
        "Seek current waypoint; auto-advance when within arriveRadius.");

    rec.bind_function(lua, path, "apply_force",
        &::Steering::ApplySteeringForce,
        "---@param r entt.registry&\n"
        "---@param e entt.entity\n"
        "---@param f number @force magnitude (world units)\n"
        "---@param radians number @direction in radians\n"
        "---@param seconds number @duration seconds",
        "Apply a world-space force that linearly decays to zero over <seconds>.");

    rec.bind_function(lua, path, "apply_impulse",
        &::Steering::ApplySteeringImpulse,
        "---@param r entt.registry&\n"
        "---@param e entt.entity\n"
        "---@param f number @impulse-per-second magnitude\n"
        "---@param radians number @direction in radians\n"
        "---@param seconds number @duration seconds",
        "Apply a constant per-frame impulse (f / sec) for <seconds> in world space.");
}


struct NavmeshWorldConfigPublicView {
    int default_inflate_px = 8;
};

inline void expose_physics_manager_to_lua(sol::state &lua, PhysicsManager &PM) {
    using std::string;
    auto &rec = BindingRecorder::instance();
    
    
    auto pm_ud = lua.new_usertype<PhysicsManager>(
        "PhysicsManagerUD",
        sol::no_constructor,

        "get_world", [](PhysicsManager* self, const string& name) -> std::shared_ptr<physics::PhysicsWorld> {
            if (auto* wr = self->get(name)) return wr->w;
            return {};
        },
        "has_world", [](PhysicsManager* self, const string& name) {
            return self->get(name) != nullptr;
        },
        "is_world_active", [](PhysicsManager* self, const string& name) {
            if (auto* wr = self->get(name)) return PhysicsManager::world_active(*wr);
            return false;
        },
        "add_world", [](PhysicsManager* self, const string& name,
                        std::shared_ptr<physics::PhysicsWorld> w,
                        sol::optional<string> bindsToState) {
            self->add(name, std::move(w),
                      bindsToState ? std::optional<string>(*bindsToState) : std::nullopt);
        },
        "enable_step",       [](PhysicsManager* self, const string& name, bool on){ self->enableStep(name, on); },
        "enable_debug_draw", [](PhysicsManager* self, const string& name, bool on){ self->enableDebugDraw(name, on); },

        "step_all", [](PhysicsManager* self, float dt){ self->stepAll(dt); },
        "draw_all", [](PhysicsManager* self){ self->drawAll(); },

        "move_entity_to_world", [](PhysicsManager* self, entt::entity e, const string& dst){
            self->moveEntityToWorld(e, dst);
        },

        "get_nav_config", [&lua](PhysicsManager* self, const string& world) {
            sol::table t = lua.create_table();
            if (auto* nav = self->nav_of(world)) {
                t["default_inflate_px"] = nav->config.default_inflate_px;
            } else {
                t["default_inflate_px"] = 8;
            }
            return t;
        },
        "set_nav_config", [](PhysicsManager* self, const string& world, sol::table cfg){
            if (auto* nav = self->nav_of(world)) {
                if (auto v = cfg.get<sol::optional<int>>("default_inflate_px")) {
                    nav->config.default_inflate_px = *v;
                    nav->dirty = true;
                }
            }
        },
        "mark_navmesh_dirty", [](PhysicsManager* self, const string& world){ self->markNavmeshDirty(world); },
        "rebuild_navmesh",    [](PhysicsManager* self, const string& world){ self->rebuildNavmeshFor(world); },

        "find_path", [&lua](PhysicsManager* self, const string& world, float sx, float sy, float dx, float dy) {
            NavMesh::Point s{(int)sx, (int)sy};
            NavMesh::Point d{(int)dx, (int)dy};
            auto pts = self->findPath(world, s, d);
            sol::table out = lua.create_table(static_cast<int>(pts.size()), 0);
            int i = 1;
            for (const auto &p : pts) {
                sol::table tp = lua.create_table();
                tp["x"] = p.x; tp["y"] = p.y;
                out[i++] = tp;
            }
            return out;
        },
        "vision_fan", [&lua](PhysicsManager* self, const string& world, float sx, float sy, float radius) {
            NavMesh::Point s{(int)sx, (int)sy};
            auto fan = self->visionFan(world, s, radius);
            sol::table out = lua.create_table(static_cast<int>(fan.size()), 0);
            int i = 1;
            for (const auto &p : fan) {
                sol::table tp = lua.create_table();
                tp["x"] = (int)p.x; tp["y"] = (int)p.y;
                out[i++] = tp;
            }
            return out;
        },

        "set_nav_obstacle", [](PhysicsManager* self, entt::entity e, bool include){
            auto &R = self->R;
            if (auto comp = R.try_get<NavmeshObstacle>(e)) {
                comp->include = include;
            } else {
                R.emplace<NavmeshObstacle>(e, include);
            }
            if (auto wr = R.try_get<PhysicsWorldRef>(e)) {
                self->markNavmeshDirty(wr->name);
            }
        }
    );

    rec.add_type("PhysicsManagerUD").doc =
        "Actual userdata type for the PhysicsManager class. "
        "Use the global `physics_manager` to access the live instance.\n"
        "Methods mirror the helpers on the `PhysicsManager` table.";

    rec.record_property("PhysicsManagerUD",
        {"get_world", "", "---@param name string\n---@return PhysicsWorld|nil"});
    rec.record_property("PhysicsManagerUD",
        {"has_world", "", "---@param name string\n---@return boolean"});
    rec.record_property("PhysicsManagerUD",
        {"is_world_active", "", "---@param name string\n---@return boolean"});
    rec.record_property("PhysicsManagerUD",
        {"add_world", "", "---@param name string\n---@param world PhysicsWorld\n---@param bindsToState string|nil"});
    rec.record_property("PhysicsManagerUD",
        {"enable_step", "", "---@param name string\n---@param on boolean"});
    rec.record_property("PhysicsManagerUD",
        {"enable_debug_draw", "", "---@param name string\n---@param on boolean"});
    rec.record_property("PhysicsManagerUD",
        {"step_all", "", "---@param dt number"});
    rec.record_property("PhysicsManagerUD",
        {"draw_all", "", ""});
    rec.record_property("PhysicsManagerUD",
        {"move_entity_to_world", "", "---@param e entt.entity\n---@param dst string"});
    rec.record_property("PhysicsManagerUD",
        {"get_nav_config", "", "---@param world string\n---@return table { default_inflate_px: integer }"});
    rec.record_property("PhysicsManagerUD",
        {"set_nav_config", "", "---@param world string\n---@param cfg table { default_inflate_px: integer|nil }"});
    rec.record_property("PhysicsManagerUD",
        {"mark_navmesh_dirty", "", "---@param world string"});
    rec.record_property("PhysicsManagerUD",
        {"rebuild_navmesh", "", "---@param world string"});
    rec.record_property("PhysicsManagerUD",
        {"find_path", "", "---@param world string\n---@param sx number\n---@param sy number\n---@param dx number\n---@param dy number\n---@return table<number,{x:integer,y:integer}>"});
    rec.record_property("PhysicsManagerUD",
        {"vision_fan", "", "---@param world string\n---@param sx number\n---@param sy number\n---@param radius number\n---@return table<number,{x:integer,y:integer}>"});
    rec.record_property("PhysicsManagerUD",
        {"set_nav_obstacle", "", "---@param e entt.entity\n---@param include boolean"});


    sol::table pm = lua["PhysicsManager"].get_or_create<sol::table>();
    rec.add_type("PhysicsManager").doc =
        "Physics manager utilities: manage physics worlds, debug toggles, "
        "navmesh (pathfinding / vision), and safe world migration for entities.";

    pm.set_function("get_world",
        [&PM](const string &name) -> std::shared_ptr<physics::PhysicsWorld> {
            if (auto *wr = PM.get(name)) return wr->w;
            return {};
        });
    rec.record_free_function(
        {"PhysicsManager"},
        {
            "get_world",
            "---@param name string\n---@return PhysicsWorld|nil",
            "Return the PhysicsWorld registered under name, or nil if missing.",
            true, false
        });

    pm.set_function("has_world",
        [&PM](const string &name) {
            return PM.get(name) != nullptr;
        });
    rec.record_free_function(
        {"PhysicsManager"},
        {
            "has_world",
            "---@param name string\n---@return boolean",
            "True if a world with this name exists.",
            true, false
        });

    pm.set_function("is_world_active",
        [&PM](const string &name) {
            if (auto *wr = PM.get(name)) return PhysicsManager::world_active(*wr);
            return false;
        });
    rec.record_free_function(
        {"PhysicsManager"},
        {
            "is_world_active",
            "---@param name string\n---@return boolean",
            "True if the world's step toggle is on and its bound game-state (if any) is active.",
            true, false
        });

    pm.set_function("add_world",
        [&PM](const string &name,
              std::shared_ptr<physics::PhysicsWorld> w,
              sol::optional<string> bindsToState) {
            PM.add(name, std::move(w),
                   bindsToState ? std::optional<string>(*bindsToState) : std::nullopt);
        });
    rec.record_free_function(
        {"PhysicsManager"},
        {
            "add_world",
            "---@param name string\n---@param world PhysicsWorld\n---@param bindsToState string|nil\n---@return void",
            "Register a PhysicsWorld under a name. Optionally bind to a game-state string.",
            true, false
        });

    pm.set_function("enable_step",
        [&PM](const string &name, bool on){ PM.enableStep(name, on); });
    rec.record_free_function(
        {"PhysicsManager"},
        {
            "enable_step",
            "---@param name string\n---@param on boolean\n---@return void",
            "Enable or disable stepping for a world.",
            true, false
        });

    pm.set_function("enable_debug_draw",
        [&PM](const string &name, bool on){ PM.enableDebugDraw(name, on); });
    rec.record_free_function(
        {"PhysicsManager"},
        {
            "enable_debug_draw",
            "---@param name string\n---@param on boolean\n---@return void",
            "Enable or disable debug draw for a world.",
            true, false
        });

    pm.set_function("step_all", [&PM](float dt){ PM.stepAll(dt); });
    rec.record_free_function(
        {"PhysicsManager"},
        {
            "step_all",
            "---@param dt number\n---@return void",
            "Step all active worlds (honors per-world toggle and game-state binding).",
            true, false
        });

    pm.set_function("draw_all", [&PM](){ PM.drawAll(); });
    rec.record_free_function(
        {"PhysicsManager"},
        {
            "draw_all",
            "---@return void",
            "Debug-draw all worlds that are active and have debug draw enabled.",
            true, false
        });

    pm.set_function("move_entity_to_world",
        [&PM](entt::entity e, const string &dst){ PM.moveEntityToWorld(e, dst); });
    rec.record_free_function(
        {"PhysicsManager"},
        {
            "move_entity_to_world",
            "---@param e entt.entity\n---@param dst string\n---@return void",
            "Move an entity's body/shape to another registered world (safe migration).",
            true, false
        });

    pm.set_function("get_nav_config",
        [&lua, &PM](const string &world){
            sol::table t = lua.create_table();
            if (auto *nav = PM.nav_of(world)) {
                t["default_inflate_px"] = nav->config.default_inflate_px;
            } else {
                t["default_inflate_px"] = 8;
            }
            return t;
        });
    rec.record_free_function(
        {"PhysicsManager"},
        {
            "get_nav_config",
            "---@param world string\n---@return table { default_inflate_px: integer }",
            "Return the navmesh config table for a world.",
            true, false
        });

    pm.set_function("set_nav_config",
        [&PM](const string &world, sol::table cfg){
            if (auto *nav = PM.nav_of(world)) {
                if (auto v = cfg.get<sol::optional<int>>("default_inflate_px")) {
                    nav->config.default_inflate_px = *v;
                    nav->dirty = true;
                }
            }
        });
    rec.record_free_function(
        {"PhysicsManager"},
        {
            "set_nav_config",
            "---@param world string\n---@param cfg table { default_inflate_px: integer|nil }\n---@return void",
            "Patch navmesh config for a world; marks the navmesh dirty.",
            true, false
        });

    pm.set_function("mark_navmesh_dirty",
        [&PM](const string &world){ PM.markNavmeshDirty(world); });
    rec.record_free_function(
        {"PhysicsManager"},
        {
            "mark_navmesh_dirty",
            "---@param world string\n---@return void",
            "Mark a world's navmesh dirty (will rebuild on next query or when forced).",
            true, false
        });

    pm.set_function("rebuild_navmesh",
        [&PM](const string &world){ PM.rebuildNavmeshFor(world); });
    rec.record_free_function(
        {"PhysicsManager"},
        {
            "rebuild_navmesh",
            "---@param world string\n---@return void",
            "Force an immediate navmesh rebuild for a world.",
            true, false
        });

    pm.set_function("find_path",
        [&lua, &PM](const string &world, float sx, float sy, float dx, float dy) {
            NavMesh::Point s{(int)sx, (int)sy};
            NavMesh::Point d{(int)dx, (int)dy};
            auto pts = PM.findPath(world, s, d);

            sol::table out = lua.create_table(static_cast<int>(pts.size()), 0);
            int i = 1;
            for (const auto &p : pts) {
                sol::table tp = lua.create_table();
                tp["x"] = p.x;
                tp["y"] = p.y;
                out[i++] = tp;
            }
            return out;
        });
    rec.record_free_function(
        {"PhysicsManager"},
        {
            "find_path",
            "---@param world string\n---@param sx number\n---@param sy number\n---@param dx number\n---@param dy number\n---@return table<number,{x:integer,y:integer}>",
            "Find a path on the world's navmesh. Returns an array of {x,y} points.",
            true, false
        });

    pm.set_function("vision_fan",
        [&lua, &PM](const string &world, float sx, float sy, float radius) {
            NavMesh::Point s{(int)sx, (int)sy};
            auto fan = PM.visionFan(world, s, radius);

            sol::table out = lua.create_table(static_cast<int>(fan.size()), 0);
            int i = 1;
            for (const auto &p : fan) {
                sol::table tp = lua.create_table();
                tp["x"] = p.x;
                tp["y"] = p.y;
                out[i++] = tp;
            }
            return out;
        });
    rec.record_free_function(
        {"PhysicsManager"},
        {
            "vision_fan",
            "---@param world string\n---@param sx number\n---@param sy number\n---@param radius number\n---@return table<number,{x:integer,y:integer}>",
            "Compute a visibility polygon (fan) from a point and radius against world obstacles.",
            true, false
        });

    pm.set_function("set_nav_obstacle",
        [&PM](entt::entity e, bool include){
            auto &R = PM.R;
            if (auto comp = R.try_get<NavmeshObstacle>(e)) {
                comp->include = include;
            } else {
                R.emplace<NavmeshObstacle>(e, include);
            }
            if (auto wr = R.try_get<PhysicsWorldRef>(e)) {
                PM.markNavmeshDirty(wr->name);
            }
        });
    rec.record_free_function(
        {"PhysicsManager"},
        {
            "set_nav_obstacle",
            "---@param e entt.entity\n---@param include boolean\n---@return void",
            "Tag/untag an entity as a navmesh obstacle and mark its world's navmesh dirty.",
            true, false
        });
        
    lua["physics_manager_instance"] = &PM;

        rec.record_free_function(
            {"physics_manager"},
            {
                "instance",
                "---@type PhysicsManagerUD",
                "The live PhysicsManager instance (userdata). Methods mirror the PhysicsManager table.",
                true, true
            });
    }

}