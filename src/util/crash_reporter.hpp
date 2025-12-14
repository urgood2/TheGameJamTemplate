#pragma once

#include <functional>
#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace spdlog {
class logger;
} // namespace spdlog

namespace crash_reporter {

// Itch.io community URL for bug reports
constexpr const char* ITCH_COMMUNITY_URL = "https://chugget.itch.io/testing/community";

struct LogEntry {
    std::string timestamp;
    std::string level;
    std::string message;
};

struct Report {
    std::string id;
    std::string timestamp;
    std::string reason;
    std::string build_id;
    std::string build_type;
    std::string platform;
    std::string thread_id;
    std::vector<std::string> stacktrace;
    std::vector<LogEntry> logs;

    // Game state (populated by callback)
    std::string current_scene;
    std::string player_position;
    int entity_count{0};
    std::string lua_script_context;

    // Web-specific
    std::string browser_info;
    std::string webgl_renderer;
    size_t estimated_memory_mb{0};
    double session_duration_sec{0.0};
};

struct Config {
    bool enabled{true};
    size_t max_log_entries{200};
    std::string build_id{"dev-local"};
    std::string output_dir{"crash_reports"};
    bool enable_browser_download{true};
    bool enable_file_output{true};
};

// Initializes crash reporting and installs fatal handlers.
void Init(const Config& config);
bool IsEnabled();

// Attach the crash reporter's ring buffer sink to a logger so logs are captured.
void AttachSinkToLogger(const std::shared_ptr<spdlog::logger>& logger);

Report CaptureReport(const std::string& reason, bool include_stacktrace = true);
std::string SerializeReport(const Report& report);
std::optional<std::string> PersistReport(const Report& report);
const std::string& LastSerializedReport();

// Easy sharing functions for web
#if defined(__EMSCRIPTEN__)
// Copy the last crash report to clipboard (web only)
void CopyToClipboard();

// Show a browser notification that a crash report was captured
void ShowCaptureNotification(const std::string& message);
#endif

// Create a compact summary string for quick sharing
std::string CreateSummary(const Report& report);

// Game state callback - register to populate game-specific fields at capture time
using GameStateCallback = std::function<void(Report&)>;
void SetGameStateCallback(GameStateCallback cb);

} // namespace crash_reporter
