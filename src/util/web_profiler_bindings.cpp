#include "web_profiler.hpp"

#ifdef __EMSCRIPTEN__
#include <emscripten.h>

extern "C" {

// Toggle profiling on/off from JavaScript
EMSCRIPTEN_KEEPALIVE
void web_profiler_toggle(bool enabled) {
    web_profiler::toggle_profiling(enabled);
    web_profiler::g_collect_frame_metrics = enabled;
}

// Export metrics to JavaScript
EMSCRIPTEN_KEEPALIVE
void web_profiler_export() {
    web_profiler::export_and_send();
}

// Reset all profiler data
EMSCRIPTEN_KEEPALIVE
void web_profiler_reset() {
    web_profiler::reset_stats();
}

// Print stats to console (for debugging)
EMSCRIPTEN_KEEPALIVE
void web_profiler_print() {
    web_profiler::print_stats();
}

// Get enabled state
EMSCRIPTEN_KEEPALIVE
bool web_profiler_is_enabled() {
    return web_profiler::g_enabled;
}

} // extern "C"

#endif // __EMSCRIPTEN__
