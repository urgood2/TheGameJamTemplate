#pragma once
// TODO: Implement log_capture

#include <string>
#include <vector>

namespace testing {

struct LogLine {
    std::string message;
    std::string category;
    int level = 0;
};

using LogEntry = LogLine;

class LogCapture {
public:
    void clear();
    void add(const LogLine& entry);
    bool empty() const;
    const std::vector<LogLine>& entries() const;

private:
    std::vector<LogLine> entries_;
};

} // namespace testing
