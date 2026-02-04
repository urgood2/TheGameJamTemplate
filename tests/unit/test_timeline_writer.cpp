#include <gtest/gtest.h>

#include <filesystem>
#include <fstream>
#include <string>
#include <vector>

#include <nlohmann/json.hpp>

#include "testing/log_capture.hpp"
#include "testing/test_input_provider.hpp"
#include "testing/timeline_writer.hpp"

namespace {

std::filesystem::path make_temp_path(const std::string& name) {
    auto root = std::filesystem::temp_directory_path() / "timeline_writer_tests";
    std::filesystem::create_directories(root);
    return root / name;
}

std::vector<nlohmann::json> read_jsonl(const std::filesystem::path& path) {
    std::ifstream in(path);
    std::vector<nlohmann::json> entries;
    std::string line;
    while (std::getline(in, line)) {
        if (line.empty()) {
            continue;
        }
        entries.push_back(nlohmann::json::parse(line));
    }
    return entries;
}

} // namespace

TEST(TimelineWriter, RecordsAndFlushesEvents) {
    testing::TimelineWriter writer;
    auto path = make_temp_path("timeline.jsonl");
    ASSERT_TRUE(writer.open(path));

    testing::TestInputEvent input{};
    input.type = "key_down";
    input.key = 32;
    input.x = 10.0f;
    input.y = 20.0f;
    writer.record_input(1, input);

    testing::LogEntry log{};
    log.frame = 1;
    log.message = "hello";
    log.category = "test";
    log.level = "info";
    log.timestamp = "2026-02-04T00:00:00Z";
    writer.record_log(1, log);

    writer.flush();

    auto entries = read_jsonl(path);
    ASSERT_EQ(entries.size(), 2u);
    EXPECT_EQ(entries[0].at("type"), "input");
    EXPECT_EQ(entries[0].at("subtype"), "key_down");
    EXPECT_EQ(entries[0].at("key"), 32);
    EXPECT_EQ(entries[1].at("type"), "log");
    EXPECT_EQ(entries[1].at("message"), "hello");
    EXPECT_EQ(entries[1].at("ts"), "2026-02-04T00:00:00Z");
}

TEST(TimelineWriter, QueryEvents) {
    testing::TimelineWriter writer;
    auto path = make_temp_path("timeline_query.jsonl");
    ASSERT_TRUE(writer.open(path));

    writer.record_test_start(1, "case");
    writer.record_step_start(2, "step");
    writer.record_test_end(3, "case", "pass");

    auto frame_events = writer.get_events_for_frame(2);
    ASSERT_EQ(frame_events.size(), 1u);
    EXPECT_EQ(frame_events[0].type, "step_start");

    auto range_events = writer.get_events_in_range(1, 2);
    ASSERT_EQ(range_events.size(), 2u);
}

TEST(TimelineWriter, WriteOutputsJsonl) {
    testing::TimelineWriter writer;
    auto path = make_temp_path("timeline_write.jsonl");
    ASSERT_TRUE(writer.open(path));

    writer.record_attachment(5, "note", "artifacts/note.txt");
    writer.write(path);

    auto entries = read_jsonl(path);
    ASSERT_EQ(entries.size(), 1u);
    EXPECT_EQ(entries[0].at("type"), "attachment");
    EXPECT_EQ(entries[0].at("path"), "artifacts/note.txt");
}
