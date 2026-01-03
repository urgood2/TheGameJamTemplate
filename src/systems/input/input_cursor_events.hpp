#pragma once

#include "input.hpp"
#include <entt/entt.hpp>

struct EngineContext;

namespace input {
namespace cursor_events {

// ───────────────────────────────────────────────────────────────────────────
// Event Handlers (called from Update)
// ───────────────────────────────────────────────────────────────────────────

/// Processes cursor down events and initiates dragging if enabled
void handle_down_event(entt::registry& registry, InputState& state);

/// Processes cursor release events and handles drag completion
void handle_released_event(InputState& state, entt::registry& registry);

/// Processes cursor hover events and manages hover state transitions
void handle_hover_event(InputState& state, entt::registry& registry);

// ───────────────────────────────────────────────────────────────────────────
// Propagation to GameObjects
// ───────────────────────────────────────────────────────────────────────────

/// Propagates click events to GameObject onClick callbacks
void propagate_clicks(entt::registry& registry, InputState& state);

/// Propagates right-click events to GameObject onRightClick callbacks
void propagate_right_clicks(entt::registry& registry, InputState& state);

/// Propagates drag events to GameObject onDrag callbacks
void propagate_drag(entt::registry& registry, InputState& state);

/// Propagates release events to GameObject onRelease callbacks
void propagate_release(InputState& state, entt::registry& registry);

/// Prevents hover and drag from occurring simultaneously on the same entity
void hover_drag_check(entt::registry& registry, InputState& state);

// ───────────────────────────────────────────────────────────────────────────
// Mouse Button Processing
// ───────────────────────────────────────────────────────────────────────────

/// Enqueues a left mouse button press event
void enqueue_left_press(InputState& state, float x = 0, float y = 0);

/// Enqueues a right mouse button press event
void enqueue_right_press(InputState& state, float x = 0, float y = 0);

/// Processes a left mouse button press, determining targets and updating state
void process_left_press(entt::registry& registry, InputState& state, float x = -1, float y = -1);

/// Processes a left mouse button release, handling clicks and publishing events
void process_left_release(entt::registry& registry, InputState& state, float x = -1, float y = -1, EngineContext* ctx = nullptr);

/// Processes queued Raylib left click events
void process_raylib_click(InputState& state, entt::registry& registry);

// ───────────────────────────────────────────────────────────────────────────
// Helpers
// ───────────────────────────────────────────────────────────────────────────

/// Stops hover state on the specified entity
void stop_hover(entt::registry& registry, entt::entity target);

} // namespace cursor_events
} // namespace input
