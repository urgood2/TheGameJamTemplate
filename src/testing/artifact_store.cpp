#include "testing/artifact_store.hpp"

#include <fstream>

namespace testing {

void ArtifactStore::set_root(const std::filesystem::path& root) {
    root_ = root;
}

bool ArtifactStore::write_text(const std::filesystem::path& relative_path,
                              const std::string& contents) {
    std::filesystem::path output_path = relative_path;
    if (!output_path.is_absolute()) {
        output_path = root_ / output_path;
    }

    std::error_code error;
    const auto parent = output_path.parent_path();
    if (!parent.empty()) {
        std::filesystem::create_directories(parent, error);
    }

    std::ofstream out(output_path);
    if (!out.is_open()) {
        return false;
    }
    out << contents;
    return static_cast<bool>(out);
}

} // namespace testing
