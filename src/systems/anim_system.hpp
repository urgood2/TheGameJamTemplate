#pragma once

#include <string>
#include <tuple>
#include "core/globals.hpp"


namespace animation_system {

    extern auto update(float dt) -> void;
    extern auto getNinepatchUIBorderInfo(std::string uuid_or_raw_identifier) -> std::tuple<NPatchInfo, Texture2D>;
    
    // pass a function which sets up shader pipeline if desired.
    extern auto createAnimatedObjectWithTransform (std::string defaultAnimationIDOrSpriteUUID, bool generateNewAnimFromSprite = false, int x = 0, int y = 0, std::function<void(entt::entity)> shaderPassConfigFunc = [](entt::entity e){}) ->  entt::entity;
    
    // convenience function to create a still animation object from a sprite UUID
    auto createStillAnimationFromSpriteUUID(std::string spriteUUID, std::optional<Color> fg = std::nullopt, std::optional<Color> bg = std::nullopt) -> AnimationObject;
    
    extern auto resizeAnimationObjectsInEntityToFit(entt::entity e, float targetWidth, float targetHeight) -> void;
    
    extern auto resizeAnimationObjectToFit(AnimationObject &animObj, float targetWidth, float targetHeight) -> void;
}