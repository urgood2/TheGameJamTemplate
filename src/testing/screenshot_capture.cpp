#include "testing/screenshot_capture.hpp"

#include <algorithm>
#include <system_error>

#include <raylib.h>
#include <spdlog/spdlog.h>

#include "testing/test_mode_config.hpp"

namespace testing {

void ScreenshotCapture::initialize(const TestModeConfig& config) {
    set_size(config.resolution_width, config.resolution_height);
    run_root_ = config.run_root;
    supported_ = config.renderer != RendererMode::Null;
}

void ScreenshotCapture::set_size(int width, int height) {
    width_ = width;
    height_ = height;
}

bool ScreenshotCapture::is_supported() const {
    return supported_ && width_ > 0 && height_ > 0;
}

bool ScreenshotCapture::validate_output_path(const std::filesystem::path& output_path,
                                             std::filesystem::path& resolved_path) const {
    if (output_path.empty()) {
        return false;
    }

    if (output_path.is_absolute()) {
        resolved_path = output_path;
    } else if (!run_root_.empty()) {
        resolved_path = run_root_ / output_path;
    } else {
        resolved_path = output_path;
    }

    std::error_code ec;
    auto parent = resolved_path.parent_path();
    if (!parent.empty()) {
        std::filesystem::create_directories(parent, ec);
        if (ec) {
            return false;
        }
    }

    if (!run_root_.empty()) {
        auto root_canon = std::filesystem::weakly_canonical(run_root_, ec);
        if (ec) {
            return false;
        }
        auto target_canon = std::filesystem::weakly_canonical(resolved_path, ec);
        if (ec) {
            return false;
        }
        auto mismatch = std::mismatch(root_canon.begin(), root_canon.end(), target_canon.begin());
        if (mismatch.first != root_canon.end()) {
            SPDLOG_WARN("[screenshot_capture] Path outside run_root: {}", resolved_path.string());
            return false;
        }
    }

    return true;
}

bool ScreenshotCapture::capture(const std::filesystem::path& output_path) {
    if (!is_supported()) {
        return false;
    }

    if (!IsWindowReady()) {
        SPDLOG_WARN("[screenshot_capture] Window not ready");
        return false;
    }

    std::filesystem::path resolved;
    if (!validate_output_path(output_path, resolved)) {
        return false;
    }

    Image image = LoadImageFromScreen();
    if (!image.data) {
        SPDLOG_WARN("[screenshot_capture] Failed to read screen image");
        return false;
    }

    bool ok = ExportImage(image, resolved.string().c_str());
    UnloadImage(image);
    return ok;
}

bool ScreenshotCapture::capture_region(const std::filesystem::path& output_path, const Region& region) {
    if (!is_supported()) {
        return false;
    }
    if (!IsWindowReady()) {
        SPDLOG_WARN("[screenshot_capture] Window not ready");
        return false;
    }

    if (region.width <= 0 || region.height <= 0) {
        return false;
    }

    std::filesystem::path resolved;
    if (!validate_output_path(output_path, resolved)) {
        return false;
    }

    Image image = LoadImageFromScreen();
    if (!image.data) {
        SPDLOG_WARN("[screenshot_capture] Failed to read screen image");
        return false;
    }

    int x = std::max(0, region.x);
    int y = std::max(0, region.y);
    int x2 = std::min(image.width, region.x + region.width);
    int y2 = std::min(image.height, region.y + region.height);
    if (x2 <= x || y2 <= y) {
        UnloadImage(image);
        return false;
    }

    Rectangle rect{static_cast<float>(x),
                   static_cast<float>(y),
                   static_cast<float>(x2 - x),
                   static_cast<float>(y2 - y)};
    ImageCrop(&image, rect);

    bool ok = ExportImage(image, resolved.string().c_str());
    UnloadImage(image);
    return ok;
}

} // namespace testing
