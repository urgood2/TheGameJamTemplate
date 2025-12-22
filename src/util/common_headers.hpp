#pragma once

/**
 * Common headers like json, spdlog, etc.
 */

#include <nlohmann/json.hpp>
#include <fstream>
using json = nlohmann::json;

#if defined(_WIN32)           
	#define NOGDI             // All GDI defines and routines
	#define NOUSER            // All USER defines and routines
    // Disable ImGui's Win32 clipboard helpers to avoid pulling in winuser APIs
    #define IMGUI_DISABLE_WIN32_DEFAULT_CLIPBOARD_FUNCTIONS
    #define IMGUI_DISABLE_WIN32_DEFAULT_IME_FUNCTIONS
#endif

#define SPDLOG_ACTIVE_LEVEL SPDLOG_LEVEL_DEBUG // compiler-time log level

#include "spdlog/spdlog.h" // SPD logging lib // or any library that uses Windows.h
#include "spdlog/sinks/basic_file_sink.h"

#if defined(_WIN32)           // raylib uses these names as function parameters
	#undef near
	#undef far
#endif

#if defined(TRACY_ENABLE) || (defined(TRACY_ENABLED) && TRACY_ENABLED)
    #include "third_party/tracy-master/public/tracy/Tracy.hpp"
    #define ZONE_SCOPED(name) ZoneScopedN(name)
#else
    #define ZONE_SCOPED(name) /* no-op */
#endif

#include "entt/fwd.hpp"

// Heavy headers - precompile to speed up builds
// These are included in 40+ files each

// EnTT - full header instead of just forward declarations
// (entt/fwd.hpp already included above, but we need full entt for templates)
#include "entt/entt.hpp"

// Sol2 - Lua binding library (included in 45 files)
#include "sol/sol.hpp"

// Raylib - graphics library (included in 47 files)
#include "raylib.h"

#include "snowhouse/snowhouse.h" // Snowhouse assertion lib

#define MAGIC_ENUM_RANGE_MIN -126
#define MAGIC_ENUM_RANGE_MAX 400
#include "magic_enum/magic_enum.hpp" // magic_enum lib
#include "../core/globals.hpp"
