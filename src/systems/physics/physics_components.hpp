#pragma once

#include "core/globals.hpp"
#include "util/common_headers.hpp"



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