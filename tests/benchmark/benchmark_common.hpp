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
