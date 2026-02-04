#pragma once
// TODO: Implement timeline_writer

#include <filesystem>
#include <fstream>
#include <mutex>
#include <string>
#include <vector>

#include <nlohmann/json.hpp>

#include "testing/log_capture.hpp"
#include "testing/test_input_provider.hpp"

namespace testing {

struct TestModeConfig;

struct TimelineEvent {
    int frame = 0;
    std::string type;
    std::string subtype;
    std::string ts;
    nlohmann::json data;
};

class TimelineWriter {
public:
    void initialize(const TestModeConfig& config);
    void shutdown();

    bool open(const std::filesystem::path& path);
    void write_event(const std::string& line);
    void close();
    bool is_open() const;

    void record_input(int frame, const TestInputEvent& event);
    void record_log(int frame, const LogEntry& entry);
    void record_screenshot(int frame, const std::string& name, const std::string& path);
    void record_step_start(int frame, const std::string& name);
    void record_step_end(int frame, const std::string& name, const std::string& status);
    void record_hash(int frame, const std::string& scope, const std::string& hash);
    void record_attachment(int frame, const std::string& name, const std::string& path);
    void record_test_start(int frame, const std::string& test_id);
    void record_test_end(int frame, const std::string& test_id, const std::string& status);

    void record_logs_batch(const std::vector<std::pair<int, LogEntry>>& logs);

    void flush();
    void write(const std::filesystem::path& path);

    std::vector<TimelineEvent> get_events_for_frame(int frame) const;
    std::vector<TimelineEvent> get_events_in_range(int start, int end) const;

private:
    bool open_ = false;
    std::filesystem::path path_;
    std::ofstream out_;
    mutable std::mutex mutex_;
    std::vector<TimelineEvent> events_;
    bool incremental_write_ = false;
    std::size_t last_flushed_index_ = 0;
};

} // namespace testing
