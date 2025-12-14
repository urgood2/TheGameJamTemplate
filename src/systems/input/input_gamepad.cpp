#include "input_gamepad.hpp"

#include "input_actions.hpp"
#include "input_constants.hpp"
#include "input_functions.hpp"

#include "core/engine_context.hpp"
#include "core/events.hpp"
#include "core/globals.hpp"
#include "systems/transform/transform_functions.hpp"

#include "raylib.h"
#include "spdlog/spdlog.h"

#include <cmath>

namespace input::gamepad {

namespace {
    // Helper to resolve EngineContext
    static EngineContext* resolveCtx(EngineContext* ctx) {
        return ctx ? ctx : globals::g_ctx;
    }

    // Helper to resolve EventBus from context
    static event_bus::EventBus& resolveEventBus(EngineContext* ctx) {
        if (auto* resolved = resolveCtx(ctx)) {
            return resolved->eventBus;
        }
        return globals::getEventBus();
    }
} // anonymous namespace

auto process_button_press(InputState& state, GamepadButton button, EngineContext* ctx) -> void
{
    // SPDLOG_DEBUG("Button press detected: {}", magic_enum::enum_name(button));
    state.gamepadButtonsPressedThisFrame[button] = true;
    state.gamepadButtonsHeldThisFrame[button] = true;
    input::DispatchRaw(state, InputDeviceInputCategory::GAMEPAD_BUTTON, (int)button, true);
    resolveEventBus(ctx).publish(events::GamepadButtonPressed{state.gamepad.id, button});
}

auto process_button_release(InputState& state, GamepadButton button, EngineContext* ctx) -> void
{
    state.gamepadButtonsHeldThisFrame[button] = false;
    state.gamepadButtonsReleasedThisFrame[button] = true;
    input::DispatchRaw(state, InputDeviceInputCategory::GAMEPAD_BUTTON, (int)button, false);
    resolveEventBus(ctx).publish(events::GamepadButtonReleased{state.gamepad.id, button});
}

auto process_axis_buttons(InputState& state, EngineContext* ctx) -> void
{
    for (auto& [key, axisButton] : state.axis_buttons)
    {
        // Trigger a button release if the button is no longer active or has changed
        if (axisButton.previous && (!axisButton.current || axisButton.previous != axisButton.current))
        {
            process_button_release(state, axisButton.previous.value(), ctx);
        }

        // Trigger a button press if a new button becomes active
        if (axisButton.current && axisButton.previous != axisButton.current)
        {
            process_button_press(state, axisButton.current.value(), ctx);
        }
    }
}

auto update_axis_input(InputState& state, entt::registry& registry, float dt, EngineContext* ctx) -> InputDeviceInputCategory
{
    InputDeviceInputCategory axisInterpretation = InputDeviceInputCategory::NONE;

    // // hack to ensure mouse state isn't written over
    // if (state.hid.controller_enabled == false)
    //     axisInterpretation = InputDeviceInputCategory::MOUSE;

    // Reset axis button states
    for (auto& [key, axisButton] : state.axis_buttons)
    {
        axisButton.previous = axisButton.current;
        axisButton.current.reset();
    }

    if (state.hid.controller_enabled)
    {
        //---------------------------------------------------------------
        //                     Left Thumbstick
        //---------------------------------------------------------------
        AssertThat(IsGamepadAvailable(state.gamepad.id), Is().EqualTo(true));

        float l_stick_x = GetGamepadAxisMovement(state.gamepad.id, GAMEPAD_AXIS_LEFT_X);
        float l_stick_y = GetGamepadAxisMovement(state.gamepad.id, GAMEPAD_AXIS_LEFT_Y);

        // If something is being dragged, treat the left stick as cursor input
        if (registry.valid(state.cursor_dragging_target) && (std::abs(l_stick_x) + std::abs(l_stick_y)) > constants::LEFT_STICK_DEADZONE)
        {
            axisInterpretation = InputDeviceInputCategory::GAMEPAD_AXIS_CURSOR; // Cursor movement detected

            // Deadzone handling for left stick
            if (std::abs(l_stick_x) < constants::LEFT_STICK_DEADZONE)
                l_stick_x = 0;
            if (std::abs(l_stick_y) < constants::LEFT_STICK_DEADZONE)
                l_stick_y = 0;
            l_stick_x += (l_stick_x > 0 ? -constants::LEFT_STICK_DEADZONE : 0.0f) + (l_stick_x < 0 ? constants::LEFT_STICK_DEADZONE : 0.0f);
            l_stick_y += (l_stick_y > 0 ? -constants::LEFT_STICK_DEADZONE : 0.0f) + (l_stick_y < 0 ? constants::LEFT_STICK_DEADZONE : 0.0f);

            // Modify the cursor position based on left stick values
            auto& transform = registry.get<transform::Transform>(globals::getCursorEntity());
            transform.setActualX(transform.getActualX() + l_stick_x * dt * state.axis_cursor_speed);
            transform.setActualY(transform.getActualY() + l_stick_y * dt * state.axis_cursor_speed);

            // Update screen space cursor position
            state.cursor_position.x = transform.getActualX();
            state.cursor_position.y = transform.getActualY();
        }
        else
        {
            // Treat the left stick as a directional pad (dpad) input
            auto& axisButton = state.axis_buttons["left_stick"];
            axisButton.current = axisButton.previous;
            if ((std::abs(l_stick_x) + std::abs(l_stick_y)) > constants::LEFT_STICK_DPAD_ACTIVATION_THRESHOLD)
            {
                axisInterpretation = InputDeviceInputCategory::GAMEPAD_BUTTON; // Left stick is a button

                axisButton.current = std::abs(l_stick_x) > std::abs(l_stick_y)
                                         ? (l_stick_x > 0 ? dpadRight : dpadLeft)
                                         : (l_stick_y > 0 ? dpadDown : dpadUp);
            }
            else if ((std::abs(l_stick_x) + std::abs(l_stick_y)) < constants::LEFT_STICK_DPAD_RELEASE_THRESHOLD)
            {
                axisButton.current.reset();
            }
        }

        //---------------------------------------------------------------
        //                     Right Thumbstick
        //---------------------------------------------------------------
        float r_stick_x = GetGamepadAxisMovement(state.gamepad.id, GAMEPAD_AXIS_RIGHT_X);
        float r_stick_y = GetGamepadAxisMovement(state.gamepad.id, GAMEPAD_AXIS_RIGHT_Y);

        const float deadzone = constants::RIGHT_STICK_DEADZONE;

        float mag = std::sqrt(std::pow(r_stick_x, 2) + std::pow(r_stick_y, 2));
        if (mag > deadzone)
        {
            axisInterpretation = InputDeviceInputCategory::GAMEPAD_AXIS_CURSOR; // Cursor movement detected

            // Apply deadzone for right stick
            if (std::abs(r_stick_x) < deadzone)
                r_stick_x = 0;
            if (std::abs(r_stick_y) < deadzone)
                r_stick_y = 0;
            r_stick_x = r_stick_x + (r_stick_x > 0 ? -deadzone : 0) + (r_stick_x < 0 ? deadzone : 0);
            r_stick_y = r_stick_y + (r_stick_y > 0 ? -deadzone : 0) + (r_stick_y < 0 ? deadzone : 0);

            // Modify the cursor position based on right stick values
            auto& transform = registry.get<transform::Transform>(globals::getCursorEntity());
            transform.setActualX(transform.getActualX() + r_stick_x * dt * state.axis_cursor_speed);
            transform.setActualY(transform.getActualY() + r_stick_y * dt * state.axis_cursor_speed);

            // Update screen space cursor position
            state.cursor_position.x = transform.getActualX();
            state.cursor_position.y = transform.getActualY();
        }

        //---------------------------------------------------------------
        //                         Triggers
        //---------------------------------------------------------------
        float l_trig = GetGamepadAxisMovement(state.gamepad.id, GAMEPAD_AXIS_LEFT_TRIGGER);
        float r_trig = GetGamepadAxisMovement(state.gamepad.id, GAMEPAD_AXIS_RIGHT_TRIGGER);

        auto& axisButtonLTrigger = state.axis_buttons["left_trigger"];
        auto& axisButtonRTrigger = state.axis_buttons["right_trigger"];

        axisButtonLTrigger.current = state.axis_buttons["left_trigger"].previous;
        axisButtonRTrigger.current = state.axis_buttons["right_trigger"].previous;

        // Handle the triggers as button presses
        if (l_trig > constants::TRIGGER_ACTIVATION_THRESHOLD)
        {
            axisButtonLTrigger.current = leftTrigger;
        }
        else if (l_trig < constants::TRIGGER_RELEASE_THRESHOLD)
        {
            axisButtonLTrigger.current.reset();
        }

        if (r_trig > constants::TRIGGER_ACTIVATION_THRESHOLD)
        {
            axisButtonRTrigger.current = rightTrigger;
        }
        else if (r_trig < constants::TRIGGER_RELEASE_THRESHOLD)
        {
            axisButtonRTrigger.current.reset();
        }

        // Return "gamepadbutton" if any trigger is active
        if (axisButtonRTrigger.current || axisButtonLTrigger.current)
        {
            axisInterpretation = (axisInterpretation == InputDeviceInputCategory::NONE) ? InputDeviceInputCategory::GAMEPAD_BUTTON : axisInterpretation;
        }

        // Handle button press/release for axis buttons
        process_axis_buttons(state, ctx);

        // send axis each frame so action_value aggregates
        input::DispatchRaw(state, InputDeviceInputCategory::GAMEPAD_AXIS, (int)GAMEPAD_AXIS_LEFT_X,  true, l_stick_x);
        input::DispatchRaw(state, InputDeviceInputCategory::GAMEPAD_AXIS, (int)GAMEPAD_AXIS_LEFT_Y,  true, l_stick_y);
        input::DispatchRaw(state, InputDeviceInputCategory::GAMEPAD_AXIS, (int)GAMEPAD_AXIS_RIGHT_X, true, r_stick_x);
        input::DispatchRaw(state, InputDeviceInputCategory::GAMEPAD_AXIS, (int)GAMEPAD_AXIS_RIGHT_Y, true, r_stick_y);
        input::DispatchRaw(state, InputDeviceInputCategory::GAMEPAD_AXIS, (int)GAMEPAD_AXIS_LEFT_TRIGGER,  true, l_trig);
        input::DispatchRaw(state, InputDeviceInputCategory::GAMEPAD_AXIS, (int)GAMEPAD_AXIS_RIGHT_TRIGGER, true, r_trig);
    }

    // Reset focus if necessary
    if (axisInterpretation != InputDeviceInputCategory::NONE)
    {
        state.focus_interrupt = false;
    }

    return axisInterpretation;
}

auto button_press_update(entt::registry& registry, InputState& state, const GamepadButton button, float dt) -> void
{
    // Exit if frame lock is active
    if (state.activeInputLocks["frame"])
        return;

    // Reset hold time and clear focus interrupt
    state.gamepadHeldButtonDurations[button] = 0;
    state.focus_interrupt = false;

    // Check for focused input capture
    if (!CaptureFocusedInput(registry, state, "press", button, dt))
    {
        if (button == GAMEPAD_BUTTON_LEFT_FACE_UP)
            NavigateFocus(registry, state, "U"); // DPAD TODO: change up down etc. to enums
        else if (button == GAMEPAD_BUTTON_LEFT_FACE_DOWN)
            NavigateFocus(registry, state, "D");
        else if (button == GAMEPAD_BUTTON_LEFT_FACE_LEFT)
            NavigateFocus(registry, state, "L");
        else if (button == GAMEPAD_BUTTON_LEFT_FACE_RIGHT)
            NavigateFocus(registry, state, "R");
    }

    // Check input lock conditions
    if ((state.inputLocked && !globals::getIsGamePaused()) || state.activeInputLocks["frame"] || state.frame_buttonpress)
        return;
    state.frame_buttonpress = true;

    // Check button registry
    if (state.button_registry.contains(button) && !state.button_registry[button].empty() &&
        !state.button_registry[button][0].under_overlay)
    {
        state.button_registry[button][0].click = true;
    }
    else
    {
        // Handle specific button actions
        if (button == GAMEPAD_BUTTON_MIDDLE_RIGHT)
        { // start button
          // if (state.game_state == GameState::SPLASH) {
          //     deleteRun();  // Reset the game
          //     mainMenu();   // Return to the main menu
          // }
        }
        else if (button == GAMEPAD_BUTTON_RIGHT_FACE_DOWN)
        { // A button (xbox)
            if (state.cursor_focused_target != entt::null)
            {
                // FIXME: patching this out for now.
                // auto &focusedNode = registry.get<transform::GameObject>(state.cursor_focused_target);
                // auto &focusedUIConfig = registry.get<ui::UIConfig>(state.cursor_focused_target);
                // if (focusedUIConfig.focusArgs->type == "slider" &&
                //     !state.hid.mouse_enabled && !state.hid.axis_cursor_enabled)
                // {
                //     // Do nothing
                // }
                // else
                // {
                //     // Trigger left cursor press
                //     ProcessLeftMouseButtonPress(registry, state); // Trigger left cursor press
                // }
            }
            else
            {
                ProcessLeftMouseButtonPress(registry, state); // Trigger left cursor press
            }
        }
        else if (button == GAMEPAD_BUTTON_RIGHT_FACE_RIGHT)
        { // B button (xbox)
            if (state.cursor_focused_target != entt::null /** && some check wehther area exists, and whether state.cursor_focused_target_area is the same as that area*/)
            {
                EnqueRightMouseButtonPress(state); // Trigger right cursor press
            }
            else
            {
                state.focus_interrupt = true;
            }
        }
    }
}

auto held_button_update(entt::registry& registry, InputState& state, const GamepadButton button, float dt) -> void
{
    // Ignore input if the system is locked or already processed
    if ((state.inputLocked && !globals::getIsGamePaused()) || state.activeInputLocks["frame"] || state.frame_buttonpress)
        return;
    state.frame_buttonpress = true;

    // SPDLOG_DEBUG("Held button: {}", magic_enum::enum_name(button));

    // Increment hold time for the button
    if (state.gamepadHeldButtonDurations.contains(button))
    {
        state.gamepadHeldButtonDurations[button] += dt;
        CaptureFocusedInput(registry, state, "hold", button, dt); // Process hold input
    }

    // Handle directional button repeat behavior
    if ((button == GAMEPAD_BUTTON_LEFT_FACE_LEFT || button == GAMEPAD_BUTTON_LEFT_FACE_RIGHT || button == GAMEPAD_BUTTON_LEFT_FACE_UP || button == GAMEPAD_BUTTON_LEFT_FACE_DOWN) && !state.no_holdcap)
    {
        state.repress_timer = state.repress_timer > 0.0f ? state.repress_timer : constants::BUTTON_REPEAT_INITIAL_DELAY;
        if (state.gamepadHeldButtonDurations[button] > state.repress_timer)
        {
            state.repress_timer = constants::BUTTON_REPEAT_SUBSEQUENT_DELAY;
            state.gamepadHeldButtonDurations[button] = 0.0f; // Reset hold time
            button_press_update(registry, state, button, dt);  // Trigger button press action

            SPDLOG_DEBUG("Repeating button: {}", magic_enum::enum_name(button));
        }
    }
}

// Handles button release updates
void released_button_update(entt::registry& registry, InputState& state, const GamepadButton button, float dt)
{
    // Check if button is being tracked
    if (state.gamepadHeldButtonDurations.find(button) == state.gamepadHeldButtonDurations.end())
    {
        return;
    }

    // Set repress timer
    state.repress_timer = constants::BUTTON_REPEAT_INITIAL_DELAY;

    // Remove button from tracking
    state.gamepadHeldButtonDurations.erase(button);

    // Handle specific button logic
    if (button == GAMEPAD_BUTTON_RIGHT_FACE_DOWN)
    { // A button (xbox)
        SPDLOG_DEBUG("A button released");
        ProcessLeftMouseButtonRelease(registry, state);
    }
}

} // namespace input::gamepad
