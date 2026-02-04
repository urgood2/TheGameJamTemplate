#include "testing/timeline_writer.hpp"

#include <system_error>

namespace testing {

bool TimelineWriter::open(const std::filesystem::path& path) {
    path_ = path;
    std::error_code ec;
    if (!path_.empty()) {
        std::filesystem::create_directories(path_.parent_path(), ec);
    }
    out_.open(path_, std::ios::out | std::ios::trunc);
    open_ = out_.is_open();
    return open_;
}

void TimelineWriter::write_event(const std::string& line) {
    if (!open_ || !out_.is_open()) {
        return;
    }
    out_ << line << '\n';
}

void TimelineWriter::close() {
    if (out_.is_open()) {
        out_.flush();
        out_.close();
    }
    open_ = false;
}

bool TimelineWriter::is_open() const {
    return open_;
}

} // namespace testing
