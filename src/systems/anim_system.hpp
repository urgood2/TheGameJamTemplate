#pragma once

#include <string>
#include <tuple>
#include "core/globals.hpp"


namespace animation_system {

    extern auto update(float dt) -> void;
    extern auto getNinepatchUIBorderInfo(std::string uuid_or_raw_identifier) -> std::tuple<NPatchInfo, Texture2D>;
    
    // pass a function which sets up shader pipeline if desired.
    extern auto createAnimatedObjectWithTransform (std::string defaultAnimationID, int x, int y, std::function<void(entt::entity)> configFunc = [](entt::entity e){}) -> entt::entity;
}