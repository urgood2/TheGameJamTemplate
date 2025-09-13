// bind_world_navmesh.cpp
#include <sol/sol.hpp>
#include "physics_manager.hpp"

static inline NavMesh::Point toPt(const sol::object& o) {
    if (o.is<NavMesh::Point>()) return o.as<NavMesh::Point>();
    sol::table t = o.as<sol::table>();
    float x = t["x"].valid() ? float(t["x"].get<double>()) : float(t.get<double>(1));
    float y = t["y"].valid() ? float(t["y"].get<double>()) : float(t.get<double>(2));
    return {(int)x,(int)y};
}

void inline register_world_navmesh(sol::state& L, PhysicsManager& PM) {
    L.new_usertype<NavmeshWorldConfig>("NavmeshWorldConfig",
        "default_inflate_px", &NavmeshWorldConfig::default_inflate_px,
        "circle_tol", &NavmeshWorldConfig::circle_tol,
        "circle_min_segments", &NavmeshWorldConfig::circle_min_segments,
        "circle_max_segments", &NavmeshWorldConfig::circle_max_segments
    );

    // Manager-level functions
    L.set_function("navmesh_mark_dirty", [&PM](const std::string& world){
        PM.markNavmeshDirty(world);
    });

    L.set_function("navmesh_rebuild", [&PM](const std::string& world){
        PM.rebuildNavmeshFor(world);
    });

    L.set_function("navmesh_find_path", [&PM](const std::string& world, const sol::object& a, const sol::object& b, sol::this_state s){
        auto src = toPt(a), dst = toPt(b);
        auto path = PM.findPath(world, src, dst);
        sol::state_view lua{s};
        sol::table arr = lua.create_table(int(path.size()), 0);
        int i=1; for (auto& p : path) { sol::table t = lua.create_table(); t["x"]=p.x; t["y"]=p.y; arr[i++]=t; }
        return arr;
    });

    L.set_function("navmesh_vision_fan", [&PM](const std::string& world, const sol::object& a, float radius, sol::this_state s){
        auto src = toPt(a);
        auto poly = PM.visionFan(world, src, radius);
        sol::state_view lua{s};
        sol::table arr = lua.create_table(int(poly.size()), 0);
        int i=1; for (auto& p : poly) { sol::table t = lua.create_table(); t["x"]=p.x; t["y"]=p.y; arr[i++]=t; }
        return arr;
    });

    // Per-world config access
    L.set_function("navmesh_get_config", [&PM](const std::string& world) -> NavmeshWorldConfig* {
        auto* rec = PM.get(world);
        if (!rec || !rec->nav) return nullptr;
        return &rec->nav->config;
    });

    // Entity-level toggle
    L.new_usertype<NavmeshObstacle>("NavmeshObstacle",
        "include", &NavmeshObstacle::include,
        "inflate_pixels", &NavmeshObstacle::inflate_pixels
    );
}