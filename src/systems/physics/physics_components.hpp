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