#include "testing/artifact_store.hpp"

namespace testing {

void ArtifactStore::set_root(const std::filesystem::path& root) {
    root_ = root;
}

bool ArtifactStore::write_text(const std::filesystem::path& relative_path,
                              const std::string& contents) {
    (void)relative_path;
    (void)contents;
    return false;
}

} // namespace testing
