#pragma once
/**
 * @file ldtk_field_converters.hpp
 * @brief Helper functions for converting LDtk field values to Lua tables
 * @see CPP_REFACTORING_PLAN.md Task 2.1
 */

#include "sol/sol.hpp"
#include "ldtk_combined.hpp"

namespace ldtk_converters {

inline sol::table colorToLua(sol::state_view lua, const ldtk::Color& c) {
    sol::table t = lua.create_table();
    t["r"] = c.r;
    t["g"] = c.g;
    t["b"] = c.b;
    t["a"] = c.a;
    return t;
}

inline sol::table pointToLua(sol::state_view lua, const ldtk::IntPoint& p) {
    sol::table t = lua.create_table();
    t["x"] = p.x;
    t["y"] = p.y;
    return t;
}

inline sol::table entityRefToLua(sol::state_view lua, const ldtk::EntityRef& ref) {
    sol::table t = lua.create_table();
    t["entity_iid"] = ref.entity_iid.str();
    t["layer_iid"] = ref.layer_iid.str();
    t["level_iid"] = ref.level_iid.str();
    t["world_iid"] = ref.world_iid.str();
    return t;
}

template<typename T, typename ToLua>
inline sol::table arrayToLua(sol::state_view lua, const ldtk::ArrayField<T>& arr, ToLua converter) {
    sol::table t = lua.create_table();
    for (size_t i = 0; i < arr.size(); ++i) {
        if (!arr[i].is_null()) {
            t[i + 1] = converter(lua, arr[i].value());
        }
    }
    return t;
}

template<typename T>
inline sol::table simpleArrayToLua(sol::state_view lua, const ldtk::ArrayField<T>& arr) {
    sol::table t = lua.create_table();
    for (size_t i = 0; i < arr.size(); ++i) {
        if (!arr[i].is_null()) {
            t[i + 1] = arr[i].value();
        }
    }
    return t;
}

inline sol::table enumArrayToLua(sol::state_view lua, const ldtk::ArrayField<ldtk::EnumValue>& arr) {
    sol::table t = lua.create_table();
    for (size_t i = 0; i < arr.size(); ++i) {
        if (!arr[i].is_null()) {
            t[i + 1] = arr[i].value().name;
        }
    }
    return t;
}

inline sol::table filePathArrayToLua(sol::state_view lua, const ldtk::ArrayField<ldtk::FilePath>& arr) {
    sol::table t = lua.create_table();
    for (size_t i = 0; i < arr.size(); ++i) {
        if (!arr[i].is_null()) {
            t[i + 1] = std::string(arr[i].value().c_str());
        }
    }
    return t;
}

} // namespace ldtk_converters
