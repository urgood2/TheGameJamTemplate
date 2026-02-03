#pragma once
// TODO: Implement screenshot_compare

#include <filesystem>

namespace testing {

struct ScreenshotDiff {
    bool matches = false;
    double diff_ratio = 1.0;
};

ScreenshotDiff compare_screenshots(const std::filesystem::path& left,
                                  const std::filesystem::path& right);

} // namespace testing
