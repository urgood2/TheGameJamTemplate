#pragma once

// Startup timing instrumentation for measuring initialization phases
// Works on both native (with Tracy) and web (without Tracy)
// Low overhead - designed to be left enabled in debug builds

#include <string>
#include <vector>
#include <chrono>

namespace startup_timer {

// Phase timing record
struct PhaseRecord {
    std::string name;
    double duration_ms;
    std::chrono::high_resolution_clock::time_point start_time;
    std::chrono::high_resolution_clock::time_point end_time;
};

// Begin timing a phase
void begin_phase(const std::string& name);

// End timing a phase
void end_phase(const std::string& name);

// Get all recorded phases
const std::vector<PhaseRecord>& get_phases();

// Get total duration of all phases
double get_total_duration();

// Reset all timing data
void reset();

// Print summary to console
void print_summary();

// RAII helper for scoped timing
class ScopedPhase {
public:
    explicit ScopedPhase(const std::string& name);
    ~ScopedPhase();

    ScopedPhase(const ScopedPhase&) = delete;
    ScopedPhase& operator=(const ScopedPhase&) = delete;

private:
    std::string name_;
};

} // namespace startup_timer
