#include <gtest/gtest.h>

#include <filesystem>

#include "testing/artifact_index.hpp"
#include "testing/artifact_store.hpp"
#include "testing/baseline_manager.hpp"
#include "testing/determinism_audit.hpp"
#include "testing/determinism_guard.hpp"
#include "testing/log_capture.hpp"
#include "testing/lua_sandbox.hpp"
#include "testing/lua_state_query.hpp"
#include "testing/path_sandbox.hpp"
#include "testing/perf_tracker.hpp"
#include "testing/screenshot_capture.hpp"
#include "testing/screenshot_compare.hpp"
#include "testing/test_api_dump.hpp"
#include "testing/test_api_registry.hpp"
#include "testing/test_forensics.hpp"
#include "testing/test_harness_lua.hpp"
#include "testing/test_input_provider.hpp"
#include "testing/test_mode.hpp"
#include "testing/test_mode_config.hpp"
#include "testing/test_runtime.hpp"
#include "testing/timeline_writer.hpp"

namespace fs = std::filesystem;

TEST(StubsCompile, AllHeadersIncludable) {
    testing::TestModeConfig config;
    EXPECT_FALSE(config.enabled);

    testing::TestRuntime runtime;
    EXPECT_FALSE(runtime.is_running());

    testing::TestMode mode;
    testing::set_test_mode_enabled(false);
    EXPECT_FALSE(testing::is_test_mode_enabled());

    testing::TestInputProvider provider;
    testing::TestInputEvent event{};
    provider.enqueue(event);
    testing::TestInputEvent out_event{};
    EXPECT_TRUE(provider.dequeue(out_event));

    testing::LuaStateQuery query;
    std::string out;
    EXPECT_FALSE(query.query_path("root", out));

    testing::LuaSandbox sandbox;
    sandbox.set_enabled(true);
    EXPECT_TRUE(sandbox.is_enabled());

    testing::ScreenshotCapture capture;
    capture.set_size(320, 180);
    EXPECT_FALSE(capture.capture(fs::path("dummy.png")));

    testing::ScreenshotDiff diff = testing::compare_screenshots("a.png", "b.png");
    EXPECT_FALSE(diff.matches);

    testing::LogCapture logs;
    logs.add({"msg", "category", 1});
    EXPECT_FALSE(logs.empty());

    testing::BaselineManager baseline;
    baseline.set_root("tests/baselines");
    EXPECT_FALSE(baseline.resolve("key").empty());

    testing::ArtifactStore artifacts;
    artifacts.set_root("tests/out");
    EXPECT_FALSE(artifacts.write_text("artifact.txt", "data"));

    testing::PathSandbox sandbox_paths;
    sandbox_paths.set_root("tests/out");
    EXPECT_TRUE(sandbox_paths.is_allowed("artifact.txt"));

    testing::TestForensics forensics;
    forensics.record_event("event");
    EXPECT_FALSE(forensics.events().empty());

    testing::DeterminismAudit audit;
    audit.start(2);
    audit.record_hash("hash");
    EXPECT_EQ(audit.runs(), 2);

    testing::DeterminismGuard guard;
    guard.begin_frame();
    guard.end_frame();

    testing::PerfTracker perf;
    perf.record_frame_ms(1.0);
    EXPECT_GT(perf.average_ms(), 0.0);

    testing::TestApiRegistry registry;
    registry.register_entry({"query", testing::TestApiKind::Query});
    EXPECT_EQ(registry.entries().size(), 1u);

    EXPECT_FALSE(testing::write_test_api_json(registry, "test_api.json"));
    EXPECT_FALSE(testing::write_artifact_index("tests/out"));

    testing::TimelineWriter timeline;
    EXPECT_TRUE(timeline.open("timeline.jsonl"));
    timeline.write_event("line");
    timeline.close();
    EXPECT_FALSE(timeline.is_open());

    auto binder = &testing::expose_to_lua;
    (void)binder;
}
