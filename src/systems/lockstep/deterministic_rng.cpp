#include "systems/lockstep/deterministic_rng.hpp"

#include <algorithm>
#include <bit>
#include <cmath>
#include <limits>

namespace lockstep {
namespace {
constexpr double kTwoPi = 6.283185307179586476925286766559;
constexpr double kDoubleUnit = 1.0 / 9007199254740992.0; // 2^53
constexpr float kFloatUnit = 1.0f / 16777216.0f;         // 2^24
} // namespace

DeterministicRng g_deterministicRng{};

void DeterministicRng::seed(uint64_t seed, uint64_t stream) {
    state_ = 0;
    inc_ = (stream << 1u) | 1u;
    nextU32();
    state_ += seed;
    nextU32();
    has_cached_normal_ = false;
}

uint32_t DeterministicRng::nextU32() {
    uint64_t oldstate = state_;
    state_ = oldstate * 6364136223846793005ULL + inc_;
    uint32_t xorshifted = static_cast<uint32_t>(((oldstate >> 18u) ^ oldstate) >> 27u);
    uint32_t rot = static_cast<uint32_t>(oldstate >> 59u);
    return (xorshifted >> rot) | (xorshifted << ((-rot) & 31));
}

uint32_t DeterministicRng::uniform(uint32_t min, uint32_t max) {
    if (min > max) {
        std::swap(min, max);
    }
    uint32_t range = max - min + 1u;
    if (range == 0u) {
        return nextU32();
    }
    uint32_t threshold = static_cast<uint32_t>(-range) % range;
    while (true) {
        uint32_t r = nextU32();
        if (r >= threshold) {
            return min + (r % range);
        }
    }
}

int DeterministicRng::uniformInt(int min, int max) {
    if (min > max) {
        std::swap(min, max);
    }
    if (min == max) {
        return min;
    }
    int64_t range = static_cast<int64_t>(max) - static_cast<int64_t>(min) + 1;
    if (range <= 0 || range > static_cast<int64_t>(std::numeric_limits<uint32_t>::max())) {
        return min;
    }
    uint32_t r = uniform(0u, static_cast<uint32_t>(range - 1));
    return static_cast<int>(static_cast<int64_t>(min) + r);
}

double DeterministicRng::uniformDouble01() {
    uint64_t high = static_cast<uint64_t>(nextU32());
    uint64_t low = static_cast<uint64_t>(nextU32());
    uint64_t combined = (high << 32) | low;
    uint64_t value = combined >> 11;
    return static_cast<double>(value) * kDoubleUnit;
}

double DeterministicRng::uniformDouble(double min, double max) {
    if (min > max) {
        std::swap(min, max);
    }
    return min + (max - min) * uniformDouble01();
}

float DeterministicRng::uniformFloat01() {
    uint32_t r = nextU32();
    return static_cast<float>(r >> 8) * kFloatUnit;
}

bool DeterministicRng::randomBool(double chance) {
    double threshold = chance * 10.0;
    if (threshold <= 0.0) {
        return false;
    }
    if (threshold >= 1000.0) {
        return true;
    }
    uint32_t r = uniform(1u, 1000u);
    return static_cast<double>(r) < threshold;
}

double DeterministicRng::normal(double mean, double stddev) {
    if (has_cached_normal_) {
        has_cached_normal_ = false;
        return mean + stddev * cached_normal_;
    }

    double u1 = uniformDouble01();
    double u2 = uniformDouble01();
    if (u1 <= 0.0) {
        u1 = std::numeric_limits<double>::min();
    }

    double mag = std::sqrt(-2.0 * std::log(u1));
    double z0 = mag * std::cos(kTwoPi * u2);
    double z1 = mag * std::sin(kTwoPi * u2);

    cached_normal_ = z1;
    has_cached_normal_ = true;
    return mean + stddev * z0;
}

uint64_t DeterministicRng::getStateHash() const {
    uint64_t hash = state_ ^ (inc_ << 1u);
    if (has_cached_normal_) {
        hash ^= std::bit_cast<uint64_t>(cached_normal_);
    }
    return hash;
}

} // namespace lockstep
