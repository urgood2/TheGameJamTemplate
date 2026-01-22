---@meta
--[[
================================================================================
TYPE DEFINITIONS - Entrypoint for LuaLS autocomplete support
================================================================================
This directory provides type stubs for IDE autocomplete. Files are organized by
where the APIs come from:

- globals.lua      - C++ bindings exposed via Sol2 (registry, physics, etc.)
- modules.lua      - Lua module return types (timer, signal, Q, etc.)
- builders.lua     - Fluent builder APIs (EntityBuilder, PhysicsBuilder, etc.)
- components.generated.lua - Generated from C++ components.hpp (if present)

These files use @meta directive so LuaLS treats them as type-only (not runtime).

Usage:
    - Add "assets/scripts/types" to workspace.library in .luarc.json
    - Types are automatically available for autocomplete
    - Update these files when APIs change

See: LUA_API_USABILITY_IMPROVEMENTS.md for design rationale.
]]

-- Note: @meta files don't need to require() each other.
-- LuaLS loads all files in workspace.library automatically.
-- This file exists as documentation and an anchor for the types/ directory.
