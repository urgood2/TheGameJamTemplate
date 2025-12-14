#pragma once

#include <sol/sol.hpp>

// Forward declarations
struct EngineContext;

namespace input::lua_bindings {
    // Main exposure function - exposes input system to Lua
    void expose_to_lua(sol::state& lua, EngineContext* ctx = nullptr);
}
