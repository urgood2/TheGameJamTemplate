#include <gtest/gtest.h>

#include "sol/sol.hpp"

#include "util/error_handling.hpp"

TEST(TextWaiters, CoroutineErrorsAreCapturedByTryWithLog) {
    sol::state lua;
    lua.open_libraries(sol::lib::base, sol::lib::coroutine);

    // Build a coroutine that throws.
    lua.script("function make_boom_co() return coroutine.create(function() error('boom') end) end");
    sol::coroutine co = lua["make_boom_co"]();

    auto result = util::tryWithLog([&]() { return co(); }, "test coroutine");
    ASSERT_TRUE(result.isOk());
    auto& pfr = result.value();
    EXPECT_FALSE(pfr.valid()); // invalid protected result -> text waiters will log/abort
}

TEST(TextWaiters, CoroutineSuccessPassesThroughTryWithLog) {
    sol::state lua;
    lua.open_libraries(sol::lib::base, sol::lib::coroutine);

    lua.script("function ok_fn() return true end");
    sol::protected_function pf = lua["ok_fn"];

    auto result = util::tryWithLog([&]() { return pf(); }, "test coroutine ok");
    ASSERT_TRUE(result.isOk());
}
