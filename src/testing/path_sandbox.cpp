#include "testing/path_sandbox.hpp"

namespace testing {

void PathSandbox::set_root(const std::filesystem::path& root) {
    root_ = root;
}

std::filesystem::path PathSandbox::resolve(const std::filesystem::path& path) const {
    return root_ / path;
}

bool PathSandbox::is_allowed(const std::filesystem::path& path) const {
    (void)path;
    return true;
}

} // namespace testing
