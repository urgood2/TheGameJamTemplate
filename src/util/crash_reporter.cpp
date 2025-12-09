#include "crash_reporter.hpp"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstring>
#include <csignal>
#include <cstdlib>
#include <exception>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <mutex>
#include <sstream>
#include <thread>

#include "spdlog/details/os.h"
#include "spdlog/sinks/base_sink.h"
#include "spdlog/spdlog.h"

#include <nlohmann/json.hpp>

#include "systems/telemetry/telemetry.hpp"

#if defined(__APPLE__) || defined(__linux__)
#include <execinfo.h>
#endif

#if defined(__EMSCRIPTEN__)
#include <emscripten/emscripten.h>
#include <emscripten/stack.h>
#endif

namespace crash_reporter {
namespace {

using json = nlohmann::json;

template <typename Mutex>
class RingBufferSink : public spdlog::sinks::base_sink<Mutex> {
public:
    explicit RingBufferSink(size_t max_entries) : max_entries_(max_entries) {}

    std::vector<LogEntry> snapshot() {
        std::lock_guard<Mutex> lock(this->mutex_);
        return buffer_;
    }

protected:
    void sink_it_(const spdlog::details::log_msg& msg) override {
        spdlog::memory_buf_t formatted;
        this->formatter_->format(msg, formatted);

        LogEntry entry;
        entry.timestamp = format_log_time(msg.time);
        const auto level_view = spdlog::level::to_string_view(msg.level);
        entry.level.assign(level_view.data(), level_view.size());
        entry.message.assign(formatted.data(), formatted.size());

        // base_sink already holds mutex_ while calling sink_it_, so don't lock again.
        buffer_.push_back(std::move(entry));
        if (buffer_.size() > max_entries_) {
            const auto overflow = buffer_.size() - max_entries_;
            buffer_.erase(buffer_.begin(), buffer_.begin() + static_cast<std::ptrdiff_t>(overflow));
        }
    }

    void flush_() override {}

private:
    static std::string format_log_time(const spdlog::log_clock::time_point& tp) {
        const auto tt = spdlog::log_clock::to_time_t(tp);
        const std::tm tm_time = spdlog::details::os::localtime(tt);
        char buffer[32];
        if (std::strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%S", &tm_time)) {
            return buffer;
        }
        return "unknown";
    }

    std::vector<LogEntry> buffer_;
    size_t max_entries_;
};

using RingSink = RingBufferSink<std::mutex>;

struct State {
    Config config{};
    std::shared_ptr<RingSink> sink;
    std::string last_json;
    std::atomic<bool> handling_fatal{false};
    std::terminate_handler previous_terminate{nullptr};
    bool initialized{false};
};

State& state() {
    static State s;
    return s;
}

std::string format_timestamp(const std::chrono::system_clock::time_point& tp) {
    const auto tt = std::chrono::system_clock::to_time_t(tp);
    const std::tm tm_time = spdlog::details::os::localtime(tt);
    char buffer[32];
    if (std::strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%S", &tm_time)) {
        return buffer;
    }
    return "unknown";
}

std::string make_report_id(const std::chrono::system_clock::time_point& tp) {
    const auto tt = std::chrono::system_clock::to_time_t(tp);
    const std::tm tm_time = spdlog::details::os::localtime(tt);
    char buffer[32];
    if (std::strftime(buffer, sizeof(buffer), "%Y%m%d_%H%M%S", &tm_time)) {
        std::ostringstream oss;
        oss << buffer;
        return oss.str();
    }
    return "report";
}

std::string detect_platform() {
#if defined(__EMSCRIPTEN__)
    return "Web/Emscripten";
#elif defined(_WIN32)
    return "Windows";
#elif defined(__APPLE__)
    return "macOS";
#elif defined(__linux__)
    return "Linux";
#else
    return "Unknown";
#endif
}

std::string detect_build_type() {
#if defined(NDEBUG)
    return "Release";
#else
    return "Debug";
#endif
}

std::vector<std::string> capture_stacktrace(bool include_stack) {
    if (!include_stack) {
        return {};
    }

#if defined(__EMSCRIPTEN__)
    constexpr int kMaxBytes = 16 * 1024;
    char buffer[kMaxBytes];
    const int written = emscripten_get_callstack(EM_LOG_DEMANGLE | EM_LOG_C_STACK | EM_LOG_JS_STACK, buffer, kMaxBytes);
    const int usable = (written > 0 && written < kMaxBytes) ? written : static_cast<int>(std::strlen(buffer));
    std::vector<std::string> frames;
    std::istringstream stream(std::string(buffer, usable));
    std::string line;
    while (std::getline(stream, line)) {
        if (!line.empty()) {
            frames.push_back(line);
        }
    }
    return frames;
#elif defined(__APPLE__) || defined(__linux__)
    constexpr int kMaxFrames = 64;
    void* buffer[kMaxFrames];
    int count = ::backtrace(buffer, kMaxFrames);
    char** symbols = ::backtrace_symbols(buffer, count);

    std::vector<std::string> frames;
    if (symbols) {
        for (int i = 0; i < count; ++i) {
            frames.emplace_back(symbols[i]);
        }
        std::free(symbols);
    }
    return frames;
#else
    return { "Stack trace capture not available on this platform." };
#endif
}

std::string thread_id_as_string() {
    std::ostringstream oss;
    oss << std::this_thread::get_id();
    return oss.str();
}

#if defined(__EMSCRIPTEN__)
void trigger_web_download(const std::string& content, const std::string& filename) {
    EM_ASM(
        {
            const data = UTF8ToString($0);
            const name = UTF8ToString($1);
            const blob = new Blob([data], { type: "application/json" });
            const url = URL.createObjectURL(blob);
            const link = document.createElement("a");
            link.href = url;
            link.download = name;
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            URL.revokeObjectURL(url);
        },
        content.c_str(), filename.c_str());
}
#endif

std::optional<std::string> persist_report_internal(const Report& report) {
    auto& s = state();
    s.last_json = SerializeReport(report);

#if defined(__EMSCRIPTEN__)
    if (s.config.enable_browser_download) {
        const std::string filename = "crash_report_" + report.id + ".json";
        trigger_web_download(s.last_json, filename);
        return filename;
    }
#endif

    if (!s.config.enable_file_output) {
        return std::nullopt;
    }

    try {
        std::filesystem::path out_dir = s.config.output_dir.empty() ? std::filesystem::path{"crash_reports"} : std::filesystem::path{s.config.output_dir};
        std::filesystem::create_directories(out_dir);
        std::filesystem::path file_path = out_dir / ("crash_report_" + report.id + ".json");
        std::ofstream out(file_path);
        out << s.last_json;
        out.close();
        return file_path.string();
    } catch (const std::exception& e) {
        SPDLOG_ERROR("Failed to write crash report: {}", e.what());
        return std::nullopt;
    }
}

void handle_fatal(const std::string& reason) {
    auto& s = state();
    if (!s.config.enabled) {
        return;
    }
    if (s.handling_fatal.exchange(true)) {
        return;
    }

    try {
        auto report = CaptureReport(reason, true);
        telemetry::RecordEvent("crash_report",
                               {{"reason", report.reason},
                                {"build_id", report.build_id},
                                {"build_type", report.build_type},
                                {"platform", report.platform},
                                {"session_id", telemetry::SessionId()}});
        const auto path = persist_report_internal(report);
        if (path) {
            SPDLOG_CRITICAL("Crash report captured: {}", *path);
        } else {
            SPDLOG_CRITICAL("Crash report captured (no file path available).");
        }
    } catch (...) {
        SPDLOG_CRITICAL("Crash reporter failed while handling fatal event.");
    }
}

void terminate_handler() {
    std::string reason = "std::terminate";
    if (auto exc = std::current_exception()) {
        try {
            std::rethrow_exception(exc);
        } catch (const std::exception& e) {
            reason = std::string("Unhandled exception: ") + e.what();
        } catch (...) {
            reason = "Unhandled unknown exception";
        }
    }

    handle_fatal(reason);
    std::_Exit(1);
}

void signal_handler(int signum) {
    handle_fatal("Signal " + std::to_string(signum));
    std::_Exit(128 + signum);
}

} // namespace

void Init(const Config& config) {
    auto& s = state();
    s.config = config;
#if defined(__EMSCRIPTEN__)
    s.config.enable_file_output = false;
#endif

    if (!s.config.enabled) {
        s.initialized = false;
        return;
    }

    if (!s.sink) {
        s.sink = std::make_shared<RingSink>(s.config.max_log_entries);
    }
    AttachSinkToLogger(spdlog::default_logger());

    s.previous_terminate = std::set_terminate(terminate_handler);

#if !defined(__EMSCRIPTEN__)
    std::signal(SIGABRT, signal_handler);
    std::signal(SIGSEGV, signal_handler);
    std::signal(SIGILL, signal_handler);
    std::signal(SIGFPE, signal_handler);
#endif

    s.initialized = true;
}

bool IsEnabled() {
    return state().initialized && state().config.enabled;
}

void AttachSinkToLogger(const std::shared_ptr<spdlog::logger>& logger) {
    auto& s = state();
    if (!logger || !s.sink) {
        return;
    }

    auto& sinks = logger->sinks();
    const auto sink_ptr = s.sink.get();
    const bool already_attached = std::any_of(sinks.begin(), sinks.end(), [sink_ptr](const auto& sink) {
        return sink.get() == sink_ptr;
    });

    if (!already_attached) {
        sinks.push_back(s.sink);
    }
}

Report CaptureReport(const std::string& reason, bool include_stacktrace) {
    auto now = std::chrono::system_clock::now();
    Report report;
    report.id = make_report_id(now);
    report.timestamp = format_timestamp(now);
    report.reason = reason;
    report.build_id = state().config.build_id.empty() ? "dev-local" : state().config.build_id;
    report.build_type = detect_build_type();
    report.platform = detect_platform();
    report.thread_id = thread_id_as_string();
    report.stacktrace = capture_stacktrace(include_stacktrace);

    if (state().sink) {
        report.logs = state().sink->snapshot();
    }

    return report;
}

std::string SerializeReport(const Report& report) {
    json j;
    j["id"] = report.id;
    j["timestamp"] = report.timestamp;
    j["reason"] = report.reason;
    j["build_id"] = report.build_id;
    j["build_type"] = report.build_type;
    j["platform"] = report.platform;
    j["thread_id"] = report.thread_id;
    j["stacktrace"] = report.stacktrace;

    auto& logs = j["logs"] = json::array();
    for (const auto& entry : report.logs) {
        logs.push_back({
            {"timestamp", entry.timestamp},
            {"level", entry.level},
            {"message", entry.message},
        });
    }

    state().last_json = j.dump(2);
    return state().last_json;
}

std::optional<std::string> PersistReport(const Report& report) {
    return persist_report_internal(report);
}

const std::string& LastSerializedReport() {
    return state().last_json;
}

std::string CreateSummary(const Report& report) {
    std::ostringstream oss;
    oss << "=== Crash Report ===" << "\n";
    oss << "ID: " << report.id << "\n";
    oss << "Time: " << report.timestamp << "\n";
    oss << "Reason: " << report.reason << "\n";
    oss << "Build: " << report.build_id << " (" << report.build_type << ")" << "\n";
    oss << "Platform: " << report.platform << "\n";

    if (!report.stacktrace.empty()) {
        oss << "\n--- Stack Trace (top 5) ---" << "\n";
        size_t count = std::min(report.stacktrace.size(), size_t{5});
        for (size_t i = 0; i < count; ++i) {
            oss << "  " << report.stacktrace[i] << "\n";
        }
        if (report.stacktrace.size() > 5) {
            oss << "  ... and " << (report.stacktrace.size() - 5) << " more frames" << "\n";
        }
    }

    if (!report.logs.empty()) {
        oss << "\n--- Recent Logs (last 10) ---" << "\n";
        size_t start = report.logs.size() > 10 ? report.logs.size() - 10 : 0;
        for (size_t i = start; i < report.logs.size(); ++i) {
            const auto& log = report.logs[i];
            oss << "[" << log.level << "] " << log.message;
        }
    }

    oss << "\n=== End Report ===" << "\n";
    return oss.str();
}

#if defined(__EMSCRIPTEN__)
void CopyToClipboard() {
    const auto& json = state().last_json;
    if (json.empty()) {
        SPDLOG_WARN("No crash report to copy to clipboard");
        return;
    }

    EM_ASM({
        const text = UTF8ToString($0);
        if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(text).then(function() {
                console.log('Crash report copied to clipboard');
            }).catch(function(err) {
                console.error('Failed to copy to clipboard:', err);
            });
        } else {
            // Fallback for older browsers
            const textarea = document.createElement('textarea');
            textarea.value = text;
            textarea.style.position = 'fixed';
            textarea.style.opacity = '0';
            document.body.appendChild(textarea);
            textarea.select();
            try {
                document.execCommand('copy');
                console.log('Crash report copied to clipboard (fallback)');
            } catch (err) {
                console.error('Fallback copy failed:', err);
            }
            document.body.removeChild(textarea);
        }
    }, json.c_str());
}

void ShowCaptureNotification(const std::string& message) {
    // Wrap the EM_ASM block in parentheses so commas inside CSS strings don't split args.
    EM_ASM(({
        const msg = UTF8ToString($0);

        // Create notification element
        const notification = document.createElement('div');
        notification.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            background: linear-gradient(135deg, #2d2d2d 0%, #1a1a1a 100%);
            color: #fff;
            padding: 16px 24px;
            border-radius: 8px;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            font-size: 14px;
            z-index: 10000;
            box-shadow: 0 4px 20px rgba(0,0,0,0.4);
            border: 1px solid rgba(255,255,255,0.1);
            max-width: 350px;
            animation: slideIn 0.3s ease-out;
        `;

        // Add animation keyframes if not already added
        if (!document.getElementById('crash-notification-styles')) {
            const style = document.createElement('style');
            style.id = 'crash-notification-styles';
            style.textContent = `
                @keyframes slideIn {
                    from { transform: translateX(100%); opacity: 0; }
                    to { transform: translateX(0); opacity: 1; }
                }
                @keyframes slideOut {
                    from { transform: translateX(0); opacity: 1; }
                    to { transform: translateX(100%); opacity: 0; }
                }
            `;
            document.head.appendChild(style);
        }

        // Create content structure safely
        const container = document.createElement('div');
        container.style.cssText = 'display: flex; align-items: flex-start; gap: 12px;';

        const icon = document.createElement('span');
        icon.style.fontSize = '24px';
        icon.textContent = '📋';

        const contentDiv = document.createElement('div');

        const title = document.createElement('div');
        title.style.cssText = 'font-weight: 600; margin-bottom: 4px;';
        title.textContent = 'Debug Report Captured';

        const messageDiv = document.createElement('div');
        messageDiv.style.cssText = 'color: rgba(255,255,255,0.7); font-size: 13px;';
        messageDiv.textContent = msg; // Safe: uses textContent

        const buttonContainer = document.createElement('div');
        buttonContainer.style.cssText = 'margin-top: 12px; display: flex; gap: 8px;';

        const copyBtn = document.createElement('button');
        copyBtn.id = 'crash-copy-btn';
        copyBtn.style.cssText = `
            background: #4a9eff;
            color: white;
            border: none;
            padding: 6px 12px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 12px;
        `;
        copyBtn.textContent = 'Copy to Clipboard';

        const dismissBtn = document.createElement('button');
        dismissBtn.id = 'crash-dismiss-btn';
        dismissBtn.style.cssText = `
            background: rgba(255,255,255,0.1);
            color: rgba(255,255,255,0.8);
            border: none;
            padding: 6px 12px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 12px;
        `;
        dismissBtn.textContent = 'Dismiss';

        buttonContainer.appendChild(copyBtn);
        buttonContainer.appendChild(dismissBtn);

        contentDiv.appendChild(title);
        contentDiv.appendChild(messageDiv);
        contentDiv.appendChild(buttonContainer);

        container.appendChild(icon);
        container.appendChild(contentDiv);

        notification.appendChild(container);
        document.body.appendChild(notification);

        // Handle copy button - directly call clipboard API with the report
        copyBtn.onclick = function() {
            const reportText = UTF8ToString($0);
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(reportText).then(function() {
                    copyBtn.textContent = 'Copied!';
                    copyBtn.style.background = '#28a745';
                    setTimeout(function() {
                        copyBtn.textContent = 'Copy to Clipboard';
                        copyBtn.style.background = '#4a9eff';
                    }, 2000);
                }).catch(function(err) {
                    console.error('Failed to copy to clipboard:', err);
                    copyBtn.textContent = 'Failed';
                    copyBtn.style.background = '#dc3545';
                });
            } else {
                // Fallback for older browsers
                const textarea = document.createElement('textarea');
                textarea.value = reportText;
                textarea.style.position = 'fixed';
                textarea.style.opacity = '0';
                document.body.appendChild(textarea);
                textarea.select();
                try {
                    document.execCommand('copy');
                    copyBtn.textContent = 'Copied!';
                    copyBtn.style.background = '#28a745';
                    setTimeout(function() {
                        copyBtn.textContent = 'Copy to Clipboard';
                        copyBtn.style.background = '#4a9eff';
                    }, 2000);
                } catch (err) {
                    console.error('Fallback copy failed:', err);
                    copyBtn.textContent = 'Failed';
                    copyBtn.style.background = '#dc3545';
                }
                document.body.removeChild(textarea);
            }
        };

        // Handle dismiss button
        const dismissNotification = function() {
            notification.style.animation = 'slideOut 0.3s ease-in forwards';
            setTimeout(function() {
                if (notification.parentNode) {
                    notification.parentNode.removeChild(notification);
                }
            }, 300);
        };

        dismissBtn.onclick = dismissNotification;

        // Auto-dismiss after 10 seconds
        setTimeout(dismissNotification, 10000);
    }), message.c_str());
}
#endif

} // namespace crash_reporter
