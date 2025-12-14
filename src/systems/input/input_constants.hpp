#pragma once

namespace input::constants {
    // ========================================================================
    // Gamepad Axis Deadzone & Threshold Values
    // ========================================================================

    // Gamepad axis movement detection threshold (applied to all axes)
    constexpr float GAMEPAD_AXIS_MOVEMENT_THRESHOLD = 0.2f;

    // Left stick deadzone for cursor/directional input (10%)
    constexpr float LEFT_STICK_DEADZONE = 0.1f;

    // Right stick deadzone for cursor movement (20%)
    constexpr float RIGHT_STICK_DEADZONE = 0.2f;

    // Left stick threshold for directional button interpretation (high sensitivity)
    constexpr float LEFT_STICK_DPAD_ACTIVATION_THRESHOLD = 0.5f;

    // Left stick threshold for releasing directional button interpretation
    constexpr float LEFT_STICK_DPAD_RELEASE_THRESHOLD = 0.3f;

    // Trigger activation threshold (treated as button press above this)
    constexpr float TRIGGER_ACTIVATION_THRESHOLD = 0.5f;

    // Trigger release threshold (treated as button release below this)
    constexpr float TRIGGER_RELEASE_THRESHOLD = 0.3f;

    // ========================================================================
    // Mouse & Cursor Settings
    // ========================================================================

    // Minimum mouse movement in pixels to be considered as movement
    constexpr float MOUSE_MOVEMENT_THRESHOLD = 1.0f;

    // ========================================================================
    // Scroll Settings
    // ========================================================================

    // Scroll speed multiplier for mouse wheel scrolling
    constexpr float SCROLL_SPEED = 10.0f;

    // ========================================================================
    // Click & Timing Constants
    // ========================================================================

    // Default click timeout duration in seconds (max time between down and up)
    constexpr float DEFAULT_CLICK_TIMEOUT = 0.05f;

    // Frame lock reset duration for overlay menu
    constexpr float OVERLAY_MENU_FRAME_LOCK_DURATION = 0.1f;

    // ========================================================================
    // Button Repeat & Hold Timings
    // ========================================================================

    // Initial delay before directional button starts repeating (seconds)
    constexpr float BUTTON_REPEAT_INITIAL_DELAY = 0.3f;

    // Delay between subsequent directional button repeats (seconds)
    constexpr float BUTTON_REPEAT_SUBSEQUENT_DELAY = 0.1f;

    // Hold duration threshold for button hold detection (coyote time)
    constexpr float BUTTON_HOLD_COYOTE_TIME = 0.12f;

    // Hold duration before slider enters continuous mode
    constexpr float SLIDER_HOLD_ACTIVATION_TIME = 0.2f;

    // ========================================================================
    // Keyboard Key Hold Settings
    // ========================================================================

    // Duration a key must be held before triggering hold reset behavior
    constexpr float KEY_HOLD_RESET_DURATION = 0.7f;

    // ========================================================================
    // Controller Navigation Constants
    // ========================================================================

    // Minimum focus vector magnitude for directional navigation
    constexpr float FOCUS_VECTOR_THRESHOLD = 0.1f;

    // Vibration intensity added on focus/selection
    constexpr float FOCUS_VIBRATION_INTENSITY = 0.7f;

    // Vibration intensity added on action confirmation
    constexpr float ACTION_VIBRATION_INTENSITY = 1.0f;

    // ========================================================================
    // Slider Adjustment Constants
    // ========================================================================

    // Slider discrete step size for single press
    constexpr float SLIDER_DISCRETE_STEP = 0.01f;

    // Slider continuous adjustment multiplier (applied with hold duration)
    constexpr float SLIDER_CONTINUOUS_MULTIPLIER = 0.6f;

    // ========================================================================
    // Input Binding Defaults
    // ========================================================================

    // Default threshold for input binding activation
    constexpr float INPUT_BINDING_DEFAULT_THRESHOLD = 0.5f;

    // ========================================================================
    // Geometric/Position Calculations
    // ========================================================================

    // Multiplier for getting center position (0.5 * width/height)
    constexpr float CENTER_POSITION_MULTIPLIER = 0.5f;

} // namespace input::constants
