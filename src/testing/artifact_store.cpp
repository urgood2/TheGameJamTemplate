#include "testing/artifact_store.hpp"

#include <atomic>
#include <fstream>

#include "testing/path_sandbox.hpp"
#include "testing/test_mode_config.hpp"

namespace testing {
namespace {

std::filesystem::path normalize_path(const std::filesystem::path& path) {
    std::error_code ec;
    auto abs = path.is_absolute() ? path : std::filesystem::absolute(path, ec);
    if (ec) {
        abs = path;
    }
    return abs.lexically_normal();
}

std::filesystem::path make_temp_path(const std::filesystem::path& output_path) {
    static std::atomic<uint64_t> counter{0};
    auto suffix = std::to_string(counter.fetch_add(1, std::memory_order_relaxed));
    std::filesystem::path temp = output_path;
    temp += ".tmp" + suffix;
    return temp;
}

} // namespace

void ArtifactStore::initialize(const TestModeConfig& config, PathSandbox& sandbox) {
    sandbox_ = &sandbox;
    artifacts_root_ = normalize_path(config.artifacts_dir);
}

bool ArtifactStore::write_file(const std::filesystem::path& rel_path,
                               std::span<const uint8_t> data) {
    auto resolved = resolve_relative_path(rel_path);
    if (!resolved) {
        return false;
    }

    const auto output_path = *resolved;
    std::error_code ec;
    if (output_path.has_parent_path()) {
        std::filesystem::create_directories(output_path.parent_path(), ec);
        if (ec) {
            return false;
        }
    }

    const auto temp_path = make_temp_path(output_path);
    {
        std::ofstream out(temp_path, std::ios::binary | std::ios::trunc);
        if (!out.is_open()) {
            return false;
        }
        if (!data.empty()) {
            out.write(reinterpret_cast<const char*>(data.data()),
                      static_cast<std::streamsize>(data.size()));
        }
        out.flush();
        if (!out) {
            std::filesystem::remove(temp_path, ec);
            return false;
        }
    }

    std::filesystem::rename(temp_path, output_path, ec);
    if (ec) {
        if (std::filesystem::exists(output_path, ec)) {
            std::filesystem::remove(output_path, ec);
            std::filesystem::rename(temp_path, output_path, ec);
        }
    }

    if (ec) {
        std::filesystem::remove(temp_path, ec);
        return false;
    }

    return true;
}

bool ArtifactStore::write_text(const std::filesystem::path& rel_path,
                               std::string_view content) {
    const auto* data_ptr = reinterpret_cast<const uint8_t*>(content.data());
    return write_file(rel_path, std::span<const uint8_t>(data_ptr, content.size()));
}

bool ArtifactStore::write_json(const std::filesystem::path& rel_path,
                               const nlohmann::json& json) {
    return write_text(rel_path, json.dump(2));
}

bool ArtifactStore::copy_file(const std::filesystem::path& src,
                              const std::filesystem::path& dst_rel) {
    if (!sandbox_) {
        return false;
    }

    auto src_resolved = sandbox_->resolve_read_path(src);
    if (!src_resolved) {
        return false;
    }

    auto dst_resolved = resolve_relative_path(dst_rel);
    if (!dst_resolved) {
        return false;
    }

    std::error_code ec;
    if (dst_resolved->has_parent_path()) {
        std::filesystem::create_directories(dst_resolved->parent_path(), ec);
        if (ec) {
            return false;
        }
    }

    std::filesystem::copy_file(*src_resolved, *dst_resolved,
                               std::filesystem::copy_options::overwrite_existing, ec);
    return !ec;
}

void ArtifactStore::register_artifact(const ArtifactInfo& info) {
    ArtifactInfo stored = info;
    if (!artifacts_root_.empty() && stored.path.is_absolute()) {
        std::error_code ec;
        auto relative = std::filesystem::relative(stored.path, artifacts_root_, ec);
        if (!ec && !relative.empty() && !relative.is_absolute()) {
            stored.path = relative;
        }
    }
    artifacts_.push_back(std::move(stored));
}

std::vector<ArtifactInfo> ArtifactStore::get_artifacts() const {
    return artifacts_;
}

std::filesystem::path ArtifactStore::get_artifact_path(const std::string& test_id,
                                                       const std::string& name) const {
    return artifacts_root_ / std::filesystem::path(test_id) / name;
}

std::optional<std::filesystem::path> ArtifactStore::resolve_relative_path(
    const std::filesystem::path& rel_path) const {
    if (!sandbox_) {
        return std::nullopt;
    }
    if (rel_path.empty() || rel_path.is_absolute()) {
        return std::nullopt;
    }
    if (artifacts_root_.empty()) {
        return std::nullopt;
    }

    auto candidate = artifacts_root_ / rel_path;
    auto resolved = sandbox_->resolve_write_path(candidate);
    if (!resolved) {
        return std::nullopt;
    }
    if (!is_subpath(*resolved, artifacts_root_)) {
        return std::nullopt;
    }
    return resolved;
}

bool ArtifactStore::is_subpath(const std::filesystem::path& candidate,
                               const std::filesystem::path& root) {
    auto root_it = root.begin();
    auto cand_it = candidate.begin();
    for (; root_it != root.end() && cand_it != candidate.end(); ++root_it, ++cand_it) {
        if (*root_it != *cand_it) {
            return false;
        }
    }
    return root_it == root.end();
}

} // namespace testing
