#include "input_keyboard.hpp"
#include "core/globals.hpp"
#include "input_constants.hpp"
#include <unordered_map>
#include <utility>

namespace input::keyboard {

    void handle_text_input(ui::TextInput& input) {
        // Process all characters pressed this frame
        int key = GetCharPressed();
        SPDLOG_DEBUG("Handling text input, char pressed: {}", key);
        while (key > 0) {
            // Filter to printable ASCII 32..126
            if ((key >= 32) && (key <= 126) && input.text.length() < input.maxLength) {
                char c = static_cast<char>(key);

                if (input.allCaps) {
                    c = toupper(c);
                }

                // Insert at cursor position
                input.text.insert(input.cursorPos, 1, c);
                input.cursorPos++;
            }

            key = GetCharPressed(); // Get next character in queue
        }

        // Handle Backspace
        if (IsKeyPressed(KEY_BACKSPACE) && input.cursorPos > 0) {
            input.text.erase(input.cursorPos - 1, 1);
            input.cursorPos--;
        }

        // Move cursor left/right
        if (IsKeyPressed(KEY_LEFT) && input.cursorPos > 0) {
            input.cursorPos--;
        }
        if (IsKeyPressed(KEY_RIGHT) && input.cursorPos < input.text.length()) {
            input.cursorPos++;
        }

        // Handle Enter
        if (IsKeyPressed(KEY_ENTER) && input.callback) {
            input.callback();
        }
    }

    char get_character_from_key(KeyboardKey key, bool caps) {
        static std::unordered_map<KeyboardKey, std::pair<char, char>> keyMap = {
            {KEY_A, {'a', 'A'}}, {KEY_B, {'b', 'B'}}, {KEY_C, {'c', 'C'}}, {KEY_D, {'d', 'D'}},
            {KEY_E, {'e', 'E'}}, {KEY_F, {'f', 'F'}}, {KEY_G, {'g', 'G'}}, {KEY_H, {'h', 'H'}},
            {KEY_I, {'i', 'I'}}, {KEY_J, {'j', 'J'}}, {KEY_K, {'k', 'K'}}, {KEY_L, {'l', 'L'}},
            {KEY_M, {'m', 'M'}}, {KEY_N, {'n', 'N'}}, {KEY_O, {'o', 'O'}}, {KEY_P, {'p', 'P'}},
            {KEY_Q, {'q', 'Q'}}, {KEY_R, {'r', 'R'}}, {KEY_S, {'s', 'S'}}, {KEY_T, {'t', 'T'}},
            {KEY_U, {'u', 'U'}}, {KEY_V, {'v', 'V'}}, {KEY_W, {'w', 'W'}}, {KEY_X, {'x', 'X'}},
            {KEY_Y, {'y', 'Y'}}, {KEY_Z, {'z', 'Z'}},
            {KEY_ZERO, {'0', ')'}}, {KEY_ONE, {'1', '!'}}, {KEY_TWO, {'2', '@'}},
            {KEY_THREE, {'3', '#'}}, {KEY_FOUR, {'4', '$'}}, {KEY_FIVE, {'5', '%'}},
            {KEY_SIX, {'6', '^'}}, {KEY_SEVEN, {'7', '&'}}, {KEY_EIGHT, {'8', '*'}},
            {KEY_NINE, {'9', '('}},
            {KEY_SPACE, {' ', ' '}},
            {KEY_MINUS, {'-', '_'}}, {KEY_EQUAL, {'=', '+'}},
            {KEY_LEFT_BRACKET, {'[', '{'}}, {KEY_RIGHT_BRACKET, {']', '}'}},
            {KEY_SEMICOLON, {';', ':'}}, {KEY_APOSTROPHE, {'\'', '"'}},
            {KEY_COMMA, {',', '<'}}, {KEY_PERIOD, {'.', '>'}},
            {KEY_SLASH, {'/', '?'}}, {KEY_BACKSLASH, {'\\', '|'}}
        };

        if (keyMap.find(key) != keyMap.end()) {
            return caps ? keyMap[key].second : keyMap[key].first;
        }
        return '\0'; // Return null character if not found
    }

    void process_text_input(entt::registry& registry, entt::entity entity, KeyboardKey key, bool shift, bool capsLock) {
        auto& textInput = registry.get<ui::TextInput>(entity);

        bool caps = capsLock || shift || textInput.allCaps;
        char inputChar = get_character_from_key(key, caps);

        // Backspace: Remove previous character
        if (key == KEY_BACKSPACE && textInput.cursorPos > 0) {
            textInput.text.erase(textInput.cursorPos - 1, 1);
            textInput.cursorPos--;
        }
        // Delete: Remove next character
        else if (key == KEY_DELETE && textInput.cursorPos < textInput.text.size()) {
            textInput.text.erase(textInput.cursorPos, 1);
        }
        // Enter: Finish input and execute callback
        else if (key == KEY_ENTER) {
            if (textInput.callback)
                textInput.callback();
            registry.remove<ui::TextInput>(entity); // Unhook text input
        }
        // Arrow Left: Move cursor left
        else if (key == KEY_LEFT) {
            if (textInput.cursorPos > 0) {
                textInput.cursorPos--;
            }
        }
        // Arrow Right: Move cursor right
        else if (key == KEY_RIGHT) {
            if (textInput.cursorPos < textInput.text.size()) {
                textInput.cursorPos++;
            }
        }
        // Normal character input
        else if (inputChar != '\0' && textInput.text.length() < textInput.maxLength) {
            textInput.text.insert(textInput.cursorPos, 1, inputChar);
            textInput.cursorPos++;
        }
    }

    void hook_text_input(entt::registry& registry, entt::entity entity) {
        registry.emplace_or_replace<ui::TextInput>(entity, ui::TextInput{});
    }

    void unhook_text_input(entt::registry& registry, entt::entity entity) {
        registry.remove<ui::TextInput>(entity);
    }

    void key_press_update(entt::registry& registry, InputState& state, KeyboardKey key, float dt) {
        // Exit early if frame locks are active
        if (state.activeInputLocks["frame"])
            return;

        // Normalize keys (adjustments for keypad keys and enter key)
        KeyboardKey normalizedKey = key;
        if (key == KEY_KP_ENTER)
            normalizedKey = KEY_ENTER;

        // Handle text input hook
        if (state.text_input_hook) {
            if (normalizedKey == KEY_ESCAPE) {
                state.text_input_hook.reset(); // Clear text input hook
            }
            else if (normalizedKey == KEY_CAPS_LOCK) {
                state.capslock = !state.capslock; // Toggle capslock
            }
            else {
                process_text_input(registry, state.text_input_hook.value(), normalizedKey,
                                 state.keysHeldThisFrame[KEY_LEFT_SHIFT] || state.keysHeldThisFrame[KEY_RIGHT_SHIFT],
                                 state.capslock);
            }
            return;
        }

        // Escape key handling for menu and state transitions
        if (normalizedKey == KEY_ESCAPE) {
            // LATER: depending on game state, transition to different game states.
            // For instance, if in splash screen go to main menu
            // or if overlay menu is not active, open options menu
            // or if overlay menu is active, close it
        }

        // Exit if locks or frame restrictions are active
        if ((state.inputLocked && !globals::getIsGamePaused()) ||
            state.activeInputLocks["frame"] ||
            state.frame_buttonpress)
            return;

        state.frame_buttonpress = true;
        state.heldKeyDurations[normalizedKey] = 0;

#ifndef RELEASE_MODE
        // LATER: debug tools can be added here, depending on the key pressed
        //  Debug tool toggle
        //  debug tool ui,
        //  hover handling (hover_target)
        //  debug ui toggle, debug shortcuts for changing game state
        //  toggle mouse visibility
        //  toggle profiling
        //  toggle debug tooltips
        //  toggle performance mode, etc.

        // not sure if using macro is the best way to handle this.
#endif
    }

    void key_hold_update(InputState& state, KeyboardKey key, float dt) {
        // Exit early if locked or certain conditions are met
        if ((state.inputLocked && !globals::getIsGamePaused()) ||
            state.activeInputLocks["frame"] ||
            state.frame_buttonpress) {
            return;
        }

        // Check if the key is being tracked in heldKeyDurations
        if (state.heldKeyDurations.find(key) != state.heldKeyDurations.end()) {
            // Handle the "R" key specifically
            if (key == KEY_R && !globals::getIsGamePaused()) {
                // If the key has been held for more than the reset duration
                if (state.heldKeyDurations[key] > constants::KEY_HOLD_RESET_DURATION) {
                    // Do something - TODO: reset state?

                    // Reset key hold time
                    state.heldKeyDurations.erase(key);
                }
                else {
                    // Increment the hold time for the key
                    state.heldKeyDurations[key] += dt;
                }
            }
        }
    }

    void key_released_update(InputState& state, KeyboardKey key, float dt) {
        // Exit early if locked, paused, or certain frame conditions are met
        if ((state.inputLocked && !globals::getIsGamePaused()) ||
            state.activeInputLocks["frame"] ||
            state.frame_buttonpress) {
            return;
        }

        // Mark the frame as having processed a button press
        state.frame_buttonpress = true;

        // Toggle debug mode if "A" is released while "G" is held, and not in release mode
        if (key == KEY_A && state.keysHeldThisFrame[KEY_G] && !globals::getReleaseMode()) {
            // example way to toggle debug tools
        }

        // Handle "TAB" key to remove debug tools
        if (key == KEY_TAB /**&& flag to show debug tool active */) {
            // do something
        }
    }

    void process_key_down(InputState& state, KeyboardKey key) {
        state.keysPressedThisFrame[key] = true;
        state.keysHeldThisFrame[key] = true;

        input::DispatchRaw(state, InputDeviceInputCategory::KEYBOARD, (int)key, true);
    }

    void process_key_release(InputState& state, KeyboardKey key) {
        SPDLOG_DEBUG("Key released: {}", magic_enum::enum_name(key));
        state.keysHeldThisFrame.erase(key); // Remove the key from held keys
        state.keysReleasedThisFrame[key] = true;
        input::DispatchRaw(state, InputDeviceInputCategory::KEYBOARD, (int)key, false);
    }

} // namespace input::keyboard
