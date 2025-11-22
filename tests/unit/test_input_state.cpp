#include <gtest/gtest.h>

#include "systems/input/input_function_data.hpp"
#include "systems/input/input_functions.hpp"

class InputStateDefaultsTest : public ::testing::Test {};

TEST_F(InputStateDefaultsTest, StartsWithNullEntitiesAndHandledFlags) {
    input::InputState state{};

    EXPECT_TRUE(state.cursor_clicked_target == entt::null);
    EXPECT_TRUE(state.cursor_dragging_target == entt::null);
    EXPECT_TRUE(state.cursor_down_handled);
    EXPECT_TRUE(state.cursor_up_handled);
    EXPECT_TRUE(state.cursor_released_on_handled);
    EXPECT_TRUE(state.cursor_click_handled);
    EXPECT_FALSE(state.is_cursor_down);
}

TEST_F(InputStateDefaultsTest, HIDFlagsStartWithMouseEnabled) {
    input::HIDFlags flags{};

    EXPECT_TRUE(flags.pointer_enabled);
    EXPECT_TRUE(flags.mouse_enabled);
    EXPECT_FALSE(flags.controller_enabled);
    EXPECT_EQ(flags.last_type, input::InputDeviceInputCategory::NONE);
}

TEST_F(InputStateDefaultsTest, ReconfigureToControllerThenBackToMouse) {
    input::InputState state{};

    input::ReconfigureInputDeviceInfo(state, input::InputDeviceInputCategory::GAMEPAD_BUTTON);
    EXPECT_TRUE(state.hid.controller_enabled);
    EXPECT_EQ(state.hid.last_type, input::InputDeviceInputCategory::GAMEPAD_BUTTON);
    EXPECT_FALSE(state.hid.mouse_enabled);
    EXPECT_TRUE(state.hid.dpad_enabled);

    state.gamepad.console = "XBOX";
    state.gamepad.object = "pad";
    state.gamepad.mapping = "old";
    state.gamepad.name = "controller";
    state.hid.controller_enabled = true;
    state.hid.dpad_enabled = true;

    input::ReconfigureInputDeviceInfo(state, input::InputDeviceInputCategory::MOUSE);
    EXPECT_FALSE(state.hid.controller_enabled);
    EXPECT_EQ(state.hid.last_type, input::InputDeviceInputCategory::MOUSE);
    EXPECT_TRUE(state.hid.mouse_enabled);
    EXPECT_TRUE(state.hid.pointer_enabled);
    EXPECT_FALSE(state.hid.axis_cursor_enabled);
    EXPECT_TRUE(state.gamepad.console.empty());
    EXPECT_TRUE(state.gamepad.object.empty());
    EXPECT_TRUE(state.gamepad.mapping.empty());
    EXPECT_TRUE(state.gamepad.name.empty());
}

TEST_F(InputStateDefaultsTest, AxisCursorEnablesPointerAndAxisFlags) {
    input::InputState state{};
    input::ReconfigureInputDeviceInfo(state, input::InputDeviceInputCategory::GAMEPAD_AXIS_CURSOR);

    EXPECT_TRUE(state.hid.controller_enabled);
    EXPECT_TRUE(state.hid.pointer_enabled);
    EXPECT_TRUE(state.hid.axis_cursor_enabled);
    EXPECT_FALSE(state.hid.mouse_enabled);
    EXPECT_EQ(state.hid.last_type, input::InputDeviceInputCategory::GAMEPAD_AXIS_CURSOR);
}

TEST_F(InputStateDefaultsTest, ProcessInputLocksClearsFrameLockWhenFlagged) {
    input::InputState state{};
    state.activeInputLocks["frame"] = true;
    state.activeInputLocks["frame_lock_reset_next_frame"] = true;
    state.activeInputLocks["wipe"] = false;

    entt::registry registry;
    input::ProcessInputLocks(state, registry, 0.016f);

    EXPECT_FALSE(state.activeInputLocks["frame"]);
    EXPECT_TRUE(state.inputLocked); // was locked this frame due to frame=true
}
