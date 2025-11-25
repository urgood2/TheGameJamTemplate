#include <gtest/gtest.h>

#include <algorithm>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <string>

#include "spdlog/spdlog.h"

#include "util/crash_reporter.hpp"

namespace fs = std::filesystem;

class CrashReporterTest : public ::testing::Test {
protected:
    void SetUp() override {
        spdlog::set_level(spdlog::level::debug);
    }

    void TearDown() override {
        if (!temp_dir.empty()) {
            std::error_code ec;
            fs::remove_all(temp_dir, ec);
        }
    }

    fs::path temp_dir{};
};

TEST_F(CrashReporterTest, DisabledConfigKeepsReporterOff) {
    crash_reporter::Config cfg{};
    cfg.enabled = false;
    cfg.output_dir.clear();
    crash_reporter::Init(cfg);

    EXPECT_FALSE(crash_reporter::IsEnabled());

    auto report = crash_reporter::CaptureReport("disabled", false);
    EXPECT_EQ(report.build_id, cfg.build_id);
    EXPECT_TRUE(report.stacktrace.empty());
}

TEST_F(CrashReporterTest, CapturesMetadataAndLogsAfterInit) {
    crash_reporter::Config cfg{};
    cfg.build_id = "test-build-id";
    cfg.max_log_entries = 8;
    cfg.enable_file_output = false;
    crash_reporter::Init(cfg);

    spdlog::info("crash reporter smoke log {}", 7);

    auto report = crash_reporter::CaptureReport("unit-crash", true);
    EXPECT_TRUE(crash_reporter::IsEnabled());
    EXPECT_EQ(report.reason, "unit-crash");
    EXPECT_EQ(report.build_id, "test-build-id");
    EXPECT_FALSE(report.platform.empty());
    EXPECT_FALSE(report.stacktrace.empty());

    const bool found_log = std::any_of(report.logs.begin(), report.logs.end(), [](const auto& entry) {
        return entry.message.find("crash reporter smoke log") != std::string::npos;
    });
    EXPECT_TRUE(found_log);
}

TEST_F(CrashReporterTest, PersistsReportWhenFileOutputEnabled) {
    temp_dir = fs::temp_directory_path() / "crash_reporter_gtest";
    std::error_code ec;
    fs::remove_all(temp_dir, ec);

    crash_reporter::Config cfg{};
    cfg.build_id = "persist-build";
    cfg.output_dir = temp_dir.string();
    cfg.enable_file_output = true;
    crash_reporter::Init(cfg);

    auto report = crash_reporter::CaptureReport("persist-test", false);
    const auto path = crash_reporter::PersistReport(report);

    ASSERT_TRUE(path.has_value());
    EXPECT_TRUE(fs::exists(*path));

    std::ifstream in(*path);
    const std::string contents((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
    EXPECT_NE(contents.find(report.reason), std::string::npos);
    EXPECT_NE(contents.find(cfg.build_id), std::string::npos);

    EXPECT_FALSE(crash_reporter::LastSerializedReport().empty());
}
