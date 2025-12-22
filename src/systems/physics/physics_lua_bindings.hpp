#pragma once

#include <sol/forward.hpp>

// Forward declarations
class EngineContext;
class PhysicsManager;

namespace physics {

/// Expose all physics bindings to Lua
void expose_physics_to_lua(sol::state& lua, EngineContext* ctx = nullptr);

/// Expose steering system to Lua
void expose_steering_to_lua(sol::state& lua, EngineContext* ctx = nullptr);

/// Expose PhysicsManager to Lua
void expose_physics_manager_to_lua(sol::state& lua, PhysicsManager& PM);

} // namespace physics
