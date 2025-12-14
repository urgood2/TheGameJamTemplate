#pragma once

#include "input.hpp"
#include <entt/entt.hpp>
#include <optional>
#include "raylib.h"

namespace input::cursor {
    // Position management
    void set_current_position(entt::registry& reg, InputState& state);
    void update(InputState& state, entt::registry& reg, std::optional<Vector2> hardSetT = std::nullopt);
    void snap_to_node(entt::registry& reg, InputState& state, entt::entity node, const Vector2& transform = {0, 0});
    void modify_context_layer(entt::registry& reg, InputState& state, int delta);

    // Collision detection
    void mark_entities_colliding(entt::registry& reg, InputState& state, const Vector2& cursorTrans);

    // Hover state
    void update_hovering_state(entt::registry& reg, InputState& state);

    // Raw cursor handling
    void handle_raw(InputState& state, entt::registry& reg);
    void process_controller_snap(InputState& state, entt::registry& reg);
}
