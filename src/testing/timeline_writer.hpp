#pragma once
// TODO: Implement timeline_writer

#include <filesystem>
#include <fstream>
#include <string>

namespace testing {

class TimelineWriter {
public:
    bool open(const std::filesystem::path& path);
    void write_event(const std::string& line);
    void close();
    bool is_open() const;

private:
    bool open_ = false;
    std::filesystem::path path_;
    std::ofstream out_;
};

} // namespace testing
