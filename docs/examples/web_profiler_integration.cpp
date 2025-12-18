/**
 * Example: Web Profiler Integration
 *
 * This file demonstrates how to integrate the web profiler into the game loop
 * to collect comprehensive performance metrics in WASM builds.
 */

#include "util/web_profiler.hpp"
#include "core/globals.hpp"
#include "systems/main_loop_enhancement/main_loop.hpp"

#ifdef __EMSCRIPTEN__

// Track frame metrics
static web_profiler::FrameMetrics g_current_frame;
static auto g_frame_start_time = std::chrono::high_resolution_clock::now();
static auto g_update_start_time = std::chrono::high_resolution_clock::now();
static float g_export_timer = 0.0f;

// Call this at the start of each frame
void profiler_frame_begin() {
    if (!web_profiler::g_enabled) return;

    g_frame_start_time = std::chrono::high_resolution_clock::now();
    g_current_frame = web_profiler::FrameMetrics();
    g_current_frame.timestamp = web_profiler::get_js_timestamp();

    // Mark frame boundary for browser Performance API
    web_profiler::js_mark("frame_start");
}

// Call this before fixed update
void profiler_update_begin() {
    if (!web_profiler::g_enabled) return;
    g_update_start_time = std::chrono::high_resolution_clock::now();
}

// Call this after fixed update
void profiler_update_end() {
    if (!web_profiler::g_enabled) return;

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration<double, std::milli>(end - g_update_start_time);
    g_current_frame.update_time_ms = duration.count();
}

// Call this before rendering
void profiler_render_begin() {
    if (!web_profiler::g_enabled) return;
    g_update_start_time = std::chrono::high_resolution_clock::now(); // reuse variable
}

// Call this after rendering
void profiler_render_end() {
    if (!web_profiler::g_enabled) return;

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration<double, std::milli>(end - g_update_start_time);
    g_current_frame.render_time_ms = duration.count();
}

// Call this at the end of each frame
void profiler_frame_end() {
    if (!web_profiler::g_enabled) return;

    // Calculate total frame time
    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration<double, std::milli>(end - g_frame_start_time);
    g_current_frame.frame_time_ms = duration.count();

    // Add entity count
    g_current_frame.entity_count = globals::getRegistry().size();

    // TODO: Add draw call count from render system
    // g_current_frame.draw_calls = render_system::get_draw_call_count();

    // Record the frame
    web_profiler::record_frame(g_current_frame);

    // Mark frame boundary
    web_profiler::js_mark("frame_end");
    web_profiler::js_measure("frame_total", "frame_start", "frame_end");
}

// Call this periodically to export metrics to JavaScript
void profiler_periodic_export(float dt) {
    if (!web_profiler::g_enabled) return;

    g_export_timer += dt;

    // Export every 5 seconds
    if (g_export_timer >= 5.0f) {
        web_profiler::export_and_send();
        g_export_timer = 0.0f;
    }
}

#else

// Stub implementations for non-web builds
void profiler_frame_begin() {}
void profiler_update_begin() {}
void profiler_update_end() {}
void profiler_render_begin() {}
void profiler_render_end() {}
void profiler_frame_end() {}
void profiler_periodic_export(float) {}

#endif

/**
 * INTEGRATION EXAMPLE
 *
 * Here's how to integrate this into your main game loop (main.cpp):
 */

#if 0 // Example code (not compiled)

// In main game loop:
void gameLoop() {
    profiler_frame_begin(); // ← Add at frame start

    BeginDrawing();

    // ... frame timing calculations ...

    // Fixed update
    {
        profiler_update_begin(); // ← Add before update
        PERF_ZONE("FixedUpdate");

        MainLoopFixedUpdateAbstraction(scaledStep);

        profiler_update_end(); // ← Add after update
    }

    // Rendering
    {
        profiler_render_begin(); // ← Add before render
        PERF_ZONE("Render");

        MainLoopRenderAbstraction(scaledStep);

        profiler_render_end(); // ← Add after render
    }

    EndDrawing();

    profiler_frame_end(); // ← Add at frame end

    // Export metrics periodically
    profiler_periodic_export(deltaTime);
}

#endif

/**
 * USAGE INSTRUCTIONS
 *
 * 1. Build for web:
 *    just build-web
 *
 * 2. Open in browser and open console (F12)
 *
 * 3. Enable profiling:
 *    WebProfiler.toggle()
 *
 * 4. Let run for 30-60 seconds
 *
 * 5. View metrics:
 *    WebProfiler.printMetrics()
 *
 * 6. Export for analysis:
 *    WebProfiler.downloadMetrics()
 *
 * PROFILING SPECIFIC SYSTEMS
 *
 * Add PERF_ZONE macros to profile specific systems:
 */

#if 0 // Example code

void MySystem::update(float dt) {
    PERF_ZONE("MySystem::update");

    {
        PERF_ZONE("MySystem::processEntities");
        for (auto entity : entities) {
            // Process entity...
        }
    }

    {
        PERF_ZONE("MySystem::updatePhysics");
        physics_world->step(dt);
    }
}

#endif

/**
 * ANALYZING RESULTS
 *
 * Frame Time Analysis:
 * - Mean frame time should be ≤16.67ms for 60 FPS
 * - P95/P99 show worst-case performance (stutters)
 * - Large gap between mean and max indicates inconsistent performance
 *
 * System Profiling:
 * - Look for zones with high mean times (bottlenecks)
 * - High count + low mean = many small operations (batch these)
 * - High max = occasional expensive operations (optimize or spread across frames)
 *
 * Memory:
 * - Steady increase = memory leak
 * - Saw-tooth pattern = normal GC
 * - Near limit = risk of OOM
 *
 * See docs/WEB_PROFILING.md for detailed analysis guide.
 */
