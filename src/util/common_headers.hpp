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
#endif

#define SPDLOG_ACTIVE_LEVEL SPDLOG_LEVEL_DEBUG // compiler-time log level

#include "spdlog/spdlog.h" // SPD logging lib // or any library that uses Windows.h
#include "spdlog/sinks/basic_file_sink.h"

#if defined(_WIN32)           // raylib uses these names as function parameters
	#undef near
	#undef far
#endif


// #include "third_party/tracy-master/public/tracy/Tracy.hpp"

#include "entt/fwd.hpp"

#include "snowhouse/snowhouse.h" // Snowhouse assertion lib

#define MAGIC_ENUM_RANGE_MIN -126
#define MAGIC_ENUM_RANGE_MAX 400
#include "magic_enum/magic_enum.hpp" // magic_enum lib
#include "../core/globals.hpp"

