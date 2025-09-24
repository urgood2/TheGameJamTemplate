#pragma once

#include "physics_manager.hpp"
#include "physics_world.hpp"
#include "systems/physics/transform_physics_hook.hpp"
#include <sol.hpp>

#include "steering.hpp"

namespace physics {


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
    t["x"] = v.x; t["y"] = v.y;
    return t;
}

inline void expose_physics_to_lua(sol::state& lua) {
    auto& rec = BindingRecorder::instance();
    const std::vector<std::string> path = {"physics"};

    rec.add_type("physics").doc =
        "Physics namespace (Chipmunk2D). Create worlds, set tags/masks, raycast, "
        "query areas, and attach colliders to entities.";

    struct LuaRaycastHit {
        void* shape{};
        cpVect point{0,0};
        cpVect normal{0,0};
        float fraction{0.f};
    };
    lua.new_usertype<LuaRaycastHit>("RaycastHit",
        "shape",    &LuaRaycastHit::shape,
        "point",    sol::property(
                        [](sol::this_state s, LuaRaycastHit& h){ return vec_to_lua(sol::state_view(s), h.point); }),
        "normal",   sol::property(
                        [](sol::this_state s, LuaRaycastHit& h){ return vec_to_lua(sol::state_view(s), h.normal); }),
        "fraction", &LuaRaycastHit::fraction
    );
    auto& rch = rec.add_type("physics.RaycastHit");
    rch.doc = "Result of a raycast: shape pointer, hit point, normal, and fraction along the ray.";
    
    struct LuaCollisionEvent {
        void* objectA{};
        void* objectB{};
        float x1{}, y1{}, x2{}, y2{}, nx{}, ny{};
    };

    lua.new_usertype<LuaCollisionEvent>("CollisionEvent",
        "objectA", &LuaCollisionEvent::objectA,
        "objectB", &LuaCollisionEvent::objectB,
        "x1", &LuaCollisionEvent::x1, "y1", &LuaCollisionEvent::y1,
        "x2", &LuaCollisionEvent::x2, "y2", &LuaCollisionEvent::y2,
        "nx", &LuaCollisionEvent::nx, "ny", &LuaCollisionEvent::ny
    );
    rec.add_type("physics.CollisionEvent").doc =
        "Collision event: endpoints (x1,y1)-(x2,y2), normal (nx,ny), and the two objects.";

    static auto to_entity = [](void* p) -> entt::entity {
        return static_cast<entt::entity>(reinterpret_cast<uintptr_t>(p));
    };

rec.bind_function(lua, path, "GetCollisionEnter",
    [&lua](physics::PhysicsWorld& W, const std::string& t1, const std::string& t2) {
        const auto& v = W.GetCollisionEnter(t1, t2);
        sol::table out = lua.create_table(static_cast<int>(v.size()), 0);
        int i = 1;
        for (const auto& e : v) {
            const entt::entity a = to_entity(e.objectA);
            const entt::entity b = to_entity(e.objectB);

            sol::table ev = lua.create_table();
            ev["a"]  = a;
            ev["b"]  = b;
            ev["x1"] = e.x1; ev["y1"] = e.y1;
            ev["x2"] = e.x2; ev["y2"] = e.y2;
            ev["nx"] = e.nx; ev["ny"] = e.ny;

            out[i++] = ev;
        }
        return out;
    },
    "---@param world physics.PhysicsWorld\n"
    "---@param type1 string\n"
    "---@param type2 string\n"
    "---@return {a:entt.entity,b:entt.entity,x1:number,y1:number,x2:number,y2:number,nx:number,ny:number}[]",
    "Buffered collision-begin events for (type1,type2) since last PostUpdate(). "
    "Returns a list of event tables with 'a' and 'b' as entt.entity handles."
);

rec.bind_function(lua, path, "GetTriggerEnter",
    [](physics::PhysicsWorld& W, const std::string& t1, const std::string& t2) {
        const auto& v = W.GetTriggerEnter(t1, t2);
        std::vector<entt::entity> out;
        out.reserve(v.size());
        for (void* u : v) {
            out.push_back(to_entity(u));
        }
        return sol::as_table(out);
    },
    "---@param world physics.PhysicsWorld\n"
    "---@param type1 string\n"
    "---@param type2 string\n"
    "---@return entt.entity[]",
    "Buffered trigger-begin hits for (type1,type2) since last PostUpdate(). "
    "Returns entities (entt.entity) rather than opaque pointers."
);

    
rec.bind_function(lua, path, "GetEntityFromBody",
    &physics::GetEntityFromBody,
    "---@param body lightuserdata @cpBody*\n---@return entt.entity"
);

rec.bind_function(lua, path, "entity_from_ptr",
    [](void* p) -> entt::entity {
        return static_cast<entt::entity>(reinterpret_cast<uintptr_t>(p));
    },
    "---@param p lightuserdata\n---@return entt.entity"
);

    

    using physics::PhysicsWorld;

    lua.new_usertype<PhysicsWorld>("PhysicsWorld",
        sol::constructors<PhysicsWorld(entt::registry*, float, float, float)>(),
        "Update",            &PhysicsWorld::Update,
        "PostUpdate",        &PhysicsWorld::PostUpdate,
        "SetGravity",        &PhysicsWorld::SetGravity,
        "SetMeter",          &PhysicsWorld::SetMeter,
        "SetCollisionCallbacks", &PhysicsWorld::SetCollisionCallbacks,
        "SetCollisionTags",      &PhysicsWorld::SetCollisionTags,
        "EnableCollisionBetween",&PhysicsWorld::EnableCollisionBetween,
        "DisableCollisionBetween",&PhysicsWorld::DisableCollisionBetween,
        "EnableTriggerBetween",  &PhysicsWorld::EnableTriggerBetween,
        "DisableTriggerBetween", &PhysicsWorld::DisableTriggerBetween,
        "UpdateCollisionMasks",  &PhysicsWorld::UpdateCollisionMasks,
        "AddCollisionTag",       &PhysicsWorld::AddCollisionTag,
        "RemoveCollisionTag",    &PhysicsWorld::RemoveCollisionTag,
        "UpdateColliderTag",     &PhysicsWorld::UpdateColliderTag,
        "PrintCollisionTags",    &PhysicsWorld::PrintCollisionTags,
        "GetCollisionEnter",     &PhysicsWorld::GetCollisionEnter,
        "GetTriggerEnter",       &PhysicsWorld::GetTriggerEnter,
        "RenderColliders",       &PhysicsWorld::RenderColliders
    );

    auto& pw = rec.add_type("physics.PhysicsWorld");
    pw.doc = "Owns Chipmunk space, tags/masks, and collision/trigger buffers. Step with Update(dt).";
    
rec.bind_function(lua, path, "SetAngularDamping",
    &physics::PhysicsWorld::SetAngularDamping,
    "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param angularDamping number"
);

rec.bind_function(lua, path, "ApplyAngularImpulse",
    &physics::PhysicsWorld::ApplyAngularImpulse,
    "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param angularImpulse number"
);

rec.bind_function(lua, path, "ApplyTorque",
    &physics::PhysicsWorld::ApplyTorque,
    "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param torque number"
);

rec.bind_function(lua, path, "SetBullet",
    &physics::PhysicsWorld::SetBullet,
    "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param isBullet boolean"
);

rec.bind_function(lua, path, "GetPosition",
    [](physics::PhysicsWorld& W, entt::entity e, sol::this_state s) {
        auto p = W.GetPosition(e);
        return vec_to_lua(sol::state_view{s}, p);
    },
    "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@return {x:number,y:number}"
);

rec.bind_function(lua, path, "SetPosition",
    &physics::PhysicsWorld::SetPosition,
    "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param x number\n---@param y number"
);

rec.bind_function(lua, path, "GetAngle",
    &physics::PhysicsWorld::GetAngle,
    "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@return number @radians"
);

rec.bind_function(lua, path, "SetAngle",
    &physics::PhysicsWorld::SetAngle,
    "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param radians number"
);

rec.bind_function(lua, path, "SetVelocity",
    &physics::PhysicsWorld::SetVelocity,
    "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param vx number\n---@param vy number"
);

rec.bind_function(lua, path, "SetAngularVelocity",
    &physics::PhysicsWorld::SetAngularVelocity,
    "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param av number @radians/sec"
);

rec.bind_function(lua, path, "ApplyForce",
    &physics::PhysicsWorld::ApplyForce,
    "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param fx number\n---@param fy number"
);

rec.bind_function(lua, path, "ApplyImpulse",
    &physics::PhysicsWorld::ApplyImpulse,
    "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param ix number\n---@param iy number"
);

rec.bind_function(lua, path, "SetDamping",
    &physics::PhysicsWorld::SetDamping,
    "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param linear number"
);

rec.bind_function(lua, path, "SetGlobalDamping",
    &physics::PhysicsWorld::SetGlobalDamping,
    "---@param world physics.PhysicsWorld\n---@param damping number"
);

rec.bind_function(lua, path, "SetRestitution",
    &physics::PhysicsWorld::SetRestitution,
    "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param restitution number"
);

rec.bind_function(lua, path, "SetFriction",
    &physics::PhysicsWorld::SetFriction,
    "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param friction number"
);

rec.bind_function(lua, path, "SetAwake",
    &physics::PhysicsWorld::SetAwake,
    "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param awake boolean"
);

rec.bind_function(lua, path, "SetFixedRotation",
    &physics::PhysicsWorld::SetFixedRotation,
    "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param fixed boolean"
);

rec.bind_function(lua, path, "GetMass",
    &physics::PhysicsWorld::GetMass,
    "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@return number"
);

rec.bind_function(lua, path, "SetMass",
    &physics::PhysicsWorld::SetMass,
    "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param mass number"
);


    rec.bind_function(lua, path, "Raycast",
        [](PhysicsWorld& W, float x1, float y1, float x2, float y2, sol::this_state s) {
            auto hits = W.Raycast(x1, y1, x2, y2);
            sol::state_view L(s);
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
        },
        "---@param world physics.PhysicsWorld\n"
        "---@param x1 number @ray start X (Chipmunk units)\n"
        "---@param y1 number @ray start Y (Chipmunk units)\n"
        "---@param x2 number @ray end X (Chipmunk units)\n"
        "---@param y2 number @ray end Y (Chipmunk units)\n"
        "---@return physics.RaycastHit[] # Array of hits, nearest-first.",
        "Segment raycast through the physics space (Chipmunk2D).");

    rec.bind_function(lua, path, "GetObjectsInArea",
    [](physics::PhysicsWorld& W, float x1, float y1, float x2, float y2) {
        auto raw = W.GetObjectsInArea(x1, y1, x2, y2);
        std::vector<entt::entity> out;
        out.reserve(raw.size());
        for (void* p : raw) {
            entt::entity e = p
                ? static_cast<entt::entity>(reinterpret_cast<uintptr_t>(p))
                : entt::null;
            out.push_back(e);
        }
        return sol::as_table(out);
    },
    "---@param world physics.PhysicsWorld\n"
    "---@param x1 number @rect min X (Chipmunk units)\n"
    "---@param y1 number @rect min Y (Chipmunk units)\n"
    "---@param x2 number @rect max X (Chipmunk units)\n"
    "---@param y2 number @rect max Y (Chipmunk units)\n"
    "---@return entt.entity[] @entities whose shapes intersect the AABB",
    "Returns entity handles for all shapes intersecting the rectangle [x1,y1]-[x2,y2]."
);


    rec.bind_function(lua, path, "AddCollider",
        [](PhysicsWorld& W, entt::entity e, const std::string& tag,
           const std::string& shapeType,
           sol::object a, sol::object b, sol::object c, sol::object d,
           bool isSensor, sol::object pointsOpt) {
            float A = a.is<double>() ? a.as<double>() : 0.0;
            float B = b.is<double>() ? b.as<double>() : 0.0;
            float C = c.is<double>() ? c.as<double>() : 0.0;
            float D = d.is<double>() ? d.as<double>() : 0.0;

            std::vector<cpVect> points;
            if (pointsOpt.is<sol::table>()) {
                points = vecarray_from_lua(pointsOpt.as<sol::table>());
            }
            W.AddCollider(e, tag, shapeType, A, B, C, D, isSensor, points);
        },
        "---@param world physics.PhysicsWorld\n"
        "---@param e entt.entity\n"
        "---@param tag string @Collision tag/category name\n"
        "---@param shapeType 'rectangle'|'circle'|'segment'|'polygon'|'chain'\n"
        "---@param a number @rectangle: width | circle: radius | segment: x1 | polygon/chain: ignored if points given\n"
        "---@param b number @rectangle: height | circle: ignored | segment: y1 | polygon/chain: ignored if points given\n"
        "---@param c number @segment: x2 | others: shape-specific/ignored\n"
        "---@param d number @segment: y2 | others: shape-specific/ignored\n"
        "---@param isSensor boolean @sensor shapes don’t collide but still trigger\n"
        "---@param points { {x:number,y:number} }? @optional explicit vertices for polygon/chain (overrides a–d)\n"
        "---@return nil",
        "Creates a cpBody+cpShape, applies tag filter (default masks = 'all' if none set), "
        "and emplaces a ColliderComponent. For polygon/chain, provide explicit vertices via `points`.");

    rec.bind_function(lua, path, "SetEntityToShape",
        &physics::SetEntityToShape,
        "---@param shape lightuserdata @cpShape*\n"
        "---@param e entt.entity",
        "Stores an entity ID into shape->userData.");
    rec.bind_function(lua, path, "SetEntityToBody",
        &physics::SetEntityToBody,
        "---@param body lightuserdata @cpBody*\n"
        "---@param e entt.entity",
        "Stores an entity ID into body->userData.");
        
    
    lua["physics"]["ColliderShapeType"] = lua.create_table_with(
        "Rectangle", static_cast<int>(physics::ColliderShapeType::Rectangle),
        "Segment",   static_cast<int>(physics::ColliderShapeType::Segment),
        "Circle",    static_cast<int>(physics::ColliderShapeType::Circle),
        "Polygon",   static_cast<int>(physics::ColliderShapeType::Polygon),
        "Chain",     static_cast<int>(physics::ColliderShapeType::Chain)
    );
    {
        auto& t = rec.add_type("physics.ColliderShapeType");
        t.doc   = "Collider shape enum; use string names for config too.";
    }

    rec.bind_function(lua, path, "create_physics_for_transform",
        [](entt::registry& R,
        PhysicsManager& PM,
        entt::entity e,
        sol::table cfg)
        {
            auto get_string = [&](const char* k, const char* def)->std::string {
                if (auto v = cfg[k]; v.valid() && v.get_type() == sol::type::string) return v.get<std::string>();
                return def;
            };
            auto get_bool = [&](const char* k, bool def)->bool {
                if (auto v = cfg[k]; v.valid() && v.get_type() == sol::type::boolean) return v.get<bool>();
                return def;
            };
            auto get_num = [&](const char* k, float def)->float {
                if (auto v = cfg[k]; v.valid() && (v.get_type() == sol::type::number)) return v.get<float>();
                return def;
            };

            auto shapeStr = get_string("shape", "rectangle");
            physics::ColliderShapeType shape = physics::ColliderShapeType::Rectangle;
            if      (shapeStr == "rectangle" || shapeStr == "Rectangle") shape = physics::ColliderShapeType::Rectangle;
            else if (shapeStr == "circle"    || shapeStr == "Circle")    shape = physics::ColliderShapeType::Circle;
            else if (shapeStr == "segment"   || shapeStr == "Segment")   shape = physics::ColliderShapeType::Segment;
            else if (shapeStr == "polygon"   || shapeStr == "Polygon")   shape = physics::ColliderShapeType::Polygon;
            else if (shapeStr == "chain"     || shapeStr == "Chain")     shape = physics::ColliderShapeType::Chain;

            physics::PhysicsCreateInfo ci;
            ci.shape   = shape;
            ci.tag     = get_string("tag", physics::DEFAULT_COLLISION_TAG.c_str());
            ci.sensor  = get_bool("sensor", false);
            ci.density = get_num("density", 1.0f);

            physics::CreatePhysicsForTransform(R, PM, e, ci);
        },
        "---@param r entt.registry& @Registry reference\n"
        "---@param pm PhysicsManager& @Physics manager\n"
        "---@param e entt.entity\n"
        "---@param config table @{ shape?:'rectangle'|'circle'|'segment'|'polygon'|'chain', tag?:string, sensor?:boolean, density?:number }\n"
        "---@return nil",
        "Create a Chipmunk body+shape for entity based on its Transform.ACTUAL size/rotation, "
        "attach ColliderComponent, tag+filter it, and add to its referenced PhysicsWorld."
    );
    
    rec.bind_function(lua, path, "create_physics_for_transform",
    [](entt::registry& R,
       PhysicsManager& PM,
       entt::entity e,
       const std::string& world,
       sol::table cfg)
    {
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

        auto shapeStr = get_string("shape", "rectangle");
        physics::ColliderShapeType shape = physics::ColliderShapeType::Rectangle;
        if      (shapeStr == "rectangle" || shapeStr == "Rectangle") shape = physics::ColliderShapeType::Rectangle;
        else if (shapeStr == "circle"    || shapeStr == "Circle")    shape = physics::ColliderShapeType::Circle;
        else if (shapeStr == "segment"   || shapeStr == "Segment")   shape = physics::ColliderShapeType::Segment;
        else if (shapeStr == "polygon"   || shapeStr == "Polygon")   shape = physics::ColliderShapeType::Polygon;
        else if (shapeStr == "chain"     || shapeStr == "Chain")     shape = physics::ColliderShapeType::Chain;

        physics::PhysicsCreateInfo ci;
        ci.shape   = shape;
        ci.tag     = get_string("tag", DEFAULT_COLLISION_TAG.c_str());
        ci.sensor  = get_bool("sensor", false);
        ci.density = get_num("density", 1.0f);

        const float inflate_px = get_num("inflate_px", 0.0f);

        const bool set_ref = get_bool("set_world_ref", true);

        physics::CreatePhysicsForTransform(R, PM, e, ci, world, inflate_px, set_ref);
    },
    "---@param R entt.registry\n"
    "---@param pm PhysicsManagerUD|PhysicsManager @manager\n"
    "---@param e entt.entity\n"
    "---@param world string @name of physics world\n"
    "---@param cfg table\n"
    "---@field cfg.shape 'rectangle'|'circle'|'segment'|'polygon'|'chain'|nil\n"
    "---@field cfg.tag string|nil @Collision tag\n"
    "---@field cfg.sensor boolean|nil\n"
    "---@field cfg.density number|nil @reserved\n"
    "---@field cfg.inflate_px number|nil @signed pixels; positive expands, negative shrinks\n"
    "---@field cfg.set_world_ref boolean|nil @default true\n"
    "---@return void",
    "Create physics for an entity in the given world, with optional signed inflate."
);

// Get main body from ColliderComponent, add an extra rectangle shape on it.
rec.bind_function(lua, {"physics"}, "add_shape_to_entity",
    [](physics::PhysicsWorld& W, entt::entity e, float w, float h, const std::string& tag, bool sensor){
        auto& col = W.registry->get<ColliderComponent>(e);
        auto shp = W.AddShape(col.body.get(), w, h, tag); // applies filter & adds to space
        cpShapeSetSensor(shp.get(), sensor);
        // Optionally store extra shapes somewhere if you track them explicitly.
    },
    "---@param world physics.PhysicsWorld\n---@param e entt.entity\n---@param w number\n---@param h number\n---@param tag string\n---@param sensor boolean");
    
    // Make a free body (dynamic/kinematic/static) not tied to an entity
    rec.bind_function(lua, {"physics"}, "body_create",
        [&] (physics::PhysicsWorld& W, const std::string& type, double mass, double moment){
            std::shared_ptr<cpBody> b;
            if (type == "dynamic")   b = MakeSharedBody((cpFloat)mass, (cpFloat)moment);
            else if (type == "kinematic") b = std::shared_ptr<cpBody>(cpBodyNewKinematic(), cpBodyFree);
            else /*static*/              b = std::shared_ptr<cpBody>(cpBodyNewStatic(), cpBodyFree);
            cpSpaceAddBody(W.space, b.get());
            return W.registerBody(std::move(b));
        },
        "---@param world physics.PhysicsWorld\n---@param type 'dynamic'|'kinematic'|'static'\n---@param mass number\n---@param moment number\n---@return integer @body_handle");

    // Destroy
    rec.bind_function(lua, {"physics"}, "body_destroy",
        [&] (physics::PhysicsWorld& W, uint64_t id){
            if (auto b = W.bodyFrom(id)) { cpSpaceRemoveBody(W.space, b.get()); W.unregisterBody(id); }
        },
        "---@param world physics.PhysicsWorld\n---@param body_handle integer");

    // Mutators
    rec.bind_function(lua, {"physics"}, "body_set_position",
        [&] (physics::PhysicsWorld& W, uint64_t id, double x, double y){
            if (auto b = W.bodyFrom(id)) cpBodySetPosition(b.get(), cpv((cpFloat)x,(cpFloat)y));
        },
        "---@return void");

    rec.bind_function(lua, {"physics"}, "body_apply_force",
        [&] (physics::PhysicsWorld& W, uint64_t id, double fx, double fy){
            if (auto b = W.bodyFrom(id)) cpBodyApplyForceAtWorldPoint(b.get(), cpv(fx,fy), cpBodyGetPosition(b.get()));
        },
        "");

    rec.bind_function(lua, {"physics"}, "body_get_entity",
        [] (uint64_t /*world ignored in helper?*/, void* bodyPtr){
            return GetEntityFromBody(static_cast<cpBody*>(bodyPtr));
        },
        "---@param body lightuserdata @cpBody*\n---@return entt.entity|entt.null");
        
    rec.bind_function(lua, {"physics"}, "get_body_handle_for_entity",
    [&] (physics::PhysicsWorld& W, entt::entity e){
        auto& col = W.registry->get<ColliderComponent>(e);
        return W.registerBody(col.body); // shares ownership
    },
    "---@return integer @body_handle");
    
    // number
    rec.bind_function(lua, {"physics"}, "arb_set_number",
        [](physics::PhysicsWorld& world, void* arbPtr, const std::string& key, double val){
            auto* s = world.ensure_store(static_cast<cpArbiter*>(arbPtr));
            s->nums[key] = val;
        },
        "---@param world physics.PhysicsWorld\n---@param arb lightuserdata @cpArbiter*\n---@param key string\n---@param value number");

    rec.bind_function(lua, {"physics"}, "arb_get_number",
        [](physics::PhysicsWorld& world, void* arbPtr, const std::string& key, sol::optional<double> def){
            if (auto* s = static_cast<physics::PhysicsWorld::ArbiterStore*>(cpArbiterGetUserData(static_cast<cpArbiter*>(arbPtr)))) {
                if (auto it = s->nums.find(key); it != s->nums.end()) return it->second;
            }
            return def.value_or(0.0);
        },
        "---@param world physics.PhysicsWorld\n---@param arb lightuserdata @cpArbiter*\n---@param key string\n---@param default number|nil\n---@return number");

    // bool
    rec.bind_function(lua, {"physics"}, "arb_set_bool",
        [](physics::PhysicsWorld& world, void* arbPtr, const std::string& key, bool v){
            auto* s = world.ensure_store(static_cast<cpArbiter*>(arbPtr));
            s->bools[key] = v;
        },
        "---@param world physics.PhysicsWorld\n---@param arb lightuserdata @cpArbiter*\n---@param key string\n---@param value boolean");

    rec.bind_function(lua, {"physics"}, "arb_get_bool",
        [](physics::PhysicsWorld& world, void* arbPtr, const std::string& key, sol::optional<bool> def){
            if (auto* s = static_cast<physics::PhysicsWorld::ArbiterStore*>(cpArbiterGetUserData(static_cast<cpArbiter*>(arbPtr)))) {
                if (auto it = s->bools.find(key); it != s->bools.end()) return it->second;
            }
            return def.value_or(false);
        },
        "---@param world physics.PhysicsWorld\n---@param arb lightuserdata @cpArbiter*\n---@param key string\n---@param default boolean|nil\n---@return boolean");

    // ptr (lightuserdata / entity ids)
    rec.bind_function(lua, {"physics"}, "arb_set_ptr",
        [](physics::PhysicsWorld& world, void* arbPtr, const std::string& key, void* p){
            auto* s = world.ensure_store(static_cast<cpArbiter*>(arbPtr));
            s->ptrs[key] = (uintptr_t)p;
        },
        "---@param world physics.PhysicsWorld\n---@param arb lightuserdata @cpArbiter*\n---@param key string\n---@param value lightuserdata");

    rec.bind_function(lua, {"physics"}, "arb_get_ptr",
        [](physics::PhysicsWorld& world, void* arbPtr, const std::string& key){
            void* out = nullptr;
            if (auto* s = static_cast<physics::PhysicsWorld::ArbiterStore*>(cpArbiterGetUserData(static_cast<cpArbiter*>(arbPtr)))) {
                if (auto it = s->ptrs.find(key); it != s->ptrs.end()) out = (void*)it->second;
            }
            return out;
        },
        "---@param world physics.PhysicsWorld\n---@param arb lightuserdata @cpArbiter*\n---@param key string\n---@return lightuserdata|nil");

        // Registration API
        auto t = lua["physics"].get_or_create<sol::table>();
    t.set_function("on_pair_presolve",
        [](PhysicsWorld &W, const std::string& a, const std::string& b, sol::protected_function fn){
            W.RegisterPairPreSolve(a,b,std::move(fn));
        });
    t.set_function("on_pair_postsolve",
        [](PhysicsWorld &W, const std::string& a, const std::string& b, sol::protected_function fn){
            W.RegisterPairPostSolve(a,b,std::move(fn));
        });

    t.set_function("on_wildcard_presolve",
        [](PhysicsWorld &W, const std::string& tag, sol::protected_function fn){
            W.RegisterWildcardPreSolve(tag,std::move(fn));
        });
    t.set_function("on_wildcard_postsolve",
        [](PhysicsWorld &W, const std::string& tag, sol::protected_function fn){
            W.RegisterWildcardPostSolve(tag,std::move(fn));
        });

    // Optional clears
    t.set_function("clear_pair_handlers",
        [](PhysicsWorld &W, const std::string& a, const std::string& b){ W.ClearPairHandlers(a,b); });
    t.set_function("clear_wildcard_handlers",
        [](PhysicsWorld &W, const std::string& tag){ W.ClearWildcardHandlers(tag); });

    // Arbiter usertype
    lua.new_usertype<LuaArbiter>("Arbiter",
        "entities",           &LuaArbiter::entities,
        "tags",               [](LuaArbiter& A, PhysicsWorld &W){ return A.tags(W); },
        "normal",             &LuaArbiter::normal,
        "total_impulse",      &LuaArbiter::total_impulse,
        "total_impulse_len",  &LuaArbiter::total_impulse_length,
        "set_friction",       &LuaArbiter::set_friction,
        "set_elasticity",     &LuaArbiter::set_elasticity,
        "set_surface_velocity",&LuaArbiter::set_surface_velocity,
        "ignore",             &LuaArbiter::ignore
    );

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