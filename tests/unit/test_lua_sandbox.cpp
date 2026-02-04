#include <gtest/gtest.h>

#include <chrono>
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>

#include "sol/sol.hpp"
#include "testing/lua_sandbox.hpp"
#include "testing/test_mode_config.hpp"

namespace {

testing::TestModeConfig make_config() {
    testing::TestModeConfig config;
    config.lua_sandbox = testing::LuaSandboxMode::On;
    config.fixed_fps = 60;
    config.seed = 1234;
    return config;
}

sol::state make_lua_state() {
    sol::state lua;
    lua.open_libraries(sol::lib::base,
                       sol::lib::math,
                       sol::lib::os,
                       sol::lib::package,
                       sol::lib::io,
                       sol::lib::table,
                       sol::lib::string);
    return lua;
}

std::filesystem::path make_temp_dir() {
    const auto now = std::chrono::steady_clock::now().time_since_epoch().count();
    auto root = std::filesystem::temp_directory_path() / ("lua_sandbox_" + std::to_string(now));
    std::filesystem::create_directories(root);
    return root;
}

} // namespace

TEST(LuaSandbox, DisabledFunctions) {
    auto lua = make_lua_state();
    testing::LuaSandbox sandbox;
    sandbox.initialize(nullptr, make_config());
    sandbox.apply(lua);

    auto exec_result = lua.safe_script("return pcall(function() os.execute('echo hi') end)");
    EXPECT_FALSE(exec_result.get<bool>());

    auto popen_result = lua.safe_script("return pcall(function() io.popen('echo hi') end)");
    EXPECT_FALSE(popen_result.get<bool>());
}

TEST(LuaSandbox, DeterministicTime) {
    auto lua = make_lua_state();
    testing::LuaSandbox sandbox;
    sandbox.initialize(nullptr, make_config());
    sandbox.apply(lua);

    sandbox.update_frame(0);
    auto t1 = lua.safe_script("return os.time()").get<long long>();
    auto c1 = lua.safe_script("return os.clock()").get<double>();

    sandbox.update_frame(60);
    auto t2 = lua.safe_script("return os.time()").get<long long>();
    auto c2 = lua.safe_script("return os.clock()").get<double>();

    EXPECT_EQ(t2 - t1, 1);
    EXPECT_NEAR(c2 - c1, 1.0, 1e-6);
}

TEST(LuaSandbox, DeterministicRandom) {
    auto lua_a = make_lua_state();
    testing::LuaSandbox sandbox_a;
    sandbox_a.initialize(nullptr, make_config());
    sandbox_a.apply(lua_a);

    auto lua_b = make_lua_state();
    testing::LuaSandbox sandbox_b;
    sandbox_b.initialize(nullptr, make_config());
    sandbox_b.apply(lua_b);

    sol::function random_a = lua_a["math"]["random"];
    sol::function random_b = lua_b["math"]["random"];

    std::vector<double> seq_a = {random_a(), random_a(), random_a()};
    std::vector<double> seq_b = {random_b(), random_b(), random_b()};

    ASSERT_EQ(seq_a.size(), seq_b.size());
    for (size_t i = 0; i < seq_a.size(); ++i) {
        EXPECT_NEAR(seq_a[i], seq_b[i], 1e-9);
    }
}

TEST(LuaSandbox, RandomSeedIsNoOp) {
    auto lua_a = make_lua_state();
    testing::LuaSandbox sandbox_a;
    sandbox_a.initialize(nullptr, make_config());
    sandbox_a.apply(lua_a);

    auto lua_b = make_lua_state();
    testing::LuaSandbox sandbox_b;
    sandbox_b.initialize(nullptr, make_config());
    sandbox_b.apply(lua_b);

    sol::function random_a = lua_a["math"]["random"];
    sol::function randomseed_a = lua_a["math"]["randomseed"];
    sol::function random_b = lua_b["math"]["random"];

    double first_a = random_a();
    randomseed_a(999);
    double second_a = random_a();

    double first_b = random_b();
    double second_b = random_b();

    EXPECT_NEAR(first_a, first_b, 1e-9);
    EXPECT_NEAR(second_a, second_b, 1e-9);
}

TEST(LuaSandbox, RequireRestriction) {
    auto lua = make_lua_state();
    testing::LuaSandbox sandbox;
    sandbox.initialize(nullptr, make_config());

    const auto temp_root = make_temp_dir();
    const auto module_path = temp_root / "allowed_mod.lua";
    std::ofstream out(module_path);
    out << "return { value = 42 }";
    out.close();

    sandbox.set_allowed_require_paths({temp_root.generic_string()});
    sandbox.apply(lua);

    auto value = lua.safe_script("local mod = require('allowed_mod'); return mod.value").get<int>();
    EXPECT_EQ(value, 42);

    sol::protected_function require_fn = lua["require"];
    sol::protected_function_result blocked = require_fn("../evil");
    EXPECT_FALSE(blocked.valid());
    sol::error err = blocked;
    EXPECT_NE(std::string(err.what()).find("require blocked"), std::string::npos);
}
