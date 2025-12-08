#pragma once

#include <chrono>
#include <functional>
#include <optional>
#include <stdexcept>
#include <string>
#include <string_view>
#include <thread>
#include <utility>
#include <variant>
#include <type_traits>

#include "spdlog/spdlog.h"

#include "sol/sol.hpp"

namespace util {

// Lightweight Result wrapper for recoverable paths.
template <typename T, typename E = std::string>
class Result {
    using Value = std::conditional_t<std::is_void_v<T>, std::monostate, T>;
public:
    Result(Value value) : data_(std::move(value)), ok_(true) {}
    Result(E error) : data_(std::move(error)), ok_(false) {}

    bool isOk() const { return ok_; }
    bool isErr() const { return !ok_; }

    template <typename U = T, typename = std::enable_if_t<!std::is_void_v<U>>>
    Value& value() { return std::get<Value>(data_); }
    template <typename U = T, typename = std::enable_if_t<!std::is_void_v<U>>>
    const Value& value() const { return std::get<Value>(data_); }

    const E& error() const { return std::get<E>(data_); }

    template <typename U = T, typename = std::enable_if_t<!std::is_void_v<U>>>
    Value valueOr(Value fallback) const { return ok_ ? std::get<Value>(data_) : std::move(fallback); }

    template <typename U = T, typename = std::enable_if_t<!std::is_void_v<U>>>
    Value valueOrThrow() const {
        if (!ok_) {
            throw std::runtime_error(std::get<E>(data_));
        }
        return std::get<Value>(data_);
    }

private:
    std::variant<Value, E> data_;
    bool ok_;
};

// Guard a callable with logging; returns Result instead of throwing.
template <typename Fn>
auto tryWithLog(Fn&& fn, std::string_view context)
    -> Result<decltype(fn()), std::string>
{
    using Ret = decltype(fn());
    try {
        if constexpr (std::is_void_v<Ret>) {
            fn();
            return Result<Ret, std::string>(std::monostate{});
        } else {
            return Result<Ret, std::string>(fn());
        }
    } catch (const std::exception& e) {
        SPDLOG_ERROR("[{}] {}", context, e.what());
        return Result<Ret, std::string>(std::string(e.what()));
    } catch (...) {
        SPDLOG_ERROR("[{}] unknown exception", context);
        return Result<Ret, std::string>(std::string("unknown exception"));
    }
}

// Retry helper for loaders that return Result.
template <typename T>
Result<T, std::string> loadWithRetry(std::function<Result<T, std::string>()> loader,
                                     int maxRetries = 3,
                                     std::chrono::milliseconds delay = std::chrono::milliseconds(100)) {
    for (int attempt = 0; attempt < maxRetries; ++attempt) {
        auto result = loader();
        if (result.isOk()) {
            return result;
        }
        SPDLOG_WARN("retry {}/{} failed: {}", attempt + 1, maxRetries, result.error());
        std::this_thread::sleep_for(delay);
    }
    return loader(); // final attempt (propagate whatever it returns)
}

// Safe Lua call wrapper returning Result instead of throwing.
template <typename... Args>
auto safeLuaCall(sol::state& lua, const std::string& fnName, Args&&... args)
    -> Result<sol::protected_function_result, std::string>
{
    try {
        sol::protected_function fn = lua[fnName];
        if (!fn.valid()) {
            return Result<sol::protected_function_result, std::string>(
                "Lua function '" + fnName + "' is not callable");
        }

        sol::protected_function_result res = fn(std::forward<Args>(args)...);
        if (!res.valid()) {
            sol::error err = res;
            return Result<sol::protected_function_result, std::string>(err.what());
        }
        return Result<sol::protected_function_result, std::string>(std::move(res));
    } catch (const std::exception& e) {
        return Result<sol::protected_function_result, std::string>(e.what());
    }
}

// Safe call for already-fetched Lua functions (protected_function or sol::function).
template <typename LuaFn, typename... Args>
auto safeLuaCall(LuaFn&& fn, const std::string& ctx, Args&&... args)
    -> Result<sol::protected_function_result, std::string>
{
    try {
        sol::protected_function_result res = fn(std::forward<Args>(args)...);
        if (!res.valid()) {
            sol::error err = res;
            return Result<sol::protected_function_result, std::string>(err.what());
        }
        return Result<sol::protected_function_result, std::string>(std::move(res));
    } catch (const std::exception& e) {
        return Result<sol::protected_function_result, std::string>(e.what());
    }
}

// ============================================================================
// Lua Error Handling Macros
// ============================================================================
// Use these macros inside lambda bodies for Sol2 bindings to add error handling.
// Sol2 doesn't work well with wrapper functions that hide the lambda signature,
// so we use inline try-catch blocks instead.
//
// Example usage in a lambda binding:
//   lua.set_function("myFunc", [](sol::object a) -> Vector2 {
//       LUA_BINDING_TRY
//           return Vector2{a.as<float>(), 0};
//       LUA_BINDING_CATCH_RETURN(Vector2{0, 0})
//   });
//
// For void functions:
//   lua.set_function("myFunc", []() {
//       LUA_BINDING_TRY
//           doSomething();
//       LUA_BINDING_CATCH_VOID
//   });

#define LUA_BINDING_TRY try {

#define LUA_BINDING_CATCH_RETURN(default_value) \
    } catch (const sol::error& e) { \
        SPDLOG_ERROR("[Lua Binding Error]: {}", e.what()); \
        return default_value; \
    } catch (const std::exception& e) { \
        SPDLOG_ERROR("[Lua Binding Error]: {}", e.what()); \
        return default_value; \
    }

#define LUA_BINDING_CATCH_VOID \
    } catch (const sol::error& e) { \
        SPDLOG_ERROR("[Lua Binding Error]: {}", e.what()); \
    } catch (const std::exception& e) { \
        SPDLOG_ERROR("[Lua Binding Error]: {}", e.what()); \
    }

} // namespace util
