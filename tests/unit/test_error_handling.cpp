#include <gtest/gtest.h>

#include <chrono>

#include "sol/sol.hpp"

#include "util/error_handling.hpp"

namespace {

TEST(ErrorHandling, SafeLuaCallByNameSucceeds) {
    sol::state lua;
    lua.open_libraries(sol::lib::base);
    lua.set_function("add", [](int a, int b) { return a + b; });

    auto result = util::safeLuaCall(lua, "add", 2, 3);

    ASSERT_TRUE(result.isOk());
    EXPECT_EQ(result.value().as<int>(), 5);
}

TEST(ErrorHandling, SafeLuaCallByNameFailsForMissingFunction) {
    sol::state lua;
    lua.open_libraries(sol::lib::base);

    auto result = util::safeLuaCall(lua, "does_not_exist", 1);

    EXPECT_TRUE(result.isErr());
}

TEST(ErrorHandling, SafeLuaCallPreboundFunctionSucceeds) {
    sol::state lua;
    lua.open_libraries(sol::lib::base);
    lua.set_function("mul", [](int a, int b) { return a * b; });
    sol::protected_function fn = lua["mul"];

    auto result = util::safeLuaCall(fn, "lua mul", 2, 4);

    ASSERT_TRUE(result.isOk());
    EXPECT_TRUE(result.value().valid());
    EXPECT_EQ(result.value().get<int>(), 8);
}

TEST(ErrorHandling, SafeLuaCallPreboundFunctionCatchesExceptions) {
    sol::state lua;
    lua.open_libraries(sol::lib::base);
    lua.set_function("explode", []() -> int {
        throw std::runtime_error("boom");
    });
    sol::protected_function fn = lua["explode"];

    auto result = util::safeLuaCall(fn, "lua explode");

    EXPECT_TRUE(result.isErr());
    EXPECT_NE(result.error().find("boom"), std::string::npos);
}

TEST(ErrorHandling, SafeLuaCallReturnsErrorsFromLuaRuntime) {
    sol::state lua;
    lua.open_libraries(sol::lib::base);
    lua.script(R"(
        function bad()
            error("lua runtime fail")
        end
    )");

    auto result = util::safeLuaCall(lua, "bad");

    EXPECT_TRUE(result.isErr());
    EXPECT_NE(result.error().find("lua runtime fail"), std::string::npos);
}

TEST(ErrorHandling, SafeLuaCallHandlesNilFunctionGracefully) {
    sol::state lua;
    lua.open_libraries(sol::lib::base);
    lua["maybe"] = sol::lua_nil;

    auto result = util::safeLuaCall(lua, "maybe", 1);

    EXPECT_TRUE(result.isErr());
}

TEST(ErrorHandling, LoadWithRetrySucceedsAfterRetry) {
    int attempts = 0;
    auto loader = [&]() -> util::Result<int, std::string> {
        attempts++;
        if (attempts < 2) {
            return util::Result<int, std::string>("fail");
        }
        return util::Result<int, std::string>(42);
    };

    auto result = util::loadWithRetry<int>(loader, 3, std::chrono::milliseconds(0));

    EXPECT_TRUE(result.isOk());
    EXPECT_EQ(result.value(), 42);
    EXPECT_EQ(attempts, 2);
}

TEST(ErrorHandling, LoadWithRetryReturnsLastErrorAfterExhaustion) {
    int attempts = 0;
    auto loader = [&]() -> util::Result<int, std::string> {
        attempts++;
        return util::Result<int, std::string>("still failing");
    };

    auto result = util::loadWithRetry<int>(loader, 2, std::chrono::milliseconds(0));

    EXPECT_TRUE(result.isErr());
    EXPECT_EQ(result.error(), "still failing");
    EXPECT_EQ(attempts, 3); // maxRetries attempts + final attempt
}

} // namespace
