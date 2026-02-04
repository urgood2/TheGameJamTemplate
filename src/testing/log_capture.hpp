#pragma once
#include <filesystem>
#include <mutex>
#include <optional>
#include <string>
#include <vector>

namespace testing {

struct TestModeConfig;

using LogMark = size_t;

struct LogEntry {
    int frame = 0;
    std::string message;
    std::string category;
    std::string level;
    std::string timestamp;
};

using LogLine = LogEntry;

struct FindOptions {
    LogMark since = 0;
    bool regex = false;
    std::string min_level = "trace";
    std::string category_filter;
};

class LogCapture {
public:
    void initialize(const struct TestModeConfig& config);
    void capture(int frame,
                 const std::string& level,
                 const std::string& category,
                 const std::string& message);
    void clear();
    void add(const LogLine& entry);
    bool empty() const;
    const std::vector<LogLine>& entries() const;
    size_t size() const;
    LogMark mark() const;
    std::optional<LogEntry> find(const std::string& pattern,
                                 const FindOptions& opts = {});
    std::vector<LogEntry> find_all(const std::string& pattern,
                                   const FindOptions& opts = {});
    bool has_logs_at_level(const std::string& level, LogMark since = 0);
    void write_jsonl(const std::filesystem::path& path);
    std::string get_last_n_lines(int n = 500) const;

private:
    std::vector<LogEntry> snapshot_entries() const;
    void enforce_capacity();
    static int level_rank(const std::string& level);

    size_t max_entries_ = 100000;
    mutable std::mutex mutex_;
    std::vector<LogLine> entries_;
};

} // namespace testing
