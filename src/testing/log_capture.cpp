#include "testing/log_capture.hpp"

#include <chrono>
#include <fstream>
#include <iomanip>
#include <regex>
#include <sstream>

#include "nlohmann/json.hpp"
#include "testing/test_mode_config.hpp"

namespace testing {
namespace {

std::string current_timestamp() {
    const auto now = std::chrono::system_clock::now();
    const auto time = std::chrono::system_clock::to_time_t(now);
    std::tm tm{};
#if defined(_WIN32)
    gmtime_s(&tm, &time);
#else
    gmtime_r(&time, &tm);
#endif
    std::ostringstream out;
    out << std::put_time(&tm, "%Y-%m-%dT%H:%M:%SZ");
    return out.str();
}

bool matches_pattern(const std::string& text, const std::string& pattern, bool use_regex) {
    if (!use_regex) {
        return pattern.empty() || text.find(pattern) != std::string::npos;
    }
    try {
        const std::regex expr(pattern);
        return std::regex_search(text, expr);
    } catch (const std::regex_error&) {
        return false;
    }
}

} // namespace

void LogCapture::initialize(const TestModeConfig& config) {
    (void)config;
    std::lock_guard<std::mutex> lock(mutex_);
    entries_.clear();
    max_entries_ = 100000;
}

void LogCapture::capture(int frame,
                         const std::string& level,
                         const std::string& category,
                         const std::string& message) {
    LogEntry entry;
    entry.frame = frame;
    entry.level = level;
    entry.category = category;
    entry.message = message;
    entry.timestamp = current_timestamp();
    std::lock_guard<std::mutex> lock(mutex_);
    entries_.push_back(entry);
    enforce_capacity();
}

void LogCapture::clear() {
    std::lock_guard<std::mutex> lock(mutex_);
    entries_.clear();
}

void LogCapture::add(const LogLine& entry) {
    std::lock_guard<std::mutex> lock(mutex_);
    entries_.push_back(entry);
    enforce_capacity();
}

bool LogCapture::empty() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return entries_.empty();
}

const std::vector<LogLine>& LogCapture::entries() const {
    return entries_;
}

size_t LogCapture::size() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return entries_.size();
}

LogMark LogCapture::mark() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return entries_.size();
}

std::optional<LogEntry> LogCapture::find(const std::string& pattern, const FindOptions& opts) {
    const auto snapshot = snapshot_entries();
    const size_t start = std::min(opts.since, snapshot.size());
    const int min_rank = level_rank(opts.min_level);
    for (size_t i = start; i < snapshot.size(); ++i) {
        const auto& entry = snapshot[i];
        if (!opts.category_filter.empty() && entry.category != opts.category_filter) {
            continue;
        }
        if (level_rank(entry.level) < min_rank) {
            continue;
        }
        if (matches_pattern(entry.message, pattern, opts.regex) ||
            matches_pattern(entry.category, pattern, opts.regex)) {
            return entry;
        }
    }
    return std::nullopt;
}

std::vector<LogEntry> LogCapture::find_all(const std::string& pattern, const FindOptions& opts) {
    const auto snapshot = snapshot_entries();
    const size_t start = std::min(opts.since, snapshot.size());
    const int min_rank = level_rank(opts.min_level);
    std::vector<LogEntry> matches;
    for (size_t i = start; i < snapshot.size(); ++i) {
        const auto& entry = snapshot[i];
        if (!opts.category_filter.empty() && entry.category != opts.category_filter) {
            continue;
        }
        if (level_rank(entry.level) < min_rank) {
            continue;
        }
        if (matches_pattern(entry.message, pattern, opts.regex) ||
            matches_pattern(entry.category, pattern, opts.regex)) {
            matches.push_back(entry);
        }
    }
    return matches;
}

bool LogCapture::has_logs_at_level(const std::string& level, LogMark since) {
    const auto snapshot = snapshot_entries();
    const size_t start = std::min(since, snapshot.size());
    const int min_rank = level_rank(level);
    for (size_t i = start; i < snapshot.size(); ++i) {
        if (level_rank(snapshot[i].level) >= min_rank) {
            return true;
        }
    }
    return false;
}

void LogCapture::write_jsonl(const std::filesystem::path& path) {
    const auto snapshot = snapshot_entries();
    std::ofstream out(path);
    if (!out) {
        return;
    }
    for (const auto& entry : snapshot) {
        nlohmann::json line;
        line["frame"] = entry.frame;
        line["level"] = entry.level;
        line["category"] = entry.category;
        line["message"] = entry.message;
        line["ts"] = entry.timestamp;
        out << line.dump() << "\n";
    }
}

std::string LogCapture::get_last_n_lines(int n) const {
    const auto snapshot = snapshot_entries();
    if (n <= 0 || snapshot.empty()) {
        return {};
    }
    const size_t total = snapshot.size();
    const size_t start = total > static_cast<size_t>(n) ? total - static_cast<size_t>(n) : 0u;
    std::ostringstream out;
    for (size_t i = start; i < total; ++i) {
        const auto& entry = snapshot[i];
        out << "[" << entry.level << "] ";
        if (!entry.category.empty()) {
            out << "[" << entry.category << "] ";
        }
        out << entry.message;
        if (i + 1 < total) {
            out << "\n";
        }
    }
    return out.str();
}

std::vector<LogEntry> LogCapture::snapshot_entries() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return entries_;
}

void LogCapture::enforce_capacity() {
    if (entries_.size() <= max_entries_) {
        return;
    }
    const size_t overflow = entries_.size() - max_entries_;
    entries_.erase(entries_.begin(), entries_.begin() + static_cast<std::ptrdiff_t>(overflow));
}

int LogCapture::level_rank(const std::string& level) {
    std::string norm;
    norm.reserve(level.size());
    for (char ch : level) {
        if (ch >= 'A' && ch <= 'Z') {
            norm.push_back(static_cast<char>(ch - 'A' + 'a'));
        } else if (ch != ' ' && ch != '\t') {
            norm.push_back(ch);
        }
    }
    if (norm == "trace") {
        return 0;
    }
    if (norm == "debug") {
        return 1;
    }
    if (norm == "info") {
        return 2;
    }
    if (norm == "warn" || norm == "warning") {
        return 3;
    }
    if (norm == "error") {
        return 4;
    }
    if (norm == "fatal" || norm == "critical") {
        return 5;
    }
    return 0;
}

} // namespace testing
