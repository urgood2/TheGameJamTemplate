#pragma once

/**
 * @file goap_debug_window.hpp
 * @brief ImGui debug window for inspecting GOAP AI entities.
 *
 * Provides real-time visualization of:
 * - GOAP entities list
 * - WorldState atoms and values
 * - Current plan (action queue)
 * - Blackboard data
 *
 * Usage:
 *   goap_debug::toggle();  // Toggle visibility (F9)
 *   goap_debug::render();  // Call in render loop within ImGui context
 */

namespace goap_debug {

/// Render the GOAP debug window. Call every frame within rlImGuiBegin/End.
void render();

/// Toggle window visibility (bound to F9).
void toggle();

/// Check if window is currently visible.
bool is_visible();

}  // namespace goap_debug
