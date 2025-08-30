#pragma once

#include "entt/entt.hpp"

#include "util/common_headers.hpp"

#include "core/globals.hpp"

#include "input.hpp"
#include "input_function_data.hpp"

#include "systems/transform/transform_functions.hpp"
#include "systems/main_loop_enhancement/main_loop.hpp"

#include "raylib.h"

#include <vector>
#include <unordered_map>
#include <string>
#include <regex>

using namespace snowhouse; // assert

namespace input
{
    auto exposeToLua(sol::state &lua) -> void;

    // Controller Initialization
    auto Init(InputState &inputState) -> void;
    auto Update(entt::registry &registry, InputState &inputState, float dt) -> void;

    void hoverDragSimultaneousCheck(entt::registry &registry, input::InputState &inputState);

    void propagateReleaseToGameObjects(input::InputState &inputState, entt::registry &registry);

    void propagateDragToGameObjects(entt::registry &registry, input::InputState &inputState);

    void propagateClicksToGameObjects(entt::registry &registry, input::InputState &inputState);

    void handleCursorHoverEvent(input::InputState &inputState, entt::registry &registry);

    void handleCursorReleasedEvent(input::InputState &inputState, entt::registry &registry);

    void handleCursorDownEvent(entt::registry &registry, input::InputState &inputState);

    void processRaylibLeftClick(input::InputState &inputState, entt::registry &registry);

    void cacheInputTargets(input::InputState &inputState);

    void resetInputStateForProcessing(input::InputState &inputState);

    void handleRawCursor(input::InputState &inputState, entt::registry &registry);

    void ProcessControllerSnapToObject(input::InputState &inputState, entt::registry &registry);

    void PropagateButtonAndKeyUpdates(input::InputState &inputState, entt::registry &registry, float dt);

    void ProcessInputLocks(input::InputState &inputState, entt::registry &registry, float dt);

    // HID (Human Interface Device) Management
    auto ReconfigureInputDeviceInfo(InputState &state, InputDeviceInputCategory category, GamepadButton button = GamepadButton::GAMEPAD_BUTTON_UNKNOWN) -> void;
    auto UpdateUISprites(const std::string &console_type) -> void;
    auto SetCurrentGamepad(InputState &state, const std::string &gamepad_object, int gamepadID) -> void;

    // Cursor Management
    auto SetCurrentCursorPosition(entt::registry &registry, InputState &state) -> void;
    auto ModifyCurrentCursorContextLayer(entt::registry &registry, InputState &state, int delta) -> void;
    auto SnapToNode(entt::registry &registry, InputState &state, entt::entity node, const Vector2 &transform = {0,0}) -> void;
    auto UpdateCursor(InputState &state, entt::registry &registry, std::optional<Vector2> hardSetT = std::nullopt) -> void;

    // Input Registry Management
    auto DeleteInvalidEntitiesFromInputRegistry(InputState &state, entt::registry &registry) -> void;
    auto AddNodeToInputRegistry(entt::registry &registry, InputState &state, entt::entity node, const GamepadButton button) -> void;
    auto ProcessInputRegistry(InputState &state, entt::registry &registry) -> void;

    // Button Processing
    auto ButtonPressUpdate(entt::registry &registry, InputState &state, const GamepadButton button, float dt) -> void;
    auto ProcessButtonPress(InputState &state, GamepadButton button) -> void;
    auto ProcessButtonRelease(InputState &state, GamepadButton button) -> void;
    auto HeldButtonUpdate(entt::registry &registry, InputState &state, const GamepadButton button, float dt) -> void;
    void ReleasedButtonUpdate(entt::registry &registry, InputState &state, const GamepadButton button, float dt);

    // Axis Processing
    auto ProcessAxisButtons(InputState &state) -> void;
    auto UpdateGamepadAxisInput(InputState &state, entt::registry &registry, float dt) -> InputDeviceInputCategory;

    // Keyboard Input Handling
    auto GetCharacterFromKey(KeyboardKey key, bool caps) -> char;
    auto ProcessTextInput(entt::registry &registry, entt::entity entity, KeyboardKey key, bool shift, bool capsLock) -> void;
    auto HookTextInput(entt::registry &registry, entt::entity entity) -> void;
    auto UnhookTextInput(entt::registry &registry, entt::entity entity) -> void;

    void KeyboardKeyPressUpdate(entt::registry &registry, InputState &state, KeyboardKey key, float dt);
    void KeyboardKeyHoldUpdate(InputState &state, KeyboardKey key, float dt);
    void KeyboardKeyReleasedUpdate(InputState &state, KeyboardKey key, float dt);

    void ProcessKeyboardKeyDown(InputState &state, KeyboardKey key);
    void ProcessKeyboardKeyRelease(InputState &state, KeyboardKey key);

    // Mouse Input Handling
    void MarkEntitiesCollidingWithCursor(entt::registry &registry, InputState &state, const Vector2 &cursor_trans);
    void UpdateCursorHoveringState(entt::registry &registry, InputState &state);

    void EnqueueLeftMouseButtonPress(InputState& state, float x = 0, float y = 0);
    void EnqueRightMouseButtonPress(InputState& state, float x = 0, float y = 0);

    void ProcessLeftMouseButtonPress(entt::registry &registry, InputState& state, float x = -1, float y = -1);
    void ProcessLeftMouseButtonRelease(entt::registry &registry, InputState& state, float x = -1, float y = -1);

    // Focus and Navigation
    bool IsNodeFocusable(entt::registry &registry, InputState &state, entt::entity entity);
    void UpdateFocusForRelevantNodes(entt::registry &registry, InputState &state, std::optional<std::string> dir = std::nullopt);

    bool CaptureFocusedInput(entt::registry &registry, InputState &state, const std::string inputType, GamepadButton button, float dt);
    void NavigateFocus(entt::registry &registry, InputState &state, std::optional<std::string> dir = std::nullopt);

    auto RebuildActionIndex(InputState &s) -> void;
    // per-frame cleanup; call at end of Update
    auto DecayActions(InputState &s) -> void;
    // O(1) dispatch for raw events/axes
    auto DispatchRaw(InputState &s, InputDeviceInputCategory dev, int code, bool down, float value = 0.f) -> void;
    // Tick held timers; call once per frame before DecayActions
    auto TickActionHolds(InputState &s, float dt) -> void;
    auto bind_action(InputState &s, const std::string &action, const ActionBinding &b) -> void;
    auto clear_action(InputState &s, const std::string &action) -> void;
    auto set_context(InputState &s, const std::string &ctx) -> void;
    auto action_pressed (InputState &s, const std::string &a) -> bool ;
    auto action_released(InputState &s, const std::string &a) -> bool ;
    auto action_down    (InputState &s, const std::string &a) -> bool ;
    auto action_value   (InputState &s, const std::string &a) -> float ;

    auto start_rebind(InputState &s, const std::string &action, std::function<void(bool, ActionBinding)> cb) -> void ;
}