#pragma once

#include "entt/entt.hpp"
#include "input.hpp"
#include <optional>
#include <string>

// Forward declarations
struct InputState;
struct EngineContext;

namespace input {
namespace focus {

/**
 * @brief Checks if an entity can receive focus based on various conditions
 *
 * Validates if a node is eligible for focus based on:
 * - UI configuration flags
 * - Visibility and hover state
 * - Pause state compatibility
 * - Screen keyboard state
 * - Position within game bounds
 *
 * @param registry The entity registry
 * @param state Current input state
 * @param entity The entity to check for focusability
 * @return true if the entity can be focused, false otherwise
 */
bool IsNodeFocusable(entt::registry &registry, InputState &state, entt::entity entity);

/**
 * @brief Updates focus state for all relevant nodes based on optional direction
 *
 * Main focus update logic that:
 * - Handles controller navigation override
 * - Clears focus if conditions aren't met
 * - Collects potentially focusable nodes
 * - Performs directional focus navigation
 * - Updates focus cursor position
 * - Assigns the closest valid node as focused target
 * - Publishes UIElementFocused events
 *
 * @param registry The entity registry
 * @param state Current input state
 * @param dir Optional direction string ("L", "R", "U", "D") for directional navigation
 * @param ctx Optional engine context for event bus access
 */
void UpdateFocusForRelevantNodes(entt::registry &registry, InputState &state,
                                  std::optional<std::string> dir = std::nullopt,
                                  EngineContext* ctx = nullptr);

/**
 * @brief Captures input for the currently focused entity
 *
 * Handles special input processing for focused elements including:
 * - Coyote time for quick directional switches while dragging
 * - D-pad input for card rank reordering within hand areas
 * - Overlay menu shoulder button navigation
 * - UI focus arguments (cycle, tab, slider types)
 *
 * @param registry The entity registry
 * @param state Current input state
 * @param inputType Type of input ("press", "hold", "release")
 * @param button The gamepad button being processed
 * @param dt Delta time for continuous input
 * @return true if input was captured/handled, false otherwise
 */
bool CaptureFocusedInput(entt::registry &registry, InputState &state,
                         const std::string inputType, GamepadButton button, float dt);

/**
 * @brief Navigates focus in an optional direction and updates cursor position
 *
 * High-level navigation wrapper that:
 * 1. Updates focus based on direction (or nearest focusable if no direction)
 * 2. Updates cursor position to match the newly focused entity
 *
 * @param registry The entity registry
 * @param state Current input state
 * @param dir Optional direction string ("L", "R", "U", "D")
 */
void NavigateFocus(entt::registry &registry, InputState &state,
                   std::optional<std::string> dir = std::nullopt);

} // namespace focus
} // namespace input
