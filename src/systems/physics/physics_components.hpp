#pragma once

#include "core/globals.hpp"
#include "util/common_headers.hpp"
#include "third_party/chipmunk/include/chipmunk/chipmunk.h"

namespace physics {
    
    class PhysicsWorld;  // forward declare
    
    // Public POD we expose to Lua
    struct LuaArbiter {
        cpArbiter* arb = nullptr;

        // Read
        std::pair<entt::entity, entt::entity> entities() const;
        std::pair<std::string, std::string>   tags(PhysicsWorld& W) const;
        cpVect normal() const;
        float total_impulse_length() const;
        cpVect total_impulse() const;

        // Mutate (preSolve only)
        void set_friction(float f) const;
        void set_elasticity(float e) const;
        void set_surface_velocity(float vx, float vy) const;
        void ignore() const;     // cpArbiterIgnore(arb)
    };
}

struct ObjectLayerTag {
    std::string name;
    std::size_t hash;
    explicit ObjectLayerTag(const std::string& n)
    : name(n), hash(std::hash<std::string>{}(n)) {}
};

// Attach to any collider entity to declare its physics tag (maps to PhysicsWorld::collisionTags)
struct PhysicsLayer {
    std::string tag;       // e.g. "WORLD", "PLAYER", "ENEMY", ...
    std::size_t tag_hash;  // cached
    explicit PhysicsLayer(const std::string& t)
    : tag(t), tag_hash(std::hash<std::string>{}(t)) {}
};

// Which physics world an entity belongs to
struct PhysicsWorldRef {
    std::string name;
    std::size_t hash;
    explicit PhysicsWorldRef(const std::string& n)
    : name(n), hash(std::hash<std::string>{}(n)) {}
};

// Optional: tag a world with a state name; when that state is inactive, the world won’t step/draw.
struct WorldStateBinding {
    std::string state_name;
    std::size_t state_hash;
    explicit WorldStateBinding(const std::string& s)
    : state_name(s), state_hash(std::hash<std::string>{}(s)) {}
};
