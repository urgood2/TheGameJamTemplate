#pragma once
#include <vector>
#include <unordered_map>
#include <cstdint>
#include "spring.hpp"

namespace spring {

//------------------------------------------------------------
// SIMD-friendly Structure of Arrays storage
//------------------------------------------------------------
struct SpringPool {
    std::vector<float> value;
    std::vector<float> target;
    std::vector<float> velocity;
    std::vector<float> stiffness;
    std::vector<float> damping;
    std::vector<uint8_t> enabled;
    std::unordered_map<entt::entity, size_t> entityToIndex;

    inline void reserve(size_t n) {
        value.reserve(n); target.reserve(n); velocity.reserve(n);
        stiffness.reserve(n); damping.reserve(n); enabled.reserve(n);
    }

    inline size_t add(entt::entity e, const Spring &s) {
        size_t idx = value.size();
        value.push_back(s.value);
        target.push_back(s.targetValue);
        velocity.push_back(s.velocity);
        stiffness.push_back(s.stiffness);
        damping.push_back(s.damping);
        enabled.push_back(s.enabled ? 1 : 0);
        entityToIndex[e] = idx;
        return idx;
    }

    inline size_t getIndex(entt::entity e) const {
        auto it = entityToIndex.find(e);
        return (it == entityToIndex.end()) ? SIZE_MAX : it->second;
    }

    inline void setEnabled(entt::entity e, bool en) {
        size_t i = getIndex(e);
        if (i != SIZE_MAX) enabled[i] = en;
    }

    inline void syncFromSpring(entt::entity e, const Spring &s) {
        size_t i = getIndex(e);
        if (i == SIZE_MAX) return;
        value[i] = s.value;
        target[i] = s.targetValue;
        velocity[i] = s.velocity;
        stiffness[i] = s.stiffness;
        damping[i] = s.damping;
        enabled[i] = s.enabled ? 1 : 0;
    }

    inline void syncToSpring(entt::entity e, Spring &s) const {
        size_t i = getIndex(e);
        if (i == SIZE_MAX) return;
        s.value = value[i];
        s.targetValue = target[i];
        s.velocity = velocity[i];
        s.stiffness = stiffness[i];
        s.damping = damping[i];
        s.enabled = enabled[i] != 0;
    }

    void clear() {
        value.clear(); target.clear(); velocity.clear();
        stiffness.clear(); damping.clear(); enabled.clear();
        entityToIndex.clear();
    }
};

// Global instance
extern SpringPool gPool;

} // namespace spring
