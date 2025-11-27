#pragma once

#include <string>

#include "core/event_bus.hpp"
#include "core/globals.hpp"
#include "entt/entt.hpp"
#include "raylib.h"

namespace events {

// Entity lifecycle
struct EntityCreated : public event_bus::Event {
    entt::entity entity{entt::null};
    std::string type{};
};

struct EntityDestroyed : public event_bus::Event {
    entt::entity entity{entt::null};
};

// Input
struct MouseClicked : public event_bus::Event {
    Vector2 position{};
    int button{0};
    entt::entity target{entt::null};

    MouseClicked() = default;
    MouseClicked(Vector2 pos, int btn, entt::entity tgt = entt::null)
        : position(pos), button(btn), target(tgt) {}
};

struct KeyPressed : public event_bus::Event {
    int keyCode{0};
    bool shift{false};
    bool ctrl{false};
    bool alt{false};

    KeyPressed() = default;
    KeyPressed(int key, bool s, bool c, bool a)
        : keyCode(key), shift(s), ctrl(c), alt(a) {}
};

struct GamepadButtonPressed : public event_bus::Event {
    int gamepadId{0};
    ::GamepadButton button{GAMEPAD_BUTTON_UNKNOWN};

    GamepadButtonPressed() = default;
    GamepadButtonPressed(int id, ::GamepadButton btn)
        : gamepadId(id), button(btn) {}
};

struct GamepadButtonReleased : public event_bus::Event {
    int gamepadId{0};
    ::GamepadButton button{GAMEPAD_BUTTON_UNKNOWN};

    GamepadButtonReleased() = default;
    GamepadButtonReleased(int id, ::GamepadButton btn)
        : gamepadId(id), button(btn) {}
};

struct InputDeviceChanged : public event_bus::Event {
    int previous{0};
    int current{0};
    int gamepadButton{GAMEPAD_BUTTON_UNKNOWN};

    InputDeviceChanged() = default;
    InputDeviceChanged(int prev, int curr, int button)
        : previous(prev), current(curr), gamepadButton(button) {}
};

// Game state
struct GameStateChanged : public event_bus::Event {
    GameState oldState{GameState::LOADING_SCREEN};
    GameState newState{GameState::LOADING_SCREEN};

    GameStateChanged() = default;
    GameStateChanged(GameState oldSt, GameState newSt)
        : oldState(oldSt), newState(newSt) {}
};

// Assets
struct AssetLoaded : public event_bus::Event {
    std::string assetId{};
    std::string assetType{};
};

struct AssetLoadFailed : public event_bus::Event {
    std::string assetId{};
    std::string error{};
};

// UI
struct UIElementFocused : public event_bus::Event {
    entt::entity element{entt::null};

    UIElementFocused() = default;
    explicit UIElementFocused(entt::entity e) : element(e) {}
};

struct UIButtonActivated : public event_bus::Event {
    entt::entity element{entt::null};
    int button{MOUSE_LEFT_BUTTON};

    UIButtonActivated() = default;
    UIButtonActivated(entt::entity e, int btn) : element(e), button(btn) {}
};

struct UIScaleChanged : public event_bus::Event {
    float scale{1.0f};

    UIScaleChanged() = default;
    explicit UIScaleChanged(float s) : scale(s) {}
};

// Loading/progress
struct LoadingStageStarted : public event_bus::Event {
    std::string stageId{};

    LoadingStageStarted() = default;
    explicit LoadingStageStarted(std::string id) : stageId(std::move(id)) {}
};

struct LoadingStageCompleted : public event_bus::Event {
    std::string stageId{};
    bool success{true};
    std::string error{};

    LoadingStageCompleted() = default;
    LoadingStageCompleted(std::string id, bool ok, std::string err = {})
        : stageId(std::move(id)), success(ok), error(std::move(err)) {}
};

// Physics
struct CollisionStarted : public event_bus::Event {
    entt::entity entityA{entt::null};
    entt::entity entityB{entt::null};
    Vector2 point{};

    CollisionStarted() = default;
    CollisionStarted(entt::entity a, entt::entity b, Vector2 p)
        : entityA(a), entityB(b), point(p) {}
};

struct CollisionEnded : public event_bus::Event {
    entt::entity entityA{entt::null};
    entt::entity entityB{entt::null};

    CollisionEnded() = default;
    CollisionEnded(entt::entity a, entt::entity b) : entityA(a), entityB(b) {}
};

} // namespace events
