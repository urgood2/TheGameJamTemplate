#pragma once

#include "input.hpp"
#include "input_function_data.hpp"
#include "raylib.h"
#include "entt/entt.hpp"
#include <memory>

// Forward declarations
struct EngineContext;

namespace input::polling {

/**
 * @brief Abstract interface for input providers (enables testing with mocks)
 *
 * This interface abstracts all direct Raylib input polling calls, allowing
 * the input system to be unit tested with mock input providers.
 */
struct IInputProvider {
    virtual ~IInputProvider() = default;

    // Keyboard
    virtual bool is_key_down(int key) const = 0;
    virtual bool is_key_released(int key) const = 0;
    virtual int get_char_pressed() const = 0;

    // Mouse
    virtual bool is_mouse_button_down(int button) const = 0;
    virtual bool is_mouse_button_pressed(int button) const = 0;
    virtual Vector2 get_mouse_delta() const = 0;
    virtual float get_mouse_wheel_move() const = 0;

    // Touch
    virtual int get_touch_point_count() const = 0;

    // Gamepad
    virtual bool is_gamepad_available(int id) const = 0;
    virtual bool is_gamepad_button_down(int id, int button) const = 0;
    virtual float get_gamepad_axis_movement(int id, int axis) const = 0;
    virtual const char* get_gamepad_name(int id) const = 0;
    virtual int get_gamepad_axis_count(int id) const = 0;
};

/**
 * @brief Raylib implementation (production)
 *
 * This implementation delegates all calls to the actual Raylib functions.
 */
struct RaylibInputProvider : IInputProvider {
    bool is_key_down(int key) const override;
    bool is_key_released(int key) const override;
    int get_char_pressed() const override;

    bool is_mouse_button_down(int button) const override;
    bool is_mouse_button_pressed(int button) const override;
    Vector2 get_mouse_delta() const override;
    float get_mouse_wheel_move() const override;

    int get_touch_point_count() const override;

    bool is_gamepad_available(int id) const override;
    bool is_gamepad_button_down(int id, int button) const override;
    float get_gamepad_axis_movement(int id, int axis) const override;
    const char* get_gamepad_name(int id) const override;
    int get_gamepad_axis_count(int id) const override;
};

/**
 * @brief Provider management
 *
 * Get the current input provider (defaults to Raylib implementation).
 */
IInputProvider& get_provider();

/**
 * @brief Set a custom input provider (primarily for testing)
 *
 * @param provider Custom provider to use (pass nullptr to reset to default)
 */
void set_provider(std::unique_ptr<IInputProvider> provider);

/**
 * @brief Main polling function - polls all input types and updates InputState
 *
 * This is the main entry point for raw input polling. It:
 * - Polls keyboard, mouse, touch, and gamepad input
 * - Updates InputState with current frame input
 * - Publishes input events to the event bus
 *
 * @param reg Entity registry
 * @param state Input state to update
 * @param dt Delta time
 * @param ctx Optional engine context (for event bus)
 */
void poll_all_inputs(entt::registry& reg, InputState& state, float dt, EngineContext* ctx = nullptr);

/**
 * @brief Mouse activity detection
 *
 * Detects whether the mouse has moved or been clicked this frame.
 * Updates the stored cursor position if activity is detected.
 *
 * @param state Input state
 * @return InputDeviceInputCategory::MOUSE if activity detected, otherwise NONE
 */
InputDeviceInputCategory detect_mouse_activity(InputState& state);

} // namespace input::polling
