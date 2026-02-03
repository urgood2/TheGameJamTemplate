#pragma once
// TODO: Implement path_sandbox

#include <filesystem>

namespace testing {

class PathSandbox {
public:
    void set_root(const std::filesystem::path& root);
    std::filesystem::path resolve(const std::filesystem::path& path) const;
    bool is_allowed(const std::filesystem::path& path) const;

private:
    std::filesystem::path root_;
};

} // namespace testing
