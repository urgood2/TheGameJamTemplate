// NavmeshBuild.hpp
#pragma once
#include <vector>
#include <cmath>
#include "third_party/chipmunk/include/chipmunk/chipmunk.h"
#include "path_finder.h"
#include "systems/physics/physics_components.hpp"
#include "navmesh_components.hpp"

namespace navmesh_build {

struct Poly {
    std::vector<NavMesh::Point> pts;
};

inline void add_poly(std::vector<NavMesh::Polygon>& out, const Poly& src) {
    if (src.pts.size() >= 3) {
        NavMesh::Polygon p;
        for (auto& q : src.pts) p.AddPoint(q.x, q.y);
        out.emplace_back(std::move(p));
    }
}

inline Poly rect_from_box(cpBody* body, float hw, float hh) {
    // Chipmunk body transform
    const cpVect c = cpBodyGetPosition(body);
    const cpFloat a = cpBodyGetAngle(body);
    const cpFloat ca = std::cos(a), sa = std::sin(a);

    auto X = [&](float x, float y){ return c.x + x*ca - y*sa; };
    auto Y = [&](float x, float y){ return c.y + x*sa + y*ca; };

    Poly poly;
    poly.pts.reserve(4);
    poly.pts.push_back({X(-hw, -hh), Y(-hw, -hh)});
    poly.pts.push_back({X( hw, -hh), Y( hw, -hh)});
    poly.pts.push_back({X( hw,  hh), Y( hw,  hh)});
    poly.pts.push_back({X(-hw,  hh), Y(-hw,  hh)});
    return poly;
}

inline Poly poly_from_circle(cpBody* body, float r, const NavmeshWorldConfig& cfg) {
    // segment count based on circumference / tol
    const float circ = 2.0f*3.14159265f*r;
    int segs = std::max(cfg.circle_min_segments,
                std::min(cfg.circle_max_segments, int(std::ceil(circ / cfg.circle_tol))));
    const cpVect c = cpBodyGetPosition(body);

    Poly poly;
    poly.pts.reserve(segs);
    for (int i=0;i<segs;i++) {
        float t = (float(i)/segs) * 2.0f*3.14159265f;
        poly.pts.push_back({ c.x + r*std::cos(t), c.y + r*std::sin(t) });
    }
    return poly;
}

// Expand a thin segment into a capsule-ish quad with radius r.
inline Poly quad_from_segment(cpBody* body, cpVect a, cpVect b, float r) {
    // Transform into world
    const cpTransform T = cpBodyGetTransform(body);
    a = cpTransformPoint(T, a);
    b = cpTransformPoint(T, b);

    // perp unit
    cpVect d = cpvsub(b, a);
    float len = cpvlength(d);
    if (len <= 1e-5f) len = 1.0f;
    cpVect n = { -d.y/len, d.x/len };

    Poly poly;
    poly.pts.reserve(4);
    poly.pts.push_back({ a.x + n.x*r, a.y + n.y*r });
    poly.pts.push_back({ b.x + n.x*r, b.y + n.y*r });
    poly.pts.push_back({ b.x - n.x*r, b.y - n.y*r });
    poly.pts.push_back({ a.x - n.x*r, a.y - n.y*r });
    return poly;
}

inline Poly poly_from_cp_polyshape(cpBody* body, const cpPolyShape* ps) {
    Poly poly;
    const int count = cpPolyShapeGetCount(ps);
    poly.pts.reserve(count);
    const cpTransform T = cpBodyGetTransform(body);
    for (int i=0;i<count;i++){
        cpVect v = cpPolyShapeGetVert(ps, i);
        v = cpTransformPoint(T, v);
        poly.pts.push_back({v.x, v.y});
    }
    return poly;
}

// Convert a ColliderComponent* to one or more polygon obstacles.
inline void collider_to_polys(const physics::ColliderComponent& C,
                              std::vector<NavMesh::Polygon>& out,
                              const NavmeshWorldConfig& cfg)
{
    if (!C.shape) return;

    cpShape* s = C.shape.get();
    cpBody*  b = cpShapeGetBody(s);

    switch (C.shapeType) {
        case physics::ColliderShapeType::Rectangle: {
            // Expect width/height in your component, else derive from poly shape BB
            // If you only have a poly shape: branch to poly path.
            if (cpShapeGetClass(s) == cpPolyShapeGetClass()) {
                add_poly(out, poly_from_cp_polyshape(b, reinterpret_cast<cpPolyShape*>(s)));
            } else {
                // Fallback: use BB (axis-aligned in world). Better to store half-extents on your side.
                cpBB bb = cpShapeGetBB(s);
                float hw = (bb.r - bb.l)*0.5f;
                float hh = (bb.t - bb.b)*0.5f;
                add_poly(out, rect_from_box(b, hw, hh));
            }
        } break;

        case physics::ColliderShapeType::Circle: {
            const cpCircleShape* cs = reinterpret_cast<const cpCircleShape*>(s);
            float r = (float)cpCircleShapeGetRadius(cs);
            add_poly(out, poly_from_circle(b, r, cfg));
        } break;

        case physics::ColliderShapeType::Segment: {
            const cpSegmentShape* sg = reinterpret_cast<const cpSegmentShape*>(s);
            cpVect a = cpSegmentShapeGetA(sg);
            cpVect b = cpSegmentShapeGetB(sg);
            float r  = (float)cpSegmentShapeGetRadius(sg);
            add_poly(out, quad_from_segment(b, a, b, std::max(r, 1.0f))); // widen at least 1px
        } break;

        case physics::ColliderShapeType::Polygon:
        case physics::ColliderShapeType::Chain: {
            if (cpShapeGetClass(s) == cpPolyShapeGetClass()) {
                add_poly(out, poly_from_cp_polyshape(b, reinterpret_cast<const cpPolyShape*>(s)));
            }
        } break;
    }
}

} // namespace navmesh_build
