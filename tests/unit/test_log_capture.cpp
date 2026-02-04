#include "testing/log_capture.hpp"

#include <gtest/gtest.h>

TEST(LogCapture, AddAndClear) {
    testing::LogCapture capture;
    testing::LogLine line{0, "message", "category", "info", ""};
    capture.add(line);
    EXPECT_FALSE(capture.empty());
    EXPECT_EQ(capture.size(), 1u);
    capture.clear();
    EXPECT_TRUE(capture.empty());
}
