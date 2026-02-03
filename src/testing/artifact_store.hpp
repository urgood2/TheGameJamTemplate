#pragma once
// TODO: Implement artifact_store

#include <filesystem>
#include <string>

namespace testing {

class ArtifactStore {
public:
    void set_root(const std::filesystem::path& root);
    bool write_text(const std::filesystem::path& relative_path,
                    const std::string& contents);

private:
    std::filesystem::path root_;
};

} // namespace testing
