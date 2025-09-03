#pragma once

#include "physics_manager.hpp"

namespace physics {
    
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
    
    // gate on both entity state and physics world active state before syncing/updating.
    void SyncPhysicsToTransform(entt::registry& R, PhysicsManager& PM) {
        auto view = R.view<physics::ColliderComponent, PhysicsWorldRef, PhysicsSyncConfig/*, Transform*/>();

        for (auto e : view) {
            auto& cc   = view.get<physics::ColliderComponent>(e);
            auto& ref  = view.get<PhysicsWorldRef>(e);
            auto& cfg  = view.get<PhysicsSyncConfig>(e);

            const bool entOn   = is_entity_state_active(R, e);
            const bool worldOn = worldActive(PM, ref.name);

            if (entOn && worldOn) {
                // Normal: physics drives Transform
                // read cpBody and write Transform here
                continue;
            }

            // Desynced: pick behavior
            switch (cfg.mode) {
            case PhysicsSyncMode::AuthoritativePhysics:
                // Let body keep simulating, don’t touch Transform.
                // Optional: hide/render-as-ghost if you dislike divergence.
                break;
            case PhysicsSyncMode::AuthoritativeTransform:
                // Keep body in lockstep with (possibly static) Transform so no divergence accumulates.
                // Example:
                //   auto pos = TransformToChipmunk(R, e);
                //   cpBodySetPosition(cc.body.get(), pos);
                //   cpBodySetAngle(cc.body.get(), angleFromTransform);
                break;
            case PhysicsSyncMode::FrozenWhileDesynced:
                // Pause body so it won’t drift while Transform is gated.
                cpBodySleep(cc.body.get());
                // (When the pair re-syncs below, Chipmunk will wake.)
                break;
            }
        }
    }


}