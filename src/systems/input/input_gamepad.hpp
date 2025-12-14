#pragma once

#include "input.hpp"
#include <entt/entt.hpp>

struct EngineContext;

namespace input::gamepad {

// Button processing
auto process_button_press(InputState& state, GamepadButton button, EngineContext* ctx = nullptr) -> void;
auto process_button_release(InputState& state, GamepadButton button, EngineContext* ctx = nullptr) -> void;
auto button_press_update(entt::registry& reg, InputState& state, GamepadButton button, float dt) -> void;
auto held_button_update(entt::registry& reg, InputState& state, GamepadButton button, float dt) -> void;
void released_button_update(entt::registry& reg, InputState& state, GamepadButton button, float dt);

// Axis processing
auto process_axis_buttons(InputState& state, EngineContext* ctx = nullptr) -> void;
auto update_axis_input(InputState& state, entt::registry& reg, float dt, EngineContext* ctx = nullptr) -> InputDeviceInputCategory;

} // namespace input::gamepad
