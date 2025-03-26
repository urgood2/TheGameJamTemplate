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

    // Controller Initialization
    auto Init(InputState &inputState) -> void;
    auto Update(entt::registry &registry, InputState &inputState, float dt) -> void;

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

    
}