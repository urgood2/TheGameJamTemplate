#pragma once

#include <entt/entt.hpp>
#include <sol/sol.hpp>
#include <string>


namespace tutorial_system_v2 {
    extern bool tutorialModeActive;
    extern float tutorialModeTickSeconds; 
    extern sol::coroutine currentTutorialCoroutine;

    extern auto init() -> void;
    extern auto draw() -> void;
    extern auto update(const float dt) -> void;
    extern auto resetTutorialSystem() -> void;
    extern auto setTutorialModeActive(bool active) -> void;
    extern auto exposeToLua(sol::state &lua) -> void;
    extern auto registerTutorialToEvent(const std::string &tutorialName, const std::string &eventName) -> void;

    // ------------------------------------------------------------------------
    // methods for tutorial system that can be called from Lua
    // ------------------------------------------------------------------------
    extern auto setShowTutorialWindow(const std::string &tutorialWindowName, const std::string &tutorialText, const bool show) -> void;
    extern auto setShowTutorialWindowWithOptions(const std::string &tutorialWindowName, const std::string &tutorialText, const std::vector<std::string> &options, const bool show) -> void;
    
    extern auto lockControls() -> void;
    extern auto unlockControls() -> void;
    
    extern auto addGameAnnouncement(const std::string &announcementText) -> void;

    extern auto moveCameraTo(float x, float y) -> void;
    extern auto moveCameraToEntity(entt::registry& registry, entt::entity entity) -> void;
    [[deprecated("Use explicit registry overload")]]
    extern auto moveCameraToEntity(entt::entity entity) -> void;

    extern auto displayIndicatorAroundEntity(entt::registry& registry, entt::entity entity, std::string indicatorTypeID) -> void;
    [[deprecated("Use explicit registry overload")]]
    extern auto displayIndicatorAroundEntity(entt::entity entity, std::string indicatorTypeID) -> void;
    extern auto displayIndicatorAroundEntity(entt::registry& registry, entt::entity entity) -> void;
    [[deprecated("Use explicit registry overload")]]
    extern auto displayIndicatorAroundEntity(entt::entity entity) -> void;

    extern auto fadeOutScreen(float seconds) -> void;
    extern auto fadeInScreen(float seconds) -> void;
}
