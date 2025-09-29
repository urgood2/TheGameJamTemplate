#include "transform_physics_hook.hpp"


namespace physics {
    void SetBodyRotationLocked(entt::registry& R, entt::entity e, bool lock) {
        auto& CC = R.get<physics::ColliderComponent>(e);
        auto* body = CC.body.get();
        if (!body) return;

        if (lock) {
            cpBodySetAngularVelocity(body, 0.0f);
            cpBodySetMoment(body, INFINITY); // cannot rotate
        } else {
            // Restore a finite moment based on current size/shape
            auto& T = R.get<transform::Transform>(e);
            cpFloat mass = cpBodyGetMass(body);
            if (mass <= 0.0f) mass = 1.0f;
            cpFloat moment = ComputeMoment(
                physics::PhysicsCreateInfo{CC.shapeType, CC.tag, CC.isSensor, 1.0f},
                mass, std::max(1.f, T.getActualW()), std::max(1.f, T.getActualH())
            );
            cpBodySetMoment(body, moment);
        }
    }

}