#pragma once

// Lua/C++ Boundary Profiler
//
// Usage:
//   1. Enable via CMake: -DPROFILE_LUA_BOUNDARY=ON
//   2. Or manually define: -DPROFILE_LUA_BOUNDARY=1
//   3. Add LUA_PROFILE_CALL("function_name") at function entry
//
// Requirements:
//   - Function names must be string literals (static lifetime)
//   - Intended for coarse profiling (e.g., per-system update, not every getter)
//
// Example:
//   void update_physics(sol::state& lua) {
//       LUA_PROFILE_CALL("update_physics");
//       // ... physics work ...
//   }
//
// Query results via ImGui or lua_profiler::print_top_calls(20).

#include <atomic>
#include <string>
#include <unordered_map>
#include <mutex>
#include <chrono>
#include <vector>
#include <algorithm>
#include <iostream>

namespace lua_profiler {

struct CallStats {
    uint64_t call_count{0};  // Protected by g_stats_mutex
    uint64_t total_ns{0};    // Protected by g_stats_mutex
};

#ifdef PROFILE_LUA_BOUNDARY
inline std::unordered_map<std::string, CallStats> g_call_stats;
inline std::mutex g_stats_mutex;
inline bool g_profiling_enabled = false;

inline void record_call(const char* func_name, uint64_t duration_ns) {
    if (!g_profiling_enabled) return;
    std::lock_guard<std::mutex> lock(g_stats_mutex);
    auto& stats = g_call_stats[func_name];
    stats.call_count += 1;
    stats.total_ns += duration_ns;
}

inline void enable_profiling(bool enabled) {
    g_profiling_enabled = enabled;
}

inline void reset_stats() {
    std::lock_guard<std::mutex> lock(g_stats_mutex);
    g_call_stats.clear();
}

inline void print_top_calls(size_t n = 20) {
    std::lock_guard<std::mutex> lock(g_stats_mutex);

    std::vector<std::pair<std::string, uint64_t>> sorted;
    for (const auto& [name, stats] : g_call_stats) {
        sorted.emplace_back(name, stats.call_count);
    }

    std::sort(sorted.begin(), sorted.end(),
        [](const auto& a, const auto& b) { return a.second > b.second; });

    std::cout << "\n=== Top " << n << " Lua->C++ Calls ===\n";
    for (size_t i = 0; i < std::min(n, sorted.size()); ++i) {
        const auto& [name, count] = sorted[i];
        auto& stats = g_call_stats[name];
        double avg_us = stats.total_ns / 1000.0 / count;
        std::cout << i+1 << ". " << name << ": " << count
                  << " calls, " << avg_us << " us/call avg\n";
    }
}

class ScopedCallTimer {
public:
    ScopedCallTimer(const char* name) : name_(name) {
        if (g_profiling_enabled) {
            start_ = std::chrono::high_resolution_clock::now();
        }
    }

    ~ScopedCallTimer() {
        if (g_profiling_enabled) {
            auto end = std::chrono::high_resolution_clock::now();
            auto ns = std::chrono::duration_cast<std::chrono::nanoseconds>(end - start_).count();
            record_call(name_, ns);
        }
    }

private:
    const char* name_;
    std::chrono::high_resolution_clock::time_point start_;
};

#define LUA_PROFILE_CALL(name) lua_profiler::ScopedCallTimer _lua_timer_##__LINE__(name)

#else
// No-op when profiling disabled
#define LUA_PROFILE_CALL(name)
inline void enable_profiling(bool) {}
inline void reset_stats() {}
inline void print_top_calls(size_t = 20) {}
#endif

} // namespace lua_profiler
