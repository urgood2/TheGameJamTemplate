#include "testing/test_harness_lua.hpp"

#include <algorithm>
#include <string>
#include <tuple>
#include <vector>

#include "sol/sol.hpp"
#include "spdlog/spdlog.h"
#include "testing/sha256.hpp"
#include "testing/test_mode.hpp"
#include "testing/test_runtime.hpp"

namespace {

std::string network_mode_label(testing::NetworkMode mode) {
    switch (mode) {
        case testing::NetworkMode::Deny:
            return "deny";
        case testing::NetworkMode::Localhost:
            return "localhost";
        case testing::NetworkMode::Any:
            return "any";
    }
    return "deny";
}

const char* determinism_code_label(testing::DeterminismCode code) {
    switch (code) {
        case testing::DeterminismCode::DET_TIME:
            return "DET_TIME";
        case testing::DeterminismCode::DET_RNG:
            return "DET_RNG";
        case testing::DeterminismCode::DET_FS_ORDER:
            return "DET_FS_ORDER";
        case testing::DeterminismCode::DET_ASYNC_ORDER:
            return "DET_ASYNC_ORDER";
        case testing::DeterminismCode::DET_NET:
            return "DET_NET";
    }
    return "DET_UNKNOWN";
}

std::string rng_scope_label(testing::RngScope scope) {
    switch (scope) {
        case testing::RngScope::Run:
            return "run";
        case testing::RngScope::Test:
        default:
            return "test";
    }
}

std::vector<int> parse_semver(const std::string& value) {
    std::vector<int> parts;
    size_t start = 0;
    while (start < value.size()) {
        size_t end = value.find('.', start);
        if (end == std::string::npos) {
            end = value.size();
        }
        const std::string token = value.substr(start, end - start);
        try {
            parts.push_back(std::stoi(token));
        } catch (...) {
            parts.push_back(0);
        }
        start = end + 1;
    }
    while (parts.size() < 3) {
        parts.push_back(0);
    }
    return parts;
}

int compare_semver(const std::string& left, const std::string& right) {
    const auto left_parts = parse_semver(left);
    const auto right_parts = parse_semver(right);
    for (size_t i = 0; i < 3; ++i) {
        if (left_parts[i] < right_parts[i]) {
            return -1;
        }
        if (left_parts[i] > right_parts[i]) {
            return 1;
        }
    }
    return 0;
}

void populate_string_list(sol::table table, const std::vector<std::string>& values) {
    int index = 1;
    for (const auto& entry : values) {
        table[index++] = entry;
    }
}

sol::table build_capabilities(sol::state& lua, const testing::TestRuntime& runtime) {
    sol::table capabilities = lua.create_table();
    const std::vector<std::string> known_caps = {
        "screenshots",
        "input",
        "state",
        "logs",
        "perf",
        "snapshot",
        "determinism",
        "render_hash",
        "gamepad",
        "attachments",
        "steps"};

    const auto registered = runtime.api_registry().get_all_capabilities();
    for (const auto& cap : known_caps) {
        auto it = registered.find(cap);
        const bool available = (it != registered.end()) ? it->second : false;
        capabilities[cap] = available;
    }
    for (const auto& pair : registered) {
        capabilities[pair.first] = pair.second;
    }
    return capabilities;
}

void set_readonly(sol::state& lua, sol::table table, const std::string& label) {
    sol::table meta = lua.create_table();
    meta["__newindex"] = [label](sol::this_state) { throw sol::error(label + " is read-only"); };
    meta["__metatable"] = false;
    table[sol::metatable_key] = meta;
}

void install_placeholder(sol::table harness,
                         const std::string& name,
                         const std::string& capability,
                         bool is_assertion = false) {
    if (harness[name].valid()) {
        return;
    }
    if (is_assertion) {
        harness.set_function(name, [capability](sol::variadic_args) {
            throw sol::error("harness_error:assertion_missing:" + capability);
        });
        return;
    }
    harness.set_function(name, [capability](sol::variadic_args) -> std::tuple<sol::lua_nil_t, std::string> {
        return {sol::lua_nil, "capability_missing:" + capability};
    });
}

testing::TestRuntime* runtime_from_upvalue(lua_State* L) {
    auto* runtime = static_cast<testing::TestRuntime*>(lua_touserdata(L, lua_upvalueindex(1)));
    if (runtime == nullptr) {
        luaL_error(L, "harness_error:runtime_missing");
        return nullptr;
    }
    return runtime;
}

bool parse_log_level(const std::string& level, int& out) {
    std::string norm;
    norm.reserve(level.size());
    for (char ch : level) {
        if (ch >= 'A' && ch <= 'Z') {
            norm.push_back(static_cast<char>(ch - 'A' + 'a'));
        } else if (ch != ' ' && ch != '\t') {
            norm.push_back(ch);
        }
    }
    if (norm == "trace") {
        out = 0;
        return true;
    }
    if (norm == "debug") {
        out = 1;
        return true;
    }
    if (norm == "info") {
        out = 2;
        return true;
    }
    if (norm == "warn" || norm == "warning") {
        out = 3;
        return true;
    }
    if (norm == "error") {
        out = 4;
        return true;
    }
    if (norm == "critical" || norm == "fatal") {
        out = 5;
        return true;
    }
    return false;
}

bool match_log_level(const std::string& entry_level, const std::string& expected) {
    int expected_value = 0;
    if (!parse_log_level(expected, expected_value)) {
        return false;
    }
    int entry_value = 0;
    if (!parse_log_level(entry_level, entry_value)) {
        return false;
    }
    return entry_value >= expected_value;
}

bool string_contains(const std::string& haystack, const std::string& needle) {
    if (needle.empty()) {
        return true;
    }
    return haystack.find(needle) != std::string::npos;
}

int wait_frames_c(lua_State* L) {
    auto* runtime = runtime_from_upvalue(L);
    if (runtime == nullptr) {
        return 0;
    }
    const int frames = static_cast<int>(luaL_checkinteger(L, 1));
    if (frames < 0) {
        return luaL_error(L, "invalid_argument: wait_frames expects n >= 0");
    }
    runtime->request_wait_frames(frames);
    SPDLOG_DEBUG("test_harness wait_frames {}", frames);
    if (frames == 0) {
        return 0;
    }
    return lua_yield(L, 0);
}

int skip_c(lua_State* L) {
    auto* runtime = runtime_from_upvalue(L);
    if (runtime == nullptr) {
        return 0;
    }
    const char* reason = luaL_optstring(L, 1, "skipped");
    if (!runtime->has_active_test()) {
        lua_pushnil(L);
        lua_pushstring(L, "harness_error:skip outside test");
        return 2;
    }
    runtime->request_skip(reason);
    lua_pushboolean(L, 1);
    return 1;
}

int xfail_c(lua_State* L) {
    auto* runtime = runtime_from_upvalue(L);
    if (runtime == nullptr) {
        return 0;
    }
    const char* reason = luaL_optstring(L, 1, "xfail");
    if (!runtime->has_active_test()) {
        lua_pushnil(L);
        lua_pushstring(L, "harness_error:xfail outside test");
        return 2;
    }
    runtime->request_xfail(reason);
    lua_pushboolean(L, 1);
    return 1;
}

int require_c(lua_State* L) {
    auto* runtime = runtime_from_upvalue(L);
    if (runtime == nullptr) {
        return 0;
    }
    if (lua_gettop(L) < 1 || lua_isnil(L, 1)) {
        lua_pushboolean(L, 1);
        return 1;
    }
    if (!lua_istable(L, 1)) {
        return luaL_error(L, "invalid_argument: require expects table");
    }

    sol::state_view lua(L);
    sol::table opts = sol::stack::get<sol::table>(L, 1);
    const std::string min_version = opts.get_or("min_test_api_version", std::string());
    if (!min_version.empty()) {
        const std::string have_version = runtime->api_registry().get_version();
        if (compare_semver(have_version, min_version) < 0) {
            const std::string error = "version_too_low:" + have_version + " " + min_version;
            lua_pushnil(L);
            lua_pushstring(L, error.c_str());
            SPDLOG_WARN("test_harness require failed: version {} < {}", have_version, min_version);
            return 2;
        }
    }

    sol::object requires_obj = opts["requires"];
    if (requires_obj.is<sol::table>()) {
        sol::table requires_table = requires_obj.as<sol::table>();
        for (auto& entry : requires_table) {
            sol::object value = entry.second;
            if (!value.is<std::string>()) {
                continue;
            }
            const std::string cap = value.as<std::string>();
            if (!runtime->api_registry().has_capability(cap)) {
                const std::string error = "capability_missing:" + cap;
                lua_pushnil(L);
                lua_pushstring(L, error.c_str());
                SPDLOG_WARN("test_harness require failed: missing {}", cap);
                return 2;
            }
        }
    }

    lua_pushboolean(L, 1);
    return 1;
}

std::string build_frame_hash_payload(const testing::TestRuntime& runtime, const std::string& scope) {
    std::string payload;
    payload.reserve(128);
    payload.append("scope=");
    payload.append(scope);
    payload.push_back('\n');
    payload.append("frame=");
    payload.append(std::to_string(runtime.current_frame()));
    payload.push_back('\n');
    payload.append("test_api_fingerprint=");
    payload.append(runtime.api_registry().compute_fingerprint());
    payload.push_back('\n');
    if (scope == "render_hash") {
        payload.append("render_hash=stub");
        payload.push_back('\n');
    }
    return payload;
}

int frame_hash_c(lua_State* L) {
    auto* runtime = runtime_from_upvalue(L);
    if (runtime == nullptr) {
        return 0;
    }
    const char* scope_cstr = luaL_optstring(L, 1, "test_api");
    std::string scope = scope_cstr ? scope_cstr : "test_api";
    if (scope != "test_api" && scope != "engine" && scope != "render_hash") {
        const std::string error = "invalid_argument: unknown scope " + scope;
        lua_pushnil(L);
        lua_pushstring(L, error.c_str());
        return 2;
    }
    if (scope == "render_hash" && !runtime->api_registry().has_capability("render_hash")) {
        lua_pushnil(L);
        lua_pushstring(L, "capability_missing:render_hash");
        return 2;
    }

    const std::string payload = build_frame_hash_payload(*runtime, scope);
    const std::string hash = testing::sha256_hex(payload);
    SPDLOG_DEBUG("[determinism] frame_hash scope={} frame={}", scope, runtime->current_frame());
    lua_pushstring(L, hash.c_str());
    return 1;
}

} // namespace

namespace testing {

void expose_to_lua(sol::state& lua, TestRuntime& runtime) {
    sol::object harness_obj = lua["test_harness"];
    sol::table harness = harness_obj.is<sol::table>() ? harness_obj.as<sol::table>()
                                                     : lua.create_table();

    const auto& config = runtime.config();

    sol::table args = lua.create_table();
    args["seed"] = config.seed;
    args["fixed_fps"] = config.fixed_fps;
    args["resolution_width"] = config.resolution_width;
    args["resolution_height"] = config.resolution_height;
    args["resolution"] = std::to_string(config.resolution_width) + "x" + std::to_string(config.resolution_height);
    args["headless"] = config.headless;
    args["run_id"] = config.run_id;
    args["run_root"] = config.run_root.generic_string();
    args["artifacts_dir"] = config.artifacts_dir.generic_string();
    args["baseline_key"] = config.baseline_key;
    args["update_baselines"] = config.update_baselines;
    args["fail_fast"] = config.fail_fast;
    args["max_failures"] = config.max_failures;
    args["shuffle_tests"] = config.shuffle_tests;
    args["shuffle_seed"] = config.shuffle_seed;
    args["rng_scope"] = rng_scope_label(config.rng_scope);
    args["default_test_timeout_frames"] = config.default_test_timeout_frames;
    args["run_quarantined"] = config.run_quarantined;
    args["timeout_seconds"] = config.timeout_seconds;
    args["retry_failures"] = config.retry_failures;
    args["allow_network"] = network_mode_label(config.allow_network);
    args["test_script"] = config.test_script.value_or("");
    args["test_suite"] = config.test_suite.value_or("");
    args["run_test_id"] = config.run_test_id.value_or("");
    args["run_test_exact"] = config.run_test_exact.value_or("");

    sol::table include_tags = lua.create_table();
    populate_string_list(include_tags, config.include_tags);
    args["include_tags"] = include_tags;

    sol::table exclude_tags = lua.create_table();
    populate_string_list(exclude_tags, config.exclude_tags);
    args["exclude_tags"] = exclude_tags;

    harness["args"] = args;

    sol::table capabilities = build_capabilities(lua, runtime);
    set_readonly(lua, capabilities, "capabilities");
    harness["capabilities"] = capabilities;

    harness["test_api_version"] = runtime.api_registry().get_version();

    harness.set_function("now_frame", [&runtime]() { return runtime.current_frame(); });

    harness.set_function("exit", [&runtime](int code) {
        runtime.request_exit(code);
        SPDLOG_INFO("test_harness exit {}", code);
    });

    harness.set_function("get_attempt", [&runtime]() { return runtime.current_attempt(); });

    harness.set_function("get_determinism_violations", [&runtime, &lua]() {
        sol::table out = lua.create_table();
        const auto violations = runtime.determinism_guard().get_violations();
        int index = 1;
        for (const auto& violation : violations) {
            sol::table entry = lua.create_table();
            entry["code"] = determinism_code_label(violation.code);
            entry["details"] = violation.details;
            entry["frame"] = violation.frame_number;
            entry["timestamp"] = violation.timestamp;
            if (violation.stack.has_value()) {
                sol::table stack = lua.create_table();
                int line_index = 1;
                for (const auto& line : *violation.stack) {
                    stack[line_index++] = line;
                }
                entry["stack"] = stack;
            }
            out[index++] = entry;
        }
        return out;
    });

    if (runtime.api_registry().has_capability("snapshot")) {
        harness.set_function("snapshot_create",
                             [](sol::this_state ts,
                                sol::optional<std::string> name) -> sol::variadic_results {
                                 sol::state_view lua_view(ts);
                                 sol::variadic_results results;
                                 auto* mode = testing::get_active_test_mode();
                                 if (!mode) {
                                     results.push_back(sol::make_object(lua_view, sol::nil));
                                     results.push_back(sol::make_object(lua_view, "harness_error:test_mode_missing"));
                                     return results;
                                 }
                                 const std::string snapshot_name = name.value_or("default");
                                 if (mode->snapshot_create(snapshot_name)) {
                                     results.push_back(sol::make_object(lua_view, true));
                                     return results;
                                 }
                                 results.push_back(sol::make_object(lua_view, sol::nil));
                                 results.push_back(sol::make_object(lua_view, "snapshot_error:create_failed"));
                                 return results;
                             });

        harness.set_function("snapshot_restore",
                             [](sol::this_state ts,
                                sol::optional<std::string> name) -> sol::variadic_results {
                                 sol::state_view lua_view(ts);
                                 sol::variadic_results results;
                                 auto* mode = testing::get_active_test_mode();
                                 if (!mode) {
                                     results.push_back(sol::make_object(lua_view, sol::nil));
                                     results.push_back(sol::make_object(lua_view, "harness_error:test_mode_missing"));
                                     return results;
                                 }
                                 const std::string snapshot_name = name.value_or("default");
                                 if (mode->snapshot_restore(snapshot_name)) {
                                     results.push_back(sol::make_object(lua_view, true));
                                     return results;
                                 }
                                 results.push_back(sol::make_object(lua_view, sol::nil));
                                 results.push_back(sol::make_object(lua_view, "snapshot_error:restore_failed"));
                                 return results;
                             });

        harness.set_function("snapshot_delete",
                             [](sol::optional<std::string> name) {
                                 auto* mode = testing::get_active_test_mode();
                                 if (!mode) {
                                     return false;
                                 }
                                 const std::string snapshot_name = name.value_or("default");
                                 mode->snapshot_delete(snapshot_name);
                                 return true;
                             });

        harness.set_function("has_snapshot",
                             [](sol::optional<std::string> name) {
                                 auto* mode = testing::get_active_test_mode();
                                 if (!mode) {
                                     return false;
                                 }
                                 const std::string snapshot_name = name.value_or("default");
                                 return mode->has_snapshot(snapshot_name);
                             });
    } else {
        install_placeholder(harness, "snapshot_create", "snapshot");
        install_placeholder(harness, "snapshot_restore", "snapshot");
    }

    install_placeholder(harness, "clear_inputs", "input");
    install_placeholder(harness, "reset_input_state", "input");
    install_placeholder(harness, "enqueue_input", "input");
    install_placeholder(harness, "press_key", "input");
    install_placeholder(harness, "release_key", "input");
    install_placeholder(harness, "move_mouse", "input");
    install_placeholder(harness, "click_mouse", "input");
    install_placeholder(harness, "record_input", "input");
    install_placeholder(harness, "stop_recording_input", "input");

    install_placeholder(harness, "log_mark", "logs");
    if (runtime.api_registry().has_capability("logs")) {
        harness.set_function("log_mark", [&runtime]() {
            const auto mark = runtime.log_capture().mark();
            SPDLOG_DEBUG("log_capture mark {}", mark);
            return static_cast<int>(mark);
        });

        harness.set_function("clear_logs", [&runtime]() {
            runtime.log_capture().clear();
            SPDLOG_DEBUG("log_capture cleared");
        });

        harness.set_function("find_log",
                             [&runtime](sol::this_state ts,
                                        const std::string& pattern,
                                        sol::optional<sol::table> opts) -> sol::variadic_results {
                                 sol::state_view lua_view(ts);
                                 FindOptions find_opts{};
                                 if (opts) {
                                     sol::table opts_table = *opts;
                                     find_opts.regex = opts_table.get_or("regex", false);
                                     find_opts.since = static_cast<LogMark>(opts_table.get_or("since", 0));
                                 }
                                 auto found = runtime.log_capture().find(pattern, find_opts);
                                 if (found) {
                                     const auto& entries = runtime.log_capture().entries();
                                     auto it = std::find_if(entries.begin(), entries.end(), [&](const LogEntry& entry) {
                                         return entry.message == found->message &&
                                                entry.category == found->category &&
                                                entry.level == found->level &&
                                                entry.frame == found->frame;
                                     });
                                     const int index = it != entries.end()
                                                           ? static_cast<int>(std::distance(entries.begin(), it))
                                                           : static_cast<int>(find_opts.since);
                                     sol::variadic_results results;
                                     results.push_back(sol::make_object(lua_view, true));
                                     results.push_back(sol::make_object(lua_view, index));
                                     results.push_back(sol::make_object(lua_view, found->message));
                                     SPDLOG_DEBUG("log_capture find match index={} since={}", index, find_opts.since);
                                     return results;
                                 }
                                 sol::variadic_results results;
                                 results.push_back(sol::make_object(lua_view, false));
                                 results.push_back(sol::make_object(lua_view, static_cast<int>(runtime.log_capture().size())));
                                 results.push_back(sol::make_object(lua_view, ""));
                                 SPDLOG_DEBUG("log_capture find no match since={}", find_opts.since);
                                 return results;
                             });

        harness.set_function("assert_no_log_level",
                             [&runtime](sol::this_state ts,
                                        const std::string& level,
                                        sol::optional<sol::table> opts) -> sol::variadic_results {
                                 sol::state_view lua_view(ts);
                                 int since = 0;
                                 if (opts) {
                                     sol::table opts_table = *opts;
                                     since = opts_table.get_or("since", 0);
                                 }
                                 if (since < 0) {
                                     since = 0;
                                 }
                                 if (runtime.log_capture().has_logs_at_level(level, static_cast<LogMark>(since))) {
                                     const auto& entries = runtime.log_capture().entries();
                                     size_t index = entries.size();
                                     for (size_t i = static_cast<size_t>(since); i < entries.size(); ++i) {
                                         if (match_log_level(entries[i].level, level)) {
                                             index = i;
                                             break;
                                         }
                                     }
                                     const std::string level_str = index < entries.size() ? entries[index].level : level;
                                     sol::variadic_results results;
                                     results.push_back(sol::make_object(lua_view, sol::nil));
                                     results.push_back(sol::make_object(
                                         lua_view,
                                         "log_gating: level " + level_str + " at index " + std::to_string(index)));
                                     SPDLOG_DEBUG("log_capture assert_no_log_level failed level={} index={}", level_str, index);
                                     return results;
                                 }
                                 sol::variadic_results results;
                                 results.push_back(sol::make_object(lua_view, true));
                                 SPDLOG_DEBUG("log_capture assert_no_log_level ok since={}", since);
                                 return results;
                             });
    } else {
        install_placeholder(harness, "log_mark", "logs");
        install_placeholder(harness, "find_log", "logs");
        install_placeholder(harness, "clear_logs", "logs");
        install_placeholder(harness, "assert_no_log_level", "logs", true);
    }

    install_placeholder(harness, "screenshot", "screenshots");
    install_placeholder(harness, "assert_screenshot", "screenshots", true);

    install_placeholder(harness, "attach_text", "attachments");
    install_placeholder(harness, "attach_file", "attachments");
    install_placeholder(harness, "attach_image", "attachments");

    install_placeholder(harness, "perf_mark", "perf");
    install_placeholder(harness, "perf_since", "perf");

    install_placeholder(harness, "get_state", "state");
    install_placeholder(harness, "set_state", "state");
    install_placeholder(harness, "query", "state");
    install_placeholder(harness, "command", "state");

    install_placeholder(harness, "frame_hash", "determinism");
    install_placeholder(harness, "assert_deterministic", "determinism", true);

    install_placeholder(harness, "step", "steps");
    install_placeholder(harness, "attach_step", "steps");

    lua["test_harness"] = harness;

    lua_State* L = lua.lua_state();
    lua_getglobal(L, "test_harness");
    if (lua_istable(L, -1)) {
        lua_pushlightuserdata(L, &runtime);
        lua_pushcclosure(L, &wait_frames_c, 1);
        lua_setfield(L, -2, "wait_frames");

        lua_pushlightuserdata(L, &runtime);
        lua_pushcclosure(L, &skip_c, 1);
        lua_setfield(L, -2, "skip");

        lua_pushlightuserdata(L, &runtime);
        lua_pushcclosure(L, &xfail_c, 1);
        lua_setfield(L, -2, "xfail");

        lua_pushlightuserdata(L, &runtime);
        lua_pushcclosure(L, &require_c, 1);
        lua_setfield(L, -2, "require");

        lua_pushlightuserdata(L, &runtime);
        lua_pushcclosure(L, &frame_hash_c, 1);
        lua_setfield(L, -2, "frame_hash");
    }
    lua_pop(L, 1);
}

} // namespace testing
