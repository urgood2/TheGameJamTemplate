#pragma once

#include <cstdint>
#include <map>
#include <memory>
#include <string>

#include "testing/artifact_store.hpp"
#include "testing/baseline_manager.hpp"
#include "testing/determinism_guard.hpp"
#include "testing/log_capture.hpp"
#include "testing/path_sandbox.hpp"
#include "testing/perf_tracker.hpp"
#include "testing/screenshot_capture.hpp"
#include "testing/test_api_registry.hpp"
#include "testing/test_forensics.hpp"
#include "testing/test_input_provider.hpp"
#include "testing/test_mode_config.hpp"
#include "testing/timeline_writer.hpp"

namespace testing {

enum class TestStatus {
    Pass,
    Fail,
    Skip,
    Error
};

class TestRuntime {
public:
    TestRuntime() = default;
    ~TestRuntime();

    bool initialize(const TestModeConfig& config);
    void shutdown();
    void tick_frame();
    bool is_running() const;

    TestInputProvider& input_provider();
    LogCapture& log_capture();
    ScreenshotCapture& screenshot_capture();
    BaselineManager& baseline_manager();
    ArtifactStore& artifact_store();
    TestForensics& forensics();
    TestApiRegistry& api_registry();
    DeterminismGuard& determinism_guard();
    PerfTracker& perf_tracker();
    TimelineWriter& timeline_writer();
    PathSandbox& path_sandbox();

    void on_test_start(const std::string& test_id, int attempt);
    void on_test_end(const std::string& test_id, TestStatus status, int attempt);
    void on_run_complete();

    void on_frame_start(int frame_number);
    void on_frame_end(int frame_number);

    void resume_test_coroutine();
    void request_wait_frames(int n);
    bool is_test_complete() const;

    void write_reports();

    bool should_retry_test(const std::string& test_id, TestStatus status) const;
    void prepare_for_retry(const std::string& test_id);

    const TestModeConfig& config() const;
    int current_frame() const;
    int wait_frames_remaining() const;
    int attempts_for(const std::string& test_id) const;
    bool reports_written() const;
    bool schema_validation_failed() const;
    const std::string& schema_validation_error() const;

private:
    void reset_state();
    void allocate_subsystems();
    void release_subsystems();

    bool running_ = false;
    bool reports_written_ = false;
    TestModeConfig config_;

    std::unique_ptr<PathSandbox> path_sandbox_;
    std::unique_ptr<ArtifactStore> artifact_store_;
    std::unique_ptr<LogCapture> log_capture_;
    std::unique_ptr<TestApiRegistry> api_registry_;
    std::unique_ptr<TestInputProvider> input_provider_;
    std::unique_ptr<ScreenshotCapture> screenshot_capture_;
    std::unique_ptr<BaselineManager> baseline_manager_;
    std::unique_ptr<DeterminismGuard> determinism_guard_;
    std::unique_ptr<PerfTracker> perf_tracker_;
    std::unique_ptr<TimelineWriter> timeline_writer_;
    std::unique_ptr<TestForensics> forensics_;

    int current_frame_ = 0;
    int wait_frames_remaining_ = 0;
    bool test_complete_ = false;
    std::string current_test_id_;
    std::map<std::string, int> retry_counts_;
    int resume_count_ = 0;
    bool schema_validation_failed_ = false;
    std::string schema_validation_error_;
};

} // namespace testing
