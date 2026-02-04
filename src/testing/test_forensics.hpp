#pragma once

#include <filesystem>
#include <optional>
#include <string>
#include <vector>

namespace testing {

class TestRuntime;
struct TestModeConfig;
enum class TestStatus;

class TestForensics {
public:
    void initialize(const TestModeConfig& config, TestRuntime& runtime);

    void capture_on_failure(const std::string& test_id, TestStatus status);
    void capture_on_crash();
    void capture_on_timeout();
    void capture_on_run_complete();

    void capture_final_frame();
    void capture_last_logs(int n_lines = 500);
    void write_repro_scripts();
    void write_repro_scripts_per_test(const std::string& test_id);

    void request_timeline_write();
    void request_hang_dump();
    void request_determinism_diff();
    void request_failure_video();
    void request_trace_export();

    void create_zip_bundle();

    std::filesystem::path get_forensics_dir() const;

    void record_event(const std::string& event);
    void clear();
    const std::vector<std::string>& events() const;

private:
    bool ensure_forensics_dir();
    std::optional<std::filesystem::path> resolve_forensics_path(
        const std::filesystem::path& rel) const;
    bool write_text_file(const std::filesystem::path& path,
                         const std::string& contents) const;
    bool copy_file(const std::filesystem::path& src,
                   const std::filesystem::path& dst) const;
    std::string build_repro_script_sh(const std::optional<std::string>& test_id) const;
    std::string build_repro_script_ps1(const std::optional<std::string>& test_id) const;
    std::string build_cli_args(const std::optional<std::string>& test_id) const;
    std::string format_last_logs(int n_lines) const;
    static std::string status_label(TestStatus status);
    static std::string current_timestamp_utc();

    TestRuntime* runtime_ = nullptr;
    std::filesystem::path forensics_dir_;
    std::vector<std::string> events_;
};

} // namespace testing
