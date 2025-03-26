#pragma once

#include <vector>
#include <cmath>
#include <ctime>
#include <chrono>
#include <random>
#include <algorithm>
#include <effolkronium/random.hpp>
#include <thread>

namespace random_utils {
    using RandomEngine = effolkronium::random_static;

    /** Sets the seed for deterministic random number generation. */
    inline void set_seed(unsigned int seed) {
        RandomEngine::seed(seed);
    }

    /** Generates a random boolean based on a given probability percentage (0-100). */
    inline bool random_bool(double chance) {
        return RandomEngine::get(1, 1000) < 10 * chance;
    }

    /** Returns a random floating-point number between `min` and `max` (inclusive). */
    inline double random_float(double min = 0.0, double max = 1.0) {
        return RandomEngine::get(min, max);
    }

    /** Returns a random integer between `min` and `max` (inclusive). */
    inline int random_int(int min = 0, int max = 1) {
        return RandomEngine::get(min, max);
    }

    /** Returns a normally distributed random number around a mean with given standard deviation. */
    inline double random_normal(double mean, double stddev) {
        return RandomEngine::get<std::normal_distribution<>>(mean, stddev);
    }

    /** Selects a random element from a vector. */
    template <typename T>
    inline T random_element(const std::vector<T>& container) {
        if (container.empty()) throw std::runtime_error("random_element: Empty container");
        return container[RandomEngine::get(0, static_cast<int>(container.size()) - 1)];
    }

    /** Selects and removes a random element from a vector. */
    template <typename T>
    inline T random_element_remove(std::vector<T>& container) {
        if (container.empty()) throw std::runtime_error("random_element_remove: Empty container");
        size_t index = RandomEngine::get(0, container.size() - 1);
        T value = container[index];
        container.erase(container.begin() + index);
        return value;
    }

    /** Returns either `1` or `-1` based on the given chance percentage. */
    inline int random_sign(double chance) {
        return random_bool(chance) ? 1 : -1;
    }

    /** Returns an index based on provided weighted probabilities. */
    inline int random_weighted_pick(const std::vector<double>& weights) {
        double total_weight = 0;
        for (double weight : weights) total_weight += weight;

        double rnd = random_float(0, total_weight);
        for (size_t i = 0; i < weights.size(); ++i) {
            if (rnd < weights[i]) return static_cast<int>(i) + 1;
            rnd -= weights[i];
        }
        return static_cast<int>(weights.size());
    }

    /** Returns a weighted value from a vector of {value, weight} pairs. */
    template <typename T>
    inline T random_weighted_pick(const std::vector<std::pair<T, double>>& items) {
        double total_weight = 0;
        for (const auto& item : items) total_weight += item.second;

        double rnd = random_float(0, total_weight);
        for (const auto& item : items) {
            if (rnd < item.second) return item.first;
            rnd -= item.second;
        }
        return items.back().first;
    }

    /** Returns a unique identifier (incrementing integer). */
    inline int random_uid() {
        static int id_counter = 0;
        return ++id_counter;
    }

    /** Returns a random angle between `0` and `2π`. */
    inline double random_angle() {
        return random_float(0, 2 * PI);
    }

    /** Returns a random 2D unit vector. */
    struct Vec2 { double x, y; };
    struct Vec3 { double x, y, z; };

    inline Vec2 random_unit_vector_2D() {
        double angle = random_angle();
        return {std::cos(angle), std::sin(angle)};
    }

    /** Returns a random 3D unit vector. */
    inline Vec3 random_unit_vector_3D() {
        double theta = random_angle();
        double phi = random_float(0, PI);
        return {std::sin(phi) * std::cos(theta), std::sin(phi) * std::sin(theta), std::cos(phi)};
    }

    /** Returns a random delay between `min_ms` and `max_ms` milliseconds. */
    inline std::chrono::milliseconds random_delay(int min_ms, int max_ms) {
        return std::chrono::milliseconds(random_int(min_ms, max_ms));
    }

    /** Returns a random RGB color. */
    struct Color { int r, g, b; };

    inline Color random_color() {
        return {random_int(0, 255), random_int(0, 255), random_int(0, 255)};
    }

    /** Returns a biased random number, favoring low or high values based on `bias_factor`. */
    inline double random_biased(double bias_factor) {
        double rnd = random_float();
        return std::pow(rnd, bias_factor);
    }

    /**
     * Generates a biased random number between 0 and 1.
     *
     * **How It Works:**
     * - A standard random number (`rnd`) is generated between 0 and 1.
     * - The result is transformed using `std::pow(rnd, bias_factor)`.
     * - **If `bias_factor > 1`**, lower values (closer to 0) are more frequent.
     * - **If `bias_factor < 1`**, higher values (closer to 1) are more frequent.
     * - **If `bias_factor == 1`**, the distribution remains uniform.
     *
     * **Examples:**
     * ```cpp
     * double v1 = Random::random_biased(2.0); // Favors low values
     * double v2 = Random::random_biased(0.5); // Favors high values
     * ```
     *
     * **Use Cases:**
     * - Favoring rare drops in loot tables.
     * - Random enemy spawn difficulty (favoring easier/harder spawns).
     * - Generating smooth difficulty progression.
     */
}