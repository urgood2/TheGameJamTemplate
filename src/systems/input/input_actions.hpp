#pragma once

// -----------------------------------------------------------------------------
// Action Binding System Module
// -----------------------------------------------------------------------------
// This module provides a flexible, context-aware input action binding system.
// Instead of checking raw keys/buttons, game code binds named actions to inputs
// and polls action states. This allows for:
// - Easy rebinding of controls
// - Multi-device support (keyboard, mouse, gamepad)
// - Context-based input (different bindings per game state)
// - Unified API for digital and analog inputs
//
// ARCHITECTURE:
// -----------------------------------------------------------------------------
// 1. Bindings: ActionBinding structs map device inputs to action names
//    - device: KEYBOARD, MOUSE, GAMEPAD_BUTTON, GAMEPAD_AXIS
//    - code: The specific key/button/axis (as int)
//    - trigger: WHEN the action fires (Pressed, Released, Held, AxisPos, etc.)
//    - context: Which game context this binding is active in
//
// 2. State: ActionFrameState tracks per-action state each frame
//    - pressed: True only on rising edge (first frame of press)
//    - released: True only on falling edge (frame of release)
//    - down: True while held (latched from press to release)
//    - held: Time in seconds the action has been held
//    - value: Analog value for axis inputs
//
// 3. Index: code_to_actions multimap for O(1) dispatch
//    - Maps (device, code) -> list of (action_name, binding_index)
//    - Rebuilt when bindings change via RebuildActionIndex()
//
// LIFECYCLE:
// -----------------------------------------------------------------------------
// Each frame:
//   1. DispatchRaw() called for each input event (key press, axis change, etc.)
//      - Looks up bindings via code_to_actions index
//      - Updates ActionFrameState based on trigger type
//   2. TickActionHolds() increments held timers for down actions
//   3. Game logic polls actions via action_pressed/released/down/value()
//   4. DecayActions() clears one-frame flags (pressed, released, value)
//      - Does NOT clear 'down' (latched until release)
//
// CONTEXTS:
// -----------------------------------------------------------------------------
// Bindings can be context-specific or "global":
// - set_context("gameplay") activates gameplay-specific bindings
// - "global" bindings are always active regardless of context
// - DispatchRaw() only processes bindings matching current/global context
//
// REBINDING:
// -----------------------------------------------------------------------------
// start_rebind() enters listen mode:
// - Next input event creates an ActionBinding
// - Callback receives the binding for saving/applying
// - Allows runtime control remapping
//
// For detailed usage examples, see input_action_binding_usage.md
//
// Key Functions:
// - bind_action(): Add a binding for an action
// - clear_action(): Remove all bindings for an action
// - set_context(): Change active input context
// - action_pressed/released/down/value(): Poll action state
// - DispatchRaw(): Process raw input events
// - RebuildActionIndex(): Rebuild fast lookup index
// - start_rebind(): Enter rebind listening mode
// -----------------------------------------------------------------------------

#include "input_function_data.hpp"
#include <string>
#include <functional>

namespace input {
namespace actions {

    // Action binding management
    auto bind_action(InputState &s, const std::string &action, const ActionBinding &b) -> void;
    auto clear_action(InputState &s, const std::string &action) -> void;

    // Context management
    auto set_context(InputState &s, const std::string &ctx) -> void;

    // Action state queries (for game logic)
    auto action_pressed (InputState &s, const std::string &a) -> bool;  // Edge: first frame only
    auto action_released(InputState &s, const std::string &a) -> bool;  // Edge: release frame only
    auto action_down    (InputState &s, const std::string &a) -> bool;  // Latched: true while held
    auto action_value   (InputState &s, const std::string &a) -> float; // Analog: axis value

    // Internal frame lifecycle
    auto RebuildActionIndex(InputState &s) -> void;     // Rebuild code_to_actions lookup
    auto DecayActions(InputState &s) -> void;           // Clear one-frame flags (call at frame end)
    auto TickActionHolds(InputState &s, float dt) -> void; // Increment held timers (call before game logic)

    // Raw input dispatch
    // Called by polling code when input events occur
    // down: true for press, false for release
    // value: analog magnitude for axis inputs
    auto DispatchRaw(InputState &s, InputDeviceInputCategory dev, int code, bool down, float value = 0.f) -> void;

    // Rebinding system
    // Enters listen mode; next input event triggers callback with binding
    auto start_rebind(InputState &s, const std::string &action, std::function<void(bool, ActionBinding)> cb) -> void;

} // namespace actions
} // namespace input
