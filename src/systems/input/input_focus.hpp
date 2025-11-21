#pragma once

// -----------------------------------------------------------------------------
// Focus and Navigation Module
// -----------------------------------------------------------------------------
// This module manages entity focus and controller-based navigation.
//
// IMPORTANT: DUAL NAVIGATION SYSTEM INTEGRATION
// -----------------------------------------------------------------------------
// This codebase has TWO navigation systems that must coexist:
//
// 1. LEGACY SYSTEM (this module):
//    - UpdateFocusForRelevantNodes(): Finds focusable entities under cursor
//    - NavigateFocus(): Directional navigation (up/down/left/right)
//    - Works with cursor_focused_target in InputState
//    - Used for general UI focus and simple menu navigation
//
// 2. NEW SYSTEM (controller_nav.hpp):
//    - controller_nav::NavManager: Hierarchical navigation with groups/layers
//    - Spatial and linear navigation modes
//    - Lua callbacks for focus/select events
//    - More sophisticated multi-menu navigation
//
// INTEGRATION MECHANISM:
// -----------------------------------------------------------------------------
// The two systems coordinate via the controllerNavOverride flag:
//
// When controller_nav::navigate() handles navigation:
//   1. It updates state.cursor_focused_target to the new entity
//   2. Sets state.controllerNavOverride = true
//   3. Calls input::UpdateCursor() to move cursor to focused entity
//
// When UpdateFocusForRelevantNodes() runs next frame:
//   1. Checks if controllerNavOverride is set
//   2. If true: consumes flag, marks entity focused, and returns early
//   3. If false: proceeds with legacy focus logic
//
// This allows:
// - controller_nav to take precedence for complex navigation
// - Legacy system to handle simple cases and non-nav controller input
// - Both systems to update the same cursor_focused_target safely
//
// USAGE GUIDELINES:
// -----------------------------------------------------------------------------
// - Use controller_nav for complex UI with groups/layers/spatial navigation
// - Use this module's NavigateFocus for simple directional navigation
// - Don't call both systems for the same input in the same frame
// - controller_nav sets controllerNavOverride, legacy system respects it
//
// Key Functions:
// - IsNodeFocusable(): Check if entity can receive focus
// - UpdateFocusForRelevantNodes(): Update focus based on cursor/direction
// - NavigateFocus(): Directional navigation wrapper
// - CaptureFocusedInput(): Check if focused entity handles input
// -----------------------------------------------------------------------------

#include "entt/entt.hpp"
#include "input_function_data.hpp"
#include "raylib.h"
#include <optional>
#include <string>

namespace input {
namespace focus {

    // Focus state queries
    // Returns true if entity can currently be focused
    bool IsNodeFocusable(entt::registry &registry, InputState &state, entt::entity entity);

    // Core focus update
    // Updates cursor_focused_target based on nodes at cursor or directional navigation
    // dir: optional direction string ("U"/"D"/"L"/"R") for directional navigation
    // IMPORTANT: Respects controllerNavOverride flag from controller_nav system
    void UpdateFocusForRelevantNodes(entt::registry &registry, InputState &state, std::optional<std::string> dir = std::nullopt);

    // High-level navigation function
    // Calls UpdateFocusForRelevantNodes() then updates cursor position
    void NavigateFocus(entt::registry &registry, InputState &state, std::optional<std::string> dir = std::nullopt);

    // Input capture
    // Returns true if the currently focused entity handled the input
    bool CaptureFocusedInput(entt::registry &registry, InputState &state, const std::string inputType, GamepadButton button, float dt);

} // namespace focus
} // namespace input
