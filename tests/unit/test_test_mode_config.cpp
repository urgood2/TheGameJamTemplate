#include <gtest/gtest.h>

#include <atomic>
#include <filesystem>
#include <string>
#include <vector>

#include "testing/test_mode_config.hpp"

namespace fs = std::filesystem;

namespace {

struct TempRoot {
    fs::path path;

    TempRoot() {
        static std::atomic<uint32_t> counter{0};
        auto suffix = counter.fetch_add(1, std::memory_order_relaxed);
        path = fs::temp_directory_path() / ("test_mode_config_" + std::to_string(suffix));
        fs::create_directories(path);
    }

    ~TempRoot() {
        std::error_code ec;
        fs::remove_all(path, ec);
    }
};

std::vector<char*> build_argv(const std::vector<std::string>& args, std::vector<std::string>& storage) {
    storage.clear();
    storage.reserve(args.size() + 1);
    storage.push_back("game");
    storage.insert(storage.end(), args.begin(), args.end());

    std::vector<char*> argv;
    argv.reserve(storage.size());
    for (auto& item : storage) {
        argv.push_back(item.data());
    }
    return argv;
}

testing::ParseResult parse_and_finalize(const std::vector<std::string>& args,
                                        testing::TestModeConfig& config,
                                        const fs::path& root) {
    std::vector<std::string> storage;
    auto argv = build_argv(args, storage);
    auto parsed = testing::parse_test_mode_args(static_cast<int>(argv.size()), argv.data(), config);
    if (!parsed.ok) {
        return parsed;
    }
    config.repo_root = root;
    return testing::validate_and_finalize(config);
}

bool is_filesystem_safe_id(const std::string& value) {
    for (unsigned char c : value) {
        if (std::isalnum(c) || c == '_' || c == '-') {
            continue;
        }
        return false;
    }
    return !value.empty();
}

} // namespace

TEST(TestModeConfig, DefaultsAndRunId) {
    TempRoot root;
    testing::TestModeConfig config;

    auto result = parse_and_finalize({"--test-mode"}, config, root.path);
    ASSERT_TRUE(result.ok) << result.error;

    EXPECT_TRUE(config.enabled);
    EXPECT_EQ(config.seed, 12345u);
    EXPECT_EQ(config.fixed_fps, 60);
    EXPECT_EQ(config.resolution_width, 1280);
    EXPECT_EQ(config.resolution_height, 720);
    EXPECT_EQ(config.allow_network, testing::NetworkMode::Deny);
    EXPECT_TRUE(config.test_suite.has_value());
    EXPECT_FALSE(config.run_id.empty());
    EXPECT_TRUE(fs::exists(config.run_root));
    EXPECT_TRUE(fs::exists(config.artifacts_dir));
    EXPECT_TRUE(fs::exists(config.forensics_dir));
    EXPECT_NE(config.report_json_path.string().find(config.run_id), std::string::npos);
}

TEST(TestModeConfig, ParsesCoreFlags) {
    TempRoot root;
    testing::TestModeConfig config;

    auto result = parse_and_finalize({
        "--test-mode",
        "--headless",
        "--test-script", "tests/example.lua",
        "--list-tests",
        "--list-tests-json", "tests/out/list.json",
        "--test-filter", "smoke*",
        "--include-tag", "fast",
        "--exclude-tag", "slow",
        "--seed", "777",
        "--fixed-fps", "30",
        "--resolution", "640x480",
        "--allow-network", "localhost"
    }, config, root.path);

    ASSERT_TRUE(result.ok) << result.error;
    EXPECT_TRUE(config.headless);
    ASSERT_TRUE(config.test_script.has_value());
    EXPECT_EQ(config.test_script->filename(), "example.lua");
    EXPECT_TRUE(config.list_tests);
    ASSERT_TRUE(config.list_tests_json_path.has_value());
    EXPECT_EQ(config.test_filter, "smoke*");
    EXPECT_EQ(config.include_tags.size(), 1u);
    EXPECT_EQ(config.exclude_tags.size(), 1u);
    EXPECT_EQ(config.seed, 777u);
    EXPECT_EQ(config.fixed_fps, 30);
    EXPECT_EQ(config.resolution_width, 640);
    EXPECT_EQ(config.resolution_height, 480);
    EXPECT_EQ(config.allow_network, testing::NetworkMode::Localhost);
}

TEST(TestModeConfig, ParsesRunTestFlags) {
    TempRoot root;
    testing::TestModeConfig config_id;

    auto result_id = parse_and_finalize({
        "--test-mode",
        "--run-test-id", "abc123",
        "--test-suite", "tests/suite"
    }, config_id, root.path);

    ASSERT_TRUE(result_id.ok) << result_id.error;
    ASSERT_TRUE(config_id.run_test_id.has_value());
    EXPECT_EQ(*config_id.run_test_id, "abc123");

    testing::TestModeConfig config_exact;
    auto result_exact = parse_and_finalize({
        "--test-mode",
        "--run-test-exact", "suite:case",
        "--test-suite", "tests/suite"
    }, config_exact, root.path);

    ASSERT_TRUE(result_exact.ok) << result_exact.error;
    ASSERT_TRUE(config_exact.run_test_exact.has_value());
    EXPECT_EQ(*config_exact.run_test_exact, "suite:case");
}

TEST(TestModeConfig, ParsesOutputAndBaselineFlags) {
    TempRoot root;
    testing::TestModeConfig config;

    auto result = parse_and_finalize({
        "--test-mode",
        "--artifacts", "tests/out/custom_artifacts",
        "--report-json", "tests/out/custom_report.json",
        "--report-junit", "tests/out/custom_report.junit.xml",
        "--update-baselines",
        "--baseline-key", "vulkan_sdr_srgb",
        "--baseline-write-mode", "stage",
        "--baseline-staging-dir", "tests/staging",
        "--baseline-approve-token", "token123"
    }, config, root.path);

    ASSERT_TRUE(result.ok) << result.error;
    EXPECT_TRUE(config.update_baselines);
    EXPECT_FALSE(config.fail_on_missing_baseline);
    ASSERT_TRUE(config.baseline_key.has_value());
    EXPECT_EQ(*config.baseline_key, "vulkan_sdr_srgb");
    EXPECT_EQ(config.baseline_write_mode, testing::BaselineWriteMode::Stage);
    EXPECT_EQ(config.baseline_staging_dir.filename(), "staging");
    ASSERT_TRUE(config.baseline_approve_token.has_value());
    EXPECT_EQ(*config.baseline_approve_token, "token123");
}

TEST(TestModeConfig, ParsesShardingAndTimeoutFlags) {
    TempRoot root;
    testing::TestModeConfig config;

    auto result = parse_and_finalize({
        "--test-mode",
        "--shard", "2",
        "--total-shards", "5",
        "--timeout-seconds", "120",
        "--default-test-timeout-frames", "900",
        "--failure-video", "on",
        "--failure-video-frames", "200"
    }, config, root.path);

    ASSERT_TRUE(result.ok) << result.error;
    EXPECT_EQ(config.shard, 2);
    EXPECT_EQ(config.total_shards, 5);
    EXPECT_EQ(config.timeout_seconds, 120);
    EXPECT_EQ(config.default_test_timeout_frames, 900);
    EXPECT_EQ(config.failure_video, testing::FailureVideoMode::On);
    EXPECT_EQ(config.failure_video_frames, 200);
}

TEST(TestModeConfig, ParsesRetryAndSuiteFlags) {
    TempRoot root;
    testing::TestModeConfig config;

    auto result = parse_and_finalize({
        "--test-mode",
        "--retry-failures", "3",
        "--allow-flaky",
        "--auto-audit-on-flake",
        "--flake-artifacts=false",
        "--run-quarantined",
        "--fail-fast",
        "--max-failures", "4",
        "--shuffle-tests",
        "--shuffle-seed", "888",
        "--test-manifest", "tests/manifest.json"
    }, config, root.path);

    ASSERT_TRUE(result.ok) << result.error;
    EXPECT_EQ(config.retry_failures, 3);
    EXPECT_TRUE(config.allow_flaky);
    EXPECT_TRUE(config.auto_audit_on_flake);
    EXPECT_FALSE(config.flake_artifacts);
    EXPECT_TRUE(config.run_quarantined);
    EXPECT_TRUE(config.fail_fast);
    EXPECT_EQ(config.max_failures, 4);
    EXPECT_TRUE(config.shuffle_tests);
    ASSERT_TRUE(config.shuffle_seed.has_value());
    EXPECT_EQ(*config.shuffle_seed, 888u);
    EXPECT_EQ(config.test_manifest_path.filename(), "manifest.json");
}

TEST(TestModeConfig, ParsesRendererAndDeterminismFlags) {
    TempRoot root;
    testing::TestModeConfig config;

    auto result = parse_and_finalize({
        "--test-mode",
        "--rng-scope", "run",
        "--renderer", "windowed",
        "--determinism-audit",
        "--determinism-audit-runs", "3",
        "--determinism-audit-scope", "render_hash",
        "--determinism-violation", "warn"
    }, config, root.path);

    ASSERT_TRUE(result.ok) << result.error;
    EXPECT_EQ(config.rng_scope, testing::RngScope::Run);
    EXPECT_EQ(config.renderer, testing::RendererMode::Windowed);
    EXPECT_TRUE(config.determinism_audit);
    EXPECT_EQ(config.determinism_audit_runs, 3);
    EXPECT_EQ(config.determinism_audit_scope, testing::DeterminismAuditScope::RenderHash);
    EXPECT_EQ(config.determinism_violation, testing::DeterminismViolationMode::Warn);
}

TEST(TestModeConfig, ParsesLoggingInputAndPerfFlags) {
    TempRoot root;
    testing::TestModeConfig config;

    auto result = parse_and_finalize({
        "--test-mode",
        "--fail-on-log-level", "warn",
        "--fail-on-log-category", "net*",
        "--record-input", "tests/out/inputs.jsonl",
        "--replay-input", "tests/in/trace.jsonl",
        "--isolate-tests", "process-per-test",
        "--lua-sandbox", "off",
        "--perf-mode", "enforce",
        "--perf-budget", "tests/perf.json",
        "--perf-trace", "tests/out/trace.json"
    }, config, root.path);

    ASSERT_TRUE(result.ok) << result.error;
    ASSERT_TRUE(config.fail_on_log_level.has_value());
    EXPECT_EQ(*config.fail_on_log_level, "warn");
    ASSERT_TRUE(config.fail_on_log_category.has_value());
    EXPECT_EQ(*config.fail_on_log_category, "net*");
    ASSERT_TRUE(config.record_input_path.has_value());
    ASSERT_TRUE(config.replay_input_path.has_value());
    EXPECT_EQ(config.isolate_tests, testing::IsolateTestsMode::ProcessPerTest);
    EXPECT_EQ(config.lua_sandbox, testing::LuaSandboxMode::Off);
    EXPECT_EQ(config.perf_mode, testing::PerfMode::Enforce);
    ASSERT_TRUE(config.perf_budget_path.has_value());
    ASSERT_TRUE(config.perf_trace_path.has_value());
}

TEST(TestModeConfig, ParsesAliases) {
    TempRoot root;
    testing::TestModeConfig config;

    auto result = parse_and_finalize({
        "--test-mode",
        "-s", "42",
        "-r", "800x600",
        "-f", "55"
    }, config, root.path);

    ASSERT_TRUE(result.ok) << result.error;
    EXPECT_EQ(config.seed, 42u);
    EXPECT_EQ(config.resolution_width, 800);
    EXPECT_EQ(config.resolution_height, 600);
    EXPECT_EQ(config.fixed_fps, 55);
}

TEST(TestModeConfig, ValidationRejectsConflicts) {
    TempRoot root;
    testing::TestModeConfig config;

    auto result = parse_and_finalize({
        "--test-mode",
        "--test-script", "tests/a.lua",
        "--test-suite", "tests/suite"
    }, config, root.path);

    EXPECT_FALSE(result.ok);
    EXPECT_FALSE(fs::exists(root.path / "tests/out"));
}

TEST(TestModeConfig, ValidationRejectsRunTestConflicts) {
    TempRoot root;
    testing::TestModeConfig config;

    auto result = parse_and_finalize({
        "--test-mode",
        "--run-test-id", "alpha",
        "--run-test-exact", "suite:case"
    }, config, root.path);

    EXPECT_FALSE(result.ok);
}

TEST(TestModeConfig, ValidationRejectsFilterConflicts) {
    TempRoot root;
    testing::TestModeConfig config;

    auto result = parse_and_finalize({
        "--test-mode",
        "--test-filter", "smoke*",
        "--run-test-id", "alpha"
    }, config, root.path);

    EXPECT_FALSE(result.ok);
}

TEST(TestModeConfig, ValidationRejectsShardRange) {
    TempRoot root;
    testing::TestModeConfig config;

    auto result = parse_and_finalize({
        "--test-mode",
        "--shard", "5",
        "--total-shards", "2"
    }, config, root.path);

    EXPECT_FALSE(result.ok);
}

TEST(TestModeConfig, ValidationRejectsTimeoutsAndResolution) {
    TempRoot root;
    testing::TestModeConfig config_timeout;

    auto result_timeout = parse_and_finalize({
        "--test-mode",
        "--timeout-seconds", "0"
    }, config_timeout, root.path);

    EXPECT_FALSE(result_timeout.ok);

    testing::TestModeConfig config_resolution;
    auto result_resolution = parse_and_finalize({
        "--test-mode",
        "--resolution", "bad"
    }, config_resolution, root.path);

    EXPECT_FALSE(result_resolution.ok);
}

TEST(TestModeConfig, UnknownFlagIsRejected) {
    TempRoot root;
    testing::TestModeConfig config;

    std::vector<std::string> storage;
    auto argv = build_argv({"--unknown"}, storage);
    auto parsed = testing::parse_test_mode_args(static_cast<int>(argv.size()), argv.data(), config);

    EXPECT_FALSE(parsed.ok);
}

TEST(TestModeConfig, PathTraversalIsRejected) {
    TempRoot root;
    testing::TestModeConfig config;

    auto result = parse_and_finalize({
        "--test-mode",
        "--artifacts", "../../etc"
    }, config, root.path);

    EXPECT_FALSE(result.ok);
}

TEST(TestModeConfig, RunIdIsUniqueAndSafe) {
    TempRoot root;
    testing::TestModeConfig config_a;
    testing::TestModeConfig config_b;

    auto result_a = parse_and_finalize({"--test-mode"}, config_a, root.path);
    ASSERT_TRUE(result_a.ok) << result_a.error;

    auto result_b = parse_and_finalize({"--test-mode"}, config_b, root.path);
    ASSERT_TRUE(result_b.ok) << result_b.error;

    EXPECT_NE(config_a.run_id, config_b.run_id);
    EXPECT_TRUE(is_filesystem_safe_id(config_a.run_id));
    EXPECT_TRUE(is_filesystem_safe_id(config_b.run_id));
}

TEST(TestModeConfig, ShuffleSeedDefaultsToRunSeed) {
    TempRoot root;
    testing::TestModeConfig config;

    auto result = parse_and_finalize({
        "--test-mode",
        "--shuffle-tests",
        "--seed", "99"
    }, config, root.path);

    ASSERT_TRUE(result.ok) << result.error;
    ASSERT_TRUE(config.shuffle_seed.has_value());
    EXPECT_EQ(*config.shuffle_seed, 99u);
}

