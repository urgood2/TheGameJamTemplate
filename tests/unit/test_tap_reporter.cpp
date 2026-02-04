#include <gtest/gtest.h>

#include <filesystem>
#include <fstream>
#include <sstream>
#include <string>

#include "sol/sol.hpp"

namespace {

std::filesystem::path make_temp_root() {
    auto root = std::filesystem::temp_directory_path() / "tap_reporter_tests";
    std::filesystem::create_directories(root);
    return root;
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
    std::string base = ASSETS_PATH;
    lua["package"]["path"] = base + "scripts/?.lua;" +
        base + "scripts/tests/?.lua;" +
        base + "scripts/tests/framework/?.lua;" +
        lua["package"]["path"].get<std::string>();
    return lua;
}

std::string read_file(const std::filesystem::path& path) {
    std::ifstream stream(path);
    std::ostringstream buffer;
    buffer << stream.rdbuf();
    return buffer.str();
}

sol::table require_tap(sol::state& lua) {
    sol::function require = lua["require"];
    return require("tests.framework.reporters.tap");
}

} // namespace

TEST(TapReporter, WritesVersionAndPlan) {
    auto lua = make_lua_state();
    auto tap = require_tap(lua);

    sol::table report = lua.create_table();
    sol::table tests = lua.create_table();

    sol::table t1 = lua.create_table();
    t1["name"] = "menu_test::loads main menu";
    t1["status"] = "pass";
    tests[1] = t1;

    sol::table t2 = lua.create_table();
    t2["name"] = "menu_test::navigation fails";
    t2["status"] = "fail";
    t2["message"] = "bad nav";
    tests[2] = t2;

    report["tests"] = tests;

    auto path = make_temp_root() / "tap_basic.txt";
    tap["write"](report, path.string());

    const auto output = read_file(path);
    EXPECT_NE(output.find("TAP version 14"), std::string::npos);
    EXPECT_NE(output.find("1..2"), std::string::npos);
    EXPECT_NE(output.find("ok 1 - menu_test::loads main menu"), std::string::npos);
    EXPECT_NE(output.find("not ok 2 - menu_test::navigation fails"), std::string::npos);
}

TEST(TapReporter, WritesDirectives) {
    auto lua = make_lua_state();
    auto tap = require_tap(lua);

    sol::table report = lua.create_table();
    sol::table tests = lua.create_table();

    sol::table t1 = lua.create_table();
    t1["name"] = "combat.basic";
    t1["status"] = "skipped";
    t1["skip_reason"] = "Not implemented yet";
    tests[1] = t1;

    sol::table t2 = lua.create_table();
    t2["name"] = "menu.flaky";
    t2["status"] = "flaky";
    t2["todo_reason"] = "Intermittent";
    t2["message"] = "flaky behavior";
    tests[2] = t2;

    report["tests"] = tests;

    auto path = make_temp_root() / "tap_directives.txt";
    tap["write"](report, path.string());

    const auto output = read_file(path);
    EXPECT_NE(output.find("ok 1 - combat.basic # SKIP Not implemented yet"), std::string::npos);
    EXPECT_NE(output.find("not ok 2 - menu.flaky # TODO Intermittent"), std::string::npos);
}

TEST(TapReporter, WritesDiagnostics) {
    auto lua = make_lua_state();
    auto tap = require_tap(lua);

    sol::table report = lua.create_table();
    sol::table tests = lua.create_table();

    sol::table t1 = lua.create_table();
    t1["name"] = "ui.snapshot";
    t1["status"] = "fail";
    t1["message"] = "line one\nline two";
    t1["failure_kind"] = "assertion";
    tests[1] = t1;

    report["tests"] = tests;

    auto path = make_temp_root() / "tap_diag.txt";
    tap["write"](report, path.string());

    const auto output = read_file(path);
    EXPECT_NE(output.find("  ---"), std::string::npos);
    EXPECT_NE(output.find("  failure_kind: assertion"), std::string::npos);
    EXPECT_NE(output.find("  message: |"), std::string::npos);
    EXPECT_NE(output.find("    line one"), std::string::npos);
    EXPECT_NE(output.find("    line two"), std::string::npos);
    EXPECT_NE(output.find("  ..."), std::string::npos);
}

TEST(TapReporter, EmptySuitePlan) {
    auto lua = make_lua_state();
    auto tap = require_tap(lua);

    sol::table report = lua.create_table();
    report["tests"] = lua.create_table();

    auto path = make_temp_root() / "tap_empty.txt";
    tap["write"](report, path.string());

    const auto output = read_file(path);
    EXPECT_NE(output.find("1..0"), std::string::npos);
}

