#include "testing/test_runtime.hpp"

#include <algorithm>
#include <chrono>
#include <cstdlib>
#include <ctime>
#include <fstream>
#include <iomanip>
#include <sstream>

#include <nlohmann/json.hpp>
#include <spdlog/spdlog.h>

#include "testing/artifact_store.hpp"
#include "testing/baseline_manager.hpp"
#include "testing/determinism_guard.hpp"
#include "testing/log_capture.hpp"
#include "testing/path_sandbox.hpp"
#include "testing/perf_tracker.hpp"
#include "testing/schema_validator.hpp"
#include "testing/screenshot_capture.hpp"
#include "testing/test_api_registry.hpp"
#include "testing/test_forensics.hpp"
#include "testing/test_input_provider.hpp"
#include "testing/timeline_writer.hpp"

namespace testing {
namespace {

std::string platform_string() {
#if defined(_WIN32)
    return "windows";
#elif defined(__APPLE__)
    return "mac";
#elif defined(__linux__)
    return "linux";
#else
    return "unknown";
#endif
}

std::string format_resolution(const TestModeConfig& config) {
    std::ostringstream oss;
    oss << config.resolution_width << "x" << config.resolution_height;
    return oss.str();
}

std::string current_timestamp_utc() {
    std::time_t now = std::time(nullptr);
    std::tm tm{};
#if defined(_WIN32)
    gmtime_s(&tm, &now);
#else
    gmtime_r(&now, &tm);
#endif
    std::ostringstream oss;
    oss << std::put_time(&tm, "%Y-%m-%dT%H:%M:%SZ");
    return oss.str();
}

nlohmann::json build_report_json(const TestModeConfig& config) {
    nlohmann::json run;
    run["run_id"] = config.run_id;
    run["seed"] = config.seed;
    run["platform"] = platform_string();
    run["engine_version"] = "dev";
    run["resolution"] = format_resolution(config);
    if (!config.baseline_key.empty()) {
        run["baseline_key"] = config.baseline_key;
    }

    nlohmann::json summary;
    summary["passed"] = 0;
    summary["failed"] = 0;
    summary["skipped"] = 0;
    summary["flaky"] = 0;

    nlohmann::json report;
    report["schema_version"] = "1.0.0";
    report["run"] = std::move(run);
    report["tests"] = nlohmann::json::array();
    report["summary"] = std::move(summary);
    return report;
}

nlohmann::json build_run_manifest_json(const TestModeConfig& config) {
    nlohmann::json manifest;
    manifest["schema_version"] = "1.0.0";
    manifest["args"] = nlohmann::json::array();
    manifest["seed"] = config.seed;
    manifest["platform"] = platform_string();
    manifest["resolution"] = format_resolution(config);
    manifest["timestamp"] = current_timestamp_utc();
    if (!config.baseline_key.empty()) {
        manifest["baseline_key"] = config.baseline_key;
    }
    manifest["shard"] = config.shard;
    manifest["total_shards"] = config.total_shards;
    manifest["timeout_seconds"] = config.timeout_seconds;
    return manifest;
}

nlohmann::json build_test_api_json() {
    nlohmann::json api;
    api["schema_version"] = "1.0.0";
    api["version"] = "1.0.0";
    api["state_paths"] = nlohmann::json::array();
    api["queries"] = nlohmann::json::array();
    api["commands"] = nlohmann::json::array();
    api["capabilities"] = nlohmann::json::object();
    return api;
}

std::filesystem::path resolve_output_path(const TestModeConfig& config,
                                          const std::filesystem::path& path,
                                          const std::string& fallback) {
    if (path.empty()) {
        return config.run_root / fallback;
    }
    if (path.is_absolute()) {
        return path;
    }
    return config.run_root / path;
}

bool validate_and_write(const std::filesystem::path& schema_path,
                        const nlohmann::json& payload,
                        const std::filesystem::path& output_path,
                        std::string& err) {
    auto result = validate_json_with_schema_file(payload, schema_path);
    if (!result.ok) {
        err = result.error;
        return false;
    }
    return write_json_file(output_path, payload, err);
}

bool write_text_file(const std::filesystem::path& path,
                     const std::string& contents,
                     std::string& err) {
    std::error_code ec;
    if (path.has_parent_path()) {
        std::filesystem::create_directories(path.parent_path(), ec);
        if (ec) {
            err = "failed to create directory: " + path.parent_path().string();
            return false;
        }
    }
    std::ofstream out(path);
    if (!out) {
        err = "unable to write file: " + path.string();
        return false;
    }
    out << contents;
    return true;
}

} // namespace

bool TestRuntime::initialize(const TestModeConfig& config) {
    if (running_) {
        shutdown();
    }

    config_ = config;
    reset_state();
    allocate_subsystems();

    if (path_sandbox_) {
        path_sandbox_->set_root(config_.run_root);
    }
    if (artifact_store_) {
        artifact_store_->set_root(config_.artifacts_dir);
    }
    if (baseline_manager_) {
        baseline_manager_->set_root(config_.baseline_staging_dir);
    }
    if (screenshot_capture_) {
        screenshot_capture_->set_size(config_.resolution_width, config_.resolution_height);
    }

    running_ = true;
    return true;
}

TestRuntime::~TestRuntime() {
    shutdown();
}

void TestRuntime::shutdown() {
    running_ = false;
    release_subsystems();
    reset_state();
}

void TestRuntime::tick_frame() {
    if (!running_) {
        return;
    }

    on_frame_start(current_frame_ + 1);
    if (wait_frames_remaining_ == 0) {
        resume_test_coroutine();
    }
    on_frame_end(current_frame_);
}

bool TestRuntime::is_running() const {
    return running_;
}

TestInputProvider& TestRuntime::input_provider() {
    return *input_provider_;
}

LogCapture& TestRuntime::log_capture() {
    return *log_capture_;
}

ScreenshotCapture& TestRuntime::screenshot_capture() {
    return *screenshot_capture_;
}

BaselineManager& TestRuntime::baseline_manager() {
    return *baseline_manager_;
}

ArtifactStore& TestRuntime::artifact_store() {
    return *artifact_store_;
}

TestForensics& TestRuntime::forensics() {
    return *forensics_;
}

TestApiRegistry& TestRuntime::api_registry() {
    return *api_registry_;
}

DeterminismGuard& TestRuntime::determinism_guard() {
    return *determinism_guard_;
}

PerfTracker& TestRuntime::perf_tracker() {
    return *perf_tracker_;
}

TimelineWriter& TestRuntime::timeline_writer() {
    return *timeline_writer_;
}

PathSandbox& TestRuntime::path_sandbox() {
    return *path_sandbox_;
}

void TestRuntime::on_test_start(const std::string& test_id, int attempt) {
    current_test_id_ = test_id;
    test_complete_ = false;
    wait_frames_remaining_ = 0;

    const int normalized_attempt = std::max(1, attempt);
    auto it = retry_counts_.find(test_id);
    if (it == retry_counts_.end() || normalized_attempt > it->second) {
        retry_counts_[test_id] = normalized_attempt;
    }
}

void TestRuntime::on_test_end(const std::string& test_id, TestStatus status, int attempt) {
    (void)status;
    current_test_id_ = test_id;
    test_complete_ = true;

    const int normalized_attempt = std::max(1, attempt);
    auto it = retry_counts_.find(test_id);
    if (it == retry_counts_.end() || normalized_attempt > it->second) {
        retry_counts_[test_id] = normalized_attempt;
    }
}

void TestRuntime::on_run_complete() {
    write_reports();
}

void TestRuntime::on_frame_start(int frame_number) {
    current_frame_ = frame_number;
    if (wait_frames_remaining_ > 0) {
        --wait_frames_remaining_;
    }

    if (determinism_guard_) {
        determinism_guard_->begin_frame();
    }

    if (input_provider_) {
        TestInputEvent event{};
        int applied = 0;
        while (input_provider_->dequeue(event)) {
            ++applied;
        }
        (void)applied;
    }
}

void TestRuntime::on_frame_end(int frame_number) {
    (void)frame_number;
    if (perf_tracker_) {
        perf_tracker_->record_frame_ms(0.0);
    }
    if (timeline_writer_ && timeline_writer_->is_open()) {
        timeline_writer_->write_event("frame_end");
    }
    if (determinism_guard_) {
        determinism_guard_->end_frame();
    }
}

void TestRuntime::resume_test_coroutine() {
    ++resume_count_;
}

void TestRuntime::request_wait_frames(int n) {
    wait_frames_remaining_ = std::max(0, n);
}

bool TestRuntime::is_test_complete() const {
    return test_complete_;
}

void TestRuntime::write_reports() {
    reports_written_ = false;
    schema_validation_failed_ = false;
    schema_validation_error_.clear();

    std::error_code ec;
    if (!config_.run_root.empty()) {
        std::filesystem::create_directories(config_.run_root, ec);
        if (ec) {
            schema_validation_failed_ = true;
            schema_validation_error_ = "failed to create run root: " + config_.run_root.string();
            SPDLOG_ERROR("{}", schema_validation_error_);
#ifndef UNIT_TESTS
            std::exit(2);
#endif
            return;
        }
    }

    const auto report = build_report_json(config_);
    const auto run_manifest = build_run_manifest_json(config_);
    const auto test_api = build_test_api_json();

    std::string err;
    const auto report_path = resolve_output_path(config_, config_.report_json_path, "report.json");
    const auto junit_path = resolve_output_path(config_, config_.report_junit_path, "report.junit.xml");
    const auto manifest_path = resolve_output_path(config_, "run_manifest.json", "run_manifest.json");
    const auto test_api_path = resolve_output_path(config_, "test_api.json", "test_api.json");

    if (!validate_and_write("tests/schemas/report.schema.json", report, report_path, err) ||
        !validate_and_write("tests/schemas/run_manifest.schema.json", run_manifest, manifest_path, err) ||
        !validate_and_write("tests/schemas/test_api.schema.json", test_api, test_api_path, err)) {
        schema_validation_failed_ = true;
        schema_validation_error_ = err.empty() ? "schema validation failed" : err;
        SPDLOG_ERROR("Schema validation failed: {}", schema_validation_error_);
#ifndef UNIT_TESTS
        std::exit(2);
#endif
        return;
    }

    if (!junit_path.empty()) {
        std::string junit_err;
        if (!write_text_file(junit_path, "", junit_err)) {
            SPDLOG_ERROR("Unable to write junit report: {}", junit_err);
        }
    }

    reports_written_ = true;
}

bool TestRuntime::should_retry_test(const std::string& test_id, TestStatus status) const {
    if (status != TestStatus::Fail) {
        return false;
    }
    if (config_.retry_failures <= 0) {
        return false;
    }

    int attempts_so_far = 1;
    auto it = retry_counts_.find(test_id);
    if (it != retry_counts_.end()) {
        attempts_so_far = it->second;
    }

    return attempts_so_far < (config_.retry_failures + 1);
}

void TestRuntime::prepare_for_retry(const std::string& test_id) {
    int& attempts = retry_counts_[test_id];
    if (attempts <= 0) {
        attempts = 1;
    }
    ++attempts;

    if (input_provider_) {
        input_provider_->clear();
    }
    if (log_capture_) {
        log_capture_->clear();
    }
    if (forensics_) {
        forensics_->clear();
    }
    if (determinism_guard_) {
        determinism_guard_->reset();
    }
    if (perf_tracker_) {
        perf_tracker_->clear();
    }
    if (timeline_writer_) {
        timeline_writer_->close();
    }

    test_complete_ = false;
}

const TestModeConfig& TestRuntime::config() const {
    return config_;
}

int TestRuntime::current_frame() const {
    return current_frame_;
}

int TestRuntime::wait_frames_remaining() const {
    return wait_frames_remaining_;
}

int TestRuntime::attempts_for(const std::string& test_id) const {
    auto it = retry_counts_.find(test_id);
    if (it == retry_counts_.end()) {
        return 0;
    }
    return it->second;
}

bool TestRuntime::reports_written() const {
    return reports_written_;
}

bool TestRuntime::schema_validation_failed() const {
    return schema_validation_failed_;
}

const std::string& TestRuntime::schema_validation_error() const {
    return schema_validation_error_;
}

void TestRuntime::reset_state() {
    reports_written_ = false;
    schema_validation_failed_ = false;
    schema_validation_error_.clear();
    current_frame_ = 0;
    wait_frames_remaining_ = 0;
    test_complete_ = false;
    current_test_id_.clear();
    retry_counts_.clear();
    resume_count_ = 0;
}

void TestRuntime::allocate_subsystems() {
    path_sandbox_ = std::make_unique<PathSandbox>();
    artifact_store_ = std::make_unique<ArtifactStore>();
    log_capture_ = std::make_unique<LogCapture>();
    api_registry_ = std::make_unique<TestApiRegistry>();
    input_provider_ = std::make_unique<TestInputProvider>();
    screenshot_capture_ = std::make_unique<ScreenshotCapture>();
    baseline_manager_ = std::make_unique<BaselineManager>();
    determinism_guard_ = std::make_unique<DeterminismGuard>();
    perf_tracker_ = std::make_unique<PerfTracker>();
    timeline_writer_ = std::make_unique<TimelineWriter>();
    forensics_ = std::make_unique<TestForensics>();
}

void TestRuntime::release_subsystems() {
    forensics_.reset();
    timeline_writer_.reset();
    perf_tracker_.reset();
    determinism_guard_.reset();
    baseline_manager_.reset();
    screenshot_capture_.reset();
    input_provider_.reset();
    api_registry_.reset();
    log_capture_.reset();
    artifact_store_.reset();
    path_sandbox_.reset();
}

} // namespace testing
