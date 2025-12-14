#pragma once

#include "input_function_data.hpp"
#include <string>
#include <functional>

namespace input::actions {
    // Action binding management
    auto rebuild_index(InputState& state) -> void;
    auto dispatch_raw(InputState& state, InputDeviceInputCategory dev, int code, bool down, float value = 0.f) -> void;

    // Frame lifecycle
    auto tick_holds(InputState& state, float dt) -> void;
    auto decay(InputState& state) -> void;

    // Public API (called from Lua bindings)
    auto bind(InputState& state, const std::string& action, const ActionBinding& binding) -> void;
    auto clear(InputState& state, const std::string& action) -> void;
    auto set_context(InputState& state, const std::string& ctx) -> void;

    // Query API
    auto pressed(const InputState& state, const std::string& action) -> bool;
    auto released(const InputState& state, const std::string& action) -> bool;
    auto down(const InputState& state, const std::string& action) -> bool;
    auto value(const InputState& state, const std::string& action) -> float;

    // Rebinding
    auto start_rebind(InputState& state, const std::string& action,
                      std::function<void(bool, ActionBinding)> callback) -> void;

    // String converters
    auto to_device(const std::string& s) -> InputDeviceInputCategory;
    auto to_trigger(const std::string& s) -> ActionTrigger;
}
