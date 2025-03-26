#include "input_function_data.hpp"

namespace input {
    std::vector<FocusEntry> temporaryListOfFocusedNodes; 
    std::vector<FocusEntry> temporaryListOfPotentiallyFocusableNodes; 

    GamepadButton xboxAButton = GAMEPAD_BUTTON_RIGHT_FACE_DOWN; // A button for xbox
    GamepadButton xboxXButton = GAMEPAD_BUTTON_RIGHT_FACE_LEFT; // X button for xbox
    GamepadButton xboxYButton = GAMEPAD_BUTTON_RIGHT_FACE_UP; // Y button for xbox
    GamepadButton xboxBButton = GAMEPAD_BUTTON_RIGHT_FACE_RIGHT; // B button for xbox
    GamepadButton dpadLeft = GAMEPAD_BUTTON_LEFT_FACE_LEFT; // left dpad
    GamepadButton dpadRight = GAMEPAD_BUTTON_LEFT_FACE_RIGHT; // right dpad
    GamepadButton dpadUp = GAMEPAD_BUTTON_LEFT_FACE_UP; // up dpad
    GamepadButton dpadDown = GAMEPAD_BUTTON_LEFT_FACE_DOWN; // down dpad
    GamepadButton leftShoulderButton = GAMEPAD_BUTTON_LEFT_TRIGGER_1; // left shoulder
    GamepadButton rightShoulderButton = GAMEPAD_BUTTON_RIGHT_TRIGGER_1; // right shoulder
    GamepadButton leftTrigger = GAMEPAD_BUTTON_LEFT_TRIGGER_2; // left trigger
    GamepadButton rightTrigger = GAMEPAD_BUTTON_RIGHT_TRIGGER_2; // right trigger
    
}