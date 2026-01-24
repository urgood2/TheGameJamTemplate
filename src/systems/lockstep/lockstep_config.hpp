#pragma once

#include <cstdint>

namespace lockstep {

struct LockstepConfig {
    bool enabled = false;                    // Master toggle (set at startup)
    bool deterministic_rng = false;          // Use deterministic RNG
    bool deterministic_timers = false;       // Use tick-based timing
    bool deterministic_time = false;         // Override GetTime/GetFrameTime/os.clock
    bool deterministic_ids = false;          // Deterministic tag/ID generation
    bool input_recording = false;            // Record inputs for replay
    bool checksum_validation = false;        // Generate state checksums
    bool rollback_enabled = false;           // Enable state snapshots/rollback
    uint32_t base_seed = 0;                  // Session seed
    uint32_t tick_rate = 60;                 // Fixed ticks per second
    uint32_t checksum_interval = 60;         // Ticks between checksums
};

extern LockstepConfig g_lockstepConfig;

void initLockstep(const LockstepConfig& config);
bool isLockstepEnabled();
bool useDeterministicRng();

} // namespace lockstep
