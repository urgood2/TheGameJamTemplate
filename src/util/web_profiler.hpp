#pragma once

#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif

#include <string>
#include <chrono>
#include <unordered_map>
#include <vector>
#include <iostream>

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

inline std::unordered_map<std::string, TimingStats> g_timings;
inline bool g_enabled = true;

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
#else
inline void js_time_start(const char*) {}
inline void js_time_end(const char*) {}
inline void js_mark(const char*) {}
inline void js_measure(const char*, const char*, const char*) {}
#endif

} // namespace web_profiler

// Unified macro: Tracy when enabled, web_profiler otherwise
#if defined(TRACY_ENABLE) || (defined(TRACY_ENABLED) && TRACY_ENABLED)
    #define PERF_ZONE(name) ZoneScopedN(name)
#else
    #define PERF_ZONE(name) web_profiler::ScopedZone _zone_##__LINE__(name)
#endif
