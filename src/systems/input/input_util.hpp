#pragma once

// -----------------------------------------------------------------------------
// Input Utility Functions Module
// -----------------------------------------------------------------------------
// This module contains utility functions used across the input system:
// - Input state initialization and cleanup
// - Input registry management
// - Input locks and interrupt handling
// - Per-frame state reset and caching
//
// These functions support the main input loop but don't fit into
// specific device or event categories.
//
// Key Functions:
// - resetInputStateForProcessing(): Clear per-frame state
// - cacheInputTargets(): Save current frame's interaction targets
// - ProcessInputLocks(): Handle input lock timers
// - PropagateButtonAndKeyUpdates(): Update all button/key states
// - DeleteInvalidEntitiesFromInputRegistry(): Clean up dead entity references
// - AddNodeToInputRegistry(): Register entity for button input
// - ProcessInputRegistry(): Process registered button->entity mappings
// - finalizeUpdateAtEndOfFrame(): End-of-frame cleanup
// -----------------------------------------------------------------------------

#include "entt/entt.hpp"
#include "input_function_data.hpp"
#include "raylib.h"

namespace input {
namespace util {

    // Per-frame state management
    void resetInputStateForProcessing(InputState &inputState);
    void cacheInputTargets(InputState &inputState);
    void finalizeUpdateAtEndOfFrame(InputState &inputState, float dt);

    // Input locks (menu locks, frame locks, etc.)
    void ProcessInputLocks(InputState &inputState, entt::registry &registry, float dt);

    // Button and key state propagation
    // Calls update functions for all pressed/held/released buttons and keys
    void PropagateButtonAndKeyUpdates(InputState &inputState, entt::registry &registry, float dt);

    // Input registry management
    // The input registry maps gamepad buttons to specific entities
    // Useful for button prompts and context-sensitive actions
    void DeleteInvalidEntitiesFromInputRegistry(InputState &state, entt::registry &registry);
    void AddNodeToInputRegistry(entt::registry &registry, InputState &state, entt::entity node, const GamepadButton button);
    void ProcessInputRegistry(InputState &state, entt::registry &registry);

} // namespace util
} // namespace input
