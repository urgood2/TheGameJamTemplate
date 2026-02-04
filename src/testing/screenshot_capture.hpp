#pragma once
#include <filesystem>
#include <optional>

#include "testing/screenshot_compare.hpp"

namespace testing {

struct Screenshot {
    std::filesystem::path path;
    int width = 0;
    int height = 0;
};

class ScreenshotCapture {
public:
    void initialize(const struct TestModeConfig& config);
    void set_size(int width, int height);
    bool capture(const std::filesystem::path& output_path);
    bool capture_region(const std::filesystem::path& output_path, const Region& region);
    bool is_supported() const;

private:
    bool validate_output_path(const std::filesystem::path& output_path,
                              std::filesystem::path& resolved_path) const;

    int width_ = 0;
    int height_ = 0;
    bool supported_ = false;
    std::filesystem::path run_root_;
};

} // namespace testing
