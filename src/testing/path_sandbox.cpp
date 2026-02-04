#include "testing/path_sandbox.hpp"

#include <algorithm>
#include <system_error>

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

std::filesystem::path canonicalize_existing(const std::filesystem::path& path) {
    std::error_code ec;
    auto canonical = std::filesystem::canonical(path, ec);
    if (ec) {
        return normalize_path(path);
    }
    return canonical;
}

bool is_subpath(const std::filesystem::path& candidate,
                const std::filesystem::path& root) {
    const auto root_norm = canonicalize_existing(root).generic_string();
    const auto cand_norm = canonicalize_existing(candidate).generic_string();
    if (cand_norm == root_norm) {
        return true;
    }
    std::string prefix = root_norm;
    if (!prefix.empty() && prefix.back() != '/') {
        prefix.push_back('/');
    }
    return cand_norm.rfind(prefix, 0) == 0;
}

void add_unique(std::vector<std::filesystem::path>& roots,
                const std::filesystem::path& root) {
    auto normalized = normalize_path(root);
    for (const auto& existing : roots) {
        if (existing == normalized) {
            return;
        }
    }
    roots.push_back(normalized);
}

} // namespace

void PathSandbox::initialize(const TestModeConfig& config) {
    read_roots_.clear();
    write_roots_.clear();
    baseline_write_allowed_ = false;

    default_root_ = normalize_path(config.run_root);

    const auto repo_root = std::filesystem::current_path();
    add_read_root(repo_root / "assets");
    add_read_root(repo_root / "tests" / "baselines");
    add_read_root(repo_root / "tests" / "baselines_staging");
    add_read_root(repo_root / "assets" / "scripts" / "tests" / "fixtures");

    add_write_root(config.run_root);
    add_write_root(config.artifacts_dir);
    add_write_root(config.forensics_dir);

    if (config.update_baselines || config.baseline_write_mode == BaselineWriteMode::Stage) {
        baseline_write_allowed_ = true;
        add_write_root(config.baseline_staging_dir);
    }
    if (config.baseline_write_mode == BaselineWriteMode::Apply &&
        !config.baseline_approve_token.empty()) {
        baseline_write_allowed_ = true;
        add_write_root(repo_root / "tests" / "baselines");
    }
}

void PathSandbox::add_read_root(const std::filesystem::path& root) {
    if (root.empty()) {
        return;
    }
    add_unique(read_roots_, root);
}

void PathSandbox::add_write_root(const std::filesystem::path& root) {
    if (root.empty()) {
        return;
    }
    add_unique(write_roots_, root);
}

bool PathSandbox::is_readable(const std::filesystem::path& path) const {
    return resolve_read_path(path).has_value();
}

bool PathSandbox::is_writable(const std::filesystem::path& path) const {
    return resolve_write_path(path).has_value();
}

std::optional<std::filesystem::path> PathSandbox::resolve_read_path(
    const std::filesystem::path& path) const {
    if (path.empty()) {
        return std::nullopt;
    }

    std::error_code ec;
    auto abs = path.is_absolute() ? path : std::filesystem::absolute(path, ec);
    if (ec) {
        return std::nullopt;
    }
    auto normalized = abs.lexically_normal();

    auto canonical = std::filesystem::canonical(normalized, ec);
    if (ec) {
        return std::nullopt;
    }

    for (const auto& root : read_roots_) {
        if (is_subpath(canonical, root)) {
            return canonical;
        }
    }

    return std::nullopt;
}

std::optional<std::filesystem::path> PathSandbox::resolve_write_path(
    const std::filesystem::path& path) const {
    if (path.empty()) {
        return std::nullopt;
    }

    std::error_code ec;
    auto abs = path.is_absolute()
        ? path
        : (!default_root_.empty() ? (default_root_ / path) : std::filesystem::absolute(path, ec));
    if (ec) {
        return std::nullopt;
    }
    auto normalized = abs.lexically_normal();

    auto canonical = std::filesystem::weakly_canonical(normalized, ec);
    if (ec) {
        canonical = normalized;
    }

    for (const auto& root : write_roots_) {
        if (is_subpath(canonical, root)) {
            return canonical;
        }
    }

    return std::nullopt;
}

std::vector<std::filesystem::path> PathSandbox::get_read_roots() const {
    return read_roots_;
}

std::vector<std::filesystem::path> PathSandbox::get_write_roots() const {
    return write_roots_;
}

void PathSandbox::set_root(const std::filesystem::path& root) {
    default_root_ = normalize_path(root);
    if (write_roots_.empty()) {
        add_write_root(default_root_);
    }
}

std::filesystem::path PathSandbox::resolve(const std::filesystem::path& path) const {
    auto resolved = resolve_write_path(path);
    if (resolved) {
        return *resolved;
    }
    return default_root_.empty() ? path : (default_root_ / path).lexically_normal();
}

bool PathSandbox::is_allowed(const std::filesystem::path& path) const {
    return is_writable(path);
}

} // namespace testing
