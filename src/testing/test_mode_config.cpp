#include "testing/test_mode_config.hpp"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cctype>
#include <ctime>
#include <iomanip>
#include <limits>
#include <sstream>

namespace testing {
namespace {
const TestModeConfig* g_active_test_config = nullptr;

std::string to_lower(std::string value) {
    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char ch) {
        return static_cast<char>(std::tolower(ch));
    });
    return value;
}

bool parse_bool_value(const std::string& value, bool& out) {
    const auto lowered = to_lower(value);
    if (lowered == "1" || lowered == "true" || lowered == "yes" || lowered == "on") {
        out = true;
        return true;
    }
    if (lowered == "0" || lowered == "false" || lowered == "no" || lowered == "off") {
        out = false;
        return true;
    }
    return false;
}

bool parse_bool_flag(const std::optional<std::string>& value, bool& out, std::string& error,
                     const std::string& flag) {
    if (!value.has_value()) {
        out = true;
        return true;
    }
    if (!parse_bool_value(*value, out)) {
        error = "Invalid value for " + flag + ": " + *value;
        return false;
    }
    return true;
}

bool parse_int(const std::string& value, int& out, std::string& error, const std::string& flag) {
    if (value.empty()) {
        error = "Missing value for " + flag;
        return false;
    }
    try {
        size_t idx = 0;
        long parsed = std::stol(value, &idx, 10);
        if (idx != value.size()) {
            error = "Invalid value for " + flag + ": " + value;
            return false;
        }
        if (parsed < std::numeric_limits<int>::min() || parsed > std::numeric_limits<int>::max()) {
            error = "Value out of range for " + flag + ": " + value;
            return false;
        }
        out = static_cast<int>(parsed);
        return true;
    } catch (const std::exception&) {
        error = "Invalid value for " + flag + ": " + value;
        return false;
    }
}

bool parse_uint32(const std::string& value, uint32_t& out, std::string& error,
                  const std::string& flag) {
    if (value.empty()) {
        error = "Missing value for " + flag;
        return false;
    }
    try {
        size_t idx = 0;
        unsigned long long parsed = std::stoull(value, &idx, 10);
        if (idx != value.size()) {
            error = "Invalid value for " + flag + ": " + value;
            return false;
        }
        if (parsed > std::numeric_limits<uint32_t>::max()) {
            error = "Value out of range for " + flag + ": " + value;
            return false;
        }
        out = static_cast<uint32_t>(parsed);
        return true;
    } catch (const std::exception&) {
        error = "Invalid value for " + flag + ": " + value;
        return false;
    }
}

bool parse_resolution(const std::string& value, int& width, int& height, std::string& error) {
    auto pos = value.find('x');
    if (pos == std::string::npos) {
        pos = value.find('X');
    }
    if (pos == std::string::npos) {
        error = "Invalid resolution format: " + value;
        return false;
    }
    const auto w_str = value.substr(0, pos);
    const auto h_str = value.substr(pos + 1);
    if (!parse_int(w_str, width, error, "--resolution") ||
        !parse_int(h_str, height, error, "--resolution")) {
        return false;
    }
    if (width <= 0 || height <= 0) {
        error = "Resolution must be positive: " + value;
        return false;
    }
    return true;
}

bool parse_network_mode(const std::string& value, NetworkMode& out, std::string& error) {
    const auto mode = to_lower(value);
    if (mode == "deny") {
        out = NetworkMode::Deny;
        return true;
    }
    if (mode == "localhost") {
        out = NetworkMode::Localhost;
        return true;
    }
    if (mode == "any") {
        out = NetworkMode::Any;
        return true;
    }
    error = "Invalid --allow-network: " + value;
    return false;
}

bool parse_baseline_write_mode(const std::string& value, BaselineWriteMode& out,
                               std::string& error) {
    const auto mode = to_lower(value);
    if (mode == "deny") {
        out = BaselineWriteMode::Deny;
        return true;
    }
    if (mode == "stage") {
        out = BaselineWriteMode::Stage;
        return true;
    }
    if (mode == "apply") {
        out = BaselineWriteMode::Apply;
        return true;
    }
    error = "Invalid --baseline-write-mode: " + value;
    return false;
}

bool parse_failure_video_mode(const std::string& value, FailureVideoMode& out,
                              std::string& error) {
    const auto mode = to_lower(value);
    if (mode == "off") {
        out = FailureVideoMode::Off;
        return true;
    }
    if (mode == "on") {
        out = FailureVideoMode::On;
        return true;
    }
    error = "Invalid --failure-video: " + value;
    return false;
}

bool parse_rng_scope(const std::string& value, RngScope& out, std::string& error) {
    const auto mode = to_lower(value);
    if (mode == "test") {
        out = RngScope::Test;
        return true;
    }
    if (mode == "run") {
        out = RngScope::Run;
        return true;
    }
    error = "Invalid --rng-scope: " + value;
    return false;
}

bool parse_renderer_mode(const std::string& value, RendererMode& out, std::string& error) {
    const auto mode = to_lower(value);
    if (mode == "null") {
        out = RendererMode::Null;
        return true;
    }
    if (mode == "offscreen") {
        out = RendererMode::Offscreen;
        return true;
    }
    if (mode == "windowed") {
        out = RendererMode::Windowed;
        return true;
    }
    error = "Invalid --renderer: " + value;
    return false;
}

bool parse_determinism_audit_scope(const std::string& value, DeterminismAuditScope& out,
                                   std::string& error) {
    const auto mode = to_lower(value);
    if (mode == "test_api") {
        out = DeterminismAuditScope::TestApi;
        return true;
    }
    if (mode == "engine") {
        out = DeterminismAuditScope::Engine;
        return true;
    }
    if (mode == "render_hash") {
        out = DeterminismAuditScope::RenderHash;
        return true;
    }
    error = "Invalid --determinism-audit-scope: " + value;
    return false;
}

bool parse_determinism_violation(const std::string& value, DeterminismViolationMode& out,
                                 std::string& error) {
    const auto mode = to_lower(value);
    if (mode == "fatal") {
        out = DeterminismViolationMode::Fatal;
        return true;
    }
    if (mode == "warn") {
        out = DeterminismViolationMode::Warn;
        return true;
    }
    error = "Invalid --determinism-violation: " + value;
    return false;
}

bool parse_isolate_tests_mode(const std::string& value, IsolateTestsMode& out,
                              std::string& error) {
    const auto mode = to_lower(value);
    if (mode == "none") {
        out = IsolateTestsMode::None;
        return true;
    }
    if (mode == "process-per-file") {
        out = IsolateTestsMode::ProcessPerFile;
        return true;
    }
    if (mode == "process-per-test") {
        out = IsolateTestsMode::ProcessPerTest;
        return true;
    }
    error = "Invalid --isolate-tests: " + value;
    return false;
}

bool parse_lua_sandbox_mode(const std::string& value, LuaSandboxMode& out,
                            std::string& error) {
    const auto mode = to_lower(value);
    if (mode == "on") {
        out = LuaSandboxMode::On;
        return true;
    }
    if (mode == "off") {
        out = LuaSandboxMode::Off;
        return true;
    }
    error = "Invalid --lua-sandbox: " + value;
    return false;
}

bool parse_perf_mode(const std::string& value, PerfMode& out, std::string& error) {
    const auto mode = to_lower(value);
    if (mode == "off") {
        out = PerfMode::Off;
        return true;
    }
    if (mode == "collect") {
        out = PerfMode::Collect;
        return true;
    }
    if (mode == "enforce") {
        out = PerfMode::Enforce;
        return true;
    }
    error = "Invalid --perf-mode: " + value;
    return false;
}

std::filesystem::path detect_repo_root() {
    std::filesystem::path current = std::filesystem::current_path();
    std::filesystem::path cursor = current;
    while (true) {
        const auto assets = cursor / "assets";
        const auto tests = cursor / "tests";
        const auto cmake = cursor / "CMakeLists.txt";
        if (std::filesystem::exists(assets) && std::filesystem::exists(tests) &&
            std::filesystem::exists(cmake)) {
            return cursor;
        }
        if (cursor == cursor.root_path()) {
            break;
        }
        cursor = cursor.parent_path();
    }
    return current;
}

std::filesystem::path resolve_path(const std::filesystem::path& root,
                                  const std::filesystem::path& value) {
    if (value.empty()) {
        return value;
    }
    if (value.is_absolute()) {
        return value.lexically_normal();
    }
    return (root / value).lexically_normal();
}

bool is_under_root(const std::filesystem::path& root, const std::filesystem::path& candidate) {
    std::error_code ec;
    auto canonical_root = std::filesystem::weakly_canonical(root, ec);
    if (ec) {
        canonical_root = std::filesystem::absolute(root, ec);
    }
    auto canonical_candidate = std::filesystem::weakly_canonical(candidate, ec);
    if (ec) {
        canonical_candidate = std::filesystem::absolute(candidate, ec);
    }

    auto root_it = canonical_root.begin();
    auto cand_it = canonical_candidate.begin();
    for (; root_it != canonical_root.end() && cand_it != canonical_candidate.end(); ++root_it, ++cand_it) {
        if (*root_it != *cand_it) {
            return false;
        }
    }
    return root_it == canonical_root.end();
}

bool ensure_dir(const std::filesystem::path& dir, std::string& error) {
    std::error_code ec;
    if (dir.empty()) {
        return true;
    }
    std::filesystem::create_directories(dir, ec);
    if (ec) {
        error = "Failed to create directory: " + dir.string();
        return false;
    }
    return true;
}

bool ensure_parent_dir(const std::filesystem::path& path, std::string& error) {
    if (path.empty()) {
        return true;
    }
    return ensure_dir(path.parent_path(), error);
}

std::string generate_run_id() {
    using namespace std::chrono;
    static std::atomic<uint64_t> counter{0};

    auto now = system_clock::now();
    auto ms = duration_cast<milliseconds>(now.time_since_epoch()) % 1000;
    auto t = system_clock::to_time_t(now);
    std::tm tm{};
#if defined(_WIN32)
    gmtime_s(&tm, &t);
#else
    gmtime_r(&t, &tm);
#endif

    char time_buf[32] = {};
    std::strftime(time_buf, sizeof(time_buf), "%Y%m%d_%H%M%S", &tm);

    std::ostringstream oss;
    oss << time_buf << '_' << std::setw(3) << std::setfill('0') << ms.count()
        << '_' << counter.fetch_add(1, std::memory_order_relaxed);
    return oss.str();
}

struct ArgSplit {
    std::string flag;
    std::optional<std::string> value;
};

ArgSplit split_arg(const std::string& arg) {
    auto pos = arg.find('=');
    if (pos == std::string::npos) {
        return {arg, std::nullopt};
    }
    return {arg.substr(0, pos), arg.substr(pos + 1)};
}

bool take_value(int& i, int argc, char** argv, const std::optional<std::string>& inline_value,
                std::string& out, std::string& error, const std::string& flag) {
    if (inline_value.has_value()) {
        out = *inline_value;
        if (out.empty()) {
            error = "Missing value for " + flag;
            return false;
        }
        return true;
    }
    if (i + 1 >= argc) {
        error = "Missing value for " + flag;
        return false;
    }
    out = argv[++i];
    return true;
}

} // namespace

std::string test_mode_usage() {
    std::ostringstream oss;
    oss << "Usage: --test-mode [options]\n";
    oss << "See planning/PLAN.md section 2 for full CLI contract.";
    return oss.str();
}

const TestModeConfig* get_active_test_mode_config() {
    return g_active_test_config;
}

void set_active_test_mode_config(const TestModeConfig* config) {
    g_active_test_config = config;
}

bool parse_test_mode_args(int argc, char** argv, TestModeConfig& out, std::string& err) {
    out = TestModeConfig{};
    bool shuffle_seed_set = false;

    for (int i = 1; i < argc; ++i) {
        std::string raw = argv[i] ? argv[i] : "";
        if (raw.empty()) {
            continue;
        }
        if (raw == "--") {
            err = "Unexpected positional arguments";
            return false;
        }

        auto split = split_arg(raw);
        std::string flag = split.flag;
        const auto& inline_value = split.value;

        if (flag == "-s") {
            flag = "--seed";
        } else if (flag == "-f") {
            flag = "--fixed-fps";
        } else if (flag == "-r") {
            flag = "--resolution";
        } else if (flag == "-t") {
            flag = "--test-script";
        } else if (flag == "-T") {
            flag = "--test-suite";
        } else if (flag == "-l") {
            flag = "--list-tests";
        }

        if (flag == "--test-mode") {
            out.enabled = true;
            continue;
        }
        if (flag == "--headless") {
            if (!parse_bool_flag(inline_value, out.headless, err, flag)) {
                return false;
            }
            continue;
        }
        if (flag == "--test-script") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            out.test_script = value;
            continue;
        }
        if (flag == "--test-suite") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            out.test_suite = value;
            continue;
        }
        if (flag == "--list-tests") {
            if (!parse_bool_flag(inline_value, out.list_tests, err, flag)) {
                return false;
            }
            continue;
        }
        if (flag == "--list-tests-json") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            out.list_tests_json_path = value;
            out.list_tests = true;
            continue;
        }
        if (flag == "--test-filter") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            out.test_filter = value;
            continue;
        }
        if (flag == "--run-test-id") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            out.run_test_id = value;
            continue;
        }
        if (flag == "--run-test-exact") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            out.run_test_exact = value;
            continue;
        }
        if (flag == "--include-tag") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            out.include_tags.push_back(value);
            continue;
        }
        if (flag == "--exclude-tag") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            out.exclude_tags.push_back(value);
            continue;
        }
        if (flag == "--seed") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            if (!parse_uint32(value, out.seed, err, flag)) {
                return false;
            }
            continue;
        }
        if (flag == "--fixed-fps") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            if (!parse_int(value, out.fixed_fps, err, flag)) {
                return false;
            }
            continue;
        }
        if (flag == "--resolution") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            if (!parse_resolution(value, out.resolution_width, out.resolution_height, err)) {
                return false;
            }
            continue;
        }
        if (flag == "--allow-network") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            if (!parse_network_mode(value, out.allow_network, err)) {
                return false;
            }
            continue;
        }
        if (flag == "--artifacts") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            out.artifacts_dir = std::filesystem::path(value);
            continue;
        }
        if (flag == "--report-json") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            out.report_json_path = std::filesystem::path(value);
            continue;
        }
        if (flag == "--report-junit") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            out.report_junit_path = std::filesystem::path(value);
            continue;
        }
        if (flag == "--update-baselines") {
            out.update_baselines = true;
            continue;
        }
        if (flag == "--fail-on-missing-baseline") {
            out.fail_on_missing_baseline = true;
            continue;
        }
        if (flag == "--baseline-key") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            out.baseline_key = value;
            continue;
        }
        if (flag == "--baseline-write-mode") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            if (!parse_baseline_write_mode(value, out.baseline_write_mode, err)) {
                return false;
            }
            continue;
        }
        if (flag == "--baseline-staging-dir") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            out.baseline_staging_dir = std::filesystem::path(value);
            continue;
        }
        if (flag == "--baseline-approve-token") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            out.baseline_approve_token = value;
            continue;
        }
        if (flag == "--shard") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            if (!parse_int(value, out.shard, err, flag)) {
                return false;
            }
            continue;
        }
        if (flag == "--total-shards") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            if (!parse_int(value, out.total_shards, err, flag)) {
                return false;
            }
            continue;
        }
        if (flag == "--timeout-seconds") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            if (!parse_int(value, out.timeout_seconds, err, flag)) {
                return false;
            }
            continue;
        }
        if (flag == "--default-test-timeout-frames") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            if (!parse_int(value, out.default_test_timeout_frames, err, flag)) {
                return false;
            }
            continue;
        }
        if (flag == "--failure-video") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            if (!parse_failure_video_mode(value, out.failure_video, err)) {
                return false;
            }
            continue;
        }
        if (flag == "--failure-video-frames") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            if (!parse_int(value, out.failure_video_frames, err, flag)) {
                return false;
            }
            continue;
        }
        if (flag == "--retry-failures") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            if (!parse_int(value, out.retry_failures, err, flag)) {
                return false;
            }
            continue;
        }
        if (flag == "--allow-flaky") {
            out.allow_flaky = true;
            continue;
        }
        if (flag == "--auto-audit-on-flake") {
            out.auto_audit_on_flake = true;
            continue;
        }
        if (flag == "--flake-artifacts") {
            out.flake_artifacts = true;
            continue;
        }
        if (flag == "--run-quarantined") {
            out.run_quarantined = true;
            continue;
        }
        if (flag == "--fail-fast") {
            out.fail_fast = true;
            continue;
        }
        if (flag == "--max-failures") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            if (!parse_int(value, out.max_failures, err, flag)) {
                return false;
            }
            continue;
        }
        if (flag == "--shuffle-tests") {
            out.shuffle_tests = true;
            continue;
        }
        if (flag == "--shuffle-seed") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            if (!parse_uint32(value, out.shuffle_seed, err, flag)) {
                return false;
            }
            shuffle_seed_set = true;
            continue;
        }
        if (flag == "--test-manifest") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            out.test_manifest_path = std::filesystem::path(value);
            continue;
        }
        if (flag == "--rng-scope") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            if (!parse_rng_scope(value, out.rng_scope, err)) {
                return false;
            }
            continue;
        }
        if (flag == "--renderer") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            if (!parse_renderer_mode(value, out.renderer, err)) {
                return false;
            }
            out.renderer_set = true;
            continue;
        }
        if (flag == "--determinism-audit") {
            out.determinism_audit = true;
            continue;
        }
        if (flag == "--determinism-audit-runs") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            if (!parse_int(value, out.determinism_audit_runs, err, flag)) {
                return false;
            }
            continue;
        }
        if (flag == "--determinism-audit-scope") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            if (!parse_determinism_audit_scope(value, out.determinism_audit_scope, err)) {
                return false;
            }
            continue;
        }
        if (flag == "--determinism-violation") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            if (!parse_determinism_violation(value, out.determinism_violation, err)) {
                return false;
            }
            continue;
        }
        if (flag == "--fail-on-log-level") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            out.fail_on_log_level = value;
            continue;
        }
        if (flag == "--fail-on-log-category") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            out.fail_on_log_category = value;
            continue;
        }
        if (flag == "--record-input") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            out.record_input_path = std::filesystem::path(value);
            continue;
        }
        if (flag == "--replay-input") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            out.replay_input_path = std::filesystem::path(value);
            continue;
        }
        if (flag == "--isolate-tests") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            if (!parse_isolate_tests_mode(value, out.isolate_tests, err)) {
                return false;
            }
            continue;
        }
        if (flag == "--lua-sandbox") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            if (!parse_lua_sandbox_mode(value, out.lua_sandbox, err)) {
                return false;
            }
            continue;
        }
        if (flag == "--perf-mode") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            if (!parse_perf_mode(value, out.perf_mode, err)) {
                return false;
            }
            continue;
        }
        if (flag == "--perf-budget") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            out.perf_budget_path = std::filesystem::path(value);
            continue;
        }
        if (flag == "--perf-trace") {
            std::string value;
            if (!take_value(i, argc, argv, inline_value, value, err, flag)) {
                return false;
            }
            out.perf_trace_path = std::filesystem::path(value);
            continue;
        }

        err = "Unknown flag: " + flag + "\n" + test_mode_usage();
        return false;
    }

    if (!shuffle_seed_set && out.shuffle_tests) {
        out.shuffle_seed = out.seed;
    }

    return true;
}

bool validate_and_finalize(TestModeConfig& config, std::string& err) {
    if (config.test_script.has_value() && config.test_suite.has_value()) {
        err = "--test-script and --test-suite are mutually exclusive";
        return false;
    }
    if (config.run_test_id.has_value() && config.run_test_exact.has_value()) {
        err = "--run-test-id and --run-test-exact are mutually exclusive";
        return false;
    }
    if (!config.test_filter.empty() && (config.run_test_id.has_value() || config.run_test_exact.has_value())) {
        err = "--test-filter is mutually exclusive with --run-test-id and --run-test-exact";
        return false;
    }
    if (config.shard <= 0 || config.total_shards <= 0) {
        err = "--shard and --total-shards must be >= 1";
        return false;
    }
    if (config.shard > config.total_shards) {
        err = "--shard must be <= --total-shards";
        return false;
    }
    if (config.timeout_seconds <= 0) {
        err = "--timeout-seconds must be > 0";
        return false;
    }
    if (config.fixed_fps <= 0) {
        err = "--fixed-fps must be > 0";
        return false;
    }
    if (config.default_test_timeout_frames <= 0) {
        err = "--default-test-timeout-frames must be > 0";
        return false;
    }
    if (config.determinism_audit_runs <= 0) {
        err = "--determinism-audit-runs must be > 0";
        return false;
    }
    if (config.failure_video_frames <= 0) {
        err = "--failure-video-frames must be > 0";
        return false;
    }
    if (config.retry_failures < 0 || config.max_failures < 0) {
        err = "Retry and max failure counts must be >= 0";
        return false;
    }
    if (config.resolution_width <= 0 || config.resolution_height <= 0) {
        err = "--resolution must be WxH with positive values";
        return false;
    }

    bool default_suite = false;
    if (!config.test_script.has_value() && !config.test_suite.has_value()) {
        config.test_suite = std::string("assets/scripts/tests/e2e");
        default_suite = true;
    }

    if (config.update_baselines) {
        config.fail_on_missing_baseline = false;
        if (config.baseline_write_mode == BaselineWriteMode::Deny) {
            config.baseline_write_mode = BaselineWriteMode::Stage;
        }
    }

    if (config.shuffle_tests && config.shuffle_seed == 0) {
        config.shuffle_seed = config.seed;
    }

    if (config.headless && !config.renderer_set) {
        config.renderer = RendererMode::Offscreen;
    }

    if (config.run_id.empty()) {
        config.run_id = generate_run_id();
    }

    auto root = detect_repo_root();
    auto out_root = root / "tests" / "out";
    auto baseline_staging_root = root / "tests" / "baselines_staging";

    config.run_root = root / "tests" / "out" / config.run_id;
    if (config.artifacts_dir.empty()) {
        config.artifacts_dir = config.run_root / "artifacts";
    }
    if (config.report_json_path.empty()) {
        config.report_json_path = config.run_root / "report.json";
    }
    if (config.report_junit_path.empty()) {
        config.report_junit_path = config.run_root / "report.junit.xml";
    }
    config.forensics_dir = config.run_root / "forensics";

    if (config.test_manifest_path.empty()) {
        config.test_manifest_path = std::filesystem::path("tests/test_manifest.json");
    }

    auto validate_path = [&](const std::filesystem::path& path,
                             const std::filesystem::path& allowed_root,
                             const std::string& label) -> bool {
        if (path.empty()) {
            return true;
        }
        auto resolved = resolve_path(root, path);
        if (!is_under_root(allowed_root, resolved)) {
            err = "Path outside allowed root for " + label;
            return false;
        }
        return true;
    };

    auto validate_input_path = [&](const std::filesystem::path& path, const std::string& label,
                                   bool require_dir) -> bool {
        auto resolved = resolve_path(root, path);
        if (!is_under_root(root, resolved)) {
            err = "Path outside repo root for " + label;
            return false;
        }
        if (!std::filesystem::exists(resolved)) {
            err = "Missing required path for " + label + ": " + resolved.string();
            return false;
        }
        if (require_dir && !std::filesystem::is_directory(resolved)) {
            err = "Expected directory for " + label + ": " + resolved.string();
            return false;
        }
        if (!require_dir && std::filesystem::is_directory(resolved)) {
            err = "Expected file for " + label + ": " + resolved.string();
            return false;
        }
        return true;
    };

    if (!validate_path(config.artifacts_dir, out_root, "--artifacts")) {
        return false;
    }
    if (!validate_path(config.report_json_path, out_root, "--report-json")) {
        return false;
    }
    if (!validate_path(config.report_junit_path, out_root, "--report-junit")) {
        return false;
    }
    if (!validate_path(config.run_root, out_root, "run root")) {
        return false;
    }
    if (!validate_path(config.forensics_dir, out_root, "forensics dir")) {
        return false;
    }
    if (!validate_path(config.baseline_staging_dir, baseline_staging_root, "--baseline-staging-dir")) {
        return false;
    }
    if (!validate_path(config.test_manifest_path, root, "--test-manifest")) {
        return false;
    }
    if (config.list_tests_json_path.has_value()) {
        if (!validate_path(std::filesystem::path(*config.list_tests_json_path), out_root, "--list-tests-json")) {
            return false;
        }
    }
    if (config.record_input_path.has_value()) {
        if (!validate_path(*config.record_input_path, out_root, "--record-input")) {
            return false;
        }
    }
    if (config.replay_input_path.has_value()) {
        if (!validate_input_path(*config.replay_input_path, "--replay-input", false)) {
            return false;
        }
    }
    if (config.perf_budget_path.has_value()) {
        if (!validate_input_path(*config.perf_budget_path, "--perf-budget", false)) {
            return false;
        }
    }
    if (config.perf_trace_path.has_value()) {
        if (!validate_path(*config.perf_trace_path, out_root, "--perf-trace")) {
            return false;
        }
    }
    if (config.test_script.has_value()) {
        if (!validate_input_path(std::filesystem::path(*config.test_script), "--test-script", false)) {
            return false;
        }
    }
    if (config.test_suite.has_value() && !default_suite) {
        if (!validate_input_path(std::filesystem::path(*config.test_suite), "--test-suite", true)) {
            return false;
        }
    }

    config.artifacts_dir = resolve_path(root, config.artifacts_dir);
    config.report_json_path = resolve_path(root, config.report_json_path);
    config.report_junit_path = resolve_path(root, config.report_junit_path);
    config.run_root = resolve_path(root, config.run_root);
    config.forensics_dir = resolve_path(root, config.forensics_dir);
    config.baseline_staging_dir = resolve_path(root, config.baseline_staging_dir);
    config.test_manifest_path = resolve_path(root, config.test_manifest_path);

    if (config.list_tests_json_path.has_value()) {
        config.list_tests_json_path = resolve_path(root, *config.list_tests_json_path).string();
    }
    if (config.record_input_path.has_value()) {
        config.record_input_path = resolve_path(root, *config.record_input_path);
    }
    if (config.replay_input_path.has_value()) {
        config.replay_input_path = resolve_path(root, *config.replay_input_path);
    }
    if (config.perf_budget_path.has_value()) {
        config.perf_budget_path = resolve_path(root, *config.perf_budget_path);
    }
    if (config.perf_trace_path.has_value()) {
        config.perf_trace_path = resolve_path(root, *config.perf_trace_path);
    }
    if (config.test_script.has_value()) {
        config.test_script = resolve_path(root, *config.test_script).string();
    }
    if (config.test_suite.has_value()) {
        config.test_suite = resolve_path(root, *config.test_suite).string();
    }

    if (!ensure_dir(config.run_root, err)) {
        return false;
    }
    if (!ensure_dir(config.artifacts_dir, err)) {
        return false;
    }
    if (!ensure_dir(config.forensics_dir, err)) {
        return false;
    }
    if (!ensure_parent_dir(config.report_json_path, err)) {
        return false;
    }
    if (!ensure_parent_dir(config.report_junit_path, err)) {
        return false;
    }
    if (config.list_tests_json_path.has_value()) {
        if (!ensure_parent_dir(std::filesystem::path(*config.list_tests_json_path), err)) {
            return false;
        }
    }
    if (config.record_input_path.has_value()) {
        if (!ensure_parent_dir(*config.record_input_path, err)) {
            return false;
        }
    }
    if (config.perf_trace_path.has_value()) {
        if (!ensure_parent_dir(*config.perf_trace_path, err)) {
            return false;
        }
    }

    return true;
}

} // namespace testing
