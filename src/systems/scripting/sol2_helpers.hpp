#pragma once
/**
 * @file sol2_helpers.hpp
 * @brief Safe Lua callback wrappers for sol2 - prevents crashes from Lua errors
 * @see CPP_REFACTORING_PLAN.md Task 1.1
 */

#include "sol/sol.hpp"
#include "spdlog/spdlog.h"

#include <optional>
#include <string>
#include <functional>

namespace sol2_util {

/**
 * @brief Safely call a Lua function, returning success/failure status
 * @param fn The sol::function to call
 * @param context Description for error logging (e.g., "input_rebind_callback")
 * @param args Arguments to pass to the Lua function
 * @return true if call succeeded, false if function was invalid or threw
 */
template<typename... Args>
inline bool safe_call(const sol::function& fn, const char* context, Args&&... args) {
    if (!fn.valid()) {
        SPDLOG_WARN("[Lua] {}: Function is invalid/nil", context);
        return false;
    }

    sol::protected_function pf(fn);
    auto result = pf(std::forward<Args>(args)...);

    if (!result.valid()) {
        sol::error err = result;
        SPDLOG_ERROR("[Lua Error] {}: {}", context, err.what());
        return false;
    }
    return true;
}

/**
 * @brief Safely call a Lua function and extract a typed result
 * @tparam R Return type expected from the Lua function
 * @param fn The sol::function to call
 * @param context Description for error logging
 * @param args Arguments to pass to the Lua function
 * @return std::optional<R> containing the result if successful, nullopt on failure
 */
template<typename R, typename... Args>
inline std::optional<R> safe_call_with_result(const sol::function& fn, const char* context, Args&&... args) {
    if (!fn.valid()) {
        SPDLOG_WARN("[Lua] {}: Function is invalid/nil", context);
        return std::nullopt;
    }

    sol::protected_function pf(fn);
    auto result = pf(std::forward<Args>(args)...);

    if (!result.valid()) {
        sol::error err = result;
        SPDLOG_ERROR("[Lua Error] {}: {}", context, err.what());
        return std::nullopt;
    }

    try {
        return result.template get<R>();
    } catch (const std::exception& e) {
        SPDLOG_ERROR("[Lua Type Error] {}: Expected type mismatch - {}", context, e.what());
        return std::nullopt;
    }
}

/**
 * @brief Wrap a sol::function for repeated safe calls with optional return
 * @tparam R Return type expected from the Lua function
 * @tparam Args Argument types for the wrapper
 * @param fn The sol::function to wrap
 * @param context Description for error logging (stored by value)
 * @return std::function wrapper that safely invokes the Lua function
 */
template<typename R, typename... Args>
inline std::function<std::optional<R>(Args...)> wrap_safe(sol::function fn, std::string context) {
    return [fn = std::move(fn), ctx = std::move(context)](Args... args) -> std::optional<R> {
        return safe_call_with_result<R>(fn, ctx.c_str(), std::forward<Args>(args)...);
    };
}

/// @brief Check if a Lua function is valid and callable
[[nodiscard]] inline bool is_callable(const sol::function& fn) noexcept {
    return fn.valid();
}

/// @brief Safely call a Lua function from a sol::object (checks if callable first)
template<typename... Args>
inline bool safe_call_object(const sol::object& obj, const char* context, Args&&... args) {
    if (!obj.valid() || !obj.is<sol::function>()) {
        SPDLOG_WARN("[Lua] {}: Object is not a callable function", context);
        return false;
    }
    return safe_call(obj.as<sol::function>(), context, std::forward<Args>(args)...);
}

} // namespace sol2_util
