#pragma once

#include <chrono>
#include <cstdint>
#include <memory>
#include <string>
#include <unordered_map>

#include "sol/sol.hpp"
#include "systems/lockstep/deterministic_rng.hpp"
#include "testing/lua_sandbox.hpp"
#include "testing/test_mode_config.hpp"
#include "testing/test_runtime.hpp"

namespace testing {

struct TestModeConfig;

struct SnapshotData {
    std::string name;
    int frame_number = 0;
    double simulation_time = 0.0;
    float timer_real = 0.0f;
    float timer_total = 0.0f;
    long frames_move = 0;
    bool rng_state_valid = false;
    lockstep::DeterministicRng::State rng_state{};
    bool save_data_valid = false;
    sol::reference save_data = sol::lua_nil;
    std::chrono::steady_clock::time_point created_at{};
};

class TestMode {
public:
    TestMode() = default;
    ~TestMode();
    bool initialize(const TestModeConfig& config);
    void shutdown();
    void on_engine_start();
    void on_frame_begin(int frame_number);
    void update();
    void on_frame_end(int frame_number);
    bool is_complete() const;
    int get_exit_code() const;
    void request_exit(int code);
    bool snapshot_create(const std::string& name);
    bool snapshot_restore(const std::string& name);
    bool has_snapshot(const std::string& name) const;
    void snapshot_delete(const std::string& name);
TestRuntime* runtime();

private:
    void apply_determinism_settings();
    bool create_test_coroutine();
    void resume_coroutine();
    void check_watchdogs(int frame_number);

    TestModeConfig config_;
    std::unique_ptr<TestRuntime> runtime_;
    sol::state* lua_state_ = nullptr;
    std::unique_ptr<sol::thread> coroutine_thread_;
    std::unique_ptr<sol::coroutine> coroutine_;
    LuaSandbox lua_sandbox_{};
    bool complete_ = false;
    int exit_code_ = 0;
    int start_frame_ = 0;
    int last_frame_ = 0;
    std::chrono::steady_clock::time_point start_time_{};
    std::unordered_map<std::string, SnapshotData> snapshots_;
};

bool is_test_mode_enabled();
void set_test_mode_enabled(bool enabled);
TestMode* get_active_test_mode();

} // namespace testing
