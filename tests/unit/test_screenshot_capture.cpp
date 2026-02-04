#include <gtest/gtest.h>

#include <filesystem>

#include "testing/screenshot_capture.hpp"
#include "testing/test_mode_config.hpp"

namespace {

std::filesystem::path make_temp_dir() {
    auto root = std::filesystem::temp_directory_path() / "screenshot_capture_tests";
    std::filesystem::create_directories(root);
    return root;
}

} // namespace

TEST(ScreenshotCapture, UnsupportedWithoutInit) {
    testing::ScreenshotCapture capture;
    capture.set_size(640, 360);
    EXPECT_FALSE(capture.is_supported());
}

TEST(ScreenshotCapture, RejectsPathOutsideRunRoot) {
    testing::ScreenshotCapture capture;
    testing::TestModeConfig config;
    config.run_root = make_temp_dir();
    config.resolution_width = 640;
    config.resolution_height = 360;
    config.renderer = testing::RendererMode::Offscreen;
    capture.initialize(config);

    auto bad_path = std::filesystem::path("../escape.png");
    EXPECT_FALSE(capture.capture(bad_path));
}

TEST(ScreenshotCapture, RejectsInvalidRegion) {
    testing::ScreenshotCapture capture;
    testing::TestModeConfig config;
    config.run_root = make_temp_dir();
    config.resolution_width = 640;
    config.resolution_height = 360;
    config.renderer = testing::RendererMode::Offscreen;
    capture.initialize(config);

    testing::Region region;
    region.x = -5;
    region.y = -5;
    region.width = -1;
    region.height = 0;
    auto out = config.run_root / "region.png";
    EXPECT_FALSE(capture.capture_region(out, region));
}

