#pragma once
#include <filesystem>
#include <optional>
#include <string>
#include <vector>

namespace testing {

struct Region {
    int x = 0;
    int y = 0;
    int width = 0;
    int height = 0;
    std::string selector;
};

struct ScreenshotDiff {
    bool matches = false;
    double diff_ratio = 1.0;
};

class ScreenshotCompare {
public:
    struct CompareOptions {
        float threshold_percent = 0.1f;
        int per_channel_tolerance = 2;
        bool generate_diff = true;
        std::optional<Region> region;
        std::vector<Region> masks;
        bool ignore_alpha = true;
        std::optional<std::filesystem::path> diff_output_path;
    };

    struct CompareResult {
        bool passed = false;
        float diff_percent = 100.0f;
        int diff_pixel_count = 0;
        int total_pixel_count = 0;
        float max_channel_diff = 0.0f;
        std::optional<std::filesystem::path> diff_image_path;
        std::string error;
    };

    CompareResult compare(const std::filesystem::path& actual,
                          const std::filesystem::path& baseline,
                          const CompareOptions& options);

    bool generate_diff_image(const std::filesystem::path& actual,
                             const std::filesystem::path& baseline,
                             const std::filesystem::path& output);
};
ScreenshotDiff compare_screenshots(const std::filesystem::path& left,
                                   const std::filesystem::path& right);

} // namespace testing
