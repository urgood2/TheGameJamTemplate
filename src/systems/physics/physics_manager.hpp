#pragma once
#include "physics_world.hpp"
#include "systems/entity_gamestate_management/entity_gamestate_management.hpp"
#include "core/globals.hpp"
#include "steering.hpp"

#include "third_party/navmesh/source/path_finder.h"
#include "third_party/navmesh/source/cone_of_vision.h"
#include "third_party/navmesh/source/navmesh_components.hpp"
#include "third_party/navmesh/source/navmesh_build.hpp"
#include "third_party/navmesh/source/pointf.h"

class PhysicsManager {
public:

    struct NavmeshCache {
        NavMesh::PathFinder pf;   // rebuilt when dirty
        bool dirty = true;
        NavmeshWorldConfig config; // per-world knobs
    };

    struct WorldRec {
        std::shared_ptr<physics::PhysicsWorld> w;
        std::string name;
        std::size_t name_hash;
        bool step_enabled = true;       // manual toggle
        bool draw_debug   = false;      // manual toggle
        std::optional<WorldStateBinding> state; // optional state binding
        
        std::unique_ptr<NavmeshCache> nav; // <-- add this
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
        rec.nav = std::make_unique<NavmeshCache>(); // default config; tweak later if needed
        worlds[rec.name_hash] = std::move(rec);
    }
    
    // navmesh helper
    NavmeshCache* nav_of(const std::string& name) {
        auto* wr = get(name);
        return (wr && wr->nav) ? wr->nav.get() : nullptr;
    }
    
    // navmesh helper
    void markNavmeshDirty(const std::string& name) {
        if (auto* n = nav_of(name)) n->dirty = true;
    }
    
    void clearAllWorlds() {
        for (auto& [h, rec] : worlds) {
            rec.w->ClearLuaRefs();
            rec.w.reset();
        }
        worlds.clear();
    }
    
    void clearLuaRefsInAllWorlds() {
        for (auto& [id, world] : worlds)
            if (world.w) world.w->ClearLuaRefs();
    }

    
    void rebuildNavmeshFor(const std::string& worldName) {
        auto* rec = get(worldName);
        if (!rec || !rec->nav) return;

        auto& W  = *rec->w;
        auto& N  = *rec->nav;
        N.pf = NavMesh::PathFinder(); // reset
        std::vector<NavMesh::Polygon> obstacles;
        obstacles.reserve(256);

        const auto& cfg = N.config;
        auto view = R.view<physics::ColliderComponent>(/* optionally also PhysicsWorldRef to filter */);

        for (auto e : view) {
            const auto& C = view.get<physics::ColliderComponent>(e);

            // Decide inclusion
            bool include = false;
            if (auto nav = R.try_get<NavmeshObstacle>(e)) {
                include = nav->include;
            } else {
                // default policy: static & !sensor
                include = (!C.isDynamic) && (!C.isSensor);
            }
            if (!include) continue;

            // Convert to polygons
            navmesh_build::collider_to_polys(C, obstacles, N.config);
        }

        // (Optional) you can also add screen bounds as obstacles by pushing a big outer rect and subtracting inner play area if needed.

        // Inflate in one go (the lib inflates internally per polygon call; we pass per-call value)
        const int inflate = N.config.default_inflate_px;
        N.pf.AddPolygons(obstacles, inflate);

        // If you have “external points” you always query, you can add them up-front, or let callers add per-path.
        N.dirty = false;
    }
    
    // cheap lazy rebuild before queries
    NavMesh::PathFinder* ensurePathFinder(const std::string& worldName) {
        auto* rec = get(worldName);
        if (!rec || !rec->nav) return nullptr;
        if (rec->nav->dirty) rebuildNavmeshFor(worldName);
        return &rec->nav->pf;
    }
    
    std::vector<NavMesh::Point> findPath(const std::string& world,
                                     const NavMesh::Point& src,
                                     const NavMesh::Point& dst)
    {
        if (auto* pf = ensurePathFinder(world)) {
            pf->AddExternalPoints({src, dst}); // optional; not strictly required every time if you don’t use portals
            return pf->GetPath(src, dst);
        }
        return {};
    }

    std::vector<NavMesh::PointF> visionFan(const std::string& world,
                                        const NavMesh::Point& src,
                                        float radius)
    {
        auto* rec = get(world);
        if (!rec || !rec->nav) return {};
        if (rec->nav->dirty) rebuildNavmeshFor(world);

        NavMesh::ConeOfVision cov;
        // reuse the same obstacle set you used to build NavMesh::PathFinder:
        // easiest: re-run conversion (cheap) or cache the last vector if you want.
        // Here, re-run:
        std::vector<NavMesh::Polygon> obstacles;
        auto view = R.view<physics::ColliderComponent>();
        for (auto e : view) {
            const auto& C = view.get<physics::ColliderComponent>(e);
            bool include = false;
            if (auto nav = R.try_get<NavmeshObstacle>(e)) include = nav->include;
            else include = (!C.isDynamic) && (!C.isSensor);
            if (!include) continue;
            navmesh_build::collider_to_polys(C, obstacles, rec->nav->config);
        }
        cov.AddPolygons(obstacles);
        return cov.GetVision(src, radius);
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
        // 0) Precompute which worlds are active this frame
        std::unordered_set<std::size_t> active;
        active.reserve(worlds.size());
        for (auto& [h, rec] : worlds) {
            if (world_active(rec)) active.insert(h);
        }

        // 1) Apply steering ONLY for agents whose world is active
        //    (requires PhysicsWorldRef on the entity)
        auto view = R.view<SteerableComponent, PhysicsWorldRef>();
        for (auto e : view) {
            const auto& ref = view.get<PhysicsWorldRef>(e);
            const auto h = std::hash<std::string>{}(ref.name);
            if (active.find(h) == active.end()) {
                continue; // world missing or inactive -> skip steering this frame
            }
            // Steering::Update(R, e, dt);
        }

        // 2) Step only active worlds
        for (auto& [h, rec] : worlds) {
            if (active.find(h) == active.end()) continue;
            rec.w->Update(dt);
        }
    }
    
    // call after all game logic at the end of the frame
    void stepAllPostUpdate(float dt) {
        // 0) Precompute which worlds are active this frame
        std::unordered_set<std::size_t> active;
        active.reserve(worlds.size());
        for (auto& [h, rec] : worlds) {
            if (world_active(rec)) active.insert(h);
        }

        // 2) Step only active worlds
        for (auto& [h, rec] : worlds) {
            if (active.find(h) == active.end()) continue;
            rec.w->PostUpdate();
        }
    }

    void drawAll() {
        // for (auto& [_, rec] : worlds) {
        //     // draw only when world is active AND requested
        //     if (!world_active(rec) || !rec.draw_debug) continue;
        //     rec.w->RenderColliders(); // or your ChipmunkDebugDraw wrapper
        // }
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
    
    entt::registry& R;

private:
    
    std::unordered_map<std::size_t, WorldRec> worlds;
};