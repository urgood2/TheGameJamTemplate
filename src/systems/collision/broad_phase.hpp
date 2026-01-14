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

#include "systems/scripting/binding_recorder.hpp"

namespace collision {
    
    using namespace transform; // for Transform, GameObject, etc


    
    struct ScreenSpaceCollisionMarker {}; // for the ui quadtree. anything thatd doesn't have this is preusmed world space. REmove it from ui if the ui should share collision checking with the world space quadtree.

    
    // FIXME: shape tags: currently not in use.
    enum class ColliderType { AABB, Circle /*, Capsule, Polygon…*/ };

    struct ColliderComponent {
        ColliderType type; // right now this is unused
    };
    
    
    
    
    inline std::unordered_map<std::string, uint32_t> tagBits;

    // Allocate and return a unique bit for each tag name.
    // Internally keeps its own nextBit and tagBits map.
    inline uint32_t getTagBit(const std::string &tag) {
        static std::unordered_map<std::string,uint32_t> tagBits;
        static uint32_t nextBit = 1u;
        auto it = tagBits.find(tag);
        if (it != tagBits.end()) {
            return it->second;
        }
        // assign & bump
        uint32_t bit = nextBit;
        tagBits[tag] = bit;
        nextBit <<= 1;
        return bit;
    }

    // Lazily fetch the “default” tag bit (only once, on first call).
    inline uint32_t defaultTag() {
        static uint32_t dt = getTagBit("default");
        return dt;
    }
    /*
    – category is a bitfield saying which tag(s) this entity is (e.g. Player=0x1, Enemy=0x2, Projectile=0x4…).
    – mask is a bitfield saying which categories it’s interested in colliding with (it only collides where (categoryB & maskA) != 0 && (categoryA & maskB) != 0).
    */
    struct CollisionFilter {
        CollisionFilter()
        : category{defaultTag()}
        , mask{defaultTag()}
        {}
        uint32_t category{};   // “what I am”
        uint32_t mask{}; // “what I collide with”
    };

    
    // 1) create_collider(shapeTag)
    //   - creates a new entity
    //   - auto-creates its Transform (using your existing helper)
    //   - emplaces a GameObject with collisionEnabled=true
    //   - emplaces a ColliderComponent with default data
    //
    
    inline entt::entity create_collider_for_entity(entt::entity master, sol::table t) {
        
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
        auto e = transform::CreateOrEmplace(&globals::getRegistry(),
                                        globals::getGameWorldContainer(),
                                        /*x*/0,/*y*/0,
                                        /*w*/1,/*h*/1,
                                        std::nullopt);
        // B) mark it collidable:
        auto &go = globals::getRegistry().get<transform::GameObject>(e);
        go.container        = globals::getGameWorldContainer();
        go.state.collisionEnabled = true;
        
        auto &role = globals::getRegistry().get<transform::InheritedProperties>(e);
        // C) set the alignment flags:
        role.flags->alignment = alignment;
        // C) set the alignment offsets:
        role.flags->extraAlignmentFinetuningOffset = Vector2{alignOffX, alignOffY};
        
        // link your hierarchy using assignRole (or InheritedProperties):
        transform::AssignRole(&globals::getRegistry(), e, transform::InheritedProperties::Type::PermanentAttachment, master, std::nullopt, std::nullopt, std::nullopt, std::nullopt, Vector2{ox, oy});

        // D) add a default ColliderComponent:
        auto  &c = globals::getRegistry().emplace<ColliderComponent>(e);
        c.type = ColliderType::AABB; // unused, we use transforms for collision
        
        auto &transform = globals::getRegistry().get<transform::Transform>(e);
        // E) set the transform properties:
        transform.setActualW(w);
        transform.setActualH(h);
        transform.setActualRotation(rotation);
        transform.setActualScale(scale);
        transform.ignoreDynamicMotion = true; // ignore dynamic motion, we only use this for static collision checks
        transform.ignoreXLeaning = true; // ignore x leaning, we only use this for static collision checks
        
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

        // apply hover/drag "forgiveness" - use max, not sum
        float bufX = 0, bufY = 0;
        if (go.state.isBeingHovered || go.state.isBeingDragged) {
            // Both states use the same buffer, so just apply once
            // Using hover buffer since it's the "forgiveness" buffer
            bufX = T->getHoverCollisionBufferX();
            bufY = T->getHoverCollisionBufferY();
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

    inline void exposeToLua(sol::state &lua, EngineContext* ctx = nullptr) {
        auto& rec = BindingRecorder::instance();
        const std::vector<std::string> path = {"collision"};
    
        // 0) Namespace
        rec.add_type("collision").doc =
            "Namespace for creating colliders and performing collision‐tests.";
    
        // 1) ColliderType enum
        // 1) ColliderType as a constant table
        lua["ColliderType"] = lua.create_table_with(
            "AABB",   static_cast<int>(collision::ColliderType::AABB),
            "Circle", static_cast<int>(collision::ColliderType::Circle)
        );
        auto& ct = rec.add_type("ColliderType");
        ct.doc = "Enum of supported collider shapes.";
        rec.record_property("ColliderType", {"AABB",   std::to_string(static_cast<int>(collision::ColliderType::AABB)),   "Axis-aligned bounding box."});
        rec.record_property("ColliderType", {"Circle", std::to_string(static_cast<int>(collision::ColliderType::Circle)), "Circle collider."});

    
        // 2) create_collider_for_entity
        rec.bind_function(lua, path, "create_collider_for_entity",
            &collision::create_collider_for_entity,
            "---@param master entt.entity               # Parent entity to attach collider to\n"
            "---@param type collision.ColliderType       # Shape of the new collider\n"
            "---@param t table                           # Config table:\n"
            "                                          #   offsetX?, offsetY?, width?, height?, rotation?, scale?\n"
            "                                          #   alignment? (bitmask), alignOffset { x?, y? }\n"
            "---@return entt.entity                      # Newly created collider entity",
            "Creates a child entity under `master` with a Transform, GameObject (collision enabled),\n"
            "and a ColliderComponent of the given `type`, applying all provided offsets, sizes, rotation,\n"
            "scale and alignment flags."
        );
    
        // 3) CheckCollisionBetweenTransforms
        rec.bind_function(lua, path, "CheckCollisionBetweenTransforms",
            &collision::CheckCollisionBetweenTransforms,
            "---@param registry entt.registry*           # Pointer to your entity registry\n"
            "---@param a entt.entity                      # First entity to test\n"
            "---@param b entt.entity                      # Second entity to test\n"
            "---@return boolean                           # True if their collider OBBs/AABBs overlap",
            "Runs a Separating Axis Theorem (SAT) test—or AABB test if both are unrotated—\n"
            "on entities `a` and `b`, returning whether they intersect based on their ColliderComponents\n"
            "and Transforms."
        );
        
        // 1) Expose the CollisionFilter struct
        lua.new_usertype<collision::CollisionFilter>(
            /* name in Lua: */        "CollisionFilter",
            /* no Lua constructor: */ sol::no_constructor,
            /* fields: */
            "category", &collision::CollisionFilter::category,
            "mask",     &collision::CollisionFilter::mask
        );
        auto& cf = rec.add_type("CollisionFilter");
        cf.doc = 
            "Component holding two 32-bit bitmasks:\n"
            "-- category = which tag-bits this collider *is*\n"
            "--- mask     = which category-bits this collider *collides with*\n"
            "--Default ctor sets both to 0xFFFFFFFF (collide with everything).";
        rec.record_property("CollisionFilter",
            { "category", "uint32", "Bitmask: what this entity *is* (e.g. Player, Enemy, Projectile)." }
        );
        rec.record_property("CollisionFilter",
            { "mask",     "uint32", "Bitmask: which categories this entity *collides* with." }
        );

        // 2) Helper: setCollisionCategory(entt.entity, string tag)
        //    → ORs the category bit in; leaves existing bits intact
        rec.bind_function(lua, path, "setCollisionCategory",
            [&](entt::entity e, const std::string &tag){
                auto &f = globals::getRegistry().get<collision::CollisionFilter>(e);
                f.category |= collision::getTagBit(tag);
            },
            "---@param e entt.entity\n"
            "---@param tag string\n"
            "---@return nil",
            "Adds the given tag bit to this entity's filter.category, so it *is* also that tag."
        );

        // 3) Helper: setCollisionMask(entt.entity, ...)
        //    → replaces the mask entirely with the OR of all provided tags
        rec.bind_function(lua, path, "setCollisionMask",
            [&](entt::entity e, sol::variadic_args args){
                auto &f = globals::getRegistry().get<collision::CollisionFilter>(e);
                f.mask = 0u;
                for (auto v : args) {
                    std::string tag = v;
                    f.mask |= collision::getTagBit(tag);
                }
            },
            "---@param e entt.entity\n"
            "---@param ... string\n"
            "---@return nil",
            "Replaces the entity's filter.mask with the OR of all specified tags."
        );

        // 4) Optional: helper to *replace* category bits (clear then OR) if you want exclusivity
        rec.bind_function(lua, path, "resetCollisionCategory",
            [&](entt::entity e, const std::string &tag){
                auto &f = globals::getRegistry().get<collision::CollisionFilter>(e);
                f.category  = collision::getTagBit(tag);
            },
            "---@param e entt.entity\n"
            "---@param tag string\n"
            "---@return nil",
            "Clears all category bits, then sets only this one."
        );
    }
    
}
