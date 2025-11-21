#pragma once

// -----------------------------------------------------------------------------
// Cursor Management Module
// -----------------------------------------------------------------------------
// This module handles cursor positioning, context layers, and snapping:
// - Cursor position updates (mouse, gamepad stick, or programmatic)
// - Cursor context layer stack for menu systems
// - Cursor snapping to UI elements (for controller navigation)
// - Collision detection between cursor and entities
//
// Cursor Context System:
// The cursor maintains a stack of "layers" for hierarchical menu navigation.
// Each layer remembers:
// - cursor_focused_target: Which entity was focused in this layer
// - cursor_position: Where the cursor was positioned
// - focus_interrupt: Whether focus was interrupted
//
// When pushing a new menu layer (e.g., opening a submenu):
// 1. Current state is saved to the stack
// 2. Cursor moves to the new menu
// 3. When popping back, previous cursor state is restored
//
// Cursor Snapping:
// Controllers can snap the cursor to specific UI elements via:
// - SnapToNode(): Snap cursor to an entity's position
// - snap_cursor_to: Stores pending snap target (node or transform)
// - ProcessControllerSnapToObject(): Executes pending snap
//
// Collision Tracking:
// - collision_list: All entities cursor is overlapping
// - nodes_at_cursor: Entities directly under cursor (filtered from collision_list)
// - MarkEntitiesCollidingWithCursor(): Updates collision data
// - UpdateCursorHoveringState(): Determines which entity is actively hovered
//
// Key Functions:
// - UpdateCursor(): Main cursor update (position, snapping, collision)
// - SetCurrentCursorPosition(): Set cursor position explicitly
// - ModifyCurrentCursorContextLayer(): Push/pop context layers
// - SnapToNode(): Schedule cursor snap to entity
// - ProcessControllerSnapToObject(): Execute pending snap
// -----------------------------------------------------------------------------

#include "entt/entt.hpp"
#include "input_function_data.hpp"
#include "raylib.h"
#include <optional>

namespace input {
namespace cursor {

    // Cursor position and update
    // Updates cursor position, handles snapping, and updates collision state
    // hardSetT = optional explicit position override
    auto UpdateCursor(InputState &state, entt::registry &registry, std::optional<Vector2> hardSetT = std::nullopt) -> void;

    // Explicitly set cursor position (used by mouse and gamepad axis)
    auto SetCurrentCursorPosition(entt::registry &registry, InputState &state) -> void;

    // Cursor context layer management
    // delta: +1 to push new layer, -1 to pop layer
    auto ModifyCurrentCursorContextLayer(entt::registry &registry, InputState &state, int delta) -> void;

    // Cursor snapping (for controller navigation)
    // Schedules cursor to snap to specified node + optional offset
    auto SnapToNode(entt::registry &registry, InputState &state, entt::entity node, const Vector2 &transform = {0,0}) -> void;

    // Process pending cursor snap (called during update)
    void ProcessControllerSnapToObject(InputState &inputState, entt::registry &registry);

    // Collision and hover detection
    // Updates collision_list with all entities under cursor at given position
    void MarkEntitiesCollidingWithCursor(entt::registry &registry, InputState &state, const Vector2 &cursor_trans);

    // Updates cursor_hovering_target based on collision_list and game state
    void UpdateCursorHoveringState(entt::registry &registry, InputState &state);

    // Raw cursor position update (from mouse movement)
    void HandleRawCursor(InputState &inputState, entt::registry &registry);

} // namespace cursor
} // namespace input
