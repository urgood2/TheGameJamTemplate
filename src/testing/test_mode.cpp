#include "testing/test_mode.hpp"

#include <cfenv>
#include <clocale>
#include <cstdlib>
#include <filesystem>

#if defined(__SSE2__) || defined(_M_X64) || (defined(_M_IX86_FP) && _M_IX86_FP >= 2)
#include <xmmintrin.h>
#endif

#include "raylib.h"
#include "sol/sol.hpp"
#include "spdlog/spdlog.h"

#include "core/globals.hpp"
#include "systems/ai/ai_system.hpp"
#include "systems/lockstep/lockstep_config.hpp"
#include "systems/main_loop_enhancement/main_loop.hpp"
#include "systems/random/random.hpp"
#include "systems/sound/sound_system.hpp"
#include "testing/test_harness_lua.hpp"
#include "testing/test_mode_config.hpp"
#include "testing/test_runtime.hpp"
#include "testing/lua_sandbox.hpp"
#include "util/utilities.hpp"

namespace testing {

namespace {
bool g_test_mode_enabled = false;
TestMode* g_active_test_mode = nullptr;
}

namespace {

void pin_fp_environment() {
    std::fesetround(FE_TONEAREST);
#if defined(__SSE2__) || defined(_M_X64) || (defined(_M_IX86_FP) && _M_IX86_FP >= 2)
    _MM_SET_FLUSH_ZERO_MODE(_MM_FLUSH_ZERO_ON);
#if defined(_MM_DENORMALS_ZERO_ON)
    _MM_SET_DENORMALS_ZERO_MODE(_MM_DENORMALS_ZERO_ON);
#endif
#endif
}

void pin_process_environment() {
    std::setlocale(LC_ALL, "C");
#if defined(_WIN32)
    _putenv_s("TZ", "UTC");
    _tzset();
#else
    setenv("TZ", "UTC", 1);
    tzset();
#endif
}

std::filesystem::path resolve_script_path(const std::string& raw_path) {
    if (raw_path.empty()) {
        return {};
    }

    std::filesystem::path path(raw_path);
    if (path.is_absolute() && std::filesystem::exists(path)) {
        return path;
    }
    if (std::filesystem::exists(path)) {
        return path;
    }

    const std::string assets_path = util::getRawAssetPathNoUUID(raw_path);
    if (!assets_path.empty() && std::filesystem::exists(assets_path)) {
        return std::filesystem::path(assets_path);
    }

    const std::string scripts_path = util::getRawAssetPathNoUUID("scripts/" + raw_path);
    if (!scripts_path.empty() && std::filesystem::exists(scripts_path)) {
        return std::filesystem::path(scripts_path);
    }

    return path;
}

float get_timer_real_value() {
#if defined(UNIT_TESTS)
    return 0.0f;
#else
    return globals::getTimerReal();
#endif
}

float get_timer_total_value() {
#if defined(UNIT_TESTS)
    return 0.0f;
#else
    return globals::getTimerTotal();
#endif
}

long get_frames_move_value() {
#if defined(UNIT_TESTS)
    return 0;
#else
    return globals::getFramesMove();
#endif
}

void set_timer_real_value(float value) {
#if !defined(UNIT_TESTS)
    globals::getTimerReal() = value;
#else
    (void)value;
#endif
}

void set_timer_total_value(float value) {
#if !defined(UNIT_TESTS)
    globals::getTimerTotal() = value;
#else
    (void)value;
#endif
}

void set_frames_move_value(long value) {
#if !defined(UNIT_TESTS)
    globals::getFramesMove() = value;
#else
    (void)value;
#endif
}

bool deterministic_rng_enabled() {
#if defined(UNIT_TESTS)
    return false;
#else
    return lockstep::useDeterministicRng();
#endif
}

lockstep::DeterministicRng::State get_rng_state_value() {
#if defined(UNIT_TESTS)
    return {};
#else
    return lockstep::g_deterministicRng.get_state();
#endif
}

void set_rng_state_value(const lockstep::DeterministicRng::State& state) {
#if !defined(UNIT_TESTS)
    lockstep::g_deterministicRng.set_state(state);
#else
    (void)state;
#endif
}

sol::object resolve_save_manager(sol::state_view& lua) {
    sol::object save_manager = lua["SaveManager"];
    if (save_manager.valid() && save_manager.get_type() == sol::type::table) {
        return save_manager;
    }

    sol::object require_fn = lua["require"];
    if (require_fn.valid() && require_fn.get_type() == sol::type::function) {
        sol::protected_function require = require_fn;
        sol::protected_function_result result = require("core.save_manager");
        if (result.valid()) {
            sol::object loaded = result;
            if (loaded.valid() && loaded.get_type() == sol::type::table) {
                return loaded;
            }
        }
    }

    return sol::lua_nil;
}

} // namespace

bool TestMode::initialize(const TestModeConfig& config) {
    config_ = config;
    complete_ = false;
    exit_code_ = 0;
    start_frame_ = 0;
    last_frame_ = 0;
    snapshots_.clear();

    runtime_ = std::make_unique<TestRuntime>();
    if (!runtime_->initialize(config_)) {
        SPDLOG_ERROR("[test_mode] runtime initialization failed");
        return false;
    }

    if (runtime_) {
        auto& api = runtime_->api_registry();
        const bool screenshots_available = (config_.renderer != RendererMode::Null);
        api.register_capability("screenshots", screenshots_available);
        api.register_capability("snapshot", true);
        api.register_capability("determinism", true);
        api.register_capability("headless", config_.headless);
        api.register_capability("render_hash", config_.renderer != RendererMode::Null);
        SPDLOG_INFO("[capabilities] screenshots={} headless={} render_hash={}",
                    screenshots_available,
                    config_.headless,
                    config_.renderer != RendererMode::Null);
    }

    lua_state_ = &ai_system::masterStateLua;
    if (lua_state_) {
        expose_to_lua(*lua_state_, *runtime_);
        lua_sandbox_.initialize(lua_state_->lua_state(), config_);
    }

    g_test_mode_enabled = true;
    g_active_test_mode = this;
    on_engine_start();
    return true;
}

TestMode::~TestMode() = default;

void TestMode::shutdown() {
    if (runtime_) {
        runtime_->shutdown();
    }
    runtime_.reset();
    coroutine_.reset();
    coroutine_thread_.reset();
    snapshots_.clear();
    lua_state_ = nullptr;
    g_test_mode_enabled = false;
    if (g_active_test_mode == this) {
        g_active_test_mode = nullptr;
    }
}

void TestMode::on_engine_start() {
    apply_determinism_settings();
    start_time_ = std::chrono::steady_clock::now();
    start_frame_ = 0;
    last_frame_ = 0;
    create_test_coroutine();
}

void TestMode::on_frame_begin(int frame_number) {
    if (!runtime_ || complete_) {
        return;
    }
    if (start_frame_ == 0) {
        start_frame_ = frame_number;
    }
    last_frame_ = frame_number;
    lua_sandbox_.update_frame(frame_number);
    runtime_->on_frame_start(frame_number);
    check_watchdogs(frame_number);
}

void TestMode::update() {
    if (!runtime_ || complete_) {
        return;
    }

    if (runtime_->wait_frames_remaining() == 0) {
        runtime_->resume_test_coroutine();
        resume_coroutine();
    }

    if (runtime_->exit_requested()) {
        request_exit(runtime_->exit_code());
    }
}

void TestMode::on_frame_end(int frame_number) {
    if (!runtime_) {
        return;
    }
    runtime_->on_frame_end(frame_number);
    if (complete_ && !runtime_->reports_written()) {
        runtime_->on_run_complete();
    }
}

bool TestMode::is_complete() const {
    return complete_;
}

int TestMode::get_exit_code() const {
    return exit_code_;
}

void TestMode::request_exit(int code) {
    if (complete_) {
        return;
    }
    exit_code_ = code;
    complete_ = true;
    if (runtime_) {
        runtime_->request_exit(code);
    }
}

bool TestMode::snapshot_create(const std::string& name) {
    std::string snapshot_name = name.empty() ? "default" : name;
    SnapshotData snapshot;
    snapshot.name = snapshot_name;
    snapshot.frame_number = last_frame_;
    snapshot.simulation_time = static_cast<double>(get_timer_total_value());
    snapshot.timer_real = get_timer_real_value();
    snapshot.timer_total = get_timer_total_value();
    snapshot.frames_move = get_frames_move_value();
    snapshot.created_at = std::chrono::steady_clock::now();

    if (deterministic_rng_enabled()) {
        snapshot.rng_state_valid = true;
        snapshot.rng_state = get_rng_state_value();
    }

    if (lua_state_) {
        sol::state_view lua(*lua_state_);
        sol::object save_manager = resolve_save_manager(lua);
        if (save_manager.valid() && save_manager.get_type() == sol::type::table) {
            sol::table save_table = save_manager;
            sol::protected_function collect = save_table["collect_all"];
            if (collect.valid()) {
                sol::protected_function_result result = collect();
                if (result.valid()) {
                    sol::object data = result;
                    if (data.valid() && data.get_type() == sol::type::table) {
                        snapshot.save_data = sol::make_reference(lua, data);
                        snapshot.save_data_valid = true;
                    }
                } else {
                    sol::error err = result;
                    SPDLOG_WARN("[test_mode] snapshot_create collect_all failed: {}", err.what());
                }
            }
        }
    }

    snapshots_[snapshot_name] = std::move(snapshot);
    SPDLOG_INFO("[test_mode] snapshot_create {}", snapshot_name);
    return true;
}

bool TestMode::snapshot_restore(const std::string& name) {
    std::string snapshot_name = name.empty() ? "default" : name;
    auto it = snapshots_.find(snapshot_name);
    if (it == snapshots_.end()) {
        return snapshot_create(snapshot_name);
    }

    const SnapshotData& snapshot = it->second;
    set_timer_real_value(snapshot.timer_real);
    set_timer_total_value(snapshot.timer_total);
    set_frames_move_value(snapshot.frames_move);
    last_frame_ = snapshot.frame_number;

    if (snapshot.rng_state_valid) {
        set_rng_state_value(snapshot.rng_state);
    }

    if (runtime_) {
        runtime_->request_wait_frames(0);
        runtime_->reset_for_snapshot();
        runtime_->input_provider().clear();
        runtime_->log_capture().clear();
        runtime_->forensics().clear();
        runtime_->determinism_guard().reset();
        runtime_->perf_tracker().clear();
        runtime_->timeline_writer().close();
    }

    if (snapshot.save_data_valid && lua_state_) {
        sol::state_view lua(*lua_state_);
        sol::object save_manager = resolve_save_manager(lua);
        if (save_manager.valid() && save_manager.get_type() == sol::type::table) {
            sol::table save_table = save_manager;
            sol::protected_function distribute = save_table["distribute_all"];
            if (distribute.valid()) {
                sol::protected_function_result result = distribute(snapshot.save_data);
                if (!result.valid()) {
                    sol::error err = result;
                    SPDLOG_WARN("[test_mode] snapshot_restore distribute_all failed: {}", err.what());
                }
            }
        }
    }

    SPDLOG_INFO("[test_mode] snapshot_restore {}", snapshot_name);
    return true;
}

bool TestMode::has_snapshot(const std::string& name) const {
    return snapshots_.find(name) != snapshots_.end();
}

void TestMode::snapshot_delete(const std::string& name) {
    snapshots_.erase(name);
}

TestRuntime* TestMode::runtime() {
    return runtime_.get();
}

void TestMode::apply_determinism_settings() {
    random_utils::set_seed(config_.seed);

    const float fixed_rate = 1.0f / static_cast<float>(config_.fixed_fps);
    main_loop::mainLoop.rate = fixed_rate;
    main_loop::mainLoop.framerate = static_cast<float>(config_.fixed_fps);
    SetTargetFPS(config_.fixed_fps);

    ClearWindowState(FLAG_VSYNC_HINT);

    if (config_.headless) {
        sound_system::SetVolume(0.0f);
    }

    pin_fp_environment();
    pin_process_environment();
}

bool TestMode::create_test_coroutine() {
    if (!lua_state_) {
        SPDLOG_ERROR("[test_mode] no lua state available");
        return false;
    }

    sol::state_view lua(*lua_state_);
    std::filesystem::path script_path;
    if (config_.test_script.has_value()) {
        script_path = resolve_script_path(*config_.test_script);
    } else {
        script_path = resolve_script_path("scripts/tests/framework/bootstrap.lua");
    }

    sol::load_result loaded = lua.load_file(script_path.string());
    if (!loaded.valid()) {
        sol::error err = loaded;
        SPDLOG_ERROR("[test_mode] failed to load script {}: {}", script_path.string(), err.what());
        request_exit(2);
        return false;
    }

    sol::protected_function fn = loaded;
    coroutine_thread_ = std::make_unique<sol::thread>(sol::thread::create(lua));
    sol::state_view thread_view = coroutine_thread_->state();
    thread_view["__test_mode_main"] = fn;
    sol::function thread_fn = thread_view["__test_mode_main"];
    coroutine_ = std::make_unique<sol::coroutine>(sol::coroutine{thread_fn});
    return true;
}

void TestMode::resume_coroutine() {
    if (!coroutine_ || !coroutine_->valid()) {
        if (!complete_) {
            request_exit(0);
        }
        return;
    }

    sol::coroutine& co = *coroutine_;
    sol::protected_function_result result = co();
    if (result.status() == sol::call_status::ok) {
        request_exit(runtime_ ? runtime_->exit_code() : 0);
        return;
    }
    if (result.status() == sol::call_status::yielded) {
        return;
    }

    sol::error err = result;
    SPDLOG_ERROR("[test_mode] coroutine error: {}", err.what());
    if (runtime_) {
        runtime_->forensics().record_event(std::string("coroutine_error:") + err.what());
        runtime_->forensics().capture_on_crash();
    }
    request_exit(4);
}

void TestMode::check_watchdogs(int frame_number) {
    if (complete_ || !runtime_) {
        return;
    }
    if (config_.default_test_timeout_frames > 0) {
        if (frame_number - start_frame_ > config_.default_test_timeout_frames) {
            runtime_->forensics().record_event("timeout:frame");
            runtime_->forensics().capture_on_timeout();
            request_exit(3);
            return;
        }
    }
    if (config_.timeout_seconds > 0) {
        auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(
            std::chrono::steady_clock::now() - start_time_);
        if (elapsed.count() >= config_.timeout_seconds) {
            runtime_->forensics().record_event("timeout:wall");
            runtime_->forensics().capture_on_timeout();
            request_exit(3);
        }
    }
}

bool is_test_mode_enabled() {
    return g_test_mode_enabled;
}

void set_test_mode_enabled(bool enabled) {
    g_test_mode_enabled = enabled;
}

TestMode* get_active_test_mode() {
    return g_active_test_mode;
}

} // namespace testing
