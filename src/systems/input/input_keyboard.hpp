#pragma once

#include "input.hpp"
#include "input_function_data.hpp"
#include "systems/ui/ui_data.hpp"
#include <entt/entt.hpp>

namespace input::keyboard {
    // Text input handling for UI components
    void handle_text_input(ui::TextInput& input);

    // Character conversion from keyboard keys
    char get_character_from_key(KeyboardKey key, bool caps);

    // Text input processing for entities
    void process_text_input(entt::registry& reg, entt::entity entity, KeyboardKey key, bool shift, bool capsLock);

    // Hook/unhook text input for entities
    void hook_text_input(entt::registry& reg, entt::entity entity);
    void unhook_text_input(entt::registry& reg, entt::entity entity);

    // Key state processing (press, hold, release)
    void key_press_update(entt::registry& reg, InputState& state, KeyboardKey key, float dt);
    void key_hold_update(InputState& state, KeyboardKey key, float dt);
    void key_released_update(InputState& state, KeyboardKey key, float dt);

    // Raw key event processing
    void process_key_down(InputState& state, KeyboardKey key);
    void process_key_release(InputState& state, KeyboardKey key);
}
