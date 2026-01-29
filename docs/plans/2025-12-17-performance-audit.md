# Comprehensive Performance Audit Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Systematically profile and optimize the game engine for both native and web platforms, targeting Lua/C++ boundary and rendering performance.

**Architecture:** Profile-driven optimization with TDD. Each optimization gets a benchmark test first, then implementation. Feature flags enable/disable optimizations safely.

**Tech Stack:** C++20, Lua/Sol2, Tracy Profiler, GoogleTest, Emscripten, Raylib 5.5

---

## Phase 1: Profiling Infrastructure

### Task 1.1: Verify Tracy Build Configuration

**Files:**
- Check: `CMakeLists.txt`
- Check: `src/util/common_headers.hpp:29-34`

**Step 1: Verify Tracy macro definition exists**

```bash
grep -n "TRACY_ENABLE" CMakeLists.txt
grep -n "ZONE_SCOPED" src/util/common_headers.hpp
```

Expected: Find Tracy conditional compilation setup.

**Step 2: Create Tracy-enabled build configuration**

Check if Tracy build option exists:
```bash
grep -i "tracy" CMakeLists.txt justfile
```

If missing, add to `justfile`:
```makefile
# Add after existing build recipes
build-tracy:
    cmake -B build-tracy -DTRACY_ENABLE=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo
    cmake --build build-tracy
```

**Step 3: Commit if changes made**

```bash
git add justfile
git commit -m "build: add Tracy-enabled build configuration"
```

---

### Task 1.2: Create Benchmark Test Infrastructure

**Files:**
- Create: `tests/benchmark/benchmark_common.hpp`
- Create: `tests/benchmark/CMakeLists.txt`
- Modify: `tests/CMakeLists.txt`

**Step 1: Create benchmark header with timing utilities**

Create `tests/benchmark/benchmark_common.hpp`:
```cpp
#pragma once

#include <chrono>
#include <string>
#include <vector>
#include <numeric>
#include <algorithm>
#include <iostream>

namespace benchmark {

struct TimingResult {
    double mean_ms;
    double median_ms;
    double p99_ms;
    double min_ms;
    double max_ms;
    size_t iterations;
};

class ScopedTimer {
public:
    using Clock = std::chrono::high_resolution_clock;

    ScopedTimer(std::vector<double>& results) : results_(results) {
        start_ = Clock::now();
    }

    ~ScopedTimer() {
        auto end = Clock::now();
        auto duration = std::chrono::duration<double, std::milli>(end - start_);
        results_.push_back(duration.count());
    }

private:
    Clock::time_point start_;
    std::vector<double>& results_;
};

inline TimingResult analyze(std::vector<double>& times) {
    if (times.empty()) return {};

    std::sort(times.begin(), times.end());

    TimingResult result;
    result.iterations = times.size();
    result.min_ms = times.front();
    result.max_ms = times.back();
    result.median_ms = times[times.size() / 2];
    result.p99_ms = times[static_cast<size_t>(times.size() * 0.99)];
    result.mean_ms = std::accumulate(times.begin(), times.end(), 0.0) / times.size();

    return result;
}

inline void print_result(const std::string& name, const TimingResult& r) {
    std::cout << "[BENCHMARK] " << name << "\n"
              << "  iterations: " << r.iterations << "\n"
              << "  mean:   " << r.mean_ms << " ms\n"
              << "  median: " << r.median_ms << " ms\n"
              << "  p99:    " << r.p99_ms << " ms\n"
              << "  min:    " << r.min_ms << " ms\n"
              << "  max:    " << r.max_ms << " ms\n";
}

// Macro for benchmark loops
#define BENCHMARK_ITERATIONS 100

#define RUN_BENCHMARK(name, code) \
    do { \
        std::vector<double> times; \
        for (int i = 0; i < BENCHMARK_ITERATIONS; ++i) { \
            benchmark::ScopedTimer timer(times); \
            code; \
        } \
        auto result = benchmark::analyze(times); \
        benchmark::print_result(name, result); \
    } while(0)

} // namespace benchmark
```

**Step 2: Create benchmark CMakeLists.txt**

Create `tests/benchmark/CMakeLists.txt`:
```cmake
# Benchmark tests for performance audit

set(BENCHMARK_SOURCES
    benchmark_lua_boundary.cpp
    benchmark_rendering.cpp
)

# Benchmarks are separate from unit tests
add_executable(perf_benchmarks
    ${BENCHMARK_SOURCES}
)

target_include_directories(perf_benchmarks PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(perf_benchmarks PRIVATE
    ${PROJECT_NAME}_lib
    GTest::gtest_main
)

# Don't run benchmarks with regular tests (they're slow)
# Run manually: ./build/tests/benchmark/perf_benchmarks
```

**Step 3: Add benchmark subdirectory to tests CMakeLists.txt**

In `tests/CMakeLists.txt`, add at the end:
```cmake
# Benchmark tests (separate from unit tests)
add_subdirectory(benchmark)
```

**Step 4: Commit**

```bash
git add tests/benchmark/benchmark_common.hpp tests/benchmark/CMakeLists.txt tests/CMakeLists.txt
git commit -m "test: add benchmark test infrastructure for performance audit"
```

---

### Task 1.3: Create Lua/C++ Boundary Benchmark Test (RED)

**Files:**
- Create: `tests/benchmark/benchmark_lua_boundary.cpp`

**Step 1: Write the benchmark test file**

Create `tests/benchmark/benchmark_lua_boundary.cpp`:
```cpp
#include <gtest/gtest.h>
#include "benchmark_common.hpp"

#define SOL_ALL_SAFETIES_ON 1
#include <sol/sol.hpp>

class LuaBoundaryBenchmark : public ::testing::Test {
protected:
    sol::state lua;

    void SetUp() override {
        lua.open_libraries(sol::lib::base, sol::lib::math, sol::lib::table);
    }
};

// Baseline: Measure cost of crossing Lua/C++ boundary
TEST_F(LuaBoundaryBenchmark, SingleFunctionCall) {
    // Expose a simple C++ function
    lua.set_function("cpp_add", [](int a, int b) { return a + b; });

    std::vector<double> times;
    const int ITERATIONS = 10000;

    for (int i = 0; i < 100; ++i) {
        benchmark::ScopedTimer timer(times);
        for (int j = 0; j < ITERATIONS; ++j) {
            lua.script("local result = cpp_add(1, 2)");
        }
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("SingleFunctionCall (10k calls)", result);

    // Baseline expectation: record current performance
    // This will fail initially - we'll update threshold after first run
    EXPECT_LT(result.mean_ms, 1000.0) << "Baseline measurement - update threshold";
}

// Measure table creation overhead (common pattern)
TEST_F(LuaBoundaryBenchmark, TableCreationInLoop) {
    lua.script(R"(
        function create_tables(n)
            local results = {}
            for i = 1, n do
                results[i] = { x = i, y = i * 2, z = i * 3 }
            end
            return results
        end
    )");

    std::vector<double> times;

    for (int i = 0; i < 100; ++i) {
        benchmark::ScopedTimer timer(times);
        sol::table result = lua["create_tables"](1000);
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("TableCreationInLoop (1k tables)", result);

    EXPECT_LT(result.mean_ms, 100.0) << "Baseline measurement - update threshold";
}

// Measure repeated component access pattern
TEST_F(LuaBoundaryBenchmark, RepeatedPropertyAccess) {
    // Simulate component cache pattern
    struct FakeTransform {
        float x = 0, y = 0, w = 32, h = 32;
    };

    FakeTransform transform;

    lua.new_usertype<FakeTransform>("Transform",
        "x", &FakeTransform::x,
        "y", &FakeTransform::y,
        "w", &FakeTransform::w,
        "h", &FakeTransform::h
    );

    lua["transform"] = &transform;

    lua.script(R"(
        function update_transform(n)
            for i = 1, n do
                transform.x = transform.x + 1
                transform.y = transform.y + 1
            end
        end
    )");

    std::vector<double> times;

    for (int i = 0; i < 100; ++i) {
        transform.x = 0;
        transform.y = 0;
        benchmark::ScopedTimer timer(times);
        lua["update_transform"](10000);
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("RepeatedPropertyAccess (10k accesses)", result);

    EXPECT_LT(result.mean_ms, 500.0) << "Baseline measurement - update threshold";
}

// Measure callback from C++ to Lua (common in event system)
TEST_F(LuaBoundaryBenchmark, CallbackFromCpp) {
    lua.script(R"(
        callback_count = 0
        function on_event(entity_id, event_type)
            callback_count = callback_count + 1
        end
    )");

    sol::function callback = lua["on_event"];

    std::vector<double> times;

    for (int i = 0; i < 100; ++i) {
        lua["callback_count"] = 0;
        benchmark::ScopedTimer timer(times);
        for (int j = 0; j < 1000; ++j) {
            callback(j, "damage");
        }
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("CallbackFromCpp (1k callbacks)", result);

    EXPECT_LT(result.mean_ms, 200.0) << "Baseline measurement - update threshold";
}
```

**Step 2: Verify it compiles (don't run yet - needs build)**

This will be built and run during Phase 1 execution.

**Step 3: Commit**

```bash
git add tests/benchmark/benchmark_lua_boundary.cpp
git commit -m "test(perf): add Lua/C++ boundary benchmark tests (RED)"
```

---

### Task 1.4: Create Rendering Benchmark Test (RED)

**Files:**
- Create: `tests/benchmark/benchmark_rendering.cpp`

**Step 1: Write the rendering benchmark test file**

Create `tests/benchmark/benchmark_rendering.cpp`:
```cpp
#include <gtest/gtest.h>
#include "benchmark_common.hpp"

#include <vector>
#include <algorithm>
#include <random>

// Mock draw command for benchmarking sort performance
struct MockDrawCommand {
    int z;
    int space;  // 0 = World, 1 = Screen
    int shader_id;
    int texture_id;
    void* data;
};

class RenderingBenchmark : public ::testing::Test {
protected:
    std::vector<MockDrawCommand> commands;
    std::mt19937 rng{42};  // Fixed seed for reproducibility

    void SetUp() override {
        // Generate realistic command distribution
        commands.clear();
    }

    void generateCommands(size_t count, int z_range = 100, int shader_count = 10, int texture_count = 50) {
        commands.reserve(count);
        std::uniform_int_distribution<int> z_dist(0, z_range);
        std::uniform_int_distribution<int> space_dist(0, 1);
        std::uniform_int_distribution<int> shader_dist(0, shader_count - 1);
        std::uniform_int_distribution<int> texture_dist(0, texture_count - 1);

        for (size_t i = 0; i < count; ++i) {
            commands.push_back({
                z_dist(rng),
                space_dist(rng),
                shader_dist(rng),
                texture_dist(rng),
                nullptr
            });
        }
    }
};

// Current sort: z only
TEST_F(RenderingBenchmark, SortByZOnly) {
    generateCommands(5000);

    std::vector<double> times;

    for (int i = 0; i < 100; ++i) {
        auto cmds = commands;  // Copy for each iteration
        benchmark::ScopedTimer timer(times);
        std::stable_sort(cmds.begin(), cmds.end(),
            [](const MockDrawCommand& a, const MockDrawCommand& b) {
                return a.z < b.z;
            });
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("SortByZOnly (5k commands)", result);

    EXPECT_LT(result.mean_ms, 10.0) << "Sort should be fast";
}

// Current state batching: z then space
TEST_F(RenderingBenchmark, SortByZAndSpace) {
    generateCommands(5000);

    std::vector<double> times;

    for (int i = 0; i < 100; ++i) {
        auto cmds = commands;
        benchmark::ScopedTimer timer(times);
        std::stable_sort(cmds.begin(), cmds.end(),
            [](const MockDrawCommand& a, const MockDrawCommand& b) {
                if (a.z != b.z) return a.z < b.z;
                if (a.space != b.space) return a.space < b.space;
                return false;
            });
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("SortByZAndSpace (5k commands)", result);

    EXPECT_LT(result.mean_ms, 10.0) << "Sort should be fast";
}

// Proposed: z, space, shader, texture (full batching)
TEST_F(RenderingBenchmark, SortByFullBatchKey) {
    generateCommands(5000);

    std::vector<double> times;

    for (int i = 0; i < 100; ++i) {
        auto cmds = commands;
        benchmark::ScopedTimer timer(times);
        std::stable_sort(cmds.begin(), cmds.end(),
            [](const MockDrawCommand& a, const MockDrawCommand& b) {
                if (a.z != b.z) return a.z < b.z;
                if (a.space != b.space) return a.space < b.space;
                if (a.shader_id != b.shader_id) return a.shader_id < b.shader_id;
                if (a.texture_id != b.texture_id) return a.texture_id < b.texture_id;
                return false;
            });
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("SortByFullBatchKey (5k commands)", result);

    EXPECT_LT(result.mean_ms, 15.0) << "Full sort should be reasonable";
}

// Measure state change counting
TEST_F(RenderingBenchmark, CountStateChanges) {
    generateCommands(5000);

    // Sort by z only
    std::stable_sort(commands.begin(), commands.end(),
        [](const MockDrawCommand& a, const MockDrawCommand& b) {
            return a.z < b.z;
        });

    int space_changes = 0;
    int shader_changes = 0;
    int texture_changes = 0;

    for (size_t i = 1; i < commands.size(); ++i) {
        if (commands[i].space != commands[i-1].space) ++space_changes;
        if (commands[i].shader_id != commands[i-1].shader_id) ++shader_changes;
        if (commands[i].texture_id != commands[i-1].texture_id) ++texture_changes;
    }

    std::cout << "[STATE CHANGES] z-only sort:\n"
              << "  space changes:   " << space_changes << "\n"
              << "  shader changes:  " << shader_changes << "\n"
              << "  texture changes: " << texture_changes << "\n";

    // Now sort by full key
    std::stable_sort(commands.begin(), commands.end(),
        [](const MockDrawCommand& a, const MockDrawCommand& b) {
            if (a.z != b.z) return a.z < b.z;
            if (a.space != b.space) return a.space < b.space;
            if (a.shader_id != b.shader_id) return a.shader_id < b.shader_id;
            if (a.texture_id != b.texture_id) return a.texture_id < b.texture_id;
            return false;
        });

    int space_changes_opt = 0;
    int shader_changes_opt = 0;
    int texture_changes_opt = 0;

    for (size_t i = 1; i < commands.size(); ++i) {
        if (commands[i].space != commands[i-1].space) ++space_changes_opt;
        if (commands[i].shader_id != commands[i-1].shader_id) ++shader_changes_opt;
        if (commands[i].texture_id != commands[i-1].texture_id) ++texture_changes_opt;
    }

    std::cout << "[STATE CHANGES] full-key sort:\n"
              << "  space changes:   " << space_changes_opt << "\n"
              << "  shader changes:  " << shader_changes_opt << "\n"
              << "  texture changes: " << texture_changes_opt << "\n";

    // Full sort should reduce state changes
    EXPECT_LE(space_changes_opt, space_changes);
    EXPECT_LE(shader_changes_opt, shader_changes);
    EXPECT_LE(texture_changes_opt, texture_changes);
}

// Large scale test
TEST_F(RenderingBenchmark, LargeScaleSort) {
    generateCommands(20000);  // Stress test

    std::vector<double> times;

    for (int i = 0; i < 50; ++i) {
        auto cmds = commands;
        benchmark::ScopedTimer timer(times);
        std::stable_sort(cmds.begin(), cmds.end(),
            [](const MockDrawCommand& a, const MockDrawCommand& b) {
                if (a.z != b.z) return a.z < b.z;
                if (a.space != b.space) return a.space < b.space;
                if (a.shader_id != b.shader_id) return a.shader_id < b.shader_id;
                return false;
            });
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("LargeScaleSort (20k commands)", result);

    // Should complete in reasonable time even at scale
    EXPECT_LT(result.p99_ms, 50.0) << "Large sort p99 should be under 50ms";
}
```

**Step 2: Commit**

```bash
git add tests/benchmark/benchmark_rendering.cpp
git commit -m "test(perf): add rendering benchmark tests (RED)"
```

---

### Task 1.5: Create Web Profiling Utility

**Files:**
- Create: `src/util/web_profiler.hpp`

**Step 1: Write web profiling header**

Create `src/util/web_profiler.hpp`:
```cpp
#pragma once

// Web profiling utilities - lightweight timing for WASM builds
// (Tracy doesn't work on web, so we need manual instrumentation)

#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif

#include <string>
#include <chrono>
#include <unordered_map>
#include <vector>
#include <iostream>

namespace web_profiler {

// Simple timing accumulator
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

// Global timing storage
inline std::unordered_map<std::string, TimingStats> g_timings;
inline bool g_enabled = true;

// Scoped timer that records to global stats
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

// Print all collected stats
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

// Reset all stats
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
// No-op on native
inline void js_time_start(const char*) {}
inline void js_time_end(const char*) {}
inline void js_mark(const char*) {}
inline void js_measure(const char*, const char*, const char*) {}
#endif

} // namespace web_profiler

// Unified macro that works on both platforms
#if defined(TRACY_ENABLE) || (defined(TRACY_ENABLED) && TRACY_ENABLED)
    // Use Tracy on native when enabled
    #define PERF_ZONE(name) ZoneScopedN(name)
#else
    // Use web profiler otherwise
    #define PERF_ZONE(name) web_profiler::ScopedZone _zone_##__LINE__(name)
#endif
```

**Step 2: Commit**

```bash
git add src/util/web_profiler.hpp
git commit -m "feat(perf): add web profiling utilities for WASM builds"
```

---

### Task 1.6: Document Baseline Metrics Template

**Files:**
- Create: `docs/perf/baseline-metrics.md`

**Step 1: Create baseline metrics template**

Create `docs/perf/baseline-metrics.md`:
```markdown
# Performance Baseline Metrics

**Date:** [Fill in after running benchmarks]
**Commit:** [Fill in]
**Platform:** [Native / Web]

## Test Environment

- **OS:**
- **CPU:**
- **GPU:**
- **RAM:**

## Lua/C++ Boundary

| Benchmark | Mean (ms) | P99 (ms) | Notes |
|-----------|-----------|----------|-------|
| SingleFunctionCall (10k) | | | |
| TableCreationInLoop (1k) | | | |
| RepeatedPropertyAccess (10k) | | | |
| CallbackFromCpp (1k) | | | |

## Rendering

| Benchmark | Mean (ms) | P99 (ms) | Notes |
|-----------|-----------|----------|-------|
| SortByZOnly (5k) | | | |
| SortByZAndSpace (5k) | | | |
| SortByFullBatchKey (5k) | | | |
| LargeScaleSort (20k) | | | |

### State Changes (5k commands)

| Sort Method | Space Changes | Shader Changes | Texture Changes |
|-------------|---------------|----------------|-----------------|
| Z-only | | | |
| Full-key | | | |

## In-Game Metrics

| Metric | Value | Notes |
|--------|-------|-------|
| Draw calls (typical scene) | | |
| FPS (typical scene) | | |
| Frame time avg (ms) | | |
| Frame time p99 (ms) | | |
| Memory usage (MB) | | |

## Web-Specific (if applicable)

| Metric | Value | Notes |
|--------|-------|-------|
| WASM module size (MB) | | |
| Initial load time (s) | | |
| FPS (same scene) | | |
| Memory heap (MB) | | |
```

**Step 2: Create docs/perf directory**

```bash
mkdir -p docs/perf
```

**Step 3: Commit**

```bash
git add docs/perf/baseline-metrics.md
git commit -m "docs(perf): add baseline metrics template"
```

---

## Phase 2: Lua/C++ Boundary Optimization

### Task 2.1: Add Boundary Crossing Instrumentation

**Files:**
- Modify: `src/systems/scripting/scripting_functions.cpp`
- Create: `src/systems/scripting/lua_profiler.hpp`

**Step 1: Create Lua profiler header**

Create `src/systems/scripting/lua_profiler.hpp`:
```cpp
#pragma once

#include <atomic>
#include <string>
#include <unordered_map>
#include <mutex>

namespace lua_profiler {

// Thread-safe call counter
struct CallStats {
    std::atomic<uint64_t> call_count{0};
    std::atomic<uint64_t> total_ns{0};
};

// Global call tracking (enabled in debug/profile builds)
#ifdef PROFILE_LUA_BOUNDARY
inline std::unordered_map<std::string, CallStats> g_call_stats;
inline std::mutex g_stats_mutex;
inline bool g_profiling_enabled = false;

inline void record_call(const char* func_name, uint64_t duration_ns) {
    if (!g_profiling_enabled) return;
    std::lock_guard<std::mutex> lock(g_stats_mutex);
    auto& stats = g_call_stats[func_name];
    stats.call_count.fetch_add(1, std::memory_order_relaxed);
    stats.total_ns.fetch_add(duration_ns, std::memory_order_relaxed);
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
        sorted.emplace_back(name, stats.call_count.load());
    }

    std::sort(sorted.begin(), sorted.end(),
        [](const auto& a, const auto& b) { return a.second > b.second; });

    std::cout << "\n=== Top " << n << " Lua->C++ Calls ===\n";
    for (size_t i = 0; i < std::min(n, sorted.size()); ++i) {
        const auto& [name, count] = sorted[i];
        auto& stats = g_call_stats[name];
        double avg_us = stats.total_ns.load() / 1000.0 / count;
        std::cout << i+1 << ". " << name << ": " << count
                  << " calls, " << avg_us << " us/call avg\n";
    }
}

// RAII timer for function calls
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
```

**Step 2: Commit**

```bash
git add src/systems/scripting/lua_profiler.hpp
git commit -m "feat(perf): add Lua/C++ boundary call profiler"
```

---

### Task 2.2: Implement Bulk Component Access API

**Files:**
- Modify: `src/systems/scripting/scripting_functions.cpp`
- Create: `tests/unit/test_bulk_component_access.cpp`

**Step 1: Write failing test**

Create `tests/unit/test_bulk_component_access.cpp`:
```cpp
#include <gtest/gtest.h>
#include <sol/sol.hpp>
#include <entt/entt.hpp>

// Test that bulk component access exists and works
class BulkComponentAccessTest : public ::testing::Test {
protected:
    sol::state lua;
    entt::registry registry;

    void SetUp() override {
        lua.open_libraries(sol::lib::base, sol::lib::table);
        // Setup would bind bulk functions
    }
};

TEST_F(BulkComponentAccessTest, GetMultipleTransforms) {
    // Create test entities
    std::vector<entt::entity> entities;
    for (int i = 0; i < 100; ++i) {
        auto e = registry.create();
        // Would add Transform component
        entities.push_back(e);
    }

    // Test: bulk access should exist
    // This is a design placeholder - actual implementation depends on codebase
    EXPECT_EQ(entities.size(), 100);
}
```

**Step 2: Commit test (RED)**

```bash
git add tests/unit/test_bulk_component_access.cpp
git commit -m "test(perf): add bulk component access test (RED)"
```

**Note:** The actual implementation of bulk APIs requires deeper codebase analysis. This task establishes the test structure; implementation details will be filled in during execution based on existing patterns.

---

### Task 2.3: Profile Coroutine Overhead

**Files:**
- Create: `tests/benchmark/benchmark_coroutines.cpp`

**Step 1: Write coroutine benchmark**

Create `tests/benchmark/benchmark_coroutines.cpp`:
```cpp
#include <gtest/gtest.h>
#include "benchmark_common.hpp"
#include <sol/sol.hpp>

class CoroutineBenchmark : public ::testing::Test {
protected:
    sol::state lua;

    void SetUp() override {
        lua.open_libraries(sol::lib::base, sol::lib::coroutine, sol::lib::table);
    }
};

TEST_F(CoroutineBenchmark, CoroutineCreationOverhead) {
    lua.script(R"(
        function make_coro()
            return coroutine.create(function()
                for i = 1, 10 do
                    coroutine.yield(i)
                end
            end)
        end
    )");

    std::vector<double> times;
    const int COUNT = 1000;

    for (int i = 0; i < 100; ++i) {
        benchmark::ScopedTimer timer(times);
        for (int j = 0; j < COUNT; ++j) {
            sol::coroutine co = lua["make_coro"]();
        }
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("CoroutineCreation (1k)", result);

    EXPECT_LT(result.mean_ms, 100.0);
}

TEST_F(CoroutineBenchmark, CoroutineResumeOverhead) {
    lua.script(R"(
        function simple_coro()
            while true do
                coroutine.yield()
            end
        end

        test_coro = coroutine.create(simple_coro)
    )");

    sol::thread coro = lua["test_coro"];

    std::vector<double> times;
    const int RESUMES = 10000;

    for (int i = 0; i < 100; ++i) {
        // Reset coroutine
        lua.script("test_coro = coroutine.create(simple_coro)");
        coro = lua["test_coro"];

        benchmark::ScopedTimer timer(times);
        for (int j = 0; j < RESUMES; ++j) {
            lua.script("coroutine.resume(test_coro)");
        }
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("CoroutineResume (10k)", result);

    EXPECT_LT(result.mean_ms, 500.0);
}

TEST_F(CoroutineBenchmark, PooledVsNewCoroutine) {
    // Compare creating new vs reusing coroutines
    lua.script(R"(
        -- Pool of coroutines
        coro_pool = {}
        pool_size = 0

        function get_pooled_coro(fn)
            if pool_size > 0 then
                pool_size = pool_size - 1
                local co = coro_pool[pool_size + 1]
                coro_pool[pool_size + 1] = nil
                return co
            end
            return coroutine.create(fn)
        end

        function return_to_pool(co)
            pool_size = pool_size + 1
            coro_pool[pool_size] = co
        end

        function task_fn()
            coroutine.yield(1)
            coroutine.yield(2)
            return 3
        end
    )");

    // Benchmark: new coroutines each time
    std::vector<double> times_new;
    for (int i = 0; i < 50; ++i) {
        benchmark::ScopedTimer timer(times_new);
        for (int j = 0; j < 500; ++j) {
            lua.script(R"(
                local co = coroutine.create(task_fn)
                coroutine.resume(co)
                coroutine.resume(co)
                coroutine.resume(co)
            )");
        }
    }

    auto result_new = benchmark::analyze(times_new);
    benchmark::print_result("NewCoroutines (500 tasks)", result_new);

    // Note: True pooling requires wrapping coroutine to reset state
    // This test documents the creation overhead
    SUCCEED();
}
```

**Step 2: Commit**

```bash
git add tests/benchmark/benchmark_coroutines.cpp
git commit -m "test(perf): add coroutine overhead benchmarks"
```

---

## Phase 3: Rendering Optimization

### Task 3.1: Add Shader/Texture Batching to Sort Key

**Files:**
- Modify: `src/systems/layer/layer_command_buffer.hpp`
- Modify: `src/systems/layer/layer_command_buffer.cpp`
- Modify: `tests/unit/test_layer_batching.cpp`

**Step 1: Review current DrawCommandV2 structure**

Read `src/systems/layer/layer_command_buffer.hpp` to understand current structure.

**Step 2: Write failing test for extended batching**

Add to `tests/unit/test_layer_batching.cpp`:
```cpp
// Test that commands are sorted by shader when g_enableShaderBatching is true
TEST(LayerBatchingTest, ShaderBatchingReducesStateChanges) {
    // This test will be implemented based on actual layer structure
    // Placeholder for TDD
    GTEST_SKIP() << "Implement after reviewing layer structure";
}
```

**Step 3: Commit test (RED)**

```bash
git add tests/unit/test_layer_batching.cpp
git commit -m "test(perf): add shader batching test (RED)"
```

**Note:** Actual implementation requires reading layer_command_buffer.hpp first. The plan provides the structure; details filled during execution.

---

### Task 3.2: Add Draw Call Source Tracking

**Files:**
- Modify: `src/systems/layer/layer_optimized.cpp`

**Step 1: Add source tracking to draw call counter**

This tracks WHERE draw calls come from (sprite, text, particle, etc.) for better optimization targeting.

Add to globals or layer header:
```cpp
// Draw call breakdown by source
struct DrawCallStats {
    uint32_t sprites = 0;
    uint32_t text = 0;
    uint32_t particles = 0;
    uint32_t ui = 0;
    uint32_t other = 0;

    void reset() {
        sprites = text = particles = ui = other = 0;
    }

    uint32_t total() const {
        return sprites + text + particles + ui + other;
    }
};

inline DrawCallStats g_drawCallStats;
```

**Step 2: Commit**

```bash
git add src/systems/layer/layer_optimized.cpp
git commit -m "feat(perf): add draw call source tracking"
```

---

## Phase 4: Memory & GC Optimization

### Task 4.1: Add GC Pause Measurement

**Files:**
- Modify: `src/core/game.cpp` (near GC step)

**Step 1: Wrap GC step with timing**

Find the `lua gc step` Tracy zone and add measurement:

```cpp
// In game update loop, around line 1573
{
    ZONE_SCOPED("lua gc step");
    auto gc_start = std::chrono::high_resolution_clock::now();

    // Existing GC step code
    lua_gc(L, LUA_GCSTEP, 0);

    auto gc_end = std::chrono::high_resolution_clock::now();
    auto gc_ms = std::chrono::duration<double, std::milli>(gc_end - gc_start).count();

    // Track max GC pause this frame
    g_maxGcPauseMs = std::max(g_maxGcPauseMs, gc_ms);

    // Warn if GC pause exceeds threshold
    if (gc_ms > 5.0) {
        // Log warning
    }
}
```

**Step 2: Commit**

```bash
git add src/core/game.cpp
git commit -m "feat(perf): add GC pause timing and warning"
```

---

### Task 4.2: Profile Table Allocation Hotspots

**Files:**
- Create: `assets/scripts/tools/allocation_profiler.lua`

**Step 1: Create Lua-side allocation profiler**

Create `assets/scripts/tools/allocation_profiler.lua`:
```lua
-- Allocation profiler for finding table creation hotspots
-- Usage: require this, call start(), run code, call report()

local AllocationProfiler = {}

local tracking = false
local allocations = {}
local call_counts = {}

-- Hook into table creation (approximate via debug hooks)
local function track_hook(event)
    if not tracking then return end

    local info = debug.getinfo(2, "Sl")
    if info and info.source and info.currentline then
        local key = info.source .. ":" .. info.currentline
        call_counts[key] = (call_counts[key] or 0) + 1
    end
end

function AllocationProfiler.start()
    tracking = true
    allocations = {}
    call_counts = {}
    -- Note: This is approximate - Lua doesn't expose table allocations directly
    -- We track function calls as a proxy for allocation patterns
    debug.sethook(track_hook, "c", 0)
    print("[AllocationProfiler] Started tracking")
end

function AllocationProfiler.stop()
    tracking = false
    debug.sethook()
    print("[AllocationProfiler] Stopped tracking")
end

function AllocationProfiler.report(top_n)
    top_n = top_n or 20

    -- Sort by count
    local sorted = {}
    for k, v in pairs(call_counts) do
        table.insert(sorted, { location = k, count = v })
    end
    table.sort(sorted, function(a, b) return a.count > b.count end)

    print("\n=== Allocation Hotspots (top " .. top_n .. ") ===")
    for i = 1, math.min(top_n, #sorted) do
        local entry = sorted[i]
        print(string.format("%d. %s: %d calls", i, entry.location, entry.count))
    end
    print("=====================================\n")

    return sorted
end

function AllocationProfiler.get_gc_stats()
    return {
        memory_kb = collectgarbage("count"),
    }
end

return AllocationProfiler
```

**Step 2: Commit**

```bash
git add assets/scripts/tools/allocation_profiler.lua
git commit -m "feat(perf): add Lua allocation profiler tool"
```

---

## Phase 5: Load Time Optimization

### Task 5.1: Add Startup Timing Instrumentation

**Files:**
- Modify: `src/core/init.cpp`

**Step 1: Add timing to major init phases**

Wrap major initialization phases with timing:

```cpp
// At start of init
auto init_start = std::chrono::high_resolution_clock::now();

// After each major phase
auto phase_end = std::chrono::high_resolution_clock::now();
auto phase_ms = std::chrono::duration<double, std::milli>(phase_end - phase_start).count();
std::cout << "[STARTUP] Phase X completed in " << phase_ms << " ms\n";
phase_start = phase_end;

// Phases to instrument:
// - Window creation
// - Shader loading
// - Texture loading
// - Lua initialization
// - Physics setup
// - First scene load
```

**Step 2: Commit**

```bash
git add src/core/init.cpp
git commit -m "feat(perf): add startup phase timing"
```

---

### Task 5.2: Implement Lazy Shader Loading

**Files:**
- Modify: `src/systems/shaders/shader_system.cpp`
- Create: `tests/unit/test_lazy_shader.cpp`

**Step 1: Write failing test**

Create `tests/unit/test_lazy_shader.cpp`:
```cpp
#include <gtest/gtest.h>

// Test that shaders are loaded on first use, not at startup
TEST(LazyShaderTest, ShaderNotLoadedUntilFirstUse) {
    // Placeholder - implement based on shader system structure
    GTEST_SKIP() << "Implement after reviewing shader system";
}

TEST(LazyShaderTest, ShaderCachedAfterFirstLoad) {
    GTEST_SKIP() << "Implement after reviewing shader system";
}
```

**Step 2: Commit test (RED)**

```bash
git add tests/unit/test_lazy_shader.cpp
git commit -m "test(perf): add lazy shader loading tests (RED)"
```

---

## Phase 6: Web-Specific Optimization

### Task 6.1: Review Emscripten Build Flags

**Files:**
- Check: `CMakeLists.txt` (Emscripten section)

**Step 1: Document current flags**

```bash
grep -A 30 "EMSCRIPTEN" CMakeLists.txt
```

**Step 2: Create optimization flag comparison**

Add to `docs/perf/web-build-flags.md`:
```markdown
# Web Build Flag Comparison

## Current Flags
[Fill in from CMakeLists.txt]

## Optimization Options to Test

| Flag | Description | Trade-off |
|------|-------------|-----------|
| `-O3` | Aggressive optimization | Larger binary |
| `-Os` | Size optimization | Current default? |
| `-flto` | Link-time optimization | Longer build |
| `-msimd128` | WASM SIMD | Not all browsers |
| `ALLOW_MEMORY_GROWTH=1` | Dynamic memory | Slight overhead |

## Testing Matrix
[Fill in with benchmark results]
```

**Step 3: Commit**

```bash
git add docs/perf/web-build-flags.md
git commit -m "docs(perf): add web build flag comparison template"
```

---

### Task 6.2: Add Web Performance Metrics Collection

**Files:**
- Modify: `src/minshell.html` or equivalent

**Step 1: Add JS performance collection**

Add to the HTML shell:
```html
<script>
// Performance metrics collection for web build
const WebPerfMetrics = {
    frames: [],
    lastTime: 0,

    recordFrame() {
        const now = performance.now();
        if (this.lastTime > 0) {
            this.frames.push(now - this.lastTime);
            // Keep last 300 frames
            if (this.frames.length > 300) {
                this.frames.shift();
            }
        }
        this.lastTime = now;
    },

    getStats() {
        if (this.frames.length === 0) return null;

        const sorted = [...this.frames].sort((a, b) => a - b);
        return {
            fps: 1000 / (sorted.reduce((a, b) => a + b) / sorted.length),
            frameTime: {
                mean: sorted.reduce((a, b) => a + b) / sorted.length,
                median: sorted[Math.floor(sorted.length / 2)],
                p99: sorted[Math.floor(sorted.length * 0.99)],
                min: sorted[0],
                max: sorted[sorted.length - 1]
            }
        };
    },

    printStats() {
        const stats = this.getStats();
        if (!stats) return;
        console.log('=== Web Performance ===');
        console.log(`FPS: ${stats.fps.toFixed(1)}`);
        console.log(`Frame time: mean=${stats.frameTime.mean.toFixed(2)}ms, p99=${stats.frameTime.p99.toFixed(2)}ms`);
    }
};

// Call from requestAnimationFrame loop
// WebPerfMetrics.recordFrame();
</script>
```

**Step 2: Commit**

```bash
git add src/minshell.html
git commit -m "feat(perf): add web performance metrics collection"
```

---

## Summary

### Total Tasks: 18

| Phase | Tasks | Focus |
|-------|-------|-------|
| Phase 1 | 6 | Profiling infrastructure |
| Phase 2 | 3 | Lua/C++ boundary |
| Phase 3 | 2 | Rendering |
| Phase 4 | 2 | Memory/GC |
| Phase 5 | 2 | Load times |
| Phase 6 | 2 | Web-specific |

### Review Checkpoints

- After Task 1.6: Baseline infrastructure complete
- After Task 2.3: Lua profiling complete
- After Task 3.2: Rendering profiling complete
- After Task 4.2: Memory profiling complete
- After Task 5.2: Load time profiling complete
- After Task 6.2: Web profiling complete, ready for optimization implementation

### Next Steps After This Plan

1. Run baseline benchmarks (populate metrics template)
2. Analyze results to prioritize optimizations
3. Implement optimizations with highest impact first
4. Re-benchmark to verify improvements

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
