#pragma once

#include <filesystem>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <vector>

#include <nlohmann/json.hpp>

namespace testing {

struct TestModeConfig;
class PathSandbox;

struct ArtifactInfo {
    std::string kind;
    std::filesystem::path path;
    std::optional<int> attempt;
    std::optional<std::string> step;
    std::optional<std::string> description;
    size_t size_bytes = 0;
    std::string created_at;
};

class ArtifactStore {
public:
    void initialize(const TestModeConfig& config, PathSandbox& sandbox);

    bool write_file(const std::filesystem::path& rel_path,
                    std::span<const uint8_t> data);
    bool write_text(const std::filesystem::path& rel_path,
                    std::string_view content);
    bool write_json(const std::filesystem::path& rel_path,
                    const nlohmann::json& json);

    bool copy_file(const std::filesystem::path& src,
                   const std::filesystem::path& dst_rel);

    void register_artifact(const ArtifactInfo& info);
    std::vector<ArtifactInfo> get_artifacts() const;

    std::filesystem::path get_artifact_path(const std::string& test_id,
                                            const std::string& name) const;

private:
    std::optional<std::filesystem::path> resolve_relative_path(
        const std::filesystem::path& rel_path) const;
    static bool is_subpath(const std::filesystem::path& candidate,
                           const std::filesystem::path& root);

    PathSandbox* sandbox_ = nullptr;
    std::filesystem::path artifacts_root_;
    std::vector<ArtifactInfo> artifacts_;
};

} // namespace testing
