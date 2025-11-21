#pragma once

// =============================================================================
// Input System - Main Coordinator
// =============================================================================
// This is the main input system header. The input system has been organized
// into focused modules to improve maintainability and documentation.
//
// MODULE STRUCTURE:
// - input_mouse.hpp      : Mouse input (clicks, movement, wheel)
// - input_keyboard.hpp   : Keyboard input (keys, text entry)
// - input_gamepad.hpp    : Gamepad input (buttons, axes)
// - input_cursor.hpp     : Cursor management (position, snapping, context)
// - input_focus.hpp      : Focus and navigation (HANDLES DUAL SYSTEM INTEGRATION)
// - input_actions.hpp    : Action binding system (context-aware bindings)
// - input_events.hpp     : Event processing (click, drag, hover, release)
// - input_util.hpp       : Utility functions (state management, locks)
//
// IMPORTANT - DUAL NAVIGATION SYSTEM:
// The codebase has two navigation systems that coordinate via controllerNavOverride:
// 1. Legacy system (input_focus.hpp): Simple directional navigation
// 2. New system (controller_nav.hpp): Hierarchical groups/layers navigation
// See INPUT_SYSTEM_GUIDE.md for detailed explanation of how they integrate.
//
// For comprehensive documentation, see: INPUT_SYSTEM_GUIDE.md
// For action binding usage, see: input_action_binding_usage.md
// =============================================================================

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

    // =============================================================================
    // Core Input Loop Functions
    // =============================================================================
    // These functions coordinate all input modules and drive the input system.

    // Initialize input system (creates cursor, sets up state)
    auto Init(InputState &inputState) -> void;

    // Main input update loop (coordinates all modules)
    auto Update(entt::registry &registry, InputState &inputState, float dt) -> void;

    // =============================================================================
    // Event Processing Functions (see input_events.hpp)
    // =============================================================================
    void hoverDragSimultaneousCheck(entt::registry &registry, input::InputState &inputState);
    void propagateReleaseToGameObjects(input::InputState &inputState, entt::registry &registry);
    void propagateDragToGameObjects(entt::registry &registry, input::InputState &inputState);
    void propagateClicksToGameObjects(entt::registry &registry, input::InputState &inputState);
    void handleCursorHoverEvent(input::InputState &inputState, entt::registry &registry);
    void handleCursorReleasedEvent(input::InputState &inputState, entt::registry &registry);
    void handleCursorDownEvent(entt::registry &registry, input::InputState &inputState);
    void processRaylibLeftClick(input::InputState &inputState, entt::registry &registry);

    // =============================================================================
    // Utility Functions (see input_util.hpp)
    // =============================================================================
    void cacheInputTargets(input::InputState &inputState);
    void resetInputStateForProcessing(input::InputState &inputState);
    void PropagateButtonAndKeyUpdates(input::InputState &inputState, entt::registry &registry, float dt);
    void ProcessInputLocks(input::InputState &inputState, entt::registry &registry, float dt);
    void finalizeUpdateAtEndOfFrame(InputState &inputState, float dt);

    // =============================================================================
    // Cursor Management Functions (see input_cursor.hpp)
    // =============================================================================
    void handleRawCursor(input::InputState &inputState, entt::registry &registry);
    void ProcessControllerSnapToObject(input::InputState &inputState, entt::registry &registry);
    auto SetCurrentCursorPosition(entt::registry &registry, InputState &state) -> void;
    auto ModifyCurrentCursorContextLayer(entt::registry &registry, InputState &state, int delta) -> void;
    auto SnapToNode(entt::registry &registry, InputState &state, entt::entity node, const Vector2 &transform = {0,0}) -> void;
    auto UpdateCursor(InputState &state, entt::registry &registry, std::optional<Vector2> hardSetT = std::nullopt) -> void;
    void MarkEntitiesCollidingWithCursor(entt::registry &registry, InputState &state, const Vector2 &cursor_trans);
    void UpdateCursorHoveringState(entt::registry &registry, InputState &state);

    // =============================================================================
    // Gamepad Input Functions (see input_gamepad.hpp)
    // =============================================================================

    // HID (Human Interface Device) Management
    auto ReconfigureInputDeviceInfo(InputState &state, InputDeviceInputCategory category, GamepadButton button = GamepadButton::GAMEPAD_BUTTON_UNKNOWN) -> void;
    auto UpdateUISprites(const std::string &console_type) -> void;
    auto SetCurrentGamepad(InputState &state, const std::string &gamepad_object, int gamepadID) -> void;

    // Input Registry Management (button->entity mappings)
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

    // =============================================================================
    // Keyboard Input Functions (see input_keyboard.hpp)
    // =============================================================================
    auto GetCharacterFromKey(KeyboardKey key, bool caps) -> char;
    auto ProcessTextInput(entt::registry &registry, entt::entity entity, KeyboardKey key, bool shift, bool capsLock) -> void;
    auto HookTextInput(entt::registry &registry, entt::entity entity) -> void;
    auto UnhookTextInput(entt::registry &registry, entt::entity entity) -> void;

    void KeyboardKeyPressUpdate(entt::registry &registry, InputState &state, KeyboardKey key, float dt);
    void KeyboardKeyHoldUpdate(InputState &state, KeyboardKey key, float dt);
    void KeyboardKeyReleasedUpdate(InputState &state, KeyboardKey key, float dt);

    void ProcessKeyboardKeyDown(InputState &state, KeyboardKey key);
    void ProcessKeyboardKeyRelease(InputState &state, KeyboardKey key);

    // =============================================================================
    // Mouse Input Functions (see input_mouse.hpp)
    // =============================================================================
    void EnqueueLeftMouseButtonPress(InputState& state, float x = 0, float y = 0);
    void EnqueRightMouseButtonPress(InputState& state, float x = 0, float y = 0);

    void ProcessLeftMouseButtonPress(entt::registry &registry, InputState& state, float x = -1, float y = -1);
    void ProcessLeftMouseButtonRelease(entt::registry &registry, InputState& state, float x = -1, float y = -1);

    // =============================================================================
    // Focus and Navigation Functions (see input_focus.hpp)
    // =============================================================================
    // IMPORTANT: These work with controller_nav.hpp via controllerNavOverride flag
    // See INPUT_SYSTEM_GUIDE.md section "Dual Navigation System Integration"

    bool IsNodeFocusable(entt::registry &registry, InputState &state, entt::entity entity);
    void UpdateFocusForRelevantNodes(entt::registry &registry, InputState &state, std::optional<std::string> dir = std::nullopt);
    bool CaptureFocusedInput(entt::registry &registry, InputState &state, const std::string inputType, GamepadButton button, float dt);
    void NavigateFocus(entt::registry &registry, InputState &state, std::optional<std::string> dir = std::nullopt);

    // =============================================================================
    // Action Binding System Functions (see input_actions.hpp)
    // =============================================================================
    // For detailed usage, see input_action_binding_usage.md

    auto RebuildActionIndex(InputState &s) -> void;
    auto DecayActions(InputState &s) -> void;              // per-frame cleanup; call at end of Update
    auto DispatchRaw(InputState &s, InputDeviceInputCategory dev, int code, bool down, float value = 0.f) -> void; // O(1) dispatch for raw events/axes
    auto TickActionHolds(InputState &s, float dt) -> void; // Tick held timers; call once per frame before DecayActions

    auto bind_action(InputState &s, const std::string &action, const ActionBinding &b) -> void;
    auto clear_action(InputState &s, const std::string &action) -> void;
    auto set_context(InputState &s, const std::string &ctx) -> void;
    auto action_pressed (InputState &s, const std::string &a) -> bool ;
    auto action_released(InputState &s, const std::string &a) -> bool ;
    auto action_down    (InputState &s, const std::string &a) -> bool ;
    auto action_value   (InputState &s, const std::string &a) -> float ;

    auto start_rebind(InputState &s, const std::string &action, std::function<void(bool, ActionBinding)> cb) -> void ;
}