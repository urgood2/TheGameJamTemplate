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
        // BindingRecorder instance
        auto& rec = BindingRecorder::instance();

        // 1) Create (or fetch) the random_utils table
        sol::state_view luaView{lua};
        auto ru = luaView["random_utils"].get_or_create<sol::table>();
        if (!ru.valid()) {
            ru = lua.create_table();
            lua["random_utils"] = ru;
        }

        // Recorder: Top-level namespace
        rec.add_type("random_utils").doc = "Random number generation utilities and helper functions";

        // 2) Vector2
        ru.new_usertype<Vector2>("Vector2",
            sol::constructors<Vector2(), Vector2(float, float)>(),
            "x", &Vector2::x,
            "y", &Vector2::y
        );
        rec.record_property("random_utils.Vector2", { "x", "0", "X coordinate" });
        rec.record_property("random_utils.Vector2", { "y", "0", "Y coordinate" });

        // 3) Vector3
        ru.new_usertype<Vector3>("Vector3",
            sol::constructors<Vector3(), Vector3(float, float, float)>(),
            "x", &Vector3::x,
            "y", &Vector3::y,
            "z", &Vector3::z
        );
        rec.record_property("random_utils.Vector3", { "x", "0", "X coordinate" });
        rec.record_property("random_utils.Vector3", { "y", "0", "Y coordinate" });
        rec.record_property("random_utils.Vector3", { "z", "0", "Z coordinate" });

        // 4) Color
        ru.new_usertype<Color>("Color",
            sol::constructors<Color(), Color(char, char, char)>(),
            "r", &Color::r,
            "g", &Color::g,
            "b", &Color::b
        );
        rec.record_property("random_utils.Color", { "r", "0", "Red channel" });
        rec.record_property("random_utils.Color", { "g", "0", "Green channel" });
        rec.record_property("random_utils.Color", { "b", "0", "Blue channel" });


        // 5) Core functions
        rec.bind_function(lua, {"random_utils"}, "set_seed", &random_utils::set_seed,
            "---@param seed number # Seed for the RNG\n"
            "---@return void",
            "Sets the seed for deterministic random behavior");

        rec.bind_function(lua, {"random_utils"}, "random_bool", &random_utils::random_bool,
            "---@return boolean # A random boolean value",
            "Returns a random boolean value");

        rec.bind_function(lua, {"random_utils"}, "random_float", &random_utils::random_float,
            "---@param min number\n"
            "---@param max number\n"
            "---@return number # A random float between min and max",
            "Returns a random float between min and max");

        rec.bind_function(lua, {"random_utils"}, "random_int", &random_utils::random_int,
            "---@param min number\n"
            "---@param max number\n"
            "---@return number # A random integer within the range",
            "Returns a random integer within a range");

        rec.bind_function(lua, {"random_utils"}, "random_normal", &random_utils::random_normal,
            "---@param mean number\n"
            "---@param stdev number\n"
            "---@return number # A float sampled from a normal distribution",
            "Returns a float sampled from a normal distribution");

        rec.bind_function(lua, {"random_utils"}, "random_sign", &random_utils::random_sign,
            "---@return number # Either +1 or -1",
            "Returns +1 or -1 randomly");

        rec.bind_function(lua, {"random_utils"}, "random_uid", &random_utils::random_uid,
            "---@return string # A random UID string",
            "Generates a random UID string");

        rec.bind_function(lua, {"random_utils"}, "random_angle", &random_utils::random_angle,
            "---@return number # A random angle in radians",
            "Returns a random angle in radians");

        rec.bind_function(lua, {"random_utils"}, "random_biased", &random_utils::random_biased,
            "---@param bias number\n"
            "---@return number # A biased random float",
            "Returns a biased random float skewed toward an end");

        rec.bind_function(lua, {"random_utils"}, "random_delay", &random_utils::random_delay,
            "---@param min number\n"
            "---@param max number\n"
            "---@return number # Random delay in milliseconds",
            "Returns a random delay in milliseconds");

        rec.bind_function(lua, {"random_utils"}, "random_unit_vector_2D", &random_utils::random_unit_vector_2D,
            "---@return Vector2 # A normalized 2D vector",
            "Returns a normalized 2D vector");

        rec.bind_function(lua, {"random_utils"}, "random_unit_vector_3D", &random_utils::random_unit_vector_3D,
            "---@return Vector3 # A normalized 3D vector",
            "Returns a normalized 3D vector");

        rec.bind_function(lua, {"random_utils"}, "random_color", &random_utils::random_color,
            "---@return Color # A random color",
            "Returns a randomly generated color");


        // --- random_element<T> ---
        rec.bind_function(lua, {"random_utils"}, "random_element_int", &random_utils::random_element<int>,
            "---@param list integer[]\n"
            "---@return integer",
            "Random element from int vector");

        rec.bind_function(lua, {"random_utils"}, "random_element_double", &random_utils::random_element<double>,
            "---@param list number[]\n"
            "---@return number",
            "Random element from double vector");

        rec.bind_function(lua, {"random_utils"}, "random_element_string", &random_utils::random_element<std::string>,
            "---@param list string[]\n"
            "---@return string",
            "Random element from string vector");

        rec.bind_function(lua, {"random_utils"}, "random_element_color", &random_utils::random_element<Color>,
            "---@param list Color[]\n"
            "---@return Color",
            "Random element from Color vector");

        rec.bind_function(lua, {"random_utils"}, "random_element_vec2", &random_utils::random_element<Vector2>,
            "---@param list Vector2[]\n"
            "---@return Vector2",
            "Random element from Vector2 vector");

        rec.bind_function(lua, {"random_utils"}, "random_element_entity", &random_utils::random_element<entt::entity>,
            "---@param list entity[]\n"
            "---@return entity",
            "Random element from entity vector");


        // --- random_element_remove<T> ---
        rec.bind_function(lua, {"random_utils"}, "random_element_remove_int", &random_utils::random_element_remove<int>,
            "---@param list integer[]\n"
            "---@return integer",
            "Removes and returns a random int");

        rec.bind_function(lua, {"random_utils"}, "random_element_remove_double", &random_utils::random_element_remove<double>,
            "---@param list number[]\n"
            "---@return number",
            "Removes and returns a random double");

        rec.bind_function(lua, {"random_utils"}, "random_element_remove_string", &random_utils::random_element_remove<std::string>,
            "---@param list string[]\n"
            "---@return string",
            "Removes and returns a random string");

        rec.bind_function(lua, {"random_utils"}, "random_element_remove_color", &random_utils::random_element_remove<Color>,
            "---@param list Color[]\n"
            "---@return Color",
            "Removes and returns a random color");

        rec.bind_function(lua, {"random_utils"}, "random_element_remove_vec2", &random_utils::random_element_remove<Vector2>,
            "---@param list Vector2[]\n"
            "---@return Vector2",
            "Removes and returns a random Vector2");

        rec.bind_function(lua, {"random_utils"}, "random_element_remove_entity", &random_utils::random_element_remove<entt::entity>,
            "---@param list entity[]\n"
            "---@return entity",
            "Removes and returns a random entity");


        // --- random_weighted_pick ---
        rec.bind_function(lua, {"random_utils"}, "random_weighted_pick_int", &random_utils::random_weighted_pick<int>,
            "---@param weights number[]\n"
            "---@return integer",
            "Index based on weight vector");

        rec.bind_function(lua, {"random_utils"}, "random_weighted_pick_string", &random_utils::random_weighted_pick<std::string>,
            "---@param values string[]\n"
            "---@param weights number[]\n"
            "---@return string",
            "Weighted pick of string");

        rec.bind_function(lua, {"random_utils"}, "random_weighted_pick_color", &random_utils::random_weighted_pick<Color>,
            "---@param values Color[]\n"
            "---@param weights number[]\n"
            "---@return Color",
            "Weighted pick of color");

        rec.bind_function(lua, {"random_utils"}, "random_weighted_pick_vec2", &random_utils::random_weighted_pick<Vector2>,
            "---@param values Vector2[]\n"
            "---@param weights number[]\n"
            "---@return Vector2",
            "Weighted pick of Vector2");

        rec.bind_function(lua, {"random_utils"}, "random_weighted_pick_entity", &random_utils::random_weighted_pick<entt::entity>,
            "---@param values entity[]\n"
            "---@param weights number[]\n"
            "---@return entity",
            "Weighted pick of entity");
        // // 1) Create (or fetch) the random_utils table
        // // sol::table ru = lua.get_or("random_utils", lua.create_table());
        // sol::state_view luaView{lua};
        // auto ru = luaView["random_utils"].get_or_create<sol::table>();
        // if (!ru.valid()) {
        //     ru = lua.create_table();
        //     lua["random_utils"] = ru;
        // }

        // // 2) Vec2
        // ru.new_usertype<Vector2>("Vector2",
        //     sol::constructors<Vector2(), Vector2(float, float)>(),
        //     "x", &Vector2::x,
        //     "y", &Vector2::y
        // );

        // // 3) Vec3

        // ru.new_usertype<Vector3>("Vector3",
        //     sol::constructors<Vector3(), Vector3(float, float, float)>(),
        //     "x", &Vector3::x,
        //     "y", &Vector3::y,
        //     "z", &Vector3::z
        // );

        // // 4) Color
        // ru.new_usertype<Color>("Color",
        //     sol::constructors<Color(), Color(char, char, char)>(),
        //     "r", &Color::r,
        //     "g", &Color::g,
        //     "b", &Color::b
        // );

        // // 5) Core functions
        // ru.set_function("set_seed",        &random_utils::set_seed);
        // ru.set_function("random_bool",     &random_utils::random_bool);
        // ru.set_function("random_float",    &random_utils::random_float);
        // ru.set_function("random_int",      &random_utils::random_int);
        // ru.set_function("random_normal",   &random_utils::random_normal);
        // ru.set_function("random_sign",     &random_utils::random_sign);
        // ru.set_function("random_uid",      &random_utils::random_uid);
        // ru.set_function("random_angle",    &random_utils::random_angle);
        // ru.set_function("random_biased",   &random_utils::random_biased);

        // // 6) Delay (returns chrono::milliseconds)
        // ru.set_function("random_delay",    &random_utils::random_delay);

        // // 7) Unit‐vector generators
        // ru.set_function("random_unit_vector_2D", &random_utils::random_unit_vector_2D);
        // ru.set_function("random_unit_vector_3D", &random_utils::random_unit_vector_3D);

        // // 8) Color picker
        // ru.set_function("random_color",    &random_utils::random_color);

        // // --- random_element<T> ---
        // ru.set_function("random_element_int",      &random_utils::random_element<int>);
        // ru.set_function("random_element_double",   &random_utils::random_element<double>);
        // ru.set_function("random_element_string",   &random_utils::random_element<std::string>);
        // ru.set_function("random_element_color",    &random_utils::random_element<Color>);
        // ru.set_function("random_element_vec2",     &random_utils::random_element<Vector2>);
        // ru.set_function("random_element_entity",   &random_utils::random_element<entt::entity>);

        // // --- random_element_remove<T> ---
        // ru.set_function("random_element_remove_int",    &random_utils::random_element_remove<int>);
        // ru.set_function("random_element_remove_double", &random_utils::random_element_remove<double>);
        // ru.set_function("random_element_remove_string", &random_utils::random_element_remove<std::string>);
        // ru.set_function("random_element_remove_color",  &random_utils::random_element_remove<Color>);
        // ru.set_function("random_element_remove_vec2",   &random_utils::random_element_remove<Vector2>);
        // ru.set_function("random_element_remove_entity", &random_utils::random_element_remove<entt::entity>);

        // // --- random_weighted_pick: vector<double> → int index ---
        // ru.set_function("random_weighted_pick_int", &random_utils::random_weighted_pick<int>);

        // // --- random_weighted_pick<T> for value picks ---
        // ru.set_function("random_weighted_pick_string", &random_utils::random_weighted_pick<std::string>);
        // ru.set_function("random_weighted_pick_color",  &random_utils::random_weighted_pick<Color>);
        // ru.set_function("random_weighted_pick_vec2",   &random_utils::random_weighted_pick<Vector2>);
        // ru.set_function("random_weighted_pick_entity",&random_utils::random_weighted_pick<entt::entity>);
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