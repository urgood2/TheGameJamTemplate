#include "input_lua_bindings.hpp"

#include "raylib.h"

#include "entt/entt.hpp"

#include "core/globals.hpp"
#include "core/engine_context.hpp"

#include "input.hpp"
#include "input_actions.hpp"
#include "input_constants.hpp"
#include "input_functions.hpp"

#include "systems/scripting/binding_recorder.hpp"
#include "systems/scripting/sol2_helpers.hpp"

#include <string>

using namespace snowhouse; // assert

namespace input::lua_bindings {

    // Helper functions for context resolution
    static InputState& resolveInputState() {
        if (globals::g_ctx && globals::g_ctx->inputState) {
            return *globals::g_ctx->inputState;
        }
        return globals::getInputState();
    }

    static entt::registry& resolveRegistry() {
        return globals::getRegistry();
    }

    // Helper functions for action system
    static auto to_device(const std::string &s) -> InputDeviceInputCategory {
        return actions::to_device(s);
    }

    static auto to_trigger(const std::string &s) -> ActionTrigger {
        return actions::to_trigger(s);
    }

    void expose_to_lua(sol::state &lua, EngineContext* ctx)
    {
        (void)ctx; // currently unused; kept for context-aware expansion

        // Sol2 binding for input::InputState struct
        auto &L = lua;
        
        L.new_usertype<HIDFlags>("HIDFlags",
                                  sol::constructors<sol::types<>>(),
                                  "last_type", &HIDFlags::last_type,
                                  "dpad_enabled", &HIDFlags::dpad_enabled,
                                  "pointer_enabled", &HIDFlags::pointer_enabled,
                                  "touch_enabled", &HIDFlags::touch_enabled,
                                  "controller_enabled", &HIDFlags::controller_enabled,
                                  "mouse_enabled", &HIDFlags::mouse_enabled,
                                  "axis_cursor_enabled", &HIDFlags::axis_cursor_enabled);
        
        
        auto inputStateType = L.new_usertype<input::InputState>("InputState",
                                          sol::no_constructor,
                                          // Cursor targets and interaction
                                          "cursor_clicked_target", &input::InputState::cursor_clicked_target,
                                          "cursor_prev_clicked_target", &input::InputState::cursor_prev_clicked_target,
                                          "cursor_focused_target", &input::InputState::cursor_focused_target,
                                          "cursor_prev_focused_target", &input::InputState::cursor_prev_focused_target,
                                          "cursor_focused_target_area", &input::InputState::cursor_focused_target_area,
                                          "cursor_dragging_target", &input::InputState::cursor_dragging_target,
                                          "cursor_prev_dragging_target", &input::InputState::cursor_prev_dragging_target,
                                          "cursor_prev_released_on_target", &input::InputState::cursor_prev_released_on_target,
                                          "cursor_released_on_target", &input::InputState::cursor_released_on_target,
                                          "current_designated_hover_target", &input::InputState::current_designated_hover_target,
                                          "prev_designated_hover_target", &input::InputState::prev_designated_hover_target,
                                          "cursor_hovering_target", &input::InputState::cursor_hovering_target,
                                          "cursor_prev_hovering_target", &input::InputState::cursor_prev_hovering_target,
                                          "cursor_hovering_handled", &input::InputState::cursor_hovering_handled,

                                          // Collision and cursor lists
                                          "collision_list", &input::InputState::collision_list,
                                          "nodes_at_cursor", &input::InputState::nodes_at_cursor,

                                          // Cursor positions
                                          "cursor_position", &input::InputState::cursor_position,
                                          "cursor_down_position", &input::InputState::cursor_down_position,
                                          "cursor_up_position", &input::InputState::cursor_up_position,
                                          "focus_cursor_pos", &input::InputState::focus_cursor_pos,
                                          "cursor_down_time", &input::InputState::cursor_down_time,
                                          "cursor_up_time", &input::InputState::cursor_up_time,

                                          // Cursor handling flags
                                          "cursor_down_handled", &input::InputState::cursor_down_handled,
                                          "cursor_down_target", &input::InputState::cursor_down_target,
                                          "cursor_down_target_click_timeout", &input::InputState::cursor_down_target_click_timeout,
                                          "cursor_up_handled", &input::InputState::cursor_up_handled,
                                          "cursor_up_target", &input::InputState::cursor_up_target,
                                          "cursor_released_on_handled", &input::InputState::cursor_released_on_handled,
                                          "cursor_click_handled", &input::InputState::cursor_click_handled,
                                          "is_cursor_down", &input::InputState::is_cursor_down,

                                          // Frame button press
                                          "frame_buttonpress", &input::InputState::frame_buttonpress,
                                          "repress_timer", &input::InputState::repress_timer,
                                          "no_holdcap", &input::InputState::no_holdcap,

                                          // Text input hook
                                          "text_input_hook", &input::InputState::text_input_hook,
                                          "capslock", &input::InputState::capslock,
                                          "coyote_focus", &input::InputState::coyote_focus,

                                          "cursor_hover_transform", &input::InputState::cursor_hover_transform,
                                          "cursor_hover_time", &input::InputState::cursor_hover_time,
                                          "L_cursor_queue", &input::InputState::L_cursor_queue,

                                          // Key states
                                          "keysPressedThisFrame", &input::InputState::keysPressedThisFrame,
                                          "keysHeldThisFrame", &input::InputState::keysHeldThisFrame,
                                          "heldKeyDurations", &input::InputState::heldKeyDurations,
                                          "keysReleasedThisFrame", &input::InputState::keysReleasedThisFrame,

                                          // Gamepad buttons
                                          "gamepadButtonsPressedThisFrame", &input::InputState::gamepadButtonsPressedThisFrame,
                                          "gamepadButtonsHeldThisFrame", &input::InputState::gamepadButtonsHeldThisFrame,
                                          "gamepadHeldButtonDurations", &input::InputState::gamepadHeldButtonDurations,
                                          "gamepadButtonsReleasedThisFrame", &input::InputState::gamepadButtonsReleasedThisFrame,

                                          // Input locks
                                          "focus_interrupt", &input::InputState::focus_interrupt,
                                          "activeInputLocks", &input::InputState::activeInputLocks,
                                          "inputLocked", &input::InputState::inputLocked,

                                          // Axis buttons
                                          "axis_buttons", &input::InputState::axis_buttons,

                                          // Gamepad state
                                          "axis_cursor_speed", &input::InputState::axis_cursor_speed,
                                          "button_registry", &input::InputState::button_registry,
                                          "snap_cursor_to", &input::InputState::snap_cursor_to,

                                          // Cursor context & HID flags
                                          "cursor_context", &input::InputState::cursor_context,
                                          "hid", sol::property([](input::InputState &s) -> HIDFlags& {
    return s.hid;
}),

                                          // Gamepad config
                                          "gamepad", &input::InputState::gamepad,
                                          "overlay_menu_active_timer", &input::InputState::overlay_menu_active_timer,
                                          "overlay_menu_active", &input::InputState::overlay_menu_active,
                                          "screen_keyboard", &input::InputState::screen_keyboard);
                                          
        inputStateType["cursor_hovering_target"] = sol::property(
            [](input::InputState &state) -> entt::entity {
                return state.cursor_hovering_target;
            },
            [](input::InputState &state, entt::entity target) {
                state.cursor_hovering_target = target;
            });

        // Finally assign the singleton instance to globals.input.state
        // lua["globals"]["inputstate"] = &globals::inputState;

        // Replacing large enums with safe Lua table creation to avoid sol2 argument overflow

        // 1. Raylib KeyboardKey enum (complete)
        lua["KeyboardKey"] = lua.create_table_with(
            "KEY_NULL", KEY_NULL,
            "KEY_APOSTROPHE", KEY_APOSTROPHE,
            "KEY_COMMA", KEY_COMMA,
            "KEY_MINUS", KEY_MINUS,
            "KEY_PERIOD", KEY_PERIOD,
            "KEY_SLASH", KEY_SLASH,
            "KEY_ZERO", KEY_ZERO,
            "KEY_ONE", KEY_ONE,
            "KEY_TWO", KEY_TWO,
            "KEY_THREE", KEY_THREE,
            "KEY_FOUR", KEY_FOUR,
            "KEY_FIVE", KEY_FIVE,
            "KEY_SIX", KEY_SIX,
            "KEY_SEVEN", KEY_SEVEN,
            "KEY_EIGHT", KEY_EIGHT,
            "KEY_NINE", KEY_NINE,
            "KEY_SEMICOLON", KEY_SEMICOLON,
            "KEY_EQUAL", KEY_EQUAL,
            "KEY_A", KEY_A,
            "KEY_B", KEY_B,
            "KEY_C", KEY_C,
            "KEY_D", KEY_D,
            "KEY_E", KEY_E,
            "KEY_F", KEY_F,
            "KEY_G", KEY_G,
            "KEY_H", KEY_H,
            "KEY_I", KEY_I,
            "KEY_J", KEY_J,
            "KEY_K", KEY_K,
            "KEY_L", KEY_L,
            "KEY_M", KEY_M,
            "KEY_N", KEY_N,
            "KEY_O", KEY_O,
            "KEY_P", KEY_P,
            "KEY_Q", KEY_Q,
            "KEY_R", KEY_R,
            "KEY_S", KEY_S,
            "KEY_T", KEY_T,
            "KEY_U", KEY_U,
            "KEY_V", KEY_V,
            "KEY_W", KEY_W,
            "KEY_X", KEY_X,
            "KEY_Y", KEY_Y,
            "KEY_Z", KEY_Z,
            "KEY_LEFT_BRACKET", KEY_LEFT_BRACKET,
            "KEY_BACKSLASH", KEY_BACKSLASH,
            "KEY_RIGHT_BRACKET", KEY_RIGHT_BRACKET,
            "KEY_GRAVE", KEY_GRAVE,
            "KEY_SPACE", KEY_SPACE,
            "KEY_ESCAPE", KEY_ESCAPE,
            "KEY_ENTER", KEY_ENTER,
            "KEY_TAB", KEY_TAB,
            "KEY_BACKSPACE", KEY_BACKSPACE,
            "KEY_INSERT", KEY_INSERT,
            "KEY_DELETE", KEY_DELETE,
            "KEY_RIGHT", KEY_RIGHT,
            "KEY_LEFT", KEY_LEFT,
            "KEY_DOWN", KEY_DOWN,
            "KEY_UP", KEY_UP,
            "KEY_PAGE_UP", KEY_PAGE_UP,
            "KEY_PAGE_DOWN", KEY_PAGE_DOWN,
            "KEY_HOME", KEY_HOME,
            "KEY_END", KEY_END,
            "KEY_CAPS_LOCK", KEY_CAPS_LOCK,
            "KEY_SCROLL_LOCK", KEY_SCROLL_LOCK,
            "KEY_NUM_LOCK", KEY_NUM_LOCK,
            "KEY_PRINT_SCREEN", KEY_PRINT_SCREEN,
            "KEY_PAUSE", KEY_PAUSE,
            "KEY_F1", KEY_F1,
            "KEY_F2", KEY_F2,
            "KEY_F3", KEY_F3,
            "KEY_F4", KEY_F4,
            "KEY_F5", KEY_F5,
            "KEY_F6", KEY_F6,
            "KEY_F7", KEY_F7,
            "KEY_F8", KEY_F8,
            "KEY_F9", KEY_F9,
            "KEY_F10", KEY_F10,
            "KEY_F11", KEY_F11,
            "KEY_F12", KEY_F12,
            "KEY_LEFT_SHIFT", KEY_LEFT_SHIFT,
            "KEY_LEFT_CONTROL", KEY_LEFT_CONTROL,
            "KEY_LEFT_ALT", KEY_LEFT_ALT,
            "KEY_LEFT_SUPER", KEY_LEFT_SUPER,
            "KEY_RIGHT_SHIFT", KEY_RIGHT_SHIFT,
            "KEY_RIGHT_CONTROL", KEY_RIGHT_CONTROL,
            "KEY_RIGHT_ALT", KEY_RIGHT_ALT,
            "KEY_RIGHT_SUPER", KEY_RIGHT_SUPER,
            "KEY_KB_MENU", KEY_KB_MENU,
            "KEY_KP_0", KEY_KP_0,
            "KEY_KP_1", KEY_KP_1,
            "KEY_KP_2", KEY_KP_2,
            "KEY_KP_3", KEY_KP_3,
            "KEY_KP_4", KEY_KP_4,
            "KEY_KP_5", KEY_KP_5,
            "KEY_KP_6", KEY_KP_6,
            "KEY_KP_7", KEY_KP_7,
            "KEY_KP_8", KEY_KP_8,
            "KEY_KP_9", KEY_KP_9,
            "KEY_KP_DECIMAL", KEY_KP_DECIMAL,
            "KEY_KP_DIVIDE", KEY_KP_DIVIDE,
            "KEY_KP_MULTIPLY", KEY_KP_MULTIPLY,
            "KEY_KP_SUBTRACT", KEY_KP_SUBTRACT,
            "KEY_KP_ADD", KEY_KP_ADD,
            "KEY_KP_ENTER", KEY_KP_ENTER,
            "KEY_KP_EQUAL", KEY_KP_EQUAL,
            "KEY_BACK", KEY_BACK,
            "KEY_MENU", KEY_MENU,
            "KEY_VOLUME_UP", KEY_VOLUME_UP,
            "KEY_VOLUME_DOWN", KEY_VOLUME_DOWN);

        // 2. MouseButton enum
        lua["MouseButton"] = lua.create_table_with(
            "MOUSE_BUTTON_LEFT", MOUSE_BUTTON_LEFT,
            "MOUSE_BUTTON_RIGHT", MOUSE_BUTTON_RIGHT,
            "MOUSE_BUTTON_MIDDLE", MOUSE_BUTTON_MIDDLE,
            "MOUSE_BUTTON_SIDE", MOUSE_BUTTON_SIDE,
            "MOUSE_BUTTON_EXTRA", MOUSE_BUTTON_EXTRA,
            "MOUSE_BUTTON_FORWARD", MOUSE_BUTTON_FORWARD,
            "MOUSE_BUTTON_BACK", MOUSE_BUTTON_BACK);

        // 3. GamepadButton enum
        lua["GamepadButton"] = lua.create_table_with(
            "GAMEPAD_BUTTON_UNKNOWN", GAMEPAD_BUTTON_UNKNOWN,
            "GAMEPAD_BUTTON_LEFT_FACE_UP", GAMEPAD_BUTTON_LEFT_FACE_UP,
            "GAMEPAD_BUTTON_LEFT_FACE_RIGHT", GAMEPAD_BUTTON_LEFT_FACE_RIGHT,
            "GAMEPAD_BUTTON_LEFT_FACE_DOWN", GAMEPAD_BUTTON_LEFT_FACE_DOWN,
            "GAMEPAD_BUTTON_LEFT_FACE_LEFT", GAMEPAD_BUTTON_LEFT_FACE_LEFT,
            "GAMEPAD_BUTTON_RIGHT_FACE_UP", GAMEPAD_BUTTON_RIGHT_FACE_UP,
            "GAMEPAD_BUTTON_RIGHT_FACE_RIGHT", GAMEPAD_BUTTON_RIGHT_FACE_RIGHT,
            "GAMEPAD_BUTTON_RIGHT_FACE_DOWN", GAMEPAD_BUTTON_RIGHT_FACE_DOWN,
            "GAMEPAD_BUTTON_RIGHT_FACE_LEFT", GAMEPAD_BUTTON_RIGHT_FACE_LEFT,
            "GAMEPAD_BUTTON_LEFT_TRIGGER_1", GAMEPAD_BUTTON_LEFT_TRIGGER_1,
            "GAMEPAD_BUTTON_LEFT_TRIGGER_2", GAMEPAD_BUTTON_LEFT_TRIGGER_2,
            "GAMEPAD_BUTTON_RIGHT_TRIGGER_1", GAMEPAD_BUTTON_RIGHT_TRIGGER_1,
            "GAMEPAD_BUTTON_RIGHT_TRIGGER_2", GAMEPAD_BUTTON_RIGHT_TRIGGER_2,
            "GAMEPAD_BUTTON_MIDDLE_LEFT", GAMEPAD_BUTTON_MIDDLE_LEFT,
            "GAMEPAD_BUTTON_MIDDLE", GAMEPAD_BUTTON_MIDDLE,
            "GAMEPAD_BUTTON_MIDDLE_RIGHT", GAMEPAD_BUTTON_MIDDLE_RIGHT,
            "GAMEPAD_BUTTON_LEFT_THUMB", GAMEPAD_BUTTON_LEFT_THUMB,
            "GAMEPAD_BUTTON_RIGHT_THUMB", GAMEPAD_BUTTON_RIGHT_THUMB);

        // 4. GamepadAxis enum
        lua["GamepadAxis"] = lua.create_table_with(
            "GAMEPAD_AXIS_LEFT_X", GAMEPAD_AXIS_LEFT_X,
            "GAMEPAD_AXIS_LEFT_Y", GAMEPAD_AXIS_LEFT_Y,
            "GAMEPAD_AXIS_RIGHT_X", GAMEPAD_AXIS_RIGHT_X,
            "GAMEPAD_AXIS_RIGHT_Y", GAMEPAD_AXIS_RIGHT_Y,
            "GAMEPAD_AXIS_LEFT_TRIGGER", GAMEPAD_AXIS_LEFT_TRIGGER,
            "GAMEPAD_AXIS_RIGHT_TRIGGER", GAMEPAD_AXIS_RIGHT_TRIGGER);

        // 5. InputDeviceInputCategory enum
        lua["InputDeviceInputCategory"] = lua.create_table_with(
            "NONE", InputDeviceInputCategory::NONE,
            "GAMEPAD_AXIS_CURSOR", InputDeviceInputCategory::GAMEPAD_AXIS_CURSOR,
            "GAMEPAD_AXIS", InputDeviceInputCategory::GAMEPAD_AXIS,
            "GAMEPAD_BUTTON", InputDeviceInputCategory::GAMEPAD_BUTTON,
            "MOUSE", InputDeviceInputCategory::MOUSE,
            "TOUCH", InputDeviceInputCategory::TOUCH,
        
            "KEYBOARD", (int)InputDeviceInputCategory::KEYBOARD   // NEW
        );

        // 2. Simple structs
        lua.new_usertype<AxisButtonState>("AxisButtonState",
                                          sol::constructors<AxisButtonState()>(),
                                          "current", &AxisButtonState::current,
                                          "previous", &AxisButtonState::previous);

        lua.new_usertype<NodeData>("NodeData",
                                   sol::constructors<NodeData()>(),
                                   "node", &NodeData::node,
                                   "click", &NodeData::click,
                                   "menu", &NodeData::menu,
                                   "under_overlay", &NodeData::under_overlay);

        lua.new_usertype<SnapTarget>("SnapTarget",
                                     sol::constructors<SnapTarget()>(),
                                     "node", &SnapTarget::node,
                                     "transform", &SnapTarget::transform,
                                     "type", &SnapTarget::type);

        // CursorContext and nested CursorLayer
        lua.new_usertype<CursorContext::CursorLayer>("CursorLayer",
                                                     sol::constructors<CursorContext::CursorLayer()>(),
                                                     "cursor_focused_target", &CursorContext::CursorLayer::cursor_focused_target,
                                                     "cursor_position", &CursorContext::CursorLayer::cursor_position,
                                                     "focus_interrupt", &CursorContext::CursorLayer::focus_interrupt);

        lua.new_usertype<CursorContext>("CursorContext",
                                        sol::constructors<CursorContext()>(),
                                        "layer", &CursorContext::layer,
                                        "stack", &CursorContext::stack);

        lua.new_usertype<GamepadState>("GamepadState",
                                       sol::constructors<GamepadState()>(),
                                       "object", &GamepadState::object,
                                       "mapping", &GamepadState::mapping,
                                       "name", &GamepadState::name,
                                       "console", &GamepadState::console,
                                       "id", &GamepadState::id);

        lua.new_usertype<HIDFlags>("HIDFlags",
                                   sol::constructors<HIDFlags()>(),
                                   "last_type", &HIDFlags::last_type,
                                   "dpad_enabled", &HIDFlags::dpad_enabled,
                                   "pointer_enabled", &HIDFlags::pointer_enabled,
                                   "touch_enabled", &HIDFlags::touch_enabled,
                                   "controller_enabled", &HIDFlags::controller_enabled,
                                   "mouse_enabled", &HIDFlags::mouse_enabled,
                                   "axis_cursor_enabled", &HIDFlags::axis_cursor_enabled);


        // raylib input

        auto in = lua.create_named_table("input");

        // make function for testing if gamepad enabled
        in.set_function("isGamepadEnabled", []() -> bool {
            return resolveInputState().hid.controller_enabled;
        });
        
        // TODO: need to expose the enums too

        // Keyboard
        in.set_function("isKeyDown", &IsKeyDown);
        in.set_function("isKeyPressed", &IsKeyPressed);
        in.set_function("isKeyReleased", &IsKeyReleased);
        in.set_function("isKeyUp", &IsKeyUp);
        
    

        // Mouse
        in.set_function("isMouseDown", &IsMouseButtonDown);
        in.set_function("isMousePressed", &IsMouseButtonPressed);
        in.set_function("isMouseReleased", &IsMouseButtonReleased);
        in.set_function("getMousePos", &globals::getScaledMousePositionCached);
        in.set_function("getMouseWheel", &GetMouseWheelMove);
        
        in.set_function("updateCursorFocus", []() {
            auto& state = resolveInputState();
            auto& reg = resolveRegistry();
            UpdateCursor(state, reg);
        });
        
        // Clear the active scroll pane reference (used when rebuilding UI to fix stale entity references)
        in.set_function("clearActiveScrollPane", []() {
            auto& state = resolveInputState();
            state.activeScrollPane = entt::null;
        });

        // Gamepad
        in.set_function("isPadConnected", &IsGamepadAvailable);
        in.set_function("isPadButtonDown", &IsGamepadButtonDown);
        in.set_function("getPadAxis", &GetGamepadAxisMovement);

        // Text / misc
        in.set_function("getChar", &GetCharPressed);
        in.set_function("getKeyPressed", &GetKeyPressed);
        in.set_function("setExitKey", &SetExitKey);

        // --- BindingRecorder definitions for input system ---

        auto &rec = BindingRecorder::instance();
        auto inputPath = std::vector<std::string>{"input"};

        // 1) InputState usertype
        rec.add_type("InputState", true);
        auto &isDef = rec.add_type("InputState");
        isDef.doc = "Per-frame snapshot of cursor, keyboard, mouse, and gamepad state.";

#define PROP(typeName, propName, docString) \
    rec.record_property("InputState", {propName, typeName, docString});

        // Cursor targets & interaction
        PROP("Entity", "cursor_clicked_target", "Entity clicked this frame")
        PROP("Entity", "cursor_prev_clicked_target", "Entity clicked in previous frame")
        PROP("Entity", "cursor_focused_target", "Entity under cursor focus now")
        PROP("Entity", "cursor_prev_focused_target", "Entity under cursor focus last frame")
        PROP("Rectangle", "cursor_focused_target_area", "Bounds of the focused target")
        PROP("Entity", "cursor_dragging_target", "Entity currently being dragged")
        PROP("Entity", "cursor_prev_dragging_target", "Entity dragged last frame")
        PROP("Entity", "cursor_prev_released_on_target", "Entity released on target last frame")
        PROP("Entity", "cursor_released_on_target", "Entity released on target this frame")
        PROP("Entity", "current_designated_hover_target", "Entity designated for hover handling")
        PROP("Entity", "prev_designated_hover_target", "Previously designated hover target")
        PROP("Entity", "cursor_hovering_target", "Entity being hovered now")
        PROP("Entity", "cursor_prev_hovering_target", "Entity hovered last frame")
        PROP("bool", "cursor_hovering_handled", "Whether hover was already handled")

        // Collision & cursor lists
        PROP("std::vector<Entity>", "collision_list", "All entities colliding with cursor")
        PROP("std::vector<NodeData>", "nodes_at_cursor", "All UI nodes under cursor")

        // Cursor positions & timing
        PROP("Vector2", "cursor_position", "Current cursor position")
        PROP("Vector2", "cursor_down_position", "Position where cursor was pressed")
        PROP("Vector2", "cursor_up_position", "Position where cursor was released")
        PROP("Vector2", "focus_cursor_pos", "Cursor pos used for gamepad/keyboard focus")
        PROP("float", "cursor_down_time", "Time of last cursor press")
        PROP("float", "cursor_up_time", "Time of last cursor release")

        // Cursor handling flags
        PROP("bool", "cursor_down_handled", "Down event handled flag")
        PROP("Entity", "cursor_down_target", "Entity pressed down on")
        PROP("float", "cursor_down_target_click_timeout", "Click timeout interval")
        PROP("bool", "cursor_up_handled", "Up event handled flag")
        PROP("Entity", "cursor_up_target", "Entity released on")
        PROP("bool", "cursor_released_on_handled", "Release handled flag")
        PROP("bool", "cursor_click_handled", "Click handled flag")
        PROP("bool", "is_cursor_down", "Is cursor currently down?")

        // Frame button press
        PROP("std::vector<InputButton>", "frame_buttonpress", "Buttons pressed this frame")
        PROP("std::unordered_map<InputButton,float>", "repress_timer", "Cooldown per button")
        PROP("bool", "no_holdcap", "Disable repeated hold events")

        // Text input hook
        PROP("std::function<void(int)>", "text_input_hook", "Callback for text input events")
        PROP("bool", "capslock", "Is caps-lock active")
        PROP("bool", "coyote_focus", "Allow focus grace period")

        // Cursor hover & queue
        PROP("Transform", "cursor_hover_transform", "Transform under cursor")
        PROP("float", "cursor_hover_time", "Hover duration")
        PROP("std::deque<Entity>", "L_cursor_queue", "Recent cursor targets queue")

        // Key & gamepad state
        PROP("std::vector<KeyboardKey>", "keysPressedThisFrame", "Keys pressed this frame")
        PROP("std::vector<KeyboardKey>", "keysHeldThisFrame", "Keys held down")
        PROP("std::unordered_map<KeyboardKey,float>", "heldKeyDurations", "Hold durations per key")
        PROP("std::vector<KeyboardKey>", "keysReleasedThisFrame", "Keys released this frame")

        PROP("std::vector<GamepadButton>", "gamepadButtonsPressedThisFrame", "Gamepad buttons pressed this frame")
        PROP("std::vector<GamepadButton>", "gamepadButtonsHeldThisFrame", "Held gamepad buttons")
        PROP("std::unordered_map<GamepadButton,float>", "gamepadHeldButtonDurations", "Hold durations per button")
        PROP("std::vector<GamepadButton>", "gamepadButtonsReleasedThisFrame", "Released gamepad buttons")

        // Input locks
        PROP("bool", "focus_interrupt", "Interrupt focus navigation")
        PROP("std::vector<InputLock>", "activeInputLocks", "Currently active input locks")
        PROP("bool", "inputLocked", "Is global input locked")

        // Axis buttons
        PROP("std::unordered_map<GamepadAxis,AxisButtonState>", "axis_buttons", "Axis-as-button states")

        // Gamepad & cursor config
        PROP("float", "axis_cursor_speed", "Cursor speed from gamepad axis")
        PROP("ButtonRegistry", "button_registry", "Action-to-button mapping")
        PROP("SnapTarget", "snap_cursor_to", "Cursor snap target")

        // CursorContext & HID
        PROP("CursorContext", "cursor_context", "Nested cursor focus contexts")
        PROP("HIDFlags", "hid", "Current HID flags")

        // Gamepad state
        PROP("GamepadState", "gamepad", "Latest gamepad info")
        PROP("float", "overlay_menu_active_timer", "Overlay menu timer")
        PROP("bool", "overlay_menu_active", "Is overlay menu active")
        PROP("ScreenKeyboard", "screen_keyboard", "On-screen keyboard state")

#undef PROP

        // 2) Raylib KeyboardKey enum
        rec.add_type("KeyboardKey");
        auto &kkDef = rec.add_type("KeyboardKey");
        kkDef.doc = "Raylib keyboard key codes";
#define ENUM_PROP(name) rec.record_property("KeyboardKey", {#name, std::to_string(name), "Keyboard key enum"})
        ENUM_PROP(KEY_NULL);
        ENUM_PROP(KEY_APOSTROPHE);
        ENUM_PROP(KEY_COMMA);
        ENUM_PROP(KEY_MINUS);
        ENUM_PROP(KEY_PERIOD);
        ENUM_PROP(KEY_SLASH);
        ENUM_PROP(KEY_ZERO);
        ENUM_PROP(KEY_ONE);
        ENUM_PROP(KEY_TWO);
        ENUM_PROP(KEY_THREE);
        ENUM_PROP(KEY_FOUR);
        ENUM_PROP(KEY_FIVE);
        ENUM_PROP(KEY_SIX);
        ENUM_PROP(KEY_SEVEN);
        ENUM_PROP(KEY_EIGHT);
        ENUM_PROP(KEY_NINE);
        ENUM_PROP(KEY_SEMICOLON);
        ENUM_PROP(KEY_EQUAL);
        ENUM_PROP(KEY_A);
        ENUM_PROP(KEY_B);
        ENUM_PROP(KEY_C);
        ENUM_PROP(KEY_D);
        ENUM_PROP(KEY_E);
        ENUM_PROP(KEY_F);
        ENUM_PROP(KEY_G);
        ENUM_PROP(KEY_H);
        ENUM_PROP(KEY_I);
        ENUM_PROP(KEY_J);
        ENUM_PROP(KEY_K);
        ENUM_PROP(KEY_L);
        ENUM_PROP(KEY_M);
        ENUM_PROP(KEY_N);
        ENUM_PROP(KEY_O);
        ENUM_PROP(KEY_P);
        ENUM_PROP(KEY_Q);
        ENUM_PROP(KEY_R);
        ENUM_PROP(KEY_S);
        ENUM_PROP(KEY_T);
        ENUM_PROP(KEY_U);
        ENUM_PROP(KEY_V);
        ENUM_PROP(KEY_W);
        ENUM_PROP(KEY_X);
        ENUM_PROP(KEY_Y);
        ENUM_PROP(KEY_Z);
        ENUM_PROP(KEY_LEFT_BRACKET);
        ENUM_PROP(KEY_BACKSLASH);
        ENUM_PROP(KEY_RIGHT_BRACKET);
        ENUM_PROP(KEY_GRAVE);
        ENUM_PROP(KEY_SPACE);
        ENUM_PROP(KEY_ESCAPE);
        ENUM_PROP(KEY_ENTER);
        ENUM_PROP(KEY_TAB);
        ENUM_PROP(KEY_BACKSPACE);
        ENUM_PROP(KEY_INSERT);
        ENUM_PROP(KEY_DELETE);
        ENUM_PROP(KEY_RIGHT);
        ENUM_PROP(KEY_LEFT);
        ENUM_PROP(KEY_DOWN);
        ENUM_PROP(KEY_UP);
        ENUM_PROP(KEY_PAGE_UP);
        ENUM_PROP(KEY_PAGE_DOWN);
        ENUM_PROP(KEY_HOME);
        ENUM_PROP(KEY_END);
        ENUM_PROP(KEY_CAPS_LOCK);
        ENUM_PROP(KEY_SCROLL_LOCK);
        ENUM_PROP(KEY_NUM_LOCK);
        ENUM_PROP(KEY_PRINT_SCREEN);
        ENUM_PROP(KEY_PAUSE);
        ENUM_PROP(KEY_F1);
        ENUM_PROP(KEY_F2);
        ENUM_PROP(KEY_F3);
        ENUM_PROP(KEY_F4);
        ENUM_PROP(KEY_F5);
        ENUM_PROP(KEY_F6);
        ENUM_PROP(KEY_F7);
        ENUM_PROP(KEY_F8);
        ENUM_PROP(KEY_F9);
        ENUM_PROP(KEY_F10);
        ENUM_PROP(KEY_F11);
        ENUM_PROP(KEY_F12);
        ENUM_PROP(KEY_LEFT_SHIFT);
        ENUM_PROP(KEY_LEFT_CONTROL);
        ENUM_PROP(KEY_LEFT_ALT);
        ENUM_PROP(KEY_LEFT_SUPER);
        ENUM_PROP(KEY_RIGHT_SHIFT);
        ENUM_PROP(KEY_RIGHT_CONTROL);
        ENUM_PROP(KEY_RIGHT_ALT);
        ENUM_PROP(KEY_RIGHT_SUPER);
        ENUM_PROP(KEY_KB_MENU);
#undef ENUM_PROP

        // 3) MouseButton enum
        rec.add_type("MouseButton");
        rec.record_property("MouseButton", {"MOUSE_BUTTON_LEFT", std::to_string(MOUSE_BUTTON_LEFT), "Left mouse button"});
        rec.record_property("MouseButton", {"MOUSE_BUTTON_RIGHT", std::to_string(MOUSE_BUTTON_RIGHT), "Right mouse button"});
        rec.record_property("MouseButton", {"MOUSE_BUTTON_MIDDLE", std::to_string(MOUSE_BUTTON_MIDDLE), "Middle mouse button"});
        rec.record_property("MouseButton", {"MOUSE_BUTTON_SIDE", std::to_string(MOUSE_BUTTON_SIDE), "Side mouse button"});
        rec.record_property("MouseButton", {"MOUSE_BUTTON_EXTRA", std::to_string(MOUSE_BUTTON_EXTRA), "Extra mouse button"});
        rec.record_property("MouseButton", {"MOUSE_BUTTON_FORWARD", std::to_string(MOUSE_BUTTON_FORWARD), "Forward mouse button"});
        rec.record_property("MouseButton", {"MOUSE_BUTTON_BACK", std::to_string(MOUSE_BUTTON_BACK), "Back mouse button"});

        // 4) GamepadButton enum
        rec.add_type("GamepadButton");
#define GB(name) rec.record_property("GamepadButton", {#name, std::to_string(name), "Gamepad button enum"})
        GB(GAMEPAD_BUTTON_UNKNOWN);
        GB(GAMEPAD_BUTTON_LEFT_FACE_UP);
        GB(GAMEPAD_BUTTON_LEFT_FACE_RIGHT);
        GB(GAMEPAD_BUTTON_LEFT_FACE_DOWN);
        GB(GAMEPAD_BUTTON_LEFT_FACE_LEFT);
        GB(GAMEPAD_BUTTON_RIGHT_FACE_UP);
        GB(GAMEPAD_BUTTON_RIGHT_FACE_RIGHT);
        GB(GAMEPAD_BUTTON_RIGHT_FACE_DOWN);
        GB(GAMEPAD_BUTTON_RIGHT_FACE_LEFT);
        GB(GAMEPAD_BUTTON_LEFT_TRIGGER_1);
        GB(GAMEPAD_BUTTON_LEFT_TRIGGER_2);
        GB(GAMEPAD_BUTTON_RIGHT_TRIGGER_1);
        GB(GAMEPAD_BUTTON_RIGHT_TRIGGER_2);
        GB(GAMEPAD_BUTTON_MIDDLE_LEFT);
        GB(GAMEPAD_BUTTON_MIDDLE);
        GB(GAMEPAD_BUTTON_MIDDLE_RIGHT);
        GB(GAMEPAD_BUTTON_LEFT_THUMB);
        GB(GAMEPAD_BUTTON_RIGHT_THUMB);
#undef GB

        // 5) GamepadAxis enum
        rec.add_type("GamepadAxis");
#define GA(name) rec.record_property("GamepadAxis", {#name, std::to_string(name), "Gamepad axis enum"})
        GA(GAMEPAD_AXIS_LEFT_X);
        GA(GAMEPAD_AXIS_LEFT_Y);
        GA(GAMEPAD_AXIS_RIGHT_X);
        GA(GAMEPAD_AXIS_RIGHT_Y);
        GA(GAMEPAD_AXIS_LEFT_TRIGGER);
        GA(GAMEPAD_AXIS_RIGHT_TRIGGER);
#undef GA

        // 6) InputDeviceInputCategory enum
        rec.add_type("InputDeviceInputCategory");
        rec.record_property("InputDeviceInputCategory", {"NONE", std::to_string((int)InputDeviceInputCategory::NONE), "No input category"});
        rec.record_property("InputDeviceInputCategory", {"GAMEPAD_AXIS_CURSOR", std::to_string((int)InputDeviceInputCategory::GAMEPAD_AXIS_CURSOR), "Axis-driven cursor category"});
        rec.record_property("InputDeviceInputCategory", {"GAMEPAD_AXIS", std::to_string((int)InputDeviceInputCategory::GAMEPAD_AXIS), "Gamepad axis category"});
        rec.record_property("InputDeviceInputCategory", {"GAMEPAD_BUTTON", std::to_string((int)InputDeviceInputCategory::GAMEPAD_BUTTON), "Gamepad button category"});
        rec.record_property("InputDeviceInputCategory", {"MOUSE", std::to_string((int)InputDeviceInputCategory::MOUSE), "Mouse input category"});
        rec.record_property("InputDeviceInputCategory", {"TOUCH", std::to_string((int)InputDeviceInputCategory::TOUCH), "Touch input category"});

        // 7) Simple structs
        rec.add_type("AxisButtonState");
        rec.record_property("AxisButtonState", {"current", "bool", "Is axis beyond threshold this frame?"});
        rec.record_property("AxisButtonState", {"previous", "bool", "Was axis beyond threshold last frame?"});

        rec.add_type("NodeData");
        rec.record_property("NodeData", {"node", "Entity", "UI node entity"});
        rec.record_property("NodeData", {"click", "bool", "Was node clicked?"});
        rec.record_property("NodeData", {"menu", "bool", "Is menu open on node?"});
        rec.record_property("NodeData", {"under_overlay", "bool", "Is node under overlay?"});

        rec.add_type("SnapTarget");
        rec.record_property("SnapTarget", {"node", "Entity", "Target entity to snap cursor to"});
        rec.record_property("SnapTarget", {"transform", "Transform", "Target's transform"});
        rec.record_property("SnapTarget", {"type", "SnapType", "Snap behavior type"});

        rec.add_type("CursorContext::CursorLayer");
        rec.record_property("CursorContext::CursorLayer", {"cursor_focused_target", "Entity", "Layer's focused target entity"});
        rec.record_property("CursorContext::CursorLayer", {"cursor_position", "Vector2", "Layer's cursor position"});
        rec.record_property("CursorContext::CursorLayer", {"focus_interrupt", "bool", "Interrupt flag for this layer"});

        rec.add_type("CursorContext", true);
        rec.record_property("CursorContext", {"layer", "CursorContext::CursorLayer", "Current layer"});
        rec.record_property("CursorContext", {"stack", "std::vector<CursorContext::CursorLayer>", "Layer stack"});

        rec.add_type("GamepadState", true);
        rec.record_property("GamepadState", {"object", "GamepadObject", "Raw gamepad object"});
        rec.record_property("GamepadState", {"mapping", "GamepadMapping", "Button/axis mapping"});
        rec.record_property("GamepadState", {"name", "std::string", "Gamepad name"});
        rec.record_property("GamepadState", {"console", "bool", "Is console gamepad?"});
        rec.record_property("GamepadState", {"id", "int", "System device ID"});

        rec.add_type("HIDFlags");
        rec.record_property("HIDFlags", {"last_type", "InputDeviceInputCategory", "Last HID type used"});
        rec.record_property("HIDFlags", {"dpad_enabled", "bool", "D-pad navigation enabled"});
        rec.record_property("HIDFlags", {"pointer_enabled", "bool", "Pointer input enabled"});
        rec.record_property("HIDFlags", {"touch_enabled", "bool", "Touch input enabled"});
        rec.record_property("HIDFlags", {"controller_enabled", "bool", "Controller navigation enabled"});
        rec.record_property("HIDFlags", {"mouse_enabled", "bool", "Mouse navigation enabled"});
        rec.record_property("HIDFlags", {"axis_cursor_enabled", "bool", "Axis-as-cursor enabled"});

        rec.record_method("ai", {"set_worldstate",
                                 "---@param e Entity\n"
                                 "---@param key string\n"
                                 "---@param value boolean\n"
                                 "---@return nil",
                                 "Sets a single world-state flag on the entity's current state."});

        rec.record_method("ai", {"set_goal",
                                 "---@param e Entity\n"
                                 "---@param goal table<string,boolean>\n"
                                 "---@return nil",
                                 "Clears the existing goal and sets new goal flags for the entity."});

        rec.record_method("ai", {"patch_worldstate",
                                 "---@param e Entity\n"
                                 "---@param key string\n"
                                 "---@param value boolean\n"
                                 "---@return nil",
                                 "Patches one world-state flag without clearing other flags."});

        rec.record_method("ai", {"patch_goal",
                                 "---@param e Entity\n"
                                 "---@param tbl table<string,boolean>\n"
                                 "---@return nil",
                                 "Patches multiple goal flags without clearing the existing goal."});

        rec.record_method("ai", {"get_blackboard",
                                 "---@param e Entity\n"
                                 "---@return Blackboard",
                                 "Returns the entity's Blackboard component."});

        rec.record_method("", {"create_ai_entity",
                               "---@param type string\n"
                               "---@param overrides table<string,any>?\n"
                               "---@return Entity",
                               "Spawns a new AI entity of the given type with optional overrides."});

        rec.record_method("ai", {"force_interrupt",
                                 "---@param e Entity\n"
                                 "---@return nil",
                                 "Immediately interrupts the entity's current GOAP action."});

        rec.record_method("ai", {"list_lua_files",
                                 "---@param dir string\n"
                                 "---@return string[]",
                                 "Lists all Lua files (no extension) in the given scripts directory."});
                   
        // input.bind(actionName, { device="keyboard", key=KeyboardKey.KEY_SPACE, trigger="Pressed", threshold=0.5, modifiers={...}, context="gameplay" })
        in.set_function("bind", [](const std::string &action, sol::table t) {
            auto &s = resolveInputState();
            ActionBinding b;
            b.device = to_device(t.get_or<std::string>("device", "keyboard"));
            b.trigger = to_trigger(t.get_or<std::string>("trigger", "Pressed"));
            b.threshold = t.get_or("threshold", constants::INPUT_BINDING_DEFAULT_THRESHOLD);
            b.context = t.get_or<std::string>("context", "global");
            b.chord_group = t.get_or<std::string>("chord_group", "");

            // code by device
            if (b.device == InputDeviceInputCategory::KEYBOARD) {
                b.code = t.get_or("key", (int)KEY_NULL);
                if (auto mods = t.get<sol::optional<sol::table>>("modifiers"); mods) {
                    for (auto &kv : *mods) b.modifiers.push_back((KeyboardKey)kv.second.as<int>());
                }
            } else if (b.device == InputDeviceInputCategory::MOUSE) {
                b.code = t.get_or("mouse", (int)MOUSE_BUTTON_LEFT);
            } else if (b.device == InputDeviceInputCategory::GAMEPAD_BUTTON) {
                b.code = t.get_or("button", (int)GAMEPAD_BUTTON_RIGHT_FACE_DOWN);
            } else if (b.device == InputDeviceInputCategory::GAMEPAD_AXIS) {
                b.code = t.get_or("axis", (int)GAMEPAD_AXIS_LEFT_X);
            }

            input::bind_action(s, action, b);
        });

        in.set_function("clear", [](const std::string &action) {
            auto& state = resolveInputState();
            input::clear_action(state, action);
        });

        in.set_function("action_pressed",  [](const std::string &a){ auto& s = resolveInputState(); return input::action_pressed (s, a); });
        in.set_function("action_released", [](const std::string &a){ auto& s = resolveInputState(); return input::action_released(s, a); });
        in.set_function("action_down",     [](const std::string &a){ auto& s = resolveInputState(); return input::action_down    (s, a); });
        in.set_function("action_value",    [](const std::string &a){ auto& s = resolveInputState(); return input::action_value   (s, a); });

        in.set_function("set_context", [](const std::string &ctx){
            auto& s = resolveInputState();
            input::set_context(s, ctx);
        });

        // input.start_rebind("Jump", function(ok, binding) ... end)
        in.set_function("start_rebind", [](const std::string &action, sol::function cb) {
            auto &s = resolveInputState();
            input::start_rebind(s, action, [cb](bool ok, const ActionBinding &b) {
                lua_State* L = cb.lua_state();        // raw lua_State*
                sol::state_view sv(L);                // wrap it

                sol::table out = sv.create_table();   // create a table on this state
                out["ok"]        = ok;
                out["device"]    = static_cast<int>(b.device);
                out["code"]      = b.code;
                out["trigger"]   = static_cast<int>(b.trigger);
                out["threshold"] = b.threshold;
                out["context"]   = b.context;

                // modifiers array
                sol::table mods = sv.create_table();
                int i = 1;
                for (auto m : b.modifiers) {
                    mods[i++] = static_cast<int>(m);
                }
                out["modifiers"] = mods;

                // Call back into Lua: (ok, bindingTable) - protected call
                sol2_util::safe_call(cb, "input_rebind_callback", ok, out);
            });
        });
        
        rec.record_free_function(inputPath, MethodDef{
            "updateCursorFocus",
            "---@return nil",
            "Update cursor focus based on current input state.",
            /*is_static=*/true,
            /*is_overload=*/false
        });

        rec.record_free_function(inputPath, MethodDef{
            "clearActiveScrollPane",
            "---@return nil",
            "Clear stale scroll pane reference after UI rebuild.",
            /*is_static=*/true,
            /*is_overload=*/false
        });

        // Optional BindingRecorder docs
        
        // input.bind
        rec.record_free_function(inputPath, MethodDef{
            "bind",
            "---@param action string\n"
            "---@param cfg {device:string, key?:integer, mouse?:integer, button?:integer, axis?:integer, trigger?:string, threshold?:number, modifiers?:integer[], context?:string}\n"
            "---@return nil",
            "Bind an action to a device code with a trigger.",
            /*is_static=*/true,
            /*is_overload=*/false
        });

        // input.clear
        rec.record_free_function(inputPath, MethodDef{
            "clear",
            "---@param action string\n---@return nil",
            "Clear all bindings for an action.",
            true, false
        });

        // input.action_pressed
        rec.record_free_function(inputPath, MethodDef{
            "action_pressed",
            "---@param action string\n---@return boolean",
            "True on the frame the action is pressed.",
            true, false
        });

        // input.action_released
        rec.record_free_function(inputPath, MethodDef{
            "action_released",
            "---@param action string\n---@return boolean",
            "True on the frame the action is released.",
            true, false
        });

        // input.action_down
        rec.record_free_function(inputPath, MethodDef{
            "action_down",
            "---@param action string\n---@return boolean",
            "True while the action is held.",
            true, false
        });

        // input.action_value
        rec.record_free_function(inputPath, MethodDef{
            "action_value",
            "---@param action string\n---@return number",
            "Analog value for axis-type actions.",
            true, false
        });

        // input.set_context
        rec.record_free_function(inputPath, MethodDef{
            "set_context",
            "---@param ctx string\n---@return nil",
            "Set the active input context.",
            true, false
        });

        // input.start_rebind
        rec.record_free_function(inputPath, MethodDef{
            "start_rebind",
            "---@param action string\n---@param cb fun(ok:boolean,binding:table)\n---@return nil",
            "Capture the next input event and pass it to callback as a binding table.",
            true, false
        });

    }

}
