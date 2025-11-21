#pragma once

// -----------------------------------------------------------------------------
// Input Event Processing Module
// -----------------------------------------------------------------------------
// This module handles high-level input event distribution to game objects:
// - Click events (when cursor is pressed and released on same entity)
// - Drag events (when cursor moves while pressed)
// - Hover events (when cursor moves over entities)
// - Release events (when cursor button is released)
//
// Event Flow:
// -----------------------------------------------------------------------------
// 1. Raw input arrives (mouse/gamepad) -> updates InputState
// 2. Cursor position and collision detection runs
// 3. Event handlers propagate events to entities:
//    - handleCursorDownEvent(): Cursor pressed on entity
//    - handleCursorHoverEvent(): Cursor moved over entity
//    - handleCursorReleasedEvent(): Cursor released
//    - hoverDragSimultaneousCheck(): Resolves hover/drag conflicts
// 4. Event propagation functions notify game objects:
//    - propagateClicksToGameObjects(): Click events
//    - propagateDragToGameObjects(): Drag events
//    - propagateReleaseToGameObjects(): Release events
//
// State Management:
// -----------------------------------------------------------------------------
// The module manages cursor interaction state in InputState:
// - cursor_down_handled: Whether cursor press was handled
// - cursor_up_handled: Whether cursor release was handled
// - cursor_click_handled: Whether click was handled
// - cursor_hovering_handled: Whether hover was handled
//
// These flags prevent duplicate event processing and allow
// event priority/filtering.
//
// Key Functions:
// - handleCursorDownEvent(): Process cursor press
// - handleCursorHoverEvent(): Process cursor hover
// - handleCursorReleasedEvent(): Process cursor release
// - propagateClicksToGameObjects(): Send click events to entities
// - propagateDragToGameObjects(): Send drag events to entities
// - propagateReleaseToGameObjects(): Send release events to entities
// - hoverDragSimultaneousCheck(): Resolve hover vs drag priority
// -----------------------------------------------------------------------------

#include "entt/entt.hpp"
#include "input_function_data.hpp"

namespace input {
namespace events {

    // Event handlers (called during Update)
    void handleCursorDownEvent(entt::registry &registry, InputState &inputState);
    void handleCursorHoverEvent(InputState &inputState, entt::registry &registry);
    void handleCursorReleasedEvent(InputState &inputState, entt::registry &registry);

    // Event propagation to game objects
    void propagateClicksToGameObjects(entt::registry &registry, InputState &inputState);
    void propagateDragToGameObjects(entt::registry &registry, InputState &inputState);
    void propagateReleaseToGameObjects(InputState &inputState, entt::registry &registry);

    // Special case handling
    void hoverDragSimultaneousCheck(entt::registry &registry, InputState &inputState);

    // Utility
    void stopHover(entt::registry &registry, entt::entity target);

} // namespace events
} // namespace input
