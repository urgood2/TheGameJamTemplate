#include "testing/screenshot_compare.hpp"

namespace testing {

ScreenshotDiff compare_screenshots(const std::filesystem::path& left,
                                  const std::filesystem::path& right) {
    (void)left;
    (void)right;
    return ScreenshotDiff{};
}

} // namespace testing
