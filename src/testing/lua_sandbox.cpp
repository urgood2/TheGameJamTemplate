#include "lua_sandbox.hpp"

#include <algorithm>
#include <ctime>
#include <filesystem>
#include <string>

#include "sol/sol.hpp"
#include "testing/test_mode_config.hpp"

namespace testing {
namespace {

std::string build_package_path(const std::vector<std::string>& roots) {
    std::string joined;
    for (const auto& root : roots) {
        if (root.empty()) {
            continue;
        }
        if (!joined.empty()) {
            joined.push_back(';');
        }
        std::string normalized = root;
        if (!normalized.empty() && normalized.back() == '/') {
            normalized.pop_back();
        }
        joined += normalized + "/?.lua;" + normalized + "/?/init.lua";
    }
    return joined;
}

std::vector<std::string> default_allowed_roots() {
    const auto root = std::filesystem::current_path();
    std::vector<std::string> paths;
    paths.push_back((root / "assets" / "scripts" / "tests" / "framework").generic_string());
    paths.push_back((root / "assets" / "scripts" / "tests" / "e2e").generic_string());
    paths.push_back((root / "assets" / "scripts" / "tests" / "fixtures").generic_string());
    return paths;
}

bool is_module_name_allowed(const std::string& name) {
    if (name.empty()) {
        return false;
    }
    if (name.find("..") != std::string::npos) {
        return false;
    }
    if (name.find('/') != std::string::npos || name.find('\\') != std::string::npos) {
        return false;
    }
    if (name.find(':') != std::string::npos) {
        return false;
    }
    return true;
}

bool is_subpath_under_root(const std::filesystem::path& candidate,
                           const std::filesystem::path& root) {
    auto cand_it = candidate.begin();
    for (auto root_it = root.begin(); root_it != root.end(); ++root_it, ++cand_it) {
        if (cand_it == candidate.end() || *cand_it != *root_it) {
            return false;
        }
    }
    return true;
}

} // namespace

void LuaSandbox::initialize(lua_State* L, const TestModeConfig& config) {
    enabled_ = (config.lua_sandbox == LuaSandboxMode::On);
    fixed_fps_ = config.fixed_fps > 0 ? config.fixed_fps : 60;
    rng_seed_ = config.seed;
    rng_.seed(rng_seed_);
    current_frame_ = 0;

    allowed_paths_ = default_allowed_roots();
    const auto add_path = [this](const std::filesystem::path& path) {
        if (path.empty()) {
            return;
        }
        const auto value = path.generic_string();
        if (std::find(allowed_paths_.begin(), allowed_paths_.end(), value) == allowed_paths_.end()) {
            allowed_paths_.push_back(value);
        }
    };

    if (config.test_script && !config.test_script->empty()) {
        add_path(std::filesystem::path(*config.test_script).parent_path());
    }
    if (config.test_suite && !config.test_suite->empty()) {
        add_path(std::filesystem::path(*config.test_suite));
    }
    if (!config.run_root.empty()) {
        add_path(config.run_root);
    }

    if (enabled_ && L) {
        apply_sandbox(L);
    }
}

void LuaSandbox::apply_sandbox(lua_State* L) {
    if (!enabled_ || L == nullptr) {
        return;
    }

    sol::state_view lua(L);

    install_time_stubs(L);
    install_random_stubs(L, rng_seed_);

    sol::table os = lua["os"];
    if (!os.valid()) {
        os = lua.create_table();
    }
    os.set_function("execute", []() -> void { throw sol::error("os.execute disabled in test mode"); });
    lua["os"] = os;

    sol::table io = lua["io"];
    if (!io.valid()) {
        io = lua.create_table();
    }
    sol::function original_open = io["open"];
    io.set_function("open", [this, original_open](sol::this_state ts,
                                                  const std::string& path,
                                                  sol::optional<std::string> mode) -> sol::variadic_results {
        sol::state_view lua_view(ts);
        if (!this->is_path_allowed(path)) {
            sol::variadic_results results;
            results.push_back(sol::make_object(lua_view, sol::nil));
            results.push_back(sol::make_object(lua_view, "path blocked by lua sandbox"));
            return results;
        }
        if (original_open.valid()) {
            if (mode.has_value()) {
                return sol::variadic_results{original_open(path, mode.value())};
            }
            return sol::variadic_results{original_open(path)};
        }
        sol::variadic_results results;
        results.push_back(sol::make_object(lua_view, sol::nil));
        results.push_back(sol::make_object(lua_view, "io.open unavailable"));
        return results;
    });
    io.set_function("popen", []() -> void { throw sol::error("io.popen disabled in test mode"); });
    lua["io"] = io;

    sol::table package = lua["package"];
    if (package.valid()) {
        const std::string path = build_package_path(allowed_paths_);
        if (!path.empty()) {
            package["path"] = path;
        } else {
            package["path"] = "";
        }
        package["cpath"] = "";
        sol::table searchers = package["searchers"];
        if (searchers.valid()) {
            sol::table new_searchers = lua.create_table();
            if (searchers[1].valid()) {
                new_searchers[1] = searchers[1];
            }
            if (searchers[2].valid()) {
                new_searchers[2] = searchers[2];
            }
            package["searchers"] = new_searchers;
        }
        lua["package"] = package;
    }

    sol::function original_require = lua["require"];
    lua.set_function("require", [this, original_require](sol::this_state ts, const std::string& name) -> sol::object {
        if (!is_module_name_allowed(name)) {
            throw sol::error("require blocked by lua sandbox: " + name);
        }
        sol::state_view lua_view(ts);
        sol::table package = lua_view["package"];
        sol::function searchpath = package["searchpath"];
        if (searchpath.valid()) {
            sol::protected_function_result search_result = searchpath(name, package["path"]);
            if (!search_result.valid()) {
                sol::error err = search_result;
                throw err;
            }
            sol::object resolved = search_result.get<sol::object>();
            if (resolved == sol::nil) {
                throw sol::error("require blocked by lua sandbox: " + name);
            }
            if (resolved.is<std::string>()) {
                if (!is_path_allowed(resolved.as<std::string>())) {
                    throw sol::error("require blocked by lua sandbox: " + name);
                }
            }
        }
        if (original_require.valid()) {
            return original_require(name);
        }
        throw sol::error("require unavailable in lua sandbox");
    });
}

void LuaSandbox::set_allowed_require_paths(const std::vector<std::string>& paths) {
    allowed_paths_.clear();
    for (const auto& path : paths) {
        if (path.empty()) {
            continue;
        }
        if (std::find(allowed_paths_.begin(), allowed_paths_.end(), path) == allowed_paths_.end()) {
            allowed_paths_.push_back(path);
        }
    }
}

void LuaSandbox::install_time_stubs(lua_State* L) {
    if (!enabled_ || L == nullptr) {
        return;
    }

    sol::state_view lua(L);
    sol::table os = lua["os"];
    if (!os.valid()) {
        os = lua.create_table();
    }
    os.set_function("time", [this]() -> lua_Integer {
        const double seconds = fixed_fps_ > 0 ? static_cast<double>(current_frame_) / fixed_fps_ : 0.0;
        return static_cast<lua_Integer>(seconds);
    });
    os.set_function("clock", [this]() -> double {
        return fixed_fps_ > 0 ? static_cast<double>(current_frame_) / fixed_fps_ : 0.0;
    });
    os.set_function("difftime", [](lua_Number t2, lua_Number t1) -> lua_Number { return t2 - t1; });
    lua["os"] = os;
}

void LuaSandbox::install_random_stubs(lua_State* L, uint32_t seed) {
    if (!enabled_ || L == nullptr) {
        return;
    }

    rng_seed_ = seed;
    rng_.seed(rng_seed_);

    sol::state_view lua(L);
    sol::table math = lua["math"];
    if (!math.valid()) {
        math = lua.create_table();
    }

    math.set_function("random", [this](sol::variadic_args args, sol::this_state state) -> sol::object {
        sol::state_view lua_view(state);
        if (args.size() == 0) {
            std::uniform_real_distribution<double> dist(0.0, 1.0);
            return sol::make_object(lua_view, dist(rng_));
        }

        lua_Integer lower = 1;
        lua_Integer upper = args.get<lua_Integer>(0);
        if (args.size() >= 2) {
            lower = args.get<lua_Integer>(0);
            upper = args.get<lua_Integer>(1);
        }
        if (args.size() == 1 && upper <= 0) {
            throw sol::error("math.random upper bound must be positive");
        }
        if (upper < lower) {
            throw sol::error("math.random interval is empty");
        }

        std::uniform_int_distribution<lua_Integer> dist(lower, upper);
        return sol::make_object(lua_view, dist(rng_));
    });

    math.set_function("randomseed", [](sol::variadic_args) -> void {});
    lua["math"] = math;
}

void LuaSandbox::update_frame(int frame_number) {
    current_frame_ = std::max(0, frame_number);
}

void LuaSandbox::apply(sol::state& lua) {
    apply_sandbox(lua.lua_state());
}

bool LuaSandbox::is_enabled() const {
    return enabled_;
}

void LuaSandbox::set_enabled(bool enabled) {
    enabled_ = enabled;
}

bool LuaSandbox::is_path_allowed(const std::string& path) const {
    if (allowed_paths_.empty() || path.empty()) {
        return false;
    }
    std::error_code ec;
    auto absolute = std::filesystem::absolute(std::filesystem::path(path), ec);
    if (ec) {
        return false;
    }
    auto normalized = absolute.lexically_normal();

    for (const auto& root_str : allowed_paths_) {
        if (root_str.empty()) {
            continue;
        }
        auto root_abs = std::filesystem::absolute(std::filesystem::path(root_str), ec);
        if (ec) {
            continue;
        }
        auto root_norm = root_abs.lexically_normal();
        if (is_subpath_under_root(normalized, root_norm)) {
            return true;
        }
    }

    return false;
}

} // namespace testing
