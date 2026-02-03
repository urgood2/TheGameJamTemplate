#pragma once
// TODO: Implement screenshot_capture

#include <filesystem>

namespace testing {

struct Screenshot {
    std::filesystem::path path;
    int width = 0;
    int height = 0;
};

class ScreenshotCapture {
public:
    void set_size(int width, int height);
    bool capture(const std::filesystem::path& output_path);

private:
    int width_ = 0;
    int height_ = 0;
};

} // namespace testing
