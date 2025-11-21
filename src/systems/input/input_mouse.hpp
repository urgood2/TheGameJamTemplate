#pragma once

// -----------------------------------------------------------------------------
// Mouse Input Module
// -----------------------------------------------------------------------------
// This module handles all mouse-related input processing including:
// - Mouse button presses and releases (left, right)
// - Mouse movement detection
// - Mouse wheel scrolling
// - Mouse position tracking
//
// The module works with the InputState to:
// 1. Detect mouse button state changes via Raylib polling
// 2. Enqueue and process mouse clicks with position data
// 3. Track mouse movement for HID device detection
// 4. Process mouse wheel as a pseudo-axis for zoom/scroll actions
//
// Key Functions:
// - EnqueueLeftMouseButtonPress/EnqueRightMouseButtonPress: Queue click events
// - ProcessLeftMouseButtonPress/Release: Handle click lifecycle
// - Mouse events are dispatched to the action binding system via DispatchRaw
// -----------------------------------------------------------------------------

#include "entt/entt.hpp"
#include "input_function_data.hpp"
#include "raylib.h"

namespace input {
namespace mouse {

    // Enqueue mouse button presses for processing
    // These functions store the click position for later processing
    void EnqueueLeftMouseButtonPress(InputState& state, float x = 0, float y = 0);
    void EnqueueRightMouseButtonPress(InputState& state, float x = 0, float y = 0);

    // Process mouse button events
    // x/y = -1 means use current cursor position
    void ProcessLeftMouseButtonPress(entt::registry &registry, InputState& state, float x = -1, float y = -1);
    void ProcessLeftMouseButtonRelease(entt::registry &registry, InputState& state, float x = -1, float y = -1);

    // Internal function that handles the low-level click processing
    void ProcessRaylibLeftClick(InputState &inputState, entt::registry &registry);

} // namespace mouse
} // namespace input
