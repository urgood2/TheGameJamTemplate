#pragma once

#include "input.hpp"
#include <string>

namespace input::hid {
    /**
     * @brief Switch input device mode based on detected input category
     *
     * Handles switching between mouse/keyboard/touch and gamepad input modes,
     * managing cursor visibility, controller state, and UI focus.
     *
     * @param state Input state to modify
     * @param category Type of input detected
     * @param button Optional button that triggered the switch (for gamepad)
     */
    void reconfigure_device_info(entt::registry& registry, InputState& state, InputDeviceInputCategory category,
                                 GamepadButton button = GAMEPAD_BUTTON_UNKNOWN);

    /**
     * @brief Update UI sprites based on console type
     *
     * Updates UI elements to show appropriate button prompts for the current console.
     * Currently placeholder, to be implemented when needed.
     *
     * @param consoleType Type of console ("PlayStation", "Xbox", "Nintendo", etc.)
     */
    void update_ui_sprites(const std::string& consoleType);

    /**
     * @brief Detect console type from gamepad name
     *
     * Analyzes gamepad name string to determine manufacturer/console type.
     * Used to show appropriate button icons in UI.
     *
     * @param gamepadIndex Index of gamepad to check
     * @return Console type string ("PlayStation", "Xbox", "Nintendo", "Unknown Console", "No Gamepad")
     */
    std::string deduce_console_from_gamepad(int gamepadIndex);

    /**
     * @brief Set the currently active gamepad
     *
     * Updates gamepad metadata in input state and triggers console detection.
     *
     * @param state Input state to modify
     * @param gamepadObject Gamepad object identifier
     * @param gamepadID Gamepad index
     */
    void set_current_gamepad(InputState& state, const std::string& gamepadObject, int gamepadID);

    /**
     * @brief Safely hide cursor (checks if window is ready)
     *
     * Only hides cursor if window is ready (avoids issues in headless tests).
     */
    void safe_hide_cursor();

    /**
     * @brief Safely show cursor (checks if window is ready)
     *
     * Only shows cursor if window is ready (avoids issues in headless tests).
     */
    void safe_show_cursor();
}
