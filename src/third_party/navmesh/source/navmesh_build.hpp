// NavmeshBuild.hpp
#pragma once
#include <vector>
#include <cmath>
#include "third_party/chipmunk/include/chipmunk/chipmunk.h"
#include "path_finder.h"
#include "systems/physics/physics_components.hpp"
#include "systems/physics/physics_world.hpp"
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

    auto X = [&](float x, float y){ return static_cast<int>(c.x + x*ca - y*sa); };
    auto Y = [&](float x, float y){ return static_cast<int>(c.y + x*sa + y*ca); };

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
        poly.pts.push_back({ static_cast<int>(c.x + r*std::cos(t)), static_cast<int>(c.y + r*std::sin(t)) });
    }
    return poly;
}


// Expand a thin segment into a quad in *world* space (already transformed)
inline Poly quad_from_segment_world(cpVect aW, cpVect bW, float r) {
    cpVect d   = cpvsub(bW, aW);
    float len  = cpvlength(d);
    if (len <= 1e-5f) len = 1.0f;
    cpVect n   = { -d.y/len, d.x/len };

    Poly poly;
    poly.pts.reserve(4);
    poly.pts.push_back({ static_cast<int>( aW.x + n.x*r), static_cast<int>(aW.y + n.y*r) });
    poly.pts.push_back({ static_cast<int>(bW.x + n.x*r), static_cast<int>(bW.y + n.y*r) });
    poly.pts.push_back({ static_cast<int>(bW.x - n.x*r), static_cast<int>(bW.y - n.y*r) });
    poly.pts.push_back({ static_cast<int>(aW.x - n.x*r), static_cast<int>(aW.y - n.y*r) });
    return poly;
}

// cpPolyShape → polygon (verts are body-local; transform via cpBodyLocalToWorld)
inline Poly poly_from_cp_polyshape(cpBody* body, const cpShape* ps) {
    Poly poly;
    const int count = cpPolyShapeGetCount(ps);               // (const cpShape*)
    poly.pts.reserve(count);
    for (int i = 0; i < count; ++i) {
        cpVect vL = cpPolyShapeGetVert(ps, i);              // local
        cpVect vW = cpBodyLocalToWorld(body, vL);           // world
        poly.pts.push_back({ static_cast<int>(vW.x), static_cast<int>(vW.y) });
    }
    return poly;
}

// Circle (center offset is body-local; transform via cpBodyLocalToWorld)
inline Poly poly_from_circle(cpBody* body, const cpShape* s, float tol, int minSeg, int maxSeg) {
    const float r = (float)cpCircleShapeGetRadius(s);        // (const cpShape*)
    cpVect  offL  = cpCircleShapeGetOffset(s);               // local center
    cpVect  cW    = cpBodyLocalToWorld(body, offL);          // world center

    // segments from circumference/tolerance
    const float circ = 2.0f * 3.14159265358979323846f * r;
    int segs = std::max(minSeg, std::min(maxSeg, (int)std::ceil(circ / std::max(tol, 1e-3f))));

    Poly poly;
    poly.pts.reserve(segs);
    for (int i = 0; i < segs; ++i) {
        float t = (float(i) / segs) * (2.0f * 3.14159265358979323846f);
        poly.pts.push_back({ static_cast<int>(cW.x + r * std::cos(t)), static_cast<int>(cW.y + r * std::sin(t)) });
    }
    return poly;
}

// ---- main converter ----------------------------------------------------------

inline void collider_to_polys(const physics::ColliderComponent& C,
                              std::vector<NavMesh::Polygon>& out,
                              const NavmeshWorldConfig& cfg)
{
    if (!C.shape) return;

    const cpShape* s = C.shape.get();
    cpBody*        b = cpShapeGetBody(s);

    switch (C.shapeType) {

        case physics::ColliderShapeType::Rectangle: {
            // Prefer poly-shape rectangles if that’s how you build them.
            // We can’t detect a “class”, so just try poly API; if it’s not a poly,
            // fall back to BB (axis-aligned in world).
            if (cpPolyShapeGetCount(s) > 0) {
                add_poly(out, poly_from_cp_polyshape(b, s));
            } else {
                // Fallback: AABB in world (loses rotation, but safe fallback)
                cpBB bb = cpShapeGetBB(s);
                Poly poly;
                poly.pts.reserve(4);
                poly.pts.push_back({ static_cast<int>((float)bb.l), static_cast<int>((float)bb.b) });
                poly.pts.push_back({ static_cast<int>((float)bb.r), static_cast<int>((float)bb.b) });
                poly.pts.push_back({ static_cast<int>((float)bb.r), static_cast<int>((float)bb.t) });
                poly.pts.push_back({ static_cast<int>((float)bb.l), static_cast<int>((float)bb.t) });
                add_poly(out, poly);
            }
        } break;

        case physics::ColliderShapeType::Circle: {
            add_poly(out, poly_from_circle(b, s, cfg.circle_tol, cfg.circle_min_segments, cfg.circle_max_segments));
        } break;

        case physics::ColliderShapeType::Segment: {
            // A/B are local; transform to world then inflate
            cpVect aL = cpSegmentShapeGetA(s);
            cpVect bL = cpSegmentShapeGetB(s);
            float  r  = (float)cpSegmentShapeGetRadius(s);
            cpVect aW = cpBodyLocalToWorld(b, aL);
            cpVect bW = cpBodyLocalToWorld(b, bL);
            add_poly(out, quad_from_segment_world(aW, bW, std::max(r, 1.0f)));
        } break;

        case physics::ColliderShapeType::Polygon:
        case physics::ColliderShapeType::Chain: {
            // If it’s actually a poly shape, this works; otherwise ignore.
            if (cpPolyShapeGetCount(s) > 0) {
                add_poly(out, poly_from_cp_polyshape(b, s));
            }
        } break;
    }
}

} // namespace navmesh_build
