#include "testing/screenshot_compare.hpp"

#include <algorithm>
#include <cmath>
#include <system_error>

#include <raylib.h>
#include <spdlog/spdlog.h>

namespace testing {
namespace {

struct RegionBounds {
    int x0 = 0;
    int y0 = 0;
    int x1 = 0;
    int y1 = 0;
};

std::optional<RegionBounds> clamp_region(const Region& region, int width, int height) {
    if (region.width <= 0 || region.height <= 0) {
        return std::nullopt;
    }
    int x0 = std::max(0, region.x);
    int y0 = std::max(0, region.y);
    int x1 = std::min(width, region.x + region.width);
    int y1 = std::min(height, region.y + region.height);
    if (x1 <= x0 || y1 <= y0) {
        return std::nullopt;
    }
    return RegionBounds{x0, y0, x1, y1};
}

std::optional<RegionBounds> resolve_region(const Region& region, int width, int height) {
    if (!region.selector.empty()) {
        if (region.selector.rfind("ui:", 0) == 0) {
            SPDLOG_WARN("[screenshot_compare] UI selector not resolved: {}", region.selector);
            return std::nullopt;
        }
    }
    return clamp_region(region, width, height);
}

bool point_in_region(int x, int y, const RegionBounds& region) {
    return x >= region.x0 && x < region.x1 && y >= region.y0 && y < region.y1;
}

} // namespace

ScreenshotCompare::CompareResult ScreenshotCompare::compare(const std::filesystem::path& actual,
                                                            const std::filesystem::path& baseline,
                                                            const CompareOptions& options) {
    CompareResult result;

    Image actual_image = LoadImage(actual.string().c_str());
    Image baseline_image = LoadImage(baseline.string().c_str());
    if (!actual_image.data || !baseline_image.data) {
        result.error = "failed to load images";
        if (actual_image.data) {
            UnloadImage(actual_image);
        }
        if (baseline_image.data) {
            UnloadImage(baseline_image);
        }
        return result;
    }

    if (actual_image.width != baseline_image.width || actual_image.height != baseline_image.height) {
        result.error = "dimension mismatch";
        UnloadImage(actual_image);
        UnloadImage(baseline_image);
        return result;
    }

    const int width = actual_image.width;
    const int height = actual_image.height;
    RegionBounds compare_bounds{0, 0, width, height};
    if (options.region) {
        auto resolved = resolve_region(*options.region, width, height);
        if (resolved) {
            compare_bounds = *resolved;
        } else {
            SPDLOG_WARN("[screenshot_compare] Region selector not resolved, comparing full image");
        }
    }

    std::vector<RegionBounds> mask_bounds;
    mask_bounds.reserve(options.masks.size());
    for (const auto& mask : options.masks) {
        auto resolved = resolve_region(mask, width, height);
        if (resolved) {
            mask_bounds.push_back(*resolved);
        }
    }

    Color* actual_pixels = LoadImageColors(actual_image);
    Color* baseline_pixels = LoadImageColors(baseline_image);

    std::vector<Color> diff_pixels;
    if (options.generate_diff) {
        diff_pixels.assign(static_cast<size_t>(width * height), Color{0, 0, 0, 255});
    }

    int diff_count = 0;
    int total_count = 0;
    float max_diff = 0.0f;

    auto is_masked = [&mask_bounds](int x, int y) {
        for (const auto& mask : mask_bounds) {
            if (point_in_region(x, y, mask)) {
                return true;
            }
        }
        return false;
    };

    for (int y = compare_bounds.y0; y < compare_bounds.y1; ++y) {
        for (int x = compare_bounds.x0; x < compare_bounds.x1; ++x) {
            if (is_masked(x, y)) {
                if (options.generate_diff) {
                    diff_pixels[static_cast<size_t>(y * width + x)] = Color{0, 255, 255, 255};
                }
                continue;
            }

            const int index = y * width + x;
            const Color a = actual_pixels[index];
            const Color b = baseline_pixels[index];

            auto diff_channel = [](unsigned char lhs, unsigned char rhs) {
                return std::abs(static_cast<int>(lhs) - static_cast<int>(rhs));
            };

            int max_channel = 0;
            max_channel = std::max(max_channel, diff_channel(a.r, b.r));
            max_channel = std::max(max_channel, diff_channel(a.g, b.g));
            max_channel = std::max(max_channel, diff_channel(a.b, b.b));
            if (!options.ignore_alpha) {
                max_channel = std::max(max_channel, diff_channel(a.a, b.a));
            }

            ++total_count;
            if (max_channel > options.per_channel_tolerance) {
                ++diff_count;
                max_diff = std::max(max_diff, static_cast<float>(max_channel));
                if (options.generate_diff) {
                    unsigned char intensity = static_cast<unsigned char>(std::min(max_channel, 255));
                    diff_pixels[static_cast<size_t>(index)] = Color{intensity, 0, 0, 255};
                }
            }
        }
    }

    UnloadImageColors(actual_pixels);
    UnloadImageColors(baseline_pixels);
    UnloadImage(actual_image);
    UnloadImage(baseline_image);

    result.diff_pixel_count = diff_count;
    result.total_pixel_count = total_count;
    if (total_count == 0) {
        result.diff_percent = 100.0f;
    } else {
        result.diff_percent = static_cast<float>(diff_count) * 100.0f / static_cast<float>(total_count);
    }
    result.max_channel_diff = max_diff;
    result.passed = result.diff_percent <= options.threshold_percent;

    if (options.generate_diff && !diff_pixels.empty()) {
        std::filesystem::path output = options.diff_output_path.value_or(actual.parent_path() / "diff.png");
        std::error_code ec;
        std::filesystem::create_directories(output.parent_path(), ec);
        Image diff_image{};
        diff_image.data = diff_pixels.data();
        diff_image.width = width;
        diff_image.height = height;
        diff_image.mipmaps = 1;
        diff_image.format = PIXELFORMAT_UNCOMPRESSED_R8G8B8A8;
        if (ExportImage(diff_image, output.string().c_str())) {
            result.diff_image_path = output;
        }
    }

    return result;
}

bool ScreenshotCompare::generate_diff_image(const std::filesystem::path& actual,
                                            const std::filesystem::path& baseline,
                                            const std::filesystem::path& output) {
    CompareOptions options;
    options.generate_diff = true;
    options.diff_output_path = output;
    auto result = compare(actual, baseline, options);
    return result.diff_image_path.has_value();
}

ScreenshotDiff compare_screenshots(const std::filesystem::path& left,
                                   const std::filesystem::path& right) {
    ScreenshotCompare comparer;
    ScreenshotCompare::CompareOptions options;
    auto result = comparer.compare(left, right, options);
    ScreenshotDiff diff;
    diff.matches = result.passed;
    diff.diff_ratio = static_cast<double>(result.diff_percent) / 100.0;
    return diff;
}

} // namespace testing
