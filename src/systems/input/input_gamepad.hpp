#pragma once

// -----------------------------------------------------------------------------
// Gamepad Input Module
// -----------------------------------------------------------------------------
// This module handles all gamepad-related input processing including:
// - Gamepad button press/hold/release tracking
// - Analog axis input (thumbsticks, triggers)
// - Axis-to-button conversion (directional stick movement → dpad-like buttons)
// - Gamepad configuration and device info
//
// The module maintains per-button state tracking in InputState:
// - gamepadButtonsPressedThisFrame: New button presses (first frame only)
// - gamepadButtonsHeldThisFrame: Currently held buttons
// - gamepadHeldButtonDurations: How long each button has been held
// - gamepadButtonsReleasedThisFrame: Buttons released this frame
//
// Axis System:
// - Axes are polled and converted to button presses when thresholds are crossed
// - axis_buttons map tracks which directional button is active per stick/trigger
// - Supports left/right stick, left/right trigger axis tracking
//
// HID Integration:
// - ReconfigureInputDeviceInfo() updates last-used device type
// - SetCurrentGamepad() configures active gamepad name and console type
// - UpdateUISprites() updates button prompt sprites based on controller type
//
// Key Functions:
// - ProcessButtonPress/Release: Update button state maps
// - ButtonPressUpdate/HeldButtonUpdate/ReleasedButtonUpdate: Per-frame updates
// - ProcessAxisButtons: Convert analog stick movement to button presses
// - UpdateGamepadAxisInput: Poll and process all gamepad axes
// -----------------------------------------------------------------------------

#include "entt/entt.hpp"
#include "input_function_data.hpp"
#include "raylib.h"

namespace input {
namespace gamepad {

    // Core button state processing
    void ProcessButtonPress(InputState &state, GamepadButton button);
    void ProcessButtonRelease(InputState &state, GamepadButton button);

    // Per-frame update functions for different button states
    void ButtonPressUpdate(entt::registry &registry, InputState &state, const GamepadButton button, float dt);
    void HeldButtonUpdate(entt::registry &registry, InputState &state, const GamepadButton button, float dt);
    void ReleasedButtonUpdate(entt::registry &registry, InputState &state, const GamepadButton button, float dt);

    // Axis processing
    // Converts analog stick movement into button-like directional presses
    void ProcessAxisButtons(InputState &state);

    // Updates all gamepad axis inputs and returns the category if axis input detected
    auto UpdateGamepadAxisInput(InputState &state, entt::registry &registry, float dt) -> InputDeviceInputCategory;

    // HID (Human Interface Device) Management
    // Updates device type tracking when gamepad input is detected
    auto ReconfigureInputDeviceInfo(InputState &state, InputDeviceInputCategory category, GamepadButton button = GamepadButton::GAMEPAD_BUTTON_UNKNOWN) -> void;

    // Updates UI button sprites based on console type (Xbox, PlayStation, Nintendo, etc.)
    auto UpdateUISprites(const std::string &console_type) -> void;

    // Sets the current active gamepad configuration
    auto SetCurrentGamepad(InputState &state, const std::string &gamepad_object, int gamepadID) -> void;

} // namespace gamepad
} // namespace input
