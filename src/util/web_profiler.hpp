#pragma once

#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif

#include <string>
#include <chrono>
#include <unordered_map>
#include <vector>
#include <deque>
#include <iostream>
#include <sstream>
#include <algorithm>

namespace web_profiler {

struct TimingStats {
    double total_ms = 0;
    double min_ms = 999999;
    double max_ms = 0;
    size_t count = 0;

    void add(double ms) {
        total_ms += ms;
        min_ms = std::min(min_ms, ms);
        max_ms = std::max(max_ms, ms);
        ++count;
    }

    double mean() const { return count > 0 ? total_ms / count : 0; }
};

struct FrameMetrics {
    double frame_time_ms = 0;
    double update_time_ms = 0;
    double render_time_ms = 0;
    size_t entity_count = 0;
    size_t draw_calls = 0;
    double timestamp = 0; // JavaScript timestamp
};

inline std::unordered_map<std::string, TimingStats> g_timings;
inline std::deque<FrameMetrics> g_frame_history;
inline constexpr size_t MAX_FRAME_HISTORY = 300; // ~5 seconds at 60fps
inline bool g_enabled = true;
inline bool g_collect_frame_metrics = false;

class ScopedZone {
public:
    ScopedZone(const char* name) : name_(name) {
        if (g_enabled) {
            start_ = std::chrono::high_resolution_clock::now();
        }
    }

    ~ScopedZone() {
        if (g_enabled) {
            auto end = std::chrono::high_resolution_clock::now();
            auto duration = std::chrono::duration<double, std::milli>(end - start_);
            g_timings[name_].add(duration.count());
        }
    }

private:
    const char* name_;
    std::chrono::high_resolution_clock::time_point start_;
};

inline void print_stats() {
    std::cout << "\n=== Web Profiler Stats ===\n";
    for (const auto& [name, stats] : g_timings) {
        if (stats.count > 0) {
            std::cout << name << ":\n"
                      << "  count: " << stats.count << "\n"
                      << "  mean:  " << stats.mean() << " ms\n"
                      << "  min:   " << stats.min_ms << " ms\n"
                      << "  max:   " << stats.max_ms << " ms\n"
                      << "  total: " << stats.total_ms << " ms\n";
        }
    }
    std::cout << "==========================\n";
}

inline void reset_stats() {
    g_timings.clear();
    g_frame_history.clear();
}

inline void record_frame(const FrameMetrics& metrics) {
    if (!g_collect_frame_metrics) return;

    g_frame_history.push_back(metrics);
    if (g_frame_history.size() > MAX_FRAME_HISTORY) {
        g_frame_history.pop_front();
    }
}

inline std::string export_json() {
    std::ostringstream oss;
    oss << "{\n  \"timings\": {\n";

    bool first = true;
    for (const auto& [name, stats] : g_timings) {
        if (!first) oss << ",\n";
        first = false;
        oss << "    \"" << name << "\": {\n"
            << "      \"count\": " << stats.count << ",\n"
            << "      \"mean\": " << stats.mean() << ",\n"
            << "      \"min\": " << stats.min_ms << ",\n"
            << "      \"max\": " << stats.max_ms << ",\n"
            << "      \"total\": " << stats.total_ms << "\n"
            << "    }";
    }

    oss << "\n  },\n  \"frame_history\": [\n";

    first = true;
    for (const auto& frame : g_frame_history) {
        if (!first) oss << ",\n";
        first = false;
        oss << "    {\n"
            << "      \"frame_time\": " << frame.frame_time_ms << ",\n"
            << "      \"update_time\": " << frame.update_time_ms << ",\n"
            << "      \"render_time\": " << frame.render_time_ms << ",\n"
            << "      \"entity_count\": " << frame.entity_count << ",\n"
            << "      \"draw_calls\": " << frame.draw_calls << ",\n"
            << "      \"timestamp\": " << frame.timestamp << "\n"
            << "    }";
    }

    oss << "\n  ]\n}";
    return oss.str();
}

// JS console timing (web only)
#ifdef __EMSCRIPTEN__
inline void js_time_start(const char* label) {
    EM_ASM({ console.time(UTF8ToString($0)); }, label);
}

inline void js_time_end(const char* label) {
    EM_ASM({ console.timeEnd(UTF8ToString($0)); }, label);
}

inline void js_mark(const char* name) {
    EM_ASM({ performance.mark(UTF8ToString($0)); }, name);
}

inline void js_measure(const char* name, const char* start_mark, const char* end_mark) {
    EM_ASM({
        performance.measure(UTF8ToString($0), UTF8ToString($1), UTF8ToString($2));
    }, name, start_mark, end_mark);
}

inline void send_to_js(const char* json_data) {
    EM_ASM({
        if (window.WebProfiler && window.WebProfiler.receiveMetrics) {
            window.WebProfiler.receiveMetrics(UTF8ToString($0));
        }
    }, json_data);
}

inline double get_js_timestamp() {
    return EM_ASM_DOUBLE({
        return performance.now();
    });
}

inline void toggle_profiling(bool enabled) {
    g_enabled = enabled;
    EM_ASM({
        console.log('[WebProfiler] Profiling ' + ($0 ? 'enabled' : 'disabled'));
    }, enabled);
}

inline void export_and_send() {
    std::string json = export_json();
    send_to_js(json.c_str());
}

#else
inline void js_time_start(const char*) {}
inline void js_time_end(const char*) {}
inline void js_mark(const char*) {}
inline void js_measure(const char*, const char*, const char*) {}
inline void send_to_js(const char*) {}
inline double get_js_timestamp() { return 0.0; }
inline void toggle_profiling(bool) {}
inline void export_and_send() {}
#endif

} // namespace web_profiler

// Unified macro: Tracy when enabled, web_profiler otherwise
#if defined(TRACY_ENABLE) || (defined(TRACY_ENABLED) && TRACY_ENABLED)
    #define PERF_ZONE(name) ZoneScopedN(name)
#else
    #define PERF_ZONE(name) web_profiler::ScopedZone _zone_##__LINE__(name)
#endif
