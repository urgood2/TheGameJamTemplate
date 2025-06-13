#pragma once

#include <vector>
#include <cmath>
#include <ctime>
#include <chrono>
#include <random>
#include <algorithm>
#include <effolkronium/random.hpp>
#include <thread>

#include "systems/scripting/binding_recorder.hpp"

#include <raylib.h>

#include "sol/sol.hpp"
#include "entt/fwd.hpp"

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
        int max_index = static_cast<int>(container.size()) - 1;
        int idx       = RandomEngine::get(0, max_index);
        // now idx is an int in [0..max_index], safe to use
        return container[static_cast<size_t>(idx)];
    }

    /** Selects and removes a random element from a vector. */
    template <typename T>
    inline T random_element_remove(std::vector<T>& container) {
        if (container.empty()) throw std::runtime_error("random_element_remove: Empty container");
        // cast container.size()-1 to int so both args to get() are int
        int max_index = static_cast<int>(container.size()) - 1;
        int idx       = RandomEngine::get(0, max_index);
        size_t index  = static_cast<size_t>(idx);
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
    inline Vector2 random_unit_vector_2D() {
        float a = float(random_angle());
        return { cosf(a), sinf(a) };
    }
    inline Vector3 random_unit_vector_3D() {
        float theta = float(random_angle());
        float phi   = float(random_float(0, PI));
        return {
            sinf(phi)*cosf(theta),
            sinf(phi)*sinf(theta),
            cosf(phi)
        };
    }

    /** Returns a random delay between `min_ms` and `max_ms` milliseconds. */
    inline std::chrono::milliseconds random_delay(int min_ms, int max_ms) {
        return std::chrono::milliseconds(random_int(min_ms, max_ms));
    }

    /** Returns a random RGB color. */

    inline Color random_color() {
        return Color{
            (unsigned char)random_int(0,255),
            (unsigned char)random_int(0,255),
            (unsigned char)random_int(0,255),
            255
        };
    }

    /** Returns a biased random number, favoring low or high values based on `bias_factor`. */
    inline double random_biased(double bias_factor) {
        double rnd = random_float();
        return std::pow(rnd, bias_factor);
    }

    
    inline void exposeToLua(sol::state &lua) {
        // 1) Create (or fetch) the random_utils table
        // sol::table ru = lua.get_or("random_utils", lua.create_table());
        sol::state_view luaView{lua};
        auto ru = luaView["random_utils"].get_or_create<sol::table>();
        if (!ru.valid()) {
            ru = lua.create_table();
            lua["random_utils"] = ru;
        }

        // 2) Vec2
        ru.new_usertype<Vector2>("Vector2",
            sol::constructors<Vector2(), Vector2(float, float)>(),
            "x", &Vector2::x,
            "y", &Vector2::y
        );

        // 3) Vec3
        ru.new_usertype<Vector3>("Vector3",
            sol::constructors<Vector3(), Vector3(float, float, float)>(),
            "x", &Vector3::x,
            "y", &Vector3::y,
            "z", &Vector3::z
        );

        // 4) Color
        ru.new_usertype<Color>("Color",
            sol::constructors<Color(), Color(char, char, char)>(),
            "r", &Color::r,
            "g", &Color::g,
            "b", &Color::b
        );

        // 5) Core functions
        ru.set_function("set_seed",        &random_utils::set_seed);
        ru.set_function("random_bool",     &random_utils::random_bool);
        ru.set_function("random_float",    &random_utils::random_float);
        ru.set_function("random_int",      &random_utils::random_int);
        ru.set_function("random_normal",   &random_utils::random_normal);
        ru.set_function("random_sign",     &random_utils::random_sign);
        ru.set_function("random_uid",      &random_utils::random_uid);
        ru.set_function("random_angle",    &random_utils::random_angle);
        ru.set_function("random_biased",   &random_utils::random_biased);

        // 6) Delay (returns chrono::milliseconds)
        ru.set_function("random_delay",    &random_utils::random_delay);

        // 7) Unit‐vector generators
        ru.set_function("random_unit_vector_2D", &random_utils::random_unit_vector_2D);
        ru.set_function("random_unit_vector_3D", &random_utils::random_unit_vector_3D);

        // 8) Color picker
        ru.set_function("random_color",    &random_utils::random_color);

        // --- random_element<T> ---
        ru.set_function("random_element_int",      &random_utils::random_element<int>);
        ru.set_function("random_element_double",   &random_utils::random_element<double>);
        ru.set_function("random_element_string",   &random_utils::random_element<std::string>);
        ru.set_function("random_element_color",    &random_utils::random_element<Color>);
        ru.set_function("random_element_vec2",     &random_utils::random_element<Vector2>);
        ru.set_function("random_element_entity",   &random_utils::random_element<entt::entity>);

        // --- random_element_remove<T> ---
        ru.set_function("random_element_remove_int",    &random_utils::random_element_remove<int>);
        ru.set_function("random_element_remove_double", &random_utils::random_element_remove<double>);
        ru.set_function("random_element_remove_string", &random_utils::random_element_remove<std::string>);
        ru.set_function("random_element_remove_color",  &random_utils::random_element_remove<Color>);
        ru.set_function("random_element_remove_vec2",   &random_utils::random_element_remove<Vector2>);
        ru.set_function("random_element_remove_entity", &random_utils::random_element_remove<entt::entity>);

        // --- random_weighted_pick: vector<double> → int index ---
        ru.set_function("random_weighted_pick_int", &random_utils::random_weighted_pick<int>);

        // --- random_weighted_pick<T> for value picks ---
        ru.set_function("random_weighted_pick_string", &random_utils::random_weighted_pick<std::string>);
        ru.set_function("random_weighted_pick_color",  &random_utils::random_weighted_pick<Color>);
        ru.set_function("random_weighted_pick_vec2",   &random_utils::random_weighted_pick<Vector2>);
        ru.set_function("random_weighted_pick_entity",&random_utils::random_weighted_pick<entt::entity>);
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