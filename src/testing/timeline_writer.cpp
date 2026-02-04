#include "testing/timeline_writer.hpp"

#include <chrono>
#include <iomanip>
#include <sstream>
#include <system_error>

#include "testing/test_mode_config.hpp"

namespace testing {
namespace {

std::string iso_timestamp_utc() {
    using clock = std::chrono::system_clock;
    auto now = clock::now();
    std::time_t tt = clock::to_time_t(now);
    std::tm tm{};
#if defined(_WIN32)
    gmtime_s(&tm, &tt);
#else
    gmtime_r(&tt, &tm);
#endif
    std::ostringstream out;
    out << std::put_time(&tm, "%Y-%m-%dT%H:%M:%SZ");
    return out.str();
}

nlohmann::json event_to_json(const TimelineEvent& event) {
    nlohmann::json obj;
    obj["frame"] = event.frame;
    obj["type"] = event.type;
    obj["ts"] = event.ts;
    if (!event.subtype.empty()) {
        obj["subtype"] = event.subtype;
    }
    if (event.data.is_object()) {
        for (auto it = event.data.begin(); it != event.data.end(); ++it) {
            obj[it.key()] = it.value();
        }
    }
    return obj;
}

} // namespace

void TimelineWriter::initialize(const TestModeConfig& config) {
    open(config.forensics_dir / "timeline.jsonl");
    incremental_write_ = true;
}

void TimelineWriter::shutdown() {
    flush();
    close();
    std::scoped_lock lock(mutex_);
    events_.clear();
    last_flushed_index_ = 0;
}

bool TimelineWriter::open(const std::filesystem::path& path) {
    path_ = path;
    std::error_code ec;
    if (!path_.empty()) {
        std::filesystem::create_directories(path_.parent_path(), ec);
    }
    out_.open(path_, std::ios::out | std::ios::trunc);
    open_ = out_.is_open();
    last_flushed_index_ = 0;
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

void TimelineWriter::record_input(int frame, const TestInputEvent& event) {
    TimelineEvent timeline_event;
    timeline_event.frame = frame;
    timeline_event.type = "input";
    timeline_event.subtype = event.type;
    timeline_event.ts = iso_timestamp_utc();
    timeline_event.data = {
        {"key", event.key},
        {"x", event.x},
        {"y", event.y},
    };
    {
        std::scoped_lock lock(mutex_);
        events_.push_back(std::move(timeline_event));
    }
    if (incremental_write_) {
        flush();
    }
}

void TimelineWriter::record_log(int frame, const LogEntry& entry) {
    TimelineEvent timeline_event;
    timeline_event.frame = frame;
    timeline_event.type = "log";
    timeline_event.ts = entry.timestamp.empty() ? iso_timestamp_utc() : entry.timestamp;
    timeline_event.data = {
        {"level", entry.level},
        {"category", entry.category},
        {"message", entry.message},
    };
    {
        std::scoped_lock lock(mutex_);
        events_.push_back(std::move(timeline_event));
    }
    if (incremental_write_) {
        flush();
    }
}

void TimelineWriter::record_screenshot(int frame, const std::string& name, const std::string& path) {
    TimelineEvent timeline_event;
    timeline_event.frame = frame;
    timeline_event.type = "screenshot";
    timeline_event.ts = iso_timestamp_utc();
    timeline_event.data = {
        {"name", name},
        {"path", path},
    };
    {
        std::scoped_lock lock(mutex_);
        events_.push_back(std::move(timeline_event));
    }
    if (incremental_write_) {
        flush();
    }
}

void TimelineWriter::record_step_start(int frame, const std::string& name) {
    TimelineEvent timeline_event;
    timeline_event.frame = frame;
    timeline_event.type = "step_start";
    timeline_event.ts = iso_timestamp_utc();
    timeline_event.data = {
        {"name", name},
    };
    {
        std::scoped_lock lock(mutex_);
        events_.push_back(std::move(timeline_event));
    }
    if (incremental_write_) {
        flush();
    }
}

void TimelineWriter::record_step_end(int frame, const std::string& name, const std::string& status) {
    TimelineEvent timeline_event;
    timeline_event.frame = frame;
    timeline_event.type = "step_end";
    timeline_event.ts = iso_timestamp_utc();
    timeline_event.data = {
        {"name", name},
        {"status", status},
    };
    {
        std::scoped_lock lock(mutex_);
        events_.push_back(std::move(timeline_event));
    }
    if (incremental_write_) {
        flush();
    }
}

void TimelineWriter::record_hash(int frame, const std::string& scope, const std::string& hash) {
    TimelineEvent timeline_event;
    timeline_event.frame = frame;
    timeline_event.type = "hash";
    timeline_event.ts = iso_timestamp_utc();
    timeline_event.data = {
        {"scope", scope},
        {"value", hash},
    };
    {
        std::scoped_lock lock(mutex_);
        events_.push_back(std::move(timeline_event));
    }
    if (incremental_write_) {
        flush();
    }
}

void TimelineWriter::record_attachment(int frame, const std::string& name, const std::string& path) {
    TimelineEvent timeline_event;
    timeline_event.frame = frame;
    timeline_event.type = "attachment";
    timeline_event.ts = iso_timestamp_utc();
    timeline_event.data = {
        {"name", name},
        {"path", path},
    };
    {
        std::scoped_lock lock(mutex_);
        events_.push_back(std::move(timeline_event));
    }
    if (incremental_write_) {
        flush();
    }
}

void TimelineWriter::record_test_start(int frame, const std::string& test_id) {
    TimelineEvent timeline_event;
    timeline_event.frame = frame;
    timeline_event.type = "test_start";
    timeline_event.ts = iso_timestamp_utc();
    timeline_event.data = {
        {"test_id", test_id},
    };
    {
        std::scoped_lock lock(mutex_);
        events_.push_back(std::move(timeline_event));
    }
    if (incremental_write_) {
        flush();
    }
}

void TimelineWriter::record_test_end(int frame, const std::string& test_id, const std::string& status) {
    TimelineEvent timeline_event;
    timeline_event.frame = frame;
    timeline_event.type = "test_end";
    timeline_event.ts = iso_timestamp_utc();
    timeline_event.data = {
        {"test_id", test_id},
        {"status", status},
    };
    {
        std::scoped_lock lock(mutex_);
        events_.push_back(std::move(timeline_event));
    }
    if (incremental_write_) {
        flush();
    }
}

void TimelineWriter::record_logs_batch(const std::vector<std::pair<int, LogEntry>>& logs) {
    for (const auto& entry : logs) {
        record_log(entry.first, entry.second);
    }
}

void TimelineWriter::flush() {
    if (!open_ || !out_.is_open()) {
        return;
    }

    std::vector<TimelineEvent> snapshot;
    {
        std::scoped_lock lock(mutex_);
        if (last_flushed_index_ >= events_.size()) {
            return;
        }
        snapshot.assign(events_.begin() + static_cast<long>(last_flushed_index_), events_.end());
        last_flushed_index_ = events_.size();
    }

    for (const auto& event : snapshot) {
        write_event(event_to_json(event).dump());
    }
    out_.flush();
}

void TimelineWriter::write(const std::filesystem::path& path) {
    std::vector<TimelineEvent> snapshot;
    {
        std::scoped_lock lock(mutex_);
        snapshot = events_;
    }

    std::error_code ec;
    std::filesystem::create_directories(path.parent_path(), ec);
    std::ofstream out(path, std::ios::out | std::ios::trunc);
    if (!out) {
        return;
    }
    for (const auto& event : snapshot) {
        out << event_to_json(event).dump() << '\n';
    }
}

std::vector<TimelineEvent> TimelineWriter::get_events_for_frame(int frame) const {
    std::vector<TimelineEvent> result;
    std::scoped_lock lock(mutex_);
    for (const auto& event : events_) {
        if (event.frame == frame) {
            result.push_back(event);
        }
    }
    return result;
}

std::vector<TimelineEvent> TimelineWriter::get_events_in_range(int start, int end) const {
    std::vector<TimelineEvent> result;
    std::scoped_lock lock(mutex_);
    for (const auto& event : events_) {
        if (event.frame >= start && event.frame <= end) {
            result.push_back(event);
        }
    }
    return result;
}

} // namespace testing
