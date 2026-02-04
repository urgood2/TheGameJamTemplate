#include <gtest/gtest.h>

#include <filesystem>
#include <fstream>
#include <string>

#include "nlohmann/json.hpp"
#include "testing/perf_tracker.hpp"
#include "testing/test_mode_config.hpp"

namespace {

testing::TestModeConfig make_config(testing::PerfMode mode = testing::PerfMode::Collect) {
    testing::TestModeConfig config;
    config.perf_mode = mode;
    return config;
}

std::filesystem::path make_temp_root() {
    auto root = std::filesystem::temp_directory_path() / "perf_tracker_tests";
    std::filesystem::create_directories(root);
    return root;
}

} // namespace

TEST(PerfTracker, MarkAndMetrics) {
    testing::PerfTracker tracker;
    tracker.initialize(make_config());

    tracker.record_frame(1, 1.0f, 2.0f);
    tracker.record_frame(2, 2.0f, 1.0f);
    auto token = tracker.mark();
    tracker.record_frame(3, 4.0f, 0.0f);

    auto metrics = tracker.get_metrics_since(token);
    EXPECT_EQ(token.frame_number, 2);
    EXPECT_EQ(metrics.frame_count, 1);
    EXPECT_NEAR(metrics.total_sim_ms, 4.0f, 0.001f);
    EXPECT_NEAR(metrics.total_render_ms, 0.0f, 0.001f);
    EXPECT_NEAR(metrics.max_frame_ms, 4.0f, 0.001f);
    EXPECT_NEAR(metrics.avg_frame_ms, 4.0f, 0.001f);
    EXPECT_NEAR(metrics.p95_frame_ms, 4.0f, 0.001f);
    EXPECT_NEAR(metrics.p99_frame_ms, 4.0f, 0.001f);
}

TEST(PerfTracker, PercentileOrdering) {
    testing::PerfTracker tracker;
    tracker.initialize(make_config());

    for (int i = 1; i <= 100; ++i) {
        tracker.record_frame(i, static_cast<float>(i), 0.0f);
    }

    auto metrics = tracker.get_current_metrics();
    EXPECT_GE(metrics.max_frame_ms, metrics.p99_frame_ms);
    EXPECT_GE(metrics.p99_frame_ms, metrics.p95_frame_ms);
    EXPECT_GT(metrics.p95_frame_ms, 0.0f);
}

TEST(PerfTracker, TestScopedMetrics) {
    testing::PerfTracker tracker;
    tracker.initialize(make_config());

    tracker.record_frame(1, 1.0f, 0.0f);
    tracker.begin_test("test.alpha");
    tracker.record_frame(2, 2.0f, 0.0f);
    tracker.record_frame(3, 3.0f, 0.0f);
    tracker.end_test();
    tracker.record_frame(4, 4.0f, 0.0f);

    auto metrics = tracker.get_test_metrics();
    EXPECT_EQ(metrics.frame_count, 2);
    EXPECT_NEAR(metrics.total_sim_ms, 5.0f, 0.001f);
    EXPECT_NEAR(metrics.max_frame_ms, 3.0f, 0.001f);
}

TEST(PerfTracker, BudgetViolations) {
    testing::PerfTracker tracker;
    tracker.initialize(make_config());

    testing::BudgetDef budget;
    budget.metric = "max_frame_ms";
    budget.op = "lte";
    budget.value = 10.0f;

    tracker.set_budgets({{"max_frame_ms", budget}});
    tracker.check_budget("max_frame_ms", 12.0f);

    EXPECT_TRUE(tracker.has_budget_violations());
    auto violations = tracker.get_violations();
    ASSERT_EQ(violations.size(), 1u);
    EXPECT_EQ(violations[0].metric, "max_frame_ms");
    EXPECT_EQ(violations[0].op, "lte");
    EXPECT_NEAR(violations[0].budget_value, 10.0f, 0.001f);
    EXPECT_NEAR(violations[0].actual_value, 12.0f, 0.001f);
}

TEST(PerfTracker, TraceExport) {
    testing::PerfTracker tracker;
    tracker.initialize(make_config());

    auto path = make_temp_root() / "trace.json";
    tracker.enable_trace_export(path);
    tracker.record_frame(1, 1.0f, 2.0f);
    tracker.write_trace();

    std::ifstream input(path);
    ASSERT_TRUE(static_cast<bool>(input));

    nlohmann::json data;
    input >> data;
    ASSERT_TRUE(data.contains("traceEvents"));
    EXPECT_TRUE(data["traceEvents"].is_array());
    EXPECT_GE(data["traceEvents"].size(), 1u);
}

