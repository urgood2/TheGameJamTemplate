#include "input_hid.hpp"

#include "raylib.h"
#include "spdlog/spdlog.h"
#include "magic_enum/magic_enum.hpp"

#include "core/globals.hpp"
#include "components/components.hpp"
#include "systems/ui/ui_data.hpp"

#include <map>

namespace input::hid {

    void safe_hide_cursor()
    {
        if (IsWindowReady())
            HideCursor();
    }

    void safe_show_cursor()
    {
        if (IsWindowReady())
            ShowCursor();
    }

    void reconfigure_device_info(entt::registry& registry, InputState& state, InputDeviceInputCategory category, const GamepadButton button)
    {
        if (category == InputDeviceInputCategory::NONE || category == state.hid.last_type)
            return;

        const bool isControllerInput =
            category == InputDeviceInputCategory::GAMEPAD_AXIS ||
            category == InputDeviceInputCategory::GAMEPAD_BUTTON ||
            category == InputDeviceInputCategory::GAMEPAD_AXIS_CURSOR;

        const bool isMouseKeyboardTouch =
            category == InputDeviceInputCategory::KEYBOARD ||
            category == InputDeviceInputCategory::MOUSE ||
            category == InputDeviceInputCategory::TOUCH;

        //----------------------------------------------------------
        // CONTROLLER INPUT: Enable controller mode persistently
        //----------------------------------------------------------
        if (isControllerInput)
        {
            if (!state.hid.controller_enabled)
            {
                SPDLOG_DEBUG("Switching to controller input: {}", magic_enum::enum_name(category));
                safe_hide_cursor();
            }

            state.hid.controller_enabled = true;
            state.hid.last_type = category;
            state.hid.dpad_enabled = true;
            state.hid.pointer_enabled = (category == InputDeviceInputCategory::GAMEPAD_AXIS_CURSOR);
            state.hid.axis_cursor_enabled = (category == InputDeviceInputCategory::GAMEPAD_AXIS_CURSOR);
            state.hid.mouse_enabled = false;
            state.hid.touch_enabled = false;
            return;
        }

        //----------------------------------------------------------
        // MOUSE / KEYBOARD / TOUCH INPUT: Disable controller mode
        //----------------------------------------------------------
        if (isMouseKeyboardTouch && state.hid.controller_enabled)
        {
            SPDLOG_DEBUG("Switching away from controller input to {}", magic_enum::enum_name(category));

            state.hid.controller_enabled = false;
            state.hid.last_type = category;
            state.hid.dpad_enabled = (category == InputDeviceInputCategory::KEYBOARD);
            state.hid.pointer_enabled = (category == InputDeviceInputCategory::MOUSE || category == InputDeviceInputCategory::TOUCH);
            state.hid.mouse_enabled = (category == InputDeviceInputCategory::MOUSE);
            state.hid.touch_enabled = (category == InputDeviceInputCategory::TOUCH);
            state.hid.axis_cursor_enabled = false;

            // clear controller metadata
            state.gamepad.console.clear();
            state.gamepad.object.clear();
            state.gamepad.mapping.clear();
            state.gamepad.name.clear();

            // restore cursor
            safe_show_cursor();

            // unfocus UI
            auto view = registry.view<transform::GameObject, ui::UIConfig>();
            for (auto entity : view)
                view.get<transform::GameObject>(entity).state.isBeingFocused = false;
        }
    }

    void update_ui_sprites(const std::string& console_type)
    {
        // LATER: implement later if needed
        //  Update sprites based on console type (e.g., load textures, modify UI)
        if (console_type == "Nintendo")
        {
            // Set Nintendo-specific icons
        }
        else if (console_type == "PlayStation")
        {
            // Set PlayStation-specific icons
        }
        else
        {
            // Default to Xbox
        }
    }

    std::string deduce_console_from_gamepad(int gamepadIndex)
    {
        if (!IsGamepadAvailable(gamepadIndex))
            return "No Gamepad";

        std::string gamepadName = GetGamepadName(gamepadIndex);

        // Gamepad name patterns for different consoles
        std::map<std::string, std::string> gamepadPatterns = {
            {"PS", "PlayStation"},
            {"Sony", "PlayStation"},
            {"DualShock", "PlayStation"},
            {"DualSense", "PlayStation"},
            {"Wireless Controller", "PlayStation"}, // DualSense controller
            {"Nintendo", "Nintendo"},
            {"Switch", "Nintendo"},
            {"Joy-Con", "Nintendo"},
            {"Pro Controller", "Nintendo"},
            {"Xbox", "Xbox"},
            {"XInput", "Xbox"},
            {"Elite", "Xbox"},
            {"360", "Xbox"},
        };

        for (const auto& [pattern, console] : gamepadPatterns)
        {
            if (gamepadName.find(pattern) != std::string::npos)
            {
                return console;
            }
        }

        return "Unknown Console"; // Default case
    }

    void set_current_gamepad(InputState& state, const std::string& gamepad_object, int gamepadID)
    {
        if (state.gamepad.object != gamepad_object)
        {
            state.gamepad.object = gamepad_object;

            // Get mapping string and name
            // state.gamepad.mapping = getGamepadMappingString(gamepad_object);
            state.gamepad.name = GetGamepadName(gamepadID);

            // Determine the console type
            std::string console_type = deduce_console_from_gamepad(gamepadID);
            if (state.gamepad.console != console_type)
            {
                state.gamepad.console = console_type;

                // Update UI elements based on console type (e.g., sprites)
                update_ui_sprites(state.gamepad.console);
            }

            state.gamepad.id = gamepadID;
        }
    }

} // namespace input::hid
