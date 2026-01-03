#pragma once

#include "entt/entt.hpp"

#include "util/common_headers.hpp"

#include "core/globals.hpp"

#include "systems/transform/transform_functions.hpp"
#include "systems/main_loop_enhancement/main_loop.hpp"

#include "raylib.h"

#include <vector>
#include <unordered_map>
#include <string>
#include <regex>

namespace input
{
    const float CURSOR_MINIMUM_MOVEMENT_DISTANCE = 500.f; // Minimum distance cursor must move to register as having moved for something to be a click
    
    const float TOUCH_INPUT_MINIMUM_HOVER_TIME = 0.1f; // Minimum time cursor must hover over an entity to register as a hover event while using touch input
    
    constexpr int AXIS_MOUSE_WHEEL_Y = 1001;
    
    //axis_cursor, axis, button, mouse, touch
    enum class InputDeviceInputCategory
    {
        NONE = 0,
        GAMEPAD_AXIS_CURSOR, // gamepad axis movement that affects cursor
        GAMEPAD_AXIS, // gamepad axis movement in general
        GAMEPAD_BUTTON, // buttons on a gamepad (abxy, dpad, etc.)
        MOUSE, // mouse buttons and movement
        TOUCH, // touch input (not configured yet)
        KEYBOARD // NEW
    };
    
    enum class ActionTrigger : uint8_t { Pressed, Released, Held, Repeat, AxisPos, AxisNeg };

    struct ActionBinding {
        InputDeviceInputCategory device = InputDeviceInputCategory::NONE;
        int   code = 0;                      // KeyboardKey / MouseButton / GamepadButton / GamepadAxis encoded as int
        ActionTrigger trigger = ActionTrigger::Pressed;
        float threshold = 0.5f;              // for axis triggers
        std::vector<KeyboardKey> modifiers;  // only used for KEYBOARD
        std::string chord_group;             // optional
        std::string context = "global";
    };

    struct ActionFrameState {
        bool  pressed = false;
        bool  released = false;
        bool  down = false;
        float held = 0.f;    // seconds
        float value = 0.f;   // for axis aggregation
    };

    // Reverse lookup key
    struct ActionKey {
        InputDeviceInputCategory dev;
        int code;
    };

    struct ActionKeyHash {
        auto operator()(const ActionKey &k) const -> size_t {
            return (static_cast<size_t>(k.dev) * 1315423911u) ^ static_cast<size_t>(k.code);
        }
    };
    struct ActionKeyEq {
        auto operator()(const ActionKey &a, const ActionKey &b) const -> bool {
            return a.dev == b.dev && a.code == b.code;
        }
    };


    struct AxisButtonState
    {
        std::optional<GamepadButton> current;  // Button currently active
        std::optional<GamepadButton> previous; // Button previously active
    };

    struct NodeData
    {
        entt::entity node = entt::null; // Associated entity
        bool click = false;             // Whether this node has been clicked
        bool menu = false;              // Whether this node is part of a menu overlay (overlay menu or paused menu)
        bool under_overlay = false;     // Whether this node is under an overlay
    };

    struct SnapTarget
    {
        entt::entity node = entt::null; // Target node (null if snapping to transform)
        Vector2 transform = {0, 0};     // Position to snap cursor to
        std::string type;               // "node" or "transform"
    };

    struct CursorContext
    {
        struct CursorLayer
        {
            entt::entity cursor_focused_target = entt::null; // Focused entity for this layer
            Vector2 cursor_position = {0, 0};                // Cursor position in world space
            bool focus_interrupt = false;                    // Whether focus was interrupted
        };

        int layer = 0;                  // Current layer of the cursor context
        std::vector<CursorLayer> stack; // Stack of previous cursor positions and focus
    };

    struct GamepadState
    {
        std::string object = ""; // TODO: what is this?
        std::string mapping = "";// TODO: what is this?
        std::string name = ""; // contains the string name of the gamepad
        std::string console = ""; // contains the name of the relevant console for this controller
        int id = 0; // Raylib gamepad ID (for future multi-gamepad support)
    };

    struct HIDFlags
    {
        InputDeviceInputCategory last_type = InputDeviceInputCategory::NONE; // Last used input type (mouse, controller, etc.)
        bool dpad_enabled = false; // dpad is currently being used
        bool pointer_enabled = true; // mouse/cursor (gamepad thumbstick) is currently being used
        bool touch_enabled = false; // touch is currently being used
        bool controller_enabled = false; // controller is currently being used
        bool mouse_enabled = true; // mouse is currently being used
        bool axis_cursor_enabled = false; // axis (gamepad) is currently being used to control cursor
    };

    struct FocusEntry
    {
        entt::entity node = entt::null; // Potential focus target
        float dist = 0.0f;              // Distance for sorting focus candidates
    };

    struct InputState
    {
        // -------------------------------
        // Cursor Targets and Interaction
        // -------------------------------
        // These track the entities currently being interacted with by the cursor.

        entt::entity cursor_clicked_target = entt::null;      // Entity clicked this frame
        entt::entity cursor_prev_clicked_target = entt::null; // Previously clicked entity

        entt::entity cursor_focused_target = entt::null;      // Entity currently in focus
        entt::entity cursor_prev_focused_target = entt::null; // Previously focused entity
        entt::entity cursor_focused_target_area = entt::null; // Parent container for focused target (e.g., UI panel)

        entt::entity cursor_dragging_target = entt::null;      // Entity currently being dragged
        entt::entity cursor_prev_dragging_target = entt::null; // Previously dragged entity
        
        entt::entity cursor_prev_released_on_target = entt::null; // Previously released entity. "Released on" means something was previously dragged, then released.
        entt::entity cursor_released_on_target = entt::null;      // Entity released on this frame. "Released on" means something was previously dragged, then released.
        
        entt::entity current_designated_hover_target = entt::null; // Entity currently hovered over, stored separately from cursor hover target
        entt::entity prev_designated_hover_target = entt::null; // Previously hovered entity, stored separately from cursor hover target

        entt::entity cursor_hovering_target = entt::null;      // Entity currently hovered over by cursor
        entt::entity cursor_prev_hovering_target = entt::null; // Previously hovered entity by cursor
        bool cursor_hovering_handled = false;                  // Whether hover event has been handled
        
        // --------------------------------
        // Controller nav override handling
        // --------------------------------
        bool controllerNavOverride = false; // Whether controller navigation is overriding cursor focus. This will override default navigation behavior, which only focuses on ui elements, and let the controller nav system handle it instead.
        

        // -------------------------------
        // Input Handling
        // -------------------------------
        // These track user inputs, including keypresses and cursor movements.
        
        
        entt::entity activeScrollPane = entt::null; // Currently active scroll pane, if any
        
        entt::entity activeTextInput = entt::null; // Currently active text input, if any

        std::vector<entt::entity> collision_list;  // List of entities cursor is colliding with
        std::vector<entt::entity> nodes_at_cursor; // List of entities directly under cursor

        Vector2 cursor_position = {0, 0};           // Screen-space position of cursor, backed up

        std::optional<Vector2> cursor_down_position; // Position when cursor was pressed down
        std::optional<Vector2> cursor_up_position;   // Position when cursor was released
        std::optional<Vector2> focus_cursor_pos;     // Last position cursor was at when focus changed

        float cursor_down_time = 0.0f; // Time when cursor was pressed down
        float cursor_up_time = 0.1f;   // Time when cursor was released

        bool cursor_down_handled = true;             // Whether cursor press has been handled in the current frame. If false, the code will handle a click.
        entt::entity cursor_down_target = entt::null; // Entity pressed on
        std::optional<float> cursor_down_target_click_timeout = 5.f; //maximum time to wait before a click becomes a hold

        bool cursor_up_handled = true;             // Whether cursor release has been handled in the current frame. If false, the code will handle a click.
        entt::entity cursor_up_target = entt::null; // Entity released on
        
        bool cursor_released_on_handled = true;             // Whether cursor release has been handled in the current frame. If false, the code will handle a click.
        bool cursor_click_handled = true; // Whether cursor click has been handled in the current frame. If false, the code will handle a click.

        bool is_cursor_down = false; // Whether cursor is currently down (pressed)

        bool frame_buttonpress = false; // This flag ensures only one button press is registered per frame
        float repress_timer = 0.3f;     // Delay before repeat input for directional buttons
        bool no_holdcap = false;        // If true, disables hold-repeat limit for some inputs

        std::optional<entt::entity> text_input_hook; // Entity capturing text input, if any
        bool capslock = false;                       // Whether caps lock is currently enabled

        bool coyote_focus = false; // Allows focus to linger after cursor leaves a node

        std::optional<Vector2> cursor_hover_transform; // stores location when cursor last hovered over something.
        float cursor_hover_time = 0.0f;                // Time since cursor started hovering

        std::optional<Vector2> L_cursor_queue; // Stores queued left cursor press position for delayed execution
        std::optional<Vector2> R_cursor_queue; // Stores queued right cursor press position for delayed execution

        // -------------------------------
        // Key States
        // -------------------------------
        // Stores current state of pressed, held, and released keys.

        std::unordered_map<KeyboardKey, bool> keysPressedThisFrame;  // Keys pressed this frame
        std::unordered_map<KeyboardKey, bool> keysHeldThisFrame;     // Keys currently being held down
        std::unordered_map<KeyboardKey, int> heldKeyDurations;       // Duration keys have been held
        std::unordered_map<KeyboardKey, bool> keysReleasedThisFrame; // Keys released this frame

        // -------------------------------
        // Button States (Gamepad)
        // -------------------------------
        // Similar to key states, but for gamepad buttons.

        std::unordered_map<GamepadButton, bool> gamepadButtonsPressedThisFrame;
        std::unordered_map<GamepadButton, bool> gamepadButtonsHeldThisFrame;
        std::unordered_map<GamepadButton, int> gamepadHeldButtonDurations;
        std::unordered_map<GamepadButton, bool> gamepadButtonsReleasedThisFrame;

        // -------------------------------
        // Lock and Interrupt States
        // -------------------------------
        // These control whether certain input actions should be blocked.

        bool focus_interrupt = false;                // serves as a temporary override that prevents focus changes under specific conditions
        std::unordered_map<std::string, bool> activeInputLocks; // Various input locks (e.g., menu locks)
        bool inputLocked = false;                         // Whether input handling locked (no input handled)

        // -------------------------------
        // Axis Buttons (Analog Stick & Triggers)
        // -------------------------------
        // Stores the state of gamepad axis buttons.
        std::unordered_map<std::string, AxisButtonState> axis_buttons = {
            {"left_stick", {std::nullopt, std::nullopt}},
            {"right_stick", {std::nullopt, std::nullopt}},
            {"left_trigger", {std::nullopt, std::nullopt}},
            {"right_trigger", {std::nullopt, std::nullopt}},
        };

        // -------------------------------
        // Gamepad State
        // -------------------------------

        float axis_cursor_speed = 300.0f; // Speed of cursor movement when controlled via gamepad stick
        std::unordered_map<GamepadButton, std::vector<NodeData>> button_registry; // Button-to-node mapping
        SnapTarget snap_cursor_to; // Cursor snap target (for menus, controller navigation)

        // -------------------------------
        // Cursor Context (Menu Layers)
        // -------------------------------
        // Tracks cursor navigation state for layered menus.
        CursorContext cursor_context;

        // -------------------------------
        // Human Interface Device (HID) Flags
        // -------------------------------
        // Determines the current input method in use.
        HIDFlags hid;

        // -------------------------------
        // Gamepad Configuration
        // -------------------------------
        // Stores details about the connected gamepad.
        GamepadState gamepad;
        
        std::optional<float> overlay_menu_active_timer; // Timer for overlay menu active duration
        bool overlay_menu_active = false;            // Whether an overlay menu is active
        std::optional<entt::entity> screen_keyboard; // represents the on-screen keyboard entity
        
        // -------------------------------
        // Action Bindings and States
        // -------------------------------
        // Context
        std::string active_context = "gameplay";

        // Bindings & states
        std::unordered_map<std::string, std::vector<ActionBinding>> action_bindings; // name -> bindings
        std::unordered_map<std::string, ActionFrameState> actions;

        // Fast reverse index
        std::unordered_multimap<ActionKey, std::pair<std::string, size_t>, ActionKeyHash, ActionKeyEq> code_to_actions;

        // Rebind capture
        bool rebind_listen = false;
        std::string rebind_action;
        std::function<void(bool, ActionBinding)> on_rebind_done;

    };

    // Special mapping for symbols when Shift is held
    const std::unordered_map<KeyboardKey, char> extendedKeyMap{
        {KEY_ONE, '!'}, {KEY_TWO, '@'}, {KEY_THREE, '#'}, {KEY_FOUR, '$'}, {KEY_FIVE, '%'}, {KEY_SIX, '^'}, {KEY_SEVEN, '&'}, {KEY_EIGHT, '*'}, {KEY_NINE, '('}, {KEY_ZERO, ')'}, {KEY_MINUS, '_'}, {KEY_EQUAL, '+'}, {KEY_LEFT_BRACKET, '{'}, {KEY_RIGHT_BRACKET, '}'}, {KEY_SEMICOLON, ':'}, {KEY_APOSTROPHE, '"'}, {KEY_COMMA, '<'}, {KEY_PERIOD, '>'}, {KEY_SLASH, '?'}, {KEY_BACKSLASH, '|'}};

    extern std::vector<FocusEntry> temporaryListOfFocusedNodes; // nodes that are actually focused, filtered from focusables
    extern std::vector<FocusEntry> temporaryListOfPotentiallyFocusableNodes; // nodes that "can" be focused on

    // some convenience declarations
    extern GamepadButton xboxAButton;         // A button for xbox
    extern GamepadButton xboxXButton;         // X button for xbox
    extern GamepadButton xboxYButton;         // Y button for xbox
    extern GamepadButton xboxBButton;         // B button for xbox
    extern GamepadButton dpadLeft;            // left dpad
    extern GamepadButton dpadRight;           // right dpad
    extern GamepadButton dpadUp;              // up dpad
    extern GamepadButton dpadDown;            // down dpad
    extern GamepadButton leftShoulderButton;  // left shoulder
    extern GamepadButton rightShoulderButton; // right shoulder
    extern GamepadButton leftTrigger;         // left trigger
    extern GamepadButton rightTrigger;        // right trigger
}
