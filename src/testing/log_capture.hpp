#pragma once
// TODO: Implement log_capture

#include <string>
#include <vector>

namespace testing {

struct LogEntry {
    std::string message;
    std::string category;
    int level = 0;
};

class LogCapture {
public:
    void clear();
    void add(const LogEntry& entry);
    bool empty() const;
    const std::vector<LogEntry>& entries() const;

private:
    std::vector<LogEntry> entries_;
};

} // namespace testing
