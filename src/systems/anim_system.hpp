#pragma once

#include <string>
#include "core/globals.hpp"

namespace animation_system {

    extern auto update(float dt) -> void;
    extern auto createAnimatedObjectWithTransform (std::string defaultAnimationID, int x, int y) -> entt::entity;
}