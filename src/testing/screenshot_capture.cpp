#include "testing/screenshot_capture.hpp"

namespace testing {

void ScreenshotCapture::set_size(int width, int height) {
    width_ = width;
    height_ = height;
}

bool ScreenshotCapture::capture(const std::filesystem::path& output_path) {
    (void)output_path;
    return false;
}

} // namespace testing
