#pragma once

#include "physics_manager.hpp"
#include "systems/transform/transform.hpp"


/*

Frame order (system sequence)

    1. Input/transform interactions (hover, press, start drag, etc.)

        On start drag: set PhysicsSyncConfig.mode = AuthoritativeTransform.

        While dragging: update Transform.actual to cursor, not visual; let visual effects add on top.

    2. Authoritative push (optional)

        If AuthoritativeTransform: call TransformToBody(..., zeroVelocity=true).

    3. Physics step for active worlds.

    4. Authoritative pull

        If AuthoritativePhysics: call BodyToTransform(...).

    5. Transform springs advance (your existing updateCachedValues path).

    6. Render using visual values.
    
    
Size/scale notes

    - visual scale (getVisualScaleWithHoverAndDynamicMotionReflected) should not affect physics. Keep physics shape constant unless you really need scaled colliders.

    - If you must reflect actualW/H changes to physics, rebuild the shape (Chipmunk geometry). Provide a small utility that marks “shapeDirty” and rebuilds it at a safe point (before stepping the world).
    
Soft move in case you move the transform and want the physics to follow (Return to normal automatically when close enough):

```
- You set the actual target (springs move visual). Now make body follow the visual:
T.setActualX(nx); T.setActualY(ny);
auto& cfg = registry.get<PhysicsSyncConfig>(e);
cfg.mode = PhysicsSyncMode::FollowVisual;
cfg.useKinematic = true; // or false for dynamic assist

```

*/

namespace physics {
    
/* -------------- Checking entity active state & physics state -------------- */
    
    inline bool is_entity_state_active(entt::registry& R, entt::entity e) {
        if (auto* tag = R.try_get<entity_gamestate_management::StateTag>(e)) {
            return entity_gamestate_management::isActiveState(*tag);
        }
        // default: only update entities in DEFAULT_STATE
        entity_gamestate_management::StateTag def{ entity_gamestate_management::DEFAULT_STATE_TAG };
        return entity_gamestate_management::isActiveState(def);
    }
    
    static bool worldActive(PhysicsManager& PM, const std::string& worldName) {
        auto* rec = PM.get(worldName);
        return rec && PhysicsManager::world_active(*rec);
    }
    
/* -------------------------------- Rendering ------------------------------- */
    
    inline bool ShouldRender(entt::registry& R,
                         PhysicsManager& PM,
                         entt::entity e)
    {
        using namespace entity_gamestate_management;

        // 1) Entity state gate
        bool entityActive = [&]{
            if (auto* t = R.try_get<StateTag>(e)) return active_states_instance().is_active(*t);
            StateTag def{DEFAULT_STATE_TAG};
            return active_states_instance().is_active(def);
        }();

        if (!entityActive) return false;

        // 2) Physics-world gate (only if this entity belongs to a physics world)
        if (auto* ref = R.try_get<PhysicsWorldRef>(e)) {
            if (auto* rec = PM.get(ref->name)) {
            // If the world is bound to a state, only render when that state is active.
            // Typically you’ll want: render only while the world is active.
            return PhysicsManager::world_active(*rec);
            }
        }
        // If no physics world, default to entity state only
        return true;
    }
    
    inline void RenderAll(entt::registry& R, PhysicsManager& PM) {
        // Choose your ordering: by TreeOrderComponent, layer order, etc.
        auto view = R.view<transform::Transform, transform::GameObject>();
        // Example: sort by a TreeOrderComponent if present
        view.use<transform::TreeOrderComponent>();
        R.sort<transform::TreeOrderComponent>([](const auto& a, const auto& b){
            return a.order < b.order;
        });

        for (auto e : view) {
            if (!ShouldRender(R, PM, e)) continue;
            // Your established per-entity renderer:
            layer::DrawTransformEntityWithAnimationWithPipeline(R, e /*, plus PM if you added gate inside*/);
        }

        // Optional: physics debug draw after sprites
        // PM.drawAll();
    }
    
/* ---------------- Making physics bodies based on transform ---------------- */
    struct PhysicsCreateInfo {
        physics::ColliderShapeType shape = physics::ColliderShapeType::Rectangle;
        std::string tag = "WORLD";        // your collision tag
        bool sensor = false;
        float density = 1.0f;
    };

    // Helper: center-based rectangle from Transform ACTUAL size.
    inline void CreatePhysicsForTransform(entt::registry& R,
                                        PhysicsManager& PM,
                                        entt::entity e,
                                        const PhysicsCreateInfo& ci)
    {
        auto& T    = R.get<transform::Transform>(e);
        auto& ref  = R.get<PhysicsWorldRef>(e);
        auto* rec  = PM.get(ref.name);
        if (!rec) return;

        // Body (dynamic by default; make static/kinematic as you like)
        auto body = physics::MakeSharedBody(/*mass*/1.0f, /*moment*/INFINITY);
        physics::SetEntityToBody(body.get(), e);

        // Choose size from ACTUAL W/H (not visual)
        float w = std::max(1.f, T.getActualW());
        float h = std::max(1.f, T.getActualH());

        // Chipmunk expects meters-ish; your PIXELS_PER_PIXEL_UNIT = 1.0f, so we’ll just convert coords.
        cpBodySetPosition(body.get(), {T.getActualX() + w / 2, T.getActualY() + h / 2});
        cpBodySetAngle(body.get(), T.getActualRotation() * DEG2RAD);

        std::shared_ptr<cpShape> shape;
        switch (ci.shape) {
            case physics::ColliderShapeType::Rectangle: {
            // Box from center
            cpVect verts[4] = {
                cpv(-w*0.5f, -h*0.5f), cpv( w*0.5f, -h*0.5f),
                cpv( w*0.5f,  h*0.5f), cpv(-w*0.5f,  h*0.5f),
            };
            shape.reset(cpPolyShapeNew(body.get(), 4, verts, cpTransformIdentity, 0), cpShapeFree);
            } break;
            case physics::ColliderShapeType::Circle: {
            float r = 0.5f * std::max(w, h);
            shape.reset(cpCircleShapeNew(body.get(), r, cpvzero), cpShapeFree);
            } break;
            // add Segment/Polygon as needed…
            default: /* fallback */ {
            shape = physics::MakeSharedShape(body.get(), w, h); // your helper
            } break;
        }

        physics::SetEntityToShape(shape.get(), e);
        cpShapeSetSensor(shape.get(), ci.sensor);

        // Add to world
        cpSpaceAddBody(rec->w->space, body.get());
        cpSpaceAddShape(rec->w->space, shape.get());

        // Store on entity
        R.emplace_or_replace<physics::ColliderComponent>(e, body, shape, ci.tag, ci.sensor, ci.shape);

        // Apply collision filter via your tag system
        rec->w->AddCollisionTag(ci.tag);
        rec->w->ApplyCollisionFilter(shape.get(), ci.tag);

        // Optional: set body type based on your intent
        // cpBodySetType(body.get(), CP_BODY_TYPE_DYNAMIC / KINEMATIC / STATIC);
    }

    
    
/* ----------------------- Physics + Transform syncing ---------------------- */
    enum class PhysicsSyncMode {
        AuthoritativePhysics,     // body -> Transform.actual (default)
        AuthoritativeTransform,   // Transform.actual -> body (drag/teleport)
        FollowVisual,             // body follows Transform.visual (your springs)
        FrozenWhileDesynced
    };
    
    
    struct PhysicsSyncConfig {
        PhysicsSyncMode mode = PhysicsSyncMode::AuthoritativePhysics;
        // follow visual knobs
        bool teleportOnResync = true; // when resuming sync after disconnect, teleport to visual
        bool useKinematic = true;      // kinematic while following visual (collides correctly)
        float maxSpeed = 2400.f;       // clamp for stability
        float doneDistPx = 0.6f;       // when close enough, flip back to AuthoritativePhysics
        float doneSpeed   = 2.0f;      // and nearly stopped
        cpBodyType prevType = CP_BODY_TYPE_DYNAMIC;
    };

    inline auto BodyToTransform(entt::registry& R, entt::entity e, physics::PhysicsWorld& W) -> void {
        if (!R.valid(e) || !R.any_of<transform::Transform, physics::ColliderComponent>(e)) return;
        auto& T  = R.get<transform::Transform>(e);
        auto& CC = R.get<physics::ColliderComponent>(e);

        const cpVect p = cpBodyGetPosition(CC.body.get());
        const float a  = (float)cpBodyGetAngle(CC.body.get());

        // raylib coords
        const Vector2 rl = { (float) p.x - T.getActualW() / 2, (float)  p.y - T.getActualH() / 2};

        // Write ACTUAL targets (not visual) so springs smoothly approach
        T.setActualX(rl.x);
        T.setActualY(rl.y);
        T.setActualRotation(a * RAD2DEG); // if your angles are degrees
    }

    inline auto TransformToBody(entt::registry& R, entt::entity e, physics::PhysicsWorld& W,
                                bool zeroVelocity) -> void {
        if (!R.valid(e) || !R.any_of<transform::Transform, physics::ColliderComponent>(e)) return;
        auto& T  = R.get<transform::Transform>(e);
        auto& CC = R.get<physics::ColliderComponent>(e);

        // Use ACTUAL (target) values
        const Vector2 rl = { T.getActualX(), T.getActualY() };
        const float   a  = T.getActualRotation() * DEG2RAD;

        const cpVect  cp = { rl.x + T.getActualW() / 2, rl.y + T.getActualH() / 2 };
        cpBodySetPosition(CC.body.get(), cp);
        cpBodySetAngle(CC.body.get(), a);

        if (zeroVelocity) {
            cpBodySetVelocity(CC.body.get(), cpvzero);
            cpBodySetAngularVelocity(CC.body.get(), 0.0f);
            cpBodyActivate(CC.body.get());
        }
    }
    
    // Kinematic follow (recommended for exact visual matching + good collisions):
    inline void VisualToBody_Kinematic(entt::registry& R, entt::entity e, physics::PhysicsWorld& W, float dt) {
        auto& T  = R.get<transform::Transform>(e);
        auto& CC = R.get<physics::ColliderComponent>(e);

        // where the sprite actually is this frame:
        Vector2 vpos = { T.getVisualX(), T.getVisualY() };
        float   vang = T.getVisualR(); // if you want rotation too

        cpBodySetType(CC.body.get(), CP_BODY_TYPE_KINEMATIC);

        // set kinematic velocity to reach visual in ~1 frame
        cpVect  p  = cpBodyGetPosition(CC.body.get());
        Vector2 pr = physics::chipmunkToRaylibCoords(p);
        Vector2 d  = { vpos.x - pr.x, vpos.y - pr.y };

        const float invDt = (dt > 0.f) ? (1.f/dt) : 0.f;
        cpVect v = physics::raylibToChipmunkCoords({ d.x * invDt, d.y * invDt });

        // clamp
        float speed = cpvlength(v);
        if (speed > 0.f && speed > 2400.f) v = cpvmult(v, 2400.f/speed);

        cpBodySetVelocity(CC.body.get(), v);
        cpBodySetAngularVelocity(CC.body.get(), (vang*DEG2RAD - cpBodyGetAngle(CC.body.get())) * invDt);
    }
    
    // Sync with dynamic body, applying impulse to pull toward visual.
    inline void VisualToBody_DynamicAssist(entt::registry& R, entt::entity e, physics::PhysicsWorld& W, float dt) {
        auto& T  = R.get<transform::Transform>(e);
        auto& CC = R.get<physics::ColliderComponent>(e);

        cpVect  p  = cpBodyGetPosition(CC.body.get());
        cpVect  v  = cpBodyGetVelocity(CC.body.get());
        Vector2 vpos = { T.getVisualX(), T.getVisualY() };
        cpVect  t  = physics::raylibToChipmunkCoords(vpos);

        cpVect err = cpvsub(t, p);
        cpVect dv  = cpvsub(cpvmult(err, 12.0f), v); // simple PD: 12 is a nice “stickiness”
        cpVect imp = cpvmult(dv, cpBodyGetMass(CC.body.get()));

        cpBodyApplyImpulseAtLocalPoint(CC.body.get(), imp, cpvzero);
    }


/* --- Transform hooks to ensure syncing happens correctly on interaction --- */

    inline auto OnStartDrag(entt::registry& R, entt::entity e) -> void {
        if (!R.valid(e)) return;

        // mark UI state
        auto& GO = R.get<transform::GameObject>(e);
        GO.state.isBeingDragged = true;

        // switch body -> KINEMATIC while we drive it
        if (auto* cc = R.try_get<physics::ColliderComponent>(e)) {
            // remember previous type so we can restore on drop
            auto& cfg = R.get_or_emplace<PhysicsSyncConfig>(e);
            cfg.prevType = cpBodyGetType(cc->body.get());
            cpBodySetVelocity(cc->body.get(), cpvzero);
            cpBodySetAngularVelocity(cc->body.get(), 0.f);
            cpBodySetType(cc->body.get(), CP_BODY_TYPE_KINEMATIC);

            // while dragging, Transform is authoritative (we push actual -> body each frame)
            cfg.mode = PhysicsSyncMode::AuthoritativeTransform;
            cfg.teleportOnResync = false;   // we’re continuously syncing; no need to snap later
        }
    }

    inline auto OnDrop(entt::registry& R, entt::entity e) -> void {
        if (!R.valid(e)) return;

        auto& GO = R.get<transform::GameObject>(e);
        GO.state.isBeingDragged = false;

        // return control to physics
        if (auto* cc = R.try_get<physics::ColliderComponent>(e)) {
            auto& cfg = R.get_or_emplace<PhysicsSyncConfig>(e);

            // stop any residual kinematic velocity before switching back
            cpBodySetVelocity(cc->body.get(), cpvzero);
            cpBodySetAngularVelocity(cc->body.get(), 0.f);

            // restore whatever the body type was pre-drag (usually DYNAMIC)
            cpBodySetType(cc->body.get(), cfg.prevType);

            // now let physics be authoritative again; body -> Transform.actual post-step
            cfg.mode = PhysicsSyncMode::AuthoritativePhysics;

            // optional: if you want one or two frames of visual-follow settle,
            // you could briefly do:
            //   cfg.mode = PhysicsSyncMode::FollowVisual; cfg.useKinematic = false;
            // and it will auto-return to AuthoritativePhysics on settle.
        }
    }

/* ------------------------ transform-dominant phase ------------------------ */
    inline auto ApplyAuthoritativeTransform(entt::registry& R, PhysicsManager& PM) -> void {
        auto view = R.view<transform::Transform, physics::ColliderComponent, PhysicsSyncConfig, PhysicsWorldRef>();
        for (auto e : view) {
            auto& cfg = view.get<PhysicsSyncConfig>(e);
            if (cfg.mode != PhysicsSyncMode::AuthoritativeTransform) continue;

            auto& ref = view.get<PhysicsWorldRef>(e);
            auto* rec = PM.get(ref.name);
            if (!rec || !PhysicsManager::world_active(*rec)) continue;

            // Push Transform.actual to body (zero vel while being driven)
            TransformToBody(R, e, *rec->w, /*zeroVelocity=*/true);
        }
    }
    
/* ------------------------ physics-dominant phase ------------------------- */
    inline auto ApplyAuthoritativePhysics(entt::registry& R, PhysicsManager& PM) -> void {
        auto view = R.view<transform::Transform, physics::ColliderComponent, PhysicsSyncConfig, PhysicsWorldRef>();
        for (auto e : view) {
            auto& cfg = view.get<PhysicsSyncConfig>(e);
            if (cfg.mode != PhysicsSyncMode::AuthoritativePhysics) continue;

            auto& ref = view.get<PhysicsWorldRef>(e);
            auto* rec = PM.get(ref.name);
            if (!rec || !PhysicsManager::world_active(*rec)) continue;

            BodyToTransform(R, e, *rec->w); // sets ACTUAL; visuals interpolate
        }
    }
    
/* ---------- disable physics bodies which are gated by state/world --------- */
    inline auto HandleDesynced(entt::registry& R, PhysicsManager& PM) -> void {
        auto view = R.view<physics::ColliderComponent, PhysicsSyncConfig, PhysicsWorldRef>();
        for (auto e : view) {
            auto& cfg = view.get<PhysicsSyncConfig>(e);
            if (cfg.mode != PhysicsSyncMode::FrozenWhileDesynced) continue;

            auto& ref = view.get<PhysicsWorldRef>(e);
            auto* rec = PM.get(ref.name);
            if (rec && !PhysicsManager::world_active(*rec)) {
                auto& cc = view.get<physics::ColliderComponent>(e);
                cpBodySleep(cc.body.get());
            }
        }
    }
    
/* ----------------------- Call every frame -------------------------- */
    inline void ApplySyncPolicy(entt::registry& R, PhysicsManager& PM, float dt) {
        auto view = R.view<transform::Transform, physics::ColliderComponent, PhysicsSyncConfig, PhysicsWorldRef>();
        for (auto e : view) {
            auto& cfg = view.get<PhysicsSyncConfig>(e);
            auto& ref = view.get<PhysicsWorldRef>(e);
            auto* rec = PM.get(ref.name);
            if (!rec || !PhysicsManager::world_active(*rec)) continue;

            switch (cfg.mode) {
            case PhysicsSyncMode::AuthoritativeTransform:
                physics::TransformToBody(R, e, *rec->w, /*zeroVelocity=*/true);
                break;

            case PhysicsSyncMode::FollowVisual: {
                // A) exact match & good collisions:
                if (cfg.useKinematic) VisualToBody_Kinematic(R, e, *rec->w, dt);
                // B) or preserve fully dynamic contact response:
                else VisualToBody_DynamicAssist(R, e, *rec->w, dt);

                // done condition → back to physics
                auto& T  = view.get<transform::Transform>(e);
                auto& CC = view.get<physics::ColliderComponent>(e);
                Vector2 vpos = { T.getVisualX(), T.getVisualY() };
                float   spd  = cpvlength(cpBodyGetVelocity(CC.body.get()));
                Vector2 bpos = physics::chipmunkToRaylibCoords(cpBodyGetPosition(CC.body.get()));
                if (Vector2Distance(vpos, bpos) <= cfg.doneDistPx && spd <= cfg.doneSpeed) {
                if (cfg.useKinematic) {
                    cpBodySetVelocity(CC.body.get(), cpvzero);
                    cpBodySetAngularVelocity(CC.body.get(), 0.f);
                    cpBodySetType(CC.body.get(), CP_BODY_TYPE_DYNAMIC);
                }
                cfg.mode = PhysicsSyncMode::AuthoritativePhysics;
                }
            } break;

            case PhysicsSyncMode::AuthoritativePhysics:
                physics::BodyToTransform(R, e, *rec->w); // body -> actual; visuals ease toward it
                break;

            case PhysicsSyncMode::FrozenWhileDesynced:
                HandleDesynced(R, PM);
                break;
            }
        }
    }


}
