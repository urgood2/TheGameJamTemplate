#pragma once
/**
 * @file result_macros.hpp
 * @brief Convenience macros for Result<T> error handling pattern
 * @see error_handling.hpp for Result<T> definition
 * @see CPP_REFACTORING_PLAN.md Task 1.4
 */

#include "error_handling.hpp"

/**
 * Early return on error - propagates error from Result-returning expression.
 * Use when the enclosing function also returns Result<T>.
 */
#define TRY(expr) \
    do { \
        auto _try_result = (expr); \
        if (_try_result.isErr()) return _try_result; \
    } while(0)

/**
 * Early return with logging - logs error with context before returning.
 * Use for important error paths that need visibility.
 */
#define TRY_OR_LOG(expr, context) \
    do { \
        auto _try_result = (expr); \
        if (_try_result.isErr()) { \
            SPDLOG_ERROR("[{}] {}", context, _try_result.error()); \
            return _try_result; \
        } \
    } while(0)

/**
 * Unwrap Result or use fallback value.
 * Useful for non-critical errors where a default is acceptable.
 */
#define UNWRAP_OR(expr, default_val) \
    ((expr).isOk() ? (expr).value() : (default_val))

/**
 * Unwrap Result and assign to variable, or return error.
 * Creates a new variable with the unwrapped value.
 */
#define TRY_ASSIGN(var, expr) \
    auto _try_##var##_result = (expr); \
    if (_try_##var##_result.isErr()) return _try_##var##_result; \
    auto var = std::move(_try_##var##_result.value())

/**
 * Check Result and run cleanup on error before returning.
 * Useful when resources need cleanup before error propagation.
 */
#define TRY_OR_CLEANUP(expr, cleanup_code) \
    do { \
        auto _try_result = (expr); \
        if (_try_result.isErr()) { \
            cleanup_code; \
            return _try_result; \
        } \
    } while(0)
