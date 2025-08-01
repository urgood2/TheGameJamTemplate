#pragma once

#include <string>
#include <tuple>
#include "core/globals.hpp"

#include "sol/sol.hpp"


namespace animation_system {
    
    extern auto exposeToLua(sol::state &lua) -> void;

    extern auto update(float dt) -> void;
    extern auto getNinepatchUIBorderInfo(std::string uuid_or_raw_identifier) -> std::tuple<NPatchInfo, Texture2D>;
    extern auto setFGColorForAllAnimationObjects(entt::entity e, Color fgColor) -> void;
    
    // pass a function which sets up shader pipeline if desired.
    extern auto createAnimatedObjectWithTransform (std::string defaultAnimationIDOrSpriteUUID, bool generateNewAnimFromSprite = false, int x = 0, int y = 0, std::function<void(entt::entity)> shaderPassConfigFunc = [](entt::entity e){}, bool shadowEnabled = true) ->  entt::entity;
    auto replaceAnimatedObjectOnEntity(
        entt::entity                            e,
        std::string                             defaultAnimationIDorSpriteUUID,
        bool                                    generateNewAnimFromSprite,
        std::function<void(entt::entity)>       shaderPassConfig,
        bool                                    shadowEnabled
    ) -> void;
    
    // convenience function to create a still animation object from a sprite UUID
    auto createStillAnimationFromSpriteUUID(std::string spriteUUID, std::optional<Color> fg = std::nullopt, std::optional<Color> bg = std::nullopt) -> AnimationObject;
    auto setupAnimatedObjectOnEntity(
        entt::entity                            e,
        std::string                             defaultAnimationIDorSpriteUUID,
        bool                                    generateNewAnimFromSprite,
        std::function<void(entt::entity)>       shaderPassConfig,
        bool                                    shadowEnabled
    ) -> void;
    
    extern auto resizeAnimationObjectsInEntityToFit(entt::entity e, float targetWidth, float targetHeight) -> void;
    extern void resizeAnimationObjectsInEntityToFitAndCenterUI(entt::entity e, float targetWidth, float targetHeight, bool centerLaterally = true, bool centerVertically = true);
    extern void resetAnimationUIRenderScale(entt::entity e);
    extern auto resizeAnimationObjectToFit(AnimationObject &animObj, float targetWidth, float targetHeight) -> void;
}