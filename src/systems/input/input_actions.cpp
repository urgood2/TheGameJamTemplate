#include "input_actions.hpp"
#include <algorithm>

namespace input::actions {

    auto rebuild_index(InputState &s) -> void {
        s.code_to_actions.clear();
        for (auto &kv : s.action_bindings) {
            const auto &name = kv.first;
            const auto &vec  = kv.second;
            for (size_t i = 0; i < vec.size(); ++i) {
                const auto &b = vec[i];
                // Only index bindings that can ever be active (context gating is rechecked at dispatch)
                s.code_to_actions.emplace(ActionKey{b.device, b.code}, std::pair<std::string,size_t>{name, i});
            }
        }
    }

    // per-frame cleanup; call at end of Update
    auto decay(InputState &s) -> void {
        for (auto &kv : s.actions) {
            auto &st = kv.second;
            st.pressed = false;
            st.released = false;
            st.down = false;
            st.value = 0.f; // axis value is recomputed each frame
        }
    }

    // O(1) dispatch for raw events/axes
    auto dispatch_raw(InputState &s, InputDeviceInputCategory dev, int code, bool down, float value) -> void {
        if (s.rebind_listen) {
            ActionBinding b;
            b.device = dev;
            b.code = code;
            b.trigger = down ? ActionTrigger::Pressed : ActionTrigger::Released;
            s.rebind_listen = false;
            if (s.on_rebind_done) s.on_rebind_done(true, b);
            return;
        }

        auto range = s.code_to_actions.equal_range(ActionKey{dev, code});
        for (auto it = range.first; it != range.second; ++it) {
            const auto &name = it->second.first;
            const auto &bind = s.action_bindings[name][it->second.second];

            // context gate
            if (!(bind.context == "global" || bind.context == s.active_context)) continue;

            auto &st = s.actions[name];

            // trigger matching (if-chains per your style)
            if (bind.trigger == ActionTrigger::Pressed) {
                if (down) {
                    if (!st.down) st.pressed = true;  // only on rising edge
                    st.down = true;
                } else {
                    st.held = 0.f;
                }
            }
            else if (bind.trigger == ActionTrigger::Released) {
                if (!down) { st.released = true; st.down = false; st.held = 0.f; }
            }
            else if (bind.trigger == ActionTrigger::Held) {
                if (down) st.down = true;
            }
            else if (bind.trigger == ActionTrigger::Repeat) {
                // implement your repeat cadence if desired
            }
            else if (bind.trigger == ActionTrigger::AxisPos) {
                if (value > bind.threshold) st.value = std::max(st.value, value);
            }
            else if (bind.trigger == ActionTrigger::AxisNeg) {
                if (value < -bind.threshold) st.value = std::min(st.value, value);
            }
        }
    }

    // Tick held timers; call once per frame before decay
    auto tick_holds(InputState &s, float dt) -> void {
        for (auto &kv : s.actions) if (kv.second.down) kv.second.held += dt;
    }

    // Public C++ API
    auto bind(InputState &s, const std::string &action, const ActionBinding &b) -> void {
        s.action_bindings[action].push_back(b);
        rebuild_index(s);
    }

    auto clear(InputState &s, const std::string &action) -> void {
        s.action_bindings.erase(action);
        s.actions.erase(action);
        rebuild_index(s);
    }

    auto set_context(InputState &s, const std::string &ctx) -> void {
        s.active_context = ctx;
        // no need to rebuild index here; we check context on dispatch
    }

    auto pressed(const InputState &s, const std::string &a) -> bool {
        auto it = s.actions.find(a);
        return it != s.actions.end() ? it->second.pressed : false;
    }

    auto released(const InputState &s, const std::string &a) -> bool {
        auto it = s.actions.find(a);
        return it != s.actions.end() ? it->second.released : false;
    }

    auto down(const InputState &s, const std::string &a) -> bool {
        auto it = s.actions.find(a);
        return it != s.actions.end() ? it->second.down : false;
    }

    auto value(const InputState &s, const std::string &a) -> float {
        auto it = s.actions.find(a);
        return it != s.actions.end() ? it->second.value : 0.f;
    }

    auto start_rebind(InputState &s, const std::string &action, std::function<void(bool, ActionBinding)> cb) -> void {
        s.rebind_action = action;
        s.on_rebind_done = std::move(cb);
        s.rebind_listen = true;
    }

    auto to_device(const std::string &s) -> InputDeviceInputCategory {
        if (s == "keyboard") return InputDeviceInputCategory::KEYBOARD;
        if (s == "mouse")    return InputDeviceInputCategory::MOUSE;
        if (s == "gamepad_button") return InputDeviceInputCategory::GAMEPAD_BUTTON;
        if (s == "gamepad_axis")   return InputDeviceInputCategory::GAMEPAD_AXIS;
        return InputDeviceInputCategory::NONE;
    }

    auto to_trigger(const std::string &s) -> ActionTrigger {
        if (s == "Pressed")  return ActionTrigger::Pressed;
        if (s == "Released") return ActionTrigger::Released;
        if (s == "Held")     return ActionTrigger::Held;
        if (s == "Repeat")   return ActionTrigger::Repeat;
        if (s == "AxisPos")  return ActionTrigger::AxisPos;
        if (s == "AxisNeg")  return ActionTrigger::AxisNeg;
        return ActionTrigger::Pressed;
    }

} // namespace input::actions
