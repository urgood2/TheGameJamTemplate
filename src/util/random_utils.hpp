#ifndef RANDOM_UTILS_HPP
#define RANDOM_UTILS_HPP

#include "effolkronium/random.hpp"
#include <vector>
#include <string>
#include <cmath>
#include <algorithm>

using Random = effolkronium::random_static; // get base random alias which is auto seeded and has static API and internal state - shared with other files who use this alias

namespace random_utils {
    void Init(unsigned int seed = static_cast<unsigned int>(time(nullptr)));

    // Basic functions
    bool RandomBool(float chance);
    float RandomFloat(float min = 0.0f, float max = 1.0f);
    int RandomInt(int min = 0, int max = 1);
    float RandomNormal(float mean, float stddev);
    int RandomSign(float chance);
    int RandomUID();

    // Table functions
    template <typename T>
    T RandomTable(const std::vector<T>& table);

    template <typename T>
    T RandomTableRemove(std::vector<T>& table);

    // Weighted random
    template <typename T>
    int RandomWeightedPick(const std::vector<T>& weights);

    // Angles
    float RandomAngle();
}

#endif // RANDOM_UTILS_HPP
