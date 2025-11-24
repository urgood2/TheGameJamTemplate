#include <gtest/gtest.h>

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

} // namespace
