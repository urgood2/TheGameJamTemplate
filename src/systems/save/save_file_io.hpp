#pragma once

#include <functional>
#include <optional>
#include <string>

#include "sol/sol.hpp"

namespace save_io {

/// Synchronously load file content. Returns nullopt if file doesn't exist or read fails.
auto load_file(const std::string& path) -> std::optional<std::string>;

/// Check if file exists at path.
auto file_exists(const std::string& path) -> bool;

/// Delete file at path. Returns true if deleted or didn't exist.
auto delete_file(const std::string& path) -> bool;

/// Asynchronously save content to file with atomic write pattern.
/// Desktop: Background thread with atomic rename.
/// Web: MEMFS write + async IDBFS sync.
/// Callback receives success boolean.
void save_file_async(const std::string& path,
                     const std::string& content,
                     sol::function on_complete);

/// Process pending callbacks on main thread. Call once per frame.
void process_pending_callbacks();

/// Register Lua bindings for save_io module.
void register_lua_bindings(sol::state& lua);

} // namespace save_io
