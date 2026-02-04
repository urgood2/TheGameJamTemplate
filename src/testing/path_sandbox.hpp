#pragma once

#include <filesystem>
#include <optional>
#include <vector>

namespace testing {

struct TestModeConfig;

class PathSandbox {
public:
    void initialize(const TestModeConfig& config);
    void add_read_root(const std::filesystem::path& root);
    void add_write_root(const std::filesystem::path& root);

    bool is_readable(const std::filesystem::path& path) const;
    bool is_writable(const std::filesystem::path& path) const;

    std::optional<std::filesystem::path> resolve_read_path(const std::filesystem::path& path) const;
    std::optional<std::filesystem::path> resolve_write_path(const std::filesystem::path& path) const;

    std::vector<std::filesystem::path> get_read_roots() const;
    std::vector<std::filesystem::path> get_write_roots() const;

    void set_root(const std::filesystem::path& root);
    std::filesystem::path resolve(const std::filesystem::path& path) const;
    bool is_allowed(const std::filesystem::path& path) const;

private:
    std::vector<std::filesystem::path> read_roots_;
    std::vector<std::filesystem::path> write_roots_;
    std::filesystem::path default_root_;
    bool baseline_write_allowed_ = false;
};

} // namespace testing
