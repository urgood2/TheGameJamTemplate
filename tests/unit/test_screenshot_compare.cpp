#include <gtest/gtest.h>

#include <filesystem>

#include <raylib.h>

#include "testing/screenshot_compare.hpp"

namespace {

std::filesystem::path make_temp_dir() {
    auto root = std::filesystem::temp_directory_path() / "screenshot_compare_tests";
    std::filesystem::create_directories(root);
    return root;
}

std::filesystem::path write_image(const std::string& name, const Color& color, bool alter_pixel) {
    auto root = make_temp_dir();
    auto path = root / name;
    Image image = GenImageColor(2, 2, color);
    if (alter_pixel) {
        ImageDrawPixel(&image, 1, 1, Color{static_cast<unsigned char>(color.r ^ 0xFF), color.g, color.b, color.a});
    }
    ExportImage(image, path.string().c_str());
    UnloadImage(image);
    return path;
}

} // namespace

TEST(ScreenshotCompare, IdenticalImagesPass) {
    auto path_a = write_image("a.png", Color{10, 20, 30, 255}, false);
    auto path_b = write_image("b.png", Color{10, 20, 30, 255}, false);

    testing::ScreenshotCompare comparer;
    testing::ScreenshotCompare::CompareOptions options;
    options.threshold_percent = 0.0f;

    auto result = comparer.compare(path_a, path_b, options);
    EXPECT_TRUE(result.passed);
    EXPECT_EQ(result.diff_pixel_count, 0);
}

TEST(ScreenshotCompare, DetectsDifferences) {
    auto path_a = write_image("c.png", Color{10, 20, 30, 255}, false);
    auto path_b = write_image("d.png", Color{10, 20, 30, 255}, true);

    testing::ScreenshotCompare comparer;
    testing::ScreenshotCompare::CompareOptions options;
    options.threshold_percent = 0.0f;

    auto result = comparer.compare(path_a, path_b, options);
    EXPECT_FALSE(result.passed);
    EXPECT_GT(result.diff_pixel_count, 0);
    EXPECT_TRUE(result.diff_image_path.has_value());
}

TEST(ScreenshotCompare, MaskIgnoresRegion) {
    auto path_a = write_image("e.png", Color{10, 20, 30, 255}, false);
    auto path_b = write_image("f.png", Color{10, 20, 30, 255}, true);

    testing::ScreenshotCompare comparer;
    testing::ScreenshotCompare::CompareOptions options;
    options.threshold_percent = 0.0f;
    testing::Region mask;
    mask.x = 1;
    mask.y = 1;
    mask.width = 1;
    mask.height = 1;
    options.masks.push_back(mask);

    auto result = comparer.compare(path_a, path_b, options);
    EXPECT_TRUE(result.passed);
}

TEST(ScreenshotCompare, ToleranceAllowsSmallDiff) {
    auto path_a = write_image("g.png", Color{10, 20, 30, 255}, false);
    auto path_b = write_image("h.png", Color{12, 20, 30, 255}, false);

    testing::ScreenshotCompare comparer;
    testing::ScreenshotCompare::CompareOptions options;
    options.per_channel_tolerance = 5;
    options.threshold_percent = 0.0f;

    auto result = comparer.compare(path_a, path_b, options);
    EXPECT_TRUE(result.passed);
}

