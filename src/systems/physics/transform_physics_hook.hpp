#pragma once

#include "physics_manager.hpp"
#include "systems/physics/physics_components.hpp"
#include "systems/transform/transform.hpp"
#include "third_party/chipmunk/include/chipmunk/chipmunk.h"


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
    
    enum class PhysicsSyncMode {
        AuthoritativePhysics,     // body -> Transform.actual (default)
        AuthoritativeTransform,   // Transform.actual -> body (drag/teleport)
        FollowVisual,             // body follows Transform.visual (your springs)
        FrozenWhileDesynced
    };
    
    enum class RotationSyncMode {
        TransformFixed_PhysicsFollows,   // keep transform angle; force body to it
        PhysicsFree_TransformFollows     // let body rotate; copy to transform
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
        
        // NEW: rotation authority
        RotationSyncMode rotMode = RotationSyncMode::PhysicsFree_TransformFollows;

        
        // rotation sync policy
        bool pushAngleFromTransform = true;   // when Transform is authoritative or following visual
        bool pullAngleFromPhysics   = true;   // when Physics is authoritative (optional)

        bool useVisualRotationWhenDragging = true; // during drag, push visual angle instead of actual

    };
    
    void SetBodyRotationLocked(entt::registry& R, entt::entity e, bool lock);

    inline void BodyToTransform(entt::registry& R, entt::entity e, physics::PhysicsWorld& W, float alpha = 1.0f)
    {
        if (!R.valid(e) || !R.any_of<transform::Transform, physics::ColliderComponent, PhysicsSyncConfig>(e))
            return;

        auto& T   = R.get<transform::Transform>(e);
        auto& CC  = R.get<physics::ColliderComponent>(e);
        auto& cfg = R.get<PhysicsSyncConfig>(e);

        if (!CC.body) return;
        cpBody* body = CC.body.get();

        // -------------------------------------------------------------------------
        // CACHED PREVIOUS PHYSICS STATE (required for lerp)
        // -------------------------------------------------------------------------
        // Note: these fields can be added to ColliderComponent if not already present.
        // Example:
        //   Vector2 prevPos;
        //   float   prevRot = 0.f;
        //   Vector2 currPos;
        //   float   currRot = 0.f;
        //
        // Update these in your physics step before and after cpSpaceStep().
        // This function will then use them for interpolation.

        const cpVect p = cpBodyGetPosition(body);
        const float a  = (float)cpBodyGetAngle(body);

        // Compute physics-space center (Chipmunk’s position is body center)
        Vector2 currCenter = { (float)p.x, (float)p.y };
        float currRot = a * RAD2DEG;

        // Lerp if we have previous data (optional guard)
        Vector2 displayCenter = currCenter;
        float displayRot = currRot;

        if (CC.prevPos.x != 0.0f || CC.prevPos.y != 0.0f || CC.prevRot != 0.0f) {
            displayCenter.x = std::lerp(CC.prevPos.x, currCenter.x, alpha);
            displayCenter.y = std::lerp(CC.prevPos.y, currCenter.y, alpha);
            displayRot      = std::lerp(CC.prevRot, currRot, alpha);
        }

        // Store current positions for next frame
        CC.prevPos = currCenter;
        CC.prevRot = currRot;

        // Offset to top-left (your engine uses actualX/Y as top-left)
        const Vector2 rl = { displayCenter.x - T.getActualW() * 0.5f,
                            displayCenter.y - T.getActualH() * 0.5f };

        // Apply interpolated transform
        T.setActualX(rl.x);
        T.setActualY(rl.y);

        // ---- ROTATION HANDOFF ----
        if (cfg.rotMode == RotationSyncMode::PhysicsFree_TransformFollows) {
            // T.setActualRotation(displayRot);
        }
        else {
            // Transform is authoritative → do NOT pull angle from physics.
        }
    }

    inline void EnforceRotationPolicy(entt::registry& R, entt::entity e) {
        auto& cfg = R.get<PhysicsSyncConfig>(e);
        auto& CC  = R.get<physics::ColliderComponent>(e);
        auto& T   = R.get<transform::Transform>(e);
        cpBody* b = CC.body.get();

        if (cfg.rotMode == RotationSyncMode::TransformFixed_PhysicsFollows) {
            // keep body locked and glued to Transform angle
            SetBodyRotationLocked(R, e, true);
            cpBodySetAngle(b, T.getActualRotation() * DEG2RAD);
            cpBodySetAngularVelocity(b, 0.0f);
            // optional: cpBodySetTorque(b, 0.0f);
        } else {
            // ensure rotation is free
            SetBodyRotationLocked(R, e, false);
            // Transform angle comes from physics in BodyToTransform()
        }
    }


    inline void TransformToBody(entt::registry& R, entt::entity e, physics::PhysicsWorld& W,
                            bool zeroVelocity, bool useVisualRotation = true)
    {
        if (!R.valid(e) || !R.any_of<transform::Transform, physics::ColliderComponent> (e)) return;

        auto& T   = R.get<transform::Transform>(e);
        auto& CC  = R.get<physics::ColliderComponent>(e);
        auto& cfg = R.get_or_emplace<PhysicsSyncConfig>(e);

        const Vector2 rl = { T.getActualX(), T.getActualY() };
        const cpVect  cp = { rl.x + T.getActualW() * 0.5f, rl.y + T.getActualH() * 0.5f };
        cpBodySetPosition(CC.body.get(), cp);

        // ---- ROTATION HANDOFF ----
        if (cfg.rotMode == RotationSyncMode::TransformFixed_PhysicsFollows) {
            // Authoritative angle is Transform
            // const float rotDeg = (cfg.pushAngleFromTransform && useVisualRotation)
            //                 ? T.getVisualR()
            //                 : (cfg.pushAngleFromTransform ? T.getActualRotation()
            //                                                 : (float)cpBodyGetAngle(CC.body.get()) * RAD2DEG);
            const float rotDeg = useVisualRotation
                            ? T.getVisualR()
                            : T.getActualRotation();
            cpBodySetAngle(CC.body.get(), rotDeg * DEG2RAD);
            cpBodySetAngularVelocity(CC.body.get(), 0.0f);
            if (cfg.rotMode == RotationSyncMode::TransformFixed_PhysicsFollows) {
                SetBodyRotationLocked(R, e, true);
            }
        } else { // PhysicsFree_TransformFollows
            // Don’t stamp angle onto body; ensure rotation is free
            if (cfg.rotMode == RotationSyncMode::PhysicsFree_TransformFollows) {
                SetBodyRotationLocked(R, e, false);
            }
        }

        if (zeroVelocity) {
            cpBodySetVelocity(CC.body.get(), cpvzero);
            // leave angular vel alone in PhysicsFree mode
            if (cfg.rotMode == RotationSyncMode::TransformFixed_PhysicsFollows) {
                cpBodySetAngularVelocity(CC.body.get(), 0.0f);
            }
            cpBodyActivate(CC.body.get());
        }
    }
    
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
        std::string tag = DEFAULT_COLLISION_TAG;        // your collision tag
        bool sensor = false;
        float density = 1.0f;
    };
    
    // --- helper ---
    inline cpFloat ComputeMoment(const PhysicsCreateInfo& ci, cpFloat mass, float w, float h){
        switch (ci.shape){
            case physics::ColliderShapeType::Rectangle:
                return cpMomentForBox(mass, w, h);
            case physics::ColliderShapeType::Circle: {
                float r = 0.5f * std::max(w, h);
                return cpMomentForCircle(mass, 0.0f, r, cpvzero);
            }
            default:
                // Fallback: approximate as box
                return cpMomentForBox(mass, w, h);
        }
    }
    
    inline void CreatePhysicsForTransform(entt::registry& R,
                                      PhysicsManager& PM,
                                      entt::entity e,
                                      const physics::PhysicsCreateInfo& ci,
                                      const std::string& worldName,
                                      float inflate_px = 0.0f,
                                      bool set_world_ref_on_entity = true)
{
    auto& T = R.get<transform::Transform>(e);
    auto* rec = PM.get(worldName);
    if (!rec) return;

    // Body
    // pick your mass policy; 1.0f is fine for now
    cpFloat mass = ci.sensor ? 0.1f : 1.0f;
    auto body = physics::MakeSharedBody(mass, /*moment*/INFINITY);
    physics::SetEntityToBody(body.get(), e);
    // Base size from ACTUAL W/H
    float base_w = std::max(1.f, T.getActualW());
    float base_h = std::max(1.f, T.getActualH());

    // Signed inflate (pixels)
    const float w = std::max(1.f, base_w + 2.f * inflate_px);
    const float h = std::max(1.f, base_h + 2.f * inflate_px);

    // Adjust center so inflated shape stays centered on original
    const float cx = T.getActualX() + (base_w * 0.5f) - (inflate_px);
    const float cy = T.getActualY() + (base_h * 0.5f) - (inflate_px);
    
    cpFloat moment = ComputeMoment(ci, mass, w, h);
    // If you must create body first, you can also set after:
    cpBodySetMass(body.get(), mass);
    cpBodySetMoment(body.get(), moment);

    cpBodySetPosition(body.get(), {cx, cy});
    cpBodySetAngle(body.get(), T.getActualRotation() * DEG2RAD);

    std::shared_ptr<cpShape> shape;
    switch (ci.shape) {
        case physics::ColliderShapeType::Rectangle: {
            const cpVect verts[4] = {
                cpv(-w*0.5f, -h*0.5f), cpv( w*0.5f, -h*0.5f),
                cpv( w*0.5f,  h*0.5f), cpv(-w*0.5f,  h*0.5f),
            };
            shape.reset(cpPolyShapeNew(body.get(), 4, verts, cpTransformIdentity, 0), cpShapeFree);
        } break;
        case physics::ColliderShapeType::Circle: {
            float r = 0.5f * std::max(w, h);
            shape.reset(cpCircleShapeNew(body.get(), r, cpvzero), cpShapeFree);
        } break;
        default: {
            shape = physics::MakeSharedShape(body.get(), w, h);
        } break;
    }

    physics::SetEntityToShape(shape.get(), e);
    cpShapeSetSensor(shape.get(), ci.sensor);

    // Add to world
    cpSpaceAddBody (rec->w->space, body.get());
    cpSpaceAddShape(rec->w->space, shape.get());

    // Store on entity
    R.emplace_or_replace<physics::ColliderComponent>(e, body, shape, ci.tag, ci.sensor, ci.shape);
    
    R.emplace_or_replace<PhysicsWorldRef>(e, worldName);
    
    // check PhysicsWorldRef
    auto &physicsWorldRef = R.get<PhysicsWorldRef>(e);
    if (physicsWorldRef.name != worldName) {
        SPDLOG_WARN("Entity {} has mismatched PhysicsWorldRef ({} vs {}). Updating to {}.",
                    (uint32_t)e, physicsWorldRef.name, worldName, worldName);
        physicsWorldRef.name = worldName;
    }
    
    auto& cfg = R.emplace_or_replace<physics::PhysicsSyncConfig>(e);
    cfg.mode = physics::PhysicsSyncMode::AuthoritativeTransform;
    cfg.pushAngleFromTransform = true;   // push rotation on first frame
    cfg.pullAngleFromPhysics   = false;  // physics should not overwrite our spawn pose this frame
    
    // Choose initial behavior based on rotMode
    if (cfg.rotMode == physics::RotationSyncMode::PhysicsFree_TransformFollows) {
        // Start with physics authority so Transform follows the body immediately
        cfg.mode = physics::PhysicsSyncMode::AuthoritativePhysics;
        cfg.pushAngleFromTransform = false;
        cfg.pullAngleFromPhysics   = true;

        // Snap Transform to the freshly created body pose *now*
        physics::BodyToTransform(R, e, *rec->w);
        EnforceRotationPolicy(R, e); // ensure finite moment (free rotation) on spawn
    } else {
        // Transform-fixed mode: keep your existing push
        cfg.mode = physics::PhysicsSyncMode::AuthoritativeTransform;
        cfg.pushAngleFromTransform = true;
        cfg.pullAngleFromPhysics   = false;

        // Push Transform pose into the body once and lock rotation
        physics::TransformToBody(R, e, *rec->w, /*zeroVelocity=*/true, /*useVisualRotation=*/true);
        EnforceRotationPolicy(R, e); // lock rotation (INFINITY moment) on spawn
    }





    // ✅ Also stamp the world ref (constructor computes hash for us)
    if (set_world_ref_on_entity) {
        R.emplace_or_replace<PhysicsWorldRef>(e, worldName);
        // Equivalent explicit form if you prefer clarity:
        // R.emplace_or_replace<PhysicsWorldRef>(e, PhysicsWorldRef{worldName});
    }

    // Tag/filter
    rec->w->AddCollisionTag(ci.tag);
    rec->w->ApplyCollisionFilter(shape.get(), ci.tag);
}


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

    float w = std::max(1.f, T.getActualW());
    float h = std::max(1.f, T.getActualH());

    // MASS & MOMENT (finite!)
    cpFloat mass   = ci.sensor ? 0.1f : 1.0f;
    cpFloat moment = ComputeMoment(ci, mass, w, h);

    auto body = physics::MakeSharedBody(mass, moment);
    physics::SetEntityToBody(body.get(), e);

    
    cpBodySetPosition(body.get(), {T.getActualX() + w / 2, T.getActualY() + h / 2});
    cpBodySetAngle(body.get(), T.getActualRotation() * DEG2RAD);

    std::shared_ptr<cpShape> shape;
    switch (ci.shape) {
        case physics::ColliderShapeType::Rectangle: {
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
        default: {
            shape = physics::MakeSharedShape(body.get(), w, h);
        } break;
    }

    physics::SetEntityToShape(shape.get(), e);
    cpShapeSetSensor(shape.get(), ci.sensor);

    cpSpaceAddBody (rec->w->space, body.get());
    cpSpaceAddShape(rec->w->space, shape.get());

    R.emplace_or_replace<physics::ColliderComponent>(e, body, shape, ci.tag, ci.sensor, ci.shape);
    
    R.emplace_or_replace<PhysicsWorldRef>(e, ref.name);
    
    // check PhysicsWorldRef
    auto &physicsWorldRef = R.get<PhysicsWorldRef>(e);
    if (physicsWorldRef.name != ref.name) {
        SPDLOG_WARN("Entity {} has mismatched PhysicsWorldRef ({} vs {}). Updating to {}.",
                    (uint32_t)e, physicsWorldRef.name, ref.name, ref.name);
        physicsWorldRef.name = ref.name;
    }
    
    auto& cfg = R.emplace_or_replace<physics::PhysicsSyncConfig>(e);
    cfg.mode = physics::PhysicsSyncMode::AuthoritativeTransform;
    cfg.pushAngleFromTransform = true;   // push rotation on first frame
    cfg.pullAngleFromPhysics   = false;  // physics should not overwrite our spawn pose this frame
    
    
    // Choose initial behavior based on rotMode
    if (cfg.rotMode == physics::RotationSyncMode::PhysicsFree_TransformFollows) {
        // Start with physics authority so Transform follows the body immediately
        cfg.mode = physics::PhysicsSyncMode::AuthoritativePhysics;
        cfg.pushAngleFromTransform = false;
        cfg.pullAngleFromPhysics   = true;

        // Snap Transform to the freshly created body pose *now*
        physics::BodyToTransform(R, e, *rec->w);
        EnforceRotationPolicy(R, e); // ensure finite moment (free rotation) on spawn
    } else {
        // Transform-fixed mode: keep your existing push
        cfg.mode = physics::PhysicsSyncMode::AuthoritativeTransform;
        cfg.pushAngleFromTransform = true;
        cfg.pullAngleFromPhysics   = false;

        // Push Transform pose into the body once and lock rotation
        physics::TransformToBody(R, e, *rec->w, /*zeroVelocity=*/true, /*useVisualRotation=*/true);
        EnforceRotationPolicy(R, e); // lock rotation (INFINITY moment) on spawn
    }


    rec->w->AddCollisionTag(ci.tag);
    rec->w->ApplyCollisionFilter(shape.get(), ci.tag);
    
    if (auto it = rec->w->_tagToCollisionType.find(ci.tag);
    it != rec->w->_tagToCollisionType.end())
    {
        cpShapeSetCollisionType(shape.get(), it->second);
    }
    else
    {
        SPDLOG_WARN("CreatePhysicsForTransform: tag '{}' has no collisionType, defaulting to 0", ci.tag);
    }

}


    
    
/* ----------------------- Physics + Transform syncing ---------------------- */
    

    

    
    // Kinematic follow (recommended for exact visual matching + good collisions):
    inline void VisualToBody_Kinematic(entt::registry& R, entt::entity e, physics::PhysicsWorld& W, float dt) {
        auto& T  = R.get<transform::Transform>(e);
        auto& CC = R.get<physics::ColliderComponent>(e);

        Vector2 vpos = { T.getVisualX(), T.getVisualY() };
        float   vangDeg = T.getVisualR();                   // visual rotation in degrees
        float   vangRad = vangDeg * DEG2RAD;

        cpBodySetType(CC.body.get(), CP_BODY_TYPE_KINEMATIC);

        // linear follow
        cpVect p = cpBodyGetPosition(CC.body.get());
        Vector2 pr = physics::chipmunkToRaylibCoords(p);
        Vector2 d  = { vpos.x - pr.x, vpos.y - pr.y };
        const float invDt = (dt > 0.f) ? (1.f/dt) : 0.f;
        cpVect v = physics::raylibToChipmunkCoords({ d.x * invDt, d.y * invDt });
        float speed = cpvlength(v);
        if (speed > 2400.f) v = cpvmult(v, 2400.f/speed);
        cpBodySetVelocity(CC.body.get(), v);

        // angular follow (wrap-safe)
        float cur = (float)cpBodyGetAngle(CC.body.get());
        float diff = vangRad - cur;
        // normalize to [-pi, pi] to avoid spin-the-long-way
        while (diff >  CP_PI) diff -= 2.f * CP_PI;
        while (diff < -CP_PI) diff += 2.f * CP_PI;

        cpBodySetAngularVelocity(CC.body.get(), diff * invDt);

        // For exact pose lock (optional): also set the angle directly
        // cpBodySetAngle(CC.body.get(), vangRad);
        //FIXME: testing
        cpBodySetAngle(CC.body.get(), vangRad);
    }
    
    // Sync with dynamic body, applying impulse to pull toward visual.
    inline void VisualToBody_DynamicAssist(entt::registry& R, entt::entity e, physics::PhysicsWorld& W, float dt) {
        auto& T  = R.get<transform::Transform>(e);
        auto& CC = R.get<physics::ColliderComponent>(e);

        // linear PD as you had...
        cpVect  p  = cpBodyGetPosition(CC.body.get());
        cpVect  v  = cpBodyGetVelocity(CC.body.get());
        Vector2 vpos = { T.getVisualX(), T.getVisualY() };
        cpVect  t  = physics::raylibToChipmunkCoords(vpos);

        cpVect err = cpvsub(t, p);
        cpVect dv  = cpvsub(cpvmult(err, 12.0f), v);
        cpVect imp = cpvmult(dv, cpBodyGetMass(CC.body.get()));
        cpBodyApplyImpulseAtLocalPoint(CC.body.get(), imp, cpvzero);

        // angular PD
        float ang  = (float)cpBodyGetAngle(CC.body.get());
        float vang = T.getVisualR() * DEG2RAD;
        float w    = (float)cpBodyGetAngularVelocity(CC.body.get());

        float dAng = vang - ang;
        while (dAng >  CP_PI) dAng -= 2.f * CP_PI;
        while (dAng < -CP_PI) dAng += 2.f * CP_PI;

        // simple critically-damped-ish gains
        const float kp = 12.0f, kd = 2.0f * std::sqrt(kp);
        float torque = kp * dAng - kd * w;

        cpBodySetTorque(CC.body.get(), torque);
    }


/* --- Transform hooks to ensure syncing happens correctly on interaction --- */

    inline void OnStartDrag(entt::registry& R, entt::entity e) {
    if (!R.valid(e)) return;

    auto& GO = R.get<transform::GameObject>(e);
    GO.state.isBeingDragged = true;

    if (auto* cc = R.try_get<physics::ColliderComponent>(e)) {
        auto& cfg = R.get_or_emplace<PhysicsSyncConfig>(e);

        // Remember original type so we can restore later
        cfg.prevType = cpBodyGetType(cc->body.get());

        // Stop all motion and freeze rotation
        cpBodySetVelocity(cc->body.get(), cpvzero);
        cpBodySetAngularVelocity(cc->body.get(), 0.f);

        // Make body kinematic for precise cursor control
        cpBodySetType(cc->body.get(), CP_BODY_TYPE_KINEMATIC);

        // Transform is authoritative while dragging
        cfg.mode = PhysicsSyncMode::AuthoritativeTransform;
        cfg.useVisualRotationWhenDragging = true;
        cfg.pushAngleFromTransform = true;
        cfg.pullAngleFromPhysics = false;

        // Optional: lock rotation if TransformFixed
        SetBodyRotationLocked(R, e,
            cfg.rotMode == RotationSyncMode::TransformFixed_PhysicsFollows);
    }
}


    inline void OnDrop(entt::registry& R, entt::entity e) {
    if (!R.valid(e)) return;

    auto& GO = R.get<transform::GameObject>(e);
    GO.state.isBeingDragged = false;

    if (auto* cc = R.try_get<physics::ColliderComponent>(e)) {
        auto& cfg = R.get_or_emplace<PhysicsSyncConfig>(e);

        // Stop residual velocity from kinematic dragging
        cpBodySetVelocity(cc->body.get(), cpvzero);
        cpBodySetAngularVelocity(cc->body.get(), 0.f);

        // Restore the previous body type (don’t hardcode to dynamic)
        cpBodySetType(cc->body.get(), cfg.prevType);

        // If we were frozen or static, don't hand control to physics immediately
        if (cfg.prevType == CP_BODY_TYPE_DYNAMIC) {
            // Soft settle: follow visual for a few frames before re-entering physics
            cfg.mode = PhysicsSyncMode::FollowVisual;
            cfg.useKinematic = true;  // use kinematic follow for clean interpolation
        } else {
            // e.g. static or sensor — just restore
            cfg.mode = PhysicsSyncMode::AuthoritativePhysics;
        }

        // Rotation policy restoration
        if (cfg.rotMode == RotationSyncMode::TransformFixed_PhysicsFollows) {
            SetBodyRotationLocked(R, e, true);
            auto& T = R.get<transform::Transform>(e);
            cpBodySetAngle(cc->body.get(), T.getActualRotation() * DEG2RAD);
            cpBodySetAngularVelocity(cc->body.get(), 0.f);
        } else {
            SetBodyRotationLocked(R, e, false);
        }
    }
}

    

/* ------------------------ transform-dominant phase ------------------------ */
    inline void ApplyAuthoritativeTransform(entt::registry& R, PhysicsManager& PM) {
        auto view = R.view<transform::Transform, physics::ColliderComponent, PhysicsSyncConfig, PhysicsWorldRef>();
        for (auto e : view) {
            auto& cfg = view.get<PhysicsSyncConfig>(e);
            if (cfg.mode != PhysicsSyncMode::AuthoritativeTransform) continue;

            auto& ref = view.get<PhysicsWorldRef>(e);
            if (auto* rec = PM.get(ref.name); rec && PhysicsManager::world_active(*rec)) {
                TransformToBody(R, e, *rec->w, /*zeroVel=*/true, /*useVisualRotation=*/cfg.useVisualRotationWhenDragging && cfg.pushAngleFromTransform);
            }
            EnforceRotationPolicy(R, e); // cheap, idempotent
        }
        
    }

    
/* ------------------------ physics-dominant phase ------------------------- */
    inline void ApplyAuthoritativePhysics(entt::registry& R, PhysicsManager& PM, float alpha = 1.0f) {
        auto view = R.view<transform::Transform, physics::ColliderComponent, PhysicsSyncConfig, PhysicsWorldRef>();
        for (auto e : view) {
            auto& cfg = view.get<PhysicsSyncConfig>(e);
            if (cfg.mode != PhysicsSyncMode::AuthoritativePhysics) continue;

            auto& ref = view.get<PhysicsWorldRef>(e);
            if (auto* rec = PM.get(ref.name); rec && PhysicsManager::world_active(*rec)) {
                BodyToTransform(R, e, *rec->w, alpha);
            }
            EnforceRotationPolicy(R, e); // cheap, idempotent
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
