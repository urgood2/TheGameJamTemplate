#include "testing/log_capture.hpp"

namespace testing {

void LogCapture::clear() {
    entries_.clear();
}

void LogCapture::add(const LogLine& entry) {
    entries_.push_back(entry);
}

bool LogCapture::empty() const {
    return entries_.empty();
}

const std::vector<LogLine>& LogCapture::entries() const {
    return entries_;
}

} // namespace testing
