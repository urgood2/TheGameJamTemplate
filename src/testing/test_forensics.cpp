#include "testing/test_forensics.hpp"

#include <chrono>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <system_error>

#include <spdlog/spdlog.h>

#include "testing/determinism_guard.hpp"
#include "testing/log_capture.hpp"
#include "testing/path_sandbox.hpp"
#include "testing/screenshot_capture.hpp"
#include "testing/test_api_registry.hpp"
#include "testing/test_mode_config.hpp"
#include "testing/test_runtime.hpp"
#include "testing/timeline_writer.hpp"

namespace testing {
namespace {

std::string renderer_label(RendererMode mode) {
    switch (mode) {
        case RendererMode::Null:
            return "null";
        case RendererMode::Offscreen:
            return "offscreen";
        case RendererMode::Windowed:
            return "windowed";
    }
    return "unknown";
}

bool set_executable_bit(const std::filesystem::path& path) {
    std::error_code ec;
    auto current = std::filesystem::status(path, ec);
    if (ec) {
        return false;
    }
    auto perms = current.permissions();
    perms |= std::filesystem::perms::owner_exec;
    perms |= std::filesystem::perms::group_exec;
    perms |= std::filesystem::perms::others_exec;
    std::filesystem::permissions(path, perms, ec);
    return !ec;
}

} // namespace

void TestForensics::initialize(const TestModeConfig& config, TestRuntime& runtime) {
    runtime_ = &runtime;
    forensics_dir_ = config.forensics_dir;
    ensure_forensics_dir();
}

void TestForensics::capture_on_failure(const std::string& test_id, TestStatus status) {
    if (!runtime_) {
        return;
    }
    const auto& config = runtime_->config();
    SPDLOG_INFO("[forensics] Capturing forensics bundle for: {} ({})", test_id,
                status_label(status));
    SPDLOG_DEBUG("[forensics] Renderer mode {}", renderer_label(config.renderer));

    ensure_forensics_dir();
    request_timeline_write();
    request_trace_export();
    capture_final_frame();
    request_failure_video();
    capture_last_logs(500);

    if (auto path = resolve_forensics_path("logs.jsonl")) {
        runtime_->log_capture().write_jsonl(*path);
    }

    write_repro_scripts();
    if (!test_id.empty()) {
        write_repro_scripts_per_test(test_id);
    }

    if (runtime_->determinism_guard().has_violations()) {
        request_determinism_diff();
    }

    capture_on_run_complete();
    create_zip_bundle();
}

void TestForensics::capture_on_crash() {
    if (!runtime_) {
        return;
    }
    const std::string test_id = runtime_->current_test_id();
    SPDLOG_INFO("[forensics] Capturing forensics bundle for crash");
    capture_on_failure(test_id, TestStatus::Error);
}

void TestForensics::capture_on_timeout() {
    if (!runtime_) {
        return;
    }
    const std::string test_id = runtime_->current_test_id();
    SPDLOG_INFO("[forensics] Capturing forensics bundle for timeout");
    request_hang_dump();
    capture_on_failure(test_id, TestStatus::Fail);
}

void TestForensics::capture_on_run_complete() {
    if (!runtime_) {
        return;
    }
    const auto& config = runtime_->config();
    ensure_forensics_dir();

    std::filesystem::path run_manifest = config.run_root / "run_manifest.json";
    std::filesystem::path test_api = config.run_root / "test_api.json";
    if (!std::filesystem::exists(run_manifest) || !std::filesystem::exists(test_api)) {
        runtime_->write_reports();
    }

    if (auto dest = resolve_forensics_path("run_manifest.json")) {
        copy_file(run_manifest, *dest);
    }

    if (auto dest = resolve_forensics_path("test_api.json")) {
        if (!runtime_->api_registry().write_json(*dest) && std::filesystem::exists(test_api)) {
            copy_file(test_api, *dest);
        }
    }
}

void TestForensics::capture_final_frame() {
    if (!runtime_) {
        return;
    }
    const auto& config = runtime_->config();
    if (config.renderer == RendererMode::Null) {
        SPDLOG_WARN("[forensics] Could not capture final_frame: renderer null");
        return;
    }
    auto output_path = resolve_forensics_path("final_frame.png");
    if (!output_path) {
        SPDLOG_WARN("[forensics] Could not resolve final_frame output path");
        return;
    }
    SPDLOG_DEBUG("[forensics] Requesting final_frame capture");
    if (!runtime_->screenshot_capture().capture(*output_path)) {
        SPDLOG_WARN("[forensics] Could not capture final_frame: capture failed");
    }
}

void TestForensics::capture_last_logs(int n_lines) {
    if (!runtime_) {
        return;
    }
    auto output_path = resolve_forensics_path("last_logs.txt");
    if (!output_path) {
        SPDLOG_WARN("[forensics] Could not resolve last_logs output path");
        return;
    }
    SPDLOG_INFO("[forensics] Writing last_logs.txt ({} lines)", n_lines);
    const auto contents = format_last_logs(n_lines);
    write_text_file(*output_path, contents);
}

void TestForensics::write_repro_scripts() {
    if (!runtime_) {
        return;
    }
    auto sh_path = resolve_forensics_path("repro.sh");
    auto ps1_path = resolve_forensics_path("repro.ps1");
    if (sh_path) {
        write_text_file(*sh_path, build_repro_script_sh(std::nullopt));
        set_executable_bit(*sh_path);
    }
    if (ps1_path) {
        write_text_file(*ps1_path, build_repro_script_ps1(std::nullopt));
    }
    SPDLOG_DEBUG("[forensics] Writing repro scripts");
}

void TestForensics::write_repro_scripts_per_test(const std::string& test_id) {
    if (!runtime_ || test_id.empty()) {
        return;
    }
    const auto& config = runtime_->config();
    std::filesystem::path output = config.artifacts_dir / test_id / "repro.sh";
    std::error_code ec;
    std::filesystem::create_directories(output.parent_path(), ec);
    if (ec) {
        SPDLOG_WARN("[forensics] Could not create repro dir for {}", test_id);
        return;
    }
    if (!write_text_file(output, build_repro_script_sh(test_id))) {
        SPDLOG_WARN("[forensics] Could not write repro script for {}", test_id);
        return;
    }
    set_executable_bit(output);
}

void TestForensics::request_timeline_write() {
    if (!runtime_) {
        return;
    }
    SPDLOG_DEBUG("[forensics] Requesting timeline flush");
    if (runtime_->timeline_writer().is_open()) {
        runtime_->timeline_writer().close();
    }
}

void TestForensics::request_hang_dump() {
    SPDLOG_DEBUG("[forensics] Requesting hang dump");
}

void TestForensics::request_determinism_diff() {
    SPDLOG_DEBUG("[forensics] Requesting determinism diff");
}

void TestForensics::request_failure_video() {
    if (!runtime_) {
        return;
    }
    if (runtime_->config().failure_video == FailureVideoMode::Off) {
        return;
    }
    SPDLOG_DEBUG("[forensics] Requesting failure clip encoding");
}

void TestForensics::request_trace_export() {
    SPDLOG_DEBUG("[forensics] Requesting trace export");
}

void TestForensics::create_zip_bundle() {
    if (!runtime_) {
        return;
    }
    ensure_forensics_dir();
    SPDLOG_INFO("[forensics] Creating forensics.zip");
#if defined(_WIN32)
    SPDLOG_WARN("[forensics] Zip bundling not implemented on Windows");
#else
    std::filesystem::path zip_path = forensics_dir_ / "forensics.zip";
    if (zip_path.empty()) {
        return;
    }
    const auto original = std::filesystem::current_path();
    std::error_code ec;
    std::filesystem::current_path(forensics_dir_, ec);
    if (ec) {
        SPDLOG_WARN("[forensics] Unable to switch into forensics dir");
        return;
    }
    int has_zip = std::system("zip -v > /dev/null 2>&1");
    if (has_zip != 0) {
        SPDLOG_WARN("[forensics] zip tool not available");
        std::filesystem::current_path(original, ec);
        return;
    }
    int result = std::system("zip -r forensics.zip . > /dev/null 2>&1");
    std::filesystem::current_path(original, ec);
    if (result != 0) {
        SPDLOG_WARN("[forensics] Failed to create forensics.zip");
        return;
    }
    if (std::filesystem::exists(zip_path)) {
        SPDLOG_INFO("[forensics] Forensics bundle complete: {}", zip_path.string());
    }
#endif
}

std::filesystem::path TestForensics::get_forensics_dir() const {
    return forensics_dir_;
}

void TestForensics::record_event(const std::string& event) {
    events_.push_back(event);
}

void TestForensics::clear() {
    events_.clear();
}

const std::vector<std::string>& TestForensics::events() const {
    return events_;
}

bool TestForensics::ensure_forensics_dir() {
    if (forensics_dir_.empty()) {
        return false;
    }
    std::error_code ec;
    std::filesystem::create_directories(forensics_dir_, ec);
    if (ec) {
        SPDLOG_WARN("[forensics] Unable to create forensics dir {}", forensics_dir_.string());
        return false;
    }
    return true;
}

std::optional<std::filesystem::path> TestForensics::resolve_forensics_path(
    const std::filesystem::path& rel) const {
    if (!runtime_ || forensics_dir_.empty() || rel.empty()) {
        return std::nullopt;
    }
    const auto candidate = forensics_dir_ / rel;
    auto resolved = runtime_->path_sandbox().resolve_write_path(candidate);
    if (!resolved) {
        return std::nullopt;
    }
    return resolved;
}

bool TestForensics::write_text_file(const std::filesystem::path& path,
                                    const std::string& contents) const {
    std::error_code ec;
    if (path.has_parent_path()) {
        std::filesystem::create_directories(path.parent_path(), ec);
        if (ec) {
            return false;
        }
    }
    std::ofstream out(path);
    if (!out) {
        return false;
    }
    out << contents;
    return true;
}

bool TestForensics::copy_file(const std::filesystem::path& src,
                              const std::filesystem::path& dst) const {
    std::error_code ec;
    if (!std::filesystem::exists(src, ec)) {
        return false;
    }
    if (dst.has_parent_path()) {
        std::filesystem::create_directories(dst.parent_path(), ec);
        if (ec) {
            return false;
        }
    }
    std::filesystem::copy_file(src, dst, std::filesystem::copy_options::overwrite_existing, ec);
    return !ec;
}

std::string TestForensics::build_repro_script_sh(
    const std::optional<std::string>& test_id) const {
    const auto& config = runtime_->config();
    std::ostringstream out;
    out << "#!/bin/bash\n";
    out << "# E2E Test Reproduction Script\n";
    out << "# Generated by E2E Test Framework\n";
    if (!config.run_id.empty()) {
        out << "# Original run: " << config.run_id << "\n";
    }
    out << "# Exit code: " << runtime_->exit_code() << "\n";
    if (!runtime_->current_test_id().empty()) {
        out << "# Failed test: " << runtime_->current_test_id() << "\n";
    }
    out << "\n";
    out << "./game " << build_cli_args(test_id) << " \\\n";
    out << "  \"$@\"\n";
    return out.str();
}

std::string TestForensics::build_repro_script_ps1(
    const std::optional<std::string>& test_id) const {
    std::ostringstream out;
    out << "# E2E Test Reproduction Script (PowerShell)\n";
    out << "# Generated by E2E Test Framework\n\n";
    out << "param(\n";
    out << "    [string]$TestId = \"\",\n";
    out << "    [switch]$Verbose\n";
    out << ")\n\n";
    out << "$GameArgs = @(\n";
    const std::string args = build_cli_args(std::nullopt);
    std::istringstream tokens(args);
    std::string token;
    while (tokens >> token) {
        out << "    \"" << token << "\"\n";
    }
    out << ")\n\n";
    if (test_id.has_value()) {
        out << "$GameArgs += \"--run-test-id\", \"" << *test_id << "\"\n";
    } else {
        out << "if ($TestId) { $GameArgs += \"--run-test-id\", $TestId }\n";
    }
    out << "\n";
    out << "& ./game.exe @GameArgs @args\n";
    return out.str();
}

std::string TestForensics::build_cli_args(
    const std::optional<std::string>& test_id) const {
    if (!runtime_) {
        return "--test-mode";
    }
    const auto& config = runtime_->config();
    std::ostringstream out;
    out << "--test-mode";
    if (config.headless) {
        out << " --headless";
    }
    out << " --seed " << config.seed;
    out << " --resolution " << config.resolution_width << "x" << config.resolution_height;
    out << " --fixed-fps " << config.fixed_fps;

    if (config.test_suite.has_value()) {
        out << " --test-suite " << *config.test_suite;
    } else if (config.test_script.has_value()) {
        out << " --test-script " << *config.test_script;
    }

    if (test_id.has_value()) {
        out << " --run-test-id " << *test_id;
    } else if (config.run_test_id.has_value()) {
        out << " --run-test-id " << *config.run_test_id;
    } else if (config.run_test_exact.has_value()) {
        out << " --run-test-exact " << *config.run_test_exact;
    }

    out << " --artifacts tests/out/repro";
    return out.str();
}

std::string TestForensics::format_last_logs(int n_lines) const {
    if (!runtime_) {
        return {};
    }
    const auto& config = runtime_->config();
    const auto entries = runtime_->log_capture().find_all("", {});
    const size_t total = entries.size();
    const size_t start = (n_lines > 0 && total > static_cast<size_t>(n_lines))
        ? (total - static_cast<size_t>(n_lines))
        : 0u;

    std::ostringstream out;
    out << "=== E2E Test Logs (last " << n_lines << " lines) ===\n";
    out << "Run: " << (config.run_id.empty() ? "unknown" : config.run_id) << "\n";
    out << "Captured at frame: " << runtime_->current_frame() << "\n";
    if (!runtime_->current_test_id().empty()) {
        out << "Test: " << runtime_->current_test_id() << "\n";
    }
    out << "\n";

    for (size_t i = start; i < total; ++i) {
        const auto& entry = entries[i];
        const std::string ts = entry.timestamp.empty() ? current_timestamp_utc() : entry.timestamp;
        out << "[" << ts << "] ";
        if (!entry.level.empty()) {
            out << entry.level << " ";
        }
        if (!entry.category.empty()) {
            out << entry.category << " ";
        }
        out << entry.message;
        if (entry.frame > 0) {
            out << " (frame " << entry.frame << ")";
        }
        if (i + 1 < total) {
            out << "\n";
        }
    }

    return out.str();
}

std::string TestForensics::status_label(TestStatus status) {
    switch (status) {
        case TestStatus::Pass:
            return "pass";
        case TestStatus::Fail:
            return "fail";
        case TestStatus::Skip:
            return "skip";
        case TestStatus::Error:
            return "error";
    }
    return "unknown";
}

std::string TestForensics::current_timestamp_utc() {
    auto now = std::chrono::system_clock::now();
    auto t = std::chrono::system_clock::to_time_t(now);
    std::tm tm{};
#if defined(_WIN32)
    gmtime_s(&tm, &t);
#else
    gmtime_r(&t, &tm);
#endif
    std::ostringstream out;
    out << std::put_time(&tm, "%Y-%m-%dT%H:%M:%SZ");
    return out.str();
}

} // namespace testing
