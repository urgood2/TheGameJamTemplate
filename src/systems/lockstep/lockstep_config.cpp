#include "systems/lockstep/lockstep_config.hpp"

#include "systems/lockstep/deterministic_rng.hpp"

namespace lockstep {

LockstepConfig g_lockstepConfig{};

void initLockstep(const LockstepConfig& config) {
    g_lockstepConfig = config;

    if (useDeterministicRng()) {
        g_deterministicRng.seed(g_lockstepConfig.base_seed);
    }
}

bool isLockstepEnabled() {
    return g_lockstepConfig.enabled;
}

bool useDeterministicRng() {
    return g_lockstepConfig.enabled && g_lockstepConfig.deterministic_rng;
}

} // namespace lockstep
