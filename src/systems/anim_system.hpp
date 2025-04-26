#pragma once

#include <string>
#include <tuple>
#include "core/globals.hpp"


namespace animation_system {

    extern auto update(float dt) -> void;
    extern auto getNinepatchUIBorderInfo(std::string uuid_or_raw_identifier) -> std::tuple<NPatchInfo, Texture2D>;
        
    extern auto createAnimatedObjectWithTransform (std::string defaultAnimationID, int x, int y) -> entt::entity;
}