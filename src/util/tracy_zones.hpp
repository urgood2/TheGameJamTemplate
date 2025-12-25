#pragma once

/**
 * Tracy Instrumentation Helper
 *
 * This file provides macros and utilities for Tracy profiler integration.
 * When TRACY_ENABLE is defined, these expand to Tracy macros.
 * Otherwise, they either compile to nothing or use web_profiler fallback.
 *
 * Usage in hot paths:
 *   void update() {
 *       ZONE_SCOPED;  // Automatic zone with function name
 *       // ... code ...
 *   }
 *
 *   void render() {
 *       ZONE_NAMED("Render/Sprites");  // Named zone
 *       // ... code ...
 *   }
 *
 * Frame marking (call once per frame):
 *   FRAME_MARK;
 *
 * Memory tracking:
 *   ZONE_ALLOC(ptr, size);
 *   ZONE_FREE(ptr);
 *
 * Plot values:
 *   ZONE_PLOT("Entity Count", entity_count);
 */

#if defined(TRACY_ENABLE)

// Full Tracy integration
#include "Tracy.hpp"

#define ZONE_SCOPED              ZoneScoped
#define ZONE_NAMED(name)         ZoneScopedN(name)
#define ZONE_FUNCTION            ZoneScoped
#define FRAME_MARK               FrameMark
#define FRAME_MARK_NAMED(name)   FrameMarkNamed(name)
#define ZONE_TEXT(txt, len)      ZoneText(txt, len)
#define ZONE_VALUE(val)          ZoneValue(val)
#define ZONE_COLOR(color)        ZoneColor(color)
#define ZONE_ALLOC(ptr, size)    TracyAlloc(ptr, size)
#define ZONE_FREE(ptr)           TracyFree(ptr)
#define ZONE_PLOT(name, val)     TracyPlot(name, val)
#define ZONE_MESSAGE(msg)        do { if (msg) TracyMessage(msg, strlen(msg)); } while(0)
#define ZONE_MESSAGE_LEN(msg, len) TracyMessage(msg, len)

// Colors for different subsystems (Tracy color format: 0xRRGGBB)
namespace tracy_colors {
    constexpr uint32_t Render     = 0x4488FF;  // Blue
    constexpr uint32_t Physics    = 0x44FF88;  // Green
    constexpr uint32_t Scripting  = 0xFFAA44;  // Orange
    constexpr uint32_t AI         = 0xFF44AA;  // Pink
    constexpr uint32_t Audio      = 0xAA44FF;  // Purple
    constexpr uint32_t Input      = 0xFFFF44;  // Yellow
    constexpr uint32_t Update     = 0x44FFFF;  // Cyan
}

#else

// Fallback to web_profiler or no-op
#include "web_profiler.hpp"

#define ZONE_SCOPED              PERF_ZONE(__FUNCTION__)
#define ZONE_NAMED(name)         PERF_ZONE(name)
#define ZONE_FUNCTION            PERF_ZONE(__FUNCTION__)
#define FRAME_MARK               ((void)0)
#define FRAME_MARK_NAMED(name)   ((void)0)
#define ZONE_TEXT(txt, len)      ((void)0)
#define ZONE_VALUE(val)          ((void)0)
#define ZONE_COLOR(color)        ((void)0)
#define ZONE_ALLOC(ptr, size)    ((void)0)
#define ZONE_FREE(ptr)           ((void)0)
#define ZONE_PLOT(name, val)     ((void)0)
#define ZONE_MESSAGE(msg)        ((void)0)

namespace tracy_colors {
    constexpr uint32_t Render     = 0;
    constexpr uint32_t Physics    = 0;
    constexpr uint32_t Scripting  = 0;
    constexpr uint32_t AI         = 0;
    constexpr uint32_t Audio      = 0;
    constexpr uint32_t Input      = 0;
    constexpr uint32_t Update     = 0;
}

#endif

/**
 * Instrumentation Checklist - ZONE_SCOPED status:
 *
 * Core Loop:
 * - [x] main.cpp: RunGameLoop(), MainLoopFixedUpdateAbstraction, updateSystems
 * - [x] game.cpp: update(), draw()
 *
 * Rendering:
 * - [x] layer_command_buffer.cpp: ExecuteCommands
 * - [x] layer.cpp: Begin
 * - [x] anim_system.cpp: Update
 * - [x] textVer2.cpp: renderText
 *
 * Physics:
 * - [x] physics_world.cpp: Update(), PostUpdate()
 * - [x] main.cpp: Physics step, ApplyAuthoritativeTransform/Physics
 *
 * Scripting:
 * - [x] scripting_system.cpp: update()
 * - [x] main.cpp: monobehavior_system::update
 *
 * AI:
 * - [x] main.cpp: AI System Update, updateHumanAI
 *
 * Audio:
 * - [x] sound_system.cpp: Update
 *
 * Input:
 * - [x] input_functions.cpp: Update
 *
 * UI:
 * - [x] element.cpp: UpdateObject, DrawSelf, Update
 * - [x] util.cpp: various drawing functions
 *
 * Transform:
 * - [x] transform_functions.cpp: UpdateAllTransforms, UpdateTransform
 */
