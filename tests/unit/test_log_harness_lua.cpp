#include "sol/sol.hpp"

#include <gtest/gtest.h>

#include "testing/test_harness_lua.hpp"
#include "testing/test_runtime.hpp"

namespace {

testing::TestModeConfig make_config() {
    testing::TestModeConfig config;
    config.enabled = true;
    config.run_root = std::filesystem::path("tests/out");
    return config;
}

sol::state create_lua() {
    sol::state lua;
    lua.open_libraries(sol::lib::base, sol::lib::package, sol::lib::string, sol::lib::table, sol::lib::math);
    return lua;
}

} // namespace

TEST(TestHarnessLuaLogs, MarkFindClear) {
    testing::TestRuntime runtime;
    ASSERT_TRUE(runtime.initialize(make_config()));
    runtime.api_registry().register_capability("logs", true);
    runtime.log_capture().add({0, "first entry", "system", "info", ""});
    runtime.log_capture().add({1, "second entry", "system", "warn", ""});

    sol::state lua = create_lua();
    testing::expose_to_lua(lua, runtime);

    sol::protected_function mark = lua["test_harness"]["log_mark"];
    sol::protected_function find = lua["test_harness"]["find_log"];
    sol::protected_function clear = lua["test_harness"]["clear_logs"];

    sol::protected_function_result mark_result = mark();
    ASSERT_TRUE(mark_result.valid());
    int mark_index = mark_result.get<int>();
    EXPECT_EQ(mark_index, 2);

    sol::table opts = lua.create_table();
    opts["since"] = mark_index;

    sol::protected_function_result find_result = find("second", opts);
    ASSERT_TRUE(find_result.valid());
    EXPECT_FALSE(find_result.get<bool>(0));
    EXPECT_EQ(find_result.get<int>(1), 2);

    sol::table opts2 = lua.create_table();
    opts2["since"] = 0;
    sol::protected_function_result find_from_start = find("second", opts2);
    ASSERT_TRUE(find_from_start.valid());
    EXPECT_TRUE(find_from_start.get<bool>(0));
    EXPECT_EQ(find_from_start.get<int>(1), 1);

    clear();
    EXPECT_TRUE(runtime.log_capture().empty());

    runtime.shutdown();
}

TEST(TestHarnessLuaLogs, AssertNoLogLevel) {
    testing::TestRuntime runtime;
    ASSERT_TRUE(runtime.initialize(make_config()));
    runtime.api_registry().register_capability("logs", true);
    runtime.log_capture().add({0, "error entry", "system", "error", ""});

    sol::state lua = create_lua();
    testing::expose_to_lua(lua, runtime);

    sol::protected_function assert_fn = lua["test_harness"]["assert_no_log_level"];
    sol::protected_function_result result = assert_fn("warn");
    ASSERT_TRUE(result.valid());
    sol::object ok = result.get<sol::object>(0);
    sol::object err = result.get<sol::object>(1);
    EXPECT_TRUE(ok == sol::nil);
    ASSERT_TRUE(err.is<std::string>());
    EXPECT_NE(err.as<std::string>().find("log_gating:"), std::string::npos);

    runtime.shutdown();
}

TEST(TestHarnessLuaLogs, RegexModeFindsMatch) {
    testing::TestRuntime runtime;
    ASSERT_TRUE(runtime.initialize(make_config()));
    runtime.api_registry().register_capability("logs", true);
    runtime.log_capture().add({0, "regex entry", "system", "info", ""});

    sol::state lua = create_lua();
    testing::expose_to_lua(lua, runtime);

    sol::protected_function find = lua["test_harness"]["find_log"];
    sol::table opts = lua.create_table();
    opts["regex"] = true;

    sol::protected_function_result result = find("regex.*", opts);
    ASSERT_TRUE(result.valid());
    EXPECT_TRUE(result.get<bool>(0));
    EXPECT_EQ(result.get<int>(1), 0);

    runtime.shutdown();
}
