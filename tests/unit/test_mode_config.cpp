#include <gtest/gtest.h>

#include <atomic>
#include <chrono>
#include <cctype>
#include <filesystem>
#include <string>
#include <vector>

#include "testing/test_mode_config.hpp"

namespace {

struct ScopedCwd {
    std::filesystem::path old;
    explicit ScopedCwd(const std::filesystem::path& path) : old(std::filesystem::current_path()) {
        std::filesystem::current_path(path);
    }
    ~ScopedCwd() {
        std::filesystem::current_path(old);
    }
};

std::filesystem::path make_temp_repo_root() {
    static std::atomic<int> counter{0};
    const auto now = std::chrono::steady_clock::now().time_since_epoch().count();
    auto root = std::filesystem::temp_directory_path() /
                ("test_mode_config_" + std::to_string(now) + "_" + std::to_string(counter.fetch_add(1)));
    std::filesystem::create_directories(root / "tests");
    return root;
}

struct ParseResult {
    bool ok = false;
    std::string err;
    testing::TestModeConfig config;
};

ParseResult parse_args(const std::vector<std::string>& args) {
    std::vector<std::string> argv_storage;
    argv_storage.reserve(args.size() + 1);
    argv_storage.push_back("game");
    for (const auto& arg : args) {
        argv_storage.push_back(arg);
    }

    std::vector<char*> argv;
    argv.reserve(argv_storage.size());
    for (auto& arg : argv_storage) {
        argv.push_back(arg.data());
    }

    ParseResult result;
    result.ok = testing::parse_test_mode_args(static_cast<int>(argv.size()), argv.data(), result.config, result.err);
    return result;
}

bool validate_config(testing::TestModeConfig& config, std::string& err, const std::filesystem::path& repo_root) {
    ScopedCwd scoped(repo_root);
    return testing::validate_and_finalize(config, err);
}

bool is_filesystem_safe_run_id(const std::string& value) {
    if (value.size() < 16) {
        return false;
    }
    for (char c : value) {
        if (!(std::isdigit(static_cast<unsigned char>(c)) || c == '_')) {
            return false;
        }
    }
    return true;
}

} // namespace

TEST(TestModeConfigParsing, DefaultsWhenNoFlags) {
    auto result = parse_args({});
    ASSERT_TRUE(result.ok);
    EXPECT_FALSE(result.config.enabled);
    EXPECT_FALSE(result.config.headless);
    EXPECT_FALSE(result.config.list_tests);
    EXPECT_TRUE(result.config.test_filter.empty());
    EXPECT_EQ(result.config.seed, 12345u);
    EXPECT_EQ(result.config.fixed_fps, 60);
    EXPECT_EQ(result.config.resolution_width, 1280);
    EXPECT_EQ(result.config.resolution_height, 720);
    EXPECT_EQ(result.config.allow_network, testing::NetworkMode::Deny);
    EXPECT_EQ(result.config.timeout_seconds, 600);
    EXPECT_EQ(result.config.default_test_timeout_frames, 1800);
    EXPECT_EQ(result.config.shard, 1);
    EXPECT_EQ(result.config.total_shards, 1);
}

TEST(TestModeConfigParsing, ParsesCoreFlagsAndAliases) {
    auto result = parse_args({
        "--test-mode",
        "--headless",
        "--test-script", "assets/scripts/tests/e2e/example.lua",
        "--list-tests",
        "--list-tests-json", "tests/out/list.json",
        "--test-filter", "regex:foo",
        "--run-test-id", "id_1",
        "--exclude-tag", "slow",
        "--include-tag", "fast",
        "-s", "777",
        "-f", "120",
        "-r", "1920x1080",
        "--allow-network", "localhost"
    });
    ASSERT_TRUE(result.ok) << result.err;
    EXPECT_TRUE(result.config.enabled);
    EXPECT_TRUE(result.config.headless);
    ASSERT_TRUE(result.config.test_script.has_value());
    EXPECT_EQ(*result.config.test_script, "assets/scripts/tests/e2e/example.lua");
    EXPECT_TRUE(result.config.list_tests);
    ASSERT_TRUE(result.config.list_tests_json_path.has_value());
    EXPECT_EQ(*result.config.list_tests_json_path, "tests/out/list.json");
    EXPECT_EQ(result.config.test_filter, "regex:foo");
    ASSERT_TRUE(result.config.run_test_id.has_value());
    EXPECT_EQ(*result.config.run_test_id, "id_1");
    EXPECT_EQ(result.config.exclude_tags.size(), 1u);
    EXPECT_EQ(result.config.exclude_tags[0], "slow");
    EXPECT_EQ(result.config.include_tags.size(), 1u);
    EXPECT_EQ(result.config.include_tags[0], "fast");
    EXPECT_EQ(result.config.seed, 777u);
    EXPECT_EQ(result.config.fixed_fps, 120);
    EXPECT_EQ(result.config.resolution_width, 1920);
    EXPECT_EQ(result.config.resolution_height, 1080);
    EXPECT_EQ(result.config.allow_network, testing::NetworkMode::Localhost);
}

TEST(TestModeConfigParsing, ParsesExtendedFlags) {
    auto result = parse_args({
        "--baseline-key", "vk_sdr",
        "--baseline-write-mode", "stage",
        "--baseline-staging-dir", "tests/baselines_staging/custom",
        "--baseline-approve-token", "token",
        "--shard", "2",
        "--total-shards", "5",
        "--timeout-seconds", "42",
        "--default-test-timeout-frames", "900",
        "--failure-video", "on",
        "--failure-video-frames", "240",
        "--retry-failures", "3",
        "--allow-flaky",
        "--auto-audit-on-flake",
        "--flake-artifacts",
        "--run-quarantined",
        "--fail-fast",
        "--max-failures", "7",
        "--shuffle-tests",
        "--shuffle-seed", "999",
        "--test-manifest", "tests/custom_manifest.json",
        "--rng-scope", "run",
        "--renderer", "windowed",
        "--determinism-audit",
        "--determinism-audit-runs", "4",
        "--determinism-audit-scope", "engine",
        "--determinism-violation", "warn",
        "--fail-on-log-level", "error",
        "--fail-on-log-category", "physics*",
        "--record-input", "tests/out/input.jsonl",
        "--replay-input", "tests/fixtures/input.jsonl",
        "--isolate-tests", "process-per-test",
        "--lua-sandbox", "off",
        "--perf-mode", "collect",
        "--perf-budget", "tests/budgets.json",
        "--perf-trace", "tests/out/trace.json"
    });

    ASSERT_TRUE(result.ok) << result.err;
    EXPECT_EQ(result.config.baseline_key, "vk_sdr");
    EXPECT_EQ(result.config.baseline_write_mode, testing::BaselineWriteMode::Stage);
    EXPECT_EQ(result.config.baseline_staging_dir, std::filesystem::path("tests/baselines_staging/custom"));
    EXPECT_EQ(result.config.baseline_approve_token, "token");
    EXPECT_EQ(result.config.shard, 2);
    EXPECT_EQ(result.config.total_shards, 5);
    EXPECT_EQ(result.config.timeout_seconds, 42);
    EXPECT_EQ(result.config.default_test_timeout_frames, 900);
    EXPECT_EQ(result.config.failure_video, testing::FailureVideoMode::On);
    EXPECT_EQ(result.config.failure_video_frames, 240);
    EXPECT_EQ(result.config.retry_failures, 3);
    EXPECT_TRUE(result.config.allow_flaky);
    EXPECT_TRUE(result.config.auto_audit_on_flake);
    EXPECT_TRUE(result.config.flake_artifacts);
    EXPECT_TRUE(result.config.run_quarantined);
    EXPECT_TRUE(result.config.fail_fast);
    EXPECT_EQ(result.config.max_failures, 7);
    EXPECT_TRUE(result.config.shuffle_tests);
    EXPECT_EQ(result.config.shuffle_seed, 999u);
    EXPECT_EQ(result.config.test_manifest_path, std::filesystem::path("tests/custom_manifest.json"));
    EXPECT_EQ(result.config.rng_scope, testing::RngScope::Run);
    EXPECT_EQ(result.config.renderer, testing::RendererMode::Windowed);
    EXPECT_TRUE(result.config.renderer_set);
    EXPECT_TRUE(result.config.determinism_audit);
    EXPECT_EQ(result.config.determinism_audit_runs, 4);
    EXPECT_EQ(result.config.determinism_audit_scope, testing::DeterminismAuditScope::Engine);
    EXPECT_EQ(result.config.determinism_violation, testing::DeterminismViolationMode::Warn);
    EXPECT_EQ(result.config.fail_on_log_level, "error");
    EXPECT_EQ(result.config.fail_on_log_category, "physics*");
    ASSERT_TRUE(result.config.record_input_path.has_value());
    EXPECT_EQ(result.config.record_input_path->string(), "tests/out/input.jsonl");
    ASSERT_TRUE(result.config.replay_input_path.has_value());
    EXPECT_EQ(result.config.replay_input_path->string(), "tests/fixtures/input.jsonl");
    EXPECT_EQ(result.config.isolate_tests, testing::IsolateTestsMode::ProcessPerTest);
    EXPECT_EQ(result.config.lua_sandbox, testing::LuaSandboxMode::Off);
    EXPECT_EQ(result.config.perf_mode, testing::PerfMode::Collect);
    ASSERT_TRUE(result.config.perf_budget_path.has_value());
    EXPECT_EQ(result.config.perf_budget_path->string(), "tests/budgets.json");
    ASSERT_TRUE(result.config.perf_trace_path.has_value());
    EXPECT_EQ(result.config.perf_trace_path->string(), "tests/out/trace.json");
}

TEST(TestModeConfigParsing, RejectsUnknownFlag) {
    auto result = parse_args({"--unknown-flag"});
    EXPECT_FALSE(result.ok);
    EXPECT_NE(result.err.find("Unknown flag"), std::string::npos);
}

TEST(TestModeConfigParsing, RejectsInvalidValues) {
    auto bad_seed = parse_args({"--seed", "not_a_number"});
    EXPECT_FALSE(bad_seed.ok);

    auto bad_fps = parse_args({"--fixed-fps", "abc"});
    EXPECT_FALSE(bad_fps.ok);

    auto bad_resolution = parse_args({"--resolution", "12by34"});
    EXPECT_FALSE(bad_resolution.ok);

    auto bad_network = parse_args({"--allow-network", "internet"});
    EXPECT_FALSE(bad_network.ok);

    auto bad_baseline = parse_args({"--baseline-write-mode", "maybe"});
    EXPECT_FALSE(bad_baseline.ok);

    auto bad_renderer = parse_args({"--renderer", "fullscreen"});
    EXPECT_FALSE(bad_renderer.ok);
}

TEST(TestModeConfigValidation, EnforcesMutualExclusionRules) {
    auto result = parse_args({"--test-script", "a.lua", "--test-suite", "tests"});
    ASSERT_TRUE(result.ok);
    auto repo_root = make_temp_repo_root();
    std::string err;
    EXPECT_FALSE(validate_config(result.config, err, repo_root));
    EXPECT_NE(err.find("--test-script"), std::string::npos);

    auto run_conflict = parse_args({"--run-test-id", "id", "--run-test-exact", "name"});
    ASSERT_TRUE(run_conflict.ok);
    EXPECT_FALSE(validate_config(run_conflict.config, err, repo_root));

    auto filter_conflict = parse_args({"--run-test-id", "id", "--test-filter", "foo"});
    ASSERT_TRUE(filter_conflict.ok);
    EXPECT_FALSE(validate_config(filter_conflict.config, err, repo_root));
}

TEST(TestModeConfigValidation, ValidatesShardAndTimeout) {
    auto invalid_shard = parse_args({"--shard", "3", "--total-shards", "2"});
    ASSERT_TRUE(invalid_shard.ok);
    auto repo_root = make_temp_repo_root();
    std::string err;
    EXPECT_FALSE(validate_config(invalid_shard.config, err, repo_root));
    EXPECT_TRUE(invalid_shard.config.run_root.empty());

    auto invalid_timeout = parse_args({"--timeout-seconds", "0"});
    ASSERT_TRUE(invalid_timeout.ok);
    EXPECT_FALSE(validate_config(invalid_timeout.config, err, repo_root));
}

TEST(TestModeConfigValidation, AppliesDefaultsAndDerivedValues) {
    auto result = parse_args({"--test-mode", "--update-baselines", "--shuffle-tests", "--headless"});
    ASSERT_TRUE(result.ok);
    auto repo_root = make_temp_repo_root();
    std::string err;
    ASSERT_TRUE(validate_config(result.config, err, repo_root)) << err;
    EXPECT_FALSE(result.config.fail_on_missing_baseline);
    EXPECT_EQ(result.config.shuffle_seed, result.config.seed);
    EXPECT_EQ(result.config.renderer, testing::RendererMode::Offscreen);
    EXPECT_FALSE(result.config.run_id.empty());
}

TEST(TestModeConfigValidation, GeneratesRunIdAndCreatesDirectories) {
    auto result = parse_args({"--test-mode"});
    ASSERT_TRUE(result.ok);
    auto repo_root = make_temp_repo_root();
    std::string err;
    ASSERT_TRUE(validate_config(result.config, err, repo_root)) << err;

    EXPECT_TRUE(is_filesystem_safe_run_id(result.config.run_id));
    EXPECT_FALSE(result.config.run_root.empty());
    EXPECT_TRUE(std::filesystem::exists(result.config.run_root));
    EXPECT_TRUE(std::filesystem::exists(result.config.artifacts_dir));
    EXPECT_TRUE(std::filesystem::exists(result.config.forensics_dir));
}

TEST(TestModeConfigValidation, RunIdUniquenessAcrossInvocations) {
    auto repo_root = make_temp_repo_root();

    auto first = parse_args({"--test-mode"});
    auto second = parse_args({"--test-mode"});
    ASSERT_TRUE(first.ok);
    ASSERT_TRUE(second.ok);

    std::string err;
    ASSERT_TRUE(validate_config(first.config, err, repo_root)) << err;
    ASSERT_TRUE(validate_config(second.config, err, repo_root)) << err;

    EXPECT_NE(first.config.run_id, second.config.run_id);
}

TEST(TestModeConfigValidation, RejectsPathTraversalForOutputs) {
    auto result = parse_args({"--test-mode", "--artifacts", "../outside"});
    ASSERT_TRUE(result.ok);
    auto repo_root = make_temp_repo_root();
    std::string err;
    EXPECT_FALSE(validate_config(result.config, err, repo_root));
    EXPECT_NE(err.find("outside allowed root"), std::string::npos);
}

TEST(TestModeConfigValidation, RejectsPathTraversalForInputs) {
    auto result = parse_args({"--test-mode", "--test-script", "../escape.lua"});
    ASSERT_TRUE(result.ok);
    auto repo_root = make_temp_repo_root();
    std::string err;
    EXPECT_FALSE(validate_config(result.config, err, repo_root));
    EXPECT_NE(err.find("outside repo root"), std::string::npos);
}

TEST(TestModeConfigValidation, EnablesListTestsFromJsonFlag) {
    auto result = parse_args({"--list-tests-json", "tests/out/list.json"});
    ASSERT_TRUE(result.ok);
    auto repo_root = make_temp_repo_root();
    std::string err;
    ASSERT_TRUE(validate_config(result.config, err, repo_root)) << err;
    EXPECT_TRUE(result.config.list_tests);
}

TEST(TestModeConfigValidation, ResolutionFormatValidationInParse) {
    auto result = parse_args({"--resolution", "1920-1080"});
    EXPECT_FALSE(result.ok);
}

TEST(TestModeConfigValidation, ReportAndArtifactsDefaultsWithinRunRoot) {
    auto result = parse_args({"--test-mode"});
    ASSERT_TRUE(result.ok);
    auto repo_root = make_temp_repo_root();
    std::string err;
    ASSERT_TRUE(validate_config(result.config, err, repo_root)) << err;
    EXPECT_EQ(result.config.artifacts_dir, result.config.run_root / "artifacts");
    EXPECT_EQ(result.config.report_json_path, result.config.run_root / "report.json");
    EXPECT_EQ(result.config.report_junit_path, result.config.run_root / "report.junit.xml");
}
