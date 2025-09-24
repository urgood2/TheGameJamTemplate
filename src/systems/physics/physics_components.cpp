#include "physics_components.hpp"

#include "physics_world.hpp"



namespace physics {
    
    // --- LuaArbiter methods (put in a cpp next to PhysicsWorld.cpp) ---
    std::pair<entt::entity, entt::entity> LuaArbiter::entities() const {
        cpShape *sa, *sb;
        cpArbiterGetShapes(arb, &sa, &sb);

        auto getE = [](cpShape* s) -> entt::entity {
            if (void* ud = cpShapeGetUserData(s)) {
                return static_cast<entt::entity>(reinterpret_cast<uintptr_t>(ud));
            }
            // Return a valid entt::entity that represents null:
            return entt::entity{entt::null}; // or: static_cast<entt::entity>(entt::null)
        };

        return { getE(sa), getE(sb) };
    }

    std::pair<std::string, std::string> LuaArbiter::tags(PhysicsWorld& W) const {
        cpShape *sa, *sb;
        cpArbiterGetShapes(arb, &sa, &sb);
        auto fA = cpShapeGetFilter(sa);
        auto fB = cpShapeGetFilter(sb);
        return { W.GetTagFromCategory(int(fA.categories)),
                W.GetTagFromCategory(int(fB.categories)) };
    }

    cpVect LuaArbiter::normal() const { return cpArbiterGetNormal(arb); }

    float LuaArbiter::total_impulse_length() const {
        cpVect J = cpArbiterTotalImpulse(arb);
        return cpvlength(J);
    }
    cpVect LuaArbiter::total_impulse() const { return cpArbiterTotalImpulse(arb); }

    void LuaArbiter::set_friction(float f)   const { cpArbiterSetFriction(arb, f); }
    void LuaArbiter::set_elasticity(float e) const { cpArbiterSetRestitution(arb, e); }
    void LuaArbiter::set_surface_velocity(float vx, float vy) const {
        cpArbiterSetSurfaceVelocity(arb, cpv(vx, vy));
    }
    void LuaArbiter::ignore() const { cpArbiterIgnore(arb); }

}