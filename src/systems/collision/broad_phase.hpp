#pragma once

#include <unordered_map>
#include <vector>
#include <utility>
#include <cmath>
#include <array>
#include <entt/entt.hpp>
#include <variant>

#include "systems/transform/transform_functions.hpp"
#include "systems/transform/transform.hpp"
#include "util/common_headers.hpp"
#include "core/globals.hpp"


namespace collision {
    
    using namespace transform; // for Transform, GameObject, etc


    
    struct ScreenSpaceCollisionMarker {}; // for the ui quadtree. anything thatd doesn't have this is preusmed world space. REmove it from ui if the ui should share collision checking with the world space quadtree.

    
    // shape tags:
    enum class ColliderType { AABB, Circle /*, Capsule, Polygon…*/ };

    struct ColliderComponent {
        ColliderType type;
    };

    
    // 1) create_collider(shapeTag)
    //   - creates a new entity
    //   - auto-creates its Transform (using your existing helper)
    //   - emplaces a GameObject with collisionEnabled=true
    //   - emplaces a ColliderComponent with default data
    //
    
    inline entt::entity create_collider_for_entity(entt::entity master, ColliderType type, sol::table t) {
        
        // unpack the offsets:
        float ox = t.get_or("offsetX", 0.f);
        float oy = t.get_or("offsetY", 0.f);
        float w = t.get_or("width", 1.f);
        float h = t.get_or("height", 1.f);
        float rotation = t.get_or("rotation", 0.f);
        float scale = t.get_or("scale", 1.f);
        
        // **NEW**: read alignment flags (default NONE)
        int alignment = t.get_or("alignment", InheritedProperties::Alignment::NONE);
        
        // **NEW**: optional fine-tune offsets in a sub-table
        float alignOffX = 0.f, alignOffY = 0.f;
        if (t["alignOffset"].valid() && t["alignOffset"].get_type() == sol::type::table) {
            sol::table ao = t["alignOffset"];
            alignOffX = ao.get_or("x", 0.f);
            alignOffY = ao.get_or("y", 0.f);
        }

        
        // A) make it “transformable”:
        auto e = transform::CreateOrEmplace(&globals::registry,
                                        globals::gameWorldContainerEntity,
                                        /*x*/0,/*y*/0,
                                        /*w*/1,/*h*/1,
                                        std::nullopt);
        // B) mark it collidable:
        auto &go = globals::registry.get<transform::GameObject>(e);
        go.container        = globals::gameWorldContainerEntity;
        go.state.collisionEnabled = true;
        
        auto &role = globals::registry.get<transform::InheritedProperties>(e);
        // C) set the alignment flags:
        role.flags->alignment = alignment;
        // C) set the alignment offsets:
        role.flags->extraAlignmentFinetuningOffset = Vector2{alignOffX, alignOffY};
        
        // link your hierarchy using assignRole (or InheritedProperties):
        transform::AssignRole(&globals::registry, e, transform::InheritedProperties::Type::RoleInheritor, master, std::nullopt, std::nullopt, std::nullopt, std::nullopt, Vector2{ox, oy});

        // D) add a default ColliderComponent:
        auto  &c = globals::registry.emplace<ColliderComponent>(e);
        c.type = type;
        
        auto &transform = globals::registry.get<transform::Transform>(e);
        // E) set the transform properties:
        transform.setActualW(w);
        transform.setActualH(h);
        transform.setActualRotation(rotation);
        transform.setActualScale(scale);
        
        return e;
    }
    
    
    // A tiny epsilon for “un‐rotated” tests
    constexpr float ROT_EPS = 0.1f;

    // Extract a rotated‐rectangle (OBB) from your Transform/GameObject
    struct OBB {
        Vector2 center;      // world-space center
        Vector2 halfExtents; // w/2, h/2 (including any buffer)
        float   rot;         // in radians
    };

    // Build an OBB for entity `e`, including hover/drag buffers
    inline OBB makeOBB(entt::registry& R, entt::entity e) {
        auto &go = R.get<GameObject>(e);
        // pick the correct Transform
        auto *T = go.collisionTransform
                    ? &R.get<transform::Transform>(*go.collisionTransform)
                    : &R.get<transform::Transform>(e);

        float cx = T->getActualX();
        float cy = T->getActualY();
        float w  = T->getActualW();
        float h  = T->getActualH();
        float r  = T->getActualRotation();

        // apply hover/drag “forgiveness”
        float bufX = 0, bufY = 0;
        if (go.state.isBeingHovered) {
        bufX += T->getHoverCollisionBufferX();
        bufY += T->getHoverCollisionBufferY();
        }
        if (go.state.isBeingDragged) {
        bufX += T->getHoverCollisionBufferX();
        bufY += T->getHoverCollisionBufferY();
        }

        // center of box:
        Vector2 center{ cx + w*0.5f, cy + h*0.5f };

        // half‐extents + buffer: (buffer applied only once)
        Vector2 half{ (w + bufX)*0.5f, (h + bufY)*0.5f };

        return { center, half, r };
    }

    // PROJECT rect onto axis (unit vector), return [min,max] scalar
    inline void projectOnto(const OBB &box, const Vector2 &axis, float& outMin, float& outMax) {
        // 4 corners relative to center
        Vector2 corners[4] = {
        {+box.halfExtents.x, +box.halfExtents.y},
        {+box.halfExtents.x, -box.halfExtents.y},
        {-box.halfExtents.x, +box.halfExtents.y},
        {-box.halfExtents.x, -box.halfExtents.y},
        };
        bool first = true;
        for (int i = 0; i < 4; ++i) {
        // rotate corner
        float c = std::cos(box.rot), s = std::sin(box.rot);
        Vector2 worldPt = {
            box.center.x + corners[i].x * c - corners[i].y * s,
            box.center.y + corners[i].x * s + corners[i].y * c
        };
        float proj = worldPt.x*axis.x + worldPt.y*axis.y;
        if (first) {
            outMin = outMax = proj;
            first = false;
        } else {
            outMin = std::min(outMin, proj);
            outMax = std::max(outMax, proj);
        }
        }
    }

    // SAT test for two OBBs
    inline bool obbIntersect(const OBB &A, const OBB &B) {
        // if both are nearly axis-aligned, skip SAT and do AABB vs AABB
        if (std::abs(A.rot) < ROT_EPS && std::abs(B.rot) < ROT_EPS) {
            return
            std::abs(A.center.x - B.center.x) <= (A.halfExtents.x + B.halfExtents.x) &&
            std::abs(A.center.y - B.center.y) <= (A.halfExtents.y + B.halfExtents.y);
        }

        // Collect the 4 candidate axes (normals of each box’s edges)
        Vector2 axes[4];
        {
        float cA = std::cos(A.rot), sA = std::sin(A.rot);
        axes[0] = {  cA,  sA }; // A’s local X
        axes[1] = { -sA,  cA }; // A’s local Y
        float cB = std::cos(B.rot), sB = std::sin(B.rot);
        axes[2] = {  cB,  sB }; // B’s local X
        axes[3] = { -sB,  cB }; // B’s local Y
        }

        // For each axis: project both and check interval overlap
        for (int i = 0; i < 4; ++i) {
        float minA, maxA, minB, maxB;
        projectOnto(A, axes[i], minA, maxA);
        projectOnto(B, axes[i], minB, maxB);
        // gap?
        if (maxA < minB || maxB < minA)
            return false;
        }
        return true;
    }

    // Public API: replace your old broad-phase callbacks with this
    inline auto CheckCollisionBetweenTransforms(entt::registry* registry,
                                        entt::entity a,
                                        entt::entity b) -> bool
    {
        // early out if either has collision disabled
        auto &goA = registry->get<GameObject>(a);
        auto &goB = registry->get<GameObject>(b);
        if (!goA.state.collisionEnabled || !goB.state.collisionEnabled)
            return false;

        // build OBBs (includes buffers)
        OBB obbA = makeOBB(*registry, a);
        OBB obbB = makeOBB(*registry, b);

        // SAT or AABB test
        return obbIntersect(obbA, obbB);
    }

}