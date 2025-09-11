// bind_navmesh.cpp
#include <sol/sol.hpp>
#include <vector>
#include <stdexcept>
#include "path_finder.h"   // adjust to the actual headers
#include "cone_of_vision.h" // ditto

// Helpers: parse Lua tables into the library types ---------------------------------
static inline auto to_point(const sol::object& o) -> NavMesh::Point {
    if (o.is<NavMesh::Point>()) return o.as<NavMesh::Point>();

    if (o.is<sol::table>()) {
        sol::table t = o.as<sol::table>();
        // Accept {x=.., y=..} or { .. , .. }
        if (t["x"].valid() && t["y"].valid()) {
            return NavMesh::Point(float(t["x"].get<double>()), float(t["y"].get<double>()));
        } else {
            auto x = t.get<double>(1);
            auto y = t.get<double>(2);
            return NavMesh::Point(float(x), float(y));
        }
    }
    throw std::runtime_error("Expected Point or {x,y} table");
}

static inline auto to_polygon(const sol::object& o) -> NavMesh::Polygon {
    if (o.is<NavMesh::Polygon>()) return o.as<NavMesh::Polygon>();

    // Accept { {x,y}, {x,y}, ... }
    if (o.is<sol::table>()) {
        NavMesh::Polygon poly;
        sol::table arr = o.as<sol::table>();
        for (auto&& kv : arr) {
            sol::object v = kv.second;
            auto p = to_point(v);
            poly.AddPoint(p.x, p.y);
        }
        return poly;
    }
    throw std::runtime_error("Expected Polygon or array of points");
}

static inline auto to_point_vec(const sol::object& o) -> std::vector<NavMesh::Point> {
    if (o.is<std::vector<NavMesh::Point>>()) return o.as<std::vector<NavMesh::Point>>();

    std::vector<NavMesh::Point> out;
    if (o.is<sol::table>()) {
        sol::table arr = o.as<sol::table>();
        out.reserve(arr.size());
        for (auto&& kv : arr) {
            out.emplace_back(to_point(kv.second));
        }
        return out;
    }
    throw std::runtime_error("Expected array of points");
}

static inline auto to_polygon_vec(const sol::object& o) -> std::vector<NavMesh::Polygon> {
    if (o.is<std::vector<NavMesh::Polygon>>()) return o.as<std::vector<NavMesh::Polygon>>();

    std::vector<NavMesh::Polygon> out;
    if (o.is<sol::table>()) {
        sol::table arr = o.as<sol::table>();
        out.reserve(arr.size());
        for (auto&& kv : arr) {
            out.emplace_back(to_polygon(kv.second));
        }
        return out;
    }
    throw std::runtime_error("Expected array of polygons");
}

// Public API ----------------------------------------------------------------------
auto inline register_navmesh(sol::state& lua) -> void {
    using namespace NavMesh;

    // Point
    lua.new_usertype<Point>("Point",
        sol::constructors<Point(float,float)>(),
        "x", &Point::x,
        "y", &Point::y
    );

    // Polygon
    lua.new_usertype<Polygon>("Polygon",
        sol::constructors<Polygon()>(),
        "add_point", [](Polygon& self, float x, float y) { self.AddPoint(x, y); },
        // convenience: add_point({x,y})
        "add_point_tbl", [](Polygon& self, const sol::object& o) {
            auto p = to_point(o);
            self.AddPoint(p.x, p.y);
        }
    );

    // PathFinder
    lua.new_usertype<PathFinder>("PathFinder",
        sol::constructors<PathFinder()>(),
        // AddPolygons(polys, inflate_pixels)
        "add_polygons", [](PathFinder& self, const sol::object& polys, sol::optional<int> inflate) {
            auto vec = to_polygon_vec(polys);
            self.AddPolygons(vec, inflate.value_or(0));
        },
        // AddExternalPoints({p1, p2, ...})
        "add_external_points", [](PathFinder& self, const sol::object& pts) {
            self.AddExternalPoints(to_point_vec(pts));
        },
        // GetPath(src, dst) -> { {x,y}, ... }
        "get_path", [](PathFinder& self, const sol::object& src_o, const sol::object& dst_o) {
            auto src = to_point(src_o);
            auto dst = to_point(dst_o);
            return self.GetPath(src, dst); // std::vector<Point> (Sol2 auto-converts to array of userdata if bound)
        }
    );

    // ConeOfVision
    lua.new_usertype<ConeOfVision>("ConeOfVision",
        sol::constructors<ConeOfVision()>(),
        "add_polygons", [](ConeOfVision& self, const sol::object& polys) {
            self.AddPolygons(to_polygon_vec(polys));
        },
        "get_vision", [](ConeOfVision& self, const sol::object& src_o, float radius) {
            auto src = to_point(src_o);
            return self.GetVision(src, radius);
        }
    );

    // Quality-of-life constructors from tables
    lua.set_function("PointFrom", [](const sol::object& o) { return to_point(o); });
    lua.set_function("PolygonFrom", [](const sol::object& o) { return to_polygon(o); });
}