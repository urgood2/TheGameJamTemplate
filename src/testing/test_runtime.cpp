#include "testing/test_runtime.hpp"

#include <algorithm>
#include <cfenv>
#include <chrono>
#include <clocale>
#include <cstdlib>
#include <ctime>
#include <fstream>
#include <iomanip>
#include <optional>
#include <sstream>

#if defined(__SSE2__) || defined(_M_X64) || (defined(_M_IX86_FP) && _M_IX86_FP >= 2)
#include <xmmintrin.h>
#endif

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
SchemaValidationResult validate_json_with_schema_file(const nlohmann::json& instance,
                                                     const std::filesystem::path& schema_path);
bool write_json_file(const std::filesystem::path& path,
                     const nlohmann::json& value,
                     std::string& err);

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

std::string current_locale_name() {
    const char* locale = std::setlocale(LC_ALL, nullptr);
    if (locale && *locale) {
        return locale;
    }
    return "C";
}

std::string current_timezone_name() {
    const char* tz = std::getenv("TZ");
    if (tz && *tz) {
        return tz;
    }
    return "UTC";
}

std::string rounding_mode_name() {
    switch (std::fegetround()) {
        case FE_TONEAREST:
            return "nearest";
        case FE_TOWARDZERO:
            return "toward_zero";
        case FE_UPWARD:
            return "toward_inf";
        case FE_DOWNWARD:
            return "toward_neg_inf";
        default:
            return "nearest";
    }
}

bool ftz_daz_enabled() {
#if defined(__SSE2__) || defined(_M_X64) || (defined(_M_IX86_FP) && _M_IX86_FP >= 2)
    const bool ftz = (_MM_GET_FLUSH_ZERO_MODE() == _MM_FLUSH_ZERO_ON);
    return ftz;
#else
    return false;
#endif
}

nlohmann::json build_determinism_pins(const TestModeConfig& config) {
    nlohmann::json pins;
    pins["ftz_daz"] = ftz_daz_enabled();
    pins["rounding"] = rounding_mode_name();
    pins["locale"] = current_locale_name();
    pins["timezone"] = current_timezone_name();
    pins["thread_mode"] = "single";
    if (config.allow_network == NetworkMode::Deny) {
        pins["network_mode"] = "deny";
    } else if (config.allow_network == NetworkMode::Localhost) {
        pins["network_mode"] = "localhost";
    } else {
        pins["network_mode"] = "any";
    }
    return pins;
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
    manifest["determinism_pins"] = build_determinism_pins(config);
    manifest["test_api_fingerprint"] = "";
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
        path_sandbox_->initialize(config_);
    }
    if (artifact_store_ && path_sandbox_) {
        artifact_store_->initialize(config_, *path_sandbox_);
    }
    if (baseline_manager_) {
        baseline_manager_->initialize(config_);
    }
    if (api_registry_) {
        api_registry_->initialize(config_);
    }
    if (determinism_guard_) {
        determinism_guard_->initialize(config_);
    }
    if (perf_tracker_) {
        perf_tracker_->initialize(config_);
    }
    if (screenshot_capture_) {
        screenshot_capture_->initialize(config_);
    }
    if (forensics_) {
        forensics_->initialize(config_, *this);
    }
    if (timeline_writer_) {
        timeline_writer_->initialize(config_);
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

const TestApiRegistry& TestRuntime::api_registry() const {
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
    requested_outcome_.clear();
    requested_outcome_reason_.clear();

    const int normalized_attempt = std::max(1, attempt);
    current_attempt_ = normalized_attempt;
    auto it = retry_counts_.find(test_id);
    if (it == retry_counts_.end() || normalized_attempt > it->second) {
        retry_counts_[test_id] = normalized_attempt;
    }

    if (perf_tracker_) {
        perf_tracker_->begin_test(test_id);
    }
}

void TestRuntime::on_test_end(const std::string& test_id, TestStatus status, int attempt) {
    current_test_id_ = test_id;
    test_complete_ = true;

    const int normalized_attempt = std::max(1, attempt);
    current_attempt_ = normalized_attempt;
    auto it = retry_counts_.find(test_id);
    if (it == retry_counts_.end() || normalized_attempt > it->second) {
        retry_counts_[test_id] = normalized_attempt;
    }

    if (perf_tracker_) {
        perf_tracker_->end_test();
    }

    if (forensics_ && (status == TestStatus::Fail || status == TestStatus::Error)) {
        if (!should_retry_test(test_id, status)) {
            forensics_->capture_on_failure(test_id, status);
        }
    }
}

void TestRuntime::on_run_complete() {
    write_reports();
    if (forensics_) {
        forensics_->capture_on_run_complete();
    }
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
    if (perf_tracker_) {
        perf_tracker_->record_frame(frame_number, 0.0f, 0.0f);
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
            if (config_.exit_on_schema_failure) {
                std::exit(2);
            }
            return;
        }
    }

    const auto report = build_report_json(config_);
    auto run_manifest = build_run_manifest_json(config_);
    const auto test_api = build_test_api_json();

    if (api_registry_) {
        run_manifest["test_api_fingerprint"] = api_registry_->compute_fingerprint();
    }

    std::string err;
    auto resolve_output = [&](const std::filesystem::path& path,
                              const std::string& label) -> std::optional<std::filesystem::path> {
        if (path.empty()) {
            return std::nullopt;
        }
        if (!path_sandbox_) {
            return path;
        }
        auto resolved = path_sandbox_->resolve_write_path(path);
        if (!resolved) {
            err = "output path outside sandbox for " + label + ": " + path.string();
            return std::nullopt;
        }
        return resolved;
    };

    const auto report_path = resolve_output_path(config_, config_.report_json_path, "report.json");
    const auto junit_path = resolve_output_path(config_, config_.report_junit_path, "report.junit.xml");
    const auto manifest_path = resolve_output_path(config_, "run_manifest.json", "run_manifest.json");
    const auto test_api_path = resolve_output_path(config_, "test_api.json", "test_api.json");

    auto resolved_report = resolve_output(report_path, "report");
    auto resolved_manifest = resolve_output(manifest_path, "run manifest");
    auto resolved_test_api = resolve_output(test_api_path, "test api");
    std::optional<std::filesystem::path> resolved_junit;
    if (!junit_path.empty()) {
        resolved_junit = resolve_output(junit_path, "junit report");
    }

    if (!resolved_report || !resolved_manifest || !resolved_test_api) {
        schema_validation_failed_ = true;
        schema_validation_error_ = err.empty() ? "output path outside sandbox" : err;
        SPDLOG_ERROR("{}", schema_validation_error_);
#ifndef UNIT_TESTS
        std::exit(2);
#endif
        return;
    }

    if (!validate_and_write("tests/schemas/report.schema.json", report, *resolved_report, err) ||
        !validate_and_write("tests/schemas/run_manifest.schema.json", run_manifest, *resolved_manifest, err) ||
        !validate_and_write("tests/schemas/test_api.schema.json", test_api, *resolved_test_api, err)) {
        schema_validation_failed_ = true;
        schema_validation_error_ = err.empty() ? "schema validation failed" : err;
        SPDLOG_ERROR("Schema validation failed: {}", schema_validation_error_);
        if (config_.exit_on_schema_failure) {
            std::exit(2);
        }
        return;
    }

    if (resolved_junit.has_value()) {
        std::string junit_err;
        if (!write_text_file(*resolved_junit, "", junit_err)) {
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

void TestRuntime::reset_for_snapshot() {
    wait_frames_remaining_ = 0;
    test_complete_ = false;
    requested_outcome_.clear();
    requested_outcome_reason_.clear();
    exit_requested_ = false;
    exit_code_ = 0;
}

void TestRuntime::request_exit(int code) {
    exit_requested_ = true;
    exit_code_ = code;
}

bool TestRuntime::exit_requested() const {
    return exit_requested_;
}

int TestRuntime::exit_code() const {
    return exit_code_;
}

void TestRuntime::request_skip(const std::string& reason) {
    requested_outcome_ = "skip";
    requested_outcome_reason_ = reason;
    test_complete_ = true;
}

void TestRuntime::request_xfail(const std::string& reason) {
    requested_outcome_ = "xfail";
    requested_outcome_reason_ = reason;
}

const std::string& TestRuntime::requested_outcome() const {
    return requested_outcome_;
}

const std::string& TestRuntime::requested_outcome_reason() const {
    return requested_outcome_reason_;
}

bool TestRuntime::has_active_test() const {
    return !current_test_id_.empty();
}

const std::string& TestRuntime::current_test_id() const {
    return current_test_id_;
}

int TestRuntime::current_attempt() const {
    return current_attempt_;
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
    current_attempt_ = 1;
    retry_counts_.clear();
    resume_count_ = 0;
    exit_requested_ = false;
    exit_code_ = 0;
    requested_outcome_.clear();
    requested_outcome_reason_.clear();
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
