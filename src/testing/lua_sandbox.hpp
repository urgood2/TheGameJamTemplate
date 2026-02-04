#pragma once

#include <cstdint>
#include <random>
#include <string>
#include <vector>

struct lua_State;

namespace sol {
class state;
}

namespace testing {

struct TestModeConfig;

class LuaSandbox {
public:
    void initialize(lua_State* L, const TestModeConfig& config);
    void apply_sandbox(lua_State* L);
    void set_allowed_require_paths(const std::vector<std::string>& paths);
    void install_time_stubs(lua_State* L);
    void install_random_stubs(lua_State* L, uint32_t seed);
    void update_frame(int frame_number);

    void apply(sol::state& lua);
    bool is_enabled() const;
    void set_enabled(bool enabled);

private:
    bool is_path_allowed(const std::string& path) const;
    std::vector<std::string> allowed_paths_;
    int current_frame_ = 0;
    int fixed_fps_ = 60;
    uint32_t rng_seed_ = 0;
    std::mt19937 rng_;
    bool enabled_ = true;
};

} // namespace testing
