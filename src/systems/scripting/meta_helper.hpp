#pragma once

#include "entt/meta/factory.hpp"
#include "entt/meta/resolve.hpp"
#include "sol/sol.hpp"

namespace scripting {
  /**
   * ------------------------------------------------------
   * Get the `entt::id_type` of a Lua object’s associated C++ type.
   * 
   * In Lua, this is done by calling the `type_id` function that 
   * your bound C++ type should expose in Lua.
   * 
   * Example usage in Lua:
   * ```lua
   * local tid = Transform.type_id()  -- for Transform
   * local tid = SomeComponent.type_id() -- for other registered components
   * ```
   * 
   * @param obj Lua table expected to have a `type_id` function.
   * @return The `entt::id_type` representing the C++ type.
   * ------------------------------------------------------
   */
  [[nodiscard]] inline entt::id_type get_type_id(const sol::table &obj) {
    const auto f = obj["type_id"].get<sol::function>();
    assert(f.valid() && "type_id not exposed to lua!");
    return f.valid() ? f().get<entt::id_type>() : -1;
  }

  /**
   * ------------------------------------------------------
   * Deduces the `entt::id_type` for a Lua-provided object.
   * 
   * This function handles two possible scenarios:
   * 1. The object is a number (e.g., passed directly as `type_id`)
   * 2. The object is a Lua table representing a bound C++ type, 
   *    which exposes a `type_id` function.
   * 
   * Example usage in Lua:
   * ```lua
   * registry:has(e, Transform)          -- Pass the table, auto-deduces
   * registry:has(e, Transform.type_id())-- Pass the type_id directly
   * ```
   * 
   * @param obj The Lua object (either a table or number).
   * @return The corresponding `entt::id_type` of the type.
   * ------------------------------------------------------
   */
  template <typename T> [[nodiscard]] inline entt::id_type deduce_type(T &&obj) {
    switch (obj.get_type()) {
    case sol::type::number:
      return obj.template as<entt::id_type>();
    case sol::type::table:
      return get_type_id(obj);
    default:
      assert(false && "deduce_type: Unsupported Lua object type");
      return -1;
    }
  }

  /**
   * ------------------------------------------------------
   * Invokes a **registered meta function** on a resolved type directly.
   * 
   * @param meta_type The resolved `entt::meta_type` (obtained via `entt::resolve`).
   * @param function_id The hashed string id of the function (e.g., `"emplace"_hs`).
   * @param args Arguments to pass to the function.
   * @return A `meta_any` holding the result of the call (may be empty if the call fails).
   * ------------------------------------------------------
   */
  template <typename... Args>
  inline auto invoke_meta_func(entt::meta_type meta_type,
                              entt::id_type function_id, Args &&...args) {
    if (!meta_type) {
      // TODO: Warning message
    } else {
      if (auto &&meta_function = meta_type.func(function_id); meta_function)
        return meta_function.invoke({}, std::forward<Args>(args)...);
    }
    return entt::meta_any{}; // empty result
  }

  /**
   * ------------------------------------------------------
   * Convenience overload: resolve the type_id internally before 
   * invoking the meta function.
   * 
   * Example usage in Lua:
   * ```lua
   * registry:emplace(e, Transform, data)
   * ```
   * 
   * C++ side (calls this helper):
   * ```cpp
   * invoke_meta_func(type_id, "emplace"_hs, &registry, entity, table, state);
   * ```
   * 
   * @param type_id The type id of the C++ component or object.
   * @param function_id The hashed string id of the function.
   * @param args Arguments to pass to the function.
   * @return A `meta_any` holding the result of the call.
   * ------------------------------------------------------
   */
  template <typename... Args>
  inline auto invoke_meta_func(entt::id_type type_id, entt::id_type function_id,
                              Args &&...args) {
    return invoke_meta_func(entt::resolve(type_id), function_id,
                            std::forward<Args>(args)...);
  }

}