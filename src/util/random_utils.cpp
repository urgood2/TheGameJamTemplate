#include "random_utils.hpp"

#include <unordered_map>

namespace random_utils {
    static int uid = 0; // Static variable for generating unique incremental IDs.

    /**
     * @brief Initialize the random number generator with a given seed.
     * 
     * @param seed The seed for the random number generator. Defaults to the current system time.
     * 
     * @note If a fixed seed is provided, the random sequence will be deterministic (useful for debugging or testing).
     */
    void Init(unsigned int seed) {
        Random::seed(seed);
    }

    /**
     * @brief Returns a boolean value with a specified chance of being true.
     * 
     * @param chance The chance (0 to 100) that the result will be true.
     * @return true if the random chance succeeds; otherwise, false.
     * 
     * @example 
     * RandomBool(50) -> true 50% of the time.
     * RandomBool(25) -> true 25% of the time.
     */
    bool RandomBool(float chance) {
        return Random::get<bool>(chance / 100.0f);
    }

    /**
     * @brief Generates a random floating-point number within the specified range.
     * 
     * @param min The lower bound of the range (inclusive).
     * @param max The upper bound of the range (inclusive).
     * @return A random float between min and max.
     * 
     * @example 
     * RandomFloat(0.0f, 1.0f) -> 0.2345.
     * RandomFloat(-10.0f, 10.0f) -> -3.47.
     */
    float RandomFloat(float min, float max) {
        return Random::get<float>(min, max);
    }

    /**
     * @brief Generates a random integer within the specified range.
     * 
     * @param min The lower bound of the range (inclusive).
     * @param max The upper bound of the range (inclusive).
     * @return A random integer between min and max.
     * 
     * @example 
     * RandomInt(1, 6) -> 4.
     * RandomInt(-5, 0) -> -2.
     */
    int RandomInt(int min, int max) {
        return Random::get<int>(min, max);
    }

    /**
     * @brief Generates a random number using a normal distribution.
     * 
     * @param mean The mean (center) of the distribution.
     * @param stddev The standard deviation (spread) of the distribution.
     * @return A normally distributed random number.
     * 
     * @example 
     * RandomNormal(0.0f, 1.0f) -> -0.34.
     * RandomNormal(100.0f, 15.0f) -> 105.3.
     */
    float RandomNormal(float mean, float stddev) {
        return Random::get<std::normal_distribution<>>(mean, stddev);
    }

    /**
     * @brief Returns either 1 or -1 with a specified chance for 1.
     * 
     * @param chance The chance (0 to 100) that the result will be 1.
     * @return 1 if the chance succeeds; otherwise, -1.
     * 
     * @example 
     * RandomSign(75) -> Returns 1 75% of the time, and -1 25% of the time.
     */
    int RandomSign(float chance) {
        return RandomBool(chance) ? 1 : -1;
    }

    /**
     * @brief Generates a unique incremental ID.
     * 
     * @return A unique integer ID starting from 1.
     * 
     * @note This is useful for assigning unique identifiers to objects or events.
     */
    int RandomUID() {
        return ++uid;
    }

    #ifndef PI
    #define PI 3.1415926545
    #endif

    /**
     * @brief Generates a random angle in radians.
     * 
     * @return A random float between 0 and 2*PI.
     * 
     * @note This can be used for rotational values or directional vectors.
     */
    float RandomAngle() {
        return RandomFloat(0.0f, 2.0f * static_cast<float>(PI));
    }

    /**
     * @brief Selects a random element from a given vector.
     * 
     * @tparam T The type of the elements in the vector.
     * @param table A vector containing the elements to choose from.
     * @return A random element from the vector.
     * 
     * @example 
     * std::vector<int> values = {1, 2, 3, 4};
     * RandomTable(values) -> 3.
     */
    template <typename T>
    T RandomTable(const std::vector<T>& table) {
        return Random::get(table);
    }

    /**
     * @brief Removes and returns a random element from a vector.
     * 
     * @tparam T The type of the elements in the vector.
     * @param table A vector containing the elements.
     * @return The randomly selected element that was removed.
     * 
     * @note This modifies the vector by removing the selected element.
     * 
     * @example 
     * std::vector<int> values = {10, 20, 30, 40};
     * RandomTableRemove(values) -> 20 (and removes it from the vector).
     */
    template <typename T>
    T RandomTableRemove(std::vector<T>& table) {
        auto it = Random::get(table.begin(), table.end());
        T value = *it;
        table.erase(it);
        return value;
    }

    /**
     * @brief Selects an index based on weighted probabilities.
     * 
     * @tparam T The type of weights (e.g., float, double).
     * @param weights A vector where each element represents the weight of the corresponding index.
     * @return The 1-based index of the selected weight.
     * 
     * @example 
     * std::vector<float> weights = {50.0f, 30.0f, 20.0f};
     * RandomWeightedPick(weights) -> Returns 1 (50%), 2 (30%), or 3 (20%).
     */
    template <typename T>
    int RandomWeightedPick(const std::vector<T>& weights) {
        std::unordered_map<int, T> weight_map;
        for (size_t i = 0; i < weights.size(); ++i) {
            weight_map[i + 1] = weights[i];
        }
        return Random::get<Random::weight>(weight_map);
    }
}
