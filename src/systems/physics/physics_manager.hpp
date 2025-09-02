#pragma once
#include "physics_world.hpp"
#include "systems/entity_gamestate_management/entity_gamestate_management.hpp"
#include "core/globals.hpp"

class PhysicsManager {
public:
    struct WorldRec {
        std::shared_ptr<physics::PhysicsWorld> w;
        std::string name;
        std::size_t name_hash;
        bool step_enabled = true;       // manual toggle
        bool draw_debug   = false;      // manual toggle
        std::optional<WorldStateBinding> state; // optional state binding
    };

    explicit PhysicsManager(entt::registry& R) : R(R) {}

    void add(const std::string& name,
             std::shared_ptr<physics::PhysicsWorld> world,
             std::optional<std::string> bindsToState = std::nullopt)
    {
        WorldRec rec;
        rec.w         = std::move(world);
        rec.name      = name;
        rec.name_hash = std::hash<std::string>{}(name);
        if (bindsToState) rec.state = WorldStateBinding{*bindsToState};
        worlds[rec.name_hash] = std::move(rec);
    }

    WorldRec* get(const std::string& name) {
        auto it = worlds.find(std::hash<std::string>{}(name));
        return (it==worlds.end()) ? nullptr : &it->second;
    }

    void enableStep(const std::string& name, bool on) { if (auto* r = get(name)) r->step_enabled = on; }
    void enableDebugDraw(const std::string& name, bool on) { if (auto* r = get(name)) r->draw_debug = on; }

    // True if manual toggle is on AND (no state binding OR bound state is active).
    static bool world_active(const WorldRec& rec) {
        if (!rec.step_enabled) return false;
        if (!rec.state) return true;
        return entity_gamestate_management::active_states_instance()
               .active_hashes.count(rec.state->state_hash) > 0;
    }

    void stepAll(float dt) {
        for (auto& [_, rec] : worlds) {
            if (!world_active(rec)) continue;
            rec.w->Update(dt);
            rec.w->PostUpdate();
        }
    }

    void drawAll() {
        for (auto& [_, rec] : worlds) {
            // draw only when world is active AND requested
            if (!world_active(rec) || !rec.draw_debug) continue;
            rec.w->RenderColliders(); // or your ChipmunkDebugDraw wrapper
        }
    }

    // Move an entity's body/shape to another world (safe migration)
    void moveEntityToWorld(entt::entity e, const std::string& dst) {
        auto dstRec = get(dst);
        if (!dstRec) return;

        auto& cc = R.get<physics::ColliderComponent>(e);
        if (auto srcSpace = cc.shape ? cpShapeGetSpace(cc.shape.get()) : nullptr) {
            // remove from old
            cpSpaceRemoveShape(srcSpace, cc.shape.get());
            cpSpaceRemoveBody (srcSpace, cc.body.get());
        }
        // add to new
        cpSpaceAddBody (dstRec->w->space, cc.body.get());
        cpSpaceAddShape(dstRec->w->space, cc.shape.get());

        R.emplace_or_replace<PhysicsWorldRef>(e, dst);
    }

private:
    entt::registry& R;
    std::unordered_map<std::size_t, WorldRec> worlds;
};