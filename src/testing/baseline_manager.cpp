#include "testing/baseline_manager.hpp"

#include <cstdlib>
#include <fstream>

#include "nlohmann/json.hpp"
#include "spdlog/spdlog.h"

namespace testing {
namespace {

std::string detect_platform() {
#if defined(_WIN32)
    return "windows";
#elif defined(__APPLE__)
    return "mac";
#elif defined(__linux__)
    return "linux";
#else
    return "unknown";
#endif
}

std::string sanitize_component(const std::string& value) {
    std::string out = value;
    for (auto& ch : out) {
        if (ch == '/' || ch == '\\') {
            ch = '_';
        }
    }
    while (out.find("..") != std::string::npos) {
        out.replace(out.find(".."), 2, "__");
    }
    return out;
}

std::filesystem::path ensure_png_extension(const std::string& name) {
    std::filesystem::path path(name);
    if (path.extension().empty()) {
        path += ".png";
    }
    return path;
}

std::filesystem::path baseline_root(const std::filesystem::path& repo_root) {
    return repo_root / "tests" / "baselines";
}

bool copy_atomic(const std::filesystem::path& source,
                 const std::filesystem::path& dest) {
    std::error_code ec;
    if (!std::filesystem::exists(source)) {
        return false;
    }
    std::filesystem::create_directories(dest.parent_path(), ec);
    if (ec) {
        return false;
    }
    auto tmp = dest;
    tmp += ".tmp";
    std::filesystem::copy_file(source, tmp, std::filesystem::copy_options::overwrite_existing, ec);
    if (ec) {
        return false;
    }
    std::filesystem::rename(tmp, dest, ec);
    if (ec) {
        std::filesystem::remove(tmp, ec);
        return false;
    }
    return true;
}

BaselineMetadata parse_metadata(const std::filesystem::path& path) {
    BaselineMetadata meta;
    std::ifstream input(path);
    if (!input) {
        return meta;
    }

    nlohmann::json data;
    input >> data;
    if (!data.is_object()) {
        return meta;
    }

    if (data.contains("threshold_percent")) {
        meta.threshold_percent = data.value("threshold_percent", meta.threshold_percent);
    }
    if (data.contains("per_channel_tolerance")) {
        meta.per_channel_tolerance = data.value("per_channel_tolerance", meta.per_channel_tolerance);
    }
    if (data.contains("notes")) {
        meta.notes = data.value("notes", "");
    }
    if (data.contains("masks") && data["masks"].is_array()) {
        for (const auto& mask : data["masks"]) {
            if (!mask.is_object()) {
                continue;
            }
            BaselineMask item;
            item.x = mask.value("x", 0);
            item.y = mask.value("y", 0);
            item.w = mask.value("w", 0);
            item.h = mask.value("h", 0);
            meta.masks.push_back(item);
        }
    }

    return meta;
}

} // namespace

void BaselineManager::initialize(const TestModeConfig& config) {
    platform_ = detect_platform();
    if (!config.baseline_key.empty()) {
        baseline_key_ = config.baseline_key;
    } else {
        const std::string backend = (config.renderer == RendererMode::Null) ? "null" : "software";
        baseline_key_ = backend + std::string("_sdr_srgb");
    }

    resolution_ = std::to_string(config.resolution_width) + "x" +
        std::to_string(config.resolution_height);
    write_mode_ = config.baseline_write_mode;
    approve_token_ = config.baseline_approve_token;

    const auto repo_root = std::filesystem::current_path();
    baselines_dir_ = baseline_root(repo_root);
    staging_dir_ = config.baseline_staging_dir.empty()
        ? (repo_root / "tests" / "baselines_staging")
        : config.baseline_staging_dir;

    SPDLOG_INFO("BaselineManager: Platform detected as '{}'", platform_);
    SPDLOG_INFO("BaselineManager: Using baseline_key '{}'", baseline_key_);
}

std::optional<std::filesystem::path> BaselineManager::resolve_baseline(
    const std::string& test_id,
    const std::string& name) const {
    if (test_id.empty() || name.empty()) {
        return std::nullopt;
    }
    auto dir = get_baseline_dir(test_id);
    auto file = ensure_png_extension(name);
    auto path = dir / file;
    if (!std::filesystem::exists(path)) {
        SPDLOG_WARN("BaselineManager: Baseline not found: {}/{}", test_id, name);
        return std::nullopt;
    }
    SPDLOG_DEBUG("BaselineManager: Resolved baseline path: {}", path.string());
    return path;
}

std::optional<std::filesystem::path> BaselineManager::resolve_metadata(
    const std::string& test_id,
    const std::string& name) const {
    if (test_id.empty() || name.empty()) {
        return std::nullopt;
    }
    auto dir = get_baseline_dir(test_id);
    auto file = ensure_png_extension(name);
    file += ".meta.json";
    auto path = dir / file;
    if (!std::filesystem::exists(path)) {
        SPDLOG_WARN("BaselineManager: Metadata file not found, using defaults");
        return std::nullopt;
    }
    SPDLOG_DEBUG("BaselineManager: Loading metadata from: {}", path.string());
    return path;
}

BaselineMetadata BaselineManager::load_metadata(const std::string& test_id,
                                               const std::string& name) const {
    auto path = resolve_metadata(test_id, name);
    if (!path) {
        return {};
    }
    try {
        return parse_metadata(*path);
    } catch (const std::exception& ex) {
        SPDLOG_WARN("BaselineManager: Metadata parse failed: {}", ex.what());
        return {};
    }
}

bool BaselineManager::write_baseline(const std::string& test_id,
                                    const std::string& name,
                                    const std::filesystem::path& source) {
    if (test_id.empty() || name.empty()) {
        return false;
    }

    if (write_mode_ == BaselineWriteMode::Deny) {
        SPDLOG_WARN("BaselineManager: Write mode is 'deny', cannot write baseline");
        return false;
    }

    std::filesystem::path root = baselines_dir_;
    if (write_mode_ == BaselineWriteMode::Stage) {
        root = staging_dir_;
        SPDLOG_INFO("BaselineManager: Writing baseline to staging: {}", root.string());
    } else if (write_mode_ == BaselineWriteMode::Apply) {
        const char* env_token = std::getenv("E2E_BASELINE_APPROVE");
        if (!env_token || approve_token_.empty() || approve_token_ != env_token) {
            SPDLOG_WARN("BaselineManager: Apply mode requires approval token");
            return false;
        }
        SPDLOG_INFO("BaselineManager: Writing baseline to baselines: {}", root.string());
    }

    auto safe_test_id = sanitize_component(test_id);
    auto safe_name = sanitize_component(name);

    auto dest_dir = root / platform_ / baseline_key_ / resolution_ / safe_test_id;
    auto dest_file = ensure_png_extension(safe_name);
    auto dest_path = dest_dir / dest_file;

    return copy_atomic(source, dest_path);
}

std::string BaselineManager::baseline_key() const {
    return baseline_key_;
}

std::filesystem::path BaselineManager::get_baseline_dir(const std::string& test_id) const {
    const auto safe_id = sanitize_component(test_id);
    return baselines_dir_ / platform_ / baseline_key_ / resolution_ / safe_id;
}

} // namespace testing
