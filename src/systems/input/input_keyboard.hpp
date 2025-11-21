#pragma once

// -----------------------------------------------------------------------------
// Keyboard Input Module
// -----------------------------------------------------------------------------
// This module handles all keyboard-related input processing including:
// - Keyboard key press/hold/release tracking
// - Text input processing for UI elements
// - Character mapping (including shift/caps lock modifiers)
// - Text input hooks for text fields
//
// The module maintains per-key state tracking in InputState:
// - keysPressedThisFrame: New key presses (first frame only)
// - keysHeldThisFrame: Currently held keys
// - heldKeyDurations: How long each key has been held
// - keysReleasedThisFrame: Keys released this frame
//
// Text Input System:
// - Entities can be "hooked" to receive text input via HookTextInput()
// - Hooked entities receive character input and cursor control
// - Only one entity can be hooked at a time (stored in activeTextInput)
//
// Key Functions:
// - ProcessKeyboardKeyDown/Release: Update key state maps
// - KeyboardKeyPressUpdate/HoldUpdate/ReleasedUpdate: Per-frame state updates
// - HookTextInput/UnhookTextInput: Enable/disable text input for an entity
// - ProcessTextInput: Convert key presses to characters with modifiers
// -----------------------------------------------------------------------------

#include "entt/entt.hpp"
#include "input_function_data.hpp"
#include "raylib.h"

namespace input {
namespace keyboard {

    // Core keyboard state processing
    void ProcessKeyboardKeyDown(InputState &state, KeyboardKey key);
    void ProcessKeyboardKeyRelease(InputState &state, KeyboardKey key);

    // Per-frame update functions for different key states
    void KeyboardKeyPressUpdate(entt::registry &registry, InputState &state, KeyboardKey key, float dt);
    void KeyboardKeyHoldUpdate(InputState &state, KeyboardKey key, float dt);
    void KeyboardKeyReleasedUpdate(InputState &state, KeyboardKey key, float dt);

    // Text input system
    // Hooks/unhooks an entity to receive text input events
    void HookTextInput(entt::registry &registry, entt::entity entity);
    void UnhookTextInput(entt::registry &registry, entt::entity entity);

    // Process text input for a specific entity with modifier keys
    void ProcessTextInput(entt::registry &registry, entt::entity entity, KeyboardKey key, bool shift, bool capsLock);

    // Convert keyboard key to character (handles shift/caps lock)
    auto GetCharacterFromKey(KeyboardKey key, bool caps) -> char;

} // namespace keyboard
} // namespace input
