#pragma once
/**
 * @file binding_helpers.hpp
 * @brief Common Lua<->C++ conversion utilities for Sol2 bindings
 * @see CPP_REFACTORING_PLAN.md Task 2.3
 */

#include "sol/sol.hpp"
#include <vector>
#include <string>
#include <optional>

namespace binding_helpers {

template<typename T = std::string>
inline std::vector<T> table_to_vector(const sol::table& t) {
    std::vector<T> result;
    result.reserve(t.size());
    for (auto& kv : t) {
        if (kv.second.is<T>()) {
            result.push_back(kv.second.as<T>());
        }
    }
    return result;
}

template<typename T>
inline sol::table vector_to_table(sol::state_view lua, const std::vector<T>& vec) {
    sol::table t = lua.create_table();
    for (size_t i = 0; i < vec.size(); ++i) {
        t[i + 1] = vec[i];
    }
    return t;
}

template<typename T>
inline std::optional<T> safe_get(const sol::table& t, const char* key) {
    if (auto val = t[key]; val.valid() && val.is<T>()) {
        return val.get<T>();
    }
    return std::nullopt;
}

inline sol::table vec_to_lua(sol::state_view lua, float x, float y) {
    sol::table t = lua.create_table();
    t["x"] = x;
    t["y"] = y;
    return t;
}

inline std::pair<float, float> vec_from_lua(const sol::table& t) {
    float x = 0.0f, y = 0.0f;
    if (auto vx = t["x"]; vx.valid() && vx.is<float>()) x = vx.get<float>();
    if (auto vy = t["y"]; vy.valid() && vy.is<float>()) y = vy.get<float>();
    return {x, y};
}

template<typename T>
inline T get_or_default(const sol::table& t, const char* key, T default_val) {
    if (auto val = t[key]; val.valid() && val.is<T>()) {
        return val.get<T>();
    }
    return default_val;
}

} // namespace binding_helpers
