#pragma once

#include <cstdint>
#include <filesystem>
#include <optional>
#include <string>
#include <vector>

namespace testing {

enum class NetworkMode {
    Deny,
    Localhost,
    Any
};

enum class BaselineWriteMode {
    Deny,
    Stage,
    Apply
};

enum class FailureVideoMode {
    Off,
    On
};

enum class RngScope {
    Test,
    Run
};

enum class RendererMode {
    Null,
    Offscreen,
    Windowed
};

enum class DeterminismAuditScope {
    TestApi,
    Engine,
    RenderHash
};

enum class DeterminismViolationMode {
    Fatal,
    Warn
};

enum class IsolateTestsMode {
    None,
    ProcessPerFile,
    ProcessPerTest
};

enum class LuaSandboxMode {
    On,
    Off
};

enum class PerfMode {
    Off,
    Collect,
    Enforce
};

struct TestModeConfig {
    bool enabled = false;
    bool headless = false;
    std::optional<std::string> test_script;
    std::optional<std::string> test_suite;
    bool list_tests = false;
    std::optional<std::string> list_tests_json_path;
    std::string test_filter;
    std::optional<std::string> run_test_id;
    std::optional<std::string> run_test_exact;
    std::vector<std::string> include_tags;
    std::vector<std::string> exclude_tags;
    uint32_t seed = 12345;
    int fixed_fps = 60;
    int resolution_width = 1280;
    int resolution_height = 720;
    NetworkMode allow_network = NetworkMode::Deny;

    bool update_baselines = false;
    bool fail_on_missing_baseline = true;
    std::string baseline_key;
    BaselineWriteMode baseline_write_mode = BaselineWriteMode::Deny;
    std::filesystem::path baseline_staging_dir = std::filesystem::path("tests/baselines_staging");
    std::string baseline_approve_token;

    int shard = 1;
    int total_shards = 1;
    int timeout_seconds = 600;
    int default_test_timeout_frames = 1800;
    FailureVideoMode failure_video = FailureVideoMode::Off;
    int failure_video_frames = 180;

    int retry_failures = 0;
    bool allow_flaky = false;
    bool auto_audit_on_flake = false;
    bool flake_artifacts = true;

    bool run_quarantined = false;
    bool fail_fast = false;
    int max_failures = 0;
    bool shuffle_tests = false;
    uint32_t shuffle_seed = 0;
    std::filesystem::path test_manifest_path;

    RngScope rng_scope = RngScope::Test;
    RendererMode renderer = RendererMode::Offscreen;
    bool renderer_set = false;

    bool determinism_audit = false;
    int determinism_audit_runs = 2;
    DeterminismAuditScope determinism_audit_scope = DeterminismAuditScope::TestApi;
    DeterminismViolationMode determinism_violation = DeterminismViolationMode::Fatal;

    std::string fail_on_log_level;
    std::string fail_on_log_category;

    std::optional<std::filesystem::path> record_input_path;
    std::optional<std::filesystem::path> replay_input_path;

    IsolateTestsMode isolate_tests = IsolateTestsMode::None;
    LuaSandboxMode lua_sandbox = LuaSandboxMode::On;

    PerfMode perf_mode = PerfMode::Off;
    std::optional<std::filesystem::path> perf_budget_path;
    std::optional<std::filesystem::path> perf_trace_path;

    std::filesystem::path artifacts_dir;
    std::filesystem::path report_json_path;
    std::filesystem::path report_junit_path;
    std::filesystem::path run_root;
    std::filesystem::path forensics_dir;
    std::string run_id;
};

bool parse_test_mode_args(int argc, char** argv, TestModeConfig& out, std::string& err);
bool validate_and_finalize(TestModeConfig& config, std::string& err);
std::string test_mode_usage();

} // namespace testing
