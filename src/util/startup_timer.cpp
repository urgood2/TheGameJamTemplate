#include "startup_timer.hpp"

#include <spdlog/spdlog.h>
#include <map>
#include <algorithm>
#include <mutex>

namespace startup_timer {

namespace {
    // Storage for timing data
    std::vector<PhaseRecord> g_phases;
    std::map<std::string, std::chrono::high_resolution_clock::time_point> g_active_phases;
    std::mutex g_mutex;  // Protects g_phases and g_active_phases
}

void begin_phase(const std::string& name) {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_active_phases[name] = std::chrono::high_resolution_clock::now();
}

void end_phase(const std::string& name) {
    std::lock_guard<std::mutex> lock(g_mutex);
    auto it = g_active_phases.find(name);
    if (it == g_active_phases.end()) {
        // Phase not found - handle gracefully by doing nothing
        return;
    }

    auto end_time = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration<double, std::milli>(end_time - it->second);

    PhaseRecord record;
    record.name = name;
    record.start_time = it->second;
    record.end_time = end_time;
    record.duration_ms = duration.count();

    g_phases.push_back(record);
    g_active_phases.erase(it);
}

const std::vector<PhaseRecord>& get_phases() {
    std::lock_guard<std::mutex> lock(g_mutex);
    return g_phases;
}

double get_total_duration() {
    std::lock_guard<std::mutex> lock(g_mutex);
    double total = 0.0;
    for (const auto& phase : g_phases) {
        total += phase.duration_ms;
    }
    return total;
}

void reset() {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_phases.clear();
    g_active_phases.clear();
}

void print_summary() {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (g_phases.empty()) {
        SPDLOG_INFO("=== Startup Timer: No phases recorded ===");
        return;
    }

    SPDLOG_INFO("=== Startup Timer Summary ===");
    double total = 0.0;
    for (const auto& phase : g_phases) {
        SPDLOG_INFO("  {}: {:.2f} ms", phase.name, phase.duration_ms);
        total += phase.duration_ms;
    }
    SPDLOG_INFO("  Total: {:.2f} ms", total);
    SPDLOG_INFO("=============================");
}

// Scoped helper implementation
ScopedPhase::ScopedPhase(const std::string& name) : name_(name) {
    begin_phase(name_);
}

ScopedPhase::~ScopedPhase() {
    end_phase(name_);
}

} // namespace startup_timer
