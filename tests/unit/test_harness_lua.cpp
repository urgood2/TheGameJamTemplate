#include <gtest/gtest.h>

#include <chrono>
#include <filesystem>
#include <string>

#include "sol/sol.hpp"
#include "testing/test_harness_lua.hpp"
#include "testing/test_runtime.hpp"

namespace {

std::filesystem::path make_temp_root() {
    const auto now = std::chrono::steady_clock::now().time_since_epoch().count();
    auto root = std::filesystem::temp_directory_path() / ("test_harness_" + std::to_string(now));
    std::filesystem::create_directories(root);
    return root;
}

testing::TestModeConfig make_config() {
    testing::TestModeConfig config;
    auto root = make_temp_root();
    config.run_root = root;
    config.artifacts_dir = root / "artifacts";
    config.forensics_dir = root / "forensics";
    config.report_json_path = std::filesystem::path("report.json");
    config.report_junit_path = std::filesystem::path("report.xml");
    config.baseline_staging_dir = root / "baselines";
    config.resolution_width = 800;
    config.resolution_height = 450;
    config.fixed_fps = 60;
    config.seed = 42;
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

} // namespace

TEST(TestHarnessLua, WaitFramesYieldAndResume) {
    testing::TestRuntime runtime;
    ASSERT_TRUE(runtime.initialize(make_config()));

    auto lua = make_lua_state();
    testing::expose_to_lua(lua, runtime);

    lua.script("function wait_two() test_harness.wait_frames(2); return 7 end");
    sol::coroutine co = lua["wait_two"];

    auto result = co();
    EXPECT_EQ(co.status(), sol::call_status::yielded);
    EXPECT_EQ(runtime.wait_frames_remaining(), 2);

    runtime.on_frame_start(1);
    runtime.on_frame_start(2);
    EXPECT_EQ(runtime.wait_frames_remaining(), 0);

    auto resumed = co();
    EXPECT_TRUE(resumed.valid());
    EXPECT_EQ(resumed.get<int>(), 7);
}

TEST(TestHarnessLua, WaitFramesZeroDoesNotYield) {
    testing::TestRuntime runtime;
    ASSERT_TRUE(runtime.initialize(make_config()));

    auto lua = make_lua_state();
    testing::expose_to_lua(lua, runtime);

    lua.script("function wait_zero() test_harness.wait_frames(0); return 1 end");
    sol::coroutine co = lua["wait_zero"];
    auto result = co();

    EXPECT_EQ(co.status(), sol::call_status::ok);
    EXPECT_TRUE(result.valid());
    EXPECT_EQ(result.get<int>(), 1);
    EXPECT_EQ(runtime.wait_frames_remaining(), 0);
}

TEST(TestHarnessLua, WaitFramesNegativeError) {
    testing::TestRuntime runtime;
    ASSERT_TRUE(runtime.initialize(make_config()));

    auto lua = make_lua_state();
    testing::expose_to_lua(lua, runtime);

    sol::protected_function wait_frames = lua["test_harness"]["wait_frames"];
    auto result = wait_frames(-1);
    EXPECT_FALSE(result.valid());
    sol::error err = result;
    EXPECT_NE(std::string(err.what()).find("invalid_argument"), std::string::npos);
}

TEST(TestHarnessLua, NowFrameReportsCurrentFrame) {
    testing::TestRuntime runtime;
    ASSERT_TRUE(runtime.initialize(make_config()));

    auto lua = make_lua_state();
    testing::expose_to_lua(lua, runtime);

    runtime.on_frame_start(12);
    auto value = lua.safe_script("return test_harness.now_frame()").get<int>();
    EXPECT_EQ(value, 12);
}

TEST(TestHarnessLua, ExitRequestsCode) {
    testing::TestRuntime runtime;
    ASSERT_TRUE(runtime.initialize(make_config()));

    auto lua = make_lua_state();
    testing::expose_to_lua(lua, runtime);

    lua.safe_script("test_harness.exit(2)");
    EXPECT_TRUE(runtime.exit_requested());
    EXPECT_EQ(runtime.exit_code(), 2);
}

TEST(TestHarnessLua, SkipAndXfailUpdateRuntime) {
    testing::TestRuntime runtime;
    ASSERT_TRUE(runtime.initialize(make_config()));

    auto lua = make_lua_state();
    testing::expose_to_lua(lua, runtime);

    runtime.on_test_start("test.skip", 1);
    sol::protected_function skip_fn = lua["test_harness"]["skip"];
    auto skip_result = skip_fn("reason");
    EXPECT_TRUE(skip_result.valid());
    EXPECT_EQ(runtime.requested_outcome(), "skip");
    EXPECT_EQ(runtime.requested_outcome_reason(), "reason");

    runtime.on_test_start("test.xfail", 2);
    sol::protected_function xfail_fn = lua["test_harness"]["xfail"];
    auto xfail_result = xfail_fn("expected");
    EXPECT_TRUE(xfail_result.valid());
    EXPECT_EQ(runtime.requested_outcome(), "xfail");
    EXPECT_EQ(runtime.requested_outcome_reason(), "expected");
    EXPECT_EQ(runtime.current_attempt(), 2);
}

TEST(TestHarnessLua, SkipOutsideTestReturnsError) {
    testing::TestRuntime runtime;
    ASSERT_TRUE(runtime.initialize(make_config()));

    auto lua = make_lua_state();
    testing::expose_to_lua(lua, runtime);

    sol::protected_function skip_fn = lua["test_harness"]["skip"];
    auto result = skip_fn("reason");
    ASSERT_TRUE(result.valid());
    auto first = result.get<sol::object>(0);
    auto second = result.get<sol::object>(1);
    EXPECT_TRUE(first.is<sol::lua_nil_t>());
    EXPECT_TRUE(second.is<std::string>());
    EXPECT_NE(second.as<std::string>().find("harness_error:skip"), std::string::npos);
}

TEST(TestHarnessLua, CapabilitiesReadOnly) {
    testing::TestRuntime runtime;
    ASSERT_TRUE(runtime.initialize(make_config()));

    auto lua = make_lua_state();
    testing::expose_to_lua(lua, runtime);

    auto result = lua.safe_script("return pcall(function() test_harness.capabilities.new_cap = true end)");
    EXPECT_FALSE(result.get<bool>());
}

TEST(TestHarnessLua, RequireRejectsMissingCapabilities) {
    testing::TestRuntime runtime;
    ASSERT_TRUE(runtime.initialize(make_config()));

    auto lua = make_lua_state();
    testing::expose_to_lua(lua, runtime);

    auto result = lua.safe_script(
        "local ok, err = test_harness.require({ requires = { 'screenshots' } }) return ok, err");
    auto ok_obj = result.get<sol::object>(0);
    auto err_obj = result.get<sol::object>(1);
    EXPECT_TRUE(ok_obj.is<sol::lua_nil_t>());
    EXPECT_TRUE(err_obj.is<std::string>());
    EXPECT_NE(err_obj.as<std::string>().find("capability_missing"), std::string::npos);
}

TEST(TestHarnessLua, RequireRejectsLowVersion) {
    testing::TestRuntime runtime;
    ASSERT_TRUE(runtime.initialize(make_config()));
    runtime.api_registry().set_version("1.0.0");

    auto lua = make_lua_state();
    testing::expose_to_lua(lua, runtime);

    auto result = lua.safe_script(
        "local ok, err = test_harness.require({ min_test_api_version = '2.0.0' }) return ok, err");
    auto ok_obj = result.get<sol::object>(0);
    auto err_obj = result.get<sol::object>(1);
    EXPECT_TRUE(ok_obj.is<sol::lua_nil_t>());
    EXPECT_TRUE(err_obj.is<std::string>());
    EXPECT_NE(err_obj.as<std::string>().find("version_too_low"), std::string::npos);
}

TEST(TestHarnessLua, RequireSucceedsWhenSatisfied) {
    testing::TestRuntime runtime;
    ASSERT_TRUE(runtime.initialize(make_config()));
    runtime.api_registry().set_version("2.1.0");
    runtime.api_registry().register_capability("screenshots", true);

    auto lua = make_lua_state();
    testing::expose_to_lua(lua, runtime);

    auto result = lua.safe_script(
        "local ok, err = test_harness.require({ min_test_api_version = '2.0.0', requires = { 'screenshots' } }) return ok, err");
    auto ok_obj = result.get<sol::object>(0);
    EXPECT_TRUE(ok_obj.is<bool>());
    EXPECT_TRUE(ok_obj.as<bool>());
}

TEST(TestHarnessLua, FrameHashStableForSameRegistry) {
    testing::TestRuntime runtime;
    ASSERT_TRUE(runtime.initialize(make_config()));

    auto lua = make_lua_state();
    testing::expose_to_lua(lua, runtime);

    auto first = lua.safe_script("return test_harness.frame_hash()");
    ASSERT_TRUE(first.valid());
    const auto hash1 = first.get<std::string>();

    auto second = lua.safe_script("return test_harness.frame_hash()");
    ASSERT_TRUE(second.valid());
    const auto hash2 = second.get<std::string>();

    EXPECT_EQ(hash1, hash2);
}

TEST(TestHarnessLua, FrameHashChangesWhenRegistryChanges) {
    testing::TestRuntime runtime;
    ASSERT_TRUE(runtime.initialize(make_config()));

    auto lua = make_lua_state();
    testing::expose_to_lua(lua, runtime);

    auto first = lua.safe_script("return test_harness.frame_hash()");
    ASSERT_TRUE(first.valid());
    const auto hash1 = first.get<std::string>();

    runtime.api_registry().register_capability("screenshots", true);

    auto second = lua.safe_script("return test_harness.frame_hash()");
    ASSERT_TRUE(second.valid());
    const auto hash2 = second.get<std::string>();

    EXPECT_NE(hash1, hash2);
}

TEST(TestHarnessLua, FrameHashRenderHashRequiresCapability) {
    testing::TestRuntime runtime;
    ASSERT_TRUE(runtime.initialize(make_config()));

    auto lua = make_lua_state();
    testing::expose_to_lua(lua, runtime);

    auto result = lua.safe_script(
        "local ok, err = test_harness.frame_hash('render_hash') return ok, err");
    ASSERT_TRUE(result.valid());
    auto ok_obj = result.get<sol::object>(0);
    auto err_obj = result.get<sol::object>(1);
    EXPECT_TRUE(ok_obj.is<sol::lua_nil_t>());
    EXPECT_TRUE(err_obj.is<std::string>());
    EXPECT_NE(err_obj.as<std::string>().find("capability_missing"), std::string::npos);
}

TEST(TestHarnessLua, DeterminismViolationsSurfaceNet) {
    testing::TestRuntime runtime;
    auto config = make_config();
    config.determinism_violation = testing::DeterminismViolationMode::Warn;
    ASSERT_TRUE(runtime.initialize(config));

    auto lua = make_lua_state();
    testing::expose_to_lua(lua, runtime);

    sol::function get_violations = lua["test_harness"]["get_determinism_violations"];
    sol::table empty = get_violations();
    int count = 0;
    for (auto& entry : empty) {
        (void)entry;
        ++count;
    }
    EXPECT_EQ(count, 0);

    runtime.determinism_guard().check_network_access("http://example.com");

    sol::table violations = get_violations();
    sol::table first = violations[1];
    EXPECT_TRUE(first.valid());
    EXPECT_EQ(first.get<std::string>("code"), "DET_NET");
}
