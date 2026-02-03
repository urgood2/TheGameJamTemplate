#include "testing/timeline_writer.hpp"

namespace testing {

bool TimelineWriter::open(const std::filesystem::path& path) {
    (void)path;
    open_ = true;
    return true;
}

void TimelineWriter::write_event(const std::string& line) {
    (void)line;
}

void TimelineWriter::close() {
    open_ = false;
}

bool TimelineWriter::is_open() const {
    return open_;
}

} // namespace testing
