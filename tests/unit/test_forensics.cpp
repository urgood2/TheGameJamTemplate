#include <gtest/gtest.h>

#include <atomic>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <string>

#include "testing/test_forensics.hpp"
#include "testing/test_runtime.hpp"

namespace {

std::filesystem::path make_temp_root() {
    static std::atomic<int> counter{0};
    const auto now = std::chrono::steady_clock::now().time_since_epoch().count();
    auto root = std::filesystem::temp_directory_path() /
                ("test_forensics_" + std::to_string(now) + "_" + std::to_string(counter.fetch_add(1)));
    std::filesystem::create_directories(root);
    return root;
}

testing::TestModeConfig make_config() {
    testing::TestModeConfig config;
    auto root = make_temp_root();
    config.run_root = root;
    config.artifacts_dir = root / "artifacts";
    config.forensics_dir = root / "forensics";
    config.report_json_path = std::filesystem::path("report.json");
    config.report_junit_path = std::filesystem::path("report.xml");
    config.baseline_staging_dir = root / "baselines";
    config.resolution_width = 800;
    config.resolution_height = 450;
    config.fixed_fps = 60;
    config.seed = 123;
    config.run_id = "forensics_run";
    config.exit_on_schema_failure = false;
    return config;
}

std::string read_file(const std::filesystem::path& path) {
    std::ifstream in(path);
    std::string contents;
    std::string line;
    while (std::getline(in, line)) {
        contents += line;
        contents.push_back('\n');
    }
    return contents;
}

} // namespace

TEST(TestForensics, WritesLastLogs) {
    testing::TestRuntime runtime;
    auto config = make_config();
    ASSERT_TRUE(runtime.initialize(config));

    runtime.log_capture().add({1, "first", "test", "info", "2026-02-03T00:00:01Z"});
    runtime.log_capture().add({2, "second", "test", "warn", "2026-02-03T00:00:02Z"});

    runtime.forensics().capture_last_logs(1);

    const auto path = config.forensics_dir / "last_logs.txt";
    ASSERT_TRUE(std::filesystem::exists(path));
    const auto contents = read_file(path);
    EXPECT_NE(contents.find("E2E Test Logs"), std::string::npos);
    EXPECT_NE(contents.find("Run: forensics_run"), std::string::npos);
    EXPECT_NE(contents.find("second"), std::string::npos);
}

TEST(TestForensics, WritesReproScripts) {
    testing::TestRuntime runtime;
    auto config = make_config();
    config.test_script = std::string("tests/sample.lua");
    ASSERT_TRUE(runtime.initialize(config));

    runtime.forensics().write_repro_scripts();

    const auto repro_sh = config.forensics_dir / "repro.sh";
    const auto repro_ps1 = config.forensics_dir / "repro.ps1";
    ASSERT_TRUE(std::filesystem::exists(repro_sh));
    ASSERT_TRUE(std::filesystem::exists(repro_ps1));

    const auto contents = read_file(repro_sh);
    EXPECT_NE(contents.find("--seed 123"), std::string::npos);
    EXPECT_NE(contents.find("--fixed-fps 60"), std::string::npos);

    std::error_code ec;
    auto perms = std::filesystem::status(repro_sh, ec).permissions();
    EXPECT_FALSE(ec);
    const bool executable = (perms & std::filesystem::perms::owner_exec) != std::filesystem::perms::none;
    EXPECT_TRUE(executable);
}

TEST(TestForensics, CaptureOnFailureWritesArtifacts) {
    testing::TestRuntime runtime;
    auto config = make_config();
    ASSERT_TRUE(runtime.initialize(config));

    runtime.log_capture().add({1, "log", "test", "info", "2026-02-03T00:00:01Z"});
    runtime.forensics().capture_on_failure("case", testing::TestStatus::Fail);

    EXPECT_TRUE(std::filesystem::exists(config.forensics_dir / "logs.jsonl"));
    EXPECT_TRUE(std::filesystem::exists(config.forensics_dir / "last_logs.txt"));
    EXPECT_TRUE(std::filesystem::exists(config.forensics_dir / "repro.sh"));
    EXPECT_TRUE(std::filesystem::exists(config.forensics_dir / "repro.ps1"));
    EXPECT_TRUE(std::filesystem::exists(config.forensics_dir / "run_manifest.json"));
    EXPECT_TRUE(std::filesystem::exists(config.forensics_dir / "test_api.json"));
}
