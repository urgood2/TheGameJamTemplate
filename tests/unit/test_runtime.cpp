#include <gtest/gtest.h>

#include <atomic>
#include <chrono>
#include <filesystem>

#include <nlohmann/json.hpp>

#include "testing/schema_validator.hpp"
#include "testing/test_input_provider.hpp"
#include "testing/test_runtime.hpp"

namespace {

std::filesystem::path make_temp_root() {
    static std::atomic<int> counter{0};
    const auto now = std::chrono::steady_clock::now().time_since_epoch().count();
    auto root = std::filesystem::temp_directory_path() /
                ("test_runtime_" + std::to_string(now) + "_" + std::to_string(counter.fetch_add(1)));
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
    config.exit_on_schema_failure = false;
    return config;
}

} // namespace

TEST(TestRuntime, InitializeCreatesSubsystems) {
    testing::TestRuntime runtime;
    EXPECT_FALSE(runtime.is_running());

    auto config = make_config();
    ASSERT_TRUE(runtime.initialize(config));
    EXPECT_TRUE(runtime.is_running());
    EXPECT_EQ(runtime.config().run_root, config.run_root);

    testing::TestInputEvent event{};
    runtime.input_provider().enqueue(event);
    EXPECT_EQ(runtime.input_provider().size(), 1u);

    EXPECT_TRUE(runtime.path_sandbox().is_allowed("artifact.txt"));
    EXPECT_FALSE(runtime.baseline_manager().baseline_key().empty());
}

TEST(TestRuntime, FrameAdvancementAndWait) {
    testing::TestRuntime runtime;
    auto config = make_config();
    ASSERT_TRUE(runtime.initialize(config));

    runtime.request_wait_frames(2);
    runtime.input_provider().enqueue({"key", 1, 0.0f, 0.0f});

    runtime.tick_frame();
    EXPECT_EQ(runtime.current_frame(), 1);
    EXPECT_EQ(runtime.wait_frames_remaining(), 1);
    EXPECT_EQ(runtime.input_provider().size(), 0u);

    runtime.tick_frame();
    EXPECT_EQ(runtime.current_frame(), 2);
    EXPECT_EQ(runtime.wait_frames_remaining(), 0);
}

TEST(TestRuntime, RetryMechanismResetsSubsystems) {
    testing::TestRuntime runtime;
    auto config = make_config();
    config.retry_failures = 1;
    config.perf_mode = testing::PerfMode::Collect;
    ASSERT_TRUE(runtime.initialize(config));

    runtime.on_test_start("case", 1);
    EXPECT_TRUE(runtime.should_retry_test("case", testing::TestStatus::Fail));

    runtime.input_provider().enqueue({"mouse", 0, 1.0f, 1.0f});
    runtime.log_capture().add({0, "msg", "cat", "info", ""});
    runtime.forensics().record_event("event");
    runtime.perf_tracker().record_frame(1, 5.0f, 0.0f);
    EXPECT_TRUE(runtime.timeline_writer().open("timeline.jsonl"));

    runtime.prepare_for_retry("case");
    EXPECT_EQ(runtime.attempts_for("case"), 2);
    EXPECT_EQ(runtime.input_provider().size(), 0u);
    EXPECT_TRUE(runtime.log_capture().empty());
    EXPECT_TRUE(runtime.forensics().events().empty());
    EXPECT_EQ(runtime.perf_tracker().get_current_metrics().avg_frame_ms, 0.0f);
    EXPECT_FALSE(runtime.timeline_writer().is_open());
}

TEST(TestRuntime, RunCompleteWritesReports) {
    testing::TestRuntime runtime;
    auto config = make_config();
    ASSERT_TRUE(runtime.initialize(config));

    EXPECT_FALSE(runtime.reports_written());
    runtime.on_run_complete();
    EXPECT_TRUE(runtime.reports_written());
    EXPECT_FALSE(runtime.schema_validation_failed());
}

TEST(TestRuntime, TestCompletionFlag) {
    testing::TestRuntime runtime;
    auto config = make_config();
    ASSERT_TRUE(runtime.initialize(config));

    runtime.on_test_start("case", 1);
    EXPECT_FALSE(runtime.is_test_complete());

    runtime.on_test_end("case", testing::TestStatus::Pass, 1);
    EXPECT_TRUE(runtime.is_test_complete());
}

TEST(TestRuntime, SchemaValidationProducesValidJson) {
    testing::TestRuntime runtime;
    auto config = make_config();
    ASSERT_TRUE(runtime.initialize(config));

    runtime.on_run_complete();
    EXPECT_FALSE(runtime.schema_validation_failed());

    std::filesystem::path report_path = config.report_json_path;
    if (report_path.is_relative()) {
        report_path = config.run_root / report_path;
    }

    nlohmann::json report;
    nlohmann::json schema;
    std::string err;
    ASSERT_TRUE(testing::load_json_file(report_path, report, err));
    ASSERT_TRUE(testing::load_json_file("tests/schemas/report.schema.json", schema, err));
    auto result = testing::validate_json_against_schema(report, schema);
    EXPECT_TRUE(result.ok);

    auto manifest_path = config.run_root / "run_manifest.json";
    nlohmann::json manifest;
    ASSERT_TRUE(testing::load_json_file(manifest_path, manifest, err));
    ASSERT_TRUE(manifest.contains("determinism_pins"));
    ASSERT_TRUE(manifest.contains("test_api_fingerprint"));
    EXPECT_TRUE(manifest["determinism_pins"].is_object());
    EXPECT_TRUE(manifest["test_api_fingerprint"].is_string());
}

TEST(TestRuntime, SchemaValidationDetectsInvalidPayload) {
    testing::TestRuntime runtime;
    auto config = make_config();
    config.resolution_width = -1;
    config.resolution_height = -1;
    ASSERT_TRUE(runtime.initialize(config));

    runtime.on_run_complete();
    EXPECT_TRUE(runtime.schema_validation_failed());
    EXPECT_FALSE(runtime.schema_validation_error().empty());
}
