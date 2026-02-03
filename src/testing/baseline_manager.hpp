#pragma once
// TODO: Implement baseline_manager

#include <filesystem>
#include <string>

namespace testing {

class BaselineManager {
public:
    void set_root(const std::filesystem::path& root);
    std::filesystem::path resolve(const std::string& key) const;

private:
    std::filesystem::path root_;
};

} // namespace testing
