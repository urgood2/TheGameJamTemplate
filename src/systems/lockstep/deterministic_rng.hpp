#pragma once

#include <cstdint>

namespace lockstep {

class DeterministicRng {
public:
    struct State {
        uint64_t state = 0;
        uint64_t inc = 0;
        bool has_cached_normal = false;
        double cached_normal = 0.0;
    };

    void seed(uint64_t seed, uint64_t stream = 0xda3e39cb94b95bdbULL);

    uint32_t nextU32();
    uint32_t uniform(uint32_t min, uint32_t max);
    int uniformInt(int min, int max);
    double uniformDouble01();
    double uniformDouble(double min, double max);
    float uniformFloat01();
    bool randomBool(double chance);
    double normal(double mean, double stddev);

    uint64_t getStateHash() const;
    State get_state() const;
    void set_state(const State& state);

private:
    uint64_t state_ = 0;
    uint64_t inc_ = 0;
    bool has_cached_normal_ = false;
    double cached_normal_ = 0.0;
};

extern DeterministicRng g_deterministicRng;

} // namespace lockstep
