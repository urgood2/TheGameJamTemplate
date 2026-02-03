#include "testing/baseline_manager.hpp"

namespace testing {

void BaselineManager::set_root(const std::filesystem::path& root) {
    root_ = root;
}

std::filesystem::path BaselineManager::resolve(const std::string& key) const {
    return root_ / key;
}

} // namespace testing
