#pragma once

#include "entt/meta/factory.hpp"
#include "entt/meta/resolve.hpp"
#include "sol/sol.hpp"

namespace scripting {
  /**
   * @brief Get the entt type id from a Lua table exposing `type_id()`.
   * @param obj Lua table expected to implement `type_id`.
   * @return entt::id_type for the bound C++ type.
   *
   * Example (Lua):
   * ```lua
   * local tid = Transform.type_id()
   * local tid = SomeComponent.type_id()
   * ```
   */
  [[nodiscard]] inline entt::id_type get_type_id(const sol::table &obj) {
    const auto f = obj["type_id"].get<sol::function>();
    assert(f.valid() && "type_id not exposed to lua!");
    return f.valid() ? f().get<entt::id_type>() : -1;
  }

  /**
   * @brief Deduce entt type id from a Lua value (number or table).
   * @param obj Lua number (type id) or table exposing `type_id`.
   * @return entt::id_type representing the C++ type.
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
   * @brief Invoke a registered meta function on a resolved entt type.
   * @param meta_type Resolved entt::meta_type.
   * @param function_id Hashed string id of the function (e.g. `"emplace"_hs`).
   * @param args Arguments forwarded to the function.
   * @return meta_any result (empty on failure).
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
   * @brief Overload resolving type id internally before invocation.
   * @param type_id entt type id.
   * @param function_id Hashed string id of the function.
   * @param args Arguments forwarded to the function.
   * @return meta_any result.
   */
  template <typename... Args>
  inline auto invoke_meta_func(entt::id_type type_id, entt::id_type function_id,
                              Args &&...args) {
    return invoke_meta_func(entt::resolve(type_id), function_id,
                            std::forward<Args>(args)...);
  }

}
