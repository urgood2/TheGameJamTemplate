#pragma once

#include <string>
#include <tuple>
#include "core/globals.hpp"

#include "sol/sol.hpp"


namespace animation_system {
    
    extern auto exposeToLua(sol::state &lua) -> void;

    extern auto update(entt::registry& registry, float dt) -> void;
    extern auto update(float dt) -> void;
    
    extern auto getNinepatchUIBorderInfo(std::string uuid_or_raw_identifier) -> std::tuple<NPatchInfo, Texture2D>;
    
    extern auto setFGColorForAllAnimationObjects(entt::registry& registry, entt::entity e, Color fgColor) -> void;
    [[deprecated("Use explicit registry overload")]]
    extern auto setFGColorForAllAnimationObjects(entt::entity e, Color fgColor) -> void;
    
    extern auto createAnimatedObjectWithTransform(entt::registry& registry, std::string defaultAnimationIDOrSpriteUUID, bool generateNewAnimFromSprite = false, int x = 0, int y = 0, std::function<void(entt::entity)> shaderPassConfigFunc = nullptr, bool shadowEnabled = true) -> entt::entity;
    [[deprecated("Use explicit registry overload")]]
    extern auto createAnimatedObjectWithTransform(std::string defaultAnimationIDOrSpriteUUID, bool generateNewAnimFromSprite = false, int x = 0, int y = 0, std::function<void(entt::entity)> shaderPassConfigFunc = nullptr, bool shadowEnabled = true) -> entt::entity;
    
    extern auto replaceAnimatedObjectOnEntity(entt::registry& registry, entt::entity e, std::string defaultAnimationIDorSpriteUUID, bool generateNewAnimFromSprite, std::function<void(entt::entity)> shaderPassConfig, bool shadowEnabled) -> void;
    [[deprecated("Use explicit registry overload")]]
    extern auto replaceAnimatedObjectOnEntity(entt::entity e, std::string defaultAnimationIDorSpriteUUID, bool generateNewAnimFromSprite, std::function<void(entt::entity)> shaderPassConfig, bool shadowEnabled) -> void;
    
    extern auto createStillAnimationFromSpriteUUID(std::string spriteUUID, std::optional<Color> fg = std::nullopt, std::optional<Color> bg = std::nullopt) -> AnimationObject;
    
    extern auto setupAnimatedObjectOnEntity(entt::registry& registry, entt::entity e, std::string defaultAnimationIDorSpriteUUID, bool generateNewAnimFromSprite, std::function<void(entt::entity)> shaderPassConfig, bool shadowEnabled) -> void;
    [[deprecated("Use explicit registry overload")]]
    extern auto setupAnimatedObjectOnEntity(entt::entity e, std::string defaultAnimationIDorSpriteUUID, bool generateNewAnimFromSprite, std::function<void(entt::entity)> shaderPassConfig, bool shadowEnabled) -> void;
    
    extern auto resizeAnimationObjectsInEntityToFit(entt::registry& registry, entt::entity e, float targetWidth, float targetHeight) -> void;
    [[deprecated("Use explicit registry overload")]]
    extern auto resizeAnimationObjectsInEntityToFit(entt::entity e, float targetWidth, float targetHeight) -> void;
    
    extern void resizeAnimationObjectsInEntityToFitAndCenterUI(entt::registry& registry, entt::entity e, float targetWidth, float targetHeight, bool centerLaterally = true, bool centerVertically = true);
    [[deprecated("Use explicit registry overload")]]
    extern void resizeAnimationObjectsInEntityToFitAndCenterUI(entt::entity e, float targetWidth, float targetHeight, bool centerLaterally = true, bool centerVertically = true);
    
    extern void resetAnimationUIRenderScale(entt::registry& registry, entt::entity e);
    [[deprecated("Use explicit registry overload")]]
    extern void resetAnimationUIRenderScale(entt::entity e);
    
    extern auto resizeAnimationObjectToFit(AnimationObject &animObj, float targetWidth, float targetHeight) -> void;
    
    extern auto getCurrentFrame(entt::entity e) -> unsigned int;
    extern auto getFrameCount(entt::entity e) -> size_t;
    extern auto isPlaying(entt::entity e) -> bool;
    extern auto getProgress(entt::entity e) -> float;
    
    extern auto playAnimation(entt::entity e) -> void;
    extern auto pauseAnimation(entt::entity e) -> void;
    extern auto stopAnimation(entt::entity e) -> void;
    extern auto setAnimationSpeed(entt::entity e, float speed) -> void;
    extern auto seekAnimationFrame(entt::entity e, unsigned int frame) -> void;
    extern auto setPlaybackDirection(entt::entity e, PlaybackDirection direction) -> void;
    extern auto setLoopCount(entt::entity e, int loopCount) -> void;
    
    extern auto setOnFrameChange(entt::entity e, std::function<void(unsigned int, unsigned int)> callback) -> void;
    extern auto setOnLoopComplete(entt::entity e, std::function<void(int)> callback) -> void;
    extern auto setOnAnimationEnd(entt::entity e, std::function<void()> callback) -> void;
    extern auto clearAnimationCallbacks(entt::entity e) -> void;
}
